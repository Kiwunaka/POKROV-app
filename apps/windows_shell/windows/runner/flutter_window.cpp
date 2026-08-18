#include "flutter_window.h"

#include <optional>
#include <shellapi.h>
#include <windows.h>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {
constexpr ULONG_PTR kPokrovAcquisitionCopyData = 0x504F4B52;
constexpr char kAcquisitionLinksChannel[] = "space.pokrov/acquisition-links";
constexpr char kWindowsShellChannel[] = "space.pokrov/windows-shell";
constexpr wchar_t kPokrovPreferencesKey[] =
    L"Software\\space.pokrov\\POKROV";
constexpr wchar_t kWindowsRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kPokrovRunValue[] = L"POKROV";
constexpr wchar_t kCloseToTrayValue[] = L"CloseToTray";

bool IsProcessElevated() {
  HANDLE token = nullptr;
  if (!::OpenProcessToken(::GetCurrentProcess(), TOKEN_QUERY, &token)) {
    return false;
  }
  TOKEN_ELEVATION elevation{};
  DWORD size = 0;
  const bool elevated =
      ::GetTokenInformation(token, TokenElevation, &elevation,
                            sizeof(elevation), &size) != FALSE &&
      elevation.TokenIsElevated != 0;
  ::CloseHandle(token);
  return elevated;
}

std::wstring CurrentExecutablePath() {
  std::wstring path(32768, L'\0');
  const DWORD length = ::GetModuleFileNameW(
      nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) {
    return L"";
  }
  path.resize(length);
  return path;
}

std::wstring QuotedExecutablePath() {
  const auto path = CurrentExecutablePath();
  return path.empty() ? L"" : L"\"" + path + L"\"";
}

bool ReadDword(HKEY root, const wchar_t* path, const wchar_t* name,
               DWORD fallback) {
  DWORD value = fallback;
  DWORD type = 0;
  DWORD size = sizeof(value);
  if (::RegGetValueW(root, path, name, RRF_RT_REG_DWORD, &type, &value,
                     &size) != ERROR_SUCCESS) {
    return fallback != 0;
  }
  return value != 0;
}

bool HasCurrentRunEntry() {
  wchar_t value[32768]{};
  DWORD type = 0;
  DWORD size = sizeof(value);
  if (::RegGetValueW(HKEY_CURRENT_USER, kWindowsRunKey, kPokrovRunValue,
                     RRF_RT_REG_SZ, &type, value, &size) != ERROR_SUCCESS) {
    return false;
  }
  const auto current = QuotedExecutablePath();
  return !current.empty() &&
         ::CompareStringOrdinal(value, -1, current.c_str(), -1, TRUE) ==
             CSTR_EQUAL;
}

bool WriteDword(const wchar_t* path, const wchar_t* name, bool value) {
  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, path, 0, nullptr, 0,
                        KEY_SET_VALUE, nullptr, &key, nullptr) !=
      ERROR_SUCCESS) {
    return false;
  }
  const DWORD data = value ? 1 : 0;
  const auto status = ::RegSetValueExW(
      key, name, 0, REG_DWORD, reinterpret_cast<const BYTE*>(&data),
      sizeof(data));
  ::RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

bool WriteLaunchAtLogin(bool enabled) {
  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, kWindowsRunKey, 0, nullptr, 0,
                        KEY_SET_VALUE, nullptr, &key, nullptr) !=
      ERROR_SUCCESS) {
    return false;
  }
  LONG status = ERROR_SUCCESS;
  if (enabled) {
    const auto command = QuotedExecutablePath();
    if (command.empty()) {
      ::RegCloseKey(key);
      return false;
    }
    status = ::RegSetValueExW(
        key, kPokrovRunValue, 0, REG_SZ,
        reinterpret_cast<const BYTE*>(command.c_str()),
        static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  } else {
    status = ::RegDeleteValueW(key, kPokrovRunValue);
    if (status == ERROR_FILE_NOT_FOUND) {
      status = ERROR_SUCCESS;
    }
  }
  ::RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

flutter::EncodableValue ReadPreferences() {
  flutter::EncodableMap values;
  values[flutter::EncodableValue("launchAtLogin")] =
      flutter::EncodableValue(HasCurrentRunEntry());
  values[flutter::EncodableValue("closeToTray")] = flutter::EncodableValue(
      ReadDword(HKEY_CURRENT_USER, kPokrovPreferencesKey, kCloseToTrayValue,
                1));
  return flutter::EncodableValue(values);
}
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             std::string initial_acquisition_uri)
    : project_(project),
      pending_acquisition_uri_(std::move(initial_acquisition_uri)) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  acquisition_links_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kAcquisitionLinksChannel,
          &flutter::StandardMethodCodec::GetInstance());
  acquisition_links_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "getInitialUri") {
          result->NotImplemented();
          return;
        }
        if (pending_acquisition_uri_.empty()) {
          result->Success();
          return;
        }
        const auto uri = pending_acquisition_uri_;
        pending_acquisition_uri_.clear();
        result->Success(flutter::EncodableValue(uri));
      });
  windows_shell_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kWindowsShellChannel,
          &flutter::StandardMethodCodec::GetInstance());
  windows_shell_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "isElevated") {
          result->Success(flutter::EncodableValue(IsProcessElevated()));
          return;
        }
        if (call.method_name() == "relaunchElevated") {
          const auto executable = CurrentExecutablePath();
          if (executable.empty()) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          const auto launched = reinterpret_cast<INT_PTR>(::ShellExecuteW(
              GetHandle(), L"runas", executable.c_str(), L"--connect",
              nullptr, SW_SHOWNORMAL));
          result->Success(flutter::EncodableValue(launched > 32));
          return;
        }
        if (call.method_name() == "readPreferences") {
          result->Success(ReadPreferences());
          return;
        }
        if (call.method_name() == "updatePreferences") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(
              call.arguments());
          if (arguments == nullptr) {
            result->Error("invalid_arguments", "Preferences are required.");
            return;
          }
          const auto launch_it =
              arguments->find(flutter::EncodableValue("launchAtLogin"));
          const auto close_it =
              arguments->find(flutter::EncodableValue("closeToTray"));
          const auto* launch = launch_it == arguments->end()
                                   ? nullptr
                                   : std::get_if<bool>(&launch_it->second);
          const auto* close = close_it == arguments->end()
                                  ? nullptr
                                  : std::get_if<bool>(&close_it->second);
          if (launch == nullptr || close == nullptr ||
              !WriteLaunchAtLogin(*launch) ||
              !WriteDword(kPokrovPreferencesKey, kCloseToTrayValue, *close)) {
            result->Error("write_failed", "Windows preferences were not saved.");
            return;
          }
          result->Success(ReadPreferences());
          return;
        }
        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  windows_shell_channel_.reset();
  acquisition_links_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_COPYDATA: {
      const auto* payload = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
      if (payload == nullptr ||
          payload->dwData != kPokrovAcquisitionCopyData ||
          payload->lpData == nullptr || payload->cbData < sizeof(wchar_t) ||
          payload->cbData > 513 * sizeof(wchar_t) ||
          payload->cbData % sizeof(wchar_t) != 0) {
        break;
      }
      const auto* text = static_cast<const wchar_t*>(payload->lpData);
      const size_t count = payload->cbData / sizeof(wchar_t);
      if (text[count - 1] != L'\0') {
        break;
      }
      const std::wstring wide_uri(text, count - 1);
      pending_acquisition_uri_ = Utf8FromUtf16(wide_uri.c_str());
      if (acquisition_links_channel_) {
        acquisition_links_channel_->InvokeMethod(
            "uriChanged",
            std::make_unique<flutter::EncodableValue>(
                pending_acquisition_uri_));
      }
      return TRUE;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
