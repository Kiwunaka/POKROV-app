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
  SeedAppContext appContext,
  AppFirstBonusSummary? bonus, [
  FreeProfileAccess? freeProfileAccess,
  ClientSubscriptionInfo? subscriptionInfo,
]) {
  final freeLabel = _freeProfileAccessLabel(freeProfileAccess);
  if (freeLabel != null) {
    return freeLabel;
  }
  final baseDays = appContext.runtimeProfile.trialDays;
  final bonusDays = bonus?.channelBonusPremiumDays ?? 0;
  final claimed = (bonus?.channelBonusClaimedAt ?? '').trim().isNotEmpty;
  final totalDays = baseDays + (claimed ? bonusDays : 0);
  final lane = _effectiveAccessLane(appContext, subscriptionInfo);
  final liveDays = subscriptionInfo?.daysLeft ?? 0;
  return switch (lane) {
    AccessLane.trialPremium => claimed
        ? '${ruDays(liveDays > 0 ? liveDays : totalDays)} доступа'
        : '${ruDays(liveDays > 0 ? liveDays : baseDays)} пробного доступа',
    AccessLane.bonusPremium =>
      '${ruDays(liveDays > 0 ? liveDays : totalDays)} доступа',
    AccessLane.paidUnlimited => 'Премиум активен',
    AccessLane.freeMonthly => 'Базовый режим',
    AccessLane.freeSoftMode => 'Лимит закончился',
  };
}

String _accessShortValue(
  SeedAppContext appContext,
  AppFirstBonusSummary? bonus, [
  FreeProfileAccess? freeProfileAccess,
  ClientSubscriptionInfo? subscriptionInfo,
]) {
  final freeValue = _freeProfileAccessShortValue(freeProfileAccess);
  if (freeValue != null) {
    return freeValue;
  }
  final baseDays = appContext.runtimeProfile.trialDays;
  final bonusDays = bonus?.channelBonusPremiumDays ?? 0;
  final claimed = (bonus?.channelBonusClaimedAt ?? '').trim().isNotEmpty;
  final totalDays = baseDays + (claimed ? bonusDays : 0);
  final lane = _effectiveAccessLane(appContext, subscriptionInfo);
  final liveDays = subscriptionInfo?.daysLeft ?? 0;
  return switch (lane) {
    AccessLane.trialPremium =>
      ruDays(liveDays > 0 ? liveDays : (claimed ? totalDays : baseDays)),
    AccessLane.bonusPremium => ruDays(liveDays > 0 ? liveDays : totalDays),
    AccessLane.paidUnlimited => liveDays > 0 ? ruDays(liveDays) : 'Премиум',
    AccessLane.freeMonthly => 'Базовый',
    AccessLane.freeSoftMode => 'Лимит',
  };
}

/// Numeric twin of [_accessShortValue] for lanes whose value is a day count;
/// null for the label-only lanes so callers fall back to static text.
int? _accessShortDays(
  SeedAppContext appContext,
  AppFirstBonusSummary? bonus, [
  FreeProfileAccess? freeProfileAccess,
  ClientSubscriptionInfo? subscriptionInfo,
]) {
  if (_freeProfileAccessLabel(freeProfileAccess) != null) {
    return null;
  }
  final baseDays = appContext.runtimeProfile.trialDays;
  final bonusDays = bonus?.channelBonusPremiumDays ?? 0;
  final claimed = (bonus?.channelBonusClaimedAt ?? '').trim().isNotEmpty;
  final totalDays = baseDays + (claimed ? bonusDays : 0);
  final lane = _effectiveAccessLane(appContext, subscriptionInfo);
  final liveDays = subscriptionInfo?.daysLeft ?? 0;
  return switch (lane) {
    AccessLane.trialPremium =>
      liveDays > 0 ? liveDays : (claimed ? totalDays : baseDays),
    AccessLane.bonusPremium => liveDays > 0 ? liveDays : totalDays,
    AccessLane.paidUnlimited => liveDays > 0 ? liveDays : null,
    AccessLane.freeMonthly || AccessLane.freeSoftMode => null,
  };
}

AccessLane _effectiveAccessLane(
  SeedAppContext appContext,
  ClientSubscriptionInfo? subscriptionInfo,
) {
  return switch (subscriptionInfo?.lane.trim()) {
    'trialPremium' => AccessLane.trialPremium,
    'bonusPremium' => AccessLane.bonusPremium,
    'paidUnlimited' => AccessLane.paidUnlimited,
    'freeMonthly' => AccessLane.freeMonthly,
    'freeSoftMode' => AccessLane.freeSoftMode,
    _ => appContext.accessLane,
  };
}

String _accessPoolLabelFor(
  AccessLane fallback, [
  FreeProfileAccess? freeProfileAccess,
]) {
  if (freeProfileAccess?.needsConservativePresentation ?? false) {
    return 'Статус доступа уточняется';
  }
  if (freeProfileAccess?.isFreeAccess ?? false) {
    return 'Базовый доступ';
  }
  return _accessPoolLabel(fallback);
}

String? _freeProfileAccessLabel(FreeProfileAccess? access) {
  if (access == null) {
    return null;
  }
  if (access.hasRecoverableError) {
    return 'Базовый доступ требует обновления';
  }
  if (access.isPending) {
    return 'Обновляем базовый доступ';
  }
  if (access.needsConservativePresentation) {
    return 'Статус доступа уточняется';
  }
  if (access.isConfirmedSoftMode || access.isFreeAccess) {
    return 'Базовый режим';
  }
  return null;
}

String? _freeProfileAccessShortValue(FreeProfileAccess? access) {
  if (access == null) {
    return null;
  }
  if (access.hasRecoverableError) {
    return 'Обновить';
  }
  if (access.isPending) {
    return 'Обновляем';
  }
  if (access.needsConservativePresentation) {
    return 'Проверяем';
  }
  if (access.isConfirmedSoftMode || access.isFreeAccess) {
    return 'Базовый';
  }
  return null;
}

String? _freeProfileAccessNotice(FreeProfileAccess? access) {
  if (access == null) {
    return null;
  }
  if (access.hasRecoverableError) {
    return 'Не удалось обновить базовый доступ. Обновите настройки через минуту; если это повторится, обратитесь в поддержку.';
  }
  if (access.isPending) {
    return 'Мы обновляем базовый доступ. Попробуйте подключиться через минуту.';
  }
  if (access.isConfirmedSoftMode) {
    return 'Лимит базового режима закончился. Доступ продолжится в базовом режиме.';
  }
  if (access.needsConservativePresentation) {
    return 'Статус базового доступа уточняется. Обновите настройки перед подключением.';
  }
  return null;
}

String _telegramBonusHomeLabel(
  AppFirstBonusSummary? bonus,
) {
  final claimed = (bonus?.channelBonusClaimedAt ?? '').trim().isNotEmpty;
  if (claimed) {
    return 'Telegram-бонус активен';
  }
  return '+${ruDays(_availableTelegramBonusDays(bonus))} за Telegram';
}

/// New claims use the server-advertised positive reward, with the current
/// product fallback when the summary has not loaded yet. A claimed reward is
/// rendered separately from its backend-returned value and is never coerced
/// to this fallback.
int _availableTelegramBonusDays(AppFirstBonusSummary? bonus) {
  final days = bonus?.channelBonusPremiumDays ?? 0;
  return days > 0 ? days : 5;
}

int? _claimedTelegramBonusDays(AppFirstBonusSummary? bonus) {
  final days = bonus?.channelBonusPremiumDays ?? 0;
  return days > 0 ? days : null;
}
