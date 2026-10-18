import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Помощь»: quick topics, the AI answer split into «Коротко» and «Что
/// сделать», a visible way to reach a person and one composer.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.data, required this.onSend, required this.onBack, this.onTopic, this.onHuman, this.onAnswerAction});

  final SupportViewData data;
  final ValueChanged<String> onSend;
  final VoidCallback onBack;
  final ValueChanged<String>? onTopic;
  final VoidCallback? onHuman;

  /// Called with «reconnect» or «solved».
  final ValueChanged<String>? onAnswerAction;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: ScreenHeader(title: 'Помощь', subtitle: 'Сначала ответит ИИ, потом человек', onBack: widget.onBack),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final topic in widget.data.topics)
                        ActionChip(
                          label: Text(topic),
                          onPressed: () => widget.onTopic?.call(topic),
                          backgroundColor: PokrovColors.surface,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          labelStyle: const TextStyle(fontFamily: pokrovFontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: PokrovColors.ink),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final m in widget.data.messages) ...[
                    m.fromUser ? _UserBubble(text: m.text) : _AssistantBubble(message: m, onAction: widget.onAnswerAction),
                    const SizedBox(height: 8),
                  ],
                  Center(
                    child: OutlinedButton(
                      onPressed: widget.onHuman,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PokrovColors.accent,
                        side: const BorderSide(color: Color(0x5912805A)),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontFamily: pokrovFontFamily, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Позвать человека'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Опиши, что случилось…',
                        filled: true,
                        fillColor: PokrovColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: PokrovColors.line)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: Color(0x14111814))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    tooltip: 'Отправить',
                    style: IconButton.styleFrom(backgroundColor: PokrovColors.accent, minimumSize: const Size(50, 50)),
                    icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: PokrovColors.accent,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(6)),
          ),
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white)),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.message, this.onAction});

  final ChatMessage message;
  final ValueChanged<String>? onAction;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: PokrovColors.accent);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PokrovColors.surface,
            border: Border.all(color: PokrovColors.line),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ИИ-ПОМОЩНИК · КОРОТКО', style: label),
              const SizedBox(height: 4),
              Text(message.short ?? '', style: const TextStyle(fontSize: 15, height: 1.4)),
              if (message.steps.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('ЧТО СДЕЛАТЬ', style: label),
                const SizedBox(height: 4),
                for (final (i, step) in message.steps.indexed) Text('${i + 1}. $step', style: const TextStyle(fontSize: 15, height: 1.45)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton(
                    onPressed: () => onAction?.call('reconnect'),
                    style: FilledButton.styleFrom(backgroundColor: PokrovColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Переподключить'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => onAction?.call('solved'),
                    style: TextButton.styleFrom(backgroundColor: PokrovColors.chip, foregroundColor: PokrovColors.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Помогло ✓'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
