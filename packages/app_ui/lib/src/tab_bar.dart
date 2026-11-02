import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';

/// Floating bottom bar: «Защита · Доступ · Помощь · Настройки».
class PokrovTabBar extends StatelessWidget {
  const PokrovTabBar({super.key, required this.current, required this.onSelect});

  final PokrovTab current;
  final ValueChanged<PokrovTab> onSelect;

  @override
  Widget build(BuildContext context) {
    const tabs = <(PokrovTab, String, IconData, IconData)>[
      (PokrovTab.protection, 'Защита', Icons.shield_outlined, Icons.shield_rounded),
      (PokrovTab.access, 'Доступ', Icons.vpn_key_outlined, Icons.vpn_key_rounded),
      (PokrovTab.help, 'Помощь', Icons.help_outline_rounded, Icons.help_rounded),
      (PokrovTab.settings, 'Настройки', Icons.settings_outlined, Icons.settings_rounded),
    ];
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        constraints: BoxConstraints(minHeight: 72),
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: pokrovColor(context, PokrovColors.surface),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Color(0x0D111814)),
          boxShadow: [BoxShadow(color: Color(0x1A101814), blurRadius: 30, offset: Offset(0, 10))],
        ),
        child: Row(
          children: [
            for (final (tab, label, icon, activeIcon) in tabs)
              Expanded(
                child: Semantics(
                  key: ValueKey('nav-${tab.name}'),
                  selected: tab == current,
                  button: true,
                  label: label,
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: () => onSelect(tab),
                    radius: 36,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 64),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: tab == current ? 1.08 : 1,
                            duration: PokrovMotion.quick,
                            curve: PokrovMotion.spring,
                            child: Icon(tab == current ? activeIcon : icon, size: 24, color: tab == current ? pokrovColor(context, PokrovColors.accent) : pokrovColor(context, PokrovColors.muted)),
                          ),
                          SizedBox(height: 3),
                          // Large text shrinks the label instead of clipping it.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: AnimatedDefaultTextStyle(
                              duration: PokrovMotion.quick,
                              style: TextStyle(
                                fontFamily: pokrovFontFamily,
                                fontSize: 12,
                                fontWeight: tab == current ? FontWeight.w800 : FontWeight.w600,
                                color: tab == current ? pokrovColor(context, PokrovColors.ink) : pokrovColor(context, PokrovColors.muted),
                              ),
                              child: Text(label, maxLines: 1),
                            ),
                          ),
                        ],
                      ),
                      ),
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
