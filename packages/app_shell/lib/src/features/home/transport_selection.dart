part of pokrov_app_shell;

/// Local resolver facts, not a signed grant or connectivity proof. The caller
/// must bind the profile, endpoint lease and access window to verified sources.
class TransportCandidate {
  factory TransportCandidate.fromResolved(AuthenticatedTransportProfile resolved,
      TransportSelection selection, TransportTimeWindow now) {
    resolved.requireCurrent(selection.source, now);
    final profile = resolved.profile;
    final query = profile.query.fields;
    return TransportCandidate(candidateRef: profile.candidateRef,
      capabilityRef: query['capability_ref'] as String, profileRef: query['profile_ref'] as String,
      profileRevision: profile.profileRevision, profileSha256: profile.profileSha256,
      endpointRef: query['endpoint_ref'] as String, endpointLeaseRef: profile.endpointLeaseRef,
      failureDomainRef: profile.failureDomainRef, bootstrapSetRef: query['bootstrap_set_ref'] as String,
      probeSetRef: query['probe_set_ref'] as String, artifactSha256: query['artifact_sha256'] as String,
      coreCapabilityRevision: query['core_capability_revision'] as String,
      routePolicyRef: query['route_policy_ref'] as String, dnsPolicyRef: query['dns_policy_ref'] as String,
      mode: RouteMode.values.firstWhere((mode) => mode.name == query['mode']), family: query['family'] as String,
      authorizedFrom: profile.authorizedFrom, authorizedUntil: profile.authorizedUntil,
      activeFlowsUntil: profile.activeFlowsUntil);
  }

  const TransportCandidate({required this.candidateRef, required this.capabilityRef,
    required this.profileRef, required this.profileRevision, required this.profileSha256,
    required this.endpointRef, required this.endpointLeaseRef, required this.failureDomainRef,
    required this.bootstrapSetRef, required this.probeSetRef, required this.artifactSha256,
    required this.coreCapabilityRevision, required this.routePolicyRef, required this.dnsPolicyRef,
    required this.mode, required this.family, required this.authorizedFrom, required this.authorizedUntil,
    required this.activeFlowsUntil});

  final String candidateRef, capabilityRef, profileRef, profileSha256;
  final int profileRevision;
  final String endpointRef, endpointLeaseRef, failureDomainRef, bootstrapSetRef, probeSetRef;
  final String artifactSha256, coreCapabilityRevision, routePolicyRef, dnsPolicyRef, family;
  final RouteMode mode;
  // Intersection of profile/endpoint-lease/entitlement/provider validity.
  final DateTime authorizedFrom, authorizedUntil, activeFlowsUntil;

  String get tuple => [candidateRef, capabilityRef, profileRef, '$profileRevision', profileSha256,
    endpointRef, endpointLeaseRef, failureDomainRef, bootstrapSetRef, probeSetRef,
    artifactSha256, coreCapabilityRevision, routePolicyRef, dnsPolicyRef, mode.name, family,
    authorizedFrom.toIso8601String(), authorizedUntil.toIso8601String(),
    activeFlowsUntil.toIso8601String()].join('|');

  void _validate() {
    for (final ref in [candidateRef, capabilityRef, profileRef, endpointRef, endpointLeaseRef,
        failureDomainRef, bootstrapSetRef, probeSetRef, coreCapabilityRevision, routePolicyRef, dnsPolicyRef]) {
      _requireTransportRef(ref);
    }
    for (final digest in [profileSha256, artifactSha256]) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) _transportSelectionFail('binding_invalid');
    }
    if (profileRevision < 1 || profileRevision > 9007199254740991 ||
        !const {'ipv4', 'ipv6'}.contains(family) || !authorizedFrom.isUtc || !authorizedUntil.isUtc ||
        !activeFlowsUntil.isUtc || !authorizedFrom.isBefore(authorizedUntil) ||
        activeFlowsUntil.isBefore(authorizedUntil)) _transportSelectionFail('binding_invalid');
  }
}

class TransportSelectionContext {
  factory TransportSelectionContext({required String networkContextRef,
    RuntimeTransportNetworkContext? networkSource,
    required TransportRoutingIntent routingIntent,
    required Set<String> families, required RuntimeSnapshot runtime, required TransportAdmission admission}) {
    routingIntent.requireCurrent();
    if (runtime.transportProofPending == null) _transportSelectionFail('bound_proof_state_unavailable');
    if (routingIntent.platform != runtime.hostPlatform) _transportSelectionFail('context_invalid');
    if (const {HostPlatform.android, HostPlatform.windows, HostPlatform.linux}.contains(runtime.hostPlatform) && (networkSource == null ||
        !RegExp(r'^network_[a-f0-9]{32}$').hasMatch(networkContextRef))) {
      _transportSelectionFail('network_context_unavailable');
    }
    final routePolicyRef = routingIntent.routePolicyRef;
    final dnsPolicyRef = routingIntent.dnsPolicyRef;
    for (final ref in [networkContextRef, routePolicyRef, dnsPolicyRef]) {
      _requireTransportRef(ref);
    }
    final artifactSha256 = runtime.coreModuleSha256;
    if (artifactSha256 == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(artifactSha256)) {
      _transportSelectionFail('core_module_identity_unavailable');
    }
    if (
        families.isEmpty || !const {'ipv4', 'ipv6'}.containsAll(families)) {
      _transportSelectionFail('context_invalid');
    }
    final inventory = runtime.transportCapabilities;
    if (inventory == null ||
        !const {RuntimePhase.initialized, RuntimePhase.configStaged, RuntimePhase.running}.contains(runtime.phase)) {
      _transportSelectionFail('core_inventory_unavailable');
    }
    final matching = admission.capabilityBindings.values.where((binding) =>
        binding.artifacts.contains((runtime.hostPlatform, artifactSha256))).toList();
    if (matching.isEmpty) _transportSelectionFail('core_artifact_not_allowed');
    // Admission guarantees a single revision for each platform/module pair.
    final bindings = <String, TransportCapabilityBinding>{
      for (final binding in matching)
        if (inventory.features.containsAll(binding.requiredFeatures)) binding.capabilityRef: binding,
    };
    if (bindings.isEmpty) _transportSelectionFail('core_features_unavailable');
    return TransportSelectionContext._(networkContextRef: networkContextRef, networkSource: networkSource,
        artifactSha256: artifactSha256,
        coreCapabilityRevision: matching.first.coreCapabilityRevision, routePolicyRef: routePolicyRef,
        dnsPolicyRef: dnsPolicyRef, mode: routingIntent.mode, routingIntent: routingIntent,
        families: families, bindings: bindings,
        manifestSha256: admission.manifest['payload_sha256'] as String,
        coreInventoryJson: inventory.canonicalJson, hostPlatform: runtime.hostPlatform);
  }

  TransportSelectionContext._({required this.networkContextRef, required RuntimeTransportNetworkContext? networkSource,
    required this.artifactSha256,
    required this.coreCapabilityRevision, required this.routePolicyRef, required this.dnsPolicyRef,
    required this.mode, required Set<String> families, required Map<String, TransportCapabilityBinding> bindings,
    required this.manifestSha256, required this.coreInventoryJson, required this.hostPlatform,
    required this.routingIntent})
      : _networkSource = networkSource, families = Set.unmodifiable(families), bindings = Map.unmodifiable(bindings);

  final String networkContextRef, artifactSha256, coreCapabilityRevision, routePolicyRef, dnsPolicyRef;
  final String manifestSha256, coreInventoryJson;
  final HostPlatform hostPlatform;
  final RuntimeTransportNetworkContext? _networkSource;
  final TransportRoutingIntent routingIntent;
  final RouteMode mode;
  final Set<String> families;
  final Map<String, TransportCapabilityBinding> bindings;

  Future<void> requireCurrentNetwork() async {
    final source = _networkSource;
    if (source != null && await source.readTransportNetworkContext() != networkContextRef) {
      _transportSelectionFail('network_context_changed');
    }
  }

  bool matchesRuntimeCore(RuntimeSnapshot? runtime) => runtime != null &&
      runtime.hostPlatform == hostPlatform &&
      runtime.coreModuleSha256 == artifactSha256 &&
      const {RuntimePhase.initialized, RuntimePhase.configStaged, RuntimePhase.running}.contains(runtime.phase) &&
      runtime.transportCapabilities?.canonicalJson == coreInventoryJson;
}

enum TransportSelectionStage { profile, transport, dns, payload, egress }
enum TransportChildResource { preparation, probe, tunnel }
enum TransportAttemptResult { pass, fail, unknown, unavailable, cancelled }

/// A stage acknowledgement is not connectivity proof or a reusable lease.
class TransportStagedProfile {
  const TransportStagedProfile._(this.prepared, this.candidateTuple, this.attemptRef,
    this.nativeProfileDigest, this.snapshot, this._selection, this._engine, this._catalogIdentity,
    this._restrictionsCurrent);
  final PreparedTransportProfile prepared;
  final String candidateTuple, attemptRef, nativeProfileDigest;
  final RuntimeSnapshot snapshot;
  final TransportSelection _selection;
  final PokrovRuntimeEngine _engine;
  final CatalogRuntimeIdentity? _catalogIdentity;
  final bool Function()? _restrictionsCurrent;
  String get templateSha256 => prepared.resolved.profile.profileSha256;

  void requireCurrent(TransportSelection selection, TransportTimeWindow now) {
    if (!identical(selection, _selection) || selection._attemptRef != attemptRef ||
        selection._candidate?.tuple != candidateTuple || selection.stopReason != null) {
      _transportSelectionFail('staged_profile_superseded');
    }
    selection._check(now);
    prepared.requireCurrent(selection.source, now);
    if (_restrictionsCurrent?.call() == false) _transportSelectionFail('staged_restriction_revoked');
  }

  @override
  String toString() => 'TransportStagedProfile(redacted)';
}

typedef TransportRestrictionPersistence = Future<String> Function(
  TransportStagePersistence stage, String identityInput, RuntimeSnapshot native);

/// Restriction IO belongs to the same stage child. Its completion is joined even
/// after cancellation; no timeout may release a still-running journal/store call.
class TransportStagePersistence {
  TransportStagePersistence._(this._selection, this.prepared, this._permit, this.engine);
  final TransportSelection _selection;
  final PreparedTransportProfile prepared;
  final TransportChildPermit _permit;
  final PokrovRuntimeEngine engine;
  CatalogRuntimeIdentity? _catalogIdentity;
  bool Function()? _restrictionsCurrent;
  DateTime get latestObservedTime => _selection._lastLatest;

  bool get isCurrent {
    try { prepared.routingIntent.requireCurrent(); } on Object { return false; }
    return _selection.stopReason == null && _selection.operationIsCurrent() &&
      _selection._children.containsKey(_permit) && (_restrictionsCurrent?.call() ?? true);
  }

  Future<TransportTimeWindow> sample() async {
    final now = await _selection.sample();
    if (!isCurrent) _transportSelectionFail('restriction_stage_superseded');
    prepared.requireCurrent(_selection.source, now);
    return now;
  }

  Future<T> wait<T>(Future<T> operation) async {
    final result = await operation;
    await sample();
    return result;
  }
}

/// Identity of one reserved child. It cannot be reused after settlement.
class TransportChildPermit {
  const TransportChildPermit._(this.remainingBudget, this.budgetStartedAt);
  final Duration remainingBudget;
  // Pair this original sample with remainingBudget; sampling again before a
  // native call would extend the reserved deadline by time spent in between.
  final RuntimeBootClockSnapshot budgetStartedAt;
}

Never _transportSelectionFail(String reason) =>
    throw TransportManifestFailure('transport_selection_$reason');

void _requireTransportRef(String value) {
  if (!RegExp(r'^[a-z][a-z0-9_]{1,23}_[a-f0-9]{16,64}$').hasMatch(value)) {
    _transportSelectionFail('reference_invalid');
  }
}

class _TransportChild {
  _TransportChild(this.resource, this.deadlineMs, this.cancel);
  final TransportChildResource resource;
  final int deadlineMs;
  final Future<void> Function() cancel;
  bool cancellationRequested = false;
  Timer? timer;
}

/// An owned native startup has completed. Android pending admission is joined
/// before publication. This is not connectivity proof or a reusable lease.
class TransportConnectAcknowledgement {
  const TransportConnectAcknowledgement._(this.staged, this.snapshot, this._owner);
  final TransportStagedProfile staged;
  final RuntimeSnapshot snapshot;
  final _TransportNativeConnect _owner;

  Future<RuntimeSnapshot> _readSnapshot() {
    final engine = staged._engine;
    if (staged._selection.context.hostPlatform == HostPlatform.android) {
      if (engine is! RuntimeConnectProgress || _owner.requestId == null) {
        _transportSelectionFail('connect_progress_unsupported');
      }
      return engine.snapshotForConnectRequest(_owner.requestId!);
    }
    return engine.snapshot();
  }

  void requireCurrent(TransportSelection selection, TransportTimeWindow now) {
    staged.requireCurrent(selection, now);
    if (!identical(selection._nativeConnect, _owner) || _owner.stopRequested) {
      _transportSelectionFail('connect_superseded');
    }
  }

  @override
  String toString() => 'TransportConnectAcknowledgement(redacted)';
}

/// Retained independently of the start Future, including uncertain teardown.
class _TransportNativeConnect {
  _TransportNativeConnect(this.selection, this.attemptRef, this.permit, this.settlement);
  final TransportSelection selection;
  final String attemptRef;
  final TransportChildPermit permit;
  final RuntimeConnectSettlement settlement;
  final startSettled = Completer<void>();
  String? requestId;
  bool stopRequested = false;
  bool promoted = false;
  Timer? deadlineTimer;
  Future<bool>? _stopping;

  late int deadlineMs = permit.budgetStartedAt.elapsedMilliseconds + permit.remainingBudget.inMilliseconds;

  Future<bool> stop() {
    stopRequested = true;
    deadlineTimer?.cancel();
    return _stopping ??= _stop().whenComplete(() { _stopping = null; });
  }

  Future<bool> _stop() async {
    try {
      // Before publication, cancellation fences dispatch in the executor.
      // Wait for its snapshot/clock work before claiming non-admission.
      if (requestId == null) await startSettled.future;
      final exactRequest = requestId;
      final confirmed = exactRequest == null ||
          await settlement.cancelAndConfirmConnectStopped(exactRequest);
      await startSettled.future;
      if (!confirmed) return false;
      if (identical(selection._nativeConnect, this)) {
        selection._acknowledgeTunnelStopped(attemptRef);
        selection._nativeConnect = null;
      }
      return true;
    } on Object {
      // A failed receipt remains reachable for explicit retry, even after the
      // selection/operation ended. It never frees a TUN on an idle snapshot.
      return false;
    }
  }
}

/// Accounting owned by ConnectionCoordinator, not another connection state machine.
/// Callers supply a fresh native-backed time window before each admission/use.
/// Cancellation retains child ownership until the executor explicitly settles it.
class TransportSelection {
  TransportSelection._({required this.source, required this.context,
      required this.generation, required this.operationIsCurrent,
      required TransportTimeWindow now})
      : _policy = source.admission.payload['budget'] as Map<String, Object?>,
        _lastElapsedMs = now.sample.elapsedMilliseconds, _lastLatest = now.latest {
    if (context.manifestSha256 != source.admission.manifest['payload_sha256']) {
      _transportSelectionFail('context_policy_mismatch');
    }
    _deadline = source.deadline;
    _check(now);
    unawaited(source.whenClosed.then((_) => cancel('policy_unavailable')));
  }

  final TransportManifestSelection source;
  TransportAdmission get admission => source.admission;
  final TransportSelectionContext context;
  final int generation;
  final bool Function() operationIsCurrent;
  final Map<String, Object?> _policy;
  late final TransportClockDeadline _deadline;
  int _lastElapsedMs;
  DateTime _lastLatest;
  String? _closed, _attemptStop;
  String? _attemptRef;
  String? _tunnelAttemptRef;
  _TransportNativeConnect? _nativeConnect;
  String? _proofStartedForAttempt;
  TransportProofBatch? _proofBatch;
  TransportConnectAcknowledgement? _runtimeControlAcknowledgement;
  String? _runtimeControlStartedForAttempt;
  TransportCandidate? _candidate;
  TransportProfileQuery? _resolvingQuery;
  int _attempts = 0, _repairs = 0, _bytes = 0, _nextAttemptMs = 0;
  final _endpoints = <String>{};
  final _attemptRefs = <String>{};
  final _children = <TransportChildPermit, _TransportChild>{};
  final _stageDeadlines = <TransportSelectionStage, int>{};
  final _negativeUntil = <String, int>{};
  bool get hasPendingChildren => _children.isNotEmpty;
  bool get hasOwnedTunnel => _tunnelAttemptRef != null;
  String? get stopReason => _closed ?? _attemptStop;

  Future<TransportTimeWindow> sample() async {
    try {
      await context.requireCurrentNetwork();
    } on Object {
      cancel('network_context_changed');
      rethrow;
    }
    try {
      final now = await source.sample();
      _check(now);
      return now;
    } on Object {
      cancel('policy_unavailable');
      rethrow;
    }
  }

  Future<List<TransportEndpointHint>> fetchShortlist(TransportEndpointShortlistQuery query,
      AppFirstTransportManifestService service) async {
    await sample();
    final fields = query.fields;
    if (fields['platform'] != context.hostPlatform.name ||
        fields['artifact_sha256'] != context.artifactSha256 ||
        fields['core_capability_revision'] != context.coreCapabilityRevision ||
        !context.families.contains(fields['family']) ||
        !context.bindings.containsKey(fields['capability_ref'])) {
      _transportSelectionFail('shortlist_context_mismatch');
    }
    query.requirePolicy(admission);
    final hints = await service.shortlistTransportEndpoints(hostPlatform: context.hostPlatform,
      selection: source, query: query, budgetStartedAt: source.operationStarted,
      budget: Duration(milliseconds: _deadline.expiresElapsedMs -
        source.operationStarted.elapsedMilliseconds), cancelled: source.whenClosed);
    await sample();
    return hints;
  }

  /// Resolution consumes an attempt and endpoint before its first IO, without
  /// inventing a candidate grant. Resolve/prepare/stage share one profile cap.
  Future<TransportStagedProfile> resolveAndStageProfile({required String attemptRef,
      required TransportProfileQuery query, required TransportEndpointHint hint,
      required AppFirstTransportManifestService service,
      required PokrovRuntimeEngine engine, required bool repair,
      TransportRestrictionPersistence? persistRestrictions}) async {
    if (context._networkSource != null && !identical(context._networkSource, engine)) {
      _transportSelectionFail('network_context_engine_changed');
    }
    final now = await sample();
    _requireQuery(query);
    _reserveAttempt(attemptRef, query.fields['endpoint_ref'] as String, now, repair: repair);
    _resolvingQuery = query;
    final cancelled = Completer<void>();
    final permit = beginChild(attemptRef, TransportSelectionStage.profile, TransportChildResource.preparation,
      now, () async { if (!cancelled.isCompleted) cancelled.complete(); });
    bool current() => operationIsCurrent() && stopReason == null && !cancelled.isCompleted &&
      _attemptRef == attemptRef && _children.containsKey(permit);
    TransportTimeWindow? settledAt;
    late final PreparedTransportProfile prepared;
    Timer? grantDeadline;
    try {
      final resolved = await service.resolveTransportProfile(hostPlatform: context.hostPlatform,
        selection: source, query: query, budgetStartedAt: permit.budgetStartedAt,
        budget: permit.remainingBudget, cancelled: cancelled.future);
      settledAt = await sample();
      if (!current() || query.fields.entries.any((entry) => resolved.profile.query.fields[entry.key] != entry.value)) {
        _transportSelectionFail('resolution_superseded');
      }
      if (hint.endpointRef != query.fields['endpoint_ref'] ||
          hint.failureDomainRef != resolved.profile.failureDomainRef ||
          hint.transportFeature != resolved.profile.transportFeature.wireName) {
        _transportSelectionFail('shortlist_profile_mismatch');
      }
      final candidate = TransportCandidate.fromResolved(resolved, this, settledAt);
      if (!_eligible(candidate, settledAt)) _transportSelectionFail('candidate_ineligible');
      if ((_negativeUntil[candidate.tuple] ?? 0) > _lastElapsedMs) _transportSelectionFail('negative_hint');
      _candidate = candidate;
      _resolvingQuery = null;
      grantDeadline = Timer(candidate.authorizedUntil.difference(settledAt.latest),
        () => _stopAttempt('candidate_expired'));
      final native = await engine.snapshot();
      settledAt = await sample();
      if (!current() || !context.matchesRuntimeCore(native)) _transportSelectionFail('core_identity_changed');
      prepared = await service.prepareTransportProfile(resolved: resolved, routingIntent: context.routingIntent,
        runtime: native, budgetStartedAt: permit.budgetStartedAt, budget: permit.remainingBudget,
        // Preparation's receipt must outlive its child, but never the attempt.
        operationIsCurrent: () => operationIsCurrent() && stopReason == null && _attemptRef == attemptRef,
        cancelled: cancelled.future);
      settledAt = await sample();
      if (!current()) _transportSelectionFail('preparation_superseded');
      prepared.requireCurrent(source, settledAt);
    } on Object {
      _stopAttempt('profile_failed');
      rethrow;
    } finally {
      // Never close the successful capture's cancellation future just because
      // preparation ended: that would revoke the profile before native stage.
      try { settledAt = await sample(); } on Object { settledAt = null; }
      grantDeadline?.cancel();
      settleChild(attemptRef, permit, now: settledAt);
    }
    return stageProfile(attemptRef, prepared, engine, persistRestrictions: persistRestrictions);
  }

  void _requireQuery(TransportProfileQuery query) {
    query.requirePolicy(admission);
    final fields = query.fields;
    if (fields['platform'] != context.hostPlatform.name || fields['artifact_sha256'] != context.artifactSha256 ||
        fields['core_capability_revision'] != context.coreCapabilityRevision ||
        fields['route_policy_ref'] != context.routePolicyRef || fields['dns_policy_ref'] != context.dnsPolicyRef ||
        fields['mode'] != context.mode.name || !context.families.contains(fields['family']) ||
        !context.bindings.containsKey(fields['capability_ref'])) _transportSelectionFail('query_context_mismatch');
  }

  /// Uses the existing runtime owner and restriction-persistence path. No TUN
  /// is acquired here. Keep the child until the native stage actually returns.
  Future<TransportStagedProfile> stageProfile(String attemptRef, PreparedTransportProfile prepared,
      PokrovRuntimeEngine engine, {
      TransportRestrictionPersistence? persistRestrictions,
  }) async {
    if (engine is! RuntimeCoreIdentityStage) _transportSelectionFail('stage_unsupported');
    if (context._networkSource != null && !identical(context._networkSource, engine)) {
      _transportSelectionFail('network_context_engine_changed');
    }
    final now = await sample();
    prepared.requireCurrent(source, now);
    if (!identical(prepared.routingIntent, context.routingIntent)) {
      _transportSelectionFail('routing_intent_mismatch');
    }
    final candidate = TransportCandidate.fromResolved(prepared.resolved, this, now);
    if (_attemptRef != attemptRef || _candidate?.tuple != candidate.tuple) {
      _transportSelectionFail('attempt_mismatch');
    }
    final cancelled = Completer<void>();
    final permit = beginChild(attemptRef, TransportSelectionStage.profile, TransportChildResource.preparation,
      now, () async { if (!cancelled.isCompleted) cancelled.complete(); });
    final persistence = TransportStagePersistence._(this, prepared, permit, engine);
    bool current() => !cancelled.isCompleted && persistence.isCurrent && stopReason == null && operationIsCurrent() &&
      _attemptRef == attemptRef && _candidate?.tuple == candidate.tuple && _children.containsKey(permit);
    String? expectedDigest;
    TransportTimeWindow? settledAt;
    try {
      final staged = await engine.stageWithCoreIdentity(prepared.payload,
        expectedCoreModuleSha256: context.artifactSha256, operationIsCurrent: current,
        persistRestrictions: persistRestrictions == null ? null : (identityInput, native) async {
          await persistence.sample();
          return persistence.wait(persistRestrictions(persistence, identityInput, native));
        },
        bindIdentity: (identityInput, native) async {
          final before = await sample();
          prepared.requireCurrent(source, before);
          if (!current() || !context.matchesRuntimeCore(native)) _transportSelectionFail('stage_superseded');
          final digest = await smartAccessProfileSha256(identityInput);
          final after = await sample();
          prepared.requireCurrent(source, after);
          if (!current()) _transportSelectionFail('stage_superseded');
          expectedDigest = digest;
          return digest;
        });
      settledAt = await sample();
      prepared.requireCurrent(source, settledAt);
      if (!current() || !context.matchesRuntimeCore(staged) || staged.phase != RuntimePhase.configStaged ||
          staged.connectionPending || expectedDigest == null || staged.stagedProfileDigest != expectedDigest) {
        _transportSelectionFail('stage_unconfirmed');
      }
      return TransportStagedProfile._(prepared, candidate.tuple, attemptRef, expectedDigest!, staged,
        this, engine, persistence._catalogIdentity, persistence._restrictionsCurrent);
    } finally {
      if (settledAt == null) {
        try { settledAt = await sample(); } on Object { /* Cancellation may close the clock handle. */ }
      }
      settleChild(attemptRef, permit, now: settledAt);
    }
  }

  Future<TransportConnectAcknowledgement> connectStagedProfile(TransportStagedProfile staged, {
      required void Function(String requestId) onRequestCreated,
      void Function(RuntimeSnapshot snapshot)? onProgress,
  }) async {
    final engine = staged._engine;
    if (engine is! RuntimeCoreIdentityConnect || engine is! RuntimeConnectCancellation ||
        engine is! RuntimeConnectSettlement) _transportSelectionFail('connect_unsupported');
    final now = await sample();
    staged.requireCurrent(this, now);
    late final _TransportNativeConnect owner;
    Timer? progressTimer;
    Completer<void>? progressWake;
    final permit = beginChild(staged.attemptRef, TransportSelectionStage.transport,
      TransportChildResource.tunnel, now, () async {
        progressTimer?.cancel();
        final wake = progressWake;
        if (wake != null && !wake.isCompleted) wake.complete();
        await owner.stop();
      });
    owner = _TransportNativeConnect(this, staged.attemptRef, permit, engine);
    _nativeConnect = owner;
    owner.deadlineTimer = Timer(permit.remainingBudget, () => _stopAttempt('stage_deadline'));
    TransportTimeWindow? settledAt;
    var acknowledged = false;
    void requireOwner() {
      if (!identical(_nativeConnect, owner) || owner.stopRequested || stopReason != null ||
          !operationIsCurrent() || staged._restrictionsCurrent?.call() == false) _transportSelectionFail('connect_superseded');
    }
    void requireSnapshot(RuntimeSnapshot value) {
      requireOwner();
      if (owner.requestId == null || engine.connectRequestForSnapshot(value) != owner.requestId ||
          value.transportProofPending != true ||
          !context.matchesRuntimeCore(value) || value.stagedProfileDigest != staged.nativeProfileDigest ||
          (!value.connectionPending && (value.phase != RuntimePhase.running ||
            value.effectiveProfileDigest != staged.nativeProfileDigest))) {
        _transportSelectionFail('connect_unacknowledged');
      }
    }
    try {
      // The same engine must still own the exact stage. This read stays within
      // the reserved child's original deadline; it does not start a new budget.
      final before = await engine.snapshot();
      final dispatchAt = await sample();
      staged.requireCurrent(this, dispatchAt);
      requireOwner();
      if (!context.matchesRuntimeCore(before) || before.phase != RuntimePhase.configStaged ||
          before.transportProofPending != false ||
          before.connectionPending || before.stagedProfileDigest != staged.nativeProfileDigest) {
        _transportSelectionFail('stage_superseded');
      }
      var result = await engine.connectWithCoreIdentity(
        expectedCoreModuleSha256: context.artifactSha256,
        expectedProfileDigest: staged.nativeProfileDigest,
        expectedNetworkContextRef: context._networkSource == null ? null : context.networkContextRef,
        budgetStartedAt: permit.budgetStartedAt, budget: permit.remainingBudget,
        onRequestCreated: (requestId) {
          owner.requestId = requestId;
          requireOwner();
          onRequestCreated(requestId);
        });
      settledAt = await sample();
      staged.requireCurrent(this, settledAt);
      requireSnapshot(result);
      while (result.connectionPending) {
        if (engine is! RuntimeConnectProgress) _transportSelectionFail('connect_progress_unsupported');
        onProgress?.call(result);
        requireOwner();
        // Match the existing Android connect-deadline observer cadence. This
        // reads local lifecycle state only; it starts no network diagnostic.
        final wake = Completer<void>();
        progressWake = wake;
        progressTimer = Timer(const Duration(milliseconds: 100), wake.complete);
        await wake.future;
        progressTimer?.cancel();
        progressTimer = null;
        progressWake = null;
        final beforeRead = await sample();
        staged.requireCurrent(this, beforeRead);
        requireOwner();
        // Await the actual channel read even after cancellation; the original
        // tunnel child and owner remain retained until this Future settles.
        result = await engine.snapshotForConnectRequest(owner.requestId!);
        settledAt = await sample();
        staged.requireCurrent(this, settledAt);
        requireSnapshot(result);
      }
      acknowledged = true;
      return TransportConnectAcknowledgement._(staged, result, owner);
    } on Object {
      _stopAttempt('connect_failed');
      rethrow;
    } finally {
      progressTimer?.cancel();
      try { settledAt = await sample(); } on Object { settledAt = null; }
      try {
        settleChild(staged.attemptRef, permit, now: settledAt);
        if (acknowledged && stopReason == null && settledAt != null) {
          final candidate = _candidate!;
          owner.deadlineMs = math.min(_deadline.expiresElapsedMs, math.min(
            settledAt.sample.elapsedMilliseconds + candidate.authorizedUntil.difference(settledAt.latest).inMilliseconds,
            settledAt.sample.elapsedMilliseconds + admission.effectiveExpiresAt.difference(settledAt.latest).inMilliseconds));
          owner.deadlineTimer?.cancel();
          owner.deadlineTimer = Timer(Duration(milliseconds:
            owner.deadlineMs - settledAt.sample.elapsedMilliseconds), () => _stopAttempt('deadline'));
        }
      } finally {
        owner.startSettled.complete();
      }
      if (!acknowledged || stopReason != null) await owner.stop();
    }
  }

  /// Available after cancellation/generation change, including a failed stop.
  Future<bool> stopNativeConnect() async {
    _stopAttempt('connect_cancelled');
    final owner = _nativeConnect;
    if (owner == null) return !hasOwnedTunnel;
    return owner.stop();
  }

  Future<RuntimeSnapshot> promoteProof(TransportProofBatch proof) async {
    final before = await sample();
    proof.requireCurrent(this, before);
    if (!proof.allStagesPassed || hasPendingChildren) _transportSelectionFail('proof_incomplete');
    final acknowledgement = proof.acknowledgement;
    final owner = acknowledgement._owner;
    final candidate = _candidate;
    final engine = acknowledgement.staged._engine;
    if (candidate == null || !identical(_nativeConnect, owner) || owner.requestId == null ||
        engine is! RuntimeTransportLeaseHandoff) _transportSelectionFail('lease_handoff_unavailable');
    final native = await engine.promoteBoundTransportLease(
      requestId: owner.requestId!, profileDigest: acknowledgement.staged.nativeProfileDigest,
      endpointLeaseRef: candidate.endpointLeaseRef,
      issuedAt: candidate.authorizedFrom,
      newFlowsUntil: candidate.authorizedUntil, activeFlowsUntil: candidate.activeFlowsUntil);
    final after = await sample();
    proof.requireCurrent(this, after);
    if (!identical(_nativeConnect, owner) || owner.stopRequested ||
        native.phase != RuntimePhase.running || native.transportProofPending != false ||
        native.coreEgressValidated != true ||
        native.connectionPending || native.effectiveProfileDigest != acknowledgement.staged.nativeProfileDigest ||
        !context.matchesRuntimeCore(native) ||
        (engine as RuntimeConnectCancellation).connectRequestForSnapshot(native) != owner.requestId) {
      _transportSelectionFail('lease_handoff_unconfirmed');
    }
    owner.promoted = true;
    return native;
  }

  /// A settled negative proof may stop the exact owner without cancelling the
  /// selection, so the signed budget can admit another candidate afterward.
  Future<bool> stopAfterFailedProof() async {
    if (hasPendingChildren) _transportSelectionFail('attempt_owned');
    final owner = _nativeConnect;
    if (owner == null) return !hasOwnedTunnel;
    return owner.stop();
  }

  void _check(TransportTimeWindow now) {
    if (_closed != null) _transportSelectionFail('closed');
    try { context.routingIntent.requireCurrent(now); } on Object {
      cancel('routing_intent_changed'); _transportSelectionFail('routing_intent_changed');
    }
    try { source.requireCurrent(); } on Object {
      cancel('policy_changed'); _transportSelectionFail('policy_changed');
    }
    if (!operationIsCurrent()) { cancel('context_changed'); _transportSelectionFail('context_changed'); }
    if (!now.earliest.isUtc || !now.latest.isUtc || now.earliest.isAfter(now.latest) ||
        now.sample.elapsedMilliseconds < _lastElapsedMs || now.latest.isBefore(_lastLatest) ||
        now.latest.isBefore(DateTime.parse(admission.nextFloor['last_observed_at'] as String)) ||
        now.earliest.isBefore(DateTime.parse(admission.payload['not_before'] as String)) ||
        (admission.rollback != null && now.earliest.isBefore(DateTime.parse(
          (admission.rollback!['payload'] as Map<String, Object?>)['not_before'] as String)))) {
      cancel('clock_invalid'); _transportSelectionFail('clock_invalid');
    }
    try { _deadline.requireCurrent(now.sample); } on Object {
      cancel('deadline'); _transportSelectionFail('deadline');
    }
    _lastElapsedMs = now.sample.elapsedMilliseconds;
    _lastLatest = now.latest;
    if (!now.latest.isBefore(admission.effectiveExpiresAt)) {
      cancel('policy_expired'); _transportSelectionFail('policy_expired');
    }
    final candidate = _candidate;
    if (candidate != null && !_eligible(candidate, now)) _stopAttempt('candidate_ineligible');
    if (_children.values.any((child) => _lastElapsedMs >= child.deadlineMs) ||
        (_nativeConnect != null && _lastElapsedMs >= _nativeConnect!.deadlineMs)) _stopAttempt('stage_deadline');
  }

  bool _eligible(TransportCandidate candidate, TransportTimeWindow now) {
    candidate._validate();
    final payload = admission.payload;
    final kills = admission.effectiveKills;
    return (payload['profile_refs'] as List).contains(candidate.profileRef) &&
      (payload['capability_refs'] as List).contains(candidate.capabilityRef) &&
      (payload['bootstrap_set_refs'] as List).contains(candidate.bootstrapSetRef) &&
      (payload['probe_set_refs'] as List).contains(candidate.probeSetRef) &&
      !(kills['profile_refs'] as List).contains(candidate.profileRef) &&
      !(kills['endpoint_refs'] as List).contains(candidate.endpointRef) &&
      !(kills['capability_refs'] as List).contains(candidate.capabilityRef) &&
      (context.bindings[candidate.capabilityRef]?.profileRefs.contains(candidate.profileRef) ?? false) &&
      context.families.contains(candidate.family) &&
      candidate.artifactSha256 == context.artifactSha256 &&
      candidate.coreCapabilityRevision == context.coreCapabilityRevision &&
      candidate.routePolicyRef == context.routePolicyRef && candidate.dnsPolicyRef == context.dnsPolicyRef &&
      candidate.mode == context.mode && !now.earliest.isBefore(candidate.authorizedFrom) &&
      now.latest.isBefore(candidate.authorizedUntil);
  }

  /// The healthy tuple must come from the current coordinator's bound proof.
  /// This ranking method neither manufactures proof nor changes protected state.
  List<TransportCandidate> shortlist(List<TransportCandidate> candidates, TransportTimeWindow now,
      {String? healthyTuple}) {
    _check(now);
    if (candidates.length > 1024) _transportSelectionFail('inventory_too_large');
    final refs = <String>{};
    final eligible = <TransportCandidate>[];
    for (final candidate in candidates) {
      if (!refs.add(candidate.candidateRef)) _transportSelectionFail('candidate_conflict');
      if (_eligible(candidate, now) && (_negativeUntil[candidate.tuple] ?? 0) <= _lastElapsedMs) eligible.add(candidate);
    }
    eligible.sort((a, b) {
      if (a.tuple == healthyTuple && b.tuple != healthyTuple) return -1;
      if (b.tuple == healthyTuple && a.tuple != healthyTuple) return 1;
      return a.candidateRef.compareTo(b.candidateRef);
    });
    return List.unmodifiable(eligible);
  }

  void beginAttempt(String attemptRef, TransportCandidate candidate, TransportTimeWindow now, {required bool repair}) {
    _check(now);
    if (!_eligible(candidate, now)) _transportSelectionFail('candidate_ineligible');
    if ((_negativeUntil[candidate.tuple] ?? 0) > _lastElapsedMs) _transportSelectionFail('negative_hint');
    _reserveAttempt(attemptRef, candidate.endpointRef, now, repair: repair);
    _candidate = candidate;
  }

  void _reserveAttempt(String attemptRef, String endpointRef, TransportTimeWindow now, {required bool repair}) {
    _check(now);
    _requireTransportRef(attemptRef);
    if (_attemptRef != null || hasPendingChildren || hasOwnedTunnel) _transportSelectionFail('attempt_owned');
    if (_attemptRefs.contains(attemptRef)) _transportSelectionFail('attempt_replay');
    if (_lastElapsedMs < _nextAttemptMs) _transportSelectionFail('cooldown');
    if (_attempts >= (_policy['max_attempts'] as int)) _transportSelectionFail('attempt_limit');
    if (!_endpoints.contains(endpointRef) && _endpoints.length >= (_policy['max_endpoints'] as int)) {
      _transportSelectionFail('endpoint_limit');
    }
    if (repair && _repairs >= (_policy['max_repairs'] as int)) _transportSelectionFail('repair_limit');
    _attempts++;
    if (repair) _repairs++;
    _endpoints.add(endpointRef);
    _attemptRefs.add(attemptRef);
    _attemptRef = attemptRef;
    _candidate = null;
    _resolvingQuery = null;
    _proofBatch = null;
    _runtimeControlAcknowledgement = null;
    _attemptStop = null;
    _stageDeadlines.clear();
  }

  /// Reserve before starting work; retain this exact permit through settlement.
  TransportChildPermit beginChild(String attemptRef, TransportSelectionStage stage,
      TransportChildResource resource, TransportTimeWindow now, Future<void> Function() cancelChild) {
    _check(now);
    if (_attemptRef != attemptRef) _transportSelectionFail('attempt_mismatch');
    final candidate = _candidate;
    if (candidate == null) {
      final query = _resolvingQuery;
      if (query == null || stage != TransportSelectionStage.profile || resource != TransportChildResource.preparation) {
        _transportSelectionFail('candidate_unresolved');
      }
      _requireQuery(query);
    } else if (!_eligible(candidate, now)) {
      _stopAttempt('candidate_expired'); _transportSelectionFail('candidate_ineligible');
    }
    if (_attemptStop != null) _transportSelectionFail('attempt_stopping');
    if (_children.length >= (_policy['max_concurrency'] as int)) _transportSelectionFail('concurrency_limit');
    if (resource == TransportChildResource.tunnel && hasOwnedTunnel) {
      _transportSelectionFail('tunnel_owned');
    }
    final cap = (_policy['stage_caps_ms'] as Map<String, Object?>)[stage.name] as int;
    final stageDeadline = _stageDeadlines[stage] ?? math.min(_deadline.expiresElapsedMs, _lastElapsedMs + cap);
    var validityMs = _lastElapsedMs + admission.effectiveExpiresAt.difference(now.latest).inMilliseconds;
    if (candidate != null) validityMs = math.min(validityMs,
      _lastElapsedMs + candidate.authorizedUntil.difference(now.latest).inMilliseconds);
    final deadline = math.min(stageDeadline, validityMs);
    if (deadline <= _lastElapsedMs) { _stopAttempt('stage_deadline'); _transportSelectionFail('deadline'); }
    _stageDeadlines[stage] = stageDeadline;
    final child = _TransportChild(resource, deadline, cancelChild);
    if (resource == TransportChildResource.tunnel) _tunnelAttemptRef = attemptRef;
    final remaining = Duration(milliseconds: deadline - _lastElapsedMs);
    // Fresh object identity rejects replay without retaining an unbounded set
    // of completed child IDs during a long stage.
    final permit = TransportChildPermit._(remaining, now.sample);
    _children[permit] = child;
    child.timer = Timer(remaining, () => _stopAttempt('stage_deadline'));
    return permit;
  }

  void reserveDiagnosticBytes(String attemptRef, TransportChildPermit permit, int count, TransportTimeWindow now) {
    _check(now);
    if (_attemptRef != attemptRef || !_children.containsKey(permit)) _transportSelectionFail('child_mismatch');
    if (_attemptStop != null) _transportSelectionFail('attempt_stopping');
    if (count < 1) _transportSelectionFail('diagnostic_count_invalid');
    if (count > (_policy['max_diagnostic_bytes'] as int) - _bytes) {
      cancel('diagnostic_limit'); _transportSelectionFail('diagnostic_limit');
    }
    _bytes += count;
  }

  /// Task settlement is permitted after cancellation, expiry or generation
  /// change. It does not relinquish a TUN that may still be running.
  void settleChild(String attemptRef, TransportChildPermit permit, {required TransportTimeWindow? now}) {
    if (_attemptRef != attemptRef || !_children.containsKey(permit)) _transportSelectionFail('child_mismatch');
    if (_closed == null) {
      if (now == null) {
        cancel('clock_unavailable');
      } else {
        // Observe deadline with the child still owned, even when a sleep-delayed
        // Dart timer has not fired yet. Missing time cannot turn into success.
        try { _check(now); } on TransportManifestFailure {
          if (_closed == null) rethrow;
        }
      }
    }
    _children.remove(permit)!.timer?.cancel();
  }

  /// Only the executor's exact-attempt stopped native readback may call this.
  /// A cancel acknowledgement, timeout or completed start call is insufficient.
  void _acknowledgeTunnelStopped(String attemptRef) {
    if (_tunnelAttemptRef != attemptRef ||
        _children.values.any((child) => child.resource == TransportChildResource.tunnel)) {
      _transportSelectionFail('tunnel_owned');
    }
    _tunnelAttemptRef = null;
  }

  void finishAttempt(String attemptRef, TransportAttemptResult result, TransportTimeWindow now) {
    if (_attemptRef != attemptRef || hasPendingChildren) _transportSelectionFail('attempt_owned');
    if (_closed == null) {
      try { _check(now); } on TransportManifestFailure {
        // A stopped attempt must still settle after a newly observed deadline.
        if (_closed == null) rethrow;
      }
    }
    if (result == TransportAttemptResult.pass && (_closed != null || _attemptStop != null ||
        _candidate == null || !_eligible(_candidate!, now))) {
      _transportSelectionFail('late_result');
    }
    if (result == TransportAttemptResult.pass) {
      final proof = _proofBatch;
      if (proof == null || !proof.allStagesPassed) _transportSelectionFail('proof_incomplete');
      proof.requireCurrent(this, now);
      final owner = _nativeConnect;
      if (owner == null || !owner.promoted || owner.attemptRef != attemptRef ||
          _tunnelAttemptRef != attemptRef) _transportSelectionFail('lease_handoff_unconfirmed');
      owner.deadlineTimer?.cancel();
      _nativeConnect = null;
      _tunnelAttemptRef = null;
    }
    if (result != TransportAttemptResult.pass && hasOwnedTunnel) _transportSelectionFail('tunnel_owned');
    if (_closed == null && _attemptStop == null && result == TransportAttemptResult.fail &&
        _candidate != null && _eligible(_candidate!, now)) {
      _negativeUntil[_candidate!.tuple] = _lastElapsedMs + (_policy['hints_ttl_ms'] as int);
    }
    _nextAttemptMs = _lastElapsedMs + (_policy['cooldown_ms'] as int);
    _attemptRef = null;
    _candidate = null;
    _resolvingQuery = null;
    if (result == TransportAttemptResult.pass) cancel('selection_finished');
    if (result == TransportAttemptResult.cancelled) cancel('user_cancelled');
  }

  void _stopAttempt(String reason) {
    _attemptStop ??= reason;
    final owner = _nativeConnect;
    if (owner != null && !owner.stopRequested) unawaited(owner.stop());
    for (final child in _children.values.toList(growable: false)) {
      if (child.cancellationRequested) continue;
      child.cancellationRequested = true;
      child.timer?.cancel();
      // A failed cancellation is not settlement and never frees an owned slot.
      unawaited(Future<void>.microtask(child.cancel).catchError((Object _) {}));
    }
  }

  void cancel(String reason) {
    _closed ??= reason;
    source.close();
    _stopAttempt(reason);
  }
}
