import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';
import 'package:pokrov_app_shell/src/shell/managed_profile_cache.dart';

class _CountingCache extends ManagedProfileCache {
  int clears = 0;
  @override
  Future<void> clear(String platform) async { clears += 1; }
}

class _Fixture {
  _Fixture(this.directory, this.server);
  final Directory directory;
  final HttpServer server;
  final secrets = MemoryAppFirstSessionSecretStore();
  final cache = _CountingCache();
  final entered = Completer<void>();
  final release = Completer<void>();
  final authorized = <String>[];
  String pausedPath = '/api/client/session/start-trial';
  bool expiredReply = false;
  bool rejectInitialAccess = false;
  bool rejectRefresh = false;
  int starts = 0;
  int refreshes = 0;
  static const install = 'synthetic-install';
  File get file => File('${directory.path}/app-first-session-windows.json');
  late final bootstrapper = AppFirstRuntimeBootstrapper(
    apiBaseUrl: 'http://127.0.0.1:${server.port}/',
    supportDirectoryResolver: () async => directory,
    sessionSecretStore: secrets,
    managedProfileCache: cache,
    deviceNameResolver: (_) async => 'Synthetic device',
    maxRequestAttempts: 1,
    requestTimeout: const Duration(seconds: 5),
  );

  static Future<_Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp('pokrov-session-fence-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _Fixture(directory, server);
    server.listen((request) { unawaited(fixture.handle(request)); });
    addTearDown(() async {
      if (!fixture.release.isCompleted) fixture.release.complete();
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    await fixture.state('', '');
    return fixture;
  }

  Future<void> state(String account, String access,
      {String? refresh, bool loggedOut = false}) async {
    if (access.isEmpty) {
      await secrets.deleteSessionToken(hostPlatform: HostPlatform.windows, installId: install);
    } else {
      await secrets.writeSessionPair(
        hostPlatform: HostPlatform.windows, installId: install,
        pair: AppFirstSessionCredentials(accessToken: access, refreshToken: refresh ?? '$access-refresh'));
    }
    await file.writeAsString(jsonEncode({
      'version': 1, 'install_id': install, 'account_id': account,
      if (access.isNotEmpty || loggedOut) 'session_token_storage': 'secure',
      'managed_manifest_path': '/api/client/profile/managed',
      'profile_revision': 'profile-$account',
    }));
  }

  Future<void> handle(HttpRequest request) async {
    await utf8.decoder.bind(request).join();
    final path = request.uri.path;
    final authorization = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (path == '/api/client/subscription') authorized.add(authorization);
    if (path == pausedPath && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    request.response.headers.contentType = ContentType.json;
    if (path == '/api/client/session/start-trial') {
      starts += 1;
      request.response.write(jsonEncode({'session': {
        'access_token': 'trial-access', 'refresh_token': 'trial-refresh', 'account_id': 'A'},
        'provisioning': {'status': 'ready', 'sync_ok': true}}));
    } else if (path == '/api/client/session/refresh') {
      refreshes += 1;
      if (rejectRefresh) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write('{"detail":"synthetic_expired"}');
      } else {
        request.response.write(jsonEncode({'session': {
          'access_token': 'renewed-access', 'refresh_token': 'renewed-refresh', 'account_id': 'A'}}));
      }
    } else if (path == '/api/client/subscription') {
      if (rejectInitialAccess && authorization == 'Bearer old-access') {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write('{"detail":"synthetic_expired"}');
      } else {
        request.response.write(jsonEncode({
          'lane': expiredReply ? 'expiredOrBlocked' : 'paid',
          'access_state': expiredReply ? 'expired' : 'paid_unlimited',
          'days_left': 30,
        }));
      }
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('{}');
    }
    await request.response.close();
  }

  Future<void> expectState(String account, String access) async {
    final state = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(state['account_id'], account);
    final pair = await secrets.readSessionPair(hostPlatform: HostPlatform.windows, installId: install);
    expect(pair?.accessToken ?? '', access);
  }

  Future<void> wait() => entered.future.timeout(const Duration(seconds: 5));
  Future<ClientSubscriptionInfo> fetch() => bootstrapper.fetchClientSubscription(hostPlatform: HostPlatform.windows);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);
  });
  final changed = isA<BootstrapFailure>().having((e) => e.code, 'code', 'session_changed');

  test('late trial cannot replace a newer account', () async {
    final f = await _Fixture.create();
    final pending = f.fetch();
    final assertion = expectLater(pending, throwsA(changed));
    await f.wait();
    await f.state('B', 'B-access');
    f.release.complete();
    await assertion;
    await f.expectState('B', 'B-access');
    expect(f.authorized, isEmpty);
  });

  test('late trial retains the same-account winner without replacing its pair', () async {
    final f = await _Fixture.create();
    final pending = f.fetch();
    await f.wait();
    await f.state('A', 'winning-access');
    f.release.complete();
    expect((await pending).lane, 'paid');
    await f.expectState('A', 'winning-access');
    expect(f.authorized, ['Bearer winning-access']);
  });

  test('late subscription denial does not clear the new account cache', () async {
    final f = await _Fixture.create();
    f.pausedPath = '/api/client/subscription';
    f.expiredReply = true;
    await f.state('A', 'old-access');
    final pending = f.fetch();
    final assertion = expectLater(pending, throwsA(changed));
    await f.wait();
    await f.state('B', 'B-access');
    f.release.complete();
    await assertion;
    await f.expectState('B', 'B-access');
    expect(f.cache.clears, 0);
  });

  test('failed old refresh cannot retry an account request with a new account token', () async {
    final f = await _Fixture.create();
    f.pausedPath = '/api/client/session/refresh';
    f.rejectInitialAccess = true;
    f.rejectRefresh = true;
    await f.state('A', 'old-access');
    final pending = f.fetch();
    final assertion = expectLater(pending, throwsA(changed));
    await f.wait();
    await f.state('B', 'B-access');
    f.release.complete();
    await assertion;
    await f.expectState('B', 'B-access');
    expect(f.authorized, ['Bearer old-access']);
  });

  test('concurrent refresh rotation retains complete same-account state', () async {
    final f = await _Fixture.create();
    f.pausedPath = '/api/client/session/refresh';
    f.rejectInitialAccess = true;
    f.rejectRefresh = true;
    await f.state('A', 'old-access');
    final pending = f.fetch();
    await f.wait();
    await f.state('A', 'rotated-access');
    f.release.complete();
    expect((await pending).lane, 'paid');
    await f.expectState('A', 'rotated-access');
    expect(f.authorized, ['Bearer old-access', 'Bearer rotated-access']);
  });

  test('late successful refresh cannot restore a logged-out session', () async {
    final f = await _Fixture.create();
    f.pausedPath = '/api/client/session/refresh';
    f.rejectInitialAccess = true;
    await f.state('A', 'old-access');
    final pending = f.fetch();
    final assertion = expectLater(pending, throwsA(isA<BootstrapFailure>()));
    await f.wait();
    await f.state('A', '', loggedOut: true);
    f.release.complete();
    await assertion;
    await f.expectState('A', '');
  });

  test('ordinary initial trial still returns the subscription', () async {
    final f = await _Fixture.create();
    f.release.complete();
    expect((await f.fetch()).lane, 'paid');
    await f.expectState('A', 'trial-access');
    expect(f.starts, 1);
  });

  test('ordinary expired session refresh does not create a second trial', () async {
    final f = await _Fixture.create();
    f.pausedPath = '/api/client/session/refresh';
    f.rejectInitialAccess = true;
    f.release.complete();
    await f.state('A', 'old-access');
    expect((await f.fetch()).lane, 'paid');
    await f.expectState('A', 'renewed-access');
    expect(f.starts, 0);
    expect(f.refreshes, 1);
  });
}
