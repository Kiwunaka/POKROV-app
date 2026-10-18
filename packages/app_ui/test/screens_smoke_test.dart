import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_ui/pokrov_app_ui.dart';

/// Loads the real Golos Text so layout checks match the device.
Future<void> _loadGolos() async {
  final loader = FontLoader(pokrovFontFamily);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/GolosText-$weight.ttf'));
  }
  await loader.load();
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: pokrovUiTheme(), home: Scaffold(body: child)));
  await tester.pump(const Duration(seconds: 1));
}

void _noop() {}

void main() {
  setUpAll(_loadGolos);

  for (final mode in InterfaceMode.values) {
    for (final phase in ConnectionPhase.values) {
      testWidgets('home ${mode.name} ${phase.name}', (tester) async {
        await _pump(
          tester,
          HomeScreen(
            data: PokrovSampleData.home(phase: phase, mode: mode),
            onToggle: _noop,
            onOpenStatus: _noop,
            onOpenCountry: _noop,
            onOpenRoute: _noop,
            onOpenAccess: _noop,
            onWarpChanged: (_) {},
          ),
        );
        expect(find.text('POKROV VPN'), findsOneWidget);
        expect(find.text('Российские сайты'), findsOneWidget);
        expect(find.text('WARP'), mode == InterfaceMode.advanced ? findsOneWidget : findsNothing);
        expect(find.text('Не получилось подключиться'), phase == ConnectionPhase.error ? findsOneWidget : findsNothing);
      });
    }
  }

  testWidgets('status sheet on and off', (tester) async {
    for (final phase in [ConnectionPhase.on, ConnectionPhase.off]) {
      await _pump(tester, StatusSheet(data: PokrovSampleData.status(phase: phase), onPrimary: _noop, onDetails: _noop));
      expect(find.text(phase == ConnectionPhase.on ? 'Всё работает' : 'Защита выключена'), findsOneWidget);
      expect(find.text('Туннель'), findsNothing);
    }
  });

  testWidgets('first connect sheet', (tester) async {
    await _pump(tester, FirstConnectSheet(choice: FirstRouteChoice.wholePhone, onChanged: (_) {}, onContinue: _noop));
    expect(find.text('Продолжить и подключить'), findsOneWidget);
  });

  testWidgets('start, locations, rules, profile', (tester) async {
    await _pump(tester, StartScreen(onStart: _noop, onHaveCode: _noop));
    expect(find.text('Начать бесплатно'), findsOneWidget);
    for (final mode in InterfaceMode.values) {
      await _pump(tester, LocationsScreen(data: LocationsViewData(mode: mode, countries: PokrovSampleData.countries), onAuto: _noop, onSelect: (_) {}));
      expect(find.text('Германия'), findsOneWidget);
      await _pump(tester, ProfileScreen(data: PokrovSampleData.profile(mode), onRenew: _noop, onModeChanged: (_) {}));
      expect(find.text('Продвинутый'), findsOneWidget);
    }
    await _pump(tester, RulesScreen(data: PokrovSampleData.rules(selected: 'all'), onSelect: (_) {}, onApply: _noop));
    expect(find.text('Применить'), findsOneWidget);
  });

  testWidgets('renew, support, bonuses, diagnostics', (tester) async {
    await _pump(tester, RenewScreen(data: PokrovSampleData.renew(), onSelect: (_) {}, onPay: _noop, onBack: _noop));
    expect(find.text('Перейти к оплате · 2 000 ₽'), findsOneWidget);
    await _pump(tester, SupportScreen(data: PokrovSampleData.support, onSend: (_) {}, onBack: _noop));
    expect(find.text('Позвать человека'), findsOneWidget);
    await _pump(tester, BonusesScreen(data: PokrovSampleData.bonuses, onBack: _noop));
    expect(find.text('+24'), findsOneWidget);
    for (final on in [true, false]) {
      await _pump(tester, DiagnosticsScreen(data: PokrovSampleData.diagnostics(on: on), onBack: _noop, onSend: _noop));
      expect(find.text('Отправить отчёт в поддержку'), findsOneWidget);
    }
  });

  testWidgets('tab bar shows Rules only in advanced mode', (tester) async {
    await _pump(tester, PokrovTabBar(mode: InterfaceMode.simple, current: PokrovTab.protection, onSelect: (_) {}));
    expect(find.text('Правила'), findsNothing);
    await _pump(tester, PokrovTabBar(mode: InterfaceMode.advanced, current: PokrovTab.rules, onSelect: (_) {}));
    expect(find.text('Правила'), findsOneWidget);
  });
}
