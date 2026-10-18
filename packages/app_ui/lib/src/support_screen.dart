import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Помощь»: quick topics, the AI answer split into «Коротко» and «Что
/// сделать», a visible way to reach a person and one composer.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.data, required this.onSend, required this.onBack,
    this.onTopic, this.onHuman, this.onAnswerAction, this.onRetry, this.onAssistant,
    this.onReport, this.onFeedback, this.composer, this.composerFocus, this.scrollController, this.adSlot});

  final SupportViewData data;
  final ValueChanged<String> onSend;
  final VoidCallback onBack;
  final ValueChanged<String>? onTopic;
  final VoidCallback? onHuman;
  final ValueChanged<String>? onAnswerAction;
  final VoidCallback? onRetry;
  final VoidCallback? onAssistant;
  final VoidCallback? onReport;
  final VoidCallback? onFeedback;
  final TextEditingController? composer;
  final FocusNode? composerFocus;
  final ScrollController? scrollController;
  final Widget? adSlot;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final _input = widget.composer ?? TextEditingController();
  @override
  void dispose() {
    if (widget.composer == null) _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || widget.data.busy) return;
    widget.onSend(text);
    if (widget.composer == null) _input.clear();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Column(children: [
      Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: ScreenHeader(title: 'Помощь', subtitle: widget.data.subtitle, onBack: widget.onBack)),
      Expanded(child: ListView(
        key: ValueKey('support-chat-message-list'), controller: widget.scrollController,
        padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
        children: [
          if (widget.adSlot != null) widget.adSlot!,
          if (widget.onTopic != null) Wrap(spacing: 8, runSpacing: 8, children: [
            for (final topic in widget.data.topics) ActionChip(label: Text(topic),
              onPressed: widget.data.busy ? null : () => widget.onTopic!(topic)),
          ]),
          for (final message in widget.data.messages) Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: message.fromUser ? _UserBubble(text: message.text)
                : _AssistantBubble(message: message, onAction: widget.onAnswerAction)),
          if (widget.data.busy) Padding(padding: EdgeInsets.all(12), child: Text(widget.data.busyLabel)),
          if (widget.data.notice != null) Text(widget.data.notice!, style: pokrovTextStyle(context, PokrovText.caption)),
          if (widget.onRetry != null) LinkButton(label: 'Попробовать снова', onPressed: widget.onRetry),
          if (widget.onHuman != null) SecondaryButton(label: 'Позвать человека', onPressed: widget.onHuman),
          if (widget.onAssistant != null) LinkButton(label: 'Спросить ИИ-помощника', onPressed: widget.onAssistant),
          if (widget.onReport != null) LinkButton(label: 'Диагностика для поддержки', onPressed: widget.onReport),
          if (widget.onFeedback != null) LinkButton(label: 'Оставить отзыв', onPressed: widget.onFeedback),
        ],
      )),
      Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 12), child: Row(children: [
        Expanded(child: TextField(
          key: ValueKey('support-composer'), controller: _input, focusNode: widget.composerFocus,
          onSubmitted: (_) => _send(), minLines: 1, maxLines: 4,
          decoration: InputDecoration(hintText: 'Опиши, что случилось…',
            filled: true, fillColor: pokrovColor(context, PokrovColors.surface),
            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: pokrovColor(context, PokrovColors.line)))),
        )),
        SizedBox(width: 8),
        IconButton.filled(key: ValueKey('support-send-action'),
          onPressed: widget.data.busy ? null : _send, tooltip: 'Отправить',
          style: IconButton.styleFrom(backgroundColor: pokrovColor(context, PokrovColors.accent), minimumSize: Size(50, 50)),
          icon: Icon(Icons.arrow_upward_rounded, color: pokrovOnAccent(context))),
      ])),
    ])),
  );
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 290),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: pokrovColor(context, PokrovColors.accent),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(6)),
          ),
          child: Text(text, style: TextStyle(fontSize: 15, height: 1.4, color: pokrovOnAccent(context))),
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
    final label = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: pokrovColor(context, PokrovColors.accent));
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 330),
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pokrovColor(context, PokrovColors.surface),
            border: Border.all(color: pokrovColor(context, PokrovColors.line)),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.author.toUpperCase() + (message.author == 'ИИ-помощник' ? ' · КОРОТКО' : ''), style: label),
              SizedBox(height: 4),
              Text(message.short ?? '', style: TextStyle(fontSize: 15, height: 1.4)),
              if (message.steps.isNotEmpty) ...[
                SizedBox(height: 8),
                Text('ЧТО СДЕЛАТЬ', style: label),
                SizedBox(height: 4),
                for (final (i, step) in message.steps.indexed) Text('${i + 1}. $step', style: TextStyle(fontSize: 15, height: 1.45)),
              ],
              if (onAction != null && message.actions.isNotEmpty) Wrap(spacing: 8, children: [
                for (final action in message.actions) TextButton(
                  onPressed: () => onAction!(action.id), child: Text(action.label)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
