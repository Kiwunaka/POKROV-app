import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart' hide TransportCandidate;
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
  @override
  Future<PokrovClientExperienceState> read() async =>
      const PokrovClientExperienceState.empty().copyWith(
          interfaceMode: PokrovInterfaceMode.advanced);
  @override
  Future<void> write(PokrovClientExperienceState state) async {}
}

class _NoConnectBootstrapper implements ManagedProfileBootstrapper {
  @override
  Never noSuchMethod(Invocation invocation) =>
      throw StateError('Home visibility must not request a managed profile');
}

void main() {
  testWidgets('restored Windows Home remains painted while inactive and after returning', (tester) async {
    final firstLaunch = _RestoredFirstLaunch();
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
      clientExperienceStore: _HomeExperience(),
    ));
    firstLaunch.completion.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    double homeOpacity() {
      final label = find.descendant(of: find.byKey(const ValueKey('home-boot-reveal')),
          matching: find.text('POKROV VPN'));
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
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(<String, String>{});
  });
  tearDown(() {
    FlutterSecureStoragePlatform.instance = defaultSecureStoragePlatform;
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
