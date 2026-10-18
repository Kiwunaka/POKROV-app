import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Правила»: one list of modes with checkmarks, three entry rows and a
/// one-line warning instead of error cards. The apply bar slides in only
/// when the selection differs from what is applied.
class RulesScreen extends StatelessWidget {
  const RulesScreen({
    super.key,
    required this.data,
    required this.onSelect,
    required this.onApply,
    this.onApps,
    this.onPresets,
    this.onExpert,
    this.onWarning,
    this.onServices,
    this.expertContent,
  });

  final RulesViewData data;
  final ValueChanged<String> onSelect;
  final VoidCallback onApply;
  final VoidCallback? onApps;
  final VoidCallback? onPresets;
  final VoidCallback? onExpert;
  final VoidCallback? onWarning;
  final VoidCallback? onServices;
  final Widget? expertContent;

  @override
  Widget build(BuildContext context) {
    final selected = data.modes.firstWhere((m) => m.id == data.selectedId, orElse: () => data.modes.first);
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 190),
            children: [
              Text('Правила', style: pokrovTextStyle(context, PokrovText.title)),
              SectionLabel('Что пускать через POKROV'),
              PokrovCard(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Column(
                  children: [
                    for (final (i, m) in data.modes.indexed)
                      Semantics(
                        selected: m.id == data.selectedId,
                        button: true,
                        child: InkWell(
                          onTap: () => onSelect(m.id),
                          child: Container(
                            constraints: BoxConstraints(minHeight: 54),
                            padding: EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              border: i < data.modes.length - 1 ? Border(bottom: BorderSide(color: pokrovColor(context, PokrovColors.line))) : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m.title, style: pokrovTextStyle(context, PokrovText.rowTitle)),
                                      if (m.recommended) Text('советуем', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pokrovColor(context, PokrovColors.accent))),
                                    ],
                                  ),
                                ),
                                SelectionCheck(visible: m.id == data.selectedId),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: AnimatedSwitcher(
                  duration: PokrovMotion.quick,
                  child: Text(selected.description, key: ValueKey(selected.id), style: pokrovTextStyle(context, PokrovText.caption)),
                ),
              ),
              SizedBox(height: 8),
              PokrovCard(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (onApps != null) PokrovRow(title: 'Приложения', value: data.appsSummary, onTap: onApps),
                    if (onPresets != null) PokrovRow(title: 'Готовые наборы', value: data.presetsSummary, onTap: onPresets),
                    if (onServices != null) PokrovRow(title: 'Выбрать сервисы и режим', onTap: onServices),
                    if (onExpert != null) PokrovRow(title: 'Для опытных', value: data.expertSummary, onTap: onExpert, divider: false),
                  ],
                ),
              ),
              if (data.warning != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onWarning,
                    icon: Container(width: 7, height: 7, decoration: BoxDecoration(color: pokrovColor(context, PokrovColors.warnDot), shape: BoxShape.circle)),
                    label: Text.rich(
                      TextSpan(
                        text: '${data.warning} · ',
                        style: TextStyle(fontSize: 13, color: pokrovColor(context, PokrovColors.warnStrong), fontWeight: FontWeight.w400),
                        children: [TextSpan(text: 'Обновить', style: TextStyle(color: pokrovColor(context, PokrovColors.accent), fontWeight: FontWeight.w700))],
                      ),
                    ),
                  ),
                ),
              if (expertContent != null) expertContent!,
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 104,
            child: AnimatedSlide(
              offset: data.hasPendingChange ? Offset.zero : Offset(0, 1.6),
              duration: Duration(milliseconds: 450),
              curve: PokrovMotion.spring,
              child: AnimatedOpacity(
                opacity: data.hasPendingChange ? 1 : 0,
                duration: PokrovMotion.quick,
                child: IgnorePointer(
                  ignoring: !data.hasPendingChange,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(PokrovRadii.button),
                      boxShadow: [BoxShadow(color: Color(0x4D12805A), blurRadius: 24, offset: Offset(0, 10))],
                    ),
                    child: PrimaryButton(label: 'Применить', icon: Icons.check_rounded, onPressed: onApply),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
