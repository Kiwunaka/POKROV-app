import 'package:flutter/material.dart';

import 'pokrov_motion.dart';

/// Flat, tactile press wrapper for primary actions.
///
/// Scales down to [pressedScale] over [PokrovMotionTokens.quick] with an
/// ease-in and releases back with the springy
/// [PokrovMotionTokens.spring] overshoot. Desktop pointers get an optional
/// gentle [hoverScale]. Press tracking uses tap gesture semantics (not raw
/// pointer events), so starting a scroll on top of the button cancels the
/// press instead of twitching the scale — the iOS delayed-highlight
/// pattern. Pointer events still pass through to the wrapped child, so
/// buttons keep their own semantics and tap handling. Respects
/// [PokrovMotionScope]: reduced motion collapses the scale animation.
class PokrovPressable extends StatefulWidget {
  const PokrovPressable({
    required this.child,
    this.enabled = true,
    this.hoverEnabled = true,
    super.key,
  });

  static const motionKey = ValueKey('pokrov-pressable-motion');
  static const pressedScale = 0.97;
  static const hoverScale = 1.01;

  final Widget child;
  final bool enabled;
  final bool hoverEnabled;

  @override
  State<PokrovPressable> createState() => _PokrovPressableState();
}

class _PokrovPressableState extends State<PokrovPressable> {
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() {
      _hovered = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = PokrovMotionScope.of(context);
    final scale = !widget.enabled
        ? 1.0
        : _pressed
            ? PokrovPressable.pressedScale
            : _hovered && widget.hoverEnabled
                ? PokrovPressable.hoverScale
                : 1.0;
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          key: PokrovPressable.motionKey,
          scale: scale,
          duration: motion.duration(PokrovMotionTokens.quick),
          curve: _pressed ? Curves.easeIn : PokrovMotionTokens.spring,
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
