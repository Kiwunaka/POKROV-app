#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include <flutter/standard_method_codec.h>

#include "activation_protocol.h"
#include "flutter/generated_plugin_registrant.h"
#include "service_client.h"
#include "service_profile_identity.h"
#include "utils.h"

namespace {
constexpr ULONG_PTR kPokrovAcquisitionCopyData = 0x504F4B52;
constexpr char kAcquisitionLinksChannel[] = "space.pokrov/acquisition-links";
constexpr char kWindowsShellChannel[] = "space.pokrov/windows-shell";
constexpr char kRuntimeEngineChannel[] = "space.pokrov/runtime_engine";
constexpr UINT kRuntimeCompletionMessage = WM_APP + 41;
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
  if (phase == "config_staged" || phase == "connecting") {
    return "configStaged";
  }
  if (phase == "initialized" || phase == "running") {
    return phase;
  }
  if (phase == "busy") return "initialized";
  return "artifactMissing";
}

flutter::EncodableValue RuntimeSnapshotValue(
    pokrov::service::ServiceRuntimeSnapshot snapshot,
    const std::string& expected_profile_digest = "") {
  snapshot = pokrov::service::BindSnapshotToProfileIntent(
      std::move(snapshot), expected_profile_digest);
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
      !snapshot.staged_profile_digest.empty()
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
  values[flutter::EncodableValue("stagedProfileDigest")] =
      flutter::EncodableValue(snapshot.staged_profile_digest);
  values[flutter::EncodableValue("effectiveProfileDigest")] =
      flutter::EncodableValue(snapshot.effective_profile_digest);
  values[flutter::EncodableValue("profileIdentityOrigin")] =
      flutter::EncodableValue("windows_service_stage_request_sha256");
  values[flutter::EncodableValue("coreEgressValidated")] =
      flutter::EncodableValue(snapshot.core_egress_validated);
  values[flutter::EncodableValue("coreEgressValidationRequired")] =
      flutter::EncodableValue(true);
  values[flutter::EncodableValue("connectionPending")] =
      flutter::EncodableValue(snapshot.phase == "connecting");
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

FlutterWindow::~FlutterWindow() {
  // View teardown can synchronously dispatch parent-window messages. Clear the
  // controller through OnDestroy before its destructor re-enters our handler.
  OnDestroy();
}

bool FlutterWindow::QueueRuntime(pokrov::service::Command command, std::string body,
                                RuntimeTaskRunner::Completion completion) {
  using pokrov::service::Command;
  auto control = std::make_shared<pokrov::service::ServiceCallControl>();
  if (!runtime_tasks_ || !runtime_tasks_->Submit(command, std::move(body), control,
                                                std::move(completion))) return false;
  if (command == Command::kConnect || command == Command::kDisconnect ||
      command == Command::kStageProfile || command == Command::kInvalidateProfile) {
    if (pending_connect_) pending_connect_->cancel_requested = true;
  }
  if (command == Command::kConnect) pending_connect_ = std::move(control);
  return true;
}

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
  const HWND runtime_window = GetHandle();
  runtime_tasks_ = std::make_unique<RuntimeTaskRunner>([runtime_window] {
    ::PostMessageW(runtime_window, kRuntimeCompletionMessage, 0, 0);
  });
  runtime_engine_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        using pokrov::service::Command;
        auto reply = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
        const auto snapshot_call = [this, reply](Command command, std::string body,
                                                std::string expected) {
          if (QueueRuntime(command, std::move(body),
              [reply, expected = std::move(expected)](auto snapshot) {
                reply->Success(RuntimeSnapshotValue(std::move(snapshot), expected));
              })) return true;
          reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return false;
        };
        if (call.method_name() == "runtimeEngine.snapshot") {
          snapshot_call(Command::kStatus, "", expected_profile_digest_);
          return;
        }
        if (call.method_name() == "runtimeEngine.initialize") {
          snapshot_call(Command::kInitialize, "", expected_profile_digest_);
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
            reply->Error("invalid_arguments",
                          "A materialized managed profile is required.");
            return;
          }
          const std::string& service_profile =
              service_profile_bundle == nullptr ? *profile
                                                : *service_profile_bundle;
          const std::string body =
              (*disable_memory_limit ? "1\n" : "0\n") + service_profile;
          const auto expected = pokrov::service::ProfileDigest(body);
          if (snapshot_call(Command::kStageProfile, body, expected)) {
            expected_profile_digest_ = expected;
          }
          return;
        }
        if (call.method_name() == "runtimeEngine.invalidateManagedProfile") {
          if (snapshot_call(Command::kInvalidateProfile, "", "")) expected_profile_digest_.clear();
          return;
        }
        if (call.method_name() == "runtimeEngine.connect") {
          snapshot_call(Command::kConnect, expected_profile_digest_, expected_profile_digest_);
          return;
        }
        if (call.method_name() == "runtimeEngine.disconnect") {
          snapshot_call(Command::kDisconnect, "", expected_profile_digest_);
          return;
        }
        if (call.method_name() == "runtimeEngine.applyWarp") {
          const auto* arguments = MapArguments(call);
          const auto* profile = StringArgument(arguments, "configPayload");
          const auto* service_profile_bundle =
              StringArgument(arguments, "serviceProfileBundle");
          if (profile == nullptr) {
            reply->Error("invalid_arguments", "A managed profile is required.");
            return;
          }
          const std::string body =
              "0\n" + (service_profile_bundle == nullptr
                           ? *profile : *service_profile_bundle);
          const auto expected = pokrov::service::ProfileDigest(body);
          if (!QueueRuntime(Command::kStageProfile, body, [reply](auto snapshot) {
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
          reply->Success(flutter::EncodableValue(values));
          })) {
            reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          } else {
            expected_profile_digest_ = expected;
          }
          return;
        }
        if (call.method_name() == "runtimeEngine.liveStats") {
          if (!QueueRuntime(Command::kStatus, "", [reply](auto snapshot) {
          flutter::EncodableMap values;
          values[flutter::EncodableValue("available")] =
              flutter::EncodableValue(snapshot.running);
          values[flutter::EncodableValue("serverCode")] =
              flutter::EncodableValue("");
          values[flutter::EncodableValue("serverCountry")] =
              flutter::EncodableValue("");
          values[flutter::EncodableValue("protocol")] =
              flutter::EncodableValue(snapshot.running ? "sing-box" : "");
          reply->Success(flutter::EncodableValue(values));
          })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.pushToken") {
          flutter::EncodableMap values;
          values[flutter::EncodableValue("available")] =
              flutter::EncodableValue(false);
          reply->Success(flutter::EncodableValue(values));
          return;
        }
        reply->NotImplemented();
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
  if (runtime_tasks_) {
    runtime_tasks_->Shutdown();
    runtime_tasks_.reset();
  }
  pending_connect_.reset();
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
  // Restart Manager uses these messages during an in-place update. A normal
  // WM_CLOSE can be converted to hide-to-tray by the window-manager plugin.
  if (message == WM_QUERYENDSESSION) {
    return TRUE;
  }
  if (message == WM_ENDSESSION) {
    if (wparam != FALSE) Destroy();
    return 0;
  }
  if (message == kRuntimeCompletionMessage) {
    if (runtime_tasks_) runtime_tasks_->Drain();
    return 0;
  }
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
