#include <windows.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <optional>
#include <string>
#include <vector>

#include "service_protocol.h"
#include "service_server.h"

namespace {

int failures = 0;

void Expect(bool condition, const char* message) {
  if (!condition) {
    std::cerr << message << '\n';
    ++failures;
  }
}

pokrov::service::Identifier MakeIdentifier(std::uint8_t seed) {
  pokrov::service::Identifier value{};
  for (std::size_t index = 0; index < value.size(); ++index) {
    value[index] = static_cast<std::uint8_t>(seed + index);
  }
  return value;
}

std::uint64_t UnixTimeMilliseconds() {
  FILETIME file_time{};
  ::GetSystemTimeAsFileTime(&file_time);
  ULARGE_INTEGER ticks{};
  ticks.LowPart = file_time.dwLowDateTime;
  ticks.HighPart = file_time.dwHighDateTime;
  return (ticks.QuadPart - 116444736000000000ULL) / 10000ULL;
}

bool TransferExact(HANDLE pipe, void* buffer, std::size_t size, bool write) {
  auto* bytes = static_cast<std::uint8_t*>(buffer);
  std::size_t offset = 0;
  while (offset < size) {
    DWORD transferred = 0;
    const DWORD chunk = static_cast<DWORD>(size - offset);
    const BOOL success = write
                             ? ::WriteFile(pipe, bytes + offset, chunk,
                                           &transferred, nullptr)
                             : ::ReadFile(pipe, bytes + offset, chunk,
                                          &transferred, nullptr);
    if (!success || transferred == 0) {
      return false;
    }
    offset += transferred;
  }
  return true;
}

bool WriteFrame(HANDLE pipe, const pokrov::service::Frame& frame) {
  auto bytes = pokrov::service::Encode(frame);
  return !bytes.empty() &&
         TransferExact(pipe, bytes.data(), bytes.size(), true);
}

std::optional<pokrov::service::Frame> ReadFrame(HANDLE pipe) {
  std::array<std::uint8_t, pokrov::service::kFrameHeaderSize> header{};
  if (!TransferExact(pipe, header.data(), header.size(), false)) {
    return std::nullopt;
  }
  const auto expected =
      pokrov::service::ExpectedFrameSize(header.data(), header.size());
  if (!expected.has_value()) {
    return std::nullopt;
  }
  std::vector<std::uint8_t> bytes(*expected);
  std::copy(header.begin(), header.end(), bytes.begin());
  if (bytes.size() > header.size() &&
      !TransferExact(pipe, bytes.data() + header.size(),
                     bytes.size() - header.size(), false)) {
    return std::nullopt;
  }
  return pokrov::service::Decode(bytes.data(), bytes.size());
}

std::wstring SiblingServicePath() {
  std::wstring path(32768, L'\0');
  const DWORD length = ::GetModuleFileNameW(
      nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) {
    return L"";
  }
  path.resize(length);
  const auto separator = path.find_last_of(L"\\/");
  if (separator == std::wstring::npos) {
    return L"";
  }
  return path.substr(0, separator + 1) + L"pokrov_service.exe";
}

bool WaitForPipe(const std::wstring& pipe_name) {
  for (int attempt = 0; attempt < 100; ++attempt) {
    if (::WaitNamedPipeW(pipe_name.c_str(), 50)) {
      return true;
    }
    ::Sleep(50);
  }
  return false;
}

}  // namespace

int wmain() {
  using namespace pokrov::service;
  const auto service_path = SiblingServicePath();
  const auto pipe_name = std::wstring(kTestPipePrefix) +
                         std::to_wstring(::GetCurrentProcessId());
  Expect(!service_path.empty(), "service binary path was unavailable");
  Expect(::SetEnvironmentVariableW(L"POKROV_SERVICE_TEST_MODE", L"1") !=
             FALSE,
         "test mode environment was unavailable");

  std::wstring command =
      L"\"" + service_path + L"\" --test-reject-then-serve \"" +
      pipe_name + L"\"";
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  const BOOL started = ::CreateProcessW(
      service_path.c_str(), command.data(), nullptr, nullptr, FALSE,
      CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process);
  Expect(started != FALSE, "service test process did not start");
  if (!started) {
    return 1;
  }

  HANDLE rejected_pipe = INVALID_HANDLE_VALUE;
  if (WaitForPipe(pipe_name)) {
    rejected_pipe = ::CreateFileW(pipe_name.c_str(),
                                  GENERIC_READ | GENERIC_WRITE, 0, nullptr,
                                  OPEN_EXISTING, 0, nullptr);
  }
  Expect(rejected_pipe != INVALID_HANDLE_VALUE,
         "pre-hello client could not open secured pipe");
  if (rejected_pipe != INVALID_HANDLE_VALUE) {
    ::CloseHandle(rejected_pipe);
  }

  HANDLE pipe = INVALID_HANDLE_VALUE;
  if (WaitForPipe(pipe_name)) {
    pipe = ::CreateFileW(pipe_name.c_str(), GENERIC_READ | GENERIC_WRITE, 0,
                         nullptr, OPEN_EXISTING, 0, nullptr);
  }
  Expect(pipe != INVALID_HANDLE_VALUE, "owner could not open secured pipe");
  if (pipe == INVALID_HANDLE_VALUE) {
    std::cerr << "pipe open error=" << ::GetLastError() << '\n';
  }
  if (pipe != INVALID_HANDLE_VALUE) {
    const Frame hello{
        FrameKind::kHelloRequest,
        Command::kHello,
        Status::kNone,
        MakeIdentifier(1),
        {},
        {},
        0,
        kCapabilityProtocolV1 | kCapabilityStatus |
            kCapabilityRuntimeControl,
        "",
    };
    Expect(WriteFrame(pipe, hello), "hello write failed");
    const auto hello_response = ReadFrame(pipe);
    Expect(hello_response.has_value(), "hello response was unavailable");
    if (hello_response.has_value()) {
      Expect(hello_response->status == Status::kOk,
             "compatible hello was rejected");
      Expect(hello_response->capabilities ==
                 (kCapabilityProtocolV1 | kCapabilityStatus |
                  kCapabilityRuntimeControl),
             "service advertised unsupported capabilities");
      Expect(!IsZeroIdentifier(hello_response->session_token),
             "service omitted the session token");

      const Frame status_request{
          FrameKind::kRequest,
          Command::kStatus,
          Status::kNone,
          MakeIdentifier(2),
          hello_response->session_token,
          MakeIdentifier(3),
          UnixTimeMilliseconds() + 30000,
          0,
          "",
      };
      Expect(WriteFrame(pipe, status_request), "status write failed");
      const auto status_response = ReadFrame(pipe);
      Expect(status_response.has_value() &&
                 status_response->status == Status::kOk &&
                 status_response->body.find("phase=artifact_ready") !=
                     std::string::npos &&
                 status_response->body.find("core_egress_validated=0") !=
                     std::string::npos &&
                 status_response->body.find("dns_ready=0") !=
                     std::string::npos,
             "status response was not bounded and ready");

      Expect(WriteFrame(pipe, status_request), "replay write failed");
      const auto replay_response = ReadFrame(pipe);
      Expect(replay_response.has_value() &&
                 replay_response->status == Status::kReplay,
             "duplicate operation nonce was accepted");

      const Frame initialize_request{
          FrameKind::kRequest,
          Command::kInitialize,
          Status::kNone,
          MakeIdentifier(4),
          hello_response->session_token,
          MakeIdentifier(5),
          UnixTimeMilliseconds() + 30000,
          0,
          "",
      };
      Expect(WriteFrame(pipe, initialize_request), "initialize write failed");
      const auto initialize_response = ReadFrame(pipe);
      Expect(initialize_response.has_value() &&
                 initialize_response->status == Status::kNotReady &&
                 (initialize_response->body.find("failure=core_missing") !=
                      std::string::npos ||
                  initialize_response->body.find(
                      "failure=runtime_directory_failed") !=
                      std::string::npos),
             "missing installed Core did not fail closed");
    }
    ::CloseHandle(pipe);
  }

  const DWORD wait = ::WaitForSingleObject(process.hProcess, 8000);
  if (wait != WAIT_OBJECT_0) {
    ::TerminateProcess(process.hProcess, ERROR_TIMEOUT);
    ::WaitForSingleObject(process.hProcess, 5000);
  }
  DWORD exit_code = ERROR_GEN_FAILURE;
  ::GetExitCodeProcess(process.hProcess, &exit_code);
  Expect(wait == WAIT_OBJECT_0, "service test process did not exit");
  Expect(exit_code == ERROR_SUCCESS, "service test process failed");
  if (exit_code != ERROR_SUCCESS) {
    std::cerr << "service exit code=" << exit_code << '\n';
  }
  ::CloseHandle(process.hThread);
  ::CloseHandle(process.hProcess);
  ::SetEnvironmentVariableW(L"POKROV_SERVICE_TEST_MODE", nullptr);
  return failures == 0 ? 0 : 1;
}
