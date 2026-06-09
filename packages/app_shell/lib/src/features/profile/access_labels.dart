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
    AccessLane.trialPremium =>
      claimed ? '$totalDays дней доступа' : '$baseDays дней пробного доступа',
    AccessLane.bonusPremium => '$totalDays дней доступа',
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
    AccessLane.trialPremium => claimed ? '$totalDays дней' : '$baseDays дней',
    AccessLane.bonusPremium => '$totalDays дней',
    AccessLane.paidUnlimited => 'Премиум',
    AccessLane.freeMonthly => 'Базовый',
    AccessLane.freeSoftMode => 'Лимит',
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
  return '+${appContext.runtimeProfile.telegramBonusDays} дней за Telegram';
}
