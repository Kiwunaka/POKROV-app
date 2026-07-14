part of pokrov_app_shell;

String _accessPoolLabel(AccessLane lane) {
  return switch (lane) {
    AccessLane.trialPremium ||
    AccessLane.bonusPremium ||
    AccessLane.paidUnlimited =>
      'Премиум-доступ',
    AccessLane.freeMonthly || AccessLane.freeSoftMode => 'Базовый доступ',
  };
}

String _accessMainLabel(
    SeedAppContext appContext, AppFirstBonusSummary? bonus) {
  final baseDays = appContext.runtimeProfile.trialDays;
  final bonusDays = bonus?.channelBonusPremiumDays ?? 0;
  final claimed = (bonus?.channelBonusClaimedAt ?? '').trim().isNotEmpty;
  final totalDays = baseDays + (claimed ? bonusDays : 0);
  return switch (appContext.accessLane) {
    AccessLane.trialPremium => claimed
        ? '${ruDays(totalDays)} доступа'
        : '${ruDays(baseDays)} пробного доступа',
    AccessLane.bonusPremium => '${ruDays(totalDays)} доступа',
    AccessLane.paidUnlimited => 'Премиум активен',
    AccessLane.freeMonthly => 'Базовый режим',
    AccessLane.freeSoftMode => 'Лимит закончился',
  };
}

String _accessShortValue(
  SeedAppContext appContext,
  AppFirstBonusSummary? bonus,
) {
  final baseDays = appContext.runtimeProfile.trialDays;
  final bonusDays = bonus?.channelBonusPremiumDays ?? 0;
  final claimed = (bonus?.channelBonusClaimedAt ?? '').trim().isNotEmpty;
  final totalDays = baseDays + (claimed ? bonusDays : 0);
  return switch (appContext.accessLane) {
    AccessLane.trialPremium => claimed ? ruDays(totalDays) : ruDays(baseDays),
    AccessLane.bonusPremium => ruDays(totalDays),
    AccessLane.paidUnlimited => 'Премиум',
    AccessLane.freeMonthly => 'Базовый',
    AccessLane.freeSoftMode => 'Лимит',
  };
}

/// Numeric twin of [_accessShortValue] for lanes whose value is a day count;
/// null for the label-only lanes so callers fall back to static text.
int? _accessShortDays(
  SeedAppContext appContext,
  AppFirstBonusSummary? bonus,
) {
  final baseDays = appContext.runtimeProfile.trialDays;
  final bonusDays = bonus?.channelBonusPremiumDays ?? 0;
  final claimed = (bonus?.channelBonusClaimedAt ?? '').trim().isNotEmpty;
  final totalDays = baseDays + (claimed ? bonusDays : 0);
  return switch (appContext.accessLane) {
    AccessLane.trialPremium => claimed ? totalDays : baseDays,
    AccessLane.bonusPremium => totalDays,
    AccessLane.paidUnlimited ||
    AccessLane.freeMonthly ||
    AccessLane.freeSoftMode =>
      null,
  };
}

String _telegramBonusHomeLabel(
  SeedAppContext appContext,
  AppFirstBonusSummary? bonus,
) {
  final claimed = (bonus?.channelBonusClaimedAt ?? '').trim().isNotEmpty;
  if (claimed) {
    return 'Telegram-бонус активен';
  }
  return '+${ruDays(appContext.runtimeProfile.telegramBonusDays)} за Telegram';
}
