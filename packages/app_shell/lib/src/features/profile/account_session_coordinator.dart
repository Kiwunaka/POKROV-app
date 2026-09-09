import 'package:pokrov_runtime_engine/runtime_engine.dart';

import '../../../app_first_runtime_bootstrap.dart';

/// Owns account actions, access/subscription state and ordered summary refresh.
/// Local routing, runtime truth and rendering remain outside this boundary.
class AccountSessionCoordinator {
  AccountSessionCoordinator({required this.accountActions});

  final AppFirstAccountActionService? accountActions;
  FreeProfileAccess? _freeProfileAccess;
  ClientSubscriptionInfo? _subscriptionInfo;
  Future<void>? _summaryRefresh;

  FreeProfileAccess? get freeProfileAccess => _freeProfileAccess;
  ClientSubscriptionInfo? get subscriptionInfo => _subscriptionInfo;

  void updateFreeProfileAccess(FreeProfileAccess? value) {
    _freeProfileAccess = value;
  }

  void updateSubscriptionInfo(ClientSubscriptionInfo? value) {
    _subscriptionInfo = value;
  }

  void clearSubscriptionInfo() {
    _subscriptionInfo = null;
  }

  Future<void> refreshSummary({
    required Future<bool> Function() refreshSubscription,
    required Future<void> Function() refreshBonus,
    required Future<void> Function() refreshInbox,
    required bool Function() isActive,
  }) {
    return _summaryRefresh ??= _loadSummary(
      refreshSubscription: refreshSubscription,
      refreshBonus: refreshBonus,
      refreshInbox: refreshInbox,
      isActive: isActive,
    ).whenComplete(() {
      _summaryRefresh = null;
    });
  }

  Future<void> _loadSummary({
    required Future<bool> Function() refreshSubscription,
    required Future<void> Function() refreshBonus,
    required Future<void> Function() refreshInbox,
    required bool Function() isActive,
  }) async {
    // These reads can refresh the same expired session. Preserve their order
    // to avoid competing account transactions during first launch.
    await refreshSubscription();
    if (isActive()) {
      await refreshBonus();
    }
    if (isActive()) {
      await refreshInbox();
    }
  }
}
