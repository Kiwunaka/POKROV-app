part of pokrov_app_shell;

/// Visual and haptic tone of a [showPokrovSnack] message.
enum PokrovSnackTone {
  info,
  success,
  danger,
}

/// The single snackbar entry point for the POKROV shell.
///
/// Floating (via the shared snackbar theme), with a tone-tinted leading icon
/// from [PokrovPaletteTokens], shown for three seconds. Success and danger
/// tones also emit the matching [PokrovHaptics] tier.
void showPokrovSnack(
  BuildContext context,
  String message, {
  PokrovSnackTone tone = PokrovSnackTone.info,
}) {
  final motion = _MotionScope.of(context);
  // The snack surface is inverted in the light theme (near-black ink), so
  // tone icons always come from the palette that reads on a dark surface.
  final onSnack = Theme.of(context).brightness == Brightness.light
      ? PokrovPalette.dark
      : PokrovPalette.of(context);
  final (IconData icon, Color iconColor) = switch (tone) {
    PokrovSnackTone.info => (Icons.info_outline, onSnack.accentBright),
    PokrovSnackTone.success => (Icons.check_circle, onSnack.success),
    PokrovSnackTone.danger => (Icons.error_outline, onSnack.danger),
  };
  switch (tone) {
    case PokrovSnackTone.success:
      PokrovHaptics.success();
    case PokrovSnackTone.danger:
      PokrovHaptics.error();
    case PokrovSnackTone.info:
      break;
  }
  // Two-beat entrance: the surface arrives first (standard, emphasized),
  // then the tone icon spring-pops ~40ms later — layered, not simultaneous.
  Widget leadingIcon = Icon(icon, size: 18, color: iconColor);
  if (!motion.disableAnimations) {
    leadingIcon = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Interval(0.18, 1, curve: PokrovMotionTokens.spring),
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: leadingIcon,
    );
  }
  ScaffoldMessenger.of(context).showSnackBar(
    snackBarAnimationStyle: motion.disableAnimations
        ? const AnimationStyle(
            duration: Duration.zero,
            reverseDuration: Duration.zero,
          )
        : const AnimationStyle(
            duration: _MotionTokens.standard,
            curve: _MotionTokens.emphasized,
            // Present gently, dismiss briskly — same grammar as the sheets.
            reverseDuration: PokrovMotionTokens.quick,
            reverseCurve: _MotionTokens.ease,
          ),
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          leadingIcon,
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
