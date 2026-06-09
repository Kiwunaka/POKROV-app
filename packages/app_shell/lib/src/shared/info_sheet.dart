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

void _showInfoSheet(
  BuildContext context, {
  required String title,
  required List<String> lines,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: _SeedPalette.surface,
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
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _SeedPalette.ink.withValues(alpha: 0.72),
                        height: 1.35,
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
