#include <winsock2.h>
#include <windows.h>

#include "service_runtime.h"
#include "service_client.h"
#include "service_profile_identity.h"

#include <atomic>
#include <functional>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

#ifdef _DEBUG
namespace pokrov::service {
std::wstring QueryLoopbackProbeAddressForTest(std::uint16_t port,
                                            const CheckInterruption& interrupted,
                                            bool reserve = false);
}
namespace {
class EgressEvents final : public pokrov::service::ServiceEventSink {
 public:
  struct Observation {
    pokrov::service::EgressProbeStage stage;
    pokrov::service::EgressProbeOutcome outcome;
    pokrov::service::EgressErrorDomain domain;
    std::uint32_t error;
    std::uint64_t elapsed_ms;
  };
  bool Record(pokrov::service::ServiceEvent, pokrov::service::ServiceEventOutcome) override { return true; }
  bool RecordSystemBoot(std::uint64_t) override { return true; }
  bool RecordIpcRequest(pokrov::service::Command, const pokrov::service::Identifier&) override { return true; }
  bool RecordIpcResponse(pokrov::service::Command, pokrov::service::Status,
                         const pokrov::service::Identifier&) override { return true; }
  bool RecordEgressProbeObservation(pokrov::service::EgressProbeStage stage,
      pokrov::service::EgressProbeOutcome outcome, pokrov::service::EgressErrorDomain domain,
      std::uint32_t error, std::uint64_t elapsed_ms) override {
    observations.push_back({stage, outcome, domain, error, elapsed_ms});
    return true;
  }
  std::vector<Observation> observations;
};

class LoopbackDnsServer {
 public:
  enum class Reply { kValid, kWrongId, kWrongName, kError, kWait };
  explicit LoopbackDnsServer(Reply reply) {
    socket_ = ::socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (socket_ == INVALID_SOCKET ||
        ::bind(socket_, reinterpret_cast<sockaddr*>(&address), sizeof(address))) return;
    int length = sizeof(address);
    if (::getsockname(socket_, reinterpret_cast<sockaddr*>(&address), &length)) return;
    port = ntohs(address.sin_port);
    worker_ = std::thread([this, reply] {
      while (!stop_) {
        fd_set readable;
        FD_ZERO(&readable);
        FD_SET(socket_, &readable);
        timeval timeout{0, 50000};
        if (::select(0, &readable, nullptr, nullptr, &timeout) <= 0) continue;
        unsigned char request[512]{};
        sockaddr_in peer{};
        int peer_size = sizeof(peer);
        const int received = ::recvfrom(socket_, reinterpret_cast<char*>(request),
            sizeof(request), 0, reinterpret_cast<sockaddr*>(&peer), &peer_size);
        ++requests;
        if (received < 17 || reply == Reply::kWait) return;
        std::vector<unsigned char> response(request, request + received);
        response[2] |= 0x80;  // QR: response; the question and transaction are echoed.
        response[3] |= 0x80;  // Recursion available.
        response[6] = 0;
        response[7] = 1;      // One A answer, compressed to the question name.
        const unsigned char answer[]{0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 60,
                                     0, 4, 127, 0, 0, 1};
        response.insert(response.end(), std::begin(answer), std::end(answer));
        if (reply == Reply::kWrongId) response[0] ^= 1;
        if (reply == Reply::kWrongName) response[13] = 'z';
        if (reply == Reply::kError) response[3] |= 3;
        ::sendto(socket_, reinterpret_cast<const char*>(response.data()),
            static_cast<int>(response.size()), 0, reinterpret_cast<sockaddr*>(&peer), peer_size);
        return;
      }
    });
  }
  ~LoopbackDnsServer() {
    stop_ = true;
    if (worker_.joinable()) worker_.join();
    if (socket_ != INVALID_SOCKET) ::closesocket(socket_);
  }
  unsigned short port = 0;
  std::atomic<int> requests{0};
 private:
  SOCKET socket_ = INVALID_SOCKET;
  std::atomic<bool> stop_{false};
  std::thread worker_;
};

class LoopbackServer {
 public:
  explicit LoopbackServer(std::string reply, bool tls_stall = false)
      : LoopbackServer([reply = std::move(reply)](const std::string&) { return reply; }, tls_stall) {}
  explicit LoopbackServer(std::function<std::string(const std::string&)> reply,
                          bool tls_stall = false, bool keep_open = false,
                          bool keep_alive = false)
      : reply_(std::move(reply)), tls_stall_(tls_stall), keep_open_(keep_open),
        keep_alive_(keep_alive) {
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
        if (::select(0, &readable, nullptr, nullptr, &timeout) <= 0)
          continue;
        const SOCKET client = ::accept(listener_, nullptr, nullptr);
        if (client == INVALID_SOCKET)
          continue;
        ++connections;
        DWORD receive_timeout = 3000;
        ::setsockopt(client, SOL_SOCKET, SO_RCVTIMEO,
                     reinterpret_cast<const char*>(&receive_timeout),
                     sizeof(receive_timeout));
        do {
          std::string request;
          char buffer[2048];
          while (request.find("\r\n\r\n") == std::string::npos &&
                 request.size() < 8192) {
            const int size = ::recv(client, buffer, sizeof(buffer), 0);
            if (size <= 0)
              break;
            request.append(buffer, size);
            if (tls_stall_)
              break;
          }
          if (request.empty())
            break;
          expected_request_received =
              tls_stall_
                  ? request.size() >= 2 &&
                        static_cast<unsigned char>(request[0]) == 0x16 &&
                        static_cast<unsigned char>(request[1]) == 0x03
                  : request.find(
                        "GET /api/public/authenticated-egress-probe HTTP/") ==
                            0 ||
                        request.find(
                            "GET /api/public/egress-probe-64k HTTP/") == 0 ||
                        request.find(
                            "GET /.well-known/pokrov/egress-probe HTTP/") ==
                            0 ||
                        request.find(
                            "GET /.well-known/pokrov/egress-probe-64k.bin "
                            "HTTP/") == 0;
          ++requests;
          const auto response = reply_(request);
          for (std::size_t offset = 0; offset < response.size();) {
            const int sent =
                ::send(client, response.data() + offset,
                       static_cast<int>(response.size() - offset), 0);
            if (sent <= 0)
              break;
            offset += sent;
          }
          const bool data_request =
              request.find("egress-probe-64k") != std::string::npos;
          if (response.empty() || (keep_open_ && data_request)) {
            receive_timeout = 10000;
            ::setsockopt(client, SOL_SOCKET, SO_RCVTIMEO,
                         reinterpret_cast<const char*>(&receive_timeout),
                         sizeof(receive_timeout));
            while (!stop_) {
              const int received = ::recv(client, buffer, sizeof(buffer), 0);
              if (received > 0) continue;
              peer_cancelled = received == 0 ||
                  (received == SOCKET_ERROR && ::WSAGetLastError() == WSAECONNRESET);
              break;
            }
            break;
          }
          if (data_request)
            break;
        } while (keep_alive_ && !stop_);
        ::closesocket(client);
      }
    });
  }
  ~LoopbackServer() {
    stop_ = true;
    if (worker_.joinable())
      worker_.join();
    if (listener_ != INVALID_SOCKET)
      ::closesocket(listener_);
  }
  unsigned short port = 0;
  std::atomic<int> requests{0};
  std::atomic<int> connections{0};
  std::atomic<bool> peer_cancelled{false};
  std::atomic<bool> expected_request_received{false};

 private:
  SOCKET listener_ = INVALID_SOCKET;
  std::function<std::string(const std::string&)> reply_;
  bool tls_stall_;
  bool keep_open_;
  bool keep_alive_;
  std::atomic<bool> stop_{false};
  std::thread worker_;
};

std::string ProofReply(bool authenticated = true) {
  return std::string("HTTP/1.1 204 No Content\r\nConnection: keep-alive\r\nX-Pokrov-Egress-Probe: ") +
      (authenticated ? "pokrov-authenticated-egress-v1" : "wrong-marker") + "\r\n\r\n";
}

std::string DataReply(std::size_t bytes = 65536, const std::string& extra_headers = "") {
  return "HTTP/1.1 200 OK\r\nConnection: keep-alive\r\nContent-Length: 65536\r\n"
      "X-Pokrov-Egress-Probe: pokrov-authenticated-egress-v1\r\n" + extra_headers +
      "\r\n" + std::string(bytes, 'p');
}

bool DataRequest(const std::string& request) {
  return request.find("GET /api/public/egress-probe-64k HTTP/") == 0 ||
      request.find("GET /.well-known/pokrov/egress-probe-64k.bin HTTP/") == 0;
}
}  // namespace
#endif

int main(int argc, char** argv) {
#ifdef _DEBUG
  using namespace pokrov::service;
  WSADATA wsa{};
  if (::WSAStartup(MAKEWORD(2, 2), &wsa)) return 1;
  int failures = 0;
  const auto expect = [&](bool value, const char* message) {
    if (!value) { std::cerr << message << '\n'; ++failures; }
  };
  if (argc == 2 && std::string(argv[1]) == "--failure-observation") {
    const SOCKET reservation = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (reservation == INVALID_SOCKET ||
        ::bind(reservation, reinterpret_cast<sockaddr*>(&address), sizeof(address))) return 1;
    int length = sizeof(address);
    if (::getsockname(reservation, reinterpret_cast<sockaddr*>(&address), &length)) return 1;
    auto probe = CreateLoopbackEgressProbeForTest(ntohs(address.sin_port));
    expect(probe->Verify() == "core_egress_connect_failed",
           "closed loopback endpoint changed its failure category");
    const auto observation = probe->LastObservation();
    expect(observation && observation->stage == EgressProbeStage::kConnect &&
               observation->outcome == EgressProbeOutcome::kFailed &&
               observation->error_domain == EgressErrorDomain::kWinHttp && observation->error_code != 0,
           "ordinary probe lost its terminal observation without an event sink");
    if (observation) {
      const auto body = std::string("phase=config_staged;core_ready=1;can_initialize=1;can_connect=1;") +
          "running=0;core_egress_validated=0;dns_ready=0;staged_profile_digest=" + ProfileDigest("0\n{}") +
          ";effective_profile_digest=none;failure=core_egress_connect_failed;"
          "routing_catalog_window_version=0;smart_access_lease_version=0;"
          "routing_catalog_control_version=0;smart_access_runtime_control_version=0;"
          "transport_capabilities=none;core_module_sha256=none;core_version=none;"
          "protection_retained=0;windows_local_dpi_admission_version=0";
      const auto suffix = EncodeEgressProbeObservation(*observation);
      const std::string transport = ";transport_proof_pending=0;transport_lease_active=0";
      ServiceRuntimeSnapshot parsed;
      expect(ParseServiceRuntimeSnapshot(body + suffix + transport, &parsed) &&
                 parsed.egress_failure_observation &&
                 parsed.egress_failure_observation->stage == observation->stage &&
                 parsed.egress_failure_observation->outcome == observation->outcome &&
                 parsed.egress_failure_observation->error_domain == observation->error_domain &&
                 parsed.egress_failure_observation->error_code == observation->error_code &&
                 parsed.egress_failure_observation->elapsed_ms == observation->elapsed_ms,
             "whole egress failure tuple did not survive the service parser");
      expect(!ParseServiceRuntimeSnapshot(body + suffix.substr(0, suffix.find(";egress_elapsed_ms=")) + transport,
                                         &parsed) && parsed.egress_failure_observation &&
                 parsed.egress_failure_observation->elapsed_ms == observation->elapsed_ms,
             "partial failure tuple was accepted or changed the previous parsed snapshot");
      expect(ParseServiceRuntimeSnapshot(body + transport, &parsed) && !parsed.egress_failure_observation,
             "a later snapshot without observation retained old diagnostic fields");
    }
    probe->Verify([] { return OperationInterruption::kCancelled; });
    expect(!probe->LastObservation(), "Verify retained an observation from the previous attempt");
    ::closesocket(reservation);
    ::WSACleanup();
    return failures == 0 ? 0 : 1;
  }
  // The probe's DNS transport is a socket owned by this process. Exercise its
  // real SDK decoder and cancellation without a TUN, OS resolver or WFP writes.
  for (const auto reply : {LoopbackDnsServer::Reply::kValid,
                          LoopbackDnsServer::Reply::kWrongId,
                          LoopbackDnsServer::Reply::kWrongName,
                          LoopbackDnsServer::Reply::kError,
                          LoopbackDnsServer::Reply::kWait}) {
    LoopbackDnsServer server(reply);
    expect(server.port != 0, "DNS loopback listener failed");
    if (server.port == 0) return 1;
    const auto started = ::GetTickCount64();
    const auto address = QueryLoopbackProbeAddressForTest(server.port, [&] {
      return reply == LoopbackDnsServer::Reply::kWait && server.requests > 0
                 ? OperationInterruption::kCancelled : OperationInterruption::kNone;
    });
    expect(reply == LoopbackDnsServer::Reply::kValid ? address == L"127.0.0.1" : address.empty(),
           "DNS accepted a mismatched/error reply or rejected the owned valid answer");
    expect(server.requests == 1, "DNS transport did not send exactly one query");
    if (reply == LoopbackDnsServer::Reply::kWait) {
      expect(::GetTickCount64() - started < 500, "DNS cancellation waited for its full deadline");
    }
  }
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
    EgressEvents events;
    auto probe = CreateLoopbackEgressProbeForTest(server.port, false, &events);
    const auto start = ::GetTickCount64();
    const auto failure = probe->Verify([&] {
      return ::GetTickCount64() - start >= 300
                 ? OperationInterruption::kDeadlineExceeded : OperationInterruption::kNone;
    });
    const auto elapsed = ::GetTickCount64() - start;
    expect(!failure.empty() && elapsed < 1500 && server.requests == 1,
           "deadline did not stop pending headers before timeout or retried");
    expect(events.observations.size() == 2 &&
               (events.observations[0].stage == EgressProbeStage::kSending ||
                events.observations[0].stage == EgressProbeStage::kResponse) &&
               events.observations[0].outcome == EgressProbeOutcome::kDeadline &&
               events.observations[0].domain == EgressErrorDomain::kNone &&
               events.observations[0].error == 0 &&
               events.observations[0].elapsed_ms >= 250 &&
               events.observations[0].elapsed_ms < 1500 &&
               events.observations[1].stage == EgressProbeStage::kRetryWait &&
               server.expected_request_received,
           "deadline erased the observed HTTP stage or invented a native timeout error");
    const auto close_deadline = ::GetTickCount64() + 1000;
    while (!server.peer_cancelled && ::GetTickCount64() < close_deadline) ::Sleep(10);
    expect(server.peer_cancelled, "cancelled WinHTTP request left its socket open");
    std::cout << "pending_headers_deadline_ms=" << elapsed << '\n';
  }
  for (bool authenticated : {true, false}) {
    LoopbackServer server([authenticated](const std::string& request) {
      return DataRequest(request) ? DataReply() : ProofReply(authenticated);
    }, false, false, true);
    expect(server.port != 0, "proof listener failed");
    if (server.port == 0) return 1;
    auto probe = CreateLoopbackEgressProbeForTest(server.port);
    expect(probe->Verify().empty() == authenticated,
           "async egress accepted invalid proof or rejected authenticated marker");
    expect(server.requests == (authenticated ? 2 : 3), "egress retry count changed");
    if (authenticated) expect(server.connections == 1, "startup proof reconnected between 204 and 64K");
  }
  {
    LoopbackDnsServer server(LoopbackDnsServer::Reply::kValid);
    expect(QueryLoopbackProbeAddressForTest(server.port, {}, true) == L"127.0.0.1",
           "reserve hostname was not resolved through the owned DNS transport");
  }
  for (const bool encoded : {false, true}) {
    LoopbackServer server([encoded](const std::string& request) {
      return DataRequest(request) ? DataReply(encoded ? 65536 : 16384,
          encoded ? "Content-Encoding: gzip\r\n" : "") : ProofReply();
    }, false, false, true);
    auto probe = CreateLoopbackEgressProbeForTest(server.port);
    expect(!probe->Verify().empty() && server.requests == 6,
           "startup accepted a partial or encoded 64K body, or added retry slots");
  }
  {
    LoopbackServer server([](const std::string& request) {
      return DataRequest(request) ? DataReply(16384) : ProofReply();
    }, false, true, true);
    auto probe = CreateLoopbackEgressProbeForTest(server.port);
    const auto started = ::GetTickCount64();
    expect(!probe->Verify([&] {
      return server.requests >= 2 && ::GetTickCount64() - started >= 250
          ? OperationInterruption::kCancelled : OperationInterruption::kNone;
    }).empty(), "cancelled partial-body request was accepted");
    expect(::GetTickCount64() - started < 1500 && server.requests == 2,
           "partial-body cancellation retried or waited for the receive timeout");
    const auto until = ::GetTickCount64() + 1000;
    while (!server.peer_cancelled && ::GetTickCount64() < until) ::Sleep(10);
    expect(server.peer_cancelled, "cancelled body read left the owned socket open");
  }
  {
    std::atomic<int> primary{0}, reserve{0};
    LoopbackServer server([&](const std::string& request) {
      if (request.find("GET /api/public/") == 0) {
        ++primary;
        return std::string("HTTP/1.1 503 Unavailable\r\nConnection: close\r\nContent-Length: 0\r\n\r\n");
      }
      ++reserve;
      return DataRequest(request) ? DataReply() : ProofReply();
    }, false, false, true);
    auto probe = CreateLoopbackEgressProbeForTest(server.port, false, nullptr, true);
    expect(probe->Verify().empty() && primary == 1 && reserve == 2,
           "startup did not use the owned reserve pair within the existing slots");
    expect(server.connections == 2, "reserve payload did not retain its proven connection");
  }
  {
    std::atomic<int> primary{0}, reserve{0};
    LoopbackServer server([&](const std::string& request) {
      if (request.find("GET /api/public/") == 0) { ++primary; return std::string{}; }
      ++reserve;
      return ProofReply();
    }, false, false, true);
    auto probe = CreateLoopbackEgressProbeForTest(server.port, false, nullptr, true);
    const auto started = ::GetTickCount64();
    expect(probe->Verify({}, true, started + 3000).empty() && primary == 1 && reserve == 1,
           "periodic reserve added a payload check or lost its remaining-budget slot");
    expect(::GetTickCount64() - started < 3000,
           "periodic fallback reset the three-second owner deadline");
  }
  {
    LoopbackServer server([](const std::string& request) {
      auto reply = DataRequest(request) ? DataReply() : ProofReply();
      const auto at = reply.find("keep-alive");
      reply.replace(at, 10, "close");
      return reply;
    });
    auto probe = CreateLoopbackEgressProbeForTest(server.port);
    expect(!probe->Verify().empty() && server.connections == 6,
           "startup accepted a reconnect as the original proven connection");
  }
  {
    LoopbackServer server("");
    auto probe = CreateLoopbackEgressProbeForTest(server.port, false, nullptr, true);
    const auto started = ::GetTickCount64();
    expect(!probe->Verify({}, true, started + 3000).empty() &&
               ::GetTickCount64() - started < 3500 && server.requests <= 2,
           "failed periodic reserve reset its owner budget or added retry slots");
  }
  {
    LoopbackServer server([](const std::string&) {
      return std::string("HTTP/1.1 302 Found\r\nConnection: close\r\nContent-Length: 0\r\n"
                         "Location: /redirected\r\n\r\n");
    });
    auto probe = CreateLoopbackEgressProbeForTest(server.port);
    expect(!probe->Verify().empty() && server.requests == 3,
           "probe followed a redirect outside its fixed proof target");
  }
  for (bool secure : {false, true}) {
    LoopbackServer server("", secure);
    expect(server.port != 0, "stall listener failed");
    if (server.port == 0) return 1;
    auto probe = CreateLoopbackEgressProbeForTest(server.port, secure);
    const auto started = ::GetTickCount64();
    const auto failure = probe->Verify();
    if (const auto observation = probe->LastObservation()) {
      std::cout << "stall_stage=" << EgressProbeStageName(observation->stage)
                << " domain=" << EgressProbeErrorDomainName(observation->error_domain)
                << " code=" << observation->error_code << '\n';
    }
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
  static_cast<void>(argc);
  static_cast<void>(argv);
  return 1;
#endif
}
