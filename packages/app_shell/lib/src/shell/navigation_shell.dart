part of pokrov_app_shell;

class _SeedContentList extends StatelessWidget {
  const _SeedContentList({
    required this.children,
    // One shared top gutter so the page rhythm does not jump between tabs.
    this.top = 16,
    this.maxContentWidth = 900,
    this.onRefresh,
    this.refreshIndicatorKey,
  });

  final List<Widget> children;
  final double top;
  final double maxContentWidth;

  /// When set, refresh follows host physics: Apple uses the signature sliver,
  /// while Android/Windows use Material pull-to-refresh.
  final Future<void> Function()? onRefresh;
  final Key? refreshIndicatorKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePadding = constraints.maxWidth >= 980
            ? math.max(24.0, (constraints.maxWidth - maxContentWidth) / 2)
            : 24.0;
        final padding = EdgeInsets.fromLTRB(sidePadding, top, sidePadding, 160);
        final onRefresh = this.onRefresh;
        if (onRefresh == null) {
          return ListView(padding: padding, children: children);
        }
        final platform = Theme.of(context).platform;
        final physics = AlwaysScrollableScrollPhysics(
          parent: pokrovScrollPhysicsFor(platform),
        );
        if (!pokrovUsesCupertinoInteraction(platform)) {
          return RefreshIndicator(
            key: refreshIndicatorKey,
            color: PokrovPalette.of(context).accent,
            onRefresh: onRefresh,
            child: ListView(
              physics: physics,
              padding: padding,
              children: children,
            ),
          );
        }
        return CustomScrollView(
          physics: physics,
          slivers: [
            CupertinoSliverRefreshControl(
              key: refreshIndicatorKey,
              onRefresh: onRefresh,
              builder: _pokrovRefreshArcBuilder,
            ),
            SliverPadding(
              padding: padding,
              sliver: SliverList.list(children: children),
            ),
          ],
        );
      },
    );
  }
}

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

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.selectedIndex,
    required this.sectionBuilders,
    required this.onSelected,
  }) : super(key: const ValueKey('desktop-shell'));

  final int selectedIndex;
  final List<WidgetBuilder> sectionBuilders;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return _DesktopDrawerShell(
            selectedIndex: selectedIndex,
            sectionBuilders: sectionBuilders,
            onSelected: onSelected,
          );
        }
        final collapsed = constraints.maxWidth < 1180;
        final p = PokrovPalette.of(context);
        return Row(
          children: [
            RepaintBoundary(
              child: _DesktopSidebar(
                selectedIndex: selectedIndex,
                onSelected: onSelected,
                collapsed: collapsed,
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: p.line),
                  ),
                ),
                child: _TabTransition(
                  index: selectedIndex,
                  axis: Axis.vertical,
                  child: _LazyIndexedStack(
                    index: selectedIndex,
                    builders: sectionBuilders,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DesktopDrawerShell extends StatelessWidget {
  const _DesktopDrawerShell({
    required this.selectedIndex,
    required this.sectionBuilders,
    required this.onSelected,
  }) : super(key: const ValueKey('desktop-drawer-shell'));

  final int selectedIndex;
  final List<WidgetBuilder> sectionBuilders;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawerScrimColor: p.ink.withValues(alpha: 0.18),
      drawer: Drawer(
        key: const ValueKey('desktop-sidebar-drawer'),
        backgroundColor: p.canvas,
        child: SafeArea(
          child: RepaintBoundary(
            child: _DesktopSidebar(
              selectedIndex: selectedIndex,
              onSelected: (index) {
                Navigator.of(context).maybePop();
                onSelected(index);
              },
              collapsed: false,
              drawer: true,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 58,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Builder(
                  builder: (buttonContext) {
                    return IconButton(
                      key: const ValueKey('desktop-sidebar-hamburger'),
                      tooltip: 'Меню',
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(buttonContext).openDrawer(),
                    );
                  },
                ),
                const SizedBox(width: 8),
                const _BrandLockup(markSize: 28),
              ],
            ),
          ),
          Expanded(
            child: _TabTransition(
              index: selectedIndex,
              child: _LazyIndexedStack(
                index: selectedIndex,
                builders: sectionBuilders,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.selectedIndex,
    required this.sectionBuilders,
    required this.onSelected,
  }) : super(key: const ValueKey('mobile-shell'));

  final int selectedIndex;
  final List<WidgetBuilder> sectionBuilders;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Column(
      children: [
        Expanded(
          child: _TabTransition(
            index: selectedIndex,
            child: _LazyIndexedStack(
              index: selectedIndex,
              builders: sectionBuilders,
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.line),
                  boxShadow: [
                    BoxShadow(
                      // Shadows darken, they never emit: ink is near-white in
                      // dark mode, so anchor the dark-mode shadow on black.
                      color: (Theme.of(context).brightness == Brightness.dark
                              ? Colors.black
                              : p.ink)
                          .withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.35
                            : 0.06,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: NavigationBar(
                  height: 64,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    // Selection tick for the thumb — pointer navigation on
                    // desktop and same-tab taps stay silent.
                    if (index == selectedIndex) {
                      return;
                    }
                    PokrovHaptics.tap();
                    onSelected(index);
                  },
                  destinations: const [
                    NavigationDestination(
                      key: ValueKey('nav-protection'),
                      icon: Icon(Icons.shield_outlined),
                      selectedIcon: Icon(Icons.shield_rounded),
                      label: 'Защита',
                    ),
                    NavigationDestination(
                      key: ValueKey('nav-locations'),
                      icon: Icon(Icons.public_outlined),
                      selectedIcon: Icon(Icons.public),
                      label: 'Локации',
                    ),
                    NavigationDestination(
                      key: ValueKey('nav-rules'),
                      icon: Icon(Icons.rule_folder_outlined),
                      selectedIcon: Icon(Icons.rule_folder),
                      label: 'Правила',
                    ),
                    NavigationDestination(
                      key: ValueKey('nav-profile'),
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Профиль',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopSidebar extends PokrovDesktopSidebar {
  _DesktopSidebar({
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    required bool collapsed,
    bool drawer = false,
  }) : super(
          selectedIndex: selectedIndex,
          onSelected: onSelected,
          collapsed: collapsed,
          drawer: drawer,
          brandMarkAssetName: _pokrovBrandMarkAsset,
          versionLabel: '',
          betaLabel: '',
          destinations: const [
            PokrovSidebarDestination(
              itemKey: ValueKey('nav-protection'),
              icon: Icons.shield_outlined,
              selectedIcon: Icons.shield_rounded,
              label: 'Защита',
            ),
            PokrovSidebarDestination(
              itemKey: ValueKey('nav-locations'),
              icon: Icons.public_outlined,
              selectedIcon: Icons.public,
              label: 'Локации',
            ),
            PokrovSidebarDestination(
              itemKey: ValueKey('nav-rules'),
              icon: Icons.rule_folder_outlined,
              selectedIcon: Icons.rule_folder,
              label: 'Правила',
            ),
            PokrovSidebarDestination(
              itemKey: ValueKey('nav-profile'),
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Профиль',
            ),
          ],
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
    this.axis = Axis.horizontal,
  }) : super(key: const ValueKey('tab-transition-motion'));

  final int index;
  final Widget child;

  /// Travel axis of the hosting navigation row or rail.
  final Axis axis;

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
            offset: widget.axis == Axis.horizontal
                ? Offset(drift, 0)
                : Offset(0, drift),
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

class PokrovLegacyDesktopSidebar extends StatelessWidget {
  PokrovLegacyDesktopSidebar({
    required this.selectedIndex,
    required this.onSelected,
    required this.collapsed,
    this.drawer = false,
  }) : super(
          key: collapsed
              ? const ValueKey('desktop-icon-rail')
              : const ValueKey('desktop-sidebar-expanded'),
        );

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool collapsed;
  final bool drawer;

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 72.0 : 224.0;
    final p = PokrovPalette.of(context);
    return AnimatedContainer(
      duration: _MotionScope.of(context).duration(_MotionTokens.standard),
      curve: _MotionTokens.ease,
      width: drawer ? 224 : width,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          collapsed ? 10 : 18,
          22,
          collapsed ? 10 : 18,
          18,
        ),
        child: Column(
          crossAxisAlignment:
              collapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (collapsed)
              const _BrandMark(size: 32)
            else ...[
              const _BrandLockup(markSize: 34),
              const SizedBox(height: 4),
              Text(
                pokrovClientVersion,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: p.muted,
                    ),
              ),
            ],
            const SizedBox(height: 28),
            _SidebarItem(
              itemKey: const ValueKey('nav-protection'),
              index: 0,
              selectedIndex: selectedIndex,
              icon: Icons.shield_outlined,
              selectedIcon: Icons.shield_rounded,
              label: 'Защита',
              onSelected: onSelected,
              collapsed: collapsed,
            ),
            _SidebarItem(
              itemKey: const ValueKey('nav-locations'),
              index: 1,
              selectedIndex: selectedIndex,
              icon: Icons.public_outlined,
              selectedIcon: Icons.public,
              label: 'Локации',
              onSelected: onSelected,
              collapsed: collapsed,
            ),
            _SidebarItem(
              itemKey: const ValueKey('nav-rules'),
              index: 2,
              selectedIndex: selectedIndex,
              icon: Icons.rule_folder_outlined,
              selectedIcon: Icons.rule_folder,
              label: 'Правила',
              onSelected: onSelected,
              collapsed: collapsed,
            ),
            _SidebarItem(
              itemKey: const ValueKey('nav-profile'),
              index: 3,
              selectedIndex: selectedIndex,
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Профиль',
              onSelected: onSelected,
              collapsed: collapsed,
            ),
            const Spacer(),
            const SizedBox.shrink(),
          ],
        ),
      ),
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

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.itemKey,
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onSelected,
    this.collapsed = false,
  });

  final Key itemKey;
  final int index;
  final int selectedIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final ValueChanged<int> onSelected;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final p = PokrovPalette.of(context);
    final child = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        key: itemKey,
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 8 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? p.accent.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment:
                collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (!collapsed) ...[
                Container(
                  width: 2,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? p.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Icon(
                selected ? selectedIcon : icon,
                size: 20,
                color: selected ? p.accent : p.muted,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                AnimatedSize(
                  key: const ValueKey('desktop-sidebar-label-motion'),
                  duration: _MotionScope.of(context).duration(
                    _MotionTokens.short,
                  ),
                  curve: _MotionTokens.ease,
                  alignment: Alignment.centerLeft,
                  child: AnimatedOpacity(
                    duration: _MotionScope.of(context).duration(
                      _MotionTokens.short,
                    ),
                    curve: _MotionTokens.ease,
                    opacity: collapsed ? 0 : 1,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: selected ? p.ink : p.muted,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (collapsed) {
      return Tooltip(message: label, child: child);
    }
    return child;
  }
}
