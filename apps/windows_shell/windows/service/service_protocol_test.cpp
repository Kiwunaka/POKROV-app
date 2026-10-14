#include "service_protocol.h"

#include <cstdint>
#include <iostream>
#include <vector>

namespace {

int failures = 0;

pokrov::service::Identifier Identifier(std::uint8_t seed) {
  pokrov::service::Identifier value{};
  for (std::size_t index = 0; index < value.size(); ++index) {
    value[index] = static_cast<std::uint8_t>(seed + index);
  }
  return value;
}

void Expect(bool condition, const char* message) {
  if (!condition) {
    std::cerr << message << '\n';
    ++failures;
  }
}

void WriteUint16(std::vector<std::uint8_t>* frame, std::size_t offset,
                 std::uint16_t value) {
  (*frame)[offset] = static_cast<std::uint8_t>(value & 0xFF);
  (*frame)[offset + 1] = static_cast<std::uint8_t>((value >> 8) & 0xFF);
}

void TestRoundTrips() {
  using namespace pokrov::service;
  const Frame hello{
      FrameKind::kHelloRequest,
      Command::kHello,
      Status::kNone,
      Identifier(1),
      {},
      {},
      0,
      kCapabilityProtocolV1 | kCapabilityStatus,
      "",
  };
  const auto hello_bytes = Encode(hello);
  Expect(Decode(hello_bytes.data(), hello_bytes.size()) == hello,
         "hello did not round-trip");

  const Frame request{
      FrameKind::kRequest,
      Command::kStatus,
      Status::kNone,
      Identifier(2),
      Identifier(3),
      Identifier(4),
      4102444800000ULL,
      0,
      "",
  };
  const auto request_bytes = Encode(request);
  Expect(Decode(request_bytes.data(), request_bytes.size()) == request,
         "request did not round-trip");

  const Frame stage_request{
      FrameKind::kRequest,
      Command::kStageProfile,
      Status::kNone,
      Identifier(5),
      Identifier(6),
      Identifier(7),
      4102444800000ULL,
      0,
      "0\n{\"route\":{\"final\":\"direct\"}}",
  };
  const auto stage_bytes = Encode(stage_request);
  Expect(Decode(stage_bytes.data(), stage_bytes.size()) == stage_request,
         "bounded materialized profile did not round-trip");

  const Frame response{
      FrameKind::kResponse,
      Command::kStatus,
      Status::kNotReady,
      request.correlation_id,
      request.session_token,
      {},
      0,
      0,
      "service_bootstrap",
  };
  const auto response_bytes = Encode(response);
  Expect(Decode(response_bytes.data(), response_bytes.size()) == response,
         "response did not round-trip");
  auto bounded_response = response;
  bounded_response.body.assign(kMaxControlBodySize + 1, 'a');
  Expect(Encode(bounded_response).empty(),
         "candidate response allowance enlarged ordinary control replies");
  bounded_response.command = Command::kProbeCandidate;
  bounded_response.body.assign(kMaxCandidateProbeResultBodySize + 1, 'a');
  Expect(Encode(bounded_response).empty(),
         "oversized candidate response crossed the IPC boundary");
}

void TestRejectsInvalidFrames() {
  using namespace pokrov::service;
  Frame request{
      FrameKind::kRequest,
      Command::kConnect,
      Status::kNone,
      Identifier(1),
      Identifier(2),
      Identifier(3),
      4102444800000ULL,
      0,
      std::string(64, 'a'),
  };
  auto bytes = Encode(request);
  Expect(!bytes.empty(), "valid request did not encode");

  auto missing_identity = request;
  missing_identity.body.clear();
  Expect(Encode(missing_identity).empty(), "connect without profile identity encoded");
  missing_identity.body = std::string(64, 'g');
  Expect(Encode(missing_identity).empty(), "non-hex profile identity encoded");
  auto future = bytes;
  WriteUint16(&future, 4, kProtocolVersion + 1);
  Expect(!Decode(future.data(), future.size()),
         "future protocol version was accepted");

  auto unknown_command = bytes;
  WriteUint16(&unknown_command, 8, 99);
  Expect(!Decode(unknown_command.data(), unknown_command.size()),
         "unknown command was accepted");

  auto unknown_kind = bytes;
  WriteUint16(&unknown_kind, 6, 99);
  Expect(!Decode(unknown_kind.data(), unknown_kind.size()),
         "unknown frame kind was accepted");

  request.session_token = {};
  Expect(Encode(request).empty(), "request without session token encoded");
  request.session_token = Identifier(2);
  request.operation_nonce = {};
  Expect(Encode(request).empty(), "request without operation nonce encoded");
  request.operation_nonce = Identifier(3);
  request.body = "caller-selected-path";
  Expect(Encode(request).empty(), "request body was accepted");

  Frame profile_request{
      FrameKind::kRequest,
      Command::kStageProfile,
      Status::kNone,
      Identifier(4),
      Identifier(5),
      Identifier(6),
      4102444800000ULL,
      0,
      "0\n{}",
  };
  profile_request.body.push_back('\0');
  Expect(Encode(profile_request).empty(), "NUL profile body was accepted");
  profile_request.body.assign(kMaxProfileBodySize + 1, 'x');
  Expect(Encode(profile_request).empty(), "oversized profile body was accepted");

  bytes.push_back(0);
  Expect(!Decode(bytes.data(), bytes.size()), "trailing byte was accepted");
}

void TestNetworkObservationBoundary() {
  using namespace pokrov::service;
  NetworkObservationRequest observation{"api.pokrov.space", "synthetic.token", "1.5.0",
      "fixture", "running", "00000000-0000-4000-8000-000000000001"};
  const auto body = EncodeNetworkObservation(observation);
  const auto decoded = DecodeNetworkObservation(body);
  Expect(decoded && decoded->session_token == observation.session_token &&
      decoded->report_run_id == observation.report_run_id, "network observation lost its bounded request");
  const Frame request{FrameKind::kRequest, Command::kObserveNetworkContext, Status::kNone,
      Identifier(1), Identifier(2), Identifier(3), 4102444800000ULL, 0, body};
  const auto frame = Encode(request);
  Expect(Decode(frame.data(), frame.size()) == request, "network observation command did not round-trip");
  const auto http = NetworkObservationHttpRequest(observation, "ethernet");
  Expect(http.rfind("POST /api/client/network/context HTTP/1.1\r\nHost: api.pokrov.space\r\n", 0) == 0 &&
      http.find("\r\nUser-Agent: POKROV/windows/1.5.0\r\n") != std::string::npos &&
      http.find("\"direct_observation\":true,\"source_network\":\"physical\"") != std::string::npos,
      "network observation did not use its fixed owned endpoint and physical contract");
  observation.host = "api.pokrov.space/another-path";
  Expect(NetworkObservationHttpRequest(observation, "ethernet").empty(), "network observation accepted a caller URL");
  observation.host = "api.pokrov.space";
  observation.session_token += "\r\nInjected: value";
  Expect(EncodeNetworkObservation(observation).empty(), "network observation accepted header injection");
  observation.session_token = "synthetic.token";
  observation.profile_revision = "\"injected\"";
  Expect(EncodeNetworkObservation(observation).empty(), "network observation accepted unescaped metadata");
}

}  // namespace

int main() {
  using namespace pokrov::service;
  const CandidateProbeRequest probe{"candidate_1", 4000, "network_" + std::string(32, 'a'), "{\"outbounds\":[]}"};
  const auto encoded_probe = EncodeCandidateProbe(probe);
  const auto decoded_probe = DecodeCandidateProbe(encoded_probe);
  Expect(decoded_probe && decoded_probe->config == probe.config && decoded_probe->probe_id == probe.probe_id &&
         decoded_probe->timeout_ms == 4000 && decoded_probe->network_context_ref == probe.network_context_ref,
         "candidate probe lost exact config or cancellation identity");
  Expect(!DecodeCandidateProbe("bad\nid\n4000\n" + probe.network_context_ref + "\n{}"),
         "candidate probe admitted an injected ID boundary");
  TestRoundTrips();
  TestRejectsInvalidFrames();
  TestNetworkObservationBoundary();
  return failures == 0 ? 0 : 1;
}
