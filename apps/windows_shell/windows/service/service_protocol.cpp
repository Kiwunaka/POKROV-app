#include "service_protocol.h"
#include "service_profile_identity.h"

#include <algorithm>
#include <charconv>
#include <cstring>

namespace pokrov::service {
namespace {

void AppendUint16(std::vector<std::uint8_t>* output, std::uint16_t value) {
  output->push_back(static_cast<std::uint8_t>(value & 0xFF));
  output->push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
}

void AppendUint32(std::vector<std::uint8_t>* output, std::uint32_t value) {
  for (int shift = 0; shift < 32; shift += 8) {
    output->push_back(static_cast<std::uint8_t>((value >> shift) & 0xFF));
  }
}

void AppendUint64(std::vector<std::uint8_t>* output, std::uint64_t value) {
  for (int shift = 0; shift < 64; shift += 8) {
    output->push_back(static_cast<std::uint8_t>((value >> shift) & 0xFF));
  }
}

std::uint16_t ReadUint16(const std::uint8_t* input) {
  return static_cast<std::uint16_t>(input[0]) |
         (static_cast<std::uint16_t>(input[1]) << 8);
}

std::uint32_t ReadUint32(const std::uint8_t* input) {
  std::uint32_t value = 0;
  for (int offset = 0; offset < 4; ++offset) {
    value |= static_cast<std::uint32_t>(input[offset]) << (offset * 8);
  }
  return value;
}

std::uint64_t ReadUint64(const std::uint8_t* input) {
  std::uint64_t value = 0;
  for (int offset = 0; offset < 8; ++offset) {
    value |= static_cast<std::uint64_t>(input[offset]) << (offset * 8);
  }
  return value;
}

bool IsBoundedAsciiControl(const std::string& value, std::size_t limit = kMaxControlBodySize) {
  return value.size() <= limit &&
         std::all_of(value.begin(), value.end(), [](unsigned char character) {
           return character >= 0x20 && character <= 0x7E;
         });
}

bool IsBoundedProfile(const std::string& value) {
  return value.size() >= 4 && value.size() <= kMaxProfileBodySize &&
         (value[0] == '0' || value[0] == '1') && value[1] == '\n' &&
         value.find('\0') == std::string::npos;
}

bool IsKnownCommand(Command command) {
  switch (command) {
    case Command::kHello:
    case Command::kStatus:
    case Command::kConnect:
    case Command::kConnectWithIdentity:
    case Command::kDisconnect:
    case Command::kCancel:
    case Command::kCancelConnectAndConfirm:
    case Command::kRecover:
    case Command::kDiagnosticState:
    case Command::kInitialize:
    case Command::kStageProfile:
    case Command::kStageBoundProfile:
    case Command::kInvalidateProfile:
    case Command::kRevokeSmartAccessLease:
    case Command::kRevokeRoutingCatalog:
    case Command::kRevokeSmartAccessPolicy:
    case Command::kRevokeRoutingCatalogService:
    case Command::kRenewSmartAccessLease:
    case Command::kConfigureSmartAccessRuntimeControl:
    case Command::kConfigureBoundSmartAccessRuntimeControl:
    case Command::kConfigureSmartAccessRenewal:
    case Command::kReadSmartAccessRestrictions:
    case Command::kAcknowledgeSmartAccessRestrictions:
    case Command::kReadSmartAccessLeases:
    case Command::kReadBootClock:
    case Command::kReadTransportNetworkContext:
    case Command::kPromoteTransportLease:
    case Command::kRevokeTransportLease:
      return true;
  }
  return false;
}

bool IsKnownStatus(Status status) {
  switch (status) {
    case Status::kNone:
    case Status::kOk:
    case Status::kInvalid:
    case Status::kUnauthorized:
    case Status::kUnsupported:
    case Status::kNotReady:
    case Status::kReplay:
    case Status::kDeadlineExceeded:
      return true;
  }
  return false;
}

bool IsValidFrame(const Frame& frame) {
  if (!IsKnownCommand(frame.command) || !IsKnownStatus(frame.status) ||
      IsZeroIdentifier(frame.correlation_id) ||
      frame.body.size() > kMaxBodySize) {
    return false;
  }

  switch (frame.kind) {
    case FrameKind::kHelloRequest:
      return frame.command == Command::kHello &&
             frame.status == Status::kNone &&
             IsZeroIdentifier(frame.session_token) &&
             IsZeroIdentifier(frame.operation_nonce) &&
             frame.deadline_unix_ms == 0 && frame.body.empty();
    case FrameKind::kRequest:
      return frame.command != Command::kHello &&
             frame.status == Status::kNone &&
             !IsZeroIdentifier(frame.session_token) &&
             !IsZeroIdentifier(frame.operation_nonce) &&
             frame.deadline_unix_ms != 0 && frame.capabilities == 0 &&
             (frame.command == Command::kConfigureBoundSmartAccessRuntimeControl
                  ? IsBoundSmartAccessRuntimeControl(frame.body)
                  : frame.command == Command::kPromoteTransportLease
                  ? DecodeTransportLeasePromotion(frame.body).has_value()
                  : frame.command == Command::kRevokeTransportLease
                  ? DecodeTransportLeaseRevocation(frame.body).has_value()
                  : frame.command == Command::kConnectWithIdentity
                  ? DecodeBoundConnect(frame.body).has_value()
                  : (frame.command == Command::kStageProfile || frame.command == Command::kStageBoundProfile)
                  ? IsBoundedProfile(frame.body)
                  : (frame.command == Command::kConnect || frame.command == Command::kRevokeRoutingCatalog ||
                         frame.command == Command::kAcknowledgeSmartAccessRestrictions || frame.command == Command::kReadSmartAccessLeases
                         ? IsProfileDigest(frame.body)
                         : (frame.command == Command::kCancel || frame.command == Command::kCancelConnectAndConfirm
                                ? DecodeCancellationTarget(frame.body).has_value()
                                : (frame.command == Command::kRevokeSmartAccessLease
                                       ? DecodeSmartAccessRevocation(frame.body).has_value()
                                       : (frame.command == Command::kRevokeSmartAccessPolicy
                                              ? IsSmartAccessPolicyRevocation(frame.body)
                                              : (frame.command == Command::kRevokeRoutingCatalogService
                                                     ? IsRoutingCatalogServiceRevocation(frame.body)
                                                     : (frame.command == Command::kRenewSmartAccessLease
                                                            ? DecodeSmartAccessRenewal(frame.body).has_value()
                                                            : (frame.command == Command::kConfigureSmartAccessRuntimeControl || frame.command == Command::kConfigureSmartAccessRenewal
                                                                   ? IsSmartAccessRuntimeControl(frame.body)
                                                                   : frame.body.empty()))))))));
    case FrameKind::kResponse:
      if (frame.status == Status::kNone ||
          IsZeroIdentifier(frame.session_token) ||
          !IsZeroIdentifier(frame.operation_nonce) ||
          frame.deadline_unix_ms != 0) {
        return false;
      }
      return (frame.command == Command::kHello || frame.capabilities == 0) &&
             IsBoundedAsciiControl(frame.body,
                 frame.command == Command::kReadSmartAccessLeases ? kMaxSmartAccessLeasesBodySize :
                 frame.command == Command::kReadSmartAccessRestrictions ? kMaxRestrictionSnapshotBodySize :
                 frame.body.rfind("phase=", 0) == 0 ? kMaxRuntimeSnapshotBodySize : kMaxControlBodySize);
  }
  return false;
}

std::optional<FrameKind> DecodeKind(std::uint16_t raw_kind) {
  switch (raw_kind) {
    case static_cast<std::uint16_t>(FrameKind::kHelloRequest):
      return FrameKind::kHelloRequest;
    case static_cast<std::uint16_t>(FrameKind::kRequest):
      return FrameKind::kRequest;
    case static_cast<std::uint16_t>(FrameKind::kResponse):
      return FrameKind::kResponse;
    default:
      return std::nullopt;
  }
}

}  // namespace

bool IsConnectCommand(Command command) {
  return command == Command::kConnect || command == Command::kConnectWithIdentity;
}

bool IsTransportNetworkContextRef(const std::string& value) {
  return value.size() == 40 && value.compare(0, 8, "network_") == 0 &&
      value.find_first_not_of("0123456789abcdef", 8) == std::string::npos;
}

std::string EncodeBoundConnect(const BoundConnectTarget& target) {
  if (!IsProfileDigest(target.core_module_sha256) || !IsProfileDigest(target.profile_digest) ||
      target.boot_ref.size() != 40 || target.boot_ref.compare(0, 8, "windows:") != 0 ||
      target.boot_ref.find_first_not_of("0123456789abcdef", 8) != std::string::npos ||
      !IsTransportNetworkContextRef(target.network_context_ref) ||
      target.deadline_elapsed_ms > 9007199254740991ULL ||
      target.deadline_elapsed_ms <= target.started_elapsed_ms ||
      target.deadline_elapsed_ms - target.started_elapsed_ms > 86400000ULL) return "";
  return target.core_module_sha256 + "|" + target.profile_digest + "|" + target.boot_ref + "|" +
      std::to_string(target.started_elapsed_ms) + "|" + std::to_string(target.deadline_elapsed_ms) + "|" +
      target.network_context_ref;
}

std::optional<BoundConnectTarget> DecodeBoundConnect(const std::string& body) {
  if (!IsBoundedAsciiControl(body)) return std::nullopt;
  std::array<std::string, 6> fields;
  std::size_t start = 0;
  for (std::size_t i = 0; i < fields.size(); ++i) {
    const auto end = body.find('|', start);
    if ((i + 1 == fields.size()) != (end == std::string::npos)) return std::nullopt;
    fields[i] = body.substr(start, end == std::string::npos ? end : end - start);
    start = end == std::string::npos ? body.size() : end + 1;
  }
  BoundConnectTarget target{fields[0], fields[1], fields[2]};
  target.network_context_ref = fields[5];
  const auto parse = [](const std::string& text, std::uint64_t* value) {
    const auto result = std::from_chars(text.data(), text.data() + text.size(), *value);
    return result.ec == std::errc{} && result.ptr == text.data() + text.size();
  };
  if (!parse(fields[3], &target.started_elapsed_ms) || !parse(fields[4], &target.deadline_elapsed_ms) ||
      EncodeBoundConnect(target) != body) return std::nullopt;
  return target;
}

std::string EncodeCancellationTarget(const CancellationTarget& target) {
  if (IsZeroIdentifier(target.session_token) || IsZeroIdentifier(target.operation_nonce)) {
    return "";
  }
  constexpr char digits[] = "0123456789abcdef";
  std::string result;
  result.reserve(64);
  for (const auto& identifier : {target.session_token, target.operation_nonce}) {
    for (const auto byte : identifier) {
      result.push_back(digits[byte >> 4]);
      result.push_back(digits[byte & 15]);
    }
  }
  return result;
}

bool IsBoundSmartAccessRuntimeControl(const std::string& body) {
  // Fixed-size private owner prefix; the remaining bytes use the existing
  // digest/config framing. Never include this body in diagnostics.
  return body.size() > 65 && body[64] == '|' &&
      DecodeCancellationTarget(body.substr(0, 64)).has_value() &&
      IsSmartAccessRuntimeControl(body.substr(65));
}

std::optional<CancellationTarget> DecodeCancellationTarget(const std::string& body) {
  if (!IsProfileDigest(body)) return std::nullopt;  // exactly 64 lower hex bytes
  const auto digit = [](char value) {
    return value <= '9' ? value - '0' : value - 'a' + 10;
  };
  CancellationTarget result;
  for (std::size_t index = 0; index < 32; ++index) {
    const auto value = static_cast<std::uint8_t>(
        digit(body[index * 2]) * 16 + digit(body[index * 2 + 1]));
    (index < 16 ? result.session_token : result.operation_nonce)[index % 16] = value;
  }
  if (IsZeroIdentifier(result.session_token) || IsZeroIdentifier(result.operation_nonce)) {
    return std::nullopt;
  }
  return result;
}

std::optional<TransportLeasePromotion> DecodeTransportLeasePromotion(const std::string& body) {
  if (body.size() != 231 || body[64] != '|' || body[129] != '|' || body[168] != '|' ||
      body[189] != '|' || body[210] != '|' ||
      !DecodeCancellationTarget(body.substr(0, 64)) ||
      !IsProfileDigest(body.substr(65, 64)) || body.substr(130, 6) != "lease_") return std::nullopt;
  const auto hex = [](char value) {
    return (value >= '0' && value <= '9') || (value >= 'a' && value <= 'f');
  };
  if (!std::all_of(body.begin() + 136, body.begin() + 168, hex)) return std::nullopt;
  for (const auto start : {169U, 190U, 211U}) {
    for (std::size_t offset = 0; offset < 20; ++offset) {
      const char value = body[start + offset];
      if (offset == 4 || offset == 7) { if (value != '-') return std::nullopt; }
      else if (offset == 10) { if (value != 'T') return std::nullopt; }
      else if (offset == 13 || offset == 16) { if (value != ':') return std::nullopt; }
      else if (offset == 19) { if (value != 'Z') return std::nullopt; }
      else if (value < '0' || value > '9') return std::nullopt;
    }
  }
  return TransportLeasePromotion{*DecodeCancellationTarget(body.substr(0, 64)),
      body.substr(65, 64), body.substr(130, 38), body.substr(169, 20),
      body.substr(190, 20), body.substr(211, 20)};
}

std::string EncodeTransportLeasePromotion(const TransportLeasePromotion& target) {
  const auto body = EncodeCancellationTarget(target.target) + "|" + target.profile_digest + "|" +
      target.endpoint_lease_ref + "|" + target.issued_at + "|" +
      target.new_flows_until + "|" + target.active_flows_until;
  return DecodeTransportLeasePromotion(body) ? body : "";
}

std::optional<TransportLeaseRevocation> DecodeTransportLeaseRevocation(const std::string& body) {
  if (body.size() != 170 || body[64] != '|' || body[129] != '|' || body[168] != '|' ||
      (body[169] != '0' && body[169] != '1') ||
      !DecodeCancellationTarget(body.substr(0, 64)) ||
      !IsProfileDigest(body.substr(65, 64)) || body.substr(130, 6) != "lease_" ||
      !std::all_of(body.begin() + 136, body.begin() + 168, [](char value) {
        return (value >= '0' && value <= '9') || (value >= 'a' && value <= 'f');
      })) return std::nullopt;
  return TransportLeaseRevocation{*DecodeCancellationTarget(body.substr(0, 64)),
      body.substr(65, 64), body.substr(130, 38), body[169] == '1'};
}

std::string EncodeTransportLeaseRevocation(const TransportLeaseRevocation& target) {
  const auto body = EncodeCancellationTarget(target.target) + "|" + target.profile_digest + "|" +
      target.endpoint_lease_ref + "|" + (target.terminate_active ? "1" : "0");
  return DecodeTransportLeaseRevocation(body) ? body : "";
}

std::optional<SmartAccessRevocationTarget> DecodeSmartAccessRevocation(const std::string& body) {
  if (body.size() != 99 || body[64] != ':' || body[97] != ':' ||
      (body[98] != '0' && body[98] != '1') || !IsProfileDigest(body.substr(0, 64)) ||
      !std::all_of(body.begin() + 65, body.begin() + 97, [](char value) {
        return (value >= '0' && value <= '9') || (value >= 'a' && value <= 'f');
      })) return std::nullopt;
  return SmartAccessRevocationTarget{body.substr(0, 64), body.substr(65, 32), body[98] == '1'};
}

bool IsSmartAccessPolicyRevocation(const std::string& body) {
  return body.size() == 66 && body[64] == ':' &&
      (body[65] == '0' || body[65] == '1') && IsProfileDigest(body.substr(0, 64));
}

bool IsRoutingCatalogServiceRevocation(const std::string& body) {
  if (body.size() < 66 || body.size() > 129 || body[64] != ':' ||
      !IsProfileDigest(body.substr(0, 64))) return false;
  const auto alphanumeric = [](char value) {
    return (value >= 'a' && value <= 'z') || (value >= '0' && value <= '9');
  };
  return alphanumeric(body[65]) && std::all_of(body.begin() + 65, body.end(), [alphanumeric](char value) {
    return alphanumeric(value) || value == '.' || value == '_' || value == '-';
  });
}

std::string EncodeSmartAccessRevocation(const SmartAccessRevocationTarget& target) {
  const auto body = target.profile_digest + ":" + target.lease_id +
                    (target.terminate_active ? ":1" : ":0");
  return DecodeSmartAccessRevocation(body) ? body : "";
}

bool IsSmartAccessRuntimeControl(const std::string& body) {
  // Sensitive, memory-only command: 64-byte identity, separator, bounded JSON.
  // Core parses the JSON and checks its binding against this exact identity.
  return body.size() > 65 && body.size() <= 65 + 16384 && body[64] == '|' &&
         IsProfileDigest(body.substr(0, 64)) && body.find('\0') == std::string::npos;
}

std::optional<SmartAccessRenewalTarget> DecodeSmartAccessRenewal(const std::string& body) {
  if (body.size() != 193 || body[64] != '|' || body[97] != '|' || body[130] != '|' ||
      body[151] != '|' || body[172] != '|' || !IsProfileDigest(body.substr(0, 64))) return std::nullopt;
  const auto hex = [](char value) {
    return (value >= '0' && value <= '9') || (value >= 'a' && value <= 'f');
  };
  if (!std::all_of(body.begin() + 65, body.begin() + 97, hex) ||
      !std::all_of(body.begin() + 98, body.begin() + 130, hex)) return std::nullopt;
  for (const auto start : {131U, 152U, 173U}) {
    for (std::size_t offset = 0; offset < 20; ++offset) {
      const char value = body[start + offset];
      if (offset == 4 || offset == 7) { if (value != '-') return std::nullopt; }
      else if (offset == 10) { if (value != 'T') return std::nullopt; }
      else if (offset == 13 || offset == 16) { if (value != ':') return std::nullopt; }
      else if (offset == 19) { if (value != 'Z') return std::nullopt; }
      else if (value < '0' || value > '9') return std::nullopt;
    }
  }
  // Core validates calendar values, freshness, maximum lifetime and expected
  // generation atomically. No profile, endpoint or reusable credential travels here.
  return SmartAccessRenewalTarget{body.substr(0, 64), body.substr(65, 32), body.substr(98, 32),
      body.substr(131, 20), body.substr(152, 20), body.substr(173, 20)};
}

std::string EncodeSmartAccessRenewal(const SmartAccessRenewalTarget& target) {
  const auto body = target.profile_digest + "|" + target.expected_lease_id + "|" + target.next_lease_id + "|" +
      target.issued_at + "|" + target.new_flows_until + "|" + target.active_flows_until;
  return DecodeSmartAccessRenewal(body) ? body : "";
}

bool IsZeroIdentifier(const Identifier& value) {
  return std::all_of(value.begin(), value.end(),
                     [](std::uint8_t byte) { return byte == 0; });
}

std::optional<std::size_t> ExpectedFrameSize(const void* header,
                                             std::size_t header_size) {
  if (header == nullptr || header_size != kFrameHeaderSize) {
    return std::nullopt;
  }
  const auto* bytes = static_cast<const std::uint8_t*>(header);
  const auto body_size = ReadUint32(bytes + 12);
  if (ReadUint32(bytes) != kFrameMagic ||
      ReadUint16(bytes + 4) != kProtocolVersion ||
      body_size > kMaxBodySize) {
    return std::nullopt;
  }
  return kFrameHeaderSize + body_size;
}

std::vector<std::uint8_t> Encode(const Frame& frame) {
  if (!IsValidFrame(frame)) {
    return {};
  }

  std::vector<std::uint8_t> output;
  output.reserve(kFrameHeaderSize + frame.body.size());
  AppendUint32(&output, kFrameMagic);
  AppendUint16(&output, kProtocolVersion);
  AppendUint16(&output, static_cast<std::uint16_t>(frame.kind));
  AppendUint16(&output, static_cast<std::uint16_t>(frame.command));
  AppendUint16(&output, static_cast<std::uint16_t>(frame.status));
  AppendUint32(&output, static_cast<std::uint32_t>(frame.body.size()));
  output.insert(output.end(), frame.correlation_id.begin(),
                frame.correlation_id.end());
  output.insert(output.end(), frame.session_token.begin(),
                frame.session_token.end());
  output.insert(output.end(), frame.operation_nonce.begin(),
                frame.operation_nonce.end());
  AppendUint64(&output, frame.deadline_unix_ms);
  AppendUint64(&output, frame.capabilities);
  output.insert(output.end(), frame.body.begin(), frame.body.end());
  return output;
}

std::optional<Frame> Decode(const void* frame, std::size_t frame_size) {
  if (frame == nullptr || frame_size < kFrameHeaderSize ||
      frame_size > kMaxFrameSize) {
    return std::nullopt;
  }
  const auto* bytes = static_cast<const std::uint8_t*>(frame);
  const auto expected_size = ExpectedFrameSize(bytes, kFrameHeaderSize);
  const auto kind = DecodeKind(ReadUint16(bytes + 6));
  if (!expected_size.has_value() || *expected_size != frame_size ||
      !kind.has_value()) {
    return std::nullopt;
  }

  Frame decoded{
      *kind,
      static_cast<Command>(ReadUint16(bytes + 8)),
      static_cast<Status>(ReadUint16(bytes + 10)),
  };
  std::memcpy(decoded.correlation_id.data(), bytes + 16,
              decoded.correlation_id.size());
  std::memcpy(decoded.session_token.data(), bytes + 32,
              decoded.session_token.size());
  std::memcpy(decoded.operation_nonce.data(), bytes + 48,
              decoded.operation_nonce.size());
  decoded.deadline_unix_ms = ReadUint64(bytes + 64);
  decoded.capabilities = ReadUint64(bytes + 72);
  decoded.body.assign(reinterpret_cast<const char*>(bytes + kFrameHeaderSize),
                      frame_size - kFrameHeaderSize);
  if (!IsValidFrame(decoded)) {
    return std::nullopt;
  }
  return decoded;
}

}  // namespace pokrov::service
