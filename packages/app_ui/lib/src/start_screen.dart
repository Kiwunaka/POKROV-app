import 'package:flutter/material.dart';

import 'brand.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Welcome card shown before the account exists.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.onStart, required this.onHaveCode, this.onPrivacy});

  final VoidCallback onStart;
  final VoidCallback onHaveCode;
  final VoidCallback? onPrivacy;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

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
      color: const Color(0xFFEEF2F0),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
              decoration: BoxDecoration(
                color: PokrovColors.surface,
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [BoxShadow(color: Color(0x24103D2E), blurRadius: 60, offset: Offset(0, 20))],
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
                                border: Border.all(color: PokrovColors.accent.withValues(alpha: 0.5 * (1 - t)), width: 1.5),
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(color: PokrovColors.accentSoft, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const PokrovMark(size: 48),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Привет! Это POKROV', textAlign: TextAlign.center, style: PokrovText.title),
                  const SizedBox(height: 6),
                  const Text('5 дней бесплатно. Карта не нужна.\nВключается одной кнопкой.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.45, color: PokrovColors.soft)),
                  const SizedBox(height: 24),
                  PrimaryButton(label: 'Начать бесплатно', icon: Icons.bolt_rounded, onPressed: widget.onStart, height: 58),
                  const SizedBox(height: 10),
                  SecondaryButton(label: 'У меня есть код', onPressed: widget.onHaveCode),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: widget.onPrivacy,
                    child: const Text.rich(
                      TextSpan(
                        text: 'Историю сайтов не собираем. Для диагностики видим IP и оператора, храним до 72 часов. ',
                        children: [TextSpan(text: 'Подробнее', style: TextStyle(color: PokrovColors.accent, fontWeight: FontWeight.w600))],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, height: 1.45, color: PokrovColors.muted),
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
