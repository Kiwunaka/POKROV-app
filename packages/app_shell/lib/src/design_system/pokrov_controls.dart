import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class PokrovSurface extends StatelessWidget {
  const PokrovSurface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.tone = PokrovSurfaceTone.neutral,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final PokrovSurfaceTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    final background = switch (tone) {
      PokrovSurfaceTone.neutral => tokens.surface,
      PokrovSurfaceTone.muted => tokens.surfaceMuted,
      PokrovSurfaceTone.accent => tokens.accent.withValues(alpha: 0.08),
      PokrovSurfaceTone.reward => tokens.reward.withValues(alpha: 0.13),
    };
    final borderColor = switch (tone) {
      PokrovSurfaceTone.accent => tokens.accent.withValues(alpha: 0.22),
      PokrovSurfaceTone.reward => tokens.reward.withValues(alpha: 0.24),
      _ => tokens.line,
    };
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
    if (onTap == null) {
      return content;
    }
    return PokrovSettingsRowPressSurface(onTap: onTap!, child: content);
  }
}

enum PokrovSurfaceTone {
  neutral,
  muted,
  accent,
  reward,
}

class PokrovGroupedSection extends StatelessWidget {
  const PokrovGroupedSection({
    required this.title,
    required this.children,
    this.subtitle,
    this.tone = PokrovSurfaceTone.neutral,
    super.key,
  });

  final String title;
  final String? subtitle;
  final PokrovSurfaceTone tone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    return PokrovSurface(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
          ),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.muted,
                    height: 1.28,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          for (var index = 0; index < children.length; index += 1) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 50,
                color: tokens.line,
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

class PokrovListRow extends StatelessWidget {
  const PokrovListRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 19, color: tokens.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.muted,
                          height: 1.25,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if ((value ?? '').trim().isNotEmpty) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: tokens.muted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: tokens.ink.withValues(alpha: 0.34),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return row;
    }
    return PokrovSettingsRowPressSurface(onTap: onTap!, child: row);
  }
}

class PokrovActionRow extends PokrovListRow {
  const PokrovActionRow({
    required super.icon,
    required super.title,
    super.subtitle,
    super.value,
    super.onTap,
    super.key,
  });
}

class PokrovInfoBanner extends StatelessWidget {
  const PokrovInfoBanner({
    required this.title,
    required this.detail,
    this.icon = Icons.info_outline_rounded,
    super.key,
  });

  final String title;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PokrovPromoCard(
      title: title,
      detail: detail,
      icon: icon,
      tone: PokrovSurfaceTone.muted,
    );
  }
}

class PokrovPromoCard extends StatelessWidget {
  const PokrovPromoCard({
    required this.title,
    required this.detail,
    this.actionLabel,
    this.icon = Icons.auto_awesome_outlined,
    this.tone = PokrovSurfaceTone.reward,
    this.onTap,
    super.key,
  });

  final String title;
  final String detail;
  final String? actionLabel;
  final IconData icon;
  final PokrovSurfaceTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    final iconColor =
        tone == PokrovSurfaceTone.reward ? tokens.reward : tokens.accent;
    return PokrovSurface(
      tone: tone,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tokens.canvasAlt.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.muted,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
          if ((actionLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              actionLabel!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class PokrovTrialBanner extends StatelessWidget {
  const PokrovTrialBanner({
    required this.title,
    required this.detail,
    this.onTap,
    super.key,
  });

  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PokrovPromoCard(
      title: title,
      detail: detail,
      actionLabel: onTap == null ? null : 'Продлить',
      icon: Icons.workspace_premium_outlined,
      tone: PokrovSurfaceTone.neutral,
      onTap: onTap,
    );
  }
}

enum PokrovTelegramBonusState {
  available,
  openingTelegram,
  checking,
  readyToClaim,
  claimed,
}

class PokrovTelegramBonusCard extends StatelessWidget {
  const PokrovTelegramBonusCard({
    required this.state,
    this.onTap,
    super.key,
  });

  final PokrovTelegramBonusState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (title, detail, action) = switch (state) {
      PokrovTelegramBonusState.available => (
          '+10 дней за Telegram',
          'Подпишитесь на канал и заберите бонус.',
          'Получить',
        ),
      PokrovTelegramBonusState.openingTelegram => (
          'Открываем Telegram',
          'После подписки вернитесь в POKROV.',
          null,
        ),
      PokrovTelegramBonusState.checking => (
          'Проверяем подписку',
          'Обычно это занимает несколько секунд.',
          null,
        ),
      PokrovTelegramBonusState.readyToClaim => (
          'Бонус готов',
          'Получите дополнительные дни к доступу.',
          'Забрать',
        ),
      PokrovTelegramBonusState.claimed => (
          'Telegram-бонус активен',
          '+10 дней добавлены к доступу.',
          null,
        ),
    };
    return PokrovPromoCard(
      title: title,
      detail: detail,
      actionLabel: action,
      icon: state == PokrovTelegramBonusState.claimed
          ? Icons.check_circle_outline_rounded
          : Icons.send_outlined,
      tone: PokrovSurfaceTone.reward,
      onTap: onTap,
    );
  }
}

/// The iOS system switch (real Cupertino widget on every platform), themed
/// with the shared `status_green` on-track per the pokrov-clear control
/// canon. A selection tick fires on toggle so the control feels physical.
class PokrovSwitch extends StatelessWidget {
  const PokrovSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    final onChanged = this.onChanged;
    return CupertinoSwitch(
      value: value,
      activeTrackColor: tokens.connectedGreen,
      onChanged: onChanged == null
          ? null
          : (next) {
              HapticFeedback.selectionClick();
              onChanged(next);
            },
    );
  }
}

/// iOS Settings-style picker row: leading icon, title, and a springy
/// emerald checkmark on the selected entry.
class PokrovCheckRow extends StatelessWidget {
  const PokrovCheckRow({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    final motion = PokrovMotionScope.of(context);
    return PokrovSettingsRowPressSurface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: tokens.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.muted,
                            height: 1.25,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedScale(
              scale: selected ? 1 : 0.4,
              duration: motion.duration(PokrovMotionTokens.short),
              curve: PokrovMotionTokens.spring,
              child: AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: motion.duration(PokrovMotionTokens.quick),
                curve: Curves.easeOut,
                child: Icon(
                  Icons.check_rounded,
                  size: 22,
                  color: tokens.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PokrovWarpToggleRow extends StatelessWidget {
  const PokrovWarpToggleRow({
    required this.enabled,
    required this.onChanged,
    this.subtitle = 'Дополнительная защита',
    this.busy = false,
    super.key,
  });

  final bool enabled;
  final bool busy;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              enabled ? Icons.verified_user_rounded : Icons.shield_outlined,
              size: 19,
              color: tokens.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WARP',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  busy ? 'Применяем настройку' : subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.muted,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PokrovSwitch(
            value: enabled,
            onChanged: busy ? null : onChanged,
          ),
        ],
      ),
    );
  }
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
    final tokens = PokrovPalette.of(context);
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
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
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
    final tokens = PokrovPalette.of(context);
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
          // Ease into the press, release with the springy overshoot.
          curve: _pressed ? PokrovMotionTokens.ease : PokrovMotionTokens.spring,
          child: AnimatedContainer(
            duration: motion.duration(PokrovMotionTokens.short),
            curve: PokrovMotionTokens.ease,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _hovered && interactive
                  ? tokens.accent.withValues(alpha: 0.07)
                  : tokens.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _hovered && interactive
                    ? tokens.accent.withValues(alpha: 0.20)
                    : tokens.line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: tokens.muted),
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
                            color: tokens.ink,
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
        final tokens = PokrovPalette.of(context);
        final compact = constraints.maxWidth < 360;
        final leading = Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: tokens.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: tokens.accent),
        );
        final titleText = Text(
          title,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: tokens.ink,
                fontWeight: FontWeight.w700,
              ),
        );
        final valueText = Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.left : TextAlign.right,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.muted,
                fontWeight: FontWeight.w400,
              ),
        );
        final chevron = onTap == null
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: tokens.ink.withValues(alpha: 0.38),
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
          // Ease into the press, release with the springy overshoot.
          curve: _pressed ? PokrovMotionTokens.ease : PokrovMotionTokens.spring,
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
  success,
  warning,
  danger,
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
    final palette = PokrovPalette.of(context);
    final background = switch (tone) {
      PokrovStatusTone.accent => palette.accent.withValues(alpha: 0.12),
      PokrovStatusTone.muted => palette.surfaceMuted.withValues(alpha: 0.92),
      PokrovStatusTone.neutral => palette.surface.withValues(alpha: 0.86),
      PokrovStatusTone.reward => palette.reward.withValues(alpha: 0.16),
      PokrovStatusTone.success => palette.success.withValues(alpha: 0.14),
      PokrovStatusTone.warning => palette.warning.withValues(alpha: 0.16),
      PokrovStatusTone.danger => palette.danger.withValues(alpha: 0.14),
    };
    final foreground = switch (tone) {
      PokrovStatusTone.reward => palette.reward,
      PokrovStatusTone.success => palette.success,
      PokrovStatusTone.warning => palette.warning,
      PokrovStatusTone.danger => palette.danger,
      PokrovStatusTone.muted => palette.muted,
      PokrovStatusTone.accent || PokrovStatusTone.neutral => palette.accent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
