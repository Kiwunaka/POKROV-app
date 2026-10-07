#ifndef POKROV_SERVICE_SERVICE_RUNTIME_H_
#define POKROV_SERVICE_SERVICE_RUNTIME_H_

#include <cstdint>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>
#include <utility>

#include "service_protocol.h"
#include "service_network_observer.h"
#include "service_recovery.h"
#include "service_events.h"
#include "service_transition_guard.h"

namespace pokrov::service {
class WindowsLocalDpiExecutor;
enum class WindowsLocalDpiStrategy;
struct WindowsLocalDpiPreparation;
struct WindowsTelegramWSPreparation;

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
  virtual std::string ProbeCandidate(const CandidateProbeRequest& request,
                                    const std::string& bind_interface,
                                    const CheckInterruption& interrupted) {
    return "";
  }
  virtual void SetOperationalEventSink(ServiceEventSink* events) {}
  virtual int RoutingCatalogWindowVersion() const { return 0; }
  virtual std::string TransportCapabilities() const { return ""; }
  virtual std::string CoreModuleSHA256() const { return ""; }
  virtual std::string CoreVersion() const { return ""; }
  virtual int SmartAccessLeaseVersion() const { return 0; }
  virtual int RoutingCatalogControlVersion() const { return 0; }
  virtual int SmartAccessRuntimeControlVersion() const { return 0; }
  virtual int SmartAccessProbeVersion() const { return 0; }
  virtual std::string ProbeSmartAccess(const std::string& tag, bool periodic,
                                      const CheckInterruption& interrupted) {
    return "core_egress_probe_unavailable";
  }
  // Native-only preparation/admission seam. API support is not an executor
  // capability or permission to admit; the host owns proof and currentness.
  virtual int WindowsLocalDpiAdmissionVersion() const { return 0; }
  virtual std::string PrepareWindowsLocalDpiProfile(
      const std::string& config, const std::string& compiled_public_keys,
      const std::string& compiled_audience, const std::string& bind_interface) {
    return "";
  }
  virtual std::string ReadLocalDpiAdmissionID(const std::string& tag) { return ""; }
  virtual int AdmitLocalDpiAdmission(const std::string& id) { return -1; }
  virtual int WithdrawLocalDpiAdmission(const std::string& id) { return -1; }
  virtual int TelegramWSAdmissionVersion() const { return 0; }
  virtual std::string PrepareTelegramWSProfile(
      const std::string& config, const std::string& compiled_public_keys,
      const std::string& compiled_audience, const std::string& bind_interface) { return ""; }
  virtual std::string ReadTelegramWSAdmissionID(const std::string& tag) { return ""; }
  virtual int AdmitTelegramWSAdmission(const std::string& id) { return -1; }
  virtual int WithdrawTelegramWSAdmission(const std::string& id) { return -1; }
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
  virtual std::optional<EgressProbeObservation> LastObservation() const {
    return std::nullopt;
  }
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
              ServiceEventSink* events = nullptr,
              std::unique_ptr<RuntimeTransitionGuard> transition_guard = nullptr);
  ~RuntimeHost();

  RuntimeResult Snapshot() const;
  RuntimeResult CrashDiagnostics() const;
  RuntimeResult PendingSnapshot(Command command) const;
  RuntimeResult RecoverOnStartup();
  RuntimeResult Initialize();
  RuntimeResult StageProfile(const std::string& body, bool requires_bound_connect = false);
  RuntimeResult InvalidateProfile();
  RuntimeResult Connect(const std::string& expected_profile_digest,
                        const CheckInterruption& interrupted = {},
                        const std::optional<CandidateNetworkContext>& local_dpi_network = std::nullopt,
                        const CheckInterruption& telegram_interrupted = {});
  RuntimeResult ConnectWithIdentity(const BoundConnectTarget& target,
                                    const CheckInterruption& interrupted = {},
                                    const std::optional<CandidateNetworkContext>& local_dpi_network = std::nullopt,
                                    const CheckInterruption& telegram_interrupted = {});
  bool RequestsWindowsLocalDpi() const { return local_dpi_requested_ && local_dpi_ready_; }
  bool ReplacementRequestsWindowsLocalDpi(const std::string& body) const;
  bool HasWindowsLocalDpi() const { return local_dpi_preparation_ != nullptr; }
  RuntimeResult MaintainWindowsLocalDpi(const CheckInterruption& interrupted = {});
  bool RequestsTelegramWS() const { return telegram_ws_requested_ && telegram_ws_ready_; }
  bool ReplacementRequestsTelegramWS(const std::string& body) const;
  bool HasTelegramWS() const { return telegram_ws_preparation_ != nullptr; }
  RuntimeResult MaintainTelegramWS(const CheckInterruption& interrupted = {});
  RuntimeResult PromoteTransportLease(const TransportLeasePromotion& target);
  RuntimeResult RevokeTransportLease(const TransportLeaseRevocation& target);
  RuntimeResult Disconnect(bool explicit_disconnect = true);
  bool CanRecheckEgress() const;
  RuntimeResult RecheckEgress(const CheckInterruption& interrupted);
  RuntimeResult ReplaceManagedProfile(const std::string& body, const CheckInterruption& interrupted,
      const std::optional<CandidateNetworkContext>& local_dpi_network = std::nullopt,
      const CheckInterruption& telegram_interrupted = {});
  RuntimeResult CancelProtectedHandoff();
  RuntimeResult RevokeSmartAccessLease(const std::string& body);
  RuntimeResult RevokeRoutingCatalog(const std::string& profile_digest);
  RuntimeResult RevokeRoutingCatalogService(const std::string& body);
  RuntimeResult RevokeSmartAccessPolicy(const std::string& body);
  RuntimeResult RenewSmartAccessLease(const std::string& body);
  RuntimeResult ConfigureSmartAccessRuntimeControl(const std::string& body, bool renewal = false);
  RuntimeResult ReadSmartAccessRestrictions();
  RuntimeResult ReadSmartAccessLeases(const std::string& profile_digest);
  // Available after Initialize; probes never read/write the TUN lifecycle state.
  CoreRuntime* CandidateProbeCore() { return initialized_ ? core_.get() : nullptr; }
  bool TransitionGuardArmed() const { return transition_guard_ && transition_guard_->IsArmed(); }
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
                            const std::string& expected_core_digest,
                            bool finish_transition_guard = true,
                            const std::optional<CandidateNetworkContext>& local_dpi_network = std::nullopt,
                            const CheckInterruption& telegram_interrupted = {});
  bool ClearWindowsLocalDpiAfterCoreStopped();
  bool WithdrawTelegramWS(const std::string& service_id = "");
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
  std::string VerifyEgress(bool periodic, const CheckInterruption& interrupted);

  std::unique_ptr<CoreRuntime> core_;
  std::unique_ptr<WindowsLocalDpiExecutor> local_dpi_executor_;
  std::unique_ptr<WindowsLocalDpiPreparation> local_dpi_preparation_;
  std::string local_dpi_profile_digest_;
  std::string local_dpi_core_digest_;
  // Ordering hint only; every new Core runtime still needs fresh holders/proof.
  std::optional<std::pair<std::string, WindowsLocalDpiStrategy>> local_dpi_success_strategy_;
  std::string original_staged_config_;
  std::string staged_runtime_config_;
  bool local_dpi_requested_ = false;
  bool local_dpi_ready_ = false;
  bool local_dpi_disabled_ = false;
  std::unique_ptr<WindowsTelegramWSPreparation> telegram_ws_preparation_;
  std::vector<std::pair<std::string, std::string>> telegram_ws_holders_;
  std::string telegram_ws_original_digest_;
  std::string telegram_ws_prepared_digest_;
  std::string telegram_ws_core_digest_;
  bool telegram_ws_requested_ = false;
  bool telegram_ws_ready_ = false;
  std::unique_ptr<RuntimeEgressProbe> egress_probe_;
  std::unique_ptr<RuntimeRecovery> recovery_;
  std::unique_ptr<RuntimeTransitionGuard> transition_guard_;
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
  std::optional<EgressProbeObservation> egress_failure_observation_;
  Phase phase_ = Phase::kArtifactMissing;
  std::string failure_ = "core_not_initialized";
};

std::unique_ptr<CoreRuntime> CreateInstalledCoreRuntime();
std::unique_ptr<RuntimeEgressProbe> CreateAuthenticatedEgressProbe(
    ServiceEventSink* events = nullptr);
#ifdef _DEBUG
// Loopback-only fixture; the production factory has no caller-owned URL.
std::unique_ptr<RuntimeEgressProbe> CreateLoopbackEgressProbeForTest(
    std::uint16_t port, bool secure = false, ServiceEventSink* events = nullptr);
#endif
std::wstring ResolveServiceRuntimeRoot();

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_RUNTIME_H_
