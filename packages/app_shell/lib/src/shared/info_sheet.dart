part of pokrov_app_shell;

class _SettingsRow extends PokrovSettingsRow {
  const _SettingsRow({
    super.key,
    required super.icon,
    required super.title,
    required super.value,
    super.onTap,
  });
}

/// Shared modal-sheet motion: [PokrovMotionTokens.sheet] with the emphasized
/// deceleration curve, collapsing to zero duration under reduced motion.
AnimationStyle _pokrovSheetAnimationStyle(BuildContext context) {
  if (_MotionScope.of(context).disableAnimations) {
    return const AnimationStyle(
      duration: Duration.zero,
      reverseDuration: Duration.zero,
    );
  }
  return const AnimationStyle(
    duration: _MotionTokens.sheet,
    reverseDuration: _MotionTokens.sheet,
    curve: _MotionTokens.emphasized,
    reverseCurve: _MotionTokens.emphasized,
  );
}

void _showInfoSheet(
  BuildContext context, {
  required String title,
  required List<String> lines,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (context) => _InfoSheet(title: title, lines: lines),
  );
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: p.ink,
                  ),
            ),
            const SizedBox(height: 12),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: p.muted,
                        height: 1.4,
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
