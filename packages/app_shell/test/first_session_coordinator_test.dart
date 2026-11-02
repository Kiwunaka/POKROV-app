import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';

class _PairingActions implements ManagedProfileBootstrapper, AppFirstAccountActionService, AppFirstExperienceService {
  int claims = 0;
  int redeems = 0;
  bool reuseCurrentDevice = false;
  BootstrapFailure failure = const BootstrapFailure('Код истёк. Получи новый в кабинете.',
      statusCode: 504, operation: 'POST /api/client/device-pairing/claim',
      apiFailureKind: 'request_timeout');
  final reports = <Map<Symbol, dynamic>>[];
  String? requestedEmail;
  String? recoveredEmail;
  String? recoveryCode;
  BootstrapFailure? emailFailure;

  @override
  Future<void> requestEmailLoginCode({required HostPlatform hostPlatform, required String email}) async {
    requestedEmail = email;
  }

  @override
  Future<DevicePairingClaimResult> recoverEmailSession({
    required HostPlatform hostPlatform, required String email, required String code,
  }) async {
    if (emailFailure case final failure?) throw failure;
    recoveredEmail = email;
    recoveryCode = code;
    return const DevicePairingClaimResult(ok: true, accountId: 'fixture-account',
      installId: 'fixture-install', existingDevice: true);
  }

  @override
  Future<DevicePairingClaimResult> claimDevicePairingCode({
    required HostPlatform hostPlatform,
    required String code,
  }) async {
    claims++;
    if (reuseCurrentDevice) {
      return const DevicePairingClaimResult(ok: true, accountId: 'fixture-account',
          installId: 'fixture-install', existingDevice: true);
    }
    throw failure;
  }

  @override
  Future<AppFirstRedeemResult> redeemCode({required HostPlatform hostPlatform, required String code}) async {
    redeems++;
    throw failure;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #reportRuntimeStats) {
      reports.add(invocation.namedArguments);
      return Future<bool>.value(true);
    }
    throw UnimplementedError();
  }
}

class _MemoryFirstLaunchStore implements PokrovFirstLaunchStore {
  _MemoryFirstLaunchStore({this.completed = false, this.fail = false});

  bool completed;
  final bool fail;
  int writes = 0;

  @override
  Future<bool> isCompleted() async {
    if (fail) {
      throw StateError('read failed');
    }
    return completed;
  }

  @override
  Future<void> markCompleted() async {
    writes += 1;
    if (fail) {
      throw StateError('write failed');
    }
    completed = true;
  }
}

void main() {
  testWidgets('email recovery sheet completes the existing restore flow', (tester) async {
    final actions = _PairingActions();
    final store = _MemoryFirstLaunchStore();
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: actions, firstLaunchStore: store,
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('У меня есть код'));
    await tester.pump();
    final emailAction = find.text('Восстановить по почте');
    await tester.ensureVisible(emailAction);
    await tester.tap(emailAction);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byKey(const ValueKey('email-recovery-address')), 'account@example.invalid');
    final submit = find.byKey(const ValueKey('email-recovery-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(actions.requestedEmail, 'account@example.invalid');
    expect(actions.recoveredEmail, isNull);
    await tester.enterText(find.byKey(const ValueKey('email-recovery-code')), '123456');
    const requestId = '11111111-1111-4111-8111-111111111111';
    actions.emailFailure = const BootstrapFailure('Код из письма не подошёл. Запроси новый код.',
      statusCode: 401, code: 'email_otp_invalid', operation: 'POST /api/auth/email/otp/finish', requestId: requestId);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Код из письма не подошёл. Запроси новый код.'), findsOneWidget);
    final failed = actions.reports.lastWhere((args) => args[#errorCode] == 'email_login_failed');
    expect(failed[#failureOperation], 'email_otp_finish');
    expect(failed[#failureReason], PortalFailureReason.emailOtpInvalid);
    expect(failed[#failureRequestId], requestId);
    expect(failed.toString(), isNot(contains('account@example.invalid')));
    expect(failed.toString(), isNot(contains('123456')));
    actions.emailFailure = null;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(actions.recoveredEmail, 'account@example.invalid');
    expect(actions.recoveryCode, '123456');
    expect(store.completed, isTrue);
    expect(find.byKey(const ValueKey('first-launch-restore-screen')), findsNothing);
    expect(find.byKey(const ValueKey('email-recovery-code')), findsNothing);
    expect(find.byKey(const ValueKey('first-launch-gate-exited')), findsOneWidget);
    expect(actions.claims, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cold and running pairing links wait for explicit code submission', (tester) async {
    final actions = _PairingActions();
    final links = StreamController<Uri>.broadcast();
    final link = Uri.parse('pokrov://pair?code=ABCD-9XYZ');
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: actions,
      firstLaunchStore: _MemoryFirstLaunchStore(),
      initialAcquisitionUri: link,
      acquisitionUriStream: links.stream,
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final field = find.byKey(const ValueKey('profile-redeem-code-field'));
    expect(tester.widget<TextField>(field).controller?.text, 'ABCD-9XYZ');
    expect(actions.claims, 0);
    links.add(link);
    await tester.pump();
    expect(field, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(actions.claims, 0);
    links.add(link);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.pump();
    expect(actions.claims, 1);
    expect(find.text('Код истёк. Получи новый в кабинете.'), findsOneWidget);
    final report = actions.reports.lastWhere((args) => args[#errorCode] == 'pairing_claim_failed');
    expect(report[#failureKind], 'request_timeout');
    expect(report[#failureOperation], 'device_pairing_claim');
    expect(report[#failureHttpStatus], isNull);
    expect(connectionFailureOperations, containsAll(['device_pairing_claim', 'redeem']));
    actions.failure = const BootstrapFailure('local session unavailable', statusCode: 401);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    links.add(link);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.pump();
    final localReport = actions.reports.lastWhere((args) => args[#errorCode] == 'pairing_claim_failed');
    expect(localReport[#failureOperation], isNull);
    expect(localReport[#failureHttpStatus], isNull);
    actions.failure = const BootstrapFailure('private response text', statusCode: 410,
        operation: 'POST /api/redeem', code: 'private_server_reason');
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    links.add(link);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(field, 'POKROV-ACCESS-TEST');
    await tester.ensureVisible(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.pump();
    final redeemReport = actions.reports.lastWhere((args) => args[#errorCode] == 'redeem_failed');
    expect(actions.redeems, 1);
    expect(redeemReport[#failureOperation], 'redeem');
    expect(redeemReport[#failureHttpStatus], 410);
    expect(redeemReport[#failureReason], isNull);
    expect(redeemReport.toString(), isNot(contains('private_server_reason')));
    expect(redeemReport.toString(), isNot(contains('private response text')));
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    actions.reuseCurrentDevice = true;
    links.add(link);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.pump();
    expect(actions.claims, 3);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Вход подтверждён. Устройство уже связано с этим аккаунтом.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await links.close();
  });

  test('pairing continuation accepts only one bounded login code', () {
    for (final path in ['', '/']) {
      final pairing = PokrovDevicePairingHandoff.tryParse(
        Uri.parse('pokrov://pair$path?code=ABCD-9XYZ'),
      );
      expect(pairing?.code, 'ABCD-9XYZ');
    }
    for (final link in [
      'pokrov://pair?code=ABCD-9XYZ&code=EFGH-2345',
      'pokrov://pair?code=ABCD-9XYZ&session=untrusted',
      'pokrov://pair/?code=ABCD-9XYZ&session=untrusted',
      'pokrov://pair?code=invalid',
      'https://pair?code=ABCD-9XYZ',
      'pokrov://pair/another?code=ABCD-9XYZ',
      'pokrov://pair//?code=ABCD-9XYZ',
      'pokrov://other@pair/?code=ABCD-9XYZ',
      'pokrov://pair:42/?code=ABCD-9XYZ',
      'pokrov://pair?code=ABCD-9XYZ#extra',
      'pokrov://pair/?code=ABCD-9XYZ#extra',
    ]) {
      expect(PokrovDevicePairingHandoff.tryParse(Uri.parse(link)), isNull);
    }
  });

  test('persisted completion silently restores the ready state', () async {
    final coordinator = FirstSessionCoordinator(
      store: _MemoryFirstLaunchStore(completed: true),
    );

    expect(await coordinator.loadPersistedCompletion(), isTrue);
    expect(coordinator.isReady, isTrue);
    expect(coordinator.exitAnimated, isFalse);
    expect(coordinator.markAuthenticatedAppOpenSeen(), isFalse);
    expect(coordinator.markFirstHomeSeen(), isFalse);
  });

  test('restore lifecycle owns choice busy failure and shared handover',
      () async {
    final store = _MemoryFirstLaunchStore();
    final coordinator = FirstSessionCoordinator(store: store);

    expect(coordinator.isChoice, isTrue);
    coordinator.openRestore();
    expect(coordinator.isRestore, isTrue);

    expect(coordinator.beginRestore(), isTrue);
    expect(coordinator.beginRestore(), isFalse);
    coordinator.backToChoice();
    expect(coordinator.isRestore, isTrue,
        reason: 'busy restore cannot navigate');

    coordinator.finishRestore(succeeded: false);
    expect(coordinator.busy, isFalse);
    expect(coordinator.isRestore, isTrue);

    expect(coordinator.beginRestore(), isTrue);
    coordinator.finishRestore(succeeded: true);
    await coordinator.persistCompletion();
    expect(coordinator.isReady, isTrue);
    expect(coordinator.exitAnimated, isTrue);
    expect(store.completed, isTrue);
    expect(store.writes, 1);
  });

  test('persistence failure never blocks first-session completion', () async {
    final coordinator = FirstSessionCoordinator(
      store: _MemoryFirstLaunchStore(fail: true),
    );

    expect(await coordinator.loadPersistedCompletion(), isFalse);
    await expectLater(coordinator.persistCompletion(), completes);
    coordinator.complete(animated: true);
    expect(coordinator.isReady, isTrue);
  });

  test('trial and existing-access selections share one gate owner', () {
    final trial = FirstSessionCoordinator(store: _MemoryFirstLaunchStore());
    expect(trial.selectTrial(), isTrue);
    expect(trial.isReady, isTrue);

    final restore = FirstSessionCoordinator(store: _MemoryFirstLaunchStore());
    expect(restore.selectExistingAccess(), isTrue);
    expect(restore.isRestore, isTrue);
    expect(restore.beginRestore(), isTrue);
    expect(restore.selectTrial(), isFalse,
        reason: 'an active restore cannot be replaced by a second access path');
  });

  test('acquisition is ephemeral deduplicated and never blocks access choice',
      () {
    final coordinator =
        FirstSessionCoordinator(store: _MemoryFirstLaunchStore());

    expect(coordinator.beginAcquisition('opaque-handle'), isTrue);
    expect(
        coordinator.acquisitionState, FirstSessionAcquisitionState.consuming);
    expect(coordinator.selectTrial(), isTrue,
        reason: 'attribution must not hold the access gate');
    coordinator.finishAcquisition(succeeded: false);
    expect(coordinator.acquisitionState, FirstSessionAcquisitionState.failed);
    expect(coordinator.beginAcquisition('opaque-handle'), isFalse,
        reason: 'the same opaque handoff is consumed at most once per process');
  });

  test('invalid acquisition leaves restore available', () {
    final coordinator =
        FirstSessionCoordinator(store: _MemoryFirstLaunchStore());

    expect(coordinator.rejectInvalidAcquisition(), isTrue);
    expect(coordinator.acquisitionState, FirstSessionAcquisitionState.failed);
    expect(coordinator.selectExistingAccess(), isTrue);
    expect(coordinator.isRestore, isTrue);
  });

  test('VPN permission explanation has denied recovery and verified finish',
      () {
    final coordinator =
        FirstSessionCoordinator(store: _MemoryFirstLaunchStore());

    expect(coordinator.beginVpnPermissionExplanation(), isTrue);
    expect(coordinator.beginVpnPermissionRequest(), isTrue);
    coordinator.finishVpnPermissionRequest(granted: false, denied: true);
    expect(coordinator.vpnPermissionDenied, isTrue);

    expect(coordinator.beginVpnPermissionExplanation(), isTrue,
        reason: 'denial must return to a recoverable explainer');
    expect(coordinator.beginVpnPermissionRequest(), isTrue);
    coordinator.finishVpnPermissionRequest(granted: true, denied: false);
    expect(
        coordinator.vpnPermissionState, FirstSessionVpnPermissionState.granted);
    expect(coordinator.beginVpnPermissionExplanation(), isFalse);
  });

  test('first home and verified-connect milestones are idempotent', () {
    final coordinator =
        FirstSessionCoordinator(store: _MemoryFirstLaunchStore());

    expect(coordinator.markFirstHomeSeen(), isTrue);
    expect(coordinator.markFirstHomeSeen(), isFalse);
    expect(coordinator.markAuthenticatedAppOpenSeen(), isTrue);
    expect(coordinator.markAuthenticatedAppOpenSeen(), isFalse);
    expect(coordinator.markFirstVerifiedConnectSeen(), isTrue);
    expect(coordinator.markFirstVerifiedConnectSeen(), isFalse);
  });
}
