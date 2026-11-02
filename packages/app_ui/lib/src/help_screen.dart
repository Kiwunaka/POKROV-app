import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Помощь»: the connection check first, then quick topics for the AI
/// helper, a person, the report and the rarer tools.
class HelpScreen extends StatelessWidget {
  const HelpScreen({
    super.key,
    required this.phase,
    required this.onCheck,
    this.topics = const ['Не подключается', 'Медленно', 'Сайт не открывается'],
    this.onTopic,
    this.onAssistant,
    this.onHuman,
    this.onReport,
    this.onHistory,
    this.onFeedback,
  });

  final ConnectionPhase phase;
  final VoidCallback onCheck;
  final List<String> topics;
  final ValueChanged<String>? onTopic;
  final VoidCallback? onAssistant;
  final VoidCallback? onHuman;
  final VoidCallback? onReport;
  final VoidCallback? onHistory;
  final VoidCallback? onFeedback;

  @override
  Widget build(BuildContext context) {
    final (status, hint) = switch (phase) {
      ConnectionPhase.on => ('Защищено', 'Проверь ещё раз, если что-то не открывается'),
      ConnectionPhase.connecting => ('Подключаемся', 'Проверка начнётся после подключения'),
      ConnectionPhase.error => ('Не получилось подключиться', 'Проверка покажет, что мешает, и предложит восстановить'),
      ConnectionPhase.off => ('Защита выключена', 'Включи защиту, и POKROV проверит соединение'),
    };
    final rows = [
      if (onAssistant != null) (Icons.chat_bubble_outline_rounded, 'Спросить помощника', 'ИИ ответит сразу, в любое время', onAssistant),
      if (onHuman != null) (Icons.support_agent_rounded, 'Позвать человека', 'Ответ придёт сюда же', onHuman),
      if (onReport != null) (Icons.send_rounded, 'Отправить отчёт', 'Код для поддержки и сводка без ключей', onReport),
      if (onHistory != null) (Icons.history_rounded, 'История и скорость', 'Когда пропадало соединение, ярлыки', onHistory),
      if (onFeedback != null) (Icons.lightbulb_outline_rounded, 'Предложить идею', 'Идеи и замечания попадут команде', onFeedback),
    ];
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          Text('Помощь', style: pokrovTextStyle(context, PokrovText.title), textScaler: pokrovTitleScaler(context)),
          SizedBox(height: 4),
          Text('Сначала ответит ИИ-помощник. Если не поможет, позови человека.', style: pokrovTextStyle(context, PokrovText.body)),
          SizedBox(height: 14),
          PokrovCard(
            color: phase == ConnectionPhase.error ? PokrovColors.warnBg : PokrovColors.surface,
            borderColor: phase == ConnectionPhase.error ? PokrovColors.warnLine : PokrovColors.line,
            child: PokrovEntryRow(
              key: const ValueKey('help-check-connection'),
              icon: Icons.health_and_safety_outlined,
              title: 'Проверить соединение',
              hint: '$status. $hint.',
              onTap: onCheck,
              divider: false,
            ),
          ),
          if (onTopic != null && topics.isNotEmpty) ...[
            SectionLabel('Что случилось?'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final topic in topics) ActionChip(
                label: Text(topic),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onPressed: () => onTopic!(topic),
              ),
            ]),
          ],
          if (rows.isNotEmpty) ...[
            SizedBox(height: 14),
            PokrovCard(child: Column(children: [
              for (final (i, row) in rows.indexed)
                PokrovEntryRow(icon: row.$1, title: row.$2, hint: row.$3, onTap: row.$4, divider: i < rows.length - 1),
            ])),
          ],
        ],
      ),
    );
  }
}
