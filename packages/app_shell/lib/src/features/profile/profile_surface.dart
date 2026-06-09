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
  final AppFirstBonusSummary? bonusSummary;
  final bool bonusSummaryBusy;
  final String? bonusSummaryError;
  final bool bonusRewardBusy;
  final VoidCallback onRefreshBonusSummary;
  final VoidCallback onSpinWheel;
  final VoidCallback onCheckInCalendar;
  final WarpRuntimePolicy warpPolicy;
  final bool warpRuntimeConsent;
  final bool warpBusy;
  final RuntimeSnapshot? runtimeSnapshot;
  final String? runtimeHeadline;
  final Future<void> Function() onOpenWarp;

  List<String> _bonusSummaryLines() {
    final summary = bonusSummary;
    if (summary == null && bonusSummaryBusy) {
      return const ['Обновляем Telegram, рефералы и промокоды.'];
    }
    if (summary == null) {
      return const ['Telegram · рефералы · промокоды'];
    }
    final referralCode =
        summary.referralCode.isEmpty ? '' : ' · ${summary.referralCode}';
    return [
      'Telegram +${summary.channelBonusPremiumDays} дней · рефералы ${summary.referralCount}$referralCode',
    ];
  }

  String _bonusHubValue() {
    final summary = bonusSummary;
    if (bonusSummaryBusy) {
      return 'Обновляем';
    }
    if (summary == null) {
      return 'Открыть';
    }
    final parts = <String>[
      if (summary.channelBonusPremiumDays > 0)
        '+${summary.channelBonusPremiumDays} дней',
      if (summary.referralCount > 0) '${summary.referralCount} реф.',
    ];
    return parts.isEmpty ? 'Открыть' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    return _SeedContentList(
      top: 18,
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
                title: 'Мой доступ',
                tone: _SectionTone.accent,
                lines: const [],
                child: _ProfileAccessOverview(
                  accessLabel: _accessMainLabel(appContext, bonusSummary),
                  accessValue: _accessShortValue(appContext, bonusSummary),
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
                    onOpenHandoff: onOpenHandoff,
                  ),
                  onCheckoutTap: () =>
                      onOpenHandoff('checkout', appContext.checkoutUrl),
                ),
              ),
              Padding(
                key: const ValueKey('profile-section-sync'),
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Быстрые действия',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Код доступа, Telegram, кабинет и поддержка.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _SeedPalette.muted,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileQuickActionsGrid(
                      children: [
                        _ProfileActionTile(
                          key: const ValueKey('profile-redeem-code-action'),
                          icon: Icons.key_rounded,
                          title: 'Ввести код',
                          subtitle: 'Бот, сайт или письмо',
                          onTap: () => _showRedeemSheet(
                            context,
                            hintCode: appContext.redeemHint,
                            onRedeem: (code) => onOpenHandoff('redeem', code),
                          ),
                        ),
                        _ProfileActionTile(
                          key: const ValueKey('profile-open-cabinet-action'),
                          icon: Icons.web_outlined,
                          title: 'Кабинет',
                          subtitle: 'Подписка и платежи',
                          onTap: () =>
                              onOpenHandoff('cabinet', appContext.cabinetUrl),
                        ),
                        _ProfileActionTile(
                          key: const ValueKey('profile-telegram-link-action'),
                          icon: Icons.send_outlined,
                          title: 'Telegram',
                          subtitle: telegramBonusBusy
                              ? 'Проверяем'
                              : '+${appContext.runtimeProfile.telegramBonusDays} дней',
                          onTap:
                              telegramBonusBusy ? null : onCreateTelegramLink,
                        ),
                        _ProfileActionTile(
                          key: const ValueKey('profile-section-support'),
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Написать',
                          subtitle: 'Чат поддержки',
                          onTap: onOpenSupportHub,
                        ),
                      ],
                      footer: (telegramBonusError ?? '').isNotEmpty
                          ? Text(
                              telegramBonusError!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                                height: 1.3,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              _SectionCard(
                key: const ValueKey('profile-section-app'),
                title: 'Настройки приложения',
                lines: [
                  '${appContext.hostPlatform.label} · ${_routeModeShortLabel(selectedRouteMode)}'
                ],
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.alt_route_rounded,
                      title: 'Правила',
                      value: _routeModeShortLabel(selectedRouteMode),
                      onTap: () => _showInfoSheet(
                        context,
                        title: 'Правила подключения',
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
                      value:
                          warpLifecycle.phase == PokrovWarpPhase.readyToConsent
                              ? 'Можно включить'
                              : warpLifecycle.publicStatus,
                      onTap: () {
                        unawaited(onOpenWarp());
                      },
                    ),
                    _SettingsRow(
                      key: const ValueKey('profile-email-action'),
                      icon: Icons.alternate_email_rounded,
                      title: 'Email',
                      value: 'Вход',
                      onTap: () => _showEmailRecoverySheet(
                        context,
                        appContext: appContext,
                        onOpenHandoff: onOpenHandoff,
                      ),
                    ),
                    _SettingsRow(
                      key: const ValueKey('profile-notifications-action'),
                      icon: Icons.notifications_none_rounded,
                      title: 'Уведомления',
                      value: 'События',
                      onTap: () => _showInfoSheet(
                        context,
                        title: 'Уведомления',
                        lines: const [
                          'Здесь будут важные сообщения о доступе, оплате и обновлениях.',
                        ],
                      ),
                    ),
                    _SettingsRow(
                      key: const ValueKey('profile-section-advanced'),
                      icon: Icons.tune_rounded,
                      title: 'Диагностика',
                      value: _pokrovAppVersion,
                      onTap: () => _showAdvancedSettingsSheet(context),
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
                    if (bonusSummary == null && bonusSummaryBusy)
                      const _MotionSkeletonList(
                        key: ValueKey('rewards-skeleton-summary'),
                        rows: 3,
                      ),
                    _SettingsRow(
                      key: const ValueKey('profile-telegram-check-action'),
                      icon: Icons.fact_check_outlined,
                      title: 'Проверить Telegram',
                      value: telegramBonusBusy ? 'Проверяем' : 'Канал',
                      onTap: telegramBonusBusy ? null : onCheckTelegramBonus,
                    ),
                    _SettingsRow(
                      key: const ValueKey('profile-telegram-claim-action'),
                      icon: Icons.send_outlined,
                      title:
                          'Telegram +${appContext.runtimeProfile.telegramBonusDays} дней',
                      value: telegramBonusCanClaim ? 'Получить' : 'Проверить',
                      onTap: telegramBonusBusy
                          ? null
                          : telegramBonusCanClaim
                              ? onClaimTelegramBonus
                              : onCheckTelegramBonus,
                    ),
                    _SettingsRow(
                      key: const ValueKey('profile-bonus-wheel-action'),
                      icon: Icons.auto_awesome_outlined,
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
                    _SettingsRow(
                      key: const ValueKey('profile-bonus-summary-refresh'),
                      icon: Icons.refresh_rounded,
                      title: 'Обновить',
                      value: bonusSummaryBusy ? 'Секунду' : 'Сводка',
                      onTap: bonusSummaryBusy ? null : onRefreshBonusSummary,
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
            final compact = constraints.maxWidth < 430;
            final identity = Row(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: _SeedPalette.surface.withValues(alpha: 0.86),
                    shape: BoxShape.circle,
                    border: Border.all(color: _SeedPalette.line),
                  ),
                  child: const Center(child: _BrandMark(size: 50)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Анонимный пользователь',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: _SeedPalette.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        poolLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _SeedPalette.muted,
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
            final progress = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: 0.42,
                    backgroundColor: _SeedPalette.ink.withValues(alpha: 0.10),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        _SeedPalette.accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  accessLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _SeedPalette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 18),
                  progress,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 18),
                progress,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ProfileMiniAction(
              icon: Icons.info_outline_rounded,
              label: 'Статус',
              value: statusLabel,
              onTap: onStatusTap,
            ),
            _ProfileMiniAction(
              key: const ValueKey('profile-plan-details-action'),
              icon: Icons.workspace_premium_outlined,
              label: 'Подписка',
              value: accessValue,
              onTap: onPlanTap,
            ),
            _ProfileMiniAction(
              key: const ValueKey('profile-checkout-action'),
              icon: Icons.shopping_bag_outlined,
              label: 'Оплата',
              value: 'Продлить',
              onTap: onCheckoutTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileMiniAction extends StatelessWidget {
  const _ProfileMiniAction({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PokrovSettingsRowPressSurface(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 132),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _SeedPalette.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _SeedPalette.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: _SeedPalette.accent),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _SeedPalette.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _SeedPalette.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileQuickActionsGrid extends StatelessWidget {
  const _ProfileQuickActionsGrid({
    required this.children,
    this.footer,
  });

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 360 ? 2 : 1;
        final tiles = <Widget>[];
        for (final child in children) {
          tiles.add(child);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 1 ? 5.2 : 3.7,
              children: tiles,
            ),
            if (footer != null) ...[
              const SizedBox(height: 10),
              footer!,
            ],
          ],
        );
      },
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _SeedPalette.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: _SeedPalette.accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _SeedPalette.muted,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: _SeedPalette.ink.withValues(alpha: 0.32),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return PokrovSettingsRowPressSurface(onTap: onTap!, child: content);
  }
}

void _showSubscriptionSheet(
  BuildContext context, {
  required SeedAppContext appContext,
  required bool hasProvisionedAccess,
  required void Function(String label, String value) onOpenHandoff,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: _SeedPalette.surface,
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasProvisionedAccess
                  ? 'Доступ активен. Продление открывается на защищенной странице оплаты.'
                  : 'Сначала подготовьте устройство, затем продлите доступ через защищенную оплату.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _SeedPalette.ink.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 16),
            _KeyValueLine(
              label: 'Текущий доступ',
              value: appContext.accessLane.label,
            ),
            _KeyValueLine(
              label: 'Устройство',
              value: appContext.hostPlatform.label,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  key: const ValueKey('subscription-checkout-primary'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenHandoff('checkout', appContext.checkoutUrl);
                  },
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Перейти к оплате'),
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
    backgroundColor: _SeedPalette.surface,
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Email нужен для восстановления доступа и входа в кабинет. Все действия открываются через короткую защищенную сессию.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _SeedPalette.ink.withValues(alpha: 0.72),
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
