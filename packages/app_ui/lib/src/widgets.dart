import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// White rounded card with the hairline border used everywhere in the frame.
class PokrovCard extends StatelessWidget {
  const PokrovCard({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 16), this.color = PokrovColors.surface, this.borderColor = PokrovColors.line, this.radius = PokrovRadii.card});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
      child: Text(text.toUpperCase(), style: PokrovText.section),
    );
  }
}

/// One row inside a [PokrovCard]: title, optional value and chevron.
class PokrovRow extends StatelessWidget {
  const PokrovRow({super.key, required this.title, this.value, this.valueColor, this.valueBold = false, this.trailing, this.onTap, this.divider = true, this.height = 54});

  final String title;
  final String? value;
  final Color? valueColor;
  final bool valueBold;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;
  final double height;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        border: divider ? const Border(bottom: BorderSide(color: PokrovColors.line)) : null,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, color: PokrovColors.ink))),
          if (value != null) ...[
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                value!,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor ?? PokrovColors.muted,
                  fontWeight: valueBold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (onTap != null && trailing == null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: PokrovColors.faint),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.height = 56});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: PokrovColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PokrovRadii.button)),
          textStyle: const TextStyle(fontFamily: pokrovFontFamily, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.height = 54, this.filled = false});

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: filled ? PokrovColors.chip : PokrovColors.surface,
          foregroundColor: PokrovColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PokrovRadii.button),
            side: filled ? BorderSide.none : const BorderSide(color: Color(0x1A111814)),
          ),
          textStyle: const TextStyle(fontFamily: pokrovFontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.onPressed, this.color = PokrovColors.accent});

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        textStyle: const TextStyle(fontFamily: pokrovFontFamily, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

/// Round back button used by pushed screens.
class BackCircle extends StatelessWidget {
  const BackCircle({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PokrovColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.arrow_back_rounded, size: 22, color: PokrovColors.ink, semanticLabel: 'Назад'),
        ),
      ),
    );
  }
}

/// Header of a pushed screen: back button, title and optional subtitle.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.onBack});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[BackCircle(onPressed: onBack!), const SizedBox(width: 10)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: onBack != null ? PokrovText.heading : PokrovText.title),
              if (subtitle != null) Text(subtitle!, style: PokrovText.caption),
            ],
          ),
        ),
      ],
    );
  }
}

/// Spring toggle in the POKROV look (green track when on).
class PokrovToggle extends StatelessWidget {
  const PokrovToggle({super.key, required this.value, required this.onChanged, required this.semanticLabel});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: PokrovMotion.quick,
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? PokrovColors.connected : const Color(0xFFD5DBD8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 350),
            curve: PokrovMotion.spring,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x2E000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-option segmented control with a sliding thumb.
class PokrovSegmented extends StatelessWidget {
  const PokrovSegmented({super.key, required this.labels, required this.index, required this.onChanged, this.height = 36});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: PokrovColors.chip, borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 400),
            curve: PokrovMotion.spring,
            alignment: Alignment(labels.length == 1 ? 0 : -1 + 2 * index / (labels.length - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: PokrovColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color(0x1F101814), blurRadius: 6, offset: Offset(0, 2))],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: i == index ? PokrovColors.ink : PokrovColors.soft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rounded-square flag, or the green «Авто» badge when [code] is null.
class FlagTile extends StatelessWidget {
  const FlagTile({super.key, this.code, this.size = 40});

  final String? code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.28;
    if (code == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: PokrovColors.accentSoft, borderRadius: BorderRadius.circular(radius)),
        child: Icon(Icons.bolt_rounded, color: PokrovColors.accent, size: size * 0.55),
      );
    }
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: PokrovColors.chip,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: CountryFlag.fromCountryCode(
        code!,
        theme: ImageTheme(width: size * 0.76, height: size * 0.56, shape: RoundedRectangle(size * 0.12)),
      ),
    );
  }
}

/// Mint square with an icon, the current app's list icon style.
class IconSquare extends StatelessWidget {
  const IconSquare({super.key, required this.icon, this.size = 44, this.background = PokrovColors.accentSoft, this.color = PokrovColors.accent});

  final IconData icon;
  final double size;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * 0.32)),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Animated green check that fades and pops in when [visible].
class SelectionCheck extends StatelessWidget {
  const SelectionCheck({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1 : 0.6,
      duration: PokrovMotion.quick,
      curve: PokrovMotion.spring,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: PokrovMotion.quick,
        child: const Icon(Icons.check_rounded, color: PokrovColors.accent, size: 24),
      ),
    );
  }
}

/// Placeholder for the home ad banner (`home_banner` in shared promo
/// slots). Full width; 132 px tall in simple mode, 84 px in advanced.
/// The real creative replaces the striped area; the «Реклама» mark stays.
class AdSlot extends StatelessWidget {
  const AdSlot({super.key, required this.child, this.compact = false});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Реклама',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 18 : 22),
      child: SizedBox(height: compact ? 84 : 132, width: double.infinity, child: child),
    ),
  );
}

/// Amber notice card used for errors and «needs attention» states.
class WarnCard extends StatelessWidget {
  const WarnCard({super.key, required this.title, required this.body, this.actions = const <Widget>[]});

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return PokrovCard(
      color: PokrovColors.warnBg,
      borderColor: PokrovColors.warnLine,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded, size: 20, color: PokrovColors.warnIcon),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: PokrovColors.warnTitle))),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.45, color: PokrovColors.warnBody)),
          if (actions.isNotEmpty) ...[const SizedBox(height: 12), Row(children: actions)],
        ],
      ),
    );
  }
}
