import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  testWidgets('windows shell boots the shared protection surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Защита'), findsWidgets);
    expect(find.text('POKROV'), findsWidgets);
    expect(find.byKey(const ValueKey('desktop-shell')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-sidebar-expanded')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pokrov-brand-mark')), findsWidgets);
    expect(find.text('Ваш основной регион'), findsNothing);
    expect(find.text('Новости и уведомления'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);

    expect(find.text('Prime runtime'), findsNothing);
    expect(find.text('Stage local smoke profile'), findsNothing);
    expect(find.text('Connect now'), findsNothing);
    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    expect(connectAction, findsOneWidget);
    expect(find.text('Пока недоступно'), findsOneWidget);
  });
}
