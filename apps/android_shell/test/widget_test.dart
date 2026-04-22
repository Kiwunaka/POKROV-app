import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  testWidgets('android shell boots the shared protection surface', (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protection'), findsWidgets);
    expect(find.text('POKROV'), findsOneWidget);
  });

  testWidgets('android shell exposes route-mode and runtime diagnostics lane', (
    tester,
  ) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Runtime health'),
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Runtime health'), findsOneWidget);
    expect(find.text('Refresh status'), findsOneWidget);
    expect(find.text('Prime runtime'), findsOneWidget);
    expect(find.text('Stage local smoke profile'), findsOneWidget);
    expect(find.text('Connect now'), findsOneWidget);
  });
}
