part of pokrov_app_shell;

class _QuickConnectSection extends StatelessWidget {
  const _QuickConnectSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.runtimeSnapshot,
    required this.runtimeHeadline,
    required this.runtimeBusy,
    required this.primaryConnectEnabled,
    required this.connectHintVisible,
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
    required this.onWarpConsentChanged,
    required this.onOpenPromoHandoff,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final RuntimeSnapshot? runtimeSnapshot;
  final String? runtimeHeadline;
  final bool runtimeBusy;
  final bool primaryConnectEnabled;
  final bool connectHintVisible;
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
  final Future<void> Function(bool value) onWarpConsentChanged;
  final void Function(String label, String value) onOpenPromoHandoff;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final snapshot = runtimeSnapshot;
    final isRunning = snapshot?.phase == RuntimePhase.running;
    final isHealthyRunning = snapshot?.isCleanlyHealthy ?? false;
    final statusLabel = _homeProtectionStatusLabel(
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
        ? p.muted
        : isRunning
            ? isHealthyRunning
                ? p.success
                : p.warning
            : p.muted;
    final actionLabel = runtimeBusy
        ? 'Подключается…'
        : isRunning
            ? 'Отключить'
            : primaryActionEnabled
                ? 'Включить VPN'
                : 'Пока недоступно';
    final recoveryNotice = _motionRecoveryNotice(
      snapshot,
      headline: runtimeHeadline,
      busy: runtimeBusy,
    );
    final infoNotice = _homeInfoNotice(runtimeHeadline);
    final homePromoSlot = _homeAdminPromoSlot(bonusSummary);

    return _SeedContentList(
      // Mobile tabs share the 16px top gutter; the desktop stage keeps its
      // larger hero offset because it has no headline row above the disc.
      top: isDesktop ? 34 : 16,
      maxContentWidth: isDesktop ? 1220 : 900,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1220 : 460),
            child: _HomeStage(
              preferDesktopLayout: isDesktop,
              statusLabel: statusLabel,
              statusColor: statusColor,
              actionLabel: actionLabel,
              actionEnabled: primaryActionEnabled,
              running: isRunning,
              busy: runtimeBusy,
              degraded: isRunning && !isHealthyRunning,
              connectHintVisible: connectHintVisible,
              recoveryNotice: recoveryNotice,
              infoNotice: infoNotice,
              accessLabel: _accessMainLabel(appContext, bonusSummary),
              accessPoolLabel: _accessHomeSupportLabel(appContext.accessLane),
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
              homePromoSlot: homePromoSlot,
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
              onWarpConsentChanged: onWarpConsentChanged,
              onOpenPromoHandoff: onOpenPromoHandoff,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeStage extends StatefulWidget {
  const _HomeStage({
    required this.preferDesktopLayout,
    required this.statusLabel,
    required this.statusColor,
    required this.actionLabel,
    required this.actionEnabled,
    required this.running,
    required this.busy,
    required this.degraded,
    required this.connectHintVisible,
    required this.recoveryNotice,
    required this.infoNotice,
    required this.accessLabel,
    required this.accessPoolLabel,
    required this.telegramBonusLabel,
    required this.telegramBonusClaimed,
    required this.selectedRouteMode,
    required this.locationLabel,
    required this.warpPolicy,
    required this.warpRuntimeConsent,
    required this.warpBusy,
    required this.homePromoSlot,
    required this.onToggleRuntime,
    required this.onTelegramBonus,
    required this.onOpenConnectionDetails,
    required this.onOpenLocations,
    required this.onOpenRules,
    required this.onOpenWarp,
    required this.onWarpConsentChanged,
    required this.onOpenPromoHandoff,
  });

  final bool preferDesktopLayout;
  final String statusLabel;
  final Color statusColor;
  final String actionLabel;
  final bool actionEnabled;
  final bool running;
  final bool busy;
  final bool degraded;
  final bool connectHintVisible;
  final String? recoveryNotice;
  final String? infoNotice;
  final String accessLabel;
  final String accessPoolLabel;
  final String telegramBonusLabel;
  final bool telegramBonusClaimed;
  final RouteMode selectedRouteMode;
  final String locationLabel;
  final WarpRuntimePolicy warpPolicy;
  final bool warpRuntimeConsent;
  final bool warpBusy;
  final AppFirstPromoSlot? homePromoSlot;
  final Future<void> Function() onToggleRuntime;
  final VoidCallback? onTelegramBonus;
  final VoidCallback onOpenConnectionDetails;
  final VoidCallback onOpenLocations;
  final VoidCallback onOpenRules;
  final Future<void> Function() onOpenWarp;
  final Future<void> Function(bool value) onWarpConsentChanged;
  final void Function(String label, String value) onOpenPromoHandoff;

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

  /// The one-time hint only makes sense while the disc is idle and the
  /// primary connect action is actually available.
  bool get _showConnectHint =>
      widget.connectHintVisible &&
      widget.actionEnabled &&
      !widget.running &&
      !widget.busy &&
      !widget.degraded &&
      widget.recoveryNotice == null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = widget.preferDesktopLayout
            ? constraints.maxWidth >= 720
            : constraints.maxWidth >= 900;
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
          // Access is stated once per screen: _HomeAccessStrip below owns
          // the label, so the brand header is a pure lockup.
          child: _HomeBrandHeader(center: true),
        ),
        const SizedBox(height: 20),
        _HomeRevealSlice(
          controller: _revealController,
          begin: 0.14,
          end: 0.66,
          child: _ConnectHintHalo(
            visible: _showConnectHint,
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
        ),
        const SizedBox(height: 14),
        _HomeRevealSlice(
          controller: _revealController,
          begin: 0.26,
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
          begin: 0.38,
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
          begin: 0.50,
          end: 1,
          child: _HomeWarpTile(
            policy: widget.warpPolicy,
            runtimeConsent: widget.warpRuntimeConsent,
            busy: widget.warpBusy,
            onOpen: widget.onOpenWarp,
            onChanged: widget.onWarpConsentChanged,
          ),
        ),
        if (widget.infoNotice != null) ...[
          const SizedBox(height: 8),
          _HomeRevealSlice(
            controller: _revealController,
            begin: 0.54,
            end: 1,
            child: _HomeInfoNotice(message: widget.infoNotice!),
          ),
        ],
        const SizedBox(height: 10),
        _HomeRevealSlice(
          controller: _revealController,
          begin: 0.58,
          end: 1,
          child: _HomeAccessStrip(
            accessLabel: widget.accessLabel,
            poolLabel: widget.accessPoolLabel,
            telegramBonusClaimed: widget.telegramBonusClaimed,
          ),
        ),
        if (!widget.telegramBonusClaimed) ...[
          const SizedBox(height: 10),
          _HomeRevealSlice(
            controller: _revealController,
            begin: 0.66,
            end: 1,
            child: _HomeTelegramBonusTile(
              label: widget.telegramBonusLabel,
              claimed: widget.telegramBonusClaimed,
              onTap: widget.onTelegramBonus,
            ),
          ),
        ],
        if (widget.homePromoSlot != null) ...[
          const SizedBox(height: 10),
          _HomeRevealSlice(
            controller: _revealController,
            begin: 0.72,
            end: 1,
            child: _HomeAdminPromoCard(
              slot: widget.homePromoSlot!,
              onOpenHandoff: widget.onOpenPromoHandoff,
            ),
          ),
        ],
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
    final p = PokrovPalette.of(context);
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
                      'POKROV VPN',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.accessLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: p.muted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              // Honest affordances: the icons and tooltips describe the real
              // targets (connection details sheet and the Rules tab).
              IconButton(
                key: const ValueKey('home-desktop-notifications-action'),
                tooltip: 'Детали подключения',
                onPressed: widget.onOpenConnectionDetails,
                icon: const Icon(Icons.info_outline_rounded),
              ),
              IconButton(
                key: const ValueKey('home-desktop-settings-action'),
                tooltip: 'Правила',
                onPressed: widget.onOpenRules,
                icon: const Icon(Icons.tune_rounded),
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
                  connectHintVisible: _showConnectHint,
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
                    child: _HomeWarpTile(
                      policy: widget.warpPolicy,
                      runtimeConsent: widget.warpRuntimeConsent,
                      busy: widget.warpBusy,
                      onOpen: widget.onOpenWarp,
                      onChanged: widget.onWarpConsentChanged,
                    ),
                  ),
                  if (widget.infoNotice != null) ...[
                    const SizedBox(height: 10),
                    _HomeRevealSlice(
                      controller: _revealController,
                      begin: 0.26,
                      end: 0.8,
                      child: _HomeInfoNotice(message: widget.infoNotice!),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _HomeRevealSlice(
                    controller: _revealController,
                    begin: 0.30,
                    end: 0.82,
                    child: _HomeAccessStrip(
                      accessLabel: widget.accessLabel,
                      poolLabel: widget.accessPoolLabel,
                      telegramBonusClaimed: widget.telegramBonusClaimed,
                    ),
                  ),
                  if (!widget.telegramBonusClaimed) ...[
                    const SizedBox(height: 14),
                    _HomeRevealSlice(
                      controller: _revealController,
                      begin: 0.38,
                      end: 0.9,
                      child: _HomeTelegramBonusTile(
                        label: widget.telegramBonusLabel,
                        claimed: widget.telegramBonusClaimed,
                        onTap: widget.onTelegramBonus,
                      ),
                    ),
                  ],
                  if (widget.homePromoSlot != null) ...[
                    const SizedBox(height: 14),
                    _HomeRevealSlice(
                      controller: _revealController,
                      begin: 0.5,
                      end: 1,
                      child: _HomeAdminPromoCard(
                        slot: widget.homePromoSlot!,
                        onOpenHandoff: widget.onOpenPromoHandoff,
                      ),
                    ),
                  ],
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
    required this.connectHintVisible,
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
  final bool connectHintVisible;
  final String? recoveryNotice;
  final RouteMode selectedRouteMode;
  final String locationLabel;
  final Future<void> Function() onToggleRuntime;
  final VoidCallback onOpenConnectionDetails;
  final VoidCallback onOpenLocations;
  final VoidCallback onOpenRules;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Container(
      key: const ValueKey('home-desktop-connect-panel'),
      constraints: const BoxConstraints(minHeight: 440),
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 18),
          _ConnectHintHalo(
            visible: connectHintVisible,
            child: _ConnectOrbButton(
              actionLabel: actionLabel,
              enabled: actionEnabled,
              running: running,
              degraded: degraded,
              error: recoveryNotice != null,
              busy: busy,
              desktopSize: true,
              onPressed: actionEnabled ? onToggleRuntime : null,
            ),
          ),
          const SizedBox(height: 22),
          _HomeStatusAction(
            statusLabel: statusLabel,
            statusColor: statusColor,
            onTap: onOpenConnectionDetails,
          ),
          const SizedBox(height: 30),
          _HomeModeChips(
            locationLabel: locationLabel,
            routeMode: selectedRouteMode,
            onOpenLocations: onOpenLocations,
            onOpenRules: onOpenRules,
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
    final p = PokrovPalette.of(context);
    return InkWell(
      key: const ValueKey('home-connection-details-action'),
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: _StatusDotLabel(
                label: statusLabel,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: p.muted.withValues(alpha: 0.6),
            ),
          ],
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

class _HomeAccessStrip extends StatelessWidget {
  const _HomeAccessStrip({
    required this.accessLabel,
    required this.poolLabel,
    required this.telegramBonusClaimed,
  });

  final String accessLabel;
  final String poolLabel;
  final bool telegramBonusClaimed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = PokrovPalette.of(context);
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
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              color: p.accent,
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
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  poolLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: p.muted,
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
            tone: _SectionTone.accent,
          ),
        ],
      ),
    );
    return content;
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
    final p = PokrovPalette.of(context);
    final content = Container(
      key: const ValueKey('home-telegram-bonus-pill'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: claimed
            ? p.surface.withValues(alpha: 0.96)
            : p.reward.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: claimed ? p.line : p.reward.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: claimed
                  ? p.accent.withValues(alpha: 0.10)
                  : p.reward.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              claimed
                  ? Icons.check_circle_outline_rounded
                  : Icons.send_outlined,
              color: claimed ? p.accent : p.reward,
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
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  claimed ? label : 'Подпишитесь на канал и заберите бонус',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: p.muted,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            claimed ? Icons.done_rounded : Icons.chevron_right_rounded,
            color: p.muted,
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

class _HomeAdminPromoCard extends StatelessWidget {
  const _HomeAdminPromoCard({
    required this.slot,
    required this.onOpenHandoff,
  });

  final AppFirstPromoSlot slot;
  final void Function(String label, String value) onOpenHandoff;

  @override
  Widget build(BuildContext context) {
    final safeHref = _safeHomePromoSlotHref(slot.ctaHref);
    final ctaLabel = slot.ctaLabel.trim().isEmpty ? 'Открыть' : slot.ctaLabel;
    final title = slot.title.trim();
    final body = slot.body.trim();
    return PokrovPromoCard(
      key: const ValueKey('home-admin-promo-card'),
      icon: Icons.campaign_outlined,
      title: title.isEmpty ? 'POKROV' : title,
      detail: body.isEmpty ? title : body,
      tone: PokrovSurfaceTone.muted,
      actionLabel: safeHref == null ? null : ctaLabel,
      onTap: safeHref == null
          ? null
          : () => onOpenHandoff('download', safeHref.toString()),
    );
  }
}

class _HomeWarpTile extends StatelessWidget {
  const _HomeWarpTile({
    required this.policy,
    required this.runtimeConsent,
    required this.busy,
    required this.onOpen,
    required this.onChanged,
  });

  final WarpRuntimePolicy policy;
  final bool runtimeConsent;
  final bool busy;
  final Future<void> Function() onOpen;
  final Future<void> Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final p = PokrovPalette.of(context);
    final displayPolicy = policy.withClientLocalDefaults();
    final lifecycle = PokrovWarpLifecycle.resolve(
      policy: displayPolicy,
      consented: runtimeConsent,
      busy: busy,
    );
    final canOffer = lifecycle.canOffer;
    final enabled = lifecycle.highlightsEnabled;
    const title = 'WARP';
    final subtitle = busy
        ? 'Применяем настройку'
        : enabled
            ? 'Включится при следующем подключении'
            : canOffer
                ? 'Дополнительная защита'
                : 'Недоступно на этом устройстве';
    final iconColor = enabled ? p.accent : p.muted.withValues(alpha: 0.8);
    final iconBackground = enabled
        ? p.accent.withValues(alpha: 0.12)
        : p.surfaceMuted.withValues(alpha: 0.86);

    return Semantics(
      key: const ValueKey('home-warp-tile'),
      toggled: enabled,
      child: GestureDetector(
        // The whole tile toggles the switch; the switch itself wins the
        // gesture arena for taps landing directly on it.
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (busy) {
            return;
          }
          if (!canOffer) {
            unawaited(onOpen());
            return;
          }
          unawaited(onChanged(!enabled));
        },
        child: AnimatedContainer(
          key: ValueKey(lifecycle.stateKey),
          duration: motion.duration(_MotionTokens.short),
          curve: _MotionTokens.ease,
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: enabled
                ? p.accent.withValues(alpha: 0.09)
                : p.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: enabled ? p.accent.withValues(alpha: 0.28) : p.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  enabled ? Icons.verified_user_rounded : Icons.blur_on_rounded,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: p.ink,
                                  fontWeight: FontWeight.w700,
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
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: p.muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PokrovSwitch(
                key: const ValueKey('home-warp-inline-switch'),
                value: enabled,
                onChanged: !canOffer || busy
                    ? null
                    : (value) {
                        unawaited(onChanged(value));
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBrandHeader extends StatelessWidget {
  const _HomeBrandHeader({this.center = false});

  final bool center;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        const _BrandMark(size: 38),
        const SizedBox(width: 10),
        Text(
          'POKROV VPN',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: p.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
        ),
      ],
    );
  }
}

String _homeProtectionStatusLabel(
  RuntimeSnapshot? snapshot, {
  bool busy = false,
}) {
  if (busy) {
    return 'Подключается…';
  }
  if (snapshot?.phase == RuntimePhase.running) {
    return (snapshot?.isCleanlyHealthy ?? false)
        ? 'Подключено'
        : 'Нужно внимание';
  }
  if (snapshot?.phase == RuntimePhase.artifactMissing) {
    return 'Не получилось подключиться';
  }
  return 'Не защищено';
}

String _accessHomeSupportLabel(AccessLane lane) {
  return switch (lane) {
    AccessLane.trialPremium => 'После пробного периода — продлите доступ',
    AccessLane.bonusPremium || AccessLane.paidUnlimited => 'Доступ активен',
    AccessLane.freeMonthly => 'Можно продлить до премиум-доступа',
    AccessLane.freeSoftMode => 'Продлите доступ, чтобы подключиться',
  };
}

String? _homeInfoNotice(String? headline) {
  final text = headline?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  if (text.startsWith('WARP ')) {
    return text;
  }
  return null;
}

AppFirstPromoSlot? _homeAdminPromoSlot(AppFirstBonusSummary? bonusSummary) {
  final promoSlots = bonusSummary?.promoSlots;
  if (promoSlots == null) {
    return null;
  }
  const placements = <String>{
    'home_banner',
    'home',
    'home_primary',
    'protection',
    'protection_home',
  };
  for (final placement in placements) {
    final slots = promoSlots.visibleForPlacement(placement);
    for (final slot in slots) {
      if (_isRenderableHomePromoSlot(slot)) {
        return slot;
      }
    }
  }
  return null;
}

bool _isRenderableHomePromoSlot(AppFirstPromoSlot slot) {
  final title = slot.title.trim();
  final body = slot.body.trim();
  final safeHref = _safeHomePromoSlotHref(slot.ctaHref);
  if (body.isNotEmpty) {
    return true;
  }
  return title.isNotEmpty && safeHref != null;
}

Uri? _safeHomePromoSlotHref(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  if (scheme == 'tg' && (host == 'resolve' || host == 'join')) {
    return uri;
  }
  if (scheme != 'https') {
    return null;
  }
  if (host == 't.me' ||
      host == 'telegram.me' ||
      host == 'pokrov.space' ||
      host.endsWith('.pokrov.space')) {
    return uri;
  }
  if (host == 'github.com' && uri.path.contains('/releases/')) {
    return uri;
  }
  return null;
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
        final progress = _MotionTokens.emphasized.transform(
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
    final p = PokrovPalette.of(context);
    return AnimatedSwitcher(
      key: const ValueKey('motion-recovery-banner'),
      duration: motion.duration(_MotionTokens.standard),
      transitionBuilder: _fadeSlideTransition,
      child: Container(
        key: ValueKey(message),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: p.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: p.warning.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: p.warning.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.ink.withValues(alpha: 0.78),
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

class _HomeInfoNotice extends StatelessWidget {
  const _HomeInfoNotice({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final p = PokrovPalette.of(context);
    return AnimatedSwitcher(
      key: const ValueKey('home-info-notice'),
      duration: motion.duration(_MotionTokens.short),
      transitionBuilder: _fadeSlideTransition,
      child: Container(
        key: ValueKey(message),
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: p.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: p.accent.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: p.accent.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.muted,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-time "first connection" hint around the idle connect disc: a soft
/// expanding pulse ring behind the disc plus a small "tap to connect" pill
/// below it. Motion is transform/opacity-only; under reduced motion the ring
/// is statically off and only the calm pill remains. Visibility is decided
/// by the caller and the dismissal is persisted by the shell through
/// [PokrovFileConnectHintStore].
class _ConnectHintHalo extends StatelessWidget {
  const _ConnectHintHalo({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final p = PokrovPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (visible && !motion.disableAnimations)
              Positioned.fill(
                child: IgnorePointer(
                  child: _ConnectHintPulseRing(
                    key: const ValueKey('home-connect-hint-pulse'),
                    accent: p.accent,
                  ),
                ),
              ),
            child,
          ],
        ),
        AnimatedSwitcher(
          key: const ValueKey('home-connect-hint-pill-motion'),
          duration: motion.duration(_MotionTokens.standard),
          switchInCurve: _MotionTokens.ease,
          switchOutCurve: _MotionTokens.ease,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: !visible
              ? const SizedBox.shrink(
                  key: ValueKey('home-connect-hint-empty'),
                )
              : Padding(
                  key: const ValueKey('home-connect-hint-pill'),
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: p.line),
                    ),
                    child: Text(
                      'Нажмите, чтобы подключиться',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: p.muted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Soft expanding ring behind the idle disc: scale 1.0 -> 1.14 with the
/// low-alpha accent stroke fading out over ~2.4s. Loops continuously in
/// release builds and collapses to one finite pass under `flutter test`
/// (see [PokrovLoopingMotion]); it is not built at all under reduced motion.
class _ConnectHintPulseRing extends StatefulWidget {
  const _ConnectHintPulseRing({
    super.key,
    required this.accent,
  });

  final Color accent;

  @override
  State<_ConnectHintPulseRing> createState() => _ConnectHintPulseRingState();
}

class _ConnectHintPulseRingState extends State<_ConnectHintPulseRing>
    with SingleTickerProviderStateMixin {
  static const _period = Duration(milliseconds: 2400);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
    if (PokrovLoopingMotion.enabled) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = Curves.easeOutCubic.transform(_controller.value);
          return Transform.scale(
            scale: 1.0 + progress * 0.14,
            child: Opacity(
              // Sine envelope: the attention ring fades in and out without
              // the hard restart pop a linear (1 - t) loop produces.
              opacity: math.sin(math.pi * progress) * 0.35,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.accent.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
              ),
            ),
          );
        },
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
