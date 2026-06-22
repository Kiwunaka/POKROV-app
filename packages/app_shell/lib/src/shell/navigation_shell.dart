part of pokrov_app_shell;

class _SeedContentList extends StatelessWidget {
  const _SeedContentList({
    required this.children,
    this.top = 12,
    this.maxContentWidth = 900,
  });

  final List<Widget> children;
  final double top;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePadding = constraints.maxWidth >= 980
            ? math.max(24.0, (constraints.maxWidth - maxContentWidth) / 2)
            : 24.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(sidePadding, top, sidePadding, 160),
          children: children,
        );
      },
    );
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
                child: _LazyIndexedStack(
                  index: selectedIndex,
                  builders: sectionBuilders,
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
            child: _LazyIndexedStack(
              index: selectedIndex,
              builders: sectionBuilders,
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
          child: _LazyIndexedStack(
            index: selectedIndex,
            builders: sectionBuilders,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.line),
                  boxShadow: [
                    BoxShadow(
                      color: p.ink.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: NavigationBar(
                  height: 64,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onSelected,
                  destinations: const [
                    NavigationDestination(
                      key: ValueKey('nav-protection'),
                      icon: Icon(Icons.flash_on_outlined),
                      selectedIcon: Icon(Icons.flash_on),
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
              icon: Icons.flash_on_outlined,
              selectedIcon: Icons.flash_on,
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
  late List<bool> _initialized;

  @override
  void initState() {
    super.initState();
    _initialized = List<bool>.filled(widget.builders.length, false);
    _markInitialized(widget.index);
  }

  @override
  void didUpdateWidget(_LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.builders.length != widget.builders.length) {
      final previous = _initialized;
      _initialized = List<bool>.generate(
        widget.builders.length,
        (index) => index < previous.length && previous[index],
      );
    }
    _markInitialized(widget.index);
  }

  void _markInitialized(int index) {
    if (index >= 0 && index < _initialized.length) {
      _initialized[index] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    _markInitialized(widget.index);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final entry in widget.builders.indexed)
          Offstage(
            offstage: entry.$1 != widget.index,
            child: TickerMode(
              enabled: entry.$1 == widget.index,
              child: RepaintBoundary(
                child: _initialized[entry.$1]
                    ? entry.$2(context)
                    : const SizedBox.shrink(),
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
                _pokrovAppVersion,
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
              icon: Icons.flash_on_outlined,
              selectedIcon: Icons.flash_on,
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
    final label = Text(
      'POKROV',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: PokrovPalette.of(context).ink,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
    );
    final children = [
      _BrandMark(size: markSize),
      const SizedBox(width: 10),
      label,
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
