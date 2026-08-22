#include <windows.h>

#include <cstdint>
#include <string>
#include <memory>

#include "service_events.h"
#include "service_runtime.h"
#include "service_security.h"
#include "service_server.h"
#include "windows_crash_profile.h"

namespace {

constexpr wchar_t kServiceName[] = L"POKROVService";
SERVICE_STATUS_HANDLE service_status_handle = nullptr;
SERVICE_STATUS service_status{};
HANDLE service_stop_event = nullptr;
pokrov::service::ServiceEventSink* service_events = nullptr;

std::uint64_t SystemBootEpochFileTime() {
  FILETIME now{};
  ::GetSystemTimeAsFileTime(&now);
  ULARGE_INTEGER ticks{};
  ticks.LowPart = now.dwLowDateTime;
  ticks.HighPart = now.dwHighDateTime;
  const std::uint64_t uptime_ticks = ::GetTickCount64() * 10000ULL;
  return ticks.QuadPart > uptime_ticks ? ticks.QuadPart - uptime_ticks : 0;
}

void ReportServiceStatus(DWORD state, DWORD win32_exit_code,
                         DWORD wait_hint = 0) {
  service_status.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
  service_status.dwCurrentState = state;
  service_status.dwWin32ExitCode = win32_exit_code;
  service_status.dwWaitHint = wait_hint;
  service_status.dwControlsAccepted =
      state == SERVICE_RUNNING
          ? SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN |
                SERVICE_ACCEPT_PRESHUTDOWN | SERVICE_ACCEPT_POWEREVENT
                               : 0;
  service_status.dwCheckPoint =
      state == SERVICE_START_PENDING || state == SERVICE_STOP_PENDING ? 1 : 0;
  if (service_status_handle != nullptr) {
    ::SetServiceStatus(service_status_handle, &service_status);
  }
}

DWORD WINAPI ServiceControlHandler(DWORD control, DWORD event_type, void*,
                                   void*) {
  if (service_events != nullptr) {
    if (control == SERVICE_CONTROL_STOP) {
      service_events->Record(pokrov::service::ServiceEvent::kServiceStopRequested,
                             pokrov::service::ServiceEventOutcome::kAccepted);
    } else if (control == SERVICE_CONTROL_SHUTDOWN) {
      service_events->Record(
          pokrov::service::ServiceEvent::kServiceShutdownRequested,
          pokrov::service::ServiceEventOutcome::kAccepted);
    } else if (control == SERVICE_CONTROL_PRESHUTDOWN) {
      service_events->Record(
          pokrov::service::ServiceEvent::kServicePreShutdownRequested,
          pokrov::service::ServiceEventOutcome::kAccepted);
    } else if (control == SERVICE_CONTROL_POWEREVENT &&
               event_type == PBT_APMSUSPEND) {
      service_events->Record(
          pokrov::service::ServiceEvent::kServicePowerSuspend,
          pokrov::service::ServiceEventOutcome::kAccepted);
    } else if (control == SERVICE_CONTROL_POWEREVENT &&
               (event_type == PBT_APMRESUMEAUTOMATIC ||
                event_type == PBT_APMRESUMECRITICAL ||
                event_type == PBT_APMRESUMESUSPEND)) {
      service_events->Record(
          pokrov::service::ServiceEvent::kServicePowerResume,
          pokrov::service::ServiceEventOutcome::kAccepted);
    }
  }
  if ((control == SERVICE_CONTROL_STOP ||
       control == SERVICE_CONTROL_SHUTDOWN ||
       control == SERVICE_CONTROL_PRESHUTDOWN) &&
      service_stop_event != nullptr) {
    ReportServiceStatus(SERVICE_STOP_PENDING, ERROR_SUCCESS, 5000);
    ::SetEvent(service_stop_event);
  }
  return ERROR_SUCCESS;
}

void WINAPI ServiceMain(DWORD, wchar_t**) {
  service_status_handle = ::RegisterServiceCtrlHandlerExW(
      kServiceName, ServiceControlHandler, nullptr);
  if (service_status_handle == nullptr) {
    return;
  }
  ReportServiceStatus(SERVICE_START_PENDING, ERROR_SUCCESS, 5000);
  const auto runtime_root = pokrov::service::ResolveServiceRuntimeRoot();
  pokrov::windows_crash::InstallWindowsCrashProfile(
      pokrov::windows_crash::WindowsCrashProcess::kService, runtime_root);
  auto event_journal =
      pokrov::service::CreateServiceEventJournal(runtime_root);
  service_events = event_journal.get();
  if (service_events != nullptr) {
    service_events->RecordSystemBoot(SystemBootEpochFileTime());
    service_events->Record(
        pokrov::service::ServiceEvent::kServiceStartPending,
        pokrov::service::ServiceEventOutcome::kAttempted);
  }

  const auto owner_sid = pokrov::service::InstalledOwnerSid();
  if (owner_sid.empty()) {
    if (service_events != nullptr) {
      service_events->Record(pokrov::service::ServiceEvent::kServiceStopped,
                             pokrov::service::ServiceEventOutcome::kFailed);
    }
    service_events = nullptr;
    event_journal.reset();
    ReportServiceStatus(SERVICE_STOPPED, ERROR_INVALID_OWNER);
    return;
  }
  service_stop_event = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (service_stop_event == nullptr) {
    if (service_events != nullptr) {
      service_events->Record(pokrov::service::ServiceEvent::kServiceStopped,
                             pokrov::service::ServiceEventOutcome::kFailed);
    }
    service_events = nullptr;
    event_journal.reset();
    ReportServiceStatus(SERVICE_STOPPED, ::GetLastError());
    return;
  }

  ReportServiceStatus(SERVICE_RUNNING, ERROR_SUCCESS);
  if (service_events != nullptr) {
    service_events->Record(pokrov::service::ServiceEvent::kServiceRunning,
                           pokrov::service::ServiceEventOutcome::kSucceeded);
  }
  const DWORD result = pokrov::service::RunPipeServer(
      pokrov::service::kProductionPipeName, owner_sid, service_stop_event,
      false, service_events);
  ::CloseHandle(service_stop_event);
  service_stop_event = nullptr;
  if (service_events != nullptr) {
    service_events->Record(
        pokrov::service::ServiceEvent::kServiceStopped,
        result == ERROR_SUCCESS
            ? pokrov::service::ServiceEventOutcome::kSucceeded
            : pokrov::service::ServiceEventOutcome::kFailed);
  }
  service_events = nullptr;
  event_journal.reset();
  ReportServiceStatus(SERVICE_STOPPED, result);
}

#ifdef _DEBUG
bool IsDebugTestMode(int argument_count, wchar_t** arguments) {
  if (argument_count != 3 ||
      std::wstring(arguments[1]) != L"--test-once" ||
      std::wstring(arguments[2]).rfind(pokrov::service::kTestPipePrefix, 0) !=
          0) {
    return false;
  }
  wchar_t enabled[8]{};
  return ::GetEnvironmentVariableW(L"POKROV_SERVICE_TEST_MODE", enabled,
                                   static_cast<DWORD>(sizeof(enabled) /
                                                      sizeof(enabled[0]))) >
             0 &&
         std::wstring(enabled) == L"1";
}
#endif

}  // namespace

int wmain(int argument_count, wchar_t** arguments) {
#ifdef _DEBUG
  if (IsDebugTestMode(argument_count, arguments)) {
    const auto owner_sid = pokrov::service::CurrentProcessUserSid();
    HANDLE stop_event = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (owner_sid.empty()) {
      if (stop_event != nullptr) {
        ::CloseHandle(stop_event);
      }
      return ERROR_NONE_MAPPED;
    }
    if (stop_event == nullptr) {
      return static_cast<int>(::GetLastError());
    }
    const DWORD result = pokrov::service::RunPipeServer(
        arguments[2], owner_sid, stop_event, true);
    ::CloseHandle(stop_event);
    return static_cast<int>(result);
  }
#endif

  SERVICE_TABLE_ENTRYW dispatch_table[] = {
      {const_cast<wchar_t*>(kServiceName), ServiceMain},
      {nullptr, nullptr},
  };
  if (!::StartServiceCtrlDispatcherW(dispatch_table)) {
    return static_cast<int>(::GetLastError());
  }
  return 0;
}
