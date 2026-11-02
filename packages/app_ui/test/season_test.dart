import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_ui/pokrov_app_ui.dart';
import '../example/lib/sample_data.dart';

Future<void> _loadGolos() async {
  final loader = FontLoader(pokrovFontFamily);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/GolosText-$weight.ttf'));
  }
  await loader.load();
}

Future<void> _pumpHome(WidgetTester tester, {
  PokrovSeason? season,
  Brightness brightness = Brightness.light,
  ConnectionPhase phase = ConnectionPhase.off,
  bool reduceMotion = false,
  double textScale = 1,
  VoidCallback? onToggle,
  VoidCallback? onStatus,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(
    theme: pokrovUiTheme(brightness: brightness, season: season),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion, textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: HomeScreen(
        data: PokrovSampleData.home(phase: phase, mode: InterfaceMode.simple),
        onToggle: onToggle ?? () {}, onOpenStatus: onStatus ?? () {},
        onOpenCountry: () {}, onOpenRoute: () {}, onOpenAccess: () {},
      )),
    ),
  ));
  await tester.pump(const Duration(seconds: 1));
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + .05 : lb + .05) / (la > lb ? lb + .05 : la + .05);
}

void main() {
  setUpAll(_loadGolos);

  for (final season in PokrovSeason.values) {
    for (final brightness in Brightness.values) {
      testWidgets('${season.name} ${brightness.name} decorates home and keeps the status', (tester) async {
        for (final phase in [ConnectionPhase.off, ConnectionPhase.connecting, ConnectionPhase.on]) {
          await _pumpHome(tester, season: season, brightness: brightness, phase: phase);
          expect(tester.takeException(), isNull);
          expect(tester.widget<CustomPaint>(find.byKey(const ValueKey('season-backdrop'))).painter, isNotNull);
          expect(tester.widget<CustomPaint>(find.byKey(const ValueKey('season-decor'))).painter, isNotNull);
        }
        expect(find.text('Защищено'), findsOneWidget);
        expect(find.text('Германия · 00:12:48'), findsOneWidget);
      });
    }
  }

  test('seasonal accents keep readable text in both themes', () {
    for (final season in PokrovSeason.values) {
      Color light(Color token) => pokrovSeasonColor(season, token, dark: false)!;
      Color dark(Color token) => pokrovSeasonColor(season, token, dark: true)!;
      expect(_contrast(light(PokrovColors.accent), Colors.white), greaterThanOrEqualTo(4.5), reason: season.name);
      expect(_contrast(light(PokrovColors.accentText), light(PokrovColors.accentSoft)), greaterThanOrEqualTo(4.5), reason: season.name);
      expect(_contrast(dark(PokrovColors.accent), const Color(0xFF101713)), greaterThanOrEqualTo(4.5), reason: season.name);
      expect(_contrast(dark(PokrovColors.accentText), dark(PokrovColors.accentSoft)), greaterThanOrEqualTo(4.5), reason: season.name);
      expect(pokrovSeasonColor(season, PokrovColors.warnDot, dark: false), isNull);
      expect(pokrovSeasonColor(season, PokrovColors.connected, dark: true), isNull);
    }
    expect(pokrovSeasonColor(null, PokrovColors.accent, dark: false), isNull);
  });

  testWidgets('an error hides the decoration and stays an error', (tester) async {
    await _pumpHome(tester, season: PokrovSeason.newYear, phase: ConnectionPhase.error);
    expect(tester.widget<CustomPaint>(find.byKey(const ValueKey('season-decor'))).painter, isNull);
    final fade = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.byKey(const ValueKey('season-backdrop')), matching: find.byType(AnimatedOpacity)));
    expect(fade.opacity, 0);
    expect(find.text('Не получилось подключиться'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Не получилось'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('motion stops under reduced motion, when muted and after a quiet minute', (tester) async {
    await _pumpHome(tester, season: PokrovSeason.newYear);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(seconds: 61));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.transientCallbackCount, 0, reason: 'a minute without touches stops the motion');
    await tester.tapAt(const Offset(20, 600));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.transientCallbackCount, greaterThan(0), reason: 'a touch wakes it again');

    await _pumpHome(tester, season: PokrovSeason.newYear, reduceMotion: true);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.widget<CustomPaint>(find.byKey(const ValueKey('season-backdrop'))).painter, isNotNull,
        reason: 'reduced motion keeps a still decoration');

    await _pumpHome(tester);
    expect(tester.binding.transientCallbackCount, 0, reason: 'ordinary days have no holiday motion');
  });

  testWidgets('the off status stays readable in the dark theme', (tester) async {
    await _pumpHome(tester, season: PokrovSeason.victoryDay, brightness: Brightness.dark);
    final color = tester.widget<Text>(find.text('Защита выключена')).style!.color!;
    expect(_contrast(color, const Color(0xFF26322B)), greaterThanOrEqualTo(4.5));
  });

  testWidgets('status and connect stay tappable over the decoration', (tester) async {
    var toggles = 0, statuses = 0;
    await _pumpHome(tester, season: PokrovSeason.aprilFools, onToggle: () => toggles++, onStatus: () => statuses++);
    await tester.tap(find.text('Защита выключена'));
    await tester.tap(find.text('Подключить'));
    expect(statuses, 1);
    expect(toggles, 1);
  });

  testWidgets('decorated home keeps text readable at 200% scale', (tester) async {
    for (final season in [PokrovSeason.aprilFools, PokrovSeason.newYear, PokrovSeason.victoryDay]) {
      for (final phase in [ConnectionPhase.off]) {
        await _pumpHome(tester, season: season, phase: phase, textScale: 2);
        expect(tester.takeException(), isNull, reason: '${season.name} ${phase.name}');
        expect(find.text(phase == ConnectionPhase.off ? 'Защита выключена' : 'Германия · 00:12:48'), findsOneWidget);
      }
    }
  });
}
