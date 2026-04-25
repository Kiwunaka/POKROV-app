import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  testWidgets('android shell boots the shared protection surface',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protection'), findsWidgets);
    expect(find.text('POKROV'), findsOneWidget);
  });

  testWidgets('android shell keeps raw runtime diagnostics out of first layer',
      (
    tester,
  ) async {
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
  });
}
