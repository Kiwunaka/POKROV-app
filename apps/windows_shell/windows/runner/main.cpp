#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {
constexpr ULONG_PTR kPokrovAcquisitionCopyData = 0x504F4B52;
constexpr wchar_t kPokrovWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

bool IsPokrovAcquisitionUri(const std::string& value) {
  constexpr char prefix[] = "pokrov://acquisition/continue?";
  return value.size() <= 512 && value.rfind(prefix, 0) == 0;
}

std::string FindAcquisitionUri(const std::vector<std::string>& arguments) {
  for (const auto& argument : arguments) {
    if (IsPokrovAcquisitionUri(argument)) {
      return argument;
    }
  }
  return "";
}

bool ForwardAcquisitionUri(const std::string& uri) {
  if (uri.empty()) {
    return false;
  }
  const HWND existing = ::FindWindowW(kPokrovWindowClass, L"POKROV");
  if (existing == nullptr) {
    return false;
  }
  const std::wstring wide_uri = Utf16FromUtf8(uri);
  COPYDATASTRUCT payload{};
  payload.dwData = kPokrovAcquisitionCopyData;
  payload.cbData = static_cast<DWORD>((wide_uri.size() + 1) * sizeof(wchar_t));
  payload.lpData = const_cast<wchar_t*>(wide_uri.c_str());
  DWORD_PTR result = 0;
  const auto delivered = ::SendMessageTimeoutW(
      existing, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&payload),
      SMTO_ABORTIFHUNG | SMTO_BLOCK, 2000, &result);
  if (delivered == 0 || result != TRUE) {
    return false;
  }
  ::ShowWindow(existing, SW_RESTORE);
  ::SetForegroundWindow(existing);
  return true;
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
  if (ForwardAcquisitionUri(acquisition_uri)) {
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, acquisition_uri);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"POKROV", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
