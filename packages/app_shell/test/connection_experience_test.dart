import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_app_shell/routing_catalog_contract.dart';
import 'package:pokrov_app_shell/smart_access_profile.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

// Selection consumes already verified snapshots; signature parsing has its own boundary.
class _SelectionCatalog implements VerifiedRoutingCatalog {
  _SelectionCatalog(this.payload);
  @override
  final Map<String, Object?> payload;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SelectionProviders implements VerifiedSmartAccessProviderPolicy {
  _SelectionProviders(this.payload);
  @override
  final Map<String, Object?> payload;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RuntimeSnapshot _runningSnapshot({
  HostPlatform hostPlatform = HostPlatform.windows,
  RuntimeHostHealth hostHealth = RuntimeHostHealth.healthy,
  RuntimeDiagnosticState dnsState = RuntimeDiagnosticState.healthy,
  RuntimeDiagnosticState uplinkState = RuntimeDiagnosticState.healthy,
  bool? dnsReady = true,
  bool? coreEgressValidated = true,
}) {
  return RuntimeSnapshot(
    hostPlatform: hostPlatform,
    lane: RuntimeLane.desktopFfi,
    phase: RuntimePhase.running,
    artifactDirectory: 'C:/POKROV/runtime',
    coreBinaryPath: 'C:/POKROV/runtime/pokrov_core.dll',
    helperBinaryPath: null,
    stagedConfigPath: 'C:/POKROV/runtime/profile.json',
    supportsLiveConnect: true,
    canInitialize: true,
    canConnect: true,
    message: 'POKROV включен.',
    hostHealth: hostHealth,
    dnsState: dnsState,
    uplinkState: uplinkState,
    dnsReady: dnsReady,
    coreEgressValidated: coreEgressValidated,
    coreEgressValidationRequired: false,
  );
}

ConnectionExperienceState _reduce(
  RuntimeSnapshot? snapshot, {
  ConnectionTransitionIntent intent = ConnectionTransitionIntent.none,
  bool actionInFlight = false,
}) {
  return ConnectionExperienceReducer.reduce(
    snapshot: snapshot,
    intent: intent,
    actionInFlight: actionInFlight,
  );
}

void main() {
  test('Smart Access defaults to eligible owned DNS and retains external affinity', () async {
    final now = DateTime.utc(2026, 10, 1);
    final window = {'issued_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
      'expires_at': now.add(const Duration(hours: 1)).toIso8601String()};
    final catalog = _SelectionCatalog({...window, 'services': [
      {'service_id': 'test-service', 'provider_capability_refs': ['owned-cap', 'external-cap']},
    ]});
    final ownedCapability = <String, Object?>{
      'capability_id': 'owned-cap', 'service_id': 'test-service', 'provider_id': 'owned-provider',
      'provider_revision': 1, 'enabled': true, 'verification': 'verified', 'platform': 'windows',
      'origin': 'current-origin', 'feature': 'web_request', 'transport': 'tls_tcp_443_visible_sni',
      'family': 'ipv4', 'observed_at': window['issued_at'], 'expires_at': window['expires_at'],
      'domains': [{'name': 'service.example', 'match': 'suffix'}],
    };
    final providers = _SelectionProviders({...window,
      'providers': [for (final kind in ['owned', 'external'])
        {'provider_id': '$kind-provider', 'kind': kind, 'enabled': true, 'revision': 1,
          'permission_id': '$kind-permission'}],
      'permissions': [for (final kind in ['owned', 'external'])
        {...window, 'permission_id': '$kind-permission', 'provider_id': '$kind-provider',
          'status': 'approved', 'embedded_use_allowed': true}],
      'capabilities': [ownedCapability,
        {...ownedCapability, 'capability_id': 'external-cap', 'provider_id': 'external-provider'}],
    });
    Future<List<String>> selected({String? affinity}) async =>
      (await selectSmartAccessWebCapabilities(catalog: catalog, providers: providers,
        serviceIds: {'test-service'}, platform: 'windows', now: now,
        // This seed ranked the external provider first before owned preference.
        selectionSeed: '0000000000000000000000000000000000000000000000000000000000000003',
        isCurrent: () => true,
        preferredCapabilityIds: affinity == null ? const {} : {'test-service': affinity}))
        .map((row) => row['capability_id']! as String).toList();
    expect(await selected(), ['owned-cap', 'external-cap']);
    expect(await selected(affinity: 'external-cap'), ['external-cap', 'owned-cap']);
    ownedCapability['expires_at'] = now.toIso8601String();
    expect(await selected(), ['external-cap']);
  });

  test('verified state requires every DNS, host, uplink and egress proof', () {
    expect(_reduce(_runningSnapshot()), isA<ConnectionConnectedVerified>());

    final missingProof = <RuntimeSnapshot>[
      _runningSnapshot(hostHealth: RuntimeHostHealth.unknown),
      _runningSnapshot(dnsState: RuntimeDiagnosticState.unknown),
      _runningSnapshot(uplinkState: RuntimeDiagnosticState.unknown),
      _runningSnapshot(dnsReady: false),
      _runningSnapshot(coreEgressValidated: null),
    ];
    for (final snapshot in missingProof) {
      final state = _reduce(snapshot);
      expect(
        state,
        isA<ConnectionConnectedUnverified>(),
        reason: 'missing proof must not produce ${state.runtimeType}',
      );
    }
  });

  test('the same proof contract applies to every supported host enum', () {
    for (final hostPlatform in HostPlatform.values) {
      expect(
        _reduce(_runningSnapshot(hostPlatform: hostPlatform)),
        isA<ConnectionConnectedVerified>(),
        reason: '$hostPlatform must use the shared verified-state contract',
      );
      expect(
        _reduce(
          _runningSnapshot(
            hostPlatform: hostPlatform,
            coreEgressValidated: null,
          ),
        ),
        isA<ConnectionConnectedUnverified>(),
        reason: '$hostPlatform must fail closed without egress proof',
      );
    }
  });

  test('host connection-pending state remains an actionable permission step',
      () {
    final pending = RuntimeSnapshot(
      hostPlatform: HostPlatform.android,
      lane: RuntimeLane.mobileArtifact,
      phase: RuntimePhase.configStaged,
      artifactDirectory: '/host/runtime',
      coreBinaryPath: '/host/runtime/pokrov-core.aar',
      helperBinaryPath: null,
      stagedConfigPath: '/host/runtime/profile.json',
      supportsLiveConnect: true,
      canInitialize: true,
      canConnect: true,
      message: 'VPN permission required.',
      connectionPending: true,
    );
    final presentation = ConnectionPresentation.fromExperience(
      _reduce(pending),
      primaryConnectEnabled: true,
    );

    expect(presentation.experience, isA<ConnectionPermissionRequired>());
    expect(presentation.primaryActionLabel, 'Разрешить');
    expect(presentation.primaryActionEnabled, isTrue);
  });

  test('initialized Core stays in the Core stage until a profile is staged', () {
    RuntimeSnapshot snapshot(RuntimePhase phase) => RuntimeSnapshot(
      hostPlatform: HostPlatform.android,
      lane: RuntimeLane.mobileArtifact,
      phase: phase,
      artifactDirectory: '/host/runtime',
      coreBinaryPath: '/host/runtime/pokrov-core.aar',
      helperBinaryPath: null,
      stagedConfigPath: phase == RuntimePhase.configStaged ? '/host/runtime/profile.json' : null,
      supportsLiveConnect: true,
      canInitialize: false,
      canConnect: phase == RuntimePhase.configStaged,
      message: '',
    );
    final initialized = _reduce(snapshot(RuntimePhase.initialized),
      intent: ConnectionTransitionIntent.connect, actionInFlight: true);
    final staged = _reduce(snapshot(RuntimePhase.configStaged),
      intent: ConnectionTransitionIntent.connect, actionInFlight: true);

    expect(initialized.stage, ConnectionStage.coreStart);
    expect(staged.stage, ConnectionStage.tunnel);
  });

  test('disconnect and reconnect require distinct explicit intents', () {
    final running = _runningSnapshot();
    final disconnecting = _reduce(
      running,
      intent: ConnectionTransitionIntent.disconnect,
      actionInFlight: true,
    );
    final reconnecting = _reduce(
      running,
      intent: ConnectionTransitionIntent.reconnect,
      actionInFlight: true,
    );

    expect(disconnecting, isA<ConnectionDisconnecting>());
    expect(reconnecting, isA<ConnectionReconnecting>());
    expect(
      ConnectionPresentation.fromExperience(
        disconnecting,
        primaryConnectEnabled: true,
      ).discPhase,
      ConnectionDiscPhase.disconnecting,
    );
    expect(
      ConnectionPresentation.fromExperience(
        reconnecting,
        primaryConnectEnabled: true,
      ).discPhase,
      ConnectionDiscPhase.reconnecting,
    );
  });

  test('one presentation owns copy, CTA, tone, semantics and disc phase', () {
    final presentation = ConnectionPresentation.fromExperience(
      ConnectionConnectedVerified(snapshot: _runningSnapshot()),
      primaryConnectEnabled: true,
    );

    expect(presentation.title, 'Подключено');
    expect(presentation.primaryActionLabel, 'Отключить');
    expect(presentation.primaryActionEnabled, isTrue);
    expect(presentation.tone, ConnectionTone.success);
    expect(presentation.discPhase, ConnectionDiscPhase.connected);
    expect(presentation.semanticLabel, 'Отключить');
    expect(presentation.isVerified, isTrue);
  });

  test('protection view keeps one connection presentation and bounded context',
      () {
    final presentation = ConnectionPresentation.fromExperience(
      ConnectionConnectedVerified(snapshot: _runningSnapshot()),
      primaryConnectEnabled: true,
    );
    final view = ProtectionViewState(
      connection: presentation,
      routeMode: RouteMode.fullTunnel,
      locationLabel: 'Автоматически',
      connectHintVisible: false,
      runtimeNotice: 'Настройки применятся при переподключении.',
    );

    expect(identical(view.connection, presentation), isTrue);
    expect(view.connection.semanticLabel, 'Отключить');
    expect(view.routeMode, RouteMode.fullTunnel);
    expect(view.locationLabel, 'Автоматически');
    expect(
      view.runtimeNotice,
      'Настройки применятся при переподключении.',
    );
  });

  test('protection intents expose one bounded action boundary', () async {
    var toggles = 0;
    var details = 0;
    var locations = 0;
    var rules = 0;
    final intents = ProtectionIntents(
      toggleConnection: () async => toggles += 1,
      openConnectionDetails: () => details += 1,
      openLocations: () => locations += 1,
      openRules: () => rules += 1,
    );

    await intents.toggleConnection();
    intents.openConnectionDetails();
    intents.openLocations();
    intents.openRules();

    expect((toggles, details, locations, rules), (1, 1, 1, 1));
  });

  test('connection coordinator owns snapshot intent action and attempt state',
      () {
    var now = DateTime.utc(2026, 8, 22, 12);
    final coordinator = ConnectionCoordinator(
      primaryConnectEnabled: (_) => true,
      actionTimeout: const Duration(seconds: 1),
      now: () => now,
    );

    coordinator.beginAction(
      ConnectionTransitionIntent.connect,
      recordAttempt: true,
    );
    expect(coordinator.actionInFlight, isTrue);
    expect(coordinator.intent, ConnectionTransitionIntent.connect);
    expect(coordinator.attemptNumber, 1);
    expect(coordinator.experience, isA<ConnectionConnecting>());

    now = now.add(const Duration(milliseconds: 375));
    expect(coordinator.attemptDurationMs, 375);

    final running = _runningSnapshot();
    coordinator.updateSnapshot(running);
    coordinator.finishAction();
    expect(coordinator.snapshot, same(running));
    expect(coordinator.presentation.isVerified, isTrue);
    expect(coordinator.intent, ConnectionTransitionIntent.none);
    expect(coordinator.actionInFlight, isFalse);

    coordinator.clearAttempt();
    expect(coordinator.attemptDurationMs, isNull);
  });

  test('connection coordinator applies the bounded runtime action timeout',
      () async {
    final coordinator = ConnectionCoordinator(
      primaryConnectEnabled: (_) => true,
      actionTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      coordinator.runWithTimeout<void>(
        'snapshot',
        () => Completer<void>().future,
      ),
      throwsA(
        isA<TimeoutException>().having(
          (error) => error.message,
          'message',
          'runtime action timed out: snapshot',
        ),
      ),
    );
  });

  test('connection coordinator exposes slow stage and resets it on progress',
      () async {
    final slowStage = Completer<void>();
    var reports = 0;
    final coordinator = ConnectionCoordinator(
      primaryConnectEnabled: (_) => true,
      actionTimeout: const Duration(seconds: 1),
      slowStageThreshold: const Duration(milliseconds: 10),
    );

    coordinator.beginAction(
      ConnectionTransitionIntent.connect,
      recordAttempt: true,
      onSlowStage: () {
        reports += 1;
        if (!slowStage.isCompleted) {
          slowStage.complete();
        }
      },
    );
    await slowStage.future.timeout(const Duration(seconds: 1));
    expect(coordinator.slowStageVisible, isTrue);
    expect(reports, 1);

    coordinator.updateSnapshot(
      const RuntimeSnapshot(
        hostPlatform: HostPlatform.windows,
        lane: RuntimeLane.desktopFfi,
        phase: RuntimePhase.initialized,
        artifactDirectory: '/runtime',
        coreBinaryPath: '/runtime/core',
        helperBinaryPath: null,
        stagedConfigPath: '/runtime/profile.json',
        canInitialize: true,
        canConnect: true,
        supportsLiveConnect: true,
        message: 'initialized',
      ),
    );
    expect(coordinator.slowStageVisible, isFalse);

    coordinator.finishAction();
    coordinator.dispose();
  });

  test('started tunnel without proof is verifying or degraded, never green',
      () {
    final verifying = ConnectionPresentation.fromExperience(
      _reduce(_runningSnapshot(coreEgressValidated: null)),
      primaryConnectEnabled: true,
    );
    final degraded = ConnectionPresentation.fromExperience(
      _reduce(_runningSnapshot(coreEgressValidated: false)),
      primaryConnectEnabled: true,
    );

    expect(verifying.title, 'Проверяем…');
    expect(verifying.discPhase, ConnectionDiscPhase.connecting);
    expect(verifying.tone, ConnectionTone.warning);
    expect(verifying.isVerified, isFalse);
    expect(verifying.discMotionBusy, isTrue);

    expect(degraded.title, 'Нужно внимание');
    expect(degraded.discPhase, ConnectionDiscPhase.error);
    expect(degraded.tone, ConnectionTone.warning);
    expect(degraded.isDegraded, isTrue);
  });

  test('artifact and bounded runtime failures map to typed safe states', () {
    final missing = RuntimeSnapshot(
      hostPlatform: HostPlatform.android,
      lane: RuntimeLane.mobileArtifact,
      phase: RuntimePhase.artifactMissing,
      artifactDirectory: null,
      coreBinaryPath: null,
      helperBinaryPath: null,
      stagedConfigPath: null,
      supportsLiveConnect: false,
      canInitialize: false,
      canConnect: false,
      message: 'Нужна подготовка.',
    );
    final failed = RuntimeSnapshot(
      hostPlatform: HostPlatform.windows,
      lane: RuntimeLane.desktopFfi,
      phase: RuntimePhase.configStaged,
      artifactDirectory: 'C:/POKROV/runtime',
      coreBinaryPath: 'C:/POKROV/runtime/pokrov_core.dll',
      helperBinaryPath: null,
      stagedConfigPath: 'C:/POKROV/runtime/profile.json',
      supportsLiveConnect: true,
      canInitialize: true,
      canConnect: true,
      message: 'Safe public copy.',
      lastFailureKind: 'desktop_tun_egress_probe_failed',
    );

    expect(_reduce(missing), isA<ConnectionBlocked>());
    final failedState = _reduce(failed);
    expect(failedState, isA<ConnectionFailed>());
    expect(
      (failedState as ConnectionFailed).reasonCode,
      'desktop_tun_egress_probe_failed',
    );
  });

  test('transition matrix covers every legal and illegal phase pair', () {
    const legal = <ConnectionExperiencePhase, Set<ConnectionExperiencePhase>>{
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

    for (final from in ConnectionExperiencePhase.values) {
      for (final to in ConnectionExperiencePhase.values) {
        final expected = from == to || (legal[from]?.contains(to) ?? false);
        expect(
          ConnectionExperienceTransitionMatrix.isLegal(from, to),
          expected,
          reason: '$from -> $to',
        );
      }
    }
  });

  test('haptic coordinator emits one action tap and bounded outcomes', () {
    final idle = ConnectionPresentation.fromExperience(
      const ConnectionIdle(),
      primaryConnectEnabled: true,
    );
    expect(
      ConnectionHapticCoordinator.action(idle),
      ConnectionHapticIntent.tap,
    );
    expect(
      ConnectionHapticCoordinator.outcome(
        ConnectionExperiencePhase.connecting,
        ConnectionExperiencePhase.connectedVerified,
      ),
      ConnectionHapticIntent.success,
    );
    expect(
      ConnectionHapticCoordinator.outcome(
        ConnectionExperiencePhase.disconnecting,
        ConnectionExperiencePhase.idle,
      ),
      ConnectionHapticIntent.none,
    );
    expect(
      ConnectionHapticCoordinator.outcome(
        ConnectionExperiencePhase.failed,
        ConnectionExperiencePhase.failed,
      ),
      ConnectionHapticIntent.none,
    );
  });
}
