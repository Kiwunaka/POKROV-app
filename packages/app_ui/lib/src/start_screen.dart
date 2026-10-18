import 'package:flutter/material.dart';

import 'brand.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Welcome card shown before the account exists.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.onStart, required this.onHaveCode, this.onPrivacy,
    this.offer = 'Начни бесплатно. Карта не нужна.\nВключается одной кнопкой.', this.notice, this.showPrivacyNotice = true});

  final VoidCallback onStart;
  final VoidCallback onHaveCode;
  final VoidCallback? onPrivacy;
  final String offer;
  final Widget? notice;
  final bool showPrivacyNotice;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (calm) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color(0xFFEEF2F0),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Container(
              padding: EdgeInsets.fromLTRB(22, 28, 22, 22),
              decoration: BoxDecoration(
                color: pokrovColor(context, PokrovColors.surface),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Color(0x24103D2E), blurRadius: 60, offset: Offset(0, 20))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) {
                            final t = _pulse.value;
                            return Container(
                              width: 64 + 32 * t,
                              height: 64 + 32 * t,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: pokrovColor(context, PokrovColors.accent).withValues(alpha: 0.5 * (1 - t)), width: 1.5),
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: pokrovColor(context, PokrovColors.accentSoft), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: PokrovMark(size: 48),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text('Привет! Это POKROV', textAlign: TextAlign.center, style: pokrovTextStyle(context, PokrovText.title)),
                  SizedBox(height: 6),
                  Text(widget.offer, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.45, color: pokrovColor(context, PokrovColors.soft))),
                  if (widget.notice != null) widget.notice!,
                  SizedBox(height: 24),
                  PrimaryButton(key: ValueKey('first-launch-new-user'), label: 'Начать бесплатно', icon: Icons.bolt_rounded, onPressed: widget.onStart, height: 58),
                  SizedBox(height: 10),
                  SecondaryButton(key: ValueKey('first-launch-returning-user'), label: 'У меня есть код', onPressed: widget.onHaveCode),
                  SizedBox(height: 16),
                  if (widget.showPrivacyNotice) GestureDetector(
                    onTap: widget.onPrivacy,
                    child: Text.rich(
                      TextSpan(
                        text: 'Историю сайтов не собираем. Для диагностики видим IP и оператора, храним до 72 часов. ',
                        children: [if (widget.onPrivacy != null) TextSpan(text: 'Подробнее', style: TextStyle(color: pokrovColor(context, PokrovColors.accent), fontWeight: FontWeight.w600))],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, height: 1.45, color: pokrovColor(context, PokrovColors.muted)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
