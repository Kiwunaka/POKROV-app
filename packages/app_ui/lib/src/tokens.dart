import 'package:flutter/material.dart';

/// Colors of the approved 18.10 frame. Values mirror the light
/// `pokrov-clear` tokens from the platform `shared/design-tokens.json`.
abstract final class PokrovColors {
  static const canvas = Color(0xFFF5F7F6);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16181D);
  static const soft = Color(0xFF5E6772);
  static const muted = Color(0xFF6B737C);
  static const faint = Color(0xFF9AA1A9);
  static const line = Color(0x0F111814);
  static const chip = Color(0xFFEEF1F0);
  static const track = Color(0xFFE3E9E6);
  static const accent = Color(0xFF12805A);
  static const accentDeep = Color(0xFF0F6B47);
  static const accentSoft = Color(0xFFE6F4ED);
  static const accentWash = Color(0xFFF1F8F4);
  static const accentText = Color(0xFF174F3D);
  static const accentBorder = Color(0xFF9FD3BA);
  static const connected = Color(0xFF34C759);
  static const warnBg = Color(0xFFFBF3E4);
  static const warnLine = Color(0xFFF0D9B0);
  static const warnDot = Color(0xFFD99A2B);
  static const warnTitle = Color(0xFF4A2E05);
  static const warnBody = Color(0xFF6A4510);
  static const warnStrong = Color(0xFF8A5A0C);
  static const warnIcon = Color(0xFFA15C07);
}

abstract final class PokrovRadii {
  static const card = 24.0;
  static const tile = 20.0;
  static const button = 18.0;
  static const small = 12.0;
}

/// Font family declared by this package.
const String pokrovFontFamily = 'packages/pokrov_app_ui/Golos Text';

/// Motion: springy for selection, calm for state colors.
abstract final class PokrovMotion {
  static const quick = Duration(milliseconds: 250);
  static const state = Duration(milliseconds: 500);
  static const spring = Curves.easeOutBack;
  static const settle = Curves.easeOutCubic;
}

ThemeData pokrovUiTheme({Brightness brightness = Brightness.light}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: pokrovFontFamily,
    scaffoldBackgroundColor: PokrovColors.canvas,
    colorScheme: ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: PokrovColors.accent,
      primary: PokrovColors.accent,
      surface: PokrovColors.surface,
    ),
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: PokrovColors.ink,
      displayColor: PokrovColors.ink,
      fontFamily: pokrovFontFamily,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PokrovColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0xFFD5DBD8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
  );
}

/// Text styles used across the frame.
abstract final class PokrovText {
  static const title = TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w800, color: PokrovColors.ink);
  static const heading = TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w800, color: PokrovColors.ink);
  static const rowTitle = TextStyle(fontSize: 16, height: 1.3, fontWeight: FontWeight.w600, color: PokrovColors.ink);
  static const rowStrong = TextStyle(fontSize: 16, height: 1.3, fontWeight: FontWeight.w800, color: PokrovColors.ink);
  static const body = TextStyle(fontSize: 15, height: 1.45, color: PokrovColors.soft);
  static const caption = TextStyle(fontSize: 13, height: 1.35, color: PokrovColors.muted);
  static const section = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: PokrovColors.muted);
  static const value = TextStyle(fontSize: 14, color: PokrovColors.muted);
}
