import 'package:flutter/material.dart';

@immutable
class PokrovPaletteTokens extends ThemeExtension<PokrovPaletteTokens> {
  const PokrovPaletteTokens({
    required this.canvas,
    required this.canvasAlt,
    required this.ink,
    required this.accent,
    required this.accentBright,
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

abstract final class PokrovPalette {
  static const canvas = Color(0xFFF9FAFB);
  static const canvasAlt = Color(0xFFFFFFFF);
  static const ink = Color(0xFF10131A);
  static const accent = Color(0xFF0F725D);
  static const accentBright = Color(0xFF16A27B);
  static const success = Color(0xFF159A68);
  static const warning = Color(0xFFE29A1F);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3F5F8);
  static const line = Color(0x1A10131A);
  static const muted = Color(0xFF697080);

  static const light = PokrovPaletteTokens(
    canvas: Color(0xFFF7F8FA),
    canvasAlt: Color(0xFFFFFFFF),
    ink: Color(0xFF10131A),
    accent: Color(0xFF0F725D),
    accentBright: Color(0xFF16A27B),
    success: Color(0xFF159A68),
    warning: Color(0xFFE29A1F),
    reward: Color(0xFFC58A24),
    danger: Color(0xFFD94D4D),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2F5F4),
    surfaceElevated: Color(0xFFFFFFFF),
    line: Color(0x1A10131A),
    muted: Color(0xFF697080),
  );

  static const dark = PokrovPaletteTokens(
    canvas: Color(0xFF11161D),
    canvasAlt: Color(0xFF141A23),
    ink: Color(0xFFF4F6FA),
    accent: Color(0xFF34C79A),
    accentBright: Color(0xFF5BDDB4),
    success: Color(0xFF45CE8E),
    warning: Color(0xFFE6B24C),
    reward: Color(0xFFE2B35B),
    danger: Color(0xFFFF6B6B),
    surface: Color(0xFF171D25),
    surfaceMuted: Color(0xFF1F2731),
    surfaceElevated: Color(0xFF202935),
    line: Color(0x1FFFFFFF),
    muted: Color(0xFF9BA4B2),
  );

  static PokrovPaletteTokens of(BuildContext context) {
    return Theme.of(context).extension<PokrovPaletteTokens>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }
}
