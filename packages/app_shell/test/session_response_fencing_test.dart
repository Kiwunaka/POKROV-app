import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_app_shell/src/shell/managed_profile_cache.dart';

class _CountingCache extends ManagedProfileCache {
  int clears = 0;
  @override
  Future<void> clear(String platform) async {
    clears += 1;
  }
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
  bool rejectInitialBonusAccess = false;
  String initialBonusAccess = 'A-access';
  int rejectRefreshCount = 0;
  int rewards = 0;
  int starts = 0;
  int refreshes = 0;
  final emailRequests = <String>[];
  final recoveryInstalls = <String>[];
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
    final directory =
        await Directory.systemTemp.createTemp('pokrov-session-fence-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _Fixture(directory, server);
    server.listen((request) {
      unawaited(fixture.handle(request));
    });
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
      await secrets.deleteSessionToken(
          hostPlatform: HostPlatform.windows, installId: install);
    } else {
      await secrets.writeSessionPair(
          hostPlatform: HostPlatform.windows,
          installId: install,
          pair: AppFirstSessionCredentials(
              accessToken: access, refreshToken: refresh ?? '$access-refresh'));
    }
    await file.writeAsString(jsonEncode({
      'version': 1,
      'install_id': install,
      'account_id': account,
      if (access.isNotEmpty || loggedOut) 'session_token_storage': 'secure',
      'managed_manifest_path': '/api/client/profile/managed',
      'profile_revision': 'profile-$account',
    }));
  }

  Future<void> handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final path = request.uri.path;
    final authorization =
        request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (path == '/api/client/subscription') authorized.add(authorization);
    if (path == pausedPath && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    request.response.headers.contentType = ContentType.json;
    if (path == '/api/auth/email/otp/start') {
      expect(authorization, isEmpty);
      emailRequests.add((jsonDecode(body) as Map)['email'] as String);
      request.response.write('{"ok":true,"otp_requested":true}');
    } else if (path == '/api/auth/email/otp/finish') {
      expect(authorization, isEmpty);
      final payload = jsonDecode(body) as Map;
      expect(payload['email'], 'account@example.invalid');
      expect(payload['code'], '123456');
      recoveryInstalls.add(payload['install_id'] as String);
      request.response.write(jsonEncode({'ok': true, 'session': {
        'access_token': 'recovered-access', 'refresh_token': 'recovered-refresh',
        'account_id': 'A', 'canonical_account_id': 'A', 'scope': 'client',
      }}));
    } else if (path == '/api/client/session/start-trial') {
      starts += 1;
      request.response.write(jsonEncode({
        'session': {
          'access_token': 'trial-access',
          'refresh_token': 'trial-refresh',
          'account_id': 'A'
        },
        'provisioning': {'status': 'ready', 'sync_ok': true}
      }));
    } else if (path == '/api/client/session/refresh') {
      refreshes += 1;
      if (rejectRefresh || refreshes <= rejectRefreshCount) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write('{"detail":"synthetic_expired"}');
      } else {
        request.response.write(jsonEncode({
          'session': {
            'access_token': 'renewed-access',
            'refresh_token': 'renewed-refresh',
            'account_id': 'A'
          }
        }));
      }
    } else if (path == '/api/client/cabinet-token') {
      request.response.write(jsonEncode({
        'token': 'synthetic-A-handoff',
        'handoff_url': 'https://app.pokrov.space/?handoff=synthetic-A-handoff',
        'expires_in': 60,
        'target_path': '/',
        'scope': 'cabinet',
      }));
    } else if (path == '/api/client/device-pairing/claim') {
      request.response.write(jsonEncode({
        'ok': true,
        'canonical_account_id': 'B',
        'session': {
          'account_id': 'B',
          'access_token': 'B-paired-access',
          'refresh_token': 'B-paired-refresh',
        },
      }));
    } else if (path == '/api/client/telegram/link') {
      request.response.write(jsonEncode({
        'ok': true,
        'start_code': 'synthetic-A-link',
        'bot_url': 'https://t.me/pokrov_bot?start=synthetic-A-link',
      }));
    } else if (path == '/api/bonuses/summary') {
      if (rejectInitialBonusAccess && authorization == 'Bearer $initialBonusAccess') {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write('{"detail":"synthetic_expired"}');
      } else {
        request.response.write('{"referral_code":"synthetic-A-bonus"}');
      }
    } else if (path == '/api/bonuses/wheel/spin') {
      rewards += 1;
      request.response.write('{"ok":true,"reward_days":1}');
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
    final pair = await secrets.readSessionPair(
        hostPlatform: HostPlatform.windows, installId: install);
    expect(pair?.accessToken ?? '', access);
  }

  Future<void> wait() => entered.future.timeout(const Duration(seconds: 5));
  Future<ClientSubscriptionInfo> fetch() =>
      bootstrapper.fetchClientSubscription(hostPlatform: HostPlatform.windows);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);
  });
  final changed =
      isA<BootstrapFailure>().having((e) => e.code, 'code', 'session_changed');

  test('late cabinet handoff cannot open the previous account', () async {
    final f = await _Fixture.create();
    f.pausedPath = '/api/client/cabinet-token';
    await f.state('A', 'A-access');
    final pending = f.bootstrapper.createCabinetHandoff(
      hostPlatform: HostPlatform.windows);
    final assertion = expectLater(pending, throwsA(changed));
    await f.wait();
    await f.state('B', 'B-access');
    f.release.complete();
    await assertion;
    await f.expectState('B', 'B-access');
  });

  test('late Telegram link cannot link the previous account', () async {
    final f = await _Fixture.create();
    f.pausedPath = '/api/client/telegram/link';
    await f.state('A', 'A-access');
    final pending = f.bootstrapper.createTelegramLink(
      hostPlatform: HostPlatform.windows);
    final assertion = expectLater(pending, throwsA(changed));
    await f.wait();
    await f.state('B', 'B-access');
    f.release.complete();
    await assertion;
    await f.expectState('B', 'B-access');
  });

  test('late bonus history cannot publish the previous account summary', () async {
    final f = await _Fixture.create();
    f.pausedPath = '/api/bonuses/history';
    await f.state('A', 'A-access');
    final pending = f.bootstrapper.fetchBonusSummary(
      hostPlatform: HostPlatform.windows);
    final assertion = expectLater(pending, throwsA(changed));
    await f.wait();
    await f.state('B', 'B-access');
    f.release.complete();
    await assertion;
    await f.expectState('B', 'B-access');
  });

  test('accepted reward is not repeated when its summary rejects refresh', () async {
    final f = await _Fixture.create();
    await f.state('A', 'A-access');
    f.rejectInitialBonusAccess = true;
    f.rejectRefreshCount = 1;

    final result = await f.bootstrapper.spinBonusWheel(hostPlatform: HostPlatform.windows);
    expect(f.rewards, 1);
    expect(f.refreshes, 1);
    expect(result.ok, isTrue);
    expect(result.rewardDays, 1);
    expect(result.summary, isNull);
  });

  test('current account links and reward survive a same-account summary refresh', () async {
    final f = await _Fixture.create();
    await f.state('A', 'A-access');
    final cabinet = await f.bootstrapper.createCabinetHandoff(
      hostPlatform: HostPlatform.windows);
    expect(cabinet.handoffUrl.queryParameters['handoff'], 'synthetic-A-handoff');
    final telegram = await f.bootstrapper.createTelegramLink(
      hostPlatform: HostPlatform.windows);
    expect(telegram.startCode, 'synthetic-A-link');

    f.rejectInitialBonusAccess = true;
    final reward = await f.bootstrapper.spinBonusWheel(
      hostPlatform: HostPlatform.windows);
    expect(reward.rewardDays, 1);
    expect(reward.summary?.referralCode, 'synthetic-A-bonus');
    expect(f.rewards, 1);
    expect(f.refreshes, 1);
    await f.expectState('A', 'renewed-access');
  });

  test('acknowledged reward permits authenticated canonical account migration', () async {
    final f = await _Fixture.create();
    final access = '${base64Url.encode(utf8.encode(jsonEncode({
      'id': 42, 'account_id': 'A',
      'session_id': 'synthetic-session', 'device_id': 'synthetic-device',
    })))}.fixture-signature';
    await f.state('42', access);
    f.initialBonusAccess = access;
    f.rejectInitialBonusAccess = true;

    final result = await f.bootstrapper.spinBonusWheel(
      hostPlatform: HostPlatform.windows);
    expect(result.ok, isTrue);
    expect(result.summary?.referralCode, 'synthetic-A-bonus');
    expect(f.rewards, 1);
    await f.expectState('A', 'renewed-access');
  });

  test('acknowledged reward cannot publish after another account signs in', () async {
    final f = await _Fixture.create();
    f.pausedPath = '/api/bonuses/history';
    await f.state('A', 'A-access');
    final pending = f.bootstrapper.spinBonusWheel(
      hostPlatform: HostPlatform.windows);
    final assertion = expectLater(pending, throwsA(changed));
    await f.wait();
    await f.state('B', 'B-access');
    f.release.complete();
    await assertion;
    expect(f.rewards, 1);
    await f.expectState('B', 'B-access');
  });

  test('failed pairing state write preserves the previous account session', () async {
    final f = await _Fixture.create();
    await f.state('A', 'A-access');
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${f.server.port}/',
      supportDirectoryResolver: () async => f.directory,
      sessionSecretStore: f.secrets,
      deviceNameResolver: (_) async => 'Synthetic device',
      stateFileWriter: (file, contents) async {
        if ((jsonDecode(contents) as Map)['account_id'] == 'B') {
          throw const FileSystemException('Synthetic state write failure');
        }
        await file.writeAsString(contents);
      },
      maxRequestAttempts: 1,
    );

    await expectLater(bootstrapper.claimDevicePairingCode(
      hostPlatform: HostPlatform.windows, code: 'ABCD-2345'),
      throwsA(isA<FileSystemException>()));
    await f.expectState('A', 'A-access');
    expect((await f.fetch()).lane, 'paid');
  });

  test('email OTP restores missing secure pair on the same install and fences old refresh', () async {
    final f = await _Fixture.create();
    f.pausedPath = '/api/client/session/refresh';
    f.rejectInitialAccess = true;
    await f.state('A', 'old-access');
    final pending = f.fetch();
    final assertion = expectLater(pending, throwsA(changed));
    await f.wait();
    await f.secrets.deleteSessionToken(
      hostPlatform: HostPlatform.windows, installId: _Fixture.install);

    await f.bootstrapper.requestEmailLoginCode(
      hostPlatform: HostPlatform.windows, email: 'account@example.invalid');
    final recovered = await f.bootstrapper.recoverEmailSession(
      hostPlatform: HostPlatform.windows, email: 'account@example.invalid', code: '123456');
    expect(recovered.installId, _Fixture.install);
    expect(f.emailRequests, ['account@example.invalid']);
    expect(f.recoveryInstalls, [_Fixture.install]);
    await f.expectState('A', 'recovered-access');
    f.release.complete();
    await assertion;
    await f.expectState('A', 'recovered-access');
    expect(f.starts, 0);
    expect((await f.fetch()).lane, 'paid');
  });

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

  test('late trial retains the same-account winner without replacing its pair',
      () async {
    final f = await _Fixture.create();
    final pending = f.fetch();
    await f.wait();
    await f.state('A', 'winning-access');
    f.release.complete();
    expect((await pending).lane, 'paid');
    await f.expectState('A', 'winning-access');
    expect(f.authorized, ['Bearer winning-access']);
  });

  test('late subscription denial does not clear the new account cache',
      () async {
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

  test(
      'failed old refresh cannot retry an account request with a new account token',
      () async {
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

  test('concurrent refresh rotation retains complete same-account state',
      () async {
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

  test('ordinary expired session refresh does not create a second trial',
      () async {
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
