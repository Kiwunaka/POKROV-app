part of pokrov_app_shell;

typedef TransportRuntimeControlEnrollment = Future<void> Function(TransportRuntimeControl scope);

/// Post-start control IO is owned by one child of the original transport stage.
/// No timeout wrapper can detach a storage/native Future from that child.
class TransportRuntimeControl {
  TransportRuntimeControl._(this._selection, this.acknowledgement, this._permit, this.cancelled);
  final TransportSelection _selection;
  final TransportConnectAcknowledgement acknowledgement;
  final TransportChildPermit _permit;
  final Future<void> cancelled;
  bool _configured = false;
  bool Function()? _authorityCurrent;
  TransportStagedProfile get staged => acknowledgement.staged;
  PokrovRuntimeEngine get engine => staged._engine;
  String get profileDigest => staged.nativeProfileDigest;
  HostPlatform get hostPlatform => _selection.context.hostPlatform;
  DateTime get latestObservedTime => _selection._lastLatest;

  bool get isCurrent {
    try { staged.prepared.routingIntent.requireCurrent(); } on Object { return false; }
    return _selection.stopReason == null && _selection.operationIsCurrent() &&
      _selection._children.containsKey(_permit) &&
      identical(_selection._nativeConnect, acknowledgement._owner) && !acknowledgement._owner.stopRequested &&
      (engine as RuntimeConnectCancellation).activeConnectRequestId == acknowledgement._owner.requestId &&
      (staged._restrictionsCurrent?.call() ?? true) && (_authorityCurrent?.call() ?? true);
  }

  Future<TransportTimeWindow> sample() async {
    final now = await _selection.sample();
    acknowledgement.requireCurrent(_selection, now);
    if (!isCurrent) _transportSelectionFail('runtime_control_superseded');
    return now;
  }

  Duration get remainingBudget {
    if (!isCurrent) _transportSelectionFail('runtime_control_superseded');
    final remaining = _permit.budgetStartedAt.elapsedMilliseconds + _permit.remainingBudget.inMilliseconds -
      _selection._lastElapsedMs;
    if (remaining <= 0) _transportSelectionFail('runtime_control_deadline');
    return Duration(milliseconds: remaining);
  }

  Future<T> wait<T>(Future<T> operation) async {
    final result = await operation;
    await sample();
    return result;
  }

  Future<RuntimeSnapshot> readRunningSnapshot() async {
    final native = await wait(acknowledgement._readSnapshot());
    if (!_selection.context.matchesRuntimeCore(native) || native.phase != RuntimePhase.running ||
        native.transportProofPending != true ||
        native.connectionPending || native.effectiveProfileDigest != profileDigest ||
        native.smartAccessRuntimeControlVersion != 1) {
      _transportSelectionFail('runtime_control_not_running');
    }
    return native;
  }

  Future<void> configure(String configJson) async {
    await sample();
    final bound = engine;
    if (bound is! RuntimeBoundSmartAccessControl) _transportSelectionFail('bound_runtime_control_unsupported');
    final configured = await wait((bound as RuntimeBoundSmartAccessControl).configureBoundSmartAccessRuntimeControl(
      requestId: acknowledgement._owner.requestId!, profileDigest: profileDigest, configJson: configJson));
    if (!configured) _transportSelectionFail('runtime_control_unconfirmed');
    await readRunningSnapshot();
    _configured = true;
  }
}

extension _TransportRuntimeControlExecution on TransportSelection {
  Future<void> enrollRuntimeControl(TransportConnectAcknowledgement acknowledgement,
      TransportRuntimeControlEnrollment? enroll) async {
    final now = await sample();
    acknowledgement.requireCurrent(this, now);
    if (acknowledgement.staged.prepared.catalogPolicy == null ||
        identical(_runtimeControlAcknowledgement, acknowledgement)) return;
    if (_runtimeControlStartedForAttempt == acknowledgement.staged.attemptRef) {
      _transportSelectionFail('runtime_control_already_started');
    }
    final cancelled = Completer<void>();
    final permit = beginChild(acknowledgement.staged.attemptRef, TransportSelectionStage.transport,
      TransportChildResource.preparation, now, () async { if (!cancelled.isCompleted) cancelled.complete(); });
    _runtimeControlStartedForAttempt = acknowledgement.staged.attemptRef;
    final scope = TransportRuntimeControl._(this, acknowledgement, permit, cancelled.future);
    TransportTimeWindow? settledAt;
    try {
      if (enroll == null) _transportSelectionFail('runtime_control_unconfigured');
      await scope.wait(enroll(scope));
      if (!scope._configured) _transportSelectionFail('runtime_control_unconfirmed');
      _runtimeControlAcknowledgement = acknowledgement;
    } on Object {
      _stopAttempt('runtime_control_failed');
      // A lost IPC reply may conceal a native mutation. Exact stop joins the
      // native owner; failed cleanup leaves that owner retained for retry.
      await stopNativeConnect();
      rethrow;
    } finally {
      try { settledAt = await sample(); } on Object { settledAt = null; }
      settleChild(acknowledgement.staged.attemptRef, permit, now: settledAt);
    }
  }
}
