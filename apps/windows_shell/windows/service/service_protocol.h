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
constexpr std::size_t kMaxRuntimeSnapshotBodySize = 8192;
constexpr std::size_t kMaxRestrictionSnapshotBodySize = 1024 * 1024;
constexpr std::size_t kMaxSmartAccessLeasesBodySize = 65536;
constexpr std::size_t kMaxProfileBodySize = 256 * 1024;
constexpr std::size_t kMaxBodySize = kMaxRestrictionSnapshotBodySize;
constexpr std::size_t kMaxFrameSize = kFrameHeaderSize + kMaxBodySize;
constexpr std::uint64_t kCapabilityProtocolV1 = 1ULL << 0;
constexpr std::uint64_t kCapabilityStatus = 1ULL << 1;
constexpr std::uint64_t kCapabilityRuntimeControl = 1ULL << 2;
constexpr std::uint64_t kCapabilityProfileIdentity = 1ULL << 5;
constexpr std::uint64_t kCapabilityCancellation = 1ULL << 6;
constexpr std::uint64_t kCapabilityRecovery = 1ULL << 3;
constexpr std::uint64_t kCapabilitySanitizedDiagnostic = 1ULL << 4;
// Negotiates the snapshot field, not support in the loaded Core itself.
constexpr std::uint64_t kCapabilityRoutingCatalogWindow = 1ULL << 7;
constexpr std::uint64_t kCapabilitySmartAccessLease = 1ULL << 8;
constexpr std::uint64_t kCapabilityRoutingCatalogControl = 1ULL << 9;
constexpr std::uint64_t kCapabilitySmartAccessPolicyControl = 1ULL << 10;
constexpr std::uint64_t kCapabilityRoutingCatalogServiceControl = 1ULL << 11;
constexpr std::uint64_t kCapabilitySmartAccessRenewal = 1ULL << 12;
constexpr std::uint64_t kCapabilitySmartAccessRuntimeControl = 1ULL << 13;
constexpr std::uint64_t kCapabilityBootClock = 1ULL << 14;
constexpr std::uint64_t kCapabilityBoundConnect = 1ULL << 15;
constexpr std::uint64_t kCapabilityConnectSettlement = 1ULL << 16;
constexpr std::uint64_t kCapabilityBoundRuntimeControl = 1ULL << 17;
constexpr std::uint64_t kCapabilityTransportNetworkContext = 1ULL << 18;
constexpr std::uint64_t kCapabilityBoundProfileStage = 1ULL << 19;
constexpr std::uint64_t kCapabilityTransportLeaseHandoff = 1ULL << 20;

struct BoundConnectTarget {
  std::string core_module_sha256;
  std::string profile_digest;
  std::string boot_ref;
  std::uint64_t started_elapsed_ms = 0;
  std::uint64_t deadline_elapsed_ms = 0;
  std::string network_context_ref;
};
bool IsTransportNetworkContextRef(const std::string& value);
std::string EncodeBoundConnect(const BoundConnectTarget& target);
std::optional<BoundConnectTarget> DecodeBoundConnect(const std::string& body);

using Identifier = std::array<std::uint8_t, 16>;

struct CancellationTarget {
  Identifier session_token{};
  Identifier operation_nonce{};
};

struct TransportLeasePromotion {
  CancellationTarget target;
  std::string profile_digest;
  std::string endpoint_lease_ref;
  std::string issued_at;
  std::string new_flows_until;
  std::string active_flows_until;
};
std::string EncodeTransportLeasePromotion(const TransportLeasePromotion& target);
std::optional<TransportLeasePromotion> DecodeTransportLeasePromotion(const std::string& body);

struct TransportLeaseRevocation {
  CancellationTarget target;
  std::string profile_digest;
  std::string endpoint_lease_ref;
  bool terminate_active = false;
};
std::string EncodeTransportLeaseRevocation(const TransportLeaseRevocation& target);
std::optional<TransportLeaseRevocation> DecodeTransportLeaseRevocation(const std::string& body);

std::string EncodeCancellationTarget(const CancellationTarget& target);
std::optional<CancellationTarget> DecodeCancellationTarget(const std::string& body);

struct SmartAccessRevocationTarget {
  std::string profile_digest;
  std::string lease_id;
  bool terminate_active = false;
};
std::string EncodeSmartAccessRevocation(const SmartAccessRevocationTarget& target);
std::optional<SmartAccessRevocationTarget> DecodeSmartAccessRevocation(const std::string& body);
bool IsSmartAccessPolicyRevocation(const std::string& body);
bool IsRoutingCatalogServiceRevocation(const std::string& body);
bool IsSmartAccessRuntimeControl(const std::string& body);
bool IsBoundSmartAccessRuntimeControl(const std::string& body);

struct SmartAccessRenewalTarget {
  std::string profile_digest;
  std::string expected_lease_id;
  std::string next_lease_id;
  std::string issued_at;
  std::string new_flows_until;
  std::string active_flows_until;
};
std::string EncodeSmartAccessRenewal(const SmartAccessRenewalTarget& target);
std::optional<SmartAccessRenewalTarget> DecodeSmartAccessRenewal(const std::string& body);

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
  kRevokeSmartAccessLease = 10,
  kRevokeRoutingCatalog = 11,
  kRevokeSmartAccessPolicy = 12,
  kRevokeRoutingCatalogService = 13,
  kRenewSmartAccessLease = 14,
  kConfigureSmartAccessRuntimeControl = 15,
  kReadSmartAccessRestrictions = 16,
  kAcknowledgeSmartAccessRestrictions = 17,
  kReadSmartAccessLeases = 18,
  kConfigureSmartAccessRenewal = 19,
  kReadBootClock = 20,
  kConnectWithIdentity = 21,
  kCancelConnectAndConfirm = 22,
  kConfigureBoundSmartAccessRuntimeControl = 23,
  kReadTransportNetworkContext = 24,
  kStageBoundProfile = 25,
  kPromoteTransportLease = 26,
  kRevokeTransportLease = 27,
};

bool IsConnectCommand(Command command);

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
