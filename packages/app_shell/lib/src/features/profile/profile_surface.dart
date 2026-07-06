part of pokrov_app_shell;

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.appContext,
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
    required this.notifications,
    required this.notificationsUnread,
    required this.notificationsBusy,
    required this.onOpenNotifications,
    required this.onRefreshNotifications,
    required this.onFetchDevices,
    required this.onRevokeDevice,
  });

  final SeedAppContext appContext;
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
  final VoidCallback onSpinWheel;
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
  final List<ClientNotificationItem> notifications;
  final int notificationsUnread;
  final bool notificationsBusy;
  final VoidCallback onOpenNotifications;
  final Future<void> Function() onRefreshNotifications;
  final Future<ClientDeviceList> Function() onFetchDevices;
  final Future<bool> Function(String deviceId) onRevokeDevice;

  List<String> _bonusSummaryLines() {
    final summary = bonusSummary();
    if (summary == null && bonusSummaryBusy) {
      return const ['Обновляем Telegram, рефералы и промокоды.'];
    }
    if (summary == null) {
      return const ['Telegram · рефералы · промокоды'];
    }
    final referralCode =
        summary.referralCode.isEmpty ? '' : ' · ${summary.referralCode}';
    return [
      'Telegram +${ruDays(summary.channelBonusPremiumDays)} · рефералы ${summary.referralCount}$referralCode',
    ];
  }

  String _bonusHubValue() {
    final summary = bonusSummary();
    if (bonusSummaryBusy) {
      return 'Обновляем';
    }
    if (summary == null) {
      return 'Открыть';
    }
    final parts = <String>[
      if (summary.channelBonusPremiumDays > 0)
        '+${ruDays(summary.channelBonusPremiumDays)}',
      if (summary.referralCount > 0) '${summary.referralCount} реф.',
    ];
    return parts.isEmpty ? 'Открыть' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = PokrovPalette.of(context);
    final currentBonusSummary = bonusSummary();
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
    return RefreshIndicator(
      key: const ValueKey('profile-refresh-indicator'),
      color: p.accent,
      onRefresh: () async {
        // Reuse the existing refresh callbacks; no new backend calls.
        await Future.wait<void>([
          onRefreshBonusSummary(),
          onRefreshNotifications(),
        ]);
      },
      child: _SeedContentList(
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
                    accessLabel:
                        _accessMainLabel(appContext, currentBonusSummary),
                    accessValue:
                        _accessShortValue(appContext, currentBonusSummary),
                    poolLabel: _accessPoolLabel(appContext.accessLane),
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
                        enabled: !telegramBonusBusy,
                        onTap: onCreateTelegramLink,
                      ),
                      _SettingsRow(
                        key: const ValueKey('profile-email-action'),
                        icon: Icons.alternate_email_rounded,
                        title: 'Email',
                        value: 'Добавить',
                        onTap: () => _showEmailRecoverySheet(
                          context,
                          appContext: appContext,
                          onOpenHandoff: onOpenHandoff,
                        ),
                      ),
                      _SettingsRow(
                        key: const ValueKey('profile-open-cabinet-action'),
                        icon: Icons.web_outlined,
                        title: 'Кабинет',
                        value: 'Аккаунт',
                        onTap: () =>
                            onOpenHandoff('cabinet', appContext.cabinetUrl),
                      ),
                      _SettingsRow(
                        key: const ValueKey('profile-devices-action'),
                        icon: Icons.devices_other_rounded,
                        title: 'Устройства',
                        value: 'Управлять',
                        onTap: () => _showDevicesSheet(
                          context,
                          currentPlatformLabel: appContext.hostPlatform.label,
                          onFetchDevices: onFetchDevices,
                          onRevokeDevice: onRevokeDevice,
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
                    'Если у вас уже есть код из Telegram, кабинета, сайта или письма.',
                  ],
                  child: _SettingsRow(
                    key: const ValueKey('profile-redeem-code-action'),
                    icon: Icons.key_rounded,
                    title: 'Код активации',
                    value: 'Ввести',
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
                    '${appContext.hostPlatform.label} · ${_routeModeShortLabel(selectedRouteMode)}'
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
                      _SettingsRow(
                        key: const ValueKey(
                          'profile-enhanced-protection-action',
                        ),
                        icon: Icons.privacy_tip_outlined,
                        title: 'WARP',
                        value: warpLifecycle.phase ==
                                PokrovWarpPhase.readyToConsent
                            ? 'Можно включить'
                            : warpLifecycle.publicStatus,
                        onTap: () {
                          unawaited(onOpenWarp());
                        },
                      ),
                      _SettingsRow(
                        key: const ValueKey('profile-notifications-action'),
                        icon: notificationsUnread > 0
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        title: 'Уведомления',
                        value: notificationsBusy
                            ? 'Обновляем'
                            : notificationsUnread > 0
                                ? '$notificationsUnread'
                                : 'Открыть',
                        onTap: () {
                          onOpenNotifications();
                          _showNotificationsSheet(
                            context,
                            notifications: notifications,
                            onRefresh: onRefreshNotifications,
                            onOpenHandoff: onOpenHandoff,
                          );
                        },
                      ),
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
                        value: telegramBonusCanClaim ? 'Получить' : 'Проверить',
                        enabled: !telegramBonusBusy,
                        onTap: telegramBonusCanClaim
                            ? onClaimTelegramBonus
                            : onCheckTelegramBonus,
                      ),
                      _SettingsRow(
                        key: const ValueKey('profile-bonus-wheel-action'),
                        icon: Icons.card_giftcard_outlined,
                        title: 'Бонусы и история',
                        value: _bonusHubValue(),
                        onTap: () => _showRewardsHubSheet(
                          context,
                          summary: bonusSummary,
                          rewardBusy: bonusRewardBusy,
                          onRefreshBonusSummary: onRefreshBonusSummary,
                          onSpinWheel: onSpinWheel,
                          onCheckInCalendar: onCheckInCalendar,
                          onOpenHandoff: onOpenHandoff,
                        ),
                      ),
                      if ((bonusSummaryError ?? '').isNotEmpty)
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
      ),
    );
  }
}

class _ProfileAccessOverview extends StatelessWidget {
  const _ProfileAccessOverview({
    required this.accessLabel,
    required this.accessValue,
    required this.poolLabel,
    required this.statusLabel,
    required this.onStatusTap,
    required this.onPlanTap,
    required this.onCheckoutTap,
  });

  final String accessLabel;
  final String accessValue;
  final String poolLabel;
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
            final header = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 54 : 62,
                  height: compact ? 54 : 62,
                  decoration: BoxDecoration(
                    color: p.surface.withValues(alpha: 0.86),
                    shape: BoxShape.circle,
                    border: Border.all(color: p.line),
                  ),
                  child: Center(child: _BrandMark(size: compact ? 34 : 40)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accessLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: p.ink,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        poolLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: p.muted,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusPill(
                            label: accessValue,
                            icon: Icons.calendar_today_outlined,
                            tone: _SectionTone.reward,
                          ),
                          _StatusPill(
                            label: statusLabel,
                            icon: Icons.check_circle_outline_rounded,
                            tone: _SectionTone.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header],
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
            _SettingsRow(
              key: const ValueKey('profile-plan-details-action'),
              icon: Icons.workspace_premium_outlined,
              title: 'Подписка',
              value: accessValue,
              onTap: onPlanTap,
            ),
            _SettingsRow(
              key: const ValueKey('profile-checkout-action'),
              icon: Icons.shopping_bag_outlined,
              title: 'Продлить доступ',
              value: 'Продлить',
              onTap: onCheckoutTap,
            ),
          ],
        ),
      ],
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
    // sheet leave once the selection has settled.
    onChanged(mode);
    Future<void>.delayed(const Duration(milliseconds: 320), () {
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
            Text(
              'Тема',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
            Text(
              'Подписка',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasProvisionedAccess
                  ? 'Доступ активен. Продление открывается на защищенной странице оплаты.'
                  : 'Сначала активируйте доступ на этом устройстве, затем продлите его на защищенной странице оплаты.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PokrovPalette.of(context).muted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 16),
            _KeyValueLine(
              label: 'Текущий доступ',
              value: appContext.accessLane.label,
            ),
            if (info != null && info.daysLeft > 0)
              _KeyValueLine(
                label: 'Осталось дней',
                value: '${info.daysLeft}',
              ),
            if (expires.isNotEmpty)
              _KeyValueLine(label: 'Действует до', value: expires),
            if (info != null)
              _KeyValueLine(
                label: 'Автопродление',
                value: info.autoRenew ? 'Включено' : 'Выключено',
              ),
            _KeyValueLine(
              label: 'Устройство',
              value: appContext.hostPlatform.label,
            ),
            if (info != null && info.plans.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Тарифы', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final plan in info.plans)
                Padding(
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Wrap(
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
  final emailUrl =
      Uri.parse(appContext.cabinetUrl).replace(path: '/account/email');
  final recoveryUrl =
      Uri.parse(appContext.cabinetUrl).replace(path: '/auth/recovery');
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
