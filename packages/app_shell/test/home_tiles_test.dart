import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: _Client(),
      firstLaunchStore: _CompletedFirstLaunch(),
      clientExperienceStore: _MemoryExperience(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('route widget opens the route page for everyone and back returns home', (tester) async {
    await boot(tester);
    for (final title in ['Страна', 'Маршрут', 'Обход блокировок', 'WARP']) {
      expect(find.text(title), findsOneWidget, reason: '$title is a default widget');
    }
    expect(find.text('Просто'), findsNothing);
    await tester.tap(find.text('Маршрут'));
    await settle(tester);
    expect(find.text('Что идёт через POKROV'), findsOneWidget);
    expect(find.text('Россия напрямую'), findsWidgets);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await settle(tester);
    expect(find.text('Изменить виджеты'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings search reaches expert settings', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Настройки').last);
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('settings-search')), 'wifi');
    await settle(tester);
    expect(find.text('Тема'), findsNothing);
    await tester.tap(find.text('Доверенный Wi-Fi'));
    await settle(tester);
    expect(find.byKey(const ValueKey('rules-advanced-open')), findsOneWidget,
      reason: 'an expert entry opens «Для опытных» already expanded');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a widget added in the picker appears on the main screen', (tester) async {
    await boot(tester);
    expect(find.byKey(const ValueKey('home-tile-help')), findsNothing);
    await tester.tap(find.text('Изменить виджеты'));
    await settle(tester);
    final add = find.bySemanticsLabel('Добавить: Помощь');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await settle(tester);
    Navigator.of(tester.element(find.byKey(const ValueKey('home-tiles-sheet')))).pop();
    await settle(tester);
    expect(find.byKey(const ValueKey('home-tile-help')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-tile-help')));
    await settle(tester);
    expect(find.text('Позвать человека'), findsOneWidget, reason: 'the Help widget opens the Help tab');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Client implements ManagedProfileBootstrapper, AppFirstClientDataService {
  @override
  Future<ClientNotificationInbox> fetchClientNotifications({required HostPlatform hostPlatform, String after = ''}) async =>
      const ClientNotificationInbox(items: [], nextCursor: '', unreadCount: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _CompletedFirstLaunch implements PokrovFirstLaunchStore {
  @override
  Future<bool> isCompleted() async => true;
  @override
  Future<void> markCompleted() async {}
}

class _MemoryExperience implements PokrovClientExperienceStore {
  @override
  Future<PokrovClientExperienceState> read() async => const PokrovClientExperienceState.empty();
  @override
  Future<void> write(PokrovClientExperienceState state) async {}
}
