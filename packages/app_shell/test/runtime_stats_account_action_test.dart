import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  test('account-action diagnostics survive the real runtime stats outbox', () async {
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final directory = await Directory.systemTemp.createTemp('pokrov-action-stats-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
      HttpOverrides.global = previousOverrides;
    });
    final reports = <Map<String, dynamic>>[];
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        switch (request.uri.path) {
          case '/api/client/session/start-trial':
            request.response.write(jsonEncode({'session': {
              'session_token': 'fixture-token', 'account_id': 'fixture-account'},
              'provisioning': {'status': 'ready', 'sync_ok': true}}));
          case '/api/redeem':
            request.response.write('{"ok":true,"kind":"promo","result":{}}');
          case '/api/client/runtime/stats':
            reports.add(jsonDecode(body) as Map<String, dynamic>);
            request.response.write('{"ok":true}');
          default:
            request.response.statusCode = 404;
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => directory,
      sessionSecretStore: MemoryAppFirstSessionSecretStore(),
    );
    await bootstrapper.redeemCode(hostPlatform: HostPlatform.windows, code: 'fixture-code');
    expect(await bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.windows, runtimePhase: 'failed', connected: false,
      errorCode: 'pairing_claim_failed', failureKind: 'request_timeout',
      failureOperation: 'device_pairing_claim',
    ), isTrue);
    final report = reports.single;
    expect(report['failure_kind'], 'request_timeout');
    expect(report['failure_operation'], 'device_pairing_claim');
    expect(report.containsKey('failure_http_status'), isFalse);
    expect(jsonEncode(report), isNot(contains('fixture-code')));
    expect(await bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.windows, runtimePhase: 'failed', connected: false,
      errorCode: 'redeem_failed', failureKind: 'unknown',
      failureOperation: 'redeem', failureHttpStatus: 410,
    ), isTrue);
    expect((reports.last['failure_operation'], reports.last['failure_http_status']), ('redeem', 410));
  });
}
