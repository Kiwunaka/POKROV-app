import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  testWidgets('android shell boots the shared protection surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Защита'), findsWidgets);
    expect(find.text('POKROV'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('pokrov-brand-mark')), findsWidgets);
    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-location-chip')), findsOneWidget);
    expect(find.text('Ваш основной регион'), findsNothing);
    expect(find.text('Новости и уведомления'), findsNothing);
  });

  testWidgets(
    'android shell keeps raw runtime diagnostics out of first layer',
    (tester) async {
      await tester.pumpWidget(
        PokrovSeedApp(
          appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Runtime health'), findsNothing);
      expect(find.text('Prime runtime'), findsNothing);
      expect(find.text('Stage local smoke profile'), findsNothing);
      expect(find.text('Connect now'), findsNothing);
    },
  );
}
