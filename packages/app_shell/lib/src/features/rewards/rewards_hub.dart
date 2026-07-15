part of pokrov_app_shell;

void _showRewardsHubSheet(
  BuildContext context, {
  required AppFirstBonusSummary? Function() summary,
  required bool Function() rewardBusy,
  required Future<void> Function() onRefreshBonusSummary,
  required VoidCallback onSpinWheel,
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
    required this.onRefreshBonusSummary,
    required this.onSpinWheel,
    required this.onCheckInCalendar,
    required this.onOpenHandoff,
  });

  final AppFirstBonusSummary? Function() summaryGetter;
  final bool Function() rewardBusyGetter;
  final Future<void> Function() onRefreshBonusSummary;
  final VoidCallback onSpinWheel;
  final VoidCallback onCheckInCalendar;
  final void Function(String label, String value) onOpenHandoff;

  @override
  State<_RewardsHubSheet> createState() => _RewardsHubSheetState();
}

class _RewardsHubSheetState extends State<_RewardsHubSheet> {
  /// Awaits the real backend refresh so the pull-to-refresh spinner stays
  /// visible for the request duration, then re-reads the live summary.
  Future<void> _refresh() async {
    await widget.onRefreshBonusSummary();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summaryGetter();
    final rewardBusy = widget.rewardBusyGetter();
    final p = PokrovPalette.of(context);
    final wheel =
        summary?.wheelState ?? AppFirstBonusFeatureState.wheelDisabled;
    final calendar =
        summary?.calendarState ?? AppFirstBonusFeatureState.calendarDisabled;
    final referralSummary = summary == null
        ? AppFirstReferralSummary.empty
        : _rewardsReferralSummary(summary);
    final referralCode = summary?.referralCode.trim() ?? '';
    final showWheel = wheel.canRun;
    final showCalendar = calendar.canRun;
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
                    'Ваши дополнительные дни, промокоды и история начислений.',
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
                  _RewardsTelegramCard(
                    summary: summary,
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
                  if (showWheel || showCalendar) ...[
                    const SizedBox(height: 12),
                    _RewardsActivitiesHeader(
                      summary: summary,
                    ),
                    if (showWheel) ...[
                      const SizedBox(height: 10),
                      _RewardsFeatureCard(
                        key: const ValueKey('rewards-wheel-card'),
                        icon: Icons.card_giftcard_outlined,
                        title: 'Бонус дня',
                        status: wheel.statusLabel,
                        detail: wheel.availabilityText,
                        lastActionAt: wheel.lastActionAt,
                        actionKey: const ValueKey('rewards-wheel-spin-action'),
                        actionLabel:
                            rewardBusy ? 'Проверяем' : 'Получить бонус',
                        actionEnabled: wheel.canRun && !rewardBusy,
                        onAction: () {
                          Navigator.of(context).maybePop();
                          widget.onSpinWheel();
                        },
                      ),
                    ],
                    if (showCalendar) ...[
                      const SizedBox(height: 10),
                      _RewardsFeatureCard(
                        key: const ValueKey('rewards-calendar-card'),
                        icon: Icons.calendar_month_outlined,
                        title: 'Календарь активности',
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
                      const SizedBox(height: 12),
                      _RewardsCalendarGrid(
                        activeDays: _rewardActiveDays(summary),
                      ),
                    ],
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

class _RewardsTelegramCard extends StatelessWidget {
  const _RewardsTelegramCard({
    required this.summary,
    required this.onRefreshBonusSummary,
    required this.onOpenHandoff,
  });

  final AppFirstBonusSummary? summary;
  final Future<void> Function() onRefreshBonusSummary;
  final void Function(String label, String value) onOpenHandoff;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final bonusDays = summary?.channelBonusPremiumDays ?? 10;
    final claimed = (summary?.channelBonusClaimedAt ?? '').trim().isNotEmpty;
    final channel = (summary?.channelUsername ?? 'pokrov_vpn').trim();
    final handle = channel.isEmpty
        ? '@pokrov_vpn'
        : channel.startsWith('@')
            ? channel
            : '@$channel';
    return Container(
      key: const ValueKey('rewards-telegram-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.accent.withValues(alpha: 0.16)),
      ),
      child: Row(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  claimed
                      ? 'Telegram-бонус активен'
                      : 'Telegram +${ruDays(bonusDays)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  claimed
                      ? 'Бонус уже учтен в вашем доступе.'
                      : 'Подпишитесь на канал и проверьте бонус.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: p.muted,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('rewards-telegram-refresh-action'),
                onPressed: () {
                  Navigator.of(context).maybePop();
                  unawaited(onRefreshBonusSummary());
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Проверить'),
              ),
              IconButton.filled(
                key: const ValueKey('rewards-telegram-open-channel'),
                tooltip: 'Открыть канал',
                onPressed: () {
                  Navigator.of(context).maybePop();
                  onOpenHandoff('community', handle);
                },
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardsActivitiesHeader extends StatelessWidget {
  const _RewardsActivitiesHeader({
    required this.summary,
  });

  final AppFirstBonusSummary? summary;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Column(
      key: const ValueKey('rewards-activities-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Активности',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: p.ink,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Забирайте доступные дни и отмечайте активность в спокойном темпе.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: p.muted,
                height: 1.3,
              ),
        ),
        const SizedBox(height: 10),
        _RewardsAchievements(summary: summary),
      ],
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
          const SizedBox(height: 10),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: p.ink.withValues(alpha: 0.70),
                  height: 1.32,
                ),
          ),
          if (lastActionAt.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Последнее действие: $lastActionAt',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: p.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          if (actionEnabled)
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
          else
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

class _RewardsCalendarGrid extends StatelessWidget {
  const _RewardsCalendarGrid({
    required this.activeDays,
  });

  final int activeDays;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Container(
      key: const ValueKey('rewards-calendar-grid'),
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
            'Активность',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: 21,
            itemBuilder: (context, index) {
              final active = index < activeDays;
              return Container(
                key: ValueKey('rewards-calendar-day-$index'),
                decoration: BoxDecoration(
                  color: active
                      ? p.accent.withValues(alpha: 0.16)
                      : p.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? p.accent.withValues(alpha: 0.22) : p.line,
                  ),
                ),
              );
            },
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
    final achievements = <({String title, bool active})>[
      (title: 'Первый старт', active: summary?.openingBonusClaimed ?? false),
      (title: 'Telegram', active: summary?.channelBonusClaimed ?? false),
      (title: 'Рефералы', active: (summary?.referralCount ?? 0) > 0),
      (title: 'Серия', active: (summary?.streakMonths ?? 0) > 0),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: achievements
                .map(
                  (achievement) => _StatusPill(
                    label: achievement.title,
                    icon: achievement.active
                        ? Icons.check_circle_rounded
                        : Icons.lock_clock_outlined,
                    tone: achievement.active
                        ? _SectionTone.accent
                        : _SectionTone.muted,
                  ),
                )
                .toList(growable: false),
          ),
        ],
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
                          ? 'Приглашений: ${widget.referralSummary.count} · бонус +${ruDays(widget.referralSummary.bonusDays)}'
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

int _rewardActiveDays(AppFirstBonusSummary? summary) {
  if (summary == null) {
    return 0;
  }
  final historyDays = summary.historyItems.length;
  final streakDays = summary.streakMonths * 3;
  return (historyDays + streakDays).clamp(0, 21);
}
