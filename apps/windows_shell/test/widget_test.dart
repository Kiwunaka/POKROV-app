import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  testWidgets('windows shell boots the shared protection surface',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Подключение'), findsWidgets);
    expect(find.text('POKROV'), findsOneWidget);

    final runtimeStatus = find.text('Состояние подключения');
    await tester.dragUntilVisible(
      runtimeStatus,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    expect(runtimeStatus, findsOneWidget);
    expect(find.text('Проверить еще раз'), findsOneWidget);
    expect(find.text('Правила'), findsOneWidget);
  });
}
