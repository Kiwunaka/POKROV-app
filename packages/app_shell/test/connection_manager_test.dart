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

class _Bootstrapper implements ManagedProfileBootstrapper, AppFirstNodePreferenceService {
  _Bootstrapper({this.warpEnabled = false, this.catalog = false});
  final bool catalog;
  List<TransportCandidate> candidates = _candidates;
  Duration exactProfileDelay = Duration.zero;
  final cancelledExactProfiles = <String>[];
  SmartConnectProfile? smartConnect;
  final nodePreferences = <SmartConnectProfile>[];
  final resolutions = <({String selected, bool select, bool cache})>[];
  final bool warpEnabled;
  Completer<void>? gate;
  Object? failure;
  StackTrace? failureStack;
  final entered = Completer<void>();
  bool cancelled = false;

  @override
  Future<SmartConnectPreferenceResult> setPreferredSmartConnectNode({
    required HostPlatform hostPlatform, required SmartConnectProfile smartConnect, required String nodeCode,
  }) async {
    nodePreferences.add(smartConnect);
    return SmartConnectPreferenceResult(preferredNodeCode: nodeCode, acceptedSamples: 0);
  }

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
    if (selectedCandidateRef.isNotEmpty && exactProfileDelay > Duration.zero) {
      var stopped = false;
      unawaited(cancelled?.then((_) => stopped = true));
      await Future<void>.delayed(exactProfileDelay);
      if (stopped) cancelledExactProfiles.add(selectedCandidateRef);
    }
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack ?? StackTrace.current);
    final nodeCode = preferredNodeCode.isEmpty ? 'de' : preferredNodeCode;
    final selected = candidates.firstWhere((candidate) => candidate.candidateRef ==
        (selectedCandidateRef.isEmpty ? candidates.first.candidateRef : selectedCandidateRef));
    return ManagedProfilePayload(
      profileName: selectedCandidateRef.isEmpty ? (catalog ? selected.candidateRef : '$nodeCode:profile_0') : selectedCandidateRef,
      transportCatalog: catalog ? TransportCandidateCatalog(revision: 'test',
          selectedCandidateRef: selected.candidateRef, candidates: candidates) : null,
      smartConnect: smartConnect,
      source: RuntimeProfileSource(revision: 'test', origin: RuntimeProfileSourceOrigin.managedManifest,
          protocol: selected.protocol),
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

class _CachedBootstrapper extends _Bootstrapper implements CachedManagedProfileBootstrapper {
  _CachedBootstrapper() : super(catalog: true);
  bool cacheAvailable = true;
  static final alternatives = [
    _candidates.first,
    for (final (index, protocol, protection) in [(1, 'awg', 'awg31'), (2, 'hysteria2', 'tls')])
      TransportCandidate(candidateRef: 'de:cached_$index', profileRef: 'cached_$index', nodeCode: 'de',
        countryCode: 'DE', protocol: protocol, transport: 'udp', protection: protection,
        priority: index, network: 'udp', flow: '', minimumClientRelease: '1.2.0',
        minimumCoreRelease: null, platforms: {HostPlatform.android, HostPlatform.windows}, requiredFeatures: const {}),
  ];

  @override
  Future<ManagedProfilePayload?> loadCachedManagedProfile(ManagedProfileCacheInputs inputs, {
    bool preferProven = false, String selectedCandidateRef = '',
    Set<RuntimeTransportFeature>? runtimeFeatures, String? coreRelease,
  }) async {
    if (!cacheAvailable) return null;
    final selected = alternatives.firstWhere((candidate) =>
        candidate.candidateRef == (selectedCandidateRef.isEmpty ? 'de:profile_0' : selectedCandidateRef));
    return ManagedProfilePayload(profileName: selected.candidateRef, cacheEntryId: selected.candidateRef,
      transportCatalog: TransportCandidateCatalog(revision: 'cached',
          selectedCandidateRef: selected.candidateRef, candidates: alternatives),
      source: RuntimeProfileSource(revision: 'cached', origin: RuntimeProfileSourceOrigin.managedManifest,
          protocol: selected.protocol),
      configPayload: '{"outbounds":[{"type":"socks","tag":"node","server":"127.0.0.1","server_port":1080},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
      materializedForRuntime: true, routeMode: inputs.routeMode, resolvedNodeCode: 'de');
  }
  @override
  Future<void> cacheResolvedManagedProfile(ManagedProfileCacheInputs inputs, ManagedProfilePayload payload,
      {Future<void>? cancelled, bool candidateOnly = false}) async {}
  @override
  Future<void> refreshCachedManagedProfile(ManagedProfileCacheInputs inputs, {
    Set<RuntimeTransportFeature> runtimeFeatures = const {}, String? coreRelease, Future<void>? cancelled,
    String selectedCandidateRef = '', bool alternativesOnly = false,
  }) async {}
  @override
  Future<void> markManagedProfileProven(ManagedProfileCacheInputs inputs, String entryId,
      {String? networkSelectionKey}) async {}
  @override
  Future<ManagedProfileOfflineState> classifyManagedProfileFailure(ManagedProfileCacheInputs inputs,
      {bool? networkAvailable, bool? captivePortal}) async => ManagedProfileOfflineState.apiUnavailable;
}

class _Runtime implements PokrovRuntimeEngine, RuntimeConnectCancellation, RuntimeCandidateProbing, RuntimeProtectedHandoff, RuntimeNetworkAvailability {
  _Runtime({this.heldOperation, this.hostPlatform = HostPlatform.android});
  final String? heldOperation;
  bool supportsCandidates = false;
  bool holdProbes = false;
  bool failProbeCancellation = false;
  bool failHandoff = false;
  final failedProbeProtocols = <String>{};
  final heldProbeProtocols = <String>{};
  Future<void>? alternateProbeGate;
  final probedProtocols = <String>[];
  final handoffProfiles = <String>[];
  String? failedHandoffProfile;
  bool failFirstActivation = false;
  bool restoredHandoffGuard = false;
  final probeRelease = Completer<void>();
  final probeStarted = Completer<void>();
  final alternateProbeStarted = Completer<void>();
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
    expect(value(phase).transportCapabilities, isNotNull);
    final protocol = payload.source?.protocol ?? 'vless';
    probedProtocols.add(protocol);
    final cancelled = Completer<void>();
    activeProbes[probeId] = cancelled;
    if (!probeStarted.isCompleted) probeStarted.complete();
    if (protocol != 'vless' && !alternateProbeStarted.isCompleted) alternateProbeStarted.complete();
    if (holdProbes) {
      if (payload.profileName == 'de:profile_1') { await Future.any([probeRelease.future, cancelled.future]); }
      else { await cancelled.future; }
    }
    if (heldProbeProtocols.contains(protocol)) await cancelled.future;
    if (alternateProbeGate != null && protocol != 'vless') {
      await Future.any([alternateProbeGate!, cancelled.future]);
    }
    activeProbes.remove(probeId);
    final success = !cancelled.isCompleted && !failedProbeProtocols.contains(protocol);
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
    handoffProfiles.add(payload.profileName);
    handoffCalls++;
    _request = 'handoff-$handoffCalls';
    expect(activeProbes, isEmpty);
    if (!handoffStarted.isCompleted) handoffStarted.complete();
    await handoffRelease?.future;
    warpEgressFailure = failHandoff || failedHandoffProfile == payload.profileName || cancelled.contains(_request);
    phase = hostPlatform == HostPlatform.windows && warpEgressFailure
        ? RuntimePhase.configStaged : RuntimePhase.running;
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
        lastFailureKind: failedHandoffProfile != null && warpEgressFailure && phase == RuntimePhase.configStaged
            ? 'core_egress_dns_failed' : failFirstActivation && connectCalls == 1 && phase == RuntimePhase.configStaged
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
  PokrovClientExperienceState saved = const PokrovClientExperienceState.empty();
  @override
  Future<PokrovClientExperienceState> read() async =>
      const PokrovClientExperienceState.empty();
  @override
  Future<void> write(PokrovClientExperienceState state) async { saved = state; }
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
  _ExperienceStore? experienceStore,
}) =>
    ConnectionManager(
      appContext: buildSeedAppContext(hostPlatform: runtime.hostPlatform),
      runtimeEngine: runtime,
      bootstrapper: bootstrapper,
      accountSessionCoordinator:
          AccountSessionCoordinator(accountActions: null),
      firstSessionCoordinator:
          FirstSessionCoordinator(store: _FirstLaunchStore()),
      clientExperienceStore: experienceStore ?? _ExperienceStore(),
      connectHintStore: const PokrovFileConnectHintStore(),
      authorizeAndroidConnect: () async => true,
      windowsTunnelAuthorizer: authorizeWindows,
      refreshSubscription: () async => true,
      onNotice: (_, __) {},
    );

void main() {
  test('unexpected connection diagnostics retain only operation type and application frames', () async {
    final store = _ExperienceStore();
    final bootstrapper = _Bootstrapper()
      ..failure = StateError('synthetic-private-token https://private.example/profile')
      ..failureStack = StackTrace.fromString('''
#0 private (https://private.example/profile?token=synthetic-private-token:1:2)
#1 private (C:/private/customer-profile.dart:3:4)
#2 first (package:pokrov_app_shell/app_first_runtime_bootstrap.dart:123:9)
#3 second (package:pokrov_runtime_engine/runtime_engine.dart:456:2)
#4 third (package:pokrov_app_shell/src/connection/connection_manager.dart:789:2)
''');
    final runtime = _Runtime();
    final manager = _manager(runtime, bootstrapper, experienceStore: store);
    addTearDown(manager.dispose);
    await manager.connect();
    final event = store.saved.protectionEvents.single;
    expect(event.kind, 'connect_unexpected_managed_profile_refresh');
    expect(event.detail, 'managed_profile_refresh: StateError; app_first_runtime_bootstrap.dart:123, runtime_engine.dart:456');
    expect(event.detail.length, lessThanOrEqualTo(180));
    expect(jsonEncode(event.toJson()), isNot(contains('synthetic-private-token')));
    expect(jsonEncode(event.toJson()), isNot(contains('private.example')));
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(runtime.connectCalls, 0);
  });

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
    var delayedAlternateCompleted = false;
    late final _Runtime onlineRuntime;
    final managedQueries = <Map<String, String>>[];
    DateTime? cacheNow;
    final expiry = DateTime.now().toUtc().add(const Duration(days: 2));
    final inputs = ManagedProfileCacheInputs(hostPlatform: HostPlatform.windows,
      routeMode: buildSeedAppContext(hostPlatform: HostPlatform.windows).runtimeProfile.defaultRouteMode);
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
          final hy2 = request.uri.queryParameters['selected_candidate_ref'] == 'de:hy2_lab';
          if (hy2 && !delayedAlternateCompleted) {
            // Production managed issuance can take longer than the former
            // three-second background deadline, even while the API is healthy.
            await Future<void>.delayed(const Duration(milliseconds: 3200));
            delayedAlternateCompleted = true;
          }
          request.response.write(jsonEncode({
            'profile_revision': 'offline-test-profile', 'config_format': 'singbox-json',
            'transport_profile': hy2 ? 'hy2_lab' : 'legacy_reality_fallback',
            'transport_kind': hy2 ? 'hysteria2' : 'reality',
            if (request.uri.queryParameters['catalog_version'] == '1') 'transport_catalog': {
              'schema_version': 'pokrov-transport-catalog-v1', 'revision': 'offline-test-profile',
              'selected_candidate_ref': hy2 ? 'de:hy2_lab' : 'de:legacy_reality_fallback',
              'candidates': [{
                'candidate_ref': 'de:legacy_reality_fallback', 'profile_ref': 'legacy_reality_fallback',
                'node_code': 'de', 'country_code': 'DE', 'protocol': 'vless',
                'transport': 'tcp', 'protection': 'reality', 'priority': 0,
                'parameters': {'network': 'tcp', 'flow': ''},
                'requirements': {'minimum_client_release': '1.2.0', 'minimum_core_release': null,
                  'platforms': ['android', 'windows'],
                  'required_features': ['singbox_reality_v1', 'singbox_tls_v1', 'singbox_utls_v1', 'singbox_vless_v1']},
              }, if (onlineRuntime.connectCalls > 0) {
                'candidate_ref': 'de:hy2_lab', 'profile_ref': 'hy2_lab',
                'node_code': 'de', 'country_code': 'DE', 'protocol': 'hysteria2',
                'transport': 'udp', 'protection': 'tls', 'priority': 1,
                'parameters': {'network': 'udp', 'flow': ''},
                'requirements': {'minimum_client_release': '1.2.0', 'minimum_core_release': null,
                  'platforms': ['android', 'windows'], 'required_features': ['singbox_hysteria2_v1']},
              }],
            },
            'provisioning': {'status': 'ready', 'sync_ok': true},
            'access': {'access_state': 'paid_unlimited', 'expiry_at': expiry.toIso8601String()},
            'config_payload': hy2 ? {
              '_meta': {'transport_contract': {
                'id': 'pokrov.hy2.outbound.v1',
                'sha256': 'c96b38e58ea33f838f23b80a65f3a9a264e932b7248f206798df9a0b8fa0fb98',
                'profile': 'hy2_lab', 'state': 'enabled', 'generation': 'ordinary-v1',
              }},
              'outbounds': [
                {'type': 'hysteria2', 'tag': 'test-node', 'server': 'hy2.example.invalid',
                  'server_port': 443, 'password': 'synthetic-password', 'up_mbps': 10, 'down_mbps': 50,
                  'tls': {'enabled': true, 'server_name': 'hy2.example.invalid', 'insecure': false, 'alpn': ['h3']}},
                {'type': 'direct', 'tag': 'direct'},
              ],
              'route': {'final': 'test-node'},
            } : {
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
    onlineRuntime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true..phase = RuntimePhase.configStaged;
    final onlineBootstrapper = bootstrapper();
    final previousProfile = await onlineBootstrapper.resolveManagedProfile(hostPlatform: inputs.hostPlatform,
        routeMode: inputs.routeMode, runtimeFeatures: RuntimeTransportFeature.values.toSet(), selectCandidate: false);
    await onlineBootstrapper.markManagedProfileProven(inputs, previousProfile.cacheEntryId, networkSelectionKey: 'network-a');
    final onlineManager = _manager(onlineRuntime, onlineBootstrapper,
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(onlineManager.dispose);
    expect(onlineRuntime.value(RuntimePhase.artifactReady).transportCapabilities, isNull);
    await onlineManager.connect();
    expect(onlineManager.status.phase, ConnectionPhase.connected);
    expect(delayedAlternateCompleted, isFalse, reason: 'first connect does not wait for alternative profiles');
    expect(onlineRuntime.calls, isNot(contains('initialize')));
    expect(managedQueries.first['catalog_version'], '1');
    expect(managedQueries.first['client_platform'], inputs.hostPlatform.name);
    expect(managedQueries.first['runtime_features']!.split(','),
        RuntimeTransportFeature.values.map((feature) => feature.wireName).toList()..sort());
    expect(managedQueries.first.containsKey('core_release'), isFalse);
    expect(onlineManager.transportCatalog?.selectedCandidateRef, 'de:legacy_reality_fallback');
    expect(onlineRuntime.probeStarted.isCompleted, isTrue);
    expect(onlineRuntime.probedProtocols, ['vless'], reason: 'last success is tried first; cache preparation does not probe alternatives');
    var proven = await onlineBootstrapper.loadCachedManagedProfile(inputs, preferProven: true,
        runtimeFeatures: onlineRuntime.value(onlineRuntime.phase).transportCapabilities!.features);
    expect(proven?.provenNetworkSelectionKey, 'network-a');
    final provenEntryId = proven?.cacheEntryId;
    final readyDeadline = DateTime.now().add(const Duration(seconds: 6));
    ManagedProfilePayload? alternate;
    do {
      alternate = await onlineBootstrapper.loadCachedManagedProfile(inputs,
          selectedCandidateRef: 'de:hy2_lab', runtimeFeatures: RuntimeTransportFeature.values.toSet());
      if (alternate == null) await Future<void>.delayed(const Duration(milliseconds: 10));
    } while (alternate == null && DateTime.now().isBefore(readyDeadline));
    expect(alternate, isNotNull);
    proven = await onlineBootstrapper.loadCachedManagedProfile(inputs, preferProven: true,
        runtimeFeatures: RuntimeTransportFeature.values.toSet());
    expect(proven?.cacheEntryId, provenEntryId, reason: 'catalog refresh does not prove new profile bytes');
    expect(proven?.transportCatalog?.candidates.length, 2,
        reason: 'the proven cold-device profile sees the newly acknowledged alternative');
    expect((await onlineBootstrapper.loadCachedManagedProfile(inputs))?.transportCatalog?.selectedCandidateRef,
        'de:legacy_reality_fallback', reason: 'alternate materialization cannot replace the selected record');
    apiUnavailable = true;
    onlineRuntime.failedProbeProtocols.add('vless');
    final probesBefore = onlineRuntime.probedProtocols.length;
    await onlineManager.reconnect();
    expect(onlineManager.status.phase, ConnectionPhase.connected);
    expect(onlineRuntime.probedProtocols.skip(probesBefore), ['vless', 'hysteria2']);
    expect(onlineManager.transportCatalog?.selectedCandidateRef, 'de:hy2_lab');
    expect(onlineRuntime.calls, isNot(contains('disconnect')));
    proven = await onlineBootstrapper.loadCachedManagedProfile(inputs, preferProven: true,
        runtimeFeatures: RuntimeTransportFeature.values.toSet());
    expect(proven?.cacheEntryId, alternate?.cacheEntryId, reason: 'offline proof promotes the existing entry');
    final downloadedProfile = onlineRuntime.stagedProfile;
    onlineRuntime.failHandoff = true;
    await onlineManager.reconnect();
    expect(onlineManager.status.phase, ConnectionPhase.actionRequired);
    expect(onlineRuntime.phase, RuntimePhase.configStaged);
    expect(onlineRuntime.handoffCalls, 2);
    expect(protectedValues, isNotEmpty);
    apiUnavailable = true;
    cacheNow = expiry.add(const Duration(hours: 23));
    onlineRuntime.failHandoff = false;
    await onlineManager.reconnect();
    expect(onlineManager.status.phase, ConnectionPhase.connected);
    expect(onlineManager.offlineState, ManagedProfileOfflineState.apiUnavailable);
    expect(onlineRuntime.handoffCalls, 3);
    expect(onlineRuntime.calls, isNot(contains('disconnect')));
    expect(onlineRuntime.connectCalls, 1);
    final recovered = await onlineBootstrapper.loadCachedManagedProfile(inputs, preferProven: true,
        runtimeFeatures: onlineRuntime.value(onlineRuntime.phase).transportCapabilities!.features);
    expect(recovered?.cacheEntryId, proven?.cacheEntryId);
    await onlineManager.disconnect();
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..networkAvailable = null..supportsCandidates = true;
    // A fresh bootstrap instance must restore the protected record after restart.
    final manager = _manager(runtime, bootstrapper(),
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
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

  test('cold candidate HTTP preparation does not consume the native probe budget', () async {
    final alternatives = _CachedBootstrapper.alternatives;
    final bootstrapper = _Bootstrapper(catalog: true)
      ..candidates = [alternatives[1], alternatives[0], alternatives[2]]
      ..exactProfileDelay = const Duration(milliseconds: 4300);
    final runtime = _Runtime()..supportsCandidates = true;
    runtime.heldProbeProtocols.addAll(['awg', 'vless']);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);

    await manager.connect();

    expect(runtime.probedProtocols, containsAll(['awg', 'vless', 'hysteria2']),
        reason: 'an initial AWG timeout must not discard pending exact TCP/HY2 profiles');
    expect(bootstrapper.cancelledExactProfiles, isEmpty,
        reason: 'the HTTP preparation is bounded by selection, not the native four-second probe');
    expect(runtime.stagedProfile, alternatives[2].candidateRef);
    expect(runtime.activeProbes, isEmpty);
    expect(manager.status.phase, ConnectionPhase.connected);
  });

  test('confirmed failure races cached alternatives before a hanging API or AWG probe', () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final bootstrapper = _CachedBootstrapper();
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.connect();
    final resolutionsBefore = bootstrapper.resolutions.length;
    final probesBefore = runtime.probedProtocols.length;
    bootstrapper.gate = Completer<void>();
    addTearDown(() => bootstrapper.gate!.complete());
    runtime.heldProbeProtocols.add('awg');
    runtime.warpEgressFailure = true;

    await runtime.handoffStarted.future.timeout(const Duration(seconds: 3), onTimeout: () {
      fail('${manager.status.phase}: ${manager.headline}; probes=${runtime.probedProtocols}; calls=${runtime.calls}');
    });
    while (manager.busy) { await Future<void>.delayed(Duration.zero); }
    expect(bootstrapper.resolutions, hasLength(resolutionsBefore), reason: 'ready cache never waits for the API');
    expect(runtime.probedProtocols.skip(probesBefore), ['awg', 'hysteria2'],
        reason: 'the confirmed failed current is not probed again');
    expect(runtime.handoffProfiles, ['de:cached_2']);
    expect(runtime.activeProbes, isEmpty, reason: 'the losing AWG probe settles before handoff');
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.connected);
  });

  for (final interrupt in ['cancel', 'deny']) {
    test('$interrupt during cached recovery cannot activate a late winner', () async {
      final runtime = _Runtime()..supportsCandidates = true;
      final bootstrapper = _CachedBootstrapper();
      final manager = _manager(runtime, bootstrapper);
      addTearDown(manager.dispose);
      await manager.connect();
      final resolutionsBefore = bootstrapper.resolutions.length;
      bootstrapper.gate = Completer<void>();
      addTearDown(() => bootstrapper.gate!.complete());
      final gate = Completer<void>();
      runtime.alternateProbeGate = gate.future;
      runtime.warpEgressFailure = true;
      await runtime.alternateProbeStarted.future.timeout(const Duration(seconds: 3));
      if (interrupt == 'cancel') {
        await manager.cancel();
      } else {
        await manager.denyAccess();
        gate.complete();
      }
      while (manager.busy) { await Future<void>.delayed(Duration.zero); }
      expect(runtime.handoffCalls, 0);
      expect(runtime.activeProbes, isEmpty);
      expect(bootstrapper.resolutions, hasLength(resolutionsBefore));
      expect(runtime.calls, isNot(contains('disconnect')));
      expect(manager.retainsProtection, isTrue);
    });
  }

  test('failed protected recovery never disconnects and explicit off releases it', () async {
    final runtime = _Runtime()..supportsCandidates = true..warpEgressFailure = true..failHandoff = true;
    final manager = _manager(runtime, _Bootstrapper(catalog: true));
    addTearDown(manager.dispose);
    await manager.connect();
    await runtime.handoffStarted.future;
    while (manager.busy) { await Future<void>.delayed(Duration.zero); }
    expect(runtime.handoffCalls, 3);
    expect(runtime.handoffProfiles.toSet(), hasLength(3), reason: 'activation failures advance to different candidates');
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    await expectLater(manager.repair(), throwsA(isA<BootstrapFailure>()));
    expect(runtime.handoffCalls, inInclusiveRange(4, 6), reason: 'a retry also keeps the native guard');
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.retainsProtection, isTrue);
    expect(manager.presentation.primaryActionLabel, 'Отключить');
    expect(manager.presentation.primaryActionEnabled, isTrue);
    await manager.toggle();
    expect(runtime.calls.where((call) => call == 'disconnect'), hasLength(1));
    expect(manager.retainsProtection, isFalse);
  });

  test('successful probe followed by activation failure advances without disconnect', () async {
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)..supportsCandidates = true;
    final manager = _manager(runtime, _Bootstrapper(catalog: true),
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);
    await manager.connect();
    runtime.failedHandoffProfile = 'de:profile_0';
    await manager.reconnect();
    expect(runtime.handoffProfiles, ['de:profile_0', 'de:profile_1']);
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(runtime.overlappingMutation, isFalse);
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

  test('healthy catalog reconnect and repair cancellation retain protection until explicit off', () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final bootstrapper = _Bootstrapper(catalog: true);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    runtime.pendingFirstEgress = true;
    await manager.repair();
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
    Future<void> Function()? cancelRepair;
    final replacement = manager.repair(onCancelAvailable: (value) => cancelRepair = value);
    final interruptedRepair = expectLater(replacement, throwsA(isA<ConnectionOperationSuperseded>()));
    while (runtime.handoffCalls == 1) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(cancelRepair, isNotNull);
    final cancellation = cancelRepair!();
    await Future<void>.delayed(Duration.zero);
    expect(runtime.calls, isNot(contains('disconnect')));
    runtime.handoffRelease!.complete();
    await Future.wait([interruptedRepair, cancellation]);
    expect(cancelRepair, isNull);
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

  for (final ordinaryCatalog in [true, false]) {
    test('location preference uses ${ordinaryCatalog ? 'catalog policy' : 'legacy lab'} transport metadata', () async {
      final current = SmartConnectProfile.tryParse({
        'transport_profile': 'awg31_lab', 'profile_revision': 'current-awg',
        'shortlist': [{'code': 'de'}, {'code': 'us'}],
      })!;
      final bootstrapper = _Bootstrapper(catalog: ordinaryCatalog)..smartConnect = current;
      final runtime = _Runtime()..supportsCandidates = ordinaryCatalog;
      final manager = _manager(runtime, bootstrapper);
      addTearDown(manager.dispose);
      manager.updateLocationsCatalog(ClientLocationsCatalog.fromJson({
        'transport_profile': 'legacy_reality_fallback', 'profile_revision': 'locations-policy',
        'countries': [{'code': 'US', 'country': 'USA', 'cities': [{'code': 'us', 'city': 'New York'}]}],
      }));
      await manager.connect();
      await manager.disconnect();

      await manager.setPreferredLocation('us', 'direct');

      final preference = bootstrapper.nodePreferences.single;
      expect(preference.transportProfile, ordinaryCatalog ? 'legacy_reality_fallback' : 'awg31_lab');
      expect(preference.profileRevision, ordinaryCatalog ? 'locations-policy' : 'current-awg');
      expect(preference.shortlist, same(current.shortlist));
    });
  }

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
