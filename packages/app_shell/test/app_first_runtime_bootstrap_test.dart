import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_app_shell/client_routing_preferences.dart';
import 'package:pokrov_app_shell/src/features/rules/ru_app_catalog.dart';
import 'package:pokrov_app_shell/routing_catalog_contract.dart';
import 'package:pokrov_app_shell/src/shell/managed_profile_cache.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

const _ruDomainWhitelistRuleSetTag = 'pokrov-ru-domain-whitelist';
const _ruDomainCategoryRuleSetTag = 'pokrov-ru-domain-category';
const _ruIpCountryRuleSetTag = 'pokrov-ru-ip-country';
const _ruIpWhitelistRuleSetTag = 'pokrov-ru-ip-whitelist';
const _validClientUpdateSha256 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Future<String> _readBootstrapFixture(String name) async {
  for (final path in <String>[
    'packages/app_shell/test/fixtures/$name',
    'test/fixtures/$name',
  ]) {
    final file = File(path);
    if (await file.exists()) {
      return file.readAsString();
    }
  }
  throw FileSystemException('Fixture not found', name);
}

Map<String, Object?> _readyManagedProfile(String revision,
    {bool pending = false}) {
  return <String, Object?>{
    'provisioning': <String, Object?>{
      'status': pending ? 'pending_sync' : 'ready',
      'sync_ok': !pending,
    },
    'profile_revision': revision,
    'config_format': 'singbox-json',
    'config_payload': <String, Object?>{
      'outbounds': <Object?>[
        <String, Object?>{'type': 'selector', 'tag': 'proxy'},
      ],
      'route': <String, Object?>{'final': 'proxy'},
    },
  };
}

ClientAppUpdateInfo _clientUpdateInfo({
  String url =
      'https://github.com/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov-android-arm64-v8a.apk',
  String sha256 = _validClientUpdateSha256,
  int size = 123456,
  String latestVersion = '1.0.1-beta',
  String updatePolicy = 'recommended',
}) {
  return ClientAppUpdateInfo(
    platform: 'android',
    channel: 'beta',
    latestVersion: latestVersion,
    minSupportedVersion: '1.0.0-beta',
    updatePolicy: updatePolicy,
    url: url,
    sha256: sha256,
    size: size,
    releaseNotes: 'Small beta fixes.',
    releaseNotesUrl: '',
    publishedAt: '2026-06-07T00:00:00Z',
  );
}

String _expectedRuleSetCachePath(Directory tempDirectory, String fileName) {
  return '${tempDirectory.path}${Platform.pathSeparator}'
      'pokrov-runtime${Platform.pathSeparator}'
      'data${Platform.pathSeparator}'
      'rule-set${Platform.pathSeparator}'
      'all-except-ru-rule-sets${Platform.pathSeparator}'
      '$fileName';
}

Map<String, List<int>> _allExceptRuRuleSetFixtures() {
  return <String, List<int>>{
    _ruDomainWhitelistRuleSetTag: utf8.encode('pokrov ru domain whitelist'),
    _ruDomainCategoryRuleSetTag: utf8.encode('pokrov ru domain category'),
    _ruIpCountryRuleSetTag: utf8.encode('pokrov ru ip country'),
    _ruIpWhitelistRuleSetTag: utf8.encode('pokrov ru ip whitelist'),
  };
}

Map<String, Object?> _supportTicketJson({
  required int id,
  required List<Object?> messages,
  String status = 'open',
  String statusTitle = 'Open',
}) {
  return <String, Object?>{
    'id': id,
    'user_tg_id': 10001,
    'status': status,
    'status_title': statusTitle,
    'subject': 'Support',
    'created_at': '2026-06-03T00:00:00Z',
    'updated_at': '2026-06-03T00:01:00Z',
    'messages': messages,
    'last_message_preview': messages.isEmpty
        ? ''
        : ((messages.last as Map<String, Object?>)['body'] ?? '').toString(),
  };
}

Map<String, Object?> _supportMessageJson({
  required int id,
  required int ticketId,
  required String senderRole,
  required String body,
  String? mediaType,
  String? mediaPayload,
}) {
  return <String, Object?>{
    'id': id,
    'ticket_id': ticketId,
    'sender_tg_id': senderRole == 'user' ? 10001 : 90001,
    'sender_role': senderRole,
    'body': body,
    if (mediaType != null) 'media_type': mediaType,
    if (mediaPayload != null) 'media_payload': mediaPayload,
    'created_at': '2026-06-03T00:00:00Z',
  };
}

class _FailingFlutterSecureStorage extends FlutterSecureStorage {
  const _FailingFlutterSecureStorage({
    this.failRead = false,
    this.failWrite = false,
    this.failDelete = false,
  });

  final bool failRead;
  final bool failWrite;
  final bool failDelete;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failRead) {
      throw PlatformException(code: 'secure-store-read-unavailable');
    }
    return super.read(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrite) {
      throw PlatformException(code: 'secure-store-write-unavailable');
    }
    await super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failDelete) {
      throw PlatformException(code: 'secure-store-delete-unavailable');
    }
    await super.delete(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}

void main() {
  final defaultSecureStoragePlatform = FlutterSecureStoragePlatform.instance;
  setUp(() {
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(<String, String>{});
  });
  tearDown(() {
    FlutterSecureStoragePlatform.instance = defaultSecureStoragePlatform;
  });

  test('managed catalog preserves SmartConnect probes and resolves the exact winning candidate', () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-candidate-catalog-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final queries = <Map<String, String>>[];
    final probes = <String>[];
    var returnWrongSelection = false;
    var returnWrongKind = false;
    var returnWrongXhttpProtection = false;
    var returnXhttpBridge = false;
    var returnUnauthorized = false;
    var returnBundle = false;
    var alternateMaterialRef = 'ru:grpc_443_primary';
    var slowSelectedRefresh = false;
    Completer<void>? managedRequested;
    Completer<void>? releaseManaged;
    Map<String, Object?> descriptor(String node, String profile, String transport) => {
      'candidate_ref': '$node:$profile', 'profile_ref': profile, 'node_code': node,
      'country_code': node.split('-').first.toUpperCase(), 'protocol': 'vless', 'transport': transport,
      'protection': transport == 'grpc' ? 'tls' : 'reality', 'priority': 0,
      'parameters': {'network': 'tcp', 'flow': transport == 'tcp' ? 'xtls-rprx-vision' : ''},
      'requirements': {'minimum_client_release': '1.2.0', 'minimum_core_release': null,
        'platforms': ['windows'], 'required_features': [
          'singbox_vless_v1',
          if (transport == 'xhttp') ...['singbox_xhttp_v1', 'singbox_tls_v1', 'singbox_utls_v1', 'singbox_reality_v1']
          else transport == 'tcp' ? 'singbox_reality_v1' : 'singbox_grpc_v1']},
    };
    Map<String, Object?> grpcMaterial(String node) => {
      'outbounds': [
        {'type': 'selector', 'tag': 'proxy', 'outbounds': [node], 'default': node},
        {'type': 'vless', 'tag': node, 'server': '$node.example.test', 'server_port': 443,
          'transport': {'type': 'grpc', 'service_name': 'test'}},
      ],
      'route': {'final': 'proxy'},
    };
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response.write(jsonEncode({
            'session': {'session_token': 'catalog-test-session', 'account_id': 'catalog-test'},
            'provisioning': {'status': 'ready', 'sync_ok': true},
          }));
        } else if (request.uri.path == '/api/client/profile/managed') {
          final query = request.uri.queryParameters;
          queries.add(query);
          managedRequested?.complete();
          if (releaseManaged != null) await releaseManaged.future;
          if (slowSelectedRefresh && query['selected_candidate_ref'] == 'de:grpc_443_primary') {
            await Future<void>.delayed(const Duration(seconds: 7));
          }
          if (returnUnauthorized) {
            request.response.statusCode = HttpStatus.unauthorized;
            request.response.write('{"detail":"session ended"}');
            await request.response.close();
            continue;
          }
          if (query['selected_candidate_ref'] == 'warp:warp_free:warp_direct') {
            request.response.write(jsonEncode({
              ..._readyManagedProfile('catalog-rev'),
              'transport_profile': 'warp_free', 'transport_kind': 'warp_direct',
              'transport_catalog': {
                'schema_version': 'pokrov-transport-catalog-v1', 'revision': 'catalog-rev',
                'selected_candidate_ref': 'warp:warp_free:warp_direct', 'candidates': [{
                  'candidate_ref': 'warp:warp_free:warp_direct', 'profile_ref': 'warp_free',
                  'node_code': '', 'country_code': 'ZZ', 'protocol': 'warp', 'transport': 'udp',
                  'protection': 'warp', 'warp_mode': 'warp_direct', 'priority': 0,
                  'parameters': {'network': 'udp', 'flow': ''},
                  'requirements': {'minimum_client_release': '1.5.0+4099', 'minimum_core_release': '1.2.8',
                    'platforms': ['windows'], 'required_features': []},
                }],
              },
              'config_payload': {
                'outbounds': [
                  {'type': 'selector', 'tag': 'proxy', 'outbounds': ['block'], 'default': 'block'},
                  {'type': 'direct', 'tag': 'direct'}, {'type': 'block', 'tag': 'block'},
                ],
                'route': {'final': 'proxy'},
              },
            }));
            await request.response.close();
            continue;
          }
          final chosen = !returnWrongSelection && query['selected_candidate_ref'] == 'de:grpc_443_primary';
          final sibling = query['selected_candidate_ref'] == 'ru-spb:grpc_443_primary';
          final xhttp = query['selected_candidate_ref'] == 'de:xhttp_reality';
          final grpc = chosen || sibling;
          final node = sibling ? 'ru-spb' : chosen || xhttp ? 'de' : 'pl';
          final profile = xhttp ? 'xhttp_reality' : grpc ? 'grpc_443_primary' : 'legacy_reality_fallback';
          request.response.write(jsonEncode({
            ..._readyManagedProfile('catalog-rev'),
            'transport_profile': profile,
            'transport_kind': xhttp ? 'xhttp' : grpc ? (returnWrongKind ? 'xhttp' : 'grpc') : 'reality',
            'transport_catalog': {
              'schema_version': 'pokrov-transport-catalog-v1', 'revision': 'catalog-rev',
              'selected_candidate_ref': '$node:$profile', 'candidates': [
                descriptor('pl', 'legacy_reality_fallback', 'tcp'),
                descriptor('de', 'grpc_443_primary', 'grpc'),
                descriptor('de', 'xhttp_reality', 'xhttp'),
                if (sibling) descriptor('ru-spb', 'grpc_443_primary', 'grpc'),
                if (returnBundle) descriptor('ru', 'grpc_443_primary', 'grpc'),
              ],
            },
            'smart_connect': {
              'eligible': true, 'fallback_required': false, 'shortlist_revision': 'catalog-shortlist',
              'profile_revision': 'catalog-rev', 'transport_profile': profile, 'shortlist_limit': 3,
              'shortlist': [for (final code in ['pl', 'de', 'it']) {
                'code': code, 'country': code, 'rank': 1, 'rank_hint': {'health_score': 100},
                'outbound_tag': code,
              }],
              'stickiness': {'preferred_node_code': 'pl', 'threshold_percent': 15},
            },
            'config_payload': {
              'outbounds': [
                {'type': 'selector', 'tag': 'proxy', 'outbounds': [
                  if (xhttp && returnXhttpBridge) 'country-auto' else node,
                ], 'default': xhttp && returnXhttpBridge ? 'country-auto' : node},
                if (xhttp && returnXhttpBridge) ...[
                  {'type': 'urltest', 'tag': 'country-auto', 'outbounds': [node, 'bridge'],
                    'url': 'https://probe.example.test'},
                  {'type': 'vless', 'tag': 'bridge', 'server': '$node.example.test',
                    'server_port': 443, 'detour': 'ingress',
                    'transport': {'type': 'xhttp', 'mode': 'stream-one', 'path': '/test'},
                    'tls': {'enabled': true, 'alpn': ['h2'], 'utls': {'enabled': true},
                      'reality': {'enabled': true, 'public_key': 'synthetic-public-key'}}},
                  {'type': 'vless', 'tag': 'ingress', 'server': 'ingress.example.test',
                    'server_port': 443, 'tls': {'enabled': true, 'utls': {'enabled': true},
                      'reality': {'enabled': true, 'public_key': 'synthetic-ingress-key'}}},
                ],
                {'type': 'vless', 'tag': node, 'server': '$node.example.test', 'server_port': 443,
                  if (grpc) 'transport': {'type': 'grpc', 'service_name': 'test'},
                  if (xhttp) ...{
                    'transport': {'type': 'xhttp', 'mode': 'stream-one', 'path': '/test'},
                    'tls': {'enabled': true, 'alpn': ['h2'],
                      'utls': {'enabled': true, 'fingerprint': 'chrome'},
                      if (!returnWrongXhttpProtection) 'reality': {'enabled': true,
                        'public_key': 'synthetic-public-key', 'short_id': ''}},
                  }},
              ],
              'route': {'final': 'proxy'},
            },
            if (returnBundle) 'candidate_materials': [
              {'candidate_ref': '$node:$profile', 'transport_kind': 'grpc',
                'config_format': 'singbox-json', 'config_payload': grpcMaterial(node)},
              {'candidate_ref': alternateMaterialRef, 'transport_kind': 'grpc',
                'config_format': 'singbox-json', 'config_payload': grpcMaterial('ru')},
            ],
          }));
        } else if (request.uri.path == '/api/client/nodes/select') {
          request.response.write('{"selected_node_code":"de"}');
        } else {
          request.response.write('{"ok":true}');
        }
        await request.response.close();
      }
    }());
    final sessionSecrets = MemoryAppFirstSessionSecretStore();
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/', supportDirectoryResolver: () async => directory,
      sessionSecretStore: sessionSecrets, maxRequestAttempts: 1,
      smartConnectLatencyProbe: (node) async {
        probes.add(node.code);
        return node.code == 'pl' ? 500 : 20;
      },
    );
    final payload = await bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, runtimeFeatures: RuntimeTransportFeature.values.toSet());
    expect(probes, ['pl', 'de'], reason: 'nodes outside the candidate catalog are not probed');
    expect(queries, hasLength(2));
    expect(queries.first['catalog_version'], '1');
    expect(queries.first.containsKey('core_release'), isFalse);
    expect(queries.last['selected_candidate_ref'], 'de:grpc_443_primary');
    expect(queries.last['selected_node_code'], 'de');
    expect(payload.transportCatalog?.selectedCandidateRef, 'de:grpc_443_primary');
    expect(payload.resolvedNodeCode, 'de');
    final config = jsonDecode(payload.configPayload) as Map;
    final selected = (config['outbounds'] as List).where((item) => item['tag'] == 'de').single;
    expect(selected['transport']['type'], 'grpc', reason: 'winner comes from secure server profile');
    expect((config['outbounds'] as List).where((item) => item['tag'] == 'pl'), isEmpty);

    final direct = await bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, runtimeFeatures: RuntimeTransportFeature.values.toSet(),
      coreRelease: '1.2.9', selectedCandidateRef: 'warp:warp_free:warp_direct',
      preferredCountryCode: 'DE', selectCandidate: false, cacheResult: false);
    expect(queries.last.containsKey('selected_node_code'), isFalse);
    expect(direct.resolvedNodeCode, isEmpty);
    expect(direct.warpPolicy.mode, 'warp_direct');
    expect(direct.warpPolicy.id, startsWith('warp-direct:'));
    expect(direct.warpPolicy.id, isNot('warp-direct:'));
    expect(direct.warpPolicy.hasServerManagedMaterial, isFalse);
    final directConfig = jsonDecode(direct.configPayload) as Map;
    expect((directConfig['outbounds'] as List).where((item) => item['type'] == 'vless'), isEmpty);
    expect((directConfig['outbounds'] as List).where((item) => item['type'] == 'selector').single['outbounds'], ['block']);
    expect(queries.last['client_release'], '$pokrovClientVersion+$pokrovClientBuildNumber');
    const profileStorage = FlutterSecureStorage();
    const profileCacheKey = 'pokrov-managed-profile-windows-v1';
    final previousCache = await profileStorage.read(key: profileCacheKey);
    const directInputs = ManagedProfileCacheInputs(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, preferredCountryCode: 'DE');
    await bootstrapper.cacheResolvedManagedProfile(directInputs, direct);
    final cachedDirect = await bootstrapper.loadCachedManagedProfile(directInputs,
      runtimeFeatures: RuntimeTransportFeature.values.toSet(), coreRelease: '1.2.9');
    expect(cachedDirect?.warpPolicy.mode, 'warp_direct');
    expect(cachedDirect?.warpPolicy.id, direct.warpPolicy.id);
    expect(cachedDirect?.warpPolicy.hasServerManagedMaterial, isFalse);
    await profileStorage.write(key: profileCacheKey, value: previousCache);

    final xhttp = await bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, runtimeFeatures: RuntimeTransportFeature.values.toSet(),
      selectedCandidateRef: 'de:xhttp_reality', selectCandidate: false, cacheResult: false);
    expect(xhttp.transportCatalog?.selected.protection, 'reality');
    final xhttpLeaf = ((jsonDecode(xhttp.configPayload) as Map)['outbounds'] as List)
        .where((item) => item['tag'] == 'de').single;
    expect(xhttpLeaf['transport'], {'type': 'xhttp', 'mode': 'stream-one', 'path': '/test'});
    expect(xhttpLeaf['tls']['reality']['enabled'], isTrue);
    returnXhttpBridge = true;
    final countryAuto = await bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, runtimeFeatures: RuntimeTransportFeature.values.toSet(),
      selectedCandidateRef: 'de:xhttp_reality', selectCandidate: false, cacheResult: false);
    final autoOutbounds = (jsonDecode(countryAuto.configPayload) as Map)['outbounds'] as List;
    expect(autoOutbounds.where((item) => item['tag'] == 'country-auto').single['outbounds'],
      ['de', 'bridge']);
    expect(autoOutbounds.where((item) => item['tag'] == 'bridge').single['detour'], 'ingress');
    expect(autoOutbounds.where((item) => item['tag'] == 'proxy').single['default'], 'country-auto');
    returnXhttpBridge = false;
    returnWrongXhttpProtection = true;
    await expectLater(bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, runtimeFeatures: RuntimeTransportFeature.values.toSet(),
      selectedCandidateRef: 'de:xhttp_reality', selectCandidate: false, cacheResult: false),
      throwsA(isA<TransportManifestFailure>()
        .having((failure) => failure.code, 'code', 'transport_catalog_profile_mismatch')));
    returnWrongXhttpProtection = false;

    const inputs = ManagedProfileCacheInputs(hostPlatform: HostPlatform.windows, routeMode: RouteMode.fullTunnel);
    final restored = await bootstrapper.loadCachedManagedProfile(inputs,
      runtimeFeatures: RuntimeTransportFeature.values.toSet());
    expect(restored?.transportCatalog?.selectedCandidateRef, 'de:grpc_443_primary');
    expect(payload.disableMemoryLimit, isTrue);
    expect(restored?.disableMemoryLimit, isTrue);
    expect(restored?.configPayload, payload.configPayload);
    expect(await bootstrapper.loadCachedManagedProfile(inputs, runtimeFeatures: const {}), isNull);
    final missingMaterial = restored!.transportCatalog!.candidates.singleWhere(
        (candidate) => candidate.candidateRef == 'de:xhttp_reality');
    expect(await bootstrapper.loadCachedManagedProfile(inputs,
        selectedCandidateRef: missingMaterial.candidateRef,
        runtimeFeatures: RuntimeTransportFeature.values.toSet()), isNull);
    final blockedOrigins = <String>{};
    final offline = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      apiFallbackBaseUrls: ['http://localhost:${server.port}/'],
      supportDirectoryResolver: () async => directory,
      sessionSecretStore: sessionSecrets, maxRequestAttempts: 1,
      httpClientFactory: () => HttpClient()..connectionFactory = (uri, _, __) async {
        blockedOrigins.add(uri.authority);
        throw const SocketException('synthetic socket denial',
            osError: OSError('network access denied', 10013));
      },
    );
    var materialSettled = Completer<void>();
    Future<void> prepare(TransportCandidate candidate, Future<void> cancelled) async {
      if (candidate.candidateRef == missingMaterial.candidateRef) {
        try {
          await offline.resolveManagedProfile(hostPlatform: inputs.hostPlatform, routeMode: inputs.routeMode,
              selectedCandidateRef: candidate.candidateRef, selectCandidate: false, cacheResult: false,
              runtimeFeatures: RuntimeTransportFeature.values.toSet(), cancelled: cancelled);
        } finally {
          materialSettled.complete();
        }
      } else {
        await materialSettled.future;
        await Future<void>.delayed(Duration.zero);
      }
    }
    final nativeProbes = <String>[];
    Future<SmartConnectCandidateProbeResult> probe(TransportCandidate candidate,
        Future<void> cancelled, Duration timeout) async {
      nativeProbes.add(candidate.candidateRef);
      return SmartConnectCandidateProbeResult.success(restored);
    }
    final selector = SmartConnectCandidateSelector();
    await expectLater(selector.select(
      catalog: restored.transportCatalog!,
      excludedCandidateRefs: restored.transportCatalog!.candidates
          .where((candidate) => candidate.candidateRef != missingMaterial.candidateRef)
          .map((candidate) => candidate.candidateRef).toSet(),
      network: 'catalog-network', platform: inputs.hostPlatform, cancelled: Completer<void>().future,
      prepare: prepare, probe: probe,
    ), throwsA(isA<BootstrapFailure>()
        .having((error) => error.operationalErrorCode, 'code', 'API-002')
        .having((error) => error.apiFailureKind, 'kind', 'origin_socket')
        .having((error) => error.osErrorCode, 'OS error', 10013)
        .having((error) => error.statusCode, 'HTTP status', isNull)));
    expect(blockedOrigins, containsAll(['127.0.0.1:${server.port}', 'localhost:${server.port}']));
    expect(nativeProbes, isEmpty);
    materialSettled = Completer<void>();
    expect(await selector.select(
      catalog: restored.transportCatalog!,
      excludedCandidateRefs: restored.transportCatalog!.candidates
          .where((candidate) => candidate.candidateRef != missingMaterial.candidateRef &&
              candidate.candidateRef != restored.materialCandidate!.candidateRef)
          .map((candidate) => candidate.candidateRef).toSet(),
      network: 'catalog-network', platform: inputs.hostPlatform, cancelled: Completer<void>().future,
      prepare: prepare, probe: probe,
    ), same(restored), reason: 'an API failure cannot cancel another usable material');
    expect(nativeProbes, [restored.materialCandidate!.candidateRef]);
    probes.clear();
    final discovery = await bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, runtimeFeatures: RuntimeTransportFeature.values.toSet(),
      selectCandidate: false, cacheResult: false);
    expect(probes, isEmpty);
    expect(discovery.transportCatalog?.selectedCandidateRef, 'pl:legacy_reality_fallback');
    expect((await bootstrapper.loadCachedManagedProfile(inputs))?.cacheEntryId, payload.cacheEntryId,
      reason: 'discovery and losing probes do not replace the saved winner');
    final cancellation = Completer<void>()..complete();
    await expectLater(bootstrapper.cacheResolvedManagedProfile(inputs, discovery,
      cancelled: cancellation.future), throwsA(isA<Exception>()));
    expect((await bootstrapper.loadCachedManagedProfile(inputs))?.cacheEntryId, payload.cacheEntryId);
    await bootstrapper.cacheResolvedManagedProfile(inputs, discovery);
    expect((await bootstrapper.loadCachedManagedProfile(inputs))?.cacheEntryId, discovery.cacheEntryId);

    const countryInputs = ManagedProfileCacheInputs(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, preferredCountryCode: 'RU');
    final sibling = await bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, preferredCountryCode: 'RU',
      runtimeFeatures: RuntimeTransportFeature.values.toSet(),
      selectedCandidateRef: 'ru-spb:grpc_443_primary', selectCandidate: false, cacheResult: false);
    expect(queries.last['selected_node_code'], 'ru-spb');
    expect(queries.last['selected_country_code'], 'RU');
    expect(sibling.transportCatalog?.selected.nodeCode, 'ru-spb');
    await bootstrapper.cacheResolvedManagedProfile(countryInputs, sibling);
    expect((await bootstrapper.loadCachedManagedProfile(countryInputs))?.cacheEntryId, sibling.cacheEntryId);
    expect(await bootstrapper.loadCachedManagedProfile(const ManagedProfileCacheInputs(
      hostPlatform: HostPlatform.windows, routeMode: RouteMode.fullTunnel, preferredNodeCode: 'ru-spb')), isNull,
      reason: 'exact egress does not rewrite the user country preference binding');

    returnBundle = true;
    final beforeBundle = queries.length;
    final bundle = await bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, preferredCountryCode: 'RU',
      runtimeFeatures: RuntimeTransportFeature.values.toSet(),
      selectedCandidateRef: 'ru-spb:grpc_443_primary', selectCandidate: false);
    expect(queries.length, beforeBundle + 1, reason: 'discovery and reserve caching share one HTTP response');
    expect(queries.last['candidate_material_limit'], '6');
    expect(bundle.candidateMaterials.keys, ['ru-spb:grpc_443_primary', 'ru:grpc_443_primary']);
    expect(() => bundle.candidateMaterials.clear(), throwsUnsupportedError);
    final alternate = bundle.candidateMaterials['ru:grpc_443_primary']!;
    expect(alternate.source?.revision, bundle.source?.revision);
    expect(alternate.materialCandidate?.nodeCode, 'ru');
    final cachedAlternate = await bootstrapper.loadCachedManagedProfile(countryInputs,
        selectedCandidateRef: 'ru:grpc_443_primary');
    expect(cachedAlternate?.materialCandidateRef, 'ru:grpc_443_primary');
    expect(cachedAlternate?.transportCatalog?.selectedCandidateRef, 'ru-spb:grpc_443_primary');
    expect(cachedAlternate?.configPayload, alternate.configPayload);
    await bootstrapper.markManagedProfileProven(countryInputs, cachedAlternate!.cacheEntryId,
        networkSelectionKey: 'network-bundle');
    expect(await bootstrapper.successfulCandidateRef(countryInputs, 'network-bundle'), 'ru:grpc_443_primary');
    for (final rejectedRef in ['pl:legacy_reality_fallback', 'ru:unadmitted']) {
      alternateMaterialRef = rejectedRef;
      await expectLater(bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel, preferredCountryCode: 'RU',
        runtimeFeatures: RuntimeTransportFeature.values.toSet(),
        selectedCandidateRef: 'ru-spb:grpc_443_primary', selectCandidate: false, cacheResult: false),
        throwsA(isA<TransportManifestFailure>()
          .having((failure) => failure.code, 'code', 'transport_catalog_materials_mismatch')));
    }
    returnBundle = false;
    await expectLater(bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, preferredCountryCode: 'RU',
      runtimeFeatures: RuntimeTransportFeature.values.toSet(),
      selectedCandidateRef: 'de:grpc_443_primary', selectCandidate: false, cacheResult: false),
      throwsA(isA<TransportManifestFailure>()
        .having((failure) => failure.code, 'code', 'transport_catalog_selection_mismatch')));

    slowSelectedRefresh = true;
    final timedOutAuto = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows, routeMode: RouteMode.selectedApps,
      selectedApps: const ['Discord.exe'],
      runtimeFeatures: RuntimeTransportFeature.values.toSet());
    slowSelectedRefresh = false;
    expect(queries.last['selected_candidate_ref'], 'de:grpc_443_primary');
    expect(timedOutAuto.transportCatalog?.selectedCandidateRef,
      'pl:legacy_reality_fallback',
      reason: 'a slow advisory refetch must keep the first authorized profile usable');

    returnWrongKind = true;
    await expectLater(bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, runtimeFeatures: RuntimeTransportFeature.values.toSet()),
      throwsA(isA<TransportManifestFailure>()
        .having((failure) => failure.code, 'code', 'transport_catalog_profile_mismatch')));

    returnWrongKind = false;
    returnWrongSelection = true;
    await expectLater(bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, runtimeFeatures: RuntimeTransportFeature.values.toSet()),
      throwsA(isA<TransportManifestFailure>()
        .having((failure) => failure.code, 'code', 'transport_catalog_selection_mismatch')));

    managedRequested = Completer<void>();
    releaseManaged = Completer<void>();
    final late = bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, runtimeFeatures: RuntimeTransportFeature.values.toSet(),
      selectCandidate: false, cacheResult: false);
    await managedRequested.future;
    final sessionFile = File('${directory.path}/app-first-session-windows.json');
    final changedAccount = jsonDecode(await sessionFile.readAsString()) as Map<String, dynamic>;
    changedAccount['account_id'] = 'new-account';
    await sessionFile.writeAsString(jsonEncode(changedAccount));
    final superseded = throwsA(isA<BootstrapFailure>()
      .having((error) => error.code, 'code', 'managed_profile_superseded'));
    final rejected = expectLater(late, superseded);
    releaseManaged.complete();
    await rejected;
    await expectLater(bootstrapper.cacheResolvedManagedProfile(inputs, discovery), superseded);
    await expectLater(bootstrapper.cacheResolvedManagedProfile(inputs, discovery, candidateOnly: true), superseded);
    await expectLater(bootstrapper.cacheResolvedManagedProfile(countryInputs, alternate, candidateOnly: true), superseded);
    expect((jsonDecode(await sessionFile.readAsString()) as Map)['account_id'], 'new-account');

    managedRequested = Completer<void>();
    releaseManaged = Completer<void>();
    returnUnauthorized = true;
    final lateDenial = bootstrapper.resolveManagedProfile(hostPlatform: inputs.hostPlatform,
        routeMode: inputs.routeMode, selectCandidate: false, cacheResult: false);
    await managedRequested.future;
    changedAccount['account_id'] = 'current-account';
    await sessionFile.writeAsString(jsonEncode(changedAccount));
    final currentCache = ManagedProfileCache();
    final currentBinding = inputs.binding('current-account', changedAccount['install_id'] as String);
    await currentCache.saveDownloaded(platform: 'windows', binding: currentBinding,
        revision: 'current-revision', verifiedAt: DateTime.now().toUtc(),
        payload: {'cache_entry_id': 'current-profile', 'access': {'expiry_at': null}});
    final deniedOldOwner = expectLater(lateDenial, superseded);
    releaseManaged.complete();
    await deniedOldOwner;
    expect((await currentCache.read(platform: 'windows', binding: currentBinding))?['cache_entry_id'], 'current-profile',
        reason: 'an old account response cannot clear the current account cache');
  });

  test('managed TUN MTU rejects missing malformed and unsafe values', () {
    expect(selectSafeTunMtu(null), 1280);
    expect(selectSafeTunMtu('1400'), 1280);
    expect(selectSafeTunMtu(1400.0), 1280);
    expect(selectSafeTunMtu(1279), 1280);
    expect(selectSafeTunMtu(1501), 1280);
    expect(selectSafeTunMtu(9000), 1280);
    expect(selectSafeTunMtu(1280), 1280);
    expect(selectSafeTunMtu(1400), 1400);
    expect(selectSafeTunMtu(1492), 1492);
    expect(selectSafeTunMtu(1500), 1500);
  });

  test('protected managed cache restores exact profile after restart and respects server denial', () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-managed-cache-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    var revision = 'a';
    var denied = false;
    var subscriptionDenied = false;
    var stall = false;
    var accessTokenExpired = false;
    var delayRenewedProfile = false;
    var sessionRefreshes = 0;
    DateTime? now;
    final expiry = DateTime.now().toUtc().add(const Duration(days: 2));
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response.write(jsonEncode({
            'session': {'access_token': 'cache-fixture-token', 'refresh_token': 'cache-fixture-refresh', 'account_id': 'cache-account'},
            'provisioning': {'status': 'ready', 'sync_ok': true},
          }));
        } else if (denied) {
          request.response.statusCode = 403;
          request.response.write('{"detail":"access denied"}');
        } else if (request.uri.path == '/api/client/session/refresh') {
          sessionRefreshes++;
          accessTokenExpired = false;
          request.response.write(jsonEncode({'session': {
            'access_token': 'renewed-fixture-token', 'refresh_token': 'renewed-fixture-refresh', 'account_id': 'cache-account',
          }}));
        } else if (request.uri.path == '/api/client/subscription') {
          request.response.write(jsonEncode({
            'lane': subscriptionDenied ? 'expiredOrBlocked' : 'paidUnlimited',
          }));
        } else if (request.uri.path == '/api/client/route-policy') {
          request.response.statusCode = accessTokenExpired ? 401 : 200;
          request.response.write(accessTokenExpired ? '{"detail":"session expired"}' : '{"ok":true}');
        } else if (request.uri.path == '/api/client/profile/managed') {
          if (stall) continue;
          if (delayRenewedProfile) {
            delayRenewedProfile = false;
            await Future<void>.delayed(const Duration(milliseconds: 3200));
          }
          request.response.write(jsonEncode({..._readyManagedProfile(revision),
            'access': {'expiry_at': expiry.toIso8601String(), 'access_state': 'paid_unlimited'},
          }));
        } else {
          request.response.statusCode = 404;
          request.response.write('{}');
        }
        await request.response.close();
      }
    }());
    AppFirstRuntimeBootstrapper create({bool offline = false}) => AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => directory,
      maxRequestAttempts: 2, delayScheduler: (_) async {},
      httpClientFactory: offline ? () => throw StateError('offline cache used HTTP') : null,
      managedProfileCache: ManagedProfileCache(now: () => now ?? DateTime.now().toUtc()),
    );
    const inputs = ManagedProfileCacheInputs(
      hostPlatform: HostPlatform.windows, routeMode: RouteMode.fullTunnel);
    final online = create();
    final a = await online.resolveManagedProfile(
      hostPlatform: inputs.hostPlatform, routeMode: inputs.routeMode,
      runtimeFeatures: RuntimeTransportFeature.values.toSet());
    expect(a.transportCatalog, isNull, reason: 'older managed API can omit the optional catalog');
    await online.markManagedProfileProven(inputs, a.cacheEntryId);
    revision = 'b';
    final b = await online.resolveManagedProfile(
      hostPlatform: inputs.hostPlatform, routeMode: inputs.routeMode);
    // Simulate a process restart with no available HTTP transport.
    final restarted = create(offline: true);
    final restored = await restarted.loadCachedManagedProfile(inputs);
    expect(restored?.configPayload, b.configPayload);
    expect(restored?.source?.revision, 'b');
    expect(restored?.cacheEntryId, b.cacheEntryId);
    final proven = await restarted.loadCachedManagedProfile(inputs, preferProven: true);
    expect(proven?.configPayload, a.configPayload);
    expect(proven?.source?.revision, 'a');
    expect(await restarted.loadCachedManagedProfile(const ManagedProfileCacheInputs(
      hostPlatform: HostPlatform.windows, routeMode: RouteMode.allExceptRu)), isNull);
    accessTokenExpired = true;
    delayRenewedProfile = true;
    revision = 'renewed';
    final renewed = await online.resolveManagedProfile(hostPlatform: inputs.hostPlatform,
        routeMode: inputs.routeMode, timeout: const Duration(seconds: 3));
    expect(renewed.source?.revision, 'renewed');
    expect(sessionRefreshes, 1);
    expect((await restarted.loadCachedManagedProfile(inputs))?.cacheEntryId, renewed.cacheEntryId,
        reason: 'authorized renewal stores fresh bytes, never resurrecting the denied cache');
    stall = true;
    await expectLater(online.resolveManagedProfile(
      hostPlatform: inputs.hostPlatform, routeMode: inputs.routeMode,
      timeout: const Duration(milliseconds: 100),
    ).timeout(const Duration(seconds: 2)), throwsA(isA<TimeoutException>()));
    expect((await restarted.loadCachedManagedProfile(inputs))?.cacheEntryId, renewed.cacheEntryId);
    stall = false;
    await online.fetchClientSubscription(hostPlatform: inputs.hostPlatform);
    expect(await restarted.loadCachedManagedProfile(inputs), isNotNull);
    subscriptionDenied = true;
    await online.fetchClientSubscription(hostPlatform: inputs.hostPlatform);
    expect(await restarted.loadCachedManagedProfile(inputs), isNull);
    subscriptionDenied = false;
    await online.resolveManagedProfile(
      hostPlatform: inputs.hostPlatform, routeMode: inputs.routeMode);
    denied = true;
    await expectLater(online.resolveManagedProfile(
      hostPlatform: inputs.hostPlatform, routeMode: inputs.routeMode),
      throwsA(isA<BootstrapFailure>().having((error) => error.statusCode, 'status', 403)));
    expect(sessionRefreshes, 1, reason: 'revoked access cannot start another auth retry');
    expect(await restarted.loadCachedManagedProfile(inputs), isNull);
    denied = false;
    await online.refreshCachedManagedProfile(inputs);
    now = expiry.add(const Duration(hours: 23));
    expect(await restarted.loadCachedManagedProfile(inputs), isNotNull,
      reason: 'local expiry during API outage keeps the following 24 hours');
    expect(await restarted.classifyManagedProfileFailure(inputs), ManagedProfileOfflineState.apiUnavailable);
    now = expiry.add(const Duration(hours: 24, seconds: 1));
    expect(await restarted.loadCachedManagedProfile(inputs), isNull);
    expect(await restarted.classifyManagedProfileFailure(inputs), ManagedProfileOfflineState.accessEnded);
    expect(await restarted.classifyManagedProfileFailure(inputs, networkAvailable: false),
      ManagedProfileOfflineState.noNetwork);
    expect(await restarted.classifyManagedProfileFailure(inputs, networkAvailable: true, captivePortal: true),
      ManagedProfileOfflineState.captivePortal);
  });

  test('automatic Android network context reports unknown origin through API and throttles duplicates', () async {
    final originalHttpOverrides = HttpOverrides.current;
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = originalHttpOverrides;
    final directory = await Directory.systemTemp.createTemp('pokrov-network-context-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final secrets = MemoryAppFirstSessionSecretStore();
    await secrets.writeSessionToken(hostPlatform: HostPlatform.android,
      installId: 'network-fixture-install', sessionToken: 'network-fixture-session');
    await File('${directory.path}/app-first-session-android.json').writeAsString(jsonEncode({
      'schema_version': 1, 'install_id': 'network-fixture-install',
      'account_id': 'network-fixture-account', 'profile_revision': 'network-revision',
      'managed_manifest_path': '/api/client/profile/managed',
    }));
    var nativeCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'runtimeEngine.observeNetworkContext') return null;
      nativeCalls++;
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args['sessionToken'], 'network-fixture-session');
      expect(args['profileRevision'], 'network-revision');
      return {'status': 'unavailable', 'network_class': 'cellular', 'carrier': 'Fixture carrier'};
    });
    final observed = Completer<Map<String, dynamic>>();
    final paths = <String>[];
    unawaited(() async {
      await for (final request in server) {
        paths.add(request.uri.path);
        final raw = await utf8.decoder.bind(request).join();
        expect(request.headers.value(HttpHeaders.authorizationHeader), 'Bearer network-fixture-session');
        if (request.uri.path == '/api/client/network/context') {
          observed.complete(jsonDecode(raw) as Map<String, dynamic>);
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"ok":true}');
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => directory, sessionSecretStore: secrets,
      maxRequestAttempts: 1,
    );
    await bootstrapper.reportRuntimeStats(hostPlatform: HostPlatform.android, runtimePhase: 'running', connected: true);
    final context = await observed.future.timeout(const Duration(seconds: 3));
    expect(context, {'network_class': 'cellular', 'carrier': 'Fixture carrier',
      'direct_observation': false, 'profile_revision': 'network-revision', 'runtime_phase': 'running'});
    await bootstrapper.reportRuntimeStats(hostPlatform: HostPlatform.android, runtimePhase: 'failed', connected: false);
    expect(nativeCalls, 1);
    expect(paths.where((path) => path == '/api/client/network/context').length, 1);
    expect(paths, isNot(contains('/api/client/session/start-trial')));
  });

  test('managed profile sends only observed cellular MCC-MNC carrier key', () async {
    final originalHttpOverrides = HttpOverrides.current;
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = originalHttpOverrides;
    final directory = await Directory.systemTemp.createTemp('pokrov-carrier-profile-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final secrets = MemoryAppFirstSessionSecretStore();
    await secrets.writeSessionToken(hostPlatform: HostPlatform.android,
        installId: 'carrier-install', sessionToken: 'carrier-session');
    await File('${directory.path}/app-first-session-android.json').writeAsString(jsonEncode({
      'schema_version': 1, 'install_id': 'carrier-install', 'account_id': 'carrier-account',
      'managed_manifest_path': '/api/client/profile/managed',
    }));
    messenger.setMockMethodCallHandler(channel, (call) async =>
        call.method == 'runtimeEngine.candidateNetwork'
            ? {'network_class': 'cellular', 'mcc_mnc': '25099'} : null);
    String? carrierHeader;
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/client/profile/managed') {
          carrierHeader = request.headers.value('X-Portal-Carrier');
          request.response.write(jsonEncode(_readyManagedProfile('carrier')));
        } else {
          request.response.write('{"ok":true}');
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => directory,
      sessionSecretStore: secrets,
    );
    await expectLater(
      bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.android,
          routeMode: RouteMode.fullTunnel),
      throwsA(isA<BootstrapFailure>()),
    );
    expect(carrierHeader, 'mcc_mnc:25099');
  });

  test('default API origin is owned and arbitrary fallbacks are rejected', () {
    expect(
      AppFirstRuntimeBootstrapper().apiBaseUrl,
      'https://app.pokrov.space/',
    );
    expect(
      () => AppFirstRuntimeBootstrapper(
        apiBaseUrl: 'https://app.pokrov.space/',
        apiFallbackBaseUrls: const <String>['https://example.invalid/'],
      ),
      throwsArgumentError,
    );
  });

  test('API preflight rejects HTML and sends one POST to the healthy fallback',
      () async {
    final primary = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fallback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-api-fallback-test-',
    );
    addTearDown(() async {
      await primary.close(force: true);
      await fallback.close(force: true);
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    var primaryHealthCount = 0;
    var primaryPostCount = 0;
    var fallbackHealthCount = 0;
    var fallbackPostCount = 0;
    unawaited(() async {
      await for (final request in primary) {
        if (request.method == 'GET' && request.uri.path == '/api/health') {
          primaryHealthCount += 1;
          request.response
            ..headers.contentType = ContentType.html
            ..write('<html>not the API</html>');
        } else {
          primaryPostCount += 1;
          request.response.statusCode = HttpStatus.internalServerError;
        }
        await request.response.close();
      }
    }());
    unawaited(() async {
      await for (final request in fallback) {
        if (request.method == 'GET' && request.uri.path == '/api/health') {
          fallbackHealthCount += 1;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'status': 'ok'}));
        } else if (request.method == 'POST' &&
            request.uri.path == '/api/client/device-pairing/claim') {
          fallbackPostCount += 1;
          await utf8.decoder.bind(request).join();
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'ok': true,
              'canonical_account_id': 'fallback-account',
              'session': <String, Object?>{
                'access_token': 'fallback-access-token',
                'refresh_token': 'fallback-refresh-token',
              },
            }));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${primary.port}/',
      apiFallbackBaseUrls: <String>[
        'http://127.0.0.1:${fallback.port}/',
      ],
      supportDirectoryResolver: () async => tempDirectory,
      maxRequestAttempts: 1,
    );
    final result = await bootstrapper.claimDevicePairingCode(
      hostPlatform: HostPlatform.android,
      code: 'ABCD1234',
    );

    expect(result.ok, isTrue);
    expect(result.accountId, 'fallback-account');
    expect(primaryHealthCount, 1);
    expect(primaryPostCount, 0);
    expect(fallbackHealthCount, 1);
    expect(fallbackPostCount, 1);
  });

  test('new profile discovery does not borrow the cancelled startup client', () async {
    final primary = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fallback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final directory = await Directory.systemTemp.createTemp('pokrov-owned-api-discovery-');
    final firstHealth = Completer<void>();
    final releaseHealth = Completer<void>();
    final nextClient = Completer<void>();
    final cancelled = Completer<void>();
    var clients = 0;
    addTearDown(() async {
      if (!releaseHealth.isCompleted) releaseHealth.complete();
      await primary.close(force: true);
      await fallback.close(force: true);
      await directory.delete(recursive: true);
    });
    primary.listen((request) async {
      if (!firstHealth.isCompleted) {
        firstHealth.complete();
        await releaseHealth.future;
      }
      request.response.headers.contentType = ContentType.html;
      request.response.write('<html>not the API</html>');
      await request.response.close();
    });
    fallback.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(request.uri.path == '/api/client/profile/managed'
          ? _readyManagedProfile('owned-client') : {'ok': true}));
      await request.response.close();
    });
    final secrets = MemoryAppFirstSessionSecretStore();
    await secrets.writeSessionToken(hostPlatform: HostPlatform.windows,
        installId: 'ownership-fixture', sessionToken: 'ownership-session');
    await File('${directory.path}/app-first-session-windows.json').writeAsString(jsonEncode({
      'schema_version': 1, 'install_id': 'ownership-fixture', 'account_id': 'ownership-account',
      'managed_manifest_path': '/api/client/profile/managed', 'session_token_storage': 'secure',
    }));
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${primary.port}/',
      apiFallbackBaseUrls: ['http://127.0.0.1:${fallback.port}/'],
      supportDirectoryResolver: () async => directory, sessionSecretStore: secrets,
      httpClientFactory: () {
        if (++clients == 2) nextClient.complete();
        return HttpClient();
      }, maxRequestAttempts: 1,
    );
    const inputs = ManagedProfileCacheInputs(hostPlatform: HostPlatform.windows, routeMode: RouteMode.fullTunnel);
    Object? startupFailure;
    final startup = bootstrapper.refreshCachedManagedProfile(inputs, cancelled: cancelled.future)
        .catchError((Object error) { startupFailure = error; });
    await firstHealth.future;
    final incoming = bootstrapper.resolveManagedProfile(hostPlatform: inputs.hostPlatform,
        routeMode: inputs.routeMode, timeout: const Duration(seconds: 2));
    final incomingReady = expectLater(incoming, completion(isA<ManagedProfilePayload>()));
    await nextClient.future;
    cancelled.complete();
    releaseHealth.complete();
    await incomingReady;
    await startup;
    expect(startupFailure.toString(), 'managed_profile_cancelled');
    expect((await bootstrapper.loadCachedManagedProfile(inputs))?.source?.revision, 'owned-client');
  });

  test('non-idempotent API request is not replayed after transport failure',
      () async {
    final primary = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fallback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-api-no-post-replay-test-',
    );
    addTearDown(() async {
      await primary.close(force: true);
      await fallback.close(force: true);
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    var primaryHealthCount = 0;
    var primaryPostCount = 0;
    var fallbackRequestCount = 0;
    unawaited(() async {
      await for (final request in primary) {
        if (request.method == 'GET' && request.uri.path == '/api/health') {
          primaryHealthCount += 1;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'status': 'ok'}));
          await request.response.close();
          continue;
        }
        primaryPostCount += 1;
        final socket = await request.response.detachSocket();
        socket.destroy();
      }
    }());
    unawaited(() async {
      await for (final request in fallback) {
        fallbackRequestCount += 1;
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, Object?>{'status': 'ok'}));
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${primary.port}/',
      apiFallbackBaseUrls: <String>[
        'http://127.0.0.1:${fallback.port}/',
      ],
      supportDirectoryResolver: () async => tempDirectory,
      maxRequestAttempts: 3,
    );

    await expectLater(
      bootstrapper.claimDevicePairingCode(
        hostPlatform: HostPlatform.android,
        code: 'ABCD1234',
      ),
      throwsA(isA<BootstrapFailure>()),
    );
    expect(primaryHealthCount, 1);
    expect(primaryPostCount, 1);
    expect(fallbackRequestCount, 0);
  });

  group('ClientAppUpdateInfo download trust', () {
    test('prompts for the canonical release URL with complete metadata', () {
      expect(_clientUpdateInfo().shouldPrompt, isTrue);
    });

    test('rejects non-canonical or ambiguous download URLs', () {
      const untrustedUrls = <String>[
        'http://github.com/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov.apk',
        'https://user@github.com/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov.apk',
        'https://github.com:444/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov.apk',
        'https://github.com/attacker/pokrov/releases/download/v1.0.1-beta/pokrov.apk',
        'https://github.com/Kiwunaka/POKROV-app/releases/download/v1.0.1-beta/pokrov.apk',
        'https://evil.example/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov.apk',
        'https://github.com/Kiwunaka/pokrov/releases/download/v1.0.1-beta/nested/pokrov.apk',
        'https://github.com/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov.apk?source=api',
        'intent://github.com/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov.apk',
        'https://github.com/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov.exe',
      ];

      for (final url in untrustedUrls) {
        expect(_clientUpdateInfo(url: url).shouldPrompt, isFalse, reason: url);
      }
    });

    test('requires a SHA-256 digest and positive expected size', () {
      expect(_clientUpdateInfo(sha256: '').shouldPrompt, isFalse);
      expect(_clientUpdateInfo(sha256: 'not-a-sha256').shouldPrompt, isFalse);
      expect(_clientUpdateInfo(size: 0).shouldPrompt, isFalse);
      expect(_clientUpdateInfo(size: -1).shouldPrompt, isFalse);
      expect(
        _clientUpdateInfo(size: 256 * 1024 * 1024 + 1).shouldPrompt,
        isFalse,
      );
      expect(
        _clientUpdateInfo(
          latestVersion: '1.${List.filled(65, '2').join()}.0',
        ).shouldPrompt,
        isFalse,
      );
    });
  });

  test(
      'secure session store fails closed when the platform store is unavailable',
      () async {
    final store = FlutterSecureAppFirstSessionSecretStore(
      storage: const _FailingFlutterSecureStorage(failWrite: true),
    );

    await expectLater(
      store.writeSessionToken(
        hostPlatform: HostPlatform.android,
        installId: 'install-fail-closed',
        sessionToken: 'must-not-fall-back-to-memory',
      ),
      throwsA(isA<PlatformException>()),
    );
  });

  test('secure session store fails closed when token reads fail', () async {
    final store = FlutterSecureAppFirstSessionSecretStore(
      storage: const _FailingFlutterSecureStorage(failRead: true),
    );

    await expectLater(
      store.readSessionToken(
        hostPlatform: HostPlatform.windows,
        installId: 'install-read-failure',
      ),
      throwsA(isA<PlatformException>()),
    );
  });

  test('secure session store fails closed when token deletion fails', () async {
    final store = FlutterSecureAppFirstSessionSecretStore(
      storage: const _FailingFlutterSecureStorage(failDelete: true),
    );

    await expectLater(
      store.deleteSessionToken(
        hostPlatform: HostPlatform.android,
        installId: 'install-delete-failure',
      ),
      throwsA(isA<PlatformException>()),
    );
  });

  test('secure session store migrates a legacy raw credential idempotently',
      () async {
    const installId = 'legacy-secure-fixture';
    const key = 'pokrov.app_first.session.windows.$installId';
    final legacyCredential =
        (await _readBootstrapFixture('secure-session-v0.txt')).trim();
    final values = <String, String>{key: legacyCredential};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(values);
    final store = FlutterSecureAppFirstSessionSecretStore();

    expect(
      await store.readSessionToken(
        hostPlatform: HostPlatform.windows,
        installId: installId,
      ),
      legacyCredential,
    );
    final migrated = values[key];
    expect(migrated, isNotNull);
    expect((jsonDecode(migrated!) as Map<String, dynamic>)['version'], 1);

    expect(
      (await store.readSessionPair(
        hostPlatform: HostPlatform.windows,
        installId: installId,
      ))
          ?.accessToken,
      legacyCredential,
    );
    expect(values[key], migrated);
  });

  test('secure session store preserves and rejects a future credential schema',
      () async {
    const installId = 'future-secure-fixture';
    const key = 'pokrov.app_first.session.android.$installId';
    const future = '{"version":2,"access_token":"synthetic-future-access"}';
    final values = <String, String>{key: future};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(values);
    final store = FlutterSecureAppFirstSessionSecretStore();

    expect(
      await store.readSessionPair(
        hostPlatform: HostPlatform.android,
        installId: installId,
      ),
      isNull,
    );
    expect(values[key], future);
  });

  test('migrates the unversioned bootstrap fixture exactly once', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-schema-migration-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    );
    await stateFile.writeAsString(
      await _readBootstrapFixture('app-first-session-v0.json'),
      flush: true,
    );
    final secretStore = MemoryAppFirstSessionSecretStore();
    await secretStore.writeSessionPair(
      hostPlatform: HostPlatform.windows,
      installId: 'fixture-install-v0',
      pair: const AppFirstSessionCredentials(
        accessToken: 'synthetic-fixture-access',
        refreshToken: 'synthetic-fixture-refresh',
      ),
    );
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:1/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: secretStore,
      maxRequestAttempts: 1,
      connectionTimeout: const Duration(milliseconds: 25),
      requestTimeout: const Duration(milliseconds: 25),
    );

    String? migrated;
    for (var attempt = 0; attempt < 2; attempt += 1) {
      await expectLater(
        bootstrapper.fetchClientSubscription(
          hostPlatform: HostPlatform.windows,
        ),
        throwsA(isA<BootstrapFailure>()),
      );
      final text = await stateFile.readAsString();
      final state = jsonDecode(text) as Map<String, dynamic>;
      expect(state['schema_version'], 1);
      expect(state['session_token_storage'], 'secure');
      expect(state.containsKey('session_token'), isFalse);
      if (attempt == 0) {
        migrated = text;
      } else {
        expect(text, migrated);
      }
    }
  });

  test('future bootstrap state fails closed and remains available for rollback',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-future-schema-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    );
    const future = '{"schema_version":2,"install_id":"future-fixture",'
        '"managed_manifest_path":"/api/client/profile/managed"}';
    await stateFile.writeAsString(future, flush: true);
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:1/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: MemoryAppFirstSessionSecretStore(),
      maxRequestAttempts: 1,
    );

    await expectLater(
      bootstrapper.fetchClientSubscription(
        hostPlatform: HostPlatform.windows,
      ),
      throwsA(isA<BootstrapFailure>()),
    );
    expect(await stateFile.readAsString(), future);
  });

  test('migrates a legacy JSON session token into secure storage', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-migration-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    );
    await stateFile.writeAsString(
      jsonEncode(<String, Object?>{
        'install_id': 'legacy-install',
        'session_token': 'legacy-session-token',
        'account_id': '42',
        'managed_manifest_path': '/api/client/profile/managed',
        'profile_revision': 'legacy-revision',
      }),
    );

    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer legacy-session-token',
        );
        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(<String, Object?>{
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true,
                },
                'profile_revision': 'migrated-revision',
                'config_format': 'singbox-json',
                'config_payload': <String, Object?>{
                  'outbounds': <Object?>[
                    <String, Object?>{'type': 'selector', 'tag': 'proxy'},
                  ],
                  'route': <String, Object?>{'final': 'proxy'},
                },
              }),
            );
          await request.response.close();
          continue;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final sessionSecretStore = MemoryAppFirstSessionSecretStore();
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: sessionSecretStore,
    );

    await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );

    final restartedBootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: sessionSecretStore,
    );
    await restartedBootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );

    final interruptedWriteBackup = File('${stateFile.path}.bak');
    await stateFile.rename(interruptedWriteBackup.path);
    final recoveredBootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: sessionSecretStore,
    );
    await recoveredBootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    expect(await stateFile.exists(), isTrue);
    expect(await interruptedWriteBackup.exists(), isFalse);

    final migrated =
        jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    expect(migrated.containsKey('session_token'), isFalse);
    expect(migrated['session_token_storage'], 'secure');
    expect(
      await sessionSecretStore.readSessionToken(
        hostPlatform: HostPlatform.windows,
        installId: 'legacy-install',
      ),
      'legacy-session-token',
    );
    expect(
      requests,
      containsAllInOrder(const <String>[
        'POST /api/client/route-policy',
        'GET /api/client/profile/managed',
      ]),
    );
    expect(requests, isNot(contains('POST /api/client/session/start-trial')));
  });

  test('keeps a legacy JSON token when secure migration cannot persist it',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-migration-failure-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    );
    await stateFile.writeAsString(
      jsonEncode(<String, Object?>{
        'install_id': 'legacy-install-write-failure',
        'session_token': 'legacy-token-must-survive',
        'account_id': '42',
        'managed_manifest_path': '/api/client/profile/managed',
        'profile_revision': 'legacy-revision',
      }),
    );
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:1/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: FlutterSecureAppFirstSessionSecretStore(
        storage: const _FailingFlutterSecureStorage(failWrite: true),
      ),
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(isA<PlatformException>()),
    );

    final preserved =
        jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    expect(preserved['session_token'], 'legacy-token-must-survive');
    expect(preserved.containsKey('session_token_storage'), isFalse);
  });

  test('requires recovery when secure session marker has no stored token',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-missing-secret-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    );
    await stateFile.writeAsString(
      jsonEncode(<String, Object?>{
        'install_id': 'secure-session-without-secret',
        'session_token_storage': 'secure',
        'account_id': '42',
        'managed_manifest_path': '/api/client/profile/managed',
        'profile_revision': 'stored-revision',
      }),
    );
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:1/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: MemoryAppFirstSessionSecretStore(),
      maxRequestAttempts: 1,
      connectionTimeout: const Duration(milliseconds: 50),
      requestTimeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(
        isA<BootstrapFailure>().having(
          (error) => error.message,
          'message',
          contains('восстановить доступ'),
        ),
      ),
    );

    final preserved =
        jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    expect(preserved['install_id'], 'secure-session-without-secret');
    expect(preserved['session_token_storage'], 'secure');
  });

  test('control-plane SocketException exposes neutral recovery copy', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-safe-network-error-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final reservedServer =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final unavailablePort = reservedServer.port;
    await reservedServer.close(force: true);
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:$unavailablePort/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: MemoryAppFirstSessionSecretStore(),
      maxRequestAttempts: 1,
      connectionTimeout: const Duration(milliseconds: 50),
      requestTimeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(
        isA<BootstrapFailure>()
            .having(
              (error) => error.message,
              'message',
              'Не удалось связаться с сервисом. Проверьте сеть и попробуйте ещё раз.',
            )
            .having(
              (error) => error.operation,
              'operation',
              'POST /api/client/session/start-trial',
            )
            .having((error) => error.apiFailureKind, 'closed API kind', 'request_socket')
            .having((error) => error.observedHttpStatus, 'observed HTTP status', isNull)
            .having(
              (error) => error.message,
              'internal details',
              allOf(
                isNot(contains('SocketException')),
                isNot(contains('127.0.0.1')),
                isNot(contains('port =')),
              ),
            ),
      ),
    );

    final primary = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fallback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await primary.close(force: true);
      await fallback.close(force: true);
    });
    for (final server in [primary, fallback]) {
      server.listen((request) async {
        expect(request.uri.path, '/api/health');
        request.response.headers.contentType = ContentType.html;
        request.response.write('not-json');
        await request.response.close();
      });
    }
    final rejectedOrigins = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${primary.port}/',
      apiFallbackBaseUrls: ['http://127.0.0.1:${fallback.port}/'],
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: MemoryAppFirstSessionSecretStore(),
      maxRequestAttempts: 1,
    );
    await expectLater(
      rejectedOrigins.resolveManagedProfile(
        hostPlatform: HostPlatform.android, routeMode: RouteMode.fullTunnel),
      throwsA(isA<BootstrapFailure>()
          .having((error) => error.operationalErrorCode, 'existing public code', 'API-002')
          .having((error) => error.apiFailureKind, 'origin reason', 'origin_content_type')
          .having((error) => error.observedHttpStatus, 'observed response', 200)
          .having((error) => error.statusCode, 'semantic status remains absent', isNull)
          .having((error) => error.osErrorCode, 'no stale socket error', isNull)),
    );
  });

  test('keeps legacy JSON token when atomic state persistence fails', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-state-write-failure-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    );
    await stateFile.writeAsString(
      jsonEncode(<String, Object?>{
        'install_id': 'legacy-install-state-write-failure',
        'session_token': 'legacy-token-survives-state-write-failure',
        'account_id': '42',
        'managed_manifest_path': '/api/client/profile/managed',
        'profile_revision': 'legacy-revision',
      }),
    );
    final sessionSecretStore = MemoryAppFirstSessionSecretStore();
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:1/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: sessionSecretStore,
      stateFileWriter: (file, contents) async {
        throw FileSystemException('simulated atomic state write failure');
      },
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(isA<FileSystemException>()),
    );

    final preserved =
        jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    expect(
      preserved['session_token'],
      'legacy-token-survives-state-write-failure',
    );
    expect(preserved.containsKey('session_token_storage'), isFalse);
    expect(
      await sessionSecretStore.readSessionToken(
        hostPlatform: HostPlatform.windows,
        installId: 'legacy-install-state-write-failure',
      ),
      'legacy-token-survives-state-write-failure',
    );
  });

  test('serializes overlapping app-first state writes without leaking secrets',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-state-write-queue-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final firstWriterEntered = Completer<void>();
    final releaseFirstWriter = Completer<void>();
    var activeWriters = 0;
    var peakActiveWriters = 0;
    var writerCalls = 0;
    Future<void> writer(File file, String contents) async {
      activeWriters += 1;
      if (activeWriters > peakActiveWriters) {
        peakActiveWriters = activeWriters;
      }
      try {
        writerCalls += 1;
        if (writerCalls == 1) {
          firstWriterEntered.complete();
          await releaseFirstWriter.future;
        }
        final nextFile = File('${file.path}.next');
        final backupFile = File('${file.path}.bak');
        if (await nextFile.exists()) {
          await nextFile.delete();
        }
        await nextFile.writeAsString(contents, flush: true);
        expect(jsonDecode(await nextFile.readAsString()), isA<Map>());
        if (await backupFile.exists()) {
          await backupFile.delete();
        }
        if (await file.exists()) {
          await file.rename(backupFile.path);
        }
        try {
          await nextFile.rename(file.path);
        } catch (_) {
          if (!await file.exists() && await backupFile.exists()) {
            await backupFile.rename(file.path);
          }
          rethrow;
        }
        if (await backupFile.exists()) {
          await backupFile.delete();
        }
      } finally {
        activeWriters -= 1;
      }
    }

    var starts = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            starts += 1;
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(<String, Object?>{
                'access_token': 'overlap-access-$starts',
                'refresh_token': 'overlap-refresh-$starts',
                'account_id': '64',
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true,
                },
              }));
          case '/api/client/route-policy':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"ok":true}');
          case '/api/client/profile/managed':
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_readyManagedProfile('overlap')));
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());

    final secretStore = MemoryAppFirstSessionSecretStore();
    AppFirstRuntimeBootstrapper createBootstrapper() =>
        AppFirstRuntimeBootstrapper(
          apiBaseUrl: 'http://127.0.0.1:${server.port}/',
          supportDirectoryResolver: () async => tempDirectory,
          sessionSecretStore: secretStore,
          stateFileWriter: writer,
          maxRequestAttempts: 1,
        );

    final firstResolve = createBootstrapper().resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    await firstWriterEntered.future;
    final secondResolve = createBootstrapper().resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    await Future<void>.delayed(Duration.zero);
    expect(peakActiveWriters, 1);

    releaseFirstWriter.complete();
    await Future.wait(<Future<dynamic>>[firstResolve, secondResolve]);

    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    );
    final state =
        jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    expect(state['session_token_storage'], 'secure');
    expect(state.containsKey('session_token'), isFalse);
    expect(state.containsKey('refresh_token'), isFalse);
    expect(
      await secretStore.readSessionPair(
        hostPlatform: HostPlatform.windows,
        installId: state['install_id'] as String,
      ),
      isNotNull,
    );
    expect(await File('${stateFile.path}.next').exists(), isFalse);
    expect(await File('${stateFile.path}.bak').exists(), isFalse);
  });

  test('bootstraps and persists a managed profile from the app-first API',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          expect(decoded['device_name'], 'POKROV Windows Surface Laptop');
          expect(decoded['app_version'], pokrovClientVersion);
          expect(decoded.containsKey('trial_days'), isFalse);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-1',
                    'account_id': '42',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer session-token-1',
          );
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['route_mode'], 'selected_apps');
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer session-token-1',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-007',
                  'access': <String, Object?>{
                    'access_state': 'free_monthly',
                    'soft_mode_active': false,
                    'free_profile_state': 'soft_transition_pending',
                    'free_profile_active_role': 'free_standard',
                    'free_profile_job_id': 81,
                  },
                  'free_caps': <String, Object?>{
                    'transition_state': 'soft_transition_pending',
                    'active_role': 'free_standard',
                    'provisioning_job_id': 81,
                    'error_code': null,
                  },
                  'smart_connect': <String, Object?>{
                    'eligible': true,
                    'fallback_required': false,
                    'shortlist_reason': 'eligible',
                    'shortlist_limit': 5,
                    'shortlist_revision': 'short-007',
                    'transport_profile': 'reality',
                    'profile_revision': 'rev-007',
                    'fallback_order': <String>['pl', 'de'],
                    'shortlist': <Object?>[
                      <String, Object?>{
                        'code': 'pl',
                        'country': 'Poland',
                        'rank': 1,
                        'rank_hint': <String, Object?>{
                          'health_score': 97.5,
                          'cpu_percent': 21.0,
                          'panel_latency_ms': 42,
                          'backend_penalty': 0,
                          'cpu_penalty': 0,
                          'sticky_preferred': true,
                        },
                      },
                    ],
                    'stickiness': <String, Object?>{
                      'preferred_node_code': 'pl',
                      'threshold_percent': 15,
                      'latest_sample_at': '2026-06-03T10:00:00Z',
                      'stickiness_applied': true,
                    },
                  },
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                  'warp_policy': <String, Object?>{
                    'enabled': true,
                    'runtime_ready': true,
                    'state': 'ready',
                    'mode': 'proxy_over_warp',
                    'source': 'backend_managed',
                    'wireguard_config': <String, Object?>{
                      'private-key': 'test-private-key',
                      'local-address-ipv4': '172.16.0.2',
                      'peer-public-key': 'test-peer-public-key',
                      'client-id': 'test-client-id',
                    },
                    'account': <String, Object?>{
                      'account-id': 'test-account-id',
                      'access-token': 'test-access-token',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final sessionSecretStore = MemoryAppFirstSessionSecretStore();
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: sessionSecretStore,
      deviceNameResolver: (_) async => 'Surface Laptop',
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.selectedApps,
      selectedApps: const ['pokrov-test.exe'],
    );

    expect(payload.profileName, 'pokrov-windows-rev-007');
    expect(payload.source?.revision, 'rev-007');
    expect(payload.source?.origin, RuntimeProfileSourceOrigin.managedManifest);
    expect(payload.smartConnect, isNotNull);
    expect(payload.smartConnect?.shortlistRevision, 'short-007');
    expect(payload.smartConnect?.shortlist.single.code, 'pl');
    expect(payload.smartConnect?.shortlist.single.rankHint.panelLatencyMs, 42);
    expect(payload.smartConnect?.stickiness.preferredNodeCode, 'pl');
    expect(payload.freeProfileAccess?.isPending, isTrue);
    expect(payload.freeProfileAccess?.activeRole, 'free_standard');
    expect(payload.freeProfileAccess?.provisioningJobId, 81);
    expect(payload.warpPolicy.enabled, isTrue);
    expect(payload.warpPolicy.runtimeReady, isTrue);
    expect(payload.warpPolicy.state, 'ready');
    expect(payload.warpPolicy.mode, 'proxy_over_warp');
    expect(payload.warpPolicy.userConsented, isFalse);
    expect(payload.warpPolicy.canOfferRuntime, isTrue);
    expect(payload.warpPolicy.canEnableRuntime, isFalse);
    expect(
        payload.warpPolicy.wireguardConfigJson, contains('test-private-key'));
    expect(payload.warpPolicy.accountId, 'test-account-id');
    expect(payload.configPayload, contains('"type": "tun"'));
    expect(payload.configPayload, contains('"final": "direct"'));
    expect(payload.configPayload, contains('"auto_detect_interface": true'));
    expect(payload.configPayload, isNot(contains('"override_android_vpn"')));
    expect(
      requests,
      containsAllInOrder(const [
        'POST /api/client/session/start-trial',
        'POST /api/client/route-policy',
        'GET /api/client/profile/managed',
      ]),
    );

    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}app-first-session-windows.json',
    );
    expect(await stateFile.exists(), isTrue);
    final state =
        jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    expect(state.containsKey('session_token'), isFalse);
    expect(state['session_token_storage'], 'secure');
    expect(
      await sessionSecretStore.readSessionToken(
        hostPlatform: HostPlatform.windows,
        installId: state['install_id'] as String,
      ),
      'session-token-1',
    );
    expect(state['managed_manifest_path'], '/api/client/profile/managed');
  });

  test('reports runtime stats with native failure through the app session',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-runtime-stats-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    final statsBodies = <Map<String, dynamic>>[];
    var denyStats = false;
    final telegramLinkEventBodies = <Map<String, dynamic>>[];
    Map<String, dynamic>? onboardingBody;
    final eventBodies = <Map<String, dynamic>>[];
    Map<String, dynamic>? acquisitionBody;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'runtime-stats-session',
                    'account_id': 'account-runtime-stats',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/client/runtime/stats') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer runtime-stats-session',
          );
          statsBodies.add(jsonDecode(body) as Map<String, dynamic>);
          request.response
            ..statusCode = denyStats ? HttpStatus.unauthorized : HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/client/telegram/link/events') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer runtime-stats-session',
          );
          telegramLinkEventBodies.add(
            jsonDecode(body) as Map<String, dynamic>,
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/account/experience/onboarding') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer runtime-stats-session',
          );
          onboardingBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/events') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer runtime-stats-session',
          );
          eventBodies.add(jsonDecode(body) as Map<String, dynamic>);
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/acquisition/handoffs/consume') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer runtime-stats-session',
          );
          acquisitionBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final secrets = MemoryAppFirstSessionSecretStore();
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://${server.address.address}:${server.port}',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: secrets,
      maxRequestAttempts: 1,
    );

    await bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.android,
      runtimePhase: 'connect_requested',
      connected: false,
    );
    expect(requests, isEmpty, reason: 'diagnostics must not start a trial');
    final stateFile = File('${tempDirectory.path}/app-first-session-android.json');
    expect(await stateFile.exists(), isFalse);
    await secrets.writeSessionPair(
      hostPlatform: HostPlatform.android,
      installId: 'runtime-stats-install',
      pair: const AppFirstSessionCredentials(
        accessToken: 'runtime-stats-session', refreshToken: 'runtime-stats-refresh',
      ),
    );
    await stateFile.writeAsString(jsonEncode({
      'schema_version': 1, 'install_id': 'runtime-stats-install',
      'account_id': 'account-runtime-stats',
      'managed_manifest_path': '/api/client/profile/managed',
    }));

    const failedSnapshot = RuntimeSnapshot(
      hostPlatform: HostPlatform.android,
      lane: RuntimeLane.mobileArtifact,
      phase: RuntimePhase.running,
      artifactDirectory: null,
      coreBinaryPath: null,
      helperBinaryPath: null,
      stagedConfigPath: null,
      supportsLiveConnect: true,
      canInitialize: false,
      canConnect: false,
      message: 'Egress verification failed.',
      coreEgressValidated: false,
      lastFailureKind: 'core_egress_timeout',
    );

    await bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.android,
      runtimePhase: 'RUNNING',
      connected: true,
      attemptNumber: 100,
      networkClass: 'cellular',
      carrierMccMnc: '25099',
      carrierName: ' Test Carrier ',
      candidateTransport: 'xhttp_reality',
      candidateRef: 'de:xhttp',
      candidateVariant: 'ru_bridge',
      candidateProbes: [
        {'candidate_ref': 'de:vless', 'candidate_transport': 'vless_reality',
          'candidate_variant': 'ru_bridge',
          'probe_stage': 'http_64k',
          'stage': 'probe', 'connected': false, 'failure_kind': 'data_stalled', 'duration_ms': 134512},
        {'candidate_ref': 'de:xhttp', 'candidate_transport': 'xhttp_reality',
          'candidate_variant': 'direct',
          'probe_stage': 'unknown_phase',
          'stage': 'probe', 'connected': true, 'failure_kind': '', 'duration_ms': 300},
        {'candidate_ref': 'warp:warp_free:warp_direct', 'candidate_transport': 'warp',
          'stage': 'probe', 'connected': true, 'duration_ms': 321},
      ],
    );
    await bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.android,
      runtimePhase: 'FAILED',
      connected: false,
      errorCode: 'connect_failed',
      attemptNumber: 101,
      connectivitySnapshot: failedSnapshot,
      candidateTransport: 'warp',
      candidateRef: 'warp:warp_free:warp_direct',
      networkClass: 'wifi',
      accessNetworkAsn: 'AS12345',
    );
    await bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.android,
      runtimePhase: 'FAILED',
      connected: false,
      errorCode: ' conn-008 ',
      failureKind: 'tls_failed',
      attemptNumber: 2147483648,
      connectivitySnapshot: failedSnapshot,
    );
    await bootstrapper.reportTelegramLinkEvent(
      hostPlatform: HostPlatform.android,
      eventName: 'verify_requested',
    );
    await bootstrapper.completeAccountOnboarding(
      hostPlatform: HostPlatform.android,
    );
    await bootstrapper.completeRoutingLesson(
      hostPlatform: HostPlatform.android,
    );
    await bootstrapper.reportPromoEvent(
      hostPlatform: HostPlatform.android,
      eventName: 'click',
      slot: const AppFirstPromoSlot(
        slotId: 'home_banner',
        contentId: 'sale_70',
        enabled: true,
        title: 'Sale',
        body: 'Visible copy must not be uploaded in telemetry.',
        placement: 'home_banner',
        ctaLabel: 'Open',
        ctaHref: 'https://pokrov.space/pricing/',
        pilotId: 'release_1_2_winback_paid_7_30d',
        pilotRevision: '2026-08-22.1',
        pilotContractSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        commercialRevision: '2026-08-21.1',
        campaignId: 'cmp_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        offerId: 'off_cccccccccccccccccccccccccccccccc',
        creativeId: 'crv_dddddddddddddddddddddddddddddddd',
        variant: 'a',
        assignmentId: 'asg_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        impressionId: 'imp_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        clickId: 'clk_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        kind: 'sale',
        goal: 'checkout',
      ),
    );
    await bootstrapper.reportFirstSessionEvent(
      hostPlatform: HostPlatform.android,
      eventName: 'vpn_permission_result',
      stage: 'vpn_permission',
      result: 'failure',
      errorCode: 'vpn_permission_denied',
      retryable: true,
    );
    await bootstrapper.reportFirstSessionEvent(
      hostPlatform: HostPlatform.android,
      eventName: 'not_allowed',
      stage: 'raw/session/token',
      result: 'failure',
    );
    await bootstrapper.consumeAcquisitionHandoff(
      hostPlatform: HostPlatform.android,
      handle: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      purpose: 'android_install',
    );

    expect(requests, <String>[
      'POST /api/client/runtime/stats',
      'POST /api/client/runtime/stats',
      'POST /api/client/runtime/stats',
      'POST /api/client/telegram/link/events',
      'POST /api/account/experience/onboarding',
      'POST /api/events',
      'POST /api/events',
      'POST /api/events',
      'POST /api/acquisition/handoffs/consume',
    ]);
    final reportRunId = statsBodies.first['report_run_id'];
    expect(reportRunId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(statsBodies, <Map<String, dynamic>>[
      <String, Object?>{
        'runtime_phase': 'running',
        'connected': true,
        'attempt_number': 100,
        'build_number': const String.fromEnvironment('POKROV_BUILD_NUMBER', defaultValue: '0'),
        'report_run_id': reportRunId,
        'report_sequence': 2,
        'connectivity': {'proof_stage': 'unknown'},
        'network_class': 'cellular',
        'carrier_mcc_mnc': '25099',
        'carrier_name': 'Test Carrier',
        'candidate_transport': 'xhttp_reality',
        'candidate_ref': 'de:xhttp',
        'candidate_variant': 'ru_bridge',
        'candidate_probes': [
          {'candidate_ref': 'de:vless', 'candidate_transport': 'vless_reality',
            'candidate_variant': 'ru_bridge',
            'probe_stage': 'http_64k',
            'stage': 'probe', 'connected': false, 'failure_kind': 'data_stalled', 'duration_ms': 134512},
          {'candidate_ref': 'de:xhttp', 'candidate_transport': 'xhttp_reality',
            'stage': 'probe', 'connected': true, 'duration_ms': 300},
          {'candidate_ref': 'warp:warp_free:warp_direct', 'candidate_transport': 'warp',
            'stage': 'probe', 'connected': true, 'duration_ms': 321},
        ],
      },
      <String, Object?>{
        'runtime_phase': 'failed',
        'connected': false,
        'build_number': const String.fromEnvironment('POKROV_BUILD_NUMBER', defaultValue: '0'),
        'error_code': 'connect_failed',
        'attempt_number': 101,
        'failure_kind': 'core_egress_timeout',
        'candidate_transport': 'warp',
        'candidate_ref': 'warp:warp_free:warp_direct',
        'network_class': 'wifi',
        'access_network_asn': 'AS12345',
        'report_run_id': reportRunId,
        'report_sequence': 3,
        'connectivity': {'proof_stage': 'degraded'},
      },
      <String, Object?>{
        'runtime_phase': 'failed',
        'connected': false,
        'build_number': const String.fromEnvironment('POKROV_BUILD_NUMBER', defaultValue: '0'),
        'error_code': 'CONN-008',
        'failure_kind': 'tls_failed',
        'attempt_number': 2147483647,
        'report_run_id': reportRunId,
        'report_sequence': 4,
        'connectivity': {'proof_stage': 'degraded'},
      },
    ]);
    expect(telegramLinkEventBodies, <Map<String, dynamic>>[
      <String, Object?>{'event_name': 'verify_requested'},
    ]);
    expect(onboardingBody, <String, Object?>{'status': 'completed'});
    expect(eventBodies, <Map<String, dynamic>>[
      <String, Object?>{
        'event_name': 'routing_lesson_completed',
        'source': 'app',
        'meta': <String, Object?>{'surface': 'route_explainer'},
      },
      <String, Object?>{
        'event_name': 'promo_click',
        'source': 'app',
        'meta': <String, Object?>{
          'slot_id': 'home_banner',
          'content_id': 'sale_70',
          'placement': 'home_banner',
          'pilot_id': 'release_1_2_winback_paid_7_30d',
          'pilot_revision': '2026-08-22.1',
          'pilot_contract_sha256':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'commercial_revision': '2026-08-21.1',
          'campaign_id': 'cmp_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'offer_id': 'off_cccccccccccccccccccccccccccccccc',
          'creative_id': 'crv_dddddddddddddddddddddddddddddddd',
          'variant': 'a',
          'assignment_id': 'asg_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          'impression_id': 'imp_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          'click_id': 'clk_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        },
      },
      <String, Object?>{
        'event_name': 'vpn_permission_result',
        'source': 'app',
        'platform': 'android',
        'app_version': pokrovClientVersion,
        'surface': 'first_session',
        'subsystem': 'onboarding',
        'stage': 'vpn_permission',
        'result': 'failure',
        'error_category': 'first_session',
        'error_code': 'vpn_permission_denied',
        'retryable': true,
      },
    ]);
    expect(acquisitionBody, <String, Object?>{
      'handle': 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      'purpose': 'android_install',
    });
    denyStats = true;
    final requestCount = requests.length;
    await expectLater(
      bootstrapper.reportRuntimeStats(
        hostPlatform: HostPlatform.android,
        runtimePhase: 'failed', connected: false, errorCode: 'API-999',
        candidateProbes: const [{
          'candidate_ref': 'de:vless', 'candidate_transport': 'vless_reality',
          'stage': 'probe', 'connected': false, 'failure_kind': 'connect_failed',
        }],
      ),
      throwsA(isA<BootstrapFailure>().having((error) => error.statusCode,
          'statusCode', HttpStatus.unauthorized)),
    );
    expect(requests.skip(requestCount), ['POST /api/client/runtime/stats'],
        reason: '401 must not refresh or reprovision a diagnostics session');
    expect(statsBodies.last, isNot(contains('error_code')));
    expect((await secrets.readSessionPair(hostPlatform: HostPlatform.android,
        installId: 'runtime-stats-install'))!.refreshToken, 'runtime-stats-refresh');
  });

  test('keeps a probe batch sequence across failed stats delivery', () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-stats-retry-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final reports = <Map<String, dynamic>>[];
    var denyStats = true;
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response.write(jsonEncode({
            'session': {'session_token': 'stats-retry-session', 'account_id': 'stats-retry-account'},
            'provisioning': {'status': 'ready', 'sync_ok': true},
          }));
        } else if (request.uri.path == '/api/client/runtime/stats') {
          reports.add(jsonDecode(body) as Map<String, dynamic>);
          if (denyStats) request.response.statusCode = HttpStatus.serviceUnavailable;
          request.response.write(jsonEncode({'ok': !denyStats}));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final secrets = MemoryAppFirstSessionSecretStore();
    await secrets.writeSessionToken(hostPlatform: HostPlatform.windows,
        installId: 'stats-retry-install', sessionToken: 'stats-retry-session');
    await File('${directory.path}/app-first-session-windows.json').writeAsString(jsonEncode({
      'schema_version': 1, 'install_id': 'stats-retry-install',
      'account_id': 'stats-retry-account',
      'managed_manifest_path': '/api/client/profile/managed',
    }));
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}',
      supportDirectoryResolver: () async => directory,
      sessionSecretStore: secrets,
      delayScheduler: (_) async {},
    );

    Future<void> report({int attemptNumber = 1}) => bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.windows,
      runtimePhase: 'runtime_observed',
      connected: true,
      attemptNumber: attemptNumber,
      networkClass: 'ethernet',
      candidateProbes: const [{
        'candidate_ref': 'ch:legacy_reality_fallback',
        'candidate_transport': 'vless_reality',
        'stage': 'probe',
        'connected': true,
        'duration_ms': 300,
      }],
    );
    await expectLater(report(), throwsA(isA<BootstrapFailure>()));
    denyStats = false;
    await report();

    expect(reports, hasLength(3));
    expect(reports[1], reports[0]);
    expect(reports[2], reports[0]);
    expect(reports[0]['report_sequence'], 1);
    expect(reports[0]['candidate_probes'], hasLength(1));

    denyStats = true;
    await expectLater(report(), throwsA(isA<BootstrapFailure>()));
    denyStats = false;
    await report(attemptNumber: 2);
    expect(reports, hasLength(6));
    expect(reports[4], reports[3]);
    expect(reports[3]['report_sequence'], 2);
    expect(reports.last['candidate_probes'], reports[3]['candidate_probes']);
    expect(reports.last['attempt_number'], 2);
    expect(reports.last['report_sequence'], 3,
        reason: 'an identical probe batch in a new attempt owns a new sequence');
  });

  test('acquisition continuation parser is host-bound and rejects extras', () {
    const handle = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    final android = PokrovAcquisitionHandoff.tryParse(
      Uri.parse(
        'pokrov://acquisition/continue?handle=$handle&purpose=android_install',
      ),
      hostPlatform: HostPlatform.android,
    );
    expect(android?.handle, handle);
    expect(android?.purpose, 'android_install');

    expect(
      PokrovAcquisitionHandoff.tryParse(
        Uri.parse(
          'pokrov://acquisition/continue?handle=$handle&purpose=windows_install',
        ),
        hostPlatform: HostPlatform.android,
      ),
      isNull,
    );
    expect(
      PokrovAcquisitionHandoff.tryParse(
        Uri.parse(
          'pokrov://acquisition/continue?handle=$handle&purpose=android_install&email=a%40b.example',
        ),
        hostPlatform: HostPlatform.android,
      ),
      isNull,
    );
  });

  test('warp lifecycle actions use app session and sanitize runtime metadata',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-warp-lifecycle-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    Map<String, dynamic>? consentBody;
    Map<String, dynamic>? runtimeEventBody;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-warp',
                    'account_id': '42',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/warp/status') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer session-token-warp',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'feature': 'extended_protection',
                  'public_label': 'WARP',
                  'technical_label': 'WARP',
                  'enabled': true,
                  'runtime_ready': true,
                  'can_enable': true,
                  'consented': false,
                  'state': 'ready_to_consent',
                  'mode': 'proxy_over_warp',
                  'source': 'backend_managed',
                  'wireguard_config_available': true,
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/warp/consent') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer session-token-warp',
          );
          consentBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'feature': 'extended_protection',
                  'public_label': 'WARP',
                  'technical_label': 'WARP',
                  'enabled': true,
                  'runtime_ready': true,
                  'can_enable': false,
                  'consented': true,
                  'state': 'consented',
                  'mode': 'proxy_over_warp',
                  'source': 'backend_managed',
                  'wireguard_config_available': true,
                  'consented_at': '2026-06-05T12:00:00Z',
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/warp/events') {
          runtimeEventBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'feature': 'extended_protection',
                  'public_label': 'WARP',
                  'technical_label': 'WARP',
                  'enabled': true,
                  'runtime_ready': true,
                  'can_enable': false,
                  'consented': true,
                  'state': 'fallback',
                  'mode': 'proxy_over_warp',
                  'source': 'backend_managed',
                  'wireguard_config_available': true,
                  'last_event': <String, Object?>{
                    'event_name': 'runtime_fallback',
                    'state': 'fallback',
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final status = await bootstrapper.fetchWarpStatus(
      hostPlatform: HostPlatform.windows,
    );
    expect(status.state, 'ready_to_consent');
    expect(status.consented, isFalse);

    final consent = await bootstrapper.setWarpConsent(
      hostPlatform: HostPlatform.windows,
      enabled: true,
    );
    expect(consent.consented, isTrue);
    expect(consentBody, containsPair('consent', true));

    final fallback = await bootstrapper.reportWarpRuntimeEvent(
      hostPlatform: HostPlatform.windows,
      eventName: 'runtime_fallback',
      state: 'fallback',
      reasonCode: 'handshake_failed',
      message:
          'baseline fallback used private-key test-private https://connect.pokrov.space/secret',
      meta: const <String, Object?>{
        'safe_detail': 'fallback',
        'wireguard_config': <String, Object?>{'private-key': 'test-private'},
        'subscription_url': 'https://connect.pokrov.space/secret',
      },
    );
    expect(fallback.state, 'fallback');
    final warpCacheFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'warp-consent-windows.json',
    );
    expect(await warpCacheFile.exists(), isTrue);
    final warpCacheJson = await warpCacheFile.readAsString();
    expect(
      (jsonDecode(warpCacheJson) as Map<String, dynamic>)['schema_version'],
      1,
    );
    expect(warpCacheJson, contains('extended_protection'));
    expect(warpCacheJson, contains('WARP'));
    expect(warpCacheJson, contains('fallback'));
    expect(warpCacheJson, isNot(contains('technical_label')));
    expect(warpCacheJson, isNot(contains('private-key')));
    expect(warpCacheJson, isNot(contains('wireguard_config')));
    expect(warpCacheJson, isNot(contains('connect.pokrov.space')));
    final runtimeEventJson = jsonEncode(runtimeEventBody);
    expect(runtimeEventJson, contains('safe_detail'));
    expect(runtimeEventJson, contains('[redacted]'));
    expect(runtimeEventJson, isNot(contains('test-private')));
    expect(runtimeEventJson, isNot(contains('private-key')));
    expect(runtimeEventJson, isNot(contains('connect.pokrov.space/secret')));
    expect(
      requests,
      containsAllInOrder(const [
        'POST /api/client/session/start-trial',
        'GET /api/client/warp/status',
        'POST /api/client/warp/consent',
        'POST /api/client/warp/events',
      ]),
    );
  });

  test('uploads smart-connect RTT samples and applies stickiness threshold',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-smart-connect-latency-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    Map<String, dynamic>? latencyBody;
    final telemetryUploaded = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'smart-connect-session',
                    'account_id': 'smart-connect-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-009',
                  'smart_connect': <String, Object?>{
                    'eligible': true,
                    'fallback_required': false,
                    'shortlist_reason': 'eligible',
                    'shortlist_limit': 5,
                    'shortlist_revision': 'short-009',
                    'transport_profile': 'reality',
                    'profile_revision': 'rev-009',
                    'fallback_order': <String>['pl', 'de'],
                    'shortlist': <Object?>[
                      <String, Object?>{
                        'code': 'pl',
                        'country': 'Poland',
                        'rank': 1,
                        'rank_hint': <String, Object?>{
                          'health_score': 98.0,
                          'cpu_percent': 20.0,
                          'panel_latency_ms': 60,
                          'backend_penalty': 0,
                          'cpu_penalty': 0,
                          'sticky_preferred': true,
                        },
                      },
                      <String, Object?>{
                        'code': 'de',
                        'country': 'Germany',
                        'rank': 2,
                        'rank_hint': <String, Object?>{
                          'health_score': 97.0,
                          'cpu_percent': 18.0,
                          'panel_latency_ms': 55,
                          'backend_penalty': 0,
                          'cpu_penalty': 0,
                          'sticky_preferred': false,
                        },
                      },
                    ],
                    'stickiness': <String, Object?>{
                      'preferred_node_code': 'pl',
                      'threshold_percent': 15,
                      'latest_sample_at': '2026-06-04T10:00:00Z',
                      'stickiness_applied': false,
                    },
                  },
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/nodes/latency-samples') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer smart-connect-session',
          );
          latencyBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'accepted_samples': 2,
                  'preferred_node_code': 'pl',
                },
              ),
            );
          await request.response.close();
          if (!telemetryUploaded.isCompleted) {
            telemetryUploaded.complete();
          }
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      smartConnectLatencyProbe: (node) async => switch (node.code) {
        'pl' => 100,
        'de' => 88,
        _ => null,
      },
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    await telemetryUploaded.future.timeout(const Duration(seconds: 2));

    expect(payload.smartConnect?.shortlistRevision, 'short-009');
    expect(latencyBody, isNotNull);
    expect(latencyBody?['profile_revision'], 'rev-009');
    expect(latencyBody?['transport_profile'], 'reality');
    expect(latencyBody?['selected_node_code'], 'pl');
    expect(latencyBody?['previous_node_code'], 'pl');
    expect(latencyBody?['stickiness_applied'], isTrue);
    expect(latencyBody?['samples'], <Object?>[
      <String, Object?>{'node_code': 'pl', 'rtt_ms': 100},
      <String, Object?>{'node_code': 'de', 'rtt_ms': 88},
    ]);
    expect(requests, <String>[
      'POST /api/client/session/start-trial',
      'POST /api/client/route-policy',
      'GET /api/client/profile/managed',
      'POST /api/client/nodes/select',
      'GET /api/client/profile/managed',
      'POST /api/client/nodes/latency-samples',
    ]);
  });

  test(
      'uses local selection and promotes the profile when Smart Connect advisory stalls',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-smart-connect-background-telemetry-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final selectStarted = Completer<void>();
    var latencyUploads = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'session': <String, Object?>{
                'session_token': 'background-session',
                'account_id': 'background-account',
              },
              'provisioning': <String, Object?>{
                'status': 'ready',
                'sync_ok': true,
              },
            }));
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write('{"ok":true}');
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/client/profile/managed') {
          final profile = _readyManagedProfile('background')
            ..['smart_connect'] = <String, Object?>{
              'eligible': true,
              'shortlist': <Object?>[
                <String, Object?>{
                  'code': 'pl',
                  'rank': 1,
                  'probe': <String, Object?>{'host': '127.0.0.1', 'port': 1},
                  'rank_hint': <String, Object?>{},
                },
              ],
            };
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(profile));
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/client/nodes/select') {
          if (!selectStarted.isCompleted) {
            selectStarted.complete();
          }
          await Future<void>.delayed(const Duration(seconds: 1));
          try {
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"ok":true}');
            await request.response.close();
          } on Object {
            // The client closes this best-effort request at its deadline.
          }
          continue;
        }
        if (request.uri.path == '/api/client/nodes/latency-samples') {
          latencyUploads += 1;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      smartConnectTelemetryDeadline: const Duration(milliseconds: 80),
      smartConnectLatencyProbe: (_) async => 42,
    );
    final stopwatch = Stopwatch()..start();
    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    stopwatch.stop();

    expect(payload.profileName, 'pokrov-windows-background');
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    await selectStarted.future.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(latencyUploads, 1);
  });

  test('bounds hanging Smart Connect probes by concurrency and deadline',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-smart-connect-background-probe-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'session': <String, Object?>{
                'session_token': 'probe-session',
                'account_id': 'probe-account',
              },
              'provisioning': <String, Object?>{
                'status': 'ready',
                'sync_ok': true,
              },
            }));
        } else if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write('{"ok":true}');
        } else if (request.uri.path == '/api/client/profile/managed') {
          final profile = _readyManagedProfile('probe')
            ..['smart_connect'] = <String, Object?>{
              'eligible': true,
              'shortlist': List<Object?>.generate(
                8,
                (index) => <String, Object?>{
                  'code': 'node-$index',
                  'rank': index + 1,
                  'probe': <String, Object?>{
                    'host': '127.0.0.1',
                    'port': index + 1,
                  },
                  'rank_hint': <String, Object?>{},
                },
              ),
            };
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(profile));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());

    var probesStarted = 0;
    final neverCompletes = Completer<int?>();
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      smartConnectTelemetryDeadline: const Duration(milliseconds: 500),
      smartConnectProbeTimeout: const Duration(milliseconds: 40),
      smartConnectProbeConcurrency: 3,
      smartConnectLatencyProbe: (_) {
        probesStarted += 1;
        return neverCompletes.future;
      },
    );
    final stopwatch = Stopwatch()..start();
    await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(probesStarted, 3);
    // A wrapper timeout does not cancel the original Future. A new resolution
    // must share occupied slots until those probes actually settle.
    await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(probesStarted, 3);
    neverCompletes.complete(null);
    await Future<void>.delayed(Duration.zero);
    await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(probesStarted, greaterThan(3));
  });

  test('manual smart-connect preference does not upload fake RTT samples',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-manual-smart-connect-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    Map<String, dynamic>? selectBody;
    var rejectSelection = false;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'manual-smart-connect-session',
                    'account_id': 'manual-smart-connect-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/nodes/select') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer manual-smart-connect-session',
          );
          selectBody = jsonDecode(body) as Map<String, dynamic>;
          if (rejectSelection) {
            request.response
              ..statusCode = HttpStatus.badRequest
              ..headers.contentType = ContentType.json
              ..write('{"detail":"selected node is not eligible"}');
            await request.response.close();
            continue;
          }
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'selected_node_code': 'de',
                  'previous_node_code': 'pl',
                  'accepted_samples': 0,
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final smartConnect = SmartConnectProfile(
      eligible: true,
      fallbackRequired: false,
      shortlistReason: 'eligible',
      shortlistLimit: 5,
      shortlistRevision: 'short-manual',
      transportProfile: 'reality',
      profileRevision: 'rev-manual',
      fallbackOrder: const <String>['de', 'pl'],
      shortlist: const <SmartConnectNode>[
        SmartConnectNode(
          code: 'de',
          country: 'Germany',
          rank: 1,
          rankHint: SmartConnectRankHint(
            healthScore: 99,
            cpuPercent: 10,
            panelLatencyMs: 40,
            backendPenalty: 0,
            cpuPenalty: 0,
            stickyPreferred: false,
          ),
        ),
        SmartConnectNode(
          code: 'pl',
          country: 'Poland',
          rank: 2,
          rankHint: SmartConnectRankHint(
            healthScore: 98,
            cpuPercent: 12,
            panelLatencyMs: 55,
            backendPenalty: 0,
            cpuPenalty: 0,
            stickyPreferred: true,
          ),
        ),
      ],
      stickiness: const SmartConnectStickiness(
        preferredNodeCode: 'pl',
        thresholdPercent: 15,
        latestSampleAt: '2026-06-04T10:00:00Z',
        stickinessApplied: false,
      ),
    );

    final result = await bootstrapper.setPreferredSmartConnectNode(
      hostPlatform: HostPlatform.windows,
      smartConnect: smartConnect,
      nodeCode: ' DE ',
    );

    expect(result.preferredNodeCode, 'de');
    expect(result.acceptedSamples, 0);
    expect(selectBody, isNotNull);
    expect(selectBody?['mode'], 'manual');
    expect(selectBody?['profile_revision'], 'rev-manual');
    expect(selectBody?['transport_profile'], 'reality');
    expect(selectBody?['selected_node_code'], 'de');
    expect(selectBody?['previous_node_code'], 'pl');
    expect(selectBody?['samples'], const <Object?>[]);
    expect(requests, <String>[
      'POST /api/client/session/start-trial',
      'POST /api/client/nodes/select',
    ]);
    rejectSelection = true;
    await expectLater(
      bootstrapper.setPreferredSmartConnectNode(
        hostPlatform: HostPlatform.windows,
        smartConnect: smartConnect,
        nodeCode: 'de',
      ),
      throwsA(isA<BootstrapFailure>().having(
        (failure) => failure.message,
        'message',
        'Эта локация сейчас недоступна. Выберите другую.',
      )),
    );
  });

  test('uses shortlist probe endpoint for default smart-connect RTT', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-smart-connect-default-probe-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final probeServer =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(probeServer.close);
    unawaited(() async {
      await for (final socket in probeServer) {
        socket.destroy();
      }
    }());

    Map<String, dynamic>? latencyBody;
    final telemetryUploaded = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'smart-connect-probe-session',
                    'account_id': 'smart-connect-probe-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-probe',
                  'smart_connect': <String, Object?>{
                    'eligible': true,
                    'fallback_required': false,
                    'shortlist_reason': 'eligible',
                    'shortlist_limit': 1,
                    'shortlist_revision': 'short-probe',
                    'transport_profile': 'reality',
                    'profile_revision': 'rev-probe',
                    'fallback_order': <String>['nl-free'],
                    'shortlist': <Object?>[
                      <String, Object?>{
                        'code': 'nl-free',
                        'country': 'Netherlands',
                        'rank': 1,
                        'probe': <String, Object?>{
                          'host': '127.0.0.1',
                          'port': probeServer.port,
                        },
                        'rank_hint': <String, Object?>{
                          'health_score': 99.0,
                          'cpu_percent': 10.0,
                          'panel_latency_ms': 30,
                          'backend_penalty': 0,
                          'cpu_penalty': 0,
                          'sticky_preferred': false,
                        },
                      },
                    ],
                    'stickiness': <String, Object?>{
                      'preferred_node_code': '',
                      'threshold_percent': 15,
                      'latest_sample_at': null,
                      'stickiness_applied': false,
                    },
                  },
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/nodes/latency-samples') {
          latencyBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'accepted_samples': 1,
                  'preferred_node_code': 'nl-free',
                },
              ),
            );
          await request.response.close();
          if (!telemetryUploaded.isCompleted) {
            telemetryUploaded.complete();
          }
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    await telemetryUploaded.future.timeout(const Duration(seconds: 2));

    final samples = latencyBody?['samples'] as List<Object?>?;
    expect(samples, hasLength(1));
    final sample = samples!.single as Map<String, dynamic>;
    expect(sample['node_code'], 'nl-free');
    expect(sample['rtt_ms'], greaterThan(0));
    expect(latencyBody?['selected_node_code'], 'nl-free');
  });

  test(
      'support ticket service creates a ticket with app-session auth and safe diagnostics',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-support-ticket-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    Map<String, dynamic>? ticketBody;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'support-session-token',
                    'account_id': 'ticket-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/tickets') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer support-session-token',
          );
          ticketBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ticket': <String, Object?>{
                    'id': 321,
                    'status': 'open',
                    'status_title': 'Open',
                    'messages': <Object?>[
                      <String, Object?>{
                        'body': ticketBody?['body'],
                      },
                    ],
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final service = AppFirstSupportTicketService(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final receipt = await service.createTicket(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.allExceptRu,
      statusLabel: 'Ready',
      subject: 'Connection help',
      body: 'Cannot connect on first launch',
      diagnostics: const <String, Object?>{
        'app_version': pokrovClientVersion,
        'platform': 'windows',
        'route_mode': 'all_except_ru',
        'connection_status': 'Ready',
        'raw_config': 'vless://secret-value',
        'subscription_url': 'https://secret.example/sub',
      },
    );

    expect(receipt.ticketId, 321);
    expect(receipt.statusTitle, 'Open');
    expect(requests, <String>[
      'POST /api/client/session/start-trial',
      'POST /api/tickets',
    ]);
    expect(ticketBody?['subject'], 'Connection help');
    expect(ticketBody?['body'], 'Cannot connect on first launch');
    expect(ticketBody?['media_type'], 'app_diagnostics');
    final mediaPayload = jsonDecode(ticketBody?['media_payload'] as String)
        as Map<String, dynamic>;
    expect(mediaPayload['platform'], 'windows');
    expect(mediaPayload['route_mode'], 'all_except_ru');
    expect(mediaPayload['connection_status'], 'Ready');
    expect(mediaPayload.containsKey('raw_config'), isFalse);
    expect(mediaPayload.containsKey('subscription_url'), isFalse);
    expect(ticketBody?['media_payload'], isNot(contains('vless://')));
    expect(ticketBody?['media_payload'], isNot(contains('secret.example')));
  });

  test(
      'support ticket service lists ticket threads and replies without resending diagnostics',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-support-thread-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    Map<String, dynamic>? replyBody;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final requestLabel = request.uri.hasQuery
            ? '${request.method} ${request.uri.path}?${request.uri.query}'
            : '${request.method} ${request.uri.path}';
        requests.add(requestLabel);
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'support-thread-token',
                    'account_id': 'thread-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.method == 'GET' && request.uri.path == '/api/tickets') {
          expect(request.uri.queryParameters['limit'], '5');
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer support-thread-token',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'tickets': <Object?>[
                    _supportTicketJson(
                      id: 654,
                      messages: <Object?>[
                        _supportMessageJson(
                          id: 1,
                          ticketId: 654,
                          senderRole: 'user',
                          body: 'Initial issue',
                        ),
                      ],
                    ),
                  ],
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.method == 'GET' && request.uri.path == '/api/tickets/654') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ticket': _supportTicketJson(
                    id: 654,
                    messages: <Object?>[
                      _supportMessageJson(
                        id: 1,
                        ticketId: 654,
                        senderRole: 'user',
                        body: 'Initial issue',
                      ),
                      _supportMessageJson(
                        id: 2,
                        ticketId: 654,
                        senderRole: 'admin',
                        body: 'Please try reconnecting.',
                      ),
                    ],
                  ),
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.method == 'POST' &&
            request.uri.path == '/api/tickets/654/messages') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer support-thread-token',
          );
          replyBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ticket': _supportTicketJson(
                    id: 654,
                    messages: <Object?>[
                      _supportMessageJson(
                        id: 1,
                        ticketId: 654,
                        senderRole: 'user',
                        body: 'Initial issue',
                      ),
                      _supportMessageJson(
                        id: 2,
                        ticketId: 654,
                        senderRole: 'admin',
                        body: 'Please try reconnecting.',
                      ),
                      _supportMessageJson(
                        id: 3,
                        ticketId: 654,
                        senderRole: 'user',
                        body: replyBody?['body'] as String? ?? '',
                      ),
                    ],
                  ),
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final service = AppFirstSupportTicketService(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final tickets = await service.listTickets(
      hostPlatform: HostPlatform.windows,
      limit: 5,
    );
    expect(tickets.single.id, 654);
    expect(tickets.single.messages.single.senderRole, 'user');

    final thread = await service.getTicket(
      hostPlatform: HostPlatform.windows,
      ticketId: 654,
    );
    expect(thread.messages.last.senderRole, 'admin');

    final updated = await service.sendMessage(
      hostPlatform: HostPlatform.windows,
      ticketId: 654,
      body: 'Follow up',
    );

    expect(updated.messages.last.body, 'Follow up');
    expect(replyBody?['body'], 'Follow up');
    expect(replyBody?.containsKey('media_type'), isFalse);
    expect(replyBody?.containsKey('media_payload'), isFalse);
    expect(requests, <String>[
      'POST /api/client/session/start-trial',
      'GET /api/tickets?limit=5',
      'GET /api/tickets/654',
      'POST /api/tickets/654/messages',
    ]);
  });

  test(
      'support ticket service can attach safe diagnostics to follow-up replies',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-support-reply-diagnostics-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    Map<String, dynamic>? replyBody;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final requestLabel = request.uri.hasQuery
            ? '${request.method} ${request.uri.path}?${request.uri.query}'
            : '${request.method} ${request.uri.path}';
        requests.add(requestLabel);
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'support-reply-diagnostics-token',
                    'account_id': 'reply-diagnostics-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.method == 'POST' &&
            request.uri.path == '/api/tickets/654/messages') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer support-reply-diagnostics-token',
          );
          replyBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ticket': _supportTicketJson(
                    id: 654,
                    messages: <Object?>[
                      _supportMessageJson(
                        id: 3,
                        ticketId: 654,
                        senderRole: 'user',
                        body: replyBody?['body'] as String? ?? '',
                        mediaType: replyBody?['media_type'] as String?,
                        mediaPayload: replyBody?['media_payload'] as String?,
                      ),
                    ],
                  ),
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final service = AppFirstSupportTicketService(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final updated = await service.sendMessage(
      hostPlatform: HostPlatform.windows,
      ticketId: 654,
      body: 'Follow up with diagnostics',
      routeMode: RouteMode.allExceptRu,
      statusLabel: 'Ready',
      diagnostics: const <String, Object?>{
        'app_version': pokrovClientVersion,
        'platform': 'windows',
        'route_mode': 'all_except_ru',
        'connection_status': 'Ready',
        'raw_config': 'vless://secret-value',
        'subscription_url': 'https://secret.example/sub',
      },
    );

    expect(updated.messages.single.mediaType, 'app_diagnostics');
    expect(replyBody?['body'], 'Follow up with diagnostics');
    expect(replyBody?['media_type'], 'app_diagnostics');
    final mediaPayload = jsonDecode(replyBody?['media_payload'] as String)
        as Map<String, dynamic>;
    expect(mediaPayload['platform'], 'windows');
    expect(mediaPayload['route_mode'], 'all_except_ru');
    expect(mediaPayload['connection_status'], 'Ready');
    expect(mediaPayload.containsKey('raw_config'), isFalse);
    expect(mediaPayload.containsKey('subscription_url'), isFalse);
    expect(replyBody?['media_payload'], isNot(contains('vless://')));
    expect(replyBody?['media_payload'], isNot(contains('secret.example')));
    expect(requests, <String>[
      'POST /api/client/session/start-trial',
      'POST /api/tickets/654/messages',
    ]);
  });

  test('redeems an activation code through the app-first unified endpoint',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-redeem-adapter-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    Map<String, dynamic>? redeemBody;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'redeem-session-token',
                    'account_id': 'redeem-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/redeem') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer redeem-session-token',
          );
          redeemBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'kind': 'access_key',
                  'code_preview': '...2026',
                  'result': <String, Object?>{
                    'access': <String, Object?>{
                      'access_state': 'paid_active',
                    },
                    'provisioning': <String, Object?>{
                      'status': 'ready',
                      'sync_ok': true,
                      'managed_profile_path': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final result = await bootstrapper.redeemCode(
      hostPlatform: HostPlatform.windows,
      code: 'POKROV-ACCESS-2026',
    );

    expect(result.ok, isTrue);
    expect(result.kind, 'access_key');
    expect(result.codePreview, '...2026');
    expect(result.result['access'], isA<Map<String, dynamic>>());
    expect(redeemBody?['code'], 'POKROV-ACCESS-2026');
    expect(requests, <String>[
      'POST /api/client/session/start-trial',
      'POST /api/redeem',
    ]);
  });

  test('claims a one-time device code without starting or persisting a trial',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-device-pairing-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    Map<String, dynamic>? claimBody;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/device-pairing/claim') {
          claimBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'access_token': 'paired-access-token',
                  'refresh_token': 'paired-refresh-token',
                  'canonical_account_id': 'paired-account-id',
                  'session': <String, Object?>{
                    'session_id': 'paired-session-id',
                    'account_id': 'paired-account-id',
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final sessionSecretStore = MemoryAppFirstSessionSecretStore();
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: sessionSecretStore,
    );

    final result = await bootstrapper.claimDevicePairingCode(
      hostPlatform: HostPlatform.windows,
      code: 'ABCD-9XYZ',
    );

    expect(result.ok, isTrue);
    expect(result.accountId, 'paired-account-id');
    expect(result.installId, startsWith('windows-'));
    expect(claimBody?['code'], 'ABCD9XYZ');
    expect(claimBody?['install_id'], result.installId);
    expect(requests, <String>['POST /api/client/device-pairing/claim']);

    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}app-first-session-windows.json',
    );
    final stateText = await stateFile.readAsString();
    expect(stateText, isNot(contains('ABCD9XYZ')));
    expect(stateText, isNot(contains('paired-access-token')));
    expect(stateText, isNot(contains('paired-refresh-token')));
    expect(
      await sessionSecretStore.readSessionToken(
        hostPlatform: HostPlatform.windows,
        installId: result.installId,
      ),
      'paired-access-token',
    );
  });

  test('creates a short-lived cabinet handoff through the app-first API',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-cabinet-handoff-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    Map<String, dynamic>? handoffBody;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'cabinet-session-token',
                    'account_id': 'cabinet-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/cabinet-token') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer cabinet-session-token',
          );
          handoffBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'token': 'short-cabinet-token',
                  'handoff_token': 'short-cabinet-token',
                  'expires_in': 120,
                  'target_path': '/profile',
                  'handoff_url':
                      'https://app.pokrov.space/profile?handoff_token=short-cabinet-token',
                  'auth_origin': 'app_cabinet_handoff',
                  'scope': 'cabinet_handoff',
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final handoff = await bootstrapper.createCabinetHandoff(
      hostPlatform: HostPlatform.windows,
      targetPath: '/profile',
    );

    expect(handoff.token, 'short-cabinet-token');
    expect(handoff.expiresIn.inSeconds, lessThanOrEqualTo(120));
    expect(handoff.handoffUrl.host, 'app.pokrov.space');
    expect(handoff.targetPath, '/profile');
    expect(handoff.scope, 'cabinet_handoff');
    expect(handoffBody?['target_path'], '/profile');
    expect(requests, <String>[
      'POST /api/client/session/start-trial',
      'POST /api/client/cabinet-token',
    ]);
  });

  test('creates a Telegram link through the app-first API', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-telegram-link-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'telegram-link-session',
                    'account_id': 'telegram-link-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/telegram/link') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer telegram-link-session',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'linked': false,
                  'linked_telegram_id': null,
                  'linked_telegram_username': null,
                  'start_code': 'app-link-2026',
                  'bot_url': 'https://t.me/pokrov_vpnbot?start=app-link-2026',
                  'channel_url': 'https://t.me/pokrov_vpn',
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final result = await bootstrapper.createTelegramLink(
      hostPlatform: HostPlatform.windows,
    );

    expect(result.ok, isTrue);
    expect(result.linked, isFalse);
    expect(result.startCode, 'app-link-2026');
    expect(result.botUrl.host, 't.me');
    expect(result.channelUrl?.path, '/pokrov_vpn');
    expect(requests, <String>[
      'POST /api/client/session/start-trial',
      'POST /api/client/telegram/link',
    ]);
  });

  test('checks and claims the Telegram channel bonus through app-first APIs',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-channel-bonus-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'channel-bonus-session',
                    'account_id': 'channel-bonus-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/channel/subscriber/check') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer channel-bonus-session',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'subscriber': true,
                  'reason': 'member',
                  'points_granted': 0,
                  'campaign_marked': false,
                  'link_required': false,
                  'claim_required': true,
                  'already_claimed': false,
                  'bonus_days': 5,
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/bonuses/channel/claim') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer channel-bonus-session',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'already_claimed': false,
                  'premium_days': 5,
                  'claimed_at': '2026-06-03T12:00:00Z',
                  'expiry_at': '2026-06-13T12:00:00Z',
                  'sub_type': 'BONUS',
                  'channel': '@pokrov_vpn',
                  'linked_telegram_id': 777001,
                  'linked_telegram_username': 'linked_user',
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final status = await bootstrapper.checkChannelBonus(
      hostPlatform: HostPlatform.windows,
    );
    final claim = await bootstrapper.claimChannelBonus(
      hostPlatform: HostPlatform.windows,
    );

    expect(status.ok, isTrue);
    expect(status.subscriber, isTrue);
    expect(status.claimRequired, isTrue);
    expect(status.bonusDays, 5);
    expect(claim.ok, isTrue);
    expect(claim.premiumDays, 5);
    expect(claim.subType, 'BONUS');
    expect(claim.claimedAt, '2026-06-03T12:00:00Z');
    expect(requests, <String>[
      'POST /api/client/session/start-trial',
      'POST /api/channel/subscriber/check',
      'POST /api/bonuses/channel/claim',
    ]);
  });

  test('fetches bonus summary through the app-first session', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bonus-summary-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'bonus-summary-session',
                    'account_id': 'bonus-summary-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/bonuses/summary') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer bonus-summary-session',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'referral_count': 2,
                  'referral_code': 'POKROV2',
                  'referral_bonus_days': 10,
                  'streak_months': 3,
                  'last_wheel_spin': null,
                  'channel_bonus_premium_days': 10,
                  'channel_bonus_claimed_at': '2026-06-03T12:00:00Z',
                  'channel_bonus': <String, Object?>{
                    'eligible': true,
                    'can_claim': false,
                    'reason': 'already_claimed',
                  },
                  'opening_bonus_premium_days': 5,
                  'opening_bonus_claimed': true,
                  'channel_username': 'pokrov_vpn',
                  'history': <String, Object?>{
                    'endpoint': '/api/bonuses/history',
                    'recent_count': 2,
                  },
                  'points_tier': <String, Object?>{
                    'tier_key': 'starter',
                    'percent': 5,
                    'paid_referrals': 2,
                    'next_tier_key': 'pro',
                    'next_tier_at': 5,
                  },
                  'wheel': <String, Object?>{
                    'ok': true,
                    'enabled': false,
                    'state': 'disabled_until_feature_flag',
                    'feature_flag': 'BONUS_WHEEL_ENABLED',
                    'feature_flag_enabled': false,
                    'spin_endpoint': '/api/bonuses/wheel/spin',
                    'last_spin_at': '2026-06-03T12:00:00Z',
                    'streak_months': 3,
                  },
                  'calendar': <String, Object?>{
                    'ok': true,
                    'enabled': false,
                    'state': 'disabled_until_reward_logic',
                    'feature_flag': 'BONUS_CALENDAR_ENABLED',
                    'feature_flag_enabled': true,
                    'checkin_endpoint': '/api/bonuses/calendar/checkin',
                    'last_wheel_spin': '2026-06-03T12:00:00Z',
                    'streak_months': 3,
                  },
                  'achievements': <String, Object?>{
                    'items': <Object?>[
                      <String, Object?>{
                        'id': 'first_tunnel',
                        'title': 'Первый туннель',
                        'description': 'Подключение подтверждено.',
                        'unlocked': true,
                      },
                    ],
                    'quests': <Object?>[
                      <String, Object?>{
                        'id': 'second_device',
                        'title': 'Добавить второе устройство',
                        'description': 'Свяжите ещё одно устройство.',
                        'progress': 1,
                        'target': 2,
                        'completed': false,
                        'action_href': '/devices/',
                        'verification': 'active_account_devices',
                      },
                    ],
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/bonuses/history') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer bonus-summary-session',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'items': <Object?>[
                    <String, Object?>{
                      'kind': 'promo',
                      'source': 'promo',
                      'title': 'Промокод активирован',
                      'occurred_at': '2026-06-03T12:30:00Z',
                      'days': 7,
                      'discount_pct': 0,
                      'code_preview': '...DAYS',
                    },
                    <String, Object?>{
                      'kind': 'telegram_channel',
                      'source': 'telegram',
                      'title': 'Telegram-бонус получен',
                      'occurred_at': '2026-06-03T12:00:00Z',
                      'days': 10,
                      'discount_pct': 0,
                    },
                  ],
                  'next_cursor': null,
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/bonuses/referral/summary') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer bonus-summary-session',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'count': 2,
                  'code': 'POKROV2',
                  'link': 'https://t.me/pokrov_vpnbot?start=ref_POKROV2',
                  'bonus_days': 10,
                  'tier': <String, Object?>{
                    'tier_key': 'starter',
                    'percent': 5,
                    'paid_referrals': 2,
                    'next_tier_key': 'pro',
                    'next_tier_at': 5,
                  },
                  'conversion': <String, Object?>{
                    'invited': 4,
                    'activated': 3,
                    'paid': 2,
                    'rewarded': 1,
                    'activation_pct': 75,
                    'paid_pct': 50,
                  },
                  'history': <Object?>[
                    <String, Object?>{
                      'id': 'ref-2',
                      'status': 'rewarded',
                      'created_at': '2026-06-02T12:00:00Z',
                      'activated_at': '2026-06-02T12:05:00Z',
                      'paid_at': '2026-06-03T12:00:00Z',
                      'hold_until': '2026-06-10T12:00:00Z',
                      'rewarded_at': '2026-06-10T12:00:00Z',
                    },
                  ],
                  'privacy': 'Имена и аккаунты приглашённых не показываются.',
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/promo-slots') {
          expect(request.uri.queryParameters['surface'], 'app');
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer bonus-summary-session',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'surface': 'app',
                  'access_state': 'trial_premium',
                  'remote_available': true,
                  'fallback_behavior':
                      'contextual_only_when_remote_unavailable',
                  'mode': 'whitelist_slots',
                  'server_time': DateTime.now().toUtc().toIso8601String(),
                  'slots': <Object?>[
                    <String, Object?>{
                      'slot_id': 'rewards_top',
                      'content_id': 'winback_offer',
                      'enabled': true,
                      'title': 'Telegram +5 days',
                      'body': 'Connect Telegram and claim the reward.',
                      'badge_label': 'Offer',
                      'image_url': 'https://cdn.example.com/promo.png',
                      'image_layout': 'media_only',
                      'media_type': 'video',
                      'media_url': 'https://cdn.example.com/promo.mp4',
                      'poster_url': 'https://cdn.example.com/poster.webp',
                      'fallback_image_url':
                          'https://cdn.example.com/fallback.webp',
                      'media_mime': 'video/mp4',
                      'media_width': 1080,
                      'media_height': 1080,
                      'media_bytes': 654321,
                      'media_duration_seconds': 12,
                      'autoplay': true,
                      'loop': false,
                      'cta_label': 'Open',
                      'cta_href': 'https://t.me/pokrov_vpnbot',
                      'accent_color': '#0B6B53',
                      'background_color': '#F4FAF7',
                      'text_color': '#10221C',
                      'button_color': '#0B6B53',
                      'button_text_color': '#FFFFFF',
                      'placement': 'home_banner',
                      'dismissible': false,
                      'whole_card_clickable': true,
                      'starts_at': '2026-06-01T00:00:00Z',
                      'ends_at': '2026-06-30T00:00:00Z',
                      'countdown_mode': 'ends_at',
                      'countdown_label': '−70% · осталось',
                      'kind': 'bonus',
                      'goal': 'bonus_claim',
                      'pilot_id': 'release_1_2_winback_paid_7_30d',
                      'pilot_revision': '2026-08-22.1',
                      'pilot_contract_sha256':
                          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                      'commercial_revision': '2026-08-21.1',
                      'campaign_id': 'cmp_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                      'offer_id': 'off_cccccccccccccccccccccccccccccccc',
                      'creative_id': 'crv_dddddddddddddddddddddddddddddddd',
                      'variant': 'a',
                      'assignment_id': 'asg_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
                      'impression_id': 'imp_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
                      'click_id': 'clk_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
                      'offer_state': 'ready',
                      'reason_code': 'ready',
                      'plan_code': '3_months',
                      'currency': 'RUB',
                      'base_price_rub': 669,
                      'final_price_rub': 602,
                      'benefit_percent': 10,
                      'remaining_quota_lower_bound': 20,
                      'terms_url': 'https://pokrov.space/offer/',
                    },
                    ...List<Object?>.generate(
                      5,
                      (index) => <String, Object?>{
                        'slot_id': 'extra-$index',
                        'content_id': 'partner_promo',
                        'enabled': true,
                        'title': 'Extra $index',
                        'body': '',
                        'placement': 'extra-$index',
                        'kind': 'promo',
                        'goal': 'open',
                      },
                    ),
                  ],
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final summary = await bootstrapper.fetchBonusSummary(
      hostPlatform: HostPlatform.windows,
    );

    expect(summary.referralCount, 2);
    expect(summary.referralCode, 'POKROV2');
    expect(summary.referralBonusDays, 10);
    expect(summary.streakMonths, 3);
    expect(summary.channelBonusClaimed, isTrue);
    expect(summary.channelBonusPremiumDays, 10);
    expect(summary.channelBonusEligible, isTrue);
    expect(summary.channelBonusCanClaim, isFalse);
    expect(summary.channelBonusReason, 'already_claimed');
    expect(summary.openingBonusClaimed, isTrue);
    expect(summary.tierKey, 'starter');
    expect(summary.nextTierAt, 5);
    expect(summary.wheelState.enabled, isFalse);
    expect(summary.wheelState.statusLabel, 'Недоступно');
    expect(summary.wheelState.actionEndpoint, '/api/bonuses/wheel/spin');
    expect(summary.wheelState.lastActionAt, '2026-06-03T12:00:00Z');
    expect(summary.calendarState.enabled, isFalse);
    expect(summary.calendarState.statusLabel, 'На проверке');
    expect(
      summary.calendarState.actionEndpoint,
      '/api/bonuses/calendar/checkin',
    );
    expect(summary.historyItems, hasLength(2));
    expect(summary.achievementItems, hasLength(1));
    expect(summary.achievementItems.single.id, 'first_tunnel');
    expect(summary.achievementItems.single.unlocked, isTrue);
    expect(summary.questItems, hasLength(1));
    expect(summary.questItems.single.id, 'second_device');
    expect(summary.questItems.single.progress, 1);
    expect(summary.questItems.single.target, 2);
    expect(summary.historyItems.first.kind, 'promo');
    expect(summary.historyItems.first.days, 7);
    expect(summary.historyItems.first.codePreview, '...DAYS');
    expect(summary.referralSummary.code, 'POKROV2');
    expect(summary.referralSummary.link,
        'https://t.me/pokrov_vpnbot?start=ref_POKROV2');
    expect(summary.referralSummary.bonusDays, 10);
    expect(summary.referralSummary.tierKey, 'starter');
    expect(summary.referralSummary.conversion.invited, 4);
    expect(summary.referralSummary.conversion.activated, 3);
    expect(summary.referralSummary.conversion.paidPct, 50);
    expect(summary.referralSummary.history, hasLength(1));
    expect(summary.referralSummary.history.single.status, 'rewarded');
    expect(summary.referralSummary.privacy, contains('не показываются'));
    expect(summary.promoSlots.remoteAvailable, isTrue);
    expect(summary.promoSlots.visibleSlots, hasLength(6));
    final primaryPromo = summary.promoSlots.visibleSlots.first;
    expect(summary.promoSlots.serverTime, isNotEmpty);
    expect(primaryPromo.title, 'Telegram +5 days');
    expect(primaryPromo.imageUrl, 'https://cdn.example.com/promo.png');
    expect(primaryPromo.badgeLabel, 'Offer');
    expect(primaryPromo.imageLayout, 'media_only');
    expect(primaryPromo.mediaType, 'video');
    expect(primaryPromo.mediaUrl, 'https://cdn.example.com/promo.mp4');
    expect(primaryPromo.posterUrl, 'https://cdn.example.com/poster.webp');
    expect(
        primaryPromo.fallbackImageUrl, 'https://cdn.example.com/fallback.webp');
    expect(primaryPromo.mediaMime, 'video/mp4');
    expect(primaryPromo.mediaWidth, 1080);
    expect(primaryPromo.mediaHeight, 1080);
    expect(primaryPromo.mediaBytes, 654321);
    expect(primaryPromo.mediaDurationSeconds, 12);
    expect(primaryPromo.autoplay, isTrue);
    expect(primaryPromo.loop, isFalse);
    expect(primaryPromo.countdownMode, 'ends_at');
    expect(primaryPromo.countdownLabel, '−70% · осталось');
    expect(primaryPromo.accentColor, '#0B6B53');
    expect(primaryPromo.buttonTextColor, '#FFFFFF');
    expect(primaryPromo.placement, 'home_banner');
    expect(primaryPromo.dismissible, isFalse);
    expect(primaryPromo.wholeCardClickable, isTrue);
    expect(primaryPromo.hasCommercialLineage, isTrue);
    expect(primaryPromo.pilotId, 'release_1_2_winback_paid_7_30d');
    expect(primaryPromo.campaignId, 'cmp_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
    expect(primaryPromo.impressionId, 'imp_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee');
    expect(primaryPromo.hasReadyCommercialOffer, isTrue);
    expect(primaryPromo.basePriceRub, 669);
    expect(primaryPromo.finalPriceRub, 602);
    expect(primaryPromo.remainingQuotaLowerBound, 20);
    expect(primaryPromo.termsUrl, 'https://pokrov.space/offer/');
    expect(summary.promoSlots.slots[1].hasCommercialLineage, isFalse);
    expect(summary.promoSlots.visibleForPlacement('home_banner'), hasLength(1));
    expect(
      primaryPromo.ctaHref,
      'https://t.me/pokrov_vpnbot',
    );
    expect(summary.historyItems.last.title, 'Telegram-бонус получен');
    expect(requests, <String>[
      'POST /api/client/session/start-trial',
      'GET /api/bonuses/summary',
      'GET /api/bonuses/history',
      'GET /api/bonuses/referral/summary',
      'GET /api/client/promo-slots',
    ]);
  });

  test('bonus feature action requires enabled feature flag', () {
    const inconsistentBackendState = AppFirstBonusFeatureState(
      ok: true,
      enabled: true,
      state: 'ready',
      featureFlag: 'BONUS_WHEEL_ENABLED',
      featureFlagEnabled: false,
      actionEndpoint: '/api/bonuses/wheel/spin',
      lastActionAt: '',
      streakMonths: 0,
    );

    expect(inconsistentBackendState.canRun, isFalse);
    expect(inconsistentBackendState.statusLabel, 'Недоступно');
    expect(
      inconsistentBackendState.availabilityText,
      'POKROV покажет эту возможность, когда она станет доступна',
    );
  });

  test('does not retry a temporary 502 during start-trial', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-retry-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    var startTrialAttempts = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          startTrialAttempts += 1;
          request.response
            ..statusCode = HttpStatus.badGateway
            ..headers.contentType = ContentType.text
            ..write('temporary upstream outage');
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-retry',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      delayScheduler: (_) async {},
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(
        isA<BootstrapFailure>()
            .having((error) => error.statusCode, 'statusCode',
                HttpStatus.badGateway)
            .having(
              (error) => error.operation,
              'operation',
              'POST /api/client/session/start-trial',
            ),
      ),
    );

    expect(startTrialAttempts, 1);
  });

  test('refreshes an expired access session without starting a second trial',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-refresh-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists())
        await tempDirectory.delete(recursive: true);
    });
    var starts = 0;
    var refreshes = 0;
    var profiles = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        final path = request.uri.path;
        if (path == '/api/client/session/start-trial') {
          starts += 1;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'access_token': 'expired-access',
              'refresh_token': 'refresh-one',
              'account_id': '42',
              'session': <String, Object?>{'session_token': 'expired-access'},
              'provisioning': <String, Object?>{
                'status': 'ready',
                'sync_ok': true
              },
            }));
        } else if (path == '/api/client/session/refresh') {
          refreshes += 1;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'access_token': 'fresh-access',
              'refresh_token': 'refresh-two',
              'account_id': '42',
            }));
        } else if (path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write('{"ok":true}');
        } else if (path == '/api/client/profile/managed') {
          profiles += 1;
          if (profiles == 1)
            request.response.statusCode = HttpStatus.unauthorized;
          request.response
            ..headers.contentType = ContentType.json
            ..write(profiles == 1
                ? '{"detail":"expired"}'
                : jsonEncode(_readyManagedProfile('refresh')));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      delayScheduler: (_) async {},
    );
    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    expect(payload.profileName, 'pokrov-windows-refresh');
    expect(starts, 1);
    expect(refreshes, 1);
  });

  test('keeps pending-sync credentials for a later managed-profile retry',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-pending-sync-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists())
        await tempDirectory.delete(recursive: true);
    });
    var starts = 0;
    var profiles = 0;
    final secretStore = MemoryAppFirstSessionSecretStore();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          starts += 1;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'access_token': 'pending-access',
              'refresh_token': 'pending-refresh',
              'account_id': '84',
              'provisioning': <String, Object?>{
                'status': 'pending_sync',
                'sync_ok': false
              },
            }));
        } else if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write('{"ok":true}');
        } else if (request.uri.path == '/api/client/profile/managed') {
          profiles += 1;
          final pending = profiles == 1;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
                jsonEncode(_readyManagedProfile('pending', pending: pending)));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: secretStore,
      delayScheduler: (_) async {},
    );
    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(isA<BootstrapFailure>().having(
        (failure) => failure.operationalErrorCode,
        'provisioning observation',
        'API-011',
      )),
    );
    expect(starts, 1);
    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    expect(payload.profileName, 'pokrov-windows-pending');
    expect(starts, 1);
  });

  test('retries access preparation without starting another trial', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-access-preparing-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) await tempDirectory.delete(recursive: true);
    });
    var starts = 0;
    var profiles = 0;
    var profileResolved = false;
    var stallAfterPreparing = false;
    var pendingBeforeStall = true;
    HttpResponse? heldProfile;
    final delays = <Duration>[];
    String? profileRunId;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/client/session/start-trial') {
          starts += 1;
          request.response.write(jsonEncode(<String, Object?>{
            'access_token': 'preparing-access',
            'refresh_token': 'preparing-refresh',
            'account_id': '85',
          }));
        } else if (request.uri.path == '/api/client/route-policy') {
          request.response.write('{"ok":true}');
        } else if (request.uri.path == '/api/client/profile/managed') {
          expect(request.headers.value('X-POKROV-Access-Preparing'), '1');
          final runId = request.uri.queryParameters['report_run_id'];
          expect(runId, matches(RegExp(r'^[0-9a-f-]{36}$')));
          profileRunId ??= runId;
          expect(runId, profileRunId);
          profiles += 1;
          if (profiles < 12 || (stallAfterPreparing && pendingBeforeStall)) {
            if (stallAfterPreparing) pendingBeforeStall = false;
            if (profiles < 12) expect(profileResolved, isFalse);
            request.response.statusCode = HttpStatus.accepted;
            request.response.write(jsonEncode(<String, Object?>{
              'status': 'access_preparing', 'retry_after_seconds': 2,
            }));
          } else if (stallAfterPreparing) {
            heldProfile = request.response;
            continue;
          } else {
            request.response.write(jsonEncode({
              ..._readyManagedProfile('prepared'),
              'access_network': {'asn': 'AS12345'},
            }));
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      maxRequestAttempts: 1,
      delayScheduler: (delay) async => delays.add(delay),
    );
    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
      timeout: const Duration(seconds: 40),
    ).then((payload) {
      profileResolved = true;
      return payload;
    });
    expect(payload.profileName, 'pokrov-windows-prepared');
    expect(payload.accessNetworkAsn, 'AS12345');
    expect(starts, 1);
    expect(profiles, 12);
    expect(delays, List.filled(11, const Duration(seconds: 2)));
    expect(delays.fold(Duration.zero, (total, delay) => total + delay),
        const Duration(seconds: 22));
    stallAfterPreparing = true;
    await expectLater(bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
      timeout: const Duration(milliseconds: 250),
    ), throwsA(isA<BootstrapFailure>()
        .having((failure) => failure.code, 'code', 'access_preparing')
        .having((failure) => failure.operationalErrorCode, 'operational code', 'API-011')
        .having((failure) => failure.message, 'explicit retry', contains('Нажмите «Подключить»'))));
    expect(heldProfile, isNotNull);
    stallAfterPreparing = false;
    try {
      heldProfile!.write(jsonEncode(_readyManagedProfile('late-ack')));
      await heldProfile!.close();
    } on Object {
      // The expired client has already closed this response.
    }
    final retried = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows, routeMode: RouteMode.fullTunnel,
      timeout: const Duration(seconds: 40),
    );
    expect(retried.profileName, 'pokrov-windows-prepared');
    expect(starts, 1, reason: 'explicit retry keeps the original trial session');
  });

  test('refresh failure never starts a second trial for an existing install',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-refresh-failure-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists())
        await tempDirectory.delete(recursive: true);
    });
    var starts = 0;
    var refreshes = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          starts += 1;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'access_token': 'expired-access',
              'refresh_token': 'refresh-one',
              'account_id': '42',
              'provisioning': <String, Object?>{
                'status': 'ready',
                'sync_ok': true
              },
            }));
        } else if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write('{"ok":true}');
        } else if (request.uri.path == '/api/client/profile/managed') {
          request.response.statusCode = HttpStatus.unauthorized;
        } else if (request.uri.path == '/api/client/session/refresh') {
          refreshes += 1;
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..headers.set('X-POKROV-Auth-Error', 'fresh_auth_required');
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      delayScheduler: (_) async {},
    );
    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(
        isA<BootstrapFailure>()
            .having(
              (error) => error.message,
              'message',
              contains('восстановить доступ'),
            )
            .having(
              (error) => error.code,
              'code',
              'fresh_auth_required',
            ),
      ),
    );
    expect(starts, 1);
    expect(refreshes, 1);
  });

  test(
      'temporary refresh failure remains manually retryable and retains the session pair',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-refresh-temporary-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists())
        await tempDirectory.delete(recursive: true);
    });
    var starts = 0;
    var refreshes = 0;
    var profiles = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            starts += 1;
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(<String, Object?>{
                'access_token': 'expired-access',
                'refresh_token': 'refresh-one',
                'account_id': '42',
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true
                },
              }));
          case '/api/client/route-policy':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"ok":true}');
          case '/api/client/profile/managed':
            profiles += 1;
            if (profiles <= 2)
              request.response.statusCode = HttpStatus.unauthorized;
            request.response
              ..headers.contentType = ContentType.json
              ..write(profiles <= 2
                  ? '{"detail":"expired"}'
                  : jsonEncode(_readyManagedProfile('refreshed')));
          case '/api/client/session/refresh':
            refreshes += 1;
            if (refreshes == 1) {
              request.response.statusCode = HttpStatus.serviceUnavailable;
              request.response.write('temporary outage');
            } else {
              request.response
                ..headers.contentType = ContentType.json
                ..write(jsonEncode(<String, Object?>{
                  'access_token': 'fresh-access',
                  'refresh_token': 'refresh-two',
                  'account_id': '42',
                }));
            }
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      delayScheduler: (_) async {},
    );
    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(isA<BootstrapFailure>().having(
        (error) => error.statusCode,
        'statusCode',
        HttpStatus.serviceUnavailable,
      )),
    );
    expect(starts, 1);
    expect(refreshes, 1);
    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    expect(payload.profileName, 'pokrov-windows-refreshed');
    expect(starts, 1);
    expect(refreshes, 2);
  });

  test(
      'captures only normalized platform error codes without changing user copy',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-error-code-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final errorHeaders = <String?>[
      'device_recovery_required',
      'Auth_Session_Expired',
      'invalid-code',
      'a' * 65,
      null,
    ];
    var requestIndex = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        final header = errorHeaders[requestIndex];
        final headerName =
            requestIndex == 0 ? 'x-pOkRoV-aUtH-eRrOr' : 'X-POKROV-Auth-Error';
        requestIndex += 1;
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..headers.contentType = ContentType.json;
        if (header != null) {
          request.response.headers.set(headerName, header);
        }
        request.response.write('{"detail":"Обновите сессию."}');
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      delayScheduler: (_) async {},
      maxRequestAttempts: 1,
    );

    final failures = <BootstrapFailure>[];
    for (var index = 0; index < errorHeaders.length; index += 1) {
      try {
        await bootstrapper.resolveManagedProfile(
          hostPlatform: HostPlatform.windows,
          routeMode: RouteMode.fullTunnel,
        );
        fail('Expected BootstrapFailure');
      } on BootstrapFailure catch (error) {
        failures.add(error);
      }
    }

    expect(requestIndex, errorHeaders.length);
    expect(
      failures.map((failure) => failure.code),
      <String>[
        'device_recovery_required',
        'auth_session_expired',
        '',
        '',
        '',
      ],
    );
    for (final failure in failures) {
      expect(failure.statusCode, HttpStatus.unauthorized);
      expect(failure.operation, 'POST /api/client/session/start-trial');
      expect(failure.message, 'Обновите сессию.');
      expect(failure.message, isNot(contains('device_recovery_required')));
      expect(failure.message, isNot(contains('auth_session_expired')));
    }
  });

  test('keeps the service failure copy when a platform error code is present',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-service-error-code-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..headers.contentType = ContentType.json;
        request.response.headers
            .set('X-POKROV-Auth-Error', 'node_capacity_exhausted');
        request.response.write('{"detail":"internal detail"}');
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      delayScheduler: (_) async {},
      maxRequestAttempts: 1,
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(
        isA<BootstrapFailure>()
            .having(
              (error) => error.code,
              'code',
              'node_capacity_exhausted',
            )
            .having(
              (error) => error.message,
              'message',
              'Сервис подготовки временно недоступен. Попробуйте ещё раз.',
            ),
      ),
    );
  });

  test('shares a rotated refresh session across concurrent API flows',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-refresh-single-flight-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    const installId = 'refresh-single-flight-install';
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    );
    await stateFile.writeAsString(jsonEncode(<String, Object?>{
      'install_id': installId,
      'session_token_storage': 'secure',
      'account_id': '42',
      'managed_manifest_path': '/api/client/profile/managed',
      'profile_revision': '',
    }));
    final secretStore = MemoryAppFirstSessionSecretStore();
    await secretStore.writeSessionPair(
      hostPlatform: HostPlatform.windows,
      installId: installId,
      pair: const AppFirstSessionCredentials(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      ),
    );
    var refreshes = 0;
    var starts = 0;
    var oldAccessRequests = 0;
    final firstRefreshStarted = Completer<void>();
    final bothOldAccessRequests = Completer<void>();
    final releaseRefresh = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    Future<void> handle(HttpRequest request) async {
      await utf8.decoder.bind(request).join();
      final path = request.uri.path;
      if (path == '/api/client/session/start-trial') {
        starts += 1;
        request.response.statusCode = HttpStatus.notFound;
      } else if (path == '/api/client/session/refresh') {
        refreshes += 1;
        if (refreshes == 1) {
          firstRefreshStarted.complete();
          await bothOldAccessRequests.future;
          await releaseRefresh.future;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'access_token': 'rotated-access',
              'refresh_token': 'rotated-refresh',
              'account_id': '42',
            }));
        } else {
          request.response.statusCode = HttpStatus.unauthorized;
        }
      } else {
        final authorization =
            request.headers.value(HttpHeaders.authorizationHeader);
        if (authorization != 'Bearer rotated-access') {
          oldAccessRequests += 1;
          if (oldAccessRequests == 2) {
            bothOldAccessRequests.complete();
          }
          request.response.statusCode = HttpStatus.unauthorized;
        } else if (path == '/api/client/devices') {
          request.response
            ..headers.contentType = ContentType.json
            ..write('{"devices":[]}');
        } else if (path == '/api/client/cabinet-token') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              '{"token":"cabinet-token","handoff_url":"https://cabinet.pokrov.space/","expires_in":60}',
            );
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
      }
      await request.response.close();
    }

    unawaited(() async {
      await for (final request in server) {
        unawaited(handle(request));
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: secretStore,
      delayScheduler: (_) async {},
      maxRequestAttempts: 1,
    );
    final devices = bootstrapper.fetchClientDevices(
      hostPlatform: HostPlatform.windows,
    );
    final handoff = bootstrapper.createCabinetHandoff(
      hostPlatform: HostPlatform.windows,
    );

    await firstRefreshStarted.future;
    await bothOldAccessRequests.future;
    expect(refreshes, 1);
    releaseRefresh.complete();
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      devices,
      handoff,
    ]);

    expect((results[1] as CabinetHandoff).token, 'cabinet-token');
    expect(refreshes, 1);
    expect(starts, 0);
    final pair = await secretStore.readSessionPair(
      hostPlatform: HostPlatform.windows,
      installId: installId,
    );
    expect(pair?.accessToken, 'rotated-access');
    expect(pair?.refreshToken, 'rotated-refresh');
  });

  test('shares a retryable refresh failure without starting another trial',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-refresh-single-flight-failure-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    const installId = 'refresh-single-flight-failure-install';
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    );
    await stateFile.writeAsString(jsonEncode(<String, Object?>{
      'install_id': installId,
      'session_token_storage': 'secure',
      'account_id': '42',
      'managed_manifest_path': '/api/client/profile/managed',
      'profile_revision': '',
    }));
    final secretStore = MemoryAppFirstSessionSecretStore();
    await secretStore.writeSessionPair(
      hostPlatform: HostPlatform.windows,
      installId: installId,
      pair: const AppFirstSessionCredentials(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      ),
    );
    var refreshes = 0;
    var starts = 0;
    var oldAccessRequests = 0;
    final firstRefreshStarted = Completer<void>();
    final bothOldAccessRequests = Completer<void>();
    final releaseRefresh = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    Future<void> handle(HttpRequest request) async {
      await utf8.decoder.bind(request).join();
      if (request.uri.path == '/api/client/session/start-trial') {
        starts += 1;
        request.response.statusCode = HttpStatus.notFound;
      } else if (request.uri.path == '/api/client/session/refresh') {
        refreshes += 1;
        if (refreshes == 1) {
          firstRefreshStarted.complete();
          await bothOldAccessRequests.future;
          await releaseRefresh.future;
          request.response
            ..statusCode = HttpStatus.serviceUnavailable
            ..write('temporary refresh outage');
        } else {
          request.response.statusCode = HttpStatus.unauthorized;
        }
      } else {
        oldAccessRequests += 1;
        if (oldAccessRequests == 2) {
          bothOldAccessRequests.complete();
        }
        request.response.statusCode = HttpStatus.unauthorized;
      }
      await request.response.close();
    }

    unawaited(() async {
      await for (final request in server) {
        unawaited(handle(request));
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: secretStore,
      delayScheduler: (_) async {},
      maxRequestAttempts: 1,
    );
    final devices = bootstrapper.fetchClientDevices(
      hostPlatform: HostPlatform.windows,
    );
    final handoff = bootstrapper.createCabinetHandoff(
      hostPlatform: HostPlatform.windows,
    );

    await firstRefreshStarted.future;
    await bothOldAccessRequests.future;
    expect(refreshes, 1);
    releaseRefresh.complete();
    await Future.wait<void>(<Future<void>>[
      expectLater(
        devices,
        throwsA(isA<BootstrapFailure>().having(
          (error) => error.statusCode,
          'statusCode',
          HttpStatus.serviceUnavailable,
        )),
      ),
      expectLater(
        handoff,
        throwsA(isA<BootstrapFailure>().having(
          (error) => error.statusCode,
          'statusCode',
          HttpStatus.serviceUnavailable,
        )),
      ),
    ]);

    expect(refreshes, 1);
    expect(starts, 0);
    final pair = await secretStore.readSessionPair(
      hostPlatform: HostPlatform.windows,
      installId: installId,
    );
    expect(pair?.accessToken, 'old-access');
    expect(pair?.refreshToken, 'old-refresh');
  });

  test('route-policy server failure aborts without a manifest or new session',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-route-policy-failure-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    var starts = 0;
    var refreshes = 0;
    var routePolicies = 0;
    var profiles = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            starts += 1;
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(<String, Object?>{
                'access_token': 'route-policy-access',
                'refresh_token': 'route-policy-refresh',
                'account_id': '64',
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true,
                },
              }));
          case '/api/client/session/refresh':
            refreshes += 1;
            request.response.statusCode = HttpStatus.internalServerError;
          case '/api/client/route-policy':
            routePolicies += 1;
            request.response
              ..statusCode = HttpStatus.serviceUnavailable
              ..headers.contentType = ContentType.json
              ..write('{"detail":"route policy unavailable"}');
          case '/api/client/profile/managed':
            profiles += 1;
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_readyManagedProfile('unexpected')));
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      delayScheduler: (_) async {},
      maxRequestAttempts: 1,
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(
        isA<BootstrapFailure>()
            .having(
              (error) => error.statusCode,
              'statusCode',
              HttpStatus.serviceUnavailable,
            )
            .having(
              (error) => error.message,
              'message',
              'Сервис подготовки временно недоступен. Попробуйте ещё раз.',
            ),
      ),
    );
    expect(starts, 1);
    expect(refreshes, 0);
    expect(routePolicies, 1);
    expect(profiles, 0);
  });

  test('rejects unsafe backend detail and non-JSON error bodies', () async {
    final traces = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.startsWith('POKROV_BOOTSTRAP ')) {
        traces.add(message);
      }
    };
    addTearDown(() => debugPrint = previousDebugPrint);
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-unsafe-error-detail-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(<String, Object?>{
                'session': <String, Object?>{
                  'session_token': 'unsafe-detail-access',
                  'refresh_token': 'unsafe-detail-refresh',
                  'account_id': '65',
                },
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true,
                },
              }));
          case '/api/client/route-policy':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"ok":true}');
          case '/api/client/profile/managed':
            request.response
              ..statusCode = HttpStatus.badRequest
              ..headers.contentType = ContentType.json
              ..headers.set('X-POKROV-Error', 'private_session_material')
              ..write(
                '{"detail":"SocketException: https://10.24.0.5:443/vless?token=secret"}',
              );
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      delayScheduler: (_) async {},
      maxRequestAttempts: 1,
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(
        isA<BootstrapFailure>().having(
          (error) => error.message,
          'message',
          'Не удалось выполнить запрос. Попробуйте ещё раз.',
        ),
      ),
    );
    final events = traces.map((line) =>
      jsonDecode(line.substring('POKROV_BOOTSTRAP '.length)) as Map<String, dynamic>)
      .toList();
    expect(events.singleWhere((event) => event['stage'] == 'managed_http' &&
      event['outcome'] == 'fail'), <String, Object?>{
      'stage': 'managed_http', 'outcome': 'fail',
      'reason': 'other_platform_code', 'status': 400,
      'operationalCode': 'API-008', 'exceptionClass': 'BootstrapFailure',
    });
    expect(events.any((event) => event['stage'] == 'pair_persist' &&
      event['outcome'] == 'readback' && event['pairPresent'] == true), isTrue);
    for (final event in events) {
      expect(event.keys.toSet().difference(<String>{'stage', 'outcome', 'reason',
        'status', 'operationalCode', 'exceptionClass', 'pairPresent'}), isEmpty);
    }
    final traceText = traces.join();
    for (final privateValue in <String>['unsafe-detail-access',
      'unsafe-detail-refresh', 'private_session_material',
      '10.24.0.5', '127.0.0.1', 'token=secret', '/api/client/']) {
      expect(traceText, isNot(contains(privateValue)));
    }
  });

  test('managed-profile generic 500 exposes a safe retryable error', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-managed-profile-500-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(<String, Object?>{
                'session': <String, Object?>{
                  'session_token': 'managed-profile-access',
                  'account_id': '65',
                },
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true,
                },
              }));
          case '/api/client/route-policy':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"ok":true}');
          case '/api/client/profile/managed':
            request.response
              ..statusCode = HttpStatus.internalServerError
              ..write('Internal Server Error');
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      delayScheduler: (_) async {},
      maxRequestAttempts: 1,
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(
        isA<BootstrapFailure>()
            .having(
              (error) => error.statusCode,
              'statusCode',
              HttpStatus.internalServerError,
            )
            .having(
              (error) => error.operation,
              'operation',
              startsWith('GET /api/client/profile/managed?report_run_id='),
            )
            .having(
              (error) => error.message,
              'message',
              'Сервис подготовки временно недоступен. Попробуйте ещё раз.',
            ),
      ),
    );
  });

  test(
      'materializes a tunnel-ready runtime config from an outbounds-only profile',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-materialize-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-3',
                    'account_id': '126',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-materialized',
                  'config_format': 'singbox-json',
                  'support_context': <String, Object?>{
                    'reality_tls_fragment': <String, Object?>{
                      'enabled': true,
                      'fragment': true,
                      'record_fragment': true,
                      'fragment_fallback_delay': '250ms',
                    },
                  },
                  'config_payload': <String, Object?>{
                    '_meta': <String, Object?>{
                      'source': 'managed',
                    },
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'legacy-reality-fallback',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                        'tcp_fast_open': true,
                        'tls': <String, Object?>{
                          'enabled': true,
                          'server_name': 'www.cloudflare.com',
                          'reality': <String, Object?>{
                            'enabled': true,
                            'public_key': 'test-public-key',
                            'short_id': '0123456789abcdef',
                          },
                        },
                      },
                    ],
                    'route': <String, Object?>{
                      'rules': <Object?>[
                        <String, Object?>{
                          'rule_set': <String>['geoip-ru'],
                          'outbound': 'direct',
                        },
                        <String, Object?>{
                          'process_name': <String>['steam.exe'],
                          'outbound': 'direct',
                        },
                        <String, Object?>{
                          'ip_is_private': true,
                          'outbound': 'direct',
                        },
                      ],
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final inbounds = (config['inbounds'] as List).cast<Map<String, dynamic>>();
    final outbounds =
        (config['outbounds'] as List).cast<Map<String, dynamic>>();
    final realityOutbound = outbounds.singleWhere(
      (outbound) => outbound['tag'] == 'legacy-reality-fallback',
    );
    final realityTls = realityOutbound['tls'] as Map<String, dynamic>;
    final route = config['route'] as Map<String, dynamic>;
    final routeRules = (route['rules'] as List).cast<Map<String, dynamic>>();
    final dns = config['dns'] as Map<String, dynamic>;
    final dnsServers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    final tunInbound =
        inbounds.singleWhere((inbound) => inbound['type'] == 'tun');

    expect(inbounds, hasLength(1));
    expect(payload.disableMemoryLimit, isTrue);
    expect(payload.configPayload, isNot(contains('12334')));
    expect(tunInbound['stack'], 'system');
    expect(tunInbound['address'], isNotEmpty);
    expect(tunInbound.containsKey('inet4_address'), isFalse);
    expect(tunInbound.containsKey('endpoint_independent_nat'), isFalse);
    expect(tunInbound.containsKey('sniff'), isFalse);
    expect(tunInbound.containsKey('domain_strategy'), isFalse);
    expect(inbounds.where((inbound) => inbound['tag'] == 'dns-in'), isEmpty);
    expect(config.containsKey('_meta'), isFalse);
    expect(route['final'], 'select');
    expect(route['auto_detect_interface'], true);
    expect(route.containsKey('override_android_vpn'), isFalse);
    expect(routeRules.first, <String, dynamic>{
      'port': 53,
      'action': 'hijack-dns',
    });
    expect(routeRules[1], <String, dynamic>{'action': 'sniff'});
    expect(
      routeRules.indexWhere((rule) => rule['ip_is_private'] == true),
      greaterThan(1),
    );
    expect(
      routeRules.any((rule) =>
          (rule['rule_set'] as List?)?.contains('geoip-ru') == true &&
          rule['outbound'] == 'direct'),
      isFalse,
    );
    expect(
      routeRules.any((rule) =>
          (rule['process_name'] as List?)?.contains('steam.exe') == true &&
          rule['outbound'] == 'direct'),
      isFalse,
    );
    expect(
      routeRules.any((rule) =>
          rule['ip_is_private'] == true && rule['outbound'] == 'direct'),
      isTrue,
    );
    expect(route['default_domain_resolver'], <String, dynamic>{
      'server': 'dns-direct',
      'strategy': 'ipv4_only',
    });
    expect(dns['final'], 'dns-remote');
    expect(
      dnsServers.singleWhere((server) => server['tag'] == 'dns-remote'),
      containsPair('type', 'tcp'),
    );
    expect(
      dnsServers.singleWhere((server) => server['tag'] == 'dns-direct'),
      containsPair('type', 'udp'),
    );
    expect(
      outbounds.where((outbound) => outbound['type'] == 'dns'),
      isEmpty,
    );
    expect(config['outbounds'].toString(), contains('urltest'));
    expect(realityTls['fragment'], true);
    expect(realityTls['record_fragment'], true);
    expect(realityTls['fragment_fallback_delay'], '250ms');
    expect(realityOutbound['tcp_fast_open'], false);
  });

  test('ordinary UDP candidates reach runtime staging through the managed API', () async {
    final originalHttpOverrides = HttpOverrides.current;
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = originalHttpOverrides;
    final directory = await Directory.systemTemp.createTemp('pokrov-ordinary-udp-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Map? staged;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.stageManagedProfile') {
        staged = jsonDecode((call.arguments as Map)['configPayload'] as String) as Map;
        return {'phase': 'configStaged', 'stagedConfigPath': '/host/synthetic-profile.json',
          'supportsLiveConnect': true, 'canInitialize': true, 'canConnect': true};
      }
      return null;
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    var awg = true;
    final queries = <Map<String, String>>[];
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response.write(jsonEncode({
            'session': {'session_token': 'ordinary-test-session', 'account_id': 'ordinary-test'},
            'provisioning': {'status': 'ready', 'sync_ok': true},
          }));
        } else if (request.uri.path == '/api/client/profile/managed') {
          queries.add(request.uri.queryParameters);
          final profile = awg ? 'awg31_lab' : 'hy2_lab';
          final protocol = awg ? 'awg' : 'hysteria2';
          final tag = 'secure-transport';
          request.response.write(jsonEncode({
            ..._readyManagedProfile('udp-revision'),
            'transport_profile': profile, 'transport_kind': awg ? 'awg31' : 'hysteria2',
            'client_policy': {'transport_profile': 'legacy_reality_fallback'},
            'transport_catalog': {
              'schema_version': 'pokrov-transport-catalog-v1', 'revision': 'udp-revision',
              'selected_candidate_ref': 'de:$profile', 'candidates': [{
                'candidate_ref': 'de:$profile', 'profile_ref': profile, 'node_code': 'de',
                'country_code': 'DE', 'protocol': protocol, 'transport': 'udp',
                'protection': awg ? 'awg31' : 'tls', 'priority': 0,
                'parameters': {'network': 'udp', 'flow': ''},
                'requirements': {'minimum_client_release': '1.2.0', 'minimum_core_release': null,
                  'platforms': ['android', 'windows'], 'required_features': [
                    awg ? 'pokrov_awg31_endpoint_v1' : 'singbox_hysteria2_v1']},
              }],
            },
            'smart_connect': {'eligible': true, 'shortlist': [{'code': 'de', 'country': 'DE'}]},
            'config_payload': {
              '_meta': {'transport_contract': {
                'id': awg ? 'pokrov.awg31.endpoint.v1' : 'pokrov.hy2.outbound.v1',
                'sha256': awg
                    ? '1bb49b61549ba7c4a3c2d56df445e919ebb1ed12d42e04b0cb3c915d23240818'
                    : 'c96b38e58ea33f838f23b80a65f3a9a264e932b7248f206798df9a0b8fa0fb98',
                'profile': profile, 'state': 'enabled', 'generation': 'ordinary-v1',
              }},
              if (awg) 'endpoints': [{'type': 'awg', 'tag': tag,
                'contract_id': 'pokrov.awg31.endpoint.v1', 'useIntegratedTun': false}],
              if (awg) 'dns': {
                'strategy': 'ipv4_only',
                'servers': [
                  {'tag': 'bootstrap', 'address': 'local'},
                  {'tag': 'cloudflare', 'address': 'https://1.1.1.1/dns-query', 'detour': tag},
                ],
                'final': 'cloudflare',
              },
              'outbounds': [
                if (!awg) {'type': 'hysteria2', 'tag': tag,
                  'server': 'hy2.example.invalid', 'server_port': 443,
                  'password': 'synthetic-password', 'up_mbps': 10, 'down_mbps': 50,
                  'tls': {'enabled': true, 'server_name': 'hy2.example.invalid',
                    'insecure': false, 'alpn': ['h3']}},
                {'type': 'direct', 'tag': 'direct'},
              ],
              'route': {'final': tag},
            },
          }));
        } else {
          request.response.write('{"ok":true}');
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/', supportDirectoryResolver: () async => directory,
      sessionSecretStore: MemoryAppFirstSessionSecretStore(), maxRequestAttempts: 1,
    );
    for (final scenario in [
      (HostPlatform.android, true, RouteMode.fullTunnel),
      (HostPlatform.windows, true, RouteMode.fullTunnel),
      (HostPlatform.android, false, RouteMode.fullTunnel),
      (HostPlatform.windows, false, RouteMode.selectedApps),
    ]) {
      awg = scenario.$2;
      final profile = awg ? 'awg31_lab' : 'hy2_lab';
      final payload = await bootstrapper.resolveManagedProfile(hostPlatform: scenario.$1,
        routeMode: scenario.$3, selectedApps: scenario.$3 == RouteMode.selectedApps ? ['browser.exe'] : [],
        runtimeFeatures: RuntimeTransportFeature.values.toSet(),
        selectedCandidateRef: 'de:$profile', selectCandidate: false, cacheResult: false);
      expect(queries.last['catalog_version'], '1');
      expect(queries.last['selected_candidate_ref'], 'de:$profile');
      expect(payload.transportCatalog?.selectedCandidateRef, 'de:$profile');
      expect(payload.resolvedNodeCode, 'de');
      expect(payload.smartConnect?.shortlist.single.code, 'de');
      final stagedPayload = awg ? applyPokrovRoutingPreferences(payload,
        const PokrovRoutingPreferences.defaults(), hostPlatform: scenario.$1) : payload;
      final config = jsonDecode(stagedPayload.configPayload) as Map;
      expect(config['_meta']?['transport_contract']?['profile'], profile);
      expect(config['route']['final'], scenario.$3 == RouteMode.selectedApps ? 'direct' : 'secure-transport');
      if (awg) {
        final expectedResolver = scenario.$1 == HostPlatform.windows ? 'dns-remote' : 'cloudflare';
        expect((config['endpoints'] as List).single['domain_resolver'],
          {'server': expectedResolver, 'strategy': 'ipv4_only'});
        final remoteDns = (config['dns']['servers'] as List)
          .singleWhere((row) => row['tag'] == expectedResolver);
        expect(remoteDns['type'], 'https');
        expect(remoteDns['server'], '1.1.1.1');
        expect(remoteDns['detour'], 'secure-transport');
        if (scenario.$1 == HostPlatform.windows) {
          expect(config['route']['default_domain_resolver'],
            {'server': 'dns-direct', 'strategy': 'ipv4_only'});
        }
      }
      if (!awg && scenario.$1 == HostPlatform.android) {
        final outbound = (config['outbounds'] as List).singleWhere((row) => row['type'] == 'hysteria2') as Map;
        expect(outbound['domain_resolver'], 'dns-local');
      }
      await expectLater(createRuntimeEngine(hostPlatform: scenario.$1).stageManagedProfile(stagedPayload),
        completes, reason: '${scenario.$1.name} $profile ${scenario.$3.name}');
      expect(staged, isNot(contains('_meta')));
      if (awg) {
        expect((staged!['endpoints'] as List).single['contract_id'], 'pokrov.awg31.endpoint.v1');
        expect((staged!['endpoints'] as List).single['domain_resolver'],
          {'server': scenario.$1 == HostPlatform.windows ? 'dns-remote' : 'cloudflare',
            'strategy': 'ipv4_only'});
      } else {
        final transport = (staged!['outbounds'] as List).singleWhere((row) => row['type'] == 'hysteria2');
        expect(transport['password'], 'synthetic-password');
        expect(transport['tls']['insecure'], isFalse);
      }
    }
  });

  test('materializes managed AWG2 and AWG31 endpoints for Android', () async {
    const labs = <Map<String, String>>[
      <String, String>{
        'profile': 'awg2_lab',
        'tag': 'pokrov-awg2-lab',
        'contract_id': 'pokrov.awg2.endpoint.v1',
        'contract_sha256':
            'c473c411025825bfef5a76c64990c5c921e9658b3581210d3a86d72e454fdea8',
      },
      <String, String>{
        'profile': 'awg31_lab',
        'tag': 'pokrov-awg31-lab',
        'contract_id': 'pokrov.awg31.endpoint.v1',
        'contract_sha256':
            '1bb49b61549ba7c4a3c2d56df445e919ebb1ed12d42e04b0cb3c915d23240818',
      },
    ];

    for (final lab in labs) {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'pokrov-bootstrap-${lab['profile']}-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      var fallbackResponseMode = 'accepted';
      final fallbackRequests = <String>[];
      unawaited(() async {
        await for (final request in server) {
          await utf8.decoder.bind(request).join();
          switch (request.uri.path) {
            case '/api/client/session/start-trial':
              request.response
                ..headers.contentType = ContentType.json
                ..write(
                  jsonEncode(<String, Object?>{
                    'session': <String, Object?>{
                      'session_token': 'awg-lab-session',
                      'account_id': '127',
                    },
                    'provisioning': <String, Object?>{
                      'status': 'ready',
                      'sync_ok': true,
                      'managed_manifest': <String, Object?>{
                        'url': '/api/client/profile/managed',
                      },
                    },
                  }),
                );
            case '/api/client/route-policy':
              request.response
                ..headers.contentType = ContentType.json
                ..write(jsonEncode(<String, Object?>{'ok': true}));
            case '/api/client/profile/managed':
              final requestedFallback =
                  request.uri.queryParameters['fallback_from_revision'];
              if (requestedFallback != null) {
                fallbackRequests.add(requestedFallback);
              }
              if (requestedFallback != null &&
                  fallbackResponseMode != 'ignored') {
                request.response
                  ..headers.contentType = ContentType.json
                  ..write(
                    jsonEncode(<String, Object?>{
                      ..._readyManagedProfile(
                        fallbackResponseMode == 'wrongRevision'
                            ? 'unrelated-revision'
                            : '$requestedFallback:fallback:legacy_reality_fallback',
                      ),
                      'transport_profile': 'legacy_reality_fallback',
                      'fallback_order': <String>['legacy_reality_fallback'],
                      'config_payload': <String, Object?>{
                        'outbounds': <Object?>[
                          <String, Object?>{
                            'type': 'vless',
                            'tag': 'proxy',
                            'server': 'tcp-fallback.example',
                            'server_port': 443,
                            'uuid': '11111111-1111-4111-8111-111111111111',
                            'tls': <String, Object?>{'enabled': true},
                          },
                          <String, Object?>{'type': 'direct', 'tag': 'direct'},
                        ],
                        'route': <String, Object?>{'final': 'proxy'},
                      },
                    }),
                  );
                break;
              }
              request.response
                ..headers.contentType = ContentType.json
                ..write(
                  jsonEncode(<String, Object?>{
                    'provisioning': <String, Object?>{
                      'status': 'ready',
                      'sync_ok': true,
                    },
                    'profile_revision': 'rev-${lab['profile']}',
                    'transport_profile': lab['profile'],
                    'fallback_order': <String>[
                      lab['profile']!,
                      'legacy_reality_fallback',
                    ],
                    'config_format': 'singbox-json',
                    'smart_connect': <String, Object?>{
                      'eligible': true,
                      'shortlist': <Object?>[
                        <String, Object?>{'code': 'de-fra'},
                      ],
                    },
                    'config_payload': <String, Object?>{
                      '_meta': <String, Object?>{
                        'title': 'POKROV',
                        'transport_contract': <String, Object?>{
                          'id': lab['contract_id'],
                          'sha256': lab['contract_sha256'],
                          'profile': lab['profile'],
                          'state': 'enabled',
                          'generation': '${lab['profile']}-v1',
                        },
                      },
                      'dns': <String, Object?>{
                        'servers': <Object?>[
                          <String, Object?>{
                            'tag': 'bootstrap',
                            'address': 'local',
                          },
                          <String, Object?>{
                            'tag': 'lab-dns',
                            'address': '8.8.8.8',
                            'detour': lab['tag'],
                          },
                        ],
                        'final': 'lab-dns',
                      },
                      'inbounds': <Object?>[],
                      'endpoints': <Object?>[
                        <String, Object?>{
                          'type': 'awg',
                          'tag': lab['tag'],
                          'contract_id': lab['contract_id'],
                          'useIntegratedTun': false,
                        },
                      ],
                      'outbounds': <Object?>[
                        <String, Object?>{'type': 'direct', 'tag': 'direct'},
                        <String, Object?>{'type': 'block', 'tag': 'block'},
                        <String, Object?>{'type': 'dns', 'tag': 'dns-out'},
                      ],
                      'route': <String, Object?>{
                        'rules': <Object?>[
                          <String, Object?>{
                            'protocol': 'dns',
                            'outbound': 'dns-out',
                          },
                        ],
                        'final': lab['tag'],
                      },
                    },
                  }),
                );
            default:
              request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        }
      }());

      final bootstrapper = AppFirstRuntimeBootstrapper(
        apiBaseUrl: 'http://127.0.0.1:${server.port}/',
        supportDirectoryResolver: () async => tempDirectory,
      );
      final payload = await bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.fullTunnel,
        excludedNodeCodes: const <String>{'de-fra'},
      );
      final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
      final endpoint =
          (config['endpoints'] as List<dynamic>).single as Map<String, dynamic>;
      final contract =
          (config['_meta'] as Map<String, dynamic>)['transport_contract']
              as Map<String, dynamic>;
      final route = config['route'] as Map<String, dynamic>;
      final outbounds = (config['outbounds'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      expect(endpoint['type'], 'awg');
      expect(endpoint['tag'], lab['tag']);
      expect(endpoint['contract_id'], lab['contract_id']);
      expect(contract['id'], lab['contract_id']);
      expect(contract['profile'], lab['profile']);
      expect(payload.tcpFallbackFromRevision, 'rev-${lab['profile']}');
      expect(payload.resolvedNodeCode, isEmpty);
      expect(payload.smartConnect, isNull);
      expect(route['final'], lab['tag']);
      expect(
        outbounds.every(
          (outbound) => const <String>{
            'direct',
            'block',
            'dns',
          }.contains(outbound['type']),
        ),
        isTrue,
      );
      final fallback = await bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.fullTunnel,
        tcpFallbackFromRevision: payload.tcpFallbackFromRevision,
      );
      final fallbackConfig =
          jsonDecode(fallback.configPayload) as Map<String, dynamic>;
      expect(
        fallback.source?.revision,
        '${payload.tcpFallbackFromRevision}:fallback:legacy_reality_fallback',
      );
      expect(fallback.tcpFallbackFromRevision, isEmpty);
      expect(fallback.routeMode, payload.routeMode);
      expect(fallbackConfig['endpoints'], anyOf(isNull, isEmpty));
      expect(
        (fallbackConfig['outbounds'] as List).any(
          (outbound) => (outbound as Map)['type'] == 'vless',
        ),
        isTrue,
      );
      expect(fallbackRequests.single, payload.tcpFallbackFromRevision);
      for (final responseMode in ['ignored', 'wrongRevision']) {
        fallbackResponseMode = responseMode;
        await expectLater(
          bootstrapper.resolveManagedProfile(
            hostPlatform: HostPlatform.android,
            routeMode: RouteMode.fullTunnel,
            tcpFallbackFromRevision: payload.tcpFallbackFromRevision,
          ),
          throwsA(isA<BootstrapFailure>()),
        );
      }
    }
  });

  test('materialization verifies an explicit Smart Connect location', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-preferred-node-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    var runtimeReady = false;
    Map<String, Object?> managedResponse({
      required bool duplicateRuProxy,
      required bool ambiguousFinalSelector,
      required bool preferredRouteVariant,
      required bool directUnlisted,
      required bool nestedRouteVariant,
      required bool hiddenUnreachableSelector,
    }) =>
        <String, Object?>{
          'provisioning': <String, Object?>{'status': 'ready', 'sync_ok': true},
          'profile_revision': 'rev-preferred-node',
          'config_format': 'singbox-json',
          'smart_connect': <String, Object?>{
            'eligible': true,
            'shortlist': <Object?>[
              <String, Object?>{
                'code': 'ru-spb',
              },
              <String, Object?>{
                'code': 'ru-nested',
                'probe': <String, Object?>{
                  'host': 'ru-nested.example.test',
                  'port': 443,
                },
              },
              <String, Object?>{
                'code': 'ru-hidden',
                'probe': <String, Object?>{
                  'host': 'ru-hidden.example.test',
                  'port': 443,
                },
              },
              <String, Object?>{
                'code': 'de-ber',
                'probe': <String, Object?>{
                  'host': 'de-ber.example.test',
                  'port': 443,
                },
              },
              <String, Object?>{
                'code': 'ru-mismatch',
                'probe': <String, Object?>{
                  'host': 'missing.example.test',
                  'port': 443,
                },
              },
              <String, Object?>{
                'code': 'ru-duplicate',
                'probe': <String, Object?>{
                  'host': 'ru-spb.example.test',
                  'port': 8443,
                },
              },
              <String, Object?>{
                'code': 'selector-ambiguous',
                'probe': <String, Object?>{
                  'host': 'de-ber.example.test',
                  'port': 443,
                },
              },
              <String, Object?>{'code': 'ru-unlisted'},
            ],
          },
          'config_payload': <String, Object?>{
            if (runtimeReady)
              'inbounds': <Object?>[
                <String, Object?>{
                  'type': 'tun',
                  'tag': 'tun-in',
                  'address': <String>['172.19.0.1/28'],
                },
              ],
            if (preferredRouteVariant)
              '_meta': <String, Object?>{
                'ru_bridge': <String, Object?>{
                  'enabled': true,
                  'endpoints': <Object?>[
                    <String, Object?>{
                      'id': 'mini',
                      'label': 'Белые списки',
                    },
                    <String, Object?>{
                      'id': 'orphan',
                      'label': 'Белые списки тип 2',
                    },
                  ],
                },
              },
            'route': <String, Object?>{'final': 'proxy'},
            'outbounds': <Object?>[
              <String, Object?>{
                'type': 'selector',
                'tag': 'proxy',
                'outbounds': nestedRouteVariant
                    ? <String>['🇷🇺 Россия Nested']
                    : <String>[
                        'de-ber',
                        '🇷🇺 Россия Spb',
                        if (!directUnlisted) 'ru-unlisted',
                        if (preferredRouteVariant)
                          '🇷🇺 Россия Spb · Белые списки',
                        if (hiddenUnreachableSelector)
                          '🇷🇺 Россия Hidden · Белые списки',
                        'bridge-ru-spb',
                      ],
                'default': nestedRouteVariant ? '🇷🇺 Россия Nested' : 'de-ber',
              },
              if (nestedRouteVariant)
                <String, Object?>{
                  'type': 'selector',
                  'tag': '🇷🇺 Россия Nested',
                  'outbounds': <String>[
                    '🇷🇺 Россия Nested · Обычный',
                    '🇷🇺 Россия Nested · Белые списки',
                  ],
                  'default': '🇷🇺 Россия Nested · Обычный',
                },
              if (hiddenUnreachableSelector)
                <String, Object?>{
                  'type': 'selector',
                  'tag': 'POKROV торренты RU §hide§',
                  'outbounds': <String>['🇷🇺 Россия Hidden'],
                  'default': '🇷🇺 Россия Hidden',
                },
              if (ambiguousFinalSelector)
                <String, Object?>{
                  'type': 'urltest',
                  'tag': 'proxy',
                  'outbounds': <String>['de-ber'],
                },
              <String, Object?>{
                'type': 'vless',
                'tag': 'de-ber',
                'server': 'de-ber.example.test',
                'server_port': 443,
              },
              <String, Object?>{
                'type': 'vless',
                'tag': '🇷🇺 Россия Spb',
                'server': 'ru-spb.example.test',
                'server_port': 443,
              },
              <String, Object?>{
                'type': 'vless',
                'tag': 'ru-unlisted',
                'server': 'ru-unlisted.example.test',
                'server_port': 443,
              },
              if (preferredRouteVariant)
                <String, Object?>{
                  'type': 'vless',
                  'tag': '🇷🇺 Россия Spb · Белые списки',
                  'server': 'ru-spb.example.test',
                  'server_port': 443,
                  'detour': 'bridge-ru-spb',
                },
              if (nestedRouteVariant)
                <String, Object?>{
                  'type': 'vless',
                  'tag': '🇷🇺 Россия Nested · Обычный',
                  'server': 'ru-nested.example.test',
                  'server_port': 443,
                },
              if (nestedRouteVariant)
                <String, Object?>{
                  'type': 'vless',
                  'tag': '🇷🇺 Россия Nested · Белые списки',
                  'server': 'ru-nested.example.test',
                  'server_port': 443,
                  'detour': 'bridge-ru-spb',
                },
              if (hiddenUnreachableSelector)
                <String, Object?>{
                  'type': 'vless',
                  'tag': '🇷🇺 Россия Hidden',
                  'server': 'ru-hidden.example.test',
                  'server_port': 443,
                },
              if (hiddenUnreachableSelector)
                <String, Object?>{
                  'type': 'vless',
                  'tag': '🇷🇺 Россия Hidden · Белые списки',
                  'server': 'ru-hidden.example.test',
                  'server_port': 443,
                  'detour': 'bridge-ru-hidden',
                },
              if (hiddenUnreachableSelector)
                <String, Object?>{
                  'type': 'vless',
                  'tag': 'bridge-ru-hidden',
                  'server': 'ru-hidden.example.test',
                  'server_port': 443,
                  'detour': '🇷🇺 Россия Hidden',
                },
              if (preferredRouteVariant)
                <String, Object?>{
                  'type': 'vless',
                  'tag': '🇷🇺 Россия Spb · Белые списки тип 2',
                  'server': 'ru-spb.example.test',
                  'server_port': 443,
                  'detour': 'bridge-ru-spb',
                },
              <String, Object?>{
                'type': 'vless',
                'tag': 'bridge-ru-spb',
                'server': 'ru-spb.example.test',
                'server_port': 443,
                'detour': 'ru-spb',
              },
              if (duplicateRuProxy)
                <String, Object?>{
                  'type': 'vless',
                  'tag': 'ru-spb-duplicate',
                  'server': 'ru-spb.example.test',
                  'server_port': 8443,
                },
              <String, Object?>{
                'type': 'vless',
                'tag': 'ru-spb-duplicate-2',
                'server': 'ru-spb.example.test',
                'server_port': 8443,
              },
            ],
          },
        };

    final managedProfileQueries = <String?>[];
    final nodeSelectionBodies = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(<String, Object?>{
                'session': <String, Object?>{
                  'session_token': 'test-session',
                  'account_id': '1',
                },
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true,
                  'managed_manifest': <String, Object?>{
                    'url': '/api/client/profile/managed',
                  },
                },
              }),
            );
        } else if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
        } else if (request.uri.path == '/api/client/profile/managed') {
          final code = request.uri.queryParameters['selected_node_code'];
          managedProfileQueries.add(code);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                managedResponse(
                  duplicateRuProxy: code == 'ru-duplicate',
                  ambiguousFinalSelector: code == 'selector-ambiguous',
                  preferredRouteVariant: code == 'ru-spb' ||
                      code == 'ru-nested' ||
                      code == 'ru-hidden',
                  directUnlisted: code == 'ru-unlisted',
                  nestedRouteVariant: code == 'ru-nested',
                  hiddenUnreachableSelector: code == 'ru-hidden',
                ),
              ),
            );
        } else if (request.uri.path == '/api/client/nodes/select') {
          nodeSelectionBodies.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(<String, Object?>{
                'ok': true,
                'selected_node_code': 'ru-spb',
                'requires_profile_refresh': true,
              }),
            );
        } else if (request.uri.path == '/api/client/nodes/latency-samples') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      smartConnectLatencyProbe: (node) async => node.code == 'de-ber' ? 20 : 40,
    );

    final automatic = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final automaticOutbounds = (jsonDecode(automatic.configPayload)
        as Map<String, dynamic>)['outbounds'] as List;
    final automaticSelector = automaticOutbounds.cast<Map>().singleWhere(
          (outbound) => outbound['tag'] == 'proxy',
        );
    expect(automaticSelector['default'], '🇷🇺 Россия Spb');
    expect(automatic.resolvedNodeCode, 'ru-spb');
    expect(managedProfileQueries, <String?>[null]);

    final failover = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
      excludedNodeCodes: const <String>{'ru-spb'},
    );
    final failoverOutbounds = (jsonDecode(failover.configPayload)
        as Map<String, dynamic>)['outbounds'] as List;
    final failoverSelector = failoverOutbounds.cast<Map>().singleWhere(
          (outbound) => outbound['tag'] == 'proxy',
        );
    expect(failoverSelector['default'], 'de-ber');
    expect(failover.resolvedNodeCode, 'de-ber');
    expect(managedProfileQueries, <String?>[null, null]);
    expect(
      nodeSelectionBodies.last['excluded_node_codes'],
      <String>['ru-spb'],
    );

    final preferred = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
      preferredNodeCode: 'ru-spb',
    );
    final preferredOutbounds = (jsonDecode(preferred.configPayload)
        as Map<String, dynamic>)['outbounds'] as List;
    final preferredSelector = preferredOutbounds.cast<Map>().singleWhere(
          (outbound) => outbound['tag'] == 'proxy',
        );
    expect(preferredSelector['default'], '🇷🇺 Россия Spb');
    expect(
      (preferredSelector['outbounds'] as List).first,
      '🇷🇺 Россия Spb',
    );
    final preferredProbeGroup = preferredOutbounds.cast<Map>().singleWhere(
          (outbound) => outbound['tag'] == 'pokrov-variant-probe',
        );
    expect(preferredProbeGroup['outbounds'], <String>[
      '🇷🇺 Россия Spb',
      '🇷🇺 Россия Spb · Белые списки',
    ]);

    for (final ready in <bool>[false, true]) {
      runtimeReady = ready;
      final selected = await bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.selectedApps,
        selectedApps: const <String>['powershell.exe'],
        preferredNodeCode: 'ru-spb',
      );
      final config = jsonDecode(selected.configPayload) as Map<String, dynamic>;
      final route = config['route'] as Map;
      expect(route['final'], 'direct');
      final rule = (route['rules'] as List).cast<Map>().singleWhere(
            (rule) => (rule['process_name'] as List?)
                ?.contains('powershell.exe') == true,
          );
      final selector = (config['outbounds'] as List).cast<Map>().singleWhere(
            (outbound) => outbound['tag'] == rule['outbound'],
          );
      expect(selector['type'], 'selector');
      expect(selector['default'], '🇷🇺 Россия Spb');
      expect(selector['outbounds'], isNot(contains('direct')));
      final dnsRule = ((config['dns'] as Map)['rules'] as List)
          .cast<Map>().singleWhere((rule) =>
              (rule['process_name'] as List?)?.contains('powershell.exe') == true);
      expect(dnsRule['server'], 'dns-remote');
    }
    runtimeReady = false;

    final bridgePreferred = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
      preferredNodeCode: 'ru-spb',
      preferredVariantId: 'mini',
    );
    final bridgeSelector = ((jsonDecode(bridgePreferred.configPayload)
            as Map<String, dynamic>)['outbounds'] as List)
        .cast<Map>()
        .singleWhere((outbound) => outbound['tag'] == 'proxy');
    expect(bridgeSelector['default'], '🇷🇺 Россия Spb · Белые списки');
    expect(
      (bridgeSelector['outbounds'] as List).first,
      '🇷🇺 Россия Spb · Белые списки',
    );
    final bridgeConfig =
        jsonDecode(bridgePreferred.configPayload) as Map<String, dynamic>;
    final runtimeVariantProbe =
        ((bridgeConfig['_meta'] as Map)['runtime_variant_probe'] as Map);
    expect(runtimeVariantProbe['group_tag'], 'pokrov-variant-probe');
    expect(
      runtimeVariantProbe['mappings'],
      <Map<String, String>>[
        <String, String>{
          'id': 'mini',
          'outbound_tag': '🇷🇺 Россия Spb · Белые списки',
        },
      ],
    );
    final variantProbeGroup = (bridgeConfig['outbounds'] as List)
        .cast<Map>()
        .singleWhere((outbound) => outbound['tag'] == 'pokrov-variant-probe');
    expect(variantProbeGroup['type'], 'urltest');
    expect(
      variantProbeGroup['url'],
      'https://api.pokrov.space/api/public/authenticated-egress-probe',
    );
    expect(
      variantProbeGroup['outbounds'],
      <String>[
        '🇷🇺 Россия Spb · Белые списки',
      ],
    );

    await expectLater(
      () => bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.fullTunnel,
        preferredNodeCode: 'ru-spb',
        preferredVariantId: 'unknown-bridge',
      ),
      throwsA(
        isA<BootstrapFailure>().having(
          (error) => error.message,
          'message',
          'Выбранный вариант подключения недоступен.',
        ),
      ),
    );
    await expectLater(
      () => bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.fullTunnel,
        preferredNodeCode: 'ru-spb',
        preferredVariantId: 'orphan',
      ),
      throwsA(isA<BootstrapFailure>()),
    );
    final insertedDirect = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
      preferredNodeCode: 'ru-unlisted',
      preferredVariantId: 'direct',
    );
    final insertedDirectSelector = ((jsonDecode(insertedDirect.configPayload)
            as Map<String, dynamic>)['outbounds'] as List)
        .cast<Map>()
        .singleWhere((outbound) => outbound['tag'] == 'proxy');
    expect(insertedDirectSelector['default'], 'ru-unlisted');
    expect((insertedDirectSelector['outbounds'] as List).first, 'ru-unlisted');

    final hiddenDirect = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
      preferredNodeCode: 'ru-hidden',
      preferredVariantId: 'direct',
    );
    final hiddenDirectSelector = ((jsonDecode(hiddenDirect.configPayload)
            as Map<String, dynamic>)['outbounds'] as List)
        .cast<Map>()
        .singleWhere((outbound) => outbound['tag'] == 'proxy');
    expect(hiddenDirectSelector['default'], '🇷🇺 Россия Hidden');
    expect(
      (hiddenDirectSelector['outbounds'] as List).first,
      '🇷🇺 Россия Hidden',
    );

    final hiddenBridge = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
      preferredNodeCode: 'ru-hidden',
      preferredVariantId: 'mini',
    );
    final hiddenBridgeSelector = ((jsonDecode(hiddenBridge.configPayload)
            as Map<String, dynamic>)['outbounds'] as List)
        .cast<Map>()
        .singleWhere((outbound) => outbound['tag'] == 'proxy');
    expect(
      hiddenBridgeSelector['default'],
      '🇷🇺 Россия Hidden · Белые списки',
    );
    expect(
      (hiddenBridgeSelector['outbounds'] as List).first,
      '🇷🇺 Россия Hidden · Белые списки',
    );

    final nestedDirect = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
      preferredNodeCode: 'ru-nested',
      preferredVariantId: 'direct',
    );
    final nestedDirectOutbounds = (jsonDecode(nestedDirect.configPayload)
        as Map<String, dynamic>)['outbounds'] as List;
    final nestedDirectFinal = nestedDirectOutbounds
        .cast<Map>()
        .singleWhere((outbound) => outbound['tag'] == 'proxy');
    final nestedDirectCountry = nestedDirectOutbounds
        .cast<Map>()
        .singleWhere((outbound) => outbound['tag'] == '🇷🇺 Россия Nested');
    expect(nestedDirectFinal['default'], '🇷🇺 Россия Nested');
    expect(nestedDirectCountry['default'], '🇷🇺 Россия Nested · Обычный');

    final nestedBridge = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
      preferredNodeCode: 'ru-nested',
      preferredVariantId: 'mini',
    );
    final nestedBridgeOutbounds = (jsonDecode(nestedBridge.configPayload)
        as Map<String, dynamic>)['outbounds'] as List;
    final nestedBridgeFinal = nestedBridgeOutbounds
        .cast<Map>()
        .singleWhere((outbound) => outbound['tag'] == 'proxy');
    final nestedBridgeCountry = nestedBridgeOutbounds
        .cast<Map>()
        .singleWhere((outbound) => outbound['tag'] == '🇷🇺 Россия Nested');
    expect(nestedBridgeFinal['default'], '🇷🇺 Россия Nested');
    expect(
      nestedBridgeCountry['default'],
      '🇷🇺 Россия Nested · Белые списки',
    );
    expect(
      (nestedBridgeCountry['outbounds'] as List).first,
      '🇷🇺 Россия Nested · Белые списки',
    );
    final nestedBridgeRoot = nestedBridgeOutbounds
        .cast<Map>()
        .singleWhere((outbound) => outbound['tag'] == '🇷🇺 Россия Spb');
    final nestedBridgeMiddle = nestedBridgeOutbounds
        .cast<Map>()
        .singleWhere((outbound) => outbound['tag'] == 'bridge-ru-spb');
    final nestedBridgeTerminal = nestedBridgeOutbounds.cast<Map>().singleWhere(
          (outbound) => outbound['tag'] == '🇷🇺 Россия Nested · Белые списки',
        );
    expect(nestedBridgeRoot['domain_resolver'], 'dns-local');
    expect(nestedBridgeMiddle['detour'], 'ru-spb');
    expect(nestedBridgeMiddle.containsKey('domain_resolver'), isFalse);
    expect(nestedBridgeTerminal['detour'], 'bridge-ru-spb');
    expect(nestedBridgeTerminal.containsKey('domain_resolver'), isFalse);

    await expectLater(
      () => bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.fullTunnel,
        preferredNodeCode: 'not-in-shortlist',
      ),
      throwsA(
        isA<BootstrapFailure>().having(
          (error) => error.message,
          'message',
          'Выбранная локация недоступна.',
        ),
      ),
    );
    await expectLater(
      () => bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.fullTunnel,
        preferredNodeCode: 'ru-mismatch',
      ),
      throwsA(isA<BootstrapFailure>()),
    );
    await expectLater(
      () => bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.fullTunnel,
        preferredNodeCode: 'ru-duplicate',
      ),
      throwsA(isA<BootstrapFailure>()),
    );
    await expectLater(
      () => bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.fullTunnel,
        preferredNodeCode: 'selector-ambiguous',
      ),
      throwsA(isA<BootstrapFailure>()),
    );
  });

  test('android materialization excludes desktop loopback listener inbounds',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-runtime-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-runtime',
                    'account_id': '252',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-android-runtime',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    '_meta': <String, Object?>{
                      'source': 'managed',
                    },
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'primary-node',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final inbounds = (config['inbounds'] as List).cast<Map<String, dynamic>>();
    final route = config['route'] as Map<String, dynamic>;
    final rules = (route['rules'] as List).cast<Map<String, dynamic>>();
    final dns = config['dns'] as Map<String, dynamic>;
    final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();

    expect(inbounds, hasLength(1));
    expect(inbounds.where((inbound) => inbound['type'] == 'tun'), hasLength(1));
    expect(
      inbounds.where((inbound) => inbound['tag'] == 'android-private-dns-in'),
      isEmpty,
    );
    expect(
      inbounds.singleWhere((inbound) => inbound['type'] == 'tun')['stack'],
      'gvisor',
    );
    expect(
      inbounds.singleWhere(
          (inbound) => inbound['type'] == 'tun')['exclude_package'],
      <String>['space.pokrov.pokrov_android_shell'],
    );
    final tunInbound =
        inbounds.singleWhere((inbound) => inbound['type'] == 'tun');
    expect(tunInbound['address'], <String>[
      '172.19.0.1/28',
      'fdfe:dcba:9876::1/126',
    ]);
    expect(tunInbound.containsKey('inet4_address'), isFalse);
    expect(tunInbound.containsKey('inet6_address'), isFalse);
    expect(tunInbound.containsKey('domain_strategy'), isFalse);
    expect(tunInbound.containsKey('endpoint_independent_nat'), isFalse);
    expect(tunInbound.containsKey('sniff'), isFalse);
    expect(payload.configPayload, isNot(contains('"mixed-in"')));
    expect(payload.configPayload, isNot(contains('"dns-in"')));
    expect(
      rules.where((rule) => rule['inbound'] == 'dns-in'),
      isEmpty,
    );
    expect(route['auto_detect_interface'], false);
    expect(route.containsKey('override_android_vpn'), isFalse);
    expect(
      rules.any(
        (rule) =>
            (rule['inbound'] as List?)?.contains('tun-in') == true &&
            (rule['package_name'] as List?)
                    ?.contains('space.pokrov.pokrov_android_shell') ==
                true &&
            rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(dns['final'], isNotEmpty);
    expect(
      servers.any((server) => server['type'] == 'local'),
      isTrue,
    );
    expect(
      dnsRules.any((rule) =>
          (rule['domain'] as List?)?.contains('nl.kiwunaka.space') ?? false),
      isTrue,
    );
    expect(rules.first, <String, dynamic>{
      'protocol': 'dns',
      'action': 'hijack-dns',
    });
    expect(rules[1], <String, dynamic>{'action': 'sniff'});
    expect(
      (config['outbounds'] as List).cast<Map<String, dynamic>>().where(
            (outbound) => outbound['type'] == 'dns',
          ),
      isEmpty,
    );
    expect(
      rules.where((rule) =>
          rule['ip_is_private'] == true && rule['outbound'] == 'direct'),
      isEmpty,
    );
  });

  test('preserves Windows runtime settings while applying mode rules',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-pass-through-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-4',
                    'account_id': '168',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-ready',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    '_meta': <String, Object?>{'source': 'managed'},
                    'log': <String, Object?>{'level': 'info'},
                    'dns': <String, Object?>{
                      'servers': <Object?>[
                        <String, Object?>{
                          'type': 'https',
                          'tag': 'sealed',
                          'server': '9.9.9.9',
                          'path': '/dns-query',
                          'detour': 'proxy'
                        }
                      ],
                      'final': 'sealed',
                    },
                    'inbounds': <Object?>[
                      <String, Object?>{
                        'type': 'tun',
                        'tag': 'tun-in',
                      },
                    ],
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': '127.0.0.1',
                        'server_port': 443,
                        'uuid': '00000000-0000-4000-8000-000000000001'
                      },
                      <String, Object?>{'type': 'direct', 'tag': 'direct'},
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <String>['node-1'],
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                      'auto_detect_interface': true,
                      'override_android_vpn': true,
                    },
                    'experimental': <String, Object?>{
                      'cache_file': <String, Object?>{'enabled': true},
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;

    expect(config['inbounds'], hasLength(1));
    expect(config['experimental'], isNotNull);
    expect(config.containsKey('_meta'), isFalse);
    expect(config.toString(), contains('auto_detect_interface'));
    expect(config.toString(), contains('override_android_vpn'));
    final dns = config['dns'] as Map<String, dynamic>;
    expect(dns['final'], 'dns-remote');
    expect(
        (dns['servers'] as List)
            .cast<Map>()
            .singleWhere((server) => server['tag'] == 'sealed'),
        <String, Object?>{
          'type': 'https',
          'tag': 'sealed',
          'server': '9.9.9.9',
          'path': '/dns-query',
          'detour': 'proxy'
        });
    expect(payload.routeMode, RouteMode.fullTunnel);
  });

  test(
      'android preserves managed routing semantics while removing desktop-only DNS surfaces',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-runtime-ready-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-runtime-ready',
                    'account_id': '336',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-android-runtime-ready',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    '_meta': <String, Object?>{'source': 'managed'},
                    'log': <String, Object?>{'level': 'info'},
                    'dns': <String, Object?>{
                      'servers': <Object?>[
                        <String, Object?>{
                          'tag': 'legacy-local-dot',
                          'address': 'tls://127.0.0.1:853',
                        },
                      ],
                    },
                    'inbounds': <Object?>[
                      <String, Object?>{
                        'type': 'tun',
                        'tag': 'tun-in',
                      },
                      <String, Object?>{
                        'type': 'direct',
                        'tag': 'dns-in',
                        'listen': '127.0.0.1',
                        'listen_port': 853,
                      },
                    ],
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                        'domain_resolver': <String, Object?>{
                          'server': 'old-bootstrap',
                          'strategy': 'ipv6_only',
                          'disable_cache': true,
                        },
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                      'auto_detect_interface': true,
                      'override_android_vpn': true,
                    },
                    'experimental': <String, Object?>{
                      'cache_file': <String, Object?>{'enabled': true},
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final dns = config['dns'] as Map<String, dynamic>;
    final inbounds = (config['inbounds'] as List).cast<Map<String, dynamic>>();
    final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    final dnsDirectServer = servers.singleWhere(
      (server) => server['tag'] == 'dns-direct',
    );
    final route = config['route'] as Map<String, dynamic>;
    final rules = (route['rules'] as List).cast<Map<String, dynamic>>();

    expect(config.containsKey('_meta'), isFalse);
    expect(payload.configPayload, isNot(contains('"dns-in"')));
    expect(payload.configPayload, isNot(contains('"override_android_vpn"')));
    expect(payload.configPayload, contains('"auto_detect_interface": false'));
    expect(inbounds, hasLength(1));
    expect(inbounds.where((inbound) => inbound['type'] == 'tun'), hasLength(1));
    expect(
      inbounds.where((inbound) => inbound['tag'] == 'android-private-dns-in'),
      isEmpty,
    );
    expect(
      inbounds.singleWhere((inbound) => inbound['type'] == 'tun')['stack'],
      'gvisor',
    );
    expect(
      inbounds.singleWhere(
          (inbound) => inbound['type'] == 'tun')['exclude_package'],
      <String>['space.pokrov.pokrov_android_shell'],
    );
    expect(
      inbounds.singleWhere((inbound) => inbound['type'] == 'tun')['address'],
      <String>['172.19.0.1/28', 'fdfe:dcba:9876::1/126'],
    );
    expect(servers.map((server) => server['type']), contains('local'));
    expect(
      servers.where(
        (server) => server['address'] == 'https://1.1.1.1/dns-query',
      ),
      hasLength(2),
    );
    expect(
      servers.map((server) => server['address']),
      isNot(contains('1.1.1.1')),
    );
    expect(servers.map((server) => server['address']),
        isNot(contains('tls://127.0.0.1:853')));
    expect(dnsDirectServer['detour'], 'direct');
    expect(dnsDirectServer['address_resolver'], 'dns-local');
    expect(dns['final'], isNotEmpty);
    expect(dns['independent_cache'], isTrue);
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();
    final serverDomainRule = dnsRules.singleWhere(
      (rule) =>
          (rule['domain'] as List?)?.contains('nl.kiwunaka.space') ?? false,
    );
    final ipPrivateRule = dnsRules.singleWhere(
      (rule) => rule['ip_is_private'] == true,
    );
    final localServer = servers.singleWhere(
      (server) => server['type'] == 'local',
    );
    expect(serverDomainRule['server'], localServer['tag']);
    expect(ipPrivateRule['server'], serverDomainRule['server']);
    final vlessOutbound =
        (config['outbounds'] as List).cast<Map<String, dynamic>>().singleWhere(
              (outbound) => outbound['type'] == 'vless',
            );
    expect(vlessOutbound['domain_resolver'], <String, Object?>{
      'server': localServer['tag'], 'strategy': 'ipv6_only', 'disable_cache': true,
    });
    expect(route['final'], 'proxy');
    expect(rules.first, <String, dynamic>{
      'protocol': 'dns',
      'action': 'hijack-dns',
    });
    expect(rules[1], <String, dynamic>{'action': 'sniff'});
    expect(
      rules[2],
      containsPair(
          'package_name', <String>['space.pokrov.pokrov_android_shell']),
    );
    expect(
      (config['outbounds'] as List).cast<Map<String, dynamic>>().where(
            (outbound) => outbound['type'] == 'dns',
          ),
      isEmpty,
    );
    expect(
      rules.where((rule) =>
          rule['ip_is_private'] == true && rule['outbound'] == 'direct'),
      isEmpty,
    );
    expect(payload.routeMode, RouteMode.fullTunnel);
  });

  test(
      'android full tunnel strips direct route bypass rules from managed routes',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-managed-safe-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-managed-safe',
                    'account_id': '337',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-android-managed-safe',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    '_meta': <String, Object?>{'source': 'managed'},
                    'log': <String, Object?>{'level': 'info'},
                    'dns': <String, Object?>{
                      'servers': <Object?>[
                        <String, Object?>{
                          'tag': 'google',
                          'address': '8.8.8.8',
                          'detour': 'proxy',
                        },
                        <String, Object?>{
                          'tag': 'local',
                          'address': 'local',
                          'detour': 'direct',
                        },
                      ],
                      'final': 'google',
                    },
                    'inbounds': <Object?>[
                      <String, Object?>{
                        'type': 'tun',
                        'tag': 'tun-in',
                      },
                    ],
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                      <String, Object?>{
                        'type': 'direct',
                        'tag': 'direct',
                      },
                      <String, Object?>{
                        'type': 'dns',
                        'tag': 'dns-out',
                      },
                    ],
                    'route': <String, Object?>{
                      'rule_set': <Object?>[
                        <String, Object?>{
                          'type': 'remote',
                          'tag': 'geoip-ru',
                          'format': 'binary',
                          'url': 'https://example.com/geoip-ru.srs',
                          'download_detour': 'direct',
                        },
                      ],
                      'rules': <Object?>[
                        <String, Object?>{
                          'ip_is_private': true,
                          'outbound': 'direct',
                        },
                        <String, Object?>{
                          'rule_set': <Object?>['geoip-ru'],
                          'outbound': 'direct',
                        },
                        <String, Object?>{
                          'protocol': 'dns',
                          'outbound': 'dns-out',
                        },
                      ],
                      'auto_detect_interface': true,
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final dns = config['dns'] as Map<String, dynamic>;
    final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();
    final route = config['route'] as Map<String, dynamic>;
    final routeRules = (route['rules'] as List).cast<Map<String, dynamic>>();

    expect(servers.map((server) => server['tag']),
        containsAll(<String>['google', 'local']));
    expect(dns['final'], 'google');
    expect(dns['independent_cache'], isTrue);
    expect(
      dnsRules.any(
        (rule) =>
            ((rule['domain'] as List?)?.contains('nl.kiwunaka.space') ??
                false) &&
            rule['server'] == 'local',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (rule) =>
            ((rule['rule_set'] as List?)?.contains('geoip-ru') ?? false) &&
            rule['outbound'] == 'direct',
      ),
      isFalse,
    );
    expect(route['auto_detect_interface'], false);
    expect(route.containsKey('override_android_vpn'), isFalse);
    expect(
      routeRules.any(
        (rule) =>
            (rule['inbound'] as List?)?.contains('tun-in') == true &&
            (rule['package_name'] as List?)
                    ?.contains('space.pokrov.pokrov_android_shell') ==
                true &&
            rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(route['final'], 'proxy');
  });

  test('android all-except-ru preserves ru direct bypass rules', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-all-except-ru-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final ruleSetBytesByTag = _allExceptRuRuleSetFixtures();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path.startsWith('/rule-sets/')) {
          final fileName = request.uri.pathSegments.isEmpty
              ? ''
              : request.uri.pathSegments.last;
          final tag = fileName.replaceAll('.srs', '');
          final bytes = ruleSetBytesByTag[tag];
          if (bytes == null) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            continue;
          }
          request.response.add(bytes);
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-all-except-ru',
                    'account_id': '338',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-android-all-except-ru',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'dns': <String, Object?>{
                      'servers': <Object?>[
                        <String, Object?>{
                          'tag': 'google',
                          'address': '8.8.8.8',
                          'detour': 'proxy',
                        },
                        <String, Object?>{
                          'tag': 'local',
                          'address': 'local',
                          'detour': 'direct',
                        },
                      ],
                      'final': 'local',
                    },
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                      <String, Object?>{
                        'type': 'direct',
                        'tag': 'direct',
                      },
                      <String, Object?>{
                        'type': 'dns',
                        'tag': 'dns-out',
                      },
                    ],
                    'route': <String, Object?>{
                      'rules': <Object?>[
                        <String, Object?>{
                          'rule_set': <Object?>['geoip-ru'],
                          'outbound': 'direct',
                        },
                      ],
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      allExceptRuRuleSetUrlsResolver: (tag) =>
          <String>['http://127.0.0.1:${server.port}/rule-sets/$tag.srs'],
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.allExceptRu,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final tun = (config['inbounds'] as List).cast<Map<String, dynamic>>()
        .singleWhere((inbound) => inbound['type'] == 'tun');
    expect(tun['exclude_package'], <String>[
      'space.pokrov.pokrov_android_shell',
      ...pokrovRuAppCatalog.map((entry) => entry.packageId),
    ]);
    final dns = config['dns'] as Map<String, dynamic>;
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();
    final dnsServers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    final route = config['route'] as Map<String, dynamic>;
    final routeRuleSets =
        (route['rule_set'] as List).cast<Map<String, dynamic>>();
    final routeRules = (route['rules'] as List).cast<Map<String, dynamic>>();

    expect(
      routeRuleSets.map((ruleSet) => ruleSet['tag']),
      containsAll(<String>[
        _ruDomainWhitelistRuleSetTag,
        _ruDomainCategoryRuleSetTag,
        _ruIpCountryRuleSetTag,
        _ruIpWhitelistRuleSetTag,
      ]),
    );
    final domainWhitelistRuleSet = routeRuleSets.singleWhere(
      (ruleSet) => ruleSet['tag'] == _ruDomainWhitelistRuleSetTag,
    );
    expect(domainWhitelistRuleSet['type'], 'local');
    expect(domainWhitelistRuleSet['format'], 'binary');
    expect(
      domainWhitelistRuleSet['path'],
      _expectedRuleSetCachePath(tempDirectory, 'ru-domain-whitelist.srs'),
    );
    expect(
      await File(domainWhitelistRuleSet['path'] as String).exists(),
      isTrue,
    );
    expect(
      routeRules.any(
        (rule) =>
            ((rule['rule_set'] as List?)?.contains('geoip-ru') ?? false) &&
            rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (rule) =>
            rule['domain_suffix'] == '.ru' && rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (rule) =>
            ((rule['rule_set'] as List?)?.contains(_ruIpCountryRuleSetTag) ??
                false) &&
            rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      dnsRules.any(
        (rule) =>
            (rule['rule_set'] as List?)?.contains(
              _ruDomainWhitelistRuleSetTag,
            ) ??
            false,
      ),
      isTrue,
    );
    expect(route['auto_detect_interface'], false);
    expect(route.containsKey('override_android_vpn'), isFalse);
    expect(route['final'], 'proxy');
    expect(
      dnsServers.singleWhere((server) => server['tag'] == dns['final'])['detour'],
      'proxy',
    );
    expect(routeRules.first, <String, dynamic>{
      'protocol': 'dns',
      'action': 'hijack-dns',
    });
    expect(
      (config['outbounds'] as List).cast<Map<String, dynamic>>().where(
            (outbound) => outbound['type'] == 'dns',
          ),
      isEmpty,
    );
  });

  test('windows all-except-ru injects cached local rule-set definitions',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-windows-all-except-ru-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final ruleSetBytesByTag = _allExceptRuRuleSetFixtures();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path.startsWith('/rule-sets/')) {
          final fileName = request.uri.pathSegments.isEmpty
              ? ''
              : request.uri.pathSegments.last;
          final tag = fileName.replaceAll('.srs', '');
          final bytes = ruleSetBytesByTag[tag];
          if (bytes == null) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            continue;
          }
          request.response.add(bytes);
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-windows-all-except-ru',
                    'account_id': '342',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['route_mode'], 'all_traffic');
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-windows-all-except-ru',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'rule_set': <Object?>[
                        <String, Object?>{
                          'type': 'remote',
                          'tag': 'geoip-ru',
                          'format': 'binary',
                          'url': 'https://example.invalid/geoip-ru.srs',
                        },
                      ],
                      'rules': <Object?>[
                        <String, Object?>{
                          'rule_set': <Object?>['geoip-ru'],
                          'outbound': 'direct',
                        },
                      ],
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      allExceptRuRuleSetUrlsResolver: (tag) =>
          <String>['http://127.0.0.1:${server.port}/rule-sets/$tag.srs'],
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.allExceptRu,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final dns = config['dns'] as Map<String, dynamic>;
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();
    final route = config['route'] as Map<String, dynamic>;
    final routeRuleSets =
        (route['rule_set'] as List).cast<Map<String, dynamic>>();
    final routeRules = (route['rules'] as List).cast<Map<String, dynamic>>();

    expect(
      routeRuleSets.map((ruleSet) => ruleSet['tag']),
      containsAll(<String>[
        'geoip-ru',
        _ruDomainWhitelistRuleSetTag,
        _ruDomainCategoryRuleSetTag,
        _ruIpCountryRuleSetTag,
        _ruIpWhitelistRuleSetTag,
      ]),
    );
    final dnsServers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    final outbounds =
        (config['outbounds'] as List).cast<Map<String, dynamic>>();
    expect(routeRules.first, <String, dynamic>{
      'port': 53,
      'action': 'hijack-dns',
    });
    expect(routeRules[1], <String, dynamic>{'action': 'sniff'});
    expect(
      dnsServers.singleWhere((server) => server['tag'] == 'dns-remote'),
      containsPair('type', 'tcp'),
    );
    expect(outbounds.where((outbound) => outbound['type'] == 'dns'), isEmpty);
    expect(
      routeRules.any(
        (rule) =>
            ((rule['rule_set'] as List?)?.contains(_ruIpWhitelistRuleSetTag) ??
                false) &&
            rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (rule) =>
            rule['domain_suffix'] == '.ru' && rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      dnsRules.any(
        (rule) =>
            (rule['rule_set'] as List?)?.contains(
              _ruDomainCategoryRuleSetTag,
            ) ??
            false,
      ),
      isTrue,
    );
    expect(route['auto_detect_interface'], true);
    expect(route['find_process'], true);
    expect(
      await File(
        _expectedRuleSetCachePath(tempDirectory, 'ru-ip-whitelist.srs'),
      ).exists(),
      isTrue,
    );
  });

  test(
      'all-except-ru falls back to suffix rules when local rule-set fetch fails',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-all-except-ru-fallback-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path.startsWith('/rule-sets/')) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-all-except-ru-fallback',
                    'account_id': '343',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['route_mode'], 'all_traffic');
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-all-except-ru-fallback',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      allExceptRuRuleSetUrlsResolver: (tag) =>
          <String>['http://127.0.0.1:${server.port}/rule-sets/$tag.srs'],
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.allExceptRu,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final route = config['route'] as Map<String, dynamic>;
    final routeRules = (route['rules'] as List).cast<Map<String, dynamic>>();
    final routeRuleSets = ((route['rule_set'] as List?) ?? const <Object?>[])
        .cast<Map<String, dynamic>>();

    expect(
      routeRules.any(
        (rule) =>
            rule['domain_suffix'] == '.ru' && rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      routeRuleSets.any(
        (ruleSet) =>
            (ruleSet['tag']?.toString().startsWith('pokrov-ru-') ?? false),
      ),
      isFalse,
    );
  });

  test(
      'android selected-apps route mode keeps selected packages local and writes tun include list',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-selected-apps-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-selected-apps',
                    'account_id': '341',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['route_mode'], 'selected_apps');
          expect(decoded.containsKey('selected_apps'), isFalse);
          expect(decoded['requires_elevated_privileges'], isTrue);
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-android-selected-apps',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'dns': <String, Object?>{
                      'servers': <Object?>[
                        <String, Object?>{
                          'tag': 'local',
                          'address': 'local',
                          'detour': 'direct',
                        },
                      ],
                      'final': 'local',
                    },
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.selectedApps,
      selectedApps: const <String>[
        'org.telegram.messenger',
        'com.example.special',
      ],
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final tunInbound = (config['inbounds'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((inbound) => inbound['type'] == 'tun');

    expect(tunInbound['include_package'], <String>[
      'org.telegram.messenger',
      'com.example.special',
    ]);
    expect(tunInbound.containsKey('exclude_package'), isFalse);
    expect(config['route'], containsPair('final', 'proxy'));
    final dns = config['dns'] as Map<String, dynamic>;
    final dnsServers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    expect(
      dnsServers.singleWhere((server) => server['tag'] == dns['final'])['detour'],
      'proxy',
    );
  });

  test(
      'android excluded-apps route keeps selected packages direct and the rest on VPN',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-excluded-apps-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-excluded-apps',
                    'account_id': '342',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['route_mode'], 'all_traffic');
          expect(decoded.containsKey('selected_apps'), isFalse);
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-android-excluded-apps',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{'final': 'proxy'},
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );
    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.excludedApps,
      selectedApps: const <String>['com.yandex.browser'],
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final tunInbound = (config['inbounds'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((inbound) => inbound['type'] == 'tun');

    expect(tunInbound.containsKey('include_package'), isFalse);
    expect(
      tunInbound['exclude_package'],
      containsAll(<String>[
        'space.pokrov.pokrov_android_shell',
        'com.yandex.browser',
      ]),
    );
    expect(config['route'], containsPair('final', 'proxy'));
  });

  for (final host in [HostPlatform.android, HostPlatform.windows]) {
    for (final selection in host == HostPlatform.windows
        ? <List<String>>[
            [],
            ['not a process']
          ]
        : <List<String>>[[]]) {
      test(
          '${host.name} selected-apps rejects an effectively empty selection $selection before bootstrap sync',
          () async {
        final bootstrapper = AppFirstRuntimeBootstrapper(
          apiBaseUrl: 'http://127.0.0.1:1/',
        );

        await expectLater(
          bootstrapper.resolveManagedProfile(
            hostPlatform: host,
            routeMode: RouteMode.selectedApps,
            selectedApps: selection,
          ),
          throwsA(
            isA<BootstrapFailure>().having(
              (error) => error.message,
              'message',
              'Выберите хотя бы одно приложение в разделе «Правила».',
            ),
          ),
        );
      });
    }
  }

  test(
      'windows selected-apps route mode limits proxy routing to selected processes',
      () async {
    const selectorTag = '🌍 Страны';
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-windows-selected-apps-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-windows-selected-apps',
                    'account_id': '342',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          if (decoded['route_mode'] != 'selected_apps') {
            expect(decoded['route_mode'], 'all_traffic');
          }
          expect(decoded.containsKey('selected_apps'), isFalse);
          expect(
            decoded['requires_elevated_privileges'],
            decoded['route_mode'] == 'selected_apps',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-windows-selected-apps',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': selectorTag,
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': selectorTag,
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.selectedApps,
      selectedApps: const <String>[
        'Telegram.exe',
        'msedge',
        'Discord.exe',
        'YouTube.exe',
      ],
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final dns = config['dns'] as Map<String, dynamic>;
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();
    final route = config['route'] as Map<String, dynamic>;
    final routeRules = (route['rules'] as List).cast<Map<String, dynamic>>();

    expect(route['find_process'], true);
    expect(route['final'], 'direct');
    expect(
      routeRules,
      contains(
        containsPair('process_name', <String>[
          'telegram.exe', 'msedge.exe', 'discord.exe', 'youtube.exe',
        ]),
      ),
    );
    expect(
      routeRules.any(
        (rule) =>
            (rule['process_name'] as List?)?.contains('telegram.exe') == true &&
            rule['outbound'] == selectorTag,
      ),
      isTrue,
    );
    expect(dns['final'], 'dns-remote');
    expect(
      (dns['servers'] as List).cast<Map>().singleWhere(
        (server) => server['tag'] == dns['final'],
      )['detour'],
      selectorTag,
    );
    expect(dns['reverse_mapping'], true);
    final serviceRoute = routeRules.singleWhere(
      (rule) => (rule['domain'] as List?)?.contains('discord.com') == true,
    );
    expect(serviceRoute['outbound'], selectorTag);
    expect(serviceRoute['domain'], containsAll(<String>[
      'discord.com', 'telegram.org', 'youtube.com', 'googlevideo.com',
    ]));
    expect(serviceRoute['domain_suffix'], contains('.discord.com'));
    final updaterRoute = routeRules.singleWhere(
      (rule) => rule.containsKey('process_path_regex'),
    );
    expect(updaterRoute['outbound'], selectorTag);
    final updaterPattern =
        (updaterRoute['process_path_regex'] as List).single as String;
    final updaterMatcher = RegExp(updaterPattern.replaceFirst('(?i)', ''),
      caseSensitive: false);
    expect(updaterMatcher.hasMatch(
      r'C:\Users\Tester\AppData\Local\Discord\app-1.0.0\Update.exe'), isTrue);
    expect(updaterMatcher.hasMatch(
      r'C:\Users\Tester\AppData\Local\Discord\app-2.0.0\Update.exe'), isTrue);
    expect(updaterMatcher.hasMatch(
      r'C:\Users\Tester\AppData\Local\Other\Update.exe'), isFalse);
    expect(dnsRules.any((rule) =>
      (rule['domain'] as List?)?.contains('youtube.com') == true &&
      rule['server'] == 'dns-remote'), isTrue);
    expect(
      dnsRules.any(
        (rule) =>
            (rule['process_name'] as List?)?.contains('msedge.exe') == true &&
            rule['server'] == 'dns-remote',
      ),
      isTrue,
    );
    final excludedPayload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.excludedApps,
      selectedApps: const <String>['YandexBrowser.exe'],
    );
    final excludedConfig =
        jsonDecode(excludedPayload.configPayload) as Map<String, dynamic>;
    final excludedDns = excludedConfig['dns'] as Map<String, dynamic>;
    final excludedDnsRules =
        (excludedDns['rules'] as List).cast<Map<String, dynamic>>();
    final excludedRoute = excludedConfig['route'] as Map<String, dynamic>;
    final excludedRouteRules =
        (excludedRoute['rules'] as List).cast<Map<String, dynamic>>();

    expect(excludedRoute['final'], selectorTag);
    expect(
      excludedRouteRules.any((rule) =>
          (rule['process_name'] as List?)?.contains('yandexbrowser.exe') ==
              true &&
          rule['outbound'] == 'direct'),
      isTrue,
    );
    expect(excludedDns['final'], 'dns-remote');
    expect(
      excludedDnsRules.any((rule) =>
          (rule['process_name'] as List?)?.contains('yandexbrowser.exe') ==
              true &&
          rule['server'] == 'dns-direct'),
      isTrue,
    );
  });

  test(
      'android full tunnel rewrites dns final away from direct bootstrap lanes',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-dns-final-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-dns-final',
                    'account_id': '339',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-android-dns-final',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'dns': <String, Object?>{
                      'servers': <Object?>[
                        <String, Object?>{
                          'tag': 'local',
                          'address': 'local',
                          'detour': 'direct',
                        },
                        <String, Object?>{
                          'tag': 'bootstrap-direct',
                          'address': 'https://1.1.1.1/dns-query',
                          'detour': 'direct',
                        },
                      ],
                      'final': 'local',
                    },
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                      <String, Object?>{
                        'type': 'direct',
                        'tag': 'direct',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final dns = config['dns'] as Map<String, dynamic>;
    final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    final finalServer = servers.singleWhere(
      (server) => server['tag'] == dns['final'],
    );

    expect(dns['final'], 'dns-remote');
    expect(
      servers.singleWhere((server) => server['tag'] == 'local')['type'],
      'local',
    );
    expect(
      servers
          .singleWhere((server) => server['tag'] == 'local')
          .containsKey('address'),
      isFalse,
    );
    expect(finalServer['address'], 'https://1.1.1.1/dns-query');
    expect(finalServer['detour'], 'proxy');
    expect(finalServer['address_resolver'], 'local');
  });

  for (final host in [
    HostPlatform.android,
    HostPlatform.windows,
    HostPlatform.linux,
  ]) {
    for (final mode in host == HostPlatform.linux
        ? [RouteMode.fullTunnel]
        : RouteMode.values.where((mode) => mode != RouteMode.selectiveServices)) {
      for (final ready in host == HostPlatform.linux
          ? [true]
          : host == HostPlatform.windows
              ? [false, true]
              : [false]) {
        test(
            '${host.name} ${mode.name} removes direct from VPN selector and urltest chains (runtimeReady=$ready)',
            () async {
          final tempDirectory = await Directory.systemTemp.createTemp(
            'pokrov-bootstrap-android-selector-sanitize-test-',
          );
          addTearDown(() async {
            if (await tempDirectory.exists()) {
              await tempDirectory.delete(recursive: true);
            }
          });

          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(server.close);
          unawaited(() async {
            await for (final request in server) {
              await utf8.decoder.bind(request).join();
              if (request.uri.path == '/api/client/session/start-trial') {
                request.response
                  ..headers.contentType = ContentType.json
                  ..write(
                    jsonEncode(
                      <String, Object?>{
                        'session': <String, Object?>{
                          'session_token':
                              'session-token-android-selector-sanitize',
                          'account_id': '340',
                        },
                        'provisioning': <String, Object?>{
                          'status': 'ready',
                          'sync_ok': true,
                          'managed_manifest': <String, Object?>{
                            'url': '/api/client/profile/managed',
                          },
                        },
                      },
                    ),
                  );
                await request.response.close();
                continue;
              }

              if (request.uri.path == '/api/client/route-policy') {
                request.response
                  ..headers.contentType = ContentType.json
                  ..write(jsonEncode(<String, Object?>{'ok': true}));
                await request.response.close();
                continue;
              }

              if (request.uri.path == '/api/client/profile/managed') {
                request.response
                  ..headers.contentType = ContentType.json
                  ..write(
                    jsonEncode(
                      <String, Object?>{
                        'provisioning': <String, Object?>{
                          'status': 'ready',
                          'sync_ok': true,
                        },
                        'profile_revision': 'rev-android-selector-sanitize',
                        'config_format': 'singbox-json',
                        'config_payload': <String, Object?>{
                          if (ready)
                            'dns': <String, Object?>{
                              'servers': <Object?>[
                                <String, Object?>{
                                  'type': 'local',
                                  'tag': 'bootstrap'
                                },
                                <String, Object?>{
                                  'type': 'https',
                                  'tag': 'sealed',
                                  'server': '9.9.9.9',
                                  'path': '/private-dns-query',
                                  'domain_resolver': <String, Object?>{
                                    'server': 'dns-direct',
                                    'strategy': 'ipv4_only'
                                  },
                                  'tls': <String, Object?>{
                                    'server_name': 'dns.example'
                                  },
                                  'detour': 'select'
                                },
                              ],
                              'rules': <Object?>[
                                <String, Object?>{
                                  'query_type': <String>['AXFR'],
                                  'action': 'reject'
                                },
                                <String, Object?>{
                                  'process_name': <String>['old.exe'],
                                  'server': 'sealed'
                                },
                                <String, Object?>{
                                  'rule_set': <String>['geoip-ru'],
                                  'server': 'sealed'
                                }
                              ],
                              'final': 'sealed',
                              'independent_cache': true,
                            },
                          if (ready)
                            'inbounds': <Object?>[
                              <String, Object?>{
                                'type': 'tun',
                                'tag': 'tun-in',
                                'address': <String>['172.19.0.1/28']
                              }
                            ],
                          'outbounds': <Object?>[
                            <String, Object?>{
                              'type': 'selector',
                              'tag': 'select',
                              'outbounds': <Object?>['auto', 'direct'],
                              'default': 'direct',
                            },
                            <String, Object?>{
                              'type': 'urltest',
                              'tag': 'auto',
                              'outbounds': <Object?>['direct', 'node-1'],
                              'url': 'http://cp.cloudflare.com',
                            },
                            <String, Object?>{
                              'type': 'vless',
                              'tag': 'node-1',
                              'server': 'nl.kiwunaka.space',
                              'server_port': 443,
                              'uuid': 'test-uuid',
                            },
                            if (!ready)
                              <String, Object?>{
                                'type': 'direct',
                                'tag': 'direct',
                              },
                          ],
                          'route': <String, Object?>{
                            if (ready)
                              'default_domain_resolver': <String, Object?>{
                                'server': 'bootstrap',
                                'strategy': 'prefer_ipv4',
                              },
                            if (ready)
                              'rules': <Object?>[
                                <String, Object?>{
                                  'process_name': <String>['old.exe'],
                                  'outbound': 'select'
                                },
                                <String, Object?>{
                                  'domain_suffix': <String>['.ru'],
                                  'outbound': 'direct'
                                },
                                <String, Object?>{
                                  'rule_set': <String>['geoip-ru'],
                                  'outbound': 'direct'
                                }
                              ],
                            'final': ready && mode == RouteMode.selectedApps
                                ? 'direct'
                                : 'select',
                          },
                        },
                      },
                    ),
                  );
                await request.response.close();
                continue;
              }

              request.response.statusCode = HttpStatus.notFound;
              await request.response.close();
            }
          }());

          final bootstrapper = AppFirstRuntimeBootstrapper(
            apiBaseUrl: 'http://127.0.0.1:${server.port}/',
            supportDirectoryResolver: () async => tempDirectory,
            allExceptRuRuleSetUrlsResolver: (_) =>
                <String>['http://127.0.0.1:${server.port}/missing-rules'],
          );

          final payload = await bootstrapper.resolveManagedProfile(
            hostPlatform: host,
            routeMode: mode,
            selectedApps: host == HostPlatform.linux
                ? const <String>[]
                : host == HostPlatform.android
                    ? const <String>['org.telegram.messenger']
                    : const <String>['telegram.exe'],
          );
          final config =
              jsonDecode(payload.configPayload) as Map<String, dynamic>;
          final outbounds =
              (config['outbounds'] as List).cast<Map<String, dynamic>>();
          final selector =
              outbounds.singleWhere((outbound) => outbound['tag'] == 'select');
          final urltest =
              outbounds.singleWhere((outbound) => outbound['tag'] == 'auto');
          final route = config['route'] as Map<String, dynamic>;

          if (ready) {
            final dns = config['dns'] as Map<String, dynamic>;
            expect(
                outbounds.singleWhere(
                    (outbound) => outbound['tag'] == 'direct')['type'],
                'direct');
            final rules = (route['rules'] as List? ?? []).cast<Map>();
            final dnsRules = (dns['rules'] as List? ?? []).cast<Map>();
            expect(route['find_process'],
                host == HostPlatform.windows ? isTrue : isNull);
            expect(route['default_domain_resolver'], <String, Object?>{
              'server': 'dns-direct',
              'strategy': 'ipv4_only',
            });
            expect(
                rules.any((rule) =>
                    (rule['process_name'] as List?)?.contains('old.exe') ==
                    true),
                isFalse);
            expect(
                rules.any((rule) =>
                    (rule['domain_suffix'] as List?)?.contains('.ru') == true &&
                    rule['outbound'] == 'direct'),
                mode == RouteMode.allExceptRu);
            expect(
                dnsRules.any((rule) =>
                    (rule['process_name'] as List?)?.contains('old.exe') ==
                    true),
                isFalse);
            expect(rules.first, containsPair('action', 'hijack-dns'));
            if (mode == RouteMode.fullTunnel) {
              expect(
                  rules.any((rule) =>
                      rule['outbound'] == 'direct' && rule['rule_set'] != null),
                  isFalse);
              expect(
                  dnsRules.any((rule) =>
                      (rule['rule_set'] as List?)?.contains('geoip-ru') ==
                      true),
                  isFalse);
            }
            if (mode == RouteMode.selectedApps ||
                mode == RouteMode.excludedApps) {
              final processRule = rules.singleWhere((rule) =>
                  (rule['process_name'] as List?)?.contains('telegram.exe') ==
                  true);
              expect(processRule['outbound'],
                  mode == RouteMode.selectedApps ? 'select' : 'direct');
              expect(
                  dnsRules.any((rule) =>
                      (rule['process_name'] as List?)
                          ?.contains('telegram.exe') ==
                      true),
                  isTrue);
            }
            expect(dnsRules.first['action'], 'reject');
            final servers = (dns['servers'] as List).cast<Map>();
            final directDns =
                servers.singleWhere((server) => server['tag'] == 'dns-direct');
            expect(directDns['domain_resolver'], <String, Object?>{
              'server': 'dns-local',
              'strategy': 'ipv4_only'
            });
            final routedDns =
                servers.singleWhere((server) => server['tag'] == dns['final']);
            expect(routedDns['type'], 'https');
            expect(routedDns['server'], '9.9.9.9');
            expect(routedDns['path'], '/private-dns-query');
            expect(routedDns['tls'],
                <String, Object?>{'server_name': 'dns.example'});
            expect(routedDns['detour'], 'select');
            final tun = (config['inbounds'] as List).cast<Map>().single;
            expect(tun['address'], <String>['172.19.0.1/28']);
          }
          expect(selector['outbounds'], isNot(contains('direct')));
          expect(selector['default'], isNot('direct'));
          expect(urltest['outbounds'], isNot(contains('direct')));
          if (host == HostPlatform.android)
            expect(
              urltest['url'],
              'https://api.pokrov.space/api/public/authenticated-egress-probe',
            );
          expect(
              route['final'],
              host == HostPlatform.windows && mode == RouteMode.selectedApps
                  ? 'direct'
                  : 'select');
        });
      }
    }
  }

  test(
      'android ipv4-only support context does not keep a dead ipv6 tunnel lane',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-ipv4-only-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-ipv4-only',
                    'account_id': '420',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-android-ipv4-only',
                  'config_format': 'singbox-json',
                  'support_context': <String, Object?>{
                    'ip_version_preference': 'ipv4_only',
                    'tun_mtu': 1400,
                  },
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'node-1',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final tunInbound = (config['inbounds'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((inbound) => inbound['type'] == 'tun');

    expect(tunInbound['address'], <String>['172.19.0.1/28']);
    expect(tunInbound.containsKey('inet4_address'), isFalse);
    expect(tunInbound.containsKey('inet6_address'), isFalse);
    expect(tunInbound.containsKey('domain_strategy'), isFalse);
    expect(tunInbound['stack'], 'gvisor');
    expect(tunInbound['mtu'], 1400);
  });

  test('client P0/P1 API additions use the app-first session', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-client-ui-api-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    Map<String, dynamic>? pushBody;
    Map<String, dynamic>? readBody;
    Map<String, dynamic>? dismissBody;
    Map<String, dynamic>? deviceMetadataBody;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'client-ui-session',
                    'account_id': 'client-ui-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer client-ui-session',
        );

        if (request.uri.path == '/api/client/locations') {
          expect(request.uri.queryParameters['platform'], 'windows');
          expect(request.uri.queryParameters['q'], 'ams');
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'auto': <String, Object?>{
                    'enabled': true,
                    'currentCode': 'nl-ams-01',
                  },
                  'freePoolCode': 'nl-free',
                  'profileRevision': 'rev-locations',
                  'transportProfile': 'reality',
                  'countries': <Object?>[
                    <String, Object?>{
                      'code': 'nl',
                      'country': 'Netherlands',
                      'cities': <Object?>[
                        <String, Object?>{
                          'code': 'nl-ams-01',
                          'city': 'Amsterdam',
                          'healthScore': 0.94,
                          'latencyMs': 38,
                          'premium': true,
                          'load': 0.31,
                          'measuredAt': '2026-07-23T10:15:00+00:00',
                        },
                        <String, Object?>{
                          'code': 'nl-ams-unknown',
                          'city': 'Amsterdam unknown',
                          'latencyMs': 44,
                          'premium': false,
                          'load': 0.42,
                          'measuredAt': '2026-07-23T10:15:00+00:00',
                        },
                      ],
                    },
                  ],
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/subscription') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'lane': 'trialPremium',
                  'expiresAt': '2026-06-27T00:00:00Z',
                  'daysLeft': 5,
                  'autoRenew': false,
                  'renewUrl': 'https://pay.pokrov.space/checkout/client-ui',
                  'trafficPolicy': <String, Object?>{
                    'freePoolCode': 'nl-free',
                    'premiumAccess': true,
                  },
                  'identities': <String, Object?>{
                    'telegram': <String, Object?>{
                      'linked': true,
                      'username': 'pokrov_owner',
                    },
                    'email': <String, Object?>{
                      'linked': true,
                      'address': 'owner@pokrov.test',
                      'verified': true,
                    },
                  },
                  'plans': <Object?>[
                    <String, Object?>{
                      'id': '1m',
                      'title': '1 month',
                      'price': '299 RUB',
                    },
                  ],
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/devices/current') {
          deviceMetadataBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/devices') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'items': <Object?>[
                    <String, Object?>{
                      'id': 'current-device',
                      'label': 'Windows 11',
                      'platform': 'windows',
                      'lastSeen': '2026-06-22T10:00:00Z',
                      'current': true,
                    },
                  ],
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/notifications') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'items': <Object?>[
                    <String, Object?>{
                      'id': 'ntf_access',
                      'kind': 'access',
                      'title': 'Access ready',
                      'body': 'You can connect now.',
                      'createdAt': '2026-06-22T10:01:00Z',
                      'ctaLabel': 'Open',
                      'ctaHref': 'https://app.pokrov.space/profile',
                      'read': false,
                    },
                  ],
                  'nextCursor': null,
                  'unreadCount': 1,
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/notifications/read') {
          readBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/notifications/dismiss') {
          dismissBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/push/register') {
          pushBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'ok': true,
                  'provider': 'wns',
                  'tokenHash': 'sha256:token',
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      deviceNameResolver: (_) async => 'Surface Laptop',
    );

    final catalog = await bootstrapper.fetchLocationsCatalog(
      hostPlatform: HostPlatform.windows,
      query: 'ams',
    );
    expect(catalog.auto.currentCode, 'nl-ams-01');
    final cities = catalog.countries.single.cities;
    expect(cities.first.city, 'Amsterdam');
    expect(cities.first.premium, isTrue);
    expect(cities.first.latencyMs, 38);
    expect(cities.first.load, 0.31);
    expect(
      cities.first.measuredAt,
      '2026-07-23T10:15:00+00:00',
    );
    expect(cities.last.city, 'Amsterdam unknown');
    expect(cities.last.healthScore, isNull);
    expect(cities.last.toJson(), isNot(contains('healthScore')));

    final subscription = await bootstrapper.fetchClientSubscription(
      hostPlatform: HostPlatform.windows,
    );
    expect(subscription.lane, 'trialPremium');
    expect(subscription.daysLeft, 5);
    expect(subscription.plans.single.id, '1m');
    expect(subscription.telegramLinked, isTrue);
    expect(subscription.telegramUsername, 'pokrov_owner');
    expect(subscription.emailAddress, 'owner@pokrov.test');
    expect(subscription.emailVerified, isTrue);

    final devices = await bootstrapper.fetchClientDevices(
      hostPlatform: HostPlatform.windows,
    );
    expect(devices.items.single.current, isTrue);
    expect(
      deviceMetadataBody,
      containsPair('device_name', 'POKROV Windows Surface Laptop'),
    );

    final inbox = await bootstrapper.fetchClientNotifications(
      hostPlatform: HostPlatform.windows,
    );
    expect(inbox.unreadCount, 1);
    expect(inbox.items.single.ctaHref?.host, 'app.pokrov.space');

    final read = await bootstrapper.markClientNotificationsRead(
      hostPlatform: HostPlatform.windows,
      ids: const <String>['ntf_access'],
    );
    expect(read, isTrue);
    expect(readBody, containsPair('ids', <Object?>['ntf_access']));

    final dismissed = await bootstrapper.dismissClientNotifications(
      hostPlatform: HostPlatform.windows,
      ids: const <String>['ntf_access'],
    );
    expect(dismissed, isTrue);
    expect(dismissBody, containsPair('ids', <Object?>['ntf_access']));

    final push = await bootstrapper.registerClientPushToken(
      hostPlatform: HostPlatform.windows,
      token: 'wns-token',
      provider: 'wns',
    );
    expect(push.ok, isTrue);
    expect(push.tokenHash, 'sha256:token');
    expect(pushBody, containsPair('platform', 'windows'));
    expect(pushBody, containsPair('provider', 'wns'));
    expect(pushBody, containsPair('token', 'wns-token'));

    expect(
      requests,
      containsAllInOrder(const [
        'POST /api/client/session/start-trial',
        'GET /api/client/locations',
        'GET /api/client/subscription',
        'GET /api/client/devices',
        'GET /api/client/notifications',
        'POST /api/client/notifications/read',
        'POST /api/client/notifications/dismiss',
        'POST /api/client/push/register',
      ]),
    );
  });

  test('client support assistant uses app-session auth and a safe wire token',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-client-assistant-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final assistantBodies = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'assistant-session',
                    'account_id': 'assistant-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer assistant-session',
        );

        if (request.uri.path == '/api/client/support/assistant') {
          final assistantBody = jsonDecode(body) as Map<String, dynamic>;
          assistantBodies.add(assistantBody);
          final requestNumber = assistantBodies.length;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'reply': 'Try reconnecting once, then send diagnostics.',
                  if (requestNumber == 1)
                    'assistantSessionId': 'session_1234567890abcdef',
                  if (requestNumber == 2)
                    'assistant_session_id': 'snake_1234567890abcdef',
                  'shouldEscalate': false,
                  'suggestedActions': <Object?>[
                    <String, Object?>{
                      'key': 'retry_connect',
                      'label': 'Retry',
                    },
                  ],
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final camelReply = await bootstrapper.askSupportAssistant(
      hostPlatform: HostPlatform.windows,
      message: 'Connection is closed',
      ticketId: 77,
      assistantSessionId: 'session_abcdefghijklmnop',
      safeDiagnostics: const <String, Object?>{
        'phase': 'running',
        'warp_status': 'active',
      },
    );
    final snakeReply = await bootstrapper.askSupportAssistant(
      hostPlatform: HostPlatform.windows,
      message: 'Connection is still closed',
      safeDiagnostics: const <String, Object?>{
        'phase': 'degraded',
        'warp_status': 'inactive',
      },
    );
    final invalidOutboundReply = await bootstrapper.askSupportAssistant(
      hostPlatform: HostPlatform.windows,
      message: 'Start a clean assistant request',
      assistantSessionId: 'invalid token',
      safeDiagnostics: const <String, Object?>{
        'phase': 'idle',
        'warp_status': 'inactive',
      },
    );

    expect(camelReply.reply, contains('reconnecting'));
    expect(camelReply.assistantSessionId, 'session_1234567890abcdef');
    expect(camelReply.shouldEscalate, isFalse);
    expect(camelReply.suggestedActions.single.key, 'retry_connect');
    expect(snakeReply.assistantSessionId, 'snake_1234567890abcdef');
    expect(invalidOutboundReply.assistantSessionId, isNull);
    expect(assistantBodies, hasLength(3));
    expect(assistantBodies.first, containsPair('ticketId', 77));
    expect(
      assistantBodies.first,
      containsPair('message', 'Connection is closed'),
    );
    expect(
      assistantBodies.first,
      containsPair('assistantSessionId', 'session_abcdefghijklmnop'),
    );
    expect(
      assistantBodies.first['safeDiagnostics'],
      containsPair('warp_status', 'active'),
    );
    expect(assistantBodies.first, containsPair('scope', 'support'));
    expect(assistantBodies[1], isNot(contains('assistantSessionId')));
    expect(assistantBodies[2], isNot(contains('assistantSessionId')));
    expect(
      assistantBodies.map((body) => body['safeDiagnostics']),
      everyElement(isA<Map<String, dynamic>>()),
    );
  });

  test('support POSTs get one longer request window', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-client-assistant-timeout-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    var assistantRequestCount = 0;
    var trialRequestCount = 0;
    var ticketRequestCount = 0;
    var messageRequestCount = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        if (request.uri.path == '/api/client/session/start-trial') {
          trialRequestCount += 1;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'assistant-timeout-session',
                    'account_id': 'assistant-timeout-account',
                  },
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/client/support/assistant') {
          assistantRequestCount += 1;
          await utf8.decoder.bind(request).join();
          await Future<void>.delayed(const Duration(milliseconds: 80));
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'reply': 'Проверка закончена.',
                  'shouldEscalate': false,
                },
              ),
            );
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/tickets' ||
            request.uri.path == '/api/tickets/321/messages') {
          final isCreate = request.uri.path == '/api/tickets';
          if (isCreate) {
            ticketRequestCount += 1;
          } else {
            messageRequestCount += 1;
          }
          final body = jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
          await Future<void>.delayed(const Duration(milliseconds: 80));
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'ticket': _supportTicketJson(
                id: 321,
                messages: <Object?>[
                  _supportMessageJson(
                    id: isCreate ? 1 : 2,
                    ticketId: 321,
                    senderRole: 'user',
                    body: body['body'] as String,
                  ),
                ],
              ),
            }));
          await request.response.close();
          continue;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      requestTimeout: const Duration(milliseconds: 30),
      maxRequestAttempts: 3,
    );

    final reply = await bootstrapper.askSupportAssistant(
      hostPlatform: HostPlatform.android,
      message: 'Почему не работает WARP?',
    );

    expect(reply.reply, 'Проверка закончена.');
    final service = AppFirstSupportTicketService(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      requestTimeout: const Duration(milliseconds: 30),
      maxRequestAttempts: 3,
    );
    final receipt = await service.createTicket(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.allExceptRu,
      statusLabel: 'Ready',
      body: 'Connection help',
    );
    expect(receipt.ticketId, 321);
    final updated = await service.sendMessage(
      hostPlatform: HostPlatform.android,
      ticketId: 321,
      body: 'Follow up',
    );
    expect(updated.messages.last.body, 'Follow up');
    expect(assistantRequestCount, 1);
    expect(ticketRequestCount, 1);
    expect(messageRequestCount, 1);
    expect(trialRequestCount, 1);
  });

  test(
      'client support assistant accepts token boundaries and rejects malformed tokens',
      () {
    const token16 = 'abcdefghijklmnop';
    final token64 = List<String>.filled(64, 'a').join();
    final token15 = List<String>.filled(15, 'a').join();
    final token65 = List<String>.filled(65, 'a').join();

    ClientSupportAssistantReply parse(String key, Object? value) {
      return ClientSupportAssistantReply.fromJson(<String, dynamic>{
        'reply': 'ok',
        key: value,
        'shouldEscalate': false,
        'suggestedActions': <Object?>[],
      });
    }

    expect(parse('assistantSessionId', token16).assistantSessionId, token16);
    expect(
      parse('assistant_session_id', token64).assistantSessionId,
      token64,
    );
    for (final malformed in <Object?>[
      null,
      token15,
      token65,
      'contains whitespace',
      'invalid!character123',
      1234567890123456,
    ]) {
      expect(
        parse('assistantSessionId', malformed).assistantSessionId,
        isNull,
        reason: 'must reject malformed token: $malformed',
      );
    }
  });

  test('client support assistant sanitizes backend source for consumers', () {
    ClientSupportAssistantSource sourceFor(Object? source) {
      return ClientSupportAssistantReply.fromJson(<String, dynamic>{
        'reply': 'ok',
        'source': source,
        'shouldEscalate': false,
        'suggestedActions': <Object?>[],
      }).source;
    }

    expect(
      sourceFor('support_agent'),
      ClientSupportAssistantSource.pokrovAssistant,
    );
    expect(
        sourceFor('support_ai'), ClientSupportAssistantSource.pokrovAssistant);
    expect(
      sourceFor('local_fallback'),
      ClientSupportAssistantSource.localFallback,
    );
    expect(sourceFor('unrecognized-backend'),
        ClientSupportAssistantSource.localFallback);
    expect(sourceFor(null), ClientSupportAssistantSource.localFallback);
  });

  test('client update discovery is anonymous and defaults to stable', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-public-update-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    var starts = 0;
    String? authorization;
    Uri? requestUri;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        if (request.uri.path == '/api/client/session/start-trial') {
          starts += 1;
          request.response.statusCode = HttpStatus.internalServerError;
        } else if (request.uri.path == '/api/public/client-apps') {
          requestUri = request.uri;
          authorization =
              request.headers.value(HttpHeaders.authorizationHeader);
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'android': <String, Object?>{
                'version': '1.0.6',
                'update': <String, Object?>{
                  'platform': 'android',
                  'channel': 'stable',
                  'latest_version': '1.0.6',
                  'update_policy': 'recommended',
                  'url':
                      'https://github.com/Kiwunaka/pokrov/releases/download/v1.0.6/pokrov-android-arm64-v8a.apk',
                },
              },
              'windows': <String, Object?>{},
              'update_check': <String, Object?>{'mode': 'prompt'},
            }));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      androidAbiResolver: (_) async => 'x86_64',
      maxRequestAttempts: 1,
    );

    final metadata = await bootstrapper.fetchClientApps(
      hostPlatform: HostPlatform.android,
      currentVersion: '1.0.5',
    );

    expect(metadata.android.update.latestVersion, '1.0.6');
    expect(metadata.android.update.channel, 'stable');
    expect(requestUri?.queryParameters['channel'], 'stable');
    expect(requestUri?.queryParameters['current_version'], '1.0.5');
    expect(requestUri?.queryParameters['android_abi'], 'x86_64');
    expect(authorization, isNull);
    expect(starts, 0);
    expect(
      File('${tempDirectory.path}${Platform.pathSeparator}'
              'app-first-session-android.json')
          .existsSync(),
      isFalse,
    );
  });

  test('shares initial state and start-trial across concurrent client services',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-initial-single-flight-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final startRead = Completer<void>();
    final releaseStart = Completer<void>();
    var starts = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            starts += 1;
            startRead.complete();
            await releaseStart.future;
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(<String, Object?>{
                'access_token': 'shared-access',
                'refresh_token': 'shared-refresh',
                'account_id': '42',
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true,
                },
              }));
          case '/api/public/client-apps':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"android":{},"windows":{},"update_check":{}}');
          case '/api/client/subscription':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{}');
          case '/api/client/devices':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"devices":[]}');
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());

    final secretStore = MemoryAppFirstSessionSecretStore();
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: secretStore,
      invitationReceiver: OfflineInvitationReceiver(
          trust: OfflineInvitationTrust(audience: 'production', issuerPublicKeys: const {})),
      maxRequestAttempts: 3,
    );
    final services = <Future<dynamic>>[
      bootstrapper.fetchClientApps(
        hostPlatform: HostPlatform.windows,
        currentVersion: '1.0.1',
      ),
      bootstrapper.fetchClientSubscription(hostPlatform: HostPlatform.windows),
      bootstrapper.fetchClientDevices(hostPlatform: HostPlatform.windows),
    ];

    await startRead.future.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);
    expect(starts, 1);
    releaseStart.complete();
    await Future.wait<dynamic>(services).timeout(const Duration(seconds: 5));

    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    );
    final state =
        jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    expect(starts, 1);
    expect(state['session_token_storage'], 'secure');
    expect(state.containsKey('session_token'), isFalse);
    final pair = await secretStore.readSessionPair(
      hostPlatform: HostPlatform.windows,
      installId: state['install_id'] as String,
    );
    expect(pair?.hasAccessToken, isTrue);
  });

  test(
      'does not replay start-trial after the server commits then loses response',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-start-trial-one-attempt-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    var starts = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          starts += 1;
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          socket.destroy();
          continue;
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      delayScheduler: (_) async {},
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(isA<BootstrapFailure>().having(
        (error) => error.message,
        'message',
        'Не удалось связаться с сервисом. Проверьте сеть и попробуйте ещё раз.',
      )),
    );
    expect(starts, 1);
  });

  test('does not replay refresh after the server commits then loses response',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-refresh-one-attempt-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    const installId = 'refresh-one-attempt-install';
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    );
    await stateFile.writeAsString(jsonEncode(<String, Object?>{
      'install_id': installId,
      'session_token_storage': 'secure',
      'managed_manifest_path': '/api/client/profile/managed',
      'profile_revision': '',
    }));
    final secretStore = MemoryAppFirstSessionSecretStore();
    await secretStore.writeSessionPair(
      hostPlatform: HostPlatform.windows,
      installId: installId,
      pair: const AppFirstSessionCredentials(
        accessToken: 'expired-access',
        refreshToken: 'old-refresh',
      ),
    );
    var refreshes = 0;
    var starts = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        switch (request.uri.path) {
          case '/api/client/profile/managed':
            request.response.statusCode = HttpStatus.unauthorized;
          case '/api/client/session/refresh':
            refreshes += 1;
            final socket = await request.response.detachSocket(
              writeHeaders: false,
            );
            socket.destroy();
            continue;
          case '/api/client/session/start-trial':
            starts += 1;
            request.response.statusCode = HttpStatus.notFound;
          case '/api/client/route-policy':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"ok":true}');
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: secretStore,
      delayScheduler: (_) async {},
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(isA<BootstrapFailure>().having(
        (error) => error.message,
        'message',
        'Не удалось связаться с сервисом. Проверьте сеть и попробуйте ещё раз.',
      )),
    );
    expect(refreshes, 1);
    expect(starts, 0);
  });

  test('does not treat a missing client resource as session expiry', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-missing-resource-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    const installId = 'missing-resource-install';
    await File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    ).writeAsString(jsonEncode(<String, Object?>{
      'install_id': installId,
      'session_token_storage': 'secure',
      'managed_manifest_path': '/api/client/profile/managed',
      'profile_revision': '',
    }));
    final secretStore = MemoryAppFirstSessionSecretStore();
    await secretStore.writeSessionPair(
      hostPlatform: HostPlatform.windows,
      installId: installId,
      pair: const AppFirstSessionCredentials(
        accessToken: 'resource-access',
        refreshToken: 'resource-refresh',
      ),
    );
    var devices = 0;
    var starts = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/devices') {
          devices += 1;
          request.response.statusCode = HttpStatus.notFound;
        } else if (request.uri.path == '/api/client/session/start-trial') {
          starts += 1;
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: secretStore,
      maxRequestAttempts: 1,
    );

    await expectLater(
      bootstrapper.fetchClientDevices(hostPlatform: HostPlatform.windows),
      throwsA(isA<BootstrapFailure>().having(
        (error) => error.statusCode,
        'statusCode',
        HttpStatus.notFound,
      )),
    );
    expect(devices, 1);
    expect(starts, 0);
  });

  test('bounds a stalled JSON response body with safe recovery copy', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-stalled-json-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    var starts = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          starts += 1;
          request.response.write('{"partial":');
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 120));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      requestTimeout: const Duration(milliseconds: 25),
      maxRequestAttempts: 1,
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(
        isA<BootstrapFailure>()
            .having((error) => error.statusCode, 'statusCode',
                HttpStatus.gatewayTimeout)
            .having(
              (error) => error.message,
              'message',
              'Сервис не ответил вовремя. Попробуйте ещё раз.',
            ),
      ),
    );
    expect(starts, 1);
  });

  test('rejects an oversized JSON response before buffering it', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-oversized-json-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    var starts = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          starts += 1;
          request.response.add(List<int>.filled(8 * 1024 * 1024 + 1, 0));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      maxRequestAttempts: 1,
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(isA<BootstrapFailure>().having(
        (error) => error.message,
        'message',
        'Ответ сервиса оказался слишком большим. Попробуйте ещё раз.',
      )),
    );
    expect(starts, 1);
  });

  test('rejects oversized rulesets without caching partial bytes', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-oversized-ruleset-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    var rulesetRequests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final oversizedRuleSetUrl = 'http://127.0.0.1:${server.port}/ruleset.srs';
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(<String, Object?>{
                'access_token': 'ruleset-access',
                'refresh_token': 'ruleset-refresh',
                'account_id': '42',
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true,
                },
              }));
          case '/api/client/route-policy':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"ok":true}');
          case '/api/client/profile/managed':
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_readyManagedProfile('oversized-ruleset')));
          case '/ruleset.srs':
            rulesetRequests += 1;
            request.response.contentLength = 33 * 1024 * 1024;
            request.response.add(<int>[0]);
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 25));
            try {
              await request.response.close();
            } on HttpException {
              // The client rejects the advertised oversize before body drain.
            }
            continue;
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      allExceptRuRuleSetUrlsResolver: (_) => <String>[oversizedRuleSetUrl],
      maxRequestAttempts: 1,
    );

    await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.allExceptRu,
    );

    expect(rulesetRequests, 4);
    for (final fileName in const <String>[
      'ru-domain-whitelist.srs',
      'ru-domain-category.srs',
      'ru-ip-country.srs',
      'ru-ip-whitelist.srs',
    ]) {
      expect(
          await File(_expectedRuleSetCachePath(tempDirectory, fileName))
              .exists(),
          isFalse);
    }
  });

  test('accepts only canonical relative managed manifest paths', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-managed-path-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final paths = <String>[
      '/api/client/profile/managed?release=2026_08',
      'https://untrusted.invalid/api/client/profile/managed',
      '//untrusted.invalid/api/client/profile/managed',
      '/api/client/profile/managed/../other',
      '/api/client/other',
    ];
    var startIndex = 0;
    var profileRequests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            final path = paths[startIndex++];
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(<String, Object?>{
                'access_token': 'path-access-$startIndex',
                'refresh_token': 'path-refresh-$startIndex',
                'account_id': '42',
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true,
                  'managed_manifest': <String, Object?>{'url': path},
                },
              }));
          case '/api/client/route-policy':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"ok":true}');
          case '/api/client/profile/managed':
            profileRequests += 1;
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_readyManagedProfile('safe-path')));
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());

    AppFirstRuntimeBootstrapper bootstrapperFor(int index) =>
        AppFirstRuntimeBootstrapper(
          apiBaseUrl: 'http://127.0.0.1:${server.port}/',
          supportDirectoryResolver: () async => Directory(
            '${tempDirectory.path}${Platform.pathSeparator}$index',
          ),
          maxRequestAttempts: 1,
        );

    final valid = await bootstrapperFor(0).resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    expect(valid.profileName, 'pokrov-windows-safe-path');
    expect(profileRequests, 1);

    for (var index = 1; index < paths.length; index += 1) {
      await expectLater(
        bootstrapperFor(index).resolveManagedProfile(
          hostPlatform: HostPlatform.windows,
          routeMode: RouteMode.fullTunnel,
        ),
        throwsA(isA<BootstrapFailure>().having(
          (error) => error.message,
          'message',
          'POKROV получил недопустимый путь профиля. Обновите настройки и попробуйте ещё раз.',
        )),
      );
    }
    expect(profileRequests, 1);
  });

  test(
      'rejects a hostile persisted managed manifest before authorized requests',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-persisted-managed-path-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    const installId = 'hostile-persisted-managed-path';
    await File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'app-first-session-windows.json',
    ).writeAsString(jsonEncode(<String, Object?>{
      'install_id': installId,
      'session_token_storage': 'secure',
      'managed_manifest_path': 'https://untrusted.invalid/profile',
      'profile_revision': '',
    }));
    final secretStore = MemoryAppFirstSessionSecretStore();
    await secretStore.writeSessionPair(
      hostPlatform: HostPlatform.windows,
      installId: installId,
      pair: const AppFirstSessionCredentials(
        accessToken: 'persisted-access',
        refreshToken: 'persisted-refresh',
      ),
    );
    var requests = 0;
    var authorizedRequests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        requests += 1;
        if ((request.headers.value(HttpHeaders.authorizationHeader) ?? '')
            .isNotEmpty) {
          authorizedRequests += 1;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: secretStore,
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel,
      ),
      throwsA(isA<BootstrapFailure>().having(
        (error) => error.message,
        'message',
        'POKROV получил недопустимый путь профиля. Обновите настройки и попробуйте ещё раз.',
      )),
    );
    expect(requests, 0);
    expect(authorizedRequests, 0);
  });

  test('retries a managed-profile GET after 5xx and uses the final response',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-managed-get-retry-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    var profileRequests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(<String, Object?>{
                'access_token': 'managed-retry-access',
                'refresh_token': 'managed-retry-refresh',
                'account_id': '42',
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true,
                },
              }));
          case '/api/client/route-policy':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"ok":true}');
          case '/api/client/profile/managed':
            profileRequests += 1;
            if (profileRequests == 1) {
              request.response
                ..statusCode = HttpStatus.serviceUnavailable
                ..write('temporary profile failure');
            } else {
              request.response
                ..headers.contentType = ContentType.json
                ..write(jsonEncode(_readyManagedProfile('managed-get-final')));
            }
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      maxRequestAttempts: 2,
      delayScheduler: (_) async {},
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );

    expect(profileRequests, 2);
    expect(payload.profileName, 'pokrov-windows-managed-get-final');
  });

  test('retries rule-set GETs after 5xx and caches only final bytes', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-ruleset-get-retry-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final requestsByTag = <String, int>{};
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(<String, Object?>{
                'access_token': 'ruleset-retry-access',
                'refresh_token': 'ruleset-retry-refresh',
                'account_id': '42',
                'provisioning': <String, Object?>{
                  'status': 'ready',
                  'sync_ok': true,
                },
              }));
          case '/api/client/route-policy':
            request.response
              ..headers.contentType = ContentType.json
              ..write('{"ok":true}');
          case '/api/client/profile/managed':
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_readyManagedProfile('ruleset-get-final')));
          default:
            if (request.uri.path.startsWith('/rule-sets/')) {
              final tag =
                  request.uri.pathSegments.last.replaceFirst('.srs', '');
              final count = (requestsByTag[tag] ?? 0) + 1;
              requestsByTag[tag] = count;
              if (count == 1) {
                request.response
                  ..statusCode = HttpStatus.serviceUnavailable
                  ..write('stale ruleset bytes');
              } else {
                request.response.add(utf8.encode('final-ruleset-$tag'));
              }
            } else {
              request.response.statusCode = HttpStatus.notFound;
            }
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      allExceptRuRuleSetUrlsResolver: (tag) =>
          <String>['http://127.0.0.1:${server.port}/rule-sets/$tag.srs'],
      maxRequestAttempts: 2,
      delayScheduler: (_) async {},
    );

    await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.allExceptRu,
    );

    for (final entry in <String, String>{
      _ruDomainWhitelistRuleSetTag: 'ru-domain-whitelist.srs',
      _ruDomainCategoryRuleSetTag: 'ru-domain-category.srs',
      _ruIpCountryRuleSetTag: 'ru-ip-country.srs',
      _ruIpWhitelistRuleSetTag: 'ru-ip-whitelist.srs',
    }.entries) {
      expect(requestsByTag[entry.key], 2);
      expect(
        await File(_expectedRuleSetCachePath(tempDirectory, entry.value))
            .readAsBytes(),
        utf8.encode('final-ruleset-${entry.key}'),
      );
    }
  });
}
