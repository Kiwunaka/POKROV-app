#ifndef POKROV_SERVICE_SERVICE_PROTOCOL_H_
#define POKROV_SERVICE_SERVICE_PROTOCOL_H_

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace pokrov::service {

constexpr std::uint32_t kFrameMagic = 0x49534B50;
constexpr std::uint16_t kProtocolVersion = 1;
constexpr std::size_t kFrameHeaderSize = 80;
constexpr std::size_t kMaxControlBodySize = 512;
constexpr std::size_t kMaxProfileBodySize = 256 * 1024;
constexpr std::size_t kMaxBodySize = kMaxProfileBodySize;
constexpr std::size_t kMaxFrameSize = kFrameHeaderSize + kMaxBodySize;
constexpr std::uint64_t kCapabilityProtocolV1 = 1ULL << 0;
constexpr std::uint64_t kCapabilityStatus = 1ULL << 1;
constexpr std::uint64_t kCapabilityRuntimeControl = 1ULL << 2;
constexpr std::uint64_t kCapabilityProfileIdentity = 1ULL << 5;
constexpr std::uint64_t kCapabilityCancellation = 1ULL << 6;
constexpr std::uint64_t kCapabilityRecovery = 1ULL << 3;
constexpr std::uint64_t kCapabilitySanitizedDiagnostic = 1ULL << 4;

using Identifier = std::array<std::uint8_t, 16>;

struct CancellationTarget {
  Identifier session_token{};
  Identifier operation_nonce{};
};

std::string EncodeCancellationTarget(const CancellationTarget& target);
std::optional<CancellationTarget> DecodeCancellationTarget(const std::string& body);

enum class FrameKind : std::uint16_t {
  kHelloRequest = 1,
  kRequest = 2,
  kResponse = 3,
};

enum class Command : std::uint16_t {
  kHello = 0,
  kStatus = 1,
  kConnect = 2,
  kDisconnect = 3,
  kCancel = 4,
  kRecover = 5,
  kDiagnosticState = 6,
  kInitialize = 7,
  kStageProfile = 8,
  kInvalidateProfile = 9,
};

enum class Status : std::uint16_t {
  kNone = 0,
  kOk = 1,
  kInvalid = 2,
  kUnauthorized = 3,
  kUnsupported = 4,
  kNotReady = 5,
  kReplay = 6,
  kDeadlineExceeded = 7,
};

struct Frame {
  FrameKind kind;
  Command command;
  Status status;
  Identifier correlation_id{};
  Identifier session_token{};
  Identifier operation_nonce{};
  std::uint64_t deadline_unix_ms = 0;
  std::uint64_t capabilities = 0;
  std::string body;

  bool operator==(const Frame& other) const {
    return kind == other.kind && command == other.command &&
           status == other.status && correlation_id == other.correlation_id &&
           session_token == other.session_token &&
           operation_nonce == other.operation_nonce &&
           deadline_unix_ms == other.deadline_unix_ms &&
           capabilities == other.capabilities && body == other.body;
  }
};

bool IsZeroIdentifier(const Identifier& value);
std::optional<std::size_t> ExpectedFrameSize(const void* header,
                                             std::size_t header_size);
std::vector<std::uint8_t> Encode(const Frame& frame);
std::optional<Frame> Decode(const void* frame, std::size_t frame_size);

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_PROTOCOL_H_
