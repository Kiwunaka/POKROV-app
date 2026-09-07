#include "service_pipe_client.h"

#include <windows.h>

namespace pokrov::service {

HANDLE OpenNamedPipeClient(const wchar_t* pipe_name, DWORD timeout_ms, DWORD flags) {
  if (pipe_name == nullptr || pipe_name[0] == L'\0') {
    ::SetLastError(ERROR_INVALID_PARAMETER);
    return INVALID_HANDLE_VALUE;
  }

  const ULONGLONG started = ::GetTickCount64();
  bool observed_busy = false;
  while (true) {
    HANDLE pipe = ::CreateFileW(pipe_name, GENERIC_READ | GENERIC_WRITE, 0,
                                nullptr, OPEN_EXISTING, flags, nullptr);
    if (pipe != INVALID_HANDLE_VALUE) {
      return pipe;
    }

    const DWORD open_error = ::GetLastError();
    if (open_error == ERROR_FILE_NOT_FOUND && observed_busy) {
      const ULONGLONG elapsed = ::GetTickCount64() - started;
      if (elapsed >= timeout_ms) {
        ::SetLastError(ERROR_SEM_TIMEOUT);
        return INVALID_HANDLE_VALUE;
      }
      const DWORD remaining =
          static_cast<DWORD>(static_cast<ULONGLONG>(timeout_ms) - elapsed);
      ::Sleep(remaining < 10 ? remaining : 10);
      continue;
    }
    if (open_error != ERROR_PIPE_BUSY) {
      ::SetLastError(open_error);
      return INVALID_HANDLE_VALUE;
    }
    observed_busy = true;

    const ULONGLONG elapsed = ::GetTickCount64() - started;
    if (elapsed >= timeout_ms) {
      ::SetLastError(ERROR_SEM_TIMEOUT);
      return INVALID_HANDLE_VALUE;
    }
    const DWORD remaining =
        static_cast<DWORD>(static_cast<ULONGLONG>(timeout_ms) - elapsed);
    if (!::WaitNamedPipeW(pipe_name, remaining)) {
      if (::GetLastError() == ERROR_FILE_NOT_FOUND) {
        continue;
      }
      return INVALID_HANDLE_VALUE;
    }
    // More than one waiter can wake for one free instance. Retry CreateFileW
    // until this caller gets the instance or the bounded deadline expires.
  }
}

}  // namespace pokrov::service
