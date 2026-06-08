import 'package:flutter/material.dart';

abstract final class PokrovMotionTokens {
  static const quick = Duration(milliseconds: 120);
  static const short = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 240);
  static const homeReveal = Duration(milliseconds: 480);
  static const ease = Curves.easeOutCubic;
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
