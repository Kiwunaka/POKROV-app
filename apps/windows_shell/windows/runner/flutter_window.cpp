#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include <flutter/standard_method_codec.h>

#include "activation_protocol.h"
#include "flutter/generated_plugin_registrant.h"
#include "service_client.h"
#include "service_profile_identity.h"
#include "utils.h"
#include "uplink_status.h"

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

bool IsConnectRequestId(const std::string& value) {
  return value.size() == 32 &&
      value.find_first_not_of("0123456789abcdef") == std::string::npos;
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
  const auto uplink = snapshot.running ? HasDefaultUplink() : std::nullopt;
  const bool proof_pending = snapshot.transport_proof_state_available &&
      snapshot.transport_proof_pending;
  const bool current_proof =
      snapshot.core_egress_validated && !proof_pending && uplink.value_or(false);
  flutter::EncodableMap values;
  if (snapshot.compatible && snapshot.transport_proof_state_available) {
    values[flutter::EncodableValue("transportProofPending")] =
        flutter::EncodableValue(snapshot.transport_proof_pending);
  }
  if (snapshot.compatible && snapshot.transport_lease_state_available) {
    values[flutter::EncodableValue("transportLeaseActive")] =
        flutter::EncodableValue(snapshot.transport_lease_active);
  }
  values[flutter::EncodableValue("routingCatalogWindowVersion")] =
      flutter::EncodableValue(snapshot.compatible
          ? snapshot.routing_catalog_window_version : 0);
  values[flutter::EncodableValue("transportCapabilitiesJson")] =
      snapshot.compatible && !snapshot.transport_capabilities_json.empty()
          ? flutter::EncodableValue(snapshot.transport_capabilities_json)
          : flutter::EncodableValue();
  values[flutter::EncodableValue("coreModuleSha256")] =
      snapshot.compatible && !snapshot.core_module_sha256.empty()
          ? flutter::EncodableValue(snapshot.core_module_sha256) : flutter::EncodableValue();
  values[flutter::EncodableValue("smartAccessLeaseVersion")] =
      flutter::EncodableValue(snapshot.compatible
          ? snapshot.smart_access_lease_version : 0);
  values[flutter::EncodableValue("routingCatalogControlVersion")] =
      flutter::EncodableValue(snapshot.compatible
          ? snapshot.routing_catalog_control_version : 0);
  values[flutter::EncodableValue("smartAccessRuntimeControlVersion")] =
      flutter::EncodableValue(snapshot.compatible ? snapshot.smart_access_runtime_control_version : 0);
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
      current_proof ? "healthy" : "unknown";
  values[flutter::EncodableValue("hostHealth")] =
      flutter::EncodableValue(uplink == false ? "degraded" : diagnostic_state);
  values[flutter::EncodableValue("dnsState")] =
      flutter::EncodableValue(diagnostic_state);
  values[flutter::EncodableValue("uplinkState")] =
      flutter::EncodableValue(uplink == false ? "degraded" : diagnostic_state);
  if (uplink == true) {
    values[flutter::EncodableValue("defaultNetworkInterface")] =
        flutter::EncodableValue("network_available");
  }
  values[flutter::EncodableValue("dnsReady")] =
      flutter::EncodableValue(snapshot.dns_ready && !proof_pending && uplink.value_or(false));
  values[flutter::EncodableValue("stagedProfileDigest")] =
      flutter::EncodableValue(snapshot.staged_profile_digest);
  values[flutter::EncodableValue("effectiveProfileDigest")] =
      flutter::EncodableValue(snapshot.effective_profile_digest);
  values[flutter::EncodableValue("profileIdentityOrigin")] =
      flutter::EncodableValue("windows_service_stage_request_sha256");
  values[flutter::EncodableValue("coreEgressValidated")] =
      flutter::EncodableValue(current_proof);
  values[flutter::EncodableValue("coreEgressValidationRequired")] =
      flutter::EncodableValue(true);
  values[flutter::EncodableValue("connectionPending")] =
      flutter::EncodableValue(snapshot.phase == "connecting" || snapshot.phase == "busy");
  if (snapshot.failure != "none" &&
      snapshot.failure != "service_unavailable") {
    values[flutter::EncodableValue("lastFailureKind")] =
        flutter::EncodableValue(snapshot.failure);
  } else if (uplink == false) {
    values[flutter::EncodableValue("lastFailureKind")] =
        flutter::EncodableValue("network_unavailable");
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

std::optional<std::uint64_t> ElapsedArgument(const flutter::EncodableMap* arguments,
                                          const char* key) {
  if (arguments == nullptr) return std::nullopt;
  const auto field = arguments->find(flutter::EncodableValue(key));
  if (field == arguments->end()) return std::nullopt;
  std::int64_t value = -1;
  if (const auto* number = std::get_if<std::int64_t>(&field->second)) value = *number;
  else if (const auto* number32 = std::get_if<std::int32_t>(&field->second)) value = *number32;
  if (value < 0 || value > 9007199254740991LL) return std::nullopt;
  return static_cast<std::uint64_t>(value);
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
                                RuntimeTaskRunner::Completion completion,
                                std::string connect_request_id) {
  using pokrov::service::Command;
  if (pending_connect_bound_ && pending_connect_ &&
      (pokrov::service::IsConnectCommand(command) || command == Command::kStageProfile ||
       command == Command::kStageBoundProfile ||
       command == Command::kInvalidateProfile || command == Command::kInitialize)) return false;
  if (command == Command::kDiagnosticState && !diagnostic_tasks_) {
    const HWND window = GetHandle();
    diagnostic_tasks_ = std::make_unique<RuntimeTaskRunner>([window] {
      ::PostMessageW(window, kRuntimeCompletionMessage, 0, 0);
    });
  }
  auto* tasks = command == Command::kDiagnosticState
                    ? diagnostic_tasks_.get() : runtime_tasks_.get();
  auto control = std::make_shared<pokrov::service::ServiceCallControl>();
  if (!tasks || !tasks->Submit(command, std::move(body), control,
                                                std::move(completion))) return false;
  if (pokrov::service::IsConnectCommand(command) || command == Command::kDisconnect ||
      command == Command::kStageProfile || command == Command::kStageBoundProfile ||
      command == Command::kInvalidateProfile) {
    if (pending_connect_) pending_connect_->cancel_requested = true;
    if (!pending_connect_bound_) pending_connect_request_id_.clear();
  }
  if (pokrov::service::IsConnectCommand(command)) {
    pending_connect_ = std::move(control);
    pending_connect_request_id_ = std::move(connect_request_id);
    pending_connect_bound_ = command == Command::kConnectWithIdentity;
    pending_connect_promoted_ = false;
  }
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
        if (call.method_name() == "runtimeEngine.clockSnapshot") {
          if (!QueueRuntime(Command::kReadBootClock, "", [reply](auto snapshot) {
                if (!snapshot.command_accepted || !snapshot.compatible || snapshot.boot_clock_json.empty()) {
                  reply->Error("runtime_clock_unavailable", "System clock unavailable.");
                  return;
                }
                reply->Success(flutter::EncodableValue(snapshot.boot_clock_json));
              })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.transportNetworkContext") {
          if (!QueueRuntime(Command::kReadTransportNetworkContext, "", [reply](auto snapshot) {
                if (!snapshot.command_accepted || !snapshot.compatible ||
                    !pokrov::service::IsTransportNetworkContextRef(snapshot.transport_network_context_ref)) {
                  reply->Error("network_context_unavailable", "Network context unavailable.");
                  return;
                }
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("network_context_ref"), flutter::EncodableValue(snapshot.transport_network_context_ref)},
                }));
              })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.revokeRoutingCatalog") {
          const auto* arguments = MapArguments(call);
          const auto* profile = StringArgument(arguments, "profileDigest");
          if (arguments == nullptr || arguments->size() != 1 || profile == nullptr ||
              !pokrov::service::IsProfileDigest(*profile)) {
            reply->Error("invalid_catalog_revocation", "Invalid catalog revocation.");
            return;
          }
          if (!QueueRuntime(Command::kRevokeRoutingCatalog, *profile,
              [reply, profile = *profile](auto snapshot) {
                if (!snapshot.command_accepted || !snapshot.compatible) {
                  reply->Error("catalog_revoke_unconfirmed", "Catalog revocation was not confirmed.");
                  return;
                }
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("profileDigest"), flutter::EncodableValue(profile)},
                    {flutter::EncodableValue("revoked"), flutter::EncodableValue(snapshot.routing_catalog_found)}}));
              })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.revokeRoutingCatalogService") {
          const auto* arguments = MapArguments(call);
          const auto* profile = StringArgument(arguments, "profileDigest");
          const auto* service = StringArgument(arguments, "serviceId");
          if (arguments == nullptr || arguments->size() != 2 || profile == nullptr || service == nullptr ||
              !pokrov::service::IsRoutingCatalogServiceRevocation(*profile + ":" + *service)) {
            reply->Error("invalid_catalog_revocation", "Invalid service revocation.");
            return;
          }
          if (!QueueRuntime(Command::kRevokeRoutingCatalogService, *profile + ":" + *service,
              [reply, profile = *profile, service = *service](auto snapshot) {
                if (!snapshot.command_accepted || !snapshot.compatible) {
                  reply->Error("catalog_revoke_unconfirmed", "Service revocation was not confirmed.");
                  return;
                }
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("profileDigest"), flutter::EncodableValue(profile)},
                    {flutter::EncodableValue("serviceId"), flutter::EncodableValue(service)},
                    {flutter::EncodableValue("revoked"), flutter::EncodableValue(snapshot.routing_catalog_found)}}));
              })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.readSmartAccessRestrictions") {
          if (call.arguments() != nullptr && !std::holds_alternative<std::monostate>(*call.arguments())) {
            reply->Error("smart_access_restriction_read_invalid", "Invalid restriction recovery request.");
            return;
          }
          if (!QueueRuntime(Command::kReadSmartAccessRestrictions, "", [reply](auto snapshot) {
                if (!snapshot.command_accepted || !snapshot.compatible || snapshot.smart_access_restriction_journal.empty()) {
                  reply->Error("smart_access_restriction_read_unconfirmed", "Restriction recovery was not confirmed.");
                  return;
                }
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("journalJson"), flutter::EncodableValue(snapshot.smart_access_restriction_journal)}}));
              })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.readSmartAccessLeases") {
          const auto* arguments = MapArguments(call);
          const auto* profile = StringArgument(arguments, "profileDigest");
          if (arguments == nullptr || arguments->size() != 1 || profile == nullptr || !pokrov::service::IsProfileDigest(*profile)) {
            reply->Error("smart_access_lease_read_invalid", "Invalid lease recovery request.");
            return;
          }
          if (!QueueRuntime(Command::kReadSmartAccessLeases, *profile, [reply, profile = *profile](auto snapshot) {
                if (!snapshot.command_accepted || !snapshot.compatible || snapshot.smart_access_lease_ids_json.empty()) {
                  reply->Error("smart_access_lease_read_unconfirmed", "Lease recovery was not confirmed.");
                  return;
                }
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("profileDigest"), flutter::EncodableValue(profile)},
                    {flutter::EncodableValue("leaseIdsJson"), flutter::EncodableValue(snapshot.smart_access_lease_ids_json)}}));
              })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.acknowledgeSmartAccessRestrictions") {
          const auto* arguments = MapArguments(call);
          const auto* digest = StringArgument(arguments, "snapshotSha256");
          if (arguments == nullptr || arguments->size() != 1 || digest == nullptr || !pokrov::service::IsProfileDigest(*digest)) {
            reply->Error("smart_access_restriction_ack_invalid", "Invalid restriction acknowledgement.");
            return;
          }
          if (!QueueRuntime(Command::kAcknowledgeSmartAccessRestrictions, *digest, [reply, digest = *digest](auto snapshot) {
                if (!snapshot.command_accepted || !snapshot.compatible) {
                  reply->Error("smart_access_restriction_ack_unconfirmed", "Restriction acknowledgement was not confirmed.");
                  return;
                }
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("snapshotSha256"), flutter::EncodableValue(digest)},
                    {flutter::EncodableValue("acknowledged"), flutter::EncodableValue(snapshot.smart_access_restrictions_acknowledged)}}));
              })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.configureSmartAccessRuntimeControl" ||
            call.method_name() == "runtimeEngine.configureBoundSmartAccessRuntimeControl" ||
            call.method_name() == "runtimeEngine.configureSmartAccessRenewal") {
          const auto* arguments = MapArguments(call);
          const auto* profile = StringArgument(arguments, "profileDigest");
          const auto* config = StringArgument(arguments, "configJson");
          const bool bound = call.method_name() == "runtimeEngine.configureBoundSmartAccessRuntimeControl";
          const auto* request_id = StringArgument(arguments, "requestId");
          if (arguments == nullptr || arguments->size() != (bound ? 3 : 2) || profile == nullptr || config == nullptr ||
              (bound && (request_id == nullptr || !IsConnectRequestId(*request_id))) ||
              !pokrov::service::IsSmartAccessRuntimeControl(*profile + "|" + *config)) {
            reply->Error("invalid_smart_access_runtime_control", "Invalid runtime control request.");
            return;
          }
          std::string body = *profile + "|" + *config;
          std::string id;
          if (bound) {
            if (!pending_connect_bound_ || !pending_connect_ || pending_connect_request_id_ != *request_id ||
                !pending_connect_->completed || pending_connect_->cancel_requested) {
              reply->Error("connect_owner_changed", "Runtime control owner is unavailable.");
              return;
            }
            std::string target;
            {
              std::lock_guard<std::mutex> guard(pending_connect_->cancellation_lock);
              target = pending_connect_->bound_cancellation_target;
            }
            if (!pokrov::service::DecodeCancellationTarget(target)) {
              reply->Error("connect_owner_changed", "Runtime control owner is unavailable.");
              return;
            }
            id = *request_id;
            body = target + "|" + body;
          }
          const auto command = bound ? Command::kConfigureBoundSmartAccessRuntimeControl
              : call.method_name() == "runtimeEngine.configureSmartAccessRenewal"
              ? Command::kConfigureSmartAccessRenewal : Command::kConfigureSmartAccessRuntimeControl;
          if (!QueueRuntime(command, std::move(body),
              [this, reply, profile = *profile, id](auto snapshot) {
                if (!snapshot.command_accepted || !snapshot.compatible ||
                    (!id.empty() && (!pending_connect_bound_ || !pending_connect_ ||
                      pending_connect_request_id_ != id || pending_connect_->cancel_requested))) {
                  reply->Error("smart_access_runtime_control_unconfirmed", "Runtime control was not confirmed.");
                  return;
                }
                flutter::EncodableMap receipt{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("profileDigest"), flutter::EncodableValue(profile)},
                    {flutter::EncodableValue("configured"), flutter::EncodableValue(snapshot.smart_access_runtime_control_configured)}};
                if (!id.empty()) receipt.emplace(flutter::EncodableValue("requestId"), flutter::EncodableValue(id));
                reply->Success(flutter::EncodableValue(std::move(receipt)));
              })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.renewSmartAccessLease") {
          const auto* arguments = MapArguments(call);
          const auto* profile = StringArgument(arguments, "profileDigest");
          const auto* expected = StringArgument(arguments, "expectedLeaseId");
          const auto* next = StringArgument(arguments, "nextLeaseId");
          const auto* issued = StringArgument(arguments, "issuedAt");
          const auto* new_until = StringArgument(arguments, "newFlowsUntil");
          const auto* active_until = StringArgument(arguments, "activeFlowsUntil");
          if (arguments == nullptr || arguments->size() != 6 || profile == nullptr || expected == nullptr ||
              next == nullptr || issued == nullptr || new_until == nullptr || active_until == nullptr) {
            reply->Error("invalid_smart_access_renewal", "Invalid lease renewal.");
            return;
          }
          const auto body = pokrov::service::EncodeSmartAccessRenewal({*profile, *expected, *next, *issued, *new_until, *active_until});
          if (body.empty()) {
            reply->Error("invalid_smart_access_renewal", "Invalid lease renewal.");
            return;
          }
          if (!QueueRuntime(Command::kRenewSmartAccessLease, body,
              [reply, profile = *profile, expected = *expected, next = *next](auto snapshot) {
                if (!snapshot.command_accepted || !snapshot.compatible) {
                  reply->Error("smart_access_renewal_unconfirmed", "Lease renewal was not confirmed.");
                  return;
                }
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("profileDigest"), flutter::EncodableValue(profile)},
                    {flutter::EncodableValue("expectedLeaseId"), flutter::EncodableValue(expected)},
                    {flutter::EncodableValue("nextLeaseId"), flutter::EncodableValue(next)},
                    {flutter::EncodableValue("renewed"), flutter::EncodableValue(snapshot.smart_access_lease_renewed)}}));
              })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.revokeSmartAccessLease") {
          const auto* arguments = MapArguments(call);
          const auto* profile = StringArgument(arguments, "profileDigest");
          const auto* lease = StringArgument(arguments, "leaseId");
          const auto* terminate = BoolArgument(arguments, "terminateActive");
          if (arguments == nullptr || arguments->size() != 3 || profile == nullptr ||
              lease == nullptr || terminate == nullptr) {
            reply->Error("invalid_smart_access_revocation", "Invalid lease revocation.");
            return;
          }
          const auto body = pokrov::service::EncodeSmartAccessRevocation({*profile, *lease, *terminate});
          if (body.empty()) {
            reply->Error("invalid_smart_access_revocation", "Invalid lease revocation.");
            return;
          }
          if (!QueueRuntime(Command::kRevokeSmartAccessLease, body,
              [reply, profile = *profile, lease = *lease](auto snapshot) {
                if (!snapshot.command_accepted || !snapshot.compatible) {
                  reply->Error("smart_access_revoke_unconfirmed", "Lease revocation was not confirmed.");
                  return;
                }
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("profileDigest"), flutter::EncodableValue(profile)},
                    {flutter::EncodableValue("leaseId"), flutter::EncodableValue(lease)},
                    {flutter::EncodableValue("revoked"), flutter::EncodableValue(snapshot.smart_access_lease_found)}}));
              })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.revokeSmartAccessPolicy") {
          const auto* arguments = MapArguments(call);
          const auto* profile = StringArgument(arguments, "profileDigest");
          const auto* terminate = BoolArgument(arguments, "terminateActive");
          if (arguments == nullptr || arguments->size() != 2 || profile == nullptr ||
              terminate == nullptr || !pokrov::service::IsProfileDigest(*profile)) {
            reply->Error("invalid_smart_access_revocation", "Invalid policy revocation.");
            return;
          }
          if (!QueueRuntime(Command::kRevokeSmartAccessPolicy, *profile + (*terminate ? ":1" : ":0"),
              [reply, profile = *profile, terminate = *terminate](auto snapshot) {
                if (!snapshot.command_accepted || !snapshot.compatible) {
                  reply->Error("smart_access_revoke_unconfirmed", "Policy revocation was not confirmed.");
                  return;
                }
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("profileDigest"), flutter::EncodableValue(profile)},
                    {flutter::EncodableValue("terminateActive"), flutter::EncodableValue(terminate)},
                    {flutter::EncodableValue("revoked"), flutter::EncodableValue(snapshot.smart_access_lease_found)}}));
              })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          return;
        }
        if (call.method_name() == "runtimeEngine.crashDiagnostics") {
          if (!QueueRuntime(Command::kDiagnosticState, "", [reply](auto snapshot) {
            if (!snapshot.command_accepted) {
              reply->Error("crash_diagnostics_unavailable", "Crash diagnostics could not be read.");
              return;
            }
            flutter::EncodableList records;
            for (const auto& record : snapshot.crash_diagnostics) {
              records.emplace_back(flutter::EncodableMap{
                  {flutter::EncodableValue("occurred_at_unix_ms"), flutter::EncodableValue(record.occurred_at_unix_ms)},
                  {flutter::EncodableValue("error_code"), flutter::EncodableValue(record.error_code)},
                  {flutter::EncodableValue("signature"), flutter::EncodableValue(record.signature)}});
            }
            reply->Success(flutter::EncodableValue(records));
          })) reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
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
          const auto* requires_bound_connect =
              BoolArgument(arguments, "requiresBoundConnect");
          if (profile == nullptr || disable_memory_limit == nullptr ||
              materialized == nullptr || !*materialized ||
              requires_bound_connect == nullptr) {
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
          const auto* persisted_digest = StringArgument(arguments, "expectedProfileDigest");
          if (persisted_digest != nullptr && *persisted_digest != expected) {
            reply->Error("profile_identity_mismatch", "Prepared profile identity changed.");
            return;
          }
          if (snapshot_call(*requires_bound_connect ? Command::kStageBoundProfile
                                                    : Command::kStageProfile, body, expected)) {
            expected_profile_digest_ = expected;
          }
          return;
        }
        if (call.method_name() == "runtimeEngine.invalidateManagedProfile") {
          if (snapshot_call(Command::kInvalidateProfile, "", "")) expected_profile_digest_.clear();
          return;
        }
        if (call.method_name() == "runtimeEngine.connectWithCoreIdentity") {
          const auto* arguments = MapArguments(call);
          const auto* request_id = StringArgument(arguments, "requestId");
          const auto* core = StringArgument(arguments, "expectedCoreModuleSha256");
          const auto* profile = StringArgument(arguments, "expectedProfileDigest");
          const auto* network = StringArgument(arguments, "expectedNetworkContextRef");
          const auto* boot = StringArgument(arguments, "bootRef");
          const auto started = ElapsedArgument(arguments, "startedElapsedMs");
          const auto deadline = ElapsedArgument(arguments, "deadlineElapsedMs");
          if (arguments == nullptr || arguments->size() != 7 || request_id == nullptr ||
              !IsConnectRequestId(*request_id) || *request_id == pending_connect_request_id_ ||
              core == nullptr || profile == nullptr || boot == nullptr || network == nullptr || !started || !deadline) {
            reply->Error("invalid_connect_request", "Exact connection identity and deadline are required.");
            return;
          }
          const pokrov::service::BoundConnectTarget target{*core, *profile, *boot, *started, *deadline, *network};
          const auto body = pokrov::service::EncodeBoundConnect(target);
          const auto not_dispatched = [reply, id = *request_id] {
            reply->Error("core_identity_connect_not_dispatched", "Connection request was not dispatched.",
                flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("requestId"), flutter::EncodableValue(id)},
                    {flutter::EncodableValue("settled"), flutter::EncodableValue(true)},
                }));
          };
          if (body.empty() || *profile != expected_profile_digest_) {
            not_dispatched();
            return;
          }
          if (!QueueRuntime(Command::kConnectWithIdentity, body,
              [this, reply, id = *request_id, target](auto snapshot) {
                if (pending_connect_request_id_ != id || !pending_connect_ || pending_connect_->cancel_requested) {
                  reply->Error("operation_cancelled", "Connection request was cancelled.");
                  return;
                }
                if (!snapshot.command_accepted || !snapshot.running ||
                    snapshot.core_module_sha256 != target.core_module_sha256 ||
                    snapshot.effective_profile_digest != target.profile_digest) {
                  reply->Error("core_identity_connect_failed", "Service did not acknowledge this connection.");
                  return;
                }
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("requestId"), flutter::EncodableValue(id)},
                    {flutter::EncodableValue("snapshot"), RuntimeSnapshotValue(std::move(snapshot), target.profile_digest)},
                }));
              }, *request_id)) {
            not_dispatched();
          }
          return;
        }
        if (call.method_name() == "runtimeEngine.promoteBoundTransportLease") {
          const auto* arguments = MapArguments(call);
          const auto* request_id = StringArgument(arguments, "requestId");
          const auto* profile = StringArgument(arguments, "profileDigest");
          const auto* lease = StringArgument(arguments, "endpointLeaseRef");
          const auto* issued = StringArgument(arguments, "issuedAt");
          const auto* new_until = StringArgument(arguments, "newFlowsUntil");
          const auto* active_until = StringArgument(arguments, "activeFlowsUntil");
          if (arguments == nullptr || arguments->size() != 6 || request_id == nullptr ||
              profile == nullptr || lease == nullptr || issued == nullptr || new_until == nullptr ||
              active_until == nullptr || !pending_connect_bound_ || !pending_connect_ ||
              pending_connect_request_id_ != *request_id || !pending_connect_->completed ||
              pending_connect_->cancel_requested || *profile != expected_profile_digest_) {
            reply->Error("transport_lease_handoff_unavailable", "Bound connection unavailable.");
            return;
          }
          std::string encoded_target;
          {
            std::lock_guard<std::mutex> guard(pending_connect_->cancellation_lock);
            encoded_target = pending_connect_->bound_cancellation_target;
          }
          const auto target = pokrov::service::DecodeCancellationTarget(encoded_target);
          const auto body = target ? pokrov::service::EncodeTransportLeasePromotion(
              pokrov::service::TransportLeasePromotion{*target, *profile, *lease,
                  *issued, *new_until, *active_until}) : "";
          if (body.empty()) {
            reply->Error("invalid_transport_lease_handoff", "Invalid transport lease.");
            return;
          }
          if (!QueueRuntime(Command::kPromoteTransportLease, body,
              [this, reply, id = *request_id, profile = *profile](auto snapshot) {
                if (pending_connect_request_id_ != id || !pending_connect_bound_ || !pending_connect_ ||
                    pending_connect_->cancel_requested || !snapshot.command_accepted ||
                    !snapshot.compatible || !snapshot.running || !snapshot.core_egress_validated ||
                    !snapshot.transport_proof_state_available || snapshot.transport_proof_pending ||
                    snapshot.effective_profile_digest != profile) {
                  reply->Error("transport_lease_handoff_unconfirmed", "Transport lease unavailable.");
                  return;
                }
                pending_connect_promoted_ = true;
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("requestId"), flutter::EncodableValue(id)},
                    {flutter::EncodableValue("snapshot"), RuntimeSnapshotValue(std::move(snapshot), profile)},
                }));
              })) {
            reply->Error("transport_lease_handoff_unavailable", "Runtime request queue unavailable.");
          }
          return;
        }
        if (call.method_name() == "runtimeEngine.revokeBoundTransportLease") {
          const auto* arguments = MapArguments(call);
          const auto* request_id = StringArgument(arguments, "requestId");
          const auto* profile = StringArgument(arguments, "profileDigest");
          const auto* lease = StringArgument(arguments, "endpointLeaseRef");
          const auto* terminate = BoolArgument(arguments, "terminateActive");
          if (arguments == nullptr || arguments->size() != 4 || request_id == nullptr ||
              profile == nullptr || lease == nullptr || terminate == nullptr ||
              !pending_connect_bound_ || !pending_connect_ ||
              pending_connect_request_id_ != *request_id || !pending_connect_->completed ||
              pending_connect_->cancel_requested || *profile != expected_profile_digest_) {
            reply->Error("transport_lease_revocation_unavailable", "Bound connection unavailable.");
            return;
          }
          std::string encoded_target;
          {
            std::lock_guard<std::mutex> guard(pending_connect_->cancellation_lock);
            encoded_target = pending_connect_->bound_cancellation_target;
          }
          const auto target = pokrov::service::DecodeCancellationTarget(encoded_target);
          const auto body = target ? pokrov::service::EncodeTransportLeaseRevocation(
              pokrov::service::TransportLeaseRevocation{*target, *profile, *lease, *terminate}) : "";
          if (body.empty()) {
            reply->Error("invalid_transport_lease_revocation", "Invalid transport lease.");
            return;
          }
          if (!QueueRuntime(Command::kRevokeTransportLease, body,
              [this, reply, id = *request_id, profile = *profile, terminal = *terminate](auto snapshot) {
                if (pending_connect_request_id_ != id || !pending_connect_bound_ || !pending_connect_ ||
                    pending_connect_->cancel_requested || !snapshot.command_accepted ||
                    !snapshot.compatible || !snapshot.running || snapshot.core_egress_validated ||
                    (terminal && (!snapshot.transport_proof_state_available || !snapshot.transport_proof_pending ||
                                  !snapshot.transport_lease_state_available || snapshot.transport_lease_active)) ||
                    snapshot.effective_profile_digest != profile) {
                  reply->Error("transport_lease_revocation_unconfirmed", "Transport lease unavailable.");
                  return;
                }
                reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                    {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                    {flutter::EncodableValue("requestId"), flutter::EncodableValue(id)},
                    {flutter::EncodableValue("snapshot"), RuntimeSnapshotValue(std::move(snapshot), profile)},
                }));
              })) {
            reply->Error("transport_lease_revocation_unavailable", "Runtime request queue unavailable.");
          }
          return;
        }
        if (call.method_name() == "runtimeEngine.connect") {
          const auto* arguments = MapArguments(call);
          const auto* request_id = StringArgument(arguments, "requestId");
          if (arguments == nullptr || arguments->size() != 1 || request_id == nullptr ||
              !IsConnectRequestId(*request_id) || *request_id == pending_connect_request_id_) {
            reply->Error("invalid_connect_request", "A fresh connection request ID is required.");
            return;
          }
          if (!QueueRuntime(Command::kConnect, expected_profile_digest_,
              [reply, expected = expected_profile_digest_](auto snapshot) {
                reply->Success(RuntimeSnapshotValue(std::move(snapshot), expected));
              }, *request_id)) {
            reply->Error("runtime_busy", "Runtime request queue is full or shutting down.");
          }
          return;
        }
        if (call.method_name() == "runtimeEngine.cancelAndConfirmConnectStopped") {
          const auto* arguments = MapArguments(call);
          const auto* request_id = StringArgument(arguments, "requestId");
          if (arguments == nullptr || arguments->size() != 1 || request_id == nullptr || !IsConnectRequestId(*request_id)) {
            reply->Error("invalid_connect_request", "A connection request ID is required.");
            return;
          }
          const auto respond = [reply, id = *request_id](bool settled) {
            reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                {flutter::EncodableValue("requestId"), flutter::EncodableValue(id)},
                {flutter::EncodableValue("settled"), flutter::EncodableValue(settled)},
            }));
          };
          if (!pending_connect_bound_ || !pending_connect_ || pending_connect_request_id_ != *request_id) {
            respond(stopped_connect_request_id_ == *request_id);
            return;
          }
          const auto owner = pending_connect_;
          owner->cancel_requested = true;
          if (!runtime_tasks_ || !runtime_tasks_->Submit(Command::kCancelConnectAndConfirm, "", owner,
              [this, owner, respond, id = *request_id](auto snapshot) {
                if (!snapshot.command_accepted) {
                  respond(false);
                  return;
                }
                if (snapshot.connect_stopped && pending_connect_ == owner) {
                  stopped_connect_request_id_ = id;
                  pending_connect_.reset();
                  pending_connect_request_id_.clear();
                  pending_connect_bound_ = false;
                  pending_connect_promoted_ = false;
                }
                respond(snapshot.connect_stopped);
              })) {
            reply->Error("connect_cancel_unconfirmed", "Cancellation queue is unavailable.");
          }
          return;
        }
        if (call.method_name() == "runtimeEngine.cancelConnectRequest") {
          const auto* arguments = MapArguments(call);
          const auto* request_id = StringArgument(arguments, "requestId");
          if (arguments == nullptr || arguments->size() != 1 || request_id == nullptr ||
              !IsConnectRequestId(*request_id)) {
            reply->Error("invalid_connect_request", "A connection request ID is required.");
            return;
          }
          if (pending_connect_bound_ && pending_connect_ && *request_id == pending_connect_request_id_) {
            const auto owner = pending_connect_;
            owner->cancel_requested = true;
            // The atomic flag reaches an in-flight call immediately. This
            // queued exact lookup also handles an already completed response.
            if (!runtime_tasks_ || !runtime_tasks_->Submit(Command::kCancel, "", owner,
                [reply, id = *request_id](auto snapshot) {
                  if (!snapshot.command_accepted) {
                    reply->Error("connect_cancel_unconfirmed", "Service cancellation was not acknowledged.");
                    return;
                  }
                  // ACK only admits cancellation. The exact settlement call
                  // must confirm restoration before this bound owner retires.
                  reply->Success(flutter::EncodableValue(flutter::EncodableMap{
                      {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
                      {flutter::EncodableValue("requestId"), flutter::EncodableValue(id)},
                      {flutter::EncodableValue("cancelled"), flutter::EncodableValue(true)},
                  }));
                })) {
              reply->Error("connect_cancel_unconfirmed", "Cancellation queue is unavailable.");
            }
            return;
          }
          const bool accepted = pending_connect_ != nullptr &&
              *request_id == pending_connect_request_id_ && !pending_connect_->completed.load();
          if (accepted) pending_connect_->cancel_requested = true;
          reply->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("schema"), flutter::EncodableValue(1)},
              {flutter::EncodableValue("requestId"), flutter::EncodableValue(*request_id)},
              {flutter::EncodableValue("cancelled"), flutter::EncodableValue(accepted)},
          }));
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
  if (pending_connect_bound_ && pending_connect_ && !pending_connect_promoted_) pending_connect_->cancel_requested = true;
  if (diagnostic_tasks_) {
    diagnostic_tasks_->Shutdown();
    diagnostic_tasks_.reset();
  }
  if (runtime_tasks_) {
    runtime_tasks_->Shutdown();
    runtime_tasks_.reset();
  }
  if (pending_connect_bound_ && pending_connect_ &&
      (!pending_connect_promoted_ || pending_connect_->cancel_requested)) {
    // An unpromoted attempt or explicit stop still needs the exact lookup.
    // An accepted lease stays with the service after this window closes.
    pokrov::service::CancelInstalledServiceConnect(pending_connect_.get());
  }
  pending_connect_.reset();
  pending_connect_request_id_.clear();
  pending_connect_bound_ = false;
  pending_connect_promoted_ = false;
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
    if (diagnostic_tasks_) diagnostic_tasks_->Drain();
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
