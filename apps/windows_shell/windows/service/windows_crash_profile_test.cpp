#include "windows_crash_profile.h"

#include <array>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <string>

namespace {

int failures = 0;

void Expect(bool condition, const char* message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << "\n";
    ++failures;
  }
}

std::size_t Count(const std::string& value, const std::string& needle) {
  std::size_t count = 0;
  std::size_t position = 0;
  while ((position = value.find(needle, position)) != std::string::npos) {
    ++count;
    position += needle.size();
  }
  return count;
}

}  // namespace

int main() {
  using pokrov::windows_crash::FormatWindowsCrashRecord;
  using pokrov::windows_crash::WindowsCrashFrame;
  using pokrov::windows_crash::WindowsCrashModule;
  using pokrov::windows_crash::WindowsCrashProcess;
  using pokrov::windows_crash::kMaximumWindowsCrashFrames;
  using pokrov::windows_crash::kMaximumWindowsCrashRecordBytes;

  const std::array<WindowsCrashFrame, 6> frames = {{
      {WindowsCrashModule::kUi, 0x1234},
      {WindowsCrashModule::kFlutter, 0x5678},
      {WindowsCrashModule::kCore, 0x9abc},
      {WindowsCrashModule::kApp, 0xdef0},
      {WindowsCrashModule::kUnknown, 0xfeedfacecafebeefULL},
      {WindowsCrashModule::kService, 0x42},
  }};
  std::array<char, kMaximumWindowsCrashRecordBytes> output{};
  const auto size = FormatWindowsCrashRecord(
      WindowsCrashProcess::kUi, 0xc0000005U, 133700000000000000ULL,
      frames.data(), frames.size(), output.data(), output.size());
  const std::string record(output.data(), size);
  Expect(size > 0, "safe crash record was not formatted");
  Expect(record.rfind("POKROV_WINDOWS_CRASH_V1|", 0) == 0,
         "safe crash record version is missing");
  Expect(record.find("process=ui") != std::string::npos,
         "safe crash record process role is missing");
  Expect(record.find("exception=0xc0000005") != std::string::npos,
         "safe crash record exception code is missing");
  Expect(record.find("ui+0x1234") != std::string::npos,
         "UI-relative frame is missing");
  Expect(record.find("flutter+0x5678") != std::string::npos,
         "Flutter-relative frame is missing");
  Expect(record.find("core+0x9abc") != std::string::npos,
         "Core-relative frame is missing");
  Expect(record.find("app+0xdef0") != std::string::npos,
         "app-relative frame is missing");
  Expect(record.find("service+0x42") != std::string::npos,
         "service-relative frame is missing");
  Expect(record.find("feedfacecafebeef") == std::string::npos,
         "unknown absolute address escaped the allowlist");
  for (const auto* forbidden : {"C:\\", "\\\\", "token", "profile=",
                                "endpoint", "command_line", "register=",
                                "heap", "memory_dump"}) {
    Expect(record.find(forbidden) == std::string::npos,
           "safe crash record retained forbidden runtime material");
  }

  std::array<WindowsCrashFrame, kMaximumWindowsCrashFrames + 8> many_frames{};
  pokrov::windows_crash::WindowsCrashDiagnostic projected;
  Expect(pokrov::windows_crash::ProjectWindowsCrashRecord(record, WindowsCrashProcess::kUi, &projected),
         "closed UI record did not project");
  Expect(projected.error_code == "CRASH-001" && projected.signature.size() == 64,
         "crash projection has no closed code/hash");
  auto later = record;
  later.replace(later.find("133700000000000000"), 18, "133700000010000000");
  pokrov::windows_crash::WindowsCrashDiagnostic next;
  Expect(pokrov::windows_crash::ProjectWindowsCrashRecord(later, WindowsCrashProcess::kUi, &next) &&
         next.signature == projected.signature && next.occurred_at_unix_ms != projected.occurred_at_unix_ms,
         "crash signature depends on capture time");
  Expect(!pokrov::windows_crash::ProjectWindowsCrashRecord(record, WindowsCrashProcess::kService, &next),
         "UI record crossed service boundary");
  for (const auto& corrupt : {record + "token=fixture-canary", std::string(2048, 'x'),
                              std::string("POKROV_WINDOWS_CRASH_V1|time=1|process=ui|exception=0xc0000005|frames=none\n")}) {
    Expect(!pokrov::windows_crash::ProjectWindowsCrashRecord(corrupt, WindowsCrashProcess::kUi, &next),
           "untrusted crash record was projected");
  }
  const auto wire = pokrov::windows_crash::EncodeWindowsCrashDiagnostics({projected, projected});
  std::vector<pokrov::windows_crash::WindowsCrashDiagnostic> decoded;
  Expect(pokrov::windows_crash::DecodeWindowsCrashDiagnostics(wire, &decoded) && decoded.size() == 2 &&
         decoded[0].signature == projected.signature && wire.find("frames") == std::string::npos,
         "bounded hashed crash IPC did not roundtrip");
  Expect(!pokrov::windows_crash::DecodeWindowsCrashDiagnostics(wire + wire.substr(10), &decoded),
         "crash IPC exceeded two records");
  Expect(pokrov::windows_crash::DecodeWindowsCrashDiagnostics("crashes_v1", &decoded) && decoded.empty(),
         "empty crash state was not distinguished from failure");
  for (std::size_t index = 0; index < many_frames.size(); ++index) {
    many_frames[index] = {WindowsCrashModule::kUi, index + 1};
  }
  output.fill('\0');
  const auto bounded_size = FormatWindowsCrashRecord(
      WindowsCrashProcess::kService, 0x80000003U, 1, many_frames.data(),
      many_frames.size(), output.data(), output.size());
  const std::string bounded(output.data(), bounded_size);
  Expect(Count(bounded, "ui+0x") == kMaximumWindowsCrashFrames,
         "safe crash record exceeded or missed the frame cap");
  Expect(bounded.size() < kMaximumWindowsCrashRecordBytes,
         "safe crash record exceeded its fixed buffer");

  std::array<char, 16> too_small{};
  Expect(FormatWindowsCrashRecord(WindowsCrashProcess::kUi, 0, 0, nullptr, 0,
                                  too_small.data(), too_small.size()) == 0,
         "undersized crash record buffer did not fail closed");
  Expect(too_small[0] == '\0',
         "failed crash record formatter retained partial output");

  if (failures != 0) {
    std::cerr << failures << " Windows crash profile checks failed\n";
    return 1;
  }
  std::cout << "Windows crash profile checks passed\n";
  return 0;
}
