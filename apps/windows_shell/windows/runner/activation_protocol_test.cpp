#include "activation_protocol.h"

#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

int failures = 0;

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
  using pokrov::activation::Command;
  using pokrov::activation::Message;

  const Message show{Command::kShow, ""};
  const auto show_frame = pokrov::activation::Encode(show);
  Expect(show_frame.size() == pokrov::activation::kFrameHeaderSize,
         "show frame has an unexpected size");
  Expect(pokrov::activation::Decode(show_frame.data(), show_frame.size()) ==
             show,
         "show frame did not round-trip");

  const Message acquisition{
      Command::kAcquisitionContinue,
      "pokrov://acquisition/continue?result=success&state=test"};
  const auto acquisition_frame = pokrov::activation::Encode(acquisition);
  Expect(pokrov::activation::Decode(acquisition_frame.data(),
                                    acquisition_frame.size()) == acquisition,
         "acquisition frame did not round-trip");
}

void TestRejectsMalformedFrames() {
  using pokrov::activation::Command;
  using pokrov::activation::Message;

  Expect(pokrov::activation::Encode(
             Message{Command::kShow, "unexpected"})
             .empty(),
         "show accepted a payload");
  Expect(pokrov::activation::Encode(Message{
             Command::kAcquisitionContinue, "https://example.invalid/"})
             .empty(),
         "acquisition accepted another origin");
  Expect(pokrov::activation::Encode(Message{
             Command::kAcquisitionContinue,
             "pokrov://acquisition/continue?state=line\nbreak"})
             .empty(),
         "acquisition accepted control characters");

  auto frame = pokrov::activation::Encode(Message{Command::kShow, ""});
  auto future = frame;
  WriteUint16(&future, 4, pokrov::activation::kFrameVersion + 1);
  Expect(!pokrov::activation::Decode(future.data(), future.size()),
         "future frame version was accepted");

  auto unknown = frame;
  WriteUint16(&unknown, 6, 99);
  Expect(!pokrov::activation::Decode(unknown.data(), unknown.size()),
         "unknown command was accepted");

  auto reserved = frame;
  reserved[12] = 1;
  Expect(!pokrov::activation::Decode(reserved.data(), reserved.size()),
         "non-zero reserved field was accepted");

  frame.push_back(0);
  Expect(!pokrov::activation::Decode(frame.data(), frame.size()),
         "trailing data was accepted");
  Expect(!pokrov::activation::Decode(nullptr, 0),
         "null frame was accepted");
}

}  // namespace

int main() {
  TestRoundTrips();
  TestRejectsMalformedFrames();
  return failures == 0 ? 0 : 1;
}
