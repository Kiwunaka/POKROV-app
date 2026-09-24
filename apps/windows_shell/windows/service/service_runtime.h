#ifndef POKROV_SERVICE_SERVICE_RUNTIME_H_
#define POKROV_SERVICE_SERVICE_RUNTIME_H_

#include <cstdint>
#include <functional>
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

enum class OperationInterruption { kNone, kCancelled, kDeadlineExceeded };
using CheckInterruption = std::function<OperationInterruption()>;

class CoreRuntime {
 public:
  virtual ~CoreRuntime() = default;

  virtual std::string Initialize(const RuntimeDirectories& directories) = 0;
  virtual std::string SecureFile(const std::wstring& path) = 0;
  virtual std::string Start(const std::wstring& config_path,
                            bool disable_memory_limit) = 0;
  virtual bool SupportsInterruptibleStart() const { return false; }
  virtual std::string StartInterruptible(const std::wstring& config_path,
                                        bool disable_memory_limit,
                                        const CheckInterruption& interrupted) {
    return "core_abi_incompatible";
  }
  virtual std::string Stop() = 0;
  virtual void SetOperationalEventSink(ServiceEventSink* events) {}
  virtual int RoutingCatalogWindowVersion() const { return 0; }
  virtual std::string TransportCapabilities() const { return ""; }
  virtual std::string CoreModuleSHA256() const { return ""; }
  virtual int SmartAccessLeaseVersion() const { return 0; }
  virtual int RoutingCatalogControlVersion() const { return 0; }
  virtual int SmartAccessRuntimeControlVersion() const { return 0; }
  virtual int ConfigureSmartAccessRuntimeControl(const std::string& profile_digest, const std::string& config) { return -1; }
  virtual int ConfigureSmartAccessRenewal(const std::string& profile_digest, const std::string& config) { return -1; }
  virtual std::string ReadSmartAccessRestrictions() { return ""; }
  virtual std::string ReadSmartAccessLeases() { return ""; }
  virtual int AcknowledgeSmartAccessRestrictions(const std::string& digest) { return -1; }
  virtual int RevokeRoutingCatalog() { return -1; }
  virtual int RevokeRoutingCatalogService(const std::string& service_id) { return -1; }
  virtual int RevokeSmartAccessPolicy(bool terminate_active) { return -1; }
  virtual int RevokeSmartAccessLease(const std::string& lease_id, bool terminate_active) { return -1; }
  virtual int RenewSmartAccessLease(const SmartAccessRenewalTarget& target) { return -1; }
  virtual int ConfirmATSLease(const TransportLeasePromotion& target) { return -1; }
  virtual int RevokeATSLease(const TransportLeaseRevocation& target) { return -1; }
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
  virtual std::string Verify(const CheckInterruption& interrupted = {}) = 0;
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
  RuntimeResult CrashDiagnostics() const;
  RuntimeResult PendingSnapshot(Command command) const;
  RuntimeResult RecoverOnStartup();
  RuntimeResult Initialize();
  RuntimeResult StageProfile(const std::string& body, bool requires_bound_connect = false);
  RuntimeResult InvalidateProfile();
  RuntimeResult Connect(const std::string& expected_profile_digest,
                        const CheckInterruption& interrupted = {});
  RuntimeResult ConnectWithIdentity(const BoundConnectTarget& target,
                                    const CheckInterruption& interrupted = {});
  RuntimeResult PromoteTransportLease(const TransportLeasePromotion& target);
  RuntimeResult RevokeTransportLease(const TransportLeaseRevocation& target);
  RuntimeResult Disconnect();
  RuntimeResult RevokeSmartAccessLease(const std::string& body);
  RuntimeResult RevokeRoutingCatalog(const std::string& profile_digest);
  RuntimeResult RevokeRoutingCatalogService(const std::string& body);
  RuntimeResult RevokeSmartAccessPolicy(const std::string& body);
  RuntimeResult RenewSmartAccessLease(const std::string& body);
  RuntimeResult ConfigureSmartAccessRuntimeControl(const std::string& body, bool renewal = false);
  RuntimeResult ReadSmartAccessRestrictions();
  RuntimeResult ReadSmartAccessLeases(const std::string& profile_digest);
  RuntimeResult AcknowledgeSmartAccessRestrictions(const std::string& digest);
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
  RuntimeResult ConnectImpl(const std::string& expected_profile_digest,
                            const CheckInterruption& interrupted,
                            const std::string& expected_core_digest);
  std::string SnapshotBody(const char* pending_phase = nullptr) const;
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
  bool requires_bound_connect_ = false;
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
#ifdef _DEBUG
// Loopback-only fixture; the production factory has no caller-owned URL.
std::unique_ptr<RuntimeEgressProbe> CreateLoopbackEgressProbeForTest(
    std::uint16_t port, bool secure = false);
#endif
std::wstring ResolveServiceRuntimeRoot();

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_RUNTIME_H_
