import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';

const _ruDomainWhitelistRuleSetTag = 'pokrov-ru-domain-whitelist';
const _ruDomainCategoryRuleSetTag = 'pokrov-ru-domain-category';
const _ruIpCountryRuleSetTag = 'pokrov-ru-ip-country';
const _ruIpWhitelistRuleSetTag = 'pokrov-ru-ip-whitelist';
const _validClientUpdateSha256 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

ClientAppUpdateInfo _clientUpdateInfo({
  String url =
      'https://github.com/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov-android-arm64-v8a.apk',
  String sha256 = _validClientUpdateSha256,
  int size = 123456,
  String updatePolicy = 'recommended',
}) {
  return ClientAppUpdateInfo(
    platform: 'android',
    channel: 'beta',
    latestVersion: '1.0.1-beta',
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

  test(
      'android bootstrap can map canonical API host to a direct control-plane IP',
      () {
    expect(
      bootstrapDirectAddressForRequest(
        requestUri: Uri.parse('https://api.pokrov.space/api/health'),
        hostPlatform: HostPlatform.android,
      )?.address,
      '82.21.114.104',
    );
    expect(
      bootstrapDirectAddressForRequest(
        requestUri: Uri.parse('https://api.pokrov.space/api/health'),
        hostPlatform: HostPlatform.windows,
      ),
      isNull,
    );
    expect(
      bootstrapDirectAddressForRequest(
        requestUri: Uri.parse('https://pokrov.space/'),
        hostPlatform: HostPlatform.android,
      ),
      isNull,
    );
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
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.selectedApps,
    );

    expect(payload.profileName, 'pokrov-windows-rev-007');
    expect(payload.smartConnect, isNotNull);
    expect(payload.smartConnect?.shortlistRevision, 'short-007');
    expect(payload.smartConnect?.shortlist.single.code, 'pl');
    expect(payload.smartConnect?.shortlist.single.rankHint.panelLatencyMs, 42);
    expect(payload.smartConnect?.stickiness.preferredNodeCode, 'pl');
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
    expect(payload.configPayload, contains('"final": "proxy"'));
    expect(payload.configPayload, contains('"auto_detect_interface": true'));
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
      'POST /api/client/nodes/latency-samples',
    ]);
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
        'app_version': '1.0.0-beta.3',
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
        'app_version': '1.0.0-beta.3',
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
                  'bonus_days': 10,
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
                  'premium_days': 10,
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
    expect(status.bonusDays, 10);
    expect(claim.ok, isTrue);
    expect(claim.premiumDays, 10);
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
                  'slots': <Object?>[
                    <String, Object?>{
                      'slot_id': 'rewards_top',
                      'content_id': 'telegram_bonus',
                      'enabled': true,
                      'title': 'Telegram +10 days',
                      'body': 'Connect Telegram and claim the reward.',
                      'image_url': 'https://cdn.example.com/promo.png',
                      'cta_label': 'Open',
                      'cta_href': 'https://t.me/pokrov_vpnbot',
                      'placement': 'home_banner',
                      'dismissible': false,
                      'starts_at': '2026-06-01T00:00:00Z',
                      'ends_at': '2026-06-30T00:00:00Z',
                      'kind': 'bonus',
                      'goal': 'bonus_claim',
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

    final summary = await bootstrapper.fetchBonusSummary(
      hostPlatform: HostPlatform.windows,
    );

    expect(summary.referralCount, 2);
    expect(summary.referralCode, 'POKROV2');
    expect(summary.referralBonusDays, 10);
    expect(summary.streakMonths, 3);
    expect(summary.channelBonusClaimed, isTrue);
    expect(summary.channelBonusPremiumDays, 10);
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
    expect(summary.historyItems.first.kind, 'promo');
    expect(summary.historyItems.first.days, 7);
    expect(summary.historyItems.first.codePreview, '...DAYS');
    expect(summary.referralSummary.code, 'POKROV2');
    expect(summary.referralSummary.link,
        'https://t.me/pokrov_vpnbot?start=ref_POKROV2');
    expect(summary.referralSummary.bonusDays, 10);
    expect(summary.referralSummary.tierKey, 'starter');
    expect(summary.promoSlots.remoteAvailable, isTrue);
    expect(summary.promoSlots.visibleSlots, hasLength(1));
    expect(summary.promoSlots.visibleSlots.single.title, 'Telegram +10 days');
    expect(summary.promoSlots.visibleSlots.single.imageUrl,
        'https://cdn.example.com/promo.png');
    expect(summary.promoSlots.visibleSlots.single.placement, 'home_banner');
    expect(summary.promoSlots.visibleSlots.single.dismissible, isFalse);
    expect(summary.promoSlots.visibleForPlacement('home_banner'), hasLength(1));
    expect(
      summary.promoSlots.visibleSlots.single.ctaHref,
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

  test('retries a temporary 502 during start-trial and then succeeds',
      () async {
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
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          startTrialAttempts += 1;
          if (startTrialAttempts == 1) {
            request.response
              ..statusCode = HttpStatus.badGateway
              ..headers.contentType = ContentType.text
              ..write('temporary upstream outage');
            await request.response.close();
            continue;
          }
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-2',
                    'account_id': '84',
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

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );

    expect(startTrialAttempts, 2);
    expect(payload.profileName, 'pokrov-android-rev-retry');
    expect(payload.configPayload, contains('"type": "tun"'));
    expect(payload.configPayload, contains('"override_android_vpn": true'));
    expect(payload.configPayload, contains('"final": "proxy"'));
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
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final inbounds = (config['inbounds'] as List).cast<Map<String, dynamic>>();
    final route = config['route'] as Map<String, dynamic>;

    expect(inbounds, isNotEmpty);
    expect(inbounds.first['type'], 'tun');
    expect(config.containsKey('_meta'), isFalse);
    expect(route['final'], 'select');
    expect(route['auto_detect_interface'], true);
    expect(config['outbounds'].toString(), contains('urltest'));
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
    expect(route['auto_detect_interface'], true);
    expect(route['override_android_vpn'], true);
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
      servers.any((server) => server['address'] == 'local'),
      isTrue,
    );
    expect(
      dnsRules.any((rule) =>
          (rule['domain'] as List?)?.contains('nl.kiwunaka.space') ?? false),
      isTrue,
    );
    expect(
      rules.any((rule) => rule['port'] == 53 && rule['outbound'] == 'dns-out'),
      isTrue,
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
    expect(payload.configPayload, contains('"override_android_vpn": true'));
    expect(payload.configPayload, contains('"auto_detect_interface": true'));
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
      inbounds
          .singleWhere((inbound) => inbound['type'] == 'tun')['inet6_address'],
      isNotNull,
    );
    expect(
      inbounds.singleWhere(
          (inbound) => inbound['type'] == 'tun')['domain_strategy'],
      'prefer_ipv4',
    );
    expect(servers.map((server) => server['address']), contains('local'));
    expect(
      servers.map((server) => server['address']),
      contains('1.1.1.1'),
    );
    expect(
      servers.map((server) => server['address']),
      contains('1.1.1.1'),
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
    expect(serverDomainRule['server'], isNot('local'));
    expect(ipPrivateRule['server'], isNot(serverDomainRule['server']));
    expect(route['final'], 'proxy');
    expect(rules.where((rule) => rule['protocol'] == 'dns'), isNotEmpty);
    expect(rules.where((rule) => rule['port'] == 53), isNotEmpty);
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
    expect(route['auto_detect_interface'], true);
    expect(route['override_android_vpn'], true);
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
    expect(route['auto_detect_interface'], true);
    expect(route['override_android_vpn'], true);
    expect(route['final'], 'proxy');
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
    expect(config['route'], containsPair('final', 'proxy'));
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
          expect(decoded['route_mode'], 'selected_apps');
          expect(decoded['selected_apps'], <String>[
            'Telegram.exe',
            'msedge',
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
                          'address': '8.8.8.8',
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
    expect(finalServer['address'], '1.1.1.1');
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
    );

    final catalog = await bootstrapper.fetchLocationsCatalog(
      hostPlatform: HostPlatform.windows,
      query: 'ams',
    );
    expect(catalog.auto.currentCode, 'nl-ams-01');
    expect(catalog.countries.single.cities.single.city, 'Amsterdam');
    expect(catalog.countries.single.cities.single.premium, isTrue);

    final subscription = await bootstrapper.fetchClientSubscription(
      hostPlatform: HostPlatform.windows,
    );
    expect(subscription.lane, 'trialPremium');
    expect(subscription.daysLeft, 5);
    expect(subscription.plans.single.id, '1m');

    final devices = await bootstrapper.fetchClientDevices(
      hostPlatform: HostPlatform.windows,
    );
    expect(devices.items.single.current, isTrue);

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
        'POST /api/client/push/register',
      ]),
    );
  });

  test('client support assistant uses app-session auth', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-client-assistant-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    Map<String, dynamic>? assistantBody;
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
          assistantBody = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'reply': 'Try reconnecting once, then send diagnostics.',
                  'assistantSessionId': 'session_1234567890abcdef',
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

    final reply = await bootstrapper.askSupportAssistant(
      hostPlatform: HostPlatform.windows,
      message: 'Connection is closed',
      ticketId: 77,
      assistantSessionId: 'session_abcdefghijklmnop',
      safeDiagnostics: const <String, Object?>{
        'phase': 'running',
        'warp_status': 'active',
      },
    );

    expect(reply.reply, contains('reconnecting'));
    expect(reply.assistantSessionId, 'session_1234567890abcdef');
    expect(reply.shouldEscalate, isFalse);
    expect(reply.suggestedActions.single.key, 'retry_connect');
    expect(assistantBody, containsPair('ticketId', 77));
    expect(assistantBody, containsPair('message', 'Connection is closed'));
    expect(
      assistantBody,
      containsPair('assistantSessionId', 'session_abcdefghijklmnop'),
    );
    expect(
      assistantBody?['safeDiagnostics'],
      containsPair('warp_status', 'active'),
    );
  });
}
