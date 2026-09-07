#ifndef POKROV_SERVICE_SERVICE_DISPATCHER_H_
#define POKROV_SERVICE_SERVICE_DISPATCHER_H_

#include <windows.h>

#include <atomic>
#include <memory>
#include <mutex>

#include "service_runtime.h"

namespace pokrov::service {

// Session threads may serve status/cancel concurrently. All RuntimeHost access
// and network mutations remain serialized, including cancellation rollback.
class RuntimeDispatcher {
 public:
  explicit RuntimeDispatcher(RuntimeHost* runtime);
  RuntimeResult Execute(const Frame& request, HANDLE stop_event,
                        ULONGLONG monotonic_deadline);

 private:
  struct ActiveConnect {
    CancellationTarget target;
    std::atomic<bool> cancelled{false};
  };
  RuntimeResult Cancel(const std::string& body);
  RuntimeHost* runtime_;
  std::mutex execution_lock_;
  std::mutex state_lock_;
  RuntimeResult snapshot_;
  std::shared_ptr<ActiveConnect> active_connect_;
};

}  // namespace pokrov::service
#endif
