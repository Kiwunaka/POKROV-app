#ifndef POKROV_SERVICE_SERVICE_TRANSITION_GUARD_H_
#define POKROV_SERVICE_SERVICE_TRANSITION_GUARD_H_

#include <memory>
#include <string>

#include "service_events.h"

#ifdef _DEBUG
#include <functional>
struct FWPM_FILTER0_;
struct FWPM_SUBLAYER0_;
#endif

namespace pokrov::service {

class RuntimeTransitionGuard {
 public:
  virtual ~RuntimeTransitionGuard() = default;
  // Start must succeed before stopping the current Core. Finish is only for a
  // verified replacement. Failure/destruction never releases the guard.
  virtual std::string Start() = 0;
  virtual std::string Finish() = 0;
  // Also usable by the service's explicit repair/uninstall command while the
  // service is stopped. Removes only this guard's fixed WFP object keys.
  virtual std::string ExplicitOff() = 0;
  // Includes incomplete/unknown persisted state: the UI must require action.
  virtual bool IsArmed() const = 0;
};

std::unique_ptr<RuntimeTransitionGuard> CreateWindowsTransitionGuard(
    ServiceEventSink* events = nullptr);

enum class TransitionGuardState { kOff, kArmed, kIncomplete };

struct TransitionGuardFailure {
  TransitionGuardStage stage = TransitionGuardStage::kReadVerify;
  std::uint32_t wfp_error = 0;
};

// Same boundary as RuntimeRecovery's backend: tests never change host policy.
class TransitionGuardBackend {
 public:
  virtual ~TransitionGuardBackend() = default;
  virtual std::string Read(TransitionGuardState* state) = 0;
  virtual std::string Install() = 0;
  virtual std::string Remove() = 0;
  virtual TransitionGuardFailure LastFailure() const { return {}; }
};

std::unique_ptr<RuntimeTransitionGuard> CreateTransitionGuardForTesting(
    std::unique_ptr<TransitionGuardBackend> backend,
    ServiceEventSink* events = nullptr);

#ifdef _DEBUG
// Builds the actual filter definitions without opening the engine or adding or
// deleting any WFP objects. The visitor's pointers are valid only in the call.
std::string VisitTransitionGuardFiltersForTesting(
    const std::function<void(const FWPM_FILTER0_&)>& visitor);
bool TransitionGuardFilterMatchesForTesting(
    const FWPM_FILTER0_& actual, const FWPM_FILTER0_& expected);
bool TransitionGuardSubLayerMatchesForTesting(const FWPM_SUBLAYER0_& actual);
#endif

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_TRANSITION_GUARD_H_
