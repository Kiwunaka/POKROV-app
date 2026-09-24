#include "service_dispatcher.h"
#include "service_boot_clock.h"
#include <chrono>
#include <utility>

namespace pokrov::service {
namespace {
bool SameTarget(const CancellationTarget& left, const CancellationTarget& right) {
  return left.session_token == right.session_token && left.operation_nonce == right.operation_nonce;
}

RuntimeResult WithFailure(RuntimeResult result, Status status, const char* code) {
  result.status = status;
  const auto field = result.body.rfind(";failure=");
  if (field != std::string::npos) {
    const auto end = result.body.find(';', field + 1);
    result.body.replace(field, end == std::string::npos ? end : end - field,
                        std::string(";failure=") + code);
  } else {
    result.body = code;
  }
  return result;
}

RuntimeResult WithTransportState(RuntimeResult result, bool pending, bool active) {
  // Only runtime snapshots carry these fields, never control/settlement receipts.
  if (result.body.rfind("phase=", 0) == 0) {
    result.body += std::string(";transport_proof_pending=") + (pending ? "1" : "0");
    result.body += std::string(";transport_lease_active=") +
        (active && result.body.rfind("phase=running;", 0) == 0 ? "1" : "0");
  }
  return result;
}
}

RuntimeDispatcher::RuntimeDispatcher(RuntimeHost* runtime)
    : runtime_(runtime), snapshot_(runtime->Snapshot()),
      watcher_([this] { WatchBoundConnect(); }) {}

RuntimeDispatcher::~RuntimeDispatcher() {
  {
    std::lock_guard<std::mutex> state(state_lock_);
    closing_ = true;
  }
  watch_changed_.notify_all();
  watcher_.join();
}

void RuntimeDispatcher::RefreshBoundNetwork(const std::shared_ptr<ActiveConnect>& operation) {
  if (!operation || !operation->bound || operation->cancelled) return;
  if ((operation->promoted_until_elapsed_ms.load() == 0 || operation->transport_terminated.load()) &&
      (operation->client_process == nullptr ||
       ::WaitForSingleObject(operation->client_process, 0) != WAIT_TIMEOUT)) {
    operation->cancelled = true;
    watch_changed_.notify_all();
    return;
  }
  const auto current = network_.Sample();
  if (!current || current != operation->network_revision || !network_.IsCurrent(*current)) {
    operation->cancelled = true;
    watch_changed_.notify_all();
  }
}

RuntimeResult RuntimeDispatcher::ProjectBoundState(RuntimeResult result) {
  const auto& operation = active_connect_;
  const bool bound = operation && operation->bound.has_value();
  if (bound) {
    const auto promoted = operation->promoted_until_elapsed_ms.load();
    if ((promoted == 0 || operation->transport_terminated.load()) && (operation->client_process == nullptr ||
        ::WaitForSingleObject(operation->client_process, 0) != WAIT_TIMEOUT)) {
      operation->cancelled = true;
    }
    if (!operation->network_revision || !network_.IsCurrent(*operation->network_revision)) {
      operation->cancelled = true;
    }
    if (promoted ? !IsActiveTransportLeaseCurrent(*operation->bound, promoted)
                 : !IsConnectDeadlineCurrent(*operation->bound)) operation->deadline_expired = true;
    if (operation->cancelled || operation->deadline_expired) {
      watch_changed_.notify_all();
      // Status cannot read RuntimeHost while Start/Stop holds the execution
      // lock. Use the pre-captured busy frame until cleanup publishes state.
      // Preserve a recorded recovery failure rather than masking it as busy.
      if (result.body.rfind("phase=", 0) == 0 && result.body.rfind("phase=recovery_required;", 0) != 0) {
        result = WithFailure(operation->stopping_snapshot,
            operation->deadline_expired ? Status::kDeadlineExceeded : Status::kNotReady,
            operation->deadline_expired ? "connect_deadline" : "operation_cancelled");
      }
    }
  }
  return WithTransportState(std::move(result),
      bound && (operation->promoted_until_elapsed_ms.load() == 0 || operation->transport_terminated.load()),
      bound && operation->promoted_until_elapsed_ms.load() != 0 && !operation->transport_terminated.load());
}

void RuntimeDispatcher::WatchBoundConnect() {
  for (;;) {
    std::shared_ptr<ActiveConnect> operation;
    {
      std::unique_lock<std::mutex> state(state_lock_);
      watch_changed_.wait_for(state, std::chrono::milliseconds(100), [this] {
        return closing_ || (active_connect_ && active_connect_->bound &&
            active_connect_->cancelled && !active_connect_->cleanup_attempted);
      });
      if (closing_) return;
      operation = active_connect_;
      if (!operation || !operation->bound || operation->cleanup_attempted) continue;
    }
    RefreshBoundNetwork(operation);
    const auto promoted = operation->promoted_until_elapsed_ms.load();
    if (promoted ? !IsActiveTransportLeaseCurrent(*operation->bound, promoted)
                 : !IsConnectDeadlineCurrent(*operation->bound)) operation->deadline_expired = true;
    if (!operation->cancelled && !operation->deadline_expired) continue;
    // Core lifecycle remains serial. The flag reaches cooperative startup
    // checks now; Stop waits for any in-progress native Start to return.
    std::unique_lock<std::mutex> execution(execution_lock_);
    {
      std::lock_guard<std::mutex> state(state_lock_);
      if (closing_) return;
      if (active_connect_ != operation || operation->cleanup_attempted) continue;
      operation->cleanup_attempted = true;
    }
    const auto stopped = runtime_->Disconnect();
    std::lock_guard<std::mutex> state(state_lock_);
    snapshot_ = runtime_->Snapshot();
    if (stopped.status == Status::kOk) {
      snapshot_ = WithFailure(snapshot_, operation->deadline_expired ? Status::kDeadlineExceeded : Status::kNotReady,
          operation->deadline_expired ? "connect_deadline" : "operation_cancelled");
      RetireConnect();
    }
    // Failed restoration retains the exact owner. An explicit cancel retries;
    // timer polling must not repeatedly mutate a failed recovery transaction.
  }
}

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
  active_connect_->cleanup_attempted = false;
  watch_changed_.notify_all();
  return {Status::kOk, "cancellation_requested"};
}

void RuntimeDispatcher::RetireConnect() {
  if (active_connect_ && active_connect_->bound) stopped_connect_ = active_connect_->target;
  active_connect_.reset();
}

RuntimeResult RuntimeDispatcher::CancelAndConfirm(const std::string& body) {
  const auto target = DecodeCancellationTarget(body);
  if (!target) return {Status::kInvalid, "invalid_cancellation_target"};
  std::shared_ptr<ActiveConnect> operation;
  {
    std::lock_guard<std::mutex> state(state_lock_);
    if (stopped_connect_ && SameTarget(*stopped_connect_, *target)) return {Status::kOk, "settled=1"};
    operation = active_connect_;
    if (!operation || !operation->bound || !SameTarget(operation->target, *target)) {
      return {Status::kOk, "settled=0"};
    }
    operation->cancelled = true;
  }
  // Signal first, then join the serial runtime owner. A queued/native Start
  // must return before Stop can confirm restoration of this exact invocation.
  std::unique_lock<std::mutex> execution(execution_lock_);
  {
    std::lock_guard<std::mutex> state(state_lock_);
    if (stopped_connect_ && SameTarget(*stopped_connect_, *target)) return {Status::kOk, "settled=1"};
    if (active_connect_ != operation) return {Status::kOk, "settled=0"};
    operation->cleanup_attempted = true;
  }
  const auto result = runtime_->Disconnect();
  std::lock_guard<std::mutex> state(state_lock_);
  snapshot_ = runtime_->Snapshot();
  if (result.status != Status::kOk) return {Status::kOk, "settled=0"};
  RetireConnect();
  return {Status::kOk, "settled=1"};
}

RuntimeResult RuntimeDispatcher::Execute(const Frame& request, HANDLE stop_event,
                                         ULONGLONG deadline, HANDLE client_pipe) {
  if (request.command == Command::kCancel) return Cancel(request.body);
  if (request.command == Command::kCancelConnectAndConfirm) return CancelAndConfirm(request.body);
  if (request.command == Command::kReadBootClock) {
    if (!request.body.empty()) return {Status::kInvalid, "runtime_clock_invalid_request"};
    const auto clock = ReadBootClockJson();
    return clock ? RuntimeResult{Status::kOk, *clock}
                 : RuntimeResult{Status::kNotReady, "runtime_clock_unavailable"};
  }
  if (request.command == Command::kReadTransportNetworkContext) {
    if (!request.body.empty()) return {Status::kInvalid, "invalid_network_context_request"};
    const auto context = network_.ReadContext();
    return context ? RuntimeResult{Status::kOk, context->reference}
                   : RuntimeResult{Status::kNotReady, "network_context_unavailable"};
  }
  if (request.command == Command::kDiagnosticState) {
    if (!request.body.empty()) return {Status::kInvalid, "invalid_diagnostic_request"};
    return runtime_->CrashDiagnostics();
  }
  if (request.command == Command::kStatus) {
    std::shared_ptr<ActiveConnect> operation;
    {
      std::lock_guard<std::mutex> state(state_lock_);
      operation = active_connect_;
    }
    RefreshBoundNetwork(operation);
    std::lock_guard<std::mutex> state(state_lock_);
    return ProjectBoundState(snapshot_);
  }
  std::optional<BoundConnectTarget> bound;
  if (request.command == Command::kConnectWithIdentity) {
    bound = DecodeBoundConnect(request.body);
    if (!bound) return {Status::kInvalid, "invalid_connect_identity"};
    if (!IsConnectDeadlineCurrent(*bound)) {
      std::lock_guard<std::mutex> state(state_lock_);
      stopped_connect_ = CancellationTarget{request.session_token, request.operation_nonce};
      return {Status::kDeadlineExceeded, "connect_deadline"};
    }
  }
  std::unique_lock<std::mutex> execution(execution_lock_, std::try_to_lock);
  if (!execution.owns_lock()) {
    std::lock_guard<std::mutex> state(state_lock_);
    if (bound) stopped_connect_ = CancellationTarget{request.session_token, request.operation_nonce};
    return ProjectBoundState(WithFailure(snapshot_, Status::kNotReady, "runtime_busy"));
  }
  std::optional<std::uint64_t> network_revision;
  if (bound) {
    const auto context = network_.ReadContext();
    if (!context || context->reference != bound->network_context_ref || !network_.IsCurrent(context->revision)) {
      std::lock_guard<std::mutex> state(state_lock_);
      stopped_connect_ = CancellationTarget{request.session_token, request.operation_nonce};
      return ProjectBoundState(WithFailure(snapshot_, Status::kNotReady, "operation_cancelled"));
    }
    network_revision = context->revision;
  }
  if (request.command == Command::kPromoteTransportLease) {
    const auto promotion = DecodeTransportLeasePromotion(request.body);
    const auto active_until = promotion ? ActiveTransportLeaseDeadline(*promotion) : std::nullopt;
    if (!promotion || !active_until) return {Status::kInvalid, "transport_lease_handoff_invalid"};
    std::shared_ptr<ActiveConnect> owner;
    const auto current = [&] {
      return owner && owner == active_connect_ && owner->bound &&
          SameTarget(owner->target, promotion->target) &&
          owner->bound->profile_digest == promotion->profile_digest &&
          !owner->cancelled && !owner->deadline_expired && !owner->cleanup_attempted &&
          owner->promoted_until_elapsed_ms.load() == 0 &&
          owner->network_revision && network_.IsCurrent(*owner->network_revision) &&
          IsConnectDeadlineCurrent(*owner->bound) &&
          ::WaitForSingleObject(owner->client_process, 0) == WAIT_TIMEOUT &&
          ::GetTickCount64() < deadline && ::WaitForSingleObject(stop_event, 0) != WAIT_OBJECT_0;
    };
    {
      std::lock_guard<std::mutex> state(state_lock_);
      owner = active_connect_;
      if (!current()) return {Status::kNotReady, "connect_owner_changed"};
    }
    RefreshBoundNetwork(owner);
    if (owner->cancelled) return {Status::kNotReady, "connect_owner_changed"};
    const auto result = runtime_->PromoteTransportLease(*promotion);
    RefreshBoundNetwork(owner);
    {
      std::lock_guard<std::mutex> state(state_lock_);
      if (result.status == Status::kOk && current() &&
          IsActiveTransportLeaseCurrent(*owner->bound, *active_until)) {
        owner->promoted_until_elapsed_ms = *active_until;
        owner->promoted_lease_ref = promotion->endpoint_lease_ref;
        snapshot_ = runtime_->Snapshot();
        watch_changed_.notify_all();
        return ProjectBoundState(snapshot_);
      }
    }
    // The Core may have accepted a promotion before the owner or ACK changed.
    const auto stopped = runtime_->Disconnect();
    {
      std::lock_guard<std::mutex> state(state_lock_);
      snapshot_ = runtime_->Snapshot();
      if (stopped.status == Status::kOk && active_connect_ == owner) RetireConnect();
      else if (active_connect_ == owner) owner->cleanup_attempted = true;
    }
    return {Status::kNotReady, "transport_lease_handoff_unconfirmed"};
  }
  if (request.command == Command::kRevokeTransportLease) {
    const auto revocation = DecodeTransportLeaseRevocation(request.body);
    if (!revocation) return {Status::kInvalid, "transport_lease_revocation_invalid"};
    std::shared_ptr<ActiveConnect> owner;
    {
      std::lock_guard<std::mutex> state(state_lock_);
      owner = active_connect_;
      if (!owner || !owner->bound || !SameTarget(owner->target, revocation->target) ||
          owner->bound->profile_digest != revocation->profile_digest ||
          owner->promoted_lease_ref != revocation->endpoint_lease_ref ||
          owner->promoted_until_elapsed_ms.load() == 0 || owner->transport_terminated.load() || owner->cancelled ||
          owner->deadline_expired || owner->cleanup_attempted ||
          ::WaitForSingleObject(owner->client_process, 0) != WAIT_TIMEOUT ||
          ::GetTickCount64() >= deadline || ::WaitForSingleObject(stop_event, 0) == WAIT_OBJECT_0) {
        return {Status::kNotReady, "connect_owner_changed"};
      }
    }
    RefreshBoundNetwork(owner);
    if (owner->cancelled) return {Status::kNotReady, "connect_owner_changed"};
    const auto result = runtime_->RevokeTransportLease(*revocation);
    RefreshBoundNetwork(owner);
    {
      std::lock_guard<std::mutex> state(state_lock_);
      if (result.status == Status::kOk && active_connect_ == owner && !owner->cancelled &&
          !owner->deadline_expired && owner->promoted_lease_ref == revocation->endpoint_lease_ref) {
        if (revocation->terminate_active) owner->transport_terminated = true;
        snapshot_ = runtime_->Snapshot();
        return ProjectBoundState(snapshot_);
      }
    }
    const auto stopped = runtime_->Disconnect();
    {
      std::lock_guard<std::mutex> state(state_lock_);
      snapshot_ = runtime_->Snapshot();
      if (stopped.status == Status::kOk && active_connect_ == owner) RetireConnect();
      else if (active_connect_ == owner) owner->cleanup_attempted = true;
    }
    return {Status::kNotReady, "transport_lease_revocation_unconfirmed"};
  }
  if (request.command == Command::kConfigureBoundSmartAccessRuntimeControl) {
    if (!IsBoundSmartAccessRuntimeControl(request.body)) return {Status::kInvalid, "invalid_runtime_control"};
    const auto target = DecodeCancellationTarget(request.body.substr(0, 64));
    const auto body = request.body.substr(65);
    std::shared_ptr<ActiveConnect> owner;
    const auto current = [&] {
      return owner && owner == active_connect_ && owner->bound &&
          SameTarget(owner->target, *target) && !owner->cancelled && !owner->deadline_expired &&
          owner->network_revision && network_.IsCurrent(*owner->network_revision) &&
          owner->bound->profile_digest == body.substr(0, 64) && IsConnectDeadlineCurrent(*owner->bound) &&
          ::GetTickCount64() < deadline && ::WaitForSingleObject(stop_event, 0) != WAIT_OBJECT_0;
    };
    {
      std::lock_guard<std::mutex> state(state_lock_);
      owner = active_connect_;
      if (!current()) return {Status::kNotReady, "connect_owner_changed"};
    }
    RefreshBoundNetwork(owner);
    if (owner->cancelled) return {Status::kNotReady, "connect_owner_changed"};
    // The execution lock excludes Stop and replacement for the whole native
    // mutation. Cancellation may signal concurrently; it suppresses receipt
    // publication and its serial cleanup follows this command.
    const auto result = runtime_->ConfigureSmartAccessRuntimeControl(body);
    RefreshBoundNetwork(owner);
    std::lock_guard<std::mutex> state(state_lock_);
    snapshot_ = runtime_->Snapshot();
    return current() ? result : RuntimeResult{Status::kNotReady, "connect_owner_changed"};
  }
  const auto operation = IsConnectCommand(request.command)
                             ? std::make_shared<ActiveConnect>() : nullptr;
  if (bound) {
    DWORD client_pid = 0;
    if (::GetNamedPipeClientProcessId(client_pipe, &client_pid) == FALSE || client_pid == 0) {
      std::lock_guard<std::mutex> state(state_lock_);
      stopped_connect_ = CancellationTarget{request.session_token, request.operation_nonce};
      return {Status::kNotReady, "connect_owner_unavailable"};
    }
    operation->client_process = ::OpenProcess(SYNCHRONIZE, FALSE, client_pid);
    if (operation->client_process == nullptr ||
        ::WaitForSingleObject(operation->client_process, 0) != WAIT_TIMEOUT) {
      std::lock_guard<std::mutex> state(state_lock_);
      stopped_connect_ = CancellationTarget{request.session_token, request.operation_nonce};
      return {Status::kNotReady, "connect_owner_unavailable"};
    }
  }
  {
    std::lock_guard<std::mutex> state(state_lock_);
    if (active_connect_ && active_connect_->bound &&
        (operation || request.command == Command::kInitialize || request.command == Command::kStageProfile ||
         request.command == Command::kStageBoundProfile ||
         request.command == Command::kInvalidateProfile)) {
      if (bound) stopped_connect_ = CancellationTarget{request.session_token, request.operation_nonce};
      return ProjectBoundState(WithFailure(snapshot_, Status::kNotReady, "runtime_busy"));
    }
    if (operation) {
      operation->target = {request.session_token, request.operation_nonce};
      operation->bound = bound;
      operation->network_revision = network_revision;
      if (bound) operation->stopping_snapshot = runtime_->PendingSnapshot(Command::kDisconnect);
      active_connect_ = operation;
    }
    snapshot_ = (request.command == Command::kRevokeSmartAccessLease || request.command == Command::kRevokeRoutingCatalog ||
        request.command == Command::kRevokeSmartAccessPolicy || request.command == Command::kRevokeRoutingCatalogService ||
        request.command == Command::kRenewSmartAccessLease || request.command == Command::kConfigureSmartAccessRuntimeControl ||
        request.command == Command::kReadSmartAccessRestrictions || request.command == Command::kAcknowledgeSmartAccessRestrictions ||
        request.command == Command::kReadSmartAccessLeases || request.command == Command::kConfigureSmartAccessRenewal)
        ? runtime_->Snapshot() : runtime_->PendingSnapshot(request.command);
  }
  RuntimeResult result;
  switch (request.command) {
    case Command::kInitialize: result = runtime_->Initialize(); break;
    case Command::kStageProfile: result = runtime_->StageProfile(request.body); break;
    case Command::kStageBoundProfile: result = runtime_->StageProfile(request.body, true); break;
    case Command::kInvalidateProfile: result = runtime_->InvalidateProfile(); break;
    case Command::kConnect:
    case Command::kConnectWithIdentity: {
      const CheckInterruption interrupted = [this, operation, stop_event, deadline] {
        if (operation->bound && (operation->client_process == nullptr ||
            ::WaitForSingleObject(operation->client_process, 0) != WAIT_TIMEOUT)) operation->cancelled = true;
        if (operation->bound && (!operation->network_revision ||
            !network_.IsCurrent(*operation->network_revision))) operation->cancelled = true;
        if (operation->cancelled ||
            ::WaitForSingleObject(stop_event, 0) == WAIT_OBJECT_0) {
          return OperationInterruption::kCancelled;
        }
        if (operation->bound && (operation->deadline_expired || !IsConnectDeadlineCurrent(*operation->bound))) {
          operation->deadline_expired = true;
          return OperationInterruption::kDeadlineExceeded;
        }
        return ::GetTickCount64() >= deadline
                   ? OperationInterruption::kDeadlineExceeded : OperationInterruption::kNone;
      };
      result = bound ? runtime_->ConnectWithIdentity(*bound, interrupted)
                     : runtime_->Connect(request.body, interrupted);
      break;
    }
    case Command::kDisconnect: result = runtime_->Disconnect(); break;
    case Command::kRevokeSmartAccessLease: result = runtime_->RevokeSmartAccessLease(request.body); break;
    case Command::kRevokeRoutingCatalog: result = runtime_->RevokeRoutingCatalog(request.body); break;
    case Command::kRevokeSmartAccessPolicy: result = runtime_->RevokeSmartAccessPolicy(request.body); break;
    case Command::kRevokeRoutingCatalogService: result = runtime_->RevokeRoutingCatalogService(request.body); break;
    case Command::kRenewSmartAccessLease: result = runtime_->RenewSmartAccessLease(request.body); break;
    case Command::kConfigureSmartAccessRuntimeControl: result = runtime_->ConfigureSmartAccessRuntimeControl(request.body); break;
    case Command::kConfigureSmartAccessRenewal: result = runtime_->ConfigureSmartAccessRuntimeControl(request.body, true); break;
    case Command::kReadSmartAccessRestrictions: result = runtime_->ReadSmartAccessRestrictions(); break;
    case Command::kReadSmartAccessLeases: result = runtime_->ReadSmartAccessLeases(request.body); break;
    case Command::kAcknowledgeSmartAccessRestrictions: result = runtime_->AcknowledgeSmartAccessRestrictions(request.body); break;
    default: result = {Status::kNotReady, "runtime_not_owned"}; break;
  }
  bool cancel_after_commit = false;
  RefreshBoundNetwork(operation);
  {
    std::lock_guard<std::mutex> state(state_lock_);
    // Bound owners survive successful start. Retire other owners under the
    // cancellation-matching lock so late cancellation cannot reach a successor.
    cancel_after_commit = operation && (operation->cancelled || operation->deadline_expired ||
        (bound && !IsConnectDeadlineCurrent(*bound))) && result.status == Status::kOk;
    if (!cancel_after_commit) {
      snapshot_ = runtime_->Snapshot();
      if (operation) {
        const bool recovery = snapshot_.body.rfind("phase=recovery_required;", 0) == 0;
        if (!bound || (result.status != Status::kOk && !recovery)) RetireConnect();
        else if (result.status != Status::kOk) operation->cleanup_attempted = true;
      } else if (request.command == Command::kDisconnect && result.status == Status::kOk) {
        RetireConnect();
      }
    }
  }
  if (cancel_after_commit) {
    result = runtime_->Disconnect();
    if (result.status == Status::kOk) {
      const bool expired = bound && (operation->deadline_expired || !IsConnectDeadlineCurrent(*bound));
      result = WithFailure(std::move(result), expired ? Status::kDeadlineExceeded : Status::kNotReady,
                           expired ? "connect_deadline" : "operation_cancelled");
    }
    std::lock_guard<std::mutex> state(state_lock_);
    snapshot_ = runtime_->Snapshot();
    if (bound && snapshot_.body.rfind("phase=recovery_required;", 0) == 0) {
      operation->cleanup_attempted = true;
    } else {
      RetireConnect();
    }
  }
  watch_changed_.notify_all();
  std::lock_guard<std::mutex> state(state_lock_);
  return ProjectBoundState(std::move(result));
}

}  // namespace pokrov::service
