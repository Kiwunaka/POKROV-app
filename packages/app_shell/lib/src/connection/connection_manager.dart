part of pokrov_app_shell;

/// Owns the native runtime and every connection attempt. UI sends commands and
/// listens to this owner; host calls and recovery never depend on a widget State.
enum ConnectionPhase {
  preparing,
  probing,
  activating,
  connected,
  recovering,
  actionRequired,
  disconnecting,
  disconnected
}

/// Independent native observations; missing route counts remain unknown.
class ConnectionStatus {
  const ConnectionStatus(
      {required this.attemptId,
      required this.phase,
      required this.transport,
      required this.routes,
      required this.dns,
      required this.egress});
  final int attemptId;
  final ConnectionPhase phase;
  final RuntimePhase? transport;
  final ({int? ipv4, int? ipv6, bool profileDirty}) routes;
  final ({RuntimeDiagnosticState state, bool? ready}) dns;
  final ({bool? validated, bool? required, bool? transportProofPending}) egress;
}

class ConnectionManager extends ChangeNotifier {
  ConnectionManager({
    required SeedAppContext appContext,
    required PokrovRuntimeEngine runtimeEngine,
    required ManagedProfileBootstrapper bootstrapper,
    required AccountSessionCoordinator accountSessionCoordinator,
    required FirstSessionCoordinator firstSessionCoordinator,
    required PokrovClientExperienceStore clientExperienceStore,
    required PokrovFileConnectHintStore connectHintStore,
    PokrovClientObservability? observability,
    Duration actionTimeout = const Duration(seconds: 18),
    PokrovWifiProbe? currentWifiProbe,
    PokrovForegroundConnectPolicy? foregroundConnectPolicy,
    PokrovWindowsTunnelAuthorizer? windowsTunnelAuthorizer,
    required Future<bool> Function() authorizeAndroidConnect,
    required Future<bool> Function() refreshSubscription,
    required void Function(String, PokrovSnackTone) onNotice,
  })  : _appContext = appContext,
        _runtimeEngine = runtimeEngine,
        _bootstrapper = bootstrapper,
        _accountSessionCoordinator = accountSessionCoordinator,
        _firstSessionCoordinator = firstSessionCoordinator,
        _clientExperienceStore = clientExperienceStore,
        _connectHintStore = connectHintStore,
        _observability = observability,
        _actionTimeout = actionTimeout,
        _currentWifiProbe = currentWifiProbe,
        _foregroundConnectPolicy = foregroundConnectPolicy ?? setPokrovForegroundConnectPolicy,
        _windowsTunnelAuthorizer = windowsTunnelAuthorizer,
        _authorizeAndroidVpnConnect = authorizeAndroidConnect,
        _refreshSubscriptionInfo = refreshSubscription,
        _onNotice = onNotice {
    _selectedRouteMode = appContext.runtimeProfile.defaultRouteMode;
    _connectionCoordinator = ConnectionCoordinator(
      primaryConnectEnabled: _canPrimaryConnect,
      actionTimeout: actionTimeout,
      captureTransportRoutingIntent: _captureTransportRoutingIntent,
      persistTransportRestrictions: _persistTransportRestrictions,
      enrollTransportRuntimeControl: _enrollTransportRuntimeControl,
      prepareTransportPayload: _prepareTransportPayload,
    );
    _managedProfileLifecycle = ManagedProfileLifecycle(
      invalidateProfile: _runtimeEngine.invalidateManagedProfile,
      invalidateOnHost: () => appContext.hostPlatform == HostPlatform.android,
      timeout: () => actionTimeout,
      onInvalidated: (snapshot) => _update(() => _runtimeSnapshot = snapshot),
    );
    if (appContext.hostPlatform == HostPlatform.windows ||
        appContext.hostPlatform == HostPlatform.linux) {
      _diagnosticsCoordinator
          .startRuntimePolling(_refreshDesktopRuntimeSnapshot);
    }
  }

  final SeedAppContext _appContext;
  final PokrovRuntimeEngine _runtimeEngine;
  ClientLocationsCatalog? _locationsCatalog;
  bool _nodePreferenceBusy = false;
  AppFirstNodePreferenceService? get _nodePreferenceService =>
      _bootstrapper is AppFirstNodePreferenceService
          ? _bootstrapper as AppFirstNodePreferenceService
          : null;
  ClientLocationsCatalog? get locationsCatalog => _locationsCatalog;
  bool get nodePreferenceBusy => _nodePreferenceBusy;
  void updateLocationsCatalog(ClientLocationsCatalog? catalog) {
    _locationsCatalog = catalog;
  }

  void markProfileDirty() {
    _managedProfileDirty = true;
  }

  void selectCatalogServices(Set<String> selection) {
    _update(() {
      _selectedRouteMode = RouteMode.selectiveServices;
      _clientExperience = _clientExperience.copyWith(
          firstRouteScopeConfirmed: true,
          firstRouteScopeMode: RouteMode.selectiveServices,
          routingPreferences: _clientExperience.routingPreferences
              .copyWith(selectedCatalogServiceIds: selection));
      markUserProfileChange();
      _runtimeHeadline =
          'Режим и сервисы сохранены. Применим при следующем подключении.';
    });
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
  }

  Future<WarpRuntimePolicy?> loadWarpPolicy() async {
    if (_warpPolicyBusy) return null;
    if (_managedWarpPolicy.canOfferRuntime) return _managedWarpPolicy;
    _update(() => _warpPolicyBusy = true);
    try {
      await _resolveManagedProfile();
      return _disposed ? null : _managedWarpPolicy;
    } on BootstrapFailure catch (error) {
      if (!_disposed) {
        _update(() => _runtimeHeadline = error.message);
        _notify(error.message, tone: PokrovSnackTone.danger);
      }
      return null;
    } finally {
      if (!_disposed) _update(() => _warpPolicyBusy = false);
    }
  }

  void markUserProfileChange() {
    _managedProfileDirty = true;
    _cachedProfileFallbackGate.markUserChange();
  }

  Future<void> denyAccess() {
    _cachedProfileFallbackGate.markAuthorizationDenied();
    _managedProfileDirty = true;
    _accessDenialPending = true;
    return _enforceKnownAccessDenial();
  }

  void updateExperience(PokrovClientExperienceState value) {
    _clientExperience = value;
    _startAndroidNetworkPolicyObservation();
  }

  void markExperienceLoaded() {
    _clientExperienceLoaded = true;
    _startAndroidNetworkPolicyObservation();
    if (_cacheRefreshTimer == null && _bootstrapper is CachedManagedProfileBootstrapper) {
      unawaited(_refreshManagedProfileCache());
      _cacheRefreshTimer = Timer.periodic(const Duration(hours: 6), (_) => unawaited(_refreshManagedProfileCache()));
    }
  }

  Future<void> _refreshManagedProfileCache({bool alternativesOnly = false}) async {
    final generation = _connectionCoordinator.operationGeneration;
    if (alternativesOnly && _cacheRefreshInFlight) await _cacheRefreshCompletion?.future;
    if (!_connectionCoordinator.ownsOperation(generation)) return;
    if (_disposed || _runtimeBusy || _cacheRefreshInFlight) return;
    final service = _bootstrapper;
    if (service is! CachedManagedProfileBootstrapper) return;
    _cacheRefreshInFlight = true;
    final completion = Completer<void>();
    _cacheRefreshCompletion = completion;
    try {
      await (service as CachedManagedProfileBootstrapper).refreshCachedManagedProfile(
        _managedProfileCacheInputs,
        runtimeFeatures: _runtimeSnapshot?.transportCapabilities?.features ?? const {},
        cancelled: _connectionCoordinator.whenOperationChanges(_connectionCoordinator.operationGeneration),
        selectedCandidateRef: _activeCandidateRef ?? '',
        alternativesOnly: alternativesOnly,
      );
    } on Object {
      // A metadata refresh never interrupts a working connection.
    } finally {
      _cacheRefreshInFlight = false;
      completion.complete();
      if (identical(_cacheRefreshCompletion, completion)) _cacheRefreshCompletion = null;
    }
  }

  void setConnectHintDismissed(bool value) {
    _connectHintDismissed = value;
  }

  void setNotice(String? value) {
    _runtimeHeadline = value;
  }

  void restoreConnectionPreferences(
      PokrovClientExperienceState value, Map<String, DateTime> quarantine) {
    _clientExperience = value;
    _startAndroidNetworkPolicyObservation();
    _selectedAppIds
      ..clear()
      ..addAll(value.selectedAppIds);
    _preferredNodeCode = value.preferredNodeCode;
    _preferredVariantId = value.preferredVariantId;
    if (_preferredNodeCode.isNotEmpty || value.preferredCountryCode.isNotEmpty || value.preferredCandidateRef.isNotEmpty)
      _cachedProfileFallbackGate.markUserChange();
    _automaticNodeQuarantineUntil
      ..clear()
      ..addAll(quarantine);
    final mode = value.firstRouteScopeMode;
    if (value.firstRouteScopeConfirmed &&
        mode != null &&
        (mode == RouteMode.selectiveServices ||
            _appContext.runtimeProfile.supportedRouteModes.contains(mode))) {
      _selectedRouteMode = mode;
    }
  }

  final ManagedProfileBootstrapper _bootstrapper;
  final AccountSessionCoordinator _accountSessionCoordinator;
  final FirstSessionCoordinator _firstSessionCoordinator;
  final PokrovClientExperienceStore _clientExperienceStore;
  final PokrovFileConnectHintStore _connectHintStore;
  final PokrovClientObservability? _observability;
  final Duration _actionTimeout;
  final PokrovWifiProbe? _currentWifiProbe;
  final PokrovForegroundConnectPolicy _foregroundConnectPolicy;
  RuntimeCandidateNetwork? _candidatePhysicalNetwork;
  RuntimeCandidateNetwork? _activePhysicalNetwork;
  RuntimeCandidateNetwork? _lastAndroidNetwork;
  String? _blockedAutomaticNetworkKey;
  bool _automaticStopNeedsNetworkKey = false;
  String? _lastAutomaticWifiContext;
  bool _androidNetworkObservationInFlight = false;
  bool _foregroundAutoConnect = false;
  final PokrovWindowsTunnelAuthorizer? _windowsTunnelAuthorizer;
  final Future<bool> Function() _authorizeAndroidVpnConnect;
  final Future<bool> Function() _refreshSubscriptionInfo;
  final void Function(String, PokrovSnackTone) _onNotice;
  late final ConnectionCoordinator _connectionCoordinator;
  late final ManagedProfileLifecycle _managedProfileLifecycle;
  final _diagnosticsCoordinator = DiagnosticsCoordinator();
  final _cachedProfileFallbackGate = CachedProfileFallbackGate();
  bool _disposed = false;
  int _commandNumber = 0;
  Future<void>? _commandTail;
  Future<void>? _cancellation;
  final Set<Future<Object?>> _runtimeActionsInFlight = {};
  ConnectionPhase? _activePhase;

  static const _automaticNodeQuarantineTtl = Duration(minutes: 15);
  static const _maxAutomaticNodeQuarantineEntries = 8;
  static const _maxAutomaticFailoverAttempts = 2;
  Timer? _transportPolicyTimer;
  Completer<void>? _transportPolicyCancelled;
  bool _transportPolicyRefreshInFlight = false;
  String? _lastHealthyTransportPath;
  final _protectionRuntimeSnapshot = ValueNotifier<RuntimeSnapshot?>(null);
  final _preparedSmartAccessGrants = Expando<List<VerifiedSmartAccessLease>>();
  final _preparedCatalogPolicies = Expando<CatalogDomainPolicy>();
  bool _smartAccessRefreshInFlight = false;
  int? _smartAccessRenewalEnrollmentGeneration;
  String? _smartAccessRenewalEnrollmentProfile;
  final _smartAccessRenewalEnrollments =
      <String, ({String leaseId, DateTime expiresAt})>{};
  late final _smartAccessRuntimeStore =
      SmartAccessRuntimeStore(platform: _appContext.hostPlatform.name);

  AppFirstWarpActionService? get _warpActionService =>
      _bootstrapper is AppFirstWarpActionService
          ? _bootstrapper as AppFirstWarpActionService
          : null;
  AppFirstExperienceService? get _experienceService =>
      _bootstrapper is AppFirstExperienceService
          ? _bootstrapper as AppFirstExperienceService
          : null;
  AppFirstFirstSessionEventService? get _firstSessionEventService =>
      _bootstrapper is AppFirstFirstSessionEventService
          ? _bootstrapper as AppFirstFirstSessionEventService
          : null;
  FreeProfileAccess? get _freeProfileAccess =>
      _accountSessionCoordinator.freeProfileAccess;
  set _freeProfileAccess(FreeProfileAccess? value) =>
      _accountSessionCoordinator.updateFreeProfileAccess(value);
  ClientSubscriptionInfo? get _subscriptionInfo =>
      _accountSessionCoordinator.subscriptionInfo;
  set _subscriptionInfo(ClientSubscriptionInfo? value) =>
      _accountSessionCoordinator.updateSubscriptionInfo(value);
  _FirstLaunchStep get _firstLaunchStep =>
      _firstSessionCoordinator._stepForView;
  bool get _managedProfileDirty => _managedProfileLifecycle.dirty;
  set _managedProfileDirty(bool value) =>
      _managedProfileLifecycle.dirty = value;
  int get _managedProfileRevision => _managedProfileLifecycle.revision;
  RuntimeSnapshot? get _runtimeSnapshot => _connectionCoordinator.snapshot;
  set _runtimeSnapshot(RuntimeSnapshot? value) {
    if (value?.lastFailureKind == 'protected_handoff_failed' ||
        (value?.lastFailureKind == 'connect_cancelled' && value?.phase == RuntimePhase.running)) {
      _protectedHandoffActive = true;
      _activePhase = ConnectionPhase.actionRequired;
    }
    _connectionCoordinator.updateSnapshot(value);
    _protectionRuntimeSnapshot.value = value;
  }

  bool get _runtimeBusy => _connectionCoordinator.actionInFlight;
  set _runtimeBusy(bool value) =>
      _connectionCoordinator.updateActionInFlight(value);
  ConnectionTransitionIntent get _runtimeIntent =>
      _connectionCoordinator.intent;
  set _runtimeIntent(ConnectionTransitionIntent value) =>
      _connectionCoordinator.updateIntent(value);
  set _connectionAttemptStartedAt(DateTime? value) =>
      _connectionCoordinator.updateAttemptStartedAt(value);
  int get _connectionAttemptNumber => _connectionCoordinator.attemptNumber;

  RuntimeSnapshot? get snapshot => _runtimeSnapshot;
  ConnectionExperienceState get experience => _connectionExperience;
  ConnectionPresentation get presentation => _connectionPresentation;
  int get attemptId => _commandNumber;
  bool get busy => _runtimeBusy;
  bool get retainsProtection =>
      _protectedHandoffActive || _runtimeSnapshot?.protectionRetained == true;
  TransportCandidateCatalog? get transportCatalog => _transportCatalog;
  domain.TransportCandidate? get materialCandidate {
    final catalog = _transportCatalog;
    if (catalog == null) return null;
    final ref = _activeCandidateRef ?? _candidateRef ?? catalog.selectedCandidateRef;
    return catalog.candidates
        .where((candidate) => candidate.candidateRef == ref).firstOrNull;
  }
  TransportCandidateCatalog? _transportCatalog;
  final _candidateSelector = SmartConnectCandidateSelector();
  String? _candidateNetworkKey;
  String? _candidateOfflineNetworkKey;
  String? _candidateNetworkClass;
  String? _candidateCarrierMccMnc;
  String? _candidateCarrierName;
  String? _candidateAccessNetworkAsn;
  String? _candidateRef;
  String? _activeCandidateRef;
  final List<Map<String, Object?>> _candidateProbeReports = [];
  bool _candidateProbeReportInFlight = false;
  bool _candidateRecoveryPending = false;
  bool _protectedHandoffActive = false;
  ManagedProfileOfflineState? _offlineState;
  ManagedProfileOfflineState? get offlineState => _offlineState;
  Timer? _cacheRefreshTimer;
  bool _cacheRefreshInFlight = false;
  Completer<void>? _cacheRefreshCompletion;
  String? get headline => _runtimeHeadline;
  bool get canCancel => _connectionCoordinator.canCancelPrimaryConnect;
  ConnectionStatus get status {
    final runtime = snapshot;
    final phase = _activePhase ??
        switch (experience.phase) {
          ConnectionExperiencePhase.idle => ConnectionPhase.disconnected,
          ConnectionExperiencePhase.disconnecting =>
            ConnectionPhase.disconnecting,
          ConnectionExperiencePhase.permissionRequired ||
          ConnectionExperiencePhase.blocked ||
          ConnectionExperiencePhase.failed =>
            ConnectionPhase.actionRequired,
          ConnectionExperiencePhase.preparing => ConnectionPhase.preparing,
          ConnectionExperiencePhase.connecting ||
          ConnectionExperiencePhase.connectedUnverified =>
            ConnectionPhase.activating,
          ConnectionExperiencePhase.connectedVerified =>
            ConnectionPhase.connected,
          ConnectionExperiencePhase.reconnecting => ConnectionPhase.recovering,
        };
    return ConnectionStatus(
        attemptId: attemptId,
        phase: phase,
        transport: runtime?.phase,
        routes: (
          ipv4: runtime?.ipv4RouteCount,
          ipv6: runtime?.ipv6RouteCount,
          profileDirty: _managedProfileDirty
        ),
        dns: (
          state: runtime?.dnsState ?? RuntimeDiagnosticState.unknown,
          ready: runtime?.dnsReady
        ),
        egress: (
          validated: runtime?.coreEgressValidated,
          required: runtime?.coreEgressValidationRequired,
          transportProofPending: runtime?.transportProofPending
        ));
  }

  Future<void> toggle({bool reconnectAfterDisconnect = false}) {
    if (_runtimeBusy && _connectionCoordinator.canCancelPrimaryConnect)
      return cancel();
    if (!_runtimeBusy && retainsProtection && !reconnectAfterDisconnect)
      return disconnect();
    if (_runtimeSnapshot?.phase == RuntimePhase.running && !reconnectAfterDisconnect) {
      _suppressAutomaticAndroidNetwork();
    } else {
      _clearAutomaticAndroidStop();
    }
    return _replaceCommand(() =>
        _toggleRuntime(reconnectAfterDisconnect: reconnectAfterDisconnect));
  }

  Future<void> connect() {
    _clearAutomaticAndroidStop();
    return _replaceCommand(() => retainsProtection
        ? _recoverCandidateConnection(_runtimeSnapshot, _activeCandidateRef ?? _candidateRef ?? '')
        : _toggleRuntime(reconnectAfterDisconnect: _runtimeSnapshot?.phase == RuntimePhase.running));
  }
  Future<void> disconnect() {
    _suppressAutomaticAndroidNetwork();
    return _replaceCommand(() async {
        if (retainsProtection) { await _disconnectProtectedHandoff(); return; }
        if (_runtimeSnapshot?.phase == RuntimePhase.running ||
            _runtimeSnapshot?.connectionPending == true) {
          await _toggleRuntime();
        }
      });
  }
  Future<void> reconnect() {
    _clearAutomaticAndroidStop();
    return _replaceCommand(() => retainsProtection
        ? _recoverCandidateConnection(_runtimeSnapshot, _activeCandidateRef ?? _candidateRef ?? '')
        : _toggleRuntime(reconnectAfterDisconnect: true));
  }
  Future<void> cancel() {
    _suppressAutomaticAndroidNetwork();
    return _replaceCommand(() async {});
  }
  Future<void> repair(
          {ValueChanged<_ProtectionRepairStep>? onStep,
          ValueChanged<Future<void> Function()?>? onCancelAvailable}) =>
      _replaceCommand(() =>
          _repairRuntime(onStep: onStep, onCancelAvailable: onCancelAvailable));

  Future<void> _disconnectProtectedHandoff() async {
    _connectionCoordinator.beginAction(ConnectionTransitionIntent.disconnect);
    final generation = _connectionCoordinator.operationGeneration;
    _update(() => _activePhase = ConnectionPhase.disconnecting);
    try {
      var stopped = await _withRuntimeActionTimeout('disconnect', _runtimeEngine.disconnect, ownerGeneration: generation);
      stopped = await _settleRuntimeDisconnectTransition(stopped, ownerGeneration: generation);
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return;
      _runtimeSnapshot = stopped;
      if (!_runtimeStopConfirmed(stopped)) throw StateError('protected_stop_unconfirmed');
      _protectedHandoffActive = false;
      _activeCandidateRef = null;
      _activePhase = null;
      _runtimeHeadline = null;
    } on Object {
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return;
      _activePhase = ConnectionPhase.actionRequired;
      _runtimeHeadline = 'Отключение не подтверждено. Повторите попытку.';
    } finally {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _connectionCoordinator.finishAction();
        _publish();
      }
    }
  }

  Future<void> _replaceCommand(Future<void> Function() action,
      {bool automatic = false}) {
    final number = ++_commandNumber;
    if (!automatic) _cancelAutomaticFailover();
    final previous = _commandTail;
    // Cleanup belongs to the old native invocation. Later commands may replace
    // the queued command, but cannot cancel or skip its confirmed stop.
    final cancellation = _cancellation ??
        (_runtimeBusy || _runtimeActionsInFlight.isNotEmpty
            ? (_cancellation = _supersedeCurrentAction()
                .whenComplete(() => _cancellation = null))
            : null);
    _publish();
    final next = () async {
      if (cancellation != null) await cancellation;
      if (previous != null) await previous;
      if (_disposed || number != _commandNumber) return;
      await action();
    }();
    // A failed repair is returned to its caller; later commands remain usable.
    late final Future<void> tail;
    tail = next.catchError((Object _) {}).whenComplete(() {
      if (identical(_commandTail, tail)) _commandTail = null;
    });
    _commandTail = tail;
    return next;
  }

  Future<void> _supersedeCurrentAction() async {
    if (_connectionCoordinator.canCancelPrimaryConnect &&
        _primaryConnectCompletion != null) {
      return _cancelPrimaryConnect();
    }
    final establishingConnection = _warpFallbackInFlight ||
        _runtimeActionsInFlight.isNotEmpty ||
        const {
          ConnectionTransitionIntent.connect,
          ConnectionTransitionIntent.reconnect,
          ConnectionTransitionIntent.recover
        }.contains(_runtimeIntent);
    _cancelPostConnectHostHealthPolling();
    _stopTransportPolicyRefresh();
    _connectionCoordinator.beginAction(ConnectionTransitionIntent.disconnect);
    final generation = _connectionCoordinator.operationGeneration;
    _publish();
    try {
      await _joinRuntimeActions();
      if (_disposed || !_connectionCoordinator.ownsOperation(generation))
        return;
      var current = await _withRuntimeActionTimeout(
          'supersededSnapshot', _runtimeEngine.snapshot,
          ownerGeneration: generation);
      if (_disposed || !_connectionCoordinator.ownsOperation(generation))
        return;
      _runtimeSnapshot = current;
      if (establishingConnection && !_protectedHandoffActive &&
          (current.phase == RuntimePhase.running ||
              current.connectionPending)) {
        current = await _withRuntimeActionTimeout(
            'disconnect', _runtimeEngine.disconnect,
            ownerGeneration: generation);
        current = await _settleRuntimeDisconnectTransition(current,
            ownerGeneration: generation);
        if (_disposed || !_connectionCoordinator.ownsOperation(generation))
          return;
        _runtimeSnapshot = current;
        if (!_runtimeStopConfirmed(current)) {
          throw const BootstrapFailure(
              'Остановка подключения ещё не подтверждена. Проверьте состояние POKROV.',
              code: 'connect_cancel_unconfirmed',
              operation: 'cancel_connect');
        }
      }
      _activePhase = null;
    } on Object catch (error) {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _activePhase = ConnectionPhase.actionRequired;
        _runtimeHeadline = error is BootstrapFailure
            ? error.message
            : _runtimeUnexpectedErrorMessage(error);
      }
      rethrow;
    } finally {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _warpFallbackInFlight = false;
        _connectionCoordinator.finishAction();
        _publish();
      }
    }
  }

  Future<void> _joinRuntimeActions() async {
    while (_runtimeActionsInFlight.isNotEmpty) {
      await Future.wait(_runtimeActionsInFlight
          .toList()
          .map((action) => action.then<void>((_) {}, onError: (Object _) {})));
    }
  }

  void _setPhase(ConnectionPhase phase, int generation) {
    if (_disposed ||
        !_connectionCoordinator.ownsOperation(generation) ||
        !_runtimeBusy) return;
    _activePhase = phase;
    _publish();
  }

  Future<void> refresh() => _refreshRuntimeSnapshot();
  Future<void> resume() => _resumeRuntimeAndTrustedWifiChecks();
  Future<RuntimeSnapshot> readSnapshot() async {
    final generation = _connectionCoordinator.operationGeneration;
    final current = await _withRuntimeActionTimeout(
        'protectionSnapshot', _runtimeEngine.snapshot,
        ownerGeneration: generation);
    if (_disposed || !_connectionCoordinator.ownsOperation(generation))
      throw const ConnectionOperationSuperseded();
    _update(() => _runtimeSnapshot = current);
    return current;
  }

  Future<RuntimeLiveStats> readLiveStats() => _withRuntimeActionTimeout(
      'protectionLiveStats', _runtimeEngine.liveStats);
  Future<RuntimeSnapshot?> applyTransportAdmission(
      TransportAdmission admission) async {
    final native =
        await _connectionCoordinator.applyTransportAdmission(admission);
    if (native != null && !_disposed) _update(() => _runtimeSnapshot = native);
    return native;
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void _update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void _notify(String message, {PokrovSnackTone tone = PokrovSnackTone.info}) {
    if (!_disposed) _onNotice(message, tone);
  }

  @override
  void dispose() {
    _disposed = true;
    _cacheRefreshTimer?.cancel();
    _stopTransportPolicyRefresh();
    _managedProfileLifecycle.dispose();
    _diagnosticsCoordinator.dispose();
    _connectionCoordinator.dispose();
    _protectionRuntimeSnapshot.dispose();
    super.dispose();
  }

  late RouteMode _selectedRouteMode;
  Completer<void>? _primaryConnectCompletion;
  PokrovClientExperienceState _clientExperience =
      const PokrovClientExperienceState.empty();
  bool _clientExperienceLoaded = false;
  Future<void> _clientExperienceWriteQueue = Future<void>.value();
  int _clientExperienceRevision = 0;
  ManagedProfileCacheInputs? _stagedCacheInputs;
  String _stagedProfileCacheEntryId = '';
  bool _connectHintDismissed = true;
  String? _runtimeHeadline;
  final List<String> _selectedAppIds = <String>[];
  WarpRuntimePolicy _managedWarpPolicy = WarpRuntimePolicy.clientLocalDefault;
  bool _warpRuntimeConsent = false;
  bool? _explicitWarpRuntimeConsent;
  bool _warpRuntimeRetryPending = false;
  bool _warpPolicyBusy = false;
  bool _stagedProfileUsesWarp = false;
  bool _activeConnectUsedWarp = false;
  bool _accessDenialPending = false;
  bool _warpFallbackInFlight = false;
  SmartConnectProfile? _smartConnectProfile;
  String _preferredNodeCode = '';
  String _preferredVariantId = 'direct';
  String _resolvedProfileNodeCode = '';
  String _resolvedProfileVariantId = 'direct';
  String _stagedNodeCode = '';
  String _stagedVariantId = 'direct';
  ({int generation, String candidateRef, String variant})? _stagedCandidateVariant;
  String _stagedTcpFallbackFromRevision = '';
  String _tcpFallbackFromRevision = '';
  String _activeNodeCode = '';
  String _activeVariantId = 'direct';
  final Map<String, DateTime> _automaticNodeQuarantineUntil =
      <String, DateTime>{};
  int _automaticFailoverAttempts = 0;
  int _automaticFailoverGeneration = 0;
  bool _automaticFailoverInFlight = false;

  void _queueClientExperienceWrite() {
    final snapshot = _clientExperience;
    // A local interaction can complete before the startup read does. Treat
    // that delayed snapshot as stale instead of replacing the user's choice.
    _clientExperienceRevision += 1;
    _clientExperienceWriteQueue = _clientExperienceWriteQueue
        .then((_) => _clientExperienceStore.write(snapshot))
        .catchError((Object _) {
      // Local convenience state must never block or crash the VPN shell.
    });
  }

  void _recordProtectionEvent({
    required String kind,
    required String title,
    required String detail,
    required PokrovProtectionEventTone tone,
  }) {
    if (_disposed) {
      return;
    }
    final now = DateTime.now().toUtc();
    final event = PokrovProtectionEvent(
      id: '${now.microsecondsSinceEpoch}-$kind',
      kind: kind,
      title: title,
      detail: detail,
      occurredAt: now.toIso8601String(),
      tone: tone,
    );
    _update(() {
      _clientExperience = _clientExperience.copyWith(
        protectionEvents: <PokrovProtectionEvent>[
          event,
          ..._clientExperience.protectionEvents,
        ].take(20).toList(growable: false),
      );
    });
    _queueClientExperienceWrite();
  }

  String _unexpectedConnectionDiagnostic(String operation, Object error, StackTrace stack) {
    final type = error.runtimeType.toString();
    final safeType = RegExp(r'^[_A-Za-z][_A-Za-z0-9]{0,63}$').hasMatch(type) ? type : 'Object';
    final frames = RegExp(
      r'package:(?:pokrov_app_shell|pokrov_runtime_engine|pokrov_core_domain)/[A-Za-z0-9_/.-]*?([A-Za-z0-9_]{1,64}\.dart):([0-9]{1,7})(?::[0-9]+)?',
    ).allMatches(stack.toString()).map((frame) => '${frame[1]}:${frame[2]}').toSet().take(2);
    final detail = '$operation: $safeType${frames.isEmpty ? '' : '; ${frames.join(', ')}'}';
    return detail.length <= 180 ? detail : detail.substring(0, 180);
  }

  Future<bool> _reconnectAfterManagedProfileChange({
    required String progressMessage,
    required String successMessage,
  }) async {
    if (_disposed || _runtimeSnapshot?.phase != RuntimePhase.running) {
      return false;
    }
    if (_runtimeBusy) {
      _update(() {
        _runtimeHeadline =
            'Настройки сохранены. Применим после текущего действия.';
      });
      return false;
    }
    _update(() {
      _runtimeHeadline = progressMessage;
    });
    final pending = reconnect();
    final command = _commandNumber;
    await pending;
    if (_disposed || command != _commandNumber) {
      return false;
    }
    final applied = _runtimeSnapshot?.phase == RuntimePhase.running &&
        !_managedProfileDirty;
    if (applied) {
      _update(() {
        _runtimeHeadline = successMessage;
      });
      _notify(
        successMessage,
        tone: PokrovSnackTone.success,
      );
    } else {
      _notify(
        'Настройки сохранены, но подключение не восстановлено. Нажмите «Подключить».',
        tone: PokrovSnackTone.danger,
      );
    }
    return applied;
  }

  bool get _selectedAppsRouteNeedsSelection =>
      (_selectedRouteMode == RouteMode.selectedApps ||
          _selectedRouteMode == RouteMode.excludedApps) &&
      _selectedAppIds.isEmpty;

  int? _connectionAttemptDurationMs() =>
      _connectionCoordinator.attemptDurationMs;

  domain.TransportCandidate? _reportedCandidate(String? ref) {
    if (ref == null) return null;
    for (final candidate in _transportCatalog?.candidates ?? const <domain.TransportCandidate>[]) {
      if (candidate.candidateRef == ref) return candidate;
    }
    return null;
  }

  String _candidateTransport(domain.TransportCandidate? candidate) {
    if (candidate == null) return '';
    if (candidate.protocol == 'vless') {
      if (candidate.transport == 'tcp' && candidate.protection == 'reality') return 'vless_reality';
      if (candidate.transport == 'grpc' && candidate.protection == 'tls') return 'vless_grpc_tls';
      if (candidate.transport == 'xhttp' && candidate.protection == 'reality') return 'xhttp_reality';
      if (candidate.transport == 'xhttp' && candidate.protection == 'tls') return 'xhttp_tls';
    }
    if (candidate.protocol == 'hysteria2' && candidate.transport == 'udp') return 'hysteria2';
    if (candidate.protocol == 'awg' && candidate.protection == 'awg31') return 'awg31';
    return '';
  }

  String _materialBridgeVariant(ManagedProfilePayload payload) {
    try {
      final config = _runtimeConfigMap(jsonDecode(payload.configPayload));
      final probe = _runtimeConfigMap(
          _runtimeConfigMap(config['_meta'])['runtime_variant_probe']);
      final mappings = probe['mappings'];
      // The managed formatter scopes an explicitly selected bridge to one mapping.
      if (mappings is! List || mappings.length != 1) return '';
      final id = _runtimeConfigMap(mappings.single)['id'];
      return id is String && id != 'direct' &&
          normalizeClientLocationVariantId(id) == id ? id : '';
    } on FormatException {
      return '';
    }
  }

  void _rememberStagedCandidateVariant(
      ManagedProfilePayload payload, int generation) {
    final candidate = payload.materialCandidate;
    _stagedCandidateVariant = candidate == null ? null : (
      generation: generation,
      candidateRef: candidate.candidateRef,
      variant: _materialBridgeVariant(payload),
    );
  }

  List<Map<String, Object?>> _pendingCandidateProbeReports() =>
      _candidateProbeReportInFlight
          ? const []
          : List<Map<String, Object?>>.from(_candidateProbeReports);

  void _ackCandidateProbeReports(List<Map<String, Object?>> reports) {
    if (reports.isNotEmpty) {
      _candidateProbeReports.removeRange(0, reports.length);
    }
  }

  void _recordRuntimeStatsDeliveryFailure(Object error) {
    _observability?.recordRuntimeStatsDeliveryFailure(
      errorCode: error is BootstrapFailure ? error.operationalErrorCode : 'API-008',
    );
  }

  Future<void> _reportClientLifecycle(
    String phase, {
    bool connected = false,
    String errorCode = '',
    bool? retryable,
  }) async {
    final service = _experienceService;
    if (service == null) {
      return;
    }
    final proven = connected ||
        (phase == 'runtime_observed' && _runtimeSnapshot?.isCleanlyHealthy == true);
    final reports = phase == 'failed' || proven
        ? _pendingCandidateProbeReports() : const <Map<String, Object?>>[];
    if (reports.isNotEmpty) _candidateProbeReportInFlight = true;
    try {
      final candidate = phase == 'failed' || proven
          ? _reportedCandidate(proven ? (_activeCandidateRef ?? _candidateRef) : _candidateRef)
          : null;
      final stagedVariant = _stagedCandidateVariant;
      await service.reportRuntimeStats(
        hostPlatform: _appContext.hostPlatform,
        runtimePhase: phase,
        connected: proven,
        connectivitySnapshot: _runtimeSnapshot,
        errorCode: errorCode,
        selectedNodeCode: materialCandidate?.warpMode == 'warp_over_proxy'
            ? ''
            : _activeNodeCode.isNotEmpty
                ? _activeNodeCode
                : _resolvedProfileNodeCode,
        routeMode: _selectedRouteMode.name,
        durationMs: _connectionAttemptDurationMs(),
        attemptNumber:
            _connectionAttemptNumber > 0 ? _connectionAttemptNumber : null,
        retryable: retryable,
        networkClass: _candidateNetworkClass ?? '',
        carrierMccMnc: _candidateCarrierMccMnc ?? '',
        carrierName: _candidateCarrierName ?? '',
        accessNetworkAsn: _candidateAccessNetworkAsn ?? '',
        candidateTransport: _candidateTransport(candidate),
        candidateRef: candidate?.candidateRef ?? '',
        candidateVariant: candidate == null ? '' : proven ? _activeVariantId :
            phase == 'failed' &&
                stagedVariant?.generation == _connectionCoordinator.operationGeneration &&
                stagedVariant?.candidateRef == candidate.candidateRef
                    ? stagedVariant!.variant : '',
        candidateProbes: reports,
      );
      _ackCandidateProbeReports(reports);
    } on Object catch (error) {
      if (reports.isNotEmpty) _recordRuntimeStatsDeliveryFailure(error);
      // Diagnostics must never replace the original user-facing failure.
    } finally {
      if (reports.isNotEmpty) _candidateProbeReportInFlight = false;
    }
  }

  Future<void> _reportClientRuntimeError(String errorCode) =>
      _reportClientLifecycle(
        'failed',
        errorCode: errorCode,
        retryable: errorCode != 'redeem_failed',
      );

  Future<void> _resumeRuntimeAndTrustedWifiChecks() async {
    if (!_diagnosticsCoordinator.beginResumeRefresh()) {
      return;
    }
    try {
      // Android permission sheets can resume Flutter while the original connect
      // call is still settling. Wait for that call to finish, then read the
      // native state again instead of leaving the pre-permission snapshot on
      // screen. The wait is bounded so a stuck host action never blocks a
      // normal foreground resume.
      for (var attempt = 0;
          !_disposed && _runtimeBusy && attempt < 80;
          attempt += 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (_disposed || _runtimeBusy) {
        return;
      }

      var snapshot =
          await _runRuntimeAction(_snapshotWithTransportReconciliation);
      final generation = _connectionCoordinator.operationGeneration;
      if (_disposed) {
        return;
      }
      if (snapshot.phase == RuntimePhase.configStaged &&
          snapshot.supportsLiveConnect &&
          !_isTerminalConnectMessage(snapshot.message)) {
        snapshot = await _settleRuntimeTransition(
          snapshot,
          ownerGeneration: generation,
        );
        if (_disposed) {
          return;
        }
        _update(() {
          _runtimeSnapshot = snapshot;
          _runtimeHeadline = null;
        });
        _publish();
      }
      _finishAndroidVpnPermission(snapshot);
      await _pauseRunningTunnelOnTrustedWifi();
      await _observeAndroidNetwork(_runtimeSnapshot ?? snapshot);
      await _refreshSmartAccessLeases();
    } on ConnectionOperationSuperseded {
      return;
    } finally {
      _diagnosticsCoordinator.finishResumeRefresh();
    }
  }

  Future<PokrovWifiNetworkStatus> _readCurrentWifi() {
    final probe = _currentWifiProbe;
    if (probe != null) {
      return probe();
    }
    return probePokrovCurrentWifi(_appContext.hostPlatform);
  }

  void _startAndroidNetworkPolicyObservation() {
    if (_appContext.hostPlatform == HostPlatform.android &&
        _clientExperience.routingPreferences.autoConnectOnUntrustedWifi) {
      _diagnosticsCoordinator.startRuntimePolling(_refreshDesktopRuntimeSnapshot);
    }
  }

  void _suppressAutomaticAndroidNetwork() {
    if (_appContext.hostPlatform != HostPlatform.android) return;
    _blockedAutomaticNetworkKey = _lastAndroidNetwork?.selectionKey ?? _activePhysicalNetwork?.selectionKey;
    _automaticStopNeedsNetworkKey = _blockedAutomaticNetworkKey == null;
  }

  void _clearAutomaticAndroidStop() {
    _blockedAutomaticNetworkKey = null;
    _automaticStopNeedsNetworkKey = false;
    _lastAutomaticWifiContext = null;
  }

  Future<bool> _observeAndroidNetwork(RuntimeSnapshot observed) async {
    final engine = _runtimeEngine;
    final preferences = _clientExperience.routingPreferences;
    final active = _activePhysicalNetwork;
    if (_appContext.hostPlatform != HostPlatform.android || engine is! RuntimeCandidateProbing ||
        _disposed || _runtimeBusy || _commandTail != null || _androidNetworkObservationInFlight ||
        _accessDenialPending || (!preferences.autoConnectOnUntrustedWifi && active == null)) return false;
    _androidNetworkObservationInFlight = true;
    final generation = _connectionCoordinator.operationGeneration;
    final command = _commandNumber;
    bool current() => !_disposed && !_runtimeBusy && command == _commandNumber &&
        _connectionCoordinator.ownsOperation(generation);
    try {
      final network = await _withRuntimeActionTimeout('androidCandidateNetwork',
          (engine as RuntimeCandidateProbing).readCandidateNetwork, ownerGeneration: generation);
      if (!current()) return false;
      final context = network.contextRef;
      final key = network.selectionKey;
      if (context == null || context.isEmpty || key == null || key.isEmpty) return false;
      _lastAndroidNetwork = network;
      if (_automaticStopNeedsNetworkKey) {
        _blockedAutomaticNetworkKey = key;
        _automaticStopNeedsNetworkKey = false;
      }
      final changed = active != null && active.contextRef != context && _activeCandidateRef != null;
      if (!changed && !preferences.autoConnectOnUntrustedWifi) return false;
      if (network.networkAvailable != true || network.captivePortal != false) return changed;
      final wifi = await _readCurrentWifi();
      if (!current() || !wifi.foreground || wifi.networkContextRef != context ||
          wifi.networkSelectionKey != key) return false;
      final latest = await _withRuntimeActionTimeout('androidNetworkSnapshot',
          _runtimeEngine.snapshot, ownerGeneration: generation);
      if (!current()) return false;
      _update(() => _runtimeSnapshot = latest);
      if (latest.lastStopReason == 'user_requested' && latest.phase != RuntimePhase.running && !latest.protectionRetained && wifi.manualStopSuppressed) {
        _blockedAutomaticNetworkKey = key;
        return changed;
      }
      if (preferences.pauseOnTrustedWifi && wifi.matches(preferences.trustedWifiNames)) {
        await _pauseRunningTunnelOnTrustedWifi();
        return true;
      }
      if (changed && (latest.phase == RuntimePhase.running || latest.protectionRetained) &&
          key != _blockedAutomaticNetworkKey) {
        // One attempt per native context, including failed handoff. Network
        // movement does not disprove or quarantine the old candidate.
        _activePhysicalNetwork = network;
        final reference = _activeCandidateRef!;
        await _replaceCommand(() => _recoverCandidateConnection(latest, reference,
            confirmedFailure: false), automatic: true);
        return true;
      }
      if (!preferences.autoConnectOnUntrustedWifi || !_clientExperienceLoaded ||
          key == _blockedAutomaticNetworkKey || _lastAutomaticWifiContext == context ||
          latest.phase == RuntimePhase.running || latest.connectionPending || retainsProtection ||
          !_canPrimaryConnect(latest) || _subscriptionInfo?.lane == 'expiredOrBlocked' ||
          !wifi.autoConnectEligible || wifi.manualStopSuppressed || wifi.manualStopEpoch == null ||
          !wifi.connected || wifi.permissionRequired || (wifi.name?.trim().isEmpty ?? true) ||
          wifi.matches(preferences.trustedWifiNames)) return false;
      _lastAutomaticWifiContext = context;
      final epoch = wifi.manualStopEpoch!;
      await _replaceCommand(() async {
        final accepted = await _foregroundConnectPolicy(context, epoch, true);
        if (!accepted) return;
        try {
          if (_disposed || _commandNumber != command + 1 ||
              !_connectionCoordinator.ownsOperation(generation) || key == _blockedAutomaticNetworkKey) return;
          _foregroundAutoConnect = true;
          // Existing profile/auth preparation, bound admission and proof flow.
          await _toggleRuntime();
        } finally {
          _foregroundAutoConnect = false;
          await _foregroundConnectPolicy(context, epoch, false);
        }
      }, automatic: true);
      return true;
    } on ConnectionOperationSuperseded {
      return false;
    } on Object {
      // An unavailable native observation never authorizes an automatic start.
      return false;
    } finally {
      _androidNetworkObservationInFlight = false;
    }
  }

  Future<bool> _authorizeWindowsTunnelConnect() async {
    if (_appContext.hostPlatform != HostPlatform.windows) {
      return true;
    }
    final authorizer = _windowsTunnelAuthorizer;
    final result = authorizer != null
        ? await authorizer()
        : await requestPokrovWindowsTunnelAuthorization(
            _appContext.hostPlatform,
          );
    if (_disposed) {
      return false;
    }
    if (result == PokrovWindowsTunnelAuthorization.allowed) {
      return true;
    }
    final message = result == PokrovWindowsTunnelAuthorization.unavailable
        ? 'Служба POKROV недоступна. Переустановите приложение или запустите восстановление.'
        : 'Служба POKROV не прошла проверку подлинности или совместимости.';
    _update(() {
      _runtimeHeadline = message;
    });
    _notify(message);
    return false;
  }

  Future<PokrovWifiNetworkStatus?> _activeTrustedWifi() async {
    final preferences = _clientExperience.routingPreferences;
    if (!preferences.pauseOnTrustedWifi ||
        preferences.trustedWifiNames.isEmpty) {
      return null;
    }
    final status = await _readCurrentWifi();
    return status.matches(preferences.trustedWifiNames) ? status : null;
  }

  Future<bool> _blockConnectOnTrustedWifi(
      {required int ownerGeneration}) async {
    final trusted = await _activeTrustedWifi();
    if (_disposed || !_connectionCoordinator.ownsOperation(ownerGeneration)) {
      throw const ConnectionOperationSuperseded();
    }
    if (trusted == null || _disposed) {
      return false;
    }
    final name = trusted.name?.trim();
    final message = name == null || name.isEmpty
        ? 'Подключение остановлено в доверенной Wi-Fi сети.'
        : 'Подключение остановлено в доверенной сети «$name».';
    _update(() {
      _runtimeHeadline =
          '$message Отключите паузу в правилах для ручного подключения.';
    });
    _notify(message, tone: PokrovSnackTone.info);
    return true;
  }

  Future<void> _pauseRunningTunnelOnTrustedWifi() async {
    if (_disposed ||
        _runtimeBusy ||
        _runtimeSnapshot?.phase != RuntimePhase.running) {
      return;
    }
    final trusted = await _activeTrustedWifi();
    if (_disposed ||
        trusted == null ||
        _runtimeBusy ||
        _runtimeSnapshot?.phase != RuntimePhase.running) {
      return;
    }

    _update(() {
      _runtimeBusy = true;
      _runtimeIntent = ConnectionTransitionIntent.disconnect;
    });
    final generation = _connectionCoordinator.operationGeneration;
    Future<T> runOwnedRuntimeAction<T>(
      String operation,
      Future<T> Function() action,
    ) =>
        _withRuntimeActionTimeout(operation, action,
            ownerGeneration: generation);
    _publish();
    try {
      var current = await runOwnedRuntimeAction(
        'trustedWifiDisconnect',
        _runtimeEngine.disconnect,
      );
      current = await _settleRuntimeDisconnectTransition(
        current,
        ownerGeneration: generation,
      );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        return;
      }
      final name = trusted.name?.trim();
      _update(() {
        _runtimeSnapshot = current;
        _runtimeHeadline = name == null || name.isEmpty
            ? 'POKROV поставлен на паузу в доверенной Wi-Fi сети.'
            : 'POKROV поставлен на паузу в сети «$name».';
      });
      _recordProtectionEvent(
        kind: 'trusted_wifi_pause',
        title: 'Пауза в доверенной сети',
        detail: name == null || name.isEmpty
            ? 'Туннель остановлен правилом trusted Wi-Fi.'
            : 'Туннель остановлен правилом для сети «$name».',
        tone: PokrovProtectionEventTone.neutral,
      );
    } on ConnectionOperationSuperseded {
      return;
    } on Object catch (error) {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _update(() {
          _runtimeHeadline = _runtimeUnexpectedErrorMessage(error);
        });
      }
    } finally {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _update(() {
          _runtimeBusy = false;
          _runtimeIntent = ConnectionTransitionIntent.none;
        });
      }
      _publish();
    }
  }

  void _dismissConnectHint() {
    if (_connectHintDismissed) {
      return;
    }
    _update(() {
      _connectHintDismissed = true;
    });
    unawaited(_connectHintStore.markCompleted());
  }

  Future<void> _repairRuntime({
    ValueChanged<_ProtectionRepairStep>? onStep,
    ValueChanged<Future<void> Function()?>? onCancelAvailable,
  }) async {
    if (_runtimeBusy) {
      if (!_disposed) {
        _update(() {
          _runtimeHeadline =
              'POKROV уже выполняет действие. Дождитесь завершения.';
        });
      }
      throw const _ProtectionRepairBusy();
    }
    _cancelPostConnectHostHealthPolling();
    _stopTransportPolicyRefresh();

    _update(() {
      _connectionCoordinator.beginAction(ConnectionTransitionIntent.recover,
          allowConnectCancellation: const {
                HostPlatform.android,
                HostPlatform.windows,
                HostPlatform.linux
              }.contains(_appContext.hostPlatform) &&
              _runtimeEngine is RuntimeConnectCancellation,
          onSlowStage: _handleSlowConnectionStage);
      _runtimeHeadline = 'Проверяем и восстанавливаем подключение…';
    });
    final generation = _connectionCoordinator.operationGeneration;
    final completion = Completer<void>();
    _primaryConnectCompletion = completion;
    Future<T> runOwnedRuntimeAction<T>(
      String operation,
      Future<T> Function() action,
    ) =>
        _withRuntimeActionTimeout(operation, action,
            ownerGeneration: generation);

    try {
      if (_connectionCoordinator.canCancelPrimaryConnect) {
        onCancelAvailable?.call(() async {
          if (_connectionCoordinator.ownsOperation(generation) &&
              _connectionCoordinator.canCancelPrimaryConnect) {
            await cancel();
          }
        });
      }
      final knownSnapshot = _runtimeSnapshot;
      RuntimeSnapshot current = knownSnapshot ??
          await runOwnedRuntimeAction(
            'repairSnapshot',
            _runtimeEngine.snapshot,
          );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        throw const ConnectionOperationSuperseded();
      }
      _runtimeSnapshot = current;
      if ((current.phase == RuntimePhase.running || _protectedHandoffActive) &&
          _runtimeEngine is RuntimeProtectedHandoff &&
          !(_bootstrapper is AppFirstTransportManifestService &&
              (_bootstrapper as AppFirstTransportManifestService).transportManifestEnabled)) {
        onStep?.call(_ProtectionRepairStep.refreshProfile);
        await _recoverCandidateConnection(current, _activeCandidateRef ?? _candidateRef ?? '',
            ownerGeneration: generation);
        if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
          throw const ConnectionOperationSuperseded();
        }
        onStep?.call(_ProtectionRepairStep.verifyProtection);
        if (_runtimeSnapshot?.isCleanlyHealthy != true || _activePhase == ConnectionPhase.actionRequired) {
          throw BootstrapFailure(_runtimeHeadline ?? 'Не удалось восстановить подключение.');
        }
        _recordProtectionEvent(kind: 'repair_success', title: 'Подключение восстановлено',
            detail: 'Туннель и проверка выхода подтверждены.', tone: PokrovProtectionEventTone.success);
        return;
      }
      onStep?.call(_ProtectionRepairStep.stopOldConnection);
      if (current.phase == RuntimePhase.running || current.connectionPending) {
        current = await runOwnedRuntimeAction(
          'repairDisconnect',
          _runtimeEngine.disconnect,
        );
        current = await _settleRuntimeDisconnectTransition(
          current,
          ownerGeneration: generation,
        );
        if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
          throw const ConnectionOperationSuperseded();
        }
        // A later profile/stage failure must not leave Home or the sheet
        // displaying the pre-repair running snapshot as active protection.
        _update(() {
          _runtimeSnapshot = current;
          _runtimeHeadline = current.message;
        });
        if (!_runtimeStopConfirmed(current)) {
          throw const BootstrapFailure(
              'Остановка прежнего подключения не подтверждена. Восстановление прервано.');
        }
        _protectedHandoffActive = false;
      }
      if (!_canPrimaryConnect(current)) {
        throw StateError('на этом устройстве не завершена подготовка runtime');
      }
      if (current.canInitialize &&
          current.phase == RuntimePhase.artifactReady) {
        current = await runOwnedRuntimeAction(
          'repairInitialize',
          _runtimeEngine.initialize,
        );
      }

      // Reuse the normal connect barrier: a pending host invalidation must
      // finish before repair can stage a replacement profile.
      final invalidated = await _waitForQuickSettingsInvalidation(
        _managedProfileRevision,
      );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        throw const ConnectionOperationSuperseded();
      }
      if (!invalidated) {
        throw const BootstrapFailure(
          'Не удалось обновить настройки для быстрого подключения. Попробуйте ещё раз.',
        );
      }

      final profileRevision = _managedProfileRevision;

      // A repair always resolves the current account/node/routing contract.
      // Staging is idempotent on the host and the loop runs exactly once.
      onStep?.call(_ProtectionRepairStep.refreshProfile);
      _managedProfileDirty = true;
      final managedProfile =
          await _resolveManagedProfile(ownerGeneration: generation);
      current = await runOwnedRuntimeAction(
        'repairStageManagedProfile',
        () => _stageManagedProfileWithLeaseBinding(managedProfile),
      );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        throw const ConnectionOperationSuperseded();
      }
      if (profileRevision != _managedProfileRevision) {
        _update(() {
          _runtimeSnapshot = current;
          _managedProfileDirty = true;
        });
        throw const BootstrapFailure(
          'Настройки изменились. Подключитесь еще раз, чтобы обновить профиль.',
        );
      }
      _managedProfileDirty = false;
      _stagedProfileUsesWarp = managedProfile.warpPolicy.canEnableRuntime;
      _stagedTcpFallbackFromRevision = managedProfile.tcpFallbackFromRevision;
      _stagedNodeCode = _resolvedProfileNodeCode;
      _stagedVariantId = _resolvedProfileVariantId;
      _rememberStagedCandidateVariant(managedProfile, generation);
      _stagedCacheInputs = _managedProfileCacheInputs;
      _stagedProfileCacheEntryId = managedProfile.cacheEntryId;
      _cachedProfileFallbackGate.markFreshProfileStaged();
      onStep?.call(_ProtectionRepairStep.verifyProtection);
      current = await runOwnedRuntimeAction(
        'repairConnect',
        _runtimeEngine.connect,
      );
      current = await _settleRuntimeTransition(
        current,
        ownerGeneration: generation,
      );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        throw const ConnectionOperationSuperseded();
      }
      if (current.phase == RuntimePhase.running) {
        if (_isConnectionProven(current)) {
          _finalizeProvenConnection(current);
        }
        _schedulePostConnectHostHealthRefresh(current);
      }
      _update(() {
        _runtimeSnapshot = current;
        _runtimeHeadline = current.phase == RuntimePhase.running
            ? current.isCoreEgressValidationPending
                ? 'Проверяем выход через VPN…'
                : current.isCleanlyHealthy
                    ? 'Подключение восстановлено.'
                    : 'Подключение восстановлено с предупреждением.'
            : current.message;
      });
      if (current.phase != RuntimePhase.running) {
        throw StateError(
          current.message.trim().isEmpty
              ? 'runtime не подтвердил подключение'
              : current.message,
        );
      }
      _recordProtectionEvent(
        kind: current.isCoreEgressValidationPending
            ? 'repair_egress_checking'
            : current.hasCoreEgressValidationFailure
                ? 'repair_egress_failed'
                : 'repair_success',
        title: current.isCoreEgressValidationPending
            ? 'Проверяем выход через VPN'
            : current.hasCoreEgressValidationFailure
                ? 'Выход через VPN не подтверждён'
                : 'Подключение восстановлено',
        detail: current.isCoreEgressValidationPending
            ? 'Туннель запущен; POKROV Core проверяет выход через выбранную локацию.'
            : current.hasCoreEgressValidationFailure
                ? 'POKROV Core не подтвердил выход через выбранную локацию.'
                : current.isCleanlyHealthy
                    ? 'Профиль обновлён, туннель и host-health подтверждены.'
                    : 'Профиль обновлён, туннель запущен с предупреждением хоста.',
        tone: current.isCleanlyHealthy
            ? PokrovProtectionEventTone.success
            : PokrovProtectionEventTone.warning,
      );
    } on ConnectionOperationSuperseded {
      rethrow;
    } on BootstrapFailure catch (error) {
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        throw const ConnectionOperationSuperseded();
      }
      _update(() { _runtimeHeadline = error.message; });
      unawaited(_reportClientRuntimeError('connect_failed'));
      _notify(error.message, tone: PokrovSnackTone.danger);
      _recordProtectionEvent(
        kind: 'repair_failed',
        title: 'Восстановление не завершено',
        detail: 'Ограниченный цикл остановлен. Можно повторить вручную.',
        tone: PokrovProtectionEventTone.error,
      );
      rethrow;
    } on Object catch (error) {
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        throw const ConnectionOperationSuperseded();
      }
      final message = _runtimeUnexpectedErrorMessage(error);
      _update(() {
        _runtimeHeadline = message;
      });
      unawaited(_reportClientRuntimeError('connect_unexpected'));
      _notify(message, tone: PokrovSnackTone.danger);
      _recordProtectionEvent(
        kind: 'repair_failed',
        title: 'Восстановление не завершено',
        detail: 'Ограниченный цикл остановлен. Можно повторить вручную.',
        tone: PokrovProtectionEventTone.error,
      );
      rethrow;
    } finally {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _update(() {
          if (_activePhase != ConnectionPhase.actionRequired) _activePhase = null;
          _connectionCoordinator.finishAction();
        });
      }
      if (!completion.isCompleted) completion.complete();
      if (identical(_primaryConnectCompletion, completion)) {
        _primaryConnectCompletion = null;
      }
      onCancelAvailable?.call(null);
      await _enforceKnownAccessDenial();
    }
  }

  Future<void> _reportFirstSessionEvent(
    String eventName, {
    required String stage,
    required String result,
    String errorCode = '',
    bool? retryable,
  }) async {
    final service = _firstSessionEventService;
    if (service == null) {
      return;
    }
    try {
      await service.reportFirstSessionEvent(
        hostPlatform: _appContext.hostPlatform,
        eventName: eventName,
        stage: stage,
        result: result,
        errorCode: errorCode,
        retryable: retryable,
      );
    } on Object {
      // First-session telemetry is best-effort and never gates access.
    }
  }

  Future<void> _enforceKnownAccessDenial() async {
    if (_protectedHandoffActive) return;
    if (_disposed || !_accessDenialPending || _runtimeBusy) return;
    _accessDenialPending = false;
    if (_runtimeSnapshot?.phase != RuntimePhase.running) {
      _invalidateQuickSettingsProfile();
      return;
    }
    _cancelPostConnectHostHealthPolling();
    _update(() {
      _runtimeBusy = true;
      _runtimeIntent = ConnectionTransitionIntent.disconnect;
    });
    final generation = _connectionCoordinator.operationGeneration;
    Future<T> runOwnedRuntimeAction<T>(
      String operation,
      Future<T> Function() action,
    ) =>
        _withRuntimeActionTimeout(operation, action,
            ownerGeneration: generation);
    try {
      var current = await runOwnedRuntimeAction(
        'accessDeniedDisconnect',
        _runtimeEngine.disconnect,
      );
      current = await _settleRuntimeDisconnectTransition(
        current,
        ownerGeneration: generation,
      );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation))
        return;
      _update(() {
        _runtimeSnapshot = current;
        _runtimeHeadline =
            'Доступ не активен. Продлите доступ, чтобы подключиться.';
      });
      _invalidateQuickSettingsProfile();
    } on ConnectionOperationSuperseded {
      return;
    } on Object catch (error) {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _update(() => _runtimeHeadline = _runtimeUnexpectedErrorMessage(error));
      }
    } finally {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _update(() {
          _runtimeBusy = false;
          _runtimeIntent = ConnectionTransitionIntent.none;
        });
      }
      _publish();
    }
  }

  Future<RuntimeSnapshot> _runRuntimeAction(
    Future<RuntimeSnapshot> Function() action,
  ) async {
    if (_runtimeBusy) throw const ConnectionOperationSuperseded();
    _update(() {
      _runtimeBusy = true;
    });
    final generation = _connectionCoordinator.operationGeneration;

    late RuntimeSnapshot snapshot;
    try {
      snapshot = await action();
      if (!_connectionCoordinator.ownsOperation(generation)) {
        throw const ConnectionOperationSuperseded();
      }
      if (_disposed) {
        return snapshot;
      }

      _update(() {
        _runtimeSnapshot = snapshot;
        _runtimeHeadline = null;
      });
      _publish();
      if (_firstLaunchStep == _FirstLaunchStep.ready) {
        unawaited(_reportClientLifecycle("runtime_observed"));
      }
    } finally {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _update(() {
          _runtimeBusy = false;
        });
      }
      await _enforceKnownAccessDenial();
      _publish();
    }
    if (!_connectionCoordinator.ownsOperation(generation)) {
      throw const ConnectionOperationSuperseded();
    }
    return _runtimeSnapshot ?? snapshot;
  }

  Future<RuntimeSnapshot> _snapshotWithTransportReconciliation() async {
    final generation = _connectionCoordinator.operationGeneration;
    final snapshot = await _runtimeEngine.snapshot();
    if (_disposed || !_connectionCoordinator.ownsOperation(generation))
      throw const ConnectionOperationSuperseded();
    if (!_requiresTransportReconciliation(snapshot)) return snapshot;
    // A new UI owner cannot inherit an unfinished proof or an accepted lease's
    // exact identity. The native service may keep the lease while UI is absent;
    // on reattachment, stop before selecting again under fresh policy.
    if (!_disposed)
      _update(() {
        _runtimeSnapshot = snapshot;
        _runtimeHeadline = null;
      });
    final stopped = await _withRuntimeActionTimeout(
        'unownedTransportStop', _runtimeEngine.disconnect,
        ownerGeneration: generation);
    return _settleRuntimeDisconnectTransition(stopped,
        ownerGeneration: generation);
  }

  bool _requiresTransportReconciliation(RuntimeSnapshot snapshot) =>
      snapshot.phase == RuntimePhase.running &&
      !_connectionCoordinator.actionInFlight &&
      (snapshot.transportProofPending == true ||
          (snapshot.transportLeaseActive == true &&
              !_connectionCoordinator.hasActiveTransportLease));

  Future<void> _refreshRuntimeSnapshot() async {
    RuntimeSnapshot snapshot;
    try {
      snapshot = await _runRuntimeAction(_snapshotWithTransportReconciliation);
    } on ConnectionOperationSuperseded {
      return;
    } on Object {
      if (_runtimeSnapshot != null &&
          _requiresTransportReconciliation(_runtimeSnapshot!)) return;
      rethrow;
    }
    if (await _observeAndroidNetwork(snapshot)) return;
    if (snapshot.phase == RuntimePhase.running) {
      if (_isConnectionProven(snapshot)) {
        _finalizeProvenConnection(snapshot);
      } else if (snapshot.transportProofPending != true &&
          _appContext.hostPlatform == HostPlatform.android &&
          snapshot.coreEgressValidated == null) {
        _schedulePostConnectHostHealthRefresh(snapshot);
      }
    }
    await _refreshSmartAccessLeases();
  }

  Future<void> _refreshDesktopRuntimeSnapshot() async {
    if (_disposed || _runtimeBusy) return;
    final generation = _connectionCoordinator.operationGeneration;
    final observed = _runtimeSnapshot;
    RuntimeSnapshot? refreshed;
    try {
      refreshed = await _withRuntimeActionTimeout(
        'desktopServiceStatus',
        _runtimeEngine.snapshot,
      );
    } on Object {
      // An unavailable observer cannot retain the previous protection proof.
      // The next local poll can recover without reconnecting or fetching API.
    }
    if (_disposed ||
        _runtimeBusy ||
        !_connectionCoordinator.ownsOperation(generation) ||
        !identical(observed, _runtimeSnapshot)) {
      return;
    }
    if (refreshed != null && _requiresTransportReconciliation(refreshed)) {
      _update(() {
        _runtimeSnapshot = refreshed;
        _runtimeHeadline = null;
      });
      try {
        await _refreshRuntimeSnapshot();
      } on Object {
        // The unowned native snapshot remains unverified after a failed stop.
      }
      return;
    }
    final unchanged = identical(observed, refreshed) ||
        (observed != null &&
            refreshed != null &&
            observed.hasSameStateAs(refreshed));
    if (!unchanged) {
      _update(() {
        _runtimeSnapshot = refreshed;
        if (observed?.phase != refreshed?.phase ||
            observed?.isCleanlyHealthy != refreshed?.isCleanlyHealthy) {
          _runtimeHeadline = null;
        }
      });
    }
    if (refreshed != null && await _observeAndroidNetwork(refreshed)) return;
    // A UI/resume read may already have adopted this failure. Recovery belongs
    // to the active candidate, not to which observer first saw the snapshot.
    if (_transportCatalog != null && _activeCandidateRef != null && refreshed != null &&
        (refreshed.hasCoreEgressProbeFailure ||
            observed?.phase == RuntimePhase.running && refreshed.phase != RuntimePhase.running)) {
      _scheduleCandidateRecovery(refreshed);
    }
    if (!unchanged) unawaited(_reportClientLifecycle("runtime_observed"));
  }

  static const _nativeMutationOperations = {
    'initialize',
    'repairInitialize',
    'stageManagedProfile',
    'repairStageManagedProfile',
    'stageWarpFallbackProfile',
    'migrateCachedAndroidProfile',
    'connect',
    'repairConnect',
    'connectWithoutWarp',
    'disconnect',
    'repairDisconnect',
    'trustedWifiDisconnect',
    'accessDeniedDisconnect',
    'unownedTransportStop',
    'applyWarpFallback',
    'replaceManagedProfile',
  };

  Future<T> _withRuntimeActionTimeout<T>(
    String operation,
    Future<T> Function() action, {
    int? ownerGeneration,
  }) async {
    // Linux and Windows IPC own their native deadlines and cancellation/cleanup.
    // The shorter UI deadline must not discard an authorized mutation's outcome.
    final engine = _runtimeEngine;
    final generation =
        ownerGeneration ?? _connectionCoordinator.operationGeneration;
    final RuntimeConnectCancellation? cancellation =
        engine is RuntimeConnectCancellation
            ? engine as RuntimeConnectCancellation
            : null;
    String? startedRequest;
    try {
      return await _connectionCoordinator.runWithTimeout(
        operation,
        () {
          final previous = cancellation?.activeConnectRequestId;
          final pending = action();
          if (_nativeMutationOperations.contains(operation)) {
            final tracked = pending.then<Object?>((value) => value);
            _runtimeActionsInFlight.add(tracked);
            unawaited(tracked
                .then<void>((_) => _runtimeActionsInFlight.remove(tracked),
                    onError: (Object _) {
              _runtimeActionsInFlight.remove(tracked);
            }));
          }
          final current = cancellation?.activeConnectRequestId;
          if (current != previous) {
            startedRequest = current;
            if (current != null &&
                !_disposed &&
                _connectionCoordinator.ownsOperation(generation) &&
                _connectionCoordinator.canCancelPrimaryConnect) {
              _update(() => _connectionCoordinator
                  .bindCancellableConnect(current, generation: generation));
            }
          }
          return pending;
        },
        ownerGeneration: generation,
        timeout: _appContext.hostPlatform == HostPlatform.android &&
                const {'initialize', 'repairInitialize'}.contains(operation)
            ? const Duration(seconds: 90)
            : null,
        hostOwnsTimeout: _appContext.hostPlatform == HostPlatform.linux ||
            _appContext.hostPlatform == HostPlatform.windows,
      );
    } on Object catch (error) {
      if (error is TimeoutException || error is ConnectionOperationSuperseded) {
        await _cancelOwnedConnect(cancellation, startedRequest);
      }
      rethrow;
    }
  }

  Future<void> _cancelOwnedConnect(
      RuntimeConnectCancellation? engine, String? requestId) async {
    if (engine == null || requestId == null) return;
    try {
      await engine
          .cancelConnectRequest(requestId)
          .timeout(const Duration(seconds: 3));
    } on Object {
      throw const BootstrapFailure(
        'Отмена подключения не подтверждена. Проверьте состояние POKROV и отключите его при необходимости.',
        code: 'connect_cancel_unconfirmed',
        operation: 'cancel_connect',
      );
    }
  }

  bool get _routingCatalogEnabled {
    final service = _bootstrapper;
    return service is AppFirstRoutingCatalogService &&
        (service as AppFirstRoutingCatalogService).routingCatalogEnabled;
  }

  bool get _selectiveServicesAvailable =>
      _routingCatalogEnabled &&
      (_appContext.hostPlatform == HostPlatform.android ||
          _appContext.hostPlatform == HostPlatform.windows);

  Future<_CatalogServiceSelectionData> _loadCatalogServiceSelection(
      {required bool Function() isCurrent,
      required Future<void> cancelled}) async {
    final service = _bootstrapper;
    final access = _freeProfileAccess;
    final revision = _managedProfileRevision;
    final generation = _connectionCoordinator.operationGeneration;
    bool metadataCurrent() =>
        !_disposed &&
        isCurrent() &&
        _selectiveServicesAvailable &&
        revision == _managedProfileRevision &&
        _freeProfileAccess?.accessState == access?.accessState &&
        _connectionCoordinator.ownsOperation(generation);
    if (!_selectiveServicesAvailable ||
        service is! AppFirstRoutingCatalogService ||
        access == null ||
        !access.hasKnownAccessState ||
        !access.isConsistent) {
      throw const RoutingCatalogFailure('catalog_selective_unavailable');
    }
    final result = await (service as AppFirstRoutingCatalogService)
        .fetchRoutingCatalog(hostPlatform: _appContext.hostPlatform)
        .timeout(_actionTimeout);
    if (result == null)
      throw const RoutingCatalogFailure('catalog_selective_unavailable');
    final catalog = RoutingCatalogPolicy.fromVerified(result.catalog);
    final native = await _runtimeEngine.snapshot().timeout(_actionTimeout);
    if (_disposed ||
        !_selectiveServicesAvailable ||
        revision != _managedProfileRevision ||
        _freeProfileAccess?.accessState != access.accessState) {
      throw const RoutingCatalogFailure('catalog_preview_superseded');
    }
    RuntimeSmartAccessLeaseState? runtime;
    DateTime? runtimeObservedAt;
    final engine = _runtimeEngine;
    final digest = native.effectiveProfileDigest;
    bool runtimeCurrent() {
      final binding = _connectionCoordinator.activeSmartAccessLeases;
      final now = DateTime.now().toUtc();
      return !_disposed &&
          isCurrent() &&
          !_runtimeBusy &&
          _connectionCoordinator.ownsOperation(generation) &&
          _runtimeSnapshot?.phase == RuntimePhase.running &&
          _runtimeSnapshot?.effectiveProfileDigest == digest &&
          binding != null &&
          binding.profileDigest == digest &&
          binding.catalogExpiresAt != null &&
          now.isBefore(binding.catalogExpiresAt!) &&
          !_connectionCoordinator.receivedCatalogRevocation(binding);
    }

    if (engine is RuntimeSmartAccessBackgroundControl &&
        native.phase == RuntimePhase.running &&
        native.smartAccessRuntimeControlVersion == 1 &&
        digest != null &&
        runtimeCurrent()) {
      try {
        final state = await (engine as RuntimeSmartAccessBackgroundControl)
            .readSmartAccessLeases(digest)
            .timeout(_actionTimeout);
        if (runtimeCurrent()) {
          runtime = state;
          runtimeObservedAt = DateTime.now().toUtc();
        }
      } on Object {
        // Native state is optional presentation data, never inferred from the
        // prepared catalog or retained inventory when readback is unavailable.
      }
    }
    final smartAccessEnabled = service is AppFirstSmartAccessService &&
        (service as AppFirstSmartAccessService).smartAccessEnabled;
    VerifiedSmartAccessProviderPolicy? providers;
    DateTime? providersObservedAt;
    if (smartAccessEnabled &&
        service is AppFirstSmartAccessService &&
        metadataCurrent() &&
        catalog.services
            .any((item) => item.providerCapabilityRefs.isNotEmpty)) {
      try {
        providers = await (service as AppFirstSmartAccessService)
            .fetchSmartAccessProviders(
                hostPlatform: _appContext.hostPlatform,
                operationIsCurrent: metadataCurrent,
                remainingBudget: _actionTimeout,
                cancelled: Future.any<void>([
                  cancelled,
                  _connectionCoordinator.whenOperationChanges(generation)
                ]))
            .timeout(_actionTimeout);
        providersObservedAt = DateTime.now().toUtc();
      } on Object {
        // Optional signed metadata must not block a valid catalog selection.
        // Missing evidence remains unknown and never grants route authority.
      }
    }
    if (_disposed ||
        revision != _managedProfileRevision ||
        _freeProfileAccess?.accessState != access.accessState) {
      throw const RoutingCatalogFailure('catalog_preview_superseded');
    }
    return _CatalogServiceSelectionData(
        catalog: catalog,
        platform: _appContext.hostPlatform.name,
        accessState: access.accessState,
        profileRevision: revision,
        nativeWindowVersion: native.routingCatalogWindowVersion,
        runtime: runtime,
        runtimeObservedAt: runtimeObservedAt,
        runtimeIsCurrent: runtimeCurrent,
        runtimeInvalidated:
            _connectionCoordinator.whenOperationChanges(generation),
        smartAccessEnabled: smartAccessEnabled,
        providerPolicy: providers,
        providerPolicyObservedAt: providersObservedAt,
        metadataIsCurrent: metadataCurrent);
  }

  Future<_RoutingCatalogPreview?> _loadRoutingCatalogPreview() async {
    final service = _bootstrapper;
    if (service is! AppFirstRoutingCatalogService ||
        !(service as AppFirstRoutingCatalogService).routingCatalogEnabled)
      return null;
    final revision = _managedProfileRevision;
    final mode = _selectedRouteMode;
    final access = _freeProfileAccess;
    if (access == null || !access.hasKnownAccessState || !access.isConsistent) {
      throw const RoutingCatalogFailure('catalog_profile_access_invalid');
    }
    final result = await (service as AppFirstRoutingCatalogService)
        .fetchRoutingCatalog(hostPlatform: _appContext.hostPlatform)
        .timeout(_actionTimeout);
    if (result == null) return null;
    final native = await _runtimeEngine.snapshot().timeout(_actionTimeout);
    if (_disposed ||
        revision != _managedProfileRevision ||
        mode != _selectedRouteMode ||
        _freeProfileAccess?.accessState != access.accessState) {
      throw const RoutingCatalogFailure('catalog_preview_superseded');
    }
    final catalog = RoutingCatalogPolicy.fromVerified(result.catalog);
    final policy = compileCatalogDomainPolicy(
      policy: catalog,
      mode: switch (mode) {
        RouteMode.selectiveServices => CatalogRoutingMode.selective,
        RouteMode.fullTunnel => CatalogRoutingMode.full,
        RouteMode.allExceptRu => CatalogRoutingMode.smartSafe,
        RouteMode.selectedApps => CatalogRoutingMode.includeApps,
        RouteMode.excludedApps => CatalogRoutingMode.excludeApps,
      },
      platform: _appContext.hostPlatform.name,
      accessState: access.accessState,
      selectedServiceIds: mode == RouteMode.selectiveServices
          ? _clientExperience.routingPreferences.selectedCatalogServiceIds
          : const {},
      // This is a prospective catalog layer, conditional on a working VPN.
      // It is never an attestation of the currently running native policy.
      vpnAvailable: true,
      now: DateTime.now().toUtc(),
    );
    return _RoutingCatalogPreview(
      catalog: catalog,
      policy: policy,
      usingCache: result.usingCache,
      checkedAt: DateTime.now().toUtc(),
      limitations: [
        if (_appContext.hostPlatform != HostPlatform.android &&
            _appContext.hostPlatform != HostPlatform.windows)
          'Применение каталога на этой платформе пока не поддерживается.',
        if (native.routingCatalogWindowVersion != 1)
          'Модуль подключения пока не подтвердил поддержку каталога; применение недоступно.',
        if (_appContext.hostPlatform == HostPlatform.windows &&
            (mode == RouteMode.selectedApps || mode == RouteMode.excludedApps))
          'В Windows общий системный DNS идёт через VPN. При восстановлении защита временно блокирует трафик всего устройства.',
        if (_appContext.hostPlatform == HostPlatform.windows &&
            (mode == RouteMode.selectedApps || mode == RouteMode.excludedApps) &&
            _clientExperience.routingPreferences.dnsTransport ==
                PokrovDnsTransport.direct)
          'Для выбора приложений в Windows включите DNS через VPN.',
        if ((mode == RouteMode.selectedApps ||
                mode == RouteMode.excludedApps) &&
            _selectedAppIds.isEmpty)
          'Перед подключением выберите хотя бы одно приложение.',
        if (_clientExperience.routingPreferences.externalSmartDnsEnabled)
          'Для внешнего Smart DNS ещё не подготовлен маршрут сервиса.',
      ],
    );
  }

  Future<CatalogAndroidDiscoveryResult> _inspectVerifiedCatalogDirectApps(
      bool fresh) async {
    final service = _bootstrapper;
    if (service is! AppFirstRoutingCatalogService ||
        !(service as AppFirstRoutingCatalogService).routingCatalogEnabled) {
      throw const RoutingCatalogFailure('catalog_discovery_unavailable');
    }
    final result = await (service as AppFirstRoutingCatalogService)
        .fetchRoutingCatalog(hostPlatform: HostPlatform.android)
        .timeout(_actionTimeout);
    if (result == null || !_routingCatalogEnabled) {
      throw const RoutingCatalogFailure('catalog_discovery_unavailable');
    }
    final access = _freeProfileAccess;
    if (_disposed ||
        access == null ||
        !access.hasKnownAccessState ||
        !access.isConsistent) {
      throw const RoutingCatalogFailure('catalog_profile_access_invalid');
    }
    final observations =
        await const CatalogAndroidDiscovery().inspectDirectCandidates(
      RoutingCatalogPolicy.fromVerified(result.catalog),
      accessState: access.accessState,
      fresh: fresh,
    );
    if (_disposed ||
        !_routingCatalogEnabled ||
        _freeProfileAccess?.accessState != access.accessState) {
      throw const RoutingCatalogFailure('catalog_profile_access_changed');
    }
    return observations;
  }

  Future<Set<String>> _loadVerifiedCatalogDirectApps(bool fresh) async {
    final observations = await _inspectVerifiedCatalogDirectApps(fresh);
    return observations.matches.entries
        .where((entry) => entry.value == CatalogAndroidMatch.matched)
        .map((entry) => entry.key)
        .toSet();
  }

  Future<ManagedProfilePayload> _resolveManagedProfile({
    Duration? deadline,
    bool suppressWarpRuntime = false,
    int? ownerGeneration,
    String recoveryCandidateRef = '',
    Set<String> excludedCandidateRefs = const {},
  }) async {
    final generation = ownerGeneration ?? _connectionCoordinator.operationGeneration;
    final profileRevision = _managedProfileRevision;
    void requireCurrent() {
      if (_disposed || !_connectionCoordinator.ownsOperation(generation) ||
          profileRevision != _managedProfileRevision) {
        throw const ConnectionOperationSuperseded();
      }
    }
    requireCurrent();
    if (recoveryCandidateRef.isEmpty) {
      _candidateRef = null;
      _candidateNetworkClass = null;
      _candidateCarrierMccMnc = null;
      _candidateCarrierName = null;
      _candidateAccessNetworkAsn = null;
    }
    _setPhase(recoveryCandidateRef.isEmpty ? ConnectionPhase.preparing : ConnectionPhase.recovering, generation);
    _observability?.enterProfilePhase();
    final cancelled = _connectionCoordinator.actionInFlight
        ? _connectionCoordinator.whenOperationEnds(generation)
        : _connectionCoordinator.whenOperationChanges(generation);
    final inputs = _managedProfileCacheInputs;
    final signedTransport = _bootstrapper is AppFirstTransportManifestService &&
        (_bootstrapper as AppFirstTransportManifestService).transportManifestEnabled;
    final features = signedTransport ? const <RuntimeTransportFeature>{}
        : _runtimeSnapshot?.transportCapabilities?.features ?? const <RuntimeTransportFeature>{};
    final engine = _runtimeEngine;
    final discoverCandidates = !signedTransport && engine is RuntimeCandidateProbing && features.isNotEmpty;
    final useCandidateProbes = discoverCandidates && _connectionCoordinator.actionInFlight;
    Future<ManagedProfilePayload> resolve({String candidateRef = '', bool select = true,
        bool cache = true, Future<void>? stop}) => _bootstrapper.resolveManagedProfile(
      timeout: deadline,
      cancelled: stop ?? cancelled,
      hostPlatform: inputs.hostPlatform,
      routeMode: inputs.routeMode,
      tcpFallbackFromRevision: _tcpFallbackFromRevision,
      runtimeFeatures: features,
      coreRelease: _runtimeSnapshot?.coreVersion,
      selectedApps: inputs.selectedApps,
      preferredNodeCode: inputs.preferredNodeCode,
      preferredVariantId: inputs.preferredNodeCode.trim().isEmpty ? 'direct' : inputs.preferredVariantId,
      preferredCountryCode: inputs.preferredCountryCode,
      preferredCandidateRef: inputs.preferredCandidateRef,
      excludedNodeCodes: inputs.preferredNodeCode.trim().isEmpty ? _activeAutomaticNodeExclusions() : const <String>{},
      selectCandidate: select, selectedCandidateRef: candidateRef, cacheResult: cache,
    );
    var payload = await resolve(candidateRef: inputs.preferredCandidateRef,
        select: !discoverCandidates, cache: !useCandidateProbes);
    requireCurrent();
    final catalog = payload.transportCatalog;
    if (useCandidateProbes && catalog != null) {
      final probing = engine as RuntimeCandidateProbing;
      final baseWarpPolicy = payload.warpPolicy.withClientLocalDefaults();
      final hasWarpCandidates = catalog.candidates.any((candidate) =>
          candidate.warpMode != null);
      final warpStatus = hasWarpCandidates
          ? await _fetchWarpStatusOrNull(ownerGeneration: generation,
              cancelled: cancelled)
          : null;
      requireCurrent();
      final candidateWarpPolicy = warpStatus?.applyTo(baseWarpPolicy) ?? baseWarpPolicy;
      final reportedWarpConsent = (warpStatus?.consented ?? false) ||
          _warpRuntimeConsent || baseWarpPolicy.userConsented;
      final useWarpCandidates =
          (_explicitWarpRuntimeConsent ?? reportedWarpConsent) &&
          candidateWarpPolicy.canOfferRuntime &&
          (_warpRuntimeRetryPending || _warpRuntimeAttemptAllowed(candidateWarpPolicy));
      final network = await probing.readCandidateNetwork();
      requireCurrent();
      final nativeKey = network.selectionKey;
      final context = network.contextRef;
      if (nativeKey == null || nativeKey.isEmpty || context == null || context.isEmpty) {
        throw const BootstrapFailure('Не удалось проверить сеть. Попробуйте подключиться ещё раз.', code: 'candidate_network_unavailable');
      }
      final asn = !retainsProtection && _runtimeSnapshot?.phase != RuntimePhase.running &&
              network.networkClass != 'cellular'
          ? payload.accessNetworkAsn : '';
      final key = asn.isNotEmpty ? 'asn:$asn' : nativeKey;
      final offlineKey = _offlineCandidateNetworkKey(nativeKey, context, network.networkClass);
      _candidateNetworkClass = network.networkClass;
      _candidateCarrierMccMnc = network.mccMnc;
      _candidateCarrierName = network.carrierName;
      _candidateAccessNetworkAsn = asn.isEmpty ? null : asn;
      final cache = _bootstrapper;
      if (cache is CachedManagedProfileBootstrapper) {
        final remembered = await (cache as CachedManagedProfileBootstrapper)
            .successfulCandidateRef(inputs, key);
        requireCurrent();
        if (remembered != null) _candidateSelector.restoreSuccess(key, remembered);
      }
      var country = inputs.preferredCountryCode;
      if (inputs.preferredNodeCode.isNotEmpty) {
        for (final candidate in catalog.candidates) {
          if (candidate.nodeCode == inputs.preferredNodeCode) { country = candidate.nodeCountryCode(catalog.candidates); break; }
        }
      }
      if (inputs.preferredNodeCode.isNotEmpty && country.isEmpty) {
        throw const BootstrapFailure('В выбранной стране сейчас нет доступного подключения.', code: 'candidate_country_unavailable');
      }
      _setPhase(recoveryCandidateRef.isEmpty ? ConnectionPhase.probing : ConnectionPhase.recovering, generation);
      final initial = payload;
      final bundled = initial.candidateMaterials;
      final materialized = <String, ManagedProfilePayload>{
        if (bundled.isEmpty) catalog.selectedCandidateRef: initial,
        ...bundled,
      };
      final eligibleCandidates = catalog.candidates.where((candidate) =>
          (bundled.isEmpty || bundled.containsKey(candidate.candidateRef)) &&
          (country.isEmpty || candidate.nodeCountryCode(catalog.candidates) == country) &&
          (inputs.preferredCandidateRef.isEmpty || candidate.candidateRef == inputs.preferredCandidateRef) &&
          (inputs.preferredNodeCode.isEmpty || candidate.nodeCode == inputs.preferredNodeCode)).toList();
      final warpCandidates = eligibleCandidates.where((candidate) =>
          candidate.warpMode != null).toList();
      final ordinaryCandidates = eligibleCandidates.where((candidate) =>
          candidate.warpMode == null).toList();
      final groups = useWarpCandidates && warpCandidates.isNotEmpty
          ? [warpCandidates, ordinaryCandidates]
          : [ordinaryCandidates];
      var selectedCandidate = false;
      for (final group in groups) {
        if (group.isEmpty) continue;
        final selectionTimeout = identical(group, warpCandidates)
            ? const Duration(seconds: 5)
            : useWarpCandidates && warpCandidates.isNotEmpty
                ? const Duration(seconds: 7)
                : const Duration(seconds: 12);
        try {
          payload = await _candidateSelector.select(
            catalog: TransportCandidateCatalog(
                revision: catalog.revision, selectedCandidateRef: catalog.selectedCandidateRef,
                candidates: group),
            network: key, platform: _appContext.hostPlatform,
            ipv6Available: network.ipv6Available,
            // Country was checked against the full catalog before grouping.
            cancelled: cancelled,
            recoveryCandidateRef: recoveryCandidateRef,
            excludedCandidateRefs: excludedCandidateRefs,
            selectionTimeout: selectionTimeout,
            onProbeResult: (candidate, result) {
              if (_disposed || !_connectionCoordinator.ownsOperation(generation) ||
                  profileRevision != _managedProfileRevision) return;
              final exact = materialized[candidate.candidateRef];
              _recordCandidateProbe(candidate, result, candidateVariant:
                  exact?.materialCandidate?.candidateRef == candidate.candidateRef
                      ? _materialBridgeVariant(exact!) : '');
            },
            prepare: (candidate, stop) async {
              requireCurrent();
              var stopped = false;
              unawaited(stop.then((_) => stopped = true));
              final exact = materialized[candidate.candidateRef] ??
                  await resolve(candidateRef: candidate.candidateRef, select: false, cache: false, stop: stop);
              requireCurrent();
              if (!stopped) materialized[candidate.candidateRef] = exact;
            },
            probe: (candidate, stop, timeout) async {
              requireCurrent();
              final exact = materialized[candidate.candidateRef]!;
              final probePayload = exact.copyWith(warpPolicy: candidate.warpMode == null
                  ? exact.warpPolicy.withUserConsent(false)
                  : candidateWarpPolicy.copyWith(mode: candidate.warpMode,
                      userConsented: true));
              final checked = await _probeManagedCandidate(probing, probePayload, context: context, cancelled: stop,
                  timeout: timeout, generation: generation, requireCurrent: requireCurrent);
              return checked.success
                  ? SmartConnectCandidateProbeResult.success(exact, duration: checked.duration)
                  : SmartConnectCandidateProbeResult.failure(checked.failureKind, duration: checked.duration);
            },
          );
          selectedCandidate = true;
          break;
        } on SmartConnectSelectionExhausted {
          // A failed WARP chain may use the ordinary candidate catalog.
        }
      }
      if (!selectedCandidate) {
        throw const BootstrapFailure('Рабочее подключение не найдено. Проверьте сеть и попробуйте ещё раз.',
            code: 'candidate_selection_exhausted', operationalCode: 'CONN-008');
      }
      requireCurrent();
      final currentNetwork = await probing.readCandidateNetwork();
      requireCurrent();
      if (currentNetwork.contextRef != context || currentNetwork.selectionKey != nativeKey) {
        throw const BootstrapFailure('Сеть изменилась. Подключитесь ещё раз.', code: 'candidate_network_changed');
      }
      if (cache is CachedManagedProfileBootstrapper) {
        try {
          await (cache as CachedManagedProfileBootstrapper).cacheResolvedManagedProfile(inputs, payload, cancelled: cancelled);
          final selected = payload.materialCandidate!;
          final alternatives = SmartConnectCandidateSelector.cacheAlternatives(selected,
              eligibleCandidates.where((candidate) => materialized.containsKey(candidate.candidateRef)),
              countryOnly: inputs.preferredCountryCode.isNotEmpty, catalog: catalog);
          for (final candidate in alternatives) {
            if (inputs.preferredCandidateRef.isNotEmpty) break;
            final alternate = materialized[candidate.candidateRef]!;
            await (cache as CachedManagedProfileBootstrapper).cacheResolvedManagedProfile(
                inputs, alternate, cancelled: cancelled, candidateOnly: true);
          }
        } on BootstrapFailure {
          rethrow;
        } on Object {
          // Secure-storage failure does not invalidate the online server reply.
        }
        requireCurrent();
      }
      _candidatePhysicalNetwork = network;
      _candidateNetworkKey = key;
      _candidateOfflineNetworkKey = offlineKey;
      _candidateRef = payload.materialCandidate!.candidateRef;
    } else if (discoverCandidates && catalog == null) {
      // Older servers still own the legacy Smart Connect path.
      payload = await resolve();
      requireCurrent();
      _candidateRef = null;
      _candidateNetworkKey = null;
      _candidateOfflineNetworkKey = null;
    }
    _transportCatalog = payload.transportCatalog;
    _offlineState = null;
    return _prepareManagedProfile(payload,
        suppressWarpRuntime: suppressWarpRuntime, ownerGeneration: generation);
  }

  void _recordCandidateProbe(
      domain.TransportCandidate candidate, SmartConnectCandidateProbeResult result,
      {String candidateVariant = ''}) {
    try {
      _observability?.recordCandidateProbe(
          failureKind: result.failureKind, duration: result.duration);
    } on Object {
      // Diagnostic validation must not turn a working candidate into a failed connect.
    }
    final transport = _candidateTransport(candidate);
    if (transport.isEmpty) return;
    if (_candidateProbeReports.length >= 16) return;
    _candidateProbeReports.add({
      'candidate_ref': candidate.candidateRef,
      'candidate_transport': transport,
      if (candidateVariant.isNotEmpty) 'candidate_variant': candidateVariant,
      'stage': 'probe',
      'connected': result.profile != null,
      'failure_kind': result.failureKind,
      'duration_ms': result.duration.inMilliseconds,
    });
  }

  Future<RuntimeCandidateProbeResult> _probeManagedCandidate(RuntimeCandidateProbing probing,
      ManagedProfilePayload payload, {required String context, required Future<void> cancelled,
      required Duration timeout, required int generation, required void Function() requireCurrent}) async {
    final probeId = 'candidate_${generation}_${math.Random.secure().nextInt(1 << 32)}';
    final result = probing.probeCandidate(probeId: probeId, payload: payload,
        timeout: timeout, expectedNetworkContext: context);
    var settled = false;
    var stopped = false;
    Future<void>? cleanup;
    unawaited(cancelled.then((_) {
      stopped = true;
      if (!settled) {
        cleanup = probing.cancelCandidateProbe(probeId);
        unawaited(cleanup!.then<void>((_) {}, onError: (Object _) {}));
      }
    }));
    try {
      final receipt = await result;
      requireCurrent();
      return stopped
          ? RuntimeCandidateProbeResult(success: false,
              failureKind: 'cancelled', duration: receipt.duration)
          : receipt;
    } finally {
      settled = true;
      if (cleanup != null) await cleanup;
    }
  }

  Future<ManagedProfilePayload> _resolveCachedCandidateProfile(ManagedProfileCacheInputs inputs,
      ManagedProfilePayload cached, {required int generation, String recoveryCandidateRef = '',
      Set<String> excludedCandidateRefs = const {}}) async {
    final engine = _runtimeEngine;
    final cache = _bootstrapper;
    final catalog = cached.transportCatalog;
    final profileRevision = _managedProfileRevision;
    void requireCurrent() {
      if (_disposed || !_connectionCoordinator.ownsOperation(generation) ||
          profileRevision != _managedProfileRevision) throw const ConnectionOperationSuperseded();
    }
    var selected = cached;
    _candidateNetworkKey = null;
    _candidateOfflineNetworkKey = null;
    if (catalog != null && engine is RuntimeCandidateProbing && cache is CachedManagedProfileBootstrapper) {
      final probing = engine as RuntimeCandidateProbing;
      final service = cache as CachedManagedProfileBootstrapper;
      final cachedWarpAllowed = _explicitWarpRuntimeConsent ?? _warpRuntimeConsent;
      final features = _runtimeSnapshot?.transportCapabilities?.features ?? const <RuntimeTransportFeature>{};
      final available = <String, ManagedProfilePayload>{};
      for (final candidate in catalog.candidates.where((candidate) =>
          (inputs.preferredCandidateRef.isEmpty || candidate.candidateRef == inputs.preferredCandidateRef) &&
          (inputs.preferredCountryCode.isEmpty ||
              candidate.nodeCountryCode(catalog.candidates) == inputs.preferredCountryCode) &&
          (inputs.preferredNodeCode.isEmpty || candidate.nodeCode == inputs.preferredNodeCode) &&
          (candidate.warpMode == null || cachedWarpAllowed))) {
        final profile = await service.loadCachedManagedProfile(inputs,
            selectedCandidateRef: candidate.candidateRef, runtimeFeatures: features);
        requireCurrent();
        if (profile != null) available[candidate.candidateRef] = profile;
      }
      final network = await probing.readCandidateNetwork();
      requireCurrent();
      final key = network.selectionKey;
      final context = network.contextRef;
      if (key == null || key.isEmpty || context == null || context.isEmpty) {
        throw const BootstrapFailure('Не удалось проверить сеть. Попробуйте подключиться ещё раз.', code: 'candidate_network_unavailable');
      }
      _candidateNetworkClass = network.networkClass;
      _candidateCarrierMccMnc = network.mccMnc;
      _candidateCarrierName = network.carrierName;
      _candidateAccessNetworkAsn = null;
      if (recoveryCandidateRef.isEmpty) {
        final remembered = await service.successfulCandidateRef(
            inputs, _offlineCandidateNetworkKey(key, context, network.networkClass));
        requireCurrent();
        if (remembered != null) _candidateSelector.restoreSuccess(key, remembered);
      }
      try {
        selected = await _candidateSelector.select(
          catalog: TransportCandidateCatalog(revision: catalog.revision,
              selectedCandidateRef: catalog.selectedCandidateRef,
              candidates: catalog.candidates.where((candidate) => available.containsKey(candidate.candidateRef)).toList()),
          network: key, platform: inputs.hostPlatform,
          ipv6Available: network.ipv6Available,
          cancelled: _connectionCoordinator.whenOperationEnds(generation),
          recoveryCandidateRef: recoveryCandidateRef, excludedCandidateRefs: excludedCandidateRefs,
          onProbeResult: (candidate, result) {
            if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return;
            final exact = available[candidate.candidateRef];
            _recordCandidateProbe(candidate, result, candidateVariant:
                exact?.materialCandidate?.candidateRef == candidate.candidateRef
                    ? _materialBridgeVariant(exact!) : '');
          },
          probe: (candidate, stop, timeout) async {
            final exact = available[candidate.candidateRef]!;
            final probePayload = exact.copyWith(warpPolicy: candidate.warpMode == null
                ? exact.warpPolicy.withUserConsent(false)
                : exact.warpPolicy.withClientLocalDefaults().copyWith(
                    mode: candidate.warpMode, userConsented: true));
            final checked = await _probeManagedCandidate(probing, probePayload,
                context: context, cancelled: stop, timeout: timeout,
                generation: generation, requireCurrent: requireCurrent);
            return checked.success
                ? SmartConnectCandidateProbeResult.success(exact, duration: checked.duration)
                : SmartConnectCandidateProbeResult.failure(checked.failureKind, duration: checked.duration);
          },
        );
      } on SmartConnectSelectionExhausted {
        throw const BootstrapFailure('Рабочее подключение не найдено. Проверьте сеть и попробуйте ещё раз.',
            code: 'candidate_selection_exhausted', operationalCode: 'CONN-008');
      }
      requireCurrent();
      final currentNetwork = await probing.readCandidateNetwork();
      final currentProfile = await service.loadCachedManagedProfile(inputs,
          selectedCandidateRef: selected.materialCandidate!.candidateRef, runtimeFeatures: features);
      requireCurrent();
      if (currentProfile == null || currentProfile.cacheEntryId != selected.cacheEntryId) {
        throw const BootstrapFailure('Подготовка подключения отменена.', code: 'managed_profile_superseded', statusCode: 409);
      }
      if (currentNetwork.contextRef != context || currentNetwork.selectionKey != key) {
        throw const BootstrapFailure('Сеть изменилась. Подключитесь ещё раз.', code: 'candidate_network_changed');
      }
      _candidatePhysicalNetwork = network;
      _candidateNetworkKey = key;
      _candidateOfflineNetworkKey = _offlineCandidateNetworkKey(key, context, network.networkClass);
    }
    _transportCatalog = selected.transportCatalog;
    _candidateRef = selected.materialCandidate?.candidateRef;
    return selected;
  }

  String _offlineCandidateNetworkKey(String nativeKey, String contextRef, String? networkClass) {
    // Android Wi-Fi keys use a network handle, which can be reused after a reboot.
    // Bind its ASN preference to this network context; cellular has a stable MCC-MNC key.
    if (_appContext.hostPlatform == HostPlatform.android && networkClass != 'cellular') {
      return '$nativeKey:$contextRef';
    }
    return nativeKey;
  }

  ManagedProfileCacheInputs get _managedProfileCacheInputs =>
      ManagedProfileCacheInputs(
        hostPlatform: _appContext.hostPlatform,
        routeMode: _selectedRouteMode,
        selectedApps: _selectedRouteMode == RouteMode.selectedApps ||
                _selectedRouteMode == RouteMode.excludedApps
            ? List<String>.of(_selectedAppIds)
            : const <String>[],
        preferredNodeCode: _clientExperience.interfaceMode == PokrovInterfaceMode.advanced ? _preferredNodeCode : '',
        preferredVariantId: _clientExperience.interfaceMode == PokrovInterfaceMode.advanced ? _preferredVariantId : 'direct',
        preferredCountryCode: _clientExperience.preferredCountryCode,
        preferredCandidateRef: _clientExperience.interfaceMode == PokrovInterfaceMode.advanced ? _clientExperience.preferredCandidateRef : '',
      );

  Future<ManagedProfilePayload> _prepareManagedProfile(
    ManagedProfilePayload payload, {
    bool suppressWarpRuntime = false,
    bool offline = false,
    int? ownerGeneration,
  }) async {
    final generation =
        ownerGeneration ?? _connectionCoordinator.operationGeneration;
    if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
      throw const ConnectionOperationSuperseded();
    }
    final profileRevision = _managedProfileRevision;
    final preparationClock = Stopwatch()..start();
    final catalogAppScopeRequired = _routingCatalogEnabled &&
        _appContext.hostPlatform == HostPlatform.android &&
        _clientExperience.catalogVerifiedRuPreset &&
        (payload.routeMode == RouteMode.selectedApps ||
            payload.routeMode == RouteMode.excludedApps);
    final cancelled = _connectionCoordinator.actionInFlight
        ? _connectionCoordinator.whenOperationEnds(generation)
        : _connectionCoordinator.whenOperationChanges(generation);
    final baseWarpPolicy = payload.warpPolicy.withClientLocalDefaults();
    final warpStatus = offline
        ? null
        : await _fetchWarpStatusOrNull(
            ownerGeneration: generation, cancelled: cancelled);
    if (_disposed ||
        !_connectionCoordinator.ownsOperation(generation) ||
        profileRevision != _managedProfileRevision) {
      throw const ConnectionOperationSuperseded();
    }
    final serverDisplayWarpPolicy =
        warpStatus?.applyTo(baseWarpPolicy) ?? baseWarpPolicy;
    final explicitRetryRequested =
        _warpRuntimeRetryPending && _explicitWarpRuntimeConsent == true;
    final displayWarpPolicy = explicitRetryRequested
        ? serverDisplayWarpPolicy.copyWith(
            state: 'consented',
            userConsented: true,
          )
        : serverDisplayWarpPolicy;
    final reportedConsent = (warpStatus?.consented ?? false) ||
        _warpRuntimeConsent ||
        baseWarpPolicy.userConsented;
    final warpConsentStillValid =
        (_explicitWarpRuntimeConsent ?? reportedConsent) &&
            displayWarpPolicy.canOfferRuntime;
    final selectedWarpMode = payload.materialCandidate?.warpMode;
    final catalogHasWarpCandidates = payload.transportCatalog?.candidates.any(
        (candidate) => candidate.warpMode != null) ?? false;
    final warpRuntimeAttemptEnabled = !suppressWarpRuntime &&
        (!catalogHasWarpCandidates || selectedWarpMode != null) &&
        warpConsentStillValid &&
        (explicitRetryRequested ||
            _warpRuntimeAttemptAllowed(displayWarpPolicy));
    final connectionPreference = _managedProfileCacheInputs;
    final requestedPreferred = connectionPreference.preferredNodeCode.trim().toLowerCase();
    final requestedVariant = requestedPreferred.isEmpty
        ? 'direct'
        : normalizeClientLocationVariantId(connectionPreference.preferredVariantId) ?? 'direct';
    if (requestedPreferred.isNotEmpty &&
        requestedVariant != 'direct' &&
        warpRuntimeAttemptEnabled) {
      throw const BootstrapFailure(
        'WARP пока нельзя использовать с вариантом «Белые списки». Выключите WARP или выберите «Обычный».',
      );
    }
    var runtimePayload = payload.copyWith(
      // A server-reported fallback/error is a circuit breaker, not a cosmetic
      // status. Keep the person's consent visible, but stage the ordinary VPN
      // until they explicitly toggle WARP off and on to retry it.
      warpPolicy: displayWarpPolicy.copyWith(
          mode: selectedWarpMode ?? displayWarpPolicy.mode,
          userConsented: warpRuntimeAttemptEnabled),
      quickSettingsEligible: _appContext.hostPlatform == HostPlatform.android &&
          _clientExperience.firstRouteScopeConfirmed &&
          _clientExperience.firstRouteScopeMode == _selectedRouteMode &&
          !catalogAppScopeRequired,
    );
    late final ManagedProfilePayload configuredPayload;
    var catalogUsingCache = false;
    try {
      CatalogDomainPolicy? catalogPolicy;
      var nativeCatalogWindowVersion = 0;
      var nativeCatalogControlVersion = 0;
      var nativeSmartAccessLeaseVersion = 0;
      final catalogService = _bootstrapper;
      if (_routingCatalogEnabled &&
          catalogService is AppFirstRoutingCatalogService) {
        RoutingCatalogFetchResult? result;
        try {
          result = await (catalogService as AppFirstRoutingCatalogService)
              .fetchRoutingCatalog(
                hostPlatform: _appContext.hostPlatform,
                cacheOnly: offline,
                cancelled: cancelled,
              )
              .timeout(_actionTimeout);
        } on BootstrapFailure catch (error) {
          if ((payload.routeMode != RouteMode.fullTunnel &&
                  payload.routeMode != RouteMode.allExceptRu) ||
              error.statusCode != HttpStatus.serviceUnavailable ||
              (error.code != 'routing_catalog_disabled' &&
                  error.code != 'routing_catalog_unavailable')) {
            rethrow;
          }
        } on RoutingCatalogFailure catch (error) {
          if (!offline || error.code != 'catalog_cache_unavailable' ||
              (payload.routeMode != RouteMode.fullTunnel &&
                  payload.routeMode != RouteMode.allExceptRu)) {
            rethrow;
          }
        }
        if (_disposed ||
            !_connectionCoordinator.ownsOperation(generation) ||
            profileRevision != _managedProfileRevision) {
          throw const ConnectionOperationSuperseded();
        }
        if (catalogAppScopeRequired && result == null) {
          throw const RoutingCatalogFailure('catalog_discovery_unavailable');
        }
        if (result != null) {
          final native = await _withRuntimeActionTimeout(
              'snapshot', _runtimeEngine.snapshot,
              ownerGeneration: generation);
          nativeCatalogWindowVersion = native.routingCatalogWindowVersion;
          nativeCatalogControlVersion = native.routingCatalogControlVersion;
          nativeSmartAccessLeaseVersion = native.smartAccessLeaseVersion;
          final access = payload.freeProfileAccess;
          if (access == null ||
              !access.hasKnownAccessState ||
              !access.isConsistent) {
            throw const RoutingCatalogFailure('catalog_profile_access_invalid');
          }
          final catalogProjection =
              RoutingCatalogPolicy.fromVerified(result.catalog);
          if (catalogAppScopeRequired) {
            final selected = _selectedAppIds.toSet();
            final binding = await const CatalogAndroidDiscovery()
                .inspectDirectCandidates(catalogProjection,
                    accessState: access.accessState, fresh: true);
            if (_disposed ||
                !_connectionCoordinator.ownsOperation(generation) ||
                profileRevision != _managedProfileRevision ||
                !_clientExperience.catalogVerifiedRuPreset ||
                !setEquals(_selectedAppIds.toSet(), selected) ||
                selected.isEmpty ||
                !selected.every((id) =>
                    binding.matchedSigners.containsKey(id) &&
                    binding.matchedLineages.containsKey(id))) {
              throw const RoutingCatalogFailure('catalog_app_scope_changed');
            }
            runtimePayload = runtimePayload.copyWith(
              catalogAppDigest: binding.catalogDigest,
              catalogAppExpiresAt: binding.expiresAt.toUtc().toIso8601String(),
              catalogAppSigners: {
                for (final id in selected) id: binding.matchedSigners[id]!,
              },
              catalogAppLineages: {
                for (final id in selected) id: binding.matchedLineages[id]!,
              },
            );
          }
          final catalogMode = switch (payload.routeMode) {
            RouteMode.selectiveServices => CatalogRoutingMode.selective,
            RouteMode.fullTunnel => CatalogRoutingMode.full,
            RouteMode.allExceptRu => CatalogRoutingMode.smartSafe,
            RouteMode.selectedApps => CatalogRoutingMode.includeApps,
            RouteMode.excludedApps => CatalogRoutingMode.excludeApps,
          };
          CatalogDomainPolicy compile(SmartAccessProfileLeases? leases) =>
              compileCatalogDomainPolicy(
                policy: catalogProjection,
                mode: catalogMode,
                platform: _appContext.hostPlatform.name,
                accessState: access.accessState,
                vpnAvailable: true,
                now: DateTime.now(),
                selectedServiceIds:
                    payload.routeMode == RouteMode.selectiveServices
                        ? _clientExperience
                            .routingPreferences.selectedCatalogServiceIds
                        : const {},
                smartAccessProfile: leases,
              );
          catalogPolicy = compile(null);
          if (!offline &&
              !result.usingCache &&
              const {CatalogRoutingMode.selective, CatalogRoutingMode.smartSafe}.contains(catalogMode) &&
              nativeSmartAccessLeaseVersion == 1 &&
              catalogService is AppFirstSmartAccessService &&
              (catalogService as AppFirstSmartAccessService)
                  .smartAccessEnabled) {
            final wanted = catalogProjection.services
                .where((service) =>
                    (catalogMode != CatalogRoutingMode.selective ||
                     catalogPolicy!.selectedServiceIds.contains(service.id)) &&
                    service.intents[catalogMode] ==
                        CatalogRouteAction.approvedGateway)
                .map((service) => service.id)
                .toSet();
            if (wanted.isNotEmpty) {
              bool current() =>
                  !_disposed &&
                  _connectionCoordinator.ownsOperation(generation) &&
                  profileRevision == _managedProfileRevision &&
                  preparationClock.elapsed < _actionTimeout;
              Duration remaining() {
                if (preparationClock.elapsed >= _actionTimeout) {
                  throw const RoutingCatalogFailure(
                      'smart_access_budget_exhausted');
                }
                if (!current()) throw const ConnectionOperationSuperseded();
                return _actionTimeout - preparationClock.elapsed;
              }

              bool authorityUnavailable(BootstrapFailure error) =>
                  error.code == 'smart_access_admission_paused' ||
                  (error.statusCode == null &&
                      error.operationalCode == 'API-002') ||
                  const {
                    HttpStatus.requestTimeout,
                    HttpStatus.tooManyRequests,
                    HttpStatus.badGateway,
                    HttpStatus.serviceUnavailable,
                    HttpStatus.gatewayTimeout
                  }.contains(error.statusCode);
              VerifiedSmartAccessProviderPolicy? providers;
              try {
                providers = await (catalogService as AppFirstSmartAccessService)
                    .fetchSmartAccessProviders(
                        hostPlatform: _appContext.hostPlatform,
                        operationIsCurrent: current,
                        remainingBudget: remaining(),
                        cancelled: cancelled);
              } on BootstrapFailure catch (error) {
                if (!authorityUnavailable(error)) rethrow;
                remaining();
                // The catalog already declares a protected per-service fallback.
                // An unavailable authority does not prove that a provider failed.
              }
              final grants = <VerifiedSmartAccessLease>[];
              if (providers != null) {
                final candidates =
                    await _connectionCoordinator.selectSmartAccessCapabilities(
                        catalog: result.catalog,
                        providers: providers,
                        serviceIds: wanted,
                        platform: _appContext.hostPlatform.name,
                        now: DateTime.now(),
                        isCurrent: current);
                remaining();
                final digest = await smartAccessProfileSha256(
                    runtimePayload.configPayload);
                for (final candidate in candidates) {
                  try {
                    grants.add(await (catalogService
                            as AppFirstSmartAccessService)
                        .requestSmartAccessLease(
                            hostPlatform: _appContext.hostPlatform,
                            catalog: result.catalog,
                            providerPolicy: providers,
                            capabilityId: candidate['capability_id']! as String,
                            profileSha256: digest,
                            origin: candidate['origin']! as String,
                            family: candidate['family']! as String,
                            feature: candidate['feature']! as String,
                            routeMode: catalogMode == CatalogRoutingMode.smartSafe ? 'smart_safe' : 'selective',
                            operationIsCurrent: current,
                            remainingBudget: remaining(),
                            cancelled: cancelled));
                  } on BootstrapFailure catch (error) {
                    if (!authorityUnavailable(error)) rethrow;
                    remaining();
                    if (error.code.startsWith('smart_access_')) grants.clear();
                    // No repeated requests to the same unavailable/rate-limited
                    // authority. Remaining services keep their declared fallback.
                    break;
                  }
                }
              }
              remaining();
              if (grants.isNotEmpty) {
                final bound = await SmartAccessProfileLeases.bind(
                    baseProfile: runtimePayload.configPayload, leases: grants,
                    routeMode: catalogMode == CatalogRoutingMode.smartSafe ? 'smart_safe' : 'selective');
                if (!current()) throw const ConnectionOperationSuperseded();
                catalogPolicy = compile(bound);
              }
            }
          }
          catalogUsingCache = result.usingCache;
        }
      }
      if (_disposed ||
          !_connectionCoordinator.ownsOperation(generation) ||
          profileRevision != _managedProfileRevision) {
        throw const ConnectionOperationSuperseded();
      }
      configuredPayload = applyPokrovRoutingPreferences(
        runtimePayload,
        _clientExperience.routingPreferences,
        hostPlatform: _appContext.hostPlatform,
        catalogPolicy: catalogPolicy,
        nativeCatalogWindowVersion: nativeCatalogWindowVersion,
        nativeSmartAccessLeaseVersion: nativeSmartAccessLeaseVersion,
        defaultRuAppPackageIds: _appContext.hostPlatform == HostPlatform.android
            ? pokrovRuAppCatalog.map((entry) => entry.packageId).toList()
            : const <String>[],
      );
      final grants = catalogPolicy?.smartAccessProfile?.byService.values
          .expand((group) => group);
      if (catalogPolicy != null &&
          catalogPolicy.rules
              .any((rule) => rule.action != CatalogRouteAction.block)) {
        if (catalogService is! AppFirstSmartAccessService ||
            !(catalogService as AppFirstSmartAccessService)
                .smartAccessControlAvailable) {
          throw const RoutingCatalogFailure(
              'catalog_control_trust_unconfigured');
        }
        if (nativeCatalogControlVersion != 4) {
          throw const RoutingCatalogFailure(
              'catalog_native_control_unsupported');
        }
        _preparedCatalogPolicies[configuredPayload] = catalogPolicy;
      }
      if (grants != null && grants.isNotEmpty) {
        _preparedSmartAccessGrants[configuredPayload] =
            List.unmodifiable(grants);
      }
    } on RoutingCatalogFailure catch (error) {
      throw BootstrapFailure(
          switch (error.code) {
            'catalog_native_window_unsupported' ||
            'catalog_native_control_unsupported' ||
            'smart_access_native_unsupported' =>
              'Для этих правил нужно обновить модуль подключения.',
            'smart_access_budget_exhausted' =>
              'Подготовка маршрута сервиса заняла слишком долго. Повторите подключение.',
            'catalog_process_scope_invalid' =>
              'Не удалось применить выбор EXE. Повторно выберите приложения.',
            'catalog_process_dns_transport_unsupported' =>
              'Для выбора приложений в Windows включите DNS через VPN.',
            'catalog_gateway_lease_missing' =>
              'Для этого режима ещё не подготовлен маршрут сервиса.',
            _ =>
              'Правила подключения недоступны. Обновите их и повторите попытку.',
          },
          code: error.code,
          operation: 'routing_catalog');
    }
    if (!_disposed) {
      final resolvedAutomatic = payload.resolvedNodeCode.trim().toLowerCase();
      // Server stickiness is an automatic routing hint, not proof of a manual
      // choice or of the profile actually staged on this device. Only the
      // authoritative resolved code may later identify a failed auto node.
      _update(() {
        _managedWarpPolicy = displayWarpPolicy.withUserConsent(
          warpConsentStillValid,
        );
        _warpRuntimeRetryPending = false;
        _freeProfileAccess = payload.freeProfileAccess;
        _warpRuntimeConsent = warpConsentStillValid;
        _smartConnectProfile = payload.smartConnect;
        _preferredNodeCode = requestedPreferred;
        _resolvedProfileNodeCode = payload.transportCatalog != null ? resolvedAutomatic
            : requestedPreferred.isNotEmpty ? requestedPreferred : resolvedAutomatic;
        _resolvedProfileVariantId =
            requestedPreferred.isNotEmpty ? requestedVariant : 'direct';
        // Consumer copy: no infra hostnames on the first layer.
        _runtimeHeadline = catalogUsingCache
            ? 'Настройки готовы. Используем сохранённые правила сервисов.'
            : 'Настройки обновлены.';
      });
    }
    return configuredPayload;
  }

  bool _warpRuntimeAttemptAllowed(WarpRuntimePolicy policy) {
    final state = policy.state.trim().toLowerCase();
    return !const <String>{
      'fallback',
      'baseline_fallback',
      'degraded',
      'error',
      'failed',
      'runtime_error',
    }.contains(state);
  }

  Duration get _cachedProfileRefreshDeadline {
    return CachedProfileFallbackGate.refreshDeadline(
      _actionTimeout,
    );
  }

  bool _hasFreshCachedManagedProfile(String? path) {
    final normalizedPath = path?.trim() ?? '';
    if (normalizedPath.isEmpty) {
      return false;
    }
    try {
      final file = File(normalizedPath);
      if (!file.existsSync()) {
        return false;
      }
      if (!CachedProfileFallbackGate.isCacheTimestampFresh(
        modifiedAt: file.lastModifiedSync(),
        now: DateTime.now(),
      )) {
        return false;
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        return false;
      }
      return _runtimeConfigMap(decoded)['outbounds'] is List;
    } on Object {
      return false;
    }
  }

  Future<RuntimeSnapshot> _migrateCachedAndroidManagedProfile(
      RuntimeSnapshot snapshot,
      {required int ownerGeneration}) async {
    final profileRevision = _managedProfileRevision;
    final path = snapshot.stagedConfigPath?.trim() ?? '';
    if (path.isEmpty) {
      return snapshot;
    }
    try {
      final raw = await File(path).readAsString();
      if (_disposed ||
          !_connectionCoordinator.ownsOperation(ownerGeneration) ||
          profileRevision != _managedProfileRevision) {
        throw const ConnectionOperationSuperseded();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return snapshot;
      }
      final config = _runtimeConfigMap(decoded);
      final dns = _runtimeConfigMap(config['dns']);
      final rawServers = dns['servers'];
      if (rawServers is! List) {
        return snapshot;
      }
      var changed = false;
      var localServerTag = '';
      final servers = rawServers.map((rawServer) {
        final server = _runtimeConfigMap(rawServer);
        final isLegacyLocal =
            (server['address'] ?? '').toString().trim().toLowerCase() ==
                'local';
        final isTypedLocal =
            (server['type'] ?? '').toString().trim().toLowerCase() == 'local';
        if (isLegacyLocal) {
          server['type'] = 'local';
          server.remove('address');
          server.remove('address_resolver');
          changed = true;
        }
        if (isLegacyLocal || isTypedLocal) {
          localServerTag = (server['tag'] ?? '').toString().trim();
        }
        return server;
      }).toList(growable: false);
      final rawOutbounds = config['outbounds'];
      if (localServerTag.isNotEmpty && rawOutbounds is List) {
        config['outbounds'] = rawOutbounds.map((rawOutbound) {
          final outbound = _runtimeConfigMap(rawOutbound);
          final server = (outbound['server'] ?? '').toString().trim();
          if (server.isNotEmpty &&
              InternetAddress.tryParse(server) == null &&
              outbound['domain_resolver'] != localServerTag) {
            outbound['domain_resolver'] = localServerTag;
            changed = true;
          }
          return outbound;
        }).toList(growable: false);
      }
      dns['servers'] = servers;
      config['dns'] = dns;
      final basePayload = ManagedProfilePayload(
        profileName: 'pokrov-cached-android',
        configPayload: jsonEncode(config),
        materializedForRuntime: true,
        routeMode: _selectedRouteMode,
      );
      if (!changed) {
        return snapshot;
      }
      return await _withRuntimeActionTimeout(
        'migrateCachedAndroidProfile',
        () => _stageManagedProfileWithLeaseBinding(
          basePayload,
        ),
        ownerGeneration: ownerGeneration,
      );
    } on ConnectionOperationSuperseded {
      rethrow;
    } on Object {
      return snapshot;
    }
  }

  bool _isTransientProfileFailure(BootstrapFailure error) {
    if (error.operation == 'routing_catalog' || error.code.startsWith('candidate_') ||
        error.code == 'managed_profile_superseded') return false;
    final statusCode = error.statusCode;
    return statusCode == null ||
        statusCode == HttpStatus.requestTimeout ||
        statusCode == HttpStatus.tooManyRequests ||
        statusCode == HttpStatus.badGateway ||
        statusCode == HttpStatus.serviceUnavailable ||
        statusCode == HttpStatus.gatewayTimeout;
  }

  Future<String?> _classifyOfflineFailure(int generation) async {
    final service = _bootstrapper;
    if (service is! CachedManagedProfileBootstrapper) return null;
    final engine = _runtimeEngine;
    try {
      final network = engine is RuntimeNetworkAvailability
          ? await (engine as RuntimeNetworkAvailability).readNetworkAvailability()
              .timeout(const Duration(seconds: 2), onTimeout: () => const RuntimeNetworkStatusObservation())
          : const RuntimeNetworkStatusObservation();
      final state = await (service as CachedManagedProfileBootstrapper).classifyManagedProfileFailure(
        _managedProfileCacheInputs, networkAvailable: network.networkAvailable,
        captivePortal: network.captivePortal);
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return null;
      _offlineState = state;
      return switch (state) {
        ManagedProfileOfflineState.noNetwork => 'Нет сети. Подключитесь к Wi-Fi или мобильному интернету.',
        ManagedProfileOfflineState.captivePortal => 'Войдите в сеть Wi-Fi, затем повторите подключение.',
        ManagedProfileOfflineState.accessEnded => 'Срок доступа истёк. Подключитесь к сети и продлите доступ.',
        ManagedProfileOfflineState.apiUnavailable => 'Сервис настроек временно недоступен. Попробуйте ещё раз.',
      };
    } on Object { return null; }
  }

  Map<String, dynamic> _runtimeConfigMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return <String, dynamic>{};
  }

  Future<WarpControlStatus?> _fetchWarpStatusOrNull({
    required int ownerGeneration,
    required Future<void> cancelled,
  }) async {
    final service = _warpActionService;
    if (service == null) {
      return null;
    }
    try {
      return await service.fetchWarpStatus(
        hostPlatform: _appContext.hostPlatform,
        cancelled: cancelled,
      );
    } on BootstrapFailure catch (error) {
      if (_disposed || !_connectionCoordinator.ownsOperation(ownerGeneration)) {
        throw const ConnectionOperationSuperseded();
      }
      if (!_disposed && error.statusCode != null) {
        _update(() {
          _runtimeHeadline = error.message;
        });
      }
      return null;
    }
  }

  Future<void> _setWarpRuntimeConsent(bool value) async {
    if (_warpPolicyBusy) {
      return;
    }
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    final localPolicy = _managedWarpPolicy.withClientLocalDefaults();
    final requestedEnabled = value && localPolicy.canOfferRuntime;
    _update(() {
      _warpPolicyBusy = true;
      _managedWarpPolicy = localPolicy;
      // Apply the person's choice before awaiting the server. A stale status
      // or managed profile can arrive while that request is in flight.
      _explicitWarpRuntimeConsent = requestedEnabled;
    });
    try {
      final service = _warpActionService;
      var status = WarpControlStatus.fromPolicy(localPolicy).copyWith(
        consented: requestedEnabled,
        canEnable: !requestedEnabled,
        state: requestedEnabled ? 'consented' : 'revoked',
        source: localPolicy.source,
      );
      if (service != null) {
        try {
          status = await service.setWarpConsent(
            hostPlatform: _appContext.hostPlatform,
            enabled: requestedEnabled,
            reasonCode: requestedEnabled ? 'user_consented' : 'user_disabled',
          );
        } on BootstrapFailure {
          status = status.copyWith(
            state: requestedEnabled ? 'consented_local' : 'revoked',
            source: 'client_local',
          );
        } on Object {
          status = status.copyWith(
            state: requestedEnabled ? 'consented_local' : 'revoked',
            source: 'client_local',
          );
        }
      }
      final servicePolicy = status.applyTo(localPolicy);
      final nextPolicy = requestedEnabled
          ? servicePolicy.copyWith(
              userConsented: true,
              state: 'consented',
              source: servicePolicy.hasServerManagedMaterial
                  ? servicePolicy.source
                  : 'client_local',
            )
          : localPolicy.copyWith(
              state: 'revoked',
              userConsented: false,
              mode: servicePolicy.mode,
              source: 'client_local',
            );
      final enabled = requestedEnabled && nextPolicy.canOfferRuntime;
      if (_disposed) {
        return;
      }
      _update(() {
        _managedWarpPolicy = nextPolicy;
        _warpRuntimeConsent = enabled;
        _warpRuntimeRetryPending = enabled;
        _managedProfileDirty = true;
        _cachedProfileFallbackGate.markUserChange();
        _runtimeHeadline = wasConnected
            ? enabled
                ? 'Включаем WARP…'
                : 'Выключаем WARP…'
            : enabled
                ? 'WARP включится при следующем подключении.'
                : 'WARP выключен для следующих подключений.';
      });
      _invalidateQuickSettingsProfile();
      if (wasConnected) {
        await _reconnectAfterManagedProfileChange(
          progressMessage: enabled ? 'Включаем WARP…' : 'Выключаем WARP…',
          successMessage: enabled ? 'WARP включён.' : 'WARP выключен.',
        );
      }
    } on BootstrapFailure catch (error) {
      if (_disposed) {
        return;
      }
      _update(() {
        _runtimeHeadline = error.message;
      });
      _notify(error.message, tone: PokrovSnackTone.danger);
    } finally {
      if (!_disposed) {
        _update(() {
          _warpPolicyBusy = false;
        });
      }
    }
  }

  void _invalidateQuickSettingsProfile() {
    _connectionCoordinator.invalidateTransportRoutingIntent();
    _managedProfileLifecycle.invalidate();
  }

  Future<bool> _waitForQuickSettingsInvalidation(int revision) =>
      _managedProfileLifecycle.waitForInvalidation(revision);

  Future<void> _toggleRuntime({bool reconnectAfterDisconnect = false}) {
    final observability = _observability;
    if (observability == null || _runtimeBusy) {
      return _toggleRuntimeObserved(
        reconnectAfterDisconnect: reconnectAfterDisconnect,
      );
    }
    final beginsWithDisconnect =
        _runtimeSnapshot?.phase == RuntimePhase.running;
    return observability.runConnectionAction(
      () async {
        try {
          await _toggleRuntimeObserved(
            reconnectAfterDisconnect: reconnectAfterDisconnect,
          );
        } finally {
          observability.observeConnection(_connectionExperience);
        }
      },
      beginsWithDisconnect: beginsWithDisconnect,
    );
  }

  Future<void> _toggleRuntimeObserved({
    bool reconnectAfterDisconnect = false,
  }) async {
    final startingGeneration = _connectionCoordinator.operationGeneration;
    final command = _commandNumber;
    if (_runtimeBusy) {
      if (_connectionCoordinator.canCancelPrimaryConnect) {
        await _cancelPrimaryConnect();
        return;
      }
      _update(() {
        _runtimeHeadline = 'POKROV уже обновляется. Подождите немного.';
      });
      return;
    }
    _cancelPostConnectHostHealthPolling();

    _stopTransportPolicyRefresh();
    if (_runtimeSnapshot?.phase != RuntimePhase.running &&
        !await _authorizeWindowsTunnelConnect()) {
      return;
    }

    // Permission/scope sheets yield to the event loop. Another action can
    // acquire the single runtime owner while they are open.
    if (_disposed ||
        _runtimeBusy ||
        command != _commandNumber ||
        !_connectionCoordinator.ownsOperation(startingGeneration)) return;

    final actionIntent = _runtimeSnapshot?.phase == RuntimePhase.running
        ? reconnectAfterDisconnect
            ? ConnectionTransitionIntent.reconnect
            : ConnectionTransitionIntent.disconnect
        : ConnectionTransitionIntent.connect;
    _update(() {
      _activePhase = actionIntent == ConnectionTransitionIntent.reconnect
          ? ConnectionPhase.recovering
          : actionIntent == ConnectionTransitionIntent.disconnect
              ? null
              : ConnectionPhase.preparing;
      _connectionCoordinator.beginAction(
        actionIntent,
        recordAttempt: actionIntent == ConnectionTransitionIntent.connect,
        allowConnectCancellation: const {
              HostPlatform.android,
              HostPlatform.windows,
              HostPlatform.linux
            }.contains(_appContext.hostPlatform) &&
            _runtimeEngine is RuntimeConnectCancellation,
        onSlowStage: _handleSlowConnectionStage,
      );
    });
    if (actionIntent != ConnectionTransitionIntent.disconnect) {
      _candidateRef = null;
      _candidateNetworkClass = null;
      _candidateCarrierMccMnc = null;
      _candidateCarrierName = null;
      _candidateAccessNetworkAsn = null;
    }
    if (actionIntent == ConnectionTransitionIntent.connect) {
      unawaited(_reportClientLifecycle('connect_requested'));
    }
    final generation = _connectionCoordinator.operationGeneration;
    Future<T> runOwnedRuntimeAction<T>(
      String operation,
      Future<T> Function() action,
    ) =>
        _withRuntimeActionTimeout(operation, action,
            ownerGeneration: generation);
    final completion = Completer<void>();
    if (actionIntent != ConnectionTransitionIntent.disconnect) {
      _primaryConnectCompletion = completion;
    }
    var failureOperation = 'snapshot';
    var failureStage = ConnectionStage.profile;
    try {
      RuntimeSnapshot snapshot = _runtimeSnapshot ??
          await runOwnedRuntimeAction('snapshot', _runtimeEngine.snapshot);
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        return;
      }

      // Restored staged profiles skip initialize; selection still needs the
      // current host inventory rather than a missing pre-action snapshot.
      _runtimeSnapshot = snapshot;
      if ((_protectedHandoffActive &&
              (actionIntent == ConnectionTransitionIntent.connect || reconnectAfterDisconnect)) ||
          (reconnectAfterDisconnect && snapshot.phase == RuntimePhase.running &&
              _runtimeEngine is RuntimeProtectedHandoff &&
              !(_bootstrapper is AppFirstTransportManifestService &&
                  (_bootstrapper as AppFirstTransportManifestService).transportManifestEnabled))) {
        await _recoverCandidateConnection(snapshot, _activeCandidateRef ?? _candidateRef ?? '',
            ownerGeneration: generation);
        return;
      }

      if (snapshot.phase == RuntimePhase.running) {
        if (_runtimeIntent == ConnectionTransitionIntent.connect) {
          // The pre-busy guess was made without a snapshot; fix the copy
          // before the disconnect actually starts.
          _update(() {
            _runtimeIntent = reconnectAfterDisconnect
                ? ConnectionTransitionIntent.reconnect
                : ConnectionTransitionIntent.disconnect;
          });
        }
        var current = await runOwnedRuntimeAction(
          'disconnect',
          _runtimeEngine.disconnect,
        );
        current = await _settleRuntimeDisconnectTransition(
          current,
          ownerGeneration: generation,
        );
        if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
          return;
        }
        _update(() {
          _runtimeSnapshot = current;
          _runtimeHeadline = current.phase != RuntimePhase.running &&
                  current.lastFailureKind == null
              ? null
              : current.message;
        });
        if (!_runtimeStopConfirmed(current)) {
          throw const BootstrapFailure(
              'Остановка прежнего подключения не подтверждена. Проверьте состояние POKROV.');
        }
        _protectedHandoffActive = false;
        _activeCandidateRef = null;
        if (!reconnectAfterDisconnect) {
          _recordProtectionEvent(
            kind: 'disconnected',
            title: 'Защита выключена',
            detail: 'Туннель остановлен по действию пользователя.',
            tone: PokrovProtectionEventTone.neutral,
          );
          _activeConnectUsedWarp = false;
          return;
        }
        snapshot = current;
      }

      if (_subscriptionInfo?.lane == 'expiredOrBlocked') {
        final refreshedSubscription = await _refreshSubscriptionInfo();
        if (_disposed || !_connectionCoordinator.ownsOperation(generation))
          return;
        if (refreshedSubscription && _subscriptionInfo?.lane == 'expiredOrBlocked') {
          _update(() {
            _runtimeHeadline =
                'Доступ не активен. Продлите доступ, чтобы подключиться.';
          });
          return;
        }
      }

      failureOperation = 'trusted_wifi';
      if (await _blockConnectOnTrustedWifi(ownerGeneration: generation)) {
        return;
      }

      if (!_canPrimaryConnect(snapshot)) {
        _update(() {
          _runtimeHeadline =
              'На этом устройстве еще нужно завершить подготовку.';
        });
        return;
      }

      // A user-owned route, location, app, or WARP change clears the host
      // reusable profile first. Do not let a fresh stage race that clear.
      failureOperation = 'profile_invalidation';
      final invalidated = await _waitForQuickSettingsInvalidation(
        _managedProfileRevision,
      );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        return;
      }
      if (!invalidated) {
        _update(() {
          _runtimeHeadline =
              'Не удалось обновить настройки для быстрого подключения. Попробуйте ещё раз.';
        });
        return;
      }
      final profileRevision = _managedProfileRevision;

      RuntimeSnapshot current = snapshot;
      var usedCachedProfile = false;

      if (current.canInitialize &&
          current.phase == RuntimePhase.artifactReady) {
        failureOperation = 'core_initialize';
        failureStage = ConnectionStage.coreStart;
        current = await runOwnedRuntimeAction(
          'initialize',
          _runtimeEngine.initialize,
        );
        if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
          return;
        }
        _update(() {
          _runtimeSnapshot = current;
          _runtimeHeadline = null;
        });
        if (!const {
          RuntimePhase.initialized,
          RuntimePhase.configStaged,
          RuntimePhase.running,
        }.contains(current.phase)) {
          throw const BootstrapFailure(
            'Запуск POKROV Core не подтверждён. Попробуйте подключиться ещё раз.',
            operation: 'initialize',
            code: 'core_initialize_unconfirmed',
          );
        }
      }

      final transportService = _bootstrapper;
      if (transportService is AppFirstTransportManifestService &&
          (transportService as AppFirstTransportManifestService)
              .transportManifestEnabled &&
          (_selectedRouteMode == RouteMode.fullTunnel ||
              (_selectedRouteMode == RouteMode.allExceptRu &&
                  const {HostPlatform.android, HostPlatform.windows}
                      .contains(_appContext.hostPlatform)) ||
              (_selectedRouteMode == RouteMode.selectiveServices &&
                  const {HostPlatform.android, HostPlatform.windows}
                      .contains(_appContext.hostPlatform)) ||
              (const {RouteMode.selectedApps, RouteMode.excludedApps}
                      .contains(_selectedRouteMode) &&
                  _appContext.hostPlatform == HostPlatform.android &&
                  (!_routingCatalogEnabled ||
                      !_clientExperience.catalogVerifiedRuPreset)))) {
        failureOperation = 'transport_manifest_connect';
        failureStage = ConnectionStage.profile;
        if (_runtimeEngine is! RuntimeBoundConnectivityProbe) {
          _transportSelectionFail('transport_runtime_unavailable');
        }
        if (!_foregroundAutoConnect && !await _authorizeAndroidVpnConnect()) return;
        if (_disposed || !_connectionCoordinator.ownsOperation(generation))
          return;
        final proven = await _connectWithTransportManifest(current, generation);
        if (_disposed || !_connectionCoordinator.ownsOperation(generation))
          return;
        _finishAndroidVpnPermission(proven);
        _update(() {
          _runtimeSnapshot = proven;
          _managedProfileDirty = false;
          _runtimeHeadline = proven.isCleanlyHealthy
              ? 'POKROV подключен.'
              : 'Туннель запущен, проверка защиты не завершена.';
        });
        if (proven.isCleanlyHealthy) _finalizeProvenConnection(proven);
        _startTransportPolicyRefresh();
        return;
      }

      final cacheInputs = _managedProfileCacheInputs;
      final cacheService = _bootstrapper is CachedManagedProfileBootstrapper
          ? _bootstrapper as CachedManagedProfileBootstrapper
          : null;
      Future<ManagedProfilePayload?> readCache() async {
        if (_disposed ||
            !_connectionCoordinator.ownsOperation(generation) ||
            profileRevision != _managedProfileRevision) {
          throw const ConnectionOperationSuperseded();
        }
        final cached = cacheService != null &&
                !_automaticFailoverInFlight &&
                _tcpFallbackFromRevision.isEmpty
            ? await cacheService
                .loadCachedManagedProfile(
                  cacheInputs,
                  preferProven: _cachedProfileFallbackGate.preferProvenProfile,
                  runtimeFeatures: current.transportCapabilities?.features ?? const {},
                )
                .timeout(const Duration(seconds: 2), onTimeout: () => null)
            : null;
        if (_disposed ||
            !_connectionCoordinator.ownsOperation(generation) ||
            profileRevision != _managedProfileRevision) {
          throw const ConnectionOperationSuperseded();
        }
        return cached;
      }

      var cachedPayload = await readCache();
      final cachedProfileAvailable = cacheService == null
          ? _hasFreshCachedManagedProfile(current.stagedConfigPath)
          : cachedPayload != null;
      final cachedProfileFallbackAllowed =
          _cachedProfileFallbackGate.canFallback(
                  cachedProfileAvailable: cachedProfileAvailable,
                  inputsVerified: cachedPayload != null) &&
              !_automaticFailoverInFlight &&
              _tcpFallbackFromRevision.isEmpty;
      final initialProfilePreparation = !cachedProfileAvailable &&
          (current.stagedConfigPath?.trim().isEmpty ?? true) &&
          cacheInputs.preferredNodeCode.trim().isEmpty &&
          cacheInputs.preferredCandidateRef.trim().isEmpty &&
          cacheInputs.preferredVariantId == 'direct' &&
          actionIntent == ConnectionTransitionIntent.connect &&
          !_automaticFailoverInFlight && _tcpFallbackFromRevision.isEmpty &&
          const {HostPlatform.android, HostPlatform.windows}
              .contains(_appContext.hostPlatform);
      if (cacheService == null &&
          cachedProfileAvailable &&
          _appContext.hostPlatform == HostPlatform.android) {
        failureOperation = 'cached_profile_migration';
        failureStage = ConnectionStage.profile;
        current = await _migrateCachedAndroidManagedProfile(current,
            ownerGeneration: generation);
        if (_disposed ||
            !_connectionCoordinator.ownsOperation(generation) ||
            profileRevision != _managedProfileRevision) {
          throw const ConnectionOperationSuperseded();
        }
      }

      final shouldRefreshManagedProfile = _managedProfileDirty ||
          (current.stagedConfigPath ?? '').isEmpty ||
          ((_appContext.hostPlatform == HostPlatform.android ||
                  _appContext.hostPlatform == HostPlatform.windows) &&
              (actionIntent == ConnectionTransitionIntent.connect ||
                  actionIntent == ConnectionTransitionIntent.reconnect));
      if (shouldRefreshManagedProfile) {
        ManagedProfilePayload? managedProfile;
        try {
          failureOperation = 'managed_profile_refresh';
          failureStage = ConnectionStage.profile;
          managedProfile = await _resolveManagedProfile(
            ownerGeneration: generation,
            deadline: cachedProfileFallbackAllowed
                ? _cachedProfileRefreshDeadline
                : initialProfilePreparation
                    ? const Duration(seconds: 40) : _actionTimeout,
          );
        } on TimeoutException {
          if (!cachedProfileFallbackAllowed ||
              !_cachedProfileFallbackGate.canFallback(
                cachedProfileAvailable: cachedProfileAvailable,
                inputsVerified: cachedPayload != null,
              )) {
            rethrow;
          }
          cachedPayload = await readCache();
          if (cacheService != null && cachedPayload == null) rethrow;
          usedCachedProfile = true;
        } on BootstrapFailure catch (error) {
          if (error.statusCode == 401 || error.statusCode == 403) {
            _cachedProfileFallbackGate.markAuthorizationDenied();
          }
          if (!cachedProfileFallbackAllowed ||
              !_cachedProfileFallbackGate.canFallback(
                cachedProfileAvailable: cachedProfileAvailable,
                inputsVerified: cachedPayload != null,
              ) ||
              !_isTransientProfileFailure(error)) {
            rethrow;
          }
          cachedPayload = await readCache();
          if (cacheService != null && cachedPayload == null) rethrow;
          usedCachedProfile = true;
        }
        if (usedCachedProfile) await _classifyOfflineFailure(generation);
        if (usedCachedProfile && cachedPayload != null) {
          // Restore from the protected original, including after process restart
          // or a host clear. Restaging must not renew the cache timestamp.
          cachedPayload = await _resolveCachedCandidateProfile(cacheInputs, cachedPayload, generation: generation);
          managedProfile = await _prepareManagedProfile(cachedPayload,
              offline: true, ownerGeneration: generation);
        }
        final resolvedProfile = managedProfile;
        if (resolvedProfile != null) {
          // A stage timeout has an unknown mutation outcome and cannot fall
          // through to connect using the previous snapshot.
          failureOperation = 'managed_profile_stage';
          current = await runOwnedRuntimeAction(
            'stageManagedProfile',
            () => _stageManagedProfileWithLeaseBinding(resolvedProfile),
          );
          if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
            return;
          }
          if (profileRevision != _managedProfileRevision) {
            _update(() {
              _runtimeSnapshot = current;
              _managedProfileDirty = true;
              _runtimeHeadline =
                  'Настройки изменились. Подключитесь еще раз, чтобы обновить профиль.';
            });
            return;
          }
          _update(() {
            _runtimeSnapshot = current;
            _runtimeHeadline = null;
            _managedProfileDirty = false;
            _stagedProfileUsesWarp =
                resolvedProfile.warpPolicy.canEnableRuntime;
            _stagedTcpFallbackFromRevision =
                resolvedProfile.tcpFallbackFromRevision;
            _stagedNodeCode = _resolvedProfileNodeCode;
            _stagedVariantId = _resolvedProfileVariantId;
            _rememberStagedCandidateVariant(resolvedProfile, generation);
            _stagedCacheInputs = cacheInputs;
            _stagedProfileCacheEntryId = resolvedProfile.cacheEntryId;
            if (!usedCachedProfile) {
              _cachedProfileFallbackGate.markFreshProfileStaged();
            }
          });
        }
      }

      if ((current.stagedConfigPath ?? '').isNotEmpty || current.canConnect) {
        failureOperation = 'vpn_permission';
        failureStage = ConnectionStage.permission;
        if (!_foregroundAutoConnect && !await _authorizeAndroidVpnConnect()) {
          return;
        }
        if (actionIntent == ConnectionTransitionIntent.connect) {
          unawaited(
            _reportFirstSessionEvent(
              'connect_requested',
              stage: 'connect',
              result: 'started',
            ),
          );
        }
        final warpRuntimeAttempted =
            _warpRuntimeConsent && _stagedProfileUsesWarp;
        _activeConnectUsedWarp = warpRuntimeAttempted;
        failureOperation = 'core_connect';
        failureStage = ConnectionStage.coreStart;
        _setPhase(ConnectionPhase.activating, generation);
        current = await runOwnedRuntimeAction(
          'connect',
          _runtimeEngine.connect,
        );
        failureOperation = 'tunnel_settle';
        failureStage = ConnectionStage.tunnel;
        current = await _settleRuntimeTransition(
          current,
          ownerGeneration: generation,
        );
        if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
          return;
        }
        _finishAndroidVpnPermission(current);
        var warpFallbackUsed = false;
        if (_transportCatalog == null && current.phase != RuntimePhase.running && warpRuntimeAttempted) {
          final fallback = await runOwnedRuntimeAction(
            'applyWarpFallback',
            () => _runtimeEngine.applyWarp(enabled: false),
          );
          if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
            return;
          }
          var baselineReady = fallback.applied;
          if (!baselineReady &&
              fallback.reason == 'smart_access_restage_required') {
            if (profileRevision != _managedProfileRevision) {
              throw const ConnectionOperationSuperseded();
            }
            final baselineProfile = await _resolveManagedProfile(
                deadline: _actionTimeout,
                suppressWarpRuntime: true,
                ownerGeneration: generation);
            current = await runOwnedRuntimeAction('stageWarpFallbackProfile',
                () => _stageManagedProfileWithLeaseBinding(baselineProfile));
            if (_disposed || !_connectionCoordinator.ownsOperation(generation))
              return;
            baselineReady = current.canConnect;
            if (baselineReady) {
              _stagedTcpFallbackFromRevision =
                  baselineProfile.tcpFallbackFromRevision;
              _stagedNodeCode = _resolvedProfileNodeCode;
              _stagedVariantId = _resolvedProfileVariantId;
              _rememberStagedCandidateVariant(baselineProfile, generation);
              _stagedCacheInputs = _managedProfileCacheInputs;
              _stagedProfileCacheEntryId = baselineProfile.cacheEntryId;
              _managedProfileDirty = false;
            }
          }
          if (baselineReady) {
            _activeConnectUsedWarp = false;
            _update(() {
              _stagedProfileUsesWarp = false;
              _managedWarpPolicy = _managedWarpPolicy.copyWith(
                state: 'fallback',
                userConsented: true,
              );
              _runtimeHeadline =
                  'WARP временно недоступен. Подключаем обычный VPN…';
            });
            current = await runOwnedRuntimeAction(
              'connectWithoutWarp',
              _runtimeEngine.connect,
            );
            current = await _settleRuntimeTransition(
              current,
              ownerGeneration: generation,
            );
            if (_disposed ||
                !_connectionCoordinator.ownsOperation(generation)) {
              return;
            }
            warpFallbackUsed = current.phase == RuntimePhase.running;
            unawaited(_reportWarpRuntimeFallback(current));
          }
        }
        if (current.phase == RuntimePhase.running) {
          if (_isConnectionProven(current)) {
            _finalizeProvenConnection(current);
          }
          _schedulePostConnectHostHealthRefresh(current);
        }
        _update(() {
          _runtimeSnapshot = current;
          _runtimeHeadline = warpFallbackUsed
              ? 'POKROV подключен. WARP временно на паузе.'
              : current.phase == RuntimePhase.running && usedCachedProfile
                  ? current.isCoreEgressValidationPending
                      ? 'Проверяем выход через VPN…'
                      : current.hasCoreEgressValidationFailure
                          ? 'Выход через VPN не подтверждён.'
                          : 'POKROV подключен по сохраненным настройкам. Сервис обновим позже.'
                  : current.phase == RuntimePhase.running
                      ? current.isCoreEgressValidationPending
                          ? 'Проверяем выход через VPN…'
                          : current.isCleanlyHealthy
                              ? materialCandidate?.warpMode == 'warp_over_proxy'
                                  ? 'POKROV подключен через WARP. Страна выхода неизвестна.'
                                  : 'POKROV подключен.'
                              : current.hasCoreEgressValidationFailure
                                  ? 'Выход через VPN не подтверждён.'
                                  : 'POKROV подключен, но требует внимания.'
                      : current.message;
        });
        if (current.phase == RuntimePhase.running) {
          _recordProtectionEvent(
            kind: current.isCoreEgressValidationPending
                ? 'egress_checking'
                : current.hasCoreEgressValidationFailure
                    ? 'egress_failed'
                    : 'connected',
            title: warpFallbackUsed
                ? 'Обычная защита включена'
                : current.isCoreEgressValidationPending
                    ? 'Проверяем выход через VPN'
                    : current.hasCoreEgressValidationFailure
                        ? 'Выход через VPN не подтверждён'
                        : usedCachedProfile
                            ? 'Защита включена по сохраненным настройкам'
                            : current.isCleanlyHealthy
                                ? 'Защита включена'
                                : 'Защита включена с предупреждением',
            detail: warpFallbackUsed
                ? 'WARP не прошёл проверку, поэтому POKROV автоматически сохранил рабочий обычный VPN.'
                : current.isCoreEgressValidationPending
                    ? 'Туннель запущен; POKROV Core проверяет выход через выбранную локацию.'
                    : current.hasCoreEgressValidationFailure
                        ? 'POKROV Core не подтвердил выход через выбранную локацию.'
                        : usedCachedProfile
                            ? 'Control plane не ответил вовремя; использован последний валидный профиль.'
                            : current.isCleanlyHealthy
                                ? 'Туннель и host-health подтверждены.'
                                : 'Туннель запущен, одна из host-проверок требует внимания.',
            tone: warpFallbackUsed
                ? PokrovProtectionEventTone.warning
                : usedCachedProfile
                    ? PokrovProtectionEventTone.warning
                    : current.isCleanlyHealthy
                        ? PokrovProtectionEventTone.success
                        : PokrovProtectionEventTone.warning,
          );
        }
        if ((current.phase != RuntimePhase.running ||
                current.hasCoreEgressProbeFailure) &&
            _handleFailedManagedProfile(current)) {
          return;
        }
        if (current.phase != RuntimePhase.running &&
            current.message.trim().isNotEmpty) {
          unawaited(
            _reportClientRuntimeError(
              current.lastFailureKind ?? 'connect_not_running',
            ),
          );
          unawaited(_reportWarpRuntimeFallback(current));
          _notify(
            current.message,
            tone: PokrovSnackTone.danger,
          );
        }
      }
    } on ConnectionOperationSuperseded {
      return;
    } on BootstrapFailure catch (error) {
      if (!_connectionCoordinator.ownsOperation(generation)) return;
      _observability?.recordConnectionFailure(
        stage: failureStage,
        errorCode: error.operationalErrorCode,
        errorOrigin: error.code == 'candidate_selection_exhausted'
            ? ObservabilityErrorOrigin.core : ObservabilityErrorOrigin.portal,
        preparationFailure: failureStage == ConnectionStage.profile ? error : null,
      );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        return;
      }
      final offlineMessage = failureOperation == 'managed_profile_refresh' &&
          error.code != 'access_preparing' && _isTransientProfileFailure(error)
          ? await _classifyOfflineFailure(generation) : null;
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return;
      _update(() {
        _activePhase = ConnectionPhase.actionRequired;
        _runtimeHeadline = offlineMessage ?? error.message;
      });
      unawaited(_reportClientRuntimeError(error.operationalErrorCode));
      _notify(error.message, tone: PokrovSnackTone.danger);
    } on Object catch (error, stack) {
      if (!_connectionCoordinator.ownsOperation(generation)) return;
      _observability?.recordConnectionFailure(
        stage: failureStage,
        errorCode: 'CONN-005',
      );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        return;
      }
      final offlineMessage = failureOperation == 'managed_profile_refresh' && error is TimeoutException
          ? await _classifyOfflineFailure(generation) : null;
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return;
      final message = offlineMessage ?? _runtimeUnexpectedErrorMessage(error);
      _update(() {
        _activePhase = ConnectionPhase.actionRequired;
        _runtimeHeadline = message;
      });
      _recordProtectionEvent(
        kind: 'connect_unexpected_$failureOperation',
        title: 'Подключение не началось',
        detail: _unexpectedConnectionDiagnostic(failureOperation, error, stack),
        tone: PokrovProtectionEventTone.error,
      );
      unawaited(_reportClientRuntimeError('connect_unexpected'));
      _notify(message, tone: PokrovSnackTone.danger);
    } finally {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _update(() {
          if (_activePhase != ConnectionPhase.actionRequired) _activePhase = null;
          _connectionCoordinator.finishAction();
        });
      }
      if (_connectionCoordinator.ownsOperation(generation) &&
          _runtimeSnapshot?.phase != RuntimePhase.running) {
        _connectionCoordinator.clearAttempt();
      }
      if (!completion.isCompleted) completion.complete();
      if (identical(_primaryConnectCompletion, completion)) {
        _primaryConnectCompletion = null;
      }
      await _enforceKnownAccessDenial();
      if (!_disposed) unawaited(_reportClientLifecycle("runtime_observed"));
      _publish();
    }
  }

  Future<void> _cancelPrimaryConnect() async {
    final engine = _runtimeEngine;
    final requestId = _connectionCoordinator.cancellableConnectRequestId;
    final completion = _primaryConnectCompletion;
    if (!const {HostPlatform.android, HostPlatform.windows, HostPlatform.linux}
            .contains(_appContext.hostPlatform) ||
        engine is! RuntimeConnectCancellation ||
        !_connectionCoordinator.canCancelPrimaryConnect ||
        completion == null) return;

    _cancelAutomaticFailover();
    _cancelPostConnectHostHealthPolling();
    _stopTransportPolicyRefresh();
    _update(() {
      // Keep the single action owner busy until old work has settled. Advancing
      // the generation prevents its remaining stages and fallback from starting.
      _connectionCoordinator.beginAction(ConnectionTransitionIntent.disconnect);
      _runtimeHeadline = 'Отменяем подключение…';
    });
    final generation = _connectionCoordinator.operationGeneration;
    try {
      Object? cancellationError;
      try {
        await _cancelOwnedConnect(
            engine as RuntimeConnectCancellation, requestId);
      } on Object catch (error) {
        cancellationError = error;
      }
      // Acknowledging the request is not proof that the host stopped. Do not
      // release the action owner while its old connect pipeline can still run.
      await completion.future;
      await _joinRuntimeActions();
      if (_disposed || !_connectionCoordinator.ownsOperation(generation))
        return;
      var current = await _withRuntimeActionTimeout(
          'cancelConnectSnapshot', _runtimeEngine.snapshot,
          ownerGeneration: generation);
      if (!_protectedHandoffActive) {
        current = await _settleRuntimeDisconnectTransition(current, ownerGeneration: generation);
      }
      if (_disposed || !_connectionCoordinator.ownsOperation(generation))
        return;
      _update(() => _runtimeSnapshot = current);
      if (cancellationError != null) throw cancellationError;
      if (!_protectedHandoffActive && !_runtimeStopConfirmed(current)) {
        throw const BootstrapFailure(
            'Остановка подключения ещё не подтверждена. Проверьте состояние POKROV.',
            code: 'connect_cancel_unconfirmed',
            operation: 'cancel_connect');
      }
      _update(() {
        _runtimeHeadline = _protectedHandoffActive
            ? 'Восстановление отменено. Повторите подключение или отключите POKROV.'
            : 'Попытка подключения отменена.';
      });
    } on ConnectionOperationSuperseded {
      return;
    } on Object catch (error) {
      if (_disposed || !_connectionCoordinator.ownsOperation(generation))
        return;
      final message = error is BootstrapFailure
          ? error.message
          : 'Отмена подключения не подтверждена. Проверьте состояние POKROV.';
      _update(() => _runtimeHeadline = message);
      _notify(message, tone: PokrovSnackTone.danger);
    } finally {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _update(() {
          _activePhase = _protectedHandoffActive ? ConnectionPhase.actionRequired : null;
          _connectionCoordinator.finishAction(
              clearAttempt: _runtimeSnapshot?.phase != RuntimePhase.running);
        });
        await _enforceKnownAccessDenial();
        if (!_disposed) _publish();
      }
    }
  }

  void _handleSlowConnectionStage() {
    if (_disposed || !_connectionCoordinator.slowStageVisible) {
      return;
    }
    final presentation = _connectionCoordinator.presentation;
    _recordProtectionEvent(
      kind: 'connection_slow_stage',
      title: 'Подключение занимает больше времени',
      detail: '${presentation.title}. ${presentation.subtitle}',
      tone: PokrovProtectionEventTone.warning,
    );
  }

  void _finishAndroidVpnPermission(RuntimeSnapshot snapshot) {
    if (_appContext.hostPlatform != HostPlatform.android) {
      return;
    }
    final denied = snapshot.lastFailureKind == 'vpn_permission_denied';
    final granted = snapshot.phase == RuntimePhase.running;
    final wasRequesting = _firstSessionCoordinator.vpnPermissionState ==
        FirstSessionVpnPermissionState.requesting;
    if (!denied &&
        !granted &&
        _firstSessionCoordinator.vpnPermissionState !=
            FirstSessionVpnPermissionState.requesting) {
      return;
    }
    _firstSessionCoordinator.finishVpnPermissionRequest(
      granted: granted,
      denied: denied,
    );
    if (denied || (granted && wasRequesting)) {
      unawaited(
        _reportFirstSessionEvent(
          'vpn_permission_result',
          stage: 'vpn_permission',
          result: granted ? 'success' : 'failure',
          errorCode: denied ? 'vpn_permission_denied' : '',
          retryable: denied,
        ),
      );
    }
  }

  Future<void> _syncSuccessfulConnectionExperience(
    RuntimeSnapshot snapshot,
  ) async {
    final service = _experienceService;
    if (service == null) {
      return;
    }
    final attemptDurationMs = _connectionAttemptDurationMs();
    _connectionAttemptStartedAt = null;
    final reports = _pendingCandidateProbeReports();
    if (reports.isNotEmpty) _candidateProbeReportInFlight = true;
    try {
      final candidate = _reportedCandidate(_activeCandidateRef ?? _candidateRef);
      await service.reportRuntimeStats(
        hostPlatform: _appContext.hostPlatform,
        runtimePhase: snapshot.phase.name,
        connected: snapshot.phase == RuntimePhase.running,
        connectivitySnapshot: snapshot,
        selectedNodeCode: materialCandidate?.warpMode == 'warp_over_proxy'
            ? ''
            : _activeNodeCode.isNotEmpty
                ? _activeNodeCode
                : _resolvedProfileNodeCode,
        routeMode: _selectedRouteMode.name,
        durationMs: attemptDurationMs,
        attemptNumber:
            _connectionAttemptNumber > 0 ? _connectionAttemptNumber : null,
        networkClass: _candidateNetworkClass ?? '',
        carrierMccMnc: _candidateCarrierMccMnc ?? '',
        carrierName: _candidateCarrierName ?? '',
        accessNetworkAsn: _candidateAccessNetworkAsn ?? '',
        candidateTransport: _candidateTransport(candidate),
        candidateRef: candidate?.candidateRef ?? '',
        candidateVariant: candidate == null ? '' : _activeVariantId,
        candidateProbes: reports,
      );
      _ackCandidateProbeReports(reports);
    } catch (error) {
      if (reports.isNotEmpty) _recordRuntimeStatsDeliveryFailure(error);
      // UX telemetry must never turn a working tunnel into a failed connect.
    } finally {
      if (reports.isNotEmpty) _candidateProbeReportInFlight = false;
    }
    try {
      await service.completeAccountOnboarding(
        hostPlatform: _appContext.hostPlatform,
      );
    } catch (_) {
      // Account-scoped onboarding sync is best-effort and retried on connect.
    }
  }

  bool _isConnectionProven(RuntimeSnapshot snapshot) =>
      snapshot.isCleanlyHealthy &&
      (snapshot.transportLeaseActive != true ||
          _connectionCoordinator.hasActiveTransportLease);

  ConnectionExperienceState get _connectionExperience =>
      _connectionCoordinator.experience;

  ConnectionPresentation get _connectionPresentation =>
      ConnectionPresentation.fromExperience(
        _connectionExperience,
        primaryConnectEnabled: _canPrimaryConnect(_runtimeSnapshot),
        canCancelConnect: canCancel,
        retainsProtection: retainsProtection,
      );

  void _finalizeProvenConnection(RuntimeSnapshot snapshot) {
    final cacheService = _bootstrapper;
    final cacheInputs = _stagedCacheInputs;
    if (snapshot.isCleanlyHealthy &&
        cacheService is CachedManagedProfileBootstrapper &&
        cacheInputs != null) {
      unawaited((cacheService as CachedManagedProfileBootstrapper)
          .markManagedProfileProven(cacheInputs, _stagedProfileCacheEntryId,
              networkSelectionKey: _candidateNetworkKey,
              offlineNetworkSelectionKey: _candidateOfflineNetworkKey));
    }
    if (_candidateNetworkKey != null && _candidateRef != null) {
      _candidateSelector.recordSuccess(_candidateNetworkKey!, _candidateRef!);
      _activeCandidateRef = _candidateRef;
      _activePhysicalNetwork = _candidatePhysicalNetwork;
      _diagnosticsCoordinator.startRuntimePolling(_refreshDesktopRuntimeSnapshot);
      final generation = _connectionCoordinator.operationGeneration;
      final completion = _primaryConnectCompletion?.future ?? Future<void>.value();
      unawaited(completion.then((_) async {
        if (!_disposed && _connectionCoordinator.ownsOperation(generation) && _runtimeSnapshot?.isCleanlyHealthy == true) {
          await _refreshManagedProfileCache(alternativesOnly: true);
        }
      }));
    }
    _automaticFailoverAttempts = 0;
    _automaticFailoverInFlight = false;
    _promoteStagedLocationAfterFreshConnect();
    final firstVerifiedConnect = !_connectHintDismissed;
    _dismissConnectHint();
    _firstSessionCoordinator.finishVpnPermissionRequest(
      granted: true,
      denied: false,
    );
    if (firstVerifiedConnect &&
        _firstSessionCoordinator.markFirstVerifiedConnectSeen()) {
      unawaited(
        _reportFirstSessionEvent(
          'first_verified_connect',
          stage: 'connect',
          result: 'success',
        ),
      );
    }
    unawaited(_syncSuccessfulConnectionExperience(snapshot));
  }

  void _schedulePostConnectHostHealthRefresh(
    RuntimeSnapshot connectedSnapshot,
  ) {
    if (_appContext.hostPlatform != HostPlatform.android ||
        connectedSnapshot.coreEgressValidated == true) {
      return;
    }
    // Observe every Android transport through the 55-second host watchdog.
    // An AWG failure can arrive after the normal group-probe window, while its
    // TUN is still running; the result must reach the bounded TCP fallback.
    _diagnosticsCoordinator.startHealthPolling(
      interval: const Duration(milliseconds: 750),
      pollCount: 76,
      canContinue: () => !_disposed,
      onPoll: (generation) => unawaited(
        _refreshPostConnectHostHealth(connectedSnapshot, generation),
      ),
    );
  }

  Future<void> _refreshPostConnectHostHealth(
    RuntimeSnapshot connectedSnapshot,
    int generation,
  ) async {
    if (_disposed ||
        !_diagnosticsCoordinator.isCurrentHealthGeneration(generation) ||
        _runtimeSnapshot?.phase != RuntimePhase.running ||
        !_diagnosticsCoordinator.beginHealthPoll(generation)) {
      return;
    }
    try {
      final refreshed = await _withRuntimeActionTimeout(
        'postConnectHealthSnapshot',
        _runtimeEngine.snapshot,
      );
      if (_disposed ||
          !_diagnosticsCoordinator.isCurrentHealthGeneration(generation) ||
          _runtimeSnapshot?.phase != RuntimePhase.running) {
        return;
      }
      final connectedPath = connectedSnapshot.stagedConfigPath?.trim() ?? '';
      final refreshedPath = refreshed.stagedConfigPath?.trim() ?? '';
      if (connectedPath.isNotEmpty &&
          refreshedPath.isNotEmpty &&
          connectedPath != refreshedPath) {
        return;
      }
      if (refreshed.phase != RuntimePhase.running ||
          refreshed.hasCoreEgressProbeFailure) {
        _cancelPostConnectHostHealthPolling();
        if (_transportCatalog != null && _candidateRef != null) {
          _scheduleCandidateRecovery(refreshed);
          return;
        }
        final shouldFallbackFromWarp = _activeConnectUsedWarp &&
            !_warpFallbackInFlight &&
            _mustRefreshProfileAfterRuntimeFailure(refreshed);
        if (shouldFallbackFromWarp) {
          _warpFallbackInFlight = true;
          _update(() {
            _runtimeSnapshot = refreshed;
            _managedWarpPolicy = _managedWarpPolicy.copyWith(
              state: 'fallback',
              userConsented: true,
            );
            _runtimeHeadline =
                'WARP временно недоступен. Подключаем обычный VPN…';
          });
          unawaited(_retryWithoutWarpAfterEgressFailure(refreshed));
          _publish();
          return;
        }
        _handleFailedManagedProfile(refreshed);
        _publish();
        return;
      }
      _update(() {
        _runtimeSnapshot = refreshed;
        if (refreshed.isCoreEgressValidationPending) {
          _runtimeHeadline = 'Проверяем выход через VPN…';
        } else if (refreshed.hasDegradedHostDiagnostics) {
          _runtimeHeadline =
              'Туннель запущен, но проверка соединения требует внимания.';
        } else if (refreshed.isCleanlyHealthy) {
          _runtimeHeadline = 'POKROV подключен.';
        }
      });
      _publish();
      if (refreshed.coreEgressValidated == true) {
        _finalizeProvenConnection(refreshed);
        _cancelPostConnectHostHealthPolling();
      }
    } on Object {
      // The host snapshot is advisory here; the normal refresh lane retries it.
    } finally {
      _diagnosticsCoordinator.finishHealthPoll(generation);
    }
  }

  void _cancelPostConnectHostHealthPolling() =>
      _diagnosticsCoordinator.stopHealthPolling();

  Future<void> _retryWithoutWarpAfterEgressFailure(
    RuntimeSnapshot warpFailure,
  ) async {
    if (_disposed) {
      _warpFallbackInFlight = false;
      return;
    }
    _update(() {
      _runtimeBusy = true;
      _runtimeIntent = ConnectionTransitionIntent.reconnect;
    });
    final generation = _connectionCoordinator.operationGeneration;
    Future<T> runOwnedRuntimeAction<T>(
      String operation,
      Future<T> Function() action,
    ) =>
        _withRuntimeActionTimeout(operation, action,
            ownerGeneration: generation);
    try {
      final fallback = await runOwnedRuntimeAction(
        'applyWarpFallback',
        () => _runtimeEngine.applyWarp(enabled: false),
      );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        return;
      }
      var baselineReady = fallback.applied;
      var fallbackReported = false;
      if (baselineReady) {
        _stagedProfileUsesWarp = false;
      }
      if (!baselineReady) {
        // A process restart can preserve the host's reusable profile while the
        // Dart runtime no longer has the original staged payload. Re-resolve
        // and stage a fresh baseline profile instead of asking the person to
        // understand this internal cache boundary.
        await _reportWarpRuntimeFallback(warpFailure);
        fallbackReported = true;
        final baselineProfile = await _resolveManagedProfile(
          deadline: _actionTimeout,
          suppressWarpRuntime: true,
          ownerGeneration: generation,
        );
        final staged = await runOwnedRuntimeAction(
          'stageWarpFallbackProfile',
          () => _stageManagedProfileWithLeaseBinding(baselineProfile),
        );
        if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
          return;
        }
        baselineReady = staged.canConnect ||
            (staged.stagedConfigPath?.trim().isNotEmpty ?? false);
        _update(() {
          _runtimeSnapshot = staged;
          _managedProfileDirty = !baselineReady;
          _stagedProfileUsesWarp = false;
          _stagedTcpFallbackFromRevision =
              baselineReady ? baselineProfile.tcpFallbackFromRevision : '';
          _stagedNodeCode = baselineReady ? _resolvedProfileNodeCode : '';
          _stagedVariantId =
              baselineReady ? _resolvedProfileVariantId : 'direct';
          if (baselineReady) {
            _rememberStagedCandidateVariant(baselineProfile, generation);
          } else {
            _stagedCandidateVariant = null;
          }
          _stagedCacheInputs = _managedProfileCacheInputs;
          _stagedProfileCacheEntryId =
              baselineReady ? baselineProfile.cacheEntryId : '';
          _managedWarpPolicy = _managedWarpPolicy.copyWith(
            state: 'fallback',
            userConsented: true,
          );
        });
      }
      if (!baselineReady) {
        _update(() {
          _runtimeHeadline =
              'WARP не прошёл проверку. Выключите его и повторите подключение.';
        });
        if (!fallbackReported) {
          unawaited(_reportWarpRuntimeFallback(warpFailure));
        }
        return;
      }

      _activeConnectUsedWarp = false;
      if (!fallbackReported) {
        unawaited(_reportWarpRuntimeFallback(warpFailure));
      }
      var current = await runOwnedRuntimeAction(
        'connectWithoutWarp',
        _runtimeEngine.connect,
      );
      current = await _settleRuntimeTransition(
        current,
        ownerGeneration: generation,
      );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        return;
      }
      _update(() {
        _runtimeSnapshot = current;
        _runtimeHeadline = current.phase == RuntimePhase.running
            ? 'POKROV подключен. WARP временно на паузе.'
            : current.message.trim().isEmpty
                ? 'Обычный VPN тоже не подключился. Попробуйте другую локацию.'
                : current.message;
      });
      if (current.phase == RuntimePhase.running) {
        if (_isConnectionProven(current)) {
          _finalizeProvenConnection(current);
        }
        _schedulePostConnectHostHealthRefresh(current);
        _recordProtectionEvent(
          kind: 'warp_fallback_connected',
          title: 'Обычная защита включена',
          detail:
              'WARP не прошёл проверку, поэтому POKROV автоматически сохранил рабочий обычный VPN.',
          tone: PokrovProtectionEventTone.warning,
        );
      } else if (_mustRefreshProfileAfterRuntimeFailure(current)) {
        _managedProfileDirty = true;
        _stagedNodeCode = '';
        _stagedVariantId = 'direct';
        _cachedProfileFallbackGate.markRuntimeFailure();
      }
      _publish();
    } on ConnectionOperationSuperseded {
      return;
    } on Object catch (error) {
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        return;
      }
      _update(() {
        _runtimeHeadline = _runtimeUnexpectedErrorMessage(error);
      });
    } finally {
      if (!_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _warpFallbackInFlight = false;
        _update(() {
          _runtimeBusy = false;
          _runtimeIntent = ConnectionTransitionIntent.none;
        });
      }
    }
  }

  bool _mustRefreshProfileAfterRuntimeFailure(RuntimeSnapshot snapshot) {
    if (_appContext.hostPlatform != HostPlatform.android) {
      return false;
    }
    return snapshot.hasCoreEgressProbeFailure ||
        snapshot.lastFailureKind?.trim() == 'core_egress_probe_unavailable';
  }

  Set<String> _activeAutomaticNodeExclusions() {
    final now = DateTime.now().toUtc();
    return <String>{
      for (final entry in _automaticNodeQuarantineUntil.entries)
        if (entry.value.isAfter(now)) entry.key,
    };
  }

  void _quarantineAutomaticNode(String nodeCode) {
    final normalized = nodeCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    final retained = _automaticNodeQuarantineUntil.entries
        .where(
          (entry) => entry.key != normalized && entry.value.isAfter(now),
        )
        .toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    _automaticNodeQuarantineUntil
      ..clear()
      ..addEntries(
        retained.take(_maxAutomaticNodeQuarantineEntries - 1),
      )
      ..[normalized] = now.add(_automaticNodeQuarantineTtl);
    _clientExperience = _clientExperience.copyWith(
      automaticNodeQuarantineUntil: <String, String>{
        for (final entry in _automaticNodeQuarantineUntil.entries)
          entry.key: entry.value.toIso8601String(),
      },
    );
    _queueClientExperienceWrite();
  }

  void _cancelAutomaticFailover() {
    _automaticFailoverGeneration += 1;
    _automaticFailoverAttempts = 0;
    _automaticFailoverInFlight = false;
    _tcpFallbackFromRevision = '';
  }

  bool _scheduleCandidateRecovery(RuntimeSnapshot failed) {
    if (_candidateRecoveryPending || _activePhase == ConnectionPhase.actionRequired) return false;
    final currentRef = _activeCandidateRef ?? _candidateRef;
    if (currentRef == null) return false;
    _candidateRecoveryPending = true;
    final command = _commandNumber;
    final completing = _primaryConnectCompletion?.future;
    unawaited(() async {
      if (completing != null) await completing;
      try {
        if (_disposed || command != _commandNumber) return;
        await _replaceCommand(() => _recoverCandidateConnection(failed, currentRef,
            confirmedFailure: true), automatic: true);
      } finally { _candidateRecoveryPending = false; }
    }());
    return true;
  }

  Future<void> _recoverCandidateConnection(RuntimeSnapshot? failed, String currentRef,
      {int? ownerGeneration, bool confirmedFailure = false}) async {
    final engine = _runtimeEngine;
    _cancelPostConnectHostHealthPolling();
    final ownsAction = ownerGeneration == null;
    if (ownsAction) {
      _connectionCoordinator.beginAction(ConnectionTransitionIntent.recover,
          allowConnectCancellation: engine is RuntimeConnectCancellation);
    }
    final generation = ownerGeneration ?? _connectionCoordinator.operationGeneration;
    final completion = ownsAction ? Completer<void>() : null;
    if (completion != null) _primaryConnectCompletion = completion;
    _update(() {
      _activePhase = ConnectionPhase.recovering;
      _runtimeSnapshot = failed;
      _runtimeHeadline = 'Восстанавливаем защищённое подключение…';
    });
    try {
      final retryInitialActivation = _activeCandidateRef == null &&
          !retainsProtection && failed != null &&
          failed.hasCoreEgressProbeFailure && _runtimeStopConfirmed(failed);
      if (!retryInitialActivation && engine is! RuntimeProtectedHandoff) {
        throw const BootstrapFailure('Для восстановления соединения обновите POKROV.', code: 'protected_handoff_unavailable');
      }
      // Profile preparation and probes must also retain the existing tunnel
      // when a manual replacement is cancelled before native handoff starts.
      if (failed?.phase == RuntimePhase.running) _protectedHandoffActive = true;
      final invalidated = await _waitForQuickSettingsInvalidation(_managedProfileRevision);
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return;
      if (!invalidated) {
        throw const BootstrapFailure(
            'Не удалось обновить настройки для быстрого подключения. Попробуйте ещё раз.');
      }
      final cacheInputs = _managedProfileCacheInputs;
      final profileRevision = _managedProfileRevision;
      final failedActivations = <String>{
        if (confirmedFailure && currentRef.isNotEmpty) currentRef,
      };
      if (confirmedFailure && currentRef.isNotEmpty && _candidateNetworkKey != null) {
        _candidateSelector.recordFailure(_candidateNetworkKey!, currentRef,
            failed?.lastFailureKind ?? '');
      }
      Future<ManagedProfilePayload?> recoverCached({bool offline = false}) async {
        final cacheService = _bootstrapper;
        if (cacheService is! CachedManagedProfileBootstrapper || _tcpFallbackFromRevision.isNotEmpty ||
            !_cachedProfileFallbackGate.canFallback(cachedProfileAvailable: true, inputsVerified: true)) return null;
        final cached = await (cacheService as CachedManagedProfileBootstrapper).loadCachedManagedProfile(
            cacheInputs, preferProven: true,
            runtimeFeatures: _runtimeSnapshot?.transportCapabilities?.features ?? const {})
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
        if (_disposed || !_connectionCoordinator.ownsOperation(generation) ||
            profileRevision != _managedProfileRevision) throw const ConnectionOperationSuperseded();
        if (cached == null || !_cachedProfileFallbackGate.canFallback(
            cachedProfileAvailable: true, inputsVerified: true)) return null;
        // A cache without a catalog cannot skip a known failed candidate.
        if (confirmedFailure && cached.transportCatalog == null) return null;
        if (offline) await _classifyOfflineFailure(generation);
        if (_disposed || !_connectionCoordinator.ownsOperation(generation) ||
            profileRevision != _managedProfileRevision) throw const ConnectionOperationSuperseded();
        final selected = await _resolveCachedCandidateProfile(cacheInputs, cached,
            generation: generation, recoveryCandidateRef: currentRef, excludedCandidateRefs: failedActivations);
        // Preserve the authorized entry and its expiry; probing does not renew it.
        return _prepareManagedProfile(selected, offline: true, ownerGeneration: generation);
      }
      for (var activation = 0; activation < 3; activation++) {
      var usedCachedProfile = false;
      ManagedProfilePayload? payload;
      if (confirmedFailure) {
        try {
          // The monitor already disproved current. Race ready alternatives
          // before waiting for the control API or probing current a second time.
          payload = await recoverCached();
          usedCachedProfile = payload != null;
        } on BootstrapFailure catch (error) {
          if (error.code != 'candidate_selection_exhausted') rethrow;
        }
      }
      if (payload == null) {
      try {
        payload = await _resolveManagedProfile(ownerGeneration: generation,
            recoveryCandidateRef: currentRef, excludedCandidateRefs: failedActivations, deadline: _actionTimeout);
      } on Object catch (error) {
        if (error is BootstrapFailure && (error.statusCode == 401 || error.statusCode == 403)) {
          _cachedProfileFallbackGate.markAuthorizationDenied();
        }
        if (!(error is TimeoutException || error is BootstrapFailure && _isTransientProfileFailure(error))) rethrow;
        payload = await recoverCached(offline: true);
        if (payload == null) rethrow;
        usedCachedProfile = true;
      }
      }
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return;
      if (usedCachedProfile && !_cachedProfileFallbackGate.canFallback(
          cachedProfileAvailable: true, inputsVerified: true)) {
        throw const BootstrapFailure('Доступ не активен. Продлите доступ, чтобы подключиться.',
            code: 'managed_profile_access_denied', statusCode: 403);
      }
      final prepared = payload;
      RuntimeSnapshot current;
      if (retryInitialActivation) {
        // The first activation stopped before proof: there is no prior healthy
        // owner to replace. Stage/connect retains any native transition guard.
        current = await _withRuntimeActionTimeout('stageManagedProfile',
            () => _stageManagedProfileWithLeaseBinding(prepared), ownerGeneration: generation);
        if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return;
        _update(() => _runtimeSnapshot = current);
        current = await _withRuntimeActionTimeout('connect', _runtimeEngine.connect,
            ownerGeneration: generation);
      } else {
        _protectedHandoffActive = true;
        current = await _withRuntimeActionTimeout('replaceManagedProfile',
            () => _stageManagedProfileWithLeaseBinding(prepared, replaceProtected: true), ownerGeneration: generation);
      }
      current = await _settleRuntimeTransition(current, ownerGeneration: generation,
          waitForEgressProof: true);
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return;
      if (!usedCachedProfile) _cachedProfileFallbackGate.markFreshProfileStaged();
      final tryNext = activation < 2 && current.hasCoreEgressProbeFailure &&
          _transportCatalog != null && _candidateRef != null;
      _update(() {
        _runtimeSnapshot = current;
        _stagedCacheInputs = cacheInputs;
        _stagedProfileCacheEntryId = prepared.cacheEntryId;
        _stagedNodeCode = _resolvedProfileNodeCode;
        _stagedVariantId = _resolvedProfileVariantId;
        _rememberStagedCandidateVariant(prepared, generation);
        _stagedProfileUsesWarp = prepared.warpPolicy.canEnableRuntime;
        _activeConnectUsedWarp = _stagedProfileUsesWarp;
        _managedProfileDirty = !current.isCleanlyHealthy;
        _activePhase = current.isCleanlyHealthy ? null : tryNext ? ConnectionPhase.recovering : ConnectionPhase.actionRequired;
        _runtimeHeadline = current.isCleanlyHealthy
            ? usedCachedProfile ? 'POKROV подключен по сохраненным настройкам. Сервис обновим позже.' : 'POKROV подключен.'
            : tryNext ? 'Проверяем другое защищённое подключение…'
            : 'Не удалось восстановить подключение. Попробуйте ещё раз или отключите POKROV.';
      });
      if (current.isCleanlyHealthy) {
        _protectedHandoffActive = false;
        _finalizeProvenConnection(current);
      }
      if (!tryNext) return;
      failedActivations.add(_candidateRef!);
      if (_candidateNetworkKey != null) _candidateSelector.recordFailure(
          _candidateNetworkKey!, _candidateRef!, current.lastFailureKind ?? '');
      }
    } on ConnectionOperationSuperseded {
      return;
    } on Object catch (error) {
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return;
      final offlineMessage = error is TimeoutException || error is BootstrapFailure && _isTransientProfileFailure(error)
          ? await _classifyOfflineFailure(generation) : null;
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) return;
      _update(() {
        _activePhase = ConnectionPhase.actionRequired;
        _runtimeHeadline = offlineMessage ?? (error is BootstrapFailure ? error.message
            : 'Не удалось восстановить подключение. Попробуйте ещё раз или отключите POKROV.');
      });
    } finally {
      if (ownsAction && !_disposed && _connectionCoordinator.ownsOperation(generation)) {
        _connectionCoordinator.finishAction();
        _publish();
      }
      if (completion != null) {
        if (!completion.isCompleted) completion.complete();
        if (identical(_primaryConnectCompletion, completion)) _primaryConnectCompletion = null;
      }
    }
  }

  bool _handleFailedManagedProfile(RuntimeSnapshot failed) {
    if (_transportCatalog != null && _candidateRef != null) return _scheduleCandidateRecovery(failed);
    final mustRefreshProfile = _mustRefreshProfileAfterRuntimeFailure(failed);
    final confirmedFailure = failed.hasCoreEgressProbeFailure;
    final failedNodeCode = _stagedNodeCode.trim().toLowerCase();
    final confirmedAutomaticNodeFailure = confirmedFailure &&
        _preferredNodeCode.trim().isEmpty &&
        failedNodeCode.isNotEmpty;
    final failedLabRevision = _stagedTcpFallbackFromRevision;
    final confirmedLabFailure = confirmedFailure &&
        failedLabRevision.isNotEmpty &&
        _tcpFallbackFromRevision.isEmpty;
    final shouldRetryAutomatically =
        (confirmedLabFailure || confirmedAutomaticNodeFailure) &&
            !_automaticFailoverInFlight &&
            _automaticFailoverAttempts < _maxAutomaticFailoverAttempts;
    if (confirmedAutomaticNodeFailure) {
      _quarantineAutomaticNode(failedNodeCode);
    }
    _update(() {
      _runtimeSnapshot = failed;
      if (mustRefreshProfile) {
        _managedProfileDirty = true;
        _stagedNodeCode = '';
        _stagedVariantId = 'direct';
        _stagedTcpFallbackFromRevision = '';
      }
      if (shouldRetryAutomatically && confirmedLabFailure) {
        _tcpFallbackFromRevision = failedLabRevision;
      }
      _runtimeHeadline = shouldRetryAutomatically
          ? confirmedLabFailure
              ? 'Основное подключение не ответило. Пробуем резервное…'
              : 'Локация не ответила. Пробуем другую…'
          : failed.message.trim().isEmpty
              ? 'Подключение остановлено. Попробуйте еще раз.'
              : failed.message;
    });
    // Preserve the downloaded/proven cache for a manual offline retry.
    // Automatic failover still requires a newly selected server profile.
    if (mustRefreshProfile) {
      _cachedProfileFallbackGate.markRuntimeFailure();
    }
    if (shouldRetryAutomatically) {
      _automaticFailoverAttempts += 1;
      _automaticFailoverInFlight = true;
      unawaited(
        _retryAutomaticLocationAfterEgressFailure(_automaticFailoverGeneration),
      );
    }
    return shouldRetryAutomatically;
  }

  Future<void> _retryAutomaticLocationAfterEgressFailure(
    int ownerGeneration,
  ) async {
    final retryIndex = (_automaticFailoverAttempts - 1).clamp(0, 1);
    final retryDelay = Duration(
      milliseconds: (250 << retryIndex) + math.Random().nextInt(251),
    );
    await Future<void>.delayed(retryDelay);
    try {
      if (_disposed ||
          ownerGeneration != _automaticFailoverGeneration ||
          (_preferredNodeCode.trim().isNotEmpty &&
              _tcpFallbackFromRevision.isEmpty)) {
        return;
      }
      await _replaceCommand(
          () => _toggleRuntime(reconnectAfterDisconnect: true),
          automatic: true);
    } finally {
      if (ownerGeneration == _automaticFailoverGeneration) {
        _automaticFailoverInFlight = false;
      }
    }
  }

  String _runtimeUnexpectedErrorMessage(Object error) {
    return switch (error) {
      TimeoutException() =>
        'POKROV не дождался ответа. Попробуйте еще раз, а если не поможет — напишите в поддержку.',
      _ =>
        'POKROV не смог начать подключение. Попробуйте еще раз, а если не поможет — напишите в поддержку: диагностику можно приложить прямо в чате.',
    };
  }

  Future<void> _reportWarpRuntimeFallback(RuntimeSnapshot snapshot) async {
    final generation = _connectionCoordinator.operationGeneration;
    final service = _warpActionService;
    if (service == null ||
        !_warpRuntimeConsent ||
        !_managedWarpPolicy.canOfferRuntime) {
      return;
    }
    try {
      final failureKind = snapshot.lastFailureKind?.trim() ?? '';
      final diagnosticsSummary = snapshot.hostDiagnosticsSummary?.trim() ?? '';
      final status = await service.reportWarpRuntimeEvent(
        hostPlatform: _appContext.hostPlatform,
        eventName: 'runtime_fallback',
        state: 'fallback',
        reasonCode:
            failureKind.isNotEmpty ? failureKind : 'connect_not_running',
        message: snapshot.message,
        meta: <String, Object?>{
          'phase': snapshot.phase.name,
          'lane': snapshot.lane.name,
          'host_health': snapshot.hostHealth.name,
          'dns_state': snapshot.dnsState.name,
          'uplink_state': snapshot.uplinkState.name,
          if (diagnosticsSummary.isNotEmpty)
            'host_diagnostics_summary': diagnosticsSummary,
        },
      );
      if (_disposed || !_connectionCoordinator.ownsOperation(generation)) {
        return;
      }
      final nextPolicy = status.applyTo(_managedWarpPolicy).copyWith(
            // Telemetry is advisory: it may refresh runtime availability, but
            // it never owns a person's enable/revoke decision.
            userConsented: _warpRuntimeConsent,
          );
      _update(() {
        _managedWarpPolicy = nextPolicy;
      });
    } on BootstrapFailure {
      // Runtime fallback telemetry must never block the user's connect flow.
    }
  }

  Future<RuntimeSnapshot> _settleRuntimeTransition(
    RuntimeSnapshot snapshot, {
    int? ownerGeneration,
    bool waitForEgressProof = false,
  }) async {
    final engine = _runtimeEngine;
    final RuntimeConnectCancellation? cancellation =
        engine is RuntimeConnectCancellation
            ? engine as RuntimeConnectCancellation
            : null;
    final requestId = cancellation?.connectRequestForSnapshot(snapshot);
    try {
      return await _settleOwnedRuntimeTransition(snapshot,
          ownerGeneration: ownerGeneration,
          waitForEgressProof: waitForEgressProof,
          deadline: requestId == null
              ? null
              : Duration(
                  milliseconds: snapshot.connectionPending || waitForEgressProof ? 81000 : 4500));
    } on Object catch (error) {
      if (error is TimeoutException || error is ConnectionOperationSuperseded) {
        await _cancelOwnedConnect(cancellation, requestId);
      }
      rethrow;
    }
  }

  Future<RuntimeSnapshot> _settleOwnedRuntimeTransition(
    RuntimeSnapshot snapshot, {
    int? ownerGeneration,
    Duration? deadline,
    bool waitForEgressProof = false,
  }) async {
    final generation =
        ownerGeneration ?? _connectionCoordinator.operationGeneration;
    if (!_connectionCoordinator.ownsOperation(generation)) {
      throw const ConnectionOperationSuperseded();
    }
    bool proofPending(RuntimeSnapshot value) => waitForEgressProof &&
        value.phase == RuntimePhase.running && value.isCoreEgressValidationPending;
    if (snapshot.phase == RuntimePhase.running && !proofPending(snapshot) ||
        !snapshot.supportsLiveConnect ||
        _isTerminalConnectMessage(snapshot.message)) {
      return snapshot;
    }

    var current = snapshot;
    // Android returns from MethodChannel before its notification and VPN
    // consent sheets complete. Keep reading the host-owned pending state rather
    // than relying on a localized status message or a lifecycle resume.
    final maxAttempts = current.connectionPending || proofPending(current) ? 180 : 10;
    final elapsed = Stopwatch()..start();
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      final remaining = deadline == null ? null : deadline - elapsed.elapsed;
      if (remaining != null && remaining <= Duration.zero) break;
      await Future<void>.delayed(
          remaining != null && remaining < const Duration(milliseconds: 450)
              ? remaining
              : const Duration(milliseconds: 450));
      final snapshotBudget =
          deadline == null ? null : deadline - elapsed.elapsed;
      if (snapshotBudget != null && snapshotBudget <= Duration.zero) break;
      final pending = _withRuntimeActionTimeout(
        'settleSnapshot',
        _runtimeEngine.snapshot,
        ownerGeneration: generation,
      );
      current = await (snapshotBudget == null
          ? pending
          : pending.timeout(snapshotBudget));
      if (!_connectionCoordinator.ownsOperation(generation)) {
        throw const ConnectionOperationSuperseded();
      }
      if (_disposed) {
        return current;
      }
      _update(() {
        _runtimeSnapshot = current;
        _runtimeHeadline = null;
      });
      if (current.phase == RuntimePhase.running && !proofPending(current)) {
        return current;
      }
      if (_isTerminalConnectMessage(current.message) ||
          !current.connectionPending && !proofPending(current)) {
        return current;
      }
    }
    if (current.connectionPending || proofPending(current)) {
      throw TimeoutException('runtime connection did not settle');
    }
    return current;
  }

  bool _runtimeStopConfirmed(RuntimeSnapshot snapshot) =>
      snapshot.phase != RuntimePhase.running &&
      snapshot.phase != RuntimePhase.artifactMissing &&
      !snapshot.protectionRetained &&
      !snapshot.connectionPending &&
      snapshot.supportsLiveConnect;

  Future<RuntimeSnapshot> _settleRuntimeDisconnectTransition(
    RuntimeSnapshot snapshot, {
    int? ownerGeneration,
  }) async {
    final generation =
        ownerGeneration ?? _connectionCoordinator.operationGeneration;
    if (!_connectionCoordinator.ownsOperation(generation)) {
      throw const ConnectionOperationSuperseded();
    }
    if (snapshot.phase != RuntimePhase.running && !snapshot.connectionPending) {
      return snapshot;
    }

    var current = snapshot;
    for (var attempt = 0; attempt < 15; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      current = await _withRuntimeActionTimeout(
        'disconnectSnapshot',
        _runtimeEngine.snapshot,
        ownerGeneration: generation,
      );
      if (!_connectionCoordinator.ownsOperation(generation)) {
        throw const ConnectionOperationSuperseded();
      }
      if (_disposed) {
        return current;
      }
      _update(() {
        _runtimeSnapshot = current;
        _runtimeHeadline = null;
      });
      if (current.phase != RuntimePhase.running && !current.connectionPending) {
        return current;
      }
    }
    return current;
  }

  bool _isTerminalConnectMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('failed') ||
        normalized.contains('denied') ||
        normalized.contains('error') ||
        normalized.contains('stopped') ||
        normalized.contains('не удалось') ||
        normalized.contains('отказ') ||
        normalized.contains('ошиб') ||
        normalized.contains('останов');
  }

  bool _canPrimaryConnect(RuntimeSnapshot? snapshot) {
    if (snapshot == null) {
      return false;
    }
    if (snapshot.phase == RuntimePhase.running) {
      return true;
    }
    if (!snapshot.supportsLiveConnect) {
      return false;
    }
    return snapshot.phase != RuntimePhase.artifactMissing;
  }

  void _promoteStagedLocationAfterFreshConnect() {
    if (materialCandidate?.warpMode == 'warp_over_proxy') {
      _update(() {
        _activeNodeCode = '';
        _activeVariantId = 'direct';
      });
      return;
    }
    final staged = _stagedNodeCode.trim().toLowerCase();
    final stagedVariant =
        normalizeClientLocationVariantId(_stagedVariantId) ?? 'direct';
    // A profile staged for a preceding failed connect is still fresh. Promote
    // it only once its later reconnect is confirmed running.
    if (staged.isEmpty ||
        (staged == _activeNodeCode && stagedVariant == _activeVariantId)) {
      return;
    }
    _update(() {
      _activeNodeCode = staged;
      _activeVariantId = stagedVariant;
    });
  }

  void selectRouteMode(RouteMode mode) {
    // Same selection tick as the theme and location picks — one class of
    // interaction, one haptic.
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    _update(() {
      _selectedRouteMode = mode;
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _clientExperience = _clientExperience.copyWith(
        firstRouteScopeConfirmed: true,
        firstRouteScopeMode: mode,
      );
    });
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    if (wasConnected && !_selectedAppsRouteNeedsSelection) {
      unawaited(
        _reconnectAfterManagedProfileChange(
          progressMessage: 'Применяем новый режим маршрутизации…',
          successMessage: 'Режим маршрутизации применён.',
        ),
      );
    }
  }

  void setRoutingPreferences(PokrovRoutingPreferences preferences) {
    _update(() {
      _clientExperience = _clientExperience.copyWith(
        routingPreferences: preferences,
      );
      _startAndroidNetworkPolicyObservation();
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _runtimeHeadline =
          'Правила сохранены. Применим при следующем подключении.';
    });
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
  }

  void applyRoutingPreferences(PokrovRoutingPreferences preferences) {
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    if (!wasConnected) {
      _update(() {
        _runtimeHeadline =
            'Правила сохранены. Они применятся при следующем подключении.';
      });
      _notify(
        'Правила сохранены. Подключите POKROV, чтобы применить.',
        tone: PokrovSnackTone.success,
      );
      return;
    }
    unawaited(_applyRoutingPreferencesToRunningTunnel(preferences));
  }

  Future<void> _applyRoutingPreferencesToRunningTunnel(
    PokrovRoutingPreferences preferences,
  ) async {
    if (preferences.pauseOnTrustedWifi) {
      await _pauseRunningTunnelOnTrustedWifi();
    }
    if (_disposed || _runtimeSnapshot?.phase != RuntimePhase.running) {
      return;
    }
    await _reconnectAfterManagedProfileChange(
      progressMessage: 'Применяем правила подключения…',
      successMessage: 'Правила подключения применены.',
    );
  }

  Future<void> _saveConnectionPreference(PokrovClientExperienceState next) async {
    final previousBinding = _managedProfileCacheInputs.binding('', '');
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    var changed = false;
    _update(() {
      _clientExperience = next;
      _preferredNodeCode = next.preferredNodeCode;
      _preferredVariantId = next.preferredVariantId;
      changed = previousBinding != _managedProfileCacheInputs.binding('', '');
      if (changed) {
        _cancelAutomaticFailover();
        _stagedNodeCode = '';
        _stagedVariantId = 'direct';
        _managedProfileDirty = true;
        _cachedProfileFallbackGate.markUserChange();
      }
    });
    _queueClientExperienceWrite();
    if (!changed) return;
    _invalidateQuickSettingsProfile();
    if (wasConnected) {
      await _reconnectAfterManagedProfileChange(
        progressMessage: 'Применяем выбор подключения…',
        successMessage: 'Выбор подключения применён.',
      );
    }
  }

  Future<void> setInterfaceMode(PokrovInterfaceMode mode) async {
    if (_nodePreferenceBusy || mode == _clientExperience.interfaceMode) return;
    var country = _clientExperience.preferredCountryCode;
    if (mode == PokrovInterfaceMode.simple) {
      for (final candidate in _transportCatalog?.candidates ?? const <domain.TransportCandidate>[]) {
        if (candidate.candidateRef == _clientExperience.preferredCandidateRef ||
            _preferredNodeCode.isNotEmpty && candidate.nodeCode == _preferredNodeCode) {
          country = candidate.nodeCountryCode(_transportCatalog!.candidates);
          break;
        }
      }
    }
    await _saveConnectionPreference(_clientExperience.copyWith(
      interfaceMode: mode, preferredCountryCode: country,
      preferredNodeCode: mode == PokrovInterfaceMode.simple ? '' : _preferredNodeCode,
      preferredVariantId: mode == PokrovInterfaceMode.simple ? 'direct' : _preferredVariantId,
      preferredCandidateRef: mode == PokrovInterfaceMode.simple ? '' : _clientExperience.preferredCandidateRef,
    ));
  }

  Future<void> setPreferredCountry(String value) async {
    final country = value.trim().toUpperCase();
    if (_nodePreferenceBusy || !RegExp(r'^[A-Z]{2}$').hasMatch(country)) return;
    await _saveConnectionPreference(_clientExperience.copyWith(
      preferredCountryCode: country, preferredNodeCode: '',
      preferredVariantId: 'direct', preferredCandidateRef: '',
    ));
  }

  Future<void> setPreferredCandidate(String value) async {
    final candidateRef = value.trim();
    if (_nodePreferenceBusy || _clientExperience.interfaceMode != PokrovInterfaceMode.advanced) return;
    if (!(_transportCatalog?.candidates.any((candidate) => candidate.candidateRef == candidateRef) ?? false)) return;
    await _saveConnectionPreference(_clientExperience.copyWith(
      preferredCountryCode: '', preferredNodeCode: '',
      preferredVariantId: 'direct', preferredCandidateRef: candidateRef,
    ));
  }

  Future<void> setPreferredLocation(
    String nodeCode,
    String variantId,
  ) async {
    final smartConnect = _smartConnectProfile;
    final normalized = nodeCode.trim().toLowerCase();
    final normalizedVariant = normalizeClientLocationVariantId(variantId);
    ClientLocationCity? catalogCity;
    for (final country
        in _locationsCatalog?.countries ?? const <ClientLocationCountry>[]) {
      for (final city in country.cities) {
        if (city.code.trim().toLowerCase() == normalized) {
          catalogCity = city;
          break;
        }
      }
      if (catalogCity != null) {
        break;
      }
    }
    final knownCatalogCode = catalogCity != null;
    final catalogConfirmsVariant = catalogCity == null
        ? normalizedVariant == 'direct'
        : catalogCity.variants.isEmpty
            ? normalizedVariant == 'direct'
            : catalogCity.variants.any(
                (variant) =>
                    variant.id == normalizedVariant && variant.available,
              );
    if (normalized.isEmpty ||
        normalizedVariant == null ||
        !catalogConfirmsVariant ||
        _nodePreferenceBusy ||
        (smartConnect == null && !knownCatalogCode)) {
      return;
    }
    if (normalizedVariant != 'direct' &&
        _warpRuntimeConsent &&
        _managedWarpPolicy.canOfferRuntime) {
      const message =
          'WARP пока нельзя использовать с вариантом «Белые списки». Выключите WARP или выберите «Обычный».';
      _update(() {
        _runtimeHeadline = message;
      });
      _notify(message, tone: PokrovSnackTone.danger);
      return;
    }

    _cancelAutomaticFailover();
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    final previousPreferredNodeCode = _preferredNodeCode;
    final previousPreferredVariantId = _preferredVariantId;
    final previousStagedNodeCode = _stagedNodeCode;
    final previousStagedVariantId = _stagedVariantId;
    final previousManagedProfileDirty = _managedProfileDirty;
    final previousHeadline = _runtimeHeadline;
    final experienceAtRequest = _clientExperience;
    _update(() {
      _nodePreferenceBusy = true;
    });
    try {
      var confirmed = normalized;
      final service = _nodePreferenceService;
      if (service != null && smartConnect != null) {
        final locations = _locationsCatalog;
        // Ordinary node eligibility follows the locations policy, not the
        // transport of the last candidate (which can be a legacy lab alias).
        final preference = _transportCatalog != null && knownCatalogCode && locations != null &&
                locations.transportProfile.trim().isNotEmpty && locations.profileRevision.trim().isNotEmpty
            ? SmartConnectProfile(
                eligible: smartConnect.eligible, fallbackRequired: smartConnect.fallbackRequired,
                shortlistReason: smartConnect.shortlistReason, shortlistLimit: smartConnect.shortlistLimit,
                shortlistRevision: smartConnect.shortlistRevision,
                transportProfile: locations.transportProfile, profileRevision: locations.profileRevision,
                fallbackOrder: smartConnect.fallbackOrder, shortlist: smartConnect.shortlist,
                stickiness: smartConnect.stickiness)
            : smartConnect;
        final result = await service.setPreferredSmartConnectNode(
          hostPlatform: _appContext.hostPlatform,
          smartConnect: preference,
          nodeCode: normalized,
        );
        if (_disposed) {
          return;
        }
        confirmed = result.preferredNodeCode.trim().toLowerCase();
        if (confirmed.isEmpty) {
          throw const BootstrapFailure('Не удалось подтвердить локацию.');
        }
      }
      if (_disposed) {
        return;
      }
      final confirmedVariant =
          confirmed == normalized ? normalizedVariant : 'direct';
      final recentCodes = <String>[
        confirmed,
        ..._clientExperience.recentNodeCodes.where((item) => item != confirmed),
      ].take(12).toList(growable: false);
      _update(() {
        _preferredNodeCode = confirmed;
        _preferredVariantId = confirmedVariant;
        _stagedNodeCode = '';
        _stagedVariantId = 'direct';
        _managedProfileDirty = true;
        _cachedProfileFallbackGate.markUserChange();
        _runtimeHeadline = wasConnected
            ? 'Локация сохранена. Переподключите POKROV, чтобы применить.'
            : 'Локация сохранена. Подключите POKROV, чтобы применить.';
        _clientExperience = _clientExperience.copyWith(
          recentNodeCodes: recentCodes,
          interfaceMode: PokrovInterfaceMode.advanced,
          preferredCountryCode: '',
          preferredCandidateRef: '',
          preferredNodeCode: confirmed,
          preferredVariantId: confirmedVariant,
        );
      });
      _invalidateQuickSettingsProfile();
      _queueClientExperienceWrite();
      if (wasConnected) {
        await _reconnectAfterManagedProfileChange(
          progressMessage: 'Переключаем локацию…',
          successMessage: 'Локация применена.',
        );
      } else {
        _notify(
          'Локация сохранена. Подключите POKROV.',
          tone: PokrovSnackTone.success,
        );
      }
    } on BootstrapFailure catch (error) {
      if (_disposed) {
        return;
      }
      _update(() {
        _preferredNodeCode = identical(_clientExperience, experienceAtRequest)
            ? previousPreferredNodeCode
            : _clientExperience.preferredNodeCode;
        _preferredVariantId = identical(_clientExperience, experienceAtRequest)
            ? previousPreferredVariantId
            : _clientExperience.preferredVariantId;
        _stagedNodeCode = previousStagedNodeCode;
        _stagedVariantId = previousStagedVariantId;
        _managedProfileDirty = previousManagedProfileDirty;
        _runtimeHeadline = previousHeadline;
      });
      _notify(error.message, tone: PokrovSnackTone.danger);
    } on Object {
      if (_disposed) {
        return;
      }
      _update(() {
        _preferredNodeCode = identical(_clientExperience, experienceAtRequest)
            ? previousPreferredNodeCode
            : _clientExperience.preferredNodeCode;
        _preferredVariantId = identical(_clientExperience, experienceAtRequest)
            ? previousPreferredVariantId
            : _clientExperience.preferredVariantId;
        _stagedNodeCode = previousStagedNodeCode;
        _stagedVariantId = previousStagedVariantId;
        _managedProfileDirty = previousManagedProfileDirty;
        _runtimeHeadline = previousHeadline;
      });
      _notify(
        'Не удалось сохранить локацию. Проверьте подключение и попробуйте ещё раз.',
        tone: PokrovSnackTone.danger,
      );
    } finally {
      if (!_disposed) {
        _update(() {
          _nodePreferenceBusy = false;
        });
      }
    }
  }

  void addSelectedAppId(String value) {
    final normalized = normalizePokrovSelectedAppIdentifier(
      value,
      hostPlatform: _appContext.hostPlatform,
    );
    if (normalized == null || _selectedAppIds.contains(normalized)) {
      return;
    }
    if (_selectedAppIds.length >= 128) {
      _update(() {
        _runtimeHeadline =
            'Можно выбрать не больше 128 приложений. Удалите одно, чтобы добавить другое.';
      });
      _notify(
        'Можно выбрать не больше 128 приложений. Удалите одно, чтобы добавить другое.',
        tone: PokrovSnackTone.danger,
      );
      return;
    }
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    _update(() {
      _selectedAppIds.add(normalized);
      if (_selectedRouteMode != RouteMode.excludedApps &&
          _appContext.runtimeProfile.supportedRouteModes.contains(
            RouteMode.selectedApps,
          )) {
        _selectedRouteMode = RouteMode.selectedApps;
      }
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _clientExperience = _clientExperience.copyWith(
        selectedAppIds: List<String>.unmodifiable(_selectedAppIds),
        catalogVerifiedRuPreset: false,
      );
    });
    _recordAndroidSelectedAppCount();
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    if (wasConnected && !_selectedAppsRouteNeedsSelection) {
      unawaited(
        _reconnectAfterManagedProfileChange(
          progressMessage: 'Применяем список приложений…',
          successMessage: 'Список приложений применён.',
        ),
      );
    }
  }

  void applyRuAppPreset(
      RouteMode mode, List<String> appIds, bool verifiedCatalog) {
    if (mode != RouteMode.selectedApps && mode != RouteMode.excludedApps) {
      return;
    }
    if (!_appContext.runtimeProfile.supportedRouteModes.contains(mode)) {
      return;
    }
    final normalized = appIds
        .map(
          (value) => normalizePokrovSelectedAppIdentifier(
            value,
            hostPlatform: _appContext.hostPlatform,
          ),
        )
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    if (normalized.length > 128) {
      _notify('Выберите не больше 128 приложений вручную.',
          tone: PokrovSnackTone.danger);
      return;
    }
    if (normalized.isEmpty) {
      _notify(
        'На устройстве не найдено приложений из RU-каталога.',
        tone: PokrovSnackTone.danger,
      );
      return;
    }
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    _update(() {
      _selectedRouteMode = mode;
      _selectedAppIds
        ..clear()
        ..addAll(normalized);
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _clientExperience = _clientExperience.copyWith(
        selectedAppIds: List<String>.unmodifiable(_selectedAppIds),
        catalogVerifiedRuPreset: verifiedCatalog,
        firstRouteScopeConfirmed: true,
        firstRouteScopeMode: mode,
      );
      _runtimeHeadline = mode == RouteMode.excludedApps
          ? 'RU-приложения пойдут напрямую, остальные — через VPN.'
          : 'Только выбранные RU-приложения пойдут через VPN.';
    });
    _recordAndroidSelectedAppCount();
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    if (wasConnected) {
      unawaited(
        _reconnectAfterManagedProfileChange(
          progressMessage: 'Применяем RU-пресет…',
          successMessage: 'RU-пресет применён.',
        ),
      );
    } else {
      _notify(
        'RU-пресет сохранён. Подключите POKROV.',
        tone: PokrovSnackTone.success,
      );
    }
  }

  Future<void> setAutomaticLocation() async {
    if (_nodePreferenceBusy || (_preferredNodeCode.trim().isEmpty &&
        _clientExperience.preferredCountryCode.isEmpty && _clientExperience.preferredCandidateRef.isEmpty)) {
      return;
    }

    _cancelAutomaticFailover();
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    _update(() {
      _preferredNodeCode = '';
      _preferredVariantId = 'direct';
      _stagedNodeCode = '';
      _stagedVariantId = 'direct';
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _runtimeHeadline = wasConnected
          ? 'Автоматический выбор включен. Переподключите POKROV, чтобы применить.'
          : 'Автоматический выбор включен. Подключите POKROV, чтобы применить.';
      _clientExperience = _clientExperience.copyWith(
        preferredNodeCode: '',
        preferredVariantId: 'direct',
        preferredCountryCode: '',
        preferredCandidateRef: '',
      );
    });
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    if (wasConnected) {
      await _reconnectAfterManagedProfileChange(
        progressMessage: 'Включаем автоматический выбор…',
        successMessage: 'Автоматический выбор применён.',
      );
    } else {
      _notify(
        'Автоматический выбор включен. Подключите POKROV.',
        tone: PokrovSnackTone.success,
      );
    }
  }

  void removeSelectedAppId(String value) {
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    _update(() {
      _selectedAppIds.remove(value);
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _clientExperience = _clientExperience.copyWith(
        selectedAppIds: List<String>.unmodifiable(_selectedAppIds),
        catalogVerifiedRuPreset: false,
      );
    });
    _recordAndroidSelectedAppCount();
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    if (wasConnected && !_selectedAppsRouteNeedsSelection) {
      unawaited(
        _reconnectAfterManagedProfileChange(
          progressMessage: 'Применяем список приложений…',
          successMessage: 'Список приложений применён.',
        ),
      );
    }
  }

  void _recordAndroidSelectedAppCount() {
    _observability?.recordAndroidRoutingAppCount(_selectedAppIds.length);
  }

  void reconcilePreferredVariantAfterCatalogRefresh(
    ClientLocationsCatalog catalog,
  ) {
    if (_nodePreferenceBusy) {
      return;
    }
    final preferredCode = _preferredNodeCode.trim().toLowerCase();
    final preferredVariant =
        normalizeClientLocationVariantId(_preferredVariantId) ?? 'direct';
    if (preferredCode.isEmpty || preferredVariant == 'direct') {
      return;
    }

    ClientLocationCity? selectedCity;
    for (final country in catalog.countries) {
      for (final city in country.cities) {
        if (city.code.trim().toLowerCase() == preferredCode) {
          selectedCity = city;
          break;
        }
      }
      if (selectedCity != null) {
        break;
      }
    }
    if (selectedCity == null) {
      return;
    }
    final variants = selectedCity.variants;
    final selectedStillAvailable = variants.any(
      (variant) => variant.id == preferredVariant && variant.available,
    );
    final directAvailable = variants.isEmpty ||
        variants.any(
          (variant) => variant.id == 'direct' && variant.available,
        );
    if (selectedStillAvailable || !directAvailable) {
      return;
    }

    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    _update(() {
      _preferredVariantId = 'direct';
      _stagedNodeCode = '';
      _stagedVariantId = 'direct';
      if (_activeNodeCode.trim().toLowerCase() == preferredCode &&
          normalizeClientLocationVariantId(_activeVariantId) ==
              preferredVariant) {
        _activeNodeCode = '';
        _activeVariantId = 'direct';
      }
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _runtimeHeadline = wasConnected
          ? 'Вариант подключения изменился. Переподключаем POKROV…'
          : 'Выбранный вариант больше недоступен. Используется «Обычный».';
      _clientExperience = _clientExperience.copyWith(
        preferredVariantId: 'direct',
      );
    });
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    _notify(
      'Выбранный вариант больше недоступен. Включён «Обычный».',
      tone: PokrovSnackTone.info,
    );
    if (wasConnected) {
      unawaited(
        _reconnectAfterManagedProfileChange(
          progressMessage: 'Обновляем вариант подключения…',
          successMessage: 'Вариант подключения обновлён.',
        ),
      );
    }
  }
}
