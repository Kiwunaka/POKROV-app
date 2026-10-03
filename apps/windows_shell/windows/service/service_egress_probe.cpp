#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <bcrypt.h>
#include <iphlpapi.h>
#include <windns.h>
#include <winhttp.h>

#include "service_runtime.h"

#include <array>
#include <atomic>
#include <memory>
#include <vector>

namespace pokrov::service {
namespace {

bool Interrupted(const CheckInterruption& check) {
  return check && check() != OperationInterruption::kNone;
}

constexpr wchar_t kProbeHostname[] = L"api.pokrov.space";

struct TunDnsEndpoint {
  ULONG interface_index = 0;
  sockaddr_in local{};
  sockaddr_in dns{};
};

struct ProbeObservation {
  EgressProbeStage stage = EgressProbeStage::kTunDns;
  EgressErrorDomain domain = EgressErrorDomain::kNone;
  DWORD error = 0;
  bool timed_out = false;

  void Error(EgressErrorDomain source, DWORD code) {
    if (domain != EgressErrorDomain::kNone) return;
    domain = source;
    error = code;
  }
};

bool FindTunDns(TunDnsEndpoint* result, ProbeObservation* observation) {
  ULONG size = 15 * 1024;
  std::vector<unsigned char> buffer(size);
  auto* adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
  ULONG status = ::GetAdaptersAddresses(AF_INET, GAA_FLAG_SKIP_ANYCAST |
      GAA_FLAG_SKIP_MULTICAST, nullptr, adapters, &size);
  if (status == ERROR_BUFFER_OVERFLOW) {
    buffer.resize(size);
    adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
    status = ::GetAdaptersAddresses(AF_INET, GAA_FLAG_SKIP_ANYCAST |
        GAA_FLAG_SKIP_MULTICAST, nullptr, adapters, &size);
  }
  if (status != NO_ERROR) {
    observation->Error(EgressErrorDomain::kWin32, status);
    return false;
  }
  bool found = false;
  for (auto* adapter = adapters; adapter != nullptr; adapter = adapter->Next) {
    if (adapter->FriendlyName == nullptr ||
        std::wstring(adapter->FriendlyName) != L"POKROV" ||
        adapter->OperStatus != IfOperStatusUp) continue;
    if (found) return false;
    for (auto* local = adapter->FirstUnicastAddress; local; local = local->Next) {
      if (local->Address.lpSockaddr == nullptr ||
          local->Address.lpSockaddr->sa_family != AF_INET) continue;
      const auto address = *reinterpret_cast<sockaddr_in*>(local->Address.lpSockaddr);
      for (auto* dns = adapter->FirstDnsServerAddress; dns; dns = dns->Next) {
        if (dns->Address.lpSockaddr == nullptr ||
            dns->Address.lpSockaddr->sa_family != AF_INET) continue;
        const auto server = *reinterpret_cast<sockaddr_in*>(dns->Address.lpSockaddr);
        // sing-tun assigns its internal DNS to the next TUN address. Never
        // send this probe to another adapter's or an external DNS server.
        if (ntohl(server.sin_addr.s_addr) != ntohl(address.sin_addr.s_addr) + 1) continue;
        result->interface_index = adapter->IfIndex;
        result->local = address;
        result->local.sin_port = 0;
        result->dns = server;
        result->dns.sin_port = htons(53);
        found = true;
        break;
      }
      if (found) break;
    }
  }
  return found && result->interface_index != 0;
}

std::wstring QueryProbeAddress(const TunDnsEndpoint& endpoint,
                              const CheckInterruption& interrupted,
                              ProbeObservation* observation) {
  observation->stage = EgressProbeStage::kDnsSetup;
  WSADATA wsa{};
  const int startup_error = ::WSAStartup(MAKEWORD(2, 2), &wsa);
  if (startup_error != 0) {
    observation->Error(EgressErrorDomain::kWinsock, startup_error);
    return {};
  }
  const SOCKET socket = ::socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (socket == INVALID_SOCKET) {
    observation->Error(EgressErrorDomain::kWinsock, ::WSAGetLastError());
  }
  std::wstring result;
  const auto query = [&] {
    if (socket == INVALID_SOCKET || Interrupted(interrupted)) return;
    const DWORD interface_index = htonl(endpoint.interface_index);
    u_long nonblocking = 1;
    if (::setsockopt(socket, IPPROTO_IP, IP_UNICAST_IF,
            reinterpret_cast<const char*>(&interface_index), sizeof(interface_index)) ||
        ::bind(socket, reinterpret_cast<const sockaddr*>(&endpoint.local), sizeof(endpoint.local)) ||
        ::connect(socket, reinterpret_cast<const sockaddr*>(&endpoint.dns), sizeof(endpoint.dns)) ||
        ::ioctlsocket(socket, FIONBIO, &nonblocking)) {
      observation->Error(EgressErrorDomain::kWinsock, ::WSAGetLastError());
      return;
    }
    // The Windows builder requires its UDP workspace (1472 bytes), even for
    // this one short question. Only request_size bytes are sent.
    alignas(DNS_MESSAGE_BUFFER) std::array<unsigned char, 4096> request{};
    DWORD request_size = static_cast<DWORD>(request.size());
    WORD transaction = 0;
    const auto random_status = ::BCryptGenRandom(nullptr,
        reinterpret_cast<PUCHAR>(&transaction), sizeof(transaction),
        BCRYPT_USE_SYSTEM_PREFERRED_RNG);
    if (random_status != 0) {
      observation->Error(EgressErrorDomain::kNtStatus, random_status);
      return;
    }
    if (!::DnsWriteQuestionToBuffer_W(reinterpret_cast<DNS_MESSAGE_BUFFER*>(request.data()),
            &request_size, kProbeHostname, DNS_TYPE_A, transaction, TRUE)) {
      observation->Error(EgressErrorDomain::kWin32, ::GetLastError());
      return;
    }
    observation->stage = EgressProbeStage::kDnsSend;
    const int sent = ::send(socket, reinterpret_cast<const char*>(request.data()),
                            static_cast<int>(request_size), 0);
    if (sent != static_cast<int>(request_size)) {
      if (sent == SOCKET_ERROR) {
        observation->Error(EgressErrorDomain::kWinsock, ::WSAGetLastError());
      }
      return;
    }
    observation->stage = EgressProbeStage::kDnsWait;
    const auto deadline = ::GetTickCount64() + 3000;
    while (!Interrupted(interrupted) && ::GetTickCount64() < deadline) {
      fd_set readable;
      FD_ZERO(&readable);
      FD_SET(socket, &readable);
      timeval timeout{0, 50000};
      const int ready = ::select(0, &readable, nullptr, nullptr, &timeout);
      if (ready < 0) {
        observation->Error(EgressErrorDomain::kWinsock, ::WSAGetLastError());
        return;
      }
      if (ready == 0) continue;
      alignas(DNS_MESSAGE_BUFFER) std::array<unsigned char, 4096> reply{};
      sockaddr_in source{};
      int source_size = sizeof(source);
      const int received = ::recvfrom(socket, reinterpret_cast<char*>(reply.data()),
          static_cast<int>(reply.size()), 0, reinterpret_cast<sockaddr*>(&source), &source_size);
      if (received == SOCKET_ERROR) {
        observation->Error(EgressErrorDomain::kWinsock, ::WSAGetLastError());
        return;
      }
      observation->stage = EgressProbeStage::kDnsReply;
      if (received < static_cast<int>(sizeof(DNS_HEADER)) ||
          source.sin_family != AF_INET || source.sin_port != endpoint.dns.sin_port ||
          source.sin_addr.s_addr != endpoint.dns.sin_addr.s_addr) return;
      auto* message = reinterpret_cast<DNS_MESSAGE_BUFFER*>(reply.data());
      DNS_BYTE_FLIP_HEADER_COUNTS(&message->MessageHead);
      const auto& header = message->MessageHead;
      if (header.Xid != transaction || !header.IsResponse || header.Opcode != DNS_OPCODE_QUERY ||
          header.ResponseCode != DNS_RCODE_NOERROR || header.Truncation ||
          header.QuestionCount != 1) {
        if (header.ResponseCode != DNS_RCODE_NOERROR) {
          observation->Error(EgressErrorDomain::kDns, header.ResponseCode);
        }
        return;
      }
      DNS_RECORDW* records = nullptr;
      const auto extract_status = ::DnsExtractRecordsFromMessage_W(
          message, static_cast<WORD>(received), &records);
      if (extract_status != 0) {
        observation->Error(EgressErrorDomain::kDns, extract_status);
        return;
      }
      for (auto* record = records; record != nullptr; record = record->pNext) {
        if (record->Flags.S.Section != DnsSectionAnswer || record->wType != DNS_TYPE_A ||
            record->pName == nullptr || !::DnsNameCompare_W(record->pName, kProbeHostname)) continue;
        IN_ADDR address{};
        address.s_addr = record->Data.A.IpAddress;
        wchar_t numeric[INET_ADDRSTRLEN]{};
        if (::InetNtopW(AF_INET, &address, numeric, INET_ADDRSTRLEN)) {
          result = numeric;
        } else {
          observation->Error(EgressErrorDomain::kWinsock, ::WSAGetLastError());
        }
        break;
      }
      if (records != nullptr) ::DnsRecordListFree(records, DnsFreeRecordList);
      return;
    }
    observation->timed_out = ::GetTickCount64() >= deadline;
  };
  query();
  if (socket != INVALID_SOCKET) ::closesocket(socket);
  ::WSACleanup();
  return Interrupted(interrupted) ? std::wstring{} : result;
}

using ProbeStage = EgressProbeStage;

const char* ObservedFailure(DWORD error, ProbeStage stage) {
  switch (error) {
    case ERROR_WINHTTP_NAME_NOT_RESOLVED:
      return "core_egress_dns_failed";
    case ERROR_WINHTTP_CANNOT_CONNECT:
      return "core_egress_connect_failed";
    case ERROR_WINHTTP_SECURE_FAILURE:
    case ERROR_WINHTTP_CLIENT_AUTH_CERT_NEEDED:
      return "core_egress_tls_failed";
    case ERROR_WINHTTP_TIMEOUT:
      if (stage == ProbeStage::kTls) return "core_egress_tls_timeout";
      if (stage == ProbeStage::kResponse) return "core_egress_response_timeout";
      return "core_egress_timeout";
    default:
      return "core_egress_probe_failed";
  }
}

// WinHTTP can call back after CloseHandle returns. The request owns one
// reference until HANDLE_CLOSING; the runtime owns the other while waiting.
class Completion {
 public:
  explicit Completion(bool secure)
      : ready(::CreateEventW(nullptr, FALSE, FALSE, nullptr)), secure_(secure) {}
  void Retain() { references.fetch_add(1); }
  void Release() {
    if (references.fetch_sub(1) == 1) delete this;
  }

  bool Wait(DWORD expected, const CheckInterruption& interrupted) {
    while (!Interrupted(interrupted)) {
      const auto wait = ::WaitForSingleObject(ready, 50);
      if (wait == WAIT_OBJECT_0) return status.load() == expected;
      if (wait != WAIT_TIMEOUT) {
        if (wait == WAIT_FAILED) wait_error.store(::GetLastError());
        return false;
      }
    }
    return false;
  }

  static void CALLBACK Callback(HINTERNET, DWORD_PTR context, DWORD status,
                                void* information, DWORD information_size) {
    auto* completion = reinterpret_cast<Completion*>(context);
    if (completion == nullptr) return;
    if (status == WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING) {
      completion->Release();
    } else if (status == WINHTTP_CALLBACK_STATUS_CONNECTING_TO_SERVER) {
      completion->stage.store(ProbeStage::kConnect);
    } else if (status == WINHTTP_CALLBACK_STATUS_CONNECTED_TO_SERVER) {
      completion->stage.store(completion->secure_ ? ProbeStage::kTls
                                                 : ProbeStage::kConnect);
    } else if (status == WINHTTP_CALLBACK_STATUS_SENDING_REQUEST) {
      // With no proxy and no request body, TLS has completed by this point.
      completion->stage.store(ProbeStage::kSending);
    } else if (status == WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE ||
               status == WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE ||
               status == WINHTTP_CALLBACK_STATUS_REQUEST_ERROR) {
      if (status == WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE) {
        completion->stage.store(ProbeStage::kResponse);
      }
      if (status == WINHTTP_CALLBACK_STATUS_REQUEST_ERROR &&
          information != nullptr && information_size == sizeof(WINHTTP_ASYNC_RESULT)) {
        completion->error.store(
            static_cast<WINHTTP_ASYNC_RESULT*>(information)->dwError);
      }
      completion->status.store(status);
      ::SetEvent(completion->ready);
    }
  }

  HANDLE ready;
  std::atomic<DWORD> error{ERROR_SUCCESS};
  std::atomic<DWORD> wait_error{ERROR_SUCCESS};
  std::atomic<ProbeStage> stage{ProbeStage::kConnect};

 private:
  ~Completion() { if (ready != nullptr) ::CloseHandle(ready); }
  std::atomic<unsigned> references{1};
  std::atomic<DWORD> status{0};
  bool secure_;
};

class AuthenticatedEgressProbe final : public RuntimeEgressProbe {
 public:
  AuthenticatedEgressProbe(const wchar_t* host, INTERNET_PORT port, bool secure,
                           bool tun_dns, ServiceEventSink* events)
      : host_(host), port_(port), secure_(secure), tun_dns_(tun_dns), events_(events) {}

  std::string Verify(const CheckInterruption& interrupted) override {
    std::string failure = "core_egress_probe_failed";
    for (int attempt = 0; attempt < 3 && !Interrupted(interrupted); ++attempt) {
      failure = ProbeOnce(interrupted);
      if (failure.empty() && !Interrupted(interrupted)) return "";
      if (attempt < 2) {
        const auto started = ::GetTickCount64();
        const auto until = started + (attempt == 0 ? 900 : 1500);
        while (::GetTickCount64() < until && !Interrupted(interrupted)) {
          ::Sleep(25);
        }
        if (Interrupted(interrupted)) {
          ProbeObservation observation;
          observation.stage = EgressProbeStage::kRetryWait;
          RecordObservation(observation, started, false, interrupted);
        }
      }
    }
    return Interrupted(interrupted) ? "core_egress_probe_failed" : failure;
  }

 private:
  void RecordObservation(const ProbeObservation& observation, ULONGLONG started,
                         bool succeeded, const CheckInterruption& interrupted) {
    if (events_ == nullptr) return;
    const auto interruption = interrupted ? interrupted() : OperationInterruption::kNone;
    auto outcome = succeeded ? EgressProbeOutcome::kSucceeded
        : observation.timed_out ? EgressProbeOutcome::kTimeout : EgressProbeOutcome::kFailed;
    if (interruption == OperationInterruption::kCancelled) {
      outcome = EgressProbeOutcome::kCancelled;
    } else if (interruption == OperationInterruption::kDeadlineExceeded) {
      outcome = EgressProbeOutcome::kDeadline;
    }
    events_->RecordEgressProbeObservation(observation.stage, outcome,
        observation.domain, observation.error, ::GetTickCount64() - started);
  }

  std::string ProbeOnce(const CheckInterruption& interrupted) {
    auto started = ::GetTickCount64();
    ProbeObservation observation;
    std::wstring numeric;
    if (tun_dns_) {
      TunDnsEndpoint endpoint;
      if (!FindTunDns(&endpoint, &observation) ||
          (numeric = QueryProbeAddress(endpoint, interrupted, &observation)).empty()) {
        RecordObservation(observation, started, false, interrupted);
        return "core_egress_dns_failed";
      }
      RecordObservation(observation, started, true, interrupted);
      observation = {};
      started = ::GetTickCount64();
    }
    observation.stage = EgressProbeStage::kHttpSetup;
    const HINTERNET session = ::WinHttpOpen(
        L"POKROVService/1.2", WINHTTP_ACCESS_TYPE_NO_PROXY,
        WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, WINHTTP_FLAG_ASYNC);
    if (session == nullptr) {
      observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
      RecordObservation(observation, started, false, interrupted);
      return "core_egress_probe_failed";
    }
    ::WinHttpSetTimeouts(session, 3000, 3000, 3000, 6000);
    const HINTERNET connection = ::WinHttpConnect(session, host_, port_, 0);
    if (connection == nullptr) {
      observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
    }
    const HINTERNET request = connection == nullptr ? nullptr :
        ::WinHttpOpenRequest(connection, L"GET",
            L"/api/public/authenticated-egress-probe", nullptr,
            WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
            WINHTTP_FLAG_REFRESH | (secure_ ? WINHTTP_FLAG_SECURE : 0));
    if (connection != nullptr && request == nullptr) {
      observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
    }
    auto* completion = new Completion(secure_);
    if (completion->ready == nullptr) {
      observation.Error(EgressErrorDomain::kWin32, ::GetLastError());
    }
    DWORD_PTR context = reinterpret_cast<DWORD_PTR>(completion);
    bool callback_installed = false;
    if (request != nullptr && completion->ready != nullptr) {
      const bool options_set =
          (!tun_dns_ || ::WinHttpSetOption(request, WINHTTP_OPTION_RESOLUTION_HOSTNAME,
              numeric.data(), static_cast<DWORD>((numeric.size() + 1) * sizeof(wchar_t)))) &&
          ::WinHttpSetOption(request, WINHTTP_OPTION_CONTEXT_VALUE,
                             &context, sizeof(context));
      if (options_set) {
        completion->Retain();
        callback_installed = ::WinHttpSetStatusCallback(
            request, Completion::Callback,
            WINHTTP_CALLBACK_FLAG_ALL_COMPLETIONS | WINHTTP_CALLBACK_FLAG_HANDLES |
                WINHTTP_CALLBACK_FLAG_CONNECT_TO_SERVER | WINHTTP_CALLBACK_FLAG_SEND_REQUEST,
            0) != WINHTTP_INVALID_STATUS_CALLBACK;
        if (!callback_installed) {
          observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
          completion->Release();
        }
      } else {
        observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
      }
    }
    bool valid = false;
    DWORD error = ERROR_SUCCESS;
    if (callback_installed && !Interrupted(interrupted)) {
      observation.stage = EgressProbeStage::kConnect;
      if (!::WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS,
                               0, WINHTTP_NO_REQUEST_DATA, 0, 0, context)) {
        error = ::GetLastError();
      } else if (completion->Wait(WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE, interrupted) &&
                 !Interrupted(interrupted)) {
        if (!::WinHttpReceiveResponse(request, nullptr)) {
          error = ::GetLastError();
        } else {
          valid = completion->Wait(WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE, interrupted) &&
                  !Interrupted(interrupted);
        }
      }
    }
    if (error == ERROR_SUCCESS) error = completion->error.load();
    if (observation.stage == EgressProbeStage::kConnect) {
      observation.stage = completion->stage.load();
    }
    if (error != ERROR_SUCCESS) {
      observation.Error(EgressErrorDomain::kWinHttp, error);
    } else if (completion->wait_error.load() != ERROR_SUCCESS) {
      observation.Error(EgressErrorDomain::kWin32, completion->wait_error.load());
    }
    const auto failure = ObservedFailure(error, completion->stage.load());
    DWORD status = 0;
    DWORD status_size = sizeof(status);
    if (valid) {
      observation.stage = EgressProbeStage::kProof;
      const bool status_read = ::WinHttpQueryHeaders(request,
          WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
          WINHTTP_HEADER_NAME_BY_INDEX, &status, &status_size,
          WINHTTP_NO_HEADER_INDEX) != FALSE;
      valid = status_read && status == HTTP_STATUS_NO_CONTENT;
      if (!status_read) observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
      else if (!valid) observation.Error(EgressErrorDomain::kHttpStatus, status);
    }
    std::array<wchar_t, 64> proof{};
    DWORD proof_size = static_cast<DWORD>(proof.size() * sizeof(wchar_t));
    if (valid) {
      const bool proof_read = ::WinHttpQueryHeaders(request, WINHTTP_QUERY_CUSTOM,
          L"x-pokrov-egress-probe", proof.data(), &proof_size,
          WINHTTP_NO_HEADER_INDEX) != FALSE;
      valid = proof_read &&
          std::wstring(proof.data()) == L"pokrov-authenticated-egress-v1";
      if (!proof_read) observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
    }
    RecordObservation(observation, started, valid, interrupted);
    // All request API calls have returned. Closing an async request cancels
    // pending I/O; no other thread calls WinHTTP with this request handle.
    if (request != nullptr) ::WinHttpCloseHandle(request);
    completion->Release();
    if (connection != nullptr) ::WinHttpCloseHandle(connection);
    ::WinHttpCloseHandle(session);
    return valid && !Interrupted(interrupted) ? "" : failure;
  }

  const wchar_t* host_;
  INTERNET_PORT port_;
  bool secure_;
  bool tun_dns_;
  ServiceEventSink* events_;
};

}  // namespace

std::unique_ptr<RuntimeEgressProbe> CreateAuthenticatedEgressProbe(ServiceEventSink* events) {
  return std::make_unique<AuthenticatedEgressProbe>(
      kProbeHostname, static_cast<INTERNET_PORT>(INTERNET_DEFAULT_HTTPS_PORT), true, true, events);
}

#ifdef _DEBUG
std::unique_ptr<RuntimeEgressProbe> CreateLoopbackEgressProbeForTest(
    std::uint16_t port, bool secure, ServiceEventSink* events) {
  return std::make_unique<AuthenticatedEgressProbe>(L"127.0.0.1", port, secure, false, events);
}

std::wstring QueryLoopbackProbeAddressForTest(std::uint16_t port,
                                            const CheckInterruption& interrupted) {
  TunDnsEndpoint endpoint;
  endpoint.local.sin_family = AF_INET;
  endpoint.local.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  endpoint.dns = endpoint.local;
  endpoint.dns.sin_port = htons(port);
  // Resolve the loopback index without relying on a machine-specific number.
  MIB_IPFORWARD_ROW2 route{};
  SOCKADDR_INET destination{};
  destination.Ipv4 = endpoint.dns;
  SOCKADDR_INET source{};
  if (::GetBestRoute2(nullptr, 0, nullptr, &destination, 0, &route, &source) != NO_ERROR) return {};
  endpoint.interface_index = route.InterfaceIndex;
  ProbeObservation observation;
  return QueryProbeAddress(endpoint, interrupted, &observation);
}
#endif

}  // namespace pokrov::service
