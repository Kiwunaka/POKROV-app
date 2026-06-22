import 'package:flutter/widgets.dart';

/// Spacing scale on a 4pt rhythm.
///
/// One source of truth for gaps, padding, and layout breathing room so
/// surfaces stay calm and consistent across Android and Windows instead of
/// relying on scattered inline literals.
abstract final class PokrovSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  /// Comfortable page gutter for compact (mobile) widths.
  static const double gutterCompact = 18;

  /// Comfortable page gutter for expanded (desktop) widths.
  static const double gutterExpanded = 28;

  /// Default vertical rhythm between stacked sections.
  static const double section = 16;
}

/// Corner radius scale.
///
/// Structural panels stay lightly rounded (Apple-like), only the primary
/// connect control and chips use the full pill. No blob-radius defaults.
abstract final class PokrovRadii {
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius cardSm = BorderRadius.all(Radius.circular(md));
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius cardLg = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(28),
  );
  static const BorderRadius stadium = BorderRadius.all(Radius.circular(pill));
}
