import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_app_shell/emergency_network_contract.dart';
import 'package:pokrov_app_shell/src/emergency/emergency_network_store.dart';
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

String _emergencyB64(List<int> value) =>
    base64UrlEncode(value).replaceAll('=', '');

Future<Map<String, Object?>> _signedEmergencyEnvelope(
  Map<String, Object?> payload, {
  required Ed25519 algorithm,
  required SimpleKeyPair keyPair,
}) async {
  final bytes = utf8.encode(jsonEncode(payload));
  final signature = await algorithm.sign(bytes, keyPair: keyPair);
  return <String, Object?>{
    'schema_version': 1,
    'algorithm': 'Ed25519',
    'key_id': 'offline-test-key',
    'payload_b64': _emergencyB64(bytes),
    'signature_b64': _emergencyB64(signature.bytes),
  };
}

Map<String, Object?> _offlineEmergencyConfig(String reserveId) =>
    <String, Object?>{
      'outbounds': <Object?>[
        <String, Object?>{
          'type': 'vless',
          'tag': 'POKROV emergency reserve',
          'server': '$reserveId.example',
          'server_port': 443,
          'uuid': '11111111-1111-4111-8111-111111111111',
          'tls': <String, Object?>{
            'enabled': true,
            'reality': <String, Object?>{'enabled': true},
          },
        },
        <String, Object?>{'type': 'direct', 'tag': 'direct'},
        <String, Object?>{'type': 'block', 'tag': 'block'},
        <String, Object?>{'type': 'dns', 'tag': 'dns-out'},
      ],
      'dns': <String, Object?>{
        'servers': <Object?>[
          <String, Object?>{'tag': 'bootstrap', 'address': 'local'},
          <String, Object?>{
            'tag': 'emergency-dns',
            'address': 'https://1.1.1.1/dns-query',
            'detour': 'POKROV emergency reserve',
          },
        ],
        'final': 'emergency-dns',
      },
      'route': <String, Object?>{
        'final': 'POKROV emergency reserve',
        'rule_set': <Object?>[
          <String, Object?>{
            'type': 'remote',
            'tag': 'geoip-ru',
            'format': 'binary',
            'url': 'https://connect.pokrov.space/rules/geoip-ru.srs',
            'download_detour': 'POKROV emergency reserve',
          },
        ],
        'rules': <Object?>[
          <String, Object?>{
            'rule_set': <String>['geoip-ru'],
            'outbound': 'direct',
          },
          <String, Object?>{'protocol': 'dns', 'outbound': 'dns-out'},
          <String, Object?>{'ip_is_private': true, 'outbound': 'direct'},
        ],
      },
      '_meta': <String, Object?>{
        'emergency': true,
        'chain_mode': 'reserve_direct',
        'route_scope': 'all_except_ru',
        'quick_settings_eligible': false,
        'warp': false,
      },
    };

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

  test('prewarmed emergency bundle connects without any control-plane request',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-emergency-offline-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    const installId = 'install-emergency-offline-123';
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}app-first-session-android.json',
    );
    await stateFile.writeAsString(
      jsonEncode(<String, Object?>{
        'install_id': installId,
        'session_token': 'offline-session-token',
        'account_id': 'offline-account',
        'managed_manifest_path': '/api/client/profile/managed',
        'profile_revision': '',
      }),
    );

    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final verifier = EmergencyEnvelopeVerifier(
      publicKeysById: <String, String>{
        'offline-test-key': _emergencyB64(publicKey.bytes),
      },
    );
    final binding = await verifier.deviceBinding(installId);
    final now = DateTime.now().toUtc();
    const catalogRevision = 'emg-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final reserveIds = List<String>.generate(
      4,
      (index) => 'emg_${(index + 1).toRadixString(16).padLeft(24, '0')}',
    );
    final catalogEnvelope = await _signedEmergencyEnvelope(
      <String, Object?>{
        'type': 'pokrov.emergency.catalog',
        'schema_version': 1,
        'catalog_revision': catalogRevision,
        'issued_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        'refresh_after': now.add(const Duration(hours: 6)).toIso8601String(),
        'valid_until': now.add(const Duration(days: 4)).toIso8601String(),
        'offline_valid_until':
            now.add(const Duration(days: 4)).toIso8601String(),
        'device_binding': binding,
        'access': <String, Object?>{
          'state': 'trial_premium',
          'expires_at': now.add(const Duration(days: 5)).toIso8601String(),
        },
        'eligibility': <String, Object?>{
          'eligible': true,
          'source': 'entitlement_precache',
          'country_code': 'RU',
          'valid_until': now.add(const Duration(days: 7)).toIso8601String(),
        },
        'disclosure_revision': '2026-08-15.1',
        'items': <Object?>[
          for (var index = 0; index < reserveIds.length; index += 1)
            <String, Object?>{
              'id': reserveIds[index],
              'ordinal': index + 1,
              'country_code': 'DE',
              'transport': 'tcp',
              'status': 'working',
              'latency_ms': 40 + index,
              'latency_source': 'server_probe',
              'checked_at': now.toIso8601String(),
              'verification': 'synthetic_bs',
              'verification_at': now.toIso8601String(),
              'modes': <String>['reserve_direct'],
            },
        ],
      },
      algorithm: algorithm,
      keyPair: keyPair,
    );
    final profileEnvelopes = <Map<String, Object?>>[];
    for (final reserveId in reserveIds) {
      final profileEnvelope = await _signedEmergencyEnvelope(
        <String, Object?>{
          'type': 'pokrov.emergency.profile',
          'schema_version': 1,
          'catalog_revision': catalogRevision,
          'profile_revision': 'emgp-${reserveId.substring(4)}',
          'issued_at':
              now.subtract(const Duration(minutes: 1)).toIso8601String(),
          'offline_valid_until':
              now.add(const Duration(days: 4)).toIso8601String(),
          'device_binding': binding,
          'reserve_id': reserveId,
          'chain_mode': 'reserve_direct',
          'route_scope': 'all_except_ru',
          'access_state': 'trial_premium',
          'access_expires_at':
              now.add(const Duration(days: 5)).toIso8601String(),
          'eligibility_valid_until':
              now.add(const Duration(days: 7)).toIso8601String(),
          'warp': false,
          'quick_settings_eligible': false,
          'config_format': 'singbox-json',
          'config_payload': _offlineEmergencyConfig(reserveId),
        },
        algorithm: algorithm,
        keyPair: keyPair,
      );
      profileEnvelopes.add(<String, Object?>{
        'reserveId': reserveId,
        'chainMode': 'reserve_direct',
        'envelope': profileEnvelope,
      });
    }

    var requestCount = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverPort = server.port;
    unawaited(() async {
      await for (final request in server) {
        requestCount += 1;
        expect(
            request.uri.path, '/api/client/emergency-network/offline-bundle');
        expect(request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer offline-session-token');
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['manual_limited_network'], isFalse);
        expect(body['precache_only'], isTrue);
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, Object?>{
            'schemaVersion': 'pokrov-emergency-offline-bundle-v1',
            'catalogEnvelope': catalogEnvelope,
            'profileEnvelopes': profileEnvelopes,
          }));
        await request.response.close();
      }
    }());
    final sessionStore = MemoryAppFirstSessionSecretStore();
    final emergencyStore = EncryptedEmergencyNetworkStore(
      directoryResolver: () async => tempDirectory,
    );
    final online = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:$serverPort',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: sessionStore,
      emergencyEnvelopeVerifier: verifier,
      emergencyNetworkStore: emergencyStore,
    );
    await online.prepareEmergencyOfflineCache(
      hostPlatform: HostPlatform.android,
    );
    expect(requestCount, 1);
    await server.close(force: true);

    final offline = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:$serverPort',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: sessionStore,
      emergencyEnvelopeVerifier: verifier,
      emergencyNetworkStore: emergencyStore,
      connectionTimeout: const Duration(milliseconds: 50),
      requestTimeout: const Duration(milliseconds: 50),
      maxRequestAttempts: 1,
    );
    final catalog = await offline.fetchEmergencyCatalog(
      hostPlatform: HostPlatform.android,
      manualLimitedNetwork: true,
    );
    final resolved = await offline.resolveEmergencyProfile(
      hostPlatform: HostPlatform.android,
      catalogRevision: catalog.catalog!.revision,
      reserveId: reserveIds.last,
      chainMode: EmergencyChainMode.reserveDirect,
      manualLimitedNetwork: true,
    );

    expect(catalog.usingCache, isTrue);
    expect(resolved.usingCache, isTrue);
    expect(resolved.profile.reserveId, reserveIds.last);
    expect(resolved.managedProfile.materializedForRuntime, isTrue);
    expect(resolved.managedProfile.coreEgressProbeRequired, isTrue);
    final runtimeConfig =
        jsonDecode(resolved.managedProfile.configPayload) as Map;
    final runtimeRoute = runtimeConfig['route'] as Map;
    final runtimeDns = runtimeConfig['dns'] as Map;
    final emergencyDns = (runtimeDns['servers'] as List)
        .cast<Map>()
        .singleWhere((server) => server['tag'] == 'emergency-dns');
    final runtimeOutbounds = (runtimeConfig['outbounds'] as List).cast<Map>();
    expect(runtimeRoute['final'], 'pokrov-emergency-health');
    expect(runtimeDns['strategy'], 'ipv4_only');
    expect(emergencyDns['address'], 'https://1.1.1.1/dns-query');
    final emergencyProbe = runtimeOutbounds.singleWhere(
      (outbound) => outbound['tag'] == 'pokrov-emergency-health',
    );
    expect(emergencyProbe['type'], 'selector');
    expect(
      emergencyProbe['outbounds'],
      <String>[
        'POKROV emergency reserve',
        'pokrov-emergency-probe-copy',
      ],
    );
    final emergencyProbeCopy = runtimeOutbounds.singleWhere(
      (outbound) => outbound['tag'] == 'pokrov-emergency-probe-copy',
    );
    expect(emergencyProbeCopy['type'], 'vless');
    expect(
      emergencyProbeCopy['server'],
      runtimeOutbounds.singleWhere(
        (outbound) => outbound['tag'] == 'POKROV emergency reserve',
      )['server'],
    );
    expect(emergencyProbe['default'], 'POKROV emergency reserve');
    expect(emergencyDns['detour'], 'POKROV emergency reserve');
    expect(emergencyDns.containsKey('type'), isFalse);
    expect(
      runtimeOutbounds.where((outbound) => outbound['type'] == 'selector'),
      hasLength(1),
    );
    expect(
      runtimeOutbounds.where((outbound) => outbound['type'] == 'urltest'),
      isEmpty,
    );
    expect(
      resolved.managedProfile.configPayload,
      isNot(contains('api.my-ip.io')),
    );
    expect(requestCount, 1);

    final authFailureServer =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => authFailureServer.close(force: true));
    unawaited(() async {
      await for (final request in authFailureServer) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
      }
    }());
    final unauthorizedOnlineRefresh = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${authFailureServer.port}',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: sessionStore,
      emergencyEnvelopeVerifier: verifier,
      emergencyNetworkStore: emergencyStore,
      maxRequestAttempts: 1,
    );
    final afterUnauthorized =
        await unauthorizedOnlineRefresh.fetchEmergencyCatalog(
      hostPlatform: HostPlatform.android,
      manualLimitedNetwork: true,
      forceRefresh: true,
    );
    expect(afterUnauthorized.usingCache, isTrue);
    expect(afterUnauthorized.catalog?.revision, catalogRevision);
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

  test('reports a successful runtime connection through the app session',
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

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://${server.address.address}:${server.port}',
      supportDirectoryResolver: () async => tempDirectory,
      sessionSecretStore: MemoryAppFirstSessionSecretStore(),
      maxRequestAttempts: 1,
    );

    await bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.android,
      runtimePhase: 'RUNNING',
      connected: true,
    );
    await bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.android,
      runtimePhase: 'FAILED',
      connected: false,
      errorCode: 'pairing_claim_failed',
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
      'POST /api/client/session/start-trial',
      'POST /api/client/runtime/stats',
      'POST /api/client/runtime/stats',
      'POST /api/client/telegram/link/events',
      'POST /api/account/experience/onboarding',
      'POST /api/events',
      'POST /api/events',
      'POST /api/events',
      'POST /api/acquisition/handoffs/consume',
    ]);
    expect(statsBodies, <Map<String, dynamic>>[
      <String, Object?>{
        'runtime_phase': 'running',
        'connected': true,
      },
      <String, Object?>{
        'runtime_phase': 'failed',
        'connected': false,
        'error_code': 'pairing_claim_failed',
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
      smartConnectTelemetryDeadline: const Duration(milliseconds: 80),
      smartConnectProbeTimeout: const Duration(seconds: 5),
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
              'GET /api/client/profile/managed',
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

    expect(inbounds, hasLength(2));
    expect(tunInbound['stack'], 'system');
    expect(tunInbound['address'], isNotEmpty);
    expect(tunInbound.containsKey('inet4_address'), isFalse);
    expect(tunInbound.containsKey('endpoint_independent_nat'), isFalse);
    expect(tunInbound.containsKey('sniff'), isFalse);
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
      unawaited(() async {
        await for (final request in server) {
          await utf8.decoder.bind(request).join();
          switch (request.uri.path) {
            case '/api/client/session/start-trial':
              request.response
                ..headers.contentType = ContentType.json
                ..write(jsonEncode(<String, Object?>{
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
                }));
            case '/api/client/route-policy':
              request.response
                ..headers.contentType = ContentType.json
                ..write(jsonEncode(<String, Object?>{'ok': true}));
            case '/api/client/profile/managed':
              request.response
                ..headers.contentType = ContentType.json
                ..write(jsonEncode(<String, Object?>{
                  'provisioning': <String, Object?>{
                    'status': 'ready',
                    'sync_ok': true,
                  },
                  'profile_revision': 'rev-${lab['profile']}',
                  'transport_profile': lab['profile'],
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
                }));
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
      final outbounds =
          (config['outbounds'] as List<dynamic>).cast<Map<String, dynamic>>();

      expect(endpoint['type'], 'awg');
      expect(endpoint['tag'], lab['tag']);
      expect(endpoint['contract_id'], lab['contract_id']);
      expect(contract['id'], lab['contract_id']);
      expect(contract['profile'], lab['profile']);
      expect(payload.resolvedNodeCode, isEmpty);
      expect(payload.smartConnect, isNull);
      expect(route['final'], lab['tag']);
      expect(
        outbounds.every(
          (outbound) => const <String>{'direct', 'block', 'dns'}
              .contains(outbound['type']),
        ),
        isTrue,
      );
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
          'id': 'direct',
          'outbound_tag': '🇷🇺 Россия Spb',
        },
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
        '🇷🇺 Россия Spb',
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
      'mixed',
    );
    expect(
      inbounds.singleWhere(
          (inbound) => inbound['type'] == 'tun')['exclude_package'],
      <String>['space.pokrov.pokrov_android_shell'],
    );
    expect(
      inbounds
          .singleWhere((inbound) => inbound['type'] == 'tun')['inet6_address'],
      isNotNull,
    );
    expect(
      inbounds.singleWhere(
          (inbound) => inbound['type'] == 'tun')['domain_strategy'],
      'prefer_ipv4',
    );
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

  test('preserves a runtime-ready managed config on desktop hosts', () async {
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
                      'servers': <Object?>['local'],
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
    expect((config['dns'] as Map<String, dynamic>)['servers'], ['local']);
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
      'mixed',
    );
    expect(
      inbounds.singleWhere(
          (inbound) => inbound['type'] == 'tun')['exclude_package'],
      <String>['space.pokrov.pokrov_android_shell'],
    );
    expect(
      inbounds
          .singleWhere((inbound) => inbound['type'] == 'tun')['inet6_address'],
      isNotNull,
    );
    expect(
      inbounds.singleWhere(
          (inbound) => inbound['type'] == 'tun')['domain_strategy'],
      'prefer_ipv4',
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
    expect(vlessOutbound['domain_resolver'], localServer['tag']);
    expect(route['final'], 'proxy');
    expect(rules.first, <String, dynamic>{
      'protocol': 'dns',
      'action': 'hijack-dns',
    });
    expect(
      rules[1],
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
                      'final': 'google',
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
    final dns = config['dns'] as Map<String, dynamic>;
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();
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
      'android selected-apps route mode syncs selected packages into policy and tun include list',
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
          expect(decoded['selected_apps'], <String>[
            'org.telegram.messenger',
            'com.example.special',
          ]);
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
          expect(decoded['selected_apps'], isEmpty);
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

  test('selected-apps mode rejects an empty selection before bootstrap sync',
      () async {
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:1/',
    );

    await expectLater(
      bootstrapper.resolveManagedProfile(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.selectedApps,
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

  test(
      'windows selected-apps route mode limits proxy routing to selected processes',
      () async {
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
          if (decoded['route_mode'] == 'selected_apps') {
            expect(decoded['selected_apps'], <String>[
              'Telegram.exe',
              'msedge',
            ]);
          } else {
            expect(decoded['route_mode'], 'all_traffic');
            expect(decoded['selected_apps'], isEmpty);
          }
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
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.selectedApps,
      selectedApps: const <String>[
        'Telegram.exe',
        'msedge',
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
        containsPair('process_name', <String>['telegram.exe', 'msedge.exe']),
      ),
    );
    expect(
      routeRules.any(
        (rule) =>
            (rule['process_name'] as List?)?.contains('telegram.exe') == true &&
            rule['outbound'] == 'proxy',
      ),
      isTrue,
    );
    expect(dns['final'], 'dns-direct');
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

    expect(excludedRoute['final'], 'proxy');
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

  test('android full tunnel removes direct from selector and urltest chains',
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
                    'session_token': 'session-token-android-selector-sanitize',
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
                      <String, Object?>{
                        'type': 'direct',
                        'tag': 'direct',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'select',
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
    final outbounds =
        (config['outbounds'] as List).cast<Map<String, dynamic>>();
    final selector =
        outbounds.singleWhere((outbound) => outbound['tag'] == 'select');
    final urltest =
        outbounds.singleWhere((outbound) => outbound['tag'] == 'auto');
    final route = config['route'] as Map<String, dynamic>;

    expect(selector['outbounds'], isNot(contains('direct')));
    expect(selector['default'], isNot('direct'));
    expect(urltest['outbounds'], isNot(contains('direct')));
    expect(
      urltest['url'],
      'https://api.pokrov.space/api/public/authenticated-egress-probe',
    );
    expect(route['final'], 'select');
  });

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

    expect(tunInbound['inet4_address'], '172.19.0.1/28');
    expect(tunInbound.containsKey('inet6_address'), isFalse);
    expect(tunInbound['domain_strategy'], 'ipv4_only');
    expect(tunInbound['stack'], 'mixed');
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

  test('client support assistant gets one longer request window', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-client-assistant-timeout-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    var assistantRequestCount = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        if (request.uri.path == '/api/client/session/start-trial') {
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
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      requestTimeout: const Duration(milliseconds: 30),
      supportAssistantRequestTimeout: const Duration(milliseconds: 250),
      maxRequestAttempts: 3,
    );

    final reply = await bootstrapper.askSupportAssistant(
      hostPlatform: HostPlatform.android,
      message: 'Почему не работает WARP?',
    );

    expect(reply.reply, 'Проверка закончена.');
    expect(assistantRequestCount, 1);
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

    await startRead.future;
    await Future<void>.delayed(Duration.zero);
    expect(starts, 1);
    releaseStart.complete();
    await Future.wait<dynamic>(services);

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
