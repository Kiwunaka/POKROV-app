import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';

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
    var denialCode = 'device_limit_reached';
    var denialHeader = '';
    const requestId = '11111111-1111-4111-8111-111111111111';
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
          case '/api/client/device-pairing/claim':
            request.response.statusCode = 409;
            request.response.headers.set('X-Request-ID', requestId);
            if (denialHeader.isNotEmpty) request.response.headers.set('X-POKROV-Error', denialHeader);
            request.response.write(jsonEncode({'detail': {'code': denialCode,
              'message': 'Private server response must not enter diagnostics'}}));
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

    Future<BootstrapFailure> claimFailure() async {
      try {
        await bootstrapper.claimDevicePairingCode(hostPlatform: HostPlatform.windows, code: 'ABCD-9XYZ');
      } on BootstrapFailure catch (failure) {
        return failure;
      }
      throw StateError('the fixture must reject this claim');
    }
    final limited = await claimFailure();
    expect(limited.reason, PortalFailureReason.deviceLimitReached);
    expect(limited.operationalErrorCode, 'AUTH-004');
    expect(limited.message, contains('Лимит устройств исчерпан'));
    expect(limited.message, contains('отвяжите старое устройство'));
    expect(limited.requestId, requestId);
    expect(await bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.windows, runtimePhase: 'failed', connected: false,
      errorCode: 'pairing_claim_failed', failureOperation: 'device_pairing_claim',
      failureHttpStatus: limited.statusCode, failureReason: limited.reason,
      failureRequestId: limited.requestId,
    ), isTrue);
    expect(reports.last['failure_reason'], 'device_limit_reached');
    expect(reports.last['failure_request_id'], requestId);
    expect(jsonEncode(reports.last), isNot(contains('Private server response')));
    denialCode = 'pairing_code_used';
    final used = await claimFailure();
    expect(used.reason, PortalFailureReason.pairingCodeUsed);
    expect(used.message, contains('уже использован'));
    expect(used.message, isNot(contains('Лимит устройств')));
    denialHeader = 'access_key_revoked';
    final revoked = await claimFailure();
    expect(revoked.reason, PortalFailureReason.accessKeyRevoked);
    expect(revoked.message, contains('отозван'));
    denialHeader = 'active_access_required';
    final accessRequired = await claimFailure();
    expect(accessRequired.reason, PortalFailureReason.activeAccessRequired);
    expect(accessRequired.message, contains('нужен действующий доступ'));
    expect(accessRequired.message, isNot(contains('истёк')));
    expect(accessRequired.message, isNot(contains('заблокирован')));
    denialHeader = '';
    denialCode = 'private_unknown_reason';
    final unknown = await claimFailure();
    expect(unknown.reason, isNull);
    expect(unknown.message, contains('Код обращения: $requestId'));
    expect(await bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.windows, runtimePhase: 'failed', connected: false,
      errorCode: 'pairing_claim_failed', failureOperation: 'device_pairing_claim',
      failureHttpStatus: unknown.statusCode, failureReason: unknown.reason,
      failureRequestId: unknown.requestId,
    ), isTrue);
    expect(reports.last.containsKey('failure_reason'), isFalse);
    expect(reports.last['failure_request_id'], requestId);
    expect(jsonEncode(reports.last), isNot(contains('private_unknown_reason')));
    expect(await bootstrapper.reportRuntimeStats(
      hostPlatform: HostPlatform.windows, runtimePhase: 'failed', connected: false,
      errorCode: 'pairing_claim_failed', failureRequestId: 'private-invalid-id',
    ), isTrue);
    expect(reports.last.containsKey('failure_request_id'), isFalse);
  });
}
