#ifndef POKROV_SERVICE_SERVICE_RECOVERY_H_
#define POKROV_SERVICE_SERVICE_RECOVERY_H_

#include <memory>
#include <string>

namespace pokrov::service {

enum class RecoveryStage {
  kClean,
  kSnapshotted,
  kCoreStarted,
  kNetworkApplied,
  kVerified,
  kCommitted,
  kRollingBack,
  kRecovered,
};

class NetworkStateBackend {
 public:
  virtual ~NetworkStateBackend() = default;

  virtual std::string Capture(std::string* snapshot) = 0;
  virtual std::string Restore(const std::string& snapshot) = 0;
};

class RuntimeRecovery {
 public:
  virtual ~RuntimeRecovery() = default;

  virtual bool RequiresRecovery() const = 0;
  virtual const char* StageName() const = 0;
  virtual std::string Begin() = 0;
  virtual std::string Record(RecoveryStage stage) = 0;
  virtual std::string BeginRollback() = 0;
  virtual std::string RestoreNetworkState() = 0;
  virtual std::string CompleteRollback() = 0;
};

std::unique_ptr<NetworkStateBackend> CreateWindowsNetworkStateBackend();
std::unique_ptr<RuntimeRecovery> CreateRuntimeRecovery(
    const std::wstring& runtime_root);
std::unique_ptr<RuntimeRecovery> CreateRuntimeRecoveryForTesting(
    const std::wstring& runtime_root,
    std::unique_ptr<NetworkStateBackend> network_state);

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_RECOVERY_H_
