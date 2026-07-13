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
      _SectionTone.muted => (
          background: p.surfaceMuted,
          border: p.line,
        ),
      _SectionTone.neutral => (
          background: p.surface,
          border: p.line,
        ),
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: p.ink,
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
  const _SeedBackdrop({
    required this.child,
  });

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
      child: Stack(
        children: [
          child,
        ],
      ),
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
  bool _pressed = false;
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
      _emitPhaseHaptics(oldWidget);
      _breathController.reset();
      _sweepController.reset();
      _optimisticBusy = false;
    }
    _syncControllers();
  }

  void _emitPhaseHaptics(_ConnectOrbButton oldWidget) {
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
    if (newPhase == PokrovConnectDiscPhase.connected) {
      PokrovHaptics.success();
    } else if (newPhase == PokrovConnectDiscPhase.error) {
      PokrovHaptics.error();
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _sweepController.dispose();
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
    // pokrov-clear canon: the running (connected) disc is the one place that
    // uses the shared iOS status green; busy/idle stay on the brand emerald.
    final accent = (widget.degraded || widget.error)
        ? p.warning
        : widget.running
            ? p.connectedGreen
            : p.accent;
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
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
              animation:
                  Listenable.merge([_breathController, _sweepController]),
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
              child: AnimatedScale(
                scale: _pressed && !disableAnimations
                    ? PokrovConnectDiscMotion.pressScale
                    : 1.0,
                duration: motion.duration(PokrovMotionTokens.quick),
                curve: _pressed ? Curves.easeIn : PokrovMotionTokens.spring,
                child: Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.surface,
                  border: Border.all(
                    color:
                        accent.withValues(alpha: widget.running ? 0.54 : 0.34),
                    width: widget.running ? 2.6 : 2.1,
                  ),
                  // Soft accent-tinted lift: the hero control floats above
                  // the canvas instead of sitting flat on it.
                  boxShadow: [
                    BoxShadow(
                      color: (widget.running ? accent : p.ink).withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge(
                          [_breathController, _sweepController]),
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size.square(diameter),
                          painter: _ConnectDiscRimPainter(
                            accent: accent,
                            warning: p.warning,
                            enabled: widget.enabled,
                            running: widget.running,
                            degraded: widget.degraded || widget.error,
                            busy: state.runsSweep,
                            disableAnimations: disableAnimations,
                            breathValue: _breathController.value,
                            sweepValue: _sweepController.value,
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
                                accent.withValues(alpha: 0.10), p.canvas)
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
                                    key: const ValueKey('connect-disc-label'),
                                    duration:
                                        motion.duration(_MotionTokens.short),
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
                    color: settleColor.withValues(
                      alpha: isError ? 0.28 : 0.18,
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

class _ConnectDiscRimPainter extends CustomPainter {
  const _ConnectDiscRimPainter({
    required this.accent,
    required this.warning,
    required this.enabled,
    required this.running,
    required this.degraded,
    required this.busy,
    required this.disableAnimations,
    required this.breathValue,
    required this.sweepValue,
  });

  final Color accent;
  final Color warning;
  final bool enabled;
  final bool running;
  final bool degraded;
  final bool busy;
  final bool disableAnimations;
  final double breathValue;
  final double sweepValue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 5;
    final breath =
        disableAnimations ? 0.0 : Curves.easeInOut.transform(breathValue);
    final baseOpacity = enabled
        ? running
            ? 0.40
            : 0.18 + breath * 0.04
        : 0.08;
    final basePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = running ? 2.8 : 1.8
      ..color = accent.withValues(alpha: baseOpacity);

    canvas.drawCircle(center, radius, basePaint);

    if (busy && enabled) {
      final sweepPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.2
        ..color = accent.withValues(alpha: disableAnimations ? 0.42 : 0.74);
      final rect = Rect.fromCircle(center: center, radius: radius);
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
    } else if (degraded && enabled) {
      final warningPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = warning.withValues(alpha: 0.72);
      canvas.drawCircle(center, radius - 1.5, warningPaint);
    } else if (running && enabled) {
      final activePaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.1
        ..color = accent.withValues(alpha: 0.56);
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        PokrovConnectDiscMotion.connectedArcStartAngle,
        PokrovConnectDiscMotion.connectedArcSweepRadians,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectDiscRimPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.warning != warning ||
        oldDelegate.enabled != enabled ||
        oldDelegate.running != running ||
        oldDelegate.degraded != degraded ||
        oldDelegate.busy != busy ||
        oldDelegate.disableAnimations != disableAnimations ||
        oldDelegate.breathValue != breathValue ||
        oldDelegate.sweepValue != sweepValue;
  }
}
