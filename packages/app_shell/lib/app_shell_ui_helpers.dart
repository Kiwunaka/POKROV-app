part of pokrov_app_shell;

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine({
    required this.label,
    required this.value,
    this.valueWidget,
  });

  final String label;
  final String value;

  /// Optional live replacement for the plain value text (e.g. the living
  /// days counter); [value] stays the semantic source of truth.
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
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
                    color: p.muted,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: valueWidget ??
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
          ),
        ],
      ),
    );
  }
}
