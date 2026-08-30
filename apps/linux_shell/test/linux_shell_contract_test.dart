import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
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
