import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_ui/pokrov_app_ui.dart';
import '../example/lib/sample_data.dart';

/// Loads the real Onest and Unbounded so layout checks match the device.
Future<void> _loadFonts() async {
  final loader = FontLoader(pokrovFontFamily);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/Onest-$weight.ttf'));
  }
  await loader.load();
  final display = FontLoader(pokrovDisplayFontFamily);
  for (final weight in ['SemiBold', 'Bold', 'ExtraBold']) {
    display.addFont(rootBundle.load('assets/fonts/Unbounded-$weight.ttf'));
  }
  await display.load();
}

Future<void> _pump(WidgetTester tester, Widget child, {double textScale = 1}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: pokrovUiTheme(), home: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(textScale)), child: Scaffold(body: child))));
  await tester.pump(const Duration(seconds: 1));
}

void _noop() {}

List<HomeTile> _tiles({bool warp = false, VoidCallback? onWarp}) => [
  HomeTile(id: 'country', title: 'Страна', value: 'Авто', icon: Icons.public_rounded, onTap: _noop),
  HomeTile(id: 'route', title: 'Маршрут', value: 'Россия напрямую', icon: Icons.alt_route_rounded, onTap: _noop),
  HomeTile(id: 'bypass', title: 'Обход блокировок', value: 'Включён', icon: Icons.turn_right_rounded, onTap: _noop),
  HomeTile(id: 'warp', title: 'WARP', value: 'Если сайты не открываются', icon: Icons.cloud_outlined, toggled: warp, onTap: onWarp ?? _noop),
];

void main() {
  setUpAll(_loadFonts);

  for (final phase in ConnectionPhase.values) {
    testWidgets('home ${phase.name} shows the chosen widgets', (tester) async {
      await _pump(
        tester,
        HomeScreen(
          data: PokrovSampleData.home(phase: phase, tiles: _tiles()),
          onToggle: _noop,
          onOpenStatus: _noop,
          onOpenAccess: _noop,
          onEditTiles: _noop,
        ),
      );
      expect(find.text('POKROV VPN'), findsOneWidget);
      expect(find.text('Маршрут'), findsOneWidget);
      expect(find.text('Изменить виджеты'), findsOneWidget);
      expect(find.text('Не получилось подключиться'), phase == ConnectionPhase.error ? findsOneWidget : findsNothing);
      expect(find.text('Защищено · Германия'), phase == ConnectionPhase.on ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('home shows the observed failure and the available action', (tester) async {
    var actions = 0;
    await _pump(tester, HomeScreen(
      data: const HomeViewData(phase: ConnectionPhase.error,
        errorTitle: 'Трафик заблокирован',
        errorMessage: 'Сервер ещё не подготовил подключение.', actionLabel: 'Отключить'),
      onToggle: () => actions++, onOpenStatus: _noop, onOpenAccess: _noop,
    ));
    expect(find.text('Сервер ещё не подготовил подключение.'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(WarnCard), matching: find.text('Отключить')));
    expect(actions, 1);
  });

  testWidgets('a switch widget flips from a tap and announces its state', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var flips = 0;
      await _pump(tester, HomeScreen(
        data: PokrovSampleData.home(phase: ConnectionPhase.off, tiles: _tiles(warp: true, onWarp: () => flips++)),
        onToggle: _noop, onOpenStatus: _noop, onOpenAccess: _noop,
      ));
      await tester.tap(find.text('WARP'));
      expect(flips, 1);
      final node = tester.getSemantics(find.byKey(const ValueKey('home-tile-warp')));
      expect(node.getSemanticsData().flagsCollection.isToggled, Tristate.isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('home stays readable at 200% text', (tester) async {
    await _pump(tester, Stack(children: [
      HomeScreen(
        data: PokrovSampleData.home(phase: ConnectionPhase.off, tiles: _tiles()),
        onToggle: _noop, onOpenStatus: _noop, onOpenAccess: _noop, onEditTiles: _noop,
      ),
      Align(alignment: Alignment.bottomCenter, child: PokrovTabBar(current: PokrovTab.protection, onSelect: (_) {})),
    ]), textScale: 2);
    expect(tester.takeException(), isNull);
    final label = find.descendant(of: find.byType(PokrovConnectButton), matching: find.text('Подключить'));
    expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines, isFalse,
      reason: 'the connect label must stay one word at 200% text');
    for (final tab in ['Защита', 'Доступ', 'Помощь', 'Настройки']) {
      expect(tester.renderObject<RenderParagraph>(find.text(tab)).didExceedMaxLines, isFalse, reason: '$tab must not be clipped');
    }
  });

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
        data: PokrovSampleData.home(phase: ConnectionPhase.off),
        onToggle: () => connects++, onOpenStatus: () => statuses++, onOpenAccess: _noop,
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
      expect(tester.getSize(find.bySemanticsLabel(RegExp('^Состояние защиты:'))).height, greaterThanOrEqualTo(48));

      await _pump(tester, HomeScreen(
        data: PokrovSampleData.home(phase: ConnectionPhase.off),
        onToggle: null, onOpenStatus: _noop, onOpenAccess: _noop,
      ));
      final disabled = tester.getSemantics(find.bySemanticsLabel('Включить защиту'));
      expect(disabled.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      await _pump(tester, PokrovConnectButton(phase: ConnectionPhase.error,
        label: 'Отключить', onPressed: () => connects++));
      final disconnect = tester.getSemantics(find.bySemanticsLabel('Отключить'));
      expect(find.bySemanticsLabel('Повторить подключение'), findsNothing);
      tester.binding.platformDispatcher.onSemanticsActionEvent!(SemanticsActionEvent(
        type: SemanticsAction.tap, nodeId: disconnect.id, viewId: tester.view.viewId,
      ));
      expect(connects, 2);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('segmented choices can be reached and activated by keyboard', (tester) async {
    final selected = <int>[];
    await _pump(tester, Center(child: SizedBox(width: 214, child: PokrovSegmented(
      labels: const ['Светлая', 'Тёмная'], index: 0, onChanged: selected.add,
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

  testWidgets('start, country and route pages with a way back', (tester) async {
    await _pump(tester, StartScreen(onStart: _noop, onHaveCode: _noop));
    expect(find.text('Начать бесплатно'), findsOneWidget);
    var back = 0;
    var manual = 0;
    await _pump(tester, LocationsScreen(data: const LocationsViewData(countries: PokrovSampleData.countries),
      onAuto: _noop, onSelect: (_) {}, onBack: () => back++, onSelectConnection: () => manual++));
    expect(find.text('Германия'), findsOneWidget);
    expect(find.text('38 мс'), findsOneWidget, reason: 'a measured delay is shown as measured');
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.tap(find.text('Соединение вручную'));
    expect((back, manual), (1, 1));
    await _pump(tester, RulesScreen(data: PokrovSampleData.rules(selected: 'all'), onSelect: (_) {}, onApply: _noop, onBack: () => back++));
    expect(find.text('Что идёт через POKROV'), findsOneWidget);
    expect(find.text('Применить'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    expect(back, 2);
  });

  testWidgets('access tab keeps every account action and stays usable at 200%', (tester) async {
    final opened = <String>[];
    Widget screen() => AccessScreen(
      data: PokrovSampleData.access, onRenew: () => opened.add('renew'),
      steps: PokrovSampleData.accessSteps, onStep: (i) => opened.add('step$i'),
      onDevices: () => opened.add('devices'), onAddDevice: () => opened.add('add'),
      onActivate: () => opened.add('code'), onAccount: () => opened.add('account'),
      onBonuses: () => opened.add('bonuses'), onTelegramProxy: () => opened.add('proxy'),
      onShare: () => opened.add('share'),
    );
    await _pump(tester, screen());
    for (final title in ['Продлить', 'Подпишись на канал', 'Устройства', 'Добавить устройство', 'Ввести код', 'Telegram и почта', 'Бонусы и друзья', 'Telegram-прокси', 'Поделиться приложением']) {
      final target = find.text(title);
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
    }
    expect(opened, ['renew', 'step0', 'devices', 'add', 'code', 'account', 'bonuses', 'proxy', 'share']);
    await _pump(tester, screen(), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('help tab leads to the check, the helper, a person and the report', (tester) async {
    final opened = <String>[];
    await _pump(tester, HelpScreen(
      phase: ConnectionPhase.error, onCheck: () => opened.add('check'), onTopic: opened.add,
      onAssistant: () => opened.add('assistant'), onHuman: () => opened.add('human'),
      onReport: () => opened.add('report'), onHistory: () => opened.add('history'), onFeedback: () => opened.add('idea'),
    ));
    for (final title in ['Проверить соединение', 'Медленно', 'Спросить помощника', 'Позвать человека', 'Отправить отчёт', 'История и скорость', 'Предложить идею']) {
      final target = find.text(title);
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
    }
    expect(opened, ['check', 'Медленно', 'assistant', 'human', 'report', 'history', 'idea']);
  });

  testWidgets('settings search finds expert entries and switches flip in place', (tester) async {
    final opened = <String>[];
    await _pump(tester, SettingsScreen(entries: [
      SettingsEntry(group: 'Подключение', title: 'WARP', hint: 'Запасной путь', icon: Icons.cloud_outlined, toggled: false, onTap: () => opened.add('warp')),
      SettingsEntry(group: 'Приложение', title: 'Тема', icon: Icons.palette_outlined, onTap: () => opened.add('theme')),
      SettingsEntry(group: pokrovExpertGroup, title: 'Доверенный Wi-Fi', hint: 'Пауза дома', keywords: 'wifi сеть', icon: Icons.wifi_rounded, onTap: () => opened.add('wifi')),
    ]));
    expect(find.textContaining('Если не знаешь, зачем это'), findsOneWidget);
    await tester.tap(find.text('WARP'));
    await tester.enterText(find.byKey(const ValueKey('settings-search')), 'wifi');
    await tester.pump();
    expect(find.text('Тема'), findsNothing);
    await tester.tap(find.text('Доверенный Wi-Fi'));
    await tester.enterText(find.byKey(const ValueKey('settings-search')), 'нет такого');
    await tester.pump();
    expect(find.textContaining('Ничего не нашли'), findsOneWidget);
    expect(opened, ['warp', 'wifi']);
  });

  testWidgets('display titles stay whole words at 200% text', (tester) async {
    await _pump(tester, SettingsScreen(entries: const []), textScale: 2);
    final title = tester.renderObject<RenderParagraph>(find.text('Настройки'));
    final lastLetter = title.getOffsetForCaret(const TextPosition(offset: 8), Rect.zero);
    expect(lastLetter.dy, lessThan(4), reason: 'Unbounded must not split «Настройки» across lines');
  });

  testWidgets('home widgets can be added, moved up, removed and reset', (tester) async {
    final changes = <List<String>>[];
    await _pump(tester, HomeTilesSheet(options: PokrovSampleData.tileOptions, selected: PokrovSampleData.defaultTiles,
      defaults: PokrovSampleData.defaultTiles, onChanged: changes.add));
    final add = find.bySemanticsLabel('Добавить: Устройства');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    expect(changes.last, [...PokrovSampleData.defaultTiles, 'devices']);
    await tester.tap(find.bySemanticsLabel('Выше: Устройства'));
    await tester.pump();
    expect(changes.last, ['country', 'route', 'bypass', 'devices', 'warp']);
    await tester.tap(find.bySemanticsLabel('Убрать: Страна'));
    await tester.pump();
    expect(changes.last.first, 'route');
    final reset = find.text('Вернуть как было');
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    expect(changes.last, PokrovSampleData.defaultTiles);
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

  testWidgets('tab bar always shows the four tabs', (tester) async {
    PokrovTab? picked;
    await _pump(tester, PokrovTabBar(current: PokrovTab.protection, onSelect: (tab) => picked = tab));
    for (final tab in ['Защита', 'Доступ', 'Помощь', 'Настройки']) {
      expect(find.text(tab), findsOneWidget);
    }
    await tester.tap(find.text('Помощь'));
    expect(picked, PokrovTab.help);
    expect(tester.getSize(find.byType(PokrovTabBar)).height, lessThan(140), reason: 'the bar must not cover the screen');
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
