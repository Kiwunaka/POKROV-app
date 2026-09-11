#include <winsock2.h>
#include <windows.h>

#include "service_runtime.h"

#include <atomic>
#include <iostream>
#include <string>
#include <thread>

#ifdef _DEBUG
namespace {
class LoopbackServer {
 public:
  explicit LoopbackServer(std::string reply, bool tls_stall = false)
      : reply_(std::move(reply)), tls_stall_(tls_stall) {
    listener_ = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (listener_ == INVALID_SOCKET ||
        ::bind(listener_, reinterpret_cast<sockaddr*>(&address), sizeof(address)) ||
        ::listen(listener_, 4)) return;
    int length = sizeof(address);
    if (::getsockname(listener_, reinterpret_cast<sockaddr*>(&address), &length)) return;
    port = ntohs(address.sin_port);
    worker_ = std::thread([this] {
      while (!stop_) {
        fd_set readable;
        FD_ZERO(&readable);
        FD_SET(listener_, &readable);
        timeval timeout{0, 100000};
        if (::select(0, &readable, nullptr, nullptr, &timeout) <= 0) continue;
        const SOCKET client = ::accept(listener_, nullptr, nullptr);
        if (client == INVALID_SOCKET) continue;
        DWORD receive_timeout = 3000;
        ::setsockopt(client, SOL_SOCKET, SO_RCVTIMEO,
                     reinterpret_cast<const char*>(&receive_timeout), sizeof(receive_timeout));
        std::string request;
        char buffer[2048];
        while (request.find("\r\n\r\n") == std::string::npos && request.size() < 8192) {
          const int size = ::recv(client, buffer, sizeof(buffer), 0);
          if (size <= 0) break;
          request.append(buffer, size);
          if (tls_stall_) break;
        }
        expected_request_received = tls_stall_
            ? request.size() >= 2 && static_cast<unsigned char>(request[0]) == 0x16 &&
                  static_cast<unsigned char>(request[1]) == 0x03
            : request.find("GET /api/public/authenticated-egress-probe HTTP/") == 0;
        ++requests;
        if (reply_.empty()) {
          receive_timeout = 10000;
          ::setsockopt(client, SOL_SOCKET, SO_RCVTIMEO,
                       reinterpret_cast<const char*>(&receive_timeout), sizeof(receive_timeout));
          const int received = ::recv(client, buffer, sizeof(buffer), 0);
          peer_cancelled = received == 0 ||
              (received == SOCKET_ERROR && ::WSAGetLastError() == WSAECONNRESET);
        } else {
          ::send(client, reply_.data(), static_cast<int>(reply_.size()), 0);
        }
        ::closesocket(client);
      }
    });
  }
  ~LoopbackServer() {
    stop_ = true;
    if (worker_.joinable()) worker_.join();
    if (listener_ != INVALID_SOCKET) ::closesocket(listener_);
  }
  unsigned short port = 0;
  std::atomic<int> requests{0};
  std::atomic<bool> peer_cancelled{false};
  std::atomic<bool> expected_request_received{false};

 private:
  SOCKET listener_ = INVALID_SOCKET;
  std::string reply_;
  bool tls_stall_;
  std::atomic<bool> stop_{false};
  std::thread worker_;
};
}  // namespace
#endif

int main() {
#ifdef _DEBUG
  using namespace pokrov::service;
  WSADATA wsa{};
  if (::WSAStartup(MAKEWORD(2, 2), &wsa)) return 1;
  int failures = 0;
  const auto expect = [&](bool value, const char* message) {
    if (!value) { std::cerr << message << '\n'; ++failures; }
  };
  {
    const SOCKET reservation = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    expect(reservation != INVALID_SOCKET &&
               ::bind(reservation, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
           "closed-port reservation failed");
    int length = sizeof(address);
    if (::getsockname(reservation, reinterpret_cast<sockaddr*>(&address), &length)) return 1;
    auto probe = CreateLoopbackEgressProbeForTest(ntohs(address.sin_port));
    const auto failure = probe->Verify();
    expect(failure == "core_egress_connect_failed",
           "real endpoint connection failure lost its observed category");
    std::cout << "closed_endpoint_failure=" << failure << '\n';
    ::closesocket(reservation);
  }
  {
    LoopbackServer server("");
    expect(server.port != 0, "loopback listener failed");
    if (server.port == 0) return 1;
    auto probe = CreateLoopbackEgressProbeForTest(server.port);
    const auto start = ::GetTickCount64();
    const auto failure = probe->Verify([&] {
      return server.requests.load() > 0 || ::GetTickCount64() - start > 2000
                 ? OperationInterruption::kCancelled : OperationInterruption::kNone;
    });
    const auto elapsed = ::GetTickCount64() - start;
    expect(!failure.empty() && elapsed < 1500 && server.requests == 1,
           "cancellation did not stop pending headers before timeout or retried");
    const auto close_deadline = ::GetTickCount64() + 1000;
    while (!server.peer_cancelled && ::GetTickCount64() < close_deadline) ::Sleep(10);
    expect(server.peer_cancelled, "cancelled WinHTTP request left its socket open");
    std::cout << "pending_headers_cancel_ms=" << elapsed << '\n';
  }
  for (bool authenticated : {true, false}) {
    LoopbackServer server(std::string("HTTP/1.1 204 No Content\r\nConnection: close\r\n") +
        "X-Pokrov-Egress-Probe: " +
        (authenticated ? "pokrov-authenticated-egress-v1" : "wrong-marker") + "\r\n\r\n");
    expect(server.port != 0, "proof listener failed");
    if (server.port == 0) return 1;
    auto probe = CreateLoopbackEgressProbeForTest(server.port);
    expect(probe->Verify().empty() == authenticated,
           "async egress accepted invalid proof or rejected authenticated marker");
    expect(server.requests == (authenticated ? 1 : 3), "egress retry count changed");
  }
  for (bool secure : {false, true}) {
    LoopbackServer server("", secure);
    expect(server.port != 0, "stall listener failed");
    if (server.port == 0) return 1;
    auto probe = CreateLoopbackEgressProbeForTest(server.port, secure);
    const auto started = ::GetTickCount64();
    const auto failure = probe->Verify();
    expect(failure == (secure ? "core_egress_tls_timeout"
                             : "core_egress_response_timeout"),
           "real stalled connection lost its observed TLS/response phase");
    expect(server.requests == 3, "stalled egress changed the three-attempt budget");
    expect(server.expected_request_received,
           "stall fixture did not observe the expected TLS/HTTP request");
    std::cout << (secure ? "tls" : "response") << "_stall_failure=" << failure
              << " elapsed_ms=" << (::GetTickCount64() - started) << '\n';
  }
  ::WSACleanup();
  return failures == 0 ? 0 : 1;
#else
  return 1;
#endif
}
