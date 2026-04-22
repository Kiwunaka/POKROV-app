import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  testWidgets('windows shell boots the shared protection surface', (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protection'), findsWidgets);
    expect(find.text('POKROV'), findsOneWidget);

    final initializeRuntime = find.text('Prime runtime');
    await tester.dragUntilVisible(
      initializeRuntime,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    expect(initializeRuntime, findsOneWidget);
    expect(find.text('Stage local smoke profile'), findsOneWidget);
    expect(find.text('Connect now'), findsOneWidget);
  });
}
