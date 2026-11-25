import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('detailed diagnostics retry after restart and opt-out clears pending reports', () async {
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final directory = await Directory.systemTemp.createTemp('pokrov-connect-stats-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
      HttpOverrides.global = previousOverrides;
    });
    const platform = HostPlatform.windows;
    final reports = <Map<String, dynamic>>[];
    var accepts = false;
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
            final report = jsonDecode(body) as Map<String, dynamic>;
            if (accepts) reports.add(report);
            request.response.statusCode = accepts ? HttpStatus.ok : HttpStatus.serviceUnavailable;
            request.response.write(accepts ? '{"ok":true}' : '{}');
          default:
            request.response.statusCode = 404;
        }
        await request.response.close();
      }
    }());
    final secrets = MemoryAppFirstSessionSecretStore();
    AppFirstRuntimeBootstrapper restart() => AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => directory,
      sessionSecretStore: secrets,
      delayScheduler: (_) async {},
    );
    final original = restart();
    await original.redeemCode(hostPlatform: platform, code: 'fixture-code');
    await original.connectionDiagnostics.start(platform, null);
    final attempt = original.connectionDiagnostics.beginAttempt(platform, 1)!;
    final outbox = File('${directory.path}/runtime-stats-outbox-windows.json');
    attempt.enter(ConnectionDiagnosticStage.profile);
    final until = DateTime.now().add(const Duration(seconds: 2));
    while (!await outbox.exists() && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    List<Map> pending() => (jsonDecode(outbox.readAsStringSync())['records'] as List)
        .map((record) => record['body'] as Map).toList();
    final early = pending().single;
    expect(early['runtime_phase'], 'connect_trace');
    expect((early['connection_trace']['points'] as List).single, containsPair('outcome', 'started'));
    expect(early['attempt_number'], 1);
    attempt.recordCandidate('de2', 'vless_reality',
      const SmartConnectCandidateProbeResult.failure('timeout', duration: Duration(milliseconds: 30),
        probeStage: 'tls_handshake'));
    attempt.enter(ConnectionDiagnosticStage.core);
    attempt.enter(ConnectionDiagnosticStage.egress);
    await attempt.finish('failed', errorCode: 'EGRESS-001');
    Map pendingDiagnostic() => pending().singleWhere((record) => record['runtime_phase'] == 'connect_diagnostic');
    final delayed = pendingDiagnostic();
    expect(delayed['connected'], isNull);
    expect(delayed['attempt_number'], 1);
    final recovering = restart();
    await recovering.connectionDiagnostics.start(platform, PreviousExitReport(
      kind: PreviousExitKind.crash, runId: 'diagnostic-test', occurredAtUtc: DateTime.now().toUtc(),
      errorCode: 'CRASH-001', crashSignature: '0123456789abcdef', breadcrumbs: const [],
    ));
    accepts = true;
    expect(await recovering.reportRuntimeStats(hostPlatform: platform,
      runtimePhase: 'app_opened', connected: false), isTrue);
    expect(reports.singleWhere((report) => report['runtime_phase'] == 'connect_diagnostic'), delayed);
    final trace = reports.where((report) => report['runtime_phase'] == 'connect_trace')
      .expand((report) => (report['connection_trace']['points'] as List).cast<Map>()).toList();
    expect(trace.where((point) => point['kind'] == 'candidate').single,
      allOf(containsPair('transport', 'vless_reality'), containsPair('stage', 'tls_handshake')));
    expect(trace.map((point) => point['sequence']).toSet().length, trace.length);
    expect(reports.singleWhere((report) => report['runtime_phase'] == 'exit_diagnostic')['exit_diagnostic'],
      containsPair('kind', 'dart_crash'));
    accepts = false;
    final second = recovering.connectionDiagnostics.beginAttempt(platform, 2)!;
    second.enter(ConnectionDiagnosticStage.profile);
    await second.finish('failed', errorCode: 'API-002');
    expect(pendingDiagnostic()['attempt_number'], 2);
    expect(pending().any((record) => record['runtime_phase'] == 'connect_trace'), isTrue);
    await recovering.connectionDiagnostics.setEnabled(platform, false);
    final disabled = restart().connectionDiagnostics;
    expect(await disabled.enabled(platform), isFalse);
    expect(disabled.beginAttempt(platform, 3), isNull);
    expect((jsonDecode(outbox.readAsStringSync()) as Map)['records'], isEmpty);
  });

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
    expect(limited.message, contains('отвяжи старое устройство'));
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
