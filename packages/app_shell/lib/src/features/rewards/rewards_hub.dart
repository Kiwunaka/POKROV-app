part of pokrov_app_shell;

void _showRewardsHubSheet(
  BuildContext context, {
  required AppFirstBonusSummary? Function() summary,
  required bool Function() rewardBusy,
  required bool paidRequired,
  required Future<void> Function() onRefreshBonusSummary,
  required Future<AppFirstBonusRewardResult?> Function() onSpinWheel,
  required VoidCallback onCheckInCalendar,
  required VoidCallback? onTelegramBonus,
  required void Function(String label, String value) onOpenHandoff,
  required void Function(AppFirstPromoSlot slot, String eventName) onPromoEvent,
}) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (context) => _RewardsHubSheet(
      summaryGetter: summary, rewardBusyGetter: rewardBusy, paidRequired: paidRequired,
      onRefreshBonusSummary: onRefreshBonusSummary, onSpinWheel: onSpinWheel,
      onTelegramBonus: onTelegramBonus,
      onCheckInCalendar: onCheckInCalendar, onOpenHandoff: onOpenHandoff, onPromoEvent: onPromoEvent,
    ),
  ));
}

class _RewardsHubSheet extends StatefulWidget {
  const _RewardsHubSheet({
    required this.summaryGetter,
    required this.rewardBusyGetter,
    required this.paidRequired,
    required this.onRefreshBonusSummary,
    required this.onSpinWheel,
    required this.onCheckInCalendar,
    required this.onTelegramBonus,
    required this.onOpenHandoff,
    required this.onPromoEvent,
  });

  final AppFirstBonusSummary? Function() summaryGetter;
  final bool Function() rewardBusyGetter;
  final bool paidRequired;
  final Future<void> Function() onRefreshBonusSummary;
  final Future<AppFirstBonusRewardResult?> Function() onSpinWheel;
  final VoidCallback onCheckInCalendar;
  final VoidCallback? onTelegramBonus;
  final void Function(String label, String value) onOpenHandoff;
  final void Function(AppFirstPromoSlot slot, String eventName) onPromoEvent;

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

  void _details(Widget child) => ui.showPokrovSheet<void>(context,
    (context) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: child));

  @override
  Widget build(BuildContext context) {
    final summary = widget.summaryGetter();
    final busy = widget.rewardBusyGetter() || _wheelBusy;
    final paidRequired = widget.paidRequired || (summary?.rewardAccess.paidRequired ?? true);
    final wheel = summary?.wheelState ?? AppFirstBonusFeatureState.wheelDisabled;
    final calendar = summary?.calendarState ?? AppFirstBonusFeatureState.calendarDisabled;
    final history = summary?.historyItems ?? const <AppFirstBonusHistoryItem>[];
    final total = history.fold<int>(0, (sum, item) => sum + math.max(0, item.days));
    final result = _wheelResult;
    return ui.BonusesScreen(
      data: ui.BonusesViewData(
        total: history.isEmpty ? '—' : '+' + total.toString(),
        totalCaption: history.isEmpty ? 'История пока пуста' : 'дней в истории',
        breakdown: 'Подтверждённые бонусы',
        notice: result != null ? result.rewardKind == 'discount' && result.discountPct > 0
            ? 'Скидка ' + result.discountPct.toString() + '% на продление'
            : result.rewardDays > 0 ? 'Добавлено: ' + ruDays(result.rewardDays) : 'Результат сохранён в истории.'
            : busy ? 'Обновляем бонусы…' : null,
        items: [
          if (summary != null) ui.BonusItem(id: 'telegram', title: 'Telegram',
            subtitle: summary.channelBonusClaimed ? 'Бонус получен' : _telegramBonusHomeLabel(summary),
            state: summary.channelBonusClaimed ? ui.BonusState.done : ui.BonusState.available),
          ui.BonusItem(id: 'referral', title: 'Пригласить друга',
            subtitle: paidRequired ? 'Откроется после первой оплаты' : 'Поделиться приглашением',
            state: paidRequired ? ui.BonusState.locked : ui.BonusState.available),
          if (wheel.isVisible) ui.BonusItem(id: 'wheel', title: 'Рулетка',
            subtitle: paidRequired ? 'После первой оплаты' : wheel.availabilityText,
            state: !paidRequired && wheel.canRun ? ui.BonusState.available : ui.BonusState.locked,
            actionable: !paidRequired && wheel.canRun && !busy),
          if (calendar.isVisible) ui.BonusItem(id: 'calendar', title: 'Календарь',
            subtitle: calendar.availabilityText,
            state: calendar.canRun ? ui.BonusState.available : ui.BonusState.locked,
            actionable: calendar.canRun && !busy),
          if (summary?.promoSlots.visibleForPlacement('rewards').isNotEmpty ?? false)
            const ui.BonusItem(id: 'promos', title: 'Акции', subtitle: 'Предложения для тебя', state: ui.BonusState.available),
          const ui.BonusItem(id: 'history', title: 'История бонусов', subtitle: 'Все начисления', state: ui.BonusState.available),
        ],
        achievements: [for (final item in summary?.achievementItems ?? const <AppFirstAchievementItem>[])
          ui.Achievement(item.title, earned: item.unlocked)],
      ),
      onBack: () => Navigator.of(context).maybePop(),
      onRefresh: busy ? null : () => unawaited(_refresh()),
      onItem: (item) {
        switch(item.id) {
          case 'wheel': unawaited(_spinWheel());
          case 'calendar': widget.onCheckInCalendar();
          case 'telegram': _details(_RewardsTelegramCard(summary: summary,
              onTelegramBonus: widget.onTelegramBonus, onOpenHandoff: widget.onOpenHandoff));
          case 'referral': _details(_RewardsReferralCard(referralCode: summary?.referralCode ?? '',
              referralSummary: summary == null ? AppFirstReferralSummary.empty : _rewardsReferralSummary(summary),
              paidRequired: paidRequired, onOpenHandoff: widget.onOpenHandoff));
          case 'history': _details(_RewardsHistorySection(summary: summary));
          case 'promos': _details(_RewardsPromoSlotsSection(promoSlots: summary!.promoSlots,
              onOpenHandoff: widget.onOpenHandoff, onPromoEvent: widget.onPromoEvent));
        }
      },
    );
  }
}

class _RewardsTelegramCard extends StatelessWidget {
  const _RewardsTelegramCard({
    required this.summary,
    required this.onTelegramBonus,
    required this.onOpenHandoff,
  });

  final AppFirstBonusSummary? summary;
  final VoidCallback? onTelegramBonus;
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
              ? 'Бонус уже учтён в твоём доступе.'
              : 'Подпишись на канал и проверь бонус — оплата не нужна.',
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
        if (!claimed && onTelegramBonus != null) OutlinedButton.icon(
          key: const ValueKey('rewards-telegram-refresh-action'),
          onPressed: () {
            Navigator.of(context).maybePop();
            onTelegramBonus!();
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
    required this.onPromoEvent,
  });

  final AppFirstPromoSlots promoSlots;
  final void Function(String label, String value) onOpenHandoff;
  final void Function(AppFirstPromoSlot slot, String eventName) onPromoEvent;

  @override
  Widget build(BuildContext context) {
    final slots = promoSlots.visibleForPlacement('rewards');
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
            (slot) => Padding(
              key: ValueKey('rewards-promo-slot-${slot.slotId}'),
              padding: const EdgeInsets.only(top: 10),
              child: _HomeAdminPromoCard(
                slot: slot,
                keyPrefix: 'rewards-promo-slot-${slot.slotId}',
                onOpenHandoff: (label, value) {
                  Navigator.of(context).maybePop();
                  onOpenHandoff(label, value);
                },
                onPromoEvent: onPromoEvent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsReferralCard extends StatefulWidget {
  const _RewardsReferralCard({
    required this.referralCode,
    required this.referralSummary,
    required this.paidRequired,
    required this.onOpenHandoff,
  });

  final String referralCode;
  final AppFirstReferralSummary referralSummary;
  final bool paidRequired;
  final void Function(String label, String value) onOpenHandoff;

  @override
  State<_RewardsReferralCard> createState() => _RewardsReferralCardState();
}

class _RewardsReferralCardState extends State<_RewardsReferralCard> {
  static const _copiedHold = Duration(milliseconds: 1600);

  bool _linkCopied = false;
  Timer? _linkCopiedTimer;

  @override
  void dispose() {
    _linkCopiedTimer?.cancel();
    super.dispose();
  }

  /// Confirms the copy inside the open sheet: the copy icon morphs into a
  /// check for a moment instead of a snack hidden under the sheet.
  void _flashCopied() {
    PokrovHaptics.tap();
    setState(() => _linkCopied = true);
    final timer = Timer(_copiedHold, () {
      if (!mounted) {
        return;
      }
      setState(() => _linkCopied = false);
    });
    _linkCopiedTimer?.cancel();
    _linkCopiedTimer = timer;
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
    final rawCode = widget.referralSummary.code.trim().isNotEmpty
        ? widget.referralSummary.code.trim()
        : widget.referralCode.trim();
    final code = rawCode == 'POKROV' ? '' : rawCode;
    final referralShareLink = widget.referralSummary.shareLink.trim().isNotEmpty
        ? widget.referralSummary.shareLink
        : code.isEmpty
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
                      'Пригласить друга',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      widget.paidRequired
                          ? 'Откроется после первой оплаты.'
                          : widget.referralSummary.bonusDays > 0
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
          if (widget.paidRequired || shareLink == null) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('rewards-referral-unavailable'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: p.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.paidRequired
                        ? Icons.lock_outline_rounded
                        : Icons.sync_rounded,
                    color: p.muted,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.paidRequired
                          ? 'Ссылка появится автоматически после первой оплаты.'
                          : 'Ссылка пока не готова. Нажмите «Обновить сводку».',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: p.muted,
                            height: 1.3,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!widget.paidRequired && shareLink != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('rewards-referral-share-action'),
                  onPressed: () =>
                      widget.onOpenHandoff('download', shareLink.toString()),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Пригласить'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('rewards-referral-copy-action'),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: shareLink.toString()),
                    );
                    _flashCopied();
                  },
                  icon: _copyMorphIcon(
                    copied: _linkCopied,
                    idleIcon: Icons.link_rounded,
                  ),
                  label: const Text('Скопировать ссылку'),
                ),
              ],
            ),
          ],
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
