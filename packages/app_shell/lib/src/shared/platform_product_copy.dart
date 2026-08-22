part of pokrov_app_shell;

/// Russian consumer copy for platform-owned numeric product facts.
///
/// Values come only from the generated digest-pinned projection. Server
/// responses remain authoritative whenever an account-specific value exists.
abstract final class _PlatformProductCopy {
  static String get trialDaysLabel => ruDays(PlatformProductFacts.trialDays);

  static String get telegramRewardLabel =>
      'Telegram +${ruDays(PlatformProductFacts.telegramRewardDays)}';

  static String get telegramRewardAvailableBeforePayment =>
      '$telegramRewardLabel доступен без оплаты';

  static String get telegramRewardPaidGateSummary =>
      '$telegramRewardLabel доступен сейчас · рулетка и приглашения после оплаты';

  static String get telegramRewardPaidGateMessage =>
      '$telegramRewardLabel доступен сейчас. Рулетка, календарь и приглашения откроются после первой оплаты.';

  static String get telegramRewardFallbackPaidGateMessage =>
      '$telegramRewardLabel доступен сейчас. Остальные бонусы откроются после первой оплаты.';
}
