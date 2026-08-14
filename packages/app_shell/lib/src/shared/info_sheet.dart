part of pokrov_app_shell;

class _SettingsRow extends PokrovSettingsRow {
  const _SettingsRow({
    super.key,
    required super.icon,
    required super.title,
    required super.value,
    super.onTap,
    super.enabled,
    super.valueIsAction,
    super.external,
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
    // Present gently, dismiss briskly: symmetric sheets feel sluggish.
    reverseDuration: Duration(milliseconds: 200),
    curve: _MotionTokens.emphasized,
    reverseCurve: Curves.easeInCubic,
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
            _SheetReveal(
              order: 0,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: p.ink,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            for (final (index, line) in lines.indexed)
              _SheetReveal(
                order: index + 1,
                child: Padding(
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

/// Sheet content cascade: the container arrives first, then rows settle into
/// it — fade + 6px rise, 30ms stagger per row (capped at five steps so the
/// tail never drags), each over [PokrovMotionTokens.short] with the
/// emphasized curve. Same finite, reduced-motion-safe construction as the
/// onboarding reveal.
class _SheetReveal extends StatelessWidget {
  const _SheetReveal({
    required this.order,
    required this.child,
  });

  static const _stagger = Duration(milliseconds: 30);
  static const _maxOrder = 5;

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = PokrovMotionScope.of(context);
    final cappedOrder = math.min(order, _maxOrder);
    final duration = motion.duration(
      PokrovMotionTokens.short + _stagger * cappedOrder,
    );
    if (duration == Duration.zero) {
      return child;
    }
    final start =
        _stagger.inMilliseconds * cappedOrder / duration.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(start, 1, curve: PokrovMotionTokens.emphasized),
      builder: (context, value, staged) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 6),
          child: staged,
        ),
      ),
      child: child,
    );
  }
}
