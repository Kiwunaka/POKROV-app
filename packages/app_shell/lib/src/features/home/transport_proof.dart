part of pokrov_app_shell;

typedef TransportPayloadProbePreparation = Future<RuntimePayloadProbeExchange> Function(
  TransportSelection selection, RuntimeBoundProbeRequest request,
  bool Function() operationIsCurrent, Future<void> cancelled);

class TransportProbeObservation {
  const TransportProbeObservation._(this.stage, this.outcome, this.receipt);
  final RuntimeBoundProbeStage stage;
  final RuntimeBoundProbeOutcome outcome;
  final RuntimeBoundProbeResult? receipt;
}

/// One bounded proof pass. Even four successful stages are not a reusable lease
/// or host/process leak coverage; promotion needs the separate lease handoff.
class TransportProofBatch {
  TransportProofBatch._(this.acknowledgement, List<TransportProbeObservation> observations)
      : observations = List.unmodifiable(observations);
  final TransportConnectAcknowledgement acknowledgement;
  final List<TransportProbeObservation> observations;
  bool get allStagesPassed => observations.length == RuntimeBoundProbeStage.values.length &&
    observations.every((item) => item.outcome == RuntimeBoundProbeOutcome.pass && item.receipt != null);

  void requireCurrent(TransportSelection selection, TransportTimeWindow now) =>
    acknowledgement.requireCurrent(selection, now);

  @override
  String toString() => 'TransportProofBatch(stages=${observations.length})';
}

extension _TransportProofExecution on TransportSelection {
  Future<TransportProofBatch> proveConnection(TransportConnectAcknowledgement acknowledgement,
      {TransportPayloadProbePreparation? preparePayload}) async {
    final now = await sample();
    acknowledgement.requireCurrent(this, now);
    final staged = acknowledgement.staged;
    if (staged.prepared.catalogPolicy != null &&
        !identical(_runtimeControlAcknowledgement, acknowledgement)) {
      _transportSelectionFail('runtime_control_unconfirmed');
    }
    if (_proofStartedForAttempt == staged.attemptRef) _transportSelectionFail('proof_already_started');
    _proofStartedForAttempt = staged.attemptRef;
    final engine = staged._engine;
    if (engine is! RuntimeBoundConnectivityProbe) {
      return _proofBatch = TransportProofBatch._(acknowledgement, const [TransportProbeObservation._(
        RuntimeBoundProbeStage.transport, RuntimeBoundProbeOutcome.unavailable, null)]);
    }
    final observations = <TransportProbeObservation>[];
    for (final stage in RuntimeBoundProbeStage.values) {
      final before = await sample();
      acknowledgement.requireCurrent(this, before);
      final cancelled = Completer<void>();
      final permit = beginChild(staged.attemptRef, TransportSelectionStage.values.byName(stage.name),
        TransportChildResource.probe, before, () async { if (!cancelled.isCompleted) cancelled.complete(); });
      TransportTimeWindow? settledAt;
      RuntimeBoundProbeResult? receipt;
      RuntimePayloadProbeExchange? payloadExchange;
      var outcome = RuntimeBoundProbeOutcome.unknown;
      var diagnosticBytesReserved = 0;
      bool current() {
        try {
          source.requireCurrent();
          staged.prepared.routingIntent.requireCurrent();
        } on Object { return false; }
        return !cancelled.isCompleted && stopReason == null && operationIsCurrent() &&
          _children.containsKey(permit) && identical(_nativeConnect, acknowledgement._owner) &&
          !acknowledgement._owner.stopRequested &&
          (engine as RuntimeConnectCancellation).activeConnectRequestId == acknowledgement._owner.requestId &&
          (staged._restrictionsCurrent?.call() ?? true);
      }
      try {
        final candidate = _candidate!;
        final random = math.Random.secure();
        final nonce = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
        final request = RuntimeBoundProbeRequest(stage: stage, nonce: nonce,
          budgetStartedAt: permit.budgetStartedAt, budget: permit.remainingBudget,
          binding: {
            'connect_request_id': acknowledgement._owner.requestId,
            'candidate_ref': candidate.candidateRef, 'attempt_ref': staged.attemptRef,
            'generation': generation, 'network_context_ref': context.networkContextRef,
            'artifact_sha256': context.artifactSha256, 'capability_ref': candidate.capabilityRef,
            'profile_ref': candidate.profileRef, 'endpoint_ref': candidate.endpointRef,
            'bootstrap_set_ref': candidate.bootstrapSetRef,
            'core_capability_revision': context.coreCapabilityRevision,
            'profile_revision': candidate.profileRevision, 'template_sha256': staged.templateSha256,
            'stage_sha256': staged.nativeProfileDigest, 'endpoint_lease_ref': candidate.endpointLeaseRef,
            'route_policy_ref': context.routePolicyRef, 'dns_policy_ref': context.dnsPolicyRef,
            'probe_set_ref': candidate.probeSetRef, 'mode': context.mode.name, 'family': candidate.family,
          });
        if (stage == RuntimeBoundProbeStage.payload) {
          if (preparePayload == null) _transportSelectionFail('payload_preparation_unconfigured');
          // Preparation and native work share this child and its original cap.
          // Assign before sampling so even a late preparation result is closed.
          payloadExchange = await preparePayload(this, request, current, cancelled.future);
          final preparedAt = await sample();
          acknowledgement.requireCurrent(this, preparedAt);
          if (!current() || !identical(payloadExchange.request, request)) {
            _transportSelectionFail('payload_preparation_superseded');
          }
        }
        final result = await (engine as RuntimeBoundConnectivityProbe).probeBoundConnection(request,
          payloadExchange: payloadExchange,
          cancelled: payloadExchange == null ? cancelled.future :
            Future.any<void>([cancelled.future, payloadExchange.whenClosed]),
          reserveDiagnosticBytes: (count) async {
            final at = await sample();
            acknowledgement.requireCurrent(this, at);
            if (!current()) _transportSelectionFail('proof_binding_changed');
            reserveDiagnosticBytes(staged.attemptRef, permit, count, at);
            diagnosticBytesReserved += count;
          });
        final native = await acknowledgement._readSnapshot();
        settledAt = await sample();
        acknowledgement.requireCurrent(this, settledAt);
        if (!current() || !identical(result.request, request) ||
            result.observedElapsedMs > settledAt.sample.elapsedMilliseconds ||
            !context.matchesRuntimeCore(native) || native.phase != RuntimePhase.running ||
            native.transportProofPending != true ||
            native.connectionPending || native.effectiveProfileDigest != staged.nativeProfileDigest) {
          _transportSelectionFail('proof_binding_changed');
        }
        if (result.outcome == RuntimeBoundProbeOutcome.pass && diagnosticBytesReserved == 0) {
          _transportSelectionFail('proof_bytes_unaccounted');
        }
        if (stage == RuntimeBoundProbeStage.payload && result.outcome == RuntimeBoundProbeOutcome.pass) {
          final verified = payloadExchange?.receipt;
          if (verified == null || result.verifierRef != verified.verifierRef ||
              result.receiptRef != verified.receiptRef) {
            _transportSelectionFail('payload_receipt_unconfirmed');
          }
        }
        if (stage == RuntimeBoundProbeStage.egress && result.outcome == RuntimeBoundProbeOutcome.pass) {
          // A native receipt can echo verifier refs without proving that the
          // observed exit belongs to this endpoint's authorized egress set.
          _transportSelectionFail('egress_oracle_unconfirmed');
        }
        receipt = result;
        outcome = result.outcome;
      } on Object {
        outcome = cancelled.isCompleted || stopReason != null
          ? RuntimeBoundProbeOutcome.cancelled : RuntimeBoundProbeOutcome.unknown;
      } finally {
        // Closing cancels further exchange use; native completion above must
        // already have joined its IO and all exchange/accounting callbacks.
        payloadExchange?.close();
        try { settledAt = await sample(); } on Object { settledAt = null; }
        settleChild(staged.attemptRef, permit, now: settledAt);
      }
      if (stopReason != null) {
        outcome = RuntimeBoundProbeOutcome.cancelled;
        receipt = null;
      }
      observations.add(TransportProbeObservation._(stage, outcome, receipt));
      if (outcome != RuntimeBoundProbeOutcome.pass) break;
    }
    return _proofBatch = TransportProofBatch._(acknowledgement, observations);
  }
}
