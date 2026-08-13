part of pokrov_app_shell;

String _rewardShortDateTime(String value) {
  final parsed = DateTime.tryParse(value.trim())?.toLocal();
  if (parsed == null) {
    return value.trim();
  }
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(parsed.day)}.${two(parsed.month)} в '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

void _showRewardsHubSheet(
  BuildContext context, {
  required AppFirstBonusSummary? Function() summary,
  required bool Function() rewardBusy,
  required bool paidRequired,
  required Future<void> Function() onRefreshBonusSummary,
  required Future<AppFirstBonusRewardResult?> Function() onSpinWheel,
  required VoidCallback onCheckInCalendar,
  required void Function(String label, String value) onOpenHandoff,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (context) => _RewardsHubSheet(
      summaryGetter: summary,
      rewardBusyGetter: rewardBusy,
      paidRequired: paidRequired,
      onRefreshBonusSummary: onRefreshBonusSummary,
      onSpinWheel: onSpinWheel,
      onCheckInCalendar: onCheckInCalendar,
      onOpenHandoff: onOpenHandoff,
    ),
  );
}

class _RewardsHubSheet extends StatefulWidget {
  const _RewardsHubSheet({
    required this.summaryGetter,
    required this.rewardBusyGetter,
    required this.paidRequired,
    required this.onRefreshBonusSummary,
    required this.onSpinWheel,
    required this.onCheckInCalendar,
    required this.onOpenHandoff,
  });

  final AppFirstBonusSummary? Function() summaryGetter;
  final bool Function() rewardBusyGetter;
  final bool paidRequired;
  final Future<void> Function() onRefreshBonusSummary;
  final Future<AppFirstBonusRewardResult?> Function() onSpinWheel;
  final VoidCallback onCheckInCalendar;
  final void Function(String label, String value) onOpenHandoff;

  @override
  State<_RewardsHubSheet> createState() => _RewardsHubSheetState();
}

class _RewardsHubSheetState extends State<_RewardsHubSheet> {
  bool _wheelBusy = false;
  AppFirstBonusRewardResult? _wheelResult;

  /// Awaits the real backend refresh so the pull-to-refresh spinner stays
  /// visible for the request duration, then re-reads the live summary.
  Future<void> _refresh() async {
    await widget.onRefreshBonusSummary();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _spinWheel() async {
    if (_wheelBusy) {
      return;
    }
    setState(() {
      _wheelBusy = true;
      _wheelResult = null;
    });
    final result = await widget.onSpinWheel();
    if (!mounted) {
      return;
    }
    setState(() {
      _wheelBusy = false;
      _wheelResult = result;
    });
    if (result != null) {
      PokrovHaptics.success();
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summaryGetter();
    final rewardBusy = widget.rewardBusyGetter() || _wheelBusy;
    final p = PokrovPalette.of(context);
    final wheel =
        summary?.wheelState ?? AppFirstBonusFeatureState.wheelDisabled;
    final calendar =
        summary?.calendarState ?? AppFirstBonusFeatureState.calendarDisabled;
    final referralSummary = summary == null
        ? AppFirstReferralSummary.empty
        : _rewardsReferralSummary(summary);
    final referralCode = summary?.referralCode.trim() ?? '';
    final showWheel = wheel.isVisible;
    final showCalendar = calendar.isVisible;
    final rewardAccess = summary?.rewardAccess ?? AppFirstRewardAccess.unknown;
    final paidRequired = widget.paidRequired || rewardAccess.paidRequired;
    final paidRequiredMessage = rewardAccess.message.trim().isEmpty
        ? 'В пробном периоде бонусов нет. Они откроются после первой оплаты.'
        : rewardAccess.message.trim();
    final promoSlots = summary?.promoSlots ?? AppFirstPromoSlots.empty;
    final showPromoSlots = promoSlots.visibleSlots.isNotEmpty;
    return SafeArea(
      top: false,
      // Signature-arc pull-to-refresh: same arc language as the profile list.
      child: CustomScrollView(
        key: const ValueKey('rewards-hub-sheet'),
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: true,
        slivers: [
          CupertinoSliverRefreshControl(
            key: const ValueKey('rewards-refresh-indicator'),
            onRefresh: _refresh,
            builder: _pokrovRefreshArcBuilder,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            // Box adapter, not a lazy list: the sheet is one short page and
            // its content contract (tests included) expects every card built.
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Бонусы',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Рулетка, приглашения и ваши достижения.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: p.ink.withValues(alpha: 0.72),
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 14),
                  if (summary == null && rewardBusy) ...[
                    const _MotionSkeletonList(
                      key: ValueKey('rewards-hub-loading'),
                      rows: 4,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (paidRequired) ...[
                    _RewardsAccessNotice(message: paidRequiredMessage),
                    const SizedBox(height: 12),
                  ],
                  if (showWheel) ...[
                    _RewardsFeatureCard(
                      key: const ValueKey('rewards-wheel-card'),
                      icon: Icons.casino_outlined,
                      title: 'Рулетка',
                      status: wheel.statusLabel,
                      detail: paidRequired ? '' : wheel.availabilityText,
                      lastActionAt: wheel.lastActionAt,
                      actionKey: const ValueKey('rewards-wheel-spin-action'),
                      actionLabel: rewardBusy
                          ? 'Проверяем'
                          : paidRequired
                              ? ''
                              : wheel.canRun
                                  ? 'Крутить рулетку'
                                  : wheel.statusLabel,
                      actionEnabled: wheel.canRun && !rewardBusy,
                      onAction: () => unawaited(_spinWheel()),
                    ),
                    if (_wheelResult != null) ...[
                      const SizedBox(height: 10),
                      _RewardRevealCard(result: _wheelResult!),
                    ],
                    const SizedBox(height: 12),
                  ],
                  _RewardsTelegramCard(
                    summary: summary,
                    paidRequired: paidRequired,
                    onRefreshBonusSummary: widget.onRefreshBonusSummary,
                    onOpenHandoff: widget.onOpenHandoff,
                  ),
                  const SizedBox(height: 12),
                  _RewardsReferralCard(
                    referralCode: referralCode,
                    referralSummary: referralSummary,
                    onOpenHandoff: widget.onOpenHandoff,
                  ),
                  const SizedBox(height: 12),
                  if (showPromoSlots) ...[
                    _RewardsPromoSlotsSection(
                      promoSlots: promoSlots,
                      onOpenHandoff: widget.onOpenHandoff,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _RewardsHistorySection(
                    summary: summary,
                  ),
                  const SizedBox(height: 12),
                  _RewardsAchievements(summary: summary),
                  if (showCalendar) ...[
                    const SizedBox(height: 12),
                    _RewardsFeatureCard(
                      key: const ValueKey('rewards-calendar-card'),
                      icon: Icons.calendar_month_outlined,
                      title: 'Календарь',
                      status: calendar.statusLabel,
                      detail: calendar.availabilityText,
                      lastActionAt: calendar.lastActionAt,
                      actionKey:
                          const ValueKey('rewards-calendar-checkin-action'),
                      actionLabel: rewardBusy ? 'Проверяем' : 'Отметиться',
                      actionEnabled: calendar.canRun && !rewardBusy,
                      onAction: () {
                        Navigator.of(context).maybePop();
                        widget.onCheckInCalendar();
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('rewards-refresh-action'),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      unawaited(widget.onRefreshBonusSummary());
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Обновить сводку'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardRevealCard extends StatelessWidget {
  const _RewardRevealCard({required this.result});

  final AppFirstBonusRewardResult result;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final isDiscount =
        result.rewardKind == 'discount' && result.discountPct > 0;
    final rewardLabel = isDiscount
        ? '−${result.discountPct}% на продление'
        : result.rewardDays > 0
            ? '+${ruDays(result.rewardDays)}'
            : 'Награда активирована';
    final detail = isDiscount
        ? 'Скидка сохранена для одного продления.'
        : result.rewardDays > 0
            ? 'Добавили к вашему премиум‑доступу.'
            : 'Результат сохранён в истории бонусов.';
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      key: const ValueKey('rewards-wheel-result-reveal'),
      tween: Tween<double>(begin: 0, end: 1),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: Transform.scale(
            scale: 0.94 + (0.06 * value),
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
      child: Semantics(
        liveRegion: true,
        label: 'Награда получена. $rewardLabel. $detail',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.accent.withValues(alpha: 0.24)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isDiscount
                      ? Icons.local_offer_outlined
                      : Icons.auto_awesome_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Награда ваша',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: p.accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rewardLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: p.muted,
                            height: 1.3,
                          ),
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
}

class _RewardsAccessNotice extends StatelessWidget {
  const _RewardsAccessNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Container(
      key: const ValueKey('rewards-paid-required-notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_open_rounded, color: p.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.trim().isEmpty
                  ? 'В пробном периоде бонусов нет. Они откроются после первой оплаты.'
                  : message.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: p.ink,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsTelegramCard extends StatelessWidget {
  const _RewardsTelegramCard({
    required this.summary,
    required this.paidRequired,
    required this.onRefreshBonusSummary,
    required this.onOpenHandoff,
  });

  final AppFirstBonusSummary? summary;
  final bool paidRequired;
  final Future<void> Function() onRefreshBonusSummary;
  final void Function(String label, String value) onOpenHandoff;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final claimed = (summary?.channelBonusClaimedAt ?? '').trim().isNotEmpty;
    final reportedBonusDays = summary?.channelBonusPremiumDays ?? 0;
    final bonusDays =
        claimed ? reportedBonusDays : _availableTelegramBonusDays(summary);
    final channel = (summary?.channelUsername ?? 'pokrov_vpn').trim();
    final handle = channel.isEmpty
        ? '@pokrov_vpn'
        : channel.startsWith('@')
            ? channel
            : '@$channel';
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          claimed ? 'Telegram-бонус активен' : 'Telegram +${ruDays(bonusDays)}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: p.ink,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          claimed
              ? 'Бонус уже учтен в вашем доступе.'
              : paidRequired
                  ? 'Подписка на канал.'
                  : 'Подпишитесь на канал и проверьте бонус.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: p.muted,
                height: 1.3,
              ),
        ),
        if (claimed && bonusDays > 0) ...[
          const SizedBox(height: 2),
          Text(
            '+${ruDays(bonusDays)} добавлены к доступу.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: p.muted,
                  height: 1.3,
                ),
          ),
        ],
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!paidRequired || claimed)
          OutlinedButton.icon(
            key: const ValueKey('rewards-telegram-refresh-action'),
            onPressed: () {
              Navigator.of(context).maybePop();
              unawaited(onRefreshBonusSummary());
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Проверить'),
          ),
        FilledButton.tonalIcon(
          key: const ValueKey('rewards-telegram-open-channel'),
          onPressed: () {
            Navigator.of(context).maybePop();
            onOpenHandoff('community', handle);
          },
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Открыть канал'),
        ),
      ],
    );
    return Container(
      key: const ValueKey('rewards-telegram-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.send_outlined, color: p.accent),
              ),
              const SizedBox(width: 12),
              Expanded(child: copy),
            ],
          ),
          const SizedBox(height: 12),
          actions,
        ],
      ),
    );
  }
}

class _RewardsFeatureCard extends StatelessWidget {
  const _RewardsFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    required this.detail,
    required this.lastActionAt,
    required this.actionKey,
    required this.actionLabel,
    required this.actionEnabled,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String status;
  final String detail;
  final String lastActionAt;
  final Key actionKey;
  final String actionLabel;
  final bool actionEnabled;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final lastActionLabel = _rewardShortDateTime(lastActionAt);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: p.accent, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              _StatusPill(
                label: status,
                icon: Icons.info_outline_rounded,
                tone: _SectionTone.reward,
              ),
            ],
          ),
          if (detail.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: p.ink.withValues(alpha: 0.70),
                    height: 1.32,
                  ),
            ),
          ],
          if (lastActionLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Последний раз: $lastActionLabel',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: p.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          if (actionLabel.trim().isNotEmpty) const SizedBox(height: 12),
          if (actionLabel.trim().isNotEmpty && actionEnabled)
            PokrovPressable(
              child: FilledButton.icon(
                key: actionKey,
                onPressed: () {
                  Feedback.forTap(context);
                  onAction?.call();
                },
                icon: const Icon(Icons.card_giftcard_outlined),
                label: Text(actionLabel),
              ),
            )
          else if (actionLabel.trim().isNotEmpty)
            KeyedSubtree(
              key: actionKey,
              child: Text(
                actionLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.muted,
                      height: 1.3,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardsAchievements extends StatelessWidget {
  const _RewardsAchievements({
    required this.summary,
  });

  final AppFirstBonusSummary? summary;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final remoteAchievements =
        summary?.achievementItems ?? const <AppFirstAchievementItem>[];
    final achievements = remoteAchievements.isNotEmpty
        ? remoteAchievements.take(8).toList(growable: false)
        : <AppFirstAchievementItem>[
            (const AppFirstAchievementItem(
              id: 'first_launch',
              title: 'Добро пожаловать',
              description: 'Вы запустили POKROV.',
              unlocked: false,
            )),
            (const AppFirstAchievementItem(
              id: 'telegram_bonus',
              title: 'Вместе с POKROV',
              description: 'Бонус за Telegram-канал.',
              unlocked: false,
            )),
            (const AppFirstAchievementItem(
              id: 'first_referral',
              title: 'Первый друг',
              description: 'Друг оплатил приглашение.',
              unlocked: false,
            )),
          ];
    return Container(
      key: const ValueKey('rewards-achievements-section'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Достижения',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < achievements.length; index += 1)
                    SizedBox(
                      width: cardWidth,
                      child: _AchievementCard(
                        item: achievements[index],
                        index: index,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.item, required this.index});

  final AppFirstAchievementItem item;
  final int index;

  IconData get _icon => switch (item.id) {
        'first_launch' => Icons.rocket_launch_outlined,
        'first_tunnel' => Icons.shield_outlined,
        'second_device' => Icons.devices_outlined,
        'telegram_bonus' => Icons.send_outlined,
        'first_wheel' => Icons.casino_outlined,
        'first_checkin' => Icons.event_available_outlined,
        'streak_7' => Icons.local_fire_department_outlined,
        'first_referral' => Icons.group_add_outlined,
        _ => Icons.workspace_premium_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final motion = _MotionScope.of(context);
    final duration = motion.disableAnimations
        ? Duration.zero
        : Duration(milliseconds: 320 + index * 45);
    return TweenAnimationBuilder<double>(
      key: ValueKey('achievement-${item.id}-${item.unlocked}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: item.unlocked ? Curves.easeOutBack : Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.scale(
          scale: 0.94 + (value.clamp(0, 1) * 0.06),
          child: child,
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              item.unlocked ? p.accent.withValues(alpha: 0.08) : p.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.unlocked ? p.accent.withValues(alpha: 0.20) : p.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.unlocked
                        ? p.accent.withValues(alpha: 0.13)
                        : p.surface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _icon,
                    color: item.unlocked ? p.accent : p.muted,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Icon(
                  item.unlocked
                      ? Icons.check_circle_rounded
                      : Icons.lock_outline_rounded,
                  color: item.unlocked ? p.success : p.muted,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: p.muted,
                    height: 1.25,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardsHistorySection extends StatelessWidget {
  const _RewardsHistorySection({
    required this.summary,
  });

  final AppFirstBonusSummary? summary;

  IconData _historyIcon(AppFirstBonusHistoryItem item) {
    switch (item.kind) {
      case 'telegram_channel':
        return Icons.send_outlined;
      case 'promo':
        return Icons.card_giftcard_outlined;
      case 'opening_bonus':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  String _historyValue(AppFirstBonusHistoryItem item) {
    if (item.days > 0) {
      return '+${ruDays(item.days)}';
    }
    return item.compactValue;
  }

  @override
  Widget build(BuildContext context) {
    final items = summary?.historyItems ?? const <AppFirstBonusHistoryItem>[];
    final p = PokrovPalette.of(context);
    return Container(
      key: const ValueKey('rewards-history-section'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'История',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'Пока пусто.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: p.muted,
                    height: 1.35,
                  ),
            )
          else
            for (final entry in items.indexed)
              _SettingsRow(
                key: ValueKey('rewards-history-item-${entry.$1}'),
                icon: _historyIcon(entry.$2),
                title: entry.$2.title,
                value: _historyValue(entry.$2),
              ),
        ],
      ),
    );
  }
}

class _RewardsPromoSlotsSection extends StatelessWidget {
  const _RewardsPromoSlotsSection({
    required this.promoSlots,
    required this.onOpenHandoff,
  });

  final AppFirstPromoSlots promoSlots;
  final void Function(String label, String value) onOpenHandoff;

  @override
  Widget build(BuildContext context) {
    final slots = promoSlots.visibleSlots;
    final p = PokrovPalette.of(context);
    return Container(
      key: const ValueKey('rewards-promo-slots-section'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                color: p.accent,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Акции',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              _StatusPill(
                label: promoSlots.remoteAvailable ? 'Обновлено' : 'Нет акций',
                icon: Icons.verified_outlined,
                tone: promoSlots.remoteAvailable
                    ? _SectionTone.accent
                    : _SectionTone.muted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...slots.map(
            (slot) => _RewardsPromoSlotRow(
              key: ValueKey('rewards-promo-slot-${slot.slotId}'),
              slot: slot,
              onOpenHandoff: onOpenHandoff,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsPromoSlotRow extends StatelessWidget {
  const _RewardsPromoSlotRow({
    super.key,
    required this.slot,
    required this.onOpenHandoff,
  });

  final AppFirstPromoSlot slot;
  final void Function(String label, String value) onOpenHandoff;

  @override
  Widget build(BuildContext context) {
    final safeHref = _safePromoSlotHref(slot.ctaHref);
    final ctaLabel = slot.ctaLabel.trim().isEmpty ? 'Открыть' : slot.ctaLabel;
    final p = PokrovPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.title.trim().isEmpty ? 'POKROV' : slot.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (slot.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    slot.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: p.muted,
                          height: 1.3,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            key: ValueKey('rewards-promo-slot-cta-${slot.slotId}'),
            onPressed: safeHref == null
                ? null
                : () {
                    Navigator.of(context).maybePop();
                    onOpenHandoff('download', safeHref.toString());
                  },
            child: Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}

Uri? _safePromoSlotHref(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'tg') {
    return null;
  }
  if (scheme == 'tg') {
    return uri;
  }
  final host = uri.host.toLowerCase();
  if (host == 't.me' ||
      host == 'pokrov.space' ||
      host.endsWith('.pokrov.space')) {
    return uri;
  }
  return null;
}

class _RewardsReferralCard extends StatefulWidget {
  const _RewardsReferralCard({
    required this.referralCode,
    required this.referralSummary,
    required this.onOpenHandoff,
  });

  final String referralCode;
  final AppFirstReferralSummary referralSummary;
  final void Function(String label, String value) onOpenHandoff;

  @override
  State<_RewardsReferralCard> createState() => _RewardsReferralCardState();
}

class _RewardsReferralCardState extends State<_RewardsReferralCard> {
  static const _copiedHold = Duration(milliseconds: 1600);

  bool _codeCopied = false;
  bool _linkCopied = false;
  Timer? _codeCopiedTimer;
  Timer? _linkCopiedTimer;

  @override
  void dispose() {
    _codeCopiedTimer?.cancel();
    _linkCopiedTimer?.cancel();
    super.dispose();
  }

  /// Confirms the copy inside the open sheet: the copy icon morphs into a
  /// check for a moment instead of a snack hidden under the sheet.
  void _flashCopied({required bool link}) {
    PokrovHaptics.tap();
    setState(() {
      if (link) {
        _linkCopied = true;
      } else {
        _codeCopied = true;
      }
    });
    final timer = Timer(_copiedHold, () {
      if (!mounted) {
        return;
      }
      setState(() {
        if (link) {
          _linkCopied = false;
        } else {
          _codeCopied = false;
        }
      });
    });
    if (link) {
      _linkCopiedTimer?.cancel();
      _linkCopiedTimer = timer;
    } else {
      _codeCopiedTimer?.cancel();
      _codeCopiedTimer = timer;
    }
  }

  Widget _copyMorphIcon({required bool copied, required IconData idleIcon}) {
    final motion = _MotionScope.of(context);
    return AnimatedSwitcher(
      duration: motion.duration(PokrovMotionTokens.quick),
      switchInCurve: PokrovMotionTokens.spring,
      switchOutCurve: PokrovMotionTokens.ease,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: Icon(
        copied ? Icons.check_rounded : idleIcon,
        key: ValueKey(copied),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final code = widget.referralSummary.code.trim().isNotEmpty
        ? widget.referralSummary.code.trim()
        : widget.referralCode.isEmpty
            ? 'POKROV'
            : widget.referralCode;
    final referralShareLink = widget.referralSummary.shareLink.trim().isNotEmpty
        ? widget.referralSummary.shareLink
        : code == 'POKROV'
            ? ''
            : 'https://t.me/pokrov_vpnbot?start=ref_$code';
    final shareLink = _safeReferralShareHref(referralShareLink);
    return Container(
      key: const ValueKey('rewards-referral-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // Reward feature wears the reward tint — warning amber means trouble.
        color: p.reward.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.reward.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_add_outlined, color: p.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      widget.referralSummary.bonusDays > 0
                          ? '+${ruDays(widget.referralSummary.bonusDays)} после первой оплаты друга · приглашений: ${widget.referralSummary.count}'
                          : 'Приглашений: ${widget.referralSummary.count}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: p.muted,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.referralSummary.conversion.invited > 0 ||
              widget.referralSummary.history.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: p.line),
            const SizedBox(height: 12),
            Text(
              'Конверсия',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ReferralMetric(
                  label: 'Приглашено',
                  value: widget.referralSummary.conversion.invited,
                ),
                _ReferralMetric(
                  label: 'Оплатили',
                  value: widget.referralSummary.conversion.paid,
                ),
                _ReferralMetric(
                  label: 'Начислено',
                  value: widget.referralSummary.conversion.rewarded,
                ),
              ],
            ),
            if (widget.referralSummary.history.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Последние приглашения',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              for (final item in widget.referralSummary.history.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _referralStatusIcon(item.status),
                        color: item.status == 'rewarded' ? p.success : p.muted,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _referralStatusLabel(item.status),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: p.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      Text(
                        _shortReferralDate(item.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: p.muted,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 6),
            Text(
              widget.referralSummary.privacy.trim().isEmpty
                  ? 'Имена и аккаунты приглашённых не показываются.'
                  : widget.referralSummary.privacy,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: p.muted,
                    height: 1.3,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          // Actions live on their own wrapping row so the card survives
          // 320pt widths instead of overflowing a single crowded line.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('rewards-referral-copy-action'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  _flashCopied(link: false);
                },
                icon: _copyMorphIcon(
                  copied: _codeCopied,
                  idleIcon: Icons.copy_rounded,
                ),
                label: const Text('Скопировать'),
              ),
              IconButton.outlined(
                key: const ValueKey('rewards-referral-copy-link-action'),
                tooltip: 'Скопировать ссылку',
                onPressed: shareLink == null
                    ? null
                    : () {
                        Clipboard.setData(
                          ClipboardData(text: shareLink.toString()),
                        );
                        _flashCopied(link: true);
                      },
                icon: _copyMorphIcon(
                  copied: _linkCopied,
                  idleIcon: Icons.link_rounded,
                ),
              ),
              IconButton.filled(
                key: const ValueKey('rewards-referral-share-action'),
                tooltip: 'Открыть ссылку',
                onPressed: shareLink == null
                    ? null
                    : () =>
                        widget.onOpenHandoff('download', shareLink.toString()),
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferralMetric extends StatelessWidget {
  const _ReferralMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: p.muted,
                ),
          ),
        ],
      ),
    );
  }
}

String _referralStatusLabel(String value) => switch (value) {
      'activated' => 'Активировал доступ',
      'hold' => 'Оплата на проверке',
      'paid' => 'Оплата подтверждена',
      'rewarded' => 'Бонус начислен',
      'review' => 'Требует проверки',
      _ => 'Перешёл по приглашению',
    };

IconData _referralStatusIcon(String value) => switch (value) {
      'rewarded' => Icons.check_circle_rounded,
      'paid' || 'hold' => Icons.payments_outlined,
      'activated' => Icons.person_add_alt_1_rounded,
      'review' => Icons.schedule_rounded,
      _ => Icons.link_rounded,
    };

String _shortReferralDate(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) {
    return '';
  }
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day.$month';
}

AppFirstReferralSummary _rewardsReferralSummary(AppFirstBonusSummary summary) {
  final remote = summary.referralSummary;
  if (remote.code.trim().isNotEmpty ||
      remote.link.trim().isNotEmpty ||
      remote.count > 0 ||
      remote.bonusDays > 0) {
    return remote;
  }
  return AppFirstReferralSummary(
    count: summary.referralCount,
    code: summary.referralCode,
    link: '',
    bonusDays: summary.referralBonusDays,
    tierKey: summary.tierKey,
    tierPercent: summary.tierPercent,
    paidReferrals: summary.paidReferrals,
    nextTierKey: summary.nextTierKey,
    nextTierAt: summary.nextTierAt,
  );
}

Uri? _safeReferralShareHref(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'tg') {
    return uri;
  }
  if (scheme != 'https') {
    return null;
  }
  if (uri.host.toLowerCase() != 't.me') {
    return null;
  }
  return uri;
}
