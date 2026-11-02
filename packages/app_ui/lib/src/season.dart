import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'models.dart';
import 'tokens.dart';

/// Holidays with their own look. The app decides which one is active; this
/// package has no clock and only draws the season it is given.
enum PokrovSeason { halloween, newYear, christmas, valentine, defender, womensDay, aprilFools, cosmonautics, easter, victoryDay }

/// The active holiday look, carried in the theme. [season] is null on
/// ordinary days and when the holiday decoration is turned off.
@immutable
class PokrovSeasonTheme extends ThemeExtension<PokrovSeasonTheme> {
  const PokrovSeasonTheme({this.season, this.fireworks = false});

  final PokrovSeason? season;

  /// Fireworks after a confirmed connection (New Year's night).
  final bool fireworks;

  static PokrovSeason? of(BuildContext context) => Theme.of(context).extension<PokrovSeasonTheme>()?.season;

  @override
  PokrovSeasonTheme copyWith({PokrovSeason? season, bool? fireworks}) =>
      PokrovSeasonTheme(season: season ?? this.season, fireworks: fireworks ?? this.fireworks);

  @override
  PokrovSeasonTheme lerp(covariant ThemeExtension<PokrovSeasonTheme>? other, double t) =>
      t < 0.5 || other is! PokrovSeasonTheme ? this : other;
}

const _accentTokens = [
  PokrovColors.accent, PokrovColors.accentDeep, PokrovColors.accentSoft,
  PokrovColors.accentWash, PokrovColors.accentText, PokrovColors.accentBorder,
];

/// Light and dark accent families, in [_accentTokens] order. Text pairs keep
/// at least 7:1 contrast; none of the hues is the amber used for errors.
const _palettes = <PokrovSeason, (List<Color>, List<Color>)>{
  PokrovSeason.halloween: (
    [Color(0xFF6B3FA0), Color(0xFF583483), Color(0xFFEFE9F6), Color(0xFFF7F4FB), Color(0xFF3B2358), Color(0xFFC5AEDF)],
    [Color(0xFFBFA7DC), Color(0xFFBFA7DC), Color(0xFF322442), Color(0xFF231A2E), Color(0xFFD5C4E8), Color(0xFF644D80)],
  ),
  PokrovSeason.newYear: (
    [Color(0xFF1A6A9C), Color(0xFF155780), Color(0xFFE7F2F9), Color(0xFFF4F8FB), Color(0xFF114769), Color(0xFFA8CEE6)],
    [Color(0xFF9DCAE7), Color(0xFF9DCAE7), Color(0xFF243742), Color(0xFF1A262E), Color(0xFFBEDCEF), Color(0xFF4D6C80)],
  ),
  PokrovSeason.christmas: (
    [Color(0xFFA3324A), Color(0xFF86293D), Color(0xFFF8E8EB), Color(0xFFFBF4F5), Color(0xFF5E1D2B), Color(0xFFE5A9B6)],
    [Color(0xFFE2A1AF), Color(0xFFE2A1AF), Color(0xFF42242A), Color(0xFF2E1A1E), Color(0xFFECC1CA), Color(0xFF804D57)],
  ),
  PokrovSeason.valentine: (
    [Color(0xFFC2255C), Color(0xFF9F1E4B), Color(0xFFF9E7ED), Color(0xFFFBF4F6), Color(0xFF671431), Color(0xFFE6A8BE)],
    [Color(0xFFE79DB7), Color(0xFFE79DB7), Color(0xFF42242E), Color(0xFF2E1A21), Color(0xFFEFBECF), Color(0xFF804D5E)],
  ),
  PokrovSeason.defender: (
    [Color(0xFF4F6B2E), Color(0xFF415826), Color(0xFFF0F6EA), Color(0xFFF8FAF4), Color(0xFF3F5625), Color(0xFFC9DDB1)],
    [Color(0xFFC4DAA9), Color(0xFFC4DAA9), Color(0xFF344224), Color(0xFF252E1A), Color(0xFFD8E6C6), Color(0xFF68804D)],
  ),
  PokrovSeason.womensDay: (
    [Color(0xFFA23B9C), Color(0xFF853080), Color(0xFFF7E9F6), Color(0xFFFBF4FA), Color(0xFF5A2156), Color(0xFFE1ADDE)],
    [Color(0xFFDEA5DB), Color(0xFFDEA5DB), Color(0xFF422441), Color(0xFF2E1A2D), Color(0xFFE9C3E7), Color(0xFF804D7D)],
  ),
  PokrovSeason.aprilFools: (
    [Color(0xFF5B4BD6), Color(0xFF3D2CC1), Color(0xFFE9E7F9), Color(0xFFF4F4FB), Color(0xFF201764), Color(0xFFAFA8E6)],
    [Color(0xFFA69DE7), Color(0xFFA69DE7), Color(0xFF272442), Color(0xFF1C1A2E), Color(0xFFC3BEEF), Color(0xFF524D80)],
  ),
  PokrovSeason.cosmonautics: (
    [Color(0xFF33409E), Color(0xFF2A3482), Color(0xFFE8EAF8), Color(0xFFF4F4FB), Color(0xFF1E255D), Color(0xFFAAB1E4)],
    [Color(0xFFA2AAE1), Color(0xFFA2AAE1), Color(0xFF242742), Color(0xFF1A1C2E), Color(0xFFC1C6EB), Color(0xFF4D5380)],
  ),
  PokrovSeason.easter: (
    [Color(0xFF9C3D6B), Color(0xFF803258), Color(0xFFF6E9EF), Color(0xFFFBF4F7), Color(0xFF58223C), Color(0xFFDFAEC6)],
    [Color(0xFFDDA7C1), Color(0xFFDDA7C1), Color(0xFF422433), Color(0xFF2E1A23), Color(0xFFE8C4D6), Color(0xFF804D65)],
  ),
  PokrovSeason.victoryDay: (
    [Color(0xFF9E2B2E), Color(0xFF822326), Color(0xFFF8E7E7), Color(0xFFFBF4F4), Color(0xFF601A1C), Color(0xFFE6A8AA)],
    [Color(0xFFE59FA1), Color(0xFFE59FA1), Color(0xFF422424), Color(0xFF2E1A1A), Color(0xFFEEBFC0), Color(0xFF804D4E)],
  ),
};

/// Seasonal replacement for an accent token, or null for any other token.
/// Warning, status and neutral tokens never change.
Color? pokrovSeasonColor(PokrovSeason? season, Color token, {required bool dark}) {
  if (season == null) return null;
  final index = _accentTokens.indexOf(token);
  if (index < 0) return null;
  final palette = _palettes[season]!;
  return (dark ? palette.$2 : palette.$1)[index];
}

/// Holiday motion clock: about 30 frames a second and only for a minute after
/// the last wake, so a screen left open does not drain the battery.
class PokrovSeasonClock extends ChangeNotifier {
  PokrovSeasonClock(TickerProvider vsync) {
    _ticker = vsync.createTicker(_tick);
  }

  static const awake = Duration(seconds: 60);
  late final Ticker _ticker;
  double _base = 0;
  Duration _last = Duration.zero;
  bool _allowed = false;

  /// Seconds of motion so far; stands still while stopped.
  double seconds = 0;

  void _tick(Duration elapsed) {
    if (elapsed - _last < const Duration(milliseconds: 33)) return;
    _last = elapsed;
    seconds = _base + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    notifyListeners();
    if (elapsed >= awake) _halt();
  }

  /// Allows or forbids motion; it starts again when it becomes allowed.
  void allow(bool value) {
    if (value == _allowed) return;
    _allowed = value;
    value ? wake() : _halt();
  }

  /// Restarts the one-minute motion window, e.g. after a tap.
  void wake() {
    if (!_allowed) return;
    _halt();
    _ticker.start();
  }

  void _halt() {
    if (!_ticker.isActive) return;
    _base = seconds;
    _last = Duration.zero;
    _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

bool _motionAllowed(BuildContext context, ConnectionPhase phase) =>
    PokrovSeasonTheme.of(context) != null &&
    phase != ConnectionPhase.error &&
    !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
    TickerMode.of(context);

/// Holiday animation behind the home screen. It never takes taps or
/// semantics, hides on an error and stands still under reduced motion.
class PokrovSeasonBackdrop extends StatefulWidget {
  const PokrovSeasonBackdrop({super.key, required this.phase, required this.child});

  final ConnectionPhase phase;
  final Widget child;

  @override
  State<PokrovSeasonBackdrop> createState() => _PokrovSeasonBackdropState();
}

class _PokrovSeasonBackdropState extends State<PokrovSeasonBackdrop> with SingleTickerProviderStateMixin {
  late final PokrovSeasonClock _clock = PokrovSeasonClock(this);
  double? _burstAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock.allow(_motionAllowed(context, widget.phase));
  }

  @override
  void didUpdateWidget(PokrovSeasonBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase == widget.phase) return;
    if (widget.phase == ConnectionPhase.on && Theme.of(context).extension<PokrovSeasonTheme>()?.fireworks == true) {
      _burstAt = _clock.seconds;
    }
    _clock.allow(_motionAllowed(context, widget.phase));
    _clock.wake();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final season = theme.extension<PokrovSeasonTheme>()?.season;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _clock.wake(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: AnimatedOpacity(
                  opacity: widget.phase == ConnectionPhase.error ? 0 : 1,
                  duration: PokrovMotion.state,
                  child: CustomPaint(
                    key: const ValueKey('season-backdrop'),
                    painter: season == null ? null : _BackdropPainter(
                      season: season, dark: theme.brightness == Brightness.dark, clock: _clock, burstAt: _burstAt),
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Decoration of the connect button: [face] paints inside the circle behind
/// the label, otherwise it paints the ring area above the circle. Nothing is
/// painted on an error.
class PokrovSeasonButtonPainter extends CustomPainter {
  PokrovSeasonButtonPainter({required this.season, required this.phase, required this.dark, required this.clock, this.face = false})
      : super(repaint: clock);

  final PokrovSeason season;
  final ConnectionPhase phase;
  final bool dark;
  final PokrovSeasonClock clock;
  final bool face;

  @override
  void paint(Canvas canvas, Size size) {
    if (phase == ConnectionPhase.error) return;
    final t = clock.seconds;
    if (face) {
      if (season == PokrovSeason.aprilFools) _googlyEyes(canvas, size.width, t);
      return;
    }
    canvas.save();
    canvas.scale(size.width / 178);
    _buttonDecor(canvas, season, t, dark, phase == ConnectionPhase.on);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PokrovSeasonButtonPainter oldDelegate) =>
      oldDelegate.season != season || oldDelegate.phase != phase || oldDelegate.dark != dark || oldDelegate.face != face;
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.season, required this.dark, required this.clock, this.burstAt}) : super(repaint: clock);

  final PokrovSeason season;
  final bool dark;
  final PokrovSeasonClock clock;
  final double? burstAt;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final soft = pokrovSeasonColor(season, PokrovColors.accentSoft, dark: dark)!;
    final glow = Offset(w / 2, h * .2);
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = ui.Gradient.radial(glow, h * .55, [_a(soft, dark ? .9 : 1), _a(soft, 0)]));
    _backdrop(canvas, season, w, h, clock.seconds, dark, burstAt);
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.season != season || oldDelegate.dark != dark || oldDelegate.burstAt != burstAt;
}

// ---- drawing ----

const _tau = math.pi * 2;

double _r(int i, int k) {
  final x = math.sin(i * 127.1 + k * 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

Color _a(Color color, double alpha) => color.withValues(alpha: alpha.clamp(0.0, 1.0));

Paint _fill(Color color) => Paint()..color = color;

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round;

void _oval(Canvas c, double x, double y, double rx, double ry, double rot, Paint paint) {
  c.save();
  c.translate(x, y);
  c.rotate(rot);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), paint);
  c.restore();
}

Path _heart(double x, double y, double s) => Path()
  ..moveTo(x, y + s * .35)
  ..cubicTo(x, y, x - s * .5, y - s * .1, x - s * .5, y + s * .25)
  ..cubicTo(x - s * .5, y + s * .55, x - s * .1, y + s * .7, x, y + s * .95)
  ..cubicTo(x + s * .1, y + s * .7, x + s * .5, y + s * .55, x + s * .5, y + s * .25)
  ..cubicTo(x + s * .5, y - s * .1, x, y, x, y + s * .35);

Path _star(double x, double y, double r, {int points = 5, double inner = .45, double rot = -math.pi / 2}) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final rr = i.isOdd ? r * inner : r;
    final a = rot + i * math.pi / points;
    final p = Offset(x + math.cos(a) * rr, y + math.sin(a) * rr);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

void _flake(Canvas c, double x, double y, double r, Paint paint) {
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    c.drawLine(Offset(x, y), Offset(x + math.cos(a) * r, y + math.sin(a) * r), paint);
  }
}

void _bat(Canvas c, double x, double y, double s, double flap, Paint paint) {
  _oval(c, x, y, s * .18, s * .28, 0, paint);
  for (final d in const [-1.0, 1.0]) {
    c.drawPath(Path()
      ..moveTo(x, y - s * .1)
      ..quadraticBezierTo(x + d * s * .5, y - s * .45 * flap, x + d * s, y - s * .2 * flap)
      ..quadraticBezierTo(x + d * s * .75, y + s * .05, x + d * s * .62, y + s * .18)
      ..quadraticBezierTo(x + d * s * .45, y + s * .02, x + d * s * .3, y + s * .2)
      ..quadraticBezierTo(x + d * s * .2, y, x, y + s * .12)
      ..close(), paint);
  }
}

void _egg(Canvas c, double x, double y, double s, Color body, Color ornament, int kind) {
  final shape = Path()
    ..moveTo(0, -s)
    ..cubicTo(s * .72, -s, s * .78, s * .75, 0, s * .75)
    ..cubicTo(-s * .78, s * .75, -s * .72, -s, 0, -s);
  c.save();
  c.translate(x, y);
  c.drawPath(shape, _fill(body));
  c.clipPath(shape);
  final paint = _fill(ornament);
  switch (kind) {
    case 0:
      final zig = Path()..moveTo(-s, .18 * s);
      for (var i = 1; i <= 8; i++) {
        zig.lineTo(-s + i * s / 4, (i.isOdd ? -.05 : .18) * s);
      }
      c.drawPath(zig, _stroke(ornament, s * .12)..strokeCap = StrokeCap.butt);
    case 1:
      for (var i = 0; i < 7; i++) {
        c.drawCircle(Offset((_r(i, 7) - .5) * s * 1.1, (_r(i, 8) - .6) * s * 1.4), s * .09, paint);
      }
    default:
      c.drawRect(Rect.fromLTWH(-s, -s * .25, s * 2, s * .14), paint);
      c.drawRect(Rect.fromLTWH(-s, s * .12, s * 2, s * .14), paint);
  }
  c.restore();
}

void _tulip(Canvas c, double x, double y, double h, Color color, double sway) {
  c.save();
  c.translate(x, y);
  c.rotate(sway);
  c.drawPath(Path()..moveTo(0, 0)..quadraticBezierTo(-2, -h * .5, 0, -h), _stroke(const Color(0xFF3E8A47), 2));
  _oval(c, -4, -h * .35, 2.5, 7, -.5, _fill(const Color(0xFF4E9A52)));
  c.drawPath(Path()
    ..moveTo(-6, -h)
    ..quadraticBezierTo(-7, -h - 11, -3, -h - 12)
    ..lineTo(0, -h - 7)
    ..lineTo(3, -h - 12)
    ..quadraticBezierTo(7, -h - 11, 6, -h)
    ..quadraticBezierTo(0, -h + 5, -6, -h), _fill(color));
  c.restore();
}

void _carnation(Canvas c, double x, double y, double h, double rot) {
  const stem = Color(0xFF3F7A45);
  c.save();
  c.translate(x, y);
  c.rotate(rot);
  c.drawLine(Offset.zero, Offset(0, -h), _stroke(stem, 1.8));
  c.drawPath(Path()..moveTo(-3, -h + 1)..lineTo(3, -h + 1)..lineTo(0, -h + 7)..close(), _fill(stem));
  for (var i = 0; i < 7; i++) {
    final a = -math.pi + i * math.pi / 6;
    _oval(c, math.cos(a) * 4, -h - 3 + math.sin(a) * 3, 3.6, 2.6, a, _fill(const Color(0xFFC42A32)));
  }
  c.drawCircle(Offset(0, -h - 4), 3, _fill(const Color(0xFFE0434B)));
  c.restore();
}

/// St. George ribbon folded into a loop: three black and two orange stripes.
void _ribbon(Canvas c, double x, double y, double rot) {
  final loop = Path()
    ..moveTo(-10, 16)
    ..cubicTo(-2, 4, 11, -9, 5, -16)
    ..cubicTo(-1, -23, -13, -13, -5, -3)
    ..cubicTo(1, 5, 8, 11, 11, 17);
  c.save();
  c.translate(x, y);
  c.rotate(rot);
  for (var i = 0; i < 5; i++) {
    c.drawPath(loop, _stroke(i.isEven ? const Color(0xFF1B1B1B) : const Color(0xFFF08A00), 7.5 - i * 1.5)..strokeCap = StrokeCap.butt);
  }
  c.restore();
}

void _laurel(Canvas c, Offset center, double r, double a0, double a1, Color color) {
  c.drawArc(Rect.fromCircle(center: center, radius: r), a0, a1 - a0, false, _stroke(color, 1.6));
  for (var i = 1; i <= 6; i++) {
    final a = a0 + (a1 - a0) * i / 7;
    final px = center.dx + math.cos(a) * r, py = center.dy + math.sin(a) * r;
    for (final s in const [-1.0, 1.0]) {
      _oval(c, px + math.cos(a) * s * 4, py + math.sin(a) * s * 4, 4.5, 2, a + s * .6 + math.pi / 2, _fill(color));
    }
  }
}

void _mimosa(Canvas c, int count, double alpha) {
  c.drawLine(Offset(-count * 1.3 - 1, count * .9 + 1), Offset(count * 1.3 + 1, -count * .9 - 1), _stroke(const Color(0xFF6E9E4E), 1.3));
  for (var k = 0; k < count; k++) {
    c.drawCircle(Offset(-count * 1.0 + k * 2.6, count * .65 - k * 1.9 + (k.isOdd ? -3 : 3)), 2.3,
        _fill(_a(k.isOdd ? const Color(0xFFF7D54A) : const Color(0xFFF2C230), alpha)));
  }
}

const _fireworkColors = [
  [Color(0xFFE5484D), Color(0xFFF5B83D), Color(0xFFFFFFFF)],
  [Color(0xFF4C9BEA), Color(0xFF3DBE6E), Color(0xFFF5B83D)],
  [Color(0xFFF07AA0), Color(0xFFFFFFFF), Color(0xFF4C9BEA)],
];

void _backdrop(Canvas c, PokrovSeason season, double w, double h, double t, bool dark, double? burstAt) {
  final k = (w / 260).clamp(1.0, 1.5);
  double fall(int i, double speed, double extra) => ((_r(i, 1) + t * speed) % 1) * (h + extra) - extra / 2;
  switch (season) {
    case PokrovSeason.halloween:
      final moon = Offset(w * .84, h * .14);
      c.drawPath(Path.combine(PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: moon, radius: 16 * k)),
          Path()..addOval(Rect.fromCircle(center: moon + Offset(7 * k, -4 * k), radius: 14 * k))),
          _fill(_a(const Color(0xFFF6D27A), dark ? .22 : .45)));
      final paint = _fill(dark ? const Color(0x61C9B5E6) : const Color(0x802A1B3D));
      for (var i = 0; i < 5; i++) {
        final x = (((_r(i, 0) + t * (.035 + _r(i, 2) * .03)) % 1.25) - .12) * w;
        final y = h * (.07 + _r(i, 1) * .32) + math.sin(t * 1.3 + i) * 8 * k;
        _bat(c, x, y, (8 + _r(i, 3) * 6) * k, math.sin(t * 9 + i * 2), paint);
      }
    case PokrovSeason.newYear:
    case PokrovSeason.christmas:
      final newYear = season == PokrovSeason.newYear;
      final snow = dark ? const Color(0xB3FFFFFF) : const Color(0xD98DB6D8);
      final line = _stroke(snow, k);
      for (var i = 0; i < (newYear ? 26 : 12); i++) {
        final speed = newYear ? .035 + _r(i, 2) * .045 : .02 + _r(i, 2) * .02;
        final x = _r(i, 0) * w + math.sin(t * .6 + i) * 10 * k, y = fall(i, speed, 20);
        final r = (1 + _r(i, 3) * 2.3) * k;
        r > 2.6 * k ? _flake(c, x, y, r + 1.5 * k, line) : c.drawCircle(Offset(x, y), r, _fill(snow));
      }
      if (!newYear) {
        for (var i = 0; i < 12; i++) {
          final glow = .25 + .75 * math.sin(t * 1.2 + i * 2.1).abs();
          c.drawPath(_star(_r(i, 4) * w, h * (.04 + _r(i, 5) * .55), (2.5 + _r(i, 6) * 3) * k, points: 4, inner: .35),
              _fill(_a(const Color(0xFFE8B53C), glow * (dark ? .7 : .85))));
        }
      }
      if (newYear && burstAt != null) {
        for (var b = 0; b < 5; b++) {
          final p = (t - burstAt - .2 - b * .45) / 1.7;
          if (p < 0 || p > 1) continue;
          final cx = (.2 + _r(b, 9) * .6) * w, cy = (.12 + _r(b, 10) * .25) * h;
          for (var i = 0; i < 30; i++) {
            final a = i / 30 * _tau, rr = math.sqrt(p) * 62 * k;
            c.drawCircle(Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr + p * p * 26 * k), 2.2 * (1 - p * .5) * k,
                _fill(_a(_fireworkColors[b % 3][i % 3], 1 - p)));
          }
        }
      }
    case PokrovSeason.valentine:
      for (var i = 0; i < 10; i++) {
        final x = _r(i, 0) * w + math.sin(t * .8 + i * 3) * 12 * k;
        final y = h - ((_r(i, 1) + t * (.03 + _r(i, 2) * .03)) % 1) * (h + 30) + 10;
        c.drawPath(_heart(x, y, (7 + _r(i, 3) * 8) * k),
            _fill(_a(dark ? const Color(0xFFF5A3C0) : const Color(0xFFE0457B), (dark ? .3 : .32) + _r(i, 4) * .2)));
      }
    case PokrovSeason.defender:
      for (var i = 0; i < 8; i++) {
        c.drawPath(_star(_r(i, 0) * w, fall(i, .012 + _r(i, 2) * .012, 20), (4 + _r(i, 3) * 4) * k),
            _fill(_a(dark ? const Color(0xFFE8686D) : const Color(0xFFC8343A), .22 + .12 * math.sin(t + i))));
      }
    case PokrovSeason.womensDay:
      for (var i = 0; i < 9; i++) {
        c.save();
        c.translate(_r(i, 0) * w + math.sin(t * .7 + i) * 12 * k, fall(i, .02 + _r(i, 2) * .02, 30));
        c.rotate(math.sin(t * .5 + i));
        c.scale(k);
        _mimosa(c, 5, dark ? .75 : .95);
        c.restore();
      }
      for (var i = 0; i < 6; i++) {
        final y = ((_r(i, 7) + t * (.025 + _r(i, 5) * .02)) % 1) * (h + 20) - 10;
        _oval(c, _r(i, 6) * w, y, 4 * k, 2.2 * k, t * .8 + i, _fill(_a(const Color(0xFFF07AA0), dark ? .4 : .45)));
      }
    case PokrovSeason.aprilFools:
      const colors = [Color(0xFFFF5A5F), Color(0xFFFFC145), Color(0xFF3DCCC7), Color(0xFF5B4BD6), Color(0xFF7BD389)];
      for (var i = 0; i < 22; i++) {
        c.save();
        c.translate(_r(i, 0) * w + math.sin(t + i) * 8 * k, fall(i, .03 + _r(i, 2) * .035, 20));
        c.rotate(t * 2 + i);
        c.scale(1, math.cos(t * 3 + i));
        c.drawRect(Rect.fromCenter(center: Offset.zero, width: 6 * k, height: 3.2 * k), _fill(_a(colors[i % 5], dark ? .7 : .8)));
        c.restore();
      }
    case PokrovSeason.cosmonautics:
      for (var i = 0; i < 30; i++) {
        final glow = .2 + .8 * math.sin(t * (.6 + _r(i, 3)) + i).abs();
        c.drawCircle(Offset(_r(i, 0) * w, _r(i, 1) * h * .75), (.6 + _r(i, 2) * 1.3) * k,
            _fill(dark ? _a(const Color(0xFFFFFFFF), glow * .8) : _a(const Color(0xFF33409E), glow * .45)));
      }
      final accent = pokrovSeasonColor(season, PokrovColors.accent, dark: dark)!;
      final planet = Offset(w * .87, h * .26);
      c.drawCircle(planet, 11 * k, _fill(_a(accent, .18)));
      _oval(c, planet.dx, planet.dy, 19 * k, 5 * k, -.35, _stroke(_a(accent, .35), 1.5));
      final cycle = (t % 11) / 4;
      if (cycle < 1) {
        c.save();
        c.translate(-20 + cycle * (w + 40), h * .62 - cycle * h * .45);
        c.rotate(-math.atan2(h * .45, w + 40) + math.pi / 2);
        c.scale(k);
        c.drawPath(Path()..moveTo(-3, 9)..lineTo(0, 19 + math.sin(t * 40) * 3)..lineTo(3, 9)..close(),
            _fill(_a(const Color(0xFFFFB13B), .8 + .2 * math.sin(t * 31))));
        final body = Path()..moveTo(0, -11)..quadraticBezierTo(6, -3, 4, 9)..lineTo(-4, 9)..quadraticBezierTo(-6, -3, 0, -11);
        c.drawPath(body, _fill(dark ? const Color(0xFFE8ECF7) : const Color(0xFFFFFFFF)));
        c.drawPath(body, _stroke(dark ? const Color(0xFF9AA3C7) : const Color(0xFF33409E), 1));
        for (final d in const [-1.0, 1.0]) {
          c.drawPath(Path()..moveTo(d * 4, 4)..lineTo(d * 8, 11)..lineTo(d * 4, 9)..close(), _fill(const Color(0xFFD8434B)));
        }
        c.drawCircle(const Offset(0, -2), 2, _fill(const Color(0xFF4C9BEA)));
        c.restore();
      }
    case PokrovSeason.easter:
      for (var i = 0; i < 12; i++) {
        final x = _r(i, 0) * w + math.sin(t * .7 + i) * 14 * k, y = fall(i, .02 + _r(i, 2) * .02, 20);
        _oval(c, x, y, 4.5 * k, 2.6 * k, t * .6 + i, _fill(_a(i % 3 == 0 ? const Color(0xFFFFFFFF) : const Color(0xFFF6C9D8), dark ? .45 : .9)));
      }
      c.save();
      c.translate(0, h * .17);
      c.rotate(math.sin(t * .7) * .03);
      c.scale(k);
      c.drawPath(Path()..moveTo(-5, 0)..quadraticBezierTo(40, 6, 70, 34), _stroke(const Color(0xFF8A5A3B), 2));
      for (var i = 0; i < 5; i++) {
        final p = .2 + i * .17;
        _oval(c, -5 + 75 * p + (i.isOdd ? 4 : -3), 34 * p * p + 3 + (i.isOdd ? -4 : 4), 3.6, 5.2, i.isOdd ? .6 : -.6,
            _fill(dark ? const Color(0xFFC9C4BE) : const Color(0xFFE7E2DC)));
      }
      c.restore();
    case PokrovSeason.victoryDay:
      for (var i = 0; i < 8; i++) {
        final x = w * (.15 + _r(i, 0) * .7) + math.sin(t * .4 + i) * 10 * k;
        final y = h - ((_r(i, 1) + t * (.012 + _r(i, 2) * .01)) % 1) * h * .9;
        c.drawCircle(Offset(x, y), (1.4 + _r(i, 3) * 1.4) * k,
            _fill(_a(const Color(0xFFE8A33D), (dark ? .35 : .4) * (.5 + .5 * math.sin(t * .8 + i)))));
      }
  }
}

/// April Fools eyes in the upper part of the circle, behind the label.
void _googlyEyes(Canvas c, double diameter, double t) {
  final r = diameter / 2;
  for (final d in const [-1.0, 1.0]) {
    final eye = Offset(r + d * r * .3, r - r * .52), er = r * .15;
    c.drawCircle(eye, er, _fill(const Color(0xFFFFFFFF)));
    c.drawCircle(eye, er, _stroke(const Color(0xFF16181D), 1.4));
    final m = er * .45;
    c.drawCircle(eye + Offset(math.sin(t * 2.1 + d) * m * .8, (math.cos(t * 1.7) * .4 + .35) * m), er * .48, _fill(const Color(0xFF16181D)));
  }
}

/// Ring decoration in a 178-unit square (the ring area of the button).
void _buttonDecor(Canvas c, PokrovSeason season, double t, bool dark, bool on) {
  const cx = 89.0, o = 86.0, ri = 71.2, center = Offset(cx, cx);
  Offset at(double deg, double r) => Offset(cx + math.cos(deg * math.pi / 180) * r, cx + math.sin(deg * math.pi / 180) * r);
  switch (season) {
    case PokrovSeason.halloween:
      final p = at(40, o - 6);
      for (final dx in const [-7.0, 7.0]) {
        _oval(c, p.dx + dx, p.dy, 9, 11, 0, _fill(const Color(0xFFE8761E)));
      }
      _oval(c, p.dx, p.dy, 10, 12, 0, _fill(const Color(0xFFF08A24)));
      c.drawRect(Rect.fromLTWH(p.dx - 1.5, p.dy - 16, 3, 6), _fill(const Color(0xFF4E7A2A)));
      final faceColor = on ? _a(const Color(0xFFFFD25A), .75 + .25 * math.sin(t * 12) * math.sin(t * 7)) : const Color(0xFF3A2410);
      final face = _fill(faceColor);
      c.drawPath(_star(p.dx - 5, p.dy - 2, 3, points: 3, inner: .5), face);
      c.drawPath(_star(p.dx + 5, p.dy - 2, 3, points: 3, inner: .5), face);
      c.drawPath(Path()
        ..moveTo(p.dx - 7, p.dy + 4)
        ..quadraticBezierTo(p.dx, p.dy + 11, p.dx + 7, p.dy + 4)
        ..quadraticBezierTo(p.dx, p.dy + 7, p.dx - 7, p.dy + 4), face);
      final sx = cx - ri * .55, sy = 26 + math.sin(t * 1.1) * 7;
      c.drawLine(Offset(sx, 4), Offset(sx, sy), _stroke(dark ? const Color(0x80FFFFFF) : const Color(0x73281E32), .8));
      final spider = dark ? const Color(0xFFD5C4E8) : const Color(0xFF2A1B3D);
      c.drawCircle(Offset(sx, sy + 3), 3.4, _fill(spider));
      for (final d in const [-1.0, 1.0]) {
        for (var i = 0; i < 3; i++) {
          c.drawLine(Offset(sx, sy + 2 + i * 1.5), Offset(sx + d * 6, sy + i * 2.5 - 1), _stroke(spider, 1));
        }
      }
    case PokrovSeason.newYear:
      const bulbs = [Color(0xFFE5484D), Color(0xFFF5B83D), Color(0xFF3DBE6E), Color(0xFF4C9BEA)];
      double wire(double deg) => o - 1 + math.sin(deg * math.pi / 180 * 7) * 2;
      final garland = Path();
      for (var deg = 0.0; deg <= 360; deg += 4) {
        final p = at(deg, wire(deg));
        deg == 0 ? garland.moveTo(p.dx, p.dy) : garland.lineTo(p.dx, p.dy);
      }
      c.drawPath(garland, _stroke(dark ? const Color(0xFF4C6A5A) : const Color(0xFF2F6B48), 1));
      for (var i = 0; i < 14; i++) {
        final deg = i * 360 / 14 + 10, p = at(deg, wire(deg));
        final glow = .45 + .55 * math.sin(t * 2.6 + i * 1.7).abs();
        final color = bulbs[i % 4];
        c.drawCircle(p, 7, Paint()..shader = ui.Gradient.radial(p, 7, [_a(color, glow * .6), _a(color, 0)]));
        c.drawCircle(p, 2.6, _fill(_a(color, .5 + glow * .5)));
      }
      const a0 = -150.0, a1 = -30.0;
      final cap = Path();
      for (var deg = a0; deg <= a1; deg += 3) {
        final p = at(deg, o + 1 + math.sin((deg - a0) / (a1 - a0) * math.pi) * 3 + math.sin(deg / 6));
        deg == a0 ? cap.moveTo(p.dx, p.dy) : cap.lineTo(p.dx, p.dy);
      }
      for (var deg = a1; deg >= a0; deg -= 3) {
        final p = at(deg, o - 9 + math.sin((deg - a0) / (a1 - a0) * math.pi * 5) * 2.5);
        cap.lineTo(p.dx, p.dy);
      }
      cap.close();
      c.drawPath(cap, _fill(const Color(0xFFFFFFFF)));
      if (!dark) c.drawPath(cap, _stroke(const Color(0xFFCFE0EE), 1));
    case PokrovSeason.christmas:
      const star = Offset(cx, 13);
      c.drawCircle(star, 22, Paint()..shader = ui.Gradient.radial(star, 22,
          [_a(const Color(0xFFF2C14E), .5 + .25 * math.sin(t * 1.8)), _a(const Color(0xFFF2C14E), 0)]));
      final gold = _fill(const Color(0xFFF2C14E));
      c.drawPath(_star(star.dx, star.dy, 9, points: 4, inner: .3), gold);
      c.drawPath(_star(star.dx, star.dy, 6, points: 4, inner: .35, rot: -math.pi / 4), gold);
      c.drawPath(Path()..moveTo(cx - 1.2, 19)..lineTo(cx, 31)..lineTo(cx + 1.2, 19)..close(), gold);
      for (final d in const [-1.0, 1.0]) {
        final b = at(90 + d * 48, o - 4);
        c.save();
        c.translate(b.dx, b.dy);
        c.rotate(d * .9);
        const fir = Color(0xFF2F7A4A);
        c.drawLine(const Offset(-14, 0), const Offset(14, 0), _stroke(fir, 1.6));
        for (var n = -12.0; n <= 12; n += 3) {
          c.drawLine(Offset(n, 0), Offset(n + 3, -5), _stroke(fir, 1.2));
          c.drawLine(Offset(n, 0), Offset(n + 3, 5), _stroke(fir, 1.2));
        }
        c.drawCircle(const Offset(2, 4), 3.2, _fill(const Color(0xFFD33A4A)));
        c.restore();
      }
    case PokrovSeason.valentine:
      final beat = on ? math.pow(math.max(0, math.sin(t * _tau * 1.1)), 8).toDouble() : 0.0;
      final paint = _fill(_a(dark ? const Color(0xFFF5A3C0) : const Color(0xFFE0457B), .85));
      for (var i = 0; i < 8; i++) {
        final p = at(i * 45 + t * 14, o - 2);
        c.drawPath(_heart(p.dx, p.dy - 4, (i.isOdd ? 7 : 9) * (1 + .25 * beat)), paint);
      }
    case PokrovSeason.defender:
      final star = _star(cx, 12, 10);
      c.drawPath(star, _fill(const Color(0xFFC8343A)));
      c.drawPath(star, _stroke(const Color(0xFFE8B53C), 1.2));
      final leaves = dark ? const Color(0xFF9DBA70) : const Color(0xFF6B8A3A);
      _laurel(c, center, o - 2, math.pi * .95, math.pi * .58, leaves);
      _laurel(c, center, o - 2, math.pi * .05, math.pi * .42, leaves);
    case PokrovSeason.womensDay:
      final sway = math.sin(t * 1.1) * .05, b = at(132, o - 2);
      _tulip(c, b.dx - 6, b.dy + 8, 22, const Color(0xFFE0475B), sway - .25);
      _tulip(c, b.dx + 2, b.dy + 8, 26, const Color(0xFFF07AA0), sway);
      _tulip(c, b.dx + 10, b.dy + 8, 21, const Color(0xFFB44AA8), sway + .25);
      final m = at(48, o - 6);
      c.save();
      c.translate(m.dx, m.dy);
      c.rotate(-.5 + sway);
      _mimosa(c, 9, 1);
      c.restore();
    case PokrovSeason.aprilFools:
      c.save();
      c.translate(cx + 18, 12);
      c.rotate(.35 + math.sin(t * 2) * .06);
      c.drawPath(Path()..moveTo(-10, 10)..lineTo(0, -16)..lineTo(10, 10)..close(),
          _fill(pokrovSeasonColor(season, PokrovColors.accent, dark: dark)!));
      c.drawRect(const Rect.fromLTWH(-7, 2, 14, 2.5), _fill(const Color(0xFFFFC145)));
      c.drawRect(const Rect.fromLTWH(-4, -6, 8, 2.5), _fill(const Color(0xFFFFC145)));
      c.drawCircle(const Offset(0, -17), 3.5, _fill(const Color(0xFFFF5A5F)));
      c.restore();
    case PokrovSeason.cosmonautics:
      final accent = pokrovSeasonColor(season, PokrovColors.accent, dark: dark)!;
      final orbit = Rect.fromCircle(center: center, radius: o - 1);
      for (var i = 0; i < 60; i++) {
        c.drawArc(orbit, i * _tau / 60, _tau / 60 * .35, false, _stroke(_a(accent, .4), 1));
      }
      final s = at(t * 30 - 90, o - 1);
      c.save();
      c.translate(s.dx, s.dy);
      c.rotate(t * .5);
      for (var i = 0; i < 4; i++) {
        final a = math.pi * .6 + i * .18;
        c.drawLine(Offset.zero, Offset(math.cos(a) * 13, math.sin(a) * 13), _stroke(dark ? const Color(0xFFC1C6EB) : const Color(0xFF5A6170), 1));
      }
      c.drawCircle(Offset.zero, 4.6, Paint()..shader = ui.Gradient.radial(const Offset(-1.5, -1.5), 5, const [Color(0xFFFFFFFF), Color(0xFF9AA3B5)]));
      c.restore();
      for (var i = 0; i < 5; i++) {
        final p = at(200 + i * 35, o + 1 + (i.isOdd ? 3 : -2));
        c.drawPath(_star(p.dx, p.dy, 3, points: 4, inner: .35), _fill(_a(const Color(0xFFF2C14E), .4 + .6 * math.sin(t * 1.5 + i).abs())));
      }
    case PokrovSeason.easter:
      final e = at(90, o - 6);
      _egg(c, e.dx - 15, e.dy + 2, 9, const Color(0xFF7FA8D9), const Color(0xFFFFFFFF), 1);
      _egg(c, e.dx + 15, e.dy + 2, 9, const Color(0xFFF2C94C), const Color(0xFFE07A2E), 2);
      _egg(c, e.dx, e.dy - 1, 11, const Color(0xFFC8343A), const Color(0xFFF2C14E), 0);
      final v = at(-50, o - 3);
      c.save();
      c.translate(v.dx, v.dy);
      c.rotate(.6 + math.sin(t * .9) * .05);
      c.drawPath(Path()..moveTo(-14, 10)..quadraticBezierTo(0, 0, 14, -10), _stroke(const Color(0xFF8A5A3B), 1.6));
      for (var i = 0; i < 4; i++) {
        _oval(c, -9 + i * 7 + (i.isOdd ? 3 : -2), 6 - i * 5 + (i.isOdd ? -3 : 2), 2.8, 4, .5,
            _fill(dark ? const Color(0xFFC9C4BE) : const Color(0xFFE7E2DC)));
      }
      c.restore();
    case PokrovSeason.victoryDay:
      final star = _star(cx, 12, 9.5);
      c.drawPath(star, _fill(const Color(0xFFB3262C)));
      c.drawPath(star, _stroke(const Color(0xFFD9A441), 1.2));
      final b = at(118, o - 2);
      _carnation(c, b.dx, b.dy + 10, 24, -.18);
      _carnation(c, b.dx + 7, b.dy + 10, 27, .12);
      final r = at(60, o - 6);
      _ribbon(c, r.dx, r.dy, -.25);
  }
}
