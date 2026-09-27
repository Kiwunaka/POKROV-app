import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

class _Bootstrapper implements ManagedProfileBootstrapper {
  _Bootstrapper({this.warpEnabled = false});
  final bool warpEnabled;
  Completer<void>? gate;
  final entered = Completer<void>();
  bool cancelled = false;

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const [],
    String preferredNodeCode = '',
    String preferredVariantId = 'direct',
    Set<String> excludedNodeCodes = const {},
    String tcpFallbackFromRevision = '',
    Duration? timeout,
    Future<void>? cancelled,
  }) async {
    if (!entered.isCompleted) entered.complete();
    unawaited(cancelled?.then((_) => this.cancelled = true));
    await gate?.future;
    return ManagedProfilePayload(
      profileName: 'test-profile',
      configPayload:
          '{"outbounds":[{"type":"socks","tag":"node","server":"127.0.0.1","server_port":1080},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
      materializedForRuntime: true,
      routeMode: routeMode,
      warpPolicy:
          WarpRuntimePolicy.clientLocalDefault.withUserConsent(warpEnabled),
    );
  }
}

class _Runtime implements PokrovRuntimeEngine, RuntimeConnectCancellation {
  _Runtime({this.heldOperation, this.hostPlatform = HostPlatform.android});
  final String? heldOperation;
  final HostPlatform hostPlatform;
  final operationEntered = Completer<void>();
  final releaseOperation = Completer<void>();
  final stopReadEntered = Completer<void>();
  Completer<void>? releaseStopRead;
  final calls = <String>[];
  final cancelled = <String>{};
  RuntimePhase phase = RuntimePhase.artifactReady;
  int connectCalls = 0;
  bool mutationPending = false;
  bool overlappingMutation = false;
  bool pendingFirstEgress = false;
  bool warpEgressFailure = false;
  String? _request;

  RuntimeSnapshot value(RuntimePhase phase) => RuntimeSnapshot(
        hostPlatform: hostPlatform,
        lane: hostPlatform == HostPlatform.android
            ? RuntimeLane.mobileArtifact
            : RuntimeLane.windowsService,
        phase: phase,
        artifactDirectory: null,
        coreBinaryPath: null,
        helperBinaryPath: null,
        stagedConfigPath: phase.index >= RuntimePhase.configStaged.index
            ? '/test/profile.json'
            : null,
        supportsLiveConnect: true,
        canInitialize: phase == RuntimePhase.artifactReady,
        canConnect: phase.index >= RuntimePhase.configStaged.index,
        message: '',
        hostHealth: phase == RuntimePhase.running
            ? RuntimeHostHealth.healthy
            : RuntimeHostHealth.unknown,
        dnsState: phase == RuntimePhase.running
            ? RuntimeDiagnosticState.healthy
            : RuntimeDiagnosticState.unknown,
        uplinkState: phase == RuntimePhase.running
            ? RuntimeDiagnosticState.healthy
            : RuntimeDiagnosticState.unknown,
        dnsReady: phase == RuntimePhase.running,
        coreEgressValidated:
            phase == RuntimePhase.running && !pendingFirstEgress
                ? !warpEgressFailure
                : null,
        coreEgressValidationRequired: true,
        lastFailureKind: phase == RuntimePhase.running &&
                warpEgressFailure &&
                !pendingFirstEgress
            ? 'core_egress_probe_failed'
            : null,
      );

  Future<RuntimeSnapshot> mutate(String name, RuntimePhase next) async {
    calls.add(name);
    if (mutationPending) overlappingMutation = true;
    mutationPending = true;
    if (name == heldOperation && !operationEntered.isCompleted) {
      operationEntered.complete();
      await releaseOperation.future;
    }
    mutationPending = false;
    phase = name == 'connect' && cancelled.contains(_request)
        ? RuntimePhase.configStaged
        : next;
    // The old native call can return its pre-cancellation success snapshot.
    return value(next);
  }

  @override
  Future<RuntimeSnapshot> snapshot() async {
    calls.add('snapshot');
    if (phase == RuntimePhase.running) pendingFirstEgress = false;
    if (cancelled.isNotEmpty && releaseStopRead != null) {
      if (!stopReadEntered.isCompleted) stopReadEntered.complete();
      await releaseStopRead!.future;
    }
    return value(phase);
  }

  @override
  Future<RuntimeSnapshot> initialize() =>
      mutate('initialize', RuntimePhase.initialized);
  @override
  Future<RuntimeSnapshot> stageManagedProfile(ManagedProfilePayload payload) =>
      mutate('stage', RuntimePhase.configStaged);
  @override
  Future<RuntimeSnapshot> invalidateManagedProfile() async => value(phase);
  @override
  Future<RuntimeSnapshot> connect() {
    _request = 'request-${++connectCalls}';
    return mutate('connect', RuntimePhase.running);
  }

  @override
  Future<RuntimeSnapshot> disconnect() =>
      mutate('disconnect', RuntimePhase.configStaged);
  @override
  Future<WarpApplyResult> applyWarp({required bool enabled}) async {
    if (heldOperation != 'warp')
      return const WarpApplyResult.notApplied(reason: 'not_used');
    calls.add('warp');
    mutationPending = true;
    operationEntered.complete();
    await releaseOperation.future;
    mutationPending = false;
    return const WarpApplyResult(
        applied: true, effectiveAt: 'next_connect', fallbackUsed: true);
  }

  @override
  Future<RuntimeLiveStats> liveStats() async =>
      const RuntimeLiveStats.unavailable();
  @override
  Future<RuntimePushToken> pushToken() async =>
      const RuntimePushToken.unavailable();
  @override
  String? get activeConnectRequestId => _request;
  @override
  String? connectRequestForSnapshot(RuntimeSnapshot snapshot) => _request;
  @override
  Future<void> cancelConnectRequest(String requestId) async {
    calls.add('cancel:$requestId');
    cancelled.add(requestId);
  }
}

class _ExperienceStore implements PokrovClientExperienceStore {
  @override
  Future<PokrovClientExperienceState> read() async =>
      const PokrovClientExperienceState.empty();
  @override
  Future<void> write(PokrovClientExperienceState state) async {}
}

class _FirstLaunchStore implements PokrovFirstLaunchStore {
  @override
  Future<bool> isCompleted() async => true;
  @override
  Future<void> markCompleted() async {}
}

ConnectionManager _manager(
  _Runtime runtime,
  _Bootstrapper bootstrapper, {
  Future<PokrovWindowsTunnelAuthorization> Function()? authorizeWindows,
}) =>
    ConnectionManager(
      appContext: buildSeedAppContext(hostPlatform: runtime.hostPlatform),
      runtimeEngine: runtime,
      bootstrapper: bootstrapper,
      accountSessionCoordinator:
          AccountSessionCoordinator(accountActions: null),
      firstSessionCoordinator:
          FirstSessionCoordinator(store: _FirstLaunchStore()),
      clientExperienceStore: _ExperienceStore(),
      connectHintStore: const PokrovFileConnectHintStore(),
      authorizeAndroidConnect: () async => true,
      windowsTunnelAuthorizer: authorizeWindows,
      refreshSubscription: () async => true,
      onNotice: (_, __) {},
    );

void main() {
  test('connect and disconnect publish existing native facts independently',
      () async {
    final runtime = _Runtime();
    final manager = _manager(runtime, _Bootstrapper());
    addTearDown(manager.dispose);
    final phases = <ConnectionPhase>[];
    manager.addListener(() => phases.add(manager.status.phase));
    await manager.connect();
    expect(
        phases,
        containsAllInOrder([
          ConnectionPhase.preparing,
          ConnectionPhase.activating,
          ConnectionPhase.connected
        ]));
    expect(manager.presentation.isVerified, isTrue);
    expect(manager.status.routes.ipv4, isNull);
    expect(manager.status.routes.ipv6, isNull);
    expect(manager.status.dns.ready, isTrue);
    expect(manager.status.egress.validated, isTrue);
    await manager.disconnect();
    expect(manager.status.phase, ConnectionPhase.disconnected);
    expect(manager.busy, isFalse);
  });

  test('new command cancels profile work and ignores its late result',
      () async {
    final runtime = _Runtime();
    final bootstrapper = _Bootstrapper()..gate = Completer<void>();
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    final first = manager.connect();
    await bootstrapper.entered.future;
    final disconnect = manager.disconnect();
    await Future<void>.delayed(Duration.zero);
    expect(bootstrapper.cancelled, isTrue);
    bootstrapper.gate!.complete();
    await Future.wait([first, disconnect]);
    expect(runtime.calls, isNot(contains('stage')));
    expect(runtime.connectCalls, 0);
    expect(manager.attemptId, 2);
    expect(manager.busy, isFalse);
  });

  for (final operation in ['initialize', 'stage', 'connect']) {
    test('replacement joins $operation and keeps one native owner', () async {
      final runtime = _Runtime(heldOperation: operation);
      if (operation == 'connect') runtime.releaseStopRead = Completer<void>();
      final manager = _manager(runtime, _Bootstrapper());
      addTearDown(manager.dispose);
      final first = manager.connect();
      await runtime.operationEntered.future;
      final cancellation = manager.cancel();
      final replacement = manager.connect();
      final replacementId = manager.attemptId;
      await Future<void>.delayed(Duration.zero);
      expect(runtime.overlappingMutation, isFalse);
      runtime.releaseOperation.complete();
      if (operation == 'connect') {
        await runtime.stopReadEntered.future;
        expect(runtime.connectCalls, 1,
            reason: 'replacement must wait for stopped readback');
        expect(manager.busy, isTrue);
        runtime.releaseStopRead!.complete();
      }
      await Future.wait([first, cancellation, replacement]);
      expect(runtime.overlappingMutation, isFalse);
      expect(manager.attemptId, replacementId);
      expect(manager.presentation.isVerified, isTrue);
      expect(manager.busy, isFalse);
      if (operation == 'connect') {
        expect(runtime.cancelled, contains('request-1'));
        expect(runtime.connectCalls, 2);
      }
    });
  }

  test('disconnect supersedes a pending Windows authorization', () async {
    final entered = Completer<void>();
    final authorization = Completer<PokrovWindowsTunnelAuthorization>();
    final runtime = _Runtime(hostPlatform: HostPlatform.windows);
    final manager = _manager(runtime, _Bootstrapper(), authorizeWindows: () {
      entered.complete();
      return authorization.future;
    });
    addTearDown(manager.dispose);
    final first = manager.connect();
    await entered.future;
    final disconnect = manager.disconnect();
    authorization.complete(PokrovWindowsTunnelAuthorization.allowed);
    await Future.wait([first, disconnect]);
    expect(runtime.connectCalls, 0);
    expect(manager.busy, isFalse);
  });

  test(
      'cancel joins post-connect WARP fallback and confirms the tunnel stopped',
      () async {
    final runtime = _Runtime(heldOperation: 'warp')
      ..pendingFirstEgress = true
      ..warpEgressFailure = true;
    final manager = _manager(runtime, _Bootstrapper(warpEnabled: true));
    addTearDown(manager.dispose);
    await manager.connect();
    await runtime.operationEntered.future;
    final cancellation = manager.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(runtime.calls, isNot(contains('disconnect')),
        reason: 'native WARP profile mutation must settle before stop');
    runtime.releaseOperation.complete();
    await cancellation;
    expect(runtime.calls, contains('disconnect'));
    expect(runtime.connectCalls, 1,
        reason: 'cancelled fallback must not reconnect');
    expect(runtime.overlappingMutation, isFalse);
    expect(manager.snapshot?.phase, isNot(RuntimePhase.running));
    expect(manager.status.phase, ConnectionPhase.disconnected);
    expect(manager.busy, isFalse);
  });
}
