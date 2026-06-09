part of pokrov_app_shell;

void _showRewardsHubSheet(
  BuildContext context, {
  required AppFirstBonusSummary? summary,
  required bool rewardBusy,
  required VoidCallback onRefreshBonusSummary,
  required VoidCallback onSpinWheel,
  required VoidCallback onCheckInCalendar,
  required void Function(String label, String value) onOpenHandoff,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: _SeedPalette.surface,
    isScrollControlled: true,
    builder: (context) => _RewardsHubSheet(
      summary: summary,
      rewardBusy: rewardBusy,
      onRefreshBonusSummary: onRefreshBonusSummary,
      onSpinWheel: onSpinWheel,
      onCheckInCalendar: onCheckInCalendar,
      onOpenHandoff: onOpenHandoff,
    ),
  );
}

class _RewardsHubSheet extends StatelessWidget {
  const _RewardsHubSheet({
    required this.summary,
    required this.rewardBusy,
    required this.onRefreshBonusSummary,
    required this.onSpinWheel,
    required this.onCheckInCalendar,
    required this.onOpenHandoff,
  });

  final AppFirstBonusSummary? summary;
  final bool rewardBusy;
  final VoidCallback onRefreshBonusSummary;
  final VoidCallback onSpinWheel;
  final VoidCallback onCheckInCalendar;
  final void Function(String label, String value) onOpenHandoff;

  @override
  Widget build(BuildContext context) {
    final wheel =
        summary?.wheelState ?? AppFirstBonusFeatureState.wheelDisabled;
    final calendar =
        summary?.calendarState ?? AppFirstBonusFeatureState.calendarDisabled;
    final referralSummary = summary == null
        ? AppFirstReferralSummary.empty
        : _rewardsReferralSummary(summary!);
    final referralCode = summary?.referralCode.trim() ?? '';
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('rewards-hub-sheet'),
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Бонусы',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Здесь собраны ваши бонусы, история и доступные акции.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _SeedPalette.ink.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 14),
            _RewardsReferralCard(
              referralCode: referralCode,
              referralSummary: referralSummary,
              onOpenHandoff: onOpenHandoff,
            ),
            const SizedBox(height: 12),
            _RewardsPromoSlotsSection(
              promoSlots: summary?.promoSlots ?? AppFirstPromoSlots.empty,
              onOpenHandoff: onOpenHandoff,
            ),
            const SizedBox(height: 12),
            _RewardsHistorySection(
              summary: summary,
            ),
            const SizedBox(height: 12),
            _RewardsAchievements(
              summary: summary,
            ),
            const SizedBox(height: 12),
            _RewardsFeatureCard(
              key: const ValueKey('rewards-wheel-card'),
              icon: Icons.casino_outlined,
              title: 'Рулетка',
              status: wheel.statusLabel,
              detail: wheel.availabilityText,
              lastActionAt: wheel.lastActionAt,
              actionKey: const ValueKey('rewards-wheel-spin-action'),
              mutedKey: const ValueKey('rewards-wheel-muted-state'),
              actionLabel: rewardBusy
                  ? 'Проверяем'
                  : wheel.canRun
                      ? 'Крутить'
                      : 'Отключено',
              actionEnabled: wheel.canRun && !rewardBusy,
              onAction: () {
                Navigator.of(context).pop();
                onSpinWheel();
              },
            ),
            const SizedBox(height: 10),
            _RewardsFeatureCard(
              key: const ValueKey('rewards-calendar-card'),
              icon: Icons.calendar_month_outlined,
              title: 'Календарь активности',
              status: calendar.statusLabel,
              detail: calendar.availabilityText,
              lastActionAt: calendar.lastActionAt,
              actionKey: const ValueKey('rewards-calendar-checkin-action'),
              mutedKey: const ValueKey('rewards-calendar-muted-state'),
              actionLabel: rewardBusy
                  ? 'Проверяем'
                  : calendar.canRun
                      ? 'Отметиться'
                      : 'Отключено',
              actionEnabled: calendar.canRun && !rewardBusy,
              onAction: () {
                Navigator.of(context).pop();
                onCheckInCalendar();
              },
            ),
            const SizedBox(height: 12),
            _RewardsCalendarGrid(
              activeDays: _rewardActiveDays(summary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('rewards-refresh-action'),
              onPressed: () {
                Navigator.of(context).pop();
                onRefreshBonusSummary();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Обновить сводку'),
            ),
          ],
        ),
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
    required this.mutedKey,
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
  final Key mutedKey;
  final String actionLabel;
  final bool actionEnabled;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final inactiveReason = detail.trim().isEmpty ? status : detail;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SeedPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _SeedPalette.line),
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
                  color: _SeedPalette.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _SeedPalette.accent, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w800,
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
                  color: _SeedPalette.ink.withValues(alpha: 0.70),
                  height: 1.32,
                ),
          ),
          if (lastActionAt.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Последнее действие: $lastActionAt',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _SeedPalette.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          if (actionEnabled)
            FilledButton.icon(
              key: actionKey,
              onPressed: () {
                Feedback.forTap(context);
                onAction?.call();
              },
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(actionLabel),
            )
          else
            KeyedSubtree(
              key: actionKey,
              child: Container(
                key: mutedKey,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _SeedPalette.ink.withValues(alpha: 0.045),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _SeedPalette.line.withValues(alpha: 0.75),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_empty_rounded,
                      size: 18,
                      color: _SeedPalette.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        inactiveReason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _SeedPalette.muted,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: _SeedPalette.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
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

class _RewardsCalendarGrid extends StatelessWidget {
  const _RewardsCalendarGrid({
    required this.activeDays,
  });

  final int activeDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('rewards-calendar-grid'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SeedPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Активность',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _SeedPalette.ink,
                  fontWeight: FontWeight.w800,
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
                      ? _SeedPalette.accent.withValues(alpha: 0.16)
                      : _SeedPalette.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? _SeedPalette.accent.withValues(alpha: 0.22)
                        : _SeedPalette.line,
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
        color: _SeedPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Достижения',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _SeedPalette.ink,
                  fontWeight: FontWeight.w800,
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

  @override
  Widget build(BuildContext context) {
    final items = summary?.historyItems ?? const <AppFirstBonusHistoryItem>[];
    return Container(
      key: const ValueKey('rewards-history-section'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SeedPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'История',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _SeedPalette.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'Пока пусто.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.muted,
                    height: 1.35,
                  ),
            )
          else
            for (final entry in items.indexed)
              _SettingsRow(
                key: ValueKey('rewards-history-item-${entry.$1}'),
                icon: _historyIcon(entry.$2),
                title: entry.$2.title,
                value: entry.$2.compactValue,
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
    return Container(
      key: const ValueKey('rewards-promo-slots-section'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SeedPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_offer_outlined,
                color: _SeedPalette.accent,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Акции',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w800,
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
          if (slots.isEmpty)
            Text(
              key: const ValueKey('rewards-promo-slot-empty'),
              'Сейчас нет персональных акций. Промокод можно ввести в поле кода выше.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.muted,
                    height: 1.35,
                  ),
            )
          else
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
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _SeedPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _SeedPalette.line),
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
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (slot.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    slot.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _SeedPalette.muted,
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
                    Navigator.of(context).pop();
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

class _RewardsReferralCard extends StatelessWidget {
  const _RewardsReferralCard({
    required this.referralCode,
    required this.referralSummary,
    required this.onOpenHandoff,
  });

  final String referralCode;
  final AppFirstReferralSummary referralSummary;
  final void Function(String label, String value) onOpenHandoff;

  @override
  Widget build(BuildContext context) {
    final code = referralSummary.code.trim().isNotEmpty
        ? referralSummary.code.trim()
        : referralCode.isEmpty
            ? 'POKROV'
            : referralCode;
    final referralShareLink = referralSummary.shareLink.trim().isNotEmpty
        ? referralSummary.shareLink
        : code == 'POKROV'
            ? ''
            : 'https://t.me/pokrov_vpnbot?start=ref_$code';
    final shareLink = _safeReferralShareHref(referralShareLink);
    return Container(
      key: const ValueKey('rewards-referral-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SeedPalette.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _SeedPalette.warning.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_add_outlined, color: _SeedPalette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  referralSummary.bonusDays > 0
                      ? 'Приглашений: ${referralSummary.count} · бонус +${referralSummary.bonusDays} дней'
                      : 'Приглашений: ${referralSummary.count}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _SeedPalette.muted,
                      ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('rewards-referral-copy-action'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Код скопирован')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Копия'),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            key: const ValueKey('rewards-referral-copy-link-action'),
            tooltip: 'Скопировать ссылку',
            onPressed: shareLink == null
                ? null
                : () {
                    Clipboard.setData(
                      ClipboardData(text: shareLink.toString()),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ссылка скопирована')),
                    );
                  },
            icon: const Icon(Icons.link_rounded),
          ),
          IconButton.filled(
            key: const ValueKey('rewards-referral-share-action'),
            tooltip: 'Открыть ссылку',
            onPressed: shareLink == null
                ? null
                : () => onOpenHandoff('download', shareLink.toString()),
            icon: const Icon(Icons.ios_share_rounded),
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
