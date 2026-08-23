#ifndef RUNNER_ACTIVATION_PROTOCOL_H_
#define RUNNER_ACTIVATION_PROTOCOL_H_

#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace pokrov::activation {

constexpr std::uint32_t kFrameMagic = 0x41524B50;
constexpr std::uint16_t kFrameVersion = 1;
constexpr std::size_t kFrameHeaderSize = 16;
constexpr std::size_t kMaxPayloadSize = 512;
constexpr std::size_t kMaxFrameSize = kFrameHeaderSize + kMaxPayloadSize;

enum class Command : std::uint16_t {
  kShow = 1,
  kAcquisitionContinue = 2,
};

struct Message {
  Command command;
  std::string payload;

  bool operator==(const Message& other) const {
    return command == other.command && payload == other.payload;
  }
};

bool IsPokrovAcquisitionUri(const std::string& value);
std::vector<std::uint8_t> Encode(const Message& message);
std::optional<Message> Decode(const void* frame, std::size_t frame_size);

}  // namespace pokrov::activation

#endif  // RUNNER_ACTIVATION_PROTOCOL_H_
