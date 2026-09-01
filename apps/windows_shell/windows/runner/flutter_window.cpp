#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include <flutter/standard_method_codec.h>

#include "activation_protocol.h"
#include "flutter/generated_plugin_registrant.h"
#include "service_client.h"
#include "utils.h"

namespace {
constexpr ULONG_PTR kPokrovAcquisitionCopyData = 0x504F4B52;
constexpr char kAcquisitionLinksChannel[] = "space.pokrov/acquisition-links";
constexpr char kWindowsShellChannel[] = "space.pokrov/windows-shell";
constexpr char kRuntimeEngineChannel[] = "space.pokrov/runtime_engine";
constexpr wchar_t kPokrovPreferencesKey[] =
    L"Software\\space.pokrov\\POKROV";
constexpr wchar_t kWindowsRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kPokrovRunValue[] = L"POKROV";
constexpr wchar_t kCloseToTrayValue[] = L"CloseToTray";

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

std::wstring StartupCommand() {
  const auto executable = QuotedExecutablePath();
  return executable.empty() ? L"" : executable + L" --startup";
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
  const auto current = StartupCommand();
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
    const auto command = StartupCommand();
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

bool WriteString(const wchar_t* path, const wchar_t* name,
                 const std::wstring& value) {
  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, path, 0, nullptr, 0,
                        KEY_SET_VALUE, nullptr, &key, nullptr) !=
      ERROR_SUCCESS) {
    return false;
  }
  const auto status = ::RegSetValueExW(
      key, name, 0, REG_SZ, reinterpret_cast<const BYTE*>(value.c_str()),
      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
  ::RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

bool EnsureUserProtocolRegistration() {
  const auto executable = CurrentExecutablePath();
  const auto quoted = QuotedExecutablePath();
  if (executable.empty() || quoted.empty()) {
    return false;
  }
  return WriteString(L"Software\\Classes\\pokrov", L"",
                     L"URL:POKROV acquisition continuation") &&
         WriteString(L"Software\\Classes\\pokrov", L"URL Protocol", L"") &&
         WriteString(L"Software\\Classes\\pokrov\\DefaultIcon", L"",
                     executable + L",0") &&
         WriteString(L"Software\\Classes\\pokrov\\shell\\open\\command",
                     L"", quoted + L" \"%1\"");
}

std::string DartRuntimePhase(const std::string& phase) {
  if (phase == "artifact_ready") {
    return "artifactReady";
  }
  if (phase == "config_staged") {
    return "configStaged";
  }
  if (phase == "initialized" || phase == "running") {
    return phase;
  }
  return "artifactMissing";
}

flutter::EncodableValue RuntimeSnapshotValue(
    const pokrov::service::ServiceRuntimeSnapshot& snapshot) {
  flutter::EncodableMap values;
  values[flutter::EncodableValue("phase")] =
      flutter::EncodableValue(DartRuntimePhase(snapshot.phase));
  values[flutter::EncodableValue("supportsLiveConnect")] =
      flutter::EncodableValue(snapshot.compatible);
  values[flutter::EncodableValue("canInitialize")] =
      flutter::EncodableValue(snapshot.compatible && snapshot.can_initialize);
  values[flutter::EncodableValue("canConnect")] =
      flutter::EncodableValue(snapshot.command_accepted &&
                              snapshot.can_connect);
  values[flutter::EncodableValue("coreBinaryPath")] =
      snapshot.core_ready
          ? flutter::EncodableValue("service://pokrov-core.dll")
          : flutter::EncodableValue();
  values[flutter::EncodableValue("helperBinaryPath")] =
      snapshot.available
          ? flutter::EncodableValue("service://pokrov_service.exe")
          : flutter::EncodableValue();
  values[flutter::EncodableValue("stagedConfigPath")] =
      snapshot.can_connect || snapshot.running
          ? flutter::EncodableValue("service://managed-profile")
          : flutter::EncodableValue();
  const char* diagnostic_state =
      snapshot.core_egress_validated ? "healthy" : "unknown";
  values[flutter::EncodableValue("hostHealth")] =
      flutter::EncodableValue(diagnostic_state);
  values[flutter::EncodableValue("dnsState")] =
      flutter::EncodableValue(diagnostic_state);
  values[flutter::EncodableValue("uplinkState")] =
      flutter::EncodableValue(diagnostic_state);
  if (snapshot.core_egress_validated) {
    values[flutter::EncodableValue("defaultNetworkInterface")] =
        flutter::EncodableValue("network_available");
  }
  values[flutter::EncodableValue("dnsReady")] =
      flutter::EncodableValue(snapshot.dns_ready);
  values[flutter::EncodableValue("coreEgressValidated")] =
      flutter::EncodableValue(snapshot.core_egress_validated);
  values[flutter::EncodableValue("coreEgressValidationRequired")] =
      flutter::EncodableValue(true);
  values[flutter::EncodableValue("connectionPending")] =
      flutter::EncodableValue(snapshot.running &&
                              !snapshot.core_egress_validated);
  if (snapshot.failure != "none" &&
      snapshot.failure != "service_unavailable") {
    values[flutter::EncodableValue("lastFailureKind")] =
        flutter::EncodableValue(snapshot.failure);
  }
  return flutter::EncodableValue(values);
}

const flutter::EncodableMap* MapArguments(
    const flutter::MethodCall<flutter::EncodableValue>& call) {
  return std::get_if<flutter::EncodableMap>(call.arguments());
}

const std::string* StringArgument(const flutter::EncodableMap* arguments,
                                  const char* key) {
  if (arguments == nullptr) {
    return nullptr;
  }
  const auto iterator = arguments->find(flutter::EncodableValue(key));
  return iterator == arguments->end()
             ? nullptr
             : std::get_if<std::string>(&iterator->second);
}

const bool* BoolArgument(const flutter::EncodableMap* arguments,
                         const char* key) {
  if (arguments == nullptr) {
    return nullptr;
  }
  const auto iterator = arguments->find(flutter::EncodableValue(key));
  return iterator == arguments->end()
             ? nullptr
             : std::get_if<bool>(&iterator->second);
}
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             std::string initial_acquisition_uri,
                             bool start_hidden)
    : project_(project),
      pending_acquisition_uri_(std::move(initial_acquisition_uri)),
      start_hidden_(start_hidden) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }
  EnsureUserProtocolRegistration();

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
        if (call.method_name() == "readServiceStatus") {
          const auto probe = pokrov::service::ProbeInstalledService();
          flutter::EncodableMap status;
          status[flutter::EncodableValue("state")] = flutter::EncodableValue(
              pokrov::service::ClientStateName(probe.state));
          status[flutter::EncodableValue("available")] =
              flutter::EncodableValue(probe.available);
          status[flutter::EncodableValue("trusted")] =
              flutter::EncodableValue(probe.trusted);
          status[flutter::EncodableValue("compatible")] =
              flutter::EncodableValue(probe.compatible);
          status[flutter::EncodableValue("runtimeReady")] =
              flutter::EncodableValue(probe.runtime_ready);
          result->Success(flutter::EncodableValue(status));
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
  runtime_engine_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kRuntimeEngineChannel,
          &flutter::StandardMethodCodec::GetInstance());
  runtime_engine_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        using pokrov::service::Command;
        if (call.method_name() == "runtimeEngine.snapshot") {
          result->Success(RuntimeSnapshotValue(
              pokrov::service::InvokeInstalledService(Command::kStatus, "")));
          return;
        }
        if (call.method_name() == "runtimeEngine.initialize") {
          result->Success(RuntimeSnapshotValue(
              pokrov::service::InvokeInstalledService(Command::kInitialize,
                                                       "")));
          return;
        }
        if (call.method_name() == "runtimeEngine.stageManagedProfile") {
          const auto* arguments = MapArguments(call);
          const auto* profile = StringArgument(arguments, "configPayload");
          const auto* service_profile_bundle =
              StringArgument(arguments, "serviceProfileBundle");
          const auto* disable_memory_limit =
              BoolArgument(arguments, "disableMemoryLimit");
          const auto* materialized =
              BoolArgument(arguments, "materializedForRuntime");
          if (profile == nullptr || disable_memory_limit == nullptr ||
              materialized == nullptr || !*materialized) {
            result->Error("invalid_arguments",
                          "A materialized managed profile is required.");
            return;
          }
          const std::string& service_profile =
              service_profile_bundle == nullptr ? *profile
                                                : *service_profile_bundle;
          const std::string body =
              (*disable_memory_limit ? "1\n" : "0\n") + service_profile;
          result->Success(RuntimeSnapshotValue(
              pokrov::service::InvokeInstalledService(Command::kStageProfile,
                                                       body)));
          return;
        }
        if (call.method_name() == "runtimeEngine.invalidateManagedProfile") {
          result->Success(RuntimeSnapshotValue(
              pokrov::service::InvokeInstalledService(
                  Command::kInvalidateProfile, "")));
          return;
        }
        if (call.method_name() == "runtimeEngine.connect") {
          result->Success(RuntimeSnapshotValue(
              pokrov::service::InvokeInstalledService(Command::kConnect,
                                                       "")));
          return;
        }
        if (call.method_name() == "runtimeEngine.disconnect") {
          result->Success(RuntimeSnapshotValue(
              pokrov::service::InvokeInstalledService(Command::kDisconnect,
                                                       "")));
          return;
        }
        if (call.method_name() == "runtimeEngine.applyWarp") {
          const auto* arguments = MapArguments(call);
          const auto* profile = StringArgument(arguments, "configPayload");
          const auto* service_profile_bundle =
              StringArgument(arguments, "serviceProfileBundle");
          if (profile == nullptr) {
            result->Error("invalid_arguments", "A managed profile is required.");
            return;
          }
          const auto snapshot = pokrov::service::InvokeInstalledService(
              Command::kStageProfile,
              "0\n" + (service_profile_bundle == nullptr
                            ? *profile
                            : *service_profile_bundle));
          flutter::EncodableMap values;
          values[flutter::EncodableValue("applied")] =
              flutter::EncodableValue(snapshot.command_accepted);
          values[flutter::EncodableValue("effectiveAt")] =
              flutter::EncodableValue(snapshot.command_accepted
                                           ? "next_connect"
                                           : "none");
          values[flutter::EncodableValue("fallbackUsed")] =
              flutter::EncodableValue(false);
          if (!snapshot.command_accepted) {
            values[flutter::EncodableValue("reason")] =
                flutter::EncodableValue("runtime_failure");
          }
          result->Success(flutter::EncodableValue(values));
          return;
        }
        if (call.method_name() == "runtimeEngine.liveStats") {
          const auto snapshot = pokrov::service::InvokeInstalledService(
              Command::kStatus, "");
          flutter::EncodableMap values;
          values[flutter::EncodableValue("available")] =
              flutter::EncodableValue(snapshot.running);
          values[flutter::EncodableValue("serverCode")] =
              flutter::EncodableValue("");
          values[flutter::EncodableValue("serverCountry")] =
              flutter::EncodableValue("");
          values[flutter::EncodableValue("protocol")] =
              flutter::EncodableValue(snapshot.running ? "sing-box" : "");
          result->Success(flutter::EncodableValue(values));
          return;
        }
        if (call.method_name() == "runtimeEngine.pushToken") {
          flutter::EncodableMap values;
          values[flutter::EncodableValue("available")] =
              flutter::EncodableValue(false);
          result->Success(flutter::EncodableValue(values));
          return;
        }
        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  if (!start_hidden_) {
    flutter_controller_->engine()->SetNextFrameCallback([&]() {
      this->Show();
    });
  }

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  runtime_engine_channel_.reset();
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
          payload->lpData == nullptr) {
        break;
      }
      const auto activation = pokrov::activation::Decode(
          payload->lpData, static_cast<std::size_t>(payload->cbData));
      if (!activation.has_value()) {
        break;
      }
      if (activation->command ==
          pokrov::activation::Command::kAcquisitionContinue) {
        pending_acquisition_uri_ = activation->payload;
        if (acquisition_links_channel_) {
          acquisition_links_channel_->InvokeMethod(
              "uriChanged",
              std::make_unique<flutter::EncodableValue>(
                  pending_acquisition_uri_));
        }
      }
      ::ShowWindow(GetHandle(), SW_RESTORE);
      ::SetForegroundWindow(GetHandle());
      return TRUE;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
