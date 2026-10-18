part of pokrov_app_shell;

/// Russian consumer copy for platform-owned numeric product facts.
///
/// Values come only from the generated digest-pinned projection. Server
/// responses remain authoritative whenever an account-specific value exists.
abstract final class _PlatformProductCopy {
  static String get telegramRewardLabel =>
      'Telegram +${ruDays(PlatformProductFacts.telegramRewardDays)}';

  static String get telegramRewardAvailableBeforePayment =>
      '$telegramRewardLabel доступен без оплаты';

}
