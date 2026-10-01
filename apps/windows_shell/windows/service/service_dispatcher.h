#ifndef POKROV_SERVICE_SERVICE_DISPATCHER_H_
#define POKROV_SERVICE_SERVICE_DISPATCHER_H_

#include <windows.h>

#include <atomic>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

#include "service_runtime.h"
#include "service_network_observer.h"

namespace pokrov::service {

// Session threads may serve status/cancel concurrently. All RuntimeHost access
// and network mutations remain serialized, including cancellation rollback.
class RuntimeDispatcher {
 public:
  explicit RuntimeDispatcher(RuntimeHost* runtime,
      std::function<std::optional<CandidateNetworkContext>()> candidate_network = {},
      std::function<bool(std::uint64_t)> candidate_current = {},
      ULONGLONG egress_interval_ms = 2000);
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
    bool protected_handoff = false;
    bool local_dpi_owner = false;  // Private captured physical-network owner.
    std::atomic<bool> local_dpi_cancelled{false};
  };
  RuntimeResult Cancel(const std::string& body);
  RuntimeResult CancelAndConfirm(const std::string& body);
  struct ActiveProbe {
    CancellationTarget target;
    std::string id;
    std::atomic<bool> cancelled{false};
  };
  RuntimeResult ProbeCandidate(const Frame& request, HANDLE stop_event,
                               ULONGLONG deadline, HANDLE client_pipe);
  RuntimeResult CancelCandidateProbe(const std::string& body);
  void RetireConnect();  // caller holds state_lock_; native cleanup has ended
  void WatchBoundConnect();
  void CheckRunningEgress();
  void RefreshBoundNetwork(const std::shared_ptr<ActiveConnect>& operation);
  RuntimeResult ProjectBoundState(RuntimeResult result);  // state_lock_ held
  RuntimeHost* runtime_;
  ServiceNetworkObserver network_;
  std::function<std::optional<CandidateNetworkContext>()> candidate_network_;
  std::function<bool(std::uint64_t)> candidate_current_;
  std::mutex execution_lock_;
  std::mutex state_lock_;
  RuntimeResult snapshot_;
  std::shared_ptr<ActiveConnect> active_connect_;
  std::optional<CancellationTarget> stopped_connect_;
  std::condition_variable watch_changed_;
  bool closing_ = false;
  const ULONGLONG egress_interval_ms_;
  ULONGLONG next_egress_check_ = 0;  // execution_lock_ held
  std::shared_ptr<std::atomic<bool>> egress_check_cancelled_;  // state_lock_ held
  std::thread watcher_;
  std::mutex probes_lock_;
  std::vector<std::shared_ptr<ActiveProbe>> probes_;
};

}  // namespace pokrov::service
#endif
