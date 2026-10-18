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
  });

  final RulesViewData data;
  final ValueChanged<String> onSelect;
  final VoidCallback onApply;
  final VoidCallback? onApps;
  final VoidCallback? onPresets;
  final VoidCallback? onExpert;
  final VoidCallback? onWarning;

  @override
  Widget build(BuildContext context) {
    final selected = data.modes.firstWhere((m) => m.id == data.selectedId, orElse: () => data.modes.first);
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 190),
            children: [
              const Text('Правила', style: PokrovText.title),
              const SectionLabel('Что пускать через POKROV'),
              PokrovCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Column(
                  children: [
                    for (final (i, m) in data.modes.indexed)
                      Semantics(
                        selected: m.id == data.selectedId,
                        button: true,
                        child: InkWell(
                          onTap: () => onSelect(m.id),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 54),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              border: i < data.modes.length - 1 ? const Border(bottom: BorderSide(color: PokrovColors.line)) : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m.title, style: PokrovText.rowTitle),
                                      if (m.recommended) const Text('советуем', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PokrovColors.accent)),
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
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: AnimatedSwitcher(
                  duration: PokrovMotion.quick,
                  child: Text(selected.description, key: ValueKey(selected.id), style: PokrovText.caption),
                ),
              ),
              const SizedBox(height: 8),
              PokrovCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    PokrovRow(title: 'Приложения', value: data.appsSummary, onTap: onApps ?? () {}),
                    PokrovRow(title: 'Готовые наборы', value: data.presetsSummary, onTap: onPresets ?? () {}),
                    PokrovRow(title: 'Для опытных', value: data.expertSummary, onTap: onExpert ?? () {}, divider: false),
                  ],
                ),
              ),
              if (data.warning != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onWarning,
                    icon: Container(width: 7, height: 7, decoration: const BoxDecoration(color: PokrovColors.warnDot, shape: BoxShape.circle)),
                    label: Text.rich(
                      TextSpan(
                        text: '${data.warning} · ',
                        style: const TextStyle(fontSize: 13, color: PokrovColors.warnStrong, fontWeight: FontWeight.w400),
                        children: const [TextSpan(text: 'Обновить', style: TextStyle(color: PokrovColors.accent, fontWeight: FontWeight.w700))],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 104,
            child: AnimatedSlide(
              offset: data.hasPendingChange ? Offset.zero : const Offset(0, 1.6),
              duration: const Duration(milliseconds: 450),
              curve: PokrovMotion.spring,
              child: AnimatedOpacity(
                opacity: data.hasPendingChange ? 1 : 0,
                duration: PokrovMotion.quick,
                child: IgnorePointer(
                  ignoring: !data.hasPendingChange,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(PokrovRadii.button),
                      boxShadow: const [BoxShadow(color: Color(0x4D12805A), blurRadius: 24, offset: Offset(0, 10))],
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
