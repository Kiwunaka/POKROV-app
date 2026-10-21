import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart' hide TransportCandidate;
import 'package:pokrov_app_ui/pokrov_app_ui.dart' as ui;
import 'package:pokrov_app_shell/routing_catalog_contract.dart';
import 'package:pokrov_app_shell/routing_catalog_policy.dart';
import 'package:pokrov_app_shell/src/features/rules/routing_catalog_store.dart';
import 'package:pokrov_app_shell/src/features/rules/smart_access_policy_store.dart';
import 'package:pokrov_app_shell/src/shell/managed_profile_cache.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

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

class _PausedProfileCacheClear extends ManagedProfileCache {
  final clearStarted = Completer<void>();
  final releaseClear = Completer<void>();

  @override
  Future<void> clear(String platform) async {
    await super.clear(platform);
    clearStarted.complete();
    await releaseClear.future;
  }
}

Object? _qaSorted(Object? value) {
  if (value is Map) return {for (final key in value.keys.cast<String>().toList()..sort()) key: _qaSorted(value[key])};
  if (value is List) return value.map(_qaSorted).toList();
  return value;
}

Future<String> _qaDigest(String value) async => (await Sha256().hash(utf8.encode(value))).bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Future<Map<String, Object?>> _qaSigned(Map<String, Object?> payload, String purpose, SimpleKeyPair key) async {
  final body = jsonEncode(_qaSorted(payload));
  final signature = await Ed25519().sign(utf8.encode('$purpose\n$body'), keyPair: key);
  return {'algorithm': 'Ed25519', 'key_id': 'qa-test', 'payload': payload,
    'payload_sha256': await _qaDigest(body), 'signature_b64': base64UrlEncode(signature.bytes).replaceAll('=', '')};
}

// Keep normal HTTPS configuration validation while the synthetic API stays local.
class _QaLocalHttpClient implements HttpClient {
  _QaLocalHttpClient(this.port, {this.controlTlsPort, this.controlError, this.controlRouteAvailable});
  final int port;
  final int? controlTlsPort;
  final Completer<Object>? controlError;
  final bool Function(Uri)? controlRouteAvailable;
  final HttpClient _client = HttpClient();
  @override
  set connectionTimeout(Duration? value) => _client.connectionTimeout = value;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (method == 'POST' && url.path == '/api/client/smart-access/first-provider-qa/control' &&
        controlRouteAvailable != null && !controlRouteAvailable!(url)) {
      throw const SocketException('Synthetic Direct API path is blocked');
    }
    final stallControl = controlTlsPort != null && method == 'POST' &&
        url.path == '/api/client/smart-access/first-provider-qa/control';
    try {
      return await _client.openUrl(method, url.replace(scheme: stallControl ? 'https' : 'http',
          host: '127.0.0.1', port: stallControl ? controlTlsPort : port));
    } on Object catch (error) {
      if (stallControl) controlError!.complete(error);
      rethrow;
    }
  }
  @override
  void close({bool force = false}) => _client.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

class _RestoredFirstLaunch implements PokrovFirstLaunchStore {
  final completion = Completer<bool>();
  @override
  Future<bool> isCompleted() => completion.future;
  @override
  Future<void> markCompleted() async {}
}

class _HomeExperience implements PokrovClientExperienceStore {
  var saved = const PokrovClientExperienceState.empty().copyWith(interfaceMode: PokrovInterfaceMode.advanced);
  @override
  Future<PokrovClientExperienceState> read() async => saved;
  @override
  Future<void> write(PokrovClientExperienceState state) async { saved = state; }
}

class _HomeThemeStore extends PokrovFileThemeModeStore {
  ThemeMode saved = ThemeMode.light;
  @override
  Future<ThemeMode> read() async => saved;
  @override
  Future<void> write(ThemeMode mode) async { saved = mode; }
}

class _NoConnectBootstrapper implements ManagedProfileBootstrapper {
  @override
  Never noSuchMethod(Invocation invocation) =>
      throw StateError('Home visibility must not request a managed profile');
}

void main() {
  test('neutral signed catalog keeps VPN defaults and rejects Selective without services', () async {
    final now = DateTime.now().toUtc();
    String wire(DateTime time) => '${time.toIso8601String().substring(0, 19)}Z';
    final key = await Ed25519().newKeyPairFromSeed(List.generate(32, (i) => i + 1));
    final envelope = await _qaSigned({
      'schema_version': 'pokrov-routing-catalog-v1', 'revision': 26,
      'security_revision': 2, 'audience': 'production',
      'issued_at': wire(now.subtract(const Duration(seconds: 1))),
      'expires_at': wire(now.add(const Duration(hours: 1))),
      'sources': <Object>[], 'evidence': <Object>[], 'services': <Object>[],
    }, 'pokrov-routing-catalog-v1', key);
    final verifier = RoutingCatalogVerifier(publicKeysById: {
      'qa-test': base64Encode((await key.extractPublicKey()).bytes),
    }, audience: 'production');
    final catalog = await verifier.verify(envelope, now: now,
      minimumRevision: 25, minimumSecurityRevision: 2, currentPayloadSha256: null);
    final policy = RoutingCatalogPolicy.fromVerified(catalog);
    expect(policy.services, isEmpty);
    for (final mode in [CatalogRoutingMode.full, CatalogRoutingMode.smartSafe]) {
      final compiled = compileCatalogDomainPolicy(policy: policy, mode: mode,
        platform: 'windows', accessState: 'paid_unlimited', vpnAvailable: true, now: now);
      expect(compiled.defaultAction, CatalogRouteAction.vpn);
      expect(compiled.rules, isEmpty);
      expect(compiled.localDpiControlHosts, isEmpty);
    }
    expect(() => compileCatalogDomainPolicy(policy: policy, mode: CatalogRoutingMode.selective,
      platform: 'windows', accessState: 'paid_unlimited', vpnAvailable: true, now: now),
      throwsA(isA<RoutingCatalogFailure>().having((error) => error.code, 'code', 'catalog_service_selection_empty')));
    expect(() => compileCatalogDomainPolicy(policy: policy, mode: CatalogRoutingMode.selective,
      platform: 'windows', accessState: 'paid_unlimited', vpnAvailable: true, now: now,
      selectedServiceIds: {'removed-service'}),
      throwsA(isA<RoutingCatalogFailure>().having((error) => error.code, 'code', 'catalog_selected_service_unsupported')));
  });

  for (final (serviceId, controlFailure) in <(String, String?)>[
    for (final failure in const <String?>[null, 'core_egress_tls_failed', 'service_unavailable', 'unknown_private_control_code', 'smart_access_signature_invalid', 'control_deadline'])
      ('gemini', failure),
    ('chatgpt', null),
  ]) {
  test('explicit first-provider QA uses the signed disabled $serviceId projection through ordinary managed stage${controlFailure == null ? '' : ' with $controlFailure'}', () async {
    final httpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = httpOverrides);
    final directory = await Directory.systemTemp.createTemp('pokrov-first-provider-qa-');
    addTearDown(() => directory.delete(recursive: true));
    final now = DateTime.now().toUtc();
    String wire(DateTime time) => '${time.toIso8601String().substring(0, 19)}Z';
    final start = wire(now.subtract(const Duration(seconds: 1)));
    final end = wire(now.add(const Duration(hours: 1)));
    final qaEnd = wire(now.add(const Duration(minutes: 5)));
    final key = await Ed25519().newKeyPairFromSeed(List.generate(32, (i) => i + 1));
    final public = base64Encode((await key.extractPublicKey()).bytes);
    final coreHash = await _qaDigest('actual fixture core');
    const admission = '1234567890abcdef1234567890abcdef';
    const leaseId = 'abcdef0123456789abcdef0123456789';
    final domainNames = serviceId == 'gemini' ? ['gemini.google.com'] : ['chatgpt.com', 'ws.chatgpt.com'];
    final service = <String, Object?>{'service_id': serviceId, 'display_name': serviceId, 'categories': ['ai'],
      'enabled': false, 'classification': 'geo_restricted', 'reason': 'test domain metadata', 'evidence_status': 'source_only',
      'source_ids': ['qa-source'], 'evidence_ids': ['domain-review'], 'platforms': ['windows'],
      'access_states': ['paid_unlimited'], 'route_intents': <Object>[], 'android': <Object>[], 'windows': <Object>[],
      'domains': [for (final name in domainNames) {'name': name, 'match': 'exact', 'shared': false, 'role': 'web', 'source_ids': ['qa-source']}],
      'networks': <Object>[], 'provider_capability_refs': <Object>[], 'external_gateway_policy': 'forbidden'};
    final catalogEnvelope = await _qaSigned({'schema_version': 'pokrov-routing-catalog-v1', 'revision': 1,
      'security_revision': 1, 'audience': 'lab', 'issued_at': start, 'expires_at': end,
      'sources': [{'source_id': 'qa-source', 'url': 'https://source.example.test/', 'revision': '1',
        'sha256': await _qaDigest('source'), 'license': 'test', 'retrieved_at': start, 'expires_at': end}],
      'evidence': [{'evidence_id': 'domain-review', 'service_id': serviceId, 'source_ids': ['qa-source'],
        'sha256': await _qaDigest('domain metadata'), 'origin': 'synthetic', 'observed_at': start, 'expires_at': end}],
      'services': [service]}, 'pokrov-routing-catalog-v1', key);
    final catalogVerifier = RoutingCatalogVerifier(publicKeysById: {'qa-test': public}, audience: 'lab');
    final catalog = await catalogVerifier.verify(catalogEnvelope, now: now, minimumRevision: 0,
      minimumSecurityRevision: 1, currentPayloadSha256: null);
    final policy = RoutingCatalogPolicy.fromVerified(catalog);
    expect(() => compileCatalogDomainPolicy(policy: policy, mode: CatalogRoutingMode.selective,
      platform: 'windows', accessState: 'paid_unlimited', vpnAvailable: true,
      now: now, selectedServiceIds: {serviceId}), throwsA(isA<RoutingCatalogFailure>()),
      reason: 'the public compiler must keep the original disabled service unavailable');
    final permission = <String, Object?>{'permission_id': 'owned-permission', 'provider_id': 'owned-provider', 'revision': 1,
      'status': 'approved', 'embedded_use_allowed': true, 'review_ref': 'permission-review',
      'review_sha256': await _qaDigest('permission'), 'issued_at': start, 'expires_at': end,
      'max_new_connections_per_minute': 1, 'max_concurrent_connections_per_lease': 1, 'relay_connect_policy': null};
    final provider = <String, Object?>{'provider_id': 'owned-provider', 'revision': 1, 'kind': 'owned', 'enabled': true,
      'permission_id': 'owned-permission', 'resolver_url': 'https://dns.example.test/dns-query',
      'relay_addresses': ['1.1.1.1'], 'privacy_review_ref': 'privacy-review', 'privacy_review_sha256': await _qaDigest('privacy')};
    final capability = <String, Object?>{'capability_id': '$serviceId-qa', 'provider_id': 'owned-provider', 'provider_revision': 1,
      'service_id': serviceId, 'enabled': false, 'verification': 'source_only',
      'checks': {for (final name in const ['resolver_transport', 'dns_answer', 'tls_certificate', 'feature_request']) name: 'NOT_VERIFIED'},
      'platform': 'windows', 'origin': 'current-origin', 'family': 'ipv4', 'feature': 'web_request',
      'transport': 'tls_tcp_443_visible_sni', 'domains': [for (final name in domainNames) {'name': name, 'match': 'exact'}],
      'proof_ref': 'unverified-proof', 'proof_sha256': await _qaDigest('unverified proof'), 'observed_at': start, 'expires_at': end};
    final providerHash = await _qaDigest(jsonEncode(_qaSorted({'schema_version': 'pokrov-smart-access-providers-v1',
      'revision': 1, 'security_revision': 1, 'audience': 'lab', 'issued_at': start, 'expires_at': end,
      'permissions': [permission], 'providers': [provider], 'capabilities': [capability]})));
    String? installId;
    Map<String, Object?>? permitEnvelope;
    Map<String, dynamic>? claimRequest;
    var terminateQa = false;
    final requests = <String>[];
    final controlDeadline = controlFailure == 'control_deadline';
    final actionTimeout = Duration(seconds: controlDeadline ? 2 : 18);
    final controlError = Completer<Object>();
    final controlAccepted = Completer<void>();
    ServerSocket? controlServer;
    if (controlDeadline) {
      controlServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      controlServer.listen((socket) {
        sockets.add(socket);
        socket.listen((_) {});
        if (!controlAccepted.isCompleted) controlAccepted.complete();
      });
      addTearDown(() async {
        for (final socket in sockets) { socket.destroy(); }
        await controlServer!.close();
      });
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        requests.add(request.uri.path);
        final raw = await utf8.decoder.bind(request).join();
        final body = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        Object reply = {'ok': true};
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            installId = body['install_id'] as String;
            reply = {'session': {'session_token': 'synthetic-qa-session', 'account_id': 'synthetic-qa-account'},
              'provisioning': {'status': 'ready', 'sync_ok': true}};
          case '/api/client/subscription':
            reply = {'access_state': 'paid_unlimited', 'lane': 'paid', 'first_provider_qa': {'admission_id': admission, 'state': 'pending'}};
          case '/api/client/profile/managed':
            reply = {..._readyManagedProfile('qa-real-material'),
              'transport_profile': 'qa_vless', 'transport_kind': 'reality',
              'access': {'access_state': 'paid_unlimited', 'expiry_at': end},
              'transport_catalog': {'schema_version': 'pokrov-transport-catalog-v1', 'revision': 'qa-real-material',
                'selected_candidate_ref': 'de:qa_vless', 'candidates': [{'candidate_ref': 'de:qa_vless', 'profile_ref': 'qa_vless',
                  'node_code': 'de', 'country_code': 'DE', 'protocol': 'vless', 'transport': 'tcp', 'protection': 'reality',
                  'priority': 0, 'parameters': {'network': 'tcp', 'flow': ''}, 'requirements': {'minimum_client_release': '1.2.0',
                    'minimum_core_release': null, 'platforms': ['windows'], 'required_features': ['singbox_reality_v1', 'singbox_tls_v1', 'singbox_utls_v1', 'singbox_vless_v1']}}]},
              'config_payload': {'outbounds': [{'type': 'selector', 'tag': 'proxy', 'outbounds': ['qa-vpn'], 'default': 'qa-vpn'},
                {'type': 'vless', 'tag': 'qa-vpn', 'server': 'vpn.example.invalid', 'server_port': 443,
                  'uuid': '11111111-1111-4111-8111-111111111111', 'tls': {'enabled': true, 'server_name': 'vpn.example.invalid',
                    'utls': {'enabled': true, 'fingerprint': 'chrome'},
                    'reality': {'enabled': true, 'public_key': base64UrlEncode(List.filled(32, 1)).replaceAll('=', ''), 'short_id': '0123456789abcdef'}}}],
                'route': {'final': 'proxy'}}};
          case '/api/client/routing-catalog':
            reply = {'schema': 'routing-catalog-response-v1', 'envelope': catalogEnvelope};
          case '/api/client/smart-access/first-provider-qa/claim':
            claimRequest = body;
            final binding = await _qaDigest('pokrov-smart-access-device-v1\u0000${body['request_nonce']}\u0000synthetic-qa-account\u0000$installId');
            final issued = wire(DateTime.now().toUtc());
            final lease = <String, Object?>{'schema_version': 'pokrov-smart-access-lease-v1', 'lease_id': leaseId,
              'audience': 'lab', 'provider_id': 'owned-provider', 'provider_revision': 1, 'permission_id': 'owned-permission',
              'permission_revision': 1, 'capability_id': '$serviceId-qa', 'provider_policy_revision': 1, 'provider_security_revision': 1,
              'provider_policy_sha256': providerHash, 'catalog_revision': 1, 'catalog_security_revision': 1,
              'catalog_sha256': catalog.payloadSha256, 'service_id': serviceId, 'platform': 'windows', 'origin': 'current-origin',
              'family': 'ipv4', 'feature': 'web_request', 'transport': 'tls_tcp_443_visible_sni', 'issued_at': issued,
              'new_flows_until': qaEnd, 'active_flows_until': qaEnd, 'resolver_url': provider['resolver_url'],
              'relay_addresses': provider['relay_addresses'], 'domains': capability['domains'],
              'max_new_connections_per_minute': 1, 'max_concurrent_connections': 1, 'relay_connect_policy': null};
            final grant = await _qaSigned({'schema_version': 'pokrov-smart-access-grant-v1', 'request_nonce': body['request_nonce'],
              'device_binding': binding, 'profile_sha256': body['profile_sha256'], 'route_mode': body['route_mode'], 'lease': lease},
              'pokrov-smart-access-grant-v1', key);
            permitEnvelope = await _qaSigned({'schema_version': 'pokrov-smart-access-first-provider-qa-v1', 'permit_id': admission,
              'request_nonce': body['request_nonce'], 'device_binding': binding, 'candidate_ref': '$serviceId-qa',
              'profile_sha256': body['profile_sha256'], 'catalog_sha256': catalog.payloadSha256, 'provider_policy_sha256': providerHash,
              'client_release': body['client_release'], 'core_version': body['core_version'], 'core_module_sha256': body['core_module_sha256'],
              'route_mode': body['route_mode'], 'issued_at': issued, 'expires_at': qaEnd, 'max_attempts': 1, 'renewable': false,
              'qa_projection': {'service': service, 'provider': provider, 'permission': permission, 'capability': capability,
                'action': 'approved_gateway', 'route_mode': body['route_mode']}, 'grant_envelope': grant},
              'pokrov-smart-access-first-provider-qa-v1', key);
            reply = {'schema': 'smart-access-first-provider-qa-response-v1', 'envelope': permitEnvelope};
          case '/api/client/smart-access/first-provider-qa/control':
            final issued = DateTime.now().toUtc();
            reply = {'schema': 'smart-access-first-provider-qa-control-response-v1',
              if (!terminateQa) 'runtime_capability': 'saqa1.c3ludGhldGlj.${await _qaDigest('synthetic hmac')}',
              'envelope': await _qaSigned({'schema_version': 'pokrov-smart-access-control-v1',
                'request_nonce': body['request_nonce'],
                'device_binding': await _qaDigest('pokrov-smart-access-device-v1\u0000${body['request_nonce']}\u0000synthetic-qa-account\u0000$installId'),
                'profile_digest': body['profile_digest'], 'platform': 'windows', 'audience': 'lab',
                'action': terminateQa ? 'terminate' : 'none', 'reason': terminateQa ? 'access_denied' : 'current',
                'issued_at': wire(issued), 'expires_at': wire(issued.add(const Duration(seconds: 60)))},
                'pokrov-smart-access-control-v1', key)};
            if (controlFailure == 'smart_access_signature_invalid') {
              ((reply as Map)['envelope'] as Map)['signature_b64'] = base64UrlEncode(List.filled(64, 0)).replaceAll('=', '');
            }
        }
        request.response.write(jsonEncode(reply));
        await request.response.close();
      }
    }());
    Map? staged;
    bool controlRouteAvailable(Uri url) {
      final route = staged!['route'] as Map;
      final dns = staged!['dns'] as Map;
      final routeRule = (route['rules'] as List).cast<Map>().where((rule) =>
        (rule['domain'] as List?)?.contains(url.host) == true &&
        rule['network'] == 'tcp' && (rule['port'] as List?)?.contains(url.port) == true).firstOrNull;
      final dnsRule = (dns['rules'] as List).cast<Map>().where((rule) =>
        (rule['domain'] as List?)?.contains(url.host) == true).firstOrNull;
      final dnsServer = (dns['servers'] as List).cast<Map>().firstWhere((server) =>
        server['tag'] == (dnsRule?['server'] ?? dns['final']));
      return (routeRule?['outbound'] ?? route['final']) == 'proxy' && dnsServer['detour'] == 'proxy';
    }
    final bootstrapper = AppFirstRuntimeBootstrapper(apiBaseUrl: 'https://app.pokrov.space', apiFallbackBaseUrls: const [],
      httpClientFactory: () => _QaLocalHttpClient(server.port, controlTlsPort: controlServer?.port, controlError: controlError,
        controlRouteAvailable: controlRouteAvailable),
      supportDirectoryResolver: () async => directory, sessionSecretStore: MemoryAppFirstSessionSecretStore(), maxRequestAttempts: 1,
      allExceptRuRuleSetUrlsResolver: (_) => const [],
      routingCatalogStore: RoutingCatalogStore(enabled: true, verifier: catalogVerifier),
      smartAccessPolicyStore: SmartAccessPolicyStore(enabled: false,
        verifier: SmartAccessVerifier(providerKeysById: {}, leaseKeysById: {'qa-test': public}, audience: 'lab')));
    final localWindows = bootstrapper.buildLocalSmartAccessBase(hostPlatform: HostPlatform.windows);
    expect(localWindows.disableMemoryLimit, isTrue);
    expect(localWindows.copyWith(configPayload: localWindows.configPayload).disableMemoryLimit, isTrue,
      reason: 'routing preparation must retain the Windows memory policy');
    expect(bootstrapper.buildLocalSmartAccessBase(hostPlatform: HostPlatform.android).disableMemoryLimit, isFalse);
    await bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.windows, routeMode: RouteMode.fullTunnel,
      runtimeFeatures: {RuntimeTransportFeature.reality, RuntimeTransportFeature.tls, RuntimeTransportFeature.utls, RuntimeTransportFeature.vless}, coreRelease: '1.2.10');
    final account = AccountSessionCoordinator(accountActions: bootstrapper)
      ..updateSubscriptionInfo(await bootstrapper.fetchClientSubscription(hostPlatform: HostPlatform.windows));
    final phase = <String, Object?>{'phase': 'initialized', 'supportsLiveConnect': true, 'canConnect': true,
      'canInitialize': false, 'coreVersion': '1.2.10', 'coreModuleSha256': coreHash,
      'routingCatalogWindowVersion': 1, 'routingCatalogControlVersion': 4, 'smartAccessLeaseVersion': 1,
      'smartAccessRuntimeControlVersion': 1, 'coreEgressValidationRequired': true,
      'transportCapabilitiesJson': jsonEncode({'schema': 1, 'features': ['singbox_reality_v1', 'singbox_tls_v1', 'singbox_utls_v1', 'singbox_vless_v1']})};
    final nativeCalls = <String>[];
    const bootRef = 'windows:0123456789abcdef0123456789abcdef';
    const networkRef = 'network_0123456789abcdef0123456789abcdef';
    String? nativeBoundRequestId;
    var probeId = 1;
    var guardClosed = false;
    var failBoundConnect = false;
    var stopConfirmed = true;
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call.method);
      final args = call.arguments as Map? ?? {};
      switch (call.method) {
        case 'runtimeEngine.clockSnapshot':
          return {'schema': 1, 'boot_ref': bootRef, 'elapsed_ms': 1000, 'quantum_ms': 1};
        case 'runtimeEngine.transportNetworkContext':
          return {'schema': 1, 'network_context_ref': networkRef};
        case 'runtimeEngine.candidateNetwork':
          return {'selection_key': 'qa-network', 'context_ref': 'qa-context', 'network_available': true, 'ipv6_available': false};
        case 'runtimeEngine.probeCandidate':
          return {'success': true, 'failure_kind': '', 'duration_ms': 1, 'stage': 'http_64k'};
        case 'runtimeEngine.readSmartAccessRestrictions':
          return {'schema': 1, 'journalJson': jsonEncode({'schema': 1, 'snapshot_sha256': await _qaDigest('[]'), 'entries': <Object>[]})};
        case 'runtimeEngine.acknowledgeSmartAccessRestrictions':
          return {'schema': 1, 'snapshotSha256': args['snapshotSha256'], 'acknowledged': true};
        case 'runtimeEngine.stageManagedProfile':
          staged = jsonDecode(args['configPayload'] as String) as Map;
          phase.addAll({'phase': 'configStaged', 'stagedProfileDigest': args['expectedProfileDigest'],
            'stagedConfigPath': '/synthetic/managed.json', 'profileIdentityOrigin': 'windows_service_stage_request_sha256'});
        case 'runtimeEngine.connect':
        case 'runtimeEngine.connectWithCoreIdentity':
          nativeBoundRequestId = null;
          if (call.method == 'runtimeEngine.connectWithCoreIdentity') {
            expect(args, hasLength(7));
            expect(args['expectedCoreModuleSha256'], coreHash);
            expect(args['expectedProfileDigest'], phase['stagedProfileDigest']);
            expect(args['expectedNetworkContextRef'], networkRef);
            expect(args['bootRef'], bootRef);
            expect(args['startedElapsedMs'], 1000);
            expect(args['deadlineElapsedMs'], 1000 + actionTimeout.inMilliseconds);
            expect(args['requestId'], matches(r'^[a-f0-9]{32}$'));
            nativeBoundRequestId = args['requestId'] as String;
            if (failBoundConnect) {
              throw PlatformException(code: 'core_identity_connect_failed', details: {
                'schema': 1, 'requestId': nativeBoundRequestId, 'operation': 'core_connect',
                'nativePhase': 'config_staged', 'failureKind': 'core_start_failed',
                'moduleMatches': true, 'profileMatches': true,
              });
            }
          }
          phase.addAll({'phase': 'running', 'effectiveProfileDigest': phase['stagedProfileDigest'],
            'hostHealth': 'healthy', 'dnsState': 'healthy', 'uplinkState': 'healthy', 'dnsReady': true,
            'coreEgressValidated': true, 'tunInterfacePresent': true, 'vpnRoutesPresent': true});
          if (nativeBoundRequestId != null) {
            return {'schema': 1, 'requestId': nativeBoundRequestId, 'snapshot': {...phase}};
          }
        case 'runtimeEngine.readSmartAccessLeases':
          final startedAt = DateTime.parse((permitEnvelope!['payload'] as Map)['issued_at'] as String).millisecondsSinceEpoch + 1;
          return {'schema': 1, 'profileDigest': args['profileDigest'], 'leaseIdsJson': jsonEncode({'schema': 1,
            'lease_ids': [leaseId], 'selections': [{'service_id': serviceId, 'lease_id': leaseId, 'selection_index': 0,
              'state': 'gateway', 'available': true, 'readiness': {'probe_id': probeId, 'lease_id': leaseId,
                'started_at_ms': startedAt, 'completed_at_ms': startedAt + 3,
                'status': guardClosed ? 'failure' : 'pass', 'fallback_guard_closed': guardClosed,
                'stages': [for (var i = 0; i < 3; i++) {'stage': ['resolver', 'dns', 'tls'][i], 'result': 'pass',
                  'observed_at_ms': startedAt + i + 1, 'duration_ms': 1}]}}]})};
        case 'runtimeEngine.configureBoundSmartAccessRuntimeControl':
          if (nativeBoundRequestId == null || args['requestId'] != nativeBoundRequestId) {
            throw PlatformException(code: 'connect_owner_changed');
          }
          if (controlFailure != null) {
            throw PlatformException(code: controlFailure, message: 'private control message',
              details: const {'capability': 'private control capability'});
          }
          final config = jsonDecode(args['configJson'] as String) as Map;
          expect(config['capability'], startsWith('saqa1.'));
          expect(config['profile_digest'], phase['stagedProfileDigest']);
          phase.remove('stagedProfileDigest');
          return {'schema': 1, 'requestId': args['requestId'], 'profileDigest': args['profileDigest'], 'configured': true};
        case 'runtimeEngine.revokeSmartAccessLease':
          expect(args['leaseId'], leaseId);
          return {'schema': 1, 'profileDigest': args['profileDigest'], 'leaseId': args['leaseId'], 'revoked': true};
        case 'runtimeEngine.disconnect':
        case 'runtimeEngine.cancelAndConfirmConnectStopped':
          if (call.method == 'runtimeEngine.cancelAndConfirmConnectStopped') {
            expect(args['requestId'], nativeBoundRequestId);
            if (!stopConfirmed) return {'schema': 1, 'requestId': args['requestId'], 'settled': false};
          }
          phase.addAll({'phase': 'initialized', 'coreEgressValidated': false, 'dnsReady': false,
            'effectiveProfileDigest': '', 'tunInterfacePresent': false, 'vpnRoutesPresent': false,
            'protectionRetained': false});
          if (call.method == 'runtimeEngine.cancelAndConfirmConnectStopped') {
            nativeBoundRequestId = null;
            return {'schema': 1, 'requestId': args['requestId'], 'settled': true};
          }
      }
      return {...phase};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final firstLaunch = _RestoredFirstLaunch()..completion.complete(true);
    final first = FirstSessionCoordinator(store: firstLaunch)..complete(animated: false);
    final runtime = createRuntimeEngine(hostPlatform: HostPlatform.windows);
    final manager = ConnectionManager(appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      runtimeEngine: runtime, bootstrapper: bootstrapper, actionTimeout: actionTimeout,
      accountSessionCoordinator: account, firstSessionCoordinator: first, clientExperienceStore: _HomeExperience(),
      connectHintStore: const PokrovFileConnectHintStore(), windowsTunnelAuthorizer: () async => PokrovWindowsTunnelAuthorization.allowed,
      authorizeAndroidConnect: () async => true, refreshSubscription: () async => true, onNotice: (_, __) {});
    addTearDown(() async {
      manager.dispose();
      // Join background lifecycle delivery before removing its temporary outbox.
      await bootstrapper.reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'disconnected', connected: false);
    });
    expect(requests.where((path) => path.endsWith('/claim')), isEmpty, reason: 'availability cannot issue a permit');
    if (controlDeadline) {
      final elapsed = Stopwatch()..start();
      final pending = manager.startFirstProviderQa(admission);
      await controlAccepted.future.timeout(const Duration(seconds: 5));
      expect(manager.status.phase, ConnectionPhase.connected);
      await pending;
      expect(elapsed.elapsed, lessThan(const Duration(seconds: 4)), reason: 'the control deadline bounds an unfinished TLS handshake');
      expect(await controlError.future.timeout(const Duration(seconds: 10)),
        isA<SocketException>().having((error) => error.osError, 'OS error', isNull));
      final context = await manager.readFirstProviderQaContext();
      expect(context?['control_delivery'], 'failed');
      expect(context?['api_failure_kind'], 'request_timeout');
      expect(context?['failure_operation'], 'qa_control');
      expect(context?['error_code'], 'API-002');
      expect(context?['os_error_code'], isNull);
      expect(context?['proof_current'], isNot(true));
      expect(manager.status.phase, ConnectionPhase.connected);
      expect(nativeCalls, isNot(contains('runtimeEngine.configureBoundSmartAccessRuntimeControl')));
      await manager.disconnect();
      expect(await manager.readFirstProviderQaContext(), {
        'control_delivery': 'failed', 'failure_operation': 'qa_control', 'error_code': 'API-002',
        'api_failure_kind': 'request_timeout',
      });
      return;
    }
    if (controlFailure != null) {
      if (controlFailure == 'smart_access_signature_invalid') {
        await manager.startFirstProviderQa(admission);
        expect(nativeCalls, isNot(contains('runtimeEngine.configureBoundSmartAccessRuntimeControl')));
      } else {
        await expectLater(manager.startFirstProviderQa(admission), throwsA(isA<PlatformException>()));
      }
      final context = await manager.readFirstProviderQaContext();
      final connected = manager.status.phase;
      await manager.disconnect();
      expect(context?['control_delivery'], 'failed');
      expect(context?['control_reason'], controlFailure == 'unknown_private_control_code' ? 'unclassified' : controlFailure);
      expect(jsonEncode(context), isNot(contains('private')));
      expect(context?['proof_current'], isNot(true));
      expect(connected, ConnectionPhase.connected,
        reason: 'failed QA control must retain the ordinary VPN health');
      return;
    }
    await manager.startFirstProviderQa(admission);
    expect(manager.status.phase, ConnectionPhase.connected, reason: manager.headline);
    expect(nativeCalls.where((method) => method == 'runtimeEngine.probeCandidate'), hasLength(1));
    expect(nativeCalls.where((method) => method == 'runtimeEngine.stageManagedProfile'), hasLength(1));
    expect(nativeCalls, isNot(contains('runtimeEngine.connect')));
    expect(nativeCalls.where((method) => method == 'runtimeEngine.connectWithCoreIdentity'), hasLength(1));
    expect(nativeCalls.where((method) => method == 'runtimeEngine.configureBoundSmartAccessRuntimeControl'), hasLength(1));
    expect(claimRequest!.containsKey('candidate_ref'), isFalse);
    expect(claimRequest!['core_module_sha256'], coreHash);
    final providerDns = ((staged!['dns'] as Map)['servers'] as List).cast<Map>()
        .singleWhere((server) => server['tag'] == 'pokrov-smart-access-dns-$leaseId');
    expect(providerDns['domain_resolver'], {'server': 'dns-direct', 'strategy': 'ipv4_only'},
      reason: 'an IPv4 lease must not wait for AAAA when bootstrapping its DoH hostname');
    final route = staged!['route'] as Map;
    for (final domainName in domainNames) {
    final domainRules = (route['rules'] as List).cast<Map>().where((row) => (row['domain'] as List?)?.contains(domainName) == true).toList();
    expect(domainRules[0]['pokrov_catalog_window']['lease_id'], leaseId);
    expect(domainRules[0]['network'], 'tcp');
    expect(domainRules[0]['port'], [443]);
    expect(domainRules[0]['ip_version'], 4);
    expect(domainRules[1]['outbound'], 'proxy', reason: 'closed QA member retains protected VPN fallback');
    final domainDnsRules = ((staged!['dns'] as Map)['rules'] as List).cast<Map>()
        .where((row) => (row['domain'] as List?)?.contains(domainName) == true).toList();
    expect(domainDnsRules[0]['query_type'], ['A', 'AAAA', 'HTTPS', 'SVCB'],
      reason: 'browser address and service-binding queries must reach the owned IPv4 resolver');
    expect(domainDnsRules[0]['strategy'], 'ipv4_only',
      reason: 'a leased IPv4 service must return AAAA NODATA instead of advertising an unusable IPv6 route');
    expect(domainDnsRules[0]['server'], 'pokrov-smart-access-dns-$leaseId');
    expect(domainDnsRules[0]['pokrov_catalog_window'], domainRules[0]['pokrov_catalog_window']);
    expect(domainDnsRules[0]['disable_cache'], isTrue);
    expect(domainDnsRules[0]['rewrite_ttl'], 0);
    expect(domainDnsRules.last['domain'], contains(domainName));
    expect(domainDnsRules.last['action'], 'reject',
      reason: 'the untimed exact-domain rejection survives catalog expiry');
    }
    expect(route['final'], 'direct', reason: 'other traffic retains Direct');
    for (final host in const ['app.pokrov.space', 'api.pokrov.space']) {
      expect(controlRouteAvailable(Uri.https(host, '/api/client/smart-access/first-provider-qa/control')), isTrue,
        reason: 'both owned API origins must deliver control when the Direct API path is blocked');
    }
    expect(controlRouteAvailable(Uri.https('unrelated.example.test', '/')), isFalse);
    await manager.readSnapshot();
    final context = await manager.readFirstProviderQaContext();
    expect(context!['service_id'], serviceId);
    expect(context['runtime_scope_sha256'], isA<String>().having((value) => value.length, 'length', 64));
    expect(context['request_id'], nativeBoundRequestId);
    expect(context['profile_digest'], phase['effectiveProfileDigest']);
    expect(context['native_stages'], 'PASS');
    expect(context['proof_current'], isTrue);
    expect(context['fallback_guard_closed'], isFalse);
    expect(context['feature_request'], 'NOT_VERIFIED');
    probeId = 2;
    expect((await manager.readFirstProviderQaContext())!['probe_id'], 1, reason: 'same live scope keeps the atomic first completion');
    guardClosed = true;
    final closedContext = await manager.readFirstProviderQaContext();
    expect(closedContext!['native_stages'], 'NOT_VERIFIED');
    expect(closedContext['proof_current'], isFalse);
    expect(closedContext['fallback_guard_closed'], isTrue);
    final verifier = SmartAccessVerifier(providerKeysById: {}, leaseKeysById: {'qa-test': public}, audience: 'lab');
    if (serviceId == 'chatgpt') {
      for (final changes in <Map<String, Object?>>[
        {'domains': [{'name': 'chatgpt.com', 'match': 'suffix'}]},
        {'service_id': 'gemini'},
      ]) {
        final rejected = jsonDecode(jsonEncode(permitEnvelope!['payload'])) as Map<String, dynamic>;
        ((rejected['qa_projection'] as Map)['capability'] as Map).addAll(changes);
        final signed = await _qaSigned(rejected, 'pokrov-smart-access-first-provider-qa-v1', key);
        await expectLater(verifier.verifyFirstProviderQa(signed, request: claimRequest!,
          accountId: 'synthetic-qa-account', installId: installId!, catalog: catalog, now: DateTime.now().toUtc()),
          throwsA(isA<RoutingCatalogFailure>().having((failure) => failure.code, 'code', 'smart_access_qa_projection_invalid')));
      }
    }
    await expectLater(verifier.verifyFirstProviderQa(permitEnvelope, request: {...claimRequest!, 'core_module_sha256': await _qaDigest('other core')},
      accountId: 'synthetic-qa-account', installId: installId!, catalog: catalog, now: DateTime.now().toUtc()),
      throwsA(isA<RoutingCatalogFailure>()));
    expect(manager.firstProviderQaAdmissionId, isNull, reason: 'one explicit attempt cannot be renewed');
    terminateQa = true;
    await manager.refresh();
    expect(nativeCalls.where((method) => method == 'runtimeEngine.revokeSmartAccessLease'), hasLength(1));
    expect(nativeCalls, isNot(contains('runtimeEngine.revokeRoutingCatalog')));
    expect(manager.status.phase, ConnectionPhase.connected, reason: 'QA termination closes the member, not ordinary VPN access');
    await manager.disconnect();
    expect(await manager.readFirstProviderQaContext(),
      {'control_delivery': 'confirmed', 'control_native_accepted': true},
      reason: 'disconnect retains only the closed control diagnostic, without live lease or proof bindings');

    // Recreate an unconfirmed native Connect with the UI's last staged snapshot.
    final failedProfile = await _qaDigest('failed-bound-profile');
    phase.addAll({'phase': 'configStaged', 'stagedProfileDigest': failedProfile});
    await manager.readSnapshot();
    failBoundConnect = true;
    stopConfirmed = false;
    await expectLater((runtime as RuntimeCoreIdentityConnect).connectWithCoreIdentity(
      expectedCoreModuleSha256: coreHash, expectedProfileDigest: failedProfile,
      expectedNetworkContextRef: networkRef,
      budgetStartedAt: RuntimeBootClockSnapshot.fromWire(
        {'schema': 1, 'boot_ref': bootRef, 'elapsed_ms': 1000, 'quantum_ms': 1}, HostPlatform.windows),
      budget: const Duration(seconds: 18), onRequestCreated: (_) {}),
      throwsA(isA<RuntimeBoundConnectFailure>().having((error) => error.cleanupConfirmed, 'cleanup', isFalse)));
    expect(manager.snapshot?.phase, RuntimePhase.configStaged);
    expect(manager.busy, isFalse);
    expect((runtime as RuntimeConnectCancellation).activeConnectRequestId, isNotNull);
    final stopsBeforeRetry = nativeCalls.where((method) => method == 'runtimeEngine.cancelAndConfirmConnectStopped').length;
    stopConfirmed = true;
    await manager.disconnect();
    expect(nativeCalls.where((method) => method == 'runtimeEngine.cancelAndConfirmConnectStopped'),
      hasLength(stopsBeforeRetry + 1), reason: 'explicit Stop retries the retained owner even with a staged snapshot');
    expect((runtime as RuntimeConnectCancellation).activeConnectRequestId, isNull);
    expect(nativeCalls, isNot(contains('runtimeEngine.disconnect')), reason: 'bound Stop remains exact-owner settlement');

    // An ordinary failed replacement can retain its guard with a staged snapshot.
    await runtime.connect();
    expect((runtime as RuntimeConnectCancellation).activeConnectRequestId, isNotNull);
    phase.addAll({'phase': 'configStaged', 'coreEgressValidated': false, 'dnsReady': false,
      'effectiveProfileDigest': '', 'tunInterfacePresent': false, 'vpnRoutesPresent': false,
      'protectionRetained': true});
    await manager.readSnapshot();
    expect(manager.retainsProtection, isTrue);
    await manager.disconnect();
    expect(nativeCalls.where((method) => method == 'runtimeEngine.disconnect'), hasLength(1),
      reason: 'ordinary retained protection needs the ordinary native Stop');
    expect(manager.retainsProtection, isFalse);
    await manager.disconnect();
    expect(manager.status.phase, ConnectionPhase.disconnected, reason: 'repeated Stop remains settled for an ordinary owner');
    expect(nativeCalls.where((method) => method == 'runtimeEngine.disconnect'), hasLength(1));
    expect(nativeCalls.where((method) => method == 'runtimeEngine.cancelAndConfirmConnectStopped'),
      hasLength(stopsBeforeRetry + 1), reason: 'ordinary Stop must not use bound settlement');
  });
  }
  testWidgets('restored Windows Home remains painted while inactive and after returning', (tester) async {
    final firstLaunch = _RestoredFirstLaunch();
    final experience = _HomeExperience();
    final themeStore = _HomeThemeStore();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('space.pokrov/runtime_engine');
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, isNot(anyOf('runtimeEngine.stageManagedProfile', 'runtimeEngine.connect')));
      return {'phase': 'initialized', 'coreVersion': '1.2.10',
        'supportsLiveConnect': true, 'canInitialize': false, 'canConnect': true};
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      messenger.setMockMethodCallHandler(channel, null);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      bootstrapper: _NoConnectBootstrapper(), firstLaunchStore: firstLaunch,
      clientExperienceStore: experience, themeModeStore: themeStore,
    ));
    firstLaunch.completion.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    double homeOpacity() {
      final label = find.text('POKROV VPN');
      expect(label, findsOneWidget);
      var opacity = 1.0;
      tester.element(label).visitAncestorElements((element) {
        final widget = element.widget;
        if (widget is Opacity) opacity *= widget.opacity;
        if (widget is FadeTransition) opacity *= widget.opacity.value;
        return true;
      });
      return opacity;
    }
    final initialOpacity = homeOpacity();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.text('Профиль'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.text('Защита'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(homeOpacity(), greaterThan(0.9), reason: 'returning Home must stay painted');
    expect(initialOpacity, greaterThan(0.9), reason: 'an inactive first frame must not hide ready Home');
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Просто'));
    await tester.tap(find.text('Просто'));
    await tester.pumpAndSettle();
    expect(experience.saved.interfaceMode, PokrovInterfaceMode.simple);
    expect(find.byKey(const ValueKey('nav-rules')), findsNothing);
    await tester.tap(find.text('Продвинутый'));
    await tester.pumpAndSettle();
    expect(experience.saved.interfaceMode, PokrovInterfaceMode.advanced);
    expect(find.byKey(const ValueKey('nav-rules')), findsOneWidget);
    await tester.ensureVisible(find.text('Тема'));
    await tester.tap(find.text('Тема'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-theme-dark')));
    await tester.pumpAndSettle();
    expect(themeStore.saved, ThemeMode.dark);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    tester.state<ScrollableState>(find.descendant(of: find.byType(ui.ProfileScreen), matching: find.byType(Scrollable)).first).position.jumpTo(0);
    await tester.pumpAndSettle();
    final profileTitle = find.descendant(of: find.byType(ui.ProfileScreen), matching: find.text('Профиль'));
    expect(Theme.of(tester.element(profileTitle)).brightness, Brightness.dark);
    expect((tester.widget(profileTitle) as Text).style!.color!.computeLuminance(), greaterThan(0.5));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  test('safe Home crash signature retains its owned frame without private messages or paths', () {
    final signature = pokrovSafeCrashSignature(StateError('private-message'),
      StackTrace.fromString('#0 foreign (file:///private-location:8:9)\n'
        '#1 _HomeStageState.build (package:pokrov_app_shell/src/features/home/home_surface.dart:321:9)'));
    expect(signature, 'c101090000014100');
    expect(pokrovSafeCrashSignature(StateError('different-message'),
      StackTrace.fromString('#0 different (file:///another-location:99:9)\n'
        '#1 _HomeStageState.build (package:pokrov_app_shell/src/features/home/home_surface.dart:321:9)')),
      signature, reason: 'only the closed kind and owned source location classify this failure');
  });
  final defaultSecureStoragePlatform = FlutterSecureStoragePlatform.instance;
  setUp(() {
    // Widget binding's HTTP 400 stub must not intercept the local API fixtures.
    final httpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = httpOverrides);
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(<String, String>{});
  });
  tearDown(() {
    FlutterSecureStoragePlatform.instance = defaultSecureStoragePlatform;
  });

  for (final hostPlatform in const [HostPlatform.android, HostPlatform.windows]) {
  test('${hostPlatform.name} network context keeps the report run and does not retry through VPN egress', () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-network-context-');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/app-first-session-${hostPlatform.name}.json').writeAsString(jsonEncode({
      'schema_version': 1, 'install_id': 'network-fixture-install', 'account_id': '42',
      'session_token_storage': 'secure', 'managed_manifest_path': '/api/client/profile/managed',
    }));
    final secrets = MemoryAppFirstSessionSecretStore();
    String sessionToken(int expires) => '${base64Url.encode(utf8.encode(jsonEncode({'exp': expires})))}.fixture-signature';
    await secrets.writeSessionToken(hostPlatform: hostPlatform,
      installId: 'network-fixture-install', sessionToken: sessionToken(1));
    var calls = 0;
    var status = 'skipped';
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'runtimeEngine.observeNetworkContext');
      final fields = call.arguments as Map;
      expect(fields['reportRunId'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      calls++;
      return {'status': status, 'network_class': 'cellular'};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final bootstrapper = AppFirstRuntimeBootstrapper(apiBaseUrl: 'https://api.pokrov.space/',
      apiFallbackBaseUrls: const [], supportDirectoryResolver: () async => directory,
      sessionSecretStore: secrets, httpClientFactory: () => throw StateError('ordinary transport must not run'));
    await bootstrapper.refreshNetworkContext(hostPlatform: hostPlatform);
    expect(calls, 0, reason: 'an expired session waits for the normal session refresh');
    await secrets.writeSessionToken(hostPlatform: hostPlatform,
      installId: 'network-fixture-install', sessionToken: sessionToken(DateTime.now().millisecondsSinceEpoch ~/ 1000 + 900));
    await bootstrapper.refreshNetworkContext(hostPlatform: hostPlatform);
    expect(await File('${directory.path}/runtime-stats-outbox-${hostPlatform.name}.json').exists(), isFalse,
      reason: 'resource suppression is not a failed availability observation');
    status = 'unavailable';
    await bootstrapper.refreshNetworkContext(hostPlatform: hostPlatform);
    await bootstrapper.refreshNetworkContext(hostPlatform: hostPlatform);
    expect(calls, 2, reason: 'resume and connect share the hourly due check after an attempted request');
    final queued = jsonDecode(await File('${directory.path}/runtime-stats-outbox-${hostPlatform.name}.json').readAsString()) as Map;
    final body = (queued['records'] as List).single['body'] as Map;
    expect(body['network_observation'], {'source_network': 'unknown', 'outcome': 'unavailable', 'network_class': 'cellular'});
    expect(body['runtime_phase'], 'network_observed');
    expect(body.containsKey('connected'), isFalse);
    expect(body.containsKey('connectivity'), isFalse);
  });
  }

  test('runtime stats freezes reports offline and cleans only same-account accepted receipts after restart', () async {
    final httpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = httpOverrides);
    final directory = await Directory.systemTemp.createTemp('pokrov-runtime-stats-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    await File('${directory.path}/app-first-session-windows.json').writeAsString(jsonEncode({
      'schema_version': 1,
      'install_id': 'stats-fixture-install',
      'account_id': '42',
      'session_token_storage': 'secure',
      'managed_manifest_path': '/api/client/profile/managed',
    }));
    final secrets = MemoryAppFirstSessionSecretStore();
    await secrets.writeSessionToken(hostPlatform: HostPlatform.windows,
        installId: 'stats-fixture-install', sessionToken: 'stats-fixture-token');
    var sessionReadStarted = Completer<void>();
    var releaseSessionRead = Completer<void>();
    var gateNextSessionRead = false;
    var offline = false;
    var stallNextRequest = false;
    Completer<void>? stalledRequestStarted;
    var runtimeStatsStatus = HttpStatus.ok;
    const canonicalAccountId = '22222222-2222-4222-8222-222222222222';
    var statsToken = 'stats-fixture-token';
    var managedRequests = 0;
    var expireNextManagedRequest = false;
    final received = <Map<String, dynamic>>[];
    final receipts = <RuntimeStatsDeliveryReceipt>[];
    unawaited(() async {
      await for (final request in server) {
        if (request.uri.path == '/api/client/session/refresh' ||
            request.uri.path == '/api/client/route-policy' ||
            request.uri.path == '/api/client/profile/managed') {
          await utf8.decoder.bind(request).join();
          request.response.headers.contentType = ContentType.json;
          if (request.uri.path == '/api/client/session/refresh') {
            statsToken = 'renewed-stats-fixture-token';
            request.response.write(jsonEncode({'ok': true, 'session': {
              'account_id': '42', 'canonical_account_id': canonicalAccountId,
              'access_token': statsToken, 'refresh_token': 'renewed-stats-fixture-refresh',
            }}));
          } else if (request.uri.path == '/api/client/profile/managed') {
            managedRequests++;
            final expired = expireNextManagedRequest;
            expireNextManagedRequest = false;
            request.response.statusCode = expired ? HttpStatus.unauthorized : HttpStatus.ok;
            request.response.write(expired
                ? '{"detail":"expired"}' : jsonEncode(_readyManagedProfile('stats')));
          } else {
            request.response.write('{"ok":true}');
          }
          await request.response.close();
          continue;
        }
        expect(request.uri.path, '/api/client/runtime/stats');
        expect(request.headers.value(HttpHeaders.authorizationHeader), 'Bearer $statsToken');
        received.add(jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>);
        if (stallNextRequest) {
          stallNextRequest = false;
          stalledRequestStarted?.complete();
          continue;
        }
        request.response.headers.contentType = ContentType.json;
        request.response.statusCode = received.length == 1 ? 503 : runtimeStatsStatus;
        request.response.write(received.length == 1 ? '{"detail":"unavailable"}' : '{"ok":true}');
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'https://api.pokrov.space/', apiFallbackBaseUrls: const [],
      supportDirectoryResolver: () async {
        if (gateNextSessionRead && !sessionReadStarted.isCompleted) {
          sessionReadStarted.complete();
          await releaseSessionRead.future;
        }
        return directory;
      },
      sessionSecretStore: secrets, httpClientFactory: () {
        if (offline) throw StateError('synthetic transport unavailable');
        return _QaLocalHttpClient(server.port);
      },
      maxRequestAttempts: 1, delayScheduler: (_) async {},
    );
    expect(await bootstrapper.reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: RuntimePhase.initialized.name, connected: false,
        onDeliveryReceipt: (receipt) => receipts.add(receipt)), isFalse,
        reason: 'a cold unbound event cannot be assigned after its first await');
    expect(received, isEmpty);
    expect((receipts.last.enqueued, receipts.last.acknowledged, receipts.last.httpStatus),
        (null, null, null));
    expect(receipts.last.runtimePhase, RuntimePhase.initialized.name);
    gateNextSessionRead = true;
    const probeError = {'operation': 'read_headers', 'cause': 'closed', 'cancel_state': 'cancelled',
      'target': 'owned_reserve', 'request': 'egress_204', 'elapsed_ms': 100,
      'stage_started_ms': 800, 'duration_ms': 900,
      'primary_error': {'operation': 'read_headers', 'cause': 'timeout', 'cancel_state': 'deadline',
        'target': 'owned_api', 'request': 'egress_204', 'elapsed_ms': 300,
        'stage_started_ms': 200, 'duration_ms': 500}};
    const preparation = {'stage': 'http_body', 'elapsed_ms': 6001, 'http_status': 200};
    const awg = {'handshake_initiations': 4, 'handshake_errors': 0,
      'handshake_responses': 0, 'handshake_retries': 2, 'destination_dns': 'resolved'};
    final probe = <String, Object?>{
      'candidate_ref': 'de:awg31_lab', 'candidate_transport': 'awg31',
      'stage': 'probe', 'connected': false, 'failure_kind': 'timeout',
      'duration_ms': 900, 'unrecognized_content': 'must-not-be-delivered',
      'probe_error': {...probeError, 'awg': awg},
      'preparation': preparation,
    };
    final report = bootstrapper.reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'failed', connected: false, attemptNumber: 1, candidateProbes: [probe, {
          'candidate_ref': 'de:profile_0', 'candidate_transport': 'vless_reality',
          'stage': 'probe', 'connected': false, 'duration_ms': 900,
          'failure_kind': 'timeout', 'probe_error': probeError,
        }],
        failureKind: 'core_identity_connect_unacknowledged', failureOperation: 'core_connect',
        failureHttpStatus: 502,
        onDeliveryReceipt: (receipt) => receipts.add(receipt));
    await sessionReadStarted.future;
    probe['duration_ms'] = 1234;
    releaseSessionRead.complete();
    expect(await report, isTrue);
    expect((receipts.last.enqueued, receipts.last.acknowledged, receipts.last.httpStatus),
        (true, true, 200));
    expect(receipts.last.attemptNumber, 1);
    expect((receipts.last.appVersion, receipts.last.buildNumber),
        (pokrovClientVersion, pokrovClientBuildNumber));
    final closedReceipt = jsonEncode(receipts.last.toJson());
    for (final privateField in ['stats-fixture-install', 'stats-fixture-token',
      'candidate_ref', 'candidate_probes', 'report_run_id', 'account_id']) {
      expect(closedReceipt, isNot(contains(privateField)));
    }
    expect(RuntimeStatsDeliveryReceipt(appVersion: pokrovClientVersion,
      buildNumber: pokrovClientBuildNumber, runtimePhase: 'failed', reportSequence: 1,
      attemptNumber: 1, enqueued: true, acknowledged: false,
      capturedAt: DateTime.now(), failureKind: 'raw_sensitive_exception').failureKind, isNull);
    expect(received, hasLength(2));
    expect(received[1], received[0], reason: 'delayed retry keeps the original report and dedupe identity');
    expect(received[0]['client_application'], 'pokrov');
    expect(received[0]['platform'], 'windows');
    expect(received[0]['app_version'], pokrovClientVersion);
    expect(received[0]['build_number'], pokrovClientBuildNumber);
    expect(receipts.last.reportRunId, received[0]['report_run_id']);
    expect(received[0]['failure_kind'], 'core_identity_connect_unacknowledged');
    expect(received[0]['failure_operation'], 'core_connect');
    expect(received[0]['failure_http_status'], 502);
    expect(received[0]['candidate_probes'], [{
      'candidate_ref': 'de:awg31_lab', 'candidate_transport': 'awg31',
      'stage': 'probe', 'connected': false, 'duration_ms': 900, 'failure_kind': 'timeout',
      'awg': awg,
      'preparation': preparation,
    }, {
      'candidate_ref': 'de:profile_0', 'candidate_transport': 'vless_reality',
      'stage': 'probe', 'connected': false, 'duration_ms': 900, 'failure_kind': 'timeout',
      'probe_error': probeError,
    }]);
    expect(jsonEncode(received), isNot(contains('must-not-be-delivered')));
    final outbox = File('${directory.path}/runtime-stats-outbox-windows.json');
    List<dynamic> pending() => (jsonDecode(outbox.readAsStringSync()) as Map)['records'] as List;
    expect(pending(), isEmpty);

    offline = true;
    const egressSnapshot = RuntimeSnapshot(hostPlatform: HostPlatform.windows, lane: RuntimeLane.windowsService,
      phase: RuntimePhase.running, artifactDirectory: null, coreBinaryPath: null, helperBinaryPath: null,
      stagedConfigPath: null, supportsLiveConnect: true, canInitialize: true, canConnect: true,
      message: 'fixture', lastFailureKind: 'core_egress_timeout',
      egressProbeObservation: (stage: 'tls', outcome: 'deadline', errorDomain: 'none', errorCode: 0,
        elapsedMs: 1438, target: 'owned_reserve', ownerRemainingMsAtEntry: 1425, dnsAAccepted: true, httpLocalIsTun: false));
    expect(await bootstrapper.reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'failed', connected: false, attemptNumber: 2, candidateProbes: [probe],
        failureKind: 'core_egress_timeout', failureOperation: 'core_connect',
        egressProbeObservation: egressSnapshot.egressProbeObservation), isFalse);
    expect(pending(), hasLength(1));
    final frozenBody = Map<String, dynamic>.from(pending().single['body'] as Map);
    expect(frozenBody['failure_operation'], 'core_connect');
    expect((frozenBody['candidate_probes'] as List).single['awg'], awg);
    expect(frozenBody['egress_probe'], {'stage': 'tls', 'outcome': 'deadline', 'error_domain': 'none',
      'error_code': 0, 'elapsed_ms': 1438, 'target': 'owned_reserve',
      'owner_remaining_ms_at_entry': 1425, 'dns_a_accepted': true, 'http_local_is_tun': false});
    expect(utf8.encode(jsonEncode(pending().single)).length, lessThanOrEqualTo(8 * 1024));
    expect(jsonEncode(pending()), isNot(contains('stats-fixture-token')));
    AppFirstRuntimeBootstrapper restart({AppFirstStateFileWriter? stateFileWriter}) => AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'https://api.pokrov.space/', apiFallbackBaseUrls: const [],
      supportDirectoryResolver: () async => directory, sessionSecretStore: secrets,
      httpClientFactory: () => _QaLocalHttpClient(server.port), maxRequestAttempts: 1,
      delayScheduler: (_) async {}, stateFileWriter: stateFileWriter,
    );
    runtimeStatsStatus = HttpStatus.accepted;
    final recovered = restart();
    expect(await recovered.reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'app_opened', connected: false,
        onDeliveryReceipt: (receipt) => receipts.add(receipt)), isFalse,
        reason: 'ACK of an older bound report is not ACK of this unbound current event');
    expect((receipts.last.enqueued, receipts.last.acknowledged, receipts.last.httpStatus),
        (null, null, null), reason: 'the older POST supplies no current-key HTTP receipt');
    expect(received, hasLength(3));
    expect(received.last, frozenBody, reason: 'restart retains original IDs, time, version, build and probes');
    expect(pending(), hasLength(1), reason: 'HTTP 202 with ok: true is not a committed ACK');
    runtimeStatsStatus = HttpStatus.ok;
    await restart().reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'app_opened', connected: false);
    expect(received, hasLength(4));
    expect(received.last, frozenBody, reason: 'HTTP 200 acknowledges the same retained report');
    expect(pending(), isEmpty);
    await restart().reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'app_opened', connected: false);
    expect(received, hasLength(4), reason: 'the acknowledged record is never replayed');

    runtimeStatsStatus = HttpStatus.accepted;
    expect(await recovered.reportRuntimeStats(hostPlatform: HostPlatform.windows,
      runtimePhase: RuntimePhase.configStaged.name, connected: false, attemptNumber: 2,
      onDeliveryReceipt: (receipt) => receipts.add(receipt)), isFalse);
    expect((receipts.last.enqueued, receipts.last.acknowledged, receipts.last.httpStatus),
        (true, false, 202), reason: 'HTTP 202 is observed but does not ACK the current key');
    expect(receipts.last.runtimePhase, RuntimePhase.configStaged.name.toLowerCase());
    runtimeStatsStatus = HttpStatus.ok;
    expect(await recovered.reportRuntimeStats(hostPlatform: HostPlatform.windows,
      runtimePhase: 'failed', connected: false, attemptNumber: 2), isTrue);
    expect(pending(), isEmpty);

    for (var index = 0; index < 16; index++) {
      expect(await bootstrapper.reportRuntimeStats(hostPlatform: HostPlatform.windows,
          runtimePhase: 'failed', connected: false, durationMs: index), isFalse);
    }
    expect(pending(), hasLength(16));
    final beforeBatch = received.length;
    expect(await recovered.reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'failed', connected: false, durationMs: 999), isTrue);
    expect(received.length - beforeBatch, 16);
    expect(received[beforeBatch]['duration_ms'], 999, reason: 'the current terminal packet goes before the backlog');
    expect(pending(), hasLength(1));
    await restart().reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'app_opened', connected: false);
    expect(pending(), isEmpty);

    stallNextRequest = true;
    stalledRequestStarted = Completer<void>();
    final deadlineWatch = Stopwatch()..start();
    final stalled = recovered.reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'failed', connected: false);
    await stalledRequestStarted.future;
    expect(await recovered.reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'failed', connected: false,
        onDeliveryReceipt: (receipt) => receipts.add(receipt)), isFalse);
    expect(await stalled, isFalse);
    expect((receipts.last.enqueued, receipts.last.acknowledged,
        receipts.last.httpStatus, receipts.last.failureKind), (true, null, null, null),
        reason: 'a coalesced caller has no evidence of its own POST or acknowledgement');
    expect(deadlineWatch.elapsed, lessThan(recovered.smartConnectTelemetryDeadline * 2));
    expect(pending(), hasLength(2), reason: 'a delivery deadline is not an ACK');
    await restart().reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'app_opened', connected: false);
    expect(pending(), isEmpty);
    sessionReadStarted = Completer<void>();
    releaseSessionRead = Completer<void>();
    final overlappingReport = bootstrapper.reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'failed', connected: false, attemptNumber: 3, candidateProbes: [probe]);
    await sessionReadStarted.future;
    expect(await bootstrapper.reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'failed', connected: false, attemptNumber: 3, candidateProbes: [probe]), isFalse);
    releaseSessionRead.complete();
    expect(await overlappingReport, isFalse);
    expect(pending(), hasLength(2));
    expect(pending().where((item) => (item['body'] as Map).containsKey('candidate_probes')),
        hasLength(1), reason: 'overlapping reports reserve each probe before the first state read');
    await restart().reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'app_opened', connected: false);
    expect(pending(), isEmpty);
    expect(await bootstrapper.reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'failed', connected: false, attemptNumber: 4, candidateProbes: [probe]), isFalse);
    final beforeRefresh = jsonDecode(outbox.readAsStringSync()) as Map<String, dynamic>;
    final legacyRecord = (beforeRefresh['records'] as List).single as Map<String, dynamic>;
    final foreignRecord = <String, dynamic>{
      ...legacyRecord, 'account_id': '99',
      'body': {...legacyRecord['body'] as Map, 'report_sequence': 1000},
    };
    (beforeRefresh['records'] as List).add(foreignRecord);
    await outbox.writeAsString(jsonEncode(beforeRefresh));
    await secrets.writeSessionPair(hostPlatform: HostPlatform.windows,
        installId: 'stats-fixture-install', pair: AppFirstSessionCredentials(
          accessToken: statsToken, refreshToken: 'stats-fixture-refresh'));
    final beforeFailedRebind = await outbox.readAsString();
    var rebindWriteFailed = false;
    expireNextManagedRequest = true;
    await restart(stateFileWriter: (file, contents) async {
      if (file.uri == outbox.uri) {
        rebindWriteFailed = true;
        throw const FileSystemException('synthetic outbox write failure');
      }
      await file.writeAsString(contents);
    }).resolveManagedProfile(hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel);
    expect(rebindWriteFailed, isTrue);
    expect(await outbox.readAsString(), beforeFailedRebind,
        reason: 'failed telemetry rebind preserves pending data while session refresh succeeds');
    expect((jsonDecode(await File('${directory.path}/app-first-session-windows.json')
        .readAsString()) as Map)['account_id'], canonicalAccountId);
    expireNextManagedRequest = true;
    await restart().resolveManagedProfile(hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.fullTunnel);
    expect(managedRequests, 4, reason: 'the next ordinary refresh retries the proven account rebind');
    expect(pending().first['account_id'], canonicalAccountId);
    expect(pending().first['body'], legacyRecord['body'], reason: 'canonical binding keeps the original event identity');
    expect(pending().last, foreignRecord);
    final beforeCanonicalDelivery = received.length;
    await restart().reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'app_opened', connected: false);
    expect(received, hasLength(beforeCanonicalDelivery + 1));
    expect(received.last, legacyRecord['body']);
    expect(pending(), [foreignRecord], reason: 'a proven account alias never rebinds another account on the same install');
    final deliveredBeforeAccountChange = received.length;

    // A fresh account must not receive the previous account's queued event.
    final held = jsonDecode(outbox.readAsStringSync()) as Map<String, dynamic>;
    final stateFile = File('${directory.path}/app-first-session-windows.json');
    final nextState = jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    nextState['account_id'] = 'changed-fixture-account';
    await stateFile.writeAsString(jsonEncode(nextState));
    await secrets.writeSessionToken(hostPlatform: HostPlatform.windows,
        installId: 'stats-fixture-install', sessionToken: 'changed-fixture-token');
    expect(await restart().reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'app_opened', connected: false), isFalse);
    expect(jsonDecode(await outbox.readAsString()), held);
    expect(received, hasLength(deliveredBeforeAccountChange));
    (held['records'] as List).single['body']['occurred_at'] = DateTime.now().toUtc()
        .subtract(const Duration(days: 7, seconds: 1)).toIso8601String();
    await outbox.writeAsString(jsonEncode(held));
    await restart().reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'app_opened', connected: false);
    expect(pending(), isEmpty, reason: 'TTL cleanup does not pretend a server ACK');
    expect(received, hasLength(deliveredBeforeAccountChange));
    await outbox.writeAsBytes(List.filled(4 * 1024 * 1024 + 1, 32));
    await expectLater(restart().reportRuntimeStats(hostPlatform: HostPlatform.windows,
        runtimePhase: 'app_opened', connected: false), throwsFormatException);
    expect(received, hasLength(deliveredBeforeAccountChange), reason: 'an oversized pending file is never transmitted');
  });

  test('country Auto caches XHTTP beside REALITY and restores its exact material offline', () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-transport-reserve-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    const realityRef = 'de:legacy_reality_fallback';
    const xhttpRef = 'de:xhttp_stream_one';
    final queries = <Map<String, String>>[];
    Map<String, Object?> config(bool xhttp) => {
      'outbounds': [
        {'type': 'selector', 'tag': 'proxy', 'outbounds': ['fixture-node'], 'default': 'fixture-node'},
        {'type': 'vless', 'tag': 'fixture-node', 'server': 'fixture.invalid', 'server_port': 443,
          'uuid': '11111111-1111-4111-8111-111111111111',
          'tls': {'enabled': true, 'server_name': 'fixture.invalid'},
          if (xhttp) 'transport': {'type': 'xhttp', 'mode': 'stream-one', 'path': '/fixture'}},
      ],
      'route': {'final': 'proxy'},
    };
    Map<String, Object?> candidate(bool xhttp) => {
      'candidate_ref': xhttp ? xhttpRef : realityRef,
      'profile_ref': xhttp ? 'xhttp_stream_one' : 'legacy_reality_fallback',
      'node_code': 'de', 'country_code': 'DE', 'protocol': 'vless',
      'transport': xhttp ? 'xhttp' : 'tcp', 'protection': xhttp ? 'tls' : 'reality',
      'priority': xhttp ? 1 : 0, 'parameters': {'network': 'tcp', 'flow': ''},
      'requirements': {'minimum_client_release': '1.2.0', 'minimum_core_release': null,
        'platforms': ['windows'], 'required_features': [
          'singbox_vless_v1', xhttp ? 'singbox_xhttp_v1' : 'singbox_reality_v1']},
    };
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response.write(jsonEncode({
            'session': {'session_token': 'synthetic-session', 'account_id': 'synthetic-account'},
            'provisioning': {'status': 'ready', 'sync_ok': true},
          }));
        } else if (request.uri.path == '/api/client/profile/managed') {
          queries.add(request.uri.queryParameters);
          final exact = request.uri.queryParameters['selected_candidate_ref'] == realityRef;
          request.response.write(jsonEncode({
            'profile_revision': 'transport-reserve', 'config_format': 'singbox-json',
            'transport_profile': 'legacy_reality_fallback', 'transport_kind': 'reality',
            'config_payload': config(false),
            'transport_catalog': {'schema_version': 'pokrov-transport-catalog-v1',
              'revision': 'transport-reserve', 'selected_candidate_ref': realityRef,
              'candidates': [candidate(false), candidate(true)]},
            'candidate_materials': exact ? [{
              'candidate_ref': realityRef, 'transport_kind': 'reality',
              'config_format': 'singbox-json', 'config_payload': config(false),
            }] : [for (final xhttp in [false, true]) {
              'candidate_ref': xhttp ? xhttpRef : realityRef,
              'transport_kind': xhttp ? 'xhttp' : 'reality',
              'config_format': 'singbox-json', 'config_payload': config(xhttp),
            }],
            'provisioning': {'status': 'ready', 'sync_ok': true},
            'access': {'access_state': 'paid_unlimited',
              'expiry_at': DateTime.now().toUtc().add(const Duration(days: 2)).toIso8601String()},
          }));
        } else {
          request.response.write('{"ok":true}');
        }
        await request.response.close();
      }
    }());
    AppFirstRuntimeBootstrapper create({bool offline = false}) => AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}', supportDirectoryResolver: () async => directory,
      maxRequestAttempts: 1,
      httpClientFactory: offline ? () => throw StateError('offline restore used HTTP') : null);
    const inputs = ManagedProfileCacheInputs(hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel, preferredCountryCode: 'DE');
    final features = RuntimeTransportFeature.values.toSet();
    final online = create();
    final selected = await online.resolveManagedProfile(hostPlatform: inputs.hostPlatform,
      routeMode: inputs.routeMode, preferredCountryCode: inputs.preferredCountryCode,
      runtimeFeatures: features, selectCandidate: false);
    expect(queries.single['selected_country_code'], 'DE');
    expect(queries.single['candidate_material_limit'], '6');
    expect(selected.materialCandidate?.candidateRef, realityRef);
    await online.markManagedProfileProven(inputs, selected.cacheEntryId);
    final restarted = create(offline: true);
    final reserve = await restarted.loadCachedManagedProfile(inputs,
      selectedCandidateRef: xhttpRef, runtimeFeatures: features);
    expect(reserve, isNotNull, reason: 'XHTTP is a distinct admitted transport despite sharing VLESS with REALITY');
    expect(reserve?.materialCandidate?.candidateRef, xhttpRef);
    expect(reserve?.materialCandidate?.countryCode, 'DE');
    expect(reserve?.configPayload, selected.candidateMaterials[xhttpRef]?.configPayload);
    expect((await restarted.loadCachedManagedProfile(inputs, preferProven: true,
      runtimeFeatures: features))?.materialCandidate?.candidateRef, realityRef);
    final exact = await online.resolveManagedProfile(hostPlatform: inputs.hostPlatform,
      routeMode: inputs.routeMode, preferredCountryCode: inputs.preferredCountryCode,
      runtimeFeatures: features, selectCandidate: false, cacheResult: false,
      selectedCandidateRef: realityRef);
    expect(queries.last['candidate_material_limit'], '1');
    expect(queries.last['selected_candidate_ref'], realityRef);
    expect(exact.materialCandidate?.candidateRef, realityRef);
    expect(exact.candidateMaterials.keys, [realityRef]);
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
    var stallRoutePolicy = false;
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
          if (stallRoutePolicy) continue;
          request.response.statusCode = accessTokenExpired ? 401 : 200;
          request.response.write(accessTokenExpired ? '{"detail":"session expired"}' : '{"ok":true}');
        } else if (request.uri.path == '/api/client/profile/managed') {
          if (stall) {
            // Headers arrived; the body never completed before the common deadline.
            request.response.write('{');
            await request.response.flush();
            continue;
          }
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
    Matcher deadlineAt(String operation) => allOf(
      isA<TimeoutException>(),
      isA<ManagedProfileTimeout>()
        .having((error) => error.operation, 'deadline operation', operation)
        .having((error) => error.preparation?['stage'], 'preparation stage',
            operation == 'managed_fetch' ? 'http_body' : 'route_policy')
        .having((error) => error.preparation?['http_status'], 'observed HTTP status',
            operation == 'managed_fetch' ? 200 : null)
        .having((error) => error.preparation?['elapsed_ms'], 'monotonic elapsed',
            greaterThanOrEqualTo(100)),
      isNot(isA<BootstrapFailure>()),
    );
    stall = true;
    await expectLater(online.resolveManagedProfile(
      hostPlatform: inputs.hostPlatform, routeMode: inputs.routeMode,
      timeout: const Duration(milliseconds: 100),
    ).timeout(const Duration(seconds: 2)), throwsA(deadlineAt('managed_fetch')));
    expect((await restarted.loadCachedManagedProfile(inputs))?.cacheEntryId, renewed.cacheEntryId);
    stall = false;
    stallRoutePolicy = true;
    await expectLater(online.resolveManagedProfile(
      hostPlatform: inputs.hostPlatform, routeMode: inputs.routeMode,
      timeout: const Duration(milliseconds: 100),
    ).timeout(const Duration(seconds: 2)), throwsA(deadlineAt('route_policy')));
    expect((await restarted.loadCachedManagedProfile(inputs))?.cacheEntryId, renewed.cacheEntryId);
    stallRoutePolicy = false;
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

  test('claims a one-time device code and reuses its current session on repeat login',
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
    final claimBearers = <String?>[];
    String? currentInstallId;
    var requireRefresh = false;
    var refreshStarted = Completer<void>();
    var releaseRefresh = Completer<void>();
    Map<String, Object?> receiptOverride = {};
    Future<void> Function()? beforeClaimResponse;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/refresh') {
          refreshStarted.complete();
          await releaseRefresh.future;
          requireRefresh = false;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'access_token': 'renewed-paired-access', 'refresh_token': 'renewed-paired-refresh',
            'canonical_account_id': 'paired-account-id',
          }));
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/api/client/device-pairing/claim') {
          claimBody = jsonDecode(body) as Map<String, dynamic>;
          claimBearers.add(request.headers.value(HttpHeaders.authorizationHeader));
          if (requireRefresh) {
            request.response.statusCode = HttpStatus.unauthorized;
            request.response.write('{"detail":"expired"}');
            await request.response.close();
            continue;
          }
          await beforeClaimResponse?.call();
          if (currentInstallId != null) {
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              'ok': true, 'existing_device': true,
              'canonical_account_id': 'paired-account-id',
              'install_id': currentInstallId,
              ...receiptOverride,
            }));
            await request.response.close();
            continue;
          }
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
    currentInstallId = result.installId;
    final establishedState = jsonDecode(stateText) as Map<String, dynamic>;
    establishedState['profile_revision'] = 'already-working-profile';
    await stateFile.writeAsString(jsonEncode(establishedState));
    final repeated = await bootstrapper.claimDevicePairingCode(
      hostPlatform: HostPlatform.windows, code: 'EFGH-2345',
    );
    expect(repeated.ok, isTrue);
    expect(repeated.existingDevice, isTrue);
    expect(repeated.installId, result.installId);
    expect(claimBearers, [null, 'Bearer paired-access-token']);
    expect(jsonDecode(await stateFile.readAsString()), establishedState);
    final retained = await sessionSecretStore.readSessionPair(
      hostPlatform: HostPlatform.windows, installId: result.installId,
    );
    expect(retained?.accessToken, 'paired-access-token');
    expect(retained?.refreshToken, 'paired-refresh-token');

    // A profile update during ordinary refresh survives the credential write.
    requireRefresh = true;
    final renewing = bootstrapper.claimDevicePairingCode(
      hostPlatform: HostPlatform.windows, code: 'JKLM-6789',
    );
    await refreshStarted.future;
    establishedState['profile_revision'] = 'concurrent-profile-update';
    await stateFile.writeAsString(jsonEncode(establishedState));
    releaseRefresh.complete();
    expect((await renewing).installId, result.installId);
    expect(jsonDecode(await stateFile.readAsString()), establishedState);

    // A replacement login during refresh must not restore its old credentials.
    requireRefresh = true;
    refreshStarted = Completer<void>();
    releaseRefresh = Completer<void>();
    final stale = bootstrapper.claimDevicePairingCode(
      hostPlatform: HostPlatform.windows, code: 'NPQR-2345',
    );
    await refreshStarted.future;
    await sessionSecretStore.writeSessionPair(
      hostPlatform: HostPlatform.windows, installId: result.installId,
      pair: const AppFirstSessionCredentials(
        accessToken: 'replacement-login-access', refreshToken: 'replacement-login-refresh'),
    );
    final rejected = expectLater(stale, throwsA(isA<BootstrapFailure>()));
    releaseRefresh.complete();
    await rejected;
    final replacement = await sessionSecretStore.readSessionPair(
      hostPlatform: HostPlatform.windows, installId: result.installId,
    );
    expect(replacement?.accessToken, 'replacement-login-access');
    expect(replacement?.refreshToken, 'replacement-login-refresh');
    expect(jsonDecode(await stateFile.readAsString()), establishedState);
    expect(requests.where((request) => request.endsWith('/refresh')), hasLength(2));
    expect(claimBearers, [null, 'Bearer paired-access-token',
      'Bearer paired-access-token', 'Bearer renewed-paired-access', 'Bearer renewed-paired-access']);

    // The two receipt bindings must match this request, never another device.
    for (final field in ['canonical_account_id', 'install_id']) {
      receiptOverride = {field: 'another-binding'};
      await expectLater(bootstrapper.claimDevicePairingCode(
        hostPlatform: HostPlatform.windows, code: 'STUV-2345',
      ), throwsA(isA<BootstrapFailure>()));
      expect(jsonDecode(await stateFile.readAsString()), establishedState);
    }
    receiptOverride = {};

    // Older persisted account IDs may be numeric; the bound request token
    // already carries the canonical account which the server verifies.
    String fixtureEnvelope(Map<String, Object?> claims) =>
        '${base64Url.encode(utf8.encode(jsonEncode(claims)))}.fixture-signature';
    establishedState['account_id'] = '42';
    await stateFile.writeAsString(jsonEncode(establishedState));
    await sessionSecretStore.writeSessionPair(hostPlatform: HostPlatform.windows, installId: result.installId,
      pair: AppFirstSessionCredentials(accessToken: fixtureEnvelope({
        'id': 42, 'account_id': 'paired-account-id', 'session_id': 'fixture-session', 'device_id': 'fixture-device',
      }), refreshToken: 'canonical-fixture-refresh'));
    final canonical = await bootstrapper.claimDevicePairingCode(
      hostPlatform: HostPlatform.windows, code: 'WXYZ-2345',
    );
    expect(canonical.accountId, 'paired-account-id');
    expect(canonical.existingDevice, isTrue);
    expect(jsonDecode(await stateFile.readAsString()), establishedState);

    // A known stateless envelope follows the original fresh pairing path;
    // an unparseable no-refresh credential is still sent and rejected.
    await sessionSecretStore.writeSessionToken(hostPlatform: HostPlatform.windows,
        installId: result.installId, sessionToken: 'malformed-device-proof');
    requireRefresh = true;
    final requestsBeforeInvalid = requests.length;
    await expectLater(bootstrapper.claimDevicePairingCode(
      hostPlatform: HostPlatform.windows, code: 'ABCD-6789',
    ), throwsA(isA<BootstrapFailure>()));
    expect(requests.length, requestsBeforeInvalid + 1);
    expect(claimBearers.last, 'Bearer malformed-device-proof');
    requireRefresh = false;
    await sessionSecretStore.writeSessionToken(hostPlatform: HostPlatform.windows, installId: result.installId,
        sessionToken: fixtureEnvelope({'id': 42, 'exp': 2000000000, 'session_id': null, 'device_id': null}));
    currentInstallId = null;
    final migrated = await bootstrapper.claimDevicePairingCode(
      hostPlatform: HostPlatform.windows, code: 'EFGH-6789',
    );
    expect(migrated.existingDevice, isFalse);
    expect(migrated.installId, isNot(result.installId));
    expect(claimBearers.last, isNull);

    // A successful new-device reply also cannot overwrite a different login
    // which completed while that claim was in flight.
    establishedState['install_id'] = 'concurrent-login-install';
    establishedState['account_id'] = 'concurrent-login-account';
    beforeClaimResponse = () async {
      await stateFile.writeAsString(jsonEncode(establishedState));
      await sessionSecretStore.writeSessionPair(hostPlatform: HostPlatform.windows,
        installId: 'concurrent-login-install', pair: const AppFirstSessionCredentials(
          accessToken: 'concurrent-login-access', refreshToken: 'concurrent-login-refresh'));
    };
    await expectLater(bootstrapper.claimDevicePairingCode(
      hostPlatform: HostPlatform.windows, code: 'JKLM-2345',
    ), throwsA(isA<BootstrapFailure>()));
    expect(jsonDecode(await stateFile.readAsString()), establishedState);
    expect((await sessionSecretStore.readSessionPair(hostPlatform: HostPlatform.windows,
        installId: 'concurrent-login-install'))?.refreshToken, 'concurrent-login-refresh');
  });

  test('refreshes an expired access session without starting a second trial',
      () async {
    final httpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = httpOverrides);
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
    const canonicalAccountId = '11111111-1111-4111-8111-111111111111';
    String? trialInstallId;
    final savedBindings = <Map<String, dynamic>>[];
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}app-first-session-windows.json',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        final path = request.uri.path;
        if (path == '/api/client/session/start-trial') {
          starts += 1;
          trialInstallId = (jsonDecode(body) as Map)['install_id'] as String;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'access_token': 'expired-access',
              'refresh_token': 'refresh-one',
              'account_id': '42',
              'canonical_account_id': canonicalAccountId,
              'session': <String, Object?>{
                'access_token': 'expired-access',
                'session_token': 'expired-access',
                'refresh_token': 'refresh-one',
                'account_id': '42',
                'canonical_account_id': canonicalAccountId,
              },
              'provisioning': <String, Object?>{
                'status': 'ready',
                'sync_ok': true
              },
            }));
        } else if (path == '/api/client/session/refresh') {
          refreshes += 1;
          final session = <String, Object?>{
            'access_token': 'fresh-access',
            'session_token': 'fresh-access',
            'refresh_token': 'refresh-two',
            'account_id': '42',
            'canonical_account_id': canonicalAccountId,
          };
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'ok': true,
              ...session,
              'session': session,
            }));
        } else if (path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write('{"ok":true}');
        } else if (path == '/api/client/profile/managed') {
          profiles += 1;
          savedBindings.add(
            jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>,
          );
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
    expect(savedBindings.map((state) => state['account_id']),
        [canonicalAccountId, canonicalAccountId]);
    expect(trialInstallId, isNotEmpty);
    expect(savedBindings.map((state) => state['install_id']),
        [trialInstallId, trialInstallId]);
  });

  test('support and account requests share one session refresh', () async {
    final httpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = httpOverrides);
    final directory = await Directory.systemTemp.createTemp(
      'pokrov-support-account-refresh-',
    );
    addTearDown(() => directory.delete(recursive: true));
    const platform = HostPlatform.windows;
    const installId = 'shared-refresh-install';
    final stateFile = File(
      '${directory.path}${Platform.pathSeparator}app-first-session-windows.json',
    );
    await stateFile.writeAsString(jsonEncode({
      'schema_version': 1,
      'install_id': installId,
      'account_id': 'shared-refresh-account',
      'session_token_storage': 'secure',
      'managed_manifest_path': '/api/client/profile/managed',
    }));
    final secrets = MemoryAppFirstSessionSecretStore();
    await secrets.writeSessionPair(
      hostPlatform: platform,
      installId: installId,
      pair: const AppFirstSessionCredentials(
        accessToken: 'expired-access', refreshToken: 'refresh-one'),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final bothDenied = Completer<void>();
    final refreshStarted = Completer<void>();
    final releaseRefresh = Completer<void>();
    var denied = 0;
    var refreshes = 0;
    final authorizedPaths = <String>[];
    addTearDown(() async {
      if (!releaseRefresh.isCompleted) releaseRefresh.complete();
      await server.close(force: true);
    });
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final path = request.uri.path;
      request.response.headers.contentType = ContentType.json;
      if (path == '/api/client/session/refresh') {
        refreshes += 1;
        expect(jsonDecode(body), {'refresh_token': 'refresh-one'});
        if (!refreshStarted.isCompleted) refreshStarted.complete();
        await releaseRefresh.future;
        request.response.write(jsonEncode({
          'session': {
            'access_token': 'fresh-access',
            'refresh_token': 'refresh-two',
            'account_id': 'shared-refresh-account',
          },
        }));
      } else if (request.headers.value(HttpHeaders.authorizationHeader) ==
          'Bearer expired-access') {
        denied += 1;
        if (denied == 2) bothDenied.complete();
        await bothDenied.future;
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..write('{"detail":"expired"}');
      } else {
        expect(request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer fresh-access');
        authorizedPaths.add(path);
        request.response.write(path == '/api/client/subscription'
            ? '{"lane":"paid"}'
            : '{"tickets":[{"id":88,"status":"open"}]}');
      }
      await request.response.close();
    });
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => directory,
      sessionSecretStore: secrets,
      maxRequestAttempts: 1,
    );
    final support = AppFirstSupportTicketService(bootstrapper: bootstrapper);
    final subscription = bootstrapper.fetchClientSubscription(
      hostPlatform: platform,
    );
    final tickets = support.listTickets(hostPlatform: platform);
    await refreshStarted.future;
    await pumpEventQueue();
    expect(refreshes, 1);
    releaseRefresh.complete();
    expect((await subscription).lane, 'paid');
    expect((await tickets).single.id, 88);
    expect(authorizedPaths,
        unorderedEquals(['/api/client/subscription', '/api/tickets']));
    expect(refreshes, 1);
    expect((await secrets.readSessionPair(
      hostPlatform: platform, installId: installId,
    ))?.refreshToken, 'refresh-two');
  });

  test('preserves account when concurrent refresh completes during profile denial',
      () async {
    final httpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = httpOverrides);
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-concurrent-refresh-test-',
    );
    addTearDown(() async => tempDirectory.delete(recursive: true));
    const canonicalAccountId = '11111111-1111-4111-8111-111111111111';
    const installId = 'concurrent-refresh-install';
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}app-first-session-windows.json',
    );
    await stateFile.writeAsString(jsonEncode(<String, Object?>{
      'schema_version': 1,
      'install_id': installId,
      'account_id': canonicalAccountId,
      'session_token_storage': 'secure',
      'managed_manifest_path': '/api/client/profile/managed',
    }));
    final secrets = MemoryAppFirstSessionSecretStore();
    await secrets.writeSessionPair(
      hostPlatform: HostPlatform.windows,
      installId: installId,
      pair: const AppFirstSessionCredentials(
        accessToken: 'expired-access', refreshToken: 'refresh-one'),
    );
    var starts = 0;
    var refreshes = 0;
    final profileBearers = <String?>[];
    final savedBindings = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        final path = request.uri.path;
        request.response.headers.contentType = ContentType.json;
        if (path == '/api/client/session/start-trial') {
          starts += 1;
          request.response.statusCode = HttpStatus.badRequest;
        } else if (path == '/api/client/session/refresh') {
          refreshes += 1;
          expect(jsonDecode(body), {'refresh_token': 'refresh-one'});
          request.response.write(jsonEncode(<String, Object?>{
            'session': <String, Object?>{
              'access_token': 'fresh-access',
              'refresh_token': 'refresh-two',
              'account_id': '42',
              'canonical_account_id': canonicalAccountId,
            },
          }));
        } else if (path == '/api/client/route-policy') {
          request.response.write('{"ok":true}');
        } else if (path == '/api/client/profile/managed') {
          profileBearers.add(request.headers.value(HttpHeaders.authorizationHeader));
          savedBindings.add(
            jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>,
          );
          if (profileBearers.length == 1) {
            request.response
              ..statusCode = HttpStatus.unauthorized
              ..write('{"detail":"expired"}');
          } else {
            request.response.write(jsonEncode(_readyManagedProfile('refresh')));
          }
        } else if (path == '/api/client/subscription') {
          if (request.headers.value(HttpHeaders.authorizationHeader) ==
              'Bearer expired-access') {
            request.response
              ..statusCode = HttpStatus.unauthorized
              ..write('{"detail":"expired"}');
          } else {
            expect(request.headers.value(HttpHeaders.authorizationHeader),
                'Bearer fresh-access');
            request.response.write('{"lane":"trial"}');
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }());
    final cache = _PausedProfileCacheClear();
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: secrets,
      managedProfileCache: cache,
      delayScheduler: (_) async {},
    );
    final resolving = bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    // The profile's identity guard has passed, but its refresh has not read
    // the latest credentials yet. Complete the concurrent rotation here.
    await cache.clearStarted.future;
    try {
      final subscription = await bootstrapper.fetchClientSubscription(
        hostPlatform: HostPlatform.windows,
      );
      expect(subscription.lane, 'trial');
      expect(refreshes, 1);
    } finally {
      cache.releaseClear.complete();
    }
    final payload = await resolving;
    expect(payload.profileName, 'pokrov-windows-refresh');
    expect(starts, 0);
    expect(refreshes, 1);
    expect(profileBearers, ['Bearer expired-access', 'Bearer fresh-access']);
    expect(savedBindings.map((state) => state['account_id']),
        [canonicalAccountId, canonicalAccountId]);
    expect(savedBindings.map((state) => state['install_id']),
        [installId, installId]);
    final cached = await bootstrapper.loadCachedManagedProfile(
      const ManagedProfileCacheInputs(
        hostPlatform: HostPlatform.windows, routeMode: RouteMode.fullTunnel),
    );
    expect(cached?.profileName, payload.profileName);
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

}
