import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  testWidgets('device actions show failures and remain retryable', (tester) async {
    final client = _DeviceClient();
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: client,
      firstLaunchStore: _CompletedFirstLaunch(),
      clientExperienceStore: _MemoryExperience(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Доступ').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Устройства'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Не удалось загрузить устройства.'), findsOneWidget);
    expect(find.text('Пока нет других устройств.'), findsNothing);
    client.failFetch = false;
    await tester.tap(find.byKey(const ValueKey('profile-devices-retry')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Other device'), findsOneWidget);

    final revoke = find.byKey(const ValueKey('profile-device-revoke-other'));
    await tester.ensureVisible(revoke);
    await tester.tap(revoke);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('profile-device-revoke-approve')));
    await tester.pump();
    expect(find.text('Не удалось отвязать устройство. Попробуйте еще раз.'), findsOneWidget);
    expect(revoke, findsOneWidget);

    final issue = find.byKey(const ValueKey('profile-device-pairing-issue'));
    await tester.ensureVisible(issue);
    await tester.tap(issue);
    await tester.pump();
    final cancel = find.byKey(const ValueKey('profile-device-pairing-cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();
    expect(find.text('Не удалось отменить код устройства.'), findsOneWidget);
    expect(cancel, findsOneWidget);
    client.failCancel = false;
    await tester.tap(cancel);
    await tester.pump();
    expect(find.byKey(const ValueKey('profile-device-pairing-issue')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _DeviceClient implements ManagedProfileBootstrapper, AppFirstClientDataService {
  bool failFetch = true;
  bool failCancel = true;

  @override
  Future<ClientDeviceList> fetchClientDevices({required HostPlatform hostPlatform}) async {
    if (failFetch) throw StateError('offline');
    return const ClientDeviceList(items: [
      ClientDeviceInfo(id: 'other', label: 'Other device', platform: 'android', lastSeen: '', current: false),
    ]);
  }

  @override
  Future<bool> revokeClientDevice({required HostPlatform hostPlatform, required String deviceId}) async {
    throw StateError('offline');
  }

  @override
  Future<ClientDevicePairingCode> issueDevicePairingCode({required HostPlatform hostPlatform}) async =>
      const ClientDevicePairingCode(id: 'pair', code: 'ABCD-9XYZ', pairingUri: '', expiresAt: '', ttlSeconds: 600);

  @override
  Future<bool> cancelDevicePairingCode({required HostPlatform hostPlatform, required String pairingId}) async {
    if (failCancel) throw StateError('offline');
    return true;
  }

  @override
  Future<ClientNotificationInbox> fetchClientNotifications({required HostPlatform hostPlatform, String after = ''}) async =>
      const ClientNotificationInbox(items: [], nextCursor: '', unreadCount: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _CompletedFirstLaunch implements PokrovFirstLaunchStore {
  @override
  Future<bool> isCompleted() async => true;
  @override
  Future<void> markCompleted() async {}
}

class _MemoryExperience implements PokrovClientExperienceStore {
  @override
  Future<PokrovClientExperienceState> read() async => const PokrovClientExperienceState.empty();
  @override
  Future<void> write(PokrovClientExperienceState state) async {}
}
