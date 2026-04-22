import 'dart:io';

import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';

Future<void> main() async {
  final outputFile = File(
    'C:/Users/kiwun/Documents/ai/VPN/.tmp/generated_live_android_runtime.json',
  );
  final scratchDirectory = await Directory.systemTemp.createTemp(
    'pokrov-live-android-runtime-',
  );
  final bootstrapper = AppFirstRuntimeBootstrapper(
    supportDirectoryResolver: () async => scratchDirectory,
  );
  final payload = await bootstrapper.resolveManagedProfile(
    hostPlatform: HostPlatform.android,
    routeMode: RouteMode.fullTunnel,
  );
  await outputFile.writeAsString(payload.configPayload);
  stdout.writeln(outputFile.path);
}
