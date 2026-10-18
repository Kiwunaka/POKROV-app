part of pokrov_app_shell;

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.title,
    required this.lines,
    this.child,
    this.tone = _SectionTone.neutral,
  });

  final String title;
  final List<String> lines;
  final Widget? child;
  final _SectionTone tone;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final colors = switch (tone) {
      _SectionTone.accent => (
          background: p.accent.withValues(alpha: 0.06),
          border: p.accent.withValues(alpha: 0.16),
        ),
      _SectionTone.muted => (background: p.surfaceMuted, border: p.line),
      _SectionTone.neutral => (background: p.surface, border: p.line),
      _SectionTone.reward => (
          background: p.reward.withValues(alpha: 0.12),
          border: p.reward.withValues(alpha: 0.22),
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: PokrovSpacing.lg),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: PokrovRadii.cardLg,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PokrovSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              // titleMedium/w600 keeps card titles a clear tier below the
              // headlineSmall page headers instead of 1px apart.
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: p.muted,
                          height: 1.32,
                        ),
                  ),
                ),
              ),
            ],
            if (child != null) ...[
              SizedBox(height: lines.isEmpty ? 12 : 14),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SeedBackdrop extends StatelessWidget {
  const _SeedBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [p.canvas, p.canvasAlt],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(children: [child]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    this.tone = _SectionTone.neutral,
  });

  final String label;
  final IconData icon;
  final _SectionTone tone;

  @override
  Widget build(BuildContext context) {
    // Thin wrapper over the design-system pill so every status badge in the
    // product shares one height, padding, and type size.
    return PokrovStatusPill(
      label: label,
      icon: icon,
      tone: switch (tone) {
        _SectionTone.accent => PokrovStatusTone.accent,
        _SectionTone.muted => PokrovStatusTone.muted,
        _SectionTone.neutral => PokrovStatusTone.neutral,
        _SectionTone.reward => PokrovStatusTone.reward,
      },
    );
  }
}
