#include "service_events.h"

#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <iostream>
#include <sstream>
#include <string>

namespace {

int failures = 0;

void Expect(bool condition, const char* message) {
  if (!condition) {
    std::cerr << message << '\n';
    ++failures;
  }
}

std::wstring CreateTestRoot() {
  wchar_t temporary[MAX_PATH]{};
  wchar_t candidate[MAX_PATH]{};
  if (::GetTempPathW(MAX_PATH, temporary) == 0 ||
      ::GetTempFileNameW(temporary, L"pke", 0, candidate) == 0) {
    return L"";
  }
  ::DeleteFileW(candidate);
  return ::CreateDirectoryW(candidate, nullptr) ? candidate : L"";
}

std::uint64_t FileSize(const std::wstring& path) {
  WIN32_FILE_ATTRIBUTE_DATA attributes{};
  if (::GetFileAttributesExW(path.c_str(), GetFileExInfoStandard,
                             &attributes) == FALSE) {
    return 0;
  }
  ULARGE_INTEGER size{};
  size.LowPart = attributes.nFileSizeLow;
  size.HighPart = attributes.nFileSizeHigh;
  return size.QuadPart;
}

std::string ReadFile(const std::wstring& path) {
  HANDLE file = ::CreateFileW(path.c_str(), GENERIC_READ,
                              FILE_SHARE_READ | FILE_SHARE_WRITE |
                                  FILE_SHARE_DELETE,
                              nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                              nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return "";
  }
  LARGE_INTEGER size{};
  if (::GetFileSizeEx(file, &size) == FALSE || size.QuadPart < 0 ||
      static_cast<std::uint64_t>(size.QuadPart) >
          pokrov::service::kMaximumServiceEventJournalSize) {
    ::CloseHandle(file);
    return "";
  }
  std::string content(static_cast<std::size_t>(size.QuadPart), '\0');
  DWORD read = 0;
  const bool success =
      content.empty() ||
      (::ReadFile(file, content.data(), static_cast<DWORD>(content.size()),
                  &read, nullptr) != FALSE &&
       read == content.size());
  ::CloseHandle(file);
  return success ? content : "";
}

void ValidateClosedLines(const std::string& content) {
  std::istringstream input(content);
  std::string line;
  while (std::getline(input, line)) {
    const bool service_event =
        line.rfind("POKROV_SERVICE_EVENT_V1|", 0) == 0;
    const bool core_event = line.rfind("POKROV_CORE_EVENT_V1|", 0) == 0;
    Expect(service_event || core_event,
           "event journal accepted an unknown wire version");
    Expect(std::count(line.begin(), line.end(), '|') ==
               (service_event ? 7 : 14),
           "event journal line escaped its closed field count");
    Expect(line.find("profile_payload") == std::string::npos &&
               line.find("session_token") == std::string::npos &&
               line.find("operation_nonce") == std::string::npos &&
               line.find("api.pokrov") == std::string::npos,
           "event journal retained forbidden runtime material");
  }
}

void TestClosedBoundedJournal() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  Expect(!root.empty(), "event journal test root was not created");
  if (root.empty()) {
    return;
  }
  const auto current = root + L"\\" + kServiceEventJournalName;
  const auto previous = root + L"\\" + kPreviousServiceEventJournalName;
  {
    auto journal = CreateServiceEventJournal(root);
    Expect(journal != nullptr, "event journal was not created");
    if (journal != nullptr) {
      Identifier correlation{};
      for (std::size_t index = 0; index < correlation.size(); ++index) {
        correlation[index] = static_cast<std::uint8_t>(index + 1);
      }
      Expect(journal->Record(ServiceEvent::kServiceRunning,
                             ServiceEventOutcome::kSucceeded),
             "service lifecycle event was not durable");
      Expect(journal->RecordSystemBoot(0x0123456789abcdefULL),
             "system boot breadcrumb was not durable");
      Expect(journal->RecordIpcRequest(Command::kStageProfile, correlation),
             "IPC request span was not durable");
      Expect(journal->RecordIpcResponse(Command::kStageProfile,
                                        Status::kUnauthorized, correlation),
             "IPC response span was not durable");
      Expect(journal->RecordCoreOperationalEvent(CoreOperationalEventRecord{
                 1,
                 1,
                 "2026-08-21T12:00:00Z",
                 "018f4f2a-6d58-4c11-8c27-4fb77bd28c15",
                 "57ba1c00-f8a9-4b76-a3dc-d44a6d7cff33",
                 7,
                 4,
                 "core.runtime.start",
                 "core",
                 "start",
                 "info",
                 "succeeded",
                 "",
                 "core_start",
             }),
             "Core operational event was not durable");
      for (int index = 0; index < 2700; ++index) {
        Expect(journal->Record(ServiceEvent::kRuntimeNetworkRestore,
                               index % 2 == 0
                                   ? ServiceEventOutcome::kAttempted
                                   : ServiceEventOutcome::kSucceeded),
               "bounded event append failed");
      }
    }
  }

  const auto current_size = FileSize(current);
  const auto previous_size = FileSize(previous);
  Expect(current_size > 0 && previous_size > 0,
         "event journal did not rotate");
  Expect(current_size <= kMaximumServiceEventJournalSize &&
             previous_size <= kMaximumServiceEventJournalSize,
         "event journal exceeded its bounded files");
  const auto previous_content = ReadFile(previous);
  const auto current_content = ReadFile(current);
  const auto combined = previous_content + current_content;
  Expect(combined.find("service_boot_observed|succeeded|none|none|"
                       "boot-0123456789abcdef") != std::string::npos,
         "event journal did not retain an opaque boot correlation");
  Expect(combined.find("ipc_request|attempted|stage_profile|none|"
                       "0102030405060708090a0b0c0d0e0f10") !=
             std::string::npos,
         "event journal did not retain the request correlation span");
  Expect(combined.find(
             "POKROV_CORE_EVENT_V1|1|1|2026-08-21T12:00:00Z|"
             "018f4f2a-6d58-4c11-8c27-4fb77bd28c15|"
             "57ba1c00-f8a9-4b76-a3dc-d44a6d7cff33|7|4|"
             "core.runtime.start|core|start|info|succeeded|none|core_start") !=
             std::string::npos,
         "event journal did not retain the closed Core correlation");
  ValidateClosedLines(previous_content);
  ValidateClosedLines(current_content);

  ::DeleteFileW(current.c_str());
  ::DeleteFileW(previous.c_str());
  ::RemoveDirectoryW(root.c_str());
}

}  // namespace

int main() {
  TestClosedBoundedJournal();
  if (failures != 0) {
    std::cerr << failures << " service event journal checks failed\n";
    return 1;
  }
  std::cout << "service event journal checks passed\n";
  return 0;
}
