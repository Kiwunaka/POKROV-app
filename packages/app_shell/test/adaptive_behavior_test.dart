import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/src/design_system/design_system.dart';

void main() {
  test('scroll physics follow the host platform', () {
    expect(
      pokrovScrollPhysicsFor(TargetPlatform.android),
      isA<ClampingScrollPhysics>(),
    );
    expect(
      pokrovScrollPhysicsFor(TargetPlatform.windows),
      isA<ClampingScrollPhysics>(),
    );
    expect(
      pokrovScrollPhysicsFor(TargetPlatform.iOS),
      isA<BouncingScrollPhysics>(),
    );
    expect(
      pokrovScrollPhysicsFor(TargetPlatform.macOS),
      isA<BouncingScrollPhysics>(),
    );
  });

  test('route transitions preserve platform conventions', () {
    final builders = pokrovAdaptivePageTransitionsTheme().builders;
    expect(builders[TargetPlatform.android], isA<ZoomPageTransitionsBuilder>());
    expect(
      builders[TargetPlatform.windows],
      isA<FadeUpwardsPageTransitionsBuilder>(),
    );
    expect(
      builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });

  testWidgets('switch uses Material on Windows and Cupertino on Apple hosts',
      (tester) async {
    Widget app(TargetPlatform platform) {
      return MaterialApp(
        key: ValueKey<TargetPlatform>(platform),
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: PokrovSwitch(value: true, onChanged: (_) {}),
        ),
      );
    }

    await tester.pumpWidget(app(TargetPlatform.windows));
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byType(CupertinoSwitch), findsNothing);

    await tester.pumpWidget(app(TargetPlatform.iOS));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoSwitch), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });
}
