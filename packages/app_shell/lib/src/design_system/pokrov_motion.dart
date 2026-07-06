import 'dart:io';

import 'package:flutter/material.dart';

/// iPhone-feel scrolling on every platform: iOS bouncing physics and no
/// Android glow/stretch overscroll indicator.
class PokrovScrollBehavior extends MaterialScrollBehavior {
  const PokrovScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

abstract final class PokrovMotionTokens {
  static const instant = Duration.zero;
  static const quick = Duration(milliseconds: 120);
  static const short = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 240);
  static const sheet = Duration(milliseconds: 280);
  static const homeReveal = Duration(milliseconds: 480);
  static const ease = Curves.easeOutCubic;

  /// Apple-like emphasized deceleration for entrances and state settles.
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Gentle symmetric curve for hover/press micro-feedback.
  static const standardEase = Curves.easeInOutCubic;

  /// Subtle overshoot for tactile, springy confirmations (finite, test-safe).
  static const spring = Cubic(0.34, 1.36, 0.64, 1.0);
}

/// Gate for endlessly looping motion (skeleton pulse, connected-disc breath,
/// busy sweep). Loops collapse to a finite, test-safe pass under
/// `flutter test` so `pumpAndSettle` contracts stay bounded, while release
/// builds keep the continuous motion.
abstract final class PokrovLoopingMotion {
  /// Test hook: force loops on/off regardless of the environment.
  @visibleForTesting
  static bool? debugLoopingOverride;

  static bool get enabled =>
      debugLoopingOverride ?? !Platform.environment.containsKey('FLUTTER_TEST');
}

class PokrovMotionScope extends InheritedWidget {
  const PokrovMotionScope({
    required super.child,
    required this.disableAnimations,
    super.key,
  });

  final bool disableAnimations;

  static PokrovMotionScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PokrovMotionScope>() ??
        const PokrovMotionScope(
          disableAnimations: false,
          child: SizedBox.shrink(),
        );
  }

  Duration duration(Duration value) {
    return disableAnimations ? Duration.zero : value;
  }

  @override
  bool updateShouldNotify(covariant PokrovMotionScope oldWidget) {
    return oldWidget.disableAnimations != disableAnimations;
  }
}
