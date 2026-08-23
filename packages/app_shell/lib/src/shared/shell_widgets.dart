part of pokrov_app_shell;

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.title,
    required this.lines,
    this.child,
    this.tone = _SectionTone.neutral,
  });

  final String title;
  final List<String> lines;
  final Widget? child;
  final _SectionTone tone;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final colors = switch (tone) {
      _SectionTone.accent => (
          background: p.accent.withValues(alpha: 0.06),
          border: p.accent.withValues(alpha: 0.16),
        ),
      _SectionTone.muted => (background: p.surfaceMuted, border: p.line),
      _SectionTone.neutral => (background: p.surface, border: p.line),
      _SectionTone.reward => (
          background: p.reward.withValues(alpha: 0.12),
          border: p.reward.withValues(alpha: 0.22),
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: PokrovSpacing.lg),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: PokrovRadii.cardLg,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PokrovSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              // titleMedium/w600 keeps card titles a clear tier below the
              // headlineSmall page headers instead of 1px apart.
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: p.muted,
                          height: 1.32,
                        ),
                  ),
                ),
              ),
            ],
            if (child != null) ...[
              SizedBox(height: lines.isEmpty ? 12 : 14),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SeedBackdrop extends StatelessWidget {
  const _SeedBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [p.canvas, p.canvasAlt],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(children: [child]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    this.tone = _SectionTone.neutral,
  });

  final String label;
  final IconData icon;
  final _SectionTone tone;

  @override
  Widget build(BuildContext context) {
    // Thin wrapper over the design-system pill so every status badge in the
    // product shares one height, padding, and type size.
    return PokrovStatusPill(
      label: label,
      icon: icon,
      tone: switch (tone) {
        _SectionTone.accent => PokrovStatusTone.accent,
        _SectionTone.muted => PokrovStatusTone.muted,
        _SectionTone.neutral => PokrovStatusTone.neutral,
        _SectionTone.reward => PokrovStatusTone.reward,
      },
    );
  }
}

class _ConnectOrbButton extends StatefulWidget {
  const _ConnectOrbButton({
    required this.presentation,
    required this.error,
    required this.onPressed,
    this.status,
    this.desktopSize = false,
  });

  final ConnectionPresentation presentation;
  final bool error;
  final Future<void> Function()? onPressed;
  final Widget? status;
  final bool desktopSize;

  String get actionLabel => presentation.primaryActionLabel;
  bool get enabled =>
      presentation.primaryActionEnabled ||
      presentation.discMotionBusy ||
      presentation.showsTunnelActive;
  bool get running => presentation.showsConnectedVisual;
  bool get degraded => presentation.isDegraded;
  bool get busy => presentation.discMotionBusy;
  PokrovConnectDiscPhase get phase => switch (presentation.discPhase) {
        ConnectionDiscPhase.idle => PokrovConnectDiscPhase.idle,
        ConnectionDiscPhase.preparing => PokrovConnectDiscPhase.preparing,
        ConnectionDiscPhase.connecting => PokrovConnectDiscPhase.connecting,
        ConnectionDiscPhase.connected => PokrovConnectDiscPhase.connected,
        ConnectionDiscPhase.disconnecting =>
          PokrovConnectDiscPhase.disconnecting,
        ConnectionDiscPhase.reconnecting => PokrovConnectDiscPhase.reconnecting,
        ConnectionDiscPhase.error => PokrovConnectDiscPhase.error,
      };

  @override
  State<_ConnectOrbButton> createState() => _ConnectOrbButtonState();
}

class _ConnectOrbButtonState extends State<_ConnectOrbButton>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _sweepController;
  late final FocusNode _focusNode;

  /// Arc Handoff: 0 = busy sweep geometry, 1 = connected arc geometry.
  /// Runs forward on landing, in reverse on release; finite either way.
  late final AnimationController _settleController;
  double _settleFromAngle = PokrovConnectDiscMotion.connectedArcStartAngle;
  bool _pressed = false;
  bool _discHovered = false;
  bool _discFocused = false;
  bool _optimisticBusy = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: 'primary connect action',
      onKeyEvent: _handleKeyEvent,
    );
    _breathController = AnimationController(
      vsync: this,
      duration: PokrovConnectDiscMotion.breathDuration,
    );
    _sweepController = AnimationController(
      vsync: this,
      duration: PokrovConnectDiscMotion.sweepDuration,
    );
    _settleController = AnimationController(
      vsync: this,
      duration: PokrovConnectDiscMotion.arcSettleDuration,
      // Booting straight into connected shows the landed arc, not a replay.
      value: widget.running ? 1 : 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _ConnectOrbButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.running != widget.running ||
        oldWidget.degraded != widget.degraded ||
        oldWidget.error != widget.error ||
        oldWidget.busy != widget.busy ||
        oldWidget.phase != widget.phase) {
      // Must run before the sweep reset: the landing captures the current
      // sweep angle so the arc lands from wherever it points right now.
      _handlePhaseChange(oldWidget);
      _breathController.reset();
      _sweepController.reset();
      _optimisticBusy = false;
    }
    _syncControllers();
  }

  /// Arc Handoff + Soft Release choreography and the shell's outcome haptic
  /// budget. The action owns its single tap; only a proved connected landing
  /// adds success. Errors keep their one outcome haptic in the snack layer.
  void _handlePhaseChange(_ConnectOrbButton oldWidget) {
    final oldPhase = oldWidget.phase;
    final newPhase = widget.phase;
    if (newPhase == oldPhase) {
      return;
    }
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    if (newPhase == PokrovConnectDiscPhase.connected) {
      _settleFromAngle = PokrovConnectDiscMotion.sweepStartAngle(
        disableAnimations: disableAnimations,
        sweepValue: _sweepController.value,
      );
      if (disableAnimations) {
        _settleController.value = 1;
      } else {
        _settleController.forward(from: 0);
      }
      if (ConnectionHapticCoordinator.outcome(
            oldWidget.presentation.experience.phase,
            widget.presentation.experience.phase,
          ) ==
          ConnectionHapticIntent.success) {
        PokrovHaptics.success();
      }
      return;
    }
    if (oldPhase == PokrovConnectDiscPhase.connected) {
      // Unwind from the current value — cancelable mid-flight, never queued.
      if (disableAnimations) {
        _settleController.value = 0;
      } else {
        _settleController.reverse();
      }
      return;
    }
    if (newPhase == PokrovConnectDiscPhase.idle) {
      if (!_settleController.isAnimating) {
        _settleController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _sweepController.dispose();
    _settleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  PokrovConnectDiscState get _discState => PokrovConnectDiscState.explicit(
        enabled: widget.enabled,
        phase: _optimisticBusy
            ? widget.running
                ? PokrovConnectDiscPhase.disconnecting
                : PokrovConnectDiscPhase.connecting
            : widget.phase,
      );

  bool get _effectiveBusy => widget.busy || _optimisticBusy;

  Future<void> _activate() async {
    if (widget.onPressed == null || _optimisticBusy) {
      return;
    }
    if (ConnectionHapticCoordinator.action(widget.presentation) ==
        ConnectionHapticIntent.tap) {
      PokrovHaptics.tap();
    }
    setState(() {
      _optimisticBusy = true;
    });
    try {
      await widget.onPressed?.call();
    } finally {
      if (mounted && _optimisticBusy) {
        setState(() {
          _optimisticBusy = false;
        });
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.space)) {
      return KeyEventResult.ignored;
    }
    unawaited(_activate());
    return KeyEventResult.handled;
  }

  void _syncControllers() {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    final state = _discState;
    final canAnimate = state.enabled && !disableAnimations;
    final loopingEnabled = PokrovLoopingMotion.enabled;

    if (canAnimate && !state.runsSweep) {
      if (PokrovConnectDiscMotion.breathRepeats(
        phase: state.phase,
        disableAnimations: disableAnimations,
        loopingEnabled: loopingEnabled,
      )) {
        // Calm connected breath: slow continuous inhale/exhale loop.
        if (!_breathController.isAnimating ||
            _breathController.duration !=
                PokrovConnectDiscMotion.breathPeriod) {
          _breathController.duration = PokrovConnectDiscMotion.breathPeriod;
          _breathController.repeat(reverse: true);
        }
      } else {
        _breathController.duration = PokrovConnectDiscMotion.breathDuration;
        if (!_breathController.isAnimating &&
            _breathController.status != AnimationStatus.completed) {
          _breathController.forward();
        }
      }
    } else {
      _breathController.stop();
      _breathController.value = 0;
    }

    if (canAnimate && state.runsSweep) {
      if (PokrovConnectDiscMotion.sweepRepeats(
        runsSweep: state.runsSweep,
        disableAnimations: disableAnimations,
        loopingEnabled: loopingEnabled,
      )) {
        // Busy sweep repeats until the phase settles instead of freezing
        // after a single pass while still connecting.
        if (!_sweepController.isAnimating) {
          _sweepController.repeat();
        }
      } else if (!_sweepController.isAnimating &&
          _sweepController.status != AnimationStatus.completed) {
        _sweepController.forward(from: 0);
      }
    } else {
      _sweepController.stop();
      _sweepController.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final p = PokrovPalette.of(context);
    final state = _discState;
    final accent = (widget.degraded || widget.error)
        ? p.warning
        : widget.running
            ? p.connectedGreen
            : p.accent;
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final controlWidth = widget.desktopSize
        ? 360.0
        : (viewportWidth - 48).clamp(280.0, 520.0).toDouble();
    final controlHeight = widget.desktopSize ? 96.0 : 84.0;
    final indicatorSize = widget.desktopSize ? 64.0 : 56.0;
    final background = widget.enabled ? accent : p.surface;
    final onBackground = widget.enabled
        ? ThemeData.estimateBrightnessForColor(background) == Brightness.dark
            ? Colors.white
            : Colors.black
        : p.muted;
    final supportingLabel = _effectiveBusy
        ? 'Настраиваем защищённое соединение'
        : !widget.enabled
            ? 'Завершите подготовку аккаунта'
            : widget.running
                ? 'Защита работает на этом устройстве'
                : (widget.degraded || widget.error)
                    ? 'Нажмите, чтобы повторить'
                    : 'Одно нажатие — и готово';

    if (!widget.desktopSize) {
      return _buildMobileDisc(
        context,
        state: state,
        accent: accent,
        disableAnimations: disableAnimations,
      );
    }

    return Semantics(
      key: const ValueKey('primary-connect-action'),
      button: true,
      enabled: widget.onPressed != null,
      label: widget.presentation.semanticLabel,
      excludeSemantics: true,
      child: FocusableActionDetector(
        key: const ValueKey('primary-connect-focusable'),
        enabled: widget.enabled && widget.onPressed != null,
        focusNode: _focusNode,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              unawaited(_activate());
              return null;
            },
          ),
        },
        onShowFocusHighlight: (focused) {
          if (_discFocused != focused) {
            setState(() => _discFocused = focused);
          }
        },
        child: MouseRegion(
          cursor: widget.onPressed == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _discHovered = true),
          onExit: (_) => setState(() => _discHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed == null ? null : _activate,
            onTapDown: widget.onPressed == null
                ? null
                : (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: widget.onPressed == null
                ? null
                : (_) => setState(() => _pressed = false),
            child: RepaintBoundary(
              child: AnimatedBuilder(
                key: const ValueKey('connect-disc-motion'),
                animation: Listenable.merge([
                  _breathController,
                  _sweepController,
                ]),
                builder: (context, child) {
                  final breath = disableAnimations
                      ? 0.0
                      : Curves.easeInOut.transform(_breathController.value);
                  return Transform.scale(
                    scale: PokrovConnectDiscMotion.scale(
                      pressed: false,
                      runsSweep: state.runsSweep,
                      breathValue: breath,
                      disableAnimations: disableAnimations,
                    ),
                    child: child,
                  );
                },
                // Physical press: compress eases in fast, release springs back.
                // Kept outside the breath/sweep transform so the press reads
                // instantly even mid-loop (HIG: the primary control feels real).
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('connect-disc-scale-settle-${state.runsSweep}'),
                  tween: Tween(
                    begin: state.runsSweep || disableAnimations
                        ? 1.0
                        : PokrovConnectDiscMotion.busyScale,
                    end: 1.0,
                  ),
                  duration: motion.duration(_MotionTokens.standard),
                  curve: PokrovMotionTokens.spring,
                  builder: (context, settleScale, child) =>
                      Transform.scale(scale: settleScale, child: child),
                  child: AnimatedScale(
                    scale: _pressed && !disableAnimations
                        ? PokrovConnectDiscMotion.pressScale
                        : 1.0,
                    duration: motion.duration(PokrovMotionTokens.quick),
                    curve: _pressed ? Curves.easeIn : PokrovMotionTokens.spring,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: widget.running ? 1.0 : 0.0),
                      duration: motion.duration(_MotionTokens.standard),
                      curve: _MotionTokens.ease,
                      builder: (context, runningT, child) {
                        final activeShadow = Color.lerp(
                          p.accent,
                          p.connectedGreen,
                          runningT,
                        )!;
                        return Container(
                          width: controlWidth,
                          height: controlHeight,
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.desktopSize ? 18 : 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: background,
                            borderRadius: BorderRadius.circular(
                              widget.desktopSize ? 28 : 26,
                            ),
                            border: Border.all(
                              color: widget.enabled
                                  ? onBackground.withValues(
                                      alpha: _discFocused ? 0.62 : 0.20,
                                    )
                                  : p.line,
                              width: _discFocused ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: activeShadow.withValues(
                                  alpha: widget.enabled ? 0.24 : 0.06,
                                ),
                                blurRadius: widget.enabled ? 22 : 10,
                                offset: const Offset(0, 9),
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: indicatorSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedContainer(
                                  duration:
                                      motion.duration(_MotionTokens.standard),
                                  curve: _MotionTokens.ease,
                                  decoration: BoxDecoration(
                                    color: onBackground.withValues(alpha: 0.10),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          onBackground.withValues(alpha: 0.22),
                                    ),
                                  ),
                                ),
                                AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _breathController,
                                    _sweepController,
                                    _settleController,
                                  ]),
                                  builder: (context, _) {
                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(
                                        begin: 0,
                                        end: (_discHovered || _discFocused) &&
                                                widget.enabled
                                            ? 1.0
                                            : 0.0,
                                      ),
                                      duration: motion.duration(
                                        PokrovMotionTokens.quick,
                                      ),
                                      curve: _MotionTokens.ease,
                                      builder: (context, hoverT, _) =>
                                          CustomPaint(
                                        size: Size.square(indicatorSize),
                                        painter: _ConnectDiscRimPainter(
                                          accent: onBackground,
                                          brandAccent: onBackground,
                                          connectedAccent: onBackground,
                                          warning: onBackground,
                                          enabled: widget.enabled,
                                          running: widget.running,
                                          degraded:
                                              widget.degraded || widget.error,
                                          busy: state.runsSweep,
                                          disableAnimations: disableAnimations,
                                          breathValue: _breathController.value,
                                          sweepValue: _sweepController.value,
                                          settleT: PokrovMotionTokens.emphasized
                                              .transform(
                                            _settleController.value,
                                          ),
                                          settleFromAngle: _settleFromAngle,
                                          hoverT: hoverT,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _ConnectSettleLayer(
                                  diameter: indicatorSize,
                                  accent: onBackground,
                                  enabled: widget.enabled,
                                  running: widget.running,
                                  degraded: widget.degraded,
                                  error: widget.error,
                                  busy: _effectiveBusy,
                                  disableAnimations: disableAnimations,
                                ),
                                AnimatedSwitcher(
                                  duration:
                                      motion.duration(_MotionTokens.short),
                                  child: _effectiveBusy
                                      ? Icon(
                                          Icons.hourglass_top_rounded,
                                          key: const ValueKey(
                                            'connect-action-progress',
                                          ),
                                          color: onBackground,
                                          size: 24,
                                        )
                                      : Icon(
                                          widget.running
                                              ? Icons.shield_rounded
                                              : Icons
                                                  .power_settings_new_rounded,
                                          key: ValueKey(
                                            'connect-action-icon-${widget.running}',
                                          ),
                                          color: onBackground,
                                          size: 25,
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  key: const ValueKey('connect-disc-label'),
                                  duration:
                                      motion.duration(_MotionTokens.short),
                                  transitionBuilder: _fadeSlideTransition,
                                  child: Text(
                                    widget.actionLabel,
                                    key: ValueKey(widget.actionLabel),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: onBackground,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.15,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  supportingLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: onBackground.withValues(
                                            alpha: 0.76),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            widget.running
                                ? Icons.power_settings_new_rounded
                                : Icons.arrow_forward_rounded,
                            color: onBackground.withValues(alpha: 0.82),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDisc(
    BuildContext context, {
    required PokrovConnectDiscState state,
    required Color accent,
    required bool disableAnimations,
  }) {
    final motion = _MotionScope.of(context);
    final p = PokrovPalette.of(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final diameter = (viewportWidth * 0.56).clamp(196.0, 228.0).toDouble();
    final borderColor = (widget.degraded || widget.error)
        ? p.warning.withValues(alpha: 0.72)
        : widget.running
            ? p.connectedGreen.withValues(alpha: 0.72)
            : _discFocused
                ? p.accent.withValues(alpha: 0.66)
                : p.line;
    final surfaceColor = widget.running
        ? Color.lerp(
            p.surface,
            p.connectedGreen.withValues(alpha: 0.10),
            0.55,
          )!
        : p.surface;

    return Semantics(
      key: const ValueKey('primary-connect-action'),
      container: true,
      button: true,
      enabled: widget.enabled,
      label: widget.actionLabel,
      child: FocusableActionDetector(
        key: const ValueKey('primary-connect-focusable'),
        enabled: widget.enabled && widget.onPressed != null,
        focusNode: _focusNode,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              unawaited(_activate());
              return null;
            },
          ),
        },
        onShowFocusHighlight: (focused) {
          if (_discFocused != focused) {
            setState(() => _discFocused = focused);
          }
        },
        child: MouseRegion(
          cursor: widget.onPressed == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _discHovered = true),
          onExit: (_) => setState(() => _discHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed == null ? null : _activate,
            onTapDown: widget.onPressed == null
                ? null
                : (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: widget.onPressed == null
                ? null
                : (_) => setState(() => _pressed = false),
            child: RepaintBoundary(
              child: AnimatedBuilder(
                key: const ValueKey('connect-disc-motion'),
                animation: _breathController,
                builder: (context, child) {
                  final breath = disableAnimations
                      ? 0.0
                      : Curves.easeInOut.transform(_breathController.value);
                  return Transform.scale(
                    scale: PokrovConnectDiscMotion.scale(
                      pressed: false,
                      runsSweep: state.runsSweep,
                      breathValue: breath,
                      disableAnimations: disableAnimations,
                    ),
                    child: child,
                  );
                },
                child: AnimatedScale(
                  scale: _pressed && !disableAnimations
                      ? PokrovConnectDiscMotion.pressScale
                      : 1,
                  duration: motion.duration(PokrovMotionTokens.quick),
                  curve: _pressed ? Curves.easeIn : PokrovMotionTokens.spring,
                  child: AnimatedContainer(
                    width: diameter,
                    height: diameter,
                    duration: motion.duration(_MotionTokens.standard),
                    curve: _MotionTokens.ease,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: surfaceColor,
                      border: Border.all(
                        color: borderColor,
                        width: _discFocused ? 2 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                    ? 0.18
                                    : 0.055,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 68,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _ConnectSettleLayer(
                                diameter: 68,
                                accent: accent,
                                enabled: widget.enabled,
                                running: widget.running,
                                degraded: widget.degraded,
                                error: widget.error,
                                busy: _effectiveBusy,
                                disableAnimations: disableAnimations,
                              ),
                              AnimatedSwitcher(
                                duration: motion.duration(_MotionTokens.short),
                                switchInCurve: PokrovMotionTokens.spring,
                                switchOutCurve: _MotionTokens.ease,
                                child: _effectiveBusy
                                    ? RotationTransition(
                                        key: const ValueKey(
                                          'connect-action-progress',
                                        ),
                                        turns: Tween<double>(begin: 0, end: 0.5)
                                            .animate(_sweepController),
                                        child: Icon(
                                          Icons.hourglass_top_rounded,
                                          color: accent,
                                          size: 42,
                                        ),
                                      )
                                    : Icon(
                                        Icons.power_settings_new_rounded,
                                        key: ValueKey(
                                          'connect-action-power-${widget.running}',
                                        ),
                                        color: accent,
                                        size: 48,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ExcludeSemantics(
                          child: AnimatedSwitcher(
                            key: const ValueKey('connect-disc-label'),
                            duration: motion.duration(_MotionTokens.short),
                            transitionBuilder: _fadeSlideTransition,
                            child: FittedBox(
                              key: ValueKey(widget.actionLabel),
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.actionLabel,
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: p.ink,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.35,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        if (widget.status != null) ...[
                          const SizedBox(height: 3),
                          widget.status!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectSettleLayer extends StatelessWidget {
  const _ConnectSettleLayer({
    required this.diameter,
    required this.accent,
    required this.enabled,
    required this.running,
    required this.degraded,
    required this.error,
    required this.busy,
    required this.disableAnimations,
  });

  final double diameter;
  final Color accent;
  final bool enabled;
  final bool running;
  final bool degraded;
  final bool error;
  final bool busy;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final state = PokrovConnectDiscState.resolve(
      enabled: enabled,
      running: running,
      degraded: degraded,
      error: error,
      busy: busy,
    );
    final isError = state.isError;
    final isActive = state.isActive;
    final settleColor = isError ? PokrovPalette.of(context).warning : accent;
    final inset = state.settleInset;
    final opacity = state.settleOpacity;

    return IgnorePointer(
      key: const ValueKey('connect-disc-settle-layer'),
      child: AnimatedSwitcher(
        duration: motion.duration(_MotionTokens.standard),
        switchInCurve: _MotionTokens.ease,
        switchOutCurve: _MotionTokens.ease,
        transitionBuilder: (child, animation) {
          if (disableAnimations) {
            return FadeTransition(opacity: animation, child: child);
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: _MotionTokens.ease,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: PokrovConnectDiscMotion.settleScaleBegin,
                end: 1,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: SizedBox.square(
          key: state.settleKey,
          dimension: diameter,
          child: AnimatedOpacity(
            duration: motion.duration(_MotionTokens.short),
            opacity: isActive ? 1 : 0,
            curve: _MotionTokens.ease,
            child: Padding(
              padding: EdgeInsets.all(inset),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: settleColor.withValues(alpha: opacity),
                  border: Border.all(
                    color: settleColor.withValues(alpha: isError ? 0.28 : 0.18),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectDiscRimPainter extends CustomPainter {
  const _ConnectDiscRimPainter({
    required this.accent,
    required this.brandAccent,
    required this.connectedAccent,
    required this.warning,
    required this.enabled,
    required this.running,
    required this.degraded,
    required this.busy,
    required this.disableAnimations,
    required this.breathValue,
    required this.sweepValue,
    required this.settleT,
    required this.settleFromAngle,
    required this.hoverT,
  });

  final Color accent;
  final Color brandAccent;
  final Color connectedAccent;
  final Color warning;
  final bool enabled;
  final bool running;
  final bool degraded;
  final bool busy;
  final bool disableAnimations;
  final double breathValue;
  final double sweepValue;

  /// Arc Handoff progress: 0 = busy sweep geometry, 1 = connected arc.
  /// Reverses toward 0 on release so the arc unwinds into its tail.
  final double settleT;

  /// Busy sweep start angle captured at the landing moment; the settle
  /// travels from here to [PokrovConnectDiscMotion.connectedArcStartAngle].
  final double settleFromAngle;

  /// Pointer hover progress: lifts the rim opacity slightly and fades in a
  /// hairline focus ring 4px inside the rim.
  final double hoverT;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 5;
    final breath =
        disableAnimations ? 0.0 : Curves.easeInOut.transform(breathValue);
    // The landing morph tints brand emerald toward the connected green in
    // step with the geometry, so color and shape arrive together.
    final morphActive = !degraded && (running || (busy && settleT > 0));
    final morphT = morphActive ? settleT : 0.0;
    final landAccent = Color.lerp(brandAccent, connectedAccent, morphT)!;
    final rimAccent = morphActive ? landAccent : accent;
    final baseOpacity = (enabled
            ? _lerp(0.18 + breath * 0.04, 0.40, running ? morphT : 0.0) +
                0.06 * hoverT
            : 0.08)
        .clamp(0.0, 1.0);
    final basePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lerp(1.8, 2.8, running ? morphT : 0.0)
      ..color = rimAccent.withValues(alpha: baseOpacity);

    canvas.drawCircle(center, radius, basePaint);

    if (hoverT > 0 && enabled) {
      final ringPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = rimAccent.withValues(alpha: 0.28 * hoverT);
      canvas.drawCircle(center, radius - 4, ringPaint);
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    if (busy && enabled) {
      if (!running && settleT > 0) {
        // Soft Release: the connected arc unwinds into its tail before the
        // busy sweep takes over — a visual overlay that never delays state.
        final remnantPaint = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _lerp(3.2, 3.1, settleT)
          ..color = landAccent.withValues(alpha: _lerp(0.74, 0.56, settleT));
        final sweep =
            PokrovConnectDiscMotion.connectedArcSweepRadians * settleT;
        final start = PokrovConnectDiscMotion.connectedArcStartAngle +
            PokrovConnectDiscMotion.connectedArcSweepRadians * (1 - settleT);
        canvas.drawArc(rect, start, sweep, false, remnantPaint);
      } else {
        final sweepPaint = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.2
          ..color = accent.withValues(alpha: disableAnimations ? 0.42 : 0.74);
        final startAngle = PokrovConnectDiscMotion.sweepStartAngle(
          disableAnimations: disableAnimations,
          sweepValue: sweepValue,
        );
        canvas.drawArc(
          rect,
          startAngle,
          PokrovConnectDiscMotion.busySweepArcRadians,
          false,
          sweepPaint,
        );
      }
    } else if (degraded && enabled) {
      final warningPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = warning.withValues(alpha: 0.72);
      canvas.drawCircle(center, radius - 1.5, warningPaint);
    } else if (running && enabled) {
      // Arc Handoff: the busy sweep is not swapped for the connected arc —
      // it lands. Start angle travels the shortest path from wherever the
      // sweep pointed, while sweep length, stroke and color morph in step.
      final activePaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = _lerp(3.2, 3.1, settleT)
        ..color = landAccent.withValues(alpha: _lerp(0.74, 0.56, settleT));
      canvas.drawArc(
        rect,
        PokrovConnectDiscMotion.settleStartAngle(
          fromAngle: settleFromAngle,
          t: settleT,
        ),
        _lerp(
          PokrovConnectDiscMotion.busySweepArcRadians,
          PokrovConnectDiscMotion.connectedArcSweepRadians,
          settleT,
        ),
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectDiscRimPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.brandAccent != brandAccent ||
        oldDelegate.connectedAccent != connectedAccent ||
        oldDelegate.warning != warning ||
        oldDelegate.enabled != enabled ||
        oldDelegate.running != running ||
        oldDelegate.degraded != degraded ||
        oldDelegate.busy != busy ||
        oldDelegate.disableAnimations != disableAnimations ||
        oldDelegate.breathValue != breathValue ||
        oldDelegate.sweepValue != sweepValue ||
        oldDelegate.settleT != settleT ||
        oldDelegate.settleFromAngle != settleFromAngle ||
        oldDelegate.hoverT != hoverT;
  }
}
