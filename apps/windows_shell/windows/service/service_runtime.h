#ifndef POKROV_SERVICE_SERVICE_RUNTIME_H_
#define POKROV_SERVICE_SERVICE_RUNTIME_H_

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "service_protocol.h"
#include "service_recovery.h"
#include "service_events.h"

namespace pokrov::service {

struct RuntimeDirectories {
  std::wstring base;
  std::wstring working;
  std::wstring temporary;
  std::wstring config;
};

class CoreRuntime {
 public:
  virtual ~CoreRuntime() = default;

  virtual std::string Initialize(const RuntimeDirectories& directories) = 0;
  virtual std::string SecureFile(const std::wstring& path) = 0;
  virtual std::string Start(const std::wstring& config_path,
                            bool disable_memory_limit) = 0;
  virtual std::string Stop() = 0;
  virtual void SetOperationalEventSink(ServiceEventSink* events) {}
};

class CoreOperationalEventFence {
 public:
  bool Activate(const std::string& run_id, const std::string& attempt_id,
                std::int64_t generation);
  bool Accept(const CoreOperationalEventRecord& event);

 private:
  std::string run_id_;
  std::string attempt_id_;
  std::int64_t generation_ = 0;
  std::int64_t last_sequence_ = 0;
};

class RuntimeEgressProbe {
 public:
  virtual ~RuntimeEgressProbe() = default;
  virtual std::string Verify() = 0;
};

struct RuntimeResult {
  Status status = Status::kNotReady;
  std::string body;
};

class RuntimeHost {
 public:
  RuntimeHost(std::unique_ptr<CoreRuntime> core,
              std::unique_ptr<RuntimeEgressProbe> egress_probe,
              std::unique_ptr<RuntimeRecovery> recovery,
              std::wstring runtime_root, bool secure_storage,
              ServiceEventSink* events = nullptr);
  ~RuntimeHost();

  RuntimeResult Snapshot() const;
  RuntimeResult RecoverOnStartup();
  RuntimeResult Initialize();
  RuntimeResult StageProfile(const std::string& body);
  RuntimeResult InvalidateProfile();
  RuntimeResult Connect(const std::string& expected_profile_digest);
  RuntimeResult Disconnect();
  void Shutdown();

 private:
  enum class Phase {
    kArtifactMissing,
    kArtifactReady,
    kInitialized,
    kConfigStaged,
    kRunning,
    kRecoveryRequired,
  };

  RuntimeResult Fail(Status status, const char* failure);
  std::string SnapshotBody() const;
  bool PrepareDirectories();
  std::string WriteProfileAtomically(const std::string& profile);
  bool WriteBundledRuleSets(
      int slot, const std::vector<std::vector<std::uint8_t>>& rule_sets,
      std::vector<std::wstring>* written_paths);
  void CleanupBundledRuleSets(int slot);
  std::string RecoverPendingRuntime();
  std::string RollbackRuntime();
  void RecordEvent(ServiceEvent event, ServiceEventOutcome outcome);

  std::unique_ptr<CoreRuntime> core_;
  std::unique_ptr<RuntimeEgressProbe> egress_probe_;
  std::unique_ptr<RuntimeRecovery> recovery_;
  std::wstring runtime_root_;
  ServiceEventSink* events_ = nullptr;
  RuntimeDirectories directories_;
  std::wstring profile_path_;
  bool secure_storage_ = true;
  bool initialized_ = false;
  bool profile_staged_ = false;
  std::string staged_profile_digest_;
  std::string effective_profile_digest_;
  bool disable_memory_limit_ = false;
  int bundled_rule_set_slot_ = 0;
  bool core_egress_validated_ = false;
  Phase phase_ = Phase::kArtifactMissing;
  std::string failure_ = "core_not_initialized";
};

std::unique_ptr<CoreRuntime> CreateInstalledCoreRuntime();
std::unique_ptr<RuntimeEgressProbe> CreateAuthenticatedEgressProbe();
std::wstring ResolveServiceRuntimeRoot();

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_RUNTIME_H_
