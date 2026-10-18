import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';

/// Floating bottom bar: «Защита · Локации · (Правила) · Профиль».
/// «Правила» appears only in the advanced interface.
class PokrovTabBar extends StatelessWidget {
  const PokrovTabBar({super.key, required this.mode, required this.current, required this.onSelect});

  final InterfaceMode mode;
  final PokrovTab current;
  final ValueChanged<PokrovTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final tabs = <(PokrovTab, String, IconData, IconData)>[
      (PokrovTab.protection, 'Защита', Icons.shield_outlined, Icons.shield_rounded),
      (PokrovTab.locations, 'Локации', Icons.public_rounded, Icons.public_rounded),
      if (mode == InterfaceMode.advanced) (PokrovTab.rules, 'Правила', Icons.alt_route_rounded, Icons.alt_route_rounded),
      (PokrovTab.profile, 'Профиль', Icons.person_outline_rounded, Icons.person_rounded),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: PokrovColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0x0D111814)),
          boxShadow: const [BoxShadow(color: Color(0x1A101814), blurRadius: 30, offset: Offset(0, 10))],
        ),
        child: Row(
          children: [
            for (final (tab, label, icon, activeIcon) in tabs)
              Expanded(
                child: Semantics(
                  selected: tab == current,
                  button: true,
                  label: label,
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: () => onSelect(tab),
                    radius: 36,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: tab == current ? 1.08 : 1,
                          duration: PokrovMotion.quick,
                          curve: PokrovMotion.spring,
                          child: Icon(tab == current ? activeIcon : icon, size: 24, color: tab == current ? PokrovColors.accent : PokrovColors.muted),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: PokrovMotion.quick,
                          style: TextStyle(
                            fontFamily: pokrovFontFamily,
                            fontSize: 12,
                            fontWeight: tab == current ? FontWeight.w800 : FontWeight.w600,
                            color: tab == current ? PokrovColors.ink : PokrovColors.muted,
                          ),
                          child: Text(label),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
