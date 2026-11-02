import 'package:flutter/material.dart';

import 'tokens.dart';
import 'widgets.dart';

/// A widget the person can put on the main screen.
class HomeTileOption {
  const HomeTileOption({required this.id, required this.title, required this.hint, required this.icon});

  final String id;
  final String title;
  final String hint;
  final IconData icon;
}

/// «Виджеты на главной»: what is shown, in which order, and what can be
/// added. Every change is reported at once through [onChanged].
class HomeTilesSheet extends StatefulWidget {
  const HomeTilesSheet({super.key, required this.options, required this.selected, required this.defaults, required this.onChanged});

  final List<HomeTileOption> options;
  final List<String> selected;
  final List<String> defaults;
  final ValueChanged<List<String>> onChanged;

  @override
  State<HomeTilesSheet> createState() => _HomeTilesSheetState();
}

class _HomeTilesSheetState extends State<HomeTilesSheet> {
  late List<String> _selected = [...widget.selected];

  void _set(List<String> next) {
    setState(() => _selected = next);
    widget.onChanged(List.unmodifiable(next));
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final option in widget.options) option.id: option};
    final shown = [for (final id in _selected) if (byId[id] != null) byId[id]!];
    final available = [for (final option in widget.options) if (!_selected.contains(option.id)) option];
    Widget action(String label, String semantic, VoidCallback onTap) => TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: Size(48, 48), foregroundColor: pokrovColor(context, PokrovColors.accent)),
      child: Semantics(label: semantic, excludeSemantics: true, child: Text(label)),
    );
    Widget line(HomeTileOption option, List<Widget> actions, bool divider) => Container(
      constraints: BoxConstraints(minHeight: 60),
      decoration: BoxDecoration(border: divider ? Border(bottom: BorderSide(color: pokrovColor(context, PokrovColors.line))) : null),
      child: Row(children: [
        IconSquare(icon: option.icon, size: 36),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(option.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(option.hint, style: pokrovTextStyle(context, PokrovText.caption)),
        ])),
        ...actions,
      ]),
    );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          key: const ValueKey('home-tiles-sheet'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Виджеты на главной', style: pokrovTextStyle(context, PokrovText.heading), textScaler: pokrovTitleScaler(context)),
            SizedBox(height: 6),
            Text('Выбери, что видно на экране «Защита». Всё остальное по-прежнему в Доступе, Помощи и Настройках.', style: pokrovTextStyle(context, PokrovText.body)),
            SectionLabel('На главной'),
            if (shown.isEmpty) Text('Пока пусто: на главной только кнопка и состояние.', style: pokrovTextStyle(context, PokrovText.caption))
            else PokrovCard(child: Column(children: [
              for (final (i, option) in shown.indexed) line(option, [
                if (i > 0) action('↑', 'Выше: ${option.title}', () => _set([..._selected]..removeAt(_selected.indexOf(option.id))..insert(_selected.indexOf(option.id) - 1, option.id))),
                action('Убрать', 'Убрать: ${option.title}', () => _set([..._selected]..remove(option.id))),
              ], i < shown.length - 1),
            ])),
            SectionLabel('Можно добавить'),
            if (available.isEmpty) Text('Все виджеты уже на главной.', style: pokrovTextStyle(context, PokrovText.caption))
            else PokrovCard(child: Column(children: [
              for (final (i, option) in available.indexed)
                line(option, [action('Добавить', 'Добавить: ${option.title}', () => _set([..._selected, option.id]))], i < available.length - 1),
            ])),
            SizedBox(height: 8),
            LinkButton(label: 'Вернуть как было', onPressed: () => _set([...widget.defaults])),
          ],
        ),
      ),
    );
  }
}
