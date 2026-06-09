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
    final colors = switch (tone) {
      _SectionTone.accent => (
          background: _SeedPalette.accent.withValues(alpha: 0.06),
          border: _SeedPalette.accent.withValues(alpha: 0.14),
        ),
      _SectionTone.muted => (
          background: _SeedPalette.surfaceMuted,
          border: _SeedPalette.line,
        ),
      _SectionTone.neutral => (
          background: _SeedPalette.surface,
          border: _SeedPalette.line,
        ),
      _SectionTone.reward => (
          background: const Color(0xFFFFF8E1),
          border: Color(0x33B99745),
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: _SeedPalette.ink.withValues(alpha: 0.035),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
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
                          color: _SeedPalette.muted,
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_SeedPalette.canvas, _SeedPalette.canvasAlt],
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
    final background = switch (tone) {
      _SectionTone.accent => _SeedPalette.accent.withValues(alpha: 0.12),
      _SectionTone.muted => _SeedPalette.surfaceMuted.withValues(alpha: 0.92),
      _SectionTone.neutral => Colors.white.withValues(alpha: 0.86),
      _SectionTone.reward => const Color(0xFFFFF3CF),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _SeedPalette.accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _SeedPalette.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
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
  });

  final String actionLabel;
  final bool enabled;
  final bool running;
  final bool degraded;
  final bool error;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  State<_ConnectOrbButton> createState() => _ConnectOrbButtonState();
}

class _ConnectOrbButtonState extends State<_ConnectOrbButton>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _sweepController;
  bool _pressed = false;

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
      _breathController.reset();
      _sweepController.reset();
    }
    _syncControllers();
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
        busy: widget.busy,
      );

  void _syncControllers() {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    final state = _discState;
    final canAnimate = state.enabled && !disableAnimations;

    if (canAnimate && !state.runsSweep) {
      if (!_breathController.isAnimating &&
          _breathController.status != AnimationStatus.completed) {
        _breathController.forward();
      }
    } else {
      _breathController.stop();
      _breathController.value = 0;
    }

    if (canAnimate && state.runsSweep) {
      if (!_sweepController.isAnimating &&
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
    final state = _discState;
    final accent = (widget.degraded || widget.error)
        ? const Color(0xFFB5673A)
        : widget.running
            ? _SeedPalette.accentBright
            : _SeedPalette.accent;
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    final diameter = switch (MediaQuery.sizeOf(context).width) {
      >= 720 => 210.0,
      _ => 182.0,
    };
    final labelColor = widget.enabled ? _SeedPalette.ink : _SeedPalette.muted;
    final markOpacity = !widget.enabled
        ? 0.34
        : (widget.degraded || widget.error)
            ? 0.62
            : widget.busy
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
                  widget.onPressed?.call();
                },
          onTapDown: widget.onPressed == null
              ? null
              : (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: widget.onPressed == null
              ? null
              : (_) => setState(() => _pressed = false),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
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
                        pressed: _pressed,
                        runsSweep: state.runsSweep,
                        breathValue: breath,
                        disableAnimations: disableAnimations,
                      ),
                      child: child,
                    );
                  },
                  child: AnimatedContainer(
                    duration: motion.duration(_MotionTokens.standard),
                    curve: _MotionTokens.ease,
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.running
                          ? _SeedPalette.accent.withValues(alpha: 0.11)
                          : _SeedPalette.surface,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.running ? accent : _SeedPalette.ink)
                              .withValues(alpha: widget.running ? 0.14 : 0.07),
                          blurRadius: widget.running ? 26 : 18,
                          offset: const Offset(0, 10),
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
                          busy: widget.busy,
                          disableAnimations: disableAnimations,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: _SeedPalette.surface.withValues(alpha: 0.74),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(
                                  alpha: widget.running ? 0.18 : 0.10),
                            ),
                          ),
                          child: SizedBox.square(
                            dimension: diameter * 0.58,
                            child: Center(
                              child: _BrandMark(
                                size: diameter * 0.42,
                                opacity: markOpacity,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                key: const ValueKey('connect-disc-label'),
                duration: motion.duration(_MotionTokens.short),
                transitionBuilder: _fadeSlideTransition,
                child: Text(
                  widget.actionLabel,
                  key: ValueKey(widget.actionLabel),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                ),
              ),
            ],
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
    final settleColor = isError ? _SeedPalette.warning : accent;
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
                  boxShadow: [
                    BoxShadow(
                      color: settleColor.withValues(alpha: opacity * 0.7),
                      blurRadius: isError ? 18 : 24,
                      spreadRadius: isError ? 1 : 2,
                    ),
                  ],
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
    required this.enabled,
    required this.running,
    required this.degraded,
    required this.busy,
    required this.disableAnimations,
    required this.breathValue,
    required this.sweepValue,
  });

  final Color accent;
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
            ? 0.36
            : 0.16 + breath * 0.08
        : 0.08;
    final basePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = running ? 3.2 : 2.2
      ..color = accent.withValues(alpha: baseOpacity);

    canvas.drawCircle(center, radius, basePaint);

    if (busy && enabled) {
      final sweepPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
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
        ..strokeWidth = 3
        ..color = _SeedPalette.warning.withValues(alpha: 0.72);
      canvas.drawCircle(center, radius - 1.5, warningPaint);
    } else if (running && enabled) {
      final activePaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
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
        oldDelegate.enabled != enabled ||
        oldDelegate.running != running ||
        oldDelegate.degraded != degraded ||
        oldDelegate.busy != busy ||
        oldDelegate.disableAnimations != disableAnimations ||
        oldDelegate.breathValue != breathValue ||
        oldDelegate.sweepValue != sweepValue;
  }
}
