import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

void main() {
  test('account session owns access and subscription state independently', () {
    final coordinator = AccountSessionCoordinator(accountActions: null);
    const access = FreeProfileAccess(
      accessState: 'trial_premium',
      transition: FreeProfileTransition.standard,
      activeRole: 'premium',
      softModeActive: false,
      provisioningJobId: null,
      errorCode: null,
      isConsistent: true,
    );
    final subscription = ClientSubscriptionInfo(
      lane: 'trialPremium',
      expiresAt: '2026-08-29T12:00:00Z',
      daysLeft: 7,
      autoRenew: false,
      renewUrl: Uri.parse('https://pay.pokrov.space/checkout/'),
      plans: const [],
      trafficPolicy: const {'kind': 'unlimited'},
    );

    coordinator.updateFreeProfileAccess(access);
    coordinator.updateSubscriptionInfo(subscription);

    expect(coordinator.accountActions, isNull);
    expect(coordinator.freeProfileAccess, same(access));
    expect(coordinator.subscriptionInfo, same(subscription));

    coordinator.clearSubscriptionInfo();
    expect(coordinator.subscriptionInfo, isNull);
    expect(coordinator.freeProfileAccess, same(access));
  });
}
