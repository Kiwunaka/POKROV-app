#ifndef POKROV_SERVICE_SERVICE_TRANSITION_GUARD_H_
#define POKROV_SERVICE_SERVICE_TRANSITION_GUARD_H_

#include <memory>
#include <string>

#ifdef _DEBUG
#include <functional>
struct FWPM_FILTER0_;
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

std::unique_ptr<RuntimeTransitionGuard> CreateWindowsTransitionGuard();

enum class TransitionGuardState { kOff, kArmed, kIncomplete };

// Same boundary as RuntimeRecovery's backend: tests never change host policy.
class TransitionGuardBackend {
 public:
  virtual ~TransitionGuardBackend() = default;
  virtual std::string Read(TransitionGuardState* state) = 0;
  virtual std::string Install() = 0;
  virtual std::string Remove() = 0;
};

std::unique_ptr<RuntimeTransitionGuard> CreateTransitionGuardForTesting(
    std::unique_ptr<TransitionGuardBackend> backend);

#ifdef _DEBUG
// Builds the actual filter definitions without opening the engine or adding or
// deleting any WFP objects. The visitor's pointers are valid only in the call.
std::string VisitTransitionGuardFiltersForTesting(
    const std::function<void(const FWPM_FILTER0_&)>& visitor);
#endif

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_TRANSITION_GUARD_H_
