#include "service_server.h"

#include <bcrypt.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <optional>
#include <memory>
#include <utility>
#include <vector>

#include "service_protocol.h"
#include "service_events.h"
#include "service_runtime.h"
#include "service_security.h"
#include "windows_crash_profile.h"

namespace pokrov::service {
namespace {

constexpr std::uint64_t kServiceCapabilities =
    kCapabilityProtocolV1 | kCapabilityStatus | kCapabilityRuntimeControl;
constexpr std::uint64_t kMaximumDeadlineLeadMs = 5 * 60 * 1000;

std::uint64_t UnixTimeMilliseconds() {
  FILETIME file_time{};
  ::GetSystemTimeAsFileTime(&file_time);
  ULARGE_INTEGER ticks{};
  ticks.LowPart = file_time.dwLowDateTime;
  ticks.HighPart = file_time.dwHighDateTime;
  constexpr std::uint64_t kWindowsToUnixEpochTicks =
      116444736000000000ULL;
  return (ticks.QuadPart - kWindowsToUnixEpochTicks) / 10000ULL;
}

bool GenerateIdentifier(Identifier* output) {
  return output != nullptr &&
         ::BCryptGenRandom(nullptr, output->data(),
                           static_cast<ULONG>(output->size()),
                           BCRYPT_USE_SYSTEM_PREFERRED_RNG) == 0 &&
         !IsZeroIdentifier(*output);
}

bool WaitForIo(HANDLE pipe, HANDLE stop_event, OVERLAPPED* overlapped,
               DWORD* transferred) {
  const HANDLE waits[] = {stop_event, overlapped->hEvent};
  const DWORD wait = ::WaitForMultipleObjects(2, waits, FALSE, INFINITE);
  if (wait == WAIT_OBJECT_0) {
    ::CancelIoEx(pipe, overlapped);
    ::GetOverlappedResult(pipe, overlapped, transferred, TRUE);
    return false;
  }
  return wait == WAIT_OBJECT_0 + 1 &&
         ::GetOverlappedResult(pipe, overlapped, transferred, FALSE) != FALSE;
}

bool TransferExact(HANDLE pipe, HANDLE stop_event, void* buffer,
                   std::size_t size, bool write) {
  auto* bytes = static_cast<std::uint8_t*>(buffer);
  std::size_t offset = 0;
  while (offset < size) {
    OVERLAPPED overlapped{};
    overlapped.hEvent = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (overlapped.hEvent == nullptr) {
      return false;
    }
    DWORD transferred = 0;
    const DWORD chunk = static_cast<DWORD>(size - offset);
    const BOOL completed =
        write ? ::WriteFile(pipe, bytes + offset, chunk, &transferred,
                            &overlapped)
              : ::ReadFile(pipe, bytes + offset, chunk, &transferred,
                           &overlapped);
    bool success = completed != FALSE;
    if (!success && ::GetLastError() == ERROR_IO_PENDING) {
      success = WaitForIo(pipe, stop_event, &overlapped, &transferred);
    }
    ::CloseHandle(overlapped.hEvent);
    if (!success || transferred == 0) {
      return false;
    }
    offset += transferred;
  }
  return true;
}

std::optional<Frame> ReadFrame(HANDLE pipe, HANDLE stop_event) {
  std::array<std::uint8_t, kFrameHeaderSize> header{};
  if (!TransferExact(pipe, stop_event, header.data(), header.size(), false)) {
    return std::nullopt;
  }
  const auto expected = ExpectedFrameSize(header.data(), header.size());
  if (!expected.has_value()) {
    return std::nullopt;
  }
  std::vector<std::uint8_t> bytes(*expected);
  std::copy(header.begin(), header.end(), bytes.begin());
  if (bytes.size() > header.size() &&
      !TransferExact(pipe, stop_event, bytes.data() + header.size(),
                     bytes.size() - header.size(), false)) {
    return std::nullopt;
  }
  return Decode(bytes.data(), bytes.size());
}

bool WriteFrame(HANDLE pipe, HANDLE stop_event, const Frame& frame) {
  auto bytes = Encode(frame);
  return !bytes.empty() &&
         TransferExact(pipe, stop_event, bytes.data(), bytes.size(), true);
}

bool ConnectClient(HANDLE pipe, HANDLE stop_event) {
  OVERLAPPED overlapped{};
  overlapped.hEvent = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (overlapped.hEvent == nullptr) {
    return false;
  }
  BOOL connected = ::ConnectNamedPipe(pipe, &overlapped);
  DWORD error = connected ? ERROR_SUCCESS : ::GetLastError();
  bool success = connected != FALSE || error == ERROR_PIPE_CONNECTED;
  if (error == ERROR_IO_PENDING) {
    DWORD transferred = 0;
    success = WaitForIo(pipe, stop_event, &overlapped, &transferred);
  }
  ::CloseHandle(overlapped.hEvent);
  return success;
}

Frame ResponseFor(const Frame& request, Status status,
                  const Identifier& session_token, std::string body = "") {
  return Frame{
      FrameKind::kResponse,
      request.command,
      status,
      request.correlation_id,
      session_token,
      {},
      0,
      request.command == Command::kHello ? kServiceCapabilities : 0,
      std::move(body),
  };
}

bool ProcessClient(HANDLE pipe, HANDLE stop_event,
                   const std::wstring& owner_sid, RuntimeHost* runtime,
                   bool* authorized, ServiceEventSink* events) {
  const auto hello = ReadFrame(pipe, stop_event);
  *authorized = AuthorizeNamedPipeCaller(pipe, owner_sid);
  if (!*authorized) {
    if (events != nullptr) {
      events->Record(ServiceEvent::kIpcSessionRejected,
                     ServiceEventOutcome::kRejected);
    }
    return false;
  }
  if (!hello.has_value() || hello->kind != FrameKind::kHelloRequest ||
      hello->command != Command::kHello) {
    if (events != nullptr) {
      events->Record(ServiceEvent::kIpcSessionRejected,
                     ServiceEventOutcome::kRejected);
    }
    return false;
  }
  if (events != nullptr) {
    events->Record(ServiceEvent::kIpcSessionAccepted,
                   ServiceEventOutcome::kAccepted);
    events->RecordIpcRequest(hello->command, hello->correlation_id);
  }

  Identifier session_token{};
  if (!GenerateIdentifier(&session_token)) {
    return false;
  }
  const bool compatible =
      (hello->capabilities & kCapabilityProtocolV1) != 0 &&
      (hello->capabilities & kCapabilityStatus) != 0;
  const auto negotiated_capabilities =
      hello->capabilities & kServiceCapabilities;
  const auto hello_response = ResponseFor(
      *hello, compatible ? Status::kOk : Status::kUnsupported, session_token,
      compatible ? "service_protocol_v1" : "unsupported_capabilities");
  if (events != nullptr) {
    events->RecordIpcResponse(hello->command, hello_response.status,
                              hello->correlation_id);
  }
  if (!WriteFrame(pipe, stop_event, hello_response) || !compatible) {
    return compatible;
  }

  std::vector<Identifier> used_nonces;
  used_nonces.reserve(256);
  while (::WaitForSingleObject(stop_event, 0) != WAIT_OBJECT_0) {
    const auto request = ReadFrame(pipe, stop_event);
    if (!request.has_value()) {
      return true;
    }
    if (request->kind != FrameKind::kRequest) {
      if (events != nullptr) {
        events->Record(ServiceEvent::kIpcSessionRejected,
                       ServiceEventOutcome::kRejected);
      }
      return false;
    }
    if (events != nullptr) {
      events->RecordIpcRequest(request->command, request->correlation_id);
    }

    Status status = Status::kOk;
    std::string body;
    const auto now = UnixTimeMilliseconds();
    if (request->session_token != session_token) {
      status = Status::kUnauthorized;
      body = "session_mismatch";
    } else if (request->deadline_unix_ms < now) {
      status = Status::kDeadlineExceeded;
      body = "deadline_exceeded";
    } else if (request->deadline_unix_ms - now > kMaximumDeadlineLeadMs) {
      status = Status::kInvalid;
      body = "deadline_too_far";
    } else if (std::find(used_nonces.begin(), used_nonces.end(),
                         request->operation_nonce) != used_nonces.end()) {
      status = Status::kReplay;
      body = "operation_replay";
    } else if (used_nonces.size() == used_nonces.capacity()) {
      status = Status::kNotReady;
      body = "session_nonce_capacity";
    } else {
      used_nonces.push_back(request->operation_nonce);
      const bool runtime_command =
          request->command == Command::kInitialize ||
          request->command == Command::kStageProfile ||
          request->command == Command::kInvalidateProfile ||
          request->command == Command::kConnect ||
          request->command == Command::kDisconnect;
      if (runtime == nullptr) {
        status = Status::kNotReady;
        body = "runtime_not_owned";
      } else if (runtime_command &&
                 (negotiated_capabilities & kCapabilityRuntimeControl) == 0) {
        status = Status::kUnsupported;
        body = "runtime_capability_required";
      } else {
        RuntimeResult result;
        switch (request->command) {
          case Command::kStatus:
            result = runtime->Snapshot();
            break;
          case Command::kInitialize:
            result = runtime->Initialize();
            break;
          case Command::kStageProfile:
            result = runtime->StageProfile(request->body);
            break;
          case Command::kInvalidateProfile:
            result = runtime->InvalidateProfile();
            break;
          case Command::kConnect:
            result = runtime->Connect();
            break;
          case Command::kDisconnect:
            result = runtime->Disconnect();
            break;
          default:
            result = RuntimeResult{Status::kNotReady, "runtime_not_owned"};
            break;
        }
        status = result.status;
        body = std::move(result.body);
      }
    }
    const auto response =
        ResponseFor(*request, status, session_token, std::move(body));
    if (events != nullptr) {
      events->RecordIpcResponse(request->command, status,
                                request->correlation_id);
    }
    if (!WriteFrame(pipe, stop_event, response)) {
      return false;
    }
  }
  return true;
}

}  // namespace

DWORD RunPipeServer(const std::wstring& pipe_name,
                    const std::wstring& owner_sid, HANDLE stop_event,
                    std::size_t test_client_limit, ServiceEventSink* events) {
  if (pipe_name.rfind(L"\\\\.\\pipe\\POKROV.Service.", 0) != 0 ||
      owner_sid.empty() || stop_event == nullptr) {
    return ERROR_INVALID_PARAMETER;
  }

  PipeSecurity security;
  if (!security.Initialize(owner_sid)) {
    return ERROR_INVALID_SECURITY_DESCR;
  }

  const auto runtime_root = ResolveServiceRuntimeRoot();
  auto core = CreateInstalledCoreRuntime();
  pokrov::windows_crash::RefreshWindowsCrashProfileModules();
  RuntimeHost runtime(std::move(core),
                      CreateAuthenticatedEgressProbe(),
                      CreateRuntimeRecovery(runtime_root), runtime_root, true,
                      events);
  runtime.RecoverOnStartup();
  std::size_t processed_client_count = 0;
  do {
    const HANDLE pipe = ::CreateNamedPipeW(
        pipe_name.c_str(), PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT |
            PIPE_REJECT_REMOTE_CLIENTS,
        1, static_cast<DWORD>(kMaxFrameSize),
        static_cast<DWORD>(kMaxFrameSize), 0, security.attributes());
    if (pipe == INVALID_HANDLE_VALUE) {
      return ::GetLastError();
    }

    if (!ConnectClient(pipe, stop_event)) {
      const DWORD result =
          ::WaitForSingleObject(stop_event, 0) == WAIT_OBJECT_0
              ? ERROR_SUCCESS
              : ::GetLastError();
      ::CloseHandle(pipe);
      return result;
    }

    bool authorized = false;
    const bool processed = ProcessClient(pipe, stop_event, owner_sid,
                                         &runtime, &authorized, events);
    ::FlushFileBuffers(pipe);
    ::DisconnectNamedPipe(pipe);
    ::CloseHandle(pipe);
    if (::WaitForSingleObject(stop_event, 0) == WAIT_OBJECT_0) {
      break;
    }
    ++processed_client_count;
    if (authorized && events != nullptr) {
      events->Record(ServiceEvent::kIpcSessionClosed,
                     ServiceEventOutcome::kSucceeded);
    }
    if (!authorized) {
      if (test_client_limit != 0 &&
          processed_client_count >= test_client_limit) {
        return ERROR_ACCESS_DENIED;
      }
      continue;
    }
    if (!processed) {
      if (test_client_limit != 0 &&
          processed_client_count >= test_client_limit) {
        return ERROR_INVALID_DATA;
      }
      continue;
    }
    if (test_client_limit != 0 &&
        processed_client_count >= test_client_limit) {
      return ERROR_SUCCESS;
    }
  } while (::WaitForSingleObject(stop_event, 0) != WAIT_OBJECT_0);
  runtime.Shutdown();
  return ERROR_SUCCESS;
}

}  // namespace pokrov::service
