import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Group whose entries carry the «leave it if unsure» note.
const String pokrovExpertGroup = 'Для опытных';

/// «Настройки»: one search over every entry, then the entries by group.
/// The query is the only state here; entries and actions come from the app.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.entries});

  final List<SettingsEntry> entries;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(SettingsEntry entry, String q) =>
      '${entry.title} ${entry.hint} ${entry.keywords} ${entry.group}'.toLowerCase().contains(q);

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final shown = q.isEmpty ? widget.entries : widget.entries.where((e) => _matches(e, q)).toList();
    final groups = <String, List<SettingsEntry>>{};
    for (final entry in shown) {
      (groups[entry.group] ??= []).add(entry);
    }
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          Text('Настройки', style: pokrovTextStyle(context, PokrovText.title), textScaler: pokrovTitleScaler(context)),
          SizedBox(height: 12),
          TextField(
            key: const ValueKey('settings-search'),
            controller: _query,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Поиск: DNS, Wi-Fi, код, тема…',
              prefixIcon: Icon(Icons.search_rounded),
              suffixIcon: q.isEmpty ? null : IconButton(
                tooltip: 'Очистить поиск',
                icon: Icon(Icons.close_rounded),
                onPressed: () => setState(_query.clear),
              ),
              filled: true,
              fillColor: pokrovColor(context, PokrovColors.surface),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: pokrovColor(context, PokrovColors.line))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: pokrovColor(context, PokrovColors.line))),
            ),
          ),
          if (shown.isEmpty) Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text('Ничего не нашли. Попробуй другое слово или спроси во вкладке «Помощь».', style: pokrovTextStyle(context, PokrovText.body)),
          ),
          for (final MapEntry(key: group, value: entries) in groups.entries) ...[
            SectionLabel(group),
            if (group == pokrovExpertGroup && q.isEmpty) Padding(
              padding: EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text('Если не знаешь, зачем это, ничего не меняй: POKROV работает и без этих настроек.', style: pokrovTextStyle(context, PokrovText.caption)),
            ),
            PokrovCard(child: Column(children: [
              for (final (i, entry) in entries.indexed) PokrovEntryRow(
                key: ValueKey('settings-${entry.title}'),
                icon: entry.icon, title: entry.title, hint: entry.hint, value: entry.value,
                toggled: entry.toggled, onTap: entry.onTap, divider: i < entries.length - 1,
              ),
            ])),
          ],
        ],
      ),
    );
  }
}
