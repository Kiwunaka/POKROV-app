part of pokrov_app_shell;

/// Owns foreground-refresh and post-connect diagnostic polling lifecycle.
///
/// It deliberately does not interpret runtime evidence. Callers retain the
/// typed connection reducer and inject the bounded poll action.
class DiagnosticsCoordinator {
  bool _resumeRefreshPending = false;
  Timer? _healthTimer;
  int _healthGeneration = 0;
  int? _healthPollInFlight;
  Timer? _runtimeTimer;
  bool _runtimePollInFlight = false;

  bool get resumeRefreshPending => _resumeRefreshPending;
  int get healthGeneration => _healthGeneration;
  bool get healthPollingActive => _healthTimer != null;

  /// Desktop service state remains observable after connect and in the tray.
  /// This reads local IPC only; it does not repeat network diagnostics.
  void startRuntimePolling(Future<void> Function() onPoll) {
    if (_runtimeTimer != null) return;
    _runtimeTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_runtimePollInFlight) return;
      _runtimePollInFlight = true;
      try {
        await onPoll();
      } finally {
        _runtimePollInFlight = false;
      }
    });
  }

  bool beginResumeRefresh() {
    if (_resumeRefreshPending) {
      return false;
    }
    _resumeRefreshPending = true;
    return true;
  }

  void finishResumeRefresh() {
    _resumeRefreshPending = false;
  }

  int startHealthPolling({
    required Duration interval,
    required int pollCount,
    required bool Function() canContinue,
    required void Function(int generation) onPoll,
  }) {
    stopHealthPolling();
    final generation = ++_healthGeneration;
    var pollsRemaining = pollCount < 0 ? 0 : pollCount;
    if (pollsRemaining == 0) {
      return generation;
    }
    _healthTimer = Timer.periodic(interval, (timer) {
      if (!canContinue() || generation != _healthGeneration) {
        timer.cancel();
        if (generation == _healthGeneration) {
          _healthTimer = null;
        }
        return;
      }
      pollsRemaining -= 1;
      onPoll(generation);
      if (pollsRemaining == 0) {
        timer.cancel();
        if (generation == _healthGeneration) {
          _healthTimer = null;
        }
      }
    });
    return generation;
  }

  bool isCurrentHealthGeneration(int generation) =>
      generation == _healthGeneration;

  bool beginHealthPoll(int generation) {
    if (!isCurrentHealthGeneration(generation) ||
        _healthPollInFlight == generation) {
      return false;
    }
    _healthPollInFlight = generation;
    return true;
  }

  void finishHealthPoll(int generation) {
    if (_healthPollInFlight == generation) {
      _healthPollInFlight = null;
    }
  }

  void stopHealthPolling() {
    _healthGeneration += 1;
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  void dispose() {
    _runtimeTimer?.cancel();
    _runtimeTimer = null;
    _resumeRefreshPending = false;
    stopHealthPolling();
    _healthPollInFlight = null;
  }
}

const pokrovClientBuildNumber = String.fromEnvironment(
  'POKROV_BUILD_NUMBER',
  defaultValue: '0',
);
const pokrovClientReleaseChannel = String.fromEnvironment(
  'POKROV_RELEASE_CHANNEL',
  defaultValue: 'local',
);
const pokrovClientCandidateLabel = String.fromEnvironment(
  'POKROV_CANDIDATE_LABEL',
  defaultValue: 'pokrov-local-client',
);
const pokrovClientGitRevision = String.fromEnvironment(
  'POKROV_GIT_REVISION',
  defaultValue: '0000000000000000000000000000000000000000',
);
const pokrovClientArchitecture = String.fromEnvironment(
  'POKROV_ARCHITECTURE',
  defaultValue: 'unknown',
);

OperationalBuildIdentity pokrovCurrentBuildIdentity(
  HostPlatform hostPlatform,
) =>
    OperationalBuildIdentity(
      appVersion: pokrovClientVersion,
      buildNumber: pokrovClientBuildNumber,
      channel: pokrovClientReleaseChannel,
      candidateLabel: pokrovClientCandidateLabel,
      gitRevision: pokrovClientGitRevision,
      coreVersion: null,
      coreAbi: null,
      platform: hostPlatform == HostPlatform.android ? 'android' : 'windows',
      architecture: pokrovClientArchitecture,
    );

typedef PokrovObservabilityDirectoryResolver = Future<Directory> Function();

enum PokrovOperationalUpdateChannel { direct, store, windows }

void installPokrovCrashHandlers(PokrovClientObservability observability) {
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    observability.markCrashSynchronously(errorCode: 'CRASH-001');
    previousFlutterHandler?.call(details);
  };
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  final previousPlatformHandler = dispatcher.onError;
  dispatcher.onError = (error, stack) {
    observability.markCrashSynchronously(errorCode: 'CRASH-001');
    return previousPlatformHandler?.call(error, stack) ?? false;
  };
}

final class PokrovClientObservability {
  PokrovClientObservability._({
    required this.hostPlatform,
    required this.dispatcher,
    required this.markerStore,
    required this.build,
    required this.runId,
    required this.ids,
  });

  final HostPlatform hostPlatform;
  final OperationalEventDispatcher dispatcher;
  final PreviousExitMarkerStore markerStore;
  final OperationalBuildIdentity build;
  final String runId;
  final OperationalIdFactory ids;
  int _generation = 0;
  OperationalAttemptTimeline? _attempt;
  String _lastExperienceFingerprint = '';
  bool _uiReadyRecorded = false;
  int _lastAndroidSelectedAppCount = -1;

  /// Returns only the already-sanitized, bounded connection timeline used by
  /// the local diagnostics screen. The dispatcher ring remains the authority;
  /// this view cannot read raw JSONL records or arbitrary event attributes.
  List<OperationalBreadcrumb> get connectionTimelineBreadcrumbs =>
      List<OperationalBreadcrumb>.unmodifiable(
        dispatcher.breadcrumbs.snapshot().where(
              (item) => item.name.startsWith('app.connection.'),
            ),
      );

  static Future<PokrovClientObservability> start({
    required HostPlatform hostPlatform,
    AppFirstReleaseHealthService? releaseHealthService,
    PokrovObservabilityDirectoryResolver? directoryResolver,
    OperationalBuildIdentity? buildIdentity,
    OperationalIdFactory? idFactory,
  }) async {
    if (hostPlatform != HostPlatform.android &&
        hostPlatform != HostPlatform.windows) {
      throw UnsupportedError(
        'Operational observability is shipped only for Android and Windows',
      );
    }
    final ids = idFactory ?? OperationalIdFactory();
    final build = buildIdentity ?? _defaultBuild(hostPlatform);
    final root = await (directoryResolver ?? getApplicationSupportDirectory)();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}pokrov-observability',
    );
    final localStore = RotatingOperationalJsonlStore(
      directory: directory,
      policy: OperationalStoragePolicy.forPlatform(
        hostPlatform == HostPlatform.android
            ? OperationalStoragePlatform.android
            : OperationalStoragePlatform.windows,
      ),
    );
    // The dispatcher initializes storage while draining and counts IO failures;
    // diagnostic persistence must not hold up the app's bootstrap.
    final OperationalEventWriter writer;
    if (releaseHealthService == null) {
      writer = localStore;
    } else {
      writer = ReleaseHealthMirrorWriter(
        localWriter: localStore,
        transport: (batch, correlationId) =>
            releaseHealthService.submitReleaseHealthBatch(
          hostPlatform: hostPlatform,
          batch: batch,
          correlationId: correlationId,
        ),
      );
    }
    final dispatcher = OperationalEventDispatcher(
      writer: writer,
      breadcrumbs: OperationalBreadcrumbRing(capacity: 256),
    );
    dispatcher.sequenceFence.activateGeneration(0);
    final runId = ids.uuidV4();
    final markerStore = PreviousExitMarkerStore(
      file: File(
        '${directory.path}${Platform.pathSeparator}previous-exit.v1.json',
      ),
    );
    final client = PokrovClientObservability._(
      hostPlatform: hostPlatform,
      dispatcher: dispatcher,
      markerStore: markerStore,
      build: build,
      runId: runId,
      ids: ids,
    );
    final startedAt = DateTime.now().toUtc();
    client._emitBootstrap(
      name: 'app.bootstrap.initialize.started',
      outcome: ObservabilityOutcome.started,
      stage: 'initialize',
    );
    final previous = await markerStore.beginRun(runId);
    client._recordPreviousExit(previous);
    client._emitBootstrap(
      name: 'app.bootstrap.initialize.finished',
      outcome: ObservabilityOutcome.succeeded,
      stage: 'complete',
      attributes: <String, Object?>{
        'phase': 'bootstrap',
        'duration_ms': DateTime.now()
            .toUtc()
            .difference(startedAt)
            .inMilliseconds
            .clamp(0, 86400000)
            .toInt(),
      },
    );
    return client;
  }

  Future<T> runConnectionAction<T>(
    Future<T> Function() action, {
    required bool beginsWithDisconnect,
  }) async {
    final previous = _attempt;
    if (previous != null && !previous.isTerminal) {
      previous.finish(OperationalTerminalKind.superseded);
    }
    _generation += 1;
    final attempt = OperationalAttemptTimeline(
      dispatcher: dispatcher,
      build: build,
      runId: runId,
      attemptId: ids.uuidV4(),
      generation: _generation,
      ids: ids,
    )..start();
    _attempt = attempt;
    _lastExperienceFingerprint = '';
    if (beginsWithDisconnect) {
      attempt.enter(OperationalTimelinePhase.rollback);
    }
    return attempt.runCorrelated(() async {
      try {
        final result = await action();
        return result;
      } on TimeoutException {
        if (!attempt.isTerminal) {
          attempt.finish(OperationalTerminalKind.timeout);
        }
        rethrow;
      } on BootstrapFailure catch (failure) {
        if (!attempt.isTerminal) {
          attempt.finish(
            OperationalTerminalKind.failed,
            errorCode: failure.operationalErrorCode,
            errorOrigin: ObservabilityErrorOrigin.portal,
          );
        }
        rethrow;
      } on Object {
        if (!attempt.isTerminal) {
          attempt.finish(
            OperationalTerminalKind.failed,
            errorCode: 'CONN-005',
          );
        }
        rethrow;
      }
    });
  }

  void observeConnection(ConnectionExperienceState experience) {
    final attempt = _attempt;
    if (attempt == null || attempt.isTerminal) {
      return;
    }
    final snapshot = experience.snapshot;
    final fingerprint = <Object?>[
      experience.phase.name,
      experience.stage.name,
      snapshot?.phase.name,
      snapshot?.hostHealth.name,
      snapshot?.dnsState.name,
      snapshot?.uplinkState.name,
      snapshot?.dnsReady,
      snapshot?.coreEgressValidated,
      snapshot?.lastFailureKind,
      snapshot?.lastStopReason,
    ].join(':');
    if (fingerprint == _lastExperienceFingerprint) {
      return;
    }
    _lastExperienceFingerprint = fingerprint;

    switch (experience) {
      case ConnectionPreparing():
        attempt.enter(OperationalTimelinePhase.profile);
      case ConnectionConnecting():
      case ConnectionReconnecting():
        attempt.enter(_timelinePhase(experience.stage));
      case ConnectionConnectedUnverified():
        attempt.enter(_timelinePhase(experience.stage));
        attempt.observeProof(_proofs(experience.snapshot!));
      case ConnectionConnectedVerified():
        _recordVerified(attempt, experience.snapshot!);
      case ConnectionDisconnecting():
        attempt.enter(OperationalTimelinePhase.rollback);
      case ConnectionFailed():
        attempt.enter(_timelinePhase(experience.stage));
        attempt.finish(
          OperationalTerminalKind.failed,
          errorCode: OperationalFailureMapper.connection(
            experience.reasonCode,
          ),
          errorOrigin: _runtimeErrorOrigin(experience.reasonCode),
        );
      case ConnectionBlocked():
        attempt.finish(
          OperationalTerminalKind.failed,
          errorCode:
              experience.reason == ConnectionBlockReason.runtimeArtifactMissing
                  ? 'CORE-001'
                  : 'CONN-005',
        );
      case ConnectionPermissionRequired():
        attempt.enter(OperationalTimelinePhase.profile);
      case ConnectionIdle():
        if (attempt.activePhase == OperationalTimelinePhase.rollback) {
          attempt.complete(
            OperationalTimelinePhase.rollback,
            outcome: ObservabilityOutcome.succeeded,
          );
          attempt.enter(OperationalTimelinePhase.stopped);
          attempt.complete(
            OperationalTimelinePhase.stopped,
            outcome: ObservabilityOutcome.succeeded,
          );
        }
        attempt.finish(OperationalTerminalKind.cancelled);
    }
  }

  void enterProfilePhase() {
    final attempt = _attempt;
    if (attempt != null && !attempt.isTerminal) {
      attempt.enter(OperationalTimelinePhase.profile);
    }
  }

  void recordConnectionFailure({
    required ConnectionStage stage,
    required String errorCode,
    ObservabilityErrorOrigin errorOrigin = ObservabilityErrorOrigin.client,
  }) {
    final attempt = _attempt;
    if (attempt == null || attempt.isTerminal) {
      return;
    }
    attempt.enter(_timelinePhase(stage));
    attempt.finish(
      OperationalTerminalKind.failed,
      errorCode: errorCode,
      errorOrigin: errorOrigin,
    );
  }

  void markUiReady() {
    if (_uiReadyRecorded || _generation != 0) {
      return;
    }
    _uiReadyRecorded = true;
    _emitBootstrap(
      name: 'app.bootstrap.ui_ready.finished',
      outcome: ObservabilityOutcome.succeeded,
      stage: 'complete',
    );
  }

  void recordUpdateCheckFailed() {
    _emitCurrent(
      name: 'app.update.check.finished',
      subsystem: 'update',
      stage: 'complete',
      outcome: ObservabilityOutcome.failed,
      errorCode: 'UPD-001',
      errorOrigin: ObservabilityErrorOrigin.portal,
      attributes: const <String, Object?>{'phase': 'update'},
    );
  }

  void recordUpdateInstallStarted({
    required PokrovOperationalUpdateChannel channel,
  }) {
    _emitCurrent(
      name: 'app.update.install.started',
      subsystem: 'update',
      stage: 'start',
      outcome: ObservabilityOutcome.started,
      attributes: <String, Object?>{
        'phase': 'update',
        'update_channel': channel.name,
      },
    );
  }

  void recordUpdateInstallFinished({
    required PokrovOperationalUpdateChannel channel,
    ClientUpdateFailure? failure,
  }) {
    _emitCurrent(
      name: 'app.update.install.finished',
      subsystem: 'update',
      stage: 'complete',
      outcome: failure == null
          ? ObservabilityOutcome.observed
          : ObservabilityOutcome.failed,
      errorCode:
          failure == null ? null : OperationalFailureMapper.update(failure),
      errorOrigin: failure == null
          ? ObservabilityErrorOrigin.client
          : ObservabilityErrorOrigin.host,
      attributes: <String, Object?>{
        'phase': 'update',
        'update_channel': channel.name,
      },
    );
  }

  void recordAuthRequestStarted() {
    _emitCurrent(
      name: 'app.auth.request.started',
      subsystem: 'auth',
      stage: 'request',
      outcome: ObservabilityOutcome.started,
      attributes: const <String, Object?>{
        'phase': 'auth',
        'operation': 'request',
      },
    );
  }

  void recordAuthRequestFinished({String? errorCode}) {
    _emitCurrent(
      name: 'app.auth.request.finished',
      subsystem: 'auth',
      stage: 'complete',
      outcome: errorCode == null
          ? ObservabilityOutcome.succeeded
          : ObservabilityOutcome.failed,
      errorCode: errorCode,
      errorOrigin: ObservabilityErrorOrigin.portal,
      attributes: <String, Object?>{
        'phase': 'auth',
        'operation': 'request',
        'status_class': errorCode == null ? 'success' : 'client_error',
      },
    );
  }

  void recordEntitlementRefreshStarted() {
    _emitCurrent(
      name: 'app.entitlement.refresh.started',
      subsystem: 'entitlement',
      stage: 'request',
      outcome: ObservabilityOutcome.started,
      attributes: const <String, Object?>{'operation': 'refresh'},
    );
  }

  void recordEntitlementRefreshFinished({String? errorCode}) {
    _emitCurrent(
      name: 'app.entitlement.refresh.finished',
      subsystem: 'entitlement',
      stage: 'complete',
      outcome: errorCode == null
          ? ObservabilityOutcome.succeeded
          : ObservabilityOutcome.failed,
      errorCode: errorCode,
      errorOrigin: ObservabilityErrorOrigin.portal,
      attributes: <String, Object?>{
        'operation': 'refresh',
        'status_class': errorCode == null ? 'success' : 'server_error',
      },
    );
  }

  void recordPerformanceSampleStarted() {
    _emitCurrent(
      name: 'app.performance.sample.started',
      subsystem: 'performance',
      stage: 'run',
      outcome: ObservabilityOutcome.started,
      attributes: const <String, Object?>{'operation': 'verify'},
    );
  }

  void recordPerformanceSampleFinished({RuntimeLiveStats? stats}) {
    final available = stats?.available == true &&
        stats?.counterState == RuntimeTrafficCounterState.available;
    final downlink = stats?.downlinkBps;
    final uplink = stats?.uplinkBps;
    _emitCurrent(
      name: 'app.performance.sample.finished',
      subsystem: 'performance',
      stage: 'complete',
      outcome: available
          ? ObservabilityOutcome.observed
          : ObservabilityOutcome.failed,
      errorCode: available ? null : 'PERF-001',
      errorOrigin: ObservabilityErrorOrigin.host,
      attributes: <String, Object?>{
        'operation': 'verify',
        'status_class': available ? 'success' : 'unavailable',
        if (available) 'duration_ms': 1000,
        if (available && downlink != null && downlink >= 0)
          'bytes_in': downlink,
        if (available && uplink != null && uplink >= 0) 'bytes_out': uplink,
      },
    );
  }

  void recordSupportBundleStarted() {
    _emitCurrent(
      name: 'app.support.bundle.started',
      subsystem: 'support',
      stage: 'upload',
      outcome: ObservabilityOutcome.started,
      attributes: const <String, Object?>{
        'phase': 'support',
        'operation': 'upload',
      },
    );
  }

  void recordSupportBundleFinished({
    required PreparedSupportBundle prepared,
    String? errorCode,
  }) {
    _emitCurrent(
      name: 'app.support.bundle.finished',
      subsystem: 'support',
      stage: 'complete',
      outcome: errorCode == null
          ? ObservabilityOutcome.succeeded
          : ObservabilityOutcome.failed,
      errorCode: errorCode,
      errorOrigin: errorCode == null
          ? ObservabilityErrorOrigin.client
          : ObservabilityErrorOrigin.portal,
      attributes: <String, Object?>{
        'phase': 'support',
        'operation': 'upload',
        'status_class': errorCode == null ? 'success' : 'unavailable',
        'bundle_item_count': prepared.preview.files.length,
        'bundle_size_bytes': prepared.preview.totalPlaintextBytes,
      },
    );
  }

  void recordAndroidRoutingAppCount(int selectedAppCount) {
    if (hostPlatform != HostPlatform.android ||
        selectedAppCount < 0 ||
        selectedAppCount > 128 ||
        selectedAppCount == _lastAndroidSelectedAppCount) {
      return;
    }
    _lastAndroidSelectedAppCount = selectedAppCount;
    _emitCurrent(
      name: 'app.routing.selection.finished',
      subsystem: 'routing',
      stage: 'complete',
      outcome: ObservabilityOutcome.observed,
      attributes: <String, Object?>{
        'selected_app_count': selectedAppCount,
      },
    );
  }

  Future<void> markCleanExit() => markerStore.markCleanExit(
        breadcrumbs: dispatcher.breadcrumbs.snapshot(),
      );

  Future<void> markCrash({String errorCode = 'CRASH-001'}) {
    final signature = switch (errorCode) {
      'CRASH-002' => 'c2c2c2c2c2c2c2c2',
      'CRASH-003' => 'c3c3c3c3c3c3c3c3',
      _ => 'c1c1c1c1c1c1c1c1',
    };
    final attempt = _attempt;
    if (attempt != null && !attempt.isTerminal) {
      attempt.finish(OperationalTerminalKind.crash);
    }
    return markerStore.markCrash(
      errorCode: errorCode,
      crashSignature: signature,
      breadcrumbs: dispatcher.breadcrumbs.snapshot(),
    );
  }

  void markCrashSynchronously({String errorCode = 'CRASH-001'}) {
    final signature = switch (errorCode) {
      'CRASH-002' => 'c2c2c2c2c2c2c2c2',
      'CRASH-003' => 'c3c3c3c3c3c3c3c3',
      _ => 'c1c1c1c1c1c1c1c1',
    };
    final attempt = _attempt;
    if (attempt != null && !attempt.isTerminal) {
      attempt.finish(OperationalTerminalKind.crash);
    }
    markerStore.markCrashSynchronously(
      errorCode: errorCode,
      crashSignature: signature,
      breadcrumbs: dispatcher.breadcrumbs.snapshot(),
    );
  }

  Future<void> flush() => dispatcher.flush();

  void _recordVerified(
    OperationalAttemptTimeline attempt,
    RuntimeSnapshot snapshot,
  ) {
    final proofs = _proofs(snapshot);
    if (!proofs.isVerified) {
      return;
    }
    for (final phase in <OperationalTimelinePhase>[
      OperationalTimelinePhase.core,
      OperationalTimelinePhase.tun,
      OperationalTimelinePhase.routes,
      OperationalTimelinePhase.dns,
      OperationalTimelinePhase.egress,
    ]) {
      attempt.enter(phase);
      attempt.complete(
        phase,
        outcome: ObservabilityOutcome.succeeded,
        proofs: phase == OperationalTimelinePhase.egress ? proofs : null,
      );
    }
    attempt.markVerified(proofs);
    attempt.finish(OperationalTerminalKind.succeeded);
  }

  void _recordPreviousExit(PreviousExitReport previous) {
    if (previous.kind == PreviousExitKind.none ||
        previous.kind == PreviousExitKind.clean) {
      return;
    }
    final errorCode = switch (previous.kind) {
      PreviousExitKind.crash => previous.errorCode ?? 'CRASH-001',
      PreviousExitKind.corrupt => 'APP-BOOT-008',
      PreviousExitKind.unclean => 'APP-BOOT-006',
      _ => null,
    };
    _emitBootstrap(
      name: 'app.previous_exit.detected',
      outcome: ObservabilityOutcome.degraded,
      stage: 'recover',
      errorCode: errorCode,
    );
  }

  void _emitBootstrap({
    required String name,
    required ObservabilityOutcome outcome,
    required String stage,
    String? errorCode,
    Map<String, Object?> attributes = const <String, Object?>{
      'phase': 'bootstrap'
    },
  }) {
    final sequence = dispatcher.sequenceFence.lastSequence + 1;
    dispatcher.emit(
      OperationalEvent(
        eventId: ids.uuidV4(),
        occurredAtUtc: DateTime.now().toUtc(),
        component: 'app',
        subsystem: 'bootstrap',
        stage: stage,
        name: name,
        severity: errorCode == null
            ? ObservabilitySeverity.info
            : ObservabilitySeverity.warn,
        outcome: outcome,
        privacyClass: ObservabilityPrivacyClass.localOperational,
        correlation: OperationalCorrelation(
          traceId: ids.traceId(),
          spanId: ids.spanId(),
          parentSpanId: null,
          runId: runId,
          attemptId: null,
          generation: 0,
          sequence: sequence,
        ),
        build: build,
        error: errorCode == null
            ? null
            : OperationalErrorIdentity(
                code: errorCode,
                origin: ObservabilityErrorOrigin.client,
              ),
        attributes: attributes,
      ),
    );
  }

  void _emitCurrent({
    required String name,
    required String subsystem,
    required String stage,
    required ObservabilityOutcome outcome,
    String? errorCode,
    ObservabilityErrorOrigin errorOrigin = ObservabilityErrorOrigin.client,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    final generation = dispatcher.sequenceFence.activeGeneration;
    final sequence = dispatcher.sequenceFence.lastSequence + 1;
    dispatcher.emit(
      OperationalEvent(
        eventId: ids.uuidV4(),
        occurredAtUtc: DateTime.now().toUtc(),
        component: 'app',
        subsystem: subsystem,
        stage: stage,
        name: name,
        severity: errorCode == null
            ? ObservabilitySeverity.info
            : ObservabilitySeverity.error,
        outcome: outcome,
        privacyClass: ObservabilityPrivacyClass.localOperational,
        correlation: OperationalCorrelation(
          traceId: ids.traceId(),
          spanId: ids.spanId(),
          parentSpanId: null,
          runId: runId,
          attemptId: _attempt?.attemptId,
          generation: generation,
          sequence: sequence,
        ),
        build: build,
        error: errorCode == null
            ? null
            : OperationalErrorIdentity(
                code: errorCode,
                origin: errorOrigin,
              ),
        attributes: attributes,
      ),
    );
  }

  static OperationalBuildIdentity _defaultBuild(HostPlatform hostPlatform) =>
      pokrovCurrentBuildIdentity(hostPlatform);

  static OperationalTimelinePhase _timelinePhase(ConnectionStage stage) =>
      switch (stage) {
        ConnectionStage.idle ||
        ConnectionStage.permission ||
        ConnectionStage.profile =>
          OperationalTimelinePhase.profile,
        ConnectionStage.coreStart => OperationalTimelinePhase.core,
        ConnectionStage.tunnel => OperationalTimelinePhase.tun,
        ConnectionStage.network => OperationalTimelinePhase.routes,
        ConnectionStage.dns => OperationalTimelinePhase.dns,
        ConnectionStage.egress ||
        ConnectionStage.complete =>
          OperationalTimelinePhase.egress,
      };

  static OperationalProofSnapshot _proofs(RuntimeSnapshot snapshot) =>
      OperationalProofSnapshot(
        interfaceReady: snapshot.phase == RuntimePhase.running,
        routesReady: snapshot.uplinkState == RuntimeDiagnosticState.healthy,
        dnsReady: snapshot.dnsState == RuntimeDiagnosticState.healthy &&
            snapshot.dnsReady != false,
        egressReady: snapshot.coreEgressValidated == true,
      );

  static ObservabilityErrorOrigin _runtimeErrorOrigin(String reasonCode) {
    final normalized = reasonCode.trim().toLowerCase();
    if (normalized.startsWith('desktop_')) {
      return ObservabilityErrorOrigin.host;
    }
    if (normalized.startsWith('resolver_') ||
        normalized.startsWith('default_network_')) {
      return ObservabilityErrorOrigin.os;
    }
    if (normalized.startsWith('core_') || normalized.startsWith('tunnel_')) {
      return ObservabilityErrorOrigin.core;
    }
    return ObservabilityErrorOrigin.client;
  }
}

String _supportBundleOperationalErrorCode(Object error) {
  final code = switch (error) {
    SupportBundleTransferFailure failure => failure.code,
    SupportBundleFailure failure => failure.code,
    _ => '',
  };
  if (code.contains('privacy') ||
      code.contains('planted') ||
      code.contains('integrity')) {
    return 'SUP-002';
  }
  if (code.contains('recipient') ||
      code.contains('signing') ||
      code.contains('encrypt')) {
    return 'SUP-003';
  }
  if (code.contains('ticket') || code.contains('expired')) {
    return 'SUP-004';
  }
  if (code.contains('outbox') || code.contains('prepare')) {
    return 'SUP-001';
  }
  return 'SUP-005';
}
