#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <bcrypt.h>
#include <iphlpapi.h>
#include <windns.h>
#include <winhttp.h>

#include "service_runtime.h"

#include <algorithm>
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

struct ProbeTarget {
  const wchar_t* hostname;
  const wchar_t* proof_path;
  const wchar_t* data_path;
};

constexpr ProbeTarget kProbeTargets[] = {
    {kProbeHostname, L"/api/public/authenticated-egress-probe", L"/api/public/egress-probe-64k"},
    {L"pokrov.space", L"/.well-known/pokrov/egress-probe", L"/.well-known/pokrov/egress-probe-64k.bin"},
};

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

bool SameSocketAddress(const SOCKADDR_STORAGE& left, const SOCKADDR_STORAGE& right) {
  if (left.ss_family != right.ss_family) return false;
  if (left.ss_family == AF_INET) {
    const auto& a = reinterpret_cast<const sockaddr_in&>(left);
    const auto& b = reinterpret_cast<const sockaddr_in&>(right);
    return a.sin_addr.s_addr == b.sin_addr.s_addr && a.sin_port == b.sin_port;
  }
  if (left.ss_family == AF_INET6) {
    const auto& a = reinterpret_cast<const sockaddr_in6&>(left);
    const auto& b = reinterpret_cast<const sockaddr_in6&>(right);
    return IN6_ADDR_EQUAL(&a.sin6_addr, &b.sin6_addr) &&
        a.sin6_port == b.sin6_port && a.sin6_scope_id == b.sin6_scope_id;
  }
  return false;
}

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
                              const wchar_t* hostname,
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
            &request_size, hostname, DNS_TYPE_A, transaction, TRUE)) {
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
            record->pName == nullptr || !::DnsNameCompare_W(record->pName, hostname)) continue;
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
               status == WINHTTP_CALLBACK_STATUS_READ_COMPLETE ||
               status == WINHTTP_CALLBACK_STATUS_REQUEST_ERROR) {
      if (status == WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE) {
        completion->stage.store(ProbeStage::kResponse);
      }
      if (status == WINHTTP_CALLBACK_STATUS_REQUEST_ERROR &&
          information != nullptr && information_size == sizeof(WINHTTP_ASYNC_RESULT)) {
        completion->error.store(
            static_cast<WINHTTP_ASYNC_RESULT*>(information)->dwError);
      }
      if (status == WINHTTP_CALLBACK_STATUS_READ_COMPLETE) {
        completion->read_size.store(information_size);
      }
      completion->status.store(status);
      ::SetEvent(completion->ready);
    }
  }

  HANDLE ready;
  std::atomic<DWORD> error{ERROR_SUCCESS};
  std::atomic<DWORD> wait_error{ERROR_SUCCESS};
  std::atomic<ProbeStage> stage{ProbeStage::kConnect};
  // WinHTTP may still use this buffer after cancellation. The request keeps
  // Completion alive until its final HANDLE_CLOSING callback.
  std::array<unsigned char, 4096> read_buffer{};
  std::atomic<DWORD> read_size{0};

 private:
  ~Completion() { if (ready != nullptr) ::CloseHandle(ready); }
  std::atomic<unsigned> references{1};
  std::atomic<DWORD> status{0};
  bool secure_;
};

class AuthenticatedEgressProbe final : public RuntimeEgressProbe {
 public:
  AuthenticatedEgressProbe(const ProbeTarget* targets, std::size_t target_count,
                           INTERNET_PORT port, bool secure,
                           bool tun_dns, ServiceEventSink* events)
      : targets_(targets), target_count_(target_count), port_(port), secure_(secure),
        tun_dns_(tun_dns), events_(events) {}

  std::string Verify(const CheckInterruption& interrupted, bool periodic,
                     std::uint64_t deadline_tick) override {
    last_observation_.reset();
    const CheckInterruption owner = [&] {
      const auto reason = interrupted ? interrupted() : OperationInterruption::kNone;
      if (reason != OperationInterruption::kNone) return reason;
      return periodic && deadline_tick != 0 && ::GetTickCount64() >= deadline_tick
          ? OperationInterruption::kDeadlineExceeded : OperationInterruption::kNone;
    };
    std::string failure = "core_egress_probe_failed";
    for (int attempt = 0; attempt < 3 && !Interrupted(owner); ++attempt) {
      std::uint64_t target_deadline = deadline_tick;
      if (periodic && deadline_tick != 0 && attempt == 0 && target_count_ > 1) {
        const auto now = ::GetTickCount64();
        const auto remaining = deadline_tick > now ? deadline_tick - now : 0;
        // Keep the existing first retry wait inside the owner's three seconds.
        const auto available = remaining > 900 ? remaining - 900 : 0;
        target_deadline = now + available * 3 / 4;
      }
      const CheckInterruption target_check = [&, target_deadline] {
        const auto reason = owner();
        if (reason != OperationInterruption::kNone) return reason;
        return periodic && target_deadline != 0 && ::GetTickCount64() >= target_deadline
            ? OperationInterruption::kDeadlineExceeded : OperationInterruption::kNone;
      };
      const auto target_index = (std::min)(static_cast<std::size_t>(attempt), target_count_ - 1);
      failure = ProbeOnce(targets_[target_index], periodic, target_check);
      if (failure.empty() && !Interrupted(owner)) return "";
      if (attempt < 2) {
        const auto started = ::GetTickCount64();
        const auto until = started + (attempt == 0 ? 900 : 1500);
        while (::GetTickCount64() < until && !Interrupted(owner)) {
          ::Sleep(25);
        }
        if (Interrupted(owner)) {
          ProbeObservation observation;
          observation.stage = EgressProbeStage::kRetryWait;
          RecordObservation(observation, started, false, owner);
        }
      }
    }
    return Interrupted(owner) ? "core_egress_probe_failed" : failure;
  }

  std::optional<EgressProbeObservation> LastObservation() const override {
    return last_observation_;
  }

 private:
  void RecordObservation(const ProbeObservation& observation, ULONGLONG started,
                         bool succeeded, const CheckInterruption& interrupted) {
    const auto interruption = interrupted ? interrupted() : OperationInterruption::kNone;
    auto outcome = succeeded ? EgressProbeOutcome::kSucceeded
        : observation.timed_out ? EgressProbeOutcome::kTimeout : EgressProbeOutcome::kFailed;
    if (interruption == OperationInterruption::kCancelled) {
      outcome = EgressProbeOutcome::kCancelled;
    } else if (interruption == OperationInterruption::kDeadlineExceeded) {
      outcome = EgressProbeOutcome::kDeadline;
    }
    last_observation_ = EgressProbeObservation{observation.stage, outcome,
        observation.domain, observation.error, ::GetTickCount64() - started};
    if (events_ != nullptr) {
      events_->RecordEgressProbeObservation(observation.stage, outcome,
          observation.domain, observation.error, last_observation_->elapsed_ms);
    }
  }

  std::string ProbeOnce(const ProbeTarget& target, bool periodic,
                        const CheckInterruption& interrupted) {
    auto started = ::GetTickCount64();
    ProbeObservation observation;
    std::wstring numeric;
    if (tun_dns_) {
      TunDnsEndpoint endpoint;
      if (!FindTunDns(&endpoint, &observation) ||
          (numeric = QueryProbeAddress(endpoint, target.hostname, interrupted,
                                       &observation))
              .empty()) {
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
    BOOL disable_global_pooling = TRUE;
    if (!::WinHttpSetOption(session, WINHTTP_OPTION_DISABLE_GLOBAL_POOLING,
                            &disable_global_pooling,
                            sizeof(disable_global_pooling))) {
      observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
      RecordObservation(observation, started, false, interrupted);
      ::WinHttpCloseHandle(session);
      return "core_egress_probe_failed";
    }
    const HINTERNET connection =
        ::WinHttpConnect(session, target.hostname, port_, 0);
    if (connection == nullptr) {
      observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
    }
    bool valid = false;
    std::string failure = "core_egress_probe_failed";
    WINHTTP_CONNECTION_INFO proof_connection{};
    for (int proof_request = 0; proof_request < (periodic ? 1 : 2);
         ++proof_request) {
      const bool data = proof_request == 1;
      const HINTERNET request =
          connection == nullptr
              ? nullptr
              : ::WinHttpOpenRequest(
                    connection, L"GET",
                    data ? target.data_path : target.proof_path, nullptr,
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
        DWORD disabled = WINHTTP_DISABLE_REDIRECTS;
        const bool options_set =
            ::WinHttpSetOption(request, WINHTTP_OPTION_DISABLE_FEATURE,
                               &disabled, sizeof(disabled)) &&
            (!tun_dns_ ||
             ::WinHttpSetOption(
                 request, WINHTTP_OPTION_RESOLUTION_HOSTNAME, numeric.data(),
                 static_cast<DWORD>((numeric.size() + 1) * sizeof(wchar_t)))) &&
            ::WinHttpSetOption(request, WINHTTP_OPTION_CONTEXT_VALUE, &context,
                               sizeof(context));
        if (options_set) {
          completion->Retain();
          callback_installed = ::WinHttpSetStatusCallback(
                                   request, Completion::Callback,
                                   WINHTTP_CALLBACK_FLAG_ALL_COMPLETIONS |
                                       WINHTTP_CALLBACK_FLAG_HANDLES |
                                       WINHTTP_CALLBACK_FLAG_CONNECT_TO_SERVER |
                                       WINHTTP_CALLBACK_FLAG_SEND_REQUEST,
                                   0) != WINHTTP_INVALID_STATUS_CALLBACK;
          if (!callback_installed) {
            observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
            completion->Release();
          }
        } else {
          observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
        }
      }
      valid = false;
      DWORD error = ERROR_SUCCESS;
      if (callback_installed && !Interrupted(interrupted)) {
        observation.stage = EgressProbeStage::kConnect;
        if (!::WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
                                  WINHTTP_NO_REQUEST_DATA, 0, 0, context)) {
          error = ::GetLastError();
        } else if (completion->Wait(
                       WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE,
                       interrupted) &&
                   !Interrupted(interrupted)) {
          if (!::WinHttpReceiveResponse(request, nullptr)) {
            error = ::GetLastError();
          } else {
            valid = completion->Wait(WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE,
                                     interrupted) &&
                    !Interrupted(interrupted);
          }
        }
      }
      if (error == ERROR_SUCCESS)
        error = completion->error.load();
      if (observation.stage == EgressProbeStage::kConnect) {
        observation.stage = completion->stage.load();
      }
      if (error != ERROR_SUCCESS) {
        observation.Error(EgressErrorDomain::kWinHttp, error);
      } else if (completion->wait_error.load() != ERROR_SUCCESS) {
        observation.Error(EgressErrorDomain::kWin32,
                          completion->wait_error.load());
      }
      DWORD status = 0;
      DWORD status_size = sizeof(status);
      if (valid) {
        observation.stage = EgressProbeStage::kProof;
        const bool status_read =
            ::WinHttpQueryHeaders(
                request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                WINHTTP_HEADER_NAME_BY_INDEX, &status, &status_size,
                WINHTTP_NO_HEADER_INDEX) != FALSE;
        valid = status_read &&
                status == static_cast<DWORD>(data ? HTTP_STATUS_OK : HTTP_STATUS_NO_CONTENT);
        if (!status_read)
          observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
        else if (!valid)
          observation.Error(EgressErrorDomain::kHttpStatus, status);
      }
      std::array<wchar_t, 64> proof{};
      DWORD proof_size = static_cast<DWORD>(proof.size() * sizeof(wchar_t));
      if (valid) {
        const bool proof_read =
            ::WinHttpQueryHeaders(
                request, WINHTTP_QUERY_CUSTOM, L"x-pokrov-egress-probe",
                proof.data(), &proof_size, WINHTTP_NO_HEADER_INDEX) != FALSE;
        valid = proof_read &&
                std::wstring(proof.data()) == L"pokrov-authenticated-egress-v1";
        if (!proof_read)
          observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
      }
      if (valid && !periodic) {
        WINHTTP_CONNECTION_INFO current{};
        current.cbSize = sizeof(current);
        DWORD connection_size = sizeof(current);
        const bool connection_read =
            ::WinHttpQueryOption(request, WINHTTP_OPTION_CONNECTION_INFO,
                                 &current, &connection_size) != FALSE;
        valid = connection_read &&
                (!data || (SameSocketAddress(proof_connection.LocalAddress,
                                             current.LocalAddress) &&
                           SameSocketAddress(proof_connection.RemoteAddress,
                                             current.RemoteAddress)));
        if (!connection_read)
          observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
        if (valid && !data)
          proof_connection = current;
      }
      if (valid && data) {
        DWORD length = 0;
        DWORD length_size = sizeof(length);
        const bool length_read =
            ::WinHttpQueryHeaders(
                request,
                WINHTTP_QUERY_CONTENT_LENGTH | WINHTTP_QUERY_FLAG_NUMBER,
                WINHTTP_HEADER_NAME_BY_INDEX, &length, &length_size,
                WINHTTP_NO_HEADER_INDEX) != FALSE;
        valid = length_read && length == 65536;
        if (!length_read)
          observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
        if (valid) {
          std::array<wchar_t, 64> encoding{};
          DWORD encoding_size =
              static_cast<DWORD>(encoding.size() * sizeof(wchar_t));
          const bool encoded =
              ::WinHttpQueryHeaders(request, WINHTTP_QUERY_CONTENT_ENCODING,
                                    WINHTTP_HEADER_NAME_BY_INDEX,
                                    encoding.data(), &encoding_size,
                                    WINHTTP_NO_HEADER_INDEX) != FALSE;
          if (encoded)
            valid = encoding[0] == L'\0';
          else if (::GetLastError() != ERROR_WINHTTP_HEADER_NOT_FOUND) {
            observation.Error(EgressErrorDomain::kWinHttp, ::GetLastError());
            valid = false;
          }
        }
        std::uint64_t received = 0;
        if (valid)
          observation.stage = EgressProbeStage::kResponse;
        while (valid && !Interrupted(interrupted)) {
          completion->stage.store(EgressProbeStage::kResponse);
          completion->read_size.store(0);
          if (!::WinHttpReadData(
                  request, completion->read_buffer.data(),
                  static_cast<DWORD>(completion->read_buffer.size()),
                  nullptr)) {
            error = ::GetLastError();
            valid = false;
            break;
          }
          if (!completion->Wait(WINHTTP_CALLBACK_STATUS_READ_COMPLETE,
                                interrupted)) {
            valid = false;
            break;
          }
          const auto bytes = completion->read_size.load();
          if (bytes == 0) {
            valid = received == 65536;
            break;
          }
          received += bytes;
          valid = received <= 65536;
        }
        if (Interrupted(interrupted))
          valid = false;
        if (valid)
          observation.stage = EgressProbeStage::kProof;
      }
      if (error == ERROR_SUCCESS)
        error = completion->error.load();
      if (error != ERROR_SUCCESS)
        observation.Error(EgressErrorDomain::kWinHttp, error);
      else if (completion->wait_error.load() != ERROR_SUCCESS) {
        observation.Error(EgressErrorDomain::kWin32,
                          completion->wait_error.load());
      }
      failure = ObservedFailure(error, completion->stage.load());
      RecordObservation(observation, started, valid, interrupted);
      // All request API calls have returned. Closing an async request cancels
      // pending I/O; no other thread calls WinHTTP with this request handle.
      if (request != nullptr)
        ::WinHttpCloseHandle(request);
      completion->Release();
      if (!valid || Interrupted(interrupted))
        break;
    }
    if (connection != nullptr)
      ::WinHttpCloseHandle(connection);
    ::WinHttpCloseHandle(session);
    return valid && !Interrupted(interrupted) ? "" : failure;
  }

  const ProbeTarget* targets_;
  std::size_t target_count_;
  INTERNET_PORT port_;
  bool secure_;
  bool tun_dns_;
  ServiceEventSink* events_;
  std::optional<EgressProbeObservation> last_observation_;
};

}  // namespace

std::unique_ptr<RuntimeEgressProbe> CreateAuthenticatedEgressProbe(ServiceEventSink* events) {
  return std::make_unique<AuthenticatedEgressProbe>(
      kProbeTargets, std::size(kProbeTargets),
      static_cast<INTERNET_PORT>(INTERNET_DEFAULT_HTTPS_PORT), true, true,
      events);
}

#ifdef _DEBUG
std::unique_ptr<RuntimeEgressProbe> CreateLoopbackEgressProbeForTest(
    std::uint16_t port, bool secure, ServiceEventSink* events, bool reserve) {
  static constexpr ProbeTarget targets[] = {
      {L"127.0.0.1", kProbeTargets[0].proof_path, kProbeTargets[0].data_path},
      {L"127.0.0.1", kProbeTargets[1].proof_path, kProbeTargets[1].data_path},
  };
  return std::make_unique<AuthenticatedEgressProbe>(
      targets, reserve ? 2 : 1, port, secure, false, events);
}

std::wstring QueryLoopbackProbeAddressForTest(std::uint16_t port,
                                            const CheckInterruption& interrupted,
                                            bool reserve) {
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
  return QueryProbeAddress(endpoint, kProbeTargets[reserve ? 1 : 0].hostname,
      interrupted, &observation);
}
#endif

}  // namespace pokrov::service
