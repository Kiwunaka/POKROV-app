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
      "",
  };
  auto bytes = Encode(request);
  Expect(!bytes.empty(), "valid request did not encode");

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

}  // namespace

int main() {
  TestRoundTrips();
  TestRejectsInvalidFrames();
  return failures == 0 ? 0 : 1;
}
