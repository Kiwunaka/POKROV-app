part of pokrov_app_shell;

/// Signature-arc pull-to-refresh: while dragging, the connect arc draws in
/// proportionally (sweep = drag share of the connected arc); armed and
/// refreshing it rotates with the disc's busy-sweep period until the real
/// future completes; the settle fades out briskly. One signature shape is
/// the refresh language app-wide — direct manipulation, no foreign spinner.
Widget _pokrovRefreshArcBuilder(
  BuildContext context,
  RefreshIndicatorMode refreshState,
  double pulledExtent,
  double refreshTriggerPullDistance,
  double refreshIndicatorExtent,
) {
  return _PokrovRefreshArc(
    mode: refreshState,
    drag: (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0),
  );
}

class _PokrovRefreshArc extends StatefulWidget {
  const _PokrovRefreshArc({
    required this.mode,
    required this.drag,
  });

  final RefreshIndicatorMode mode;
  final double drag;

  @override
  State<_PokrovRefreshArc> createState() => _PokrovRefreshArcState();
}

class _PokrovRefreshArcState extends State<_PokrovRefreshArc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: PokrovConnectDiscMotion.sweepDuration,
  );

  bool get _spinning =>
      widget.mode == RefreshIndicatorMode.armed ||
      widget.mode == RefreshIndicatorMode.refresh;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant _PokrovRefreshArc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode == RefreshIndicatorMode.drag &&
        widget.mode == RefreshIndicatorMode.armed) {
      // Direct manipulation acknowledged: one tick at the arm threshold.
      PokrovHaptics.tap();
    }
    _syncSpin();
  }

  /// Progress rotation, not decoration: it loops only behind the shared
  /// looping gate and keeps the finite single pass under `flutter test`,
  /// so `pumpAndSettle` contracts stay bounded.
  void _syncSpin() {
    final disableAnimations = _MotionScope.of(context).disableAnimations;
    if (_spinning && !disableAnimations) {
      if (PokrovLoopingMotion.enabled) {
        if (!_spin.isAnimating) {
          _spin.repeat();
        }
      } else if (!_spin.isAnimating &&
          _spin.status != AnimationStatus.completed) {
        _spin.forward(from: 0);
      }
    } else {
      _spin.stop();
      if (!_spinning) {
        _spin.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final motion = _MotionScope.of(context);
    return Center(
      child: AnimatedOpacity(
        // Settle: the arc fades out briskly once the refresh resolves.
        duration: motion.duration(PokrovMotionTokens.quick),
        curve: _MotionTokens.ease,
        opacity: widget.mode == RefreshIndicatorMode.done ? 0 : 1,
        child: SizedBox(
          width: 22,
          height: 22,
          child: AnimatedBuilder(
            animation: _spin,
            builder: (context, _) => CustomPaint(
              painter: _PokrovRefreshArcPainter(
                color: p.accent,
                sweep: _spinning
                    ? PokrovConnectDiscMotion.connectedArcSweepRadians
                    : PokrovConnectDiscMotion.connectedArcSweepRadians *
                        widget.drag,
                rotation: _spin.value * math.pi * 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PokrovRefreshArcPainter extends CustomPainter {
  const _PokrovRefreshArcPainter({
    required this.color,
    required this.sweep,
    required this.rotation,
  });

  final Color color;
  final double sweep;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    if (sweep <= 0.01) {
      return;
    }
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: size.shortestSide / 2 - 1.5,
      ),
      PokrovConnectDiscMotion.connectedArcStartAngle + rotation,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PokrovRefreshArcPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.sweep != sweep ||
        oldDelegate.rotation != rotation;
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.advanced, required this.selectedIndex,
    required this.sectionBuilders, required this.onSelected});

  final bool advanced;
  final int selectedIndex;
  final List<WidgetBuilder> sectionBuilders;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Stack(children: [
        Positioned.fill(child: _TabTransition(
          index: selectedIndex,
          child: _LazyIndexedStack(index: selectedIndex, builders: sectionBuilders),
        )),
        Align(alignment: Alignment.bottomCenter, child: ui.PokrovTabBar(
          mode: advanced ? ui.InterfaceMode.advanced : ui.InterfaceMode.simple,
          current: ui.PokrovTab.values[selectedIndex],
          onSelect: (tab) {
            if (tab.index == selectedIndex) return;
            PokrovHaptics.tap();
            onSelected(tab.index);
          },
        )),
      ]),
    ),
  );
}

/// Calm cross-tab transition: fades 0.92 -> 1 over [_MotionTokens.short]
/// while the content drifts 8px in from the side of travel (vertically for
/// the desktop sidebar), confirming the spatial model of the navigation.
/// The wrapped [_LazyIndexedStack] keeps every opened tab alive and reduced
/// motion switches instantly.
class _TabTransition extends StatefulWidget {
  const _TabTransition({
    required this.index,
    required this.child,
  }) : super(key: const ValueKey('tab-transition-motion'));

  final int index;
  final Widget child;


  @override
  State<_TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<_TabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _MotionTokens.short,
    value: 1,
  );

  /// +1 when moving to a later tab, -1 for an earlier one: the new content
  /// enters from the direction of travel.
  double _direction = 1;

  @override
  void didUpdateWidget(covariant _TabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) {
      return;
    }
    _direction = widget.index > oldWidget.index ? 1 : -1;
    if (_MotionScope.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = _MotionScope.of(context).disableAnimations
            ? 1.0
            : _MotionTokens.emphasized.transform(_controller.value);
        // Hard-capped at 8px: any more and the fade-dominant transition
        // starts reading as a carousel.
        final drift = (1 - progress) * 8 * _direction;
        return Opacity(
          opacity: 0.92 + 0.08 * progress,
          child: Transform.translate(
            offset: Offset(drift, 0),
            child: child,
          ),
        );
      },
    );
  }
}

class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({
    required this.index,
    required this.builders,
  }) : super(key: const ValueKey('lazy-indexed-stack'));

  final int index;
  final List<WidgetBuilder> builders;

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late List<Widget?> _children;

  @override
  void initState() {
    super.initState();
    _children = List<Widget?>.filled(widget.builders.length, null);
  }

  @override
  void didUpdateWidget(_LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.builders.length != widget.builders.length) {
      final previous = _children;
      _children = List<Widget?>.generate(
        widget.builders.length,
        (index) => index < previous.length ? previous[index] : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep inactive widget configurations stable. Activation uses the latest
    // builder so account and runtime changes are visible before the tab paints.
    for (final entry in widget.builders.indexed) {
      if (entry.$1 == widget.index) {
        _children[entry.$1] = entry.$2(context);
      }
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final entry in _children.indexed)
          Offstage(
            offstage: entry.$1 != widget.index,
            child: TickerMode(
              enabled: entry.$1 == widget.index,
              child: RepaintBoundary(
                child: entry.$2 ?? const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({
    this.markSize = 32,
    this.center = false,
  });

  final double markSize;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final label = Text(
      'POKROV',
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: PokrovPalette.of(context).ink,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
    );
    if (center && largeText) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrandMark(size: markSize),
          const SizedBox(height: 6),
          label,
        ],
      );
    }
    final children = <Widget>[
      _BrandMark(size: markSize),
      const SizedBox(width: 10),
      Flexible(child: label),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: children,
    );
  }
}

class _BrandMark extends PokrovBrandMark {
  const _BrandMark({
    required double size,
    double opacity = 1,
  }) : super(
          size: size,
          opacity: opacity,
          assetName: _pokrovBrandMarkAsset,
        );
}
