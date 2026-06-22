import 'package:flutter/material.dart';

import 'pokrov_brand.dart';
import 'pokrov_controls.dart';
import 'pokrov_motion.dart';
import 'pokrov_palette.dart';

class PokrovSidebarDestination {
  const PokrovSidebarDestination({
    required this.itemKey,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final Key itemKey;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class PokrovDesktopSidebar extends StatelessWidget {
  PokrovDesktopSidebar({
    required this.selectedIndex,
    required this.onSelected,
    required this.collapsed,
    required this.destinations,
    this.drawer = false,
    this.brandTitle = 'POKROV',
    this.versionLabel = '',
    this.betaLabel = '',
    this.brandMarkAssetName = PokrovBrandAssets.mark,
    super.key,
  }) : assert(destinations.isNotEmpty);

  static const expandedKey = ValueKey('desktop-sidebar-expanded');
  static const iconRailKey = ValueKey('desktop-icon-rail');
  static const labelMotionKey = ValueKey('desktop-sidebar-label-motion');

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool collapsed;
  final bool drawer;
  final List<PokrovSidebarDestination> destinations;
  final String brandTitle;
  final String versionLabel;
  final String betaLabel;
  final String brandMarkAssetName;

  Key get effectiveKey => key ?? (collapsed ? iconRailKey : expandedKey);

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 72.0 : 224.0;
    final tokens = PokrovPalette.of(context);
    return SizedBox(
      key: effectiveKey,
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
              PokrovBrandMark(size: 32, assetName: brandMarkAssetName)
            else ...[
              _PokrovBrandLockup(
                markSize: 34,
                title: brandTitle,
                assetName: brandMarkAssetName,
              ),
              const SizedBox(height: 4),
              if (versionLabel.trim().isNotEmpty)
                Text(
                  versionLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: tokens.muted,
                      ),
                ),
            ],
            const SizedBox(height: 28),
            for (final entry in destinations.indexed)
              _PokrovSidebarItem(
                itemKey: entry.$2.itemKey,
                index: entry.$1,
                selectedIndex: selectedIndex,
                icon: entry.$2.icon,
                selectedIcon: entry.$2.selectedIcon,
                label: entry.$2.label,
                onSelected: onSelected,
                collapsed: collapsed,
              ),
            const Spacer(),
            if (collapsed && betaLabel.trim().isNotEmpty)
              Icon(
                Icons.info_outline_rounded,
                color: tokens.muted,
                size: 20,
              )
            else if (betaLabel.trim().isNotEmpty)
              PokrovStatusPill(
                label: betaLabel,
                icon: Icons.info_outline_rounded,
                tone: PokrovStatusTone.muted,
              ),
          ],
        ),
      ),
    );
  }
}

class _PokrovBrandLockup extends StatelessWidget {
  const _PokrovBrandLockup({
    required this.title,
    required this.assetName,
    this.markSize = 32,
  });

  final String title;
  final String assetName;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    final label = Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PokrovBrandMark(size: markSize, assetName: assetName),
        const SizedBox(width: 10),
        label,
      ],
    );
  }
}

class _PokrovSidebarItem extends StatelessWidget {
  const _PokrovSidebarItem({
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
    final tokens = PokrovPalette.of(context);
    final child = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: itemKey,
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelected(index),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? tokens.accent.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 8 : 12,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (!collapsed) ...[
                    Container(
                      width: 2,
                      height: 20,
                      decoration: BoxDecoration(
                        color: selected
                            ? tokens.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 9),
                  ],
                  Icon(
                    selected ? selectedIcon : icon,
                    size: 20,
                    color:
                        selected ? tokens.accent : tokens.muted,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      key: PokrovDesktopSidebar.labelMotionKey,
                      child: AnimatedOpacity(
                        duration: PokrovMotionScope.of(context).duration(
                          PokrovMotionTokens.short,
                        ),
                        curve: PokrovMotionTokens.ease,
                        opacity: collapsed ? 0 : 1,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: selected
                                        ? tokens.ink
                                        : tokens.muted,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w600,
                                  ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
