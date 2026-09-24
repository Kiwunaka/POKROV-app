#ifndef POKROV_SERVICE_SERVICE_DISPATCHER_H_
#define POKROV_SERVICE_SERVICE_DISPATCHER_H_

#include <windows.h>

#include <atomic>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <thread>

#include "service_runtime.h"
#include "service_network_observer.h"

namespace pokrov::service {

// Session threads may serve status/cancel concurrently. All RuntimeHost access
// and network mutations remain serialized, including cancellation rollback.
class RuntimeDispatcher {
 public:
  explicit RuntimeDispatcher(RuntimeHost* runtime);
  ~RuntimeDispatcher();
  RuntimeResult Execute(const Frame& request, HANDLE stop_event,
                        ULONGLONG monotonic_deadline, HANDLE client_pipe);

 private:
  struct ActiveConnect {
    ~ActiveConnect() { if (client_process != nullptr) ::CloseHandle(client_process); }
    CancellationTarget target;
    std::atomic<bool> cancelled{false};
    std::atomic<bool> deadline_expired{false};
    std::optional<BoundConnectTarget> bound;
    std::atomic<std::uint64_t> promoted_until_elapsed_ms{0};
    std::atomic<bool> transport_terminated{false};
    std::string promoted_lease_ref;
    std::optional<std::uint64_t> network_revision;
    HANDLE client_process = nullptr;  // duplicated from the kernel-owned pipe peer PID
    RuntimeResult stopping_snapshot;
    bool cleanup_attempted = false;  // protected by state_lock_
  };
  RuntimeResult Cancel(const std::string& body);
  RuntimeResult CancelAndConfirm(const std::string& body);
  void RetireConnect();  // caller holds state_lock_; native cleanup has ended
  void WatchBoundConnect();
  void RefreshBoundNetwork(const std::shared_ptr<ActiveConnect>& operation);
  RuntimeResult ProjectBoundState(RuntimeResult result);  // state_lock_ held
  RuntimeHost* runtime_;
  ServiceNetworkObserver network_;
  std::mutex execution_lock_;
  std::mutex state_lock_;
  RuntimeResult snapshot_;
  std::shared_ptr<ActiveConnect> active_connect_;
  std::optional<CancellationTarget> stopped_connect_;
  std::condition_variable watch_changed_;
  bool closing_ = false;
  std::thread watcher_;
};

}  // namespace pokrov::service
#endif
