import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_ui/pokrov_app_ui.dart';
import '../example/lib/sample_data.dart';

/// Loads the real Golos Text so layout checks match the device.
Future<void> _loadGolos() async {
  final loader = FontLoader(pokrovFontFamily);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/GolosText-$weight.ttf'));
  }
  await loader.load();
}

Future<void> _pump(WidgetTester tester, Widget child, {double textScale = 1}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: pokrovUiTheme(), home: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(textScale)), child: Scaffold(body: child))));
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

  testWidgets('home connect and status expose working accessibility actions', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var connects = 0;
      var statuses = 0;
      await _pump(tester, HomeScreen(
        data: PokrovSampleData.home(phase: ConnectionPhase.off, mode: InterfaceMode.simple),
        onToggle: () => connects++, onOpenStatus: () => statuses++,
        onOpenCountry: _noop, onOpenRoute: _noop, onOpenAccess: _noop,
      ));
      final connect = tester.getSemantics(find.bySemanticsLabel('Включить защиту'));
      final status = tester.getSemantics(find.bySemanticsLabel(RegExp('^Состояние защиты:')));
      expect(connect.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(status.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.platformDispatcher.onSemanticsActionEvent!(SemanticsActionEvent(
        type: SemanticsAction.tap, nodeId: connect.id, viewId: tester.view.viewId,
      ));
      tester.binding.platformDispatcher.onSemanticsActionEvent!(SemanticsActionEvent(
        type: SemanticsAction.tap, nodeId: status.id, viewId: tester.view.viewId,
      ));
      expect(connects, 1);
      expect(statuses, 1);

      await _pump(tester, HomeScreen(
        data: PokrovSampleData.home(phase: ConnectionPhase.off, mode: InterfaceMode.simple),
        onToggle: null, onOpenStatus: _noop,
        onOpenCountry: _noop, onOpenRoute: _noop, onOpenAccess: _noop,
      ));
      final disabled = tester.getSemantics(find.bySemanticsLabel('Включить защиту'));
      expect(disabled.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('segmented choices can be reached and activated by keyboard', (tester) async {
    final selected = <int>[];
    await _pump(tester, Center(child: SizedBox(width: 214, child: PokrovSegmented(
      labels: const ['Просто', 'Продвинутый'], index: 0, onChanged: selected.add,
    ))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, [0]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, [0, 1]);
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
    InterfaceMode? selectedMode;
    await _pump(tester, ProfileScreen(data: PokrovSampleData.profile(InterfaceMode.simple),
      onRenew: _noop, onModeChanged: (mode) => selectedMode = mode), textScale: 2);
    expect(tester.takeException(), isNull);
    final advanced = find.descendant(of: find.byType(PokrovSegmented), matching: find.text('Продвинутый'));
    expect(tester.renderObject<RenderParagraph>(advanced).didExceedMaxLines, isFalse,
      reason: 'the interface mode must remain readable at 200% text scale');
    await tester.ensureVisible(advanced);
    await tester.tap(advanced);
    expect(selectedMode, InterfaceMode.advanced);
    await _pump(tester, RulesScreen(data: PokrovSampleData.rules(selected: 'all'), onSelect: (_) {}, onApply: _noop));
    expect(find.text('Применить'), findsOneWidget);
  });

  testWidgets('renew, support, bonuses, diagnostics', (tester) async {
    await _pump(tester, RenewScreen(data: PokrovSampleData.renew(), onSelect: (_) {}, onPay: _noop, onBack: _noop));
    expect(find.text('Перейти к оплате · 2 000 ₽'), findsOneWidget);
    final catalog = RenewViewData(current: 'Доступ активен', selectedId: 'intro', introOffer: '', plans: [
      const PlanOption(id: 'intro', short: 'Первый месяц', title: 'Первый месяц', price: '100 ₽', perMonth: '', saving: ''),
      for (final plan in PokrovSampleData.plans) PlanOption(id: plan.id, short: plan.title,
        title: plan.title, price: plan.price, perMonth: '', saving: ''),
    ]);
    for (final scale in [1.0, 2.0]) {
      await _pump(tester, RenewScreen(data: catalog, onSelect: (_) {}, onPay: _noop, onBack: _noop), textScale: scale);
      for (final plan in catalog.plans) {
        final label = find.descendant(of: find.byType(PokrovSegmented), matching: find.text(plan.title));
        expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines, isFalse,
          reason: 'the full platform plan title must remain readable at $scale text scale');
      }
    }
    await _pump(tester, SupportScreen(data: PokrovSampleData.support, onSend: (_) {}, onBack: _noop, onHuman: _noop));
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

  testWidgets('support keeps an externally owned draft until accepted and exposes the human action', (tester) async {
    final composer = TextEditingController();
    final sent = <String>[];
    var human = false;
    await _pump(tester, SupportScreen(
      data: const SupportViewData(topics: [], messages: []),
      composer: composer, onSend: sent.add, onBack: _noop,
      onHuman: () => human = true,
    ));
    await tester.enterText(find.byKey(const ValueKey('support-composer')), 'Не открывается сайт');
    await tester.tap(find.byKey(const ValueKey('support-send-action')));
    await tester.pump();
    expect(sent, ['Не открывается сайт']);
    expect(composer.text, 'Не открывается сайт', reason: 'only the real send controller may clear an accepted draft');
    await tester.tap(find.text('Позвать человека'));
    expect(human, isTrue);
    expect(find.text('Переподключить'), findsNothing, reason: 'no fabricated assistant action without a callback');
    await tester.pumpWidget(const SizedBox.shrink());
    composer.dispose();
  });
}
