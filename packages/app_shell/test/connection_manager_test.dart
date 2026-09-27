import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart' hide TransportCandidate;
import 'package:pokrov_app_shell/src/shell/managed_profile_cache.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

final _candidates = List.generate(4, (index) => TransportCandidate(
  candidateRef: 'de:profile_$index', profileRef: 'profile_$index', nodeCode: 'de',
  countryCode: 'DE', protocol: 'vless', transport: 'tcp', protection: 'reality',
  priority: index, network: 'tcp', flow: '', minimumClientRelease: '1.2.0',
  minimumCoreRelease: null, platforms: {HostPlatform.android, HostPlatform.windows}, requiredFeatures: const {},
));

class _Bootstrapper implements ManagedProfileBootstrapper {
  _Bootstrapper({this.warpEnabled = false, this.catalog = false});
  final bool catalog;
  final resolutions = <({String selected, bool select, bool cache})>[];
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
    Set<RuntimeTransportFeature> runtimeFeatures = const {},
    String? coreRelease,
    bool selectCandidate = true,
    String selectedCandidateRef = '',
    bool cacheResult = true,
    Duration? timeout,
    Future<void>? cancelled,
  }) async {
    resolutions.add((selected: selectedCandidateRef, select: selectCandidate, cache: cacheResult));
    if (!entered.isCompleted) entered.complete();
    unawaited(cancelled?.then((_) => this.cancelled = true));
    await gate?.future;
    final nodeCode = preferredNodeCode.isEmpty ? 'de' : preferredNodeCode;
    return ManagedProfilePayload(
      profileName: selectedCandidateRef.isEmpty ? '$nodeCode:profile_0' : selectedCandidateRef,
      transportCatalog: catalog ? TransportCandidateCatalog(revision: 'test',
          selectedCandidateRef: selectedCandidateRef.isEmpty ? 'de:profile_0' : selectedCandidateRef,
          candidates: _candidates) : null,
      resolvedNodeCode: nodeCode,
      configPayload:
          '{"outbounds":[{"type":"socks","tag":"node","server":"127.0.0.1","server_port":1080},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
      materializedForRuntime: true,
      routeMode: routeMode,
      warpPolicy:
          WarpRuntimePolicy.clientLocalDefault.withUserConsent(warpEnabled),
    );
  }
}

class _ManifestBootstrapper extends _Bootstrapper implements AppFirstTransportManifestService {
  @override
  bool get transportManifestEnabled => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runtime implements PokrovRuntimeEngine, RuntimeConnectCancellation, RuntimeCandidateProbing, RuntimeProtectedHandoff, RuntimeNetworkAvailability {
  _Runtime({this.heldOperation, this.hostPlatform = HostPlatform.android});
  final String? heldOperation;
  bool supportsCandidates = false;
  bool holdProbes = false;
  bool failProbeCancellation = false;
  bool failHandoff = false;
  bool failFirstActivation = false;
  bool restoredHandoffGuard = false;
  final probeRelease = Completer<void>();
  final probeStarted = Completer<void>();
  final handoffStarted = Completer<void>();
  Completer<void>? handoffRelease;
  final activeProbes = <String, Completer<void>>{};
  String? stagedProfile;
  int handoffCalls = 0;
  bool? networkAvailable = true;
  bool? captivePortal;

  @override
  Future<RuntimeNetworkStatusObservation> readNetworkAvailability() async => RuntimeNetworkStatusObservation(
      networkAvailable: networkAvailable, captivePortal: captivePortal);

  @override
  Future<RuntimeCandidateNetwork> readCandidateNetwork() async => const RuntimeCandidateNetwork(
      selectionKey: 'network-a', contextRef: 'context-a', networkAvailable: true);
  @override
  Future<RuntimeCandidateProbeResult> probeCandidate({required String probeId,
      required ManagedProfilePayload payload, required Duration timeout, required String expectedNetworkContext}) async {
    expect(calls.contains('initialize') || restoredHandoffGuard || phase == RuntimePhase.configStaged, isTrue);
    final cancelled = Completer<void>();
    activeProbes[probeId] = cancelled;
    if (!probeStarted.isCompleted) probeStarted.complete();
    if (holdProbes) {
      if (payload.profileName == 'de:profile_1') { await Future.any([probeRelease.future, cancelled.future]); }
      else { await cancelled.future; }
    }
    activeProbes.remove(probeId);
    final success = !cancelled.isCompleted;
    return RuntimeCandidateProbeResult(success: success, failureKind: success ? '' : 'cancelled', duration: Duration.zero);
  }
  @override
  Future<void> cancelCandidateProbe(String probeId) async {
    final pending = activeProbes[probeId];
    if (pending != null && !pending.isCompleted) {
      if (failProbeCancellation) {
        unawaited(Future<void>.delayed(const Duration(milliseconds: 10), pending.complete));
        throw StateError('candidate_cancel_channel_unavailable');
      }
      pending.complete();
    }
  }
  @override
  Future<RuntimeSnapshot> replaceManagedProfile(ManagedProfilePayload payload, {
    required bool Function() operationIsCurrent,
    Future<String> Function(String, RuntimeSnapshot)? persistRestrictions,
  }) async {
    calls.add('replace');
    stagedProfile = payload.profileName;
    handoffCalls++;
    _request = 'handoff-$handoffCalls';
    expect(activeProbes, isEmpty);
    if (!handoffStarted.isCompleted) handoffStarted.complete();
    await handoffRelease?.future;
    warpEgressFailure = failHandoff || cancelled.contains(_request);
    phase = RuntimePhase.running;
    return value(phase);
  }

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
        transportCapabilities: supportsCandidates && phase != RuntimePhase.artifactReady
            ? RuntimeTransportCapabilities.fromWire(jsonEncode({'schema': 1,
                'features': RuntimeTransportFeature.values.map((feature) => feature.wireName).toList()..sort()})) : null,
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
        lastFailureKind: failFirstActivation && connectCalls == 1 && phase == RuntimePhase.configStaged
            ? 'core_egress_timeout' : restoredHandoffGuard ? 'protected_handoff_failed' : phase == RuntimePhase.running &&
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
  Future<RuntimeSnapshot> stageManagedProfile(ManagedProfilePayload payload) {
    expect(activeProbes, isEmpty, reason: 'all candidate workers must settle before the single TUN owner starts');
    stagedProfile = payload.profileName;
    return mutate('stage', RuntimePhase.configStaged);
  }
  @override
  Future<RuntimeSnapshot> invalidateManagedProfile() async {
    calls.add('invalidate');
    return value(phase);
  }
  @override
  Future<RuntimeSnapshot> connect() {
    _request = 'request-${++connectCalls}';
    return mutate('connect', failFirstActivation && connectCalls == 1
        ? RuntimePhase.configStaged : RuntimePhase.running);
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
  ManagedProfileBootstrapper bootstrapper, {
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
  test('API outage connects the protected profile through expiry grace and exposes offline states', () async {
    final originalStorage = FlutterSecureStoragePlatform.instance;
    final protectedValues = <String, String>{};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(protectedValues);
    final directory = await Directory.systemTemp.createTemp('pokrov-offline-connect-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
      FlutterSecureStoragePlatform.instance = originalStorage;
    });
    var apiUnavailable = false;
    var failedRequests = 0;
    var clientsCreated = 0;
    final managedQueries = <Map<String, String>>[];
    DateTime? cacheNow;
    final expiry = DateTime.now().toUtc().add(const Duration(days: 2));
    final inputs = ManagedProfileCacheInputs(hostPlatform: HostPlatform.android,
      routeMode: buildSeedAppContext(hostPlatform: HostPlatform.android).runtimeProfile.defaultRouteMode);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (apiUnavailable) {
          failedRequests++;
          request.response.statusCode = HttpStatus.serviceUnavailable;
          request.response.write('{"detail":"temporarily unavailable"}');
        } else if (request.uri.path == '/api/client/session/start-trial') {
          request.response.write(jsonEncode({
            'session': {'session_token': 'offline-test-session', 'account_id': 'offline-test-account'},
            'provisioning': {'status': 'ready', 'sync_ok': true},
          }));
        } else if (request.uri.path == '/api/client/profile/managed') {
          managedQueries.add(request.uri.queryParameters);
          request.response.write(jsonEncode({
            'profile_revision': 'offline-test-profile', 'config_format': 'singbox-json',
            'transport_profile': 'legacy_reality_fallback', 'transport_kind': 'reality',
            if (request.uri.queryParameters['catalog_version'] == '1') 'transport_catalog': {
              'schema_version': 'pokrov-transport-catalog-v1', 'revision': 'offline-test-profile',
              'selected_candidate_ref': 'de:legacy_reality_fallback',
              'candidates': [{
                'candidate_ref': 'de:legacy_reality_fallback', 'profile_ref': 'legacy_reality_fallback',
                'node_code': 'de', 'country_code': 'DE', 'protocol': 'vless',
                'transport': 'tcp', 'protection': 'reality', 'priority': 0,
                'parameters': {'network': 'tcp', 'flow': ''},
                'requirements': {'minimum_client_release': '1.2.0', 'minimum_core_release': null,
                  'platforms': ['android', 'windows'],
                  'required_features': ['singbox_reality_v1', 'singbox_tls_v1', 'singbox_utls_v1', 'singbox_vless_v1']},
              }],
            },
            'provisioning': {'status': 'ready', 'sync_ok': true},
            'access': {'access_state': 'paid_unlimited', 'expiry_at': expiry.toIso8601String()},
            'config_payload': {
              'outbounds': [
                {'type': 'selector', 'tag': 'proxy', 'outbounds': ['test-node'], 'default': 'test-node'},
                {'type': 'vless', 'tag': 'test-node', 'server': 'vpn.example.test', 'server_port': 443,
                  'uuid': '11111111-1111-4111-8111-111111111111'},
              ],
              'route': {'final': 'proxy'},
            },
          }));
        } else {
          request.response.write('{"ok":true}');
        }
        await request.response.close();
      }
    }());
    AppFirstRuntimeBootstrapper bootstrapper() => AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}',
      supportDirectoryResolver: () async => directory,
      managedProfileCache: ManagedProfileCache(now: () => cacheNow ?? DateTime.now().toUtc()),
      httpClientFactory: () { clientsCreated++; return HttpClient(); },
      allExceptRuRuleSetUrlsResolver: (_) => const [], maxRequestAttempts: 1,
    );
    final onlineRuntime = _Runtime()..supportsCandidates = true..phase = RuntimePhase.configStaged;
    final onlineManager = _manager(onlineRuntime, bootstrapper());
    addTearDown(onlineManager.dispose);
    expect(onlineRuntime.value(RuntimePhase.artifactReady).transportCapabilities, isNull);
    await onlineManager.connect();
    expect(onlineManager.status.phase, ConnectionPhase.connected);
    expect(onlineRuntime.calls, isNot(contains('initialize')));
    expect(managedQueries.single['catalog_version'], '1');
    expect(managedQueries.single['client_platform'], inputs.hostPlatform.name);
    expect(managedQueries.single['runtime_features']!.split(','),
        RuntimeTransportFeature.values.map((feature) => feature.wireName).toList()..sort());
    expect(managedQueries.single.containsKey('core_release'), isFalse);
    expect(onlineManager.transportCatalog?.selectedCandidateRef, 'de:legacy_reality_fallback');
    expect(onlineRuntime.probeStarted.isCompleted, isTrue);
    final downloadedProfile = onlineRuntime.stagedProfile;
    await onlineManager.disconnect();
    expect(protectedValues, isNotEmpty);
    apiUnavailable = true;
    cacheNow = expiry.add(const Duration(hours: 23));
    final runtime = _Runtime()..networkAvailable = null..supportsCandidates = true;
    // A fresh bootstrap instance must restore the protected record after restart.
    final manager = _manager(runtime, bootstrapper());
    addTearDown(manager.dispose);
    await manager.connect();
    expect(failedRequests, greaterThan(0));
    expect(clientsCreated, greaterThan(1));
    expect(runtime.stagedProfile, downloadedProfile);
    expect(runtime.connectCalls, 1);
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.offlineState, ManagedProfileOfflineState.apiUnavailable,
      reason: 'unknown native network status is not evidence of no network');

    await manager.disconnect();
    cacheNow = expiry.add(const Duration(hours: 24, seconds: 1));
    runtime.networkAvailable = true;
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(manager.offlineState, ManagedProfileOfflineState.accessEnded);
    expect(runtime.connectCalls, 1, reason: 'an expired cache cannot reuse the already staged host profile');
    runtime.networkAvailable = false;
    await manager.connect();
    expect(manager.offlineState, ManagedProfileOfflineState.noNetwork);
    runtime.networkAvailable = true;
    runtime.captivePortal = true;
    await manager.connect();
    expect(manager.offlineState, ManagedProfileOfflineState.captivePortal);
    expect(runtime.calls.where((call) => call == 'stage'), hasLength(1));
  });

  test('catalog winner settles every probe before staging its exact profile', () async {
    final runtime = _Runtime()..supportsCandidates = true..holdProbes = true..failProbeCancellation = true;
    final bootstrapper = _Bootstrapper(catalog: true);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    final connection = manager.connect();
    await runtime.probeStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(manager.status.phase, ConnectionPhase.probing);
    expect(runtime.activeProbes, hasLength(3));
    runtime.probeRelease.complete();
    await connection;
    expect(runtime.activeProbes, isEmpty);
    expect(runtime.stagedProfile, 'de:profile_1');
    expect(bootstrapper.resolutions.every((call) => !call.select && !call.cache), isTrue);
    expect(manager.status.phase, ConnectionPhase.connected);
  });

  test('failed protected recovery never disconnects and explicit off releases it', () async {
    final runtime = _Runtime()..supportsCandidates = true..warpEgressFailure = true..failHandoff = true;
    final manager = _manager(runtime, _Bootstrapper(catalog: true));
    addTearDown(manager.dispose);
    await manager.connect();
    await runtime.handoffStarted.future;
    while (manager.busy) { await Future<void>.delayed(Duration.zero); }
    expect(runtime.handoffCalls, 1);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    await manager.connect();
    expect(runtime.handoffCalls, 2, reason: 'a retry also keeps the native guard');
    expect(runtime.calls, isNot(contains('disconnect')));
    await manager.disconnect();
    expect(runtime.calls.where((call) => call == 'disconnect'), hasLength(1));
  });

  test('first activation egress failure retries stage and connect without protected replacement', () async {
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true..failFirstActivation = true;
    final manager = _manager(runtime, _Bootstrapper(catalog: true),
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);
    await manager.connect();
    while (runtime.connectCalls < 2 || manager.busy) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(runtime.calls.where((call) => call == 'stage'), hasLength(2));
    expect(runtime.connectCalls, 2);
    expect(runtime.handoffCalls, 0);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(runtime.overlappingMutation, isFalse);
  });

  test('retry after UI restart preserves a guard without in-memory candidate state', () async {
    final runtime = _Runtime()..supportsCandidates = true..phase = RuntimePhase.running
      ..restoredHandoffGuard = true..warpEgressFailure = true..failHandoff = true;
    final manager = _manager(runtime, _Bootstrapper(catalog: true));
    addTearDown(manager.dispose);
    await manager.connect();
    expect(runtime.handoffCalls, 1);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.actionRequired);
  });

  test('healthy catalog reconnect and cancellation retain protection until explicit off', () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final bootstrapper = _Bootstrapper(catalog: true);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    await manager.reconnect();
    expect(runtime.handoffCalls, 1);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.busy, isFalse);

    bootstrapper.gate = Completer<void>();
    final previousResolutions = bootstrapper.resolutions.length;
    final preparing = manager.reconnect();
    while (bootstrapper.resolutions.length == previousResolutions) {
      await Future<void>.delayed(Duration.zero);
    }
    final cancelledPreparation = manager.cancel();
    expect(runtime.calls, isNot(contains('disconnect')));
    bootstrapper.gate!.complete();
    await Future.wait([preparing, cancelledPreparation]);
    expect(runtime.phase, RuntimePhase.running);
    expect(runtime.handoffCalls, 1);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.busy, isFalse);

    bootstrapper.gate = null;
    runtime.handoffRelease = Completer<void>();
    final replacement = manager.reconnect();
    while (runtime.handoffCalls == 1) {
      await Future<void>.delayed(Duration.zero);
    }
    final cancellation = manager.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(runtime.calls, isNot(contains('disconnect')));
    runtime.handoffRelease!.complete();
    await Future.wait([replacement, cancellation]);
    expect(runtime.phase, RuntimePhase.running);
    expect(runtime.connectCalls, 1);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(manager.busy, isFalse);
    await manager.disconnect();
    expect(runtime.calls.where((call) => call == 'disconnect'), hasLength(1));
    expect(runtime.phase, RuntimePhase.configStaged);
  });

  test('location callback retains the running tunnel without catalog capabilities', () async {
    final runtime = _Runtime();
    final manager = _manager(runtime, _Bootstrapper());
    addTearDown(manager.dispose);
    manager.updateLocationsCatalog(ClientLocationsCatalog.fromJson({
      'countries': [
        {'code': 'CH', 'country': 'Switzerland', 'cities': [
          {'code': 'ch', 'city': 'Zurich'},
        ]},
      ],
    }));
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.transportCatalog, isNull);
    expect(manager.snapshot?.transportCapabilities, isNull);

    await manager.setPreferredLocation('ch', 'direct');

    expect(runtime.calls, containsAllInOrder(['invalidate', 'replace']));
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(runtime.calls.where((call) => call == 'stage'), hasLength(1));
    expect(runtime.connectCalls, 1);
    expect(runtime.handoffCalls, 1);
    expect(runtime.stagedProfile, 'ch:profile_0');
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.busy, isFalse);
  });

  test('enabled signed transport mode cannot fall through to ordinary catalog profiles', () async {
    final runtime = _Runtime();
    final bootstrapper = _ManifestBootstrapper();
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.connect();
    expect(bootstrapper.entered.isCompleted, isFalse,
      reason: 'ordinary catalog cannot bypass the required bound ATS runtime');
    expect(runtime.calls, isNot(contains('stage')));
    expect(runtime.connectCalls, 0);
    expect(manager.presentation.isVerified, isFalse);
  });

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
