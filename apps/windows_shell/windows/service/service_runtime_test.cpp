#include "service_runtime.h"
#include "service_profile_identity.h"

#include <windows.h>

#include <iostream>
#include <memory>
#include <string>
#include <vector>

namespace {

int failures = 0;

void Expect(bool condition, const char* message) {
  if (!condition) {
    std::cerr << message << '\n';
    ++failures;
  }
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
    return start_error;
  }

  std::string Stop() override {
    ++stop_calls;
    return stop_error;
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
};

class FakeEgressProbe final : public pokrov::service::RuntimeEgressProbe {
 public:
  std::string Verify() override {
    ++verify_calls;
    return verify_error;
  }

  int verify_calls = 0;
  std::string verify_error;
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
        "TRANSPORT-004"}) {
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

}  // namespace

int main() {
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
