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
    required this.actionLabel,
    required this.enabled,
    required this.running,
    required this.degraded,
    required this.error,
    required this.busy,
    required this.onPressed,
    this.desktopSize = false,
  });

  final String actionLabel;
  final bool enabled;
  final bool running;
  final bool degraded;
  final bool error;
  final bool busy;
  final VoidCallback? onPressed;
  final bool desktopSize;

  @override
  State<_ConnectOrbButton> createState() => _ConnectOrbButtonState();
}

class _ConnectOrbButtonState extends State<_ConnectOrbButton>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _sweepController;

  /// Arc Handoff: 0 = busy sweep geometry, 1 = connected arc geometry.
  /// Runs forward on landing, in reverse on release; finite either way.
  late final AnimationController _settleController;
  double _settleFromAngle = PokrovConnectDiscMotion.connectedArcStartAngle;
  bool _pressed = false;
  bool _discHovered = false;
  bool _optimisticBusy = false;

  @override
  void initState() {
    super.initState();
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
        oldWidget.busy != widget.busy) {
      // Must run before the sweep reset: the landing captures the current
      // sweep angle so the arc lands from wherever it points right now.
      _handlePhaseChange(oldWidget);
      _breathController.reset();
      _sweepController.reset();
      _optimisticBusy = false;
    }
    _syncControllers();
  }

  /// Arc Handoff + Soft Release choreography and the shell's whole phase
  /// haptic budget: one success at landing, a quiet tap at rest. Errors keep
  /// their haptic in the snack layer — the disc never buzzes for trouble.
  void _handlePhaseChange(_ConnectOrbButton oldWidget) {
    final oldPhase = PokrovConnectDiscState.resolve(
      enabled: oldWidget.enabled,
      running: oldWidget.running,
      degraded: oldWidget.degraded,
      error: oldWidget.error,
      busy: oldWidget.busy,
    ).phase;
    final newPhase = PokrovConnectDiscState.resolve(
      enabled: widget.enabled,
      running: widget.running,
      degraded: widget.degraded,
      error: widget.error,
      busy: widget.busy,
    ).phase;
    if (newPhase == oldPhase) {
      return;
    }
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
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
      PokrovHaptics.success();
      return;
    }
    if (oldPhase == PokrovConnectDiscPhase.connected) {
      // Unwind from the current value — cancelable mid-flight, never queued.
      if (disableAnimations) {
        _settleController.value = 0;
      } else {
        _settleController.reverse();
      }
      if (newPhase == PokrovConnectDiscPhase.idle) {
        PokrovHaptics.tap();
      }
      return;
    }
    if (newPhase == PokrovConnectDiscPhase.idle) {
      // Landing at rest is an exhale, deliberately quieter than connect.
      PokrovHaptics.tap();
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
    super.dispose();
  }

  PokrovConnectDiscState get _discState => PokrovConnectDiscState.resolve(
    enabled: widget.enabled,
    running: widget.running,
    degraded: widget.degraded,
    error: widget.error,
    busy: _effectiveBusy,
  );

  bool get _effectiveBusy => widget.busy || _optimisticBusy;

  void _syncControllers() {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
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
    // pokrov-clear canon: the running (connected) disc is the one place that
    // uses the shared iOS status green; busy/idle stay on the brand emerald.
    final accent = (widget.degraded || widget.error)
        ? p.warning
        : widget.running
        ? p.connectedGreen
        : p.accent;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
    final diameter = widget.desktopSize
        ? 208.0
        : switch (MediaQuery.sizeOf(context).width) {
            >= 600 => 168.0,
            >= 390 => 158.0,
            _ => 148.0,
          };
    final labelColor = widget.enabled ? p.ink : p.muted;
    final markOpacity = !widget.enabled
        ? 0.34
        : (widget.degraded || widget.error)
        ? 0.62
        : _effectiveBusy
        ? 0.72
        : 1.0;

    return Semantics(
      key: const ValueKey('primary-connect-action'),
      button: true,
      enabled: widget.enabled,
      label: widget.actionLabel,
      child: MouseRegion(
        cursor: widget.onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _discHovered = true),
        onExit: (_) => setState(() => _discHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed == null
              ? null
              : () {
                  Feedback.forTap(context);
                  PokrovHaptics.tap();
                  setState(() {
                    _optimisticBusy = true;
                  });
                  widget.onPressed?.call();
                },
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
                // Soft Release: leaving the busy compression springs back to
                // rest instead of stepping — one finite pass per sweep exit.
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
                  // Border eases between rest and connected weights so the
                  // release reads as a deliberate exhale, not a flag flip.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: widget.running ? 1.0 : 0.0),
                    duration: motion.duration(_MotionTokens.standard),
                    curve: _MotionTokens.ease,
                    builder: (context, runningT, child) {
                      final borderAccent = (widget.degraded || widget.error)
                          ? p.warning
                          : Color.lerp(p.accent, p.connectedGreen, runningT)!;
                      return Container(
                        width: diameter,
                        height: diameter,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.surface,
                          border: Border.all(
                            color: borderAccent.withValues(
                              alpha: 0.34 + (0.54 - 0.34) * runningT,
                            ),
                            width: 2.1 + (2.6 - 2.1) * runningT,
                          ),
                          // Soft accent-tinted lift: the hero control floats
                          // above the canvas instead of sitting flat on it.
                          boxShadow: [
                            BoxShadow(
                              color: (widget.running ? accent : p.ink)
                                  .withValues(
                                    alpha:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? 0.35
                                        : widget.running
                                        ? 0.18
                                        : 0.08,
                                  ),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _breathController,
                            _sweepController,
                            _settleController,
                          ]),
                          builder: (context, _) {
                            // Pointer grammar: hover lifts the rim and shows a
                            // hairline focus ring — material, not geometry.
                            return TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: _discHovered && widget.enabled ? 1.0 : 0.0,
                              ),
                              duration: motion.duration(
                                PokrovMotionTokens.quick,
                              ),
                              curve: _MotionTokens.ease,
                              builder: (context, hoverT, _) => CustomPaint(
                                size: Size.square(diameter),
                                painter: _ConnectDiscRimPainter(
                                  accent: accent,
                                  brandAccent: p.accent,
                                  connectedAccent: p.connectedGreen,
                                  warning: p.warning,
                                  enabled: widget.enabled,
                                  running: widget.running,
                                  degraded: widget.degraded || widget.error,
                                  busy: state.runsSweep,
                                  disableAnimations: disableAnimations,
                                  breathValue: _breathController.value,
                                  sweepValue: _sweepController.value,
                                  settleT: PokrovMotionTokens.emphasized
                                      .transform(_settleController.value),
                                  settleFromAngle: _settleFromAngle,
                                  hoverT: hoverT,
                                ),
                              ),
                            );
                          },
                        ),
                        _ConnectSettleLayer(
                          diameter: diameter,
                          accent: accent,
                          enabled: widget.enabled,
                          running: widget.running,
                          degraded: widget.degraded,
                          error: widget.error,
                          busy: _effectiveBusy,
                          disableAnimations: disableAnimations,
                        ),
                        // Connected morph: the inner plate takes a faint green
                        // wash so the state is glanceable, not forensic. The disc
                        // is the one sanctioned connectedGreen surface.
                        AnimatedContainer(
                          duration: motion.duration(_MotionTokens.standard),
                          curve: _MotionTokens.ease,
                          decoration: BoxDecoration(
                            color: widget.running
                                ? Color.alphaBlend(
                                    accent.withValues(alpha: 0.10),
                                    p.canvas,
                                  )
                                : p.canvas,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: p.line.withValues(alpha: 0.72),
                            ),
                          ),
                          child: SizedBox.square(
                            dimension: diameter * 0.70,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _BrandMark(
                                    size: diameter * 0.23,
                                    opacity: markOpacity,
                                  ),
                                  SizedBox(height: diameter < 180 ? 7 : 9),
                                  SizedBox(
                                    width: diameter * 0.66,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: AnimatedSwitcher(
                                        key: const ValueKey(
                                          'connect-disc-label',
                                        ),
                                        duration: motion.duration(
                                          _MotionTokens.short,
                                        ),
                                        transitionBuilder: _fadeSlideTransition,
                                        child: Text(
                                          widget.actionLabel,
                                          key: ValueKey(widget.actionLabel),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.visible,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: labelColor,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
    final breath = disableAnimations
        ? 0.0
        : Curves.easeInOut.transform(breathValue);
    // The landing morph tints brand emerald toward the connected green in
    // step with the geometry, so color and shape arrive together.
    final morphActive = !degraded && (running || (busy && settleT > 0));
    final morphT = morphActive ? settleT : 0.0;
    final landAccent = Color.lerp(brandAccent, connectedAccent, morphT)!;
    final rimAccent = morphActive ? landAccent : accent;
    final baseOpacity =
        (enabled
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
        final start =
            PokrovConnectDiscMotion.connectedArcStartAngle +
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
