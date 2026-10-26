#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <bcrypt.h>
#include <iphlpapi.h>
#include <windns.h>
#define SECURITY_WIN32
#include <security.h>
#include <schannel.h>

#include "service_runtime.h"

#include <algorithm>
#include <array>
#include <charconv>
#include <cstring>
#include <string_view>
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

constexpr ProbeTarget kApiReserve = {
    L"app.pokrov.space", L"/api/public/authenticated-egress-probe", L"/api/public/egress-probe-64k"};

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
  std::optional<EgressProbeTarget> target;
  std::optional<std::uint32_t> owner_remaining_ms_at_entry;
  std::optional<bool> dns_a_accepted;
  std::optional<bool> http_local_is_tun;

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
                              const wchar_t* hostname,
                              const CheckInterruption& interrupted,
                              ProbeObservation* observation) {
  observation->stage = EgressProbeStage::kDnsSetup;
  observation->dns_a_accepted = false;
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
          observation->dns_a_accepted = true;
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

// Like the physical-interface probe, own one nonblocking socket and Schannel
// context. No WinHTTP pool or OS-version-dependent resolution override is used.
class EgressConnection {
 public:
  EgressConnection(ProbeObservation& observation, const CheckInterruption& interrupted)
      : observation_(observation), interrupted_(interrupted) {
    SecInvalidateHandle(&credentials_);
    SecInvalidateHandle(&context_);
    WSADATA data{};
    const auto error = ::WSAStartup(MAKEWORD(2, 2), &data);
    winsock_ready_ = error == 0;
    if (error != 0) observation_.Error(EgressErrorDomain::kWinsock, error);
  }
  ~EgressConnection() {
    if (socket_ != INVALID_SOCKET) ::closesocket(socket_);
    if (SecIsValidHandle(&context_)) ::DeleteSecurityContext(&context_);
    if (SecIsValidHandle(&credentials_)) ::FreeCredentialsHandle(&credentials_);
    if (winsock_ready_) ::WSACleanup();
  }

  bool Connect(const std::wstring& numeric, std::uint16_t port,
               const std::optional<std::uint32_t>& expected_tun_ipv4) {
    if (!winsock_ready_ || Interrupted(interrupted_)) return false;
    socket_ = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (socket_ == INVALID_SOCKET) return SocketError();
    u_long nonblocking = 1;
    if (::ioctlsocket(socket_, FIONBIO, &nonblocking)) return SocketError();
    sockaddr_in remote{};
    remote.sin_family = AF_INET;
    remote.sin_port = htons(port);
    if (::InetPtonW(AF_INET, numeric.c_str(), &remote.sin_addr) != 1) {
      observation_.Error(EgressErrorDomain::kWin32, ERROR_INVALID_ADDRESS);
      return false;
    }
    observation_.stage = EgressProbeStage::kConnect;
    if (::connect(socket_, reinterpret_cast<const sockaddr*>(&remote), sizeof(remote))) {
      const auto error = ::WSAGetLastError();
      if (error != WSAEWOULDBLOCK) return SocketError(error);
      if (!Wait(true, ::GetTickCount64() + 3000)) return false;
      int pending_error = 0, length = sizeof(pending_error);
      if (::getsockopt(socket_, SOL_SOCKET, SO_ERROR,
              reinterpret_cast<char*>(&pending_error), &length)) return SocketError();
      if (pending_error != 0) return SocketError(pending_error);
    }
    sockaddr_in local{};
    int size = sizeof(local);
    if (expected_tun_ipv4) {
      if (::getsockname(socket_, reinterpret_cast<sockaddr*>(&local), &size)) return SocketError();
      observation_.http_local_is_tun = local.sin_family == AF_INET &&
          local.sin_addr.s_addr == *expected_tun_ipv4;
      // HTTP must exercise the OS route, not force a broken route through TUN.
      if (!*observation_.http_local_is_tun) {
        observation_.Error(EgressErrorDomain::kWin32, ERROR_NETWORK_UNREACHABLE);
        return false;
      }
    }
    return !Interrupted(interrupted_);
  }

  bool Handshake(const std::wstring& host) {
    observation_.stage = EgressProbeStage::kTls;
    SCHANNEL_CRED credentials{};
    credentials.dwVersion = SCHANNEL_CRED_VERSION;
    credentials.grbitEnabledProtocols = SP_PROT_TLS1_2_CLIENT;
    credentials.dwFlags = SCH_CRED_AUTO_CRED_VALIDATION | SCH_CRED_NO_DEFAULT_CREDS |
        SCH_USE_STRONG_CRYPTO | SCH_CRED_CACHE_ONLY_URL_RETRIEVAL;
    auto status = ::AcquireCredentialsHandleW(nullptr, const_cast<wchar_t*>(UNISP_NAME_W),
        SECPKG_CRED_OUTBOUND, nullptr, &credentials, nullptr, nullptr, &credentials_, nullptr);
    if (status != SEC_E_OK) return TlsError(status);
    constexpr ULONG flags = ISC_REQ_SEQUENCE_DETECT | ISC_REQ_REPLAY_DETECT |
        ISC_REQ_CONFIDENTIALITY | ISC_REQ_ALLOCATE_MEMORY | ISC_REQ_STREAM |
        ISC_REQ_USE_SUPPLIED_CREDS;
    const auto deadline = ::GetTickCount64() + 3000;
    bool first = true;
    while (Current(deadline)) {
      SecBuffer inputs[2]{{static_cast<ULONG>(encrypted_.size()), SECBUFFER_TOKEN, encrypted_.data()},
                          {0, SECBUFFER_EMPTY, nullptr}};
      SecBufferDesc input{SECBUFFER_VERSION, 2, inputs};
      SecBuffer token{0, SECBUFFER_TOKEN, nullptr};
      SecBufferDesc output{SECBUFFER_VERSION, 1, &token};
      ULONG attributes = 0;
      // The DNS result controls only the TCP destination. The original owned
      // hostname remains the SNI and automatic certificate-name validation target.
      status = ::InitializeSecurityContextW(&credentials_, first ? nullptr : &context_,
          const_cast<wchar_t*>(host.c_str()), flags, 0, SECURITY_NATIVE_DREP,
          first ? nullptr : &input, 0, &context_, &output, &attributes, nullptr);
      first = false;
      bool sent = true;
      if (token.pvBuffer != nullptr) {
        if (status >= 0 && token.cbBuffer != 0)
          sent = SendBytes(token.pvBuffer, token.cbBuffer, deadline);
        ::FreeContextBuffer(token.pvBuffer);
      }
      if (!sent) return false;
      if (status != SEC_E_OK && status != SEC_I_CONTINUE_NEEDED && status != SEC_E_INCOMPLETE_MESSAGE)
        return TlsError(status);
      if (status != SEC_E_INCOMPLETE_MESSAGE &&
          !RetainExtra(inputs[1].BufferType == SECBUFFER_EXTRA ? inputs[1].cbBuffer : 0)) return false;
      if (status == SEC_E_OK) {
        status = ::QueryContextAttributesW(&context_, SECPKG_ATTR_STREAM_SIZES, &sizes_);
        secure_ = status == SEC_E_OK;
        return secure_ ? Current(deadline) : TlsError(status);
      }
      if ((status == SEC_E_INCOMPLETE_MESSAGE || encrypted_.empty()) &&
          !ReceiveBytes(deadline)) return false;
    }
    return false;
  }

  bool Write(const std::string& request) {
    observation_.stage = EgressProbeStage::kSending;
    const auto deadline = ::GetTickCount64() + 3000;
    if (!secure_) return SendBytes(request.data(), request.size(), deadline);
    if (request.size() > sizes_.cbMaximumMessage) return TlsError(SEC_E_BUFFER_TOO_SMALL);
    std::vector<char> bytes(sizes_.cbHeader + request.size() + sizes_.cbTrailer);
    std::memcpy(bytes.data() + sizes_.cbHeader, request.data(), request.size());
    SecBuffer buffers[4]{{sizes_.cbHeader, SECBUFFER_STREAM_HEADER, bytes.data()},
        {static_cast<ULONG>(request.size()), SECBUFFER_DATA, bytes.data() + sizes_.cbHeader},
        {sizes_.cbTrailer, SECBUFFER_STREAM_TRAILER, bytes.data() + sizes_.cbHeader + request.size()},
        {0, SECBUFFER_EMPTY, nullptr}};
    SecBufferDesc message{SECBUFFER_VERSION, 4, buffers};
    const auto status = ::EncryptMessage(&context_, 0, &message, 0);
    if (status != SEC_E_OK) return TlsError(status);
    for (unsigned int index = 0; index < 3; ++index)
      if (!SendBytes(buffers[index].pvBuffer, buffers[index].cbBuffer, deadline)) return false;
    return true;
  }

  bool Read(std::string* plain, ULONGLONG deadline) {
    while (Current(deadline)) {
      if (encrypted_.empty() && !ReceiveBytes(deadline)) return false;
      if (!secure_) {
        plain->append(encrypted_.data(), encrypted_.size());
        encrypted_.clear();
        return true;
      }
      SecBuffer buffers[4]{{static_cast<ULONG>(encrypted_.size()), SECBUFFER_DATA, encrypted_.data()},
          {0, SECBUFFER_EMPTY, nullptr}, {0, SECBUFFER_EMPTY, nullptr}, {0, SECBUFFER_EMPTY, nullptr}};
      SecBufferDesc message{SECBUFFER_VERSION, 4, buffers};
      const auto status = ::DecryptMessage(&context_, &message, 0, nullptr);
      if (status == SEC_E_INCOMPLETE_MESSAGE) {
        if (!ReceiveBytes(deadline)) return false;
        continue;
      }
      // No renegotiation, reconnect or replay may replace the proven TLS session.
      if (status != SEC_E_OK) return TlsError(status);
      ULONG extra = 0;
      const auto before = plain->size();
      for (const auto& buffer : buffers) {
        if (buffer.BufferType == SECBUFFER_DATA)
          plain->append(static_cast<const char*>(buffer.pvBuffer), buffer.cbBuffer);
        if (buffer.BufferType == SECBUFFER_EXTRA) extra = buffer.cbBuffer;
      }
      if (!RetainExtra(extra)) return false;
      if (plain->size() != before) return true;
    }
    return false;
  }

 private:
  bool Current(ULONGLONG deadline) {
    if (Interrupted(interrupted_)) return false;
    if (::GetTickCount64() < deadline) return true;
    observation_.timed_out = true;
    return SocketError(WSAETIMEDOUT);
  }
  bool SocketError(int error = ::WSAGetLastError()) {
    observation_.Error(EgressErrorDomain::kWinsock, static_cast<DWORD>(error));
    return false;
  }
  bool TlsError(SECURITY_STATUS error) {
    observation_.Error(EgressErrorDomain::kNtStatus, static_cast<DWORD>(error));
    return false;
  }
  bool Wait(bool write, ULONGLONG deadline) {
    while (Current(deadline)) {
      fd_set ready, failed;
      FD_ZERO(&ready); FD_SET(socket_, &ready);
      FD_ZERO(&failed); FD_SET(socket_, &failed);
      timeval timeout{0, 50000};
      const int status = ::select(0, write ? nullptr : &ready, write ? &ready : nullptr,
                                  write ? &failed : nullptr, &timeout);
      if (status > 0) return Current(deadline);
      if (status < 0) return SocketError();
    }
    return false;
  }
  bool SendBytes(const void* data, std::size_t size, ULONGLONG deadline) {
    const auto* bytes = static_cast<const char*>(data);
    while (size != 0) {
      if (!Wait(true, deadline)) return false;
      const int sent = ::send(socket_, bytes, static_cast<int>(size), 0);
      if (sent == SOCKET_ERROR && ::WSAGetLastError() == WSAEWOULDBLOCK) continue;
      if (sent <= 0) return SocketError();
      bytes += sent;
      size -= static_cast<std::size_t>(sent);
    }
    return true;
  }
  bool ReceiveBytes(ULONGLONG deadline) {
    while (Wait(false, deadline)) {
      std::array<char, 16384> bytes{};
      const int received = ::recv(socket_, bytes.data(), static_cast<int>(bytes.size()), 0);
      if (received == SOCKET_ERROR && ::WSAGetLastError() == WSAEWOULDBLOCK) continue;
      if (received <= 0) return SocketError(received == 0 ? WSAECONNRESET : ::WSAGetLastError());
      if (encrypted_.size() + static_cast<std::size_t>(received) > 65536)
        return TlsError(SEC_E_BUFFER_TOO_SMALL);
      encrypted_.insert(encrypted_.end(), bytes.data(), bytes.data() + received);
      return true;
    }
    return false;
  }
  bool RetainExtra(ULONG size) {
    if (size > encrypted_.size()) return TlsError(SEC_E_INVALID_TOKEN);
    encrypted_.erase(encrypted_.begin(), encrypted_.end() - size);
    return true;
  }

  ProbeObservation& observation_;
  const CheckInterruption& interrupted_;
  bool winsock_ready_ = false;
  bool secure_ = false;
  SOCKET socket_ = INVALID_SOCKET;
  CredHandle credentials_{};
  CtxtHandle context_{};
  SecPkgContext_StreamSizes sizes_{};
  std::vector<char> encrypted_;
};

std::string Ascii(const wchar_t* text) {
  std::string result;
  for (; *text != L'\0'; ++text) result += static_cast<char>(*text);
  return result;  // Only the fixed owned hostnames and paths reach this function.
}

std::string_view Trim(std::string_view value) {
  const auto first = value.find_first_not_of(" \t");
  if (first == std::string_view::npos) return {};
  return value.substr(first, value.find_last_not_of(" \t") - first + 1);
}

bool ReadProof(EgressConnection& connection, bool data, bool periodic,
               ProbeObservation& observation, const CheckInterruption& interrupted) {
  observation.stage = EgressProbeStage::kResponse;
  auto deadline = ::GetTickCount64() + 6000;
  std::string bytes;
  auto end = bytes.find("\r\n\r\n");
  while (end == std::string::npos) {
    if (bytes.size() >= 16384 || !connection.Read(&bytes, deadline)) return false;
    end = bytes.find("\r\n\r\n");
  }
  if (end + 4 > 16384) return false;
  observation.stage = EgressProbeStage::kProof;
  const std::string_view headers(bytes.data(), end + 2);
  const auto first_line = headers.find("\r\n");
  if (first_line < 12 || (headers.substr(0, 9) != "HTTP/1.1 " &&
                         headers.substr(0, 9) != "HTTP/1.0 ") ||
      (first_line > 12 && headers[12] != ' ')) return false;
  unsigned int status = 0;
  const auto parsed = std::from_chars(headers.data() + 9, headers.data() + 12, status);
  if (parsed.ec != std::errc{} || parsed.ptr != headers.data() + 12) return false;
  if (status != (data ? 200U : 204U)) {
    observation.Error(EgressErrorDomain::kHttpStatus, status);
    return false;
  }
  bool marker = false, length_present = false, close = false;
  std::uint32_t length = 0;
  for (auto offset = first_line + 2; offset < headers.size();) {
    const auto next = headers.find("\r\n", offset);
    if (next == std::string_view::npos) return false;
    const auto line = headers.substr(offset, next - offset);
    const auto colon = line.find(':');
    if (colon == std::string_view::npos || colon == 0) return false;
    std::string name(line.substr(0, colon));
    for (auto& character : name) {
      if (character >= 'A' && character <= 'Z') character += 'a' - 'A';
      else if (!((character >= 'a' && character <= 'z') ||
                 (character >= '0' && character <= '9') || character == '-')) return false;
    }
    const auto value = Trim(line.substr(colon + 1));
    if (name == "x-pokrov-egress-probe") {
      if (marker || value != "pokrov-authenticated-egress-v1") return false;
      marker = true;
    } else if (name == "content-length") {
      if (length_present || value.empty()) return false;
      const auto number = std::from_chars(value.data(), value.data() + value.size(), length);
      if (number.ec != std::errc{} || number.ptr != value.data() + value.size()) return false;
      length_present = true;
    } else if (name == "transfer-encoding" || (name == "content-encoding" && !value.empty())) {
      return false;
    } else if (name == "connection") {
      std::string lower(value);
      for (auto& character : lower)
        if (character >= 'A' && character <= 'Z') character += 'a' - 'A';
      close = lower.find("close") != std::string::npos;
    }
    offset = next + 2;
  }
  if (!marker || (data ? !length_present || length != 65536
                       : (length_present && length != 0) || (!periodic && close))) return false;
  bytes.erase(0, end + 4);
  if (!data) return bytes.empty() && !Interrupted(interrupted);
  observation.stage = EgressProbeStage::kResponse;
  std::size_t received = bytes.size();
  while (received < 65536 && !Interrupted(interrupted)) {
    bytes.clear();
    deadline = ::GetTickCount64() + 6000;
    if (!connection.Read(&bytes, deadline)) return false;
    received += bytes.size();
  }
  if (received != 65536 || Interrupted(interrupted)) return false;
  observation.stage = EgressProbeStage::kProof;
  return true;
}

const char* ObservedFailure(const ProbeObservation& observation) {
  if (observation.timed_out) {
    if (observation.stage == EgressProbeStage::kTls) return "core_egress_tls_timeout";
    if (observation.stage == EgressProbeStage::kResponse) return "core_egress_response_timeout";
    return "core_egress_timeout";
  }
  if (observation.stage == EgressProbeStage::kConnect) return "core_egress_connect_failed";
  if (observation.stage == EgressProbeStage::kTls) return "core_egress_tls_failed";
  return "core_egress_probe_failed";
}

class AuthenticatedEgressProbe final : public RuntimeEgressProbe {
 public:
  AuthenticatedEgressProbe(const ProbeTarget* targets, std::size_t target_count, const ProbeTarget& api_reserve,
                           std::uint16_t port, bool secure,
                           bool tun_dns, ServiceEventSink* events,
                           std::optional<std::uint32_t> loopback_tun_ipv4 = std::nullopt)
      : targets_(targets), target_count_(target_count), api_reserve_(api_reserve), port_(port), secure_(secure),
        tun_dns_(tun_dns), events_(events), loopback_tun_ipv4_(loopback_tun_ipv4) {}

  std::string Verify(const CheckInterruption& interrupted, bool periodic,
                     std::uint64_t deadline_tick, EgressProbeReserve reserve) override {
    last_observation_.reset();
    const auto target_count = reserve == EgressProbeReserve::kNone ? std::size_t{1} : target_count_;
    const CheckInterruption owner = [&] {
      const auto reason = interrupted ? interrupted() : OperationInterruption::kNone;
      if (reason != OperationInterruption::kNone) return reason;
      return periodic && deadline_tick != 0 && ::GetTickCount64() >= deadline_tick
          ? OperationInterruption::kDeadlineExceeded : OperationInterruption::kNone;
    };
    std::string failure = "core_egress_probe_failed";
    for (int attempt = 0; attempt < 3 && !Interrupted(owner); ++attempt) {
      std::uint64_t target_deadline = deadline_tick;
      if (periodic && deadline_tick != 0 && attempt == 0 && target_count > 1) {
        const auto now = ::GetTickCount64();
        const auto remaining = deadline_tick > now ? deadline_tick - now : 0;
        // Retain the existing bounded primary slice. The skipped cross-target
        // retry wait now remains available to the reserve.
        const auto available = remaining > 900 ? remaining - 900 : 0;
        target_deadline = now + available * 3 / 4;
      }
      const CheckInterruption target_check = [&, target_deadline] {
        const auto reason = owner();
        if (reason != OperationInterruption::kNone) return reason;
        return periodic && target_deadline != 0 && ::GetTickCount64() >= target_deadline
            ? OperationInterruption::kDeadlineExceeded : OperationInterruption::kNone;
      };
      const auto target_index = (std::min)(static_cast<std::size_t>(attempt), target_count - 1);
      const auto& target = target_index != 0 && reserve == EgressProbeReserve::kApi
          ? api_reserve_ : targets_[target_index];
      failure = ProbeOnce(target, periodic, target_check,
          target_index == 0 ? EgressProbeTarget::kOwnedApi : EgressProbeTarget::kOwnedReserve,
          deadline_tick);
      if (failure.empty() && !Interrupted(owner)) return "";
      // Periodic failover to a different target gets the remaining budget
      // immediately. Startup and same-target retries retain their backoff.
      if (attempt < 2 && (!periodic || target_index + 1 >= target_count)) {
        const auto started = ::GetTickCount64();
        const auto until = started + (attempt == 0 ? 900 : 1500);
        while (::GetTickCount64() < until && !Interrupted(owner)) {
          ::Sleep(25);
        }
        if (Interrupted(owner)) {
          const auto probe_observation = last_observation_;
          ProbeObservation observation;
          observation.stage = EgressProbeStage::kRetryWait;
          RecordObservation(observation, started, false, owner);
          // Retry waiting is lifecycle evidence, not a new network failure.
          // Keep its event, but expose the preceding failed IO in Snapshot.
          if (probe_observation &&
              probe_observation->outcome != EgressProbeOutcome::kSucceeded) {
            last_observation_ = probe_observation;
          }
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
    last_observation_->target = observation.target;
    last_observation_->owner_remaining_ms_at_entry = observation.owner_remaining_ms_at_entry;
    last_observation_->dns_a_accepted = observation.dns_a_accepted;
    last_observation_->http_local_is_tun = observation.http_local_is_tun;
    if (events_ != nullptr) {
      events_->RecordEgressProbeObservation(observation.stage, outcome,
          observation.domain, observation.error, last_observation_->elapsed_ms);
    }
  }

  std::string ProbeOnce(const ProbeTarget& target, bool periodic,
                        const CheckInterruption& interrupted,
                        EgressProbeTarget target_kind, std::uint64_t owner_deadline) {
    auto started = ::GetTickCount64();
    ProbeObservation observation;
    observation.target = target_kind;
    if (periodic && owner_deadline != 0) {
      observation.owner_remaining_ms_at_entry = static_cast<std::uint32_t>(
          (std::min)(owner_deadline > started ? owner_deadline - started : 0, std::uint64_t{3000}));
    }
    std::wstring numeric;
    auto expected_tun_ipv4 = loopback_tun_ipv4_;
    TunDnsEndpoint endpoint;
    if (tun_dns_) {
      if (!FindTunDns(&endpoint, &observation) ||
          (numeric = QueryProbeAddress(endpoint, target.hostname, interrupted,
                                       &observation))
              .empty()) {
        RecordObservation(observation, started, false, interrupted);
        return "core_egress_dns_failed";
      }
      expected_tun_ipv4 = endpoint.local.sin_addr.s_addr;
      RecordObservation(observation, started, true, interrupted);
      // Keep this target's entry budget and accepted DNS evidence for HTTP.
      observation.domain = EgressErrorDomain::kNone;
      observation.error = 0;
      observation.timed_out = false;
      started = ::GetTickCount64();
    }
    observation.stage = EgressProbeStage::kHttpSetup;
    EgressConnection connection(observation, interrupted);
    bool valid = connection.Connect(tun_dns_ ? numeric : target.hostname, port_,
                                    expected_tun_ipv4);
    if (valid && secure_) valid = connection.Handshake(target.hostname);
    if (!valid) {
      RecordObservation(observation, started, false, interrupted);
      return ObservedFailure(observation);
    }
    for (int request = 0; request < (periodic ? 1 : 2); ++request) {
      const bool data = request == 1;
      const std::string http = "GET " + Ascii(data ? target.data_path : target.proof_path) +
          " HTTP/1.1\r\nHost: " + Ascii(target.hostname) +
          "\r\nConnection: " + (data || periodic ? "close" : "keep-alive") + "\r\n\r\n";
      valid = connection.Write(http) && ReadProof(connection, data, periodic, observation, interrupted);
      RecordObservation(observation, started, valid, interrupted);
      if (!valid || Interrupted(interrupted)) return ObservedFailure(observation);
    }
    return "";
  }

  const ProbeTarget* targets_;
  std::size_t target_count_;
  const ProbeTarget& api_reserve_;
  std::uint16_t port_;
  bool secure_;
  bool tun_dns_;
  ServiceEventSink* events_;
  const std::optional<std::uint32_t> loopback_tun_ipv4_;
  std::optional<EgressProbeObservation> last_observation_;
};

}  // namespace

std::unique_ptr<RuntimeEgressProbe> CreateAuthenticatedEgressProbe(ServiceEventSink* events) {
  return std::make_unique<AuthenticatedEgressProbe>(
      kProbeTargets, std::size(kProbeTargets), kApiReserve,
      std::uint16_t{443}, true, true,
      events);
}

#ifdef _DEBUG
std::unique_ptr<RuntimeEgressProbe> CreateLoopbackEgressProbeForTest(
    std::uint16_t port, bool secure, ServiceEventSink* events, bool reserve,
    std::optional<std::uint32_t> expected_tun_ipv4) {
  static constexpr ProbeTarget targets[] = {
      {L"127.0.0.1", kProbeTargets[0].proof_path, kProbeTargets[0].data_path},
      {L"127.0.0.1", kProbeTargets[1].proof_path, kProbeTargets[1].data_path},
  };
  static constexpr ProbeTarget api_reserve{L"127.0.0.1", kApiReserve.proof_path, kApiReserve.data_path};
  return std::make_unique<AuthenticatedEgressProbe>(
      targets, reserve ? 2 : 1, api_reserve, port, secure, false, events, expected_tun_ipv4);
}

std::wstring QueryLoopbackProbeAddressForTest(std::uint16_t port,
                                            const CheckInterruption& interrupted,
                                            bool reserve, std::optional<bool>* dns_a_accepted) {
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
  auto result = QueryProbeAddress(endpoint, kProbeTargets[reserve ? 1 : 0].hostname,
      interrupted, &observation);
  if (dns_a_accepted != nullptr) *dns_a_accepted = observation.dns_a_accepted;
  return result;
}
#endif

}  // namespace pokrov::service
