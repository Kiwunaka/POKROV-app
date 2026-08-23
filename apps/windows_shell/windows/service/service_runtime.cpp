#include "service_runtime.h"

#include <windows.h>

#include <aclapi.h>
#include <knownfolders.h>
#include <sddl.h>
#include <shlobj.h>
#include <winhttp.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <climits>
#include <cstdio>
#include <memory>
#include <mutex>
#include <string>
#include <utility>

namespace pokrov::service {
namespace {

constexpr char kCoreCapabilities[] =
    "{\"schema_version\":1,\"desktop_abi\":2,\"event_abi\":1,"
    "\"capabilities\":[\"bounded_stop_reason\",\"core_start_stop\","
    "\"materialized_profile\",\"secure_profile_file\","
    "\"structured_operational_events\",\"typed_lifecycle_events\"],"
    "\"lifecycle_events\":[\"initialization\","
    "\"profile\",\"core_start\",\"tun\",\"routes\",\"dns\",\"egress\","
    "\"recovery\",\"stop\"],\"operational_events\":{"
    "\"contract\":\"config/core-event-abi.json\",\"schema_version\":1,"
    "\"event_abi\":1,\"callback_symbol\":\"pokrovCoreSetEventCallback\","
    "\"context_symbol\":\"pokrovCoreSetEventContext\","
    "\"maximum_pending_events\":128}}";
constexpr char kLegacyCoreCapabilities[] =
    "{\"schema_version\":1,\"desktop_abi\":2,\"event_abi\":1,"
    "\"capabilities\":[\"bounded_stop_reason\",\"core_start_stop\","
    "\"materialized_profile\",\"secure_profile_file\","
    "\"typed_lifecycle_events\"],\"lifecycle_events\":[\"initialization\","
    "\"profile\",\"core_start\",\"tun\",\"routes\",\"dns\",\"egress\","
    "\"recovery\",\"stop\"]}";
constexpr wchar_t kPrivateRuntimeSddl[] =
    L"D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)";

std::wstring AppendPath(const std::wstring& base, const wchar_t* child) {
  if (base.empty()) {
    return L"";
  }
  return base + (base.back() == L'\\' ? L"" : L"\\") + child;
}

std::wstring CurrentExecutableDirectory() {
  std::wstring path(32768, L'\0');
  const DWORD length = ::GetModuleFileNameW(
      nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) {
    return L"";
  }
  path.resize(length);
  const auto separator = path.find_last_of(L"\\/");
  return separator == std::wstring::npos ? L"" : path.substr(0, separator);
}

std::string Utf8(const std::wstring& value) {
  if (value.empty()) {
    return "";
  }
  const int size = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
  if (size <= 0) {
    return "";
  }
  std::string encoded(static_cast<std::size_t>(size), '\0');
  if (::WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
                            static_cast<int>(value.size()), encoded.data(),
                            size, nullptr, nullptr) != size) {
    return "";
  }
  return encoded;
}

bool IsValidUtf8JsonObject(const std::string& value) {
  if (value.empty() || value.find('\0') != std::string::npos) {
    return false;
  }
  const auto first = value.find_first_not_of(" \t\r\n");
  const auto last = value.find_last_not_of(" \t\r\n");
  if (first == std::string::npos || value[first] != '{' ||
      value[last] != '}') {
    return false;
  }
  return ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                               static_cast<int>(value.size()), nullptr, 0) > 0;
}

bool IsLowerHex(char value) {
  return (value >= '0' && value <= '9') ||
         (value >= 'a' && value <= 'f');
}

bool IsLowerUuid(const std::string& value) {
  if (value.size() != 36 || value[8] != '-' || value[13] != '-' ||
      value[18] != '-' || value[23] != '-' || value[14] < '1' ||
      value[14] > '5' || std::string("89ab").find(value[19]) ==
                               std::string::npos) {
    return false;
  }
  for (std::size_t index = 0; index < value.size(); ++index) {
    if (index == 8 || index == 13 || index == 18 || index == 23) {
      continue;
    }
    if (!IsLowerHex(value[index])) {
      return false;
    }
  }
  return true;
}

bool IsUtcTimestamp(const std::string& value) {
  if (value.size() < 20 || value.size() > 30 || value.back() != 'Z' ||
      value[4] != '-' || value[7] != '-' || value[10] != 'T' ||
      value[13] != ':' || value[16] != ':') {
    return false;
  }
  for (std::size_t index = 0; index + 1 < value.size(); ++index) {
    const char character = value[index];
    if (!std::isdigit(static_cast<unsigned char>(character)) &&
        character != '-' && character != 'T' && character != ':' &&
        character != '.') {
      return false;
    }
  }
  return true;
}

std::string NewUuid() {
  GUID value{};
  if (FAILED(::CoCreateGuid(&value))) {
    return "";
  }
  char encoded[37]{};
  const int written = std::snprintf(
      encoded, sizeof(encoded),
      "%08lx-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x",
      static_cast<unsigned long>(value.Data1), value.Data2, value.Data3,
      value.Data4[0], value.Data4[1], value.Data4[2], value.Data4[3],
      value.Data4[4], value.Data4[5], value.Data4[6], value.Data4[7]);
  return written == 36 ? std::string(encoded) : "";
}

bool IsCoreEventDefinition(const CoreOperationalEventRecord& event) {
  return (event.name == "core.runtime.initialize" &&
          event.subsystem == "core" && event.stage == "initialize" &&
          event.phase == "initialization") ||
         (event.name == "core.runtime.start" &&
          event.subsystem == "core" && event.stage == "start" &&
          event.phase == "core_start") ||
         (event.name == "core.runtime.stop" &&
          event.subsystem == "core" && event.stage == "stop" &&
          event.phase == "stop") ||
         (event.name == "core.egress.probe" &&
          event.subsystem == "egress" && event.stage == "verify" &&
          event.phase == "egress");
}

bool IsCoreErrorCode(const std::string& value) {
  return value == "CORE-003" || value == "CORE-005" ||
         value == "CORE-006" || value == "CORE-008" ||
         value == "TRANSPORT-001" || value == "TRANSPORT-002" ||
         value == "TRANSPORT-003" || value == "TRANSPORT-004" ||
         value == "EGRESS-001";
}

bool EnsureDirectory(const std::wstring& path) {
  return !path.empty() &&
         (::CreateDirectoryW(path.c_str(), nullptr) != FALSE ||
          ::GetLastError() == ERROR_ALREADY_EXISTS) &&
         (::GetFileAttributesW(path.c_str()) & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

bool ProtectDirectory(const std::wstring& path) {
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (!::ConvertStringSecurityDescriptorToSecurityDescriptorW(
          kPrivateRuntimeSddl, SDDL_REVISION_1, &descriptor, nullptr)) {
    return false;
  }
  BOOL present = FALSE;
  BOOL defaulted = FALSE;
  PACL dacl = nullptr;
  const bool decoded =
      ::GetSecurityDescriptorDacl(descriptor, &present, &dacl, &defaulted) !=
          FALSE &&
      present != FALSE;
  const DWORD result = decoded
                           ? ::SetNamedSecurityInfoW(
                                 const_cast<wchar_t*>(path.c_str()),
                                 SE_FILE_OBJECT,
                                 DACL_SECURITY_INFORMATION |
                                     PROTECTED_DACL_SECURITY_INFORMATION,
                                 nullptr, nullptr, dacl, nullptr)
                           : ERROR_INVALID_SECURITY_DESCR;
  ::LocalFree(descriptor);
  return result == ERROR_SUCCESS;
}

const char* PhaseName(int phase) {
  switch (phase) {
    case 0:
      return "artifact_missing";
    case 1:
      return "artifact_ready";
    case 2:
      return "initialized";
    case 3:
      return "config_staged";
    case 4:
      return "running";
    case 5:
      return "recovery_required";
    default:
      return "artifact_missing";
  }
}

class InstalledCoreRuntime final : public CoreRuntime {
 public:
  ~InstalledCoreRuntime() override {
    if (set_event_callback_ != nullptr) {
      set_event_callback_(nullptr);
    }
    std::lock_guard<std::mutex> guard(callback_lock_);
    if (callback_runtime_ == this) {
      callback_runtime_ = nullptr;
    }
  }

  void SetOperationalEventSink(ServiceEventSink* events) override {
    events_ = events;
  }

  std::string Initialize(const RuntimeDirectories& directories) override {
    if (initialized_) {
      return "";
    }
    const auto directory = CurrentExecutableDirectory();
    const auto library_path = AppendPath(directory, L"pokrov-core.dll");
    if (directory.empty() ||
        ::GetFileAttributesW(library_path.c_str()) == INVALID_FILE_ATTRIBUTES) {
      return "core_missing";
    }
    module_ = ::LoadLibraryExW(
        library_path.c_str(), nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (module_ == nullptr) {
      return "core_load_failed";
    }

    abi_ = reinterpret_cast<AbiFunction>(
        ::GetProcAddress(module_, "pokrovCoreAbiVersion"));
    capabilities_ = reinterpret_cast<CapabilitiesFunction>(
        ::GetProcAddress(module_, "pokrovCoreCapabilities"));
    set_event_callback_ = reinterpret_cast<SetEventCallbackFunction>(
        ::GetProcAddress(module_, "pokrovCoreSetEventCallback"));
    set_event_context_ = reinterpret_cast<SetEventContextFunction>(
        ::GetProcAddress(module_, "pokrovCoreSetEventContext"));
    setup_ = reinterpret_cast<SetupFunction>(
        ::GetProcAddress(module_, "setup"));
    secure_file_ = reinterpret_cast<SecureFileFunction>(
        ::GetProcAddress(module_, "pokrovSecureFile"));
    start_ = reinterpret_cast<StartFunction>(
        ::GetProcAddress(module_, "start"));
    stop_ = reinterpret_cast<StopFunction>(::GetProcAddress(module_, "stop"));
    free_string_ = reinterpret_cast<FreeStringFunction>(
        ::GetProcAddress(module_, "freeString"));
    if (abi_ == nullptr || setup_ == nullptr || secure_file_ == nullptr ||
        start_ == nullptr || stop_ == nullptr || free_string_ == nullptr ||
        abi_() != 2) {
      return "core_abi_incompatible";
    }
    if (capabilities_ != nullptr) {
      const auto descriptor = StringResult(capabilities_());
      if (descriptor == kCoreCapabilities) {
        structured_events_ = true;
      } else if (descriptor != kLegacyCoreCapabilities) {
        return "core_capabilities_incompatible";
      }
    }

    if (structured_events_) {
      if (set_event_callback_ == nullptr || set_event_context_ == nullptr) {
        return "core_abi_incompatible";
      }
      run_id_ = NewUuid();
      attempt_id_ = NewUuid();
      generation_ = 1;
      if (run_id_.empty() || attempt_id_.empty() ||
          !event_fence_.Activate(run_id_, attempt_id_, generation_)) {
        return "core_event_context_failed";
      }
      {
        std::lock_guard<std::mutex> guard(callback_lock_);
        callback_runtime_ = this;
      }
      set_event_callback_(&InstalledCoreRuntime::ReceiveOperationalEvent);
      if (!StringResult(set_event_context_(run_id_.c_str(),
                                           attempt_id_.c_str(), generation_))
               .empty()) {
        set_event_callback_(nullptr);
        std::lock_guard<std::mutex> guard(callback_lock_);
        callback_runtime_ = nullptr;
        return "core_event_context_failed";
      }
    }

    const auto base = Utf8(directories.base);
    const auto working = Utf8(directories.working);
    const auto temporary = Utf8(directories.temporary);
    if (base.empty() || working.empty() || temporary.empty()) {
      return "runtime_path_invalid";
    }
    const auto error = StringResult(setup_(base.c_str(), working.c_str(),
                                           temporary.c_str(), 0, "", "", 0,
                                           false));
    if (!error.empty()) {
      return "core_setup_failed";
    }
    initialized_ = true;
    return "";
  }

  std::string SecureFile(const std::wstring& path) override {
    const auto encoded = Utf8(path);
    if (!initialized_ || encoded.empty()) {
      return "core_not_initialized";
    }
    return StringResult(secure_file_(encoded.c_str())).empty()
               ? ""
               : "profile_security_failed";
  }

  std::string Start(const std::wstring& config_path,
                    bool disable_memory_limit) override {
    const auto encoded = Utf8(config_path);
    if (!initialized_ || encoded.empty()) {
      return "core_not_initialized";
    }
    if (structured_events_ && start_attempts_ > 0 && !BeginNextAttempt()) {
      return "core_event_context_failed";
    }
    ++start_attempts_;
    return StringResult(start_(encoded.c_str(), disable_memory_limit)).empty()
               ? ""
               : "core_start_failed";
  }

  std::string Stop() override {
    if (!initialized_) {
      return "";
    }
    return StringResult(stop_()).empty() ? "" : "core_stop_failed";
  }

 private:
  using EventCallback = void(__cdecl*)(
      int, int, const char*, const char*, const char*, long long, long long,
      const char*, const char*, const char*, const char*, const char*,
      const char*, const char*);
  using AbiFunction = int(__cdecl*)();
  using CapabilitiesFunction = char*(__cdecl*)();
  using SetEventCallbackFunction = void(__cdecl*)(EventCallback);
  using SetEventContextFunction = char*(__cdecl*)(const char*, const char*,
                                                  long long);
  using SetupFunction = char*(__cdecl*)(const char*, const char*, const char*,
                                        int, const char*, const char*,
                                        long long, bool);
  using SecureFileFunction = char*(__cdecl*)(const char*);
  using StartFunction = char*(__cdecl*)(const char*, bool);
  using StopFunction = char*(__cdecl*)();
  using FreeStringFunction = void(__cdecl*)(char*);

  bool BeginNextAttempt() {
    const auto attempt_id = NewUuid();
    const auto generation = generation_ + 1;
    std::lock_guard<std::mutex> guard(callback_lock_);
    if (attempt_id.empty() || generation > INT_MAX ||
        !event_fence_.Activate(run_id_, attempt_id, generation)) {
      return false;
    }
    if (!StringResult(set_event_context_(run_id_.c_str(), attempt_id.c_str(),
                                         generation))
             .empty()) {
      return false;
    }
    attempt_id_ = attempt_id;
    generation_ = generation;
    return true;
  }

  static void __cdecl ReceiveOperationalEvent(
      int schema_version, int event_abi, const char* occurred_at_utc,
      const char* run_id, const char* attempt_id, long long generation,
      long long sequence, const char* name, const char* subsystem,
      const char* stage, const char* severity, const char* outcome,
      const char* error_code, const char* phase) {
    std::lock_guard<std::mutex> guard(callback_lock_);
    if (callback_runtime_ == nullptr || occurred_at_utc == nullptr ||
        run_id == nullptr || attempt_id == nullptr || name == nullptr ||
        subsystem == nullptr || stage == nullptr || severity == nullptr ||
        outcome == nullptr || error_code == nullptr || phase == nullptr) {
      return;
    }
    callback_runtime_->AcceptOperationalEvent(CoreOperationalEventRecord{
        schema_version,
        event_abi,
        occurred_at_utc,
        run_id,
        attempt_id,
        generation,
        sequence,
        name,
        subsystem,
        stage,
        severity,
        outcome,
        error_code,
        phase,
    });
  }

  void AcceptOperationalEvent(const CoreOperationalEventRecord& event) {
    if (events_ != nullptr && event_fence_.Accept(event)) {
      events_->RecordCoreOperationalEvent(event);
    }
  }

  std::string StringResult(char* value) const {
    if (value == nullptr) {
      return "";
    }
    const std::string result(value);
    free_string_(value);
    return result;
  }

  HMODULE module_ = nullptr;
  AbiFunction abi_ = nullptr;
  CapabilitiesFunction capabilities_ = nullptr;
  SetEventCallbackFunction set_event_callback_ = nullptr;
  SetEventContextFunction set_event_context_ = nullptr;
  SetupFunction setup_ = nullptr;
  SecureFileFunction secure_file_ = nullptr;
  StartFunction start_ = nullptr;
  StopFunction stop_ = nullptr;
  FreeStringFunction free_string_ = nullptr;
  ServiceEventSink* events_ = nullptr;
  CoreOperationalEventFence event_fence_;
  std::string run_id_;
  std::string attempt_id_;
  std::int64_t generation_ = 0;
  int start_attempts_ = 0;
  bool structured_events_ = false;
  bool initialized_ = false;
  static std::mutex callback_lock_;
  static InstalledCoreRuntime* callback_runtime_;
};

std::mutex InstalledCoreRuntime::callback_lock_;
InstalledCoreRuntime* InstalledCoreRuntime::callback_runtime_ = nullptr;

class AuthenticatedEgressProbe final : public RuntimeEgressProbe {
 public:
  std::string Verify() override {
    for (int attempt = 0; attempt < 3; ++attempt) {
      if (ProbeOnce()) {
        return "";
      }
      if (attempt < 2) {
        ::Sleep(attempt == 0 ? 900 : 1500);
      }
    }
    return "core_egress_probe_failed";
  }

 private:
  bool ProbeOnce() {
    HINTERNET session = ::WinHttpOpen(
        L"POKROVService/1.2", WINHTTP_ACCESS_TYPE_NO_PROXY,
        WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (session == nullptr) {
      return false;
    }
    ::WinHttpSetTimeouts(session, 3000, 3000, 3000, 6000);
    HINTERNET connection = ::WinHttpConnect(
        session, L"api.pokrov.space", INTERNET_DEFAULT_HTTPS_PORT, 0);
    HINTERNET request =
        connection == nullptr
            ? nullptr
            : ::WinHttpOpenRequest(
                  connection, L"GET",
                  L"/api/public/authenticated-egress-probe", nullptr,
                  WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
                  WINHTTP_FLAG_SECURE | WINHTTP_FLAG_REFRESH);
    bool valid = request != nullptr &&
                 ::WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS,
                                      0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0) !=
                     FALSE &&
                 ::WinHttpReceiveResponse(request, nullptr) != FALSE;
    DWORD status = 0;
    DWORD status_size = sizeof(status);
    if (valid) {
      valid = ::WinHttpQueryHeaders(
                  request,
                  WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                  WINHTTP_HEADER_NAME_BY_INDEX, &status, &status_size,
                  WINHTTP_NO_HEADER_INDEX) != FALSE &&
              status == HTTP_STATUS_NO_CONTENT;
    }
    std::array<wchar_t, 64> proof{};
    DWORD proof_size = static_cast<DWORD>(proof.size() * sizeof(wchar_t));
    if (valid) {
      valid = ::WinHttpQueryHeaders(
                  request, WINHTTP_QUERY_CUSTOM,
                  L"x-pokrov-egress-probe", proof.data(), &proof_size,
                  WINHTTP_NO_HEADER_INDEX) != FALSE &&
              std::wstring(proof.data()) == L"pokrov-authenticated-egress-v1";
    }
    if (request != nullptr) {
      ::WinHttpCloseHandle(request);
    }
    if (connection != nullptr) {
      ::WinHttpCloseHandle(connection);
    }
    ::WinHttpCloseHandle(session);
    return valid;
  }
};

}  // namespace

bool CoreOperationalEventFence::Activate(const std::string& run_id,
                                         const std::string& attempt_id,
                                         std::int64_t generation) {
  if (!IsLowerUuid(run_id) || !IsLowerUuid(attempt_id) || generation < 1 ||
      generation > INT_MAX || generation < generation_) {
    return false;
  }
  if (generation > generation_) {
    last_sequence_ = 0;
  }
  run_id_ = run_id;
  attempt_id_ = attempt_id;
  generation_ = generation;
  return true;
}

bool CoreOperationalEventFence::Accept(
    const CoreOperationalEventRecord& event) {
  if (event.schema_version != 1 || event.event_abi != 1 ||
      event.run_id != run_id_ || event.attempt_id != attempt_id_ ||
      event.generation != generation_ || event.sequence <= last_sequence_ ||
      !IsUtcTimestamp(event.occurred_at_utc) ||
      !IsCoreEventDefinition(event)) {
    return false;
  }
  const bool failed = event.outcome == "failed";
  if ((event.outcome != "started" && event.outcome != "succeeded" &&
       !failed) ||
      (failed &&
       (event.severity != "error" || !IsCoreErrorCode(event.error_code))) ||
      (!failed &&
       (event.severity != "info" || !event.error_code.empty()))) {
    return false;
  }
  last_sequence_ = event.sequence;
  return true;
}

RuntimeHost::RuntimeHost(std::unique_ptr<CoreRuntime> core,
                         std::unique_ptr<RuntimeEgressProbe> egress_probe,
                         std::unique_ptr<RuntimeRecovery> recovery,
                         std::wstring runtime_root, bool secure_storage,
                         ServiceEventSink* events)
    : core_(std::move(core)),
      egress_probe_(std::move(egress_probe)),
      recovery_(std::move(recovery)),
      runtime_root_(std::move(runtime_root)),
      events_(events),
      secure_storage_(secure_storage) {
  if (core_ != nullptr) {
    core_->SetOperationalEventSink(events_);
  }
  if (core_ != nullptr && !runtime_root_.empty()) {
    phase_ = Phase::kArtifactReady;
    failure_.clear();
  }
}

RuntimeHost::~RuntimeHost() { Shutdown(); }

RuntimeResult RuntimeHost::Snapshot() const {
  return RuntimeResult{Status::kOk, SnapshotBody()};
}

RuntimeResult RuntimeHost::Initialize() {
  if (initialized_) {
    return Snapshot();
  }
  if (core_ == nullptr || runtime_root_.empty()) {
    RecordEvent(ServiceEvent::kRuntimeInitialize,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, "core_missing");
  }
  RecordEvent(ServiceEvent::kRuntimeInitialize,
              ServiceEventOutcome::kAttempted);
  if (!PrepareDirectories()) {
    RecordEvent(ServiceEvent::kRuntimeInitialize,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, "runtime_directory_failed");
  }
  const auto error = core_->Initialize(directories_);
  if (!error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeInitialize,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, error.c_str());
  }
  const auto recovery_error = RecoverPendingRuntime();
  if (!recovery_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeInitialize,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, recovery_error.c_str());
  }
  initialized_ = true;
  phase_ = Phase::kInitialized;
  failure_.clear();
  RecordEvent(ServiceEvent::kRuntimeInitialize,
              ServiceEventOutcome::kSucceeded);
  return Snapshot();
}

RuntimeResult RuntimeHost::StageProfile(const std::string& body) {
  RecordEvent(ServiceEvent::kRuntimeProfileStage,
              ServiceEventOutcome::kAttempted);
  if (!initialized_) {
    const auto initialized = Initialize();
    if (initialized.status != Status::kOk) {
      RecordEvent(ServiceEvent::kRuntimeProfileStage,
                  ServiceEventOutcome::kFailed);
      return initialized;
    }
  }
  if (phase_ == Phase::kRunning || phase_ == Phase::kRecoveryRequired ||
      body.size() < 4 ||
      (body[0] != '0' && body[0] != '1') || body[1] != '\n') {
    RecordEvent(ServiceEvent::kRuntimeProfileStage,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kInvalid, "profile_request_invalid");
  }
  const std::string profile = body.substr(2);
  if (!IsValidUtf8JsonObject(profile)) {
    RecordEvent(ServiceEvent::kRuntimeProfileStage,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kInvalid, "profile_payload_invalid");
  }
  if (!WriteProfileAtomically(profile)) {
    RecordEvent(ServiceEvent::kRuntimeProfileStage,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, "profile_write_failed");
  }
  if (!core_->SecureFile(profile_path_).empty()) {
    ::DeleteFileW(profile_path_.c_str());
    RecordEvent(ServiceEvent::kRuntimeProfileStage,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, "profile_security_failed");
  }
  disable_memory_limit_ = body[0] == '1';
  profile_staged_ = true;
  phase_ = Phase::kConfigStaged;
  failure_.clear();
  RecordEvent(ServiceEvent::kRuntimeProfileStage,
              ServiceEventOutcome::kSucceeded);
  return Snapshot();
}

RuntimeResult RuntimeHost::InvalidateProfile() {
  if (phase_ == Phase::kRunning) {
    return Fail(Status::kNotReady, "runtime_running");
  }
  if (phase_ == Phase::kRecoveryRequired) {
    return Fail(Status::kNotReady, "recovery_required");
  }
  if (!profile_path_.empty()) {
    ::DeleteFileW(profile_path_.c_str());
  }
  profile_staged_ = false;
  disable_memory_limit_ = false;
  phase_ = initialized_ ? Phase::kInitialized : Phase::kArtifactReady;
  failure_.clear();
  return Snapshot();
}

RuntimeResult RuntimeHost::Connect() {
  if (!initialized_ || !profile_staged_) {
    return Fail(Status::kNotReady, "profile_not_staged");
  }
  if (phase_ == Phase::kRunning) {
    return Snapshot();
  }
  if (phase_ == Phase::kRecoveryRequired) {
    return Fail(Status::kNotReady, "recovery_required");
  }
  if (recovery_ == nullptr) {
    return Fail(Status::kNotReady, "recovery_unavailable");
  }
  RecordEvent(ServiceEvent::kRuntimeNetworkSnapshot,
              ServiceEventOutcome::kAttempted);
  auto recovery_error = recovery_->Begin();
  if (!recovery_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeNetworkSnapshot,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, recovery_error.c_str());
  }
  RecordEvent(ServiceEvent::kRuntimeNetworkSnapshot,
              ServiceEventOutcome::kSucceeded);
  recovery_error = recovery_->Record(RecoveryStage::kCoreStarted);
  if (!recovery_error.empty()) {
    const auto rollback_error = RollbackRuntime();
    phase_ = rollback_error.empty() ? Phase::kConfigStaged
                                    : Phase::kRecoveryRequired;
    if (!rollback_error.empty()) {
      RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                  ServiceEventOutcome::kFailed);
      return Fail(Status::kNotReady, rollback_error.c_str());
    }
    return Fail(Status::kNotReady, recovery_error.c_str());
  }
  RecordEvent(ServiceEvent::kRuntimeCoreStart,
              ServiceEventOutcome::kAttempted);
  RecordEvent(ServiceEvent::kRuntimeWintunStart,
              ServiceEventOutcome::kAttempted);
  RecordEvent(ServiceEvent::kRuntimeAdapterApply,
              ServiceEventOutcome::kAttempted);
  RecordEvent(ServiceEvent::kRuntimeRouteApply,
              ServiceEventOutcome::kAttempted);
  RecordEvent(ServiceEvent::kRuntimeDnsApply,
              ServiceEventOutcome::kAttempted);
  if (!core_->Start(profile_path_, disable_memory_limit_).empty()) {
    RecordEvent(ServiceEvent::kRuntimeCoreStart,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeWintunStart,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeAdapterApply,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeRouteApply,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeDnsApply,
                ServiceEventOutcome::kFailed);
    const auto rollback_error = RollbackRuntime();
    phase_ = rollback_error.empty() ? Phase::kConfigStaged
                                    : Phase::kRecoveryRequired;
    if (!rollback_error.empty()) {
      RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                  ServiceEventOutcome::kFailed);
      return Fail(Status::kNotReady, rollback_error.c_str());
    }
    return Fail(Status::kNotReady, "core_start_failed");
  }
  recovery_error = recovery_->Record(RecoveryStage::kNetworkApplied);
  if (!recovery_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeCoreStart,
                ServiceEventOutcome::kSucceeded);
    RecordEvent(ServiceEvent::kRuntimeWintunStart,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeAdapterApply,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeRouteApply,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeDnsApply,
                ServiceEventOutcome::kFailed);
    const auto rollback_error = RollbackRuntime();
    phase_ = rollback_error.empty() ? Phase::kConfigStaged
                                    : Phase::kRecoveryRequired;
    if (!rollback_error.empty()) {
      RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                  ServiceEventOutcome::kFailed);
      return Fail(Status::kNotReady, rollback_error.c_str());
    }
    return Fail(Status::kNotReady, recovery_error.c_str());
  }
  RecordEvent(ServiceEvent::kRuntimeCoreStart,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeWintunStart,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeAdapterApply,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeRouteApply,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeDnsApply,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeEgressVerify,
              ServiceEventOutcome::kAttempted);
  if (egress_probe_ == nullptr || !egress_probe_->Verify().empty()) {
    RecordEvent(ServiceEvent::kRuntimeEgressVerify,
                ServiceEventOutcome::kFailed);
    const auto rollback_error = RollbackRuntime();
    core_egress_validated_ = false;
    phase_ = rollback_error.empty() ? Phase::kConfigStaged
                                    : Phase::kRecoveryRequired;
    if (!rollback_error.empty()) {
      RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                  ServiceEventOutcome::kFailed);
      return Fail(Status::kNotReady, rollback_error.c_str());
    }
    return Fail(Status::kNotReady, "core_egress_probe_failed");
  }
  RecordEvent(ServiceEvent::kRuntimeEgressVerify,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeCommit,
              ServiceEventOutcome::kAttempted);
  recovery_error = recovery_->Record(RecoveryStage::kVerified);
  if (recovery_error.empty()) {
    recovery_error = recovery_->Record(RecoveryStage::kCommitted);
  }
  if (!recovery_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeCommit,
                ServiceEventOutcome::kFailed);
    const auto rollback_error = RollbackRuntime();
    core_egress_validated_ = false;
    phase_ = rollback_error.empty() ? Phase::kConfigStaged
                                    : Phase::kRecoveryRequired;
    if (!rollback_error.empty()) {
      RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                  ServiceEventOutcome::kFailed);
      return Fail(Status::kNotReady, rollback_error.c_str());
    }
    return Fail(Status::kNotReady, recovery_error.c_str());
  }
  core_egress_validated_ = true;
  phase_ = Phase::kRunning;
  failure_.clear();
  RecordEvent(ServiceEvent::kRuntimeCommit,
              ServiceEventOutcome::kSucceeded);
  return Snapshot();
}

RuntimeResult RuntimeHost::Disconnect() {
  if (!initialized_ ||
      (phase_ != Phase::kRunning &&
       phase_ != Phase::kRecoveryRequired)) {
    return Snapshot();
  }
  const auto rollback_error = RollbackRuntime();
  core_egress_validated_ = false;
  phase_ = rollback_error.empty()
               ? (profile_staged_ ? Phase::kConfigStaged
                                  : Phase::kInitialized)
               : Phase::kRecoveryRequired;
  if (!rollback_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, rollback_error.c_str());
  }
  failure_.clear();
  return Snapshot();
}

void RuntimeHost::Shutdown() {
  if (core_ != nullptr && initialized_ &&
      (phase_ == Phase::kRunning ||
       phase_ == Phase::kRecoveryRequired)) {
    const auto rollback_error = RollbackRuntime();
    core_egress_validated_ = false;
    phase_ = rollback_error.empty()
                 ? (profile_staged_ ? Phase::kConfigStaged
                                    : Phase::kInitialized)
                 : Phase::kRecoveryRequired;
  }
}

std::string RuntimeHost::RecoverPendingRuntime() {
  if (recovery_ == nullptr) {
    return "recovery_unavailable";
  }
  if (!recovery_->RequiresRecovery()) {
    return "";
  }
  RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
              ServiceEventOutcome::kAttempted);
  const auto begin_error = recovery_->BeginRollback();
  RecordEvent(ServiceEvent::kRuntimeCoreStop,
              ServiceEventOutcome::kAttempted);
  const auto stop_error = core_->Stop();
  if (!begin_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
                ServiceEventOutcome::kFailed);
    return begin_error;
  }
  RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
              ServiceEventOutcome::kSucceeded);
  if (!stop_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeCoreStop,
                ServiceEventOutcome::kFailed);
    return "recovery_core_stop_failed";
  }
  RecordEvent(ServiceEvent::kRuntimeCoreStop,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
              ServiceEventOutcome::kAttempted);
  const auto network_error = recovery_->RestoreNetworkState();
  if (!network_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
                ServiceEventOutcome::kFailed);
    return network_error;
  }
  RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeRollbackComplete,
              ServiceEventOutcome::kAttempted);
  const auto complete_error = recovery_->CompleteRollback();
  RecordEvent(ServiceEvent::kRuntimeRollbackComplete,
              complete_error.empty() ? ServiceEventOutcome::kSucceeded
                                     : ServiceEventOutcome::kFailed);
  return complete_error.empty() ? "" : complete_error;
}

std::string RuntimeHost::RollbackRuntime() {
  if (recovery_ == nullptr) {
    RecordEvent(ServiceEvent::kRuntimeCoreStop,
                ServiceEventOutcome::kAttempted);
    core_->Stop();
    RecordEvent(ServiceEvent::kRuntimeCoreStop,
                ServiceEventOutcome::kFailed);
    return "recovery_unavailable";
  }
  RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
              ServiceEventOutcome::kAttempted);
  const auto begin_error = recovery_->BeginRollback();
  RecordEvent(ServiceEvent::kRuntimeCoreStop,
              ServiceEventOutcome::kAttempted);
  const auto stop_error = core_->Stop();
  if (!begin_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
                ServiceEventOutcome::kFailed);
    return begin_error;
  }
  RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
              ServiceEventOutcome::kSucceeded);
  if (!stop_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeCoreStop,
                ServiceEventOutcome::kFailed);
    return "core_stop_failed";
  }
  RecordEvent(ServiceEvent::kRuntimeCoreStop,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
              ServiceEventOutcome::kAttempted);
  const auto network_error = recovery_->RestoreNetworkState();
  if (!network_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
                ServiceEventOutcome::kFailed);
    return network_error;
  }
  RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeRollbackComplete,
              ServiceEventOutcome::kAttempted);
  const auto complete_error = recovery_->CompleteRollback();
  RecordEvent(ServiceEvent::kRuntimeRollbackComplete,
              complete_error.empty() ? ServiceEventOutcome::kSucceeded
                                     : ServiceEventOutcome::kFailed);
  return complete_error.empty() ? "" : complete_error;
}

void RuntimeHost::RecordEvent(ServiceEvent event,
                              ServiceEventOutcome outcome) {
  if (events_ != nullptr) {
    events_->Record(event, outcome);
  }
}

RuntimeResult RuntimeHost::Fail(Status status, const char* failure) {
  failure_ = failure == nullptr ? "runtime_failure" : failure;
  return RuntimeResult{status, SnapshotBody()};
}

std::string RuntimeHost::SnapshotBody() const {
  const auto phase = static_cast<int>(phase_);
  const bool core_ready = initialized_;
  const bool can_initialize = core_ != nullptr && !runtime_root_.empty();
  const bool can_connect = initialized_ && profile_staged_ &&
                           phase_ == Phase::kConfigStaged;
  return std::string("phase=") + PhaseName(phase) +
         ";core_ready=" + (core_ready ? "1" : "0") +
         ";can_initialize=" + (can_initialize ? "1" : "0") +
         ";can_connect=" + (can_connect ? "1" : "0") +
         ";running=" + (phase_ == Phase::kRunning ? "1" : "0") +
         ";core_egress_validated=" +
         (core_egress_validated_ ? "1" : "0") +
         ";dns_ready=" + (core_egress_validated_ ? "1" : "0") +
         ";failure=" +
         (failure_.empty() ? "none" : failure_);
}

bool RuntimeHost::PrepareDirectories() {
  directories_.base = runtime_root_;
  directories_.working = AppendPath(runtime_root_, L"working");
  directories_.temporary = AppendPath(runtime_root_, L"temp");
  directories_.config = AppendPath(directories_.working, L"configs");
  const std::array<std::wstring, 6> paths = {
      directories_.base,
      directories_.working,
      directories_.temporary,
      directories_.config,
      AppendPath(directories_.base, L"data"),
      AppendPath(directories_.working, L"data"),
  };
  for (const auto& path : paths) {
    if (!EnsureDirectory(path) ||
        (secure_storage_ && !ProtectDirectory(path))) {
      return false;
    }
  }
  profile_path_ = AppendPath(directories_.config, L"managed-profile.json");
  return true;
}

bool RuntimeHost::WriteProfileAtomically(const std::string& profile) {
  const auto pending =
      AppendPath(directories_.config, L"managed-profile.pending");
  HANDLE file = ::CreateFileW(pending.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  DWORD written = 0;
  const bool success =
      ::WriteFile(file, profile.data(), static_cast<DWORD>(profile.size()),
                  &written, nullptr) != FALSE &&
      written == profile.size() && ::FlushFileBuffers(file) != FALSE;
  ::CloseHandle(file);
  if (!success ||
      ::MoveFileExW(pending.c_str(), profile_path_.c_str(),
                    MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) ==
          FALSE) {
    ::DeleteFileW(pending.c_str());
    return false;
  }
  return true;
}

std::unique_ptr<CoreRuntime> CreateInstalledCoreRuntime() {
  return std::make_unique<InstalledCoreRuntime>();
}

std::unique_ptr<RuntimeEgressProbe> CreateAuthenticatedEgressProbe() {
  return std::make_unique<AuthenticatedEgressProbe>();
}

std::wstring ResolveServiceRuntimeRoot() {
  PWSTR program_data = nullptr;
  if (FAILED(::SHGetKnownFolderPath(FOLDERID_ProgramData, KF_FLAG_DEFAULT,
                                    nullptr, &program_data)) ||
      program_data == nullptr) {
    return L"";
  }
  const std::wstring pokrov_root = AppendPath(program_data, L"POKROV");
  ::CoTaskMemFree(program_data);
  const std::wstring runtime_root = AppendPath(pokrov_root, L"ServiceRuntime");
  if (!EnsureDirectory(pokrov_root) || !EnsureDirectory(runtime_root) ||
      !ProtectDirectory(runtime_root)) {
    return L"";
  }
  return runtime_root;
}

}  // namespace pokrov::service
