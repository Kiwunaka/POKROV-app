part of pokrov_app_shell;

class _QuickConnectSection extends StatelessWidget {
  const _QuickConnectSection({
    required this.appContext,
    required this.freeProfileAccess,
    required this.selectedRouteMode,
    required this.locationLabel,
    required this.runtimeSnapshot,
    required this.runtimeHeadline,
    required this.runtimeBusy,
    required this.runtimeDisconnecting,
    required this.primaryConnectEnabled,
    required this.connectHintVisible,
    required this.revealHold,
    required this.bonusSummary,
    required this.subscriptionInfo,
    required this.telegramBonusBusy,
    required this.warpPolicy,
    required this.warpRuntimeConsent,
    required this.warpRuntimeActive,
    required this.warpBusy,
    required this.onToggleRuntime,
    required this.onOpenConnectionDetails,
    required this.onTelegramBonus,
    required this.onOpenLocations,
    required this.onOpenRules,
    required this.onOpenWarp,
    required this.onWarpConsentChanged,
    required this.onOpenCheckout,
    required this.onOpenPromoHandoff,
  });

  final SeedAppContext appContext;
  final FreeProfileAccess? freeProfileAccess;
  final RouteMode selectedRouteMode;
  final String locationLabel;
  final RuntimeSnapshot? runtimeSnapshot;
  final String? runtimeHeadline;
  final bool runtimeBusy;
  final bool runtimeDisconnecting;
  final bool primaryConnectEnabled;
  final bool connectHintVisible;

  /// Welcome Handover: true while the first-launch gate covers the shell,
  /// so the staged reveal waits for the handover instead of burning at boot.
  final bool revealHold;
  final AppFirstBonusSummary? bonusSummary;
  final ClientSubscriptionInfo? subscriptionInfo;
  final bool telegramBonusBusy;
  final WarpRuntimePolicy warpPolicy;
  final bool warpRuntimeConsent;
  final bool warpRuntimeActive;
  final bool warpBusy;
  final Future<void> Function() onToggleRuntime;
  final VoidCallback onOpenConnectionDetails;
  final VoidCallback? onTelegramBonus;
  final VoidCallback onOpenLocations;
  final VoidCallback onOpenRules;
  final Future<void> Function() onOpenWarp;
  final Future<void> Function(bool value) onWarpConsentChanged;
  final VoidCallback onOpenCheckout;
  final void Function(String label, String value) onOpenPromoHandoff;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final snapshot = runtimeSnapshot;
    final tunnelRunning = snapshot?.phase == RuntimePhase.running;
    final egressValidationPending =
        appContext.hostPlatform == HostPlatform.android &&
            tunnelRunning &&
            snapshot?.coreEgressValidated != true;
    // Android's TUN is only the transport. The consumer-facing connected state
    // starts after Core proves egress through the selected outbound.
    final isRunning = tunnelRunning && !egressValidationPending;
    final isHealthyRunning = snapshot?.isCleanlyHealthy ?? false;
    final statusLabel = _homeProtectionStatusLabel(
      snapshot,
      busy: runtimeBusy,
      disconnecting: runtimeDisconnecting,
    );
    final primaryActionEnabled = !runtimeBusy && primaryConnectEnabled;
    final isDesktop = switch (appContext.hostPlatform) {
      HostPlatform.windows || HostPlatform.macos => true,
      HostPlatform.android || HostPlatform.ios => false,
    };
    final statusColor = runtimeBusy
        ? p.muted
        : tunnelRunning
            ? isHealthyRunning
                ? p.success
                : p.warning
            : p.muted;
    final actionLabel = runtimeBusy
        // Honest direction while busy: tearing the tunnel down must never
        // read as if a connection is being established.
        ? runtimeDisconnecting
            ? 'Отключаем…'
            : 'Подключаемся…'
        : tunnelRunning
            ? 'Отключить'
            : primaryActionEnabled
                ? 'Подключить'
                : 'Пока недоступно';
    final freeProfileNotice = _freeProfileAccessNotice(freeProfileAccess);
    final recoveryNotice = freeProfileAccess?.hasRecoverableError ?? false
        ? freeProfileNotice
        : _motionRecoveryNotice(
            snapshot,
            headline: runtimeHeadline,
            busy: runtimeBusy,
          );
    final infoNotice = recoveryNotice == null
        ? (freeProfileNotice ?? _homeInfoNotice(runtimeHeadline))
        : null;
    final homePromoSlot = _homeAdminPromoSlot(bonusSummary);
    final telegramBonusClaimed =
        (bonusSummary?.channelBonusClaimedAt ?? '').trim().isNotEmpty;

    return _SeedContentList(
      // Mobile tabs share the 16px top gutter; the desktop stage keeps its
      // larger hero offset because it has no headline row above the disc.
      top: isDesktop ? 34 : 16,
      maxContentWidth: isDesktop ? 1220 : 900,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1220 : 500),
            child: _HomeStage(
              preferDesktopLayout: isDesktop,
              revealHold: revealHold,
              statusLabel: statusLabel,
              statusColor: statusColor,
              actionLabel: actionLabel,
              actionEnabled: primaryActionEnabled,
              running: isRunning,
              busy: runtimeBusy || egressValidationPending,
              degraded: isRunning && !isHealthyRunning,
              connectHintVisible: connectHintVisible,
              recoveryNotice: recoveryNotice,
              infoNotice: infoNotice,
              accessLabel: _accessMainLabel(
                appContext,
                bonusSummary,
                freeProfileAccess,
                subscriptionInfo,
              ),
              accessPoolLabel: _accessHomeSupportLabel(
                _effectiveAccessLane(appContext, subscriptionInfo),
                freeProfileAccess,
              ),
              telegramBonusLabel: telegramBonusBusy
                  ? 'Проверяем Telegram'
                  : _telegramBonusHomeLabel(bonusSummary),
              telegramBonusClaimed: telegramBonusClaimed,
              telegramBonusClaimedDays: telegramBonusClaimed
                  ? _claimedTelegramBonusDays(bonusSummary)
                  : null,
              selectedRouteMode: selectedRouteMode,
              locationLabel: locationLabel,
              warpPolicy: warpPolicy,
              warpRuntimeConsent: warpRuntimeConsent,
              warpRuntimeActive: warpRuntimeActive,
              warpBusy: warpBusy,
              homePromoSlot: homePromoSlot,
              onToggleRuntime: onToggleRuntime,
              onTelegramBonus: onTelegramBonus,
              onOpenConnectionDetails: onOpenConnectionDetails,
              onOpenLocations: onOpenLocations,
              onOpenRules: onOpenRules,
              onOpenWarp: onOpenWarp,
              onWarpConsentChanged: onWarpConsentChanged,
              onOpenCheckout: onOpenCheckout,
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
    required this.revealHold,
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
    required this.telegramBonusClaimedDays,
    required this.selectedRouteMode,
    required this.locationLabel,
    required this.warpPolicy,
    required this.warpRuntimeConsent,
    required this.warpRuntimeActive,
    required this.warpBusy,
    required this.homePromoSlot,
    required this.onToggleRuntime,
    required this.onTelegramBonus,
    required this.onOpenConnectionDetails,
    required this.onOpenLocations,
    required this.onOpenRules,
    required this.onOpenWarp,
    required this.onWarpConsentChanged,
    required this.onOpenCheckout,
    required this.onOpenPromoHandoff,
  });

  final bool preferDesktopLayout;

  /// Welcome Handover: while true the staged reveal stays parked at zero;
  /// the flip to false starts it a beat into the gate's exit.
  final bool revealHold;
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
  final int? telegramBonusClaimedDays;
  final RouteMode selectedRouteMode;
  final String locationLabel;
  final WarpRuntimePolicy warpPolicy;
  final bool warpRuntimeConsent;
  final bool warpRuntimeActive;
  final bool warpBusy;
  final AppFirstPromoSlot? homePromoSlot;
  final Future<void> Function() onToggleRuntime;
  final VoidCallback? onTelegramBonus;
  final VoidCallback onOpenConnectionDetails;
  final VoidCallback onOpenLocations;
  final VoidCallback onOpenRules;
  final Future<void> Function() onOpenWarp;
  final Future<void> Function(bool value) onWarpConsentChanged;
  final VoidCallback onOpenCheckout;
  final void Function(String label, String value) onOpenPromoHandoff;

  @override
  State<_HomeStage> createState() => _HomeStageState();
}

class _HomeStageState extends State<_HomeStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;
  bool _revealStarted = false;
  Timer? _revealTimer;

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
    if (!_revealStarted && !widget.revealHold) {
      _revealStarted = true;
      _revealController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _HomeStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.revealHold || widget.revealHold || _revealStarted) {
      return;
    }
    _revealStarted = true;
    if (_MotionScope.of(context).disableAnimations) {
      _revealController.value = 1;
      return;
    }
    // Welcome Handover: the reveal starts a beat into the gate's exit so
    // the brand lockup reads as one mark persisting across the crossfade.
    _revealTimer = Timer(const Duration(milliseconds: 80), () {
      if (mounted) {
        _revealController.forward();
      }
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
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
          child: _HomeTopBar(
            accessLabel: widget.accessLabel,
            poolLabel: widget.accessPoolLabel,
            onOpenCheckout: widget.onOpenCheckout,
          ),
        ),
        const SizedBox(height: 22),
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
              status: _HomeStatusAction(
                statusLabel: widget.statusLabel,
                statusColor: widget.statusColor,
                onTap: widget.onOpenConnectionDetails,
                compact: true,
              ),
              onPressed: widget.actionEnabled ? widget.onToggleRuntime : null,
            ),
          ),
        ),
        if (widget.recoveryNotice != null) ...[
          const SizedBox(height: 16),
          _HomeRevealSlice(
            controller: _revealController,
            begin: 0.32,
            end: 0.78,
            child: _MotionRecoveryBanner(message: widget.recoveryNotice!),
          ),
        ],
        const SizedBox(height: 20),
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
            runtimeActive: widget.warpRuntimeActive,
            busy: widget.warpBusy,
            compact: true,
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
        if (widget.homePromoSlot != null) ...[
          const SizedBox(height: 14),
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
                      runtimeActive: widget.warpRuntimeActive,
                      busy: widget.warpBusy,
                      compact: false,
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
                      telegramBonusClaimedDays: widget.telegramBonusClaimedDays,
                      onTap: widget.onOpenCheckout,
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
    this.compact = false,
  });

  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    if (compact) {
      return KeyedSubtree(
        key: const ValueKey('home-connection-details-action'),
        child: PokrovSettingsRowPressSurface(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: AnimatedSwitcher(
              key: const ValueKey('home-status-switcher'),
              duration: _MotionScope.of(context).duration(_MotionTokens.short),
              transitionBuilder: _fadeSlideTransition,
              child: Text(
                statusLabel,
                key: ValueKey(statusLabel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: p.muted,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
        ),
      );
    }
    // Keep the design branch's disclosure affordance while using the shared
    // press-scale grammar instead of a one-off InkWell.
    return KeyedSubtree(
      key: const ValueKey('home-connection-details-action'),
      child: PokrovSettingsRowPressSurface(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _StatusDotLabel(label: statusLabel, color: statusColor),
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
    return Row(
      children: [
        Expanded(
          child: _HomeChip(
            key: const ValueKey('home-location-chip'),
            icon: Icons.public_rounded,
            label: locationLabel,
            onTap: onOpenLocations,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HomeChip(
            key: const ValueKey('home-route-chip'),
            icon: Icons.alt_route_rounded,
            label: _routeModeShortLabel(routeMode),
            onTap: onOpenRules,
          ),
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
    required this.telegramBonusClaimedDays,
    required this.onTap,
  });

  final String accessLabel;
  final String poolLabel;
  final bool telegramBonusClaimed;
  final int? telegramBonusClaimedDays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motion = _MotionScope.of(context);
    final p = PokrovPalette.of(context);
    final accessBadgeLabel = telegramBonusClaimed
        ? telegramBonusClaimedDays == null
            ? 'Telegram'
            : '+${ruDays(telegramBonusClaimedDays!)}'
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On narrow phones the badge repeats the access headline and steals
          // enough width to ellipsize both useful lines. Keep it for wider
          // layouts where it remains a quick status cue.
          final showBadge = constraints.maxWidth >= 360;
          return Row(
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
              if (showBadge) ...[
                const SizedBox(width: 10),
                // Claim settle bloom: the badge does one spring overshoot when
                // the bonus lands — keyed on the data flip, not on rebuilds.
                TweenAnimationBuilder<double>(
                  key: ValueKey(
                    'home-access-badge-bloom-$telegramBonusClaimed',
                  ),
                  tween: Tween(
                    begin: telegramBonusClaimed && !motion.disableAnimations
                        ? 0.9
                        : 1.0,
                    end: 1,
                  ),
                  duration: motion.duration(_MotionTokens.standard),
                  curve: PokrovMotionTokens.spring,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: _StatusPill(
                    label: accessBadgeLabel,
                    icon: telegramBonusClaimed
                        ? Icons.check_circle_outline_rounded
                        : Icons.calendar_today_outlined,
                    tone: _SectionTone.accent,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: p.muted, size: 22),
            ],
          );
        },
      ),
    );
    return Semantics(
      button: true,
      label: '$accessLabel. $poolLabel. Открыть оплату',
      onTap: onTap,
      child: ExcludeSemantics(
        child: PokrovSettingsRowPressSurface(onTap: onTap, child: content),
      ),
    );
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
    final motion = _MotionScope.of(context);
    final p = PokrovPalette.of(context);
    // Claim settle: the tile acknowledges in place — reward tint relaxes to
    // surface and the send icon morphs into a check (rewards copy-morph
    // recipe), keyed off the data change so it plays wherever it's visible.
    final content = AnimatedContainer(
      key: const ValueKey('home-telegram-bonus-pill'),
      duration: motion.duration(_MotionTokens.standard),
      curve: _MotionTokens.emphasized,
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
          AnimatedContainer(
            duration: motion.duration(_MotionTokens.standard),
            curve: _MotionTokens.ease,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: claimed
                  ? p.accent.withValues(alpha: 0.10)
                  : p.reward.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: AnimatedSwitcher(
              duration: motion.duration(PokrovMotionTokens.quick),
              switchInCurve: PokrovMotionTokens.spring,
              switchOutCurve: _MotionTokens.ease,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Icon(
                claimed
                    ? Icons.check_circle_outline_rounded
                    : Icons.send_outlined,
                key: ValueKey(claimed),
                color: claimed ? p.accent : p.reward,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  claimed ? 'Telegram-бонус активен' : label,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: p.muted, height: 1.25),
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

class _HomeAdminPromoCard extends StatefulWidget {
  const _HomeAdminPromoCard({required this.slot, required this.onOpenHandoff});

  final AppFirstPromoSlot slot;
  final void Function(String label, String value) onOpenHandoff;

  @override
  State<_HomeAdminPromoCard> createState() => _HomeAdminPromoCardState();
}

class _HomeAdminPromoCardState extends State<_HomeAdminPromoCard> {
  final PokrovFilePromoDismissStore _dismissStore =
      const PokrovFilePromoDismissStore();
  bool _dismissed = true;
  bool _dismissStateLoaded = false;

  String get _campaignKey {
    final slot = widget.slot;
    return <String>[
      slot.slotId.trim(),
      slot.contentId.trim(),
      slot.startsAt.trim(),
      slot.endsAt.trim(),
    ].join('|');
  }

  @override
  void initState() {
    super.initState();
    unawaited(_restoreDismissState());
  }

  @override
  void didUpdateWidget(covariant _HomeAdminPromoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = <String>[
      oldWidget.slot.slotId.trim(),
      oldWidget.slot.contentId.trim(),
      oldWidget.slot.startsAt.trim(),
      oldWidget.slot.endsAt.trim(),
    ].join('|');
    if (oldKey != _campaignKey) {
      _dismissed = true;
      _dismissStateLoaded = false;
      unawaited(_restoreDismissState());
    }
  }

  Future<void> _restoreDismissState() async {
    final key = _campaignKey;
    final dismissed = await _dismissStore.isDismissed(key).timeout(
          const Duration(milliseconds: 400),
          onTimeout: () => false,
        );
    if (!mounted || key != _campaignKey) {
      return;
    }
    setState(() {
      _dismissed = dismissed;
      _dismissStateLoaded = true;
    });
  }

  void _dismiss() {
    final key = _campaignKey;
    setState(() => _dismissed = true);
    unawaited(_dismissStore.dismiss(key));
  }

  @override
  Widget build(BuildContext context) {
    if (!_dismissStateLoaded || _dismissed) {
      return const SizedBox.shrink(key: ValueKey('home-admin-promo-dismissed'));
    }
    final slot = widget.slot;
    final safeHref = _safeHomePromoSlotHref(slot.ctaHref);
    final safeImage = _safeHomePromoImageUri(slot.imageUrl);
    final ctaLabel = slot.ctaLabel.trim().isEmpty ? 'Открыть' : slot.ctaLabel;
    final title = slot.title.trim();
    final body = slot.body.trim();
    final badge = slot.badgeLabel.trim();
    final p = PokrovPalette.of(context);
    final accent = _promoHexColor(slot.accentColor) ?? p.accent;
    final background = _promoHexColor(slot.backgroundColor) ?? p.surface;
    final textColor = _promoHexColor(slot.textColor) ?? p.ink;
    final buttonColor = _promoHexColor(slot.buttonColor) ?? accent;
    final buttonTextColor = _promoHexColor(slot.buttonTextColor) ??
        (ThemeData.estimateBrightnessForColor(buttonColor) == Brightness.dark
            ? Colors.white
            : Colors.black);
    final imageOnly = safeImage != null && title.isEmpty && body.isEmpty;
    final bannerImage = slot.imageLayout.trim().toLowerCase() == 'banner';
    final open = safeHref == null
        ? null
        : () => widget.onOpenHandoff('promo', safeHref.toString());

    Widget remoteImage({required double height, required BoxFit fit}) {
      if (safeImage == null) {
        return const _BrandMark(size: 46);
      }
      return Image.network(
        safeImage.toString(),
        height: height,
        width: double.infinity,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const Center(child: _BrandMark(size: 46)),
      );
    }

    final card = Container(
      key: const ValueKey('home-admin-promo-card'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.64)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bannerImage && safeImage != null)
                remoteImage(height: imageOnly ? 148 : 108, fit: BoxFit.cover),
              if (!imageOnly)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    bannerImage && safeImage != null ? 13 : 16,
                    16,
                    16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!bannerImage) ...[
                        SizedBox(
                          width: 54,
                          height: 54,
                          child: remoteImage(height: 54, fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 13),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (badge.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  badge.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.25,
                                      ),
                                ),
                              ),
                            if (title.isNotEmpty)
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: textColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: textColor.withValues(alpha: 0.72),
                                      height: 1.25,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (open != null) ...[
                        const SizedBox(width: 12),
                        FilledButton(
                          key: const ValueKey('home-admin-promo-action'),
                          onPressed: open,
                          style: FilledButton.styleFrom(
                            backgroundColor: buttonColor,
                            foregroundColor: buttonTextColor,
                            minimumSize: const Size(86, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text(
                            ctaLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          if (slot.dismissible)
            Positioned(
              top: 5,
              right: 5,
              child: IconButton.filledTonal(
                key: const ValueKey('home-admin-promo-dismiss'),
                tooltip: 'Скрыть предложение',
                onPressed: _dismiss,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ),
        ],
      ),
    );
    if (open == null || !slot.wholeCardClickable) {
      return card;
    }
    return Semantics(
      button: true,
      label: '${title.isEmpty ? 'Предложение' : title}. $ctaLabel',
      onTap: open,
      child: PokrovSettingsRowPressSurface(onTap: open, child: card),
    );
  }
}

class _HomeWarpTile extends StatelessWidget {
  const _HomeWarpTile({
    required this.policy,
    required this.runtimeConsent,
    required this.runtimeActive,
    required this.busy,
    required this.compact,
    required this.onOpen,
    required this.onChanged,
  });

  final WarpRuntimePolicy policy;
  final bool runtimeConsent;
  final bool runtimeActive;
  final bool busy;
  final bool compact;
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
      runtimeActive: runtimeActive,
    );
    final canOffer = lifecycle.canOffer;
    final enabled = lifecycle.consented;
    final highlighted = lifecycle.highlightsEnabled;
    const title = 'WARP';
    final subtitle = busy
        ? 'Применяем настройку'
        : switch (lifecycle.phase) {
            PokrovWarpPhase.active => 'Активна',
            PokrovWarpPhase.consented => 'Включится при следующем подключении',
            PokrovWarpPhase.fallback => 'На паузе · обычный режим',
            PokrovWarpPhase.degraded => 'Работает нестабильно',
            PokrovWarpPhase.error => 'Не удалось включить',
            _ when canOffer => 'Дополнительная защита',
            _ => 'Недоступно на этом устройстве',
          };
    final iconColor = lifecycle.isProblem
        ? p.warning
        : highlighted
            ? p.accent
            : p.muted.withValues(alpha: 0.8);
    final iconBackground = lifecycle.isProblem
        ? p.warning.withValues(alpha: 0.12)
        : highlighted
            ? p.accent.withValues(alpha: 0.12)
            : p.surfaceMuted.withValues(alpha: 0.86);

    void handleTap() {
      if (busy) {
        return;
      }
      if (!canOffer) {
        unawaited(onOpen());
        return;
      }
      // Same selection tick as the inline switch emits for direct taps.
      PokrovHaptics.tap();
      unawaited(onChanged(!enabled));
    }

    return Semantics(
      key: const ValueKey('home-warp-tile'),
      container: true,
      enabled: !busy,
      label: title,
      value: subtitle,
      toggled: enabled,
      onTap: busy ? null : handleTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          // Pointer input still works on the whole tile and on the inline
          // switch. ExcludeSemantics keeps TalkBack on one toggle node.
          behavior: HitTestBehavior.opaque,
          onTap: handleTap,
          child: AnimatedContainer(
            key: ValueKey(lifecycle.stateKey),
            duration: motion.duration(_MotionTokens.short),
            curve: _MotionTokens.ease,
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: enabled
                  ? lifecycle.isProblem
                      ? p.warning.withValues(alpha: 0.07)
                      : p.accent.withValues(alpha: 0.09)
                  : p.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: lifecycle.isProblem
                    ? p.warning.withValues(alpha: 0.24)
                    : enabled
                        ? p.accent.withValues(alpha: 0.28)
                        : p.line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Consent settle: turning WARP on lands the shield with a small
                // spring — the promise reads committed. The off direction fades
                // only: downgrades stay deliberately quieter.
                AnimatedSwitcher(
                  duration: motion.duration(_MotionTokens.short),
                  switchInCurve: _MotionTokens.ease,
                  switchOutCurve: _MotionTokens.ease,
                  transitionBuilder: (child, animation) {
                    final fade =
                        FadeTransition(opacity: animation, child: child);
                    if (child.key != const ValueKey(true)) {
                      return fade;
                    }
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: PokrovMotionTokens.spring,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    key: ValueKey(enabled),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      enabled
                          ? Icons.verified_user_rounded
                          : Icons.blur_on_rounded,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: compact
                        ? Row(
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: p.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                key: const ValueKey('home-warp-info-action'),
                                tooltip: 'Как работает WARP',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => unawaited(onOpen()),
                                icon: Icon(
                                  Icons.info_outline_rounded,
                                  size: 19,
                                  color: p.muted,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
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
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.accessLabel,
    required this.poolLabel,
    required this.onOpenCheckout,
  });

  final String accessLabel;
  final String poolLabel;
  final VoidCallback onOpenCheckout;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Row(
      children: [
        const _BrandMark(size: 30),
        const SizedBox(width: 7),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'POKROV VPN',
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.15,
                  ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _HomeAccessPill(
          accessLabel: accessLabel,
          poolLabel: poolLabel,
          onTap: onOpenCheckout,
        ),
      ],
    );
  }
}

class _HomeAccessPill extends StatelessWidget {
  const _HomeAccessPill({
    required this.accessLabel,
    required this.poolLabel,
    required this.onTap,
  });

  final String accessLabel;
  final String poolLabel;
  final VoidCallback onTap;

  String get _label {
    final days = RegExp(r'\d+\s+(?:день|дня|дней)').firstMatch(accessLabel);
    if (days != null) {
      final normalized = accessLabel.toLowerCase();
      if (normalized.contains('пробн') || normalized.contains('триал')) {
        return 'Пробный · ${days.group(0)}';
      }
      return 'Премиум · ${days.group(0)}';
    }
    if (accessLabel.toLowerCase().contains('премиум')) {
      return 'Премиум';
    }
    return 'Продлить';
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final content = Container(
      key: const ValueKey('home-access-strip'),
      constraints: const BoxConstraints(minHeight: 38, maxWidth: 158),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.accent.withValues(alpha: 0.56)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _label,
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: p.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.chevron_right_rounded, color: p.accent, size: 18),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: '$_label. $poolLabel. Открыть тарифы',
      onTap: onTap,
      child: ExcludeSemantics(
        child: PokrovSettingsRowPressSurface(onTap: onTap, child: content),
      ),
    );
  }
}

String _homeProtectionStatusLabel(
  RuntimeSnapshot? snapshot, {
  bool busy = false,
  bool disconnecting = false,
}) {
  if (busy) {
    return disconnecting ? 'Завершаем соединение' : 'Подбираем локацию';
  }
  if (snapshot?.phase == RuntimePhase.running) {
    if (snapshot?.isCoreEgressValidationPending ?? false) {
      return 'Проверяем…';
    }
    if (snapshot?.hostHealth == RuntimeHostHealth.unknown) {
      return 'Проверяем…';
    }
    return (snapshot?.isCleanlyHealthy ?? false)
        ? 'Подключено'
        : 'Нужно внимание';
  }
  if (snapshot?.phase == RuntimePhase.artifactMissing) {
    return 'Не получилось подключиться';
  }
  return 'Не защищено';
}

String _accessHomeSupportLabel(
  AccessLane lane, [
  FreeProfileAccess? freeProfileAccess,
]) {
  final freeNotice = _freeProfileAccessNotice(freeProfileAccess);
  if (freeNotice != null) {
    return freeNotice;
  }
  return switch (lane) {
    AccessLane.trialPremium => 'Затем — продлите доступ',
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
  if (text.startsWith('WARP ') || text.startsWith('Локация сохранена.')) {
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
  final safeImage = _safeHomePromoImageUri(slot.imageUrl);
  final safeHref = _safeHomePromoSlotHref(slot.ctaHref);
  if (body.isNotEmpty || safeImage != null) {
    return true;
  }
  return title.isNotEmpty && safeHref != null;
}

Color? _promoHexColor(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
    return null;
  }
  return Color(int.parse('FF$normalized', radix: 16));
}

Uri? _safeHomePromoImageUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
    return null;
  }
  return uri;
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
  if (scheme == 'https' && host.isNotEmpty) {
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
  const _MotionRecoveryBanner({required this.message});

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
          border: Border.all(color: p.warning.withValues(alpha: 0.22)),
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
  const _HomeInfoNotice({required this.message});

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
          border: Border.all(color: p.accent.withValues(alpha: 0.18)),
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

/// Keeps the persisted first-use hint available to accessibility services
/// without adding a second pill or a decorative glow around the main action.
class _ConnectHintHalo extends StatelessWidget {
  const _ConnectHintHalo({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The selected Home direction makes the central action self-evident. Keep
    // the persisted first-use flag for compatibility, but do not draw a glowing
    // halo or a second instructional pill around the primary action.
    return Semantics(
      hint: visible ? 'Главная кнопка подключения' : null,
      child: child,
    );
  }
}

class _StatusDotLabel extends PokrovStatusDotLabel {
  const _StatusDotLabel({required super.label, required super.color});
}

class _HomeChip extends PokrovHomeChip {
  const _HomeChip({
    super.key,
    required super.icon,
    required super.label,
    super.onTap,
  });
}

class _MotionSkeletonList extends PokrovSkeletonList {
  const _MotionSkeletonList({super.key, super.rows = 4});
}
