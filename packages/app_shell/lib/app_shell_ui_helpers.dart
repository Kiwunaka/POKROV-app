part of pokrov_app_shell;

class _ProfileHubTile extends StatelessWidget {
  const _ProfileHubTile({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    this.tone = _SectionTone.neutral,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final _SectionTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      _SectionTone.accent => _SeedPalette.accent.withOpacity(0.1),
      _SectionTone.muted => Colors.white.withOpacity(0.72),
      _SectionTone.neutral => Colors.white.withOpacity(0.84),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _SeedPalette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: _SeedPalette.accent),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _SeedPalette.ink.withOpacity(0.72),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _SeedPalette.ink,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.ink.withOpacity(0.68),
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.ink.withOpacity(0.62),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
