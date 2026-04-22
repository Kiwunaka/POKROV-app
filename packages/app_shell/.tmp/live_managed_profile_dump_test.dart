import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  test('dump live managed Android runtime config', () async {
    final outputFile = File(
      'C:/Users/kiwun/Documents/ai/VPN/.tmp/live_managed_android_runtime_from_code.json',
    );
    final supportDir = await Directory.systemTemp.createTemp(
      'pokrov-live-bootstrap-',
    );
    addTearDown(() async {
      if (await supportDir.exists()) {
        await supportDir.delete(recursive: true);
      }
    });

    final bootstrapper = AppFirstRuntimeBootstrapper(
      supportDirectoryResolver: () async => supportDir,
    );
    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    await outputFile.writeAsString(payload.configPayload);
    print('WROTE:${outputFile.path}');
  });
}
