#include "service_dispatcher.h"

namespace pokrov::service {

RuntimeDispatcher::RuntimeDispatcher(RuntimeHost* runtime)
    : runtime_(runtime), snapshot_(runtime->Snapshot()) {}

RuntimeResult RuntimeDispatcher::Cancel(const std::string& body) {
  const auto target = DecodeCancellationTarget(body);
  if (!target) return {Status::kInvalid, "invalid_cancellation_target"};
  std::lock_guard<std::mutex> state(state_lock_);
  if (!active_connect_ ||
      active_connect_->target.session_token != target->session_token ||
      active_connect_->target.operation_nonce != target->operation_nonce) {
    return {Status::kNotReady, "operation_not_active"};
  }
  active_connect_->cancelled = true;
  return {Status::kOk, "cancellation_requested"};
}

RuntimeResult RuntimeDispatcher::Execute(const Frame& request, HANDLE stop_event,
                                         ULONGLONG deadline) {
  if (request.command == Command::kCancel) return Cancel(request.body);
  if (request.command == Command::kDiagnosticState) {
    if (!request.body.empty()) return {Status::kInvalid, "invalid_diagnostic_request"};
    return runtime_->CrashDiagnostics();
  }
  if (request.command == Command::kStatus) {
    std::lock_guard<std::mutex> state(state_lock_);
    return snapshot_;
  }
  std::unique_lock<std::mutex> execution(execution_lock_, std::try_to_lock);
  if (!execution.owns_lock()) {
    std::lock_guard<std::mutex> state(state_lock_);
    auto busy = snapshot_;
    busy.status = Status::kNotReady;
    const auto failure = busy.body.rfind(";failure=");
    if (failure != std::string::npos) busy.body.replace(failure, std::string::npos,
                                                     ";failure=runtime_busy");
    return busy;
  }
  const auto operation = request.command == Command::kConnect
                             ? std::make_shared<ActiveConnect>() : nullptr;
  {
    std::lock_guard<std::mutex> state(state_lock_);
    if (operation) {
      operation->target = {request.session_token, request.operation_nonce};
    }
    active_connect_ = operation;
    snapshot_ = runtime_->PendingSnapshot(request.command);
  }
  RuntimeResult result;
  switch (request.command) {
    case Command::kInitialize: result = runtime_->Initialize(); break;
    case Command::kStageProfile: result = runtime_->StageProfile(request.body); break;
    case Command::kInvalidateProfile: result = runtime_->InvalidateProfile(); break;
    case Command::kConnect:
      result = runtime_->Connect(request.body, [operation, stop_event, deadline] {
        if (operation->cancelled ||
            ::WaitForSingleObject(stop_event, 0) == WAIT_OBJECT_0) {
          return OperationInterruption::kCancelled;
        }
        return ::GetTickCount64() >= deadline
                   ? OperationInterruption::kDeadlineExceeded : OperationInterruption::kNone;
      });
      break;
    case Command::kDisconnect: result = runtime_->Disconnect(); break;
    default: result = {Status::kNotReady, "runtime_not_owned"}; break;
  }
  bool cancel_after_commit = false;
  {
    std::lock_guard<std::mutex> state(state_lock_);
    // Clear under the same lock as cancellation matching. A late cancel cannot
    // reach a later generation, even when a new connection starts immediately.
    cancel_after_commit = operation && operation->cancelled && result.status == Status::kOk;
    if (!cancel_after_commit) {
      active_connect_.reset();
      snapshot_ = runtime_->Snapshot();
    }
  }
  if (cancel_after_commit) {
    result = runtime_->Disconnect();
    if (result.status == Status::kOk) {
      result.status = Status::kNotReady;
      const auto failure = result.body.rfind(";failure=");
      result.body.replace(failure, std::string::npos, ";failure=operation_cancelled");
    }
    std::lock_guard<std::mutex> state(state_lock_);
    active_connect_.reset();
    snapshot_ = runtime_->Snapshot();
  }
  return result;
}

}  // namespace pokrov::service
