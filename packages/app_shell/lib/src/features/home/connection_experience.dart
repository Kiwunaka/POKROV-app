part of pokrov_app_shell;

enum ConnectionExperiencePhase {
  idle,
  permissionRequired,
  preparing,
  connecting,
  connectedUnverified,
  connectedVerified,
  disconnecting,
  reconnecting,
  blocked,
  failed,
}

enum ConnectionStage {
  idle,
  permission,
  profile,
  coreStart,
  tunnel,
  network,
  dns,
  egress,
  complete,
}

enum ConnectionTransitionIntent {
  none,
  permission,
  prepare,
  connect,
  disconnect,
  reconnect,
  recover,
}

enum ConnectionBlockReason {
  runtimeArtifactMissing,
  permissionRequired,
  unavailable,
}

enum ConnectionTone { muted, success, warning, danger }

enum ConnectionDiscPhase {
  idle,
  preparing,
  connecting,
  connected,
  disconnecting,
  reconnecting,
  error,
}

enum ConnectionHapticIntent { none, tap, success, error }

sealed class ConnectionExperienceState {
  const ConnectionExperienceState({
    required this.phase,
    required this.stage,
    this.snapshot,
  });

  final ConnectionExperiencePhase phase;
  final ConnectionStage stage;
  final RuntimeSnapshot? snapshot;
}

final class ConnectionIdle extends ConnectionExperienceState {
  const ConnectionIdle({super.snapshot})
      : super(
          phase: ConnectionExperiencePhase.idle,
          stage: ConnectionStage.idle,
        );
}

final class ConnectionPermissionRequired extends ConnectionExperienceState {
  const ConnectionPermissionRequired({super.snapshot})
      : super(
          phase: ConnectionExperiencePhase.permissionRequired,
          stage: ConnectionStage.permission,
        );
}

final class ConnectionPreparing extends ConnectionExperienceState {
  const ConnectionPreparing({
    required super.stage,
    super.snapshot,
  }) : super(phase: ConnectionExperiencePhase.preparing);
}

final class ConnectionConnecting extends ConnectionExperienceState {
  const ConnectionConnecting({
    required super.stage,
    required this.attempt,
    super.snapshot,
  }) : super(phase: ConnectionExperiencePhase.connecting);

  final int attempt;
}

final class ConnectionConnectedUnverified extends ConnectionExperienceState {
  const ConnectionConnectedUnverified({
    required super.stage,
    required RuntimeSnapshot super.snapshot,
  }) : super(phase: ConnectionExperiencePhase.connectedUnverified);
}

final class ConnectionConnectedVerified extends ConnectionExperienceState {
  const ConnectionConnectedVerified({
    required RuntimeSnapshot super.snapshot,
  }) : super(
          phase: ConnectionExperiencePhase.connectedVerified,
          stage: ConnectionStage.complete,
        );
}

final class ConnectionDisconnecting extends ConnectionExperienceState {
  const ConnectionDisconnecting({super.snapshot})
      : super(
          phase: ConnectionExperiencePhase.disconnecting,
          stage: ConnectionStage.tunnel,
        );
}

final class ConnectionReconnecting extends ConnectionExperienceState {
  const ConnectionReconnecting({
    required super.stage,
    required this.attempt,
    super.snapshot,
  }) : super(phase: ConnectionExperiencePhase.reconnecting);

  final int attempt;
}

final class ConnectionBlocked extends ConnectionExperienceState {
  const ConnectionBlocked({
    required this.reason,
    super.snapshot,
  }) : super(
          phase: ConnectionExperiencePhase.blocked,
          stage: ConnectionStage.idle,
        );

  final ConnectionBlockReason reason;
}

final class ConnectionFailed extends ConnectionExperienceState {
  const ConnectionFailed({
    required this.reasonCode,
    required super.stage,
    required this.retryable,
    super.snapshot,
  }) : super(phase: ConnectionExperiencePhase.failed);

  final String reasonCode;
  final bool retryable;
}

class ConnectionExperienceReducer {
  const ConnectionExperienceReducer._();

  static ConnectionExperienceState reduce({
    required RuntimeSnapshot? snapshot,
    required ConnectionTransitionIntent intent,
    required bool actionInFlight,
    int attempt = 1,
    bool boundProofPending = false,
  }) {
    if (actionInFlight) {
      return switch (intent) {
        ConnectionTransitionIntent.permission =>
          ConnectionPermissionRequired(snapshot: snapshot),
        ConnectionTransitionIntent.disconnect =>
          ConnectionDisconnecting(snapshot: snapshot),
        ConnectionTransitionIntent.reconnect ||
        ConnectionTransitionIntent.recover =>
          ConnectionReconnecting(
            stage: _stageFor(snapshot),
            attempt: attempt,
            snapshot: snapshot,
          ),
        ConnectionTransitionIntent.prepare => ConnectionPreparing(
            stage: _stageFor(snapshot),
            snapshot: snapshot,
          ),
        ConnectionTransitionIntent.connect => ConnectionConnecting(
            stage: _stageFor(snapshot),
            attempt: attempt,
            snapshot: snapshot,
          ),
        ConnectionTransitionIntent.none => ConnectionPreparing(
            stage: _stageFor(snapshot),
            snapshot: snapshot,
          ),
      };
    }

    if (snapshot == null) {
      return const ConnectionIdle();
    }
    if (snapshot.phase == RuntimePhase.running) {
      if (snapshot.isCleanlyHealthy && !boundProofPending) {
        return ConnectionConnectedVerified(snapshot: snapshot);
      }
      return ConnectionConnectedUnverified(
        stage: boundProofPending || snapshot.transportProofPending == true
            ? ConnectionStage.egress : _verificationStageFor(snapshot),
        snapshot: snapshot,
      );
    }
    final reasonCode = snapshot.lastFailureKind?.trim();
    if (reasonCode != null && reasonCode.isNotEmpty) {
      return ConnectionFailed(
        reasonCode: reasonCode,
        stage: _stageFor(snapshot),
        retryable: true,
        snapshot: snapshot,
      );
    }
    if (snapshot.phase == RuntimePhase.artifactMissing) {
      return ConnectionBlocked(
        reason: ConnectionBlockReason.runtimeArtifactMissing,
        snapshot: snapshot,
      );
    }
    if (snapshot.connectionPending) {
      return ConnectionPermissionRequired(snapshot: snapshot);
    }
    return ConnectionIdle(snapshot: snapshot);
  }

  static ConnectionStage _stageFor(RuntimeSnapshot? snapshot) {
    if (snapshot == null) {
      return ConnectionStage.profile;
    }
    if (snapshot.phase == RuntimePhase.artifactReady) {
      return ConnectionStage.coreStart;
    }
    if (snapshot.phase == RuntimePhase.initialized ||
        snapshot.phase == RuntimePhase.configStaged) {
      return ConnectionStage.tunnel;
    }
    return _verificationStageFor(snapshot);
  }

  static ConnectionStage _verificationStageFor(RuntimeSnapshot snapshot) {
    if (snapshot.dnsReady != true ||
        snapshot.dnsState != RuntimeDiagnosticState.healthy) {
      return ConnectionStage.dns;
    }
    if (snapshot.coreEgressValidated != true) {
      return ConnectionStage.egress;
    }
    return ConnectionStage.network;
  }
}

class ConnectionPresentation {
  const ConnectionPresentation({
    required this.experience,
    required this.title,
    required this.subtitle,
    required this.primaryActionLabel,
    required this.primaryActionEnabled,
    required this.discPhase,
    required this.tone,
    required this.semanticLabel,
    required this.showsTunnelActive,
    required this.showsConnectedVisual,
    required this.isVerified,
    required this.isDegraded,
    required this.discMotionBusy,
  });

  factory ConnectionPresentation.fromExperience(
    ConnectionExperienceState experience, {
    required bool primaryConnectEnabled,
    bool canCancelConnect = false,
  }) {
    final phase = experience.phase;
    final snapshot = experience.snapshot;
    final tunnelActive = snapshot?.phase == RuntimePhase.running;
    final awaitingVerification = experience is ConnectionConnectedUnverified &&
        !snapshot!.hasDegradedHostDiagnostics &&
        snapshot.dnsReady != false &&
        snapshot.coreEgressValidated != false;
    final verified = experience is ConnectionConnectedVerified;
    final degraded =
        experience is ConnectionConnectedUnverified && !awaitingVerification;
    final transitioning = const <ConnectionExperiencePhase>{
      ConnectionExperiencePhase.preparing,
      ConnectionExperiencePhase.connecting,
      ConnectionExperiencePhase.disconnecting,
      ConnectionExperiencePhase.reconnecting,
    }.contains(phase);

    final title = switch (phase) {
      ConnectionExperiencePhase.idle => 'Не защищено',
      ConnectionExperiencePhase.permissionRequired => 'Нужен доступ к VPN',
      ConnectionExperiencePhase.preparing => 'Подготавливаем профиль',
      ConnectionExperiencePhase.connecting => _stageTitle(experience.stage),
      ConnectionExperiencePhase.connectedUnverified =>
        awaitingVerification ? 'Проверяем…' : 'Нужно внимание',
      ConnectionExperiencePhase.connectedVerified => 'Подключено',
      ConnectionExperiencePhase.disconnecting => 'Завершаем соединение',
      ConnectionExperiencePhase.reconnecting => 'Восстанавливаем соединение',
      ConnectionExperiencePhase.blocked => 'Не получилось подключиться',
      ConnectionExperiencePhase.failed => 'Не удалось подключиться',
    };
    final actionLabel = canCancelConnect ? 'Отменить' : switch (phase) {
      ConnectionExperiencePhase.idle =>
        primaryConnectEnabled ? 'Подключить' : 'Пока недоступно',
      ConnectionExperiencePhase.permissionRequired => 'Разрешить',
      ConnectionExperiencePhase.preparing ||
      ConnectionExperiencePhase.connecting =>
        'Подключаемся…',
      ConnectionExperiencePhase.connectedUnverified ||
      ConnectionExperiencePhase.connectedVerified =>
        'Отключить',
      ConnectionExperiencePhase.disconnecting => 'Отключаем…',
      ConnectionExperiencePhase.reconnecting => 'Переподключаем…',
      ConnectionExperiencePhase.blocked => 'Пока недоступно',
      ConnectionExperiencePhase.failed => 'Повторить',
    };
    final actionEnabled = canCancelConnect ? true : switch (phase) {
      ConnectionExperiencePhase.idle ||
      ConnectionExperiencePhase.permissionRequired ||
      ConnectionExperiencePhase.failed =>
        primaryConnectEnabled,
      ConnectionExperiencePhase.connectedUnverified ||
      ConnectionExperiencePhase.connectedVerified =>
        true,
      ConnectionExperiencePhase.preparing ||
      ConnectionExperiencePhase.connecting ||
      ConnectionExperiencePhase.disconnecting ||
      ConnectionExperiencePhase.reconnecting ||
      ConnectionExperiencePhase.blocked =>
        false,
    };
    final discPhase = switch (phase) {
      ConnectionExperiencePhase.idle ||
      ConnectionExperiencePhase.permissionRequired =>
        ConnectionDiscPhase.idle,
      ConnectionExperiencePhase.preparing => ConnectionDiscPhase.preparing,
      ConnectionExperiencePhase.connecting => ConnectionDiscPhase.connecting,
      ConnectionExperiencePhase.connectedUnverified => awaitingVerification
          ? ConnectionDiscPhase.connecting
          : ConnectionDiscPhase.error,
      ConnectionExperiencePhase.connectedVerified =>
        ConnectionDiscPhase.connected,
      ConnectionExperiencePhase.disconnecting =>
        ConnectionDiscPhase.disconnecting,
      ConnectionExperiencePhase.reconnecting =>
        ConnectionDiscPhase.reconnecting,
      ConnectionExperiencePhase.blocked ||
      ConnectionExperiencePhase.failed =>
        ConnectionDiscPhase.error,
    };
    final tone = switch (phase) {
      ConnectionExperiencePhase.connectedVerified => ConnectionTone.success,
      ConnectionExperiencePhase.connectedUnverified => ConnectionTone.warning,
      ConnectionExperiencePhase.failed => ConnectionTone.danger,
      ConnectionExperiencePhase.blocked => ConnectionTone.warning,
      ConnectionExperiencePhase.idle ||
      ConnectionExperiencePhase.permissionRequired ||
      ConnectionExperiencePhase.preparing ||
      ConnectionExperiencePhase.connecting ||
      ConnectionExperiencePhase.disconnecting ||
      ConnectionExperiencePhase.reconnecting =>
        ConnectionTone.muted,
    };
    final subtitle = switch (phase) {
      ConnectionExperiencePhase.connectedVerified =>
        'DNS и выход через VPN подтверждены',
      ConnectionExperiencePhase.connectedUnverified => awaitingVerification
          ? 'Туннель запущен, подтверждаем DNS и выход'
          : 'Туннель работает, одна из проверок требует внимания',
      ConnectionExperiencePhase.disconnecting => 'Останавливаем туннель',
      ConnectionExperiencePhase.reconnecting =>
        'Повторно проверяем защищённый маршрут',
      ConnectionExperiencePhase.failed => 'Можно безопасно повторить попытку',
      ConnectionExperiencePhase.blocked =>
        'На этом устройстве не завершена подготовка',
      ConnectionExperiencePhase.permissionRequired =>
        'Разрешение нужно для системного VPN',
      ConnectionExperiencePhase.preparing ||
      ConnectionExperiencePhase.connecting =>
        _stageSubtitle(experience.stage),
      ConnectionExperiencePhase.idle => 'Защита выключена',
    };

    return ConnectionPresentation(
      experience: experience,
      title: title,
      subtitle: subtitle,
      primaryActionLabel: actionLabel,
      primaryActionEnabled: actionEnabled,
      discPhase: discPhase,
      tone: tone,
      // The action owns only its action name. Connection state is announced
      // by the dedicated status live region, so assistive technology does not
      // hear the same transition from both the CTA and status control.
      semanticLabel: actionLabel,
      showsTunnelActive: tunnelActive,
      showsConnectedVisual: verified || degraded,
      isVerified: verified,
      isDegraded: degraded,
      discMotionBusy: transitioning || awaitingVerification,
    );
  }

  final ConnectionExperienceState experience;
  final String title;
  final String subtitle;
  final String primaryActionLabel;
  final bool primaryActionEnabled;
  final ConnectionDiscPhase discPhase;
  final ConnectionTone tone;
  final String semanticLabel;
  final bool showsTunnelActive;
  final bool showsConnectedVisual;
  final bool isVerified;
  final bool isDegraded;
  final bool discMotionBusy;

  static String _stageTitle(ConnectionStage stage) => switch (stage) {
        ConnectionStage.permission => 'Нужен доступ к VPN',
        ConnectionStage.profile => 'Подготавливаем профиль',
        ConnectionStage.coreStart => 'Запускаем защиту',
        ConnectionStage.tunnel => 'Создаём защищённое соединение',
        ConnectionStage.network => 'Проверяем интернет',
        ConnectionStage.dns => 'Проверяем DNS',
        ConnectionStage.egress => 'Подтверждаем защиту',
        ConnectionStage.idle || ConnectionStage.complete => 'Подключаемся…',
      };

  static String _stageSubtitle(ConnectionStage stage) => switch (stage) {
        ConnectionStage.permission => 'Ждём системное разрешение',
        ConnectionStage.profile => 'Получаем и проверяем настройки',
        ConnectionStage.coreStart => 'Готовим POKROV Core',
        ConnectionStage.tunnel => 'Запускаем системный туннель',
        ConnectionStage.network => 'Проверяем доступность сети',
        ConnectionStage.dns => 'Проверяем защищённый DNS',
        ConnectionStage.egress => 'Проверяем выбранный выход через VPN',
        ConnectionStage.idle ||
        ConnectionStage.complete =>
          'Настраиваем защищённое соединение',
      };
}

/// Immutable state consumed by the Home protection block.
///
/// [connection] remains the only owner of connection copy, CTA, semantics and
/// connect-disc visuals. The remaining fields are presentation context for the
/// same protection surface, not a second connection state machine.
class ProtectionViewState {
  const ProtectionViewState({
    required this.connection,
    required this.routeMode,
    required this.locationLabel,
    required this.emergencyRuntimeActive,
    required this.emergencyChainMode,
    required this.connectHintVisible,
    required this.whitelistRecoverySuggested,
    this.slowConnectionVisible = false,
    this.vpnPermissionRecoveryVisible = false,
    this.routeChangesPending = false,
    this.runtimeNotice,
  });

  final ConnectionPresentation connection;
  final RouteMode routeMode;
  final String locationLabel;
  final bool emergencyRuntimeActive;
  final EmergencyChainMode emergencyChainMode;
  final bool connectHintVisible;
  final bool whitelistRecoverySuggested;
  final bool slowConnectionVisible;
  final bool vpnPermissionRecoveryVisible;
  final bool routeChangesPending;

  /// Secondary recovery/info copy. It never replaces connection status or CTA
  /// copy owned by [connection].
  final String? runtimeNotice;
}

/// User intents exposed by the Home protection block.
///
/// Keeping callbacks together makes the composition root pass one explicit
/// protection boundary instead of leaking individual feature actions through
/// the screen tree.
class ProtectionIntents {
  const ProtectionIntents({
    required this.toggleConnection,
    required this.openConnectionDetails,
    required this.openLocations,
    required this.openRules,
    required this.openRecovery,
  });

  final Future<void> Function() toggleConnection;
  final VoidCallback openConnectionDetails;
  final VoidCallback openLocations;
  final VoidCallback openRules;
  final VoidCallback openRecovery;
}

/// A superseded async result must not change the current connection projection.
class ConnectionOperationSuperseded implements Exception {
  const ConnectionOperationSuperseded();

  @override
  String toString() => 'connection_operation_superseded';
}

class _ActiveTransportLease {
  const _ActiveTransportLease({required this.engine, required this.requestId,
    required this.profileDigest, required this.endpointLeaseRef,
    required this.profileRef, required this.endpointRef, required this.capabilityRef});
  final PokrovRuntimeEngine engine;
  final String requestId, profileDigest, endpointLeaseRef;
  final String profileRef, endpointRef, capabilityRef;
}

/// Owns mutable connection orchestration state for the shell.
///
/// Host actions and product decisions remain injected by the composition root;
/// this coordinator owns only the snapshot/intent/action/attempt lifecycle and
/// derives the existing reducer and presenter from that one state.
class ConnectionCoordinator {
  ConnectionCoordinator({
    required this.primaryConnectEnabled,
    required this.actionTimeout,
    this.slowStageThreshold = const Duration(seconds: 10),
    TransportRoutingIntent Function(CatalogDomainPolicy? catalogPolicy, String? catalogAccessState,
      TransportSmartAccessGrantResolver? smartAccessGrantResolver)? captureTransportRoutingIntent,
    TransportRestrictionPersistence? persistTransportRestrictions,
    TransportRuntimeControlEnrollment? enrollTransportRuntimeControl,
    TransportPayloadProbePreparation? prepareTransportPayload,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now, _captureTransportRoutingIntent = captureTransportRoutingIntent,
    _persistTransportRestrictions = persistTransportRestrictions,
    _enrollTransportRuntimeControl = enrollTransportRuntimeControl,
    _prepareTransportPayload = prepareTransportPayload;

  final bool Function(RuntimeSnapshot? snapshot) primaryConnectEnabled;
  final Duration actionTimeout;
  final Duration slowStageThreshold;
  final DateTime Function() _now;
  final TransportRoutingIntent Function(CatalogDomainPolicy? catalogPolicy, String? catalogAccessState,
    TransportSmartAccessGrantResolver? smartAccessGrantResolver)? _captureTransportRoutingIntent;
  final TransportRestrictionPersistence? _persistTransportRestrictions;
  final TransportRuntimeControlEnrollment? _enrollTransportRuntimeControl;
  final TransportPayloadProbePreparation? _prepareTransportPayload;

  RuntimeSnapshot? _snapshot;
  bool _actionInFlight = false;
  ConnectionTransitionIntent _intent = ConnectionTransitionIntent.none;
  DateTime? _attemptStartedAt;
  int _attemptNumber = 0;
  int _operationGeneration = 0;
  TransportSelection? _transportSelection;
  _ActiveTransportLease? _activeTransportLease;
  bool _transportProofPending = false;
  String? _cancellableConnectRequestId;
  bool _primaryConnectCancellationAllowed = false;
  Completer<void> _operationEnded = Completer<void>();
  Completer<void> _operationChanged = Completer<void>();
  SmartAccessRuntimeLeases? _stagedSmartAccessLeases;
  SmartAccessRuntimeLeases? _activeSmartAccessLeases;
  final _smartAccessRenewals = <String, SmartAccessLeaseRenewal>{};
  final _pendingSmartAccessRevocations = <String, SmartAccessLeaseRevocation>{};
  final _smartAccessRevocations = <String, SmartAccessLeaseRevocation>{};
  bool _catalogRevoked = false;
  bool _catalogWithdrawn = false;
  bool _catalogRevocationAcknowledged = false;
  SmartAccessLeaseRevocation? _smartAccessPolicyRevocation;
  SmartAccessLeaseRevocation? _smartAccessPolicyAcknowledged;
  final _catalogServiceRevocations = <String>{};
  final _catalogServiceAcknowledgements = <String>{};
  String? _revokedServiceCatalogSha256;
  DateTime? _revokedServiceCatalogExpiresAt;
  final _revokedCatalogServices = <String>{};
  String? _smartAccessSelectionSeed;
  String? _revokedCatalogSha256;
  DateTime? _revokedCatalogExpiresAt;
  bool _disposed = false;
  Timer? _slowStageTimer;
  VoidCallback? _onSlowStage;
  bool _slowStageVisible = false;

  RuntimeSnapshot? get snapshot => _snapshot;
  bool get hasActiveTransportLease => _activeTransportLease != null;
  bool get actionInFlight => _actionInFlight;
  ConnectionTransitionIntent get intent => _intent;
  DateTime? get attemptStartedAt => _attemptStartedAt;
  int get attemptNumber => _attemptNumber;
  int get operationGeneration => _operationGeneration;
  bool get canCancelPrimaryConnect => _primaryConnectCancellationAllowed &&
      _tracksSlowStage && !_disposed;
  String? get cancellableConnectRequestId => canCancelPrimaryConnect
      ? _cancellableConnectRequestId : null;

  void bindCancellableConnect(String requestId, {required int generation}) {
    if (ownsOperation(generation) && canCancelPrimaryConnect) {
      _cancellableConnectRequestId = requestId;
    }
  }
  bool ownsOperation(int generation) =>
      !_disposed && generation == _operationGeneration;
  Future<void> whenOperationEnds(int generation) => ownsOperation(generation)
      ? _operationEnded.future : Future<void>.value();
  Future<void> whenOperationChanges(int generation) => ownsOperation(generation)
      ? _operationChanged.future : Future<void>.value();

  Future<TransportSelection> beginTransportSelection({required TransportManifestSelection source,
      String? networkContextRef, required PokrovRuntimeEngine engine,
      required Set<String> families, required RuntimeSnapshot runtime,
        required int generation, CatalogDomainPolicy? catalogPolicy, String? catalogAccessState,
        TransportSmartAccessGrantResolver? smartAccessGrantResolver}) async {
    void closeUnusedSource() {
      if (!identical(source, _transportSelection?.source)) source.close();
    }
    if (!ownsOperation(generation) || !_actionInFlight) {
      closeUnusedSource();
      throw const ConnectionOperationSuperseded();
    }
    final previous = _transportSelection;
    if (previous != null && (previous.hasPendingChildren || previous.hasOwnedTunnel || previous.generation == generation)) {
      closeUnusedSource();
      _transportSelectionFail('budget_owned');
    }
    RuntimeTransportNetworkContext? networkSource;
    var capturedNetworkRef = networkContextRef;
    late final TransportTimeWindow now;
    try {
      if (const {HostPlatform.android, HostPlatform.windows, HostPlatform.linux}.contains(runtime.hostPlatform)) {
        if (engine is! RuntimeTransportNetworkContext) _transportSelectionFail('network_context_unavailable');
        networkSource = engine;
        capturedNetworkRef = await networkSource.readTransportNetworkContext();
      }
      now = await source.sample();
    } on Object {
      closeUnusedSource();
      rethrow;
    }
    if (!ownsOperation(generation) || !_actionInFlight) {
      closeUnusedSource();
      throw const ConnectionOperationSuperseded();
    }
    if (!identical(previous, _transportSelection)) {
      closeUnusedSource();
      _transportSelectionFail('budget_owned');
    }
    try {
      final capture = _captureTransportRoutingIntent;
      if (capture == null) _transportSelectionFail('routing_owner_unavailable');
      if (capturedNetworkRef == null) _transportSelectionFail('network_context_unavailable');
      final context = TransportSelectionContext(networkContextRef: capturedNetworkRef,
        networkSource: networkSource,
          routingIntent: capture(catalogPolicy, catalogAccessState, smartAccessGrantResolver),
          families: families, runtime: runtime, admission: source.admission);
      if (!context.matchesRuntimeCore(_snapshot)) _transportSelectionFail('core_identity_changed');
      final selection = TransportSelection._(source: source, context: context, generation: generation,
        operationIsCurrent: () => ownsOperation(generation) && _actionInFlight,
        now: now);
      _transportSelection = selection;
      return selection;
    } on Object {
      closeUnusedSource();
      rethrow;
    }
  }

  void invalidateTransportRoutingIntent() => _transportSelection?.cancel('routing_intent_changed');

  /// A committed signed kill fences protection before native revocation IO.
  /// Exact stopped readback is the fallback when the Core ACK is uncertain.
  Future<RuntimeSnapshot?> applyTransportAdmission(TransportAdmission admission) async {
    final active = _activeTransportLease;
    if (active == null) return null;
    final kills = admission.effectiveKills;
    final binding = admission.capabilityBindings[active.capabilityRef];
    final forbidden = (kills['profile_refs'] as List).contains(active.profileRef) ||
        (kills['endpoint_refs'] as List).contains(active.endpointRef) ||
        (kills['capability_refs'] as List).contains(active.capabilityRef) ||
        binding == null || !binding.profileRefs.contains(active.profileRef);
    if (!forbidden) return null;
    return _revokeActiveTransportLease(active);
  }

  Future<RuntimeSnapshot?> withdrawTransportAuthority() async {
    final active = _activeTransportLease;
    return active == null ? null : _revokeActiveTransportLease(active);
  }

  Future<RuntimeSnapshot?> _revokeActiveTransportLease(_ActiveTransportLease active) async {
    _transportProofPending = true;
    final engine = active.engine;
    try {
      if (engine is! RuntimeConnectCancellation || engine.activeConnectRequestId != active.requestId) {
        throw StateError('transport_lease_owner_unavailable');
      }
      if (engine is! RuntimeTransportLeaseRevocation) throw StateError('transport_lease_revocation_unavailable');
      final native = await engine.revokeBoundTransportLease(requestId: active.requestId,
        profileDigest: active.profileDigest, endpointLeaseRef: active.endpointLeaseRef,
        terminateActive: true);
      if (!identical(active, _activeTransportLease)) return null;
      _activeTransportLease = null;
      updateSnapshot(native);
      return native;
    } on Object {
      if (engine is RuntimeConnectSettlement) {
        try {
          if (await engine.cancelAndConfirmConnectStopped(active.requestId)) {
            _activeTransportLease = null;
            final native = await engine.snapshot();
            updateSnapshot(native);
            return native;
          }
        } on Object { /* Keep protection fenced until exact cleanup is confirmed. */ }
      }
      return null;
    }
  }

  Future<TransportConnectAcknowledgement> resolveAndConnectTransportProfile({
      required String attemptRef, required TransportProfileQuery query,
      required TransportEndpointHint hint,
      required AppFirstTransportManifestService service, required PokrovRuntimeEngine engine,
      required int generation, required bool repair}) async {
    final selection = _transportSelection;
    if (!ownsOperation(generation) || !_actionInFlight || selection == null ||
        selection.generation != generation) throw const ConnectionOperationSuperseded();
    late final TransportStagedProfile staged;
    try {
      staged = await selection.resolveAndStageProfile(attemptRef: attemptRef, query: query, hint: hint,
        service: service, engine: engine, repair: repair, persistRestrictions: _persistTransportRestrictions);
      final catalog = staged.prepared.catalogPolicy;
      if (catalog != null) {
        if (staged._catalogIdentity == null) _transportSelectionFail('restriction_stage_unconfirmed');
        acknowledgeSmartAccessStage(staged.snapshot,
          catalog.smartAccessProfile?.byService.values.expand((group) => group) ?? const <VerifiedSmartAccessLease>[],
          generation: generation, catalogIssuedAt: catalog.issuedAt, catalogExpiresAt: catalog.expiresAt,
          catalogSha256: catalog.payloadSha256, catalogIdentity: staged._catalogIdentity);
      }
    } on Object {
      await _settleFailedTransportAttempt(selection, attemptRef, engine, generation);
      rethrow;
    }
    return connectTransportProfile(staged, generation: generation);
  }

  Future<TransportConnectAcknowledgement> connectTransportProfile(
      TransportStagedProfile staged, {required int generation}) async {
    final selection = _transportSelection;
    if (!ownsOperation(generation) || !_actionInFlight || selection == null ||
        selection.generation != generation) throw const ConnectionOperationSuperseded();
    try {
      _transportProofPending = true;
      final acknowledgement = await selection.connectStagedProfile(staged,
        onRequestCreated: (requestId) => bindCancellableConnect(requestId, generation: generation),
        onProgress: (snapshot) {
          if (ownsOperation(generation) && _actionInFlight && identical(selection, _transportSelection)) {
            updateSnapshot(snapshot);
          }
        });
      if (!ownsOperation(generation) || !_actionInFlight ||
          !identical(selection, _transportSelection) || selection.stopReason != null) {
        selection.cancel('context_changed');
        throw const ConnectionOperationSuperseded();
      }
      // This only projects the native acknowledgement. The existing reducer and
      // subsequent proof stages still decide whether protection is established.
      updateSnapshot(acknowledgement.snapshot);
      return acknowledgement;
    } on Object {
      await _settleFailedTransportAttempt(selection, staged.attemptRef, staged._engine, generation);
      rethrow;
    }
  }

  Future<void> _settleFailedTransportAttempt(TransportSelection selection,
      String attemptRef, PokrovRuntimeEngine engine, int generation) async {
    if (selection._attemptRef != attemptRef) return;
    final stopped = await selection.stopNativeConnect();
    if (!stopped || selection._attemptRef != attemptRef || selection.hasPendingChildren ||
        !ownsOperation(generation) || !identical(selection, _transportSelection)) return;
    try {
      final now = await selection.sample();
      selection.finishAttempt(attemptRef, TransportAttemptResult.unknown, now);
    } on Object {
      // A closed context cannot admit another attempt.
    }
    try {
      final native = await engine.snapshot();
      if (ownsOperation(generation) && identical(selection, _transportSelection)) updateSnapshot(native);
    } on Object {
      // An unavailable read cannot clear proof pending.
    }
  }

  Future<TransportProofBatch> proveTransportConnection(TransportConnectAcknowledgement acknowledgement,
      {required int generation}) async {
    final selection = _transportSelection;
    if (!ownsOperation(generation) || !_actionInFlight || selection == null ||
        selection.generation != generation) throw const ConnectionOperationSuperseded();
    TransportProofBatch? proof;
    var promoted = false;
    try {
      await selection.enrollRuntimeControl(acknowledgement, _enrollTransportRuntimeControl);
      final completed = await selection.proveConnection(acknowledgement, preparePayload: _prepareTransportPayload);
      proof = completed;
      if (completed.allStagesPassed) {
        final native = await selection.promoteProof(completed);
        if (!ownsOperation(generation) || !identical(selection, _transportSelection)) {
          throw const ConnectionOperationSuperseded();
        }
        updateSnapshot(native);
        final settledAt = await selection.sample();
        if (!ownsOperation(generation) || !identical(selection, _transportSelection)) {
          throw const ConnectionOperationSuperseded();
        }
        final candidate = selection._candidate!;
        selection.finishAttempt(acknowledgement.staged.attemptRef, TransportAttemptResult.pass, settledAt);
        _activeTransportLease = _ActiveTransportLease(
          engine: acknowledgement.staged._engine,
          requestId: acknowledgement._owner.requestId!,
          profileDigest: acknowledgement.staged.nativeProfileDigest,
          endpointLeaseRef: candidate.endpointLeaseRef,
          profileRef: candidate.profileRef,
          endpointRef: candidate.endpointRef,
          capabilityRef: candidate.capabilityRef,
        );
        _transportProofPending = false;
        promoted = true;
      }
      return completed;
    } finally {
      if (!promoted) {
        final failure = proof != null && proof.observations.isNotEmpty ? proof.observations.last : null;
        final canRetry = proof?.allStagesPassed != true && failure != null &&
            failure.outcome != RuntimeBoundProbeOutcome.cancelled &&
            selection.stopReason == null;
        final stopped = canRetry
            ? await selection.stopAfterFailedProof()
            : await selection.stopNativeConnect();
        if (stopped && ownsOperation(generation) && identical(selection, _transportSelection)) {
          try {
            if (canRetry) {
              final now = await selection.sample();
              final observation = failure!;
              final outcome = observation.outcome == RuntimeBoundProbeOutcome.fail && observation.receipt != null
                  ? TransportAttemptResult.fail
                  : observation.outcome == RuntimeBoundProbeOutcome.unavailable
                      ? TransportAttemptResult.unavailable : TransportAttemptResult.unknown;
              selection.finishAttempt(acknowledgement.staged.attemptRef, outcome, now);
            }
            final native = await acknowledgement.staged._engine.snapshot();
            if (ownsOperation(generation) && identical(selection, _transportSelection)) updateSnapshot(native);
          } on Object {
            // Leave proof pending until a current native snapshot is available.
          }
        }
      }
    }
  }

  /// Retains the old selector across generations until exact cleanup succeeds.
  Future<bool> stopTransportConnect() async {
    final selection = _transportSelection;
    if (selection == null) return true;
    selection.cancel('user_cancelled');
    return selection.stopNativeConnect();
  }

  SmartAccessRuntimeLeases? get activeSmartAccessLeases =>
      !_disposed && _snapshot?.phase == RuntimePhase.running &&
      _snapshot?.effectiveProfileDigest == _activeSmartAccessLeases?.profileDigest
          ? _activeSmartAccessLeases : null;

  void acknowledgeSmartAccessStage(RuntimeSnapshot staged,
      Iterable<VerifiedSmartAccessLease> grants, {required int generation,
      DateTime? catalogIssuedAt, DateTime? catalogExpiresAt, String? catalogSha256,
      CatalogRuntimeIdentity? catalogIdentity}) {
    if (!ownsOperation(generation) || staged.phase != RuntimePhase.configStaged) return;
    final digest = staged.stagedProfileDigest;
    final verified = List<VerifiedSmartAccessLease>.unmodifiable(grants);
    _stagedSmartAccessLeases = digest != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)
        ? SmartAccessRuntimeLeases(digest, verified.map(SmartAccessLeaseIdentity.fromGrant),
          catalogIssuedAt: catalogIssuedAt, catalogExpiresAt: catalogExpiresAt, catalogSha256: catalogSha256,
          catalogIdentity: catalogIdentity, verifiedGrants: verified) : null;
  }

  SmartAccessRuntimeLeases? get stagedSmartAccessLeases => _stagedSmartAccessLeases;

  void invalidateSmartAccessStagedReuse(String profileDigest) {
    if (_stagedSmartAccessLeases?.profileDigest == profileDigest) _stagedSmartAccessLeases = null;
  }

  SmartAccessLeaseRenewal? pendingSmartAccessRenewal(String leaseId) => _smartAccessRenewals[leaseId];

  void discardSmartAccessRenewal(SmartAccessLeaseRenewal renewal, {required int generation}) {
    if (ownsOperation(generation) && identical(_smartAccessRenewals[renewal.previousLeaseId], renewal)) {
      _smartAccessRenewals.remove(renewal.previousLeaseId);
    }
  }

  SmartAccessLeaseRenewal prepareSmartAccessRenewal(SmartAccessRuntimeLeases binding,
      String previousLeaseId, VerifiedSmartAccessLease next, {required int generation, required Set<String> currentLeaseIds}) {
    if (!ownsOperation(generation) || !identical(activeSmartAccessLeases, binding) ||
        _smartAccessRenewals.containsKey(previousLeaseId)) throw const ConnectionOperationSuperseded();
    final renewal = SmartAccessLeaseRenewal.prepare(binding: binding,
      previousLeaseId: previousLeaseId, next: next, now: _now().toUtc(), currentLeaseIds: currentLeaseIds);
    _smartAccessRenewals[previousLeaseId] = renewal;
    if (!smartAccessRenewalIsCurrent(renewal, generation: generation)) {
      _smartAccessRenewals.remove(previousLeaseId);
      throw const ConnectionOperationSuperseded();
    }
    return renewal;
  }

  bool smartAccessRenewalIsCurrent(SmartAccessLeaseRenewal renewal, {required int generation}) {
    final active = activeSmartAccessLeases;
    final now = _now().toUtc();
    return ownsOperation(generation) && !_actionInFlight && active != null &&
        active.profileDigest == renewal.binding.profileDigest &&
        identical(_smartAccessRenewals[renewal.previousLeaseId], renewal) &&
        active.leases.any((grant) => grant.matches(renewal.previous)) &&
        !_catalogRevoked && _smartAccessPolicyRevocation == null &&
        !_catalogServiceRevocations.contains(renewal.next.lease['service_id']) &&
        !_pendingSmartAccessRevocations.containsKey(renewal.previousLeaseId) &&
        !_pendingSmartAccessRevocations.containsKey(renewal.nextLeaseId) &&
        active.catalogIssuedAt != null && active.catalogExpiresAt != null &&
        !now.isBefore(active.catalogIssuedAt!) && now.isBefore(active.catalogExpiresAt!) &&
        renewal.next.admitsNewFlows(now);
  }

  bool retainSmartAccessRenewal(SmartAccessLeaseRenewal renewal, StoredSmartAccessRuntime stored,
      {required int generation}) {
    if (!smartAccessRenewalIsCurrent(renewal, generation: generation)) return false;
    final active = activeSmartAccessLeases!;
    final retained = stored.binding;
    final next = SmartAccessLeaseIdentity.fromGrant(renewal.next);
    if (retained.profileDigest != active.profileDigest || retained.catalogSha256 != active.catalogSha256 ||
        retained.catalogIssuedAt != active.catalogIssuedAt || retained.catalogExpiresAt != active.catalogExpiresAt ||
        !retained.leases.any((lease) => lease.matches(next)) ||
        active.leases.any((lease) => _now().toUtc().isBefore(lease.activeFlowsUntil) &&
          !retained.leases.any((storedLease) => storedLease.matches(lease)))) {
      throw const RoutingCatalogFailure('smart_access_renewal_binding_missing');
    }
    final binding = SmartAccessRuntimeLeases(active.profileDigest, retained.leases,
      catalogIssuedAt: active.catalogIssuedAt, catalogExpiresAt: active.catalogExpiresAt,
      catalogSha256: active.catalogSha256, catalogIdentity: active.catalogIdentity,
      verifiedGrants: active.verifiedGrants);
    _activeSmartAccessLeases = binding;
    final ids = binding.leases.map((lease) => lease.leaseId).toSet();
    _pendingSmartAccessRevocations.removeWhere((id, _) => !ids.contains(id));
    _smartAccessRevocations.removeWhere((id, _) => !ids.contains(id));
    receiveSmartAccessRevocations(binding, stored.decisions);
    if (stored.catalogRevoked) receiveCatalogRevocation(binding, withdrawCatalog: stored.catalogWithdrawn);
    receiveCatalogServiceRevocations(binding, stored.catalogServiceRevocations);
    return smartAccessRenewalIsCurrent(renewal, generation: generation);
  }

  bool retainNativeSmartAccessLeases(StoredSmartAccessRuntime stored,
      {required int generation, required Set<String> currentLeaseIds, TransportRuntimeControl? transportControl}) {
    final ownedTransport = transportControl != null &&
      identical(transportControl._selection, _transportSelection) && transportControl.isCurrent &&
      transportControl.profileDigest == stored.binding.profileDigest;
    if (!ownsOperation(generation) || (_actionInFlight && !ownedTransport) || _snapshot?.phase != RuntimePhase.running ||
        _snapshot?.effectiveProfileDigest != stored.binding.profileDigest) return false;
    if (!(activeSmartAccessLeases?.hasRestrictionMetadata ?? false)) {
      restoreSmartAccessLeases(stored.binding, stored.decisions, generation: generation,
        catalogRevoked: stored.catalogRevoked, catalogWithdrawn: stored.catalogWithdrawn,
        catalogServiceRevocations: stored.catalogServiceRevocations);
    }
    final active = activeSmartAccessLeases;
    final retained = stored.binding;
    if (active == null || retained.catalogSha256 != active.catalogSha256 ||
        retained.catalogIssuedAt != active.catalogIssuedAt || retained.catalogExpiresAt != active.catalogExpiresAt ||
        active.leases.any((lease) => (_now().toUtc().isBefore(lease.activeFlowsUntil) || currentLeaseIds.contains(lease.leaseId)) &&
          !retained.leases.any((candidate) => candidate.matches(lease)))) {
      throw const RoutingCatalogFailure('smart_access_native_binding_mismatch');
    }
    final ids = retained.leases.map((lease) => lease.leaseId).toSet();
    final binding = SmartAccessRuntimeLeases(active.profileDigest, retained.leases,
      catalogIssuedAt: active.catalogIssuedAt, catalogExpiresAt: active.catalogExpiresAt,
      catalogSha256: active.catalogSha256, catalogIdentity: active.catalogIdentity,
      verifiedGrants: active.verifiedGrants.where((grant) => ids.contains(grant.lease['lease_id'])));
    _activeSmartAccessLeases = binding;
    _pendingSmartAccessRevocations.removeWhere((id, _) => !ids.contains(id));
    _smartAccessRevocations.removeWhere((id, _) => !ids.contains(id));
    // Native renewal can win against a pending foreground candidate. Discard
    // only that obsolete in-memory attempt; its retained identity stays intact.
    _smartAccessRenewals.removeWhere((_, renewal) => !currentLeaseIds.contains(renewal.previousLeaseId) &&
      !currentLeaseIds.contains(renewal.nextLeaseId));
    receiveSmartAccessRevocations(binding, stored.decisions);
    if (stored.catalogRevoked || _catalogRevoked) {
      receiveCatalogRevocation(binding, withdrawCatalog: stored.catalogWithdrawn || _catalogWithdrawn);
    }
    receiveCatalogServiceRevocations(binding, {..._catalogServiceRevocations, ...stored.catalogServiceRevocations});
    if (_smartAccessPolicyRevocation != null) receiveSmartAccessPolicyRevocation(binding, _smartAccessPolicyRevocation!);
    return true;
  }

  void acknowledgeSmartAccessRenewal(SmartAccessLeaseRenewal renewal, {required int generation}) {
    if (!smartAccessRenewalIsCurrent(renewal, generation: generation)) return;
    final active = activeSmartAccessLeases!;
    _activeSmartAccessLeases = SmartAccessRuntimeLeases(active.profileDigest, active.leases,
      catalogIssuedAt: active.catalogIssuedAt, catalogExpiresAt: active.catalogExpiresAt,
      catalogSha256: active.catalogSha256, catalogIdentity: active.catalogIdentity,
      verifiedGrants: [for (final grant in active.verifiedGrants)
        if (grant.lease['lease_id'] != renewal.previousLeaseId && grant.lease['lease_id'] != renewal.nextLeaseId) grant,
        renewal.next]);
    _smartAccessRenewals.remove(renewal.previousLeaseId);
    if (_stagedSmartAccessLeases?.profileDigest == active.profileDigest) _stagedSmartAccessLeases = null;
  }

  Future<List<Map<String, Object?>>> selectSmartAccessCapabilities({
    required VerifiedRoutingCatalog catalog, required VerifiedSmartAccessProviderPolicy providers,
    required Set<String> serviceIds, required String platform, required DateTime now,
    required bool Function() isCurrent,
  }) {
    if (_disposed || !isCurrent()) throw const ConnectionOperationSuperseded();
    final seed = _smartAccessSelectionSeed ??= (() {
      final random = math.Random.secure();
      return List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    })();
    final preferred = <String, String>{};
    final activeCapabilities = <String, Set<String>>{};
    final active = activeSmartAccessLeases;
    if (active != null && !_catalogRevoked && _smartAccessPolicyRevocation == null) {
      for (final lease in active.leases) {
        final serviceId = lease.lease['service_id']! as String;
        if (now.toUtc().isBefore(lease.activeFlowsUntil) && !_catalogServiceRevocations.contains(serviceId) &&
            !_pendingSmartAccessRevocations.containsKey(lease.leaseId)) {
          (activeCapabilities[serviceId] ??= {}).add(lease.lease['capability_id']! as String);
        }
      }
    }
    // Inventory includes standbys and history, not the native group's current
    // choice. Only an unambiguous single capability supplies affinity here.
    for (final entry in activeCapabilities.entries) {
      if (entry.value.length == 1) preferred[entry.key] = entry.value.single;
    }
    return selectSmartAccessWebCapabilities(catalog: catalog, providers: providers,
      serviceIds: serviceIds, platform: platform, now: now, selectionSeed: seed,
      preferredCapabilityIds: preferred, isCurrent: () => !_disposed && isCurrent());
  }

  void restoreSmartAccessLeases(SmartAccessRuntimeLeases binding,
      Map<String, SmartAccessLeaseRevocation> decisions, {required int generation,
      bool catalogRevoked = false, bool catalogWithdrawn = false, Set<String> catalogServiceRevocations = const {}}) {
    if (!ownsOperation(generation) || _snapshot?.phase != RuntimePhase.running ||
        _snapshot?.effectiveProfileDigest != binding.profileDigest ||
        (activeSmartAccessLeases?.hasRestrictionMetadata ?? false)) return;
    // A native digest alone can hold a received profile restriction while the
    // inventory is unavailable. Recovering metadata must not clear that kill.
    final sameProfile = _activeSmartAccessLeases?.profileDigest == binding.profileDigest;
    final receivedRevoke = sameProfile && _catalogRevoked;
    final receivedWithdrawal = sameProfile && _catalogWithdrawn;
    final revokeAcknowledged = sameProfile && _catalogRevocationAcknowledged;
    final policyRevocation = sameProfile ? _smartAccessPolicyRevocation : null;
    final policyAcknowledged = sameProfile ? _smartAccessPolicyAcknowledged : null;
    final receivedServices = sameProfile ? Set<String>.of(_catalogServiceRevocations) : <String>{};
    if (!sameProfile) _catalogServiceAcknowledgements.clear();
    _catalogServiceRevocations.clear();
    _activeSmartAccessLeases = binding;
    _smartAccessRevocations.clear();
    _pendingSmartAccessRevocations.clear();
    _catalogRevoked = catalogRevoked || receivedRevoke;
    _catalogWithdrawn = catalogWithdrawn || receivedWithdrawal;
    _catalogRevocationAcknowledged = revokeAcknowledged;
    _smartAccessPolicyRevocation = null;
    _smartAccessPolicyAcknowledged = policyAcknowledged;
    receiveSmartAccessRevocations(binding, decisions);
    if (policyRevocation != null) receiveSmartAccessPolicyRevocation(binding, policyRevocation);
    if (_catalogRevoked) receiveCatalogRevocation(binding, withdrawCatalog: _catalogWithdrawn);
    receiveCatalogServiceRevocations(binding, {...receivedServices, ...catalogServiceRevocations});
  }

  void receiveCatalogRevocation(SmartAccessRuntimeLeases binding, {bool withdrawCatalog = false}) {
    if (identical(activeSmartAccessLeases, binding)) {
      _catalogRevoked = true;
      if (withdrawCatalog) {
        _catalogWithdrawn = true;
        if (binding.catalogSha256 != null && binding.catalogExpiresAt != null) {
          _revokedCatalogSha256 = binding.catalogSha256;
          _revokedCatalogExpiresAt = binding.catalogExpiresAt;
        }
      }
    }
  }

  // Survive a switch to a non-catalog profile even if secure storage failed.
  // Earlier catalog revisions remain excluded by the catalog cache's floors.
  bool isCatalogRevoked(String digest, DateTime now) => !_disposed &&
      _revokedCatalogSha256 == digest && _revokedCatalogExpiresAt != null &&
      now.isBefore(_revokedCatalogExpiresAt!);

  bool receivedCatalogRevocation(SmartAccessRuntimeLeases binding) =>
      identical(activeSmartAccessLeases, binding) && _catalogRevoked;

  bool receivedCatalogWithdrawal(SmartAccessRuntimeLeases binding) =>
      identical(activeSmartAccessLeases, binding) && _catalogWithdrawn;

  bool needsCatalogRevocation(SmartAccessRuntimeLeases binding) =>
      receivedCatalogRevocation(binding) && !_catalogRevocationAcknowledged;

  void acknowledgeCatalogRevocation(SmartAccessRuntimeLeases binding) {
    if (needsCatalogRevocation(binding)) _catalogRevocationAcknowledged = true;
  }

  void receiveCatalogServiceRevocations(SmartAccessRuntimeLeases binding, Set<String> serviceIds) {
    if (!identical(activeSmartAccessLeases, binding) || serviceIds.isEmpty) return;
    if (serviceIds.any((id) => binding.catalogIdentity?.services.containsKey(id) != true)) {
      throw const RoutingCatalogFailure('catalog_service_revocation_invalid');
    }
    _catalogServiceRevocations.addAll(serviceIds);
    if (_revokedServiceCatalogSha256 != binding.catalogSha256) _revokedCatalogServices.clear();
    _revokedServiceCatalogSha256 = binding.catalogSha256;
    _revokedServiceCatalogExpiresAt = binding.catalogExpiresAt;
    _revokedCatalogServices.addAll(serviceIds);
    receiveSmartAccessRevocations(binding, {for (final lease in binding.leases)
      if (serviceIds.contains(lease.lease['service_id'])) lease.leaseId: SmartAccessLeaseRevocation.terminate});
  }

  bool isCatalogServiceRevoked(String digest, Iterable<String> serviceIds, DateTime now) =>
      !_disposed && digest == _revokedServiceCatalogSha256 && _revokedServiceCatalogExpiresAt != null &&
      now.isBefore(_revokedServiceCatalogExpiresAt!) && serviceIds.any(_revokedCatalogServices.contains);

  Set<String> receivedCatalogServiceRevocations(SmartAccessRuntimeLeases binding) =>
      identical(activeSmartAccessLeases, binding) ? Set.unmodifiable(_catalogServiceRevocations) : const {};

  Set<String> pendingCatalogServiceRevocations(SmartAccessRuntimeLeases binding) =>
      receivedCatalogServiceRevocations(binding).difference(_catalogServiceAcknowledgements);

  void acknowledgeCatalogServiceRevocation(SmartAccessRuntimeLeases binding, String serviceId) {
    if (identical(activeSmartAccessLeases, binding) && _catalogServiceRevocations.contains(serviceId)) {
      _catalogServiceAcknowledgements.add(serviceId);
      for (final lease in binding.leases) {
        if (lease.lease['service_id'] == serviceId) {
          acknowledgeSmartAccessRevocation(binding, lease.leaseId, SmartAccessLeaseRevocation.terminate);
        }
      }
    }
  }

  void receiveSmartAccessPolicyRevocation(SmartAccessRuntimeLeases binding, SmartAccessLeaseRevocation decision) {
    if (!identical(activeSmartAccessLeases, binding)) return;
    if (_smartAccessPolicyRevocation != SmartAccessLeaseRevocation.terminate) _smartAccessPolicyRevocation = decision;
    // Persist known identities through the existing per-lease restriction map.
    // Empty metadata stays memory-only; Core enumerates its own actual leases.
    receiveSmartAccessRevocations(binding, {for (final lease in binding.leases)
      lease.leaseId: _smartAccessPolicyRevocation!});
  }

  SmartAccessLeaseRevocation? pendingSmartAccessPolicyRevocation(SmartAccessRuntimeLeases binding) {
    if (!identical(activeSmartAccessLeases, binding) || _smartAccessPolicyRevocation == null ||
        _smartAccessPolicyAcknowledged == SmartAccessLeaseRevocation.terminate ||
        _smartAccessPolicyAcknowledged == _smartAccessPolicyRevocation) return null;
    return _smartAccessPolicyRevocation;
  }

  void acknowledgeSmartAccessPolicyRevocation(SmartAccessRuntimeLeases binding, SmartAccessLeaseRevocation decision) {
    if (identical(activeSmartAccessLeases, binding) &&
        _smartAccessPolicyAcknowledged != SmartAccessLeaseRevocation.terminate) _smartAccessPolicyAcknowledged = decision;
  }

  bool needsSmartAccessRevocation(SmartAccessRuntimeLeases binding, String leaseId,
      SmartAccessLeaseRevocation decision) {
    if (!identical(activeSmartAccessLeases, binding)) return false;
    if (_smartAccessPolicyAcknowledged == SmartAccessLeaseRevocation.terminate ||
        _smartAccessPolicyAcknowledged == decision) return false;
    final applied = _smartAccessRevocations[leaseId];
    return applied == null || (applied == SmartAccessLeaseRevocation.drain &&
        decision == SmartAccessLeaseRevocation.terminate);
  }

  void receiveSmartAccessRevocations(SmartAccessRuntimeLeases binding,
      Map<String, SmartAccessLeaseRevocation> decisions) {
    if (!identical(activeSmartAccessLeases, binding)) return;
    for (final entry in decisions.entries) {
      if (_pendingSmartAccessRevocations[entry.key] != SmartAccessLeaseRevocation.terminate) {
        _pendingSmartAccessRevocations[entry.key] = entry.value;
      }
    }
  }

  Map<String, SmartAccessLeaseRevocation> pendingSmartAccessRevocations(SmartAccessRuntimeLeases binding) =>
      Map.unmodifiable({for (final entry in _pendingSmartAccessRevocations.entries)
        if (needsSmartAccessRevocation(binding, entry.key, entry.value)) entry.key: entry.value});

  Map<String, SmartAccessLeaseRevocation> receivedSmartAccessRevocations(SmartAccessRuntimeLeases binding) =>
      identical(activeSmartAccessLeases, binding) ? Map.unmodifiable(_pendingSmartAccessRevocations) : const {};

  void acknowledgeSmartAccessRevocation(SmartAccessRuntimeLeases binding, String leaseId,
      SmartAccessLeaseRevocation decision) {
    if (needsSmartAccessRevocation(binding, leaseId, decision)) {
      _smartAccessRevocations[leaseId] = decision;
    }
  }

  void _advanceOperation() {
    _cancellableConnectRequestId = null;
    _primaryConnectCancellationAllowed = false;
    if (!_operationEnded.isCompleted) _operationEnded.complete();
    if (!_operationChanged.isCompleted) _operationChanged.complete();
    _operationEnded = Completer<void>();
    _operationChanged = Completer<void>();
    _operationGeneration += 1;
    _transportSelection?.cancel('context_changed');
  }
  bool get slowStageVisible => _slowStageVisible;

  ConnectionExperienceState get experience =>
      ConnectionExperienceReducer.reduce(
        snapshot: _snapshot,
        intent: _intent,
        actionInFlight: _actionInFlight,
        attempt: _attemptNumber < 1 ? 1 : _attemptNumber,
        boundProofPending: _transportProofPending ||
            (_snapshot?.transportLeaseActive == true && _activeTransportLease == null),
      );

  ConnectionPresentation get presentation =>
      ConnectionPresentation.fromExperience(
        experience,
        primaryConnectEnabled: primaryConnectEnabled(_snapshot),
        canCancelConnect: canCancelPrimaryConnect,
      );

  void updateSnapshot(RuntimeSnapshot? snapshot) {
    // A late snapshot from an older operation cannot discard the exact lease
    // owner needed to apply a newly received signed kill.
    final activeLease = _activeTransportLease;
    if (snapshot != null && snapshot.phase != RuntimePhase.running &&
        activeLease != null && activeLease.engine is RuntimeConnectCancellation &&
        (activeLease.engine as RuntimeConnectCancellation).activeConnectRequestId != activeLease.requestId) {
      _activeTransportLease = null;
    }
    final selection = _transportSelection;
    // An old healthy snapshot cannot clear the ATS proof requirement after a
    // stop ACK. First observe ended runtime with no retained native owner.
    if (snapshot?.transportProofPending == true) _transportProofPending = true;
    if (snapshot != null && snapshot.transportProofPending == false &&
        snapshot.phase != RuntimePhase.running && !snapshot.connectionPending &&
        selection?.hasOwnedTunnel != true && selection?.hasPendingChildren != true) _transportProofPending = false;
    if (selection != null && !selection.context.matchesRuntimeCore(snapshot)) {
      selection.cancel('core_identity_changed');
    }
    final previousStage = experience.stage;
    final digest = snapshot?.effectiveProfileDigest;
    if (digest != null && digest != _activeSmartAccessLeases?.profileDigest) {
      _smartAccessRenewals.clear();
      _activeSmartAccessLeases = digest == _stagedSmartAccessLeases?.profileDigest
          ? _stagedSmartAccessLeases : null;
      _pendingSmartAccessRevocations.clear();
      _smartAccessRevocations.clear();
      _catalogRevoked = false;
      _catalogWithdrawn = false;
      _catalogRevocationAcknowledged = false;
      _smartAccessPolicyRevocation = null;
      _smartAccessPolicyAcknowledged = null;
      _catalogServiceRevocations.clear();
      _catalogServiceAcknowledgements.clear();
    }
    if (snapshot != null && snapshot.phase != RuntimePhase.running) {
      _smartAccessRenewals.clear();
      if (_snapshot?.phase == RuntimePhase.running && _activeSmartAccessLeases != null) {
        // After a known stop, the same digest cannot prove which lease generation
        // a restarted Core loaded. Preserve restrictions, discard renewal authority.
        final binding = _activeSmartAccessLeases!;
        _activeSmartAccessLeases = SmartAccessRuntimeLeases(binding.profileDigest, binding.leases,
          catalogIssuedAt: binding.catalogIssuedAt, catalogExpiresAt: binding.catalogExpiresAt,
          catalogSha256: binding.catalogSha256, catalogIdentity: binding.catalogIdentity);
      }
      // A later restart can reuse the same staged bytes. Keep received kills,
      // but require acknowledgement from the new running instance again.
      _smartAccessRevocations.clear();
      _catalogRevocationAcknowledged = false;
      _smartAccessPolicyAcknowledged = null;
      _catalogServiceAcknowledgements.clear();
    }
    _snapshot = snapshot;
    if (_tracksSlowStage && experience.stage != previousStage) {
      _scheduleSlowStage();
    }
  }

  void updateActionInFlight(bool value) {
    if (value && !_actionInFlight) {
      _advanceOperation();
    }
    _actionInFlight = value;
    if (!value) {
      _cancelSlowStage();
    } else if (_tracksSlowStage && _slowStageTimer == null) {
      _scheduleSlowStage();
    }
  }

  void updateIntent(ConnectionTransitionIntent intent) {
    _intent = intent;
    if (!_tracksSlowStage) {
      _cancelSlowStage();
    } else {
      _scheduleSlowStage();
    }
  }

  void updateAttemptStartedAt(DateTime? value) {
    _attemptStartedAt = value;
  }

  void updateAttemptNumber(int value) {
    _attemptNumber = value < 0 ? 0 : value;
  }

  void beginAction(
    ConnectionTransitionIntent intent, {
    bool recordAttempt = false,
    bool allowConnectCancellation = false,
    VoidCallback? onSlowStage,
  }) {
    _advanceOperation();
    _actionInFlight = true;
    _intent = intent;
    _primaryConnectCancellationAllowed = allowConnectCancellation;
    _onSlowStage = onSlowStage;
    if (recordAttempt) {
      _attemptStartedAt = _now().toUtc();
      _attemptNumber += 1;
    }
    if (_tracksSlowStage) {
      _scheduleSlowStage();
    }
  }

  void finishAction({bool clearAttempt = false}) {
    _cancellableConnectRequestId = null;
    _primaryConnectCancellationAllowed = false;
    if (!_operationEnded.isCompleted) _operationEnded.complete();
    _cancelSlowStage();
    _actionInFlight = false;
    _transportSelection?.cancel('operation_finished');
    _intent = ConnectionTransitionIntent.none;
    if (clearAttempt) {
      _attemptStartedAt = null;
    }
  }

  void clearAttempt() {
    _attemptStartedAt = null;
  }

  bool get _tracksSlowStage =>
      _actionInFlight &&
      const <ConnectionTransitionIntent>{
        ConnectionTransitionIntent.connect,
        ConnectionTransitionIntent.reconnect,
        ConnectionTransitionIntent.recover,
      }.contains(_intent);

  void _scheduleSlowStage() {
    _slowStageTimer?.cancel();
    _slowStageVisible = false;
    _slowStageTimer = Timer(slowStageThreshold, () {
      if (!_tracksSlowStage) {
        return;
      }
      _slowStageVisible = true;
      _onSlowStage?.call();
    });
  }

  void _cancelSlowStage() {
    _slowStageTimer?.cancel();
    _slowStageTimer = null;
    _slowStageVisible = false;
    _onSlowStage = null;
  }

  void dispose() {
    _disposed = true;
    _smartAccessSelectionSeed = null;
    _advanceOperation();
    _stagedSmartAccessLeases = null;
    _activeSmartAccessLeases = null;
    _smartAccessRenewals.clear();
    _pendingSmartAccessRevocations.clear();
    _smartAccessRevocations.clear();
    _cancelSlowStage();
  }

  int? get attemptDurationMs {
    final startedAt = _attemptStartedAt;
    if (startedAt == null) {
      return null;
    }
    final duration = _now().toUtc().difference(startedAt).inMilliseconds;
    return duration < 0 ? 0 : duration;
  }

  Future<T> runWithTimeout<T>(
    String operation,
    Future<T> Function() action, {
    int? ownerGeneration,
    bool hostOwnsTimeout = false,
  }) async {
    final generation = ownerGeneration ?? _operationGeneration;
    if (!ownsOperation(generation)) {
      throw const ConnectionOperationSuperseded();
    }
    try {
      final pending = action();
      final result = await (hostOwnsTimeout
          ? pending
          : pending.timeout(
              actionTimeout,
              onTimeout: () => throw TimeoutException(
                'runtime action timed out: $operation',
                actionTimeout,
              ),
            ));
      if (!ownsOperation(generation)) {
        throw const ConnectionOperationSuperseded();
      }
      return result;
    } on Object {
      if (!ownsOperation(generation)) {
        throw const ConnectionOperationSuperseded();
      }
      rethrow;
    }
  }
}

class ConnectionExperienceTransitionMatrix {
  const ConnectionExperienceTransitionMatrix._();

  static bool isLegal(
    ConnectionExperiencePhase from,
    ConnectionExperiencePhase to,
  ) {
    if (from == to) {
      return true;
    }
    return (_legal[from] ?? const <ConnectionExperiencePhase>{}).contains(to);
  }

  static const Map<ConnectionExperiencePhase, Set<ConnectionExperiencePhase>>
      _legal = {
    ConnectionExperiencePhase.idle: {
      ConnectionExperiencePhase.permissionRequired,
      ConnectionExperiencePhase.preparing,
      ConnectionExperiencePhase.connecting,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.permissionRequired: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.preparing,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.preparing: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.connecting,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.connecting: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.disconnecting,
      ConnectionExperiencePhase.connectedUnverified,
      ConnectionExperiencePhase.connectedVerified,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.connectedUnverified: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.connectedVerified,
      ConnectionExperiencePhase.disconnecting,
      ConnectionExperiencePhase.reconnecting,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.connectedVerified: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.connectedUnverified,
      ConnectionExperiencePhase.disconnecting,
      ConnectionExperiencePhase.reconnecting,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.disconnecting: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.reconnecting: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.disconnecting,
      ConnectionExperiencePhase.connectedUnverified,
      ConnectionExperiencePhase.connectedVerified,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.blocked: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.permissionRequired,
      ConnectionExperiencePhase.preparing,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.failed: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.preparing,
      ConnectionExperiencePhase.connecting,
      ConnectionExperiencePhase.blocked,
    },
  };
}

class ConnectionHapticCoordinator {
  const ConnectionHapticCoordinator._();

  static ConnectionHapticIntent action(ConnectionPresentation presentation) =>
      presentation.primaryActionEnabled
          ? ConnectionHapticIntent.tap
          : ConnectionHapticIntent.none;

  static ConnectionHapticIntent outcome(
    ConnectionExperiencePhase from,
    ConnectionExperiencePhase to,
  ) {
    if (from == to) {
      return ConnectionHapticIntent.none;
    }
    if (to == ConnectionExperiencePhase.connectedVerified) {
      return ConnectionHapticIntent.success;
    }
    if (to == ConnectionExperiencePhase.failed) {
      return ConnectionHapticIntent.error;
    }
    return ConnectionHapticIntent.none;
  }
}
