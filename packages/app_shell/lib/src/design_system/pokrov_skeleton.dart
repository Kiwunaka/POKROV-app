import 'package:flutter/material.dart';

import 'pokrov_motion.dart';
import 'pokrov_palette.dart';

/// Shared gentle opacity pulse for skeleton placeholders.
///
/// Loops 1.0 <-> [minOpacity] (repeat-reverse) over [period]; stays on the
/// static resting frame under reduced motion ([PokrovMotionScope]) and in
/// non-looping environments ([PokrovLoopingMotion]), so geometry and keys of
/// the wrapped skeleton stay untouched.
class PokrovSkeletonPulse extends StatefulWidget {
  const PokrovSkeletonPulse({
    required this.child,
    super.key,
  });

  static const motionKey = ValueKey('pokrov-skeleton-pulse');
  static const period = Duration(milliseconds: 1100);
  static const minOpacity = 0.55;

  final Widget child;

  @override
  State<PokrovSkeletonPulse> createState() => _PokrovSkeletonPulseState();
}

class _PokrovSkeletonPulseState extends State<PokrovSkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PokrovSkeletonPulse.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  void _syncController() {
    final canLoop = PokrovLoopingMotion.enabled &&
        !PokrovMotionScope.of(context).disableAnimations;
    if (canLoop) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: PokrovSkeletonPulse.motionKey,
      opacity: Tween<double>(
        begin: 1.0,
        end: PokrovSkeletonPulse.minOpacity,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

class PokrovSkeletonList extends StatelessWidget {
  const PokrovSkeletonList({
    super.key,
    this.rows = 4,
  });

  final int rows;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return RepaintBoundary(
      child: PokrovSkeletonPulse(
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(rows, (index) {
              return Padding(
                padding: EdgeInsets.only(bottom: index == rows - 1 ? 0 : 14),
                child: Row(
                  children: [
                    const PokrovSkeletonLine(width: 36, height: 36, radius: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PokrovSkeletonLine(
                            width: index.isEven ? 168 : 132,
                            height: 12,
                          ),
                          const SizedBox(height: 8),
                          PokrovSkeletonLine(
                            width: index.isEven ? 232 : 188,
                            height: 10,
                            opacity: 0.08,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class PokrovAccountSkeletonSummary extends StatelessWidget {
  const PokrovAccountSkeletonSummary({super.key});

  static const summaryKey = ValueKey('account-skeleton-summary');

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return RepaintBoundary(
      child: PokrovSkeletonPulse(
        child: Container(
          key: summaryKey,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.line),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PokrovSkeletonLine(width: 220, height: 12),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PokrovSkeletonLine(height: 74, radius: 12),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: PokrovSkeletonLine(height: 74, radius: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PokrovSkeletonLine extends StatelessWidget {
  const PokrovSkeletonLine({
    this.width,
    required this.height,
    this.radius = 999,
    this.opacity = 0.12,
    super.key,
  });

  static const lineKey = ValueKey('motion-skeleton-line');

  final double? width;
  final double height;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Container(
      key: lineKey,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.ink.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
