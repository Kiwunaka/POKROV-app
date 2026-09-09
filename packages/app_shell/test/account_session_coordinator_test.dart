import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_app_shell/src/features/profile/account_session_coordinator.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

void main() {
  test('summary callers share an ordered flight and can refresh again',
      () async {
    final coordinator = AccountSessionCoordinator(accountActions: null);
    final subscription = Completer<bool>();
    final bonus = Completer<void>();
    final reads = <String>[];
    Future<void> refresh() => coordinator.refreshSummary(
          refreshSubscription: () {
            reads.add('subscription');
            return subscription.future;
          },
          refreshBonus: () {
            reads.add('bonus');
            return bonus.future;
          },
          refreshInbox: () async => reads.add('inbox'),
          isActive: () => true,
        );

    final first = refresh();
    final duplicate = refresh();
    expect(duplicate, same(first));
    expect(reads, ['subscription']);
    subscription.complete(false); // Handled refresh failure still allows reads.
    await Future<void>.delayed(Duration.zero);
    expect(reads, ['subscription', 'bonus']);
    expect(refresh(), same(first));
    bonus.complete();
    await Future.wait([first, duplicate]);
    expect(reads, ['subscription', 'bonus', 'inbox']);

    await refresh();
    expect(reads, [
      'subscription',
      'bonus',
      'inbox',
      'subscription',
      'bonus',
      'inbox',
    ]);
  });

  test('summary failure releases the shared flight for retry', () async {
    final coordinator = AccountSessionCoordinator(accountActions: null);
    final bonus = Completer<void>();
    var subscriptionReads = 0;
    var inboxReads = 0;
    var failBonus = true;
    Future<void> refresh() => coordinator.refreshSummary(
          refreshSubscription: () async {
            subscriptionReads++;
            return true;
          },
          refreshBonus: () => failBonus ? bonus.future : Future<void>.value(),
          refreshInbox: () async {
            inboxReads++;
          },
          isActive: () => true,
        );
    final first = refresh();
    final duplicate = refresh();
    final observed = expectLater(first, throwsStateError);
    expect(duplicate, same(first));
    bonus.completeError(StateError('synthetic failure'));
    await observed;
    expect(inboxReads, 0);

    failBonus = false;
    await refresh();
    expect(subscriptionReads, 2);
    expect(inboxReads, 1);
  });

  for (final closeAfter in ['subscription', 'bonus']) {
    test('summary stops after $closeAfter when shell becomes inactive',
        () async {
      final coordinator = AccountSessionCoordinator(accountActions: null);
      var active = true;
      final pending = Completer<void>();
      final reached = Completer<void>();
      final reads = <String>[];
      Future<void> read(String name) async {
        reads.add(name);
        if (name == closeAfter) {
          reached.complete();
          await pending.future;
        }
      }

      final flight = coordinator.refreshSummary(
        refreshSubscription: () async {
          await read('subscription');
          return true;
        },
        refreshBonus: () => read('bonus'),
        refreshInbox: () => read('inbox'),
        isActive: () => active,
      );
      await reached.future;
      active = false;
      pending.complete();
      await flight;
      expect(
          reads,
          closeAfter == 'subscription'
              ? ['subscription']
              : ['subscription', 'bonus']);
    });
  }

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
