#include <windows.h>

#include <atomic>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

#include "service_pipe_client.h"

namespace {

constexpr int kClientCount = 32;
constexpr DWORD kConnectTimeoutMs = 5000;

int failures = 0;

void Expect(bool condition, const char* message) {
  if (!condition) {
    std::cerr << message << '\n';
    ++failures;
  }
}

bool AcceptOneClient(const std::wstring& pipe_name, HANDLE ready_event,
                     bool first) {
  HANDLE pipe = ::CreateNamedPipeW(
      pipe_name.c_str(), PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED,
      PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT |
          PIPE_REJECT_REMOTE_CLIENTS,
      1, 1024, 1024, 0, nullptr);
  if (pipe == INVALID_HANDLE_VALUE) {
    return false;
  }
  if (first) {
    ::SetEvent(ready_event);
  }

  OVERLAPPED overlapped{};
  overlapped.hEvent = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (overlapped.hEvent == nullptr) {
    ::CloseHandle(pipe);
    return false;
  }

  const BOOL connected = ::ConnectNamedPipe(pipe, &overlapped);
  bool accepted = connected != FALSE;
  if (!accepted) {
    const DWORD error = ::GetLastError();
    if (error == ERROR_PIPE_CONNECTED) {
      accepted = true;
    } else if (error == ERROR_IO_PENDING) {
      accepted = ::WaitForSingleObject(overlapped.hEvent,
                                       kConnectTimeoutMs) == WAIT_OBJECT_0;
      if (accepted) {
        DWORD transferred = 0;
        accepted = ::GetOverlappedResult(pipe, &overlapped, &transferred,
                                         FALSE) != FALSE;
      } else {
        ::CancelIoEx(pipe, &overlapped);
      }
    }
  }
  if (accepted) {
    ::Sleep(5);
    ::DisconnectNamedPipe(pipe);
  }
  ::CloseHandle(overlapped.hEvent);
  ::CloseHandle(pipe);
  return accepted;
}

}  // namespace

int wmain() {
  using pokrov::service::OpenNamedPipeClient;

  Expect(OpenNamedPipeClient(nullptr, 1) == INVALID_HANDLE_VALUE,
         "null pipe name was accepted");
  Expect(::GetLastError() == ERROR_INVALID_PARAMETER,
         "null pipe name returned the wrong error");

  const std::wstring pipe_name =
      L"\\\\.\\pipe\\POKROV.Service.PipeClientTest." +
      std::to_wstring(::GetCurrentProcessId());
  HANDLE ready_event = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  Expect(ready_event != nullptr, "ready event was unavailable");
  if (ready_event == nullptr) {
    return 1;
  }

  std::atomic<int> accepted_clients{0};
  std::thread server([&]() {
    for (int index = 0; index < kClientCount; ++index) {
      if (!AcceptOneClient(pipe_name, ready_event, index == 0)) {
        break;
      }
      ++accepted_clients;
    }
  });

  Expect(::WaitForSingleObject(ready_event, kConnectTimeoutMs) ==
             WAIT_OBJECT_0,
         "test pipe did not become ready");

  std::atomic<int> opened_clients{0};
  std::vector<std::thread> clients;
  clients.reserve(kClientCount);
  for (int index = 0; index < kClientCount; ++index) {
    clients.emplace_back([&]() {
      HANDLE pipe = OpenNamedPipeClient(pipe_name.c_str(),
                                        kConnectTimeoutMs);
      if (pipe != INVALID_HANDLE_VALUE) {
        ++opened_clients;
        // Keep the handle alive long enough for the overlapped test server to
        // observe the connection before the next single instance is created.
        ::Sleep(20);
        ::CloseHandle(pipe);
      }
    });
  }
  for (auto& client : clients) {
    client.join();
  }
  server.join();
  ::CloseHandle(ready_event);

  Expect(opened_clients == kClientCount,
         "not every concurrent client opened the single-instance pipe");
  Expect(accepted_clients == kClientCount,
         "server did not accept every concurrent client");
  return failures == 0 ? 0 : 1;
}
