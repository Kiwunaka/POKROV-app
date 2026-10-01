#include <winsock2.h>
#include <ws2tcpip.h>
#define SECURITY_WIN32
#include <security.h>
#include <schannel.h>
#include <iphlpapi.h>
#include <windns.h>
#include <bcrypt.h>
#include "service_local_dpi_probe.h"

#include <array>
#include <climits>
#include <cstring>
#include <vector>

namespace pokrov::service {
namespace {
struct Socket {
  SOCKET value = INVALID_SOCKET;
  ~Socket() { if (value != INVALID_SOCKET) ::closesocket(value); }
};
struct Winsock {
  WSADATA data{};
  bool ready = ::WSAStartup(MAKEWORD(2, 2), &data) == 0;
  ~Winsock() { if (ready) ::WSACleanup(); }
};
struct Tls {
  CredHandle credentials{};
  CtxtHandle context{};
  Tls() { SecInvalidateHandle(&credentials); SecInvalidateHandle(&context); }
  ~Tls() {
    if (SecIsValidHandle(&context)) ::DeleteSecurityContext(&context);
    if (SecIsValidHandle(&credentials)) ::FreeCredentialsHandle(&credentials);
  }
};

bool Current(const CheckInterruption& interrupted, ULONGLONG deadline) {
  return ::GetTickCount64() < deadline &&
      (!interrupted || interrupted() == OperationInterruption::kNone);
}

bool Wait(SOCKET socket, bool write, const CheckInterruption& interrupted, ULONGLONG deadline) {
  while (Current(interrupted, deadline)) {
    fd_set set;
    FD_ZERO(&set); FD_SET(socket, &set);
    timeval timeout{0, 50000};
    const auto result = ::select(0, write ? nullptr : &set, write ? &set : nullptr, nullptr, &timeout);
    if (result > 0) return true;
    if (result < 0) return false;
  }
  return false;
}

bool Send(SOCKET socket, const void* data, std::size_t size,
          const CheckInterruption& interrupted, ULONGLONG deadline) {
  const auto* bytes = static_cast<const char*>(data);
  while (size != 0 && Current(interrupted, deadline)) {
    if (!Wait(socket, true, interrupted, deadline)) return false;
    const auto count = ::send(socket, bytes, static_cast<int>(size), 0);
    if (count == SOCKET_ERROR && ::WSAGetLastError() == WSAEWOULDBLOCK) continue;
    if (count <= 0) return false;
    bytes += count; size -= static_cast<std::size_t>(count);
  }
  return size == 0;
}

bool Receive(SOCKET socket, std::vector<char>* pending,
             const CheckInterruption& interrupted, ULONGLONG deadline) {
  while (Wait(socket, false, interrupted, deadline)) {
    std::array<char, 16384> buffer{};
    const auto count = ::recv(socket, buffer.data(), static_cast<int>(buffer.size()), 0);
    if (count == SOCKET_ERROR && ::WSAGetLastError() == WSAEWOULDBLOCK) continue;
    if (count <= 0 || pending->size() + static_cast<std::size_t>(count) > 65536) return false;
    pending->insert(pending->end(), buffer.begin(), buffer.begin() + count);
    return true;
  }
  return false;
}

std::wstring Wide(const std::string& text) {
  if (text.empty() || text.size() > INT_MAX || text.find('\0') != std::string::npos) return {};
  const auto count = ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      text.data(), static_cast<int>(text.size()), nullptr, 0);
  if (count == 0) return {};
  std::wstring result(static_cast<std::size_t>(count), L'\0');
  return ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
      static_cast<int>(text.size()), result.data(), count) == count ? result : L"";
}

struct PhysicalEndpoint { ULONG index = 0; sockaddr_in local{}, dns{}; };
bool Endpoint(const std::wstring& alias, PhysicalEndpoint* result) {
  NET_LUID luid{};
  MIB_IF_ROW2 physical{};
  if (::ConvertInterfaceAliasToLuid(alias.c_str(), &luid) != NO_ERROR) return false;
  physical.InterfaceLuid = luid;
  if (::GetIfEntry2(&physical) != NO_ERROR || !physical.InterfaceAndOperStatusFlags.HardwareInterface ||
      physical.OperStatus != IfOperStatusUp || physical.MediaConnectState != MediaConnectStateConnected) return false;
  ULONG size = 15 * 1024;
  std::vector<unsigned char> buffer(size);
  auto* adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
  auto status = ::GetAdaptersAddresses(AF_INET, GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST,
      nullptr, adapters, &size);
  if (status == ERROR_BUFFER_OVERFLOW) {
    buffer.resize(size); adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
    status = ::GetAdaptersAddresses(AF_INET, GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST,
        nullptr, adapters, &size);
  }
  if (status != NO_ERROR) return false;
  for (auto* adapter = adapters; adapter != nullptr; adapter = adapter->Next) {
    if (adapter->Luid.Value != luid.Value || adapter->IfIndex == 0) continue;
    for (auto* address = adapter->FirstUnicastAddress; address != nullptr; address = address->Next) {
      if (address->Address.lpSockaddr == nullptr || address->Address.lpSockaddr->sa_family != AF_INET ||
          address->DadState != IpDadStatePreferred) continue;
      result->local = *reinterpret_cast<sockaddr_in*>(address->Address.lpSockaddr);
      result->local.sin_port = 0;
      for (auto* dns = adapter->FirstDnsServerAddress; dns != nullptr; dns = dns->Next) {
        if (dns->Address.lpSockaddr == nullptr || dns->Address.lpSockaddr->sa_family != AF_INET) continue;
        result->index = adapter->IfIndex;
        result->dns = *reinterpret_cast<sockaddr_in*>(dns->Address.lpSockaddr);
        result->dns.sin_port = htons(53);
        return true;
      }
    }
  }
  return false;
}

bool PublicIPv4(IN_ADDR address) {
  const auto value = ntohl(address.s_addr);
  const auto first = value >> 24;
  return first != 0 && first != 10 && first != 127 && first < 224 &&
      (value & 0xffff0000) != 0xa9fe0000 && (value & 0xfff00000) != 0xac100000 &&
      (value & 0xffff0000) != 0xc0a80000 && (value & 0xffc00000) != 0x64400000;
}

bool BoundSocket(Socket* socket, int type, int protocol, const PhysicalEndpoint& endpoint) {
  socket->value = ::socket(AF_INET, type, protocol);
  const DWORD interface_index = htonl(endpoint.index);
  u_long nonblocking = 1;
  return socket->value != INVALID_SOCKET &&
      ::setsockopt(socket->value, IPPROTO_IP, IP_UNICAST_IF,
          reinterpret_cast<const char*>(&interface_index), sizeof(interface_index)) == 0 &&
      ::bind(socket->value, reinterpret_cast<const sockaddr*>(&endpoint.local), sizeof(endpoint.local)) == 0 &&
      ::ioctlsocket(socket->value, FIONBIO, &nonblocking) == 0;
}

bool Resolve(const PhysicalEndpoint& endpoint, const std::wstring& host, IN_ADDR* address,
             const CheckInterruption& interrupted, ULONGLONG deadline) {
  Socket socket;
  if (!BoundSocket(&socket, SOCK_DGRAM, IPPROTO_UDP, endpoint) ||
      ::connect(socket.value, reinterpret_cast<const sockaddr*>(&endpoint.dns), sizeof(endpoint.dns))) return false;
  alignas(DNS_MESSAGE_BUFFER) std::array<unsigned char, 4096> query{};
  DWORD size = static_cast<DWORD>(query.size());
  WORD transaction = 0;
  if (::BCryptGenRandom(nullptr, reinterpret_cast<PUCHAR>(&transaction), sizeof(transaction),
          BCRYPT_USE_SYSTEM_PREFERRED_RNG) != 0 ||
      !::DnsWriteQuestionToBuffer_W(reinterpret_cast<DNS_MESSAGE_BUFFER*>(query.data()),
          &size, const_cast<wchar_t*>(host.c_str()), DNS_TYPE_A, transaction, TRUE) ||
      !Send(socket.value, query.data(), size, interrupted, deadline) ||
      !Wait(socket.value, false, interrupted, deadline)) return false;
  alignas(DNS_MESSAGE_BUFFER) std::array<unsigned char, 4096> reply{};
  const auto received = ::recv(socket.value, reinterpret_cast<char*>(reply.data()), static_cast<int>(reply.size()), 0);
  if (received < static_cast<int>(sizeof(DNS_HEADER))) return false;
  auto* message = reinterpret_cast<DNS_MESSAGE_BUFFER*>(reply.data());
  DNS_BYTE_FLIP_HEADER_COUNTS(&message->MessageHead);
  const auto& header = message->MessageHead;
  if (header.Xid != transaction || !header.IsResponse || header.Opcode != DNS_OPCODE_QUERY ||
      header.ResponseCode != DNS_RCODE_NOERROR || header.Truncation || header.QuestionCount != 1) return false;
  DNS_RECORDW* records = nullptr;
  if (::DnsExtractRecordsFromMessage_W(message, static_cast<WORD>(received), &records) != 0) return false;
  bool found = false;
  for (auto* record = records; record != nullptr; record = record->pNext) {
    if (record->Flags.S.Section != DnsSectionAnswer || record->wType != DNS_TYPE_A) continue;
    IN_ADDR candidate{};
    candidate.s_addr = record->Data.A.IpAddress;
    if (PublicIPv4(candidate)) { *address = candidate; found = true; break; }
  }
  if (records != nullptr) ::DnsRecordListFree(records, DnsFreeRecordList);
  return found;
}

bool Handshake(Tls* tls, SOCKET socket, const std::wstring& host, std::vector<char>* pending,
               const CheckInterruption& interrupted, ULONGLONG deadline) {
  SCHANNEL_CRED credentials{};
  credentials.dwVersion = SCHANNEL_CRED_VERSION;
  credentials.grbitEnabledProtocols = SP_PROT_TLS1_2_CLIENT;
  credentials.dwFlags = SCH_CRED_AUTO_CRED_VALIDATION | SCH_CRED_NO_DEFAULT_CREDS |
      SCH_USE_STRONG_CRYPTO | SCH_CRED_CACHE_ONLY_URL_RETRIEVAL;
  if (::AcquireCredentialsHandleW(nullptr, const_cast<wchar_t*>(UNISP_NAME_W), SECPKG_CRED_OUTBOUND,
      nullptr, &credentials, nullptr, nullptr, &tls->credentials, nullptr) != SEC_E_OK) return false;
  constexpr ULONG flags = ISC_REQ_SEQUENCE_DETECT | ISC_REQ_REPLAY_DETECT | ISC_REQ_CONFIDENTIALITY |
      ISC_REQ_ALLOCATE_MEMORY | ISC_REQ_STREAM | ISC_REQ_USE_SUPPLIED_CREDS;
  bool first = true;
  while (Current(interrupted, deadline)) {
    SecBuffer input_buffers[2]{{static_cast<ULONG>(pending->size()), SECBUFFER_TOKEN, pending->data()}, {0, SECBUFFER_EMPTY, nullptr}};
    SecBufferDesc input{SECBUFFER_VERSION, 2, input_buffers};
    SecBuffer token{0, SECBUFFER_TOKEN, nullptr};
    SecBufferDesc output{SECBUFFER_VERSION, 1, &token};
    ULONG attributes = 0;
    const auto status = ::InitializeSecurityContextW(&tls->credentials,
        first ? nullptr : &tls->context, const_cast<wchar_t*>(host.c_str()), flags, 0, SECURITY_NATIVE_DREP,
        first ? nullptr : &input, 0, &tls->context, &output, &attributes, nullptr);
    first = false;
    bool sent = true;
    if (token.pvBuffer != nullptr) {
      if (status >= 0 && token.cbBuffer != 0) sent = Send(socket, token.pvBuffer, token.cbBuffer, interrupted, deadline);
      ::FreeContextBuffer(token.pvBuffer);
    }
    if (!sent || (status != SEC_E_OK && status != SEC_I_CONTINUE_NEEDED && status != SEC_E_INCOMPLETE_MESSAGE)) return false;
    if (status != SEC_E_INCOMPLETE_MESSAGE) {
      const auto extra = input_buffers[1].BufferType == SECBUFFER_EXTRA ? input_buffers[1].cbBuffer : 0;
      if (extra > pending->size()) return false;
      pending->erase(pending->begin(), pending->end() - extra);
    }
    if (status == SEC_E_OK) return Current(interrupted, deadline);
    if (status == SEC_E_INCOMPLETE_MESSAGE || pending->empty()) {
      if (!Receive(socket, pending, interrupted, deadline)) return false;
    }
  }
  return false;
}

bool Head(Tls* tls, SOCKET socket, const std::string& host, std::vector<char>* pending,
          const CheckInterruption& interrupted, ULONGLONG deadline) {
  SecPkgContext_StreamSizes sizes{};
  if (::QueryContextAttributesW(&tls->context, SECPKG_ATTR_STREAM_SIZES, &sizes) != SEC_E_OK) return false;
  const auto head = "HEAD / HTTP/1.1\r\nHost: " + host + "\r\nConnection: close\r\n\r\n";
  std::vector<char> encrypted(sizes.cbHeader + head.size() + sizes.cbTrailer);
  std::memcpy(encrypted.data() + sizes.cbHeader, head.data(), head.size());
  SecBuffer outgoing[4]{{sizes.cbHeader, SECBUFFER_STREAM_HEADER, encrypted.data()},
      {static_cast<ULONG>(head.size()), SECBUFFER_DATA, encrypted.data() + sizes.cbHeader},
      {sizes.cbTrailer, SECBUFFER_STREAM_TRAILER, encrypted.data() + sizes.cbHeader + head.size()}, {0, SECBUFFER_EMPTY, nullptr}};
  SecBufferDesc message{SECBUFFER_VERSION, 4, outgoing};
  if (::EncryptMessage(&tls->context, 0, &message, 0) != SEC_E_OK) return false;
  for (unsigned int i = 0; i < 3; ++i) {
    if (!Send(socket, outgoing[i].pvBuffer, outgoing[i].cbBuffer, interrupted, deadline)) return false;
  }
  std::string response;
  while (Current(interrupted, deadline)) {
    if (pending->empty() && !Receive(socket, pending, interrupted, deadline)) return false;
    SecBuffer incoming[4]{{static_cast<ULONG>(pending->size()), SECBUFFER_DATA, pending->data()},
        {0, SECBUFFER_EMPTY, nullptr}, {0, SECBUFFER_EMPTY, nullptr}, {0, SECBUFFER_EMPTY, nullptr}};
    SecBufferDesc input{SECBUFFER_VERSION, 4, incoming};
    const auto status = ::DecryptMessage(&tls->context, &input, 0, nullptr);
    if (status == SEC_E_INCOMPLETE_MESSAGE) {
      if (!Receive(socket, pending, interrupted, deadline)) return false;
      continue;
    }
    if (status != SEC_E_OK) return false;  // No renegotiation or response replay.
    ULONG extra = 0;
    for (const auto& buffer : incoming) {
      if (buffer.BufferType == SECBUFFER_DATA) {
        if (response.size() + buffer.cbBuffer > 16384) return false;
        response.append(static_cast<const char*>(buffer.pvBuffer), buffer.cbBuffer);
      }
      if (buffer.BufferType == SECBUFFER_EXTRA) extra = buffer.cbBuffer;
    }
    if (extra > pending->size()) return false;
    pending->erase(pending->begin(), pending->end() - extra);
    if (response.find("\r\n\r\n") != std::string::npos) {
      const bool protocol = response.rfind("HTTP/1.1 ", 0) == 0 || response.rfind("HTTP/1.0 ", 0) == 0;
      return Current(interrupted, deadline) && protocol && response.size() >= 13 && response[9] == '2' &&
          response[10] >= '0' && response[10] <= '9' && response[11] >= '0' && response[11] <= '9' &&
          (response[12] == ' ' || response[12] == '\r');
    }
  }
  return false;
}
}  // namespace

std::string VerifyWindowsLocalDpiControlHost(const std::string& control_host,
                                           const std::string& bind_interface,
                                           const CheckInterruption& interrupted) {
  const auto host = Wide(control_host), alias = Wide(bind_interface);
  if (host.empty() || alias.empty()) return "local_dpi_control_invalid";
  const auto deadline = ::GetTickCount64() + 10000;
  Winsock winsock;
  PhysicalEndpoint endpoint;
  if (!winsock.ready || !Endpoint(alias, &endpoint) || !Current(interrupted, deadline)) return "local_dpi_physical_unavailable";
  IN_ADDR address{};
  if (!Resolve(endpoint, host, &address, interrupted, deadline)) return "local_dpi_control_dns_failed";
  Socket socket;
  if (!BoundSocket(&socket, SOCK_STREAM, IPPROTO_TCP, endpoint)) return "local_dpi_control_connect_failed";
  sockaddr_in target{};
  target.sin_family = AF_INET; target.sin_port = htons(443); target.sin_addr = address;
  if (::connect(socket.value, reinterpret_cast<const sockaddr*>(&target), sizeof(target)) == SOCKET_ERROR &&
      ::WSAGetLastError() != WSAEWOULDBLOCK) return "local_dpi_control_connect_failed";
  int error = 0, length = sizeof(error);
  if (!Wait(socket.value, true, interrupted, deadline) ||
      ::getsockopt(socket.value, SOL_SOCKET, SO_ERROR, reinterpret_cast<char*>(&error), &length) || error != 0) return "local_dpi_control_connect_failed";
  sockaddr_in actual{};
  length = sizeof(actual);
  if (::getsockname(socket.value, reinterpret_cast<sockaddr*>(&actual), &length) ||
      actual.sin_addr.s_addr != endpoint.local.sin_addr.s_addr) return "local_dpi_physical_changed";
  Tls tls;
  std::vector<char> pending;
  if (!Handshake(&tls, socket.value, host, &pending, interrupted, deadline)) return "local_dpi_control_tls_failed";
  return Head(&tls, socket.value, control_host, &pending, interrupted, deadline) ? "" : "local_dpi_control_http_failed";
}
}  // namespace pokrov::service
