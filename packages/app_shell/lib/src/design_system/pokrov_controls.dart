import 'package:flutter/material.dart';

import 'pokrov_motion.dart';
import 'pokrov_palette.dart';

Widget pokrovFadeSlideTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: PokrovMotionTokens.ease,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

class PokrovStatusDotLabel extends StatelessWidget {
  const PokrovStatusDotLabel({
    required this.label,
    required this.color,
    super.key,
  });

  static const switcherKey = ValueKey('home-status-switcher');
  static const dotMotionKey = ValueKey('home-status-dot-motion');

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final motion = PokrovMotionScope.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        AnimatedContainer(
          key: dotMotionKey,
          duration: motion.duration(PokrovMotionTokens.short),
          curve: PokrovMotionTokens.ease,
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        AnimatedSwitcher(
          key: switcherKey,
          duration: motion.duration(PokrovMotionTokens.short),
          transitionBuilder: pokrovFadeSlideTransition,
          child: Text(
            label,
            key: ValueKey(label),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: PokrovPalette.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}

class PokrovHomeChip extends StatefulWidget {
  const PokrovHomeChip({
    super.key,
    required this.icon,
    required this.label,
    this.minLabelWidth = 0,
    this.onTap,
  });

  static const motionKey = ValueKey('home-chip-motion');
  static const labelMotionKey = ValueKey('home-chip-label-motion');

  final IconData icon;
  final String label;
  final double minLabelWidth;
  final VoidCallback? onTap;

  @override
  State<PokrovHomeChip> createState() => _PokrovHomeChipState();
}

class _PokrovHomeChipState extends State<PokrovHomeChip> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final motion = PokrovMotionScope.of(context);
    final interactive = widget.onTap != null;
    final scale = _pressed
        ? 0.97
        : _hovered && interactive
            ? 1.015
            : 1.0;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: interactive ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: interactive ? (_) => setState(() => _pressed = true) : null,
        onTapCancel:
            interactive ? () => setState(() => _pressed = false) : null,
        onTapUp: interactive ? (_) => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          key: PokrovHomeChip.motionKey,
          scale: scale,
          duration: motion.duration(PokrovMotionTokens.quick),
          curve: PokrovMotionTokens.ease,
          child: AnimatedContainer(
            duration: motion.duration(PokrovMotionTokens.short),
            curve: PokrovMotionTokens.ease,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: _hovered && interactive
                  ? PokrovPalette.accent.withValues(alpha: 0.07)
                  : PokrovPalette.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _hovered && interactive
                    ? PokrovPalette.accent.withValues(alpha: 0.20)
                    : PokrovPalette.line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: PokrovPalette.muted),
                const SizedBox(width: 8),
                ConstrainedBox(
                  key: PokrovHomeChip.labelMotionKey,
                  constraints: BoxConstraints(
                    minWidth: widget.minLabelWidth,
                  ),
                  child: AnimatedSwitcher(
                    duration: motion.duration(PokrovMotionTokens.short),
                    transitionBuilder: pokrovFadeSlideTransition,
                    child: Text(
                      widget.label,
                      key: ValueKey(widget.label),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: PokrovPalette.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PokrovSettingsRow extends StatelessWidget {
  const PokrovSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final leading = Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: PokrovPalette.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: PokrovPalette.accent),
        );
        final titleText = Text(
          title,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: PokrovPalette.ink,
                fontWeight: FontWeight.w700,
              ),
        );
        final valueText = Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.left : TextAlign.right,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: PokrovPalette.ink.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
              ),
        );
        final chevron = onTap == null
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: PokrovPalette.ink.withValues(alpha: 0.38),
              );

        if (compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleText,
                      const SizedBox(height: 3),
                      valueText,
                    ],
                  ),
                ),
                if (chevron != null) ...[
                  const SizedBox(width: 8),
                  chevron,
                ],
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: titleText),
              const SizedBox(width: 12),
              Flexible(child: valueText),
              if (chevron != null) ...[
                const SizedBox(width: 8),
                chevron,
              ],
            ],
          ),
        );
      },
    );

    if (onTap == null) {
      return row;
    }
    return PokrovSettingsRowPressSurface(
      onTap: () {
        Feedback.forTap(context);
        onTap!();
      },
      child: row,
    );
  }
}

class PokrovSettingsRowPressSurface extends StatefulWidget {
  const PokrovSettingsRowPressSurface({
    required this.child,
    required this.onTap,
    super.key,
  });

  static const feedbackKey = ValueKey('settings-row-press-feedback');

  final Widget child;
  final VoidCallback onTap;

  @override
  State<PokrovSettingsRowPressSurface> createState() =>
      _PokrovSettingsRowPressSurfaceState();
}

class _PokrovSettingsRowPressSurfaceState
    extends State<PokrovSettingsRowPressSurface> {
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = PokrovMotionScope.of(context);
    final scale = _pressed ? 0.985 : (_hovered ? 1.006 : 1.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() {
        _hovered = true;
      }),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: AnimatedScale(
          key: PokrovSettingsRowPressSurface.feedbackKey,
          scale: scale,
          duration: motion.duration(PokrovMotionTokens.short),
          curve: PokrovMotionTokens.ease,
          alignment: Alignment.center,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

enum PokrovStatusTone {
  accent,
  muted,
  neutral,
  reward,
}

class PokrovStatusPill extends StatelessWidget {
  const PokrovStatusPill({
    required this.label,
    required this.icon,
    this.tone = PokrovStatusTone.neutral,
    super.key,
  });

  final String label;
  final IconData icon;
  final PokrovStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      PokrovStatusTone.accent => PokrovPalette.accent.withValues(alpha: 0.12),
      PokrovStatusTone.muted =>
        PokrovPalette.surfaceMuted.withValues(alpha: 0.92),
      PokrovStatusTone.neutral => Colors.white.withValues(alpha: 0.86),
      PokrovStatusTone.reward => const Color(0xFFFFF3CF),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PokrovPalette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: PokrovPalette.accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: PokrovPalette.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
