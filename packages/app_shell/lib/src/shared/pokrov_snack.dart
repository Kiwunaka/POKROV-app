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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
