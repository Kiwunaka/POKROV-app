#include "activation_protocol.h"

#include <algorithm>

namespace pokrov::activation {
namespace {

constexpr char kAcquisitionPrefix[] = "pokrov://acquisition/continue?";

void AppendUint16(std::vector<std::uint8_t>* output, std::uint16_t value) {
  output->push_back(static_cast<std::uint8_t>(value & 0xFF));
  output->push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
}

void AppendUint32(std::vector<std::uint8_t>* output, std::uint32_t value) {
  output->push_back(static_cast<std::uint8_t>(value & 0xFF));
  output->push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
  output->push_back(static_cast<std::uint8_t>((value >> 16) & 0xFF));
  output->push_back(static_cast<std::uint8_t>((value >> 24) & 0xFF));
}

std::uint16_t ReadUint16(const std::uint8_t* input) {
  return static_cast<std::uint16_t>(input[0]) |
         (static_cast<std::uint16_t>(input[1]) << 8);
}

std::uint32_t ReadUint32(const std::uint8_t* input) {
  return static_cast<std::uint32_t>(input[0]) |
         (static_cast<std::uint32_t>(input[1]) << 8) |
         (static_cast<std::uint32_t>(input[2]) << 16) |
         (static_cast<std::uint32_t>(input[3]) << 24);
}

bool IsBoundedAscii(const std::string& value) {
  return !value.empty() && value.size() <= kMaxPayloadSize &&
         std::all_of(value.begin(), value.end(), [](unsigned char character) {
           return character >= 0x21 && character <= 0x7E;
         });
}

bool IsValidMessage(const Message& message) {
  switch (message.command) {
    case Command::kShow:
      return message.payload.empty();
    case Command::kAcquisitionContinue:
      return IsPokrovAcquisitionUri(message.payload);
  }
  return false;
}

}  // namespace

bool IsPokrovAcquisitionUri(const std::string& value) {
  return IsBoundedAscii(value) && value.rfind(kAcquisitionPrefix, 0) == 0;
}

std::vector<std::uint8_t> Encode(const Message& message) {
  if (!IsValidMessage(message)) {
    return {};
  }

  std::vector<std::uint8_t> frame;
  frame.reserve(kFrameHeaderSize + message.payload.size());
  AppendUint32(&frame, kFrameMagic);
  AppendUint16(&frame, kFrameVersion);
  AppendUint16(&frame, static_cast<std::uint16_t>(message.command));
  AppendUint32(&frame, static_cast<std::uint32_t>(message.payload.size()));
  AppendUint32(&frame, 0);
  frame.insert(frame.end(), message.payload.begin(), message.payload.end());
  return frame;
}

std::optional<Message> Decode(const void* frame, std::size_t frame_size) {
  if (frame == nullptr || frame_size < kFrameHeaderSize ||
      frame_size > kMaxFrameSize) {
    return std::nullopt;
  }

  const auto* bytes = static_cast<const std::uint8_t*>(frame);
  const auto magic = ReadUint32(bytes);
  const auto version = ReadUint16(bytes + 4);
  const auto raw_command = ReadUint16(bytes + 6);
  const auto payload_size = ReadUint32(bytes + 8);
  const auto reserved = ReadUint32(bytes + 12);
  if (magic != kFrameMagic || version != kFrameVersion || reserved != 0 ||
      payload_size > kMaxPayloadSize ||
      frame_size != kFrameHeaderSize + payload_size) {
    return std::nullopt;
  }

  Command command;
  switch (raw_command) {
    case static_cast<std::uint16_t>(Command::kShow):
      command = Command::kShow;
      break;
    case static_cast<std::uint16_t>(Command::kAcquisitionContinue):
      command = Command::kAcquisitionContinue;
      break;
    default:
      return std::nullopt;
  }

  const auto* payload_begin =
      reinterpret_cast<const char*>(bytes + kFrameHeaderSize);
  Message message{command, std::string(payload_begin, payload_size)};
  if (!IsValidMessage(message)) {
    return std::nullopt;
  }
  return message;
}

}  // namespace pokrov::activation
