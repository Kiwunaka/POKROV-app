#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "activation_protocol.h"
#include "flutter_window.h"
#include "utils.h"
#include "windows_crash_profile.h"

namespace {
constexpr ULONG_PTR kPokrovAcquisitionCopyData = 0x504F4B52;
constexpr wchar_t kPokrovWindowClass[] = L"POKROV_WINDOWS_UI_WINDOW_V1";
constexpr wchar_t kPokrovUiMutexPrefix[] = L"Local\\POKROV.UI.";
constexpr char kStartupArgument[] = "--startup";

bool HasArgument(const std::vector<std::string>& arguments,
                 const std::string& expected) {
  for (const auto& argument : arguments) {
    if (argument == expected) {
      return true;
    }
  }
  return false;
}

std::string FindAcquisitionUri(const std::vector<std::string>& arguments) {
  for (const auto& argument : arguments) {
    if (pokrov::activation::IsPokrovAcquisitionUri(argument)) {
      return argument;
    }
  }
  return "";
}

std::wstring CurrentSessionMutexName() {
  DWORD session_id = 0;
  if (!::ProcessIdToSessionId(::GetCurrentProcessId(), &session_id)) {
    return L"";
  }
  return std::wstring(kPokrovUiMutexPrefix) + std::to_wstring(session_id);
}

bool ForwardActivation(const pokrov::activation::Message& message) {
  const auto frame = pokrov::activation::Encode(message);
  if (frame.empty()) {
    return false;
  }

  for (int attempt = 0; attempt < 40; ++attempt) {
    const HWND existing = ::FindWindowW(kPokrovWindowClass, L"POKROV");
    if (existing != nullptr) {
      DWORD existing_process_id = 0;
      if (::GetWindowThreadProcessId(existing, &existing_process_id) != 0 &&
          existing_process_id != 0) {
        // The new instance was started by the foreground shell. Transfer that
        // permission before the existing instance handles WM_COPYDATA and
        // calls SetForegroundWindow; otherwise Windows can keep focus on the
        // launcher even though forwarding itself succeeds.
        ::AllowSetForegroundWindow(existing_process_id);
      }
      COPYDATASTRUCT payload{};
      payload.dwData = kPokrovAcquisitionCopyData;
      payload.cbData = static_cast<DWORD>(frame.size());
      payload.lpData = const_cast<std::uint8_t*>(frame.data());
      DWORD_PTR result = 0;
      const auto delivered = ::SendMessageTimeoutW(
          existing, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&payload),
          SMTO_ABORTIFHUNG | SMTO_BLOCK, 2000, &result);
      return delivered != 0 && result == TRUE;
    }
    ::Sleep(50);
  }
  return false;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const std::string acquisition_uri =
      FindAcquisitionUri(command_line_arguments);
  const bool start_hidden =
      acquisition_uri.empty() &&
      HasArgument(command_line_arguments, kStartupArgument);

  const auto mutex_name = CurrentSessionMutexName();
  if (mutex_name.empty()) {
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  const HANDLE ui_mutex = ::CreateMutexW(nullptr, FALSE, mutex_name.c_str());
  if (ui_mutex == nullptr) {
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    const pokrov::activation::Message activation{
        acquisition_uri.empty()
            ? pokrov::activation::Command::kShow
            : pokrov::activation::Command::kAcquisitionContinue,
        acquisition_uri};
    const bool delivered = ForwardActivation(activation);
    ::CloseHandle(ui_mutex);
    ::CoUninitialize();
    return delivered ? EXIT_SUCCESS : EXIT_FAILURE;
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, acquisition_uri, start_hidden);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"POKROV", origin, size)) {
    ::CloseHandle(ui_mutex);
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  pokrov::windows_crash::InstallWindowsCrashProfile(
      pokrov::windows_crash::WindowsCrashProcess::kUi,
      pokrov::windows_crash::ResolveWindowsUiStateRoot());
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CloseHandle(ui_mutex);
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
