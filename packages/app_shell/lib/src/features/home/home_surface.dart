part of pokrov_app_shell;

class _QuickConnectSection extends StatelessWidget {
  const _QuickConnectSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.runtimeSnapshot,
    required this.runtimeHeadline,
    required this.runtimeBusy,
    required this.primaryConnectEnabled,
    required this.bonusSummary,
    required this.telegramBonusBusy,
    required this.warpPolicy,
    required this.warpRuntimeConsent,
    required this.warpBusy,
    required this.onToggleRuntime,
    required this.onTelegramBonus,
    required this.onOpenLocations,
    required this.onOpenRules,
    required this.onOpenWarp,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final RuntimeSnapshot? runtimeSnapshot;
  final String? runtimeHeadline;
  final bool runtimeBusy;
  final bool primaryConnectEnabled;
  final AppFirstBonusSummary? bonusSummary;
  final bool telegramBonusBusy;
  final WarpRuntimePolicy warpPolicy;
  final bool warpRuntimeConsent;
  final bool warpBusy;
  final Future<void> Function() onToggleRuntime;
  final VoidCallback? onTelegramBonus;
  final VoidCallback onOpenLocations;
  final VoidCallback onOpenRules;
  final Future<void> Function() onOpenWarp;

  @override
  Widget build(BuildContext context) {
    final snapshot = runtimeSnapshot;
    final isRunning = snapshot?.phase == RuntimePhase.running;
    final isHealthyRunning = snapshot?.isCleanlyHealthy ?? false;
    final statusLabel = _consumerProtectionStatusLabel(
      snapshot,
      busy: runtimeBusy,
    );
    final statusSummary = _consumerProtectionStatusSummary(
      snapshot,
      headline: runtimeHeadline,
      hostPlatform: appContext.hostPlatform,
    );
    final primaryActionEnabled = !runtimeBusy && primaryConnectEnabled;
    final isDesktop = switch (appContext.hostPlatform) {
      HostPlatform.windows || HostPlatform.macos => true,
      HostPlatform.android || HostPlatform.ios => false,
    };
    final statusColor = runtimeBusy
        ? _SeedPalette.warning
        : isRunning
            ? isHealthyRunning
                ? _SeedPalette.success
                : _SeedPalette.warning
            : _SeedPalette.muted;
    final actionLabel = runtimeBusy
        ? 'Подключаемся'
        : isRunning
            ? 'Отключить'
            : primaryActionEnabled
                ? 'Подключить'
                : 'Пока недоступно';
    final recoveryNotice = _motionRecoveryNotice(
      snapshot,
      headline: runtimeHeadline,
      busy: runtimeBusy,
    );

    return _SeedContentList(
      top: isDesktop ? 34 : 18,
      maxContentWidth: isDesktop ? 1220 : 900,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1220 : 460),
            child: _HomeStage(
              statusLabel: statusLabel,
              statusColor: statusColor,
              actionLabel: actionLabel,
              actionEnabled: primaryActionEnabled,
              running: isRunning,
              busy: runtimeBusy,
              degraded: isRunning && !isHealthyRunning,
              recoveryNotice: recoveryNotice,
              accessLabel: _accessMainLabel(appContext, bonusSummary),
              accessPoolLabel: _accessPoolLabel(appContext.accessLane),
              telegramBonusLabel: telegramBonusBusy
                  ? 'Проверяем Telegram'
                  : _telegramBonusHomeLabel(appContext, bonusSummary),
              telegramBonusClaimed:
                  (bonusSummary?.channelBonusClaimedAt ?? '').trim().isNotEmpty,
              selectedRouteMode: selectedRouteMode,
              locationLabel: 'Автоматически',
              warpPolicy: warpPolicy,
              warpRuntimeConsent: warpRuntimeConsent,
              warpBusy: warpBusy,
              onToggleRuntime: onToggleRuntime,
              onTelegramBonus: onTelegramBonus,
              onOpenConnectionDetails: () => _showInfoSheet(
                context,
                title: 'Подключение',
                lines: [
                  statusSummary,
                  'Доступ: ${_accessMainLabel(appContext, bonusSummary)}.',
                  'Локация: автоматический выбор.',
                  'Режим: ${_routeModeShortLabel(selectedRouteMode)}.',
                ],
              ),
              onOpenLocations: onOpenLocations,
              onOpenRules: onOpenRules,
              onOpenWarp: onOpenWarp,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeStage extends StatefulWidget {
  const _HomeStage({
    required this.statusLabel,
    required this.statusColor,
    required this.actionLabel,
    required this.actionEnabled,
    required this.running,
    required this.busy,
    required this.degraded,
    required this.recoveryNotice,
    required this.accessLabel,
    required this.accessPoolLabel,
    required this.telegramBonusLabel,
    required this.telegramBonusClaimed,
    required this.selectedRouteMode,
    required this.locationLabel,
    required this.warpPolicy,
    required this.warpRuntimeConsent,
    required this.warpBusy,
    required this.onToggleRuntime,
    required this.onTelegramBonus,
    required this.onOpenConnectionDetails,
    required this.onOpenLocations,
    required this.onOpenRules,
    required this.onOpenWarp,
  });

  final String statusLabel;
  final Color statusColor;
  final String actionLabel;
  final bool actionEnabled;
  final bool running;
  final bool busy;
  final bool degraded;
  final String? recoveryNotice;
  final String accessLabel;
  final String accessPoolLabel;
  final String telegramBonusLabel;
  final bool telegramBonusClaimed;
  final RouteMode selectedRouteMode;
  final String locationLabel;
  final WarpRuntimePolicy warpPolicy;
  final bool warpRuntimeConsent;
  final bool warpBusy;
  final Future<void> Function() onToggleRuntime;
  final VoidCallback? onTelegramBonus;
  final VoidCallback onOpenConnectionDetails;
  final VoidCallback onOpenLocations;
  final VoidCallback onOpenRules;
  final Future<void> Function() onOpenWarp;

  @override
  State<_HomeStage> createState() => _HomeStageState();
}

class _HomeStageState extends State<_HomeStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;
  bool _revealStarted = false;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: _MotionTokens.homeReveal,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = _MotionScope.of(context);
    if (motion.disableAnimations) {
      _revealController.value = 1;
      _revealStarted = true;
      return;
    }
    if (!_revealStarted) {
      _revealStarted = true;
      _revealController.forward();
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return Padding(
          key: const ValueKey('home-boot-reveal'),
          padding: EdgeInsets.symmetric(horizontal: desktop ? 0 : 4),
          child: desktop ? _buildDesktop(context) : _buildMobile(context),
        );
      },
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _HomeRevealSlice(
          controller: _revealController,
          begin: 0,
          end: 0.42,
          child: const _BrandLockup(markSize: 38, center: true),
        ),
        const SizedBox(height: 18),
        _HomeRevealSlice(
          controller: _revealController,
          begin: 0.18,
          end: 0.58,
          child: _HomeAccessStrip(
            accessLabel: widget.accessLabel,
            poolLabel: widget.accessPoolLabel,
            telegramBonusLabel: widget.telegramBonusLabel,
            telegramBonusClaimed: widget.telegramBonusClaimed,
            onTelegramBonus: widget.onTelegramBonus,
          ),
        ),
        const SizedBox(height: 20),
        _HomeRevealSlice(
          controller: _revealController,
          begin: 0.2,
          end: 0.66,
          child: _ConnectOrbButton(
            actionLabel: widget.actionLabel,
            enabled: widget.actionEnabled,
            running: widget.running,
            degraded: widget.degraded,
            error: widget.recoveryNotice != null,
            busy: widget.busy,
            onPressed: widget.actionEnabled ? widget.onToggleRuntime : null,
          ),
        ),
        const SizedBox(height: 14),
        _HomeRevealSlice(
          controller: _revealController,
          begin: 0.28,
          end: 0.78,
          child: _HomeStatusAction(
            statusLabel: widget.statusLabel,
            statusColor: widget.statusColor,
            onTap: widget.onOpenConnectionDetails,
          ),
        ),
        const SizedBox(height: 14),
        _HomeRevealSlice(
          controller: _revealController,
          begin: 0.42,
          end: 0.88,
          child: _HomeModeChips(
            locationLabel: widget.locationLabel,
            routeMode: widget.selectedRouteMode,
            onOpenLocations: widget.onOpenLocations,
            onOpenRules: widget.onOpenRules,
          ),
        ),
        const SizedBox(height: 12),
        _HomeRevealSlice(
          controller: _revealController,
          begin: 0.54,
          end: 1,
          child: _HomeWarpTile(
            policy: widget.warpPolicy,
            runtimeConsent: widget.warpRuntimeConsent,
            busy: widget.warpBusy,
            onOpen: widget.onOpenWarp,
          ),
        ),
        const SizedBox(height: 10),
        _HomeRevealSlice(
          controller: _revealController,
          begin: 0.62,
          end: 1,
          child: _HomeTelegramBonusTile(
            label: widget.telegramBonusLabel,
            claimed: widget.telegramBonusClaimed,
            onTap: widget.telegramBonusClaimed ? null : widget.onTelegramBonus,
          ),
        ),
        if (widget.recoveryNotice != null) ...[
          const SizedBox(height: 12),
          _HomeRevealSlice(
            controller: _revealController,
            begin: 0.22,
            end: 0.62,
            child: _MotionRecoveryBanner(message: widget.recoveryNotice!),
          ),
        ],
      ],
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeRevealSlice(
          controller: _revealController,
          begin: 0,
          end: 0.42,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Защита',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Подключение, правила и доступ рядом.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _SeedPalette.muted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('home-desktop-notifications-action'),
                tooltip: 'Уведомления',
                onPressed: widget.onOpenConnectionDetails,
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              IconButton(
                key: const ValueKey('home-desktop-settings-action'),
                tooltip: 'Профиль',
                onPressed: widget.onOpenRules,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: _HomeRevealSlice(
                controller: _revealController,
                begin: 0.16,
                end: 0.72,
                child: _HomeConnectPanel(
                  statusLabel: widget.statusLabel,
                  statusColor: widget.statusColor,
                  actionLabel: widget.actionLabel,
                  actionEnabled: widget.actionEnabled,
                  running: widget.running,
                  busy: widget.busy,
                  degraded: widget.degraded,
                  recoveryNotice: widget.recoveryNotice,
                  selectedRouteMode: widget.selectedRouteMode,
                  locationLabel: widget.locationLabel,
                  onToggleRuntime: widget.onToggleRuntime,
                  onOpenConnectionDetails: widget.onOpenConnectionDetails,
                  onOpenLocations: widget.onOpenLocations,
                  onOpenRules: widget.onOpenRules,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 9,
              child: Column(
                children: [
                  _HomeRevealSlice(
                    controller: _revealController,
                    begin: 0.22,
                    end: 0.76,
                    child: _HomeAccessStrip(
                      accessLabel: widget.accessLabel,
                      poolLabel: widget.accessPoolLabel,
                      telegramBonusLabel: widget.telegramBonusLabel,
                      telegramBonusClaimed: widget.telegramBonusClaimed,
                      onTelegramBonus: widget.onTelegramBonus,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HomeRevealSlice(
                    controller: _revealController,
                    begin: 0.34,
                    end: 0.84,
                    child: _HomeTelegramBonusTile(
                      label: widget.telegramBonusLabel,
                      claimed: widget.telegramBonusClaimed,
                      onTap: widget.telegramBonusClaimed
                          ? null
                          : widget.onTelegramBonus,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HomeRevealSlice(
                    controller: _revealController,
                    begin: 0.42,
                    end: 0.92,
                    child: _HomeWarpTile(
                      policy: widget.warpPolicy,
                      runtimeConsent: widget.warpRuntimeConsent,
                      busy: widget.warpBusy,
                      onOpen: widget.onOpenWarp,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HomeRevealSlice(
                    controller: _revealController,
                    begin: 0.50,
                    end: 1,
                    child: const _HomeNewsCard(),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.recoveryNotice != null) ...[
          const SizedBox(height: 14),
          _MotionRecoveryBanner(message: widget.recoveryNotice!),
        ],
      ],
    );
  }
}

class _HomeConnectPanel extends StatelessWidget {
  const _HomeConnectPanel({
    required this.statusLabel,
    required this.statusColor,
    required this.actionLabel,
    required this.actionEnabled,
    required this.running,
    required this.busy,
    required this.degraded,
    required this.recoveryNotice,
    required this.selectedRouteMode,
    required this.locationLabel,
    required this.onToggleRuntime,
    required this.onOpenConnectionDetails,
    required this.onOpenLocations,
    required this.onOpenRules,
  });

  final String statusLabel;
  final Color statusColor;
  final String actionLabel;
  final bool actionEnabled;
  final bool running;
  final bool busy;
  final bool degraded;
  final String? recoveryNotice;
  final RouteMode selectedRouteMode;
  final String locationLabel;
  final Future<void> Function() onToggleRuntime;
  final VoidCallback onOpenConnectionDetails;
  final VoidCallback onOpenLocations;
  final VoidCallback onOpenRules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('home-desktop-connect-panel'),
      constraints: const BoxConstraints(minHeight: 560),
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
      decoration: BoxDecoration(
        color: _SeedPalette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _SeedPalette.line),
        boxShadow: [
          BoxShadow(
            color: _SeedPalette.ink.withValues(alpha: 0.035),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              running ? 'POKROV включен' : 'Готово к подключению',
              style: theme.textTheme.titleLarge?.copyWith(
                color: _SeedPalette.ink,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 74),
          _ConnectOrbButton(
            actionLabel: actionLabel,
            enabled: actionEnabled,
            running: running,
            degraded: degraded,
            error: recoveryNotice != null,
            busy: busy,
            onPressed: actionEnabled ? onToggleRuntime : null,
          ),
          const SizedBox(height: 16),
          _HomeStatusAction(
            statusLabel: statusLabel,
            statusColor: statusColor,
            onTap: onOpenConnectionDetails,
          ),
          const SizedBox(height: 18),
          _HomeModeChips(
            locationLabel: locationLabel,
            routeMode: selectedRouteMode,
            onOpenLocations: onOpenLocations,
            onOpenRules: onOpenRules,
          ),
          const SizedBox(height: 54),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _SeedPalette.accent.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _SeedPalette.accent.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _SeedPalette.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: _SeedPalette.accent,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    running
                        ? 'Трафик идет по выбранным правилам POKROV.'
                        : 'Нажмите главную кнопку, когда будете готовы.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _SeedPalette.ink.withValues(alpha: 0.74),
                      height: 1.28,
                    ),
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

class _HomeStatusAction extends StatelessWidget {
  const _HomeStatusAction({
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('home-connection-details-action'),
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: _StatusDotLabel(
          label: statusLabel,
          color: statusColor,
        ),
      ),
    );
  }
}

class _HomeModeChips extends StatelessWidget {
  const _HomeModeChips({
    required this.locationLabel,
    required this.routeMode,
    required this.onOpenLocations,
    required this.onOpenRules,
  });

  final String locationLabel;
  final RouteMode routeMode;
  final VoidCallback onOpenLocations;
  final VoidCallback onOpenRules;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        _HomeChip(
          key: const ValueKey('home-location-chip'),
          icon: Icons.public_rounded,
          label: locationLabel,
          onTap: onOpenLocations,
        ),
        _HomeChip(
          key: const ValueKey('home-route-chip'),
          icon: Icons.alt_route_rounded,
          label: _routeModeShortLabel(routeMode),
          minLabelWidth: 142,
          onTap: onOpenRules,
        ),
      ],
    );
  }
}

class _HomeNewsCard extends StatelessWidget {
  const _HomeNewsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('home-news-card'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: _SeedPalette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _SeedPalette.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.article_outlined,
              color: _SeedPalette.accent,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Новости',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Важные сообщения из @pokrov_vpn появятся здесь.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.muted,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: _SeedPalette.ink.withValues(alpha: 0.34),
          ),
        ],
      ),
    );
  }
}

class _HomeAccessStrip extends StatelessWidget {
  const _HomeAccessStrip({
    required this.accessLabel,
    required this.poolLabel,
    required this.telegramBonusLabel,
    required this.telegramBonusClaimed,
    required this.onTelegramBonus,
  });

  final String accessLabel;
  final String poolLabel;
  final String telegramBonusLabel;
  final bool telegramBonusClaimed;
  final VoidCallback? onTelegramBonus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accessBadgeLabel = telegramBonusClaimed
        ? '+10 дней'
        : accessLabel.startsWith('5 ')
            ? '5 дней'
            : accessLabel.toLowerCase().contains('премиум')
                ? 'Премиум'
                : 'Активен';
    final content = Container(
      key: const ValueKey('home-access-strip'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
      decoration: BoxDecoration(
        color: _SeedPalette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _SeedPalette.line),
        boxShadow: [
          BoxShadow(
            color: _SeedPalette.ink.withValues(alpha: 0.045),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _SeedPalette.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: _SeedPalette.accent,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accessLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  poolLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _SeedPalette.muted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(
            label: accessBadgeLabel,
            icon: telegramBonusClaimed
                ? Icons.check_circle_outline_rounded
                : Icons.calendar_today_outlined,
            tone: _SectionTone.reward,
          ),
        ],
      ),
    );
    if (onTelegramBonus == null || telegramBonusClaimed) {
      return content;
    }
    return PokrovSettingsRowPressSurface(
        onTap: onTelegramBonus!, child: content);
  }
}

class _HomeTelegramBonusTile extends StatelessWidget {
  const _HomeTelegramBonusTile({
    required this.label,
    required this.claimed,
    required this.onTap,
  });

  final String label;
  final bool claimed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      key: const ValueKey('home-telegram-bonus-pill'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: claimed
            ? _SeedPalette.surface.withValues(alpha: 0.96)
            : const Color(0xFFFFF5D8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: claimed ? _SeedPalette.line : const Color(0x40B99745),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: claimed
                  ? _SeedPalette.accent.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              claimed
                  ? Icons.check_circle_outline_rounded
                  : Icons.send_outlined,
              color: _SeedPalette.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  claimed ? 'Telegram-бонус активен' : '+10 дней за Telegram',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  claimed ? label : 'Подпишитесь на канал и заберите бонус',
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
            claimed ? Icons.done_rounded : Icons.chevron_right_rounded,
            color: _SeedPalette.muted,
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

class _HomeWarpTile extends StatelessWidget {
  const _HomeWarpTile({
    required this.policy,
    required this.runtimeConsent,
    required this.busy,
    required this.onOpen,
  });

  final WarpRuntimePolicy policy;
  final bool runtimeConsent;
  final bool busy;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final lifecycle = PokrovWarpLifecycle.resolve(
      policy: policy,
      consented: runtimeConsent,
      busy: busy,
    );
    final canOffer = lifecycle.canOffer;
    final enabled = lifecycle.highlightsEnabled;
    const title = 'WARP';
    final subtitle = switch (lifecycle.phase) {
      PokrovWarpPhase.notReady => 'Проверим доступность',
      PokrovWarpPhase.readyToConsent => 'Можно включить',
      _ => lifecycle.publicStatus,
    };
    final iconColor = enabled
        ? _SeedPalette.accent
        : _SeedPalette.muted.withValues(alpha: 0.8);
    final iconBackground = enabled
        ? _SeedPalette.accent.withValues(alpha: 0.12)
        : _SeedPalette.surfaceMuted.withValues(alpha: 0.86);

    return InkWell(
      key: const ValueKey('home-warp-tile'),
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        unawaited(onOpen());
      },
      child: AnimatedContainer(
        key: ValueKey(lifecycle.stateKey),
        duration: motion.duration(_MotionTokens.short),
        curve: _MotionTokens.ease,
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: enabled
              ? _SeedPalette.accent.withValues(alpha: 0.09)
              : _SeedPalette.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: enabled
                ? _SeedPalette.accent.withValues(alpha: 0.28)
                : _SeedPalette.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                enabled ? Icons.verified_user_rounded : Icons.blur_on_rounded,
                size: 22,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _SeedPalette.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    key: const ValueKey('home-warp-status-label'),
                    duration: motion.duration(_MotionTokens.short),
                    transitionBuilder: _fadeSlideTransition,
                    child: Text(
                      subtitle,
                      key: ValueKey(subtitle),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: enabled
                                ? _SeedPalette.accent
                                : _SeedPalette.muted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _HomeWarpSwitchGlyph(
              enabled: enabled,
              busy: busy,
              muted: !canOffer,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeWarpSwitchGlyph extends StatelessWidget {
  const _HomeWarpSwitchGlyph({
    required this.enabled,
    required this.busy,
    required this.muted,
  });

  final bool enabled;
  final bool busy;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final active = enabled && !muted;
    return AnimatedContainer(
      duration: motion.duration(_MotionTokens.short),
      curve: _MotionTokens.ease,
      width: 48,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: active
            ? _SeedPalette.accent
            : _SeedPalette.ink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: motion.duration(_MotionTokens.short),
        curve: _MotionTokens.ease,
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _SeedPalette.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _SeedPalette.ink.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
      ),
    );
  }
}

class _HomeRevealSlice extends StatelessWidget {
  const _HomeRevealSlice({
    required this.controller,
    required this.begin,
    required this.end,
    required this.child,
  });

  final AnimationController controller;
  final double begin;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_MotionScope.of(context).disableAnimations) {
      return child;
    }
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(
          ((controller.value - begin) / (end - begin)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * 12),
            child: child,
          ),
        );
      },
    );
  }
}

Widget _fadeSlideTransition(Widget child, Animation<double> animation) {
  return pokrovFadeSlideTransition(child, animation);
}

class _MotionRecoveryBanner extends StatelessWidget {
  const _MotionRecoveryBanner({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    return AnimatedSwitcher(
      key: const ValueKey('motion-recovery-banner'),
      duration: motion.duration(_MotionTokens.standard),
      transitionBuilder: _fadeSlideTransition,
      child: Container(
        key: ValueKey(message),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _SeedPalette.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _SeedPalette.warning.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: _SeedPalette.warning.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _SeedPalette.ink.withValues(alpha: 0.78),
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDotLabel extends PokrovStatusDotLabel {
  const _StatusDotLabel({
    required super.label,
    required super.color,
  });
}

class _HomeChip extends PokrovHomeChip {
  const _HomeChip({
    super.key,
    required super.icon,
    required super.label,
    super.minLabelWidth,
    super.onTap,
  });
}

class _MotionSkeletonList extends PokrovSkeletonList {
  const _MotionSkeletonList({
    super.key,
    super.rows = 4,
  });
}
