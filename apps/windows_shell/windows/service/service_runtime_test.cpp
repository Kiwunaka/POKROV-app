#include "service_runtime.h"
#include "service_profile_identity.h"
#include "service_local_dpi.h"
#include "service_local_dpi_json.h"

#include <windows.h>

#include <iostream>
#include <memory>
#include <string>
#include <vector>

namespace pokrov::service {
bool CoreDescriptorHasRuntimeControl(const std::string& descriptor);
bool CoreDescriptorHasWindowsLocalDpi(const std::string& descriptor);
bool CoreDescriptorHasTelegramWS(const std::string& descriptor);
bool CoreDescriptorHasSmartAccessProbe(const std::string& descriptor);
bool StopWindowsLocalDpiChild(HANDLE& job, HANDLE& process);
bool CloseWindowsLocalDpiDriver(HANDLE& guard, BOOL (__cdecl* close)(HANDLE));
}

namespace {

int failures = 0;

void Expect(bool condition, const char* message) {
  if (!condition) {
    std::cerr << message << '\n';
    ++failures;
  }
}

void TestReleasedCoreDescriptorCompatibility() {
  // Native query of the retained released 1.2.2 DLL; no setup/start calls.
  const std::string core122 =
      R"({"schema_version":1,"desktop_abi":2,"event_abi":1,"routing_catalog_window_version":1,"smart_access_lease_version":1,"smart_access_runtime_control_version":1,"routing_catalog_control_version":4,"local_dpi_admission_version":1,"capabilities":["bounded_stop_reason","core_start_stop","materialized_profile","secure_profile_file","structured_operational_events","typed_lifecycle_events"],"lifecycle_events":["initialization","profile","core_start","tun","routes","dns","egress","recovery","stop"],"operational_events":{"contract":"config/core-event-abi.json","schema_version":1,"event_abi":1,"callback_symbol":"pokrovCoreSetEventCallback","context_symbol":"pokrovCoreSetEventContext","maximum_pending_events":128}})";
  Expect(pokrov::service::CoreDescriptorHasRuntimeControl(core122),
         "released Core 1.2.2 ordinary runtime descriptor was rejected");
  std::string core112(core122);
  const std::string admission = "\"local_dpi_admission_version\":1,";
  core112.erase(core112.find(admission), admission.size());
  Expect(pokrov::service::CoreDescriptorHasRuntimeControl(core112),
         "released Core 1.1.2 runtime descriptor was rejected");
  Expect(!pokrov::service::CoreDescriptorHasWindowsLocalDpi(core122) &&
         !pokrov::service::CoreDescriptorHasWindowsLocalDpi(core112),
         "released Core descriptor acquired a Windows local-DPI API");
  std::string windows_next(core122);
  const std::string windows_admission = "\"windows_local_dpi_admission_version\":1,";
  windows_next.insert(windows_next.find("\"capabilities\""), windows_admission);
  Expect(pokrov::service::CoreDescriptorHasRuntimeControl(windows_next) &&
         pokrov::service::CoreDescriptorHasWindowsLocalDpi(windows_next),
         "exact additive Windows Core descriptor was rejected");
  Expect(!pokrov::service::CoreDescriptorHasTelegramWS(windows_next) &&
         !pokrov::service::CoreDescriptorHasTelegramWS(core122),
         "old Core descriptor acquired Telegram WS admission");
  std::string telegram_next(windows_next);
  const std::string telegram_admission = "\"telegram_ws_admission_version\":1,";
  telegram_next.insert(telegram_next.find("\"capabilities\""), telegram_admission);
  Expect(pokrov::service::CoreDescriptorHasRuntimeControl(telegram_next) &&
         pokrov::service::CoreDescriptorHasTelegramWS(telegram_next),
         "exact Telegram WS descriptor was rejected");
  telegram_next.replace(telegram_next.find(telegram_admission), telegram_admission.size(),
      "\"telegram_ws_admission_version\":2,");
  Expect(!pokrov::service::CoreDescriptorHasRuntimeControl(telegram_next),
         "unknown Telegram WS admission version bypassed the closed descriptor");
  windows_next.replace(windows_next.find(windows_admission), windows_admission.size(),
      "\"windows_local_dpi_admission_version\":2,");
  Expect(!pokrov::service::CoreDescriptorHasRuntimeControl(windows_next),
         "unknown Windows local-DPI ABI bypassed the closed descriptor");
  std::string unknown(core122);
  unknown.replace(unknown.find("bounded_stop_reason"),
      std::string("bounded_stop_reason").size(), "unknown_capability");
  Expect(!pokrov::service::CoreDescriptorHasRuntimeControl(unknown),
         "unknown Core capability bypassed the closed runtime descriptor");
  unknown = core122;
  unknown.replace(unknown.find(admission), admission.size(),
      "\"local_dpi_admission_version\":2,");
  Expect(!pokrov::service::CoreDescriptorHasRuntimeControl(unknown),
         "unknown admission version bypassed the closed runtime descriptor");
  const std::string probe_field = "\"smart_access_probe_version\":1,";
  auto smart_next(core122);
  smart_next.insert(smart_next.find("\"local_dpi_admission_version\""), probe_field);
  Expect(pokrov::service::CoreDescriptorHasRuntimeControl(smart_next) &&
         pokrov::service::CoreDescriptorHasSmartAccessProbe(smart_next) &&
         !pokrov::service::CoreDescriptorHasSmartAccessProbe(core122),
         "optional Smart probe metadata changed ordinary Core compatibility");
}

void TestWindowsTelegramMetadataComposition() {
  using namespace pokrov::service;
  const std::string prepared = R"({"outbounds":[{"type":"pokrov_telegram_ws","tag":"tg"}],"_meta":{"telegram_ws":{"platform":"windows","mode":"selective"},"local_dpi":{"platform":"windows","mode":"selective"}}})";
  std::string runtime_copy;
  bool dpi = false, telegram = false;
  Expect(StripWindowsLocalDpiMetadata(prepared, &runtime_copy, &dpi, &telegram) && dpi && telegram,
         "composed Telegram/DPI intent did not reach the native owner");
  Expect(runtime_copy.find("_meta") == std::string::npos &&
         runtime_copy.find("pokrov_telegram_ws") != std::string::npos,
         "final metadata strip lost the prepared Telegram outbound");
  const auto receipt = ReadWindowsTelegramWSPreparation(
      "{\"schema_version\":1,\"profile\":" + prepared +
      R"(,"issued_at":"2020-01-01T00:00:00Z","expires_at":"2099-01-01T00:00:00Z","services":[{"service_id":"telegram","outbound_tag":"tg"}]})");
  Expect(receipt && receipt->services.size() == 1 && receipt->services.front().second == "tg" &&
         WindowsTelegramWSPreparationCurrent(*receipt), "private Telegram receipt was not consumed");
  if (receipt) {
    auto expired = *receipt;
    expired.expires_elapsed_ms = ::GetTickCount64();
    Expect(!WindowsTelegramWSPreparationCurrent(expired), "Telegram monotonic expiry did not retire admission");
  }
}

void TestWindowsLocalDpiScopePreparation() {
  using pokrov::service::WindowsLocalDpiService;
  using pokrov::service::WindowsLocalDpiHostList;
  const WindowsLocalDpiService service{"media", "pokrov-local-dpi-media", "control.example.com",
      {{"control.example.com", true}, {"media.example.com", false}}};
  Expect(WindowsLocalDpiHostList({service}) == "^control.example.com,media.example.com",
         "signed exact/suffix domain semantics changed in winws hostlist");
  Expect(WindowsLocalDpiHostList({}).empty(), "empty plan became unrestricted winws scope");
  auto invalid = service;
  invalid.domains[0].shared = true;
  Expect(WindowsLocalDpiHostList({invalid}).empty(), "shared provider scope reached winws");
  invalid = service;
  invalid.control_host = "foreign.example.com";
  Expect(WindowsLocalDpiHostList({invalid}).empty(), "proof host escaped exact signed scope");
  invalid = service;
  invalid.domains[1].name = "media.example.com,foreign.example.com";
  Expect(WindowsLocalDpiHostList({invalid}).empty(), "hostlist delimiter expanded winws scope");
}

BOOL __cdecl RefuseDriverClose(HANDLE) { return FALSE; }
BOOL __cdecl CloseTestDriverGuard(HANDLE handle) { return ::CloseHandle(handle); }

void TestWindowsLocalDpiOwnedCleanup() {
  using pokrov::service::StopWindowsLocalDpiChild;
  using pokrov::service::CloseWindowsLocalDpiDriver;
  std::vector<wchar_t> path(32768);
  const auto size = ::GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  Expect(size > 0 && size < path.size(), "local DPI child executable was unavailable");
  if (size == 0 || size >= path.size()) return;
  for (const bool kill_on_close : {true, false}) {
    HANDLE job = ::CreateJobObjectW(nullptr, nullptr);
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
    limits.BasicLimitInformation.LimitFlags = kill_on_close ? JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE : 0;
    const bool configured = job != nullptr && ::SetInformationJobObject(job,
        JobObjectExtendedLimitInformation, &limits, sizeof(limits));
    Expect(configured, "local DPI test Job was not configured");
    if (!configured) { if (job != nullptr) ::CloseHandle(job); return; }
    std::wstring command = L"\"" + std::wstring(path.data(), size) + L"\" --local-dpi-test-child";
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION child{};
    const bool created = ::CreateProcessW(path.data(), command.data(), nullptr, nullptr, FALSE,
        CREATE_SUSPENDED | CREATE_NO_WINDOW, nullptr, nullptr, &startup, &child) != FALSE;
    Expect(created, "local DPI test child was not created");
    if (!created) { ::CloseHandle(job); return; }
    const bool assigned = ::AssignProcessToJobObject(job, child.hProcess) != FALSE;
    Expect(assigned, "local DPI test child was not assigned to its Job");
    if (!assigned) {
      ::TerminateProcess(child.hProcess, 1);
      ::CloseHandle(child.hThread);
      ::CloseHandle(child.hProcess);
      ::CloseHandle(job);
      return;
    }
    const auto resumed = ::ResumeThread(child.hThread);
    ::CloseHandle(child.hThread);
    Expect(resumed != static_cast<DWORD>(-1), "local DPI test child was not resumed");
    HANDLE witness = nullptr;
    const bool duplicated = ::DuplicateHandle(::GetCurrentProcess(), child.hProcess,
        ::GetCurrentProcess(), &witness, SYNCHRONIZE, FALSE, 0) != FALSE;
    Expect(duplicated, "local DPI test child exit witness was unavailable");
    HANDLE process = child.hProcess;
    const bool stopped = StopWindowsLocalDpiChild(job, process);
    Expect(job == nullptr && stopped == kill_on_close,
           "local DPI cleanup did not confirm the owned Job exit");
    if (kill_on_close) {
      Expect(process == nullptr && witness != nullptr && ::WaitForSingleObject(witness, 0) == WAIT_OBJECT_0,
             "local DPI cleanup reported success before its child exited");
    } else {
      Expect(process == child.hProcess && ::WaitForSingleObject(process, 0) == WAIT_TIMEOUT,
             "unconfirmed child cleanup forgot its retry handle");
    }
    if (process != nullptr) {
      ::TerminateProcess(process, 1);  // Only this test's child.
      ::WaitForSingleObject(process, 2000);
      Expect(StopWindowsLocalDpiChild(job, process) && process == nullptr,
             "local DPI cleanup could not retry its retained child");
    }
    if (witness != nullptr) ::CloseHandle(witness);
  }
  HANDLE guard = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  Expect(guard != nullptr, "local DPI cleanup test guard was unavailable");
  if (guard == nullptr) return;
  const auto captured_guard = guard;
  Expect(!CloseWindowsLocalDpiDriver(guard, RefuseDriverClose) && guard == captured_guard,
         "failed driver close forgot its captured guard");
  Expect(CloseWindowsLocalDpiDriver(guard, CloseTestDriverGuard) && guard == INVALID_HANDLE_VALUE,
         "driver close could not retry its retained guard");
}

bool Contains(const pokrov::service::RuntimeResult& result,
              const char* value) {
  return result.body.find(value) != std::string::npos;
}

class FakeCoreRuntime final : public pokrov::service::CoreRuntime {
 public:
  std::string Initialize(
      const pokrov::service::RuntimeDirectories& directories) override {
    ++initialize_calls;
    last_directories = directories;
    return initialize_error;
  }

  std::string SecureFile(const std::wstring& path) override {
    ++secure_calls;
    last_profile_path = path;
    return secure_error;
  }

  std::string Start(const std::wstring& config_path,
                    bool disable_memory_limit) override {
    ++start_calls;
    last_profile_path = config_path;
    last_disable_memory_limit = disable_memory_limit;
    if (on_start) on_start();
    return start_error;
  }

  std::string Stop() override {
    ++stop_calls;
    return stop_error;
  }

  int SmartAccessProbeVersion() const override { return smart_probe_version; }
  std::string ProbeSmartAccess(const std::string& tag, bool periodic,
      const pokrov::service::CheckInterruption& interrupted) override {
    ++smart_probe_calls;
    smart_probe_tag = tag;
    smart_probe_periodic = periodic;
    if (interrupted && interrupted() != pokrov::service::OperationInterruption::kNone) return "core_egress_probe_unavailable";
    return smart_probe_error;
  }

  int initialize_calls = 0;
  int secure_calls = 0;
  int start_calls = 0;
  int stop_calls = 0;
  bool last_disable_memory_limit = false;
  pokrov::service::RuntimeDirectories last_directories;
  std::wstring last_profile_path;
  std::string initialize_error;
  std::string secure_error;
  std::string start_error;
  std::string stop_error;
  std::function<void()> on_start;
  int smart_probe_version = 0;
  int smart_probe_calls = 0;
  std::string smart_probe_tag;
  bool smart_probe_periodic = false;
  std::string smart_probe_error;
};

class FakeEgressProbe final : public pokrov::service::RuntimeEgressProbe {
 public:
  std::string Verify(const pokrov::service::CheckInterruption& = {}) override {
    ++verify_calls;
    if (on_verify) on_verify();
    return verify_error;
  }
  std::optional<pokrov::service::EgressProbeObservation> LastObservation() const override {
    return observation;
  }

  int verify_calls = 0;
  std::string verify_error;
  std::function<void()> on_verify;
  std::optional<pokrov::service::EgressProbeObservation> observation;
};

class FakeTransitionGuard final : public pokrov::service::RuntimeTransitionGuard {
 public:
  std::string Start() override { armed = true; ++starts; return ""; }
  std::string Finish() override { armed = false; ++finishes; return ""; }
  std::string ExplicitOff() override { armed = false; ++offs; return ""; }
  bool IsArmed() const override { return armed; }
  bool armed = false;
  int starts = 0, finishes = 0, offs = 0;
};

class FakeRecovery final : public pokrov::service::RuntimeRecovery {
 public:
  bool RequiresRecovery() const override { return requires_recovery; }
  const char* StageName() const override { return "fake"; }

  std::string Begin() override {
    ++begin_calls;
    if (begin_error.empty()) {
      requires_recovery = true;
    }
    return begin_error;
  }

  std::string Record(pokrov::service::RecoveryStage stage) override {
    recorded.push_back(stage);
    if (on_record) on_record(stage);
    return fail_record && stage == fail_stage ? record_error : "";
  }

  std::string BeginRollback() override {
    ++begin_rollback_calls;
    return rollback_error;
  }

  std::string RestoreNetworkState() override {
    ++restore_network_calls;
    return restore_error;
  }

  std::string CompleteRollback() override {
    ++complete_rollback_calls;
    if (complete_error.empty()) {
      requires_recovery = false;
    }
    return complete_error;
  }

  bool requires_recovery = false;
  int begin_calls = 0;
  int begin_rollback_calls = 0;
  int restore_network_calls = 0;
  int complete_rollback_calls = 0;
  std::vector<pokrov::service::RecoveryStage> recorded;
  bool fail_record = false;
  pokrov::service::RecoveryStage fail_stage =
      pokrov::service::RecoveryStage::kCoreStarted;
  std::string begin_error;
  std::string record_error;
  std::string rollback_error;
  std::string restore_error;
  std::string complete_error;
  std::function<void(pokrov::service::RecoveryStage)> on_record;
};

class FakeServiceEvents final : public pokrov::service::ServiceEventSink {
 public:
  bool Record(pokrov::service::ServiceEvent event,
              pokrov::service::ServiceEventOutcome outcome) override {
    events.push_back({event, outcome});
    return true;
  }

  bool RecordSystemBoot(std::uint64_t) override { return true; }

  bool RecordIpcRequest(
      pokrov::service::Command,
      const pokrov::service::Identifier&) override {
    return true;
  }

  bool RecordIpcResponse(
      pokrov::service::Command, pokrov::service::Status,
      const pokrov::service::Identifier&) override {
    return true;
  }

  bool Has(pokrov::service::ServiceEvent event,
           pokrov::service::ServiceEventOutcome outcome) const {
    for (const auto& recorded : events) {
      if (recorded.event == event && recorded.outcome == outcome) {
        return true;
      }
    }
    return false;
  }

  struct RecordedEvent {
    pokrov::service::ServiceEvent event;
    pokrov::service::ServiceEventOutcome outcome;
  };
  std::vector<RecordedEvent> events;
};

class FakeNetworkState final : public pokrov::service::NetworkStateBackend {
 public:
  std::string Capture(std::string* snapshot) override {
    ++capture_calls;
    if (!capture_error.empty()) {
      return capture_error;
    }
    if (snapshot != nullptr) {
      *snapshot = captured_snapshot;
    }
    return "";
  }

  std::string Restore(const std::string& snapshot) override {
    ++restore_calls;
    restored_snapshot = snapshot;
    return restore_error;
  }

  int capture_calls = 0;
  int restore_calls = 0;
  std::string captured_snapshot = "POKROV_NETWORK_TEST_V1\nadapter=absent\n";
  std::string restored_snapshot;
  std::string capture_error;
  std::string restore_error;
};

std::wstring CreateTestRoot() {
  wchar_t temporary[MAX_PATH]{};
  wchar_t candidate[MAX_PATH]{};
  if (::GetTempPathW(MAX_PATH, temporary) == 0 ||
      ::GetTempFileNameW(temporary, L"pks", 0, candidate) == 0) {
    return L"";
  }
  ::DeleteFileW(candidate);
  return ::CreateDirectoryW(candidate, nullptr) ? candidate : L"";
}

void RemoveTestRoot(const std::wstring& root) {
  const auto path = [&root](const wchar_t* suffix) {
    return root + L"\\" + suffix;
  };
  ::DeleteFileW(path(L"working\\configs\\managed-profile.json").c_str());
  ::DeleteFileW(path(L"working\\configs\\managed-profile.pending").c_str());
  ::DeleteFileW(path(L"recovery-journal.v1").c_str());
  ::DeleteFileW(path(L"recovery-journal.pending").c_str());
  for (const wchar_t* slot : {L"profile-a", L"profile-b"}) {
    for (int index = 0; index < 8; ++index) {
      const auto asset = path(
          (std::wstring(L"working\\data\\rule-set\\") + slot +
           L"\\ruleset-" + std::to_wstring(index) + L".srs")
              .c_str());
      ::DeleteFileW((asset + L".pending").c_str());
      ::DeleteFileW(asset.c_str());
    }
    ::RemoveDirectoryW(
        path((std::wstring(L"working\\data\\rule-set\\") + slot).c_str())
            .c_str());
  }
  ::RemoveDirectoryW(path(L"working\\data\\rule-set").c_str());
  ::RemoveDirectoryW(path(L"working\\configs").c_str());
  ::RemoveDirectoryW(path(L"working\\data").c_str());
  ::RemoveDirectoryW(path(L"working").c_str());
  ::RemoveDirectoryW(path(L"temp").c_str());
  ::RemoveDirectoryW(path(L"data").c_str());
  ::RemoveDirectoryW(root.c_str());
}

std::string ReadTextFile(const std::wstring& path);

std::string StagedDigest(const pokrov::service::RuntimeHost& host) {
  const auto body = host.Snapshot().body;
  const std::string key = ";staged_profile_digest=";
  const auto start = body.find(key);
  if (start == std::string::npos) return std::string(64, 'a');
  const auto value = start + key.size();
  return body.substr(value, body.find(';', value) - value);
}

void TestBundledRuleSetsAreStagedInsideProtectedWorkingDirectory() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  Expect(!root.empty(), "bundle test runtime root was not created");
  if (root.empty()) {
    return;
  }

  auto fake = std::make_unique<FakeCoreRuntime>();
  auto* core = fake.get();
  RuntimeHost host(std::move(fake), std::make_unique<FakeEgressProbe>(),
                   std::make_unique<FakeRecovery>(), root, false);
  Expect(host.Initialize().status == Status::kOk,
         "bundle test runtime initialization failed");
  const std::string profile =
      "{\"route\":{\"rule_set\":[{\"type\":\"local\","
      "\"format\":\"binary\",\"path\":\"data/rule-set/"
      "__POKROV_RULE_SET_SLOT__/ruleset-0.srs\"}]}}";
  const std::string first_bundle =
      "0\nPOKROV_PROFILE_BUNDLE_V1\n1\nruleset-0.srs\nAQID\n"
      "POKROV_PROFILE_JSON\n" +
      profile;
  const auto first = host.StageProfile(first_bundle);
  Expect(first.status == Status::kOk,
         "bounded rule-set bundle was rejected");
  const auto first_asset =
      root + L"\\working\\data\\rule-set\\profile-a\\ruleset-0.srs";
  const auto staged_profile =
      root + L"\\working\\configs\\managed-profile.json";
  Expect(ReadTextFile(first_asset) == std::string("\x01\x02\x03", 3),
         "bundled rule-set bytes were not written exactly");
  Expect(ReadTextFile(staged_profile).find("profile-a/ruleset-0.srs") !=
             std::string::npos &&
             ReadTextFile(staged_profile).find(
                 "__POKROV_RULE_SET_SLOT__") == std::string::npos,
         "staged profile did not bind the service-owned rule-set slot");
  Expect(core->secure_calls == 2,
         "bundle asset and profile were not both secured");

  const std::string second_bundle =
      "0\nPOKROV_PROFILE_BUNDLE_V1\n1\nruleset-0.srs\nBAUG\n"
      "POKROV_PROFILE_JSON\n" +
      profile;
  const auto second = host.StageProfile(second_bundle);
  const auto second_asset =
      root + L"\\working\\data\\rule-set\\profile-b\\ruleset-0.srs";
  Expect(second.status == Status::kOk &&
             ReadTextFile(second_asset) == std::string("\x04\x05\x06", 3),
         "second rule-set generation was not staged independently");
  Expect(::GetFileAttributesW(first_asset.c_str()) == INVALID_FILE_ATTRIBUTES,
         "superseded rule-set generation was retained");

  const auto before_rejection = ReadTextFile(staged_profile);
  const auto malformed = host.StageProfile(
      "0\nPOKROV_PROFILE_BUNDLE_V1\n1\nruleset-0.srs\nnot-base64\n"
      "POKROV_PROFILE_JSON\n{}");
  Expect(malformed.status == Status::kInvalid &&
             ReadTextFile(staged_profile) == before_rejection,
         "malformed bundle changed the active staged profile");

  Expect(host.InvalidateProfile().status == Status::kOk,
         "bundled profile invalidation failed");
  Expect(::GetFileAttributesW(second_asset.c_str()) == INVALID_FILE_ATTRIBUTES,
         "profile invalidation retained bundled rule-set bytes");
  RemoveTestRoot(root);
}

bool WriteTextFile(const std::wstring& path, const std::string& content) {
  HANDLE file = ::CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  DWORD written = 0;
  const bool success =
      ::WriteFile(file, content.data(), static_cast<DWORD>(content.size()),
                  &written, nullptr) != FALSE &&
      written == content.size() && ::FlushFileBuffers(file) != FALSE;
  ::CloseHandle(file);
  return success;
}

std::string ReadTextFile(const std::wstring& path) {
  HANDLE file = ::CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ,
                              nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                              nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return "";
  }
  LARGE_INTEGER size{};
  if (::GetFileSizeEx(file, &size) == FALSE || size.QuadPart <= 0 ||
      size.QuadPart > 4096) {
    ::CloseHandle(file);
    return "";
  }
  std::string content(static_cast<std::size_t>(size.QuadPart), '\0');
  DWORD read = 0;
  const bool success =
      ::ReadFile(file, content.data(), static_cast<DWORD>(content.size()),
                 &read, nullptr) != FALSE &&
      read == content.size();
  ::CloseHandle(file);
  return success ? content : "";
}

void TestFailedProfileSecurityPreservesPreviouslyStagedBytes() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  if (root.empty()) {
    Expect(false, "profile security test root was not created");
    return;
  }
  auto fake = std::make_unique<FakeCoreRuntime>();
  auto* core = fake.get();
  {
    RuntimeHost host(std::move(fake), std::make_unique<FakeEgressProbe>(),
                     std::make_unique<FakeRecovery>(), root, false);
    const std::string previous = "{\"route\":{\"final\":\"old-proxy\"}}";
    Expect(host.StageProfile("0\n" + previous).status == Status::kOk,
           "previous profile fixture was not staged");
    const auto path = root + L"\\working\\configs\\managed-profile.json";
    core->secure_error = "synthetic security failure";
    const auto failed = host.StageProfile("0\n{\"route\":{\"final\":\"new-proxy\"}}");
    Expect(failed.status == Status::kNotReady &&
               Contains(failed, "failure=profile_security_failed"),
           "profile security failure was not reported");
    Expect(ReadTextFile(path) == previous,
           "failed stage destroyed the previously staged profile");
    Expect(StagedDigest(host) == ProfileDigest("0\n" + previous),
           "failed stage changed acknowledged profile identity");
    Expect(core->start_calls == 0,
           "failed staging started a runtime");
  }
  RemoveTestRoot(root);
}

void TestProfileIdentityFollowsCommittedRuntime() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  Expect(!root.empty(), "identity test root was not created");
  if (root.empty()) return;
  {
    RuntimeHost host(std::make_unique<FakeCoreRuntime>(),
                     std::make_unique<FakeEgressProbe>(),
                     std::make_unique<FakeRecovery>(), root, false);
    const auto staged = host.StageProfile("0\n{}");
    const auto digest = ProfileDigest("0\n{}");
    Expect(staged.body.find(";staged_profile_digest=" + digest + ";") != std::string::npos,
           "staged snapshot has wrong profile identity");
    Expect(host.Connect(std::string(64, '0')).status == Status::kNotReady,
           "connect accepted another profile identity");
    const auto connected = host.Connect(StagedDigest(host));
    Expect(connected.body.find(";effective_profile_digest=" + digest + ";") != std::string::npos,
           "running proof has wrong effective profile identity");
    const auto stopped = host.Disconnect();
    Expect(Contains(stopped, ";effective_profile_digest=none;"),
           "stopped snapshot retains effective profile identity");
    Expect(host.StageProfile("1\n{}").status == Status::kOk,
           "replacement profile did not stage");
    const auto mismatch = host.Connect(digest);
    Expect(mismatch.status == Status::kNotReady &&
               Contains(mismatch, "failure=profile_identity_mismatch") &&
               Contains(mismatch, ";effective_profile_digest=none;"),
           "stale intent connected a replacement profile");
    Expect(host.Connect(ProfileDigest("1\n{}")).status == Status::kOk,
           "matching replacement identity failed to connect");
    host.Disconnect();
    host.InvalidateProfile();
    Expect(StagedDigest(host) == "none", "invalidation retained staged identity");
  }
  RemoveTestRoot(root);
}

void TestRuntimeLifecycle() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  Expect(!root.empty(), "test runtime root was not created");
  if (root.empty()) {
    return;
  }

  auto fake = std::make_unique<FakeCoreRuntime>();
  auto* core = fake.get();
  auto probe = std::make_unique<FakeEgressProbe>();
  auto* egress = probe.get();
  auto recovery = std::make_unique<FakeRecovery>();
  auto* transaction = recovery.get();
  FakeServiceEvents events;
  {
    RuntimeHost host(std::move(fake), std::move(probe), std::move(recovery),
                     root, false, &events);
    Expect(Contains(host.Snapshot(), "phase=artifact_ready"),
           "initial service phase was not artifact_ready");
    const auto initialized = host.Initialize();
    Expect(initialized.status == Status::kOk,
           "runtime initialization failed");
    Expect(Contains(initialized, "phase=initialized"),
           "runtime did not enter initialized phase");
    Expect(core->initialize_calls == 1,
           "core initialize was not called exactly once");

    const auto rejected = host.StageProfile("0\nnot-json");
    Expect(rejected.status == Status::kInvalid,
           "non-JSON profile was accepted");
    Expect(core->secure_calls == 0,
           "rejected profile reached secure-file boundary");

    const auto staged = host.StageProfile(
        "1\n{\"inbounds\":[{\"type\":\"tun\"}],\"route\":{\"final\":\"direct\"}}");
    Expect(staged.status == Status::kOk, "profile staging failed");
    Expect(Contains(staged, "phase=config_staged"),
           "runtime did not enter config_staged phase");
    Expect(core->secure_calls == 1,
           "staged profile was not secured exactly once");
    Expect(core->last_profile_path.find(L"managed-profile.pending") !=
               std::wstring::npos,
           "runtime used a caller-selected profile path");

    const auto connected = host.Connect(StagedDigest(host));
    Expect(connected.status == Status::kOk, "runtime connect failed");
    Expect(Contains(connected, "phase=running"),
           "runtime did not enter running phase");
    Expect(Contains(connected, "core_egress_validated=1"),
           "service did not retain authenticated egress proof");
    Expect(Contains(connected, "dns_ready=1"),
           "service did not derive DNS readiness from the egress proof");
    Expect(egress->verify_calls == 1,
           "authenticated egress probe was not called exactly once");
    Expect(core->start_calls == 1 && core->last_disable_memory_limit,
           "core start did not receive the staged bounded flag");
    Expect(transaction->begin_calls == 1 &&
               transaction->recorded.size() == 4,
           "runtime transaction did not persist every connect stage");

    egress->verify_error = "core_egress_dns_failed";
    egress->observation = EgressProbeObservation{EgressProbeStage::kDnsWait,
        EgressProbeOutcome::kTimeout, EgressErrorDomain::kNone, 0, 3000};
    const auto failed_recheck = host.RecheckEgress({});
    Expect(failed_recheck.status == Status::kNotReady &&
               Contains(failed_recheck, "core_egress_validated=0") &&
               Contains(failed_recheck, "failure=core_egress_dns_failed") &&
               Contains(failed_recheck, "egress_probe_outcome=timeout"),
           "failed egress recheck did not revoke its proof");
    Expect(host.CanRecheckEgress(),
           "failed egress recheck stopped future checks");
    bool cancelled = false;
    egress->verify_error = "core_egress_probe_failed";
    egress->on_verify = [&] {
      egress->observation = EgressProbeObservation{EgressProbeStage::kDnsWait,
          EgressProbeOutcome::kCancelled, EgressErrorDomain::kNone, 0, 12};
      cancelled = true;
    };
    const auto cancelled_recheck = host.RecheckEgress([&] {
      return cancelled ? OperationInterruption::kCancelled : OperationInterruption::kNone;
    });
    Expect(Contains(cancelled_recheck, "failure=core_egress_dns_failed") &&
               !Contains(cancelled_recheck, "egress_probe_stage=") &&
               Contains(host.Snapshot(), "failure=core_egress_dns_failed") &&
               !Contains(host.Snapshot(), "egress_probe_stage="),
           "cancelled recheck attached a new observation to the previous DNS failure");
    egress->on_verify = {};
    egress->observation.reset();
    egress->verify_error.clear();
    const auto recovered_recheck = host.RecheckEgress({});
    Expect(recovered_recheck.status == Status::kOk &&
               Contains(recovered_recheck, "core_egress_validated=1") &&
               Contains(recovered_recheck, "failure=none") &&
               egress->verify_calls == 4,
           "successful egress recheck did not restore proof");

    const auto disconnected = host.Disconnect();
    Expect(disconnected.status == Status::kOk,
           "runtime disconnect failed");
    Expect(core->stop_calls == 1, "core stop was not called exactly once");
    Expect(transaction->begin_rollback_calls == 1 &&
               transaction->restore_network_calls == 1 &&
               transaction->complete_rollback_calls == 1 &&
               !transaction->requires_recovery,
           "disconnect did not durably complete rollback");
    Expect(Contains(disconnected, "phase=config_staged"),
           "runtime did not retain the staged profile after stop");

    const auto repeated = host.Disconnect();
    Expect(repeated.status == Status::kOk && core->stop_calls == 1 &&
               transaction->restore_network_calls == 1,
           "repeated disconnect was not idempotent");

    const auto invalidated = host.InvalidateProfile();
    Expect(invalidated.status == Status::kOk,
           "profile invalidation failed");
    Expect(Contains(invalidated, "phase=initialized"),
           "profile invalidation did not return to initialized");
  }
  Expect(events.Has(ServiceEvent::kRuntimeNetworkSnapshot,
                    ServiceEventOutcome::kSucceeded) &&
             events.Has(ServiceEvent::kRuntimeAdapterApply,
                        ServiceEventOutcome::kSucceeded) &&
             events.Has(ServiceEvent::kRuntimeWintunStart,
                        ServiceEventOutcome::kSucceeded) &&
             events.Has(ServiceEvent::kRuntimeRouteApply,
                        ServiceEventOutcome::kSucceeded) &&
             events.Has(ServiceEvent::kRuntimeDnsApply,
                        ServiceEventOutcome::kSucceeded) &&
             events.Has(ServiceEvent::kRuntimeRollbackComplete,
                        ServiceEventOutcome::kSucceeded),
         "runtime lifecycle did not emit closed recovery breadcrumbs");
  RemoveTestRoot(root);
}

void TestCoreErrorsAreSanitized() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  if (root.empty()) {
    Expect(false, "error test root was not created");
    return;
  }
  auto fake = std::make_unique<FakeCoreRuntime>();
  fake->start_error = "raw provider secret must not cross IPC";
  RuntimeHost host(std::move(fake), std::make_unique<FakeEgressProbe>(),
                   std::make_unique<FakeRecovery>(), root, false);
  host.Initialize();
  host.StageProfile("0\n{}");
  const auto result = host.Connect(StagedDigest(host));
  Expect(result.status == Status::kNotReady,
         "core start failure did not fail closed");
  Expect(Contains(result, "failure=core_start_failed"),
         "core start failure category was not sanitized");
  Expect(!Contains(result, "provider secret"),
         "raw core error crossed the service boundary");
  RemoveTestRoot(root);
}

void TestEgressFailureStopsCoreAndIsSanitized() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  if (root.empty()) {
    Expect(false, "egress test root was not created");
    return;
  }
  auto fake = std::make_unique<FakeCoreRuntime>();
  auto* core = fake.get();
  auto probe = std::make_unique<FakeEgressProbe>();
  probe->verify_error =
      "raw DNS and provider response must not cross IPC";
  RuntimeHost host(std::move(fake), std::move(probe),
                   std::make_unique<FakeRecovery>(), root, false);
  host.Initialize();
  host.StageProfile("0\n{}");

  const auto result = host.Connect(StagedDigest(host));

  Expect(result.status == Status::kNotReady,
         "failed authenticated egress probe did not fail closed");
  Expect(core->start_calls == 1 && core->stop_calls == 1,
         "failed egress proof did not stop the started Core runtime");
  Expect(Contains(result, "phase=config_staged"),
         "failed egress proof left the runtime in a running phase");
  Expect(Contains(result, "core_egress_validated=0;dns_ready=0"),
         "failed egress proof exposed a green runtime signal");
  Expect(Contains(result, "failure=core_egress_probe_failed"),
         "egress failure category was not sanitized");
  Expect(!Contains(result, "provider response"),
         "raw egress probe error crossed the service boundary");
  auto classified_core = std::make_unique<FakeCoreRuntime>();
  auto classified_probe = std::make_unique<FakeEgressProbe>();
  classified_probe->verify_error = "core_egress_response_timeout";
  RuntimeHost classified(std::move(classified_core), std::move(classified_probe),
                         std::make_unique<FakeRecovery>(), root, false);
  classified.Initialize();
  classified.StageProfile("0\n{}");
  const auto observed = classified.Connect(StagedDigest(classified));
  Expect(Contains(observed, "failure=core_egress_response_timeout") &&
             Contains(observed, "core_egress_validated=0;dns_ready=0"),
         "service discarded the observed egress failure after rollback");
  const std::string smart_profile = R"({"inbounds":[{"type":"tun"}],"outbounds":[
    {"type":"direct","tag":"direct"},
    {"type":"pokrov-smart-access","tag":"pokrov-smart-access-00000000000000000000000000000000","lease_id":"00000000000000000000000000000000",
     "domains":[{"name":"service.example","match":"exact"}],"relay_addresses":["203.0.113.1"]}],
    "route":{"final":"direct","rules":[{"domain":["service.example"],"network":"tcp","port":[443],"ip_version":4,"action":"route",
     "outbound":"pokrov-smart-access-00000000000000000000000000000000","pokrov_catalog_window":{
       "issued_at":"2026-10-05T10:00:00Z","expires_at":"2099-01-01T00:00:00Z","service_id":"owned-service",
       "lease_id":"00000000000000000000000000000000","lease_group":["00000000000000000000000000000000"]}}]},
    "dns":{"servers":[{"tag":"pokrov-smart-access-dns-00000000000000000000000000000000","address":"https://resolver.example/dns-query","detour":"direct"}],
     "rules":[{"domain":["service.example"],"query_type":["A"],"action":"route","server":"pokrov-smart-access-dns-00000000000000000000000000000000",
      "disable_cache":true,"rewrite_ttl":0,"pokrov_catalog_window":{
       "issued_at":"2026-10-05T10:00:00Z","expires_at":"2099-01-01T00:00:00Z","service_id":"owned-service",
       "lease_id":"00000000000000000000000000000000","lease_group":["00000000000000000000000000000000"]}}]}})";
  const auto smart_target = ReadWindowsSmartAccessProbeTarget(smart_profile);
  Expect(smart_target && *smart_target == "pokrov-smart-access-00000000000000000000000000000000",
         "bound service graph did not select its Smart anchor");
  auto smart_core = std::make_unique<FakeCoreRuntime>();
  auto* selected_core = smart_core.get();
  selected_core->smart_probe_version = 1;
  auto smart_api = std::make_unique<FakeEgressProbe>();
  auto* unrelated_api = smart_api.get();
  RuntimeHost smart(std::move(smart_core), std::move(smart_api), std::make_unique<FakeRecovery>(), root, false);
  smart.Initialize(); smart.StageProfile("0\n" + smart_profile);
  const auto smart_connected = smart.Connect(StagedDigest(smart));
  Expect(smart_connected.status == Status::kOk && Contains(smart_connected, "core_egress_validated=1") &&
         selected_core->smart_probe_calls == 1 && !selected_core->smart_probe_periodic &&
         selected_core->smart_probe_tag == "pokrov-smart-access-00000000000000000000000000000000" && unrelated_api->verify_calls == 0,
         "local Smart readiness used Direct API health instead of its captured service");
  selected_core->smart_probe_error = "core_egress_tls_failed";
  const auto smart_failed = smart.RecheckEgress({});
  Expect(Contains(smart_failed, "core_egress_validated=0") && Contains(smart_failed, "failure=core_egress_tls_failed") &&
         selected_core->smart_probe_calls == 2 && selected_core->smart_probe_periodic && unrelated_api->verify_calls == 0,
         "periodic Smart failure fell back to healthy Direct API egress");
  selected_core->smart_probe_error = "core_smart_access_lease_expired";
  const auto smart_expired = smart.RecheckEgress({});
  Expect(Contains(smart_expired, "core_egress_validated=0") &&
         Contains(smart_expired, "failure=core_smart_access_lease_expired") &&
         selected_core->smart_probe_calls == 3 && unrelated_api->verify_calls == 0,
         "expired Smart admission lost its closed outcome or used Direct API proof");
  smart.Disconnect();
  auto old_core = std::make_unique<FakeCoreRuntime>();
  auto old_api = std::make_unique<FakeEgressProbe>();
  auto* old_api_calls = old_api.get();
  RuntimeHost old(std::move(old_core), std::move(old_api), std::make_unique<FakeRecovery>(), root, false);
  old.Initialize(); old.StageProfile("0\n" + smart_profile);
  const auto unsupported = old.Connect(StagedDigest(old));
  Expect(Contains(unsupported, "failure=core_egress_probe_unavailable") &&
         Contains(unsupported, "core_egress_validated=0") && old_api_calls->verify_calls == 0,
         "old Core proved local Smart readiness through Direct API health");
  auto unused = smart_profile;
  const auto route_domain = unused.find("\"domain\":[\"service.example\"]");
  unused.replace(route_domain, std::string("\"domain\":[\"service.example\"]").size(), "\"domain\":[\"other.example\"]");
  const auto unused_target = ReadWindowsSmartAccessProbeTarget(unused);
  Expect(unused_target && unused_target->empty(), "an unused anchor became Smart proof");
  auto mixed = smart_profile;
  mixed.insert(mixed.find("\"outbounds\":[") + std::string("\"outbounds\":[").size(), "{\"type\":\"vless\",\"tag\":\"vpn\"},");
  mixed.insert(mixed.find("\"rules\":[") + std::string("\"rules\":[").size(),
      "{\"domain\":[\"api.pokrov.space\"],\"network\":\"tcp\",\"port\":[443],\"action\":\"route\",\"outbound\":\"vpn\"},");
  const auto dns_start = mixed.find("\"dns\":");
  mixed.insert(mixed.find("\"servers\":[", dns_start) + std::string("\"servers\":[").size(), "{\"tag\":\"dns-vpn\",\"detour\":\"vpn\"},");
  mixed.insert(mixed.find("\"rules\":[", dns_start) + std::string("\"rules\":[").size(),
      "{\"domain\":[\"api.pokrov.space\"],\"action\":\"route\",\"server\":\"dns-vpn\",\"disable_cache\":true,\"rewrite_ttl\":0},");
  Expect(!ReadWindowsSmartAccessProbeTarget(mixed), "normal selective VPN proof lost precedence to Smart");
  mixed.replace(mixed.find("\"port\":[443]"), std::string("\"port\":[443]").size(), "\"port\":[80]");
  const auto invalid_boundary = ReadWindowsSmartAccessProbeTarget(mixed);
  Expect(invalid_boundary && invalid_boundary->empty(), "partial owned VPN boundary silently became Smart proof");
  RemoveTestRoot(root);
}

void TestPendingRecoveryStopsCoreBeforeRuntimeReady() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  if (root.empty()) {
    Expect(false, "pending recovery test root was not created");
    return;
  }
  auto fake = std::make_unique<FakeCoreRuntime>();
  auto* core = fake.get();
  auto recovery = std::make_unique<FakeRecovery>();
  auto* transaction = recovery.get();
  recovery->requires_recovery = true;
  RuntimeHost host(std::move(fake), std::make_unique<FakeEgressProbe>(),
                   std::move(recovery), root, false);

  const auto result = host.Initialize();

  Expect(result.status == Status::kOk,
         "pending runtime transaction was not recovered at initialization");
  Expect(core->initialize_calls == 1 && core->stop_calls == 1,
         "startup recovery did not initialize then idempotently stop Core");
  Expect(transaction->begin_rollback_calls == 1 &&
             transaction->restore_network_calls == 1 &&
             transaction->complete_rollback_calls == 1 &&
             !transaction->requires_recovery,
         "startup recovery did not return the journal to clean");
  RemoveTestRoot(root);
}

void TestStartupRecoveryIsEagerOnlyWhenJournalIsPending() {
  using namespace pokrov::service;
  const auto clean_root = CreateTestRoot();
  if (clean_root.empty()) {
    Expect(false, "clean startup recovery test root was not created");
    return;
  }
  auto clean_core = std::make_unique<FakeCoreRuntime>();
  auto* clean_core_state = clean_core.get();
  auto clean_recovery = std::make_unique<FakeRecovery>();
  auto* clean_recovery_state = clean_recovery.get();
  RuntimeHost clean_host(
      std::move(clean_core), std::make_unique<FakeEgressProbe>(),
      std::move(clean_recovery), clean_root, false);

  const auto clean_result = clean_host.RecoverOnStartup();

  Expect(clean_result.status == Status::kOk &&
             Contains(clean_result, "phase=artifact_ready") &&
             clean_core_state->initialize_calls == 0 &&
             clean_recovery_state->begin_rollback_calls == 0,
         "clean service startup initialized Core or recovery eagerly");
  RemoveTestRoot(clean_root);

  const auto pending_root = CreateTestRoot();
  if (pending_root.empty()) {
    Expect(false, "pending startup recovery test root was not created");
    return;
  }
  auto pending_core = std::make_unique<FakeCoreRuntime>();
  auto* pending_core_state = pending_core.get();
  auto pending_recovery = std::make_unique<FakeRecovery>();
  auto* pending_recovery_state = pending_recovery.get();
  pending_recovery->requires_recovery = true;
  RuntimeHost pending_host(
      std::move(pending_core), std::make_unique<FakeEgressProbe>(),
      std::move(pending_recovery), pending_root, false);

  const auto pending_result = pending_host.RecoverOnStartup();

  Expect(pending_result.status == Status::kOk &&
             Contains(pending_result, "phase=initialized") &&
             pending_core_state->initialize_calls == 1 &&
             pending_core_state->stop_calls == 1 &&
             pending_recovery_state->begin_rollback_calls == 1 &&
             pending_recovery_state->restore_network_calls == 1 &&
             pending_recovery_state->complete_rollback_calls == 1 &&
             !pending_recovery_state->requires_recovery,
         "pending service startup did not finish recovery before IPC");
  RemoveTestRoot(pending_root);
}

void TestFailedStartupRecoveryRemainsRetryable() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  if (root.empty()) {
    Expect(false, "retryable startup recovery test root was not created");
    return;
  }
  auto core = std::make_unique<FakeCoreRuntime>();
  auto* core_state = core.get();
  auto recovery = std::make_unique<FakeRecovery>();
  auto* recovery_state = recovery.get();
  recovery->requires_recovery = true;
  recovery->restore_error = "recovery_network_restore_failed";
  RuntimeHost host(std::move(core), std::make_unique<FakeEgressProbe>(),
                   std::move(recovery), root, false);

  const auto failed = host.RecoverOnStartup();

  Expect(failed.status == Status::kNotReady &&
             Contains(failed, "phase=recovery_required") &&
             Contains(failed, "core_ready=1") &&
             Contains(failed, "failure=recovery_network_restore_failed") &&
             core_state->initialize_calls == 1 &&
             recovery_state->requires_recovery,
         "failed startup recovery did not remain initialized and closed");

  recovery_state->restore_error.clear();
  const auto retried = host.Disconnect();

  Expect(retried.status == Status::kOk &&
             Contains(retried, "phase=initialized") &&
             !recovery_state->requires_recovery &&
             recovery_state->begin_rollback_calls == 2 &&
             recovery_state->restore_network_calls == 2 &&
             recovery_state->complete_rollback_calls == 1,
         "failed startup recovery could not be retried through disconnect");
  RemoveTestRoot(root);
}

void TestConnectFaultsRollbackEveryPersistedStage() {
  using namespace pokrov::service;
  const std::vector<RecoveryStage> stages = {
      RecoveryStage::kCoreStarted,
      RecoveryStage::kNetworkApplied,
      RecoveryStage::kVerified,
      RecoveryStage::kCommitted,
  };
  for (const auto stage : stages) {
    const auto root = CreateTestRoot();
    if (root.empty()) {
      Expect(false, "stage fault test root was not created");
      return;
    }
    auto fake = std::make_unique<FakeCoreRuntime>();
    auto* core = fake.get();
    auto probe = std::make_unique<FakeEgressProbe>();
    auto* egress = probe.get();
    auto recovery = std::make_unique<FakeRecovery>();
    auto* transaction = recovery.get();
    recovery->fail_record = true;
    recovery->fail_stage = stage;
    recovery->record_error = "recovery_write_failed";
    RuntimeHost host(std::move(fake), std::move(probe), std::move(recovery),
                     root, false);
    host.Initialize();
    host.StageProfile("0\n{}");

    const auto result = host.Connect(StagedDigest(host));

    Expect(result.status == Status::kNotReady &&
               Contains(result, "failure=recovery_write_failed") &&
               Contains(result, "phase=config_staged"),
           "persisted-stage fault did not fail closed after rollback");
    Expect(core->stop_calls == 1 &&
               transaction->begin_rollback_calls == 1 &&
               transaction->restore_network_calls == 1 &&
               transaction->complete_rollback_calls == 1,
           "persisted-stage fault did not run the complete rollback chain");
    const bool core_should_start = stage != RecoveryStage::kCoreStarted;
    Expect((core->start_calls == 1) == core_should_start,
           "Core start crossed the wrong journal failure boundary");
    const bool egress_should_run =
        stage == RecoveryStage::kVerified ||
        stage == RecoveryStage::kCommitted;
    Expect((egress->verify_calls == 1) == egress_should_run,
           "egress probe crossed the wrong journal failure boundary");
    RemoveTestRoot(root);
  }
}

void TestSnapshotCaptureFailureDoesNotStartCore() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  if (root.empty()) {
    Expect(false, "snapshot capture test root was not created");
    return;
  }
  auto fake = std::make_unique<FakeCoreRuntime>();
  auto* core = fake.get();
  auto recovery = std::make_unique<FakeRecovery>();
  auto* transaction = recovery.get();
  recovery->begin_error = "recovery_network_capture_failed";
  RuntimeHost host(std::move(fake), std::make_unique<FakeEgressProbe>(),
                   std::move(recovery), root, false);
  host.Initialize();
  host.StageProfile("0\n{}");

  const auto result = host.Connect(StagedDigest(host));

  Expect(result.status == Status::kNotReady &&
             Contains(result, "failure=recovery_network_capture_failed") &&
             Contains(result, "phase=config_staged"),
         "network snapshot failure did not leave a retryable closed state");
  Expect(core->start_calls == 0 && core->stop_calls == 0 &&
             transaction->begin_rollback_calls == 0,
         "Core mutation crossed a failed pre-mutation network snapshot");
  RemoveTestRoot(root);
}

void TestRollbackFailuresStayClosedAndCanRetry() {
  using namespace pokrov::service;
  enum class Fault { kCoreStop, kNetworkRestore, kJournalComplete };
  for (const auto fault :
       {Fault::kCoreStop, Fault::kNetworkRestore, Fault::kJournalComplete}) {
    const auto root = CreateTestRoot();
    if (root.empty()) {
      Expect(false, "rollback fault test root was not created");
      return;
    }
    auto fake = std::make_unique<FakeCoreRuntime>();
    auto* core = fake.get();
    auto recovery = std::make_unique<FakeRecovery>();
    auto* transaction = recovery.get();
    RuntimeHost host(std::move(fake), std::make_unique<FakeEgressProbe>(),
                     std::move(recovery), root, false);
    host.Initialize();
    host.StageProfile("0\n{}");
    Expect(host.Connect(StagedDigest(host)).status == Status::kOk,
           "rollback fault fixture did not connect");
    if (fault == Fault::kCoreStop) {
      core->stop_error = "stop failed";
    } else if (fault == Fault::kNetworkRestore) {
      transaction->restore_error = "recovery_network_restore_failed";
    } else {
      transaction->complete_error = "recovery_write_failed";
    }

    const auto failed = host.Disconnect();

    Expect(failed.status == Status::kNotReady &&
               Contains(failed, "phase=recovery_required") &&
               Contains(failed, "can_connect=0") &&
               Contains(failed,
                        "running=0;core_egress_validated=0;dns_ready=0"),
           "rollback fault exposed a retryable or green connection state");
    if (fault == Fault::kCoreStop) {
      Expect(transaction->restore_network_calls == 0 &&
                 transaction->complete_rollback_calls == 0,
             "network state changed after Core stop failed");
      core->stop_error.clear();
    } else if (fault == Fault::kNetworkRestore) {
      Expect(transaction->restore_network_calls == 1 &&
                 transaction->complete_rollback_calls == 0,
             "journal was closed after network restoration failed");
      transaction->restore_error.clear();
    } else {
      Expect(transaction->restore_network_calls == 1 &&
                 transaction->complete_rollback_calls == 1,
             "journal completion fault crossed the wrong rollback boundary");
      transaction->complete_error.clear();
    }

    const auto retried = host.Disconnect();

    Expect(retried.status == Status::kOk &&
               Contains(retried, "phase=config_staged") &&
               Contains(retried, "failure=none"),
           "idempotent rollback retry did not return to config_staged");
    RemoveTestRoot(root);
  }
}

void TestDurableRecoveryJournalSurvivesRestart() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  if (root.empty()) {
    Expect(false, "durable recovery test root was not created");
    return;
  }

  auto first_network = std::make_unique<FakeNetworkState>();
  auto* first_network_ptr = first_network.get();
  auto first =
      CreateRuntimeRecoveryForTesting(root, std::move(first_network));
  Expect(first != nullptr && !first->RequiresRecovery() &&
             std::string(first->StageName()) == "clean",
         "new recovery journal did not start clean");
  Expect(first->Begin().empty(), "recovery journal begin failed");
  Expect(first_network_ptr->capture_calls == 1,
         "network state was not captured before Core mutation");
  Expect(first->Record(RecoveryStage::kCoreStarted).empty(),
         "core_started was not persisted");
  Expect(first->Record(RecoveryStage::kNetworkApplied).empty(),
         "network_applied was not persisted");
  Expect(first->Record(RecoveryStage::kVerified).empty(),
         "verified was not persisted");
  Expect(first->Record(RecoveryStage::kCommitted).empty(),
         "committed was not persisted");
  first.reset();

  auto restarted_network = std::make_unique<FakeNetworkState>();
  auto* restarted_network_ptr = restarted_network.get();
  auto restarted = CreateRuntimeRecoveryForTesting(
      root, std::move(restarted_network));
  Expect(restarted->RequiresRecovery() &&
             std::string(restarted->StageName()) == "committed",
         "committed recovery journal was not detected after restart");
  Expect(restarted->Begin() == "recovery_required",
         "new transaction started over pending recovery");
  Expect(restarted->BeginRollback().empty() &&
             restarted->RestoreNetworkState().empty() &&
             restarted->CompleteRollback().empty(),
         "restart rollback did not complete durably");
  Expect(restarted_network_ptr->restore_calls == 1 &&
             restarted_network_ptr->restored_snapshot ==
                 "POKROV_NETWORK_TEST_V1\nadapter=absent\n",
         "restart rollback did not restore the captured network snapshot");
  restarted.reset();

  auto clean = CreateRuntimeRecoveryForTesting(
      root, std::make_unique<FakeNetworkState>());
  Expect(!clean->RequiresRecovery() &&
             std::string(clean->StageName()) == "clean",
         "completed rollback did not survive journal reload");
  const auto content = ReadTextFile(root + L"\\recovery-journal.v1");
  Expect(content.find("POKROV_RECOVERY_V1\nstage=clean\n") == 0,
         "journal wire format was not closed and versioned");
  Expect(content.find("profile") == std::string::npos &&
             content.find("endpoint") == std::string::npos,
         "recovery journal retained runtime material");
  RemoveTestRoot(root);
}

void TestRecoveredCheckpointCanRetryAndSurviveRestart() {
  using namespace pokrov::service;
  for (const bool restart : {false, true}) {
    const auto root = CreateTestRoot();
    if (root.empty()) {
      Expect(false, "recovered checkpoint test root was not created");
      return;
    }
    auto recovery = CreateRuntimeRecoveryForTesting(
        root, std::make_unique<FakeNetworkState>());
    Expect(recovery->Begin().empty() &&
               recovery->BeginRollback().empty() &&
               recovery->RestoreNetworkState().empty() &&
               recovery->Record(RecoveryStage::kRecovered).empty(),
           "recovered checkpoint fixture failed");
    if (restart) {
      recovery = CreateRuntimeRecoveryForTesting(
          root, std::make_unique<FakeNetworkState>());
    }
    const auto journal = root + L"\\recovery-journal.v1";
    const auto recovered_bytes = ReadTextFile(journal);
    HANDLE lock = ::CreateFileW(journal.c_str(), GENERIC_READ,
                                FILE_SHARE_READ, nullptr, OPEN_EXISTING,
                                FILE_ATTRIBUTE_NORMAL, nullptr);
    Expect(lock != INVALID_HANDLE_VALUE, "journal fixture lock failed");
    Expect(recovery->BeginRollback() == "recovery_write_failed" &&
               std::string(recovery->StageName()) == "recovered" &&
               recovery->RequiresRecovery(),
           "failed clean commit lost the recovered checkpoint");
    Expect(ReadTextFile(journal) == recovered_bytes,
           "failed clean commit changed durable recovery evidence");
    if (lock != INVALID_HANDLE_VALUE) {
      ::CloseHandle(lock);
    }
    Expect(recovery->BeginRollback().empty() &&
               recovery->RestoreNetworkState().empty() &&
               recovery->CompleteRollback().empty(),
           "recovered checkpoint could not finish after write retry");
    recovery = CreateRuntimeRecoveryForTesting(
        root, std::make_unique<FakeNetworkState>());
    Expect(!recovery->RequiresRecovery() &&
               std::string(recovery->StageName()) == "clean",
           "recovered checkpoint produced an invalid clean journal on restart");
    Expect(recovery->Begin().empty(),
           "recovered checkpoint blocked the next transaction");
    RemoveTestRoot(root);
  }
}

void TestCorruptRecoveryJournalIsPreservedAndFailsClosed() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  if (root.empty()) {
    Expect(false, "corrupt recovery test root was not created");
    return;
  }
  const auto path = root + L"\\recovery-journal.v1";
  const std::string future =
      "POKROV_RECOVERY_V2\nstage=committed\ngeneration=" +
      std::string(32, 'a') + "\nnetwork_state=00\n";
  Expect(WriteTextFile(path, future), "future journal fixture write failed");

  auto recovery = CreateRuntimeRecoveryForTesting(
      root, std::make_unique<FakeNetworkState>());
  Expect(recovery->RequiresRecovery() &&
             std::string(recovery->StageName()) == "invalid",
         "future recovery journal was not rejected");
  Expect(recovery->BeginRollback() == "recovery_journal_invalid",
         "future recovery journal did not fail closed");
  Expect(ReadTextFile(path) == future,
         "future recovery journal was overwritten instead of preserved");
  RemoveTestRoot(root);
}

void TestPartialRecoveryJournalIsPreservedAndFailsClosed() {
  using namespace pokrov::service;
  const auto root = CreateTestRoot();
  if (root.empty()) {
    Expect(false, "partial recovery test root was not created");
    return;
  }
  const auto path = root + L"\\recovery-journal.v1";
  const std::string partial =
      "POKROV_RECOVERY_V1\nstage=core_started\ngeneration=" +
      std::string(32, 'b') + "\nnetwork_state=";
  Expect(WriteTextFile(path, partial), "partial journal fixture write failed");

  auto recovery = CreateRuntimeRecoveryForTesting(
      root, std::make_unique<FakeNetworkState>());
  Expect(recovery->RequiresRecovery() &&
             std::string(recovery->StageName()) == "invalid" &&
             recovery->BeginRollback() == "recovery_journal_invalid",
         "partial recovery journal did not fail closed");
  Expect(ReadTextFile(path) == partial,
         "partial recovery journal was not preserved");
  RemoveTestRoot(root);
}

void TestCoreOperationalEventFenceRejectsLateAndUnsafeCallbacks() {
  using namespace pokrov::service;
  const std::string run_id = "018f4f2a-6d58-4c11-8c27-4fb77bd28c15";
  const std::string first_attempt =
      "57ba1c00-f8a9-4b76-a3dc-d44a6d7cff33";
  const std::string second_attempt =
      "a69dc69d-fd10-474f-8c63-4bf8b224c184";
  CoreOperationalEventFence fence;
  Expect(fence.Activate(run_id, first_attempt, 7),
         "Core event context was rejected");
  CoreOperationalEventRecord event{
      1,          1,           "2026-08-21T12:00:00Z",
      run_id,     first_attempt, 7,
      1,          "core.runtime.start",
      "core",    "start",     "info",
      "started", "",          "core_start",
  };
  Expect(fence.Accept(event), "valid Core event was rejected");
  Expect(!fence.Accept(event), "duplicate Core event was accepted");

  event.sequence = 2;
  event.generation = 6;
  Expect(!fence.Accept(event), "old-generation Core event was accepted");
  event.generation = 7;
  Expect(fence.Activate(run_id, second_attempt, 7),
         "next Core attempt was rejected");
  Expect(!fence.Accept(event), "previous-attempt Core event was accepted");
  event.attempt_id = second_attempt;
  Expect(fence.Accept(event), "active Core attempt event was rejected");

  event.sequence = 3;
  event.outcome = "failed";
  event.severity = "error";
  for (const std::string& error_code :
       {"TRANSPORT-001", "TRANSPORT-002", "TRANSPORT-003",
        "TRANSPORT-004", "TRANSPORT-005", "TRANSPORT-006", "TRANSPORT-007",
        "DNS-002"}) {
    event.error_code = error_code;
    Expect(fence.Accept(event), "closed transport failure was rejected");
    event.sequence += 1;
  }
  event.error_code =
      "https://private.example.test/path?token=planted-secret";
  Expect(!fence.Accept(event), "raw failure material crossed the Core fence");
  event.error_code = "EGRESS-001";
  event.name = "core.egress.probe";
  event.subsystem = "egress";
  event.stage = "verify";
  event.phase = "egress";
  Expect(fence.Accept(event), "closed egress failure was rejected");
}

void TestInterruptedConnectNeverPublishesProtection() {
  using namespace pokrov::service;
  // The signal can arrive before mutation, inside Core/probe, or while the
  // durable journal is being advanced. No late success may publish protection.
  for (int checkpoint = 0; checkpoint < 6; ++checkpoint) {
    const auto root = CreateTestRoot();
    Expect(!root.empty(), "interrupted connect root was not created");
    if (root.empty()) return;
    {
      auto core = std::make_unique<FakeCoreRuntime>();
      auto* core_state = core.get();
      auto probe = std::make_unique<FakeEgressProbe>();
      auto* probe_state = probe.get();
      auto recovery = std::make_unique<FakeRecovery>();
      auto* recovery_state = recovery.get();
      auto signal = OperationInterruption::kNone;
      const auto reason = checkpoint % 2 == 0
                              ? OperationInterruption::kDeadlineExceeded
                              : OperationInterruption::kCancelled;
      core->on_start = [&] {
        if (checkpoint == 1) signal = reason;
      };
      probe->on_verify = [&] {
        if (checkpoint == 2 || checkpoint == 5) signal = reason;
      };
      recovery->on_record = [&](RecoveryStage stage) {
        if ((checkpoint == 3 && stage == RecoveryStage::kVerified) ||
            (checkpoint == 4 && stage == RecoveryStage::kCommitted)) {
          signal = reason;
        }
      };
      if (checkpoint == 5) {
        recovery->restore_error = "recovery_network_restore_failed";
      }
      RuntimeHost host(std::move(core), std::move(probe), std::move(recovery),
                       root, false);
      Expect(host.Initialize().status == Status::kOk &&
                 host.StageProfile("0\n{\"inbounds\":[{\"type\":\"tun\"}]}")
                         .status == Status::kOk,
             "interrupted connect fixture could not stage");
      if (checkpoint == 0) signal = reason;
      const auto result = host.Connect(StagedDigest(host), [&] { return signal; });
      const auto expected_status =
          checkpoint == 5 || reason == OperationInterruption::kCancelled
              ? Status::kNotReady : Status::kDeadlineExceeded;
      Expect(result.status == expected_status,
             "interrupted connection returned success or lost interruption status");
      Expect(!Contains(result, "phase=running") &&
                 Contains(result, ";core_egress_validated=0;") &&
                 Contains(result, ";effective_profile_digest=none;"),
             "interrupted connection published protection or effective identity");
      Expect(checkpoint == 0
                 ? core_state->start_calls == 0 && recovery_state->begin_calls == 0
                 : core_state->stop_calls == 1 &&
                       recovery_state->restore_network_calls == 1,
             "interrupted connection crossed mutation boundary or skipped rollback");
      Expect(checkpoint != 1 || probe_state->verify_calls == 0,
             "cancelled Core start continued into egress verification");
      if (checkpoint == 5) {
        Expect(Contains(result, "phase=recovery_required") &&
                   Contains(result, "failure=recovery_network_restore_failed"),
               "interruption hid rollback failure");
        recovery_state->restore_error.clear();
        Expect(host.Disconnect().status == Status::kOk,
               "interrupted rollback could not be retried");
      } else {
        Expect(Contains(result, "phase=config_staged"),
               "interruption did not preserve staged profile for a fresh attempt");
      }
    }
    RemoveTestRoot(root);
  }
}

void TestProtectedHandoffRetainsGuardUntilVerifiedOrExplicitOff() {
  using namespace pokrov::service;
  for (int scenario = 0; scenario != 3; ++scenario) {
    const auto root = CreateTestRoot();
    {
      auto core = std::make_unique<FakeCoreRuntime>();
      auto* core_state = core.get();
      auto probe = std::make_unique<FakeEgressProbe>();
      auto* probe_state = probe.get();
      auto guard = std::make_unique<FakeTransitionGuard>();
      auto* guard_state = guard.get();
      RuntimeHost host(std::move(core), std::move(probe), std::make_unique<FakeRecovery>(),
          root, false, nullptr, std::move(guard));
      Expect(host.StageProfile("0\n{}").status == Status::kOk &&
             host.Connect(ProfileDigest("0\n{}")).status == Status::kOk,
             "protected handoff fixture could not connect");
      OperationInterruption interruption = OperationInterruption::kNone;
      core_state->on_start = [&] { Expect(guard_state->armed, "handoff Start ran without guard"); };
      probe_state->on_verify = [&] {
        Expect(guard_state->armed && guard_state->finishes == 0, "guard released before new egress verification");
        if (scenario == 2) interruption = OperationInterruption::kCancelled;
      };
      if (scenario == 1) core_state->start_error = "fixture failure";
      const auto result = host.ReplaceManagedProfile("1\n{}", [&] { return interruption; });
      Expect(guard_state->starts == 1, "handoff did not arm the guard exactly once");
      if (scenario == 0) {
        Expect(result.status == Status::kOk && !guard_state->armed && guard_state->finishes == 1 &&
                   Contains(result, ";core_egress_validated=1;") &&
                   result.body.find(";effective_profile_digest=" + ProfileDigest("1\n{}")) != std::string::npos,
               "verified replacement did not finish with its exact identity");
        Expect(host.CancelProtectedHandoff().status == Status::kOk && guard_state->armed,
               "late cancellation stopped replacement without rearming guard");
      } else {
        Expect(result.status != Status::kOk && guard_state->armed && guard_state->finishes == 0 &&
                   Contains(host.Snapshot(), ";core_egress_validated=0;"),
               "failed/cancelled replacement released guard or reported protection");
      }
      Expect(host.Disconnect().status == Status::kOk && !guard_state->armed && guard_state->offs == 1,
             "explicit off did not clear retained guard");
    }
    RemoveTestRoot(root);
  }
}

}  // namespace

int main(int argc, char** argv) {
  if (argc == 2 && std::string(argv[1]) == "--local-dpi-test-child") {
    ::Sleep(10000);
    return 0;
  }
  if (argc == 2 && std::string(argv[1]) == "--local-dpi-lifecycle") {
    TestWindowsLocalDpiOwnedCleanup();
    return failures == 0 ? 0 : 1;
  }
  if (argc == 2 && std::string(argv[1]) == "--periodic-cancel-observation") {
    TestRuntimeLifecycle();
    return failures == 0 ? 0 : 1;
  }
  TestReleasedCoreDescriptorCompatibility();
  TestWindowsTelegramMetadataComposition();
  TestWindowsLocalDpiScopePreparation();
  TestWindowsLocalDpiOwnedCleanup();
  TestProtectedHandoffRetainsGuardUntilVerifiedOrExplicitOff();
  TestInterruptedConnectNeverPublishesProtection();
  TestProfileIdentityFollowsCommittedRuntime();
  TestFailedProfileSecurityPreservesPreviouslyStagedBytes();
  TestRuntimeLifecycle();
  TestBundledRuleSetsAreStagedInsideProtectedWorkingDirectory();
  TestCoreErrorsAreSanitized();
  TestEgressFailureStopsCoreAndIsSanitized();
  TestPendingRecoveryStopsCoreBeforeRuntimeReady();
  TestStartupRecoveryIsEagerOnlyWhenJournalIsPending();
  TestFailedStartupRecoveryRemainsRetryable();
  TestConnectFaultsRollbackEveryPersistedStage();
  TestSnapshotCaptureFailureDoesNotStartCore();
  TestRollbackFailuresStayClosedAndCanRetry();
  TestDurableRecoveryJournalSurvivesRestart();
  TestRecoveredCheckpointCanRetryAndSurviveRestart();
  TestCorruptRecoveryJournalIsPreservedAndFailsClosed();
  TestPartialRecoveryJournalIsPreservedAndFailsClosed();
  TestCoreOperationalEventFenceRejectsLateAndUnsafeCallbacks();
  return failures == 0 ? 0 : 1;
}
