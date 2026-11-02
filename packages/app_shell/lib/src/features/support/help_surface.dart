part of pokrov_app_shell;

/// «Помощь» tab: entry points into the existing protection check, support
/// chat, diagnostics and feedback. It owns no support state itself.
class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.phase,
    required this.onCheck,
    required this.onAssistant,
    required this.onTopic,
    required this.onHuman,
    required this.onReport,
    required this.onHistory,
    required this.onFeedback,
  });

  final ui.ConnectionPhase phase;
  final VoidCallback onCheck;
  final VoidCallback onAssistant;
  final ValueChanged<String> onTopic;
  final VoidCallback onHuman;
  final VoidCallback onReport;
  final VoidCallback onHistory;
  final VoidCallback onFeedback;

  @override
  Widget build(BuildContext context) => ui.HelpScreen(
    phase: phase,
    onCheck: onCheck,
    onTopic: onTopic,
    onAssistant: onAssistant,
    onHuman: onHuman,
    onReport: onReport,
    onHistory: onHistory,
    onFeedback: onFeedback,
  );
}
