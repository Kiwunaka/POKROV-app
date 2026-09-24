part of pokrov_app_shell;

extension _TransportShellOperations on _PokrovSeedShellState {
  void _stopTransportPolicyRefresh() {
    _transportPolicyTimer?.cancel();
    _transportPolicyTimer = null;
    final cancelled = _transportPolicyCancelled;
    _transportPolicyCancelled = null;
    if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
  }

  void _startTransportPolicyRefresh() {
    _stopTransportPolicyRefresh();
    final service = _bootstrapper;
    if (service is! AppFirstTransportManifestService ||
        !(service as AppFirstTransportManifestService).transportManifestEnabled) return;
    final manifestService = service as AppFirstTransportManifestService;
    final cancelled = Completer<void>();
    _transportPolicyCancelled = cancelled;
    _transportPolicyTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted || cancelled.isCompleted || _runtimeSnapshot?.phase != RuntimePhase.running ||
          !_connectionCoordinator.hasActiveTransportLease) {
        _stopTransportPolicyRefresh();
        return;
      }
      if (_transportPolicyRefreshInFlight || _runtimeBusy) return;
      _transportPolicyRefreshInFlight = true;
      try {
        await manifestService.fetchTransportManifest(hostPlatform: widget.appContext.hostPlatform,
          remainingBudget: const Duration(seconds: 10), cancelled: cancelled.future);
      } on BootstrapFailure catch (error) {
        if (error.statusCode == HttpStatus.unauthorized || error.statusCode == HttpStatus.forbidden) {
          final native = await _connectionCoordinator.withdrawTransportAuthority();
           // ignore: invalid_use_of_protected_member
           if (native != null && mounted) setState(() => _runtimeSnapshot = native);
        }
      } on Object {
        // Offline Core deadlines remain the authority until a signed update is received.
      } finally {
        _transportPolicyRefreshInFlight = false;
      }
    });
  }

  Future<RuntimeSnapshot> _connectWithTransportManifest(RuntimeSnapshot runtime,
      int generation) async {
    final service = _bootstrapper;
    final engine = _runtimeEngine;
    if (service is! AppFirstTransportManifestService ||
        !(service as AppFirstTransportManifestService).transportManifestEnabled ||
        engine is! RuntimeBootClock || engine is! RuntimeConnectCancellation ||
        engine is! RuntimeCoreIdentityStage || engine is! RuntimeCoreIdentityConnect ||
        engine is! RuntimeBoundConnectivityProbe) {
      _transportSelectionFail('transport_runtime_unavailable');
    }
    final manifestService = service as AppFirstTransportManifestService;
    final bootClock = engine as RuntimeBootClock;
    final started = await bootClock.readBootClock();
    const budget = Duration(seconds: 60);
    final cancelled = _connectionCoordinator.whenOperationEnds(generation);
    bool current() => mounted && _connectionCoordinator.ownsOperation(generation) &&
      _connectionCoordinator.actionInFlight;
    TransportManifestSelection? source;
    try {
      source = await manifestService.openTransportSelection(hostPlatform: widget.appContext.hostPlatform,
        operationStarted: started, operationBudget: budget,
        operationIsCurrent: current, cancelled: cancelled);
    } on TransportManifestFailure catch (error) {
      if (error.code != 'transport_floor_missing') rethrow;
      // First enrollment is a fresh authenticated nonce exchange, never a
      // cached policy or an arbitrary response supplied by the caller.
      final enrollmentClock = await bootClock.readBootClock();
      if (enrollmentClock.bootRef != started.bootRef ||
          enrollmentClock.elapsedMilliseconds < started.elapsedMilliseconds ||
          enrollmentClock.elapsedMilliseconds >= started.elapsedMilliseconds + budget.inMilliseconds) {
        _transportSelectionFail('transport_budget_exhausted');
      }
      await manifestService.enrollTransportManifest(hostPlatform: widget.appContext.hostPlatform,
        remainingBudget: Duration(milliseconds: started.elapsedMilliseconds +
          budget.inMilliseconds - enrollmentClock.elapsedMilliseconds), cancelled: cancelled);
      if (!current()) throw const ConnectionOperationSuperseded();
      source = await manifestService.openTransportSelection(hostPlatform: widget.appContext.hostPlatform,
        operationStarted: started, operationBudget: budget,
        operationIsCurrent: current, cancelled: cancelled);
    }
    if (source == null || !current()) {
      source?.close();
      _transportSelectionFail('transport_policy_unavailable');
    }
    if ((source.admission.payload['budget'] as Map)['max_diagnostic_bytes'] == 0) {
      source.close();
      _transportSelectionFail('diagnostic_limit');
    }
    CatalogDomainPolicy? catalogPolicy;
    String? catalogAccessState;
    TransportSmartAccessGrantResolver? smartAccessGrantResolver;
    try {
      final catalogRequired = const {RouteMode.allExceptRu, RouteMode.selectiveServices}
        .contains(_selectedRouteMode);
      final catalogHost = const {HostPlatform.android, HostPlatform.windows}
        .contains(widget.appContext.hostPlatform);
      if (catalogRequired && (!catalogHost || service is! AppFirstRoutingCatalogService ||
          !(service as AppFirstRoutingCatalogService).routingCatalogEnabled)) _transportSelectionFail('routing_catalog_unavailable');
      if (catalogHost && service is AppFirstRoutingCatalogService &&
          (service as AppFirstRoutingCatalogService).routingCatalogEnabled) {
        final catalogService = service as AppFirstRoutingCatalogService;
        final catalogClock = await bootClock.readBootClock();
        if (catalogClock.bootRef != started.bootRef ||
            catalogClock.elapsedMilliseconds < started.elapsedMilliseconds ||
            catalogClock.elapsedMilliseconds >= started.elapsedMilliseconds + budget.inMilliseconds) {
          _transportSelectionFail('transport_budget_exhausted');
        }
        final catalog = await catalogService.fetchRoutingCatalog(
          hostPlatform: widget.appContext.hostPlatform, cancelled: source.whenClosed);
        if (!current()) _transportSelectionFail('routing_catalog_unavailable');
        if (catalog == null && catalogRequired) _transportSelectionFail('routing_catalog_unavailable');
        if (catalog != null) {
          if (service is! AppFirstClientDataService) _transportSelectionFail('routing_access_unavailable');
          final dataService = service as AppFirstClientDataService;
          final accessClock = await bootClock.readBootClock();
          if (accessClock.bootRef != started.bootRef ||
              accessClock.elapsedMilliseconds < catalogClock.elapsedMilliseconds ||
              accessClock.elapsedMilliseconds >= started.elapsedMilliseconds + budget.inMilliseconds) {
            _transportSelectionFail('transport_budget_exhausted');
          }
          final info = await dataService.fetchClientSubscription(
            hostPlatform: widget.appContext.hostPlatform,
            requestTimeout: Duration(milliseconds: started.elapsedMilliseconds +
              budget.inMilliseconds - accessClock.elapsedMilliseconds),
            cancelled: source.whenClosed);
          if (!current() || !const {'trial_premium', 'bonus_premium', 'paid_unlimited',
              'free_monthly', 'free_soft_mode'}.contains(info.accessState)) {
            _transportSelectionFail('routing_access_unavailable');
          }
           // ignore: invalid_use_of_protected_member
           setState(() => _subscriptionInfo = info);
          final accessState = info.accessState;
          catalogAccessState = accessState;
          final observed = await source.sample();
          if (_subscriptionInfo?.accessState != accessState) _transportSelectionFail('routing_access_changed');
          final verified = RoutingCatalogPolicy.fromVerified(catalog.catalog);
          final selectedServices = _selectedRouteMode == RouteMode.selectiveServices
            ? Set<String>.unmodifiable(_clientExperience.routingPreferences.selectedCatalogServiceIds)
            : const <String>{};
          final baseline = compileCatalogDomainPolicy(policy: verified,
            mode: switch (_selectedRouteMode) {
              RouteMode.allExceptRu => CatalogRoutingMode.smartSafe,
              RouteMode.selectedApps => CatalogRoutingMode.includeApps,
              RouteMode.excludedApps => CatalogRoutingMode.excludeApps,
              RouteMode.fullTunnel => CatalogRoutingMode.full,
              RouteMode.selectiveServices => CatalogRoutingMode.selective,
            },
            platform: widget.appContext.hostPlatform.name,
            accessState: accessState, vpnAvailable: true, now: observed.latest,
            selectedServiceIds: selectedServices);
          catalogPolicy = baseline;
            if (_selectedRouteMode == RouteMode.selectiveServices && !catalog.usingCache &&
               runtime.smartAccessLeaseVersion == 1 && service is AppFirstSmartAccessService &&
               (service as AppFirstSmartAccessService).smartAccessEnabled) {
            final wanted = verified.services.where((item) =>
              selectedServices.contains(item.id) &&
              item.intents[CatalogRoutingMode.selective] == CatalogRouteAction.approvedGateway)
              .map((item) => item.id).toSet();
            if (wanted.isNotEmpty) {
              final smartService = service as AppFirstSmartAccessService;
               final grantSource = source;
              var providerUnavailable = false;
              smartAccessGrantResolver = (baseProfile, remainingBudget, operationIsCurrent, grantCancelled) async {
                bool grantCurrent() => current() && operationIsCurrent();
                if (!grantCurrent()) throw const ConnectionOperationSuperseded();
                if (providerUnavailable) return baseline;
                bool authorityUnavailable(BootstrapFailure error) =>
                  error.code == 'smart_access_admission_paused' ||
                  (error.statusCode == null && error.operationalCode == 'API-002') ||
                  const {HttpStatus.requestTimeout, HttpStatus.tooManyRequests, HttpStatus.badGateway,
                    HttpStatus.serviceUnavailable, HttpStatus.gatewayTimeout}.contains(error.statusCode);
                VerifiedSmartAccessProviderPolicy? providers;
                try {
                  providers = await smartService.fetchSmartAccessProviders(
                    hostPlatform: widget.appContext.hostPlatform, operationIsCurrent: grantCurrent,
                    remainingBudget: await remainingBudget(), cancelled: grantCancelled);
                } on BootstrapFailure catch (error) {
                  if (!authorityUnavailable(error)) rethrow;
                  providerUnavailable = true;
                  await remainingBudget();
                }
                if (providers == null) return baseline;
                final now = await grantSource.sample();
                if (!grantCurrent()) throw const ConnectionOperationSuperseded();
                final candidates = await _connectionCoordinator.selectSmartAccessCapabilities(
                  catalog: catalog.catalog, providers: providers, serviceIds: wanted,
                  platform: widget.appContext.hostPlatform.name, now: now.latest,
                  isCurrent: grantCurrent);
                final digest = await smartAccessProfileSha256(baseProfile);
                final grants = <VerifiedSmartAccessLease>[];
                for (final candidate in candidates) {
                  try {
                    grants.add(await smartService.requestSmartAccessLease(
                      hostPlatform: widget.appContext.hostPlatform, catalog: catalog.catalog,
                      providerPolicy: providers, capabilityId: candidate['capability_id']! as String,
                      profileSha256: digest, origin: candidate['origin']! as String,
                      family: candidate['family']! as String, feature: candidate['feature']! as String,
                      operationIsCurrent: grantCurrent, remainingBudget: await remainingBudget(),
                      cancelled: grantCancelled));
                  } on BootstrapFailure catch (error) {
                    if (!authorityUnavailable(error)) rethrow;
                    providerUnavailable = true;
                    await remainingBudget();
                    if (error.code.startsWith('smart_access_')) return baseline;
                    break;
                  }
                }
                await remainingBudget();
                if (grants.isEmpty) return baseline;
                final bound = await SmartAccessProfileLeases.bind(baseProfile: baseProfile, leases: grants);
                final grantedAt = await grantSource.sample();
                if (!grantCurrent()) throw const ConnectionOperationSuperseded();
                return compileCatalogDomainPolicy(policy: verified, mode: CatalogRoutingMode.selective,
                  platform: widget.appContext.hostPlatform.name, accessState: accessState,
                  vpnAvailable: true, now: grantedAt.latest,
                  selectedServiceIds: selectedServices, smartAccessProfile: bound);
              };
            }
          }
        }
      }
    } on Object {
      source.close();
      rethrow;
    }
    final selection = await _connectionCoordinator.beginTransportSelection(source: source,
      engine: engine, families: const {'ipv4', 'ipv6'}, runtime: runtime,
      generation: generation, catalogPolicy: catalogPolicy, catalogAccessState: catalogAccessState,
      smartAccessGrantResolver: smartAccessGrantResolver);
    final admission = source.admission;
    final payload = admission.payload;
    final kills = admission.effectiveKills;
    final storedPath = _lastHealthyTransportPath?.split('|');
    final sticky = storedPath != null && storedPath.length == 6 &&
        storedPath[0] == selection.context.networkContextRef &&
        storedPath[1] == selection.context.mode.name ? storedPath : const <String>[];
    int comparePreferred(String a, String b, String? preferred) {
      if (a == preferred && b != preferred) return -1;
      if (b == preferred && a != preferred) return 1;
      return a.compareTo(b);
    }
    final bindings = selection.context.bindings.values.where((binding) =>
      binding.requiredFeatures.contains(RuntimeTransportFeature.atsLease) &&
      !(kills['capability_refs'] as List).contains(binding.capabilityRef)).toList()
      ..sort((a, b) => comparePreferred(a.capabilityRef, b.capabilityRef,
        sticky.length == 6 ? sticky[2] : null));
    final bootstrapRefs = (payload['bootstrap_set_refs'] as List).cast<String>();
    final probeRefs = (payload['probe_set_refs'] as List).cast<String>();
    final maxEndpoints = (payload['budget'] as Map)['max_endpoints'] as int;
    final maxAttempts = (payload['budget'] as Map)['max_attempts'] as int;
    final attemptedFailureDomains = <String>{};
    String pathKey(String capabilityRef, String profileRef, String endpointRef, String family) =>
      [selection.context.networkContextRef, selection.context.mode.name,
        capabilityRef, profileRef, endpointRef, family].join('|');
    for (final binding in bindings) {
      final profiles = binding.profileRefs.where((ref) =>
        !(kills['profile_refs'] as List).contains(ref)).toList()
        ..sort((a, b) => comparePreferred(a, b, sticky.length == 6 ? sticky[3] : null));
      for (final profileRef in profiles) {
        final families = ['ipv4', 'ipv6']
          ..sort((a, b) => comparePreferred(a, b, sticky.length == 6 ? sticky[5] : null));
        for (final family in families) {
          if (!current()) throw const ConnectionOperationSuperseded();
          if (selection._attempts >= maxAttempts) {
            _transportSelectionFail('transport_candidates_exhausted');
          }
          Future<List<TransportEndpointHint>> fetchRole(String role, int limit) =>
            selection.fetchShortlist(TransportEndpointShortlistQuery({
              'platform': widget.appContext.hostPlatform.name,
              'capability_ref': binding.capabilityRef, 'profile_ref': profileRef,
              'bootstrap_set_ref': bootstrapRefs.first, 'probe_set_ref': probeRefs.first,
              'artifact_sha256': selection.context.artifactSha256,
              'core_capability_revision': binding.coreCapabilityRevision,
              'family': family, 'selection_role': role, 'max_endpoints': limit,
             }), manifestService);
          final primaries = await fetchRole('primary', maxEndpoints);
          final remainingSlots = maxEndpoints - selection._endpoints.length;
          var coldReserve = <TransportEndpointHint>[];
          if (remainingSlots > 0 && (remainingSlots > 1 || primaries.isEmpty)) {
            try {
              coldReserve = await fetchRole('cold_reserve', 1);
            } on BootstrapFailure catch (error) {
              // Only a transiently missing reserve may leave admitted primaries
              // usable. Denial, malformed material and policy errors are not
              // availability evidence and must fail this selection.
              final transient = (error.statusCode == null && error.operationalCode == 'API-002') ||
                const {HttpStatus.requestTimeout, HttpStatus.tooManyRequests,
                  HttpStatus.badGateway, HttpStatus.serviceUnavailable,
                  HttpStatus.gatewayTimeout}.contains(error.statusCode);
              if (!transient || error.code.startsWith('transport_') ||
                  primaries.isEmpty || !current()) rethrow;
              await selection.sample();
            }
          }
          final primaryLimit = coldReserve.isEmpty ? maxEndpoints : remainingSlots - 1;
          final rankedPrimaries = [...primaries];
          final stickyPrimary = rankedPrimaries.indexWhere((hint) => _lastHealthyTransportPath ==
            pathKey(binding.capabilityRef, profileRef, hint.endpointRef, family));
          if (stickyPrimary > 0) rankedPrimaries.insert(0, rankedPrimaries.removeAt(stickyPrimary));
          final remainingHints = <TransportEndpointHint>[
            ...rankedPrimaries.take(primaryLimit), ...coldReserve,
          ];
          while (remainingHints.isNotEmpty) {
            if (selection._attempts >= maxAttempts) {
              _transportSelectionFail('transport_candidates_exhausted');
            }
            final preferred = _lastHealthyTransportPath;
            final stickyIndex = remainingHints.indexWhere((hint) => preferred ==
              pathKey(binding.capabilityRef, profileRef, hint.endpointRef, family));
            final otherDomainIndex = remainingHints.indexWhere((hint) =>
              !attemptedFailureDomains.contains(hint.failureDomainRef));
            final hint = remainingHints.removeAt(stickyIndex >= 0 ? stickyIndex :
              otherDomainIndex >= 0 ? otherDomainIndex : 0);
            if (selection._endpoints.length >= maxEndpoints &&
                !selection._endpoints.contains(hint.endpointRef)) continue;
            if (!current()) throw const ConnectionOperationSuperseded();
            final now = await selection.sample();
            final cooldown = selection._nextAttemptMs - now.sample.elapsedMilliseconds;
            if (cooldown > 0) {
              await Future.any<void>([Future<void>.delayed(Duration(milliseconds: cooldown)),
                source.whenClosed]);
              await selection.sample();
            }
            final random = math.Random.secure();
            final attemptRef = 'attempt_${List.generate(16,
              (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
            final query = TransportProfileQuery({
              'platform': widget.appContext.hostPlatform.name,
              'profile_ref': profileRef, 'endpoint_ref': hint.endpointRef,
              'capability_ref': binding.capabilityRef,
              'bootstrap_set_ref': bootstrapRefs.first, 'probe_set_ref': probeRefs.first,
              'artifact_sha256': selection.context.artifactSha256,
              'core_capability_revision': binding.coreCapabilityRevision,
              'route_policy_ref': selection.context.routePolicyRef,
              'dns_policy_ref': selection.context.dnsPolicyRef,
              'mode': selection.context.mode.name, 'family': family,
            });
            try {
              final acknowledgement = await _connectionCoordinator.resolveAndConnectTransportProfile(
                 attemptRef: attemptRef, query: query, hint: hint, service: manifestService, engine: engine,
                generation: generation, repair: false);
              final proof = await _connectionCoordinator.proveTransportConnection(
                acknowledgement, generation: generation);
              if (proof.allStagesPassed) {
                final native = _connectionCoordinator.snapshot;
                if (native != null && native.phase == RuntimePhase.running &&
                    native.coreEgressValidated == true) {
                  _lastHealthyTransportPath = pathKey(binding.capabilityRef,
                    profileRef, hint.endpointRef, family);
                  return native;
                }
                _transportSelectionFail('transport_protection_unconfirmed');
              }
              attemptedFailureDomains.add(hint.failureDomainRef);
            } on ConnectionOperationSuperseded { rethrow; }
              on Object {
                attemptedFailureDomains.add(hint.failureDomainRef);
                if (selection.stopReason != null || selection.hasOwnedTunnel ||
                    selection.hasPendingChildren) rethrow;
                // The coordinator settled the exact failed attempt; the signed
                // budget decides whether another endpoint can be tried.
              }
          }
        }
      }
    }
    _transportSelectionFail('transport_candidates_exhausted');
  }

  Future<RuntimePayloadProbeExchange> _prepareTransportPayload(TransportSelection selection,
      RuntimeBoundProbeRequest request, bool Function() operationIsCurrent, Future<void> cancelled) {
    final service = _bootstrapper;
    if (service is! AppFirstTransportPayloadService) {
      _transportSelectionFail('payload_preparation_unconfigured');
    }
    return (service as AppFirstTransportPayloadService).prepareTransportPayloadProbe(hostPlatform: selection.context.hostPlatform,
      selection: selection.source, request: request, operationIsCurrent: operationIsCurrent, cancelled: cancelled);
  }

  Future<void> _enrollTransportRuntimeControl(TransportRuntimeControl scope) async {
    final service = _bootstrapper;
    final catalog = scope.staged.prepared.catalogPolicy;
    if (!identical(scope.engine, _runtimeEngine) || catalog == null ||
        service is! AppFirstSmartAccessService ||
        !(service as AppFirstSmartAccessService).smartAccessControlAvailable ||
        service is! AppFirstSmartAccessRuntimeControlService) {
      _transportSelectionFail('runtime_control_unconfigured');
    }
    final controlService = service as AppFirstSmartAccessRuntimeControlService;
    final native = await scope.readRunningSnapshot();
    _connectionCoordinator.updateSnapshot(native);
    final retained = await scope.wait(_smartAccessRuntimeStore.readNativeRestrictions());
    _applyNativeSmartAccessRestrictions(retained);
    await scope.sample();
    final recovered = await scope.wait(_recoverNativeSmartAccessRestrictions(native, forStage: false,
      current: () => scope.isCurrent, waitFor: scope.wait, transportControl: scope));
    final binding = _connectionCoordinator.activeSmartAccessLeases;
    if (binding == null || binding.profileDigest != scope.profileDigest ||
        binding.catalogSha256 != catalog.payloadSha256 ||
        !binding.hasLiveAuthority(scope.latestObservedTime) || [...retained, ...recovered].any((record) =>
          (record.restricted && record.profileDigest == binding.profileDigest) ||
          record.affectsCatalog(binding.catalogSha256))) {
      _transportSelectionFail('runtime_control_restriction_changed');
    }
    scope._authorityCurrent = () => identical(_connectionCoordinator.activeSmartAccessLeases, binding) &&
      binding.hasLiveAuthority(scope.latestObservedTime) &&
      !_connectionCoordinator.receivedCatalogRevocation(binding) &&
      _connectionCoordinator.receivedCatalogServiceRevocations(binding).isEmpty &&
      _connectionCoordinator.receivedSmartAccessRevocations(binding).isEmpty &&
      _connectionCoordinator.pendingSmartAccessPolicyRevocation(binding) == null;
    await scope.sample();
    final control = await scope.wait((service as AppFirstSmartAccessService).fetchSmartAccessControl(
      hostPlatform: scope.hostPlatform, profileDigest: scope.profileDigest,
      operationIsCurrent: () => scope.isCurrent, remainingBudget: scope.remainingBudget, cancelled: scope.cancelled));
    if (control.profileDigest != scope.profileDigest || !scope.latestObservedTime.isBefore(control.expiresAt)) {
      _transportSelectionFail('runtime_control_expired');
    }
    if (control.action != 'none') {
      if (const {'catalog_disabled', 'access_denied'}.contains(control.reason)) {
        _connectionCoordinator.receiveCatalogRevocation(binding, withdrawCatalog: control.reason == 'catalog_disabled');
      }
      _connectionCoordinator.receiveSmartAccessPolicyRevocation(binding, control.action == 'terminate'
        ? SmartAccessLeaseRevocation.terminate : SmartAccessLeaseRevocation.drain);
      // This attempt has no healthy lease to drain. The executor cancels its
      // exact start instead of enabling a worker against withdrawn authority.
      _transportSelectionFail('runtime_control_revoked');
    }
    final config = await scope.wait(controlService.requestSmartAccessRuntimeControl(
      hostPlatform: scope.hostPlatform, profileDigest: scope.profileDigest, catalogSha256: catalog.payloadSha256,
      operationIsCurrent: () => scope.isCurrent, remainingBudget: scope.remainingBudget, cancelled: scope.cancelled));
    if (!scope.latestObservedTime.isBefore(control.expiresAt)) _transportSelectionFail('runtime_control_expired');
    _connectionCoordinator.invalidateSmartAccessStagedReuse(scope.profileDigest);
    await scope.configure(config);
    if (!scope.latestObservedTime.isBefore(control.expiresAt)) _transportSelectionFail('runtime_control_expired');
  }

  Future<String> _persistTransportRestrictions(TransportStagePersistence stage,
      String identityInput, RuntimeSnapshot native) async {
    if (!identical(stage.engine, _runtimeEngine)) _transportSelectionFail('restriction_engine_mismatch');
    final catalog = stage.prepared.catalogPolicy;
    final service = _bootstrapper;
    if (catalog == null || service is! AppFirstSmartAccessService ||
        !(service as AppFirstSmartAccessService).smartAccessControlAvailable) {
      throw const RoutingCatalogFailure('catalog_control_trust_unconfigured');
    }
    if (native.routingCatalogControlVersion != 4) {
      throw const RoutingCatalogFailure('catalog_native_control_unsupported');
    }
    final now = await stage.sample();
    if (_connectionCoordinator.isCatalogRevoked(catalog.payloadSha256, now.latest)) {
      throw const RoutingCatalogFailure('catalog_stage_revoked');
    }
    final identity = await stage.wait(catalogRuntimeIdentity(catalog));
    stage._restrictionsCurrent = () =>
      !_connectionCoordinator.isCatalogRevoked(catalog.payloadSha256, stage.latestObservedTime) &&
      !_connectionCoordinator.isCatalogServiceRevoked(catalog.payloadSha256, identity.services.keys, stage.latestObservedTime);
    if (!stage.isCurrent) {
      throw const RoutingCatalogFailure('catalog_service_stage_revoked');
    }
    await stage.wait(_recoverNativeSmartAccessRestrictions(native, forStage: true,
      current: () => stage.isCurrent, waitFor: stage.wait));
    final grants = List<VerifiedSmartAccessLease>.unmodifiable(
      catalog.smartAccessProfile?.byService.values.expand((group) => group) ?? const <VerifiedSmartAccessLease>[]);
    final grantedAt = await stage.sample();
    if (grants.any((grant) => !grant.admitsNewFlows(grantedAt.earliest) || !grant.admitsNewFlows(grantedAt.latest))) {
      throw const RoutingCatalogFailure('smart_access_stage_expired');
    }
    final digest = await stage.wait(smartAccessProfileSha256(identityInput));
    await stage.wait(_smartAccessRuntimeStore.prepareStage(
      SmartAccessRuntimeLeases(digest, grants.map(SmartAccessLeaseIdentity.fromGrant),
        catalogIssuedAt: catalog.issuedAt, catalogExpiresAt: catalog.expiresAt,
        catalogSha256: catalog.payloadSha256, catalogIdentity: identity),
      activeDigest: native.effectiveProfileDigest, stagedDigest: native.stagedProfileDigest,
      isCurrent: () => stage.isCurrent));
    // This identity is retained only after durable persistence and a fresh owner
    // sample; the stage receipt publishes it only after native acknowledgement.
    stage._catalogIdentity = identity;
    return digest;
  }

  TransportRoutingIntent _captureTransportRoutingIntent(CatalogDomainPolicy? catalogPolicy,
      String? catalogAccessState, TransportSmartAccessGrantResolver? smartAccessGrantResolver) {
    final generation = _connectionCoordinator.operationGeneration;
    final revision = _managedProfileRevision;
    final mode = _selectedRouteMode;
    final preferences = _clientExperience.routingPreferences;
    final apps = List<String>.unmodifiable(_selectedAppIds);
    final access = _freeProfileAccess;
    final platform = widget.appContext.hostPlatform;
    // Reading settings never approves an unconfirmed first-run routing choice.
    if (!_clientExperienceLoaded || !_clientExperience.firstRouteScopeConfirmed ||
        _clientExperience.firstRouteScopeMode != mode || _selectedAppsRouteNeedsSelection ||
        (mode == RouteMode.selectiveServices
          ? !_selectiveServicesAvailable || preferences.selectedCatalogServiceIds.isEmpty
          : !widget.appContext.runtimeProfile.supportedRouteModes.contains(mode))) {
      _transportSelectionFail('routing_intent_unconfirmed');
    }
    final catalogMode = switch (mode) {
      RouteMode.fullTunnel => CatalogRoutingMode.full,
      RouteMode.allExceptRu => CatalogRoutingMode.smartSafe,
      RouteMode.selectedApps => CatalogRoutingMode.includeApps,
      RouteMode.excludedApps => CatalogRoutingMode.excludeApps,
      RouteMode.selectiveServices => CatalogRoutingMode.selective,
    };
    if (catalogPolicy != null && (catalogAccessState == null ||
        catalogPolicy.accessState != catalogAccessState || catalogPolicy.mode != catalogMode ||
        _subscriptionInfo?.accessState != catalogAccessState ||
        (mode == RouteMode.selectiveServices &&
          !setEquals(catalogPolicy.selectedServiceIds, preferences.selectedCatalogServiceIds)))) {
      _transportSelectionFail('routing_catalog_mismatch');
    }
    bool current() => mounted && _connectionCoordinator.ownsOperation(generation) &&
      _connectionCoordinator.actionInFlight && revision == _managedProfileRevision &&
      mode == _selectedRouteMode && platform == widget.appContext.hostPlatform &&
      identical(preferences, _clientExperience.routingPreferences) &&
       listEquals(apps, _selectedAppIds) && identical(access, _freeProfileAccess) &&
       (catalogAccessState == null || _subscriptionInfo?.accessState == catalogAccessState);
    return TransportRoutingIntent.capture(preferences: preferences, selectedApps: apps,
       mode: mode, platform: platform, catalogPolicy: catalogPolicy,
       catalogAccessState: catalogAccessState, configurationIsCurrent: current,
       smartAccessGrantResolver: smartAccessGrantResolver);
  }
}
