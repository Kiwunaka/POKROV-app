part of pokrov_app_shell;

extension _SmartAccessRuntimeOperations on _PokrovSeedShellState {
  void _applyNativeSmartAccessRestrictions(Iterable<NativeSmartAccessRestriction> restrictions) {
    final binding = _connectionCoordinator.activeSmartAccessLeases;
    if (binding == null) return;
    for (final restriction in restrictions) {
      if (restriction.catalogWithdrawn && (restriction.profileDigest == binding.profileDigest ||
          restriction.affectsCatalog(binding.catalogSha256))) {
        _connectionCoordinator.receiveCatalogRevocation(binding, withdrawCatalog: true);
      }
      if (restriction.profileDigest == binding.profileDigest && restriction.policyAction != 'none') {
        _connectionCoordinator.receiveSmartAccessPolicyRevocation(binding, restriction.policyAction == 'terminate'
            ? SmartAccessLeaseRevocation.terminate : SmartAccessLeaseRevocation.drain);
      }
      if (restriction.profileDigest == binding.profileDigest && restriction.scopeActions.isNotEmpty) {
        _connectionCoordinator.receiveSmartAccessRevocations(binding, {
          for (final lease in binding.leases)
            if (restriction.scopeActions.containsKey(lease.lease['runtime_scope_sha256']))
              lease.leaseId: restriction.scopeActions[lease.lease['runtime_scope_sha256']] == 'terminate'
                ? SmartAccessLeaseRevocation.terminate : SmartAccessLeaseRevocation.drain,
        });
      }
      // Unknown crash state blocks reuse/renewal in the store; it is not a
      // signed kill and does not terminate a currently healthy connection.
    }
  }

  Future<List<NativeSmartAccessRestriction>> _recoverNativeSmartAccessRestrictions(RuntimeSnapshot native,
      {required bool forStage, required bool Function() current,
      TransportRuntimeControl? transportControl,
      required Future<T> Function<T>(Future<T> operation) waitFor}) async {
    final engine = _runtimeEngine;
    final generation = _connectionCoordinator.operationGeneration;
    if (engine is! RuntimeSmartAccessBackgroundControl || native.smartAccessRuntimeControlVersion != 1) {
      throw const RoutingCatalogFailure('smart_access_native_recovery_unsupported');
    }
    // One reread covers a concurrent final receipt; continuous change consumes
    // the action budget and requires another user/foreground operation.
    for (var attempt = 0; attempt < 2; attempt++) {
      if (!current()) throw const ConnectionOperationSuperseded();
      final encoded = await waitFor(engine.readSmartAccessRestrictions());
      if (!current()) throw const ConnectionOperationSuperseded();
      final activeDigest = native.phase == RuntimePhase.running ? native.effectiveProfileDigest : null;
      final currentLeaseIds = activeDigest == null ? <String>{} :
        (await waitFor(engine.readSmartAccessLeases(activeDigest))).leaseIds;
      if (!current()) throw const ConnectionOperationSuperseded();
      final retained = await waitFor(_smartAccessRuntimeStore.retainNativeJournal(encoded, isCurrent: current,
        activeProfileDigest: activeDigest, currentLeaseIds: currentLeaseIds));
      if (!current()) throw const ConnectionOperationSuperseded();
      if (!forStage) {
        for (final stored in retained.bindings) {
          if (stored.binding.profileDigest == activeDigest && !_connectionCoordinator.retainNativeSmartAccessLeases(stored,
              generation: generation, currentLeaseIds: currentLeaseIds,
              transportControl: transportControl)) throw const ConnectionOperationSuperseded();
        }
      }
      _applyNativeSmartAccessRestrictions(retained.restrictions);
      // Android can stage while its previous Core is alive. Do not allow a
      // concurrent worker receipt to race cached catalog stage after readback.
      if (forStage && retained.hasLiveWorker) {
        throw const RoutingCatalogFailure('smart_access_recovery_requires_stopped_runtime');
      }
      final acknowledged = await waitFor(engine.acknowledgeSmartAccessRestrictions(retained.snapshotSha256));
      if (!current()) throw const ConnectionOperationSuperseded();
      if (acknowledged) return retained.restrictions;
    }
    throw const RoutingCatalogFailure('smart_access_recovery_changed');
  }

  Future<RuntimeSnapshot> _stageManagedProfileWithLeaseBinding(ManagedProfilePayload payload) async {
    final generation = _connectionCoordinator.operationGeneration;
    final elapsed = Stopwatch()..start();
    bool current() => mounted && _connectionCoordinator.ownsOperation(generation) &&
        elapsed.elapsed < widget.runtimeActionTimeout;
    final grants = _preparedSmartAccessGrants[payload] ?? const <VerifiedSmartAccessLease>[];
    final catalog = _preparedCatalogPolicies[payload];
    if (catalog != null && _connectionCoordinator.isCatalogRevoked(catalog.payloadSha256, DateTime.now().toUtc())) {
      throw const RoutingCatalogFailure('catalog_stage_revoked');
    }
    final identity = catalog == null ? null : await catalogRuntimeIdentity(catalog);
    if (!current()) throw const ConnectionOperationSuperseded();
    if (catalog != null && identity != null && _connectionCoordinator.isCatalogServiceRevoked(
        catalog.payloadSha256, identity.services.keys, DateTime.now().toUtc())) {
      throw const RoutingCatalogFailure('catalog_service_stage_revoked');
    }
    final engine = _runtimeEngine;
    final RuntimeSnapshot staged;
    if (grants.isNotEmpty || catalog != null) {
      if (engine is! RuntimeSmartAccessControl) throw const RoutingCatalogFailure('smart_access_stage_unsupported');
      staged = await engine.stageSmartAccessProfile(payload, operationIsCurrent: current,
        persistRestrictions: (identityInput, native) async {
          await _recoverNativeSmartAccessRestrictions(native, forStage: true, current: current,
            waitFor: <T>(Future<T> operation) => operation.timeout(widget.runtimeActionTimeout - elapsed.elapsed));
          if (!current()) throw const ConnectionOperationSuperseded();
          final digest = await smartAccessProfileSha256(identityInput);
          await _smartAccessRuntimeStore.prepareStage(
            SmartAccessRuntimeLeases(digest, grants.map(SmartAccessLeaseIdentity.fromGrant),
              catalogIssuedAt: catalog?.issuedAt, catalogExpiresAt: catalog?.expiresAt,
              catalogSha256: catalog?.payloadSha256, catalogIdentity: identity),
            activeDigest: native.effectiveProfileDigest, stagedDigest: native.stagedProfileDigest,
            isCurrent: current);
          return digest;
        });
    } else {
      staged = await engine.stageManagedProfile(payload);
    }
    if (current()) {
      _connectionCoordinator.acknowledgeSmartAccessStage(staged,
        grants, generation: generation, catalogIssuedAt: catalog?.issuedAt, catalogExpiresAt: catalog?.expiresAt,
        catalogSha256: catalog?.payloadSha256, catalogIdentity: identity);
    }
    return staged;
  }

  /// Runs on existing foreground/account refresh paths. No remote reachability
  /// or revocation is inferred from a failed request; Core retains lease bounds.
  Future<void> _refreshSmartAccessLeases() async {
    final service = _bootstrapper;
    final engine = _runtimeEngine;
    final snapshot = _runtimeSnapshot;
    final digest = snapshot?.effectiveProfileDigest;
    if (!mounted || _runtimeBusy || _smartAccessRefreshInFlight ||
        engine is! RuntimeSmartAccessControl || snapshot?.phase != RuntimePhase.running ||
        (snapshot?.smartAccessLeaseVersion != 1 && !const {1, 2, 3, 4}.contains(snapshot?.routingCatalogControlVersion)) || digest == null ||
        !const {HostPlatform.android, HostPlatform.windows}.contains(widget.appContext.hostPlatform)) return;
    _smartAccessRefreshInFlight = true;
    final generation = _connectionCoordinator.operationGeneration;
    final elapsed = Stopwatch()..start();
    bool current() => mounted && !_runtimeBusy &&
        _connectionCoordinator.ownsOperation(generation) &&
        _runtimeSnapshot?.phase == RuntimePhase.running && _runtimeSnapshot?.effectiveProfileDigest == digest &&
        elapsed.elapsed < widget.runtimeActionTimeout;
    Duration remaining() {
      if (!current()) throw const ConnectionOperationSuperseded();
      return widget.runtimeActionTimeout - elapsed.elapsed;
    }
    try {
      if (!(_connectionCoordinator.activeSmartAccessLeases?.hasRestrictionMetadata ?? false)) {
        StoredSmartAccessRuntime? stored;
        try {
          final halfBudget = Duration(microseconds: remaining().inMicroseconds ~/ 2);
          final storageWait = halfBudget < const Duration(seconds: 2) ? halfBudget : const Duration(seconds: 2);
          stored = await _smartAccessRuntimeStore.read(digest).timeout(storageWait);
        } on Object {
          // Preserve corrupt/unavailable storage. It cannot prevent checking a
          // fresh signed whole-profile restriction against the native digest.
        }
        if (!current()) return;
        _connectionCoordinator.restoreSmartAccessLeases(
          stored?.binding ?? SmartAccessRuntimeLeases(digest, const []), stored?.decisions ?? const {},
          generation: generation, catalogRevoked: stored?.catalogRevoked ?? false,
          catalogWithdrawn: stored?.catalogWithdrawn ?? false,
          catalogServiceRevocations: stored?.catalogServiceRevocations ?? const {});
      }
      var nativeRecoveryReady = false;
      var nativeAuthorityAllowed = false;
      try {
        final halfBudget = Duration(microseconds: remaining().inMicroseconds ~/ 2);
        final recoveryBudget = halfBudget < const Duration(seconds: 2) ? halfBudget : const Duration(seconds: 2);
        final recoveryElapsed = Stopwatch()..start();
        bool recoveryCurrent() => current() && recoveryElapsed.elapsed < recoveryBudget;
        Duration recoveryRemaining() {
          if (!recoveryCurrent()) throw const ConnectionOperationSuperseded();
          return recoveryBudget - recoveryElapsed.elapsed;
        }
        final retained = await _smartAccessRuntimeStore.readNativeRestrictions().timeout(recoveryRemaining());
        if (!recoveryCurrent()) throw const ConnectionOperationSuperseded();
        _applyNativeSmartAccessRestrictions(retained);
        final recovered = await _recoverNativeSmartAccessRestrictions(snapshot!, forStage: false,
          current: recoveryCurrent, waitFor: <T>(Future<T> operation) => operation.timeout(recoveryRemaining()));
        nativeRecoveryReady = true;
        final recoveredBinding = _connectionCoordinator.activeSmartAccessLeases;
        nativeAuthorityAllowed = recoveredBinding != null && !recovered.any((record) =>
          (record.blocksProfile && record.profileDigest == recoveredBinding.profileDigest) ||
          record.affectsCatalog(recoveredBinding.catalogSha256));
      } on Object {
        // No native ACK or new authority after failed recovery. Independently
        // signed foreground restrictions can still tighten the live runtime.
      }
      final binding = _connectionCoordinator.activeSmartAccessLeases;
      if (binding == null || (binding.hasRestrictionMetadata && !binding.hasLiveAuthority(DateTime.now().toUtc()))) return;
      // Retry persistence too: Core acknowledgement does not prove that a
      // previous secure-store write succeeded. Keep delivery independent of it.
      try {
        await _retainAndDeliverSmartAccessRevocations(engine, binding,
          _connectionCoordinator.receivedSmartAccessRevocations(binding), current, remaining);
      } on Object {
        // A storage failure does not prevent fetching stricter signed control.
      }
      if (!current() || service is! AppFirstSmartAccessService) return;
      DateTime? renewalControlExpiresAt;
      VerifiedRoutingCatalog? renewalCatalog;
      var runtimeWorkerReady = false;
      try {
        final control = await service.fetchSmartAccessControl(
          hostPlatform: widget.appContext.hostPlatform, profileDigest: digest, operationIsCurrent: current,
          remainingBudget: remaining(), cancelled: _connectionCoordinator.whenOperationChanges(generation));
        if (!current() || control.profileDigest != digest ||
            !DateTime.now().toUtc().isBefore(control.expiresAt)) return;
        if (control.action == 'none') renewalControlExpiresAt = control.expiresAt;
        if (control.action != 'none') {
          if (const {'catalog_disabled', 'access_denied'}.contains(control.reason)) {
            _connectionCoordinator.receiveCatalogRevocation(binding,
              withdrawCatalog: control.reason == 'catalog_disabled');
          }
          if (control.reason == 'catalog_disabled' && service is AppFirstRoutingCatalogService) {
            try {
              final halfBudget = Duration(microseconds: remaining().inMicroseconds ~/ 2);
              final storageWait = halfBudget < const Duration(seconds: 2) ? halfBudget : const Duration(seconds: 2);
              await service.discardRoutingCatalog().timeout(storageWait);
            } on Object {
              // The store suspends reuse synchronously and preserves its floors.
              // Disk failure cannot prevent delivery to the current runtime.
            }
          }
          final decision = control.action == 'terminate'
              ? SmartAccessLeaseRevocation.terminate : SmartAccessLeaseRevocation.drain;
          _connectionCoordinator.receiveSmartAccessPolicyRevocation(binding, decision);
          await _retainAndDeliverSmartAccessRevocations(engine, binding,
            {for (final lease in binding.leases)
              if (DateTime.now().toUtc().isBefore(lease.activeFlowsUntil)) lease.leaseId: decision},
            current, remaining);
          if (decision == SmartAccessLeaseRevocation.terminate) return;
        }
      } on Object {
        // Control failure is not a kill or an extension. Independently signed
        // provider replacements may still tighten authority within this budget.
      }
      if (current() && nativeRecoveryReady && renewalControlExpiresAt != null &&
          snapshot?.smartAccessRuntimeControlVersion == 1 && engine is RuntimeSmartAccessBackgroundControl &&
          service is AppFirstSmartAccessRuntimeControlService) {
        try {
          final config = await service.requestSmartAccessRuntimeControl(
            catalogSha256: binding.catalogSha256,
            hostPlatform: widget.appContext.hostPlatform, profileDigest: digest, operationIsCurrent: current,
            remainingBudget: remaining(), cancelled: _connectionCoordinator.whenOperationChanges(generation));
          if (!current()) return;
          _connectionCoordinator.invalidateSmartAccessStagedReuse(digest);
          runtimeWorkerReady = await engine.configureSmartAccessRuntimeControl(
            profileDigest: digest, configJson: config).timeout(remaining());
        } on Object {
          // Uncertain delivery is never positive authority. Native expiry and
          // foreground signed restrictions remain effective without a worker.
        }
      }
      if (current() && binding.catalogIdentity != null && binding.catalogSha256 != null &&
          service is AppFirstRoutingCatalogService && service.routingCatalogEnabled) {
        try {
          final replacement = await service.fetchRoutingCatalog(hostPlatform: widget.appContext.hostPlatform).timeout(remaining());
          if (!current()) return;
          if (replacement != null) {
            final replacementPolicy = RoutingCatalogPolicy.fromVerified(replacement.catalog);
            final revoked = await catalogRuntimeRevocations(binding.catalogIdentity!, binding.catalogSha256!,
              replacementPolicy, DateTime.now().toUtc()).timeout(remaining());
            if (!current() || !DateTime.now().toUtc().isBefore(replacement.catalog.expiresAt)) return;
            renewalCatalog = replacement.catalog;
            _connectionCoordinator.receiveCatalogServiceRevocations(binding, revoked);
            final services = {for (final service in replacementPolicy.services) service.id: service};
            final withdrawnCapabilities = <String, SmartAccessLeaseRevocation>{};
            for (final lease in binding.leases) {
              final service = services[lease.lease['service_id']];
              if (service != null && !service.providerCapabilityRefs.contains(lease.lease['capability_id'])) {
                withdrawnCapabilities[lease.leaseId] = SmartAccessLeaseRevocation.terminate;
              }
            }
            _connectionCoordinator.receiveSmartAccessRevocations(binding, withdrawnCapabilities);
            await _retainAndDeliverSmartAccessRevocations(engine, binding,
              _connectionCoordinator.receivedSmartAccessRevocations(binding), current, remaining);
          }
        } on Object {
          // A failed or invalid replacement does not withdraw the current scope.
          // Retained original catalog/lease deadlines remain effective in Core.
        }
      }
      if (!current() || !service.smartAccessEnabled || binding.leases.isEmpty) return;
      final policy = await service.fetchSmartAccessProviders(
          hostPlatform: widget.appContext.hostPlatform, operationIsCurrent: current,
          remainingBudget: remaining(), cancelled: _connectionCoordinator.whenOperationChanges(generation));
      if (!current()) return;
      // Evaluate the whole response before retaining or issuing a mutation.
      final decisions = <String, SmartAccessLeaseRevocation>{};
      for (final grant in binding.leases) {
        if (!DateTime.now().toUtc().isBefore(grant.activeFlowsUntil)) continue;
        final verified = binding.verifiedGrants.where((value) => value.lease['lease_id'] == grant.leaseId).toList();
        final decision = await smartAccessLeaseRevocation(grant: grant, policy: policy, now: DateTime.now(),
          verifiedGrant: verified.length == 1 ? verified.single : null).timeout(remaining());
        if (!current()) return;
        if (decision != null) decisions[grant.lease['lease_id']! as String] = decision;
      }
      await _retainAndDeliverSmartAccessRevocations(engine, binding, decisions, current, remaining);
      if (current() && nativeAuthorityAllowed && renewalCatalog != null && renewalControlExpiresAt != null &&
          engine is RuntimeSmartAccessRenewalControl && _runtimeSnapshot?.routingCatalogControlVersion == 4) {
        await _renewSmartAccessLeases(engine, service, renewalCatalog, policy,
          renewalControlExpiresAt, generation, current, remaining);
        if (current() && runtimeWorkerReady && engine is RuntimeSmartAccessBackgroundControl &&
            service is AppFirstSmartAccessRuntimeControlService) {
          await _enrollSmartAccessRenewal(engine, service, renewalCatalog, policy,
            renewalControlExpiresAt, generation, current, remaining);
        }
      }
    } on Object {
      // No acknowledgement on timeout, missing lease, invalid policy or host
      // rejection. A later foreground refresh may retry the idempotent revoke.
    } finally {
      _smartAccessRefreshInFlight = false;
    }
  }

  Future<void> _enrollSmartAccessRenewal(RuntimeSmartAccessBackgroundControl engine,
      AppFirstSmartAccessRuntimeControlService service, VerifiedRoutingCatalog catalog,
      VerifiedSmartAccessProviderPolicy providers, DateTime controlExpiresAt, int generation,
      bool Function() current, Duration Function() remaining) async {
    final binding = _connectionCoordinator.activeSmartAccessLeases;
    if (binding == null) return;
    if (_smartAccessRenewalEnrollmentGeneration != generation ||
        _smartAccessRenewalEnrollmentProfile != binding.profileDigest) {
      _smartAccessRenewalEnrollments.clear();
      _smartAccessRenewalEnrollmentGeneration = generation;
      _smartAccessRenewalEnrollmentProfile = binding.profileDigest;
    }
    final now = DateTime.now().toUtc();
    _smartAccessRenewalEnrollments.removeWhere((_, receipt) => !now.isBefore(receipt.expiresAt));
    bool authorityCurrent() {
      final now = DateTime.now().toUtc();
      final active = _connectionCoordinator.activeSmartAccessLeases;
      return current() && active != null && active.profileDigest == binding.profileDigest &&
          now.isBefore(controlExpiresAt) && !now.isBefore(catalog.issuedAt) && now.isBefore(catalog.expiresAt) &&
          !now.isBefore(providers.issuedAt) && now.isBefore(providers.expiresAt) &&
          !_connectionCoordinator.receivedCatalogRevocation(active);
    }
    if (!authorityCurrent()) return;
    final currentIds = (await engine.readSmartAccessLeases(binding.profileDigest).timeout(remaining())).leaseIds;
    if (!authorityCurrent()) return;
    for (final grant in binding.verifiedGrants) {
      final leaseId = grant.lease['lease_id']! as String;
      final scope = grant.runtimeScopeSha256;
      final receipt = _smartAccessRenewalEnrollments[scope];
      if (!currentIds.contains(leaseId) || !grant.admitsNewFlows(DateTime.now().toUtc()) ||
          grant.lease['catalog_sha256'] != catalog.payloadSha256 ||
          (receipt?.leaseId == leaseId && DateTime.now().toUtc().isBefore(receipt!.expiresAt))) continue;
      bool enrollmentCurrent() {
        final active = _connectionCoordinator.activeSmartAccessLeases;
        return authorityCurrent() && active != null && grant.admitsNewFlows(DateTime.now().toUtc()) &&
            active.verifiedGrants.contains(grant) &&
            !_connectionCoordinator.receivedCatalogServiceRevocations(active).contains(grant.lease['service_id']) &&
            !_connectionCoordinator.receivedSmartAccessRevocations(active).containsKey(leaseId);
      }
      if (!enrollmentCurrent()) continue;
      // One mint per foreground refresh. Only public receipt metadata is kept;
      // the capability remains local to this call and the live native worker.
      final config = await service.requestSmartAccessRuntimeRenewal(hostPlatform: widget.appContext.hostPlatform,
        profileDigest: binding.profileDigest, grant: grant, catalog: catalog, operationIsCurrent: enrollmentCurrent,
        remainingBudget: remaining(), cancelled: _connectionCoordinator.whenOperationChanges(generation));
      if (!enrollmentCurrent()) return;
      final expires = DateTime.parse((jsonDecode(config) as Map<String, dynamic>)['expires_at'] as String);
      _connectionCoordinator.invalidateSmartAccessStagedReuse(binding.profileDigest);
      final configured = await engine.configureSmartAccessRenewal(
        profileDigest: binding.profileDigest, configJson: config).timeout(remaining());
      if (configured && enrollmentCurrent() && DateTime.now().toUtc().isBefore(expires)) {
        _smartAccessRenewalEnrollments[scope] = (leaseId: leaseId, expiresAt: expires);
      }
      return;
    }
  }

  Future<void> _renewSmartAccessLeases(RuntimeSmartAccessRenewalControl engine,
      AppFirstSmartAccessService service, VerifiedRoutingCatalog catalog,
      VerifiedSmartAccessProviderPolicy providers, DateTime controlExpiresAt, int generation,
      bool Function() current, Duration Function() remaining) async {
    final initial = _connectionCoordinator.activeSmartAccessLeases;
    if (initial == null || engine is! RuntimeSmartAccessBackgroundControl) return;
    bool authorityCurrent() {
      final now = DateTime.now().toUtc();
      return current() && service.smartAccessEnabled && now.isBefore(controlExpiresAt) &&
          !now.isBefore(catalog.issuedAt) && now.isBefore(catalog.expiresAt) &&
          !now.isBefore(providers.issuedAt) && now.isBefore(providers.expiresAt);
    }
    final currentLeaseIds = (await engine.readSmartAccessLeases(initial.profileDigest).timeout(remaining())).leaseIds;
    if (!authorityCurrent()) return;
    final attemptedServices = <Object?>{};
    for (final previous in initial.leases) {
      if (!authorityCurrent()) return;
      var pending = _connectionCoordinator.pendingSmartAccessRenewal(previous.leaseId);
      if (pending != null && (!pending.next.admitsNewFlows(DateTime.now().toUtc()) ||
          (!currentLeaseIds.contains(pending.previousLeaseId) && !currentLeaseIds.contains(pending.nextLeaseId)))) {
        _connectionCoordinator.discardSmartAccessRenewal(pending, generation: generation);
        pending = null;
      }
      if (!previous.hasRenewalScope || (!currentLeaseIds.contains(previous.leaseId) && pending == null)) continue;
      final binding = _connectionCoordinator.activeSmartAccessLeases;
      if (binding == null || binding.profileDigest != initial.profileDigest ||
          !binding.leases.any((grant) => grant.matches(previous)) ||
          _connectionCoordinator.receivedCatalogRevocation(binding) ||
          _connectionCoordinator.receivedCatalogServiceRevocations(binding).contains(previous.lease['service_id']) ||
          _connectionCoordinator.receivedSmartAccessRevocations(binding).containsKey(previous.lease['lease_id'])) continue;
      final previousId = previous.lease['lease_id']! as String;
      var renewal = pending;
      if (renewal == null && (binding.catalogExpiresAt == null ||
          !previous.newFlowsUntil.isBefore(binding.catalogExpiresAt!))) continue;
      // Use the grant's own admission lifetime, without inventing another TTL.
      // Pending native results retry the exact identity even before this point.
      final midpoint = previous.issuedAt.add(Duration(microseconds:
        previous.newFlowsUntil.difference(previous.issuedAt).inMicroseconds ~/ 2));
      if (renewal == null && DateTime.now().toUtc().isBefore(midpoint)) continue;
      if (!attemptedServices.add(previous.lease['service_id'])) continue;
      try {
        if (renewal == null) {
          final next = await service.requestSmartAccessLease(hostPlatform: widget.appContext.hostPlatform,
            catalog: catalog, providerPolicy: providers, capabilityId: previous.lease['capability_id']! as String,
            profileSha256: previous.lease['profile_sha256']! as String,
            origin: previous.lease['origin']! as String, family: previous.lease['family']! as String,
            feature: previous.lease['feature']! as String, operationIsCurrent: authorityCurrent,
            remainingBudget: remaining(), cancelled: _connectionCoordinator.whenOperationChanges(generation));
          if (!authorityCurrent()) return;
          renewal = _connectionCoordinator.prepareSmartAccessRenewal(binding, previousId, next,
            generation: generation, currentLeaseIds: currentLeaseIds);
        }
        final candidate = renewal;
        bool renewalCurrent() => authorityCurrent() &&
            _connectionCoordinator.smartAccessRenewalIsCurrent(candidate, generation: generation);
        if (!renewalCurrent()) continue;
        final stored = await _smartAccessRuntimeStore.retainRenewal(candidate, isCurrent: renewalCurrent).timeout(remaining());
        if (!renewalCurrent() ||
            !_connectionCoordinator.retainSmartAccessRenewal(candidate, stored, generation: generation)) continue;
        // Both identities are now visible to current-profile revocation delivery.
        // A lost reply leaves the candidate pending; no new grant is substituted.
        final lease = candidate.next.lease;
        final renewed = await engine.renewSmartAccessLease(profileDigest: initial.profileDigest,
          expectedLeaseId: candidate.previousLeaseId, nextLeaseId: candidate.nextLeaseId,
          issuedAt: lease['issued_at']! as String, newFlowsUntil: lease['new_flows_until']! as String,
          activeFlowsUntil: lease['active_flows_until']! as String).timeout(remaining());
        if (renewed && renewalCurrent()) {
          _connectionCoordinator.acknowledgeSmartAccessRenewal(candidate, generation: generation);
        }
      } on Object {
        // No immediate network retry on outage, rate limit, storage failure or
        // uncertain native result. Original native bounds/fallback remain active.
        return;
      }
    }
  }

  Future<void> _retainAndDeliverSmartAccessRevocations(RuntimeSmartAccessControl engine,
      SmartAccessRuntimeLeases binding, Map<String, SmartAccessLeaseRevocation> decisions,
      bool Function() current, Duration Function() remaining) async {
    if (!current()) return;
    _connectionCoordinator.receiveSmartAccessRevocations(binding, decisions);
    try {
      if (binding.hasRestrictionMetadata &&
          (decisions.isNotEmpty || _connectionCoordinator.receivedCatalogRevocation(binding) ||
           _connectionCoordinator.receivedCatalogServiceRevocations(binding).isNotEmpty)) {
        // Keep time for native delivery if secure storage stalls. The queued
        // write may still finish, but a timeout is not a durability claim.
        final persistenceBudget = Duration(microseconds: remaining().inMicroseconds ~/ 2);
        final storageWait = persistenceBudget < const Duration(seconds: 2)
            ? persistenceBudget : const Duration(seconds: 2);
        await _smartAccessRuntimeStore.retainDecisions(binding,
          _connectionCoordinator.receivedSmartAccessRevocations(binding),
          catalogRevoked: _connectionCoordinator.receivedCatalogRevocation(binding),
          catalogWithdrawn: _connectionCoordinator.receivedCatalogWithdrawal(binding),
          catalogServiceRevocations: _connectionCoordinator.receivedCatalogServiceRevocations(binding)).timeout(storageWait);
      }
    } finally {
      // Storage failure cannot prevent tightening the currently running Core.
      await _deliverSmartAccessRevocations(engine, binding, current, remaining);
    }
  }

  Future<void> _deliverSmartAccessRevocations(RuntimeSmartAccessControl engine,
      SmartAccessRuntimeLeases binding, bool Function() current, Duration Function() remaining) async {
    if (_connectionCoordinator.receivedCatalogRevocation(binding)) {
      if (!current()) return;
      if (!_connectionCoordinator.needsCatalogRevocation(binding)) return;
      if (engine is RuntimeCatalogControl && const {1, 2, 3, 4}.contains(_runtimeSnapshot?.routingCatalogControlVersion)) {
        try {
          final revoked = await engine.revokeRoutingCatalog(profileDigest: binding.profileDigest).timeout(remaining());
          if (!current()) return;
          if (revoked) {
            _connectionCoordinator.acknowledgeCatalogRevocation(binding);
            return;
          }
        } on Object {
          // Keep the whole-catalog decision pending; individual leases may still
          // accept their restrictions while this refresh has time remaining.
        }
      }
    }
    final policyDecision = _connectionCoordinator.pendingSmartAccessPolicyRevocation(binding);
    if (policyDecision != null && engine is RuntimeCatalogControl &&
        const {2, 3, 4}.contains(_runtimeSnapshot?.routingCatalogControlVersion)) {
      if (!current()) return;
      try {
        final revoked = await engine.revokeSmartAccessPolicy(profileDigest: binding.profileDigest,
          terminateActive: policyDecision == SmartAccessLeaseRevocation.terminate).timeout(remaining());
        if (!current()) return;
        if (revoked) _connectionCoordinator.acknowledgeSmartAccessPolicyRevocation(binding, policyDecision);
      } on Object {
        // Keep the profile restriction pending. Known exact leases may still
        // receive it through the older command within this same action budget.
      }
    }
    if (engine is RuntimeCatalogControl && const {3, 4}.contains(_runtimeSnapshot?.routingCatalogControlVersion)) {
      for (final serviceId in _connectionCoordinator.pendingCatalogServiceRevocations(binding)) {
        if (!current()) return;
        try {
          final revoked = await engine.revokeRoutingCatalogService(
            profileDigest: binding.profileDigest, serviceId: serviceId).timeout(remaining());
          if (!current()) return;
          if (revoked) _connectionCoordinator.acknowledgeCatalogServiceRevocation(binding, serviceId);
        } on Object {
          // Keep this service pending; independent services can still be withdrawn.
        }
      }
    }
    for (final entry in _connectionCoordinator.pendingSmartAccessRevocations(binding).entries) {
      if (!current()) return;
      if (!binding.leases.any((lease) => lease.leaseId == entry.key &&
          DateTime.now().toUtc().isBefore(lease.activeFlowsUntil))) continue;
      try {
        final revoked = await engine.revokeSmartAccessLease(
          profileDigest: binding.profileDigest, leaseId: entry.key,
          terminateActive: entry.value == SmartAccessLeaseRevocation.terminate).timeout(remaining());
        if (!current()) return;
        if (revoked) {
          _connectionCoordinator.acknowledgeSmartAccessRevocation(binding, entry.key, entry.value);
        }
      } on Object {
        // A rejected lease must not prevent another independent lease from
        // receiving its kill while this refresh still has budget.
      }
    }
  }
}
