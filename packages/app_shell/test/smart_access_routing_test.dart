import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_app_shell/routing_catalog_contract.dart';
import 'package:pokrov_app_shell/routing_catalog_materializer.dart';
import 'package:pokrov_app_shell/routing_catalog_policy.dart';
import 'package:pokrov_app_shell/smart_access_profile.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

void main() {
  test('stale signed provider scope preserves VPN fallback and catalog validation', () async {
    final clock = DateTime.now().toUtc();
    final now = DateTime.utc(clock.year, clock.month, clock.day,
        clock.hour, clock.minute, clock.second);
    final catalog = _Catalog(now);
    Future<List<Map<String, Object?>>> selected(_Catalog providerCatalog,
        {VerifiedRoutingCatalog? routingCatalog}) => selectSmartAccessWebCapabilities(
      catalog: routingCatalog ?? catalog, providers: _Providers(providerCatalog),
      serviceIds: {'ai'}, platform: 'android', now: now,
      selectionSeed: '01' * 32, selectedProviderId: 'owned', isCurrent: () => true);
    expect(await selected(_Catalog(now.subtract(const Duration(hours: 2)))), isEmpty);
    expect(await selected(_Catalog(now.add(const Duration(hours: 2)))), isEmpty);
    final fallback = compileCatalogDomainPolicy(
      policy: RoutingCatalogPolicy.fromVerified(catalog), mode: CatalogRoutingMode.smartSafe,
      platform: 'android', accessState: 'paid_unlimited', vpnAvailable: true, now: now);
    expect(fallback.rules.single.action, CatalogRouteAction.vpn);
    expect(fallback.rules.single.fallbackReason, 'gateway_unavailable_using_vpn');
    await expectLater(selected(_Catalog(now),
      routingCatalog: _Catalog(now.subtract(const Duration(hours: 2)))),
      throwsA(isA<RoutingCatalogFailure>()));
  });

  test('local SmartDNS without eligible provider connects through existing VPN path', () async {
    final clock = DateTime.now().toUtc();
    final now = DateTime.utc(clock.year, clock.month, clock.day,
        clock.hour, clock.minute, clock.second);
    final originalStorage = FlutterSecureStoragePlatform.instance;
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    addTearDown(() => FlutterSecureStoragePlatform.instance = originalStorage);
    final bootstrapper = _LifecycleBootstrapper(_Catalog(now, audience: 'production'));
    final runtime = _LifecycleRuntime();
    final store = _ExperienceStore();
    final manager = ConnectionManager(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      runtimeEngine: runtime, bootstrapper: bootstrapper,
      accountSessionCoordinator: AccountSessionCoordinator(accountActions: null),
      firstSessionCoordinator: FirstSessionCoordinator(store: _FirstLaunchStore()),
      clientExperienceStore: store, connectHintStore: const PokrovFileConnectHintStore(),
      authorizeAndroidConnect: () async => true, refreshSubscription: () async => true,
      onNotice: (_, __) {});
    addTearDown(manager.dispose);
    manager.setConnectHintDismissed(true);
    manager.selectCatalogServices({'ai'});
    manager.setRoutingPreferences(const PokrovRoutingPreferences.defaults().copyWith(
      selectedCatalogServiceIds: {'ai'}, smartDnsProviderId: 'missing-provider'));
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected, reason: manager.headline);
    expect(bootstrapper.grantRequests, 0);
    expect(bootstrapper.ordinaryRequests, 1);
    final config = jsonDecode(runtime.payload!.configPayload) as Map;
    expect((config['outbounds'] as List).any((row) => row['type'] == 'pokrov-smart-access'), isFalse);
    expect((config['route']['rules'] as List).any((row) =>
      row['domain_suffix']?.contains('chatgpt.com') == true && row['outbound'] == 'vpn'), isTrue);
    expect(store.saved.routingPreferences.smartDnsProviderId, 'missing-provider');
    await manager.disconnect();
  });

  test('owned Smart DNS supports RU-direct and DNS-only with protected fallback', () async {
    final clock = DateTime.now().toUtc();
    final now = DateTime.utc(clock.year, clock.month, clock.day,
        clock.hour, clock.minute, clock.second);
    final catalog = _Catalog(now);
    final policy = RoutingCatalogPolicy.fromVerified(catalog);
    for (final mode in [CatalogRoutingMode.smartSafe, CatalogRoutingMode.selective]) {
      final wireMode = mode == CatalogRoutingMode.smartSafe ? 'smart_safe' : 'selective';
      final grant = _Grant(now, wireMode, await smartAccessProfileSha256('{}'));
      final leases = await SmartAccessProfileLeases.bind(baseProfile: '{}', leases: [grant], routeMode: wireMode);
      final compiled = compileCatalogDomainPolicy(policy: policy, mode: mode,
        platform: 'android', accessState: 'paid_unlimited', vpnAvailable: true, now: now,
        selectedServiceIds: mode == CatalogRoutingMode.selective ? {'ai'} : {}, smartAccessProfile: leases);
      final layer = materializeCatalogRuleLayer(policy: compiled, nativeWindowVersion: 1,
        nativeSmartAccessLeaseVersion: 1, vpnOutbound: 'vpn', directOutbound: 'direct',
        vpnDnsServer: 'vpn-dns', directDnsServer: 'direct-dns', now: now);
      expect(layer.outbounds.single['type'], 'pokrov-smart-access');
      expect(layer.dnsServers.single['address'], 'https://dns.example.test/dns-query');
      expect(layer.routeRules[1]['outbound'], 'vpn');
      expect(layer.dnsRules[1]['server'], 'vpn-dns');
      expect(compiled.defaultAction, mode == CatalogRoutingMode.selective ? CatalogRouteAction.direct : CatalogRouteAction.vpn);
      final unavailable = compileCatalogDomainPolicy(policy: policy, mode: mode,
        platform: 'android', accessState: 'paid_unlimited', vpnAvailable: true, now: now,
        selectedServiceIds: mode == CatalogRoutingMode.selective ? {'ai'} : {});
      expect(unavailable.rules.single.action, CatalogRouteAction.vpn);
      expect(() => compileCatalogDomainPolicy(policy: policy,
        mode: mode == CatalogRoutingMode.smartSafe ? CatalogRoutingMode.selective : CatalogRoutingMode.smartSafe,
        platform: 'android', accessState: 'paid_unlimited', vpnAvailable: true, now: now,
        selectedServiceIds: mode == CatalogRoutingMode.smartSafe ? {'ai'} : {}, smartAccessProfile: leases),
        throwsA(isA<RoutingCatalogFailure>()));
    }

    final base = AppFirstRuntimeBootstrapper()
        .buildLocalSmartAccessBase(hostPlatform: HostPlatform.android);
    final grant = _Grant(now, 'selective', await smartAccessProfileSha256(base.configPayload));
    final leases = await SmartAccessProfileLeases.bind(baseProfile: base.configPayload, leases: [grant]);
    final compiled = compileCatalogDomainPolicy(policy: policy, mode: CatalogRoutingMode.selective,
      platform: 'android', accessState: 'paid_unlimited', vpnAvailable: false, now: now,
      selectedServiceIds: {'ai'}, smartAccessProfile: leases);
    final preferences = const PokrovRoutingPreferences.defaults()
        .copyWith(selectedCatalogServiceIds: {'ai'});
    expect(base.freeProfileAccess, isNull);
    final configured = applyPokrovRoutingPreferences(base, preferences,
      hostPlatform: HostPlatform.android, catalogPolicy: compiled, catalogAccessState: 'paid_unlimited',
      nativeCatalogWindowVersion: 1, nativeSmartAccessLeaseVersion: 1);
    final config = jsonDecode(configured.configPayload) as Map<String, dynamic>;
    expect(configured.coreEgressProbeRequired, isTrue);
    expect(config['route']['final'], 'direct');
    expect((config['outbounds'] as List).map((row) => row['type']), ['direct', 'pokrov-smart-access']);
    expect(config['dns']['final'], 'dns-direct');
    expect((config['dns']['servers'] as List).any((row) => row['tag'] == 'dns-remote'), isFalse);
    final selectedRoute = (config['route']['rules'] as List)
        .where((row) => row['domain_suffix']?.contains('chatgpt.com') == true).toList();
    expect(selectedRoute.first['outbound'], smartAccessOutboundTag(grant));
    expect(selectedRoute.last['action'], 'reject');

    final unavailable = compileCatalogDomainPolicy(policy: policy, mode: CatalogRoutingMode.selective,
      platform: 'android', accessState: 'paid_unlimited', vpnAvailable: false, now: now,
      selectedServiceIds: {'ai'});
    final blocked = applyPokrovRoutingPreferences(base, preferences,
      hostPlatform: HostPlatform.android, catalogPolicy: unavailable, catalogAccessState: 'paid_unlimited',
      nativeCatalogWindowVersion: 1, nativeSmartAccessLeaseVersion: 1);
    final blockedConfig = jsonDecode(blocked.configPayload) as Map<String, dynamic>;
    expect(blockedConfig['route']['final'], 'direct');
    final blockedService = (blockedConfig['route']['rules'] as List)
        .where((row) => row['domain_suffix']?.contains('chatgpt.com') == true);
    expect(blockedService, isNotEmpty);
    expect(blockedService.every((row) => row['action'] == 'reject'), isTrue);
    expect(() => applyPokrovRoutingPreferences(base.copyWith(configPayload: '{}'), preferences,
      hostPlatform: HostPlatform.android, catalogPolicy: compiled, catalogAccessState: 'paid_unlimited',
      nativeCatalogWindowVersion: 1, nativeSmartAccessLeaseVersion: 1),
      throwsA(isA<RoutingCatalogFailure>()));

    final originalStorage = FlutterSecureStoragePlatform.instance;
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    addTearDown(() => FlutterSecureStoragePlatform.instance = originalStorage);
    final bootstrapper = _LifecycleBootstrapper(_Catalog(now, audience: 'production'));
    final runtime = _LifecycleRuntime();
    final experienceStore = _ExperienceStore();
    final directory = await Directory.systemTemp.createTemp('pokrov-smart-lifecycle-');
    final observability = await PokrovClientObservability.start(hostPlatform: HostPlatform.android,
      directoryResolver: () async => directory);
    addTearDown(() async { await observability.flush(); await directory.delete(recursive: true); });
    final manager = ConnectionManager(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      runtimeEngine: runtime, bootstrapper: bootstrapper,
      accountSessionCoordinator: AccountSessionCoordinator(accountActions: null),
      firstSessionCoordinator: FirstSessionCoordinator(store: _FirstLaunchStore()),
      clientExperienceStore: experienceStore,
      observability: observability,
      connectHintStore: const PokrovFileConnectHintStore(),
      authorizeAndroidConnect: () async => true, refreshSubscription: () async => true,
      onNotice: (_, __) {});
    addTearDown(manager.dispose);
    manager.setConnectHintDismissed(true);
    manager.selectCatalogServices({'ai'});
    await manager.connect();
    await observability.flush();
    final journal = await (observability.dispatcher.writer as RotatingOperationalJsonlStore).readCurrent();
    expect(manager.status.phase, ConnectionPhase.connected, reason:
      '${manager.headline}; grants=${bootstrapper.grantRequests}; '
      '${journal.records.map((row) => (row['attributes'] as Map)['prepare_reason']).whereType<String>().toList()}');
    expect(bootstrapper.grantRequests, 1);
    expect(bootstrapper.ordinaryRequests, 0, reason: 'local Smart starts without managed VPN material');

    Future<void> awaitAutomaticVpn(int requestCount) async {
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while ((bootstrapper.ordinaryRequests < requestCount || manager.busy ||
          manager.status.phase != ConnectionPhase.connected) && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(bootstrapper.ordinaryRequests, requestCount, reason: manager.headline);
      expect(manager.status.phase, ConnectionPhase.connected, reason:
        '${manager.headline}; stage_error=${runtime.stageError}; unsupported=${runtime.unsupported}');
      expect(manager.busy, isFalse);
      expect(bootstrapper.grantRequests, 1, reason: 'automatic VPN recovery must not reissue failed Smart grants');
      final current = jsonDecode(runtime.payload!.configPayload) as Map;
      expect(current['route']['final'], 'direct');
      expect((current['outbounds'] as List).any((row) => row['type'] == 'pokrov-smart-access'), isFalse);
      expect((current['route']['rules'] as List).any((row) =>
          row['domain_suffix']?.contains('chatgpt.com') == true && row['outbound'] == 'vpn'), isTrue);
      expect(experienceStore.saved.routingPreferences.selectedCatalogServiceIds, {'ai'});
    }

    runtime.fail('core_egress_dns_failed', stopped: true);
    await awaitAutomaticVpn(1);
    runtime.fail('core_egress_connect_failed', stopped: true);
    await awaitAutomaticVpn(2);
    runtime.fail('core_egress_tls_failed', stopped: false);
    await awaitAutomaticVpn(3);

    runtime.fail('core_egress_connect_failed', stopped: true);
    await manager.refresh();
    expect(manager.snapshot?.phase, RuntimePhase.configStaged);
    expect(manager.retainsProtection, isFalse);
    await manager.disconnect();
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(bootstrapper.ordinaryRequests, 3, reason: 'explicit Disconnect stops automatic recovery');
    expect(bootstrapper.grantRequests, 1);
    expect(manager.snapshot?.phase, RuntimePhase.configStaged);
    expect(manager.busy, isFalse);
  });
}

class _Catalog implements VerifiedRoutingCatalog {
  _Catalog(this.now, {this.audience = 'lab'});
  final DateTime now;
  final String audience;
  @override
  int get revision => 1;
  @override
  int get securityRevision => 1;
  @override
  String get payloadSha256 => 'ab' * 32;
  @override
  DateTime get issuedAt => now.subtract(const Duration(minutes: 1));
  @override
  DateTime get expiresAt => now.add(const Duration(hours: 1));
  @override
  Map<String, Object?> get payload => {
    'audience': audience, 'issued_at': issuedAt.toIso8601String(), 'expires_at': expiresAt.toIso8601String(),
    'sources': [{'source_id': 'owned', 'license': 'owner', 'revision': '1',
      'url': 'https://source.example.test/list', 'sha256': 'bc' * 32,
      'retrieved_at': issuedAt.toIso8601String().replaceFirst('.000Z', 'Z'), 'expires_at': expiresAt.toIso8601String().replaceFirst('.000Z', 'Z')}],
    'evidence': [{'evidence_id': 'probe', 'service_id': 'ai', 'source_ids': ['owned'],
      'sha256': 'cd' * 32, 'origin': audience == 'production' ? 'current-origin' : 'synthetic',
      'observed_at': issuedAt.toIso8601String().replaceFirst('.000Z', 'Z'),
      'expires_at': expiresAt.toIso8601String().replaceFirst('.000Z', 'Z')}],
    'services': [{'service_id': 'ai', 'display_name': 'AI', 'categories': ['ai'],
      'enabled': true, 'classification': 'geo_restricted', 'reason': 'Owned Smart DNS',
      'evidence_status': 'verified', 'source_ids': ['owned'], 'evidence_ids': ['probe'],
      'platforms': ['android'], 'access_states': ['paid_unlimited'],
      'route_intents': [{'mode': 'smart_safe', 'action': 'approved_gateway'},
        {'mode': 'selective', 'action': 'approved_gateway'}],
      'android': [], 'windows': [], 'domains': [{'name': 'chatgpt.com', 'match': 'suffix',
        'role': 'web', 'shared': false, 'source_ids': ['owned']}],
      'networks': [], 'provider_capability_refs': ['ai-android'], 'external_gateway_policy': 'approved'}],
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Grant implements VerifiedSmartAccessLease {
  _Grant(this.now, this.mode, this.profile, {this.audience = 'lab'});
  final DateTime now;
  final String mode;
  final String profile;
  final String audience;
  @override
  Map<String, Object?> get grant => {'profile_sha256': profile, 'route_mode': mode};
  @override
  DateTime get issuedAt => now.subtract(const Duration(minutes: 1));
  @override
  DateTime get newFlowsUntil => now.add(const Duration(minutes: 9));
  @override
  DateTime get activeFlowsUntil => now.add(const Duration(minutes: 59));
  @override
  bool admitsNewFlows(DateTime value) => value.isBefore(newFlowsUntil);
  @override
  Map<String, Object?> get runtimeIdentity => {
    for (final key in ['lease_id', 'audience', 'platform', 'service_id', 'provider_id',
      'permission_id', 'capability_id', 'provider_policy_revision', 'provider_security_revision',
      'provider_policy_sha256', 'issued_at', 'new_flows_until', 'active_flows_until']) key: lease[key],
  };
  @override
  Map<String, Object?> get lease => {
    'lease_id': '0123456789abcdef0123456789abcdef', 'service_id': 'ai', 'provider_id': 'owned',
    'platform': 'android', 'audience': audience, 'origin': 'current-origin', 'family': 'ipv4',
    'permission_id': 'owned-permission', 'capability_id': 'ai-android',
    'provider_policy_revision': 1, 'provider_security_revision': 1, 'provider_policy_sha256': 'ef' * 32,
    'feature': 'web_request', 'transport': 'tls_tcp_443_visible_sni',
    'catalog_sha256': 'ab' * 32, 'catalog_revision': 1, 'catalog_security_revision': 1,
    'resolver_url': 'https://dns.example.test/dns-query', 'relay_addresses': ['8.8.8.8'],
    'domains': [{'name': 'chatgpt.com', 'match': 'suffix'}], 'relay_connect_policy': null,
    'issued_at': issuedAt.toIso8601String().replaceFirst('.000Z', 'Z'), 'new_flows_until': newFlowsUntil.toIso8601String().replaceFirst('.000Z', 'Z'),
    'active_flows_until': activeFlowsUntil.toIso8601String().replaceFirst('.000Z', 'Z'),
    'max_new_connections_per_minute': 10, 'max_concurrent_connections': 4,
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Providers implements VerifiedSmartAccessProviderPolicy {
  _Providers(this.catalog);
  final _Catalog catalog;
  @override
  Map<String, Object?> get payload => {
    'issued_at': catalog.issuedAt.toIso8601String(), 'expires_at': catalog.expiresAt.toIso8601String(),
    'providers': [<String, Object?>{'provider_id': 'owned', 'kind': 'owned', 'enabled': true,
      'revision': 1, 'permission_id': 'owned-permission'}],
    'permissions': [<String, Object?>{'permission_id': 'owned-permission', 'provider_id': 'owned',
      'status': 'approved', 'embedded_use_allowed': true,
      'issued_at': catalog.issuedAt.toIso8601String(), 'expires_at': catalog.expiresAt.toIso8601String()}],
    'capabilities': [<String, Object?>{'capability_id': 'ai-android', 'service_id': 'ai',
      'provider_id': 'owned', 'provider_revision': 1, 'enabled': true, 'verification': 'verified',
      'platform': 'android', 'origin': 'current-origin', 'feature': 'web_request',
      'transport': 'tls_tcp_443_visible_sni', 'family': 'ipv4',
      'observed_at': catalog.issuedAt.toIso8601String(), 'expires_at': catalog.expiresAt.toIso8601String(),
      'domains': [<String, Object?>{'name': 'chatgpt.com', 'match': 'suffix'}]}],
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LifecycleBootstrapper extends AppFirstRuntimeBootstrapper {
  _LifecycleBootstrapper(this.catalog) : super(apiBaseUrl: 'http://127.0.0.1:1', maxRequestAttempts: 1);
  final _Catalog catalog;
  int grantRequests = 0;
  int ordinaryRequests = 0;
  @override
  bool get routingCatalogEnabled => true;
  @override
  bool get smartAccessEnabled => true;
  @override
  bool get smartAccessControlAvailable => true;
  @override
  Future<WarpControlStatus> fetchWarpStatus({required HostPlatform hostPlatform,
      Future<void>? cancelled}) async => WarpControlStatus.unavailable;
  @override
  Future<ClientSubscriptionInfo> fetchClientSubscription({required HostPlatform hostPlatform,
      Duration? requestTimeout, Future<void>? cancelled}) async => const ClientSubscriptionInfo(
    lane: 'paid', accessState: 'paid_unlimited', expiresAt: '', daysLeft: 2, autoRenew: false,
    renewUrl: null, plans: [], trafficPolicy: {});
  @override
  Future<RoutingCatalogFetchResult?> fetchRoutingCatalog({required HostPlatform hostPlatform,
      bool cacheOnly = false, Future<void>? cancelled}) async => RoutingCatalogFetchResult(catalog: catalog, usingCache: false);
  @override
  Future<VerifiedSmartAccessProviderPolicy> fetchSmartAccessProviders({required HostPlatform hostPlatform,
      required bool Function() operationIsCurrent, required Duration remainingBudget,
      required Future<void> cancelled}) async => _Providers(catalog);
  @override
  Future<VerifiedSmartAccessLease> requestSmartAccessLease({required HostPlatform hostPlatform,
      required VerifiedRoutingCatalog catalog, required VerifiedSmartAccessProviderPolicy providerPolicy,
      required String capabilityId, required String profileSha256, required String origin,
      required String family, required String feature, String routeMode = 'selective',
      required bool Function() operationIsCurrent, required Duration remainingBudget,
      required Future<void> cancelled}) async {
    grantRequests++;
    return _Grant(this.catalog.now, routeMode, profileSha256, audience: 'production');
  }
  @override
  Future<ManagedProfilePayload> resolveManagedProfile({required HostPlatform hostPlatform,
      required RouteMode routeMode, List<String> selectedApps = const [], String preferredNodeCode = '',
      String preferredVariantId = 'direct', String preferredCountryCode = '', String preferredCandidateRef = '',
      Set<String> excludedNodeCodes = const {}, String tcpFallbackFromRevision = '',
      Set<RuntimeTransportFeature> runtimeFeatures = const {}, String? coreRelease,
      bool selectCandidate = true, String selectedCandidateRef = '', bool cacheResult = true,
      Duration? timeout, Future<void>? cancelled}) async {
    ordinaryRequests++;
    final config = jsonDecode(buildLocalSmartAccessBase(hostPlatform: hostPlatform).configPayload) as Map<String, dynamic>;
    config['outbounds'] = [
      {'type': 'socks', 'tag': 'vpn', 'server': '127.0.0.1', 'server_port': 1080},
      {'type': 'direct', 'tag': 'direct'},
    ];
    config['route']['final'] = 'vpn';
    config['dns']['servers'].add({'tag': 'dns-remote', 'address': 'https://dns.example.test/dns-query',
      'address_resolver': 'dns-direct', 'detour': 'vpn'});
    config['dns']['final'] = 'dns-remote';
    return ManagedProfilePayload(profileName: 'ordinary', materializedForRuntime: true,
      resolvedNodeCode: 'de', routeMode: routeMode,
      freeProfileAccess: FreeProfileAccess.tryParse(access: {'access_state': 'paid_unlimited'}),
      configPayload: jsonEncode(config));
  }
  @override
  Future<ManagedProfilePayload?> loadCachedManagedProfile(ManagedProfileCacheInputs inputs,
      {bool preferProven = false, String selectedCandidateRef = '',
      Set<RuntimeTransportFeature>? runtimeFeatures, String? coreRelease}) async => null;
  @override
  Future<void> markManagedProfileProven(ManagedProfileCacheInputs inputs, String entryId,
      {String? networkSelectionKey, String? offlineNetworkSelectionKey}) async {}
  @override
  Future<VerifiedSmartAccessControl> fetchSmartAccessControl({required HostPlatform hostPlatform,
      required String profileDigest, required bool Function() operationIsCurrent,
      required Duration remainingBudget, required Future<void> cancelled}) async =>
      throw const BootstrapFailure('Synthetic control transport unavailable', operationalCode: 'API-002');
  @override
  Future<void> reportRuntimeStats({required HostPlatform hostPlatform, required String runtimePhase,
      required bool connected, String errorCode = '', String failureKind = '', String selectedNodeCode = '',
      String routeMode = '', int? durationMs, int? attemptNumber, bool? retryable, String networkClass = '',
      String carrierMccMnc = '', String carrierName = '', String candidateTransport = '', String candidateRef = '',
      String candidateVariant = '', String accessNetworkAsn = '', List<Map<String, Object?>> candidateProbes = const [],
      RuntimeSnapshot? connectivitySnapshot}) async {}
  @override
  Future<void> reportFirstSessionEvent({required HostPlatform hostPlatform, required String eventName,
      required String stage, required String result, String errorCode = '', bool? retryable}) async {}
  @override
  Future<void> completeAccountOnboarding({required HostPlatform hostPlatform}) async {}
}

class _LifecycleRuntime implements PokrovRuntimeEngine, RuntimeSmartAccessControl,
    RuntimeSmartAccessBackgroundControl, RuntimeCandidateProbing, RuntimeProtectedHandoff {
  RuntimePhase phase = RuntimePhase.artifactReady;
  ManagedProfilePayload? payload;
  String? digest;
  String? failure;
  String? stageError;
  final unsupported = <String>[];
  void fail(String kind, {required bool stopped}) {
    failure = kind;
    phase = stopped ? RuntimePhase.configStaged : RuntimePhase.running;
  }
  RuntimeSnapshot get value => RuntimeSnapshot(hostPlatform: HostPlatform.android,
    lane: RuntimeLane.mobileArtifact, phase: phase, artifactDirectory: null, coreBinaryPath: null,
    helperBinaryPath: null, stagedConfigPath: payload == null ? null : '/test/profile.json',
    supportsLiveConnect: true, canInitialize: phase == RuntimePhase.artifactReady, canConnect: payload != null,
    message: '', stagedProfileDigest: digest, effectiveProfileDigest: phase == RuntimePhase.running ? digest : null,
    coreVersion: '1.2.7', routingCatalogWindowVersion: 1, routingCatalogControlVersion: 4,
    smartAccessLeaseVersion: 1, smartAccessRuntimeControlVersion: 1,
    lastFailureKind: failure, coreEgressValidationRequired: true,
    coreEgressValidated: phase == RuntimePhase.running && failure == null,
    hostHealth: phase == RuntimePhase.running ? RuntimeHostHealth.healthy : RuntimeHostHealth.unknown,
    dnsState: RuntimeDiagnosticState.healthy, uplinkState: RuntimeDiagnosticState.healthy,
    dnsReady: phase == RuntimePhase.running);
  @override
  Future<RuntimeSnapshot> snapshot() async => value;
  @override
  Future<RuntimeSnapshot> initialize() async { phase = RuntimePhase.initialized; return value; }
  @override
  Future<RuntimeSnapshot> invalidateManagedProfile() async => value;
  @override
  Future<RuntimeSnapshot> stageSmartAccessProfile(ManagedProfilePayload next,
      {required Future<String> Function(String, RuntimeSnapshot) persistRestrictions,
      required bool Function() operationIsCurrent}) async {
    try {
      digest = await persistRestrictions(next.configPayload, value);
    } on RoutingCatalogFailure catch (error) {
      stageError = error.code;
      rethrow;
    }
    expect(operationIsCurrent(), isTrue);
    payload = next; failure = null; phase = RuntimePhase.configStaged;
    return value;
  }
  @override
  Future<RuntimeSnapshot> replaceManagedProfile(ManagedProfilePayload next,
      {required bool Function() operationIsCurrent,
      Future<String> Function(String, RuntimeSnapshot)? persistRestrictions}) async {
    await stageSmartAccessProfile(next, persistRestrictions: persistRestrictions!, operationIsCurrent: operationIsCurrent);
    phase = RuntimePhase.running; return value;
  }
  @override
  Future<RuntimeSnapshot> connect() async { failure = null; phase = RuntimePhase.running; return value; }
  @override
  Future<RuntimeSnapshot> disconnect() async { failure = null; phase = RuntimePhase.configStaged; return value; }
  @override
  Future<String> readSmartAccessRestrictions() async => jsonEncode({'schema': 1,
    'snapshot_sha256': await smartAccessProfileSha256('[]'), 'entries': []});
  @override
  Future<bool> acknowledgeSmartAccessRestrictions(String snapshotSha256) async => true;
  @override
  Future<RuntimeSmartAccessLeaseState> readSmartAccessLeases(String profileDigest) async =>
    RuntimeSmartAccessLeaseState(profileDigest: profileDigest, leaseIds: const {}, selections: const {});
  @override
  Future<RuntimeCandidateNetwork> readCandidateNetwork() async => RuntimeCandidateNetwork(
    selectionKey: 'synthetic-network', contextRef: 'synthetic-context', networkClass: 'wifi');
  @override
  dynamic noSuchMethod(Invocation invocation) {
    unsupported.add(invocation.memberName.toString());
    return super.noSuchMethod(invocation);
  }
}

class _ExperienceStore implements PokrovClientExperienceStore {
  PokrovClientExperienceState saved = const PokrovClientExperienceState.empty();
  @override
  Future<PokrovClientExperienceState> read() async => const PokrovClientExperienceState.empty();
  @override
  Future<void> write(PokrovClientExperienceState state) async { saved = state; }
}

class _FirstLaunchStore implements PokrovFirstLaunchStore {
  @override
  Future<bool> isCompleted() async => true;
  @override
  Future<void> markCompleted() async {}
}
