import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

class _PairingActions implements ManagedProfileBootstrapper, AppFirstAccountActionService {
  int claims = 0;

  @override
  Future<DevicePairingClaimResult> claimDevicePairingCode({
    required HostPlatform hostPlatform,
    required String code,
  }) async {
    claims++;
    throw const BootstrapFailure('Код истёк. Получите новый в кабинете.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
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
    expect(find.text('Код истёк. Получите новый в кабинете.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await links.close();
  });

  test('pairing continuation accepts only one bounded login code', () {
    final pairing = PokrovDevicePairingHandoff.tryParse(
      Uri.parse('pokrov://pair?code=ABCD-9XYZ'),
    );
    expect(pairing?.code, 'ABCD-9XYZ');
    for (final link in [
      'pokrov://pair?code=ABCD-9XYZ&code=EFGH-2345',
      'pokrov://pair?code=ABCD-9XYZ&session=untrusted',
      'pokrov://pair?code=invalid',
      'https://pair?code=ABCD-9XYZ',
      'pokrov://pair/another?code=ABCD-9XYZ',
      'pokrov://pair?code=ABCD-9XYZ#extra',
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
