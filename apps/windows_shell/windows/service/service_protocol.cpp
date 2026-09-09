#include "service_protocol.h"
#include "service_profile_identity.h"

#include <algorithm>
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

bool IsBoundedAsciiControl(const std::string& value) {
  return value.size() <= kMaxControlBodySize &&
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
    case Command::kDisconnect:
    case Command::kCancel:
    case Command::kRecover:
    case Command::kDiagnosticState:
    case Command::kInitialize:
    case Command::kStageProfile:
    case Command::kInvalidateProfile:
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
             (frame.command == Command::kStageProfile
                  ? IsBoundedProfile(frame.body)
                  : (frame.command == Command::kConnect
                         ? IsProfileDigest(frame.body)
                         : (frame.command == Command::kCancel
                                ? DecodeCancellationTarget(frame.body).has_value()
                                : frame.body.empty())));
    case FrameKind::kResponse:
      if (frame.status == Status::kNone ||
          IsZeroIdentifier(frame.session_token) ||
          !IsZeroIdentifier(frame.operation_nonce) ||
          frame.deadline_unix_ms != 0) {
        return false;
      }
      return (frame.command == Command::kHello || frame.capabilities == 0) &&
             IsBoundedAsciiControl(frame.body);
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
