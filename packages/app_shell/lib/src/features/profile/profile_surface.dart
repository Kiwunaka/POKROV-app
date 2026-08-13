part of pokrov_app_shell;

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.appContext,
    required this.freeProfileAccess,
    required this.selectedRouteMode,
    required this.hasProvisionedAccess,
    required this.onOpenHandoff,
    required this.onOpenSupportHub,
    required this.onCreateTelegramLink,
    required this.onCheckTelegramBonus,
    required this.onClaimTelegramBonus,
    required this.telegramBonusStatus,
    required this.telegramBonusBusy,
    required this.telegramBonusCanClaim,
    required this.telegramBonusError,
    required this.bonusSummary,
    required this.bonusSummaryBusy,
    required this.bonusSummaryError,
    required this.bonusRewardBusy,
    required this.onRefreshBonusSummary,
    required this.onSpinWheel,
    required this.onCheckInCalendar,
    required this.warpPolicy,
    required this.warpRuntimeConsent,
    required this.warpBusy,
    required this.runtimeSnapshot,
    required this.runtimeHeadline,
    required this.onOpenWarp,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.subscriptionInfo,
    required this.systemSurfacePreferences,
    required this.onSystemSurfacePreferencesChanged,
    required this.onOpenNotificationSettings,
    required this.notifications,
    required this.notificationsUnread,
    required this.notificationsBusy,
    required this.notificationsUsingCache,
    required this.notificationsCachedAt,
    required this.onOpenNotifications,
    required this.onRefreshNotifications,
    required this.onFetchDevices,
    required this.onRevokeDevice,
    required this.onIssuePairingCode,
    required this.onCancelPairingCode,
  });

  final SeedAppContext appContext;
  final FreeProfileAccess? freeProfileAccess;
  final RouteMode selectedRouteMode;
  final bool hasProvisionedAccess;
  final void Function(String label, String value) onOpenHandoff;
  final VoidCallback onOpenSupportHub;
  final VoidCallback onCreateTelegramLink;
  final VoidCallback onCheckTelegramBonus;
  final VoidCallback onClaimTelegramBonus;
  final String telegramBonusStatus;
  final bool telegramBonusBusy;
  final bool telegramBonusCanClaim;
  final String? telegramBonusError;

  /// Live getter into the shell state so the rewards sheet stays current
  /// while it is open (the sheet lives outside this widget's subtree).
  final AppFirstBonusSummary? Function() bonusSummary;
  final bool bonusSummaryBusy;
  final String? bonusSummaryError;
  final bool Function() bonusRewardBusy;
  final Future<void> Function() onRefreshBonusSummary;
  final Future<AppFirstBonusRewardResult?> Function() onSpinWheel;
  final VoidCallback onCheckInCalendar;
  final WarpRuntimePolicy warpPolicy;
  final bool warpRuntimeConsent;
  final bool warpBusy;
  final RuntimeSnapshot? runtimeSnapshot;
  final String? runtimeHeadline;
  final Future<void> Function() onOpenWarp;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ClientSubscriptionInfo? subscriptionInfo;
  final PokrovSystemSurfacePreferences systemSurfacePreferences;
  final Future<bool> Function(PokrovSystemSurfacePreferences preferences)
      onSystemSurfacePreferencesChanged;
  final Future<bool> Function() onOpenNotificationSettings;
  final List<ClientNotificationItem> notifications;
  final int notificationsUnread;
  final bool notificationsBusy;
  final bool notificationsUsingCache;
  final String notificationsCachedAt;
  final VoidCallback onOpenNotifications;
  final Future<void> Function() onRefreshNotifications;
  final Future<ClientDeviceList> Function() onFetchDevices;
  final Future<bool> Function(String deviceId) onRevokeDevice;
  final Future<ClientDevicePairingCode> Function() onIssuePairingCode;
  final Future<bool> Function(String pairingId) onCancelPairingCode;

  List<String> _bonusSummaryLines() {
    final summary = bonusSummary();
    if (summary == null && bonusSummaryBusy) {
      return const ['Обновляем Telegram, рефералы и промокоды.'];
    }
    if (summary == null) {
      if (_bonusPaidRequired(null)) {
        return const [
          'В пробном периоде бонусов нет. Они откроются после первой оплаты.'
        ];
      }
      return const ['Рулетка · Telegram · приглашения'];
    }
    if (_bonusPaidRequired(summary)) {
      return [
        summary.rewardAccess.message.trim().isEmpty
            ? 'В пробном периоде бонусов нет. Они откроются после первой оплаты.'
            : summary.rewardAccess.message.trim(),
      ];
    }
    final claimed = summary.channelBonusClaimed;
    final bonusDays = claimed
        ? summary.channelBonusPremiumDays
        : _availableTelegramBonusDays(summary);
    final telegramLabel =
        bonusDays > 0 ? 'Telegram +${ruDays(bonusDays)}' : 'Telegram';
    return [
      '$telegramLabel · рефералы ${summary.referralCount}',
    ];
  }

  String _bonusHubValue() {
    final summary = bonusSummary();
    if (bonusSummaryBusy) {
      return 'Обновляем';
    }
    if (summary == null) {
      return _bonusPaidRequired(null) ? 'После оплаты' : 'Открыть';
    }
    if (_bonusPaidRequired(summary)) {
      return 'После оплаты';
    }
    final claimed = summary.channelBonusClaimed;
    final bonusDays = claimed
        ? summary.channelBonusPremiumDays
        : _availableTelegramBonusDays(summary);
    final parts = <String>[
      if (bonusDays > 0) '+${ruDays(bonusDays)}',
      if (summary.referralCount > 0) '${summary.referralCount} реф.',
    ];
    return parts.isEmpty ? 'Открыть' : parts.join(' · ');
  }

  bool _bonusPaidRequired(AppFirstBonusSummary? summary) {
    if (summary?.rewardAccess.paidRequired ?? false) {
      return true;
    }
    return _effectiveAccessLane(appContext, subscriptionInfo) ==
        AccessLane.trialPremium;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentBonusSummary = bonusSummary();
    final bonusPaidRequired = _bonusPaidRequired(currentBonusSummary);
    final statusLabel = _consumerProtectionStatusLabel(runtimeSnapshot);
    final statusSummary = _consumerProtectionStatusSummary(
      runtimeSnapshot,
      headline: runtimeHeadline,
      hostPlatform: appContext.hostPlatform,
    );
    final warpLifecycle = PokrovWarpLifecycle.resolve(
      policy: warpPolicy,
      consented: warpRuntimeConsent,
      busy: warpBusy,
    );
    // Signature-arc pull-to-refresh: the connect arc is the product's own
    // refresh language; reuses the existing refresh callbacks — no new
    // backend calls.
    return _SeedContentList(
      onRefresh: () async {
        await Future.wait<void>([
          onRefreshBonusSummary(),
          onRefreshNotifications(),
        ]);
      },
      refreshIndicatorKey: const ValueKey('profile-refresh-indicator'),
      children: [
        Text('Профиль', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const ValueKey('profile-compact-account-layer'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                key: const ValueKey('profile-section-plan-access'),
                title: 'Ваш доступ',
                lines: const [],
                child: _ProfileAccessOverview(
                  accessLabel: _accessMainLabel(
                    appContext,
                    currentBonusSummary,
                    freeProfileAccess,
                    subscriptionInfo,
                  ),
                  accessValue: _accessShortValue(
                    appContext,
                    currentBonusSummary,
                    freeProfileAccess,
                    subscriptionInfo,
                  ),
                  accessDays: _accessShortDays(
                    appContext,
                    currentBonusSummary,
                    freeProfileAccess,
                    subscriptionInfo,
                  ),
                  poolLabel: _accessPoolLabelFor(
                    _effectiveAccessLane(appContext, subscriptionInfo),
                    freeProfileAccess,
                  ),
                  accessNotice: _freeProfileAccessNotice(freeProfileAccess),
                  statusLabel: statusLabel,
                  onStatusTap: () => _showInfoSheet(
                    context,
                    title: 'Статус',
                    lines: [statusSummary],
                  ),
                  onPlanTap: () => _showSubscriptionSheet(
                    context,
                    appContext: appContext,
                    hasProvisionedAccess: hasProvisionedAccess,
                    subscriptionInfo: subscriptionInfo,
                    onOpenHandoff: onOpenHandoff,
                  ),
                  onCheckoutTap: () =>
                      onOpenHandoff('checkout', appContext.checkoutUrl),
                ),
              ),
              _SectionCard(
                key: const ValueKey('profile-section-statistics'),
                title: 'Статистика',
                lines: const ['Только подтверждённые данные этого аккаунта.'],
                child: Column(
                  children: [
                    _SettingsRow(
                      key: const ValueKey('profile-statistics-traffic'),
                      icon: Icons.data_usage_rounded,
                      title: 'Трафик через POKROV',
                      value: subscriptionInfo?.usageSource == 'panel_runtime'
                          ? _formatTrafficVolume(
                              subscriptionInfo?.trafficUsedBytes ?? 0,
                            )
                          : 'Нет свежих данных',
                    ),
                    const _SettingsRowDivider(),
                    _SettingsRow(
                      key: const ValueKey('profile-statistics-connections'),
                      icon: Icons.link_rounded,
                      title: 'Активные подключения',
                      value: subscriptionInfo?.usageSource == 'panel_runtime'
                          ? '${subscriptionInfo?.activeConnections ?? 0}'
                          : '—',
                    ),
                  ],
                ),
              ),
              _SectionCard(
                key: const ValueKey('profile-section-account'),
                title: 'Аккаунт',
                lines: const [
                  'Telegram, email и кабинет помогают не потерять доступ.',
                ],
                child: Column(
                  children: [
                    _SettingsRow(
                      key: const ValueKey('profile-telegram-link-action'),
                      icon: Icons.send_outlined,
                      title: 'Telegram',
                      value: telegramBonusBusy ? 'Проверяем' : 'Привязать',
                      valueIsAction: !telegramBonusBusy,
                      enabled: !telegramBonusBusy,
                      onTap: onCreateTelegramLink,
                    ),
                    const _SettingsRowDivider(),
                    _SettingsRow(
                      key: const ValueKey('profile-email-action'),
                      icon: Icons.alternate_email_rounded,
                      title: 'Email',
                      value: 'Добавить',
                      valueIsAction: true,
                      onTap: () => _showEmailRecoverySheet(
                        context,
                        appContext: appContext,
                        onOpenHandoff: onOpenHandoff,
                      ),
                    ),
                    const _SettingsRowDivider(),
                    _SettingsRow(
                      key: const ValueKey('profile-open-cabinet-action'),
                      icon: Icons.web_outlined,
                      title: 'Кабинет',
                      value: 'Аккаунт',
                      onTap: () =>
                          onOpenHandoff('cabinet', appContext.cabinetUrl),
                    ),
                    const _SettingsRowDivider(),
                    _SettingsRow(
                      key: const ValueKey('profile-devices-action'),
                      icon: Icons.devices_other_rounded,
                      title: 'Устройства',
                      value: 'Управлять',
                      valueIsAction: true,
                      onTap: () => _showDevicesSheet(
                        context,
                        currentPlatformLabel: appContext.hostPlatform.label,
                        onFetchDevices: onFetchDevices,
                        onRevokeDevice: onRevokeDevice,
                        onIssuePairingCode: onIssuePairingCode,
                        onCancelPairingCode: onCancelPairingCode,
                      ),
                    ),
                    if ((telegramBonusError ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          telegramBonusError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _SectionCard(
                key: const ValueKey('profile-section-sync'),
                title: 'Восстановить доступ',
                lines: const [
                  'Одноразовый вход с другого устройства или активация доступа.',
                ],
                child: _SettingsRow(
                  key: const ValueKey('profile-redeem-code-action'),
                  icon: Icons.key_rounded,
                  title: 'Код входа или активации',
                  value: 'Ввести',
                  valueIsAction: true,
                  onTap: () => _showRedeemSheet(
                    context,
                    hintCode: appContext.redeemHint,
                    onRedeem: (code) => onOpenHandoff('redeem', code),
                  ),
                ),
              ),
              PokrovSettingsRowPressSurface(
                key: const ValueKey('profile-section-support'),
                onTap: onOpenSupportHub,
                child: _SectionCard(
                  key: const ValueKey('profile-section-support-group'),
                  title: 'Поддержка',
                  lines: const [
                    'Чат и безопасная сводка состояния без ключей, ссылок и технических логов.',
                  ],
                  child: Column(
                    children: [
                      _SettingsRow(
                        key: const ValueKey('profile-open-support-action'),
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Написать в поддержку',
                        value: 'Чат',
                        onTap: onOpenSupportHub,
                      ),
                      const _SettingsRowDivider(),
                      _SettingsRow(
                        key: const ValueKey('profile-guides-action'),
                        icon: Icons.menu_book_outlined,
                        title: 'Пошаговые инструкции',
                        value: 'Открыть',
                        onTap: () => onOpenHandoff(
                          'download',
                          'https://pokrov.space/guides/',
                        ),
                      ),
                      const _SettingsRowDivider(),
                      _SettingsRow(
                        key: const ValueKey('profile-diagnostics-action'),
                        icon: Icons.health_and_safety_outlined,
                        title: 'Сведения для поддержки',
                        value: 'Открыть',
                        onTap: () => _showAdvancedSettingsSheet(
                          context,
                          hostPlatform: appContext.hostPlatform,
                          selectedRouteMode: selectedRouteMode,
                          statusLabel: statusLabel,
                          warpStatus: warpLifecycle.publicStatus,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _SectionCard(
                key: const ValueKey('profile-section-app'),
                title: 'Настройки',
                lines: [
                  '${appContext.hostPlatform.label} · ${_routeModeShortLabel(selectedRouteMode)}',
                ],
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.alt_route_rounded,
                      title: 'Режим работы',
                      value: _routeModeShortLabel(selectedRouteMode),
                      onTap: () => _showInfoSheet(
                        context,
                        title: 'Режим работы',
                        lines: [
                          _routeModeRowSummary(selectedRouteMode),
                          'Изменить режим можно во вкладке «Правила».',
                        ],
                      ),
                    ),
                    const _SettingsRowDivider(),
                    _SettingsRow(
                      key: const ValueKey('profile-enhanced-protection-action'),
                      icon: Icons.privacy_tip_outlined,
                      title: 'WARP',
                      value:
                          warpLifecycle.phase == PokrovWarpPhase.readyToConsent
                              ? 'Можно включить'
                              : warpLifecycle.publicStatus,
                      onTap: () {
                        unawaited(onOpenWarp());
                      },
                    ),
                    const _SettingsRowDivider(),
                    if (appContext.hostPlatform == HostPlatform.android) ...[
                      _SettingsRow(
                        key: const ValueKey(
                          'profile-system-surfaces-action',
                        ),
                        icon: Icons.notifications_active_outlined,
                        title: 'Шторка и VPN-уведомление',
                        value: systemSurfacePreferences.summary,
                        onTap: () => _showSystemSurfacePreferencesSheet(
                          context,
                          preferences: systemSurfacePreferences,
                          onChanged: onSystemSurfacePreferencesChanged,
                          onOpenNotificationSettings:
                              onOpenNotificationSettings,
                        ),
                      ),
                      const _SettingsRowDivider(),
                    ],
                    _SettingsRow(
                      key: const ValueKey('profile-notifications-action'),
                      icon: notificationsUnread > 0
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      title: 'Уведомления',
                      value: notificationsBusy
                          ? 'Обновляем'
                          : notificationsUsingCache
                              ? 'Сохранено'
                              : notificationsUnread > 0
                                  ? '$notificationsUnread'
                                  : 'Открыть',
                      onTap: () {
                        onOpenNotifications();
                        _showNotificationsSheet(
                          context,
                          notifications: notifications,
                          usingCache: notificationsUsingCache,
                          cachedAt: notificationsCachedAt,
                          onRefresh: onRefreshNotifications,
                          onOpenHandoff: onOpenHandoff,
                        );
                      },
                    ),
                    const _SettingsRowDivider(),
                    _SettingsRow(
                      key: const ValueKey('profile-theme-action'),
                      icon: Icons.brightness_6_outlined,
                      title: 'Тема',
                      value: _themeModeLabel(themeMode),
                      onTap: () => _showThemeModeSheet(
                        context,
                        selected: themeMode,
                        onChanged: onThemeModeChanged,
                      ),
                    ),
                  ],
                ),
              ),
              _SectionCard(
                key: const ValueKey('profile-section-bonus-summary'),
                title: 'Бонусы',
                tone: _SectionTone.reward,
                lines: _bonusSummaryLines(),
                child: Column(
                  children: [
                    if (currentBonusSummary == null && bonusSummaryBusy)
                      const _MotionSkeletonList(
                        key: ValueKey('rewards-skeleton-summary'),
                        rows: 3,
                      ),
                    _SettingsRow(
                      key: const ValueKey('profile-telegram-claim-action'),
                      icon: Icons.send_outlined,
                      title: 'Telegram-бонус',
                      value: bonusPaidRequired
                          ? 'После оплаты'
                          : telegramBonusCanClaim
                              ? 'Получить'
                              : 'Проверить',
                      valueIsAction: !bonusPaidRequired && !telegramBonusBusy,
                      enabled: !bonusPaidRequired && !telegramBonusBusy,
                      onTap: bonusPaidRequired
                          ? null
                          : telegramBonusCanClaim
                              ? onClaimTelegramBonus
                              : onCheckTelegramBonus,
                    ),
                    const _SettingsRowDivider(),
                    _SettingsRow(
                      key: const ValueKey('profile-bonus-wheel-action'),
                      icon: Icons.card_giftcard_outlined,
                      title: 'Бонусы и история',
                      value: _bonusHubValue(),
                      onTap: () => _showRewardsHubSheet(
                        context,
                        summary: bonusSummary,
                        rewardBusy: bonusRewardBusy,
                        paidRequired: bonusPaidRequired,
                        onRefreshBonusSummary: onRefreshBonusSummary,
                        onSpinWheel: onSpinWheel,
                        onCheckInCalendar: onCheckInCalendar,
                        onOpenHandoff: onOpenHandoff,
                      ),
                    ),
                    if (!bonusPaidRequired &&
                        (bonusSummaryError ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          bonusSummaryError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatTrafficVolume(int bytes) {
  final safeBytes = bytes < 0 ? 0 : bytes;
  const kib = 1024.0;
  const mib = 1024.0 * kib;
  const gib = 1024.0 * mib;
  if (safeBytes >= gib) {
    final value = safeBytes / gib;
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ГБ';
  }
  if (safeBytes >= mib) {
    final value = safeBytes / mib;
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} МБ';
  }
  return '${(safeBytes / kib).toStringAsFixed(0)} КБ';
}

class _ProfileAccessOverview extends StatelessWidget {
  const _ProfileAccessOverview({
    required this.accessLabel,
    required this.accessValue,
    required this.accessDays,
    required this.poolLabel,
    required this.accessNotice,
    required this.statusLabel,
    required this.onStatusTap,
    required this.onPlanTap,
    required this.onCheckoutTap,
  });

  final String accessLabel;
  final String accessValue;

  /// Day count behind [accessValue] when the lane is numeric; drives the
  /// living count-up so the entitlement feels owned, not printed.
  final int? accessDays;
  final String poolLabel;
  final String? accessNotice;
  final String statusLabel;
  final VoidCallback onStatusTap;
  final VoidCallback onPlanTap;
  final VoidCallback onCheckoutTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final p = PokrovPalette.of(context);
            final compact = constraints.maxWidth < 430;
            final isProtected = statusLabel == 'Подключено';
            final brand = Container(
              width: compact ? 54 : 62,
              height: compact ? 54 : 62,
              decoration: BoxDecoration(
                color: p.surface.withValues(alpha: 0.86),
                shape: BoxShape.circle,
                border: Border.all(color: p.line),
              ),
              child: Center(child: _BrandMark(size: compact ? 34 : 40)),
            );
            final headline = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accessLabel,
                  maxLines: compact ? 2 : 1,
                  overflow: compact ? TextOverflow.clip : TextOverflow.ellipsis,
                  style: (compact
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.titleLarge)
                      ?.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  poolLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
              ],
            );
            final badges = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (accessDays != null)
                  _LivingDaysCount(
                    days: accessDays!,
                    builder: (context, days) => _StatusPill(
                      label: ruDays(days),
                      icon: Icons.calendar_today_outlined,
                      tone: _SectionTone.reward,
                    ),
                  )
                else
                  _StatusPill(
                    label: accessValue,
                    icon: Icons.calendar_today_outlined,
                    tone: _SectionTone.reward,
                  ),
                KeyedSubtree(
                  key: const ValueKey('profile-connection-status-pill'),
                  child: _StatusPill(
                    label: statusLabel,
                    icon: isProtected
                        ? Icons.verified_user_outlined
                        : Icons.shield_outlined,
                    tone:
                        isProtected ? _SectionTone.accent : _SectionTone.muted,
                  ),
                ),
              ],
            );
            final header = compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          brand,
                          const SizedBox(width: 14),
                          Expanded(child: headline),
                        ],
                      ),
                      const SizedBox(height: 12),
                      badges,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      brand,
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            headline,
                            const SizedBox(height: 8),
                            badges,
                          ],
                        ),
                      ),
                    ],
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                if (accessNotice != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    accessNotice!,
                    key: const ValueKey('profile-free-access-notice'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: p.muted,
                          height: 1.35,
                        ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            _SettingsRow(
              key: const ValueKey('profile-status-action'),
              icon: Icons.info_outline_rounded,
              title: 'Статус',
              value: statusLabel,
              onTap: onStatusTap,
            ),
            const _SettingsRowDivider(),
            _SettingsRow(
              key: const ValueKey('profile-plan-details-action'),
              icon: Icons.workspace_premium_outlined,
              title: 'Подписка',
              value: accessValue,
              onTap: onPlanTap,
            ),
            const _SettingsRowDivider(),
            _SettingsRow(
              key: const ValueKey('profile-checkout-action'),
              icon: Icons.shopping_bag_outlined,
              title: 'Продлить',
              value: 'Выбрать срок',
              valueIsAction: true,
              onTap: onCheckoutTap,
            ),
          ],
        ),
      ],
    );
  }
}

/// Inset hairline between grouped settings rows, iOS grouped-table style:
/// aligned to the text column (34px icon + 12px gap), never full-bleed.
class _SettingsRowDivider extends StatelessWidget {
  const _SettingsRowDivider();

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Divider(height: 1, thickness: 1, indent: 46, color: p.line);
  }
}

/// Screen-Time-style living counter for entitlement numbers: counts old→new
/// once per data change (the first arrival counts up from zero), rebuilds
/// its text every frame so RU plural forms track the interpolated value, and
/// lands with one soft spring pulse. Static under reduced motion or when the
/// target is zero — bad news is never dramatized.
class _LivingDaysCount extends StatefulWidget {
  const _LivingDaysCount({required this.days, required this.builder});

  final int days;
  final Widget Function(BuildContext context, int days) builder;

  @override
  State<_LivingDaysCount> createState() => _LivingDaysCountState();
}

class _LivingDaysCountState extends State<_LivingDaysCount> {
  double _from = 0;
  int _pulseTick = 0;

  @override
  void didUpdateWidget(covariant _LivingDaysCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) {
      _from = oldWidget.days.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    if (motion.disableAnimations || widget.days <= 0) {
      return widget.builder(context, widget.days);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey('living-days-${widget.days}'),
      tween: Tween(begin: _from, end: widget.days.toDouble()),
      duration: _MotionTokens.homeReveal,
      curve: _MotionTokens.emphasized,
      onEnd: () => setState(() => _pulseTick += 1),
      builder: (context, value, _) => TweenAnimationBuilder<double>(
        key: ValueKey('living-days-pulse-$_pulseTick'),
        tween: Tween(begin: _pulseTick == 0 ? 1.0 : 1.04, end: 1),
        duration: motion.duration(PokrovMotionTokens.quick),
        curve: PokrovMotionTokens.spring,
        builder: (context, scale, _) => Transform.scale(
          scale: scale,
          child: widget.builder(context, value.round()),
        ),
      ),
    );
  }
}

String _themeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => 'Системная',
    ThemeMode.light => 'Светлая',
    ThemeMode.dark => 'Тёмная',
  };
}

void _showThemeModeSheet(
  BuildContext context, {
  required ThemeMode selected,
  required ValueChanged<ThemeMode> onChanged,
}) {
  void select(ThemeMode mode) {
    // Apply immediately so the springy checkmark is visible, then let the
    // sheet leave once the selection has settled. The settle delay follows
    // the motion scope: under reduced motion the sheet pops right away.
    onChanged(mode);
    final settle = _MotionScope.of(
      context,
    ).duration(const Duration(milliseconds: 320));
    Future<void>.delayed(settle, () {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        key: const ValueKey('profile-theme-sheet'),
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тема', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'POKROV может следовать системе или всегда открываться в выбранном оформлении.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PokrovPalette.of(context).muted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 14),
            PokrovCheckRow(
              key: const ValueKey('profile-theme-system'),
              icon: Icons.brightness_auto_outlined,
              title: 'Системная',
              selected: selected == ThemeMode.system,
              onTap: () => select(ThemeMode.system),
            ),
            PokrovCheckRow(
              key: const ValueKey('profile-theme-light'),
              icon: Icons.light_mode_outlined,
              title: 'Светлая',
              selected: selected == ThemeMode.light,
              onTap: () => select(ThemeMode.light),
            ),
            PokrovCheckRow(
              key: const ValueKey('profile-theme-dark'),
              icon: Icons.dark_mode_outlined,
              title: 'Тёмная',
              selected: selected == ThemeMode.dark,
              onTap: () => select(ThemeMode.dark),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showSystemSurfacePreferencesSheet(
  BuildContext context, {
  required PokrovSystemSurfacePreferences preferences,
  required Future<bool> Function(PokrovSystemSurfacePreferences preferences)
      onChanged,
  required Future<bool> Function() onOpenNotificationSettings,
}) {
  var current = preferences;
  var busy = false;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> save(PokrovSystemSurfacePreferences next) async {
          if (busy) {
            return;
          }
          setSheetState(() => busy = true);
          final saved = await onChanged(next);
          if (!sheetContext.mounted) {
            return;
          }
          setSheetState(() {
            if (saved) {
              current = next;
            }
            busy = false;
          });
          if (!saved) {
            showPokrovSnack(
              sheetContext,
              'Не удалось сохранить настройки шторки.',
              tone: PokrovSnackTone.danger,
            );
          }
        }

        Widget toggleRow({
          required Key key,
          required String title,
          required String description,
          required bool value,
          required PokrovSystemSurfacePreferences Function(bool value) next,
        }) {
          return Padding(
            key: key,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(sheetContext).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: Theme.of(sheetContext)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: PokrovPalette.of(sheetContext).muted,
                              height: 1.3,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                PokrovSwitch(
                  value: value,
                  onChanged: busy
                      ? null
                      : (value) {
                          unawaited(save(next(value)));
                        },
                ),
              ],
            ),
          );
        }

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              22,
              4,
              22,
              24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              key: const ValueKey('profile-system-surfaces-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Шторка и VPN-уведомление',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Статус подключения остаётся всегда. Остальные данные можно скрыть.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color: PokrovPalette.of(sheetContext).muted,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 8),
                toggleRow(
                  key: const ValueKey('system-surface-country-toggle'),
                  title: 'Страна',
                  description:
                      'Показывать страну в VPN-уведомлении. В плитке — только если это поддерживает оболочка Android.',
                  value: current.showCountry,
                  next: (value) => current.copyWith(showCountry: value),
                ),
                const Divider(height: 1),
                toggleRow(
                  key: const ValueKey('system-surface-speed-toggle'),
                  title: 'Скорость',
                  description:
                      'Показывать текущие входящую и исходящую скорости.',
                  value: current.showSpeed,
                  next: (value) => current.copyWith(showSpeed: value),
                ),
                const Divider(height: 1),
                toggleRow(
                  key: const ValueKey('system-surface-route-toggle'),
                  title: 'Режим маршрутизации',
                  description:
                      'Например: «РФ напрямую» или «Весь трафик через VPN».',
                  value: current.showRouteMode,
                  next: (value) => current.copyWith(showRouteMode: value),
                ),
                const SizedBox(height: 16),
                Text(
                  'Быстрая кнопка',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Если плитки POKROV нет: раскройте шторку, нажмите «Изменить» и перетащите POKROV в активные кнопки.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: PokrovPalette.of(sheetContext).muted,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey(
                      'system-surface-notification-settings-action',
                    ),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(onOpenNotificationSettings());
                    },
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Настройки уведомлений Android'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String _formatClientDate(String iso) {
  final parsed = DateTime.tryParse(iso.trim());
  if (parsed == null) {
    return '';
  }
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}

void _showSubscriptionSheet(
  BuildContext context, {
  required SeedAppContext appContext,
  required bool hasProvisionedAccess,
  required ClientSubscriptionInfo? subscriptionInfo,
  required void Function(String label, String value) onOpenHandoff,
}) {
  final info = subscriptionInfo;
  final expires = info == null ? '' : _formatClientDate(info.expiresAt);
  final renewUrl = info?.renewUrl;
  final renewTarget = renewUrl != null && renewUrl.toString().trim().isNotEmpty
      ? renewUrl.toString()
      : appContext.checkoutUrl;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('profile-subscription-sheet'),
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetReveal(
              order: 0,
              child: Text(
                'Подписка',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            _SheetReveal(
              order: 1,
              child: Text(
                hasProvisionedAccess
                    ? 'Доступ активен. Продление открывается на защищенной странице оплаты.'
                    : 'Сначала активируйте доступ на этом устройстве, затем продлите его на защищенной странице оплаты.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: PokrovPalette.of(context).muted,
                      height: 1.35,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            _SheetReveal(
              order: 2,
              child: _KeyValueLine(
                label: 'Текущий доступ',
                value: _effectiveAccessLane(appContext, info).label,
              ),
            ),
            if (info != null && info.daysLeft > 0)
              _SheetReveal(
                order: 3,
                child: _KeyValueLine(
                  label: 'Осталось дней',
                  value: '${info.daysLeft}',
                  valueWidget: _LivingDaysCount(
                    days: info.daysLeft,
                    builder: (context, days) => Text(
                      '$days',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: PokrovPalette.of(context).ink,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),
            if (expires.isNotEmpty)
              _SheetReveal(
                order: 4,
                child: _KeyValueLine(label: 'Действует до', value: expires),
              ),
            if (info != null)
              _SheetReveal(
                order: 5,
                child: _KeyValueLine(
                  label: 'Автопродление',
                  value: info.autoRenew ? 'Включено' : 'Выключено',
                ),
              ),
            _SheetReveal(
              order: 5,
              child: _KeyValueLine(
                label: 'Устройство',
                value: appContext.hostPlatform.label,
              ),
            ),
            if (info != null && info.plans.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SheetReveal(
                order: 5,
                child: Text(
                  'Тарифы',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              for (final plan in info.plans)
                _SheetReveal(
                  order: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.title,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          plan.price,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            _SheetReveal(
              order: 5,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  PokrovPressable(
                    child: FilledButton.icon(
                      key: const ValueKey('subscription-checkout-primary'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onOpenHandoff('checkout', renewTarget);
                      },
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text('Перейти к оплате'),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('subscription-cabinet-primary'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpenHandoff('cabinet', appContext.cabinetUrl);
                    },
                    icon: const Icon(Icons.web_outlined),
                    label: const Text('Открыть кабинет'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showEmailRecoverySheet(
  BuildContext context, {
  required SeedAppContext appContext,
  required void Function(String label, String value) onOpenHandoff,
}) {
  final emailUrl = Uri.parse(
    appContext.cabinetUrl,
  ).replace(path: '/account/email');
  final recoveryUrl = Uri.parse(
    appContext.cabinetUrl,
  ).replace(path: '/auth/recovery');
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('profile-email-recovery-sheet'),
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email и восстановление',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Email нужен для восстановления доступа и входа в кабинет. Все действия открываются через короткую защищенную сессию.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PokrovPalette.of(context).muted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  key: const ValueKey('profile-email-add-action'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenHandoff('download', emailUrl.toString());
                  },
                  icon: const Icon(Icons.alternate_email_rounded),
                  label: const Text('Добавить email'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('profile-email-cabinet-action'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenHandoff('cabinet', appContext.cabinetUrl);
                  },
                  icon: const Icon(Icons.web_outlined),
                  label: const Text('Кабинет'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('profile-email-recovery-action'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenHandoff('download', recoveryUrl.toString());
                  },
                  icon: const Icon(Icons.lock_reset_rounded),
                  label: const Text('Восстановить'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
