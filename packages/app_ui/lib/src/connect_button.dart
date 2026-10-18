import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';

/// The big round «Подключить» button with a live ring.
///
/// connecting: an arc spins around the circle;
/// on: the circle fills green and soft waves leave it;
/// error: the ring turns amber and the label says «Повторить».
/// With reduced motion the ring stays still.
class PokrovConnectButton extends StatefulWidget {
  const PokrovConnectButton({super.key, required this.phase, required this.onPressed, this.diameter = 232, this.label});

  final ConnectionPhase phase;
  final VoidCallback? onPressed;
  final String? label;

  /// Diameter of the white circle; the ring area is 25% larger.
  final double diameter;

  @override
  State<PokrovConnectButton> createState() => _PokrovConnectButtonState();
}

class _PokrovConnectButtonState extends State<PokrovConnectButton> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: Duration(milliseconds: 1100));
  late final AnimationController _waves = AnimationController(vsync: this, duration: Duration(milliseconds: 2800));

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PokrovConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) _sync();
  }

  void _sync() {
    final calm = _reduceMotion;
    if (widget.phase == ConnectionPhase.connecting && !calm) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
    if (widget.phase == ConnectionPhase.on && !calm) {
      if (!_waves.isAnimating) _waves.repeat();
    } else {
      _waves.stop();
      _waves.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _waves.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    final on = phase == ConnectionPhase.on;
    final error = phase == ConnectionPhase.error;
    final ring = widget.diameter * 1.25;
    final label = widget.label ?? switch (phase) {
      ConnectionPhase.off => 'Подключить',
      ConnectionPhase.connecting => 'Подключаемся…',
      ConnectionPhase.on => 'Защищено',
      ConnectionPhase.error => 'Повторить',
    };
    final semantics = switch (phase) {
      ConnectionPhase.off => 'Включить защиту',
      ConnectionPhase.connecting => 'Отменить подключение',
      ConnectionPhase.on => 'Выключить защиту',
      ConnectionPhase.error => 'Повторить подключение',
    };
    final iconColor = on ? pokrovOnAccent(context) : (error ? pokrovColor(context, PokrovColors.warnIcon) : pokrovColor(context, PokrovColors.accent));

    return SizedBox(
      width: ring,
      height: ring,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(
                phase: phase,
                spin: _spin,
                waves: _waves,
                innerRadius: widget.diameter / 2,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: semantics,
            enabled: widget.onPressed != null,
            onTap: widget.onPressed,
            excludeSemantics: true,
            child: AnimatedContainer(
              duration: PokrovMotion.state,
              curve: PokrovMotion.settle,
              width: widget.diameter,
              height: widget.diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? pokrovColor(context, PokrovColors.accent) : pokrovColor(context, PokrovColors.surface),
                boxShadow: [
                  BoxShadow(
                    color: on ? Color(0x5912805A) : Color(0x1F103D2E),
                    blurRadius: 44,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onPressed,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: PokrovMotion.quick,
                          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            Icons.power_settings_new_rounded,
                            key: ValueKey(iconColor),
                            size: widget.diameter * 0.23,
                            color: iconColor,
                          ),
                        ),
                        SizedBox(height: widget.diameter * 0.04),
                        AnimatedDefaultTextStyle(
                          duration: PokrovMotion.state,
                          style: TextStyle(
                            fontFamily: pokrovFontFamily,
                            fontSize: widget.diameter * 0.09,
                            fontWeight: FontWeight.w800,
                            color: on ? pokrovOnAccent(context) : pokrovColor(context, PokrovColors.ink),
                          ),
                          child: Text(label),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.phase, required this.spin, required this.waves, required this.innerRadius})
      : super(repaint: Listenable.merge([spin, waves]));

  final ConnectionPhase phase;
  final Animation<double> spin;
  final Animation<double> waves;
  final double innerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 4;
    final stroke = Paint()..style = PaintingStyle.stroke;

    switch (phase) {
      case ConnectionPhase.off:
        stroke
          ..color = PokrovColors.track
          ..strokeWidth = 2;
        canvas.drawCircle(center, outer, stroke);
      case ConnectionPhase.error:
        stroke
          ..color = PokrovColors.warnLine
          ..strokeWidth = 3;
        canvas.drawCircle(center, outer, stroke);
      case ConnectionPhase.connecting:
        stroke
          ..color = PokrovColors.track
          ..strokeWidth = 2;
        canvas.drawCircle(center, outer, stroke);
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = PokrovColors.accent;
        final start = spin.value * 2 * math.pi - math.pi / 2;
        canvas.drawArc(Rect.fromCircle(center: center, radius: outer), start, math.pi * 0.55, false, arc);
      case ConnectionPhase.on:
        for (final offset in const [0.0, 0.5]) {
          final t = (waves.value + offset) % 1.0;
          final radius = innerRadius + (outer + 6 - innerRadius) * t;
          final wave = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = PokrovColors.accent.withValues(alpha: 0.45 * (1 - t));
          if (waves.value > 0 || offset == 0) canvas.drawCircle(center, radius, wave);
        }
        stroke
          ..color = PokrovColors.accent.withValues(alpha: 0.3)
          ..strokeWidth = 3;
        canvas.drawCircle(center, outer, stroke);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.phase != phase || oldDelegate.innerRadius != innerRadius;
}
