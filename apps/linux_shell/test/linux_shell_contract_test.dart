import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_linux_shell/main.dart' as shell;

void main() {
  testWidgets('Linux entrypoint reaches its first frame', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    shell.main();
    await tester.pump();

    expect(find.byType(PokrovSeedApp), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Linux beta uses the non-root system-service boundary', () {
    final context = buildSeedAppContext(hostPlatform: HostPlatform.linux);

    expect(context.hostPlatform, HostPlatform.linux);
    expect(context.bootstrapContract.requiredPermissions, hasLength(1));
    expect(
      context.bootstrapContract.requiredPermissions.single.name,
      'systemServiceAuthorization',
    );
    expect(context.bootstrapContract.supportsSelectedAppsMode, isFalse);
    expect(context.runtimeProfile.supportedRouteModes, <RouteMode>[
      RouteMode.allExceptRu,
      RouteMode.fullTunnel,
    ]);
  });
}
