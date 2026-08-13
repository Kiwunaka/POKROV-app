import 'package:flutter/material.dart';

@immutable
class PokrovPaletteTokens extends ThemeExtension<PokrovPaletteTokens> {
  const PokrovPaletteTokens({
    required this.canvas,
    required this.canvasAlt,
    required this.ink,
    required this.accent,
    required this.accentBright,
    required this.accentSoft,
    required this.connectedGreen,
    required this.success,
    required this.warning,
    required this.reward,
    required this.danger,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.line,
    required this.muted,
  });

  final Color canvas;
  final Color canvasAlt;
  final Color ink;
  final Color accent;
  final Color accentBright;

  /// Soft accent tint for selected states and emphasis backgrounds
  /// (`emerald_soft` in the shared pokrov-clear tokens).
  final Color accentSoft;

  /// iOS system green from the shared `status_green` token. Reserved for the
  /// connected state of the connect disc and switch on-tracks only — never
  /// for text or generic accents (pokrov-clear canon).
  final Color connectedGreen;

  final Color success;
  final Color warning;
  final Color reward;
  final Color danger;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceElevated;
  final Color line;
  final Color muted;

  @override
  PokrovPaletteTokens copyWith({
    Color? canvas,
    Color? canvasAlt,
    Color? ink,
    Color? accent,
    Color? accentBright,
    Color? accentSoft,
    Color? connectedGreen,
    Color? success,
    Color? warning,
    Color? reward,
    Color? danger,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? line,
    Color? muted,
  }) {
    return PokrovPaletteTokens(
      canvas: canvas ?? this.canvas,
      canvasAlt: canvasAlt ?? this.canvasAlt,
      ink: ink ?? this.ink,
      accent: accent ?? this.accent,
      accentBright: accentBright ?? this.accentBright,
      accentSoft: accentSoft ?? this.accentSoft,
      connectedGreen: connectedGreen ?? this.connectedGreen,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      reward: reward ?? this.reward,
      danger: danger ?? this.danger,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      line: line ?? this.line,
      muted: muted ?? this.muted,
    );
  }

  @override
  PokrovPaletteTokens lerp(
    ThemeExtension<PokrovPaletteTokens>? other,
    double t,
  ) {
    if (other is! PokrovPaletteTokens) {
      return this;
    }
    return PokrovPaletteTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      canvasAlt: Color.lerp(canvasAlt, other.canvasAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentBright: Color.lerp(accentBright, other.accentBright, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      connectedGreen: Color.lerp(connectedGreen, other.connectedGreen, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      reward: Color.lerp(reward, other.reward, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      line: Color.lerp(line, other.line, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

/// pokrov-clear alignment (2026-07 redesign wave 3): values mirror the shared
/// `VPN/shared/design-tokens.json` palette until a generated Flutter export
/// exists. Change them together with `design_system_contract_test.dart`.
abstract final class PokrovPalette {
  static const canvas = Color(0xFFF5F7F6);
  static const canvasAlt = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16181D);
  static const accent = Color(0xFF12805A);
  static const accentBright = Color(0xFF0F6B47);
  static const success = Color(0xFF174F3D);
  static const warning = Color(0xFF765D23);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEEF4F1);
  static const line = Color(0x14111814);
  static const muted = Color(0xFF5E6772);

  static const light = PokrovPaletteTokens(
    canvas: Color(0xFFF5F7F6),
    canvasAlt: Color(0xFFFFFFFF),
    ink: Color(0xFF16181D),
    accent: Color(0xFF12805A),
    accentBright: Color(0xFF0F6B47),
    accentSoft: Color(0xFFE6F4ED),
    connectedGreen: Color(0xFF34C759),
    success: Color(0xFF174F3D),
    warning: Color(0xFF765D23),
    reward: Color(0xFFC58A24),
    danger: Color(0xFF8D352E),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEF4F1),
    surfaceElevated: Color(0xFFFFFFFF),
    line: Color(0x14111814),
    muted: Color(0xFF5E6772),
  );

  static const dark = PokrovPaletteTokens(
    canvas: Color(0xFF111715),
    canvasAlt: Color(0xFF151C19),
    ink: Color(0xFFF3F2EC),
    accent: Color(0xFF8AC4AB),
    accentBright: Color(0xFFA5D3BF),
    accentSoft: Color(0x294A9B7A),
    connectedGreen: Color(0xFF30D158),
    success: Color(0xFFB8E5D0),
    warning: Color(0xFFE8D19A),
    reward: Color(0xFFE2B35B),
    danger: Color(0xFFF0B8B1),
    surface: Color(0xFF161D1A),
    surfaceMuted: Color(0xFF17221D),
    surfaceElevated: Color(0xFF182019),
    line: Color(0x1FEFF3F1),
    muted: Color(0xFF83908A),
  );

  static PokrovPaletteTokens of(BuildContext context) {
    return Theme.of(context).extension<PokrovPaletteTokens>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }
}
