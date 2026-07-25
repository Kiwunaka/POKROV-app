import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  testWidgets('macos shell boots the shared protection surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.macos),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Защита'), findsWidgets);
    expect(find.text('POKROV'), findsWidgets);
    expect(find.byKey(const ValueKey('desktop-shell')), findsOneWidget);
  });
}
