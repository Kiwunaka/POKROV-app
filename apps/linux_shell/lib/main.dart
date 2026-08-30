import 'package:flutter/widgets.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrapper = AppFirstRuntimeBootstrapper();
  final observability = await PokrovClientObservability.start(
    hostPlatform: HostPlatform.linux,
    releaseHealthService: bootstrapper,
  );
  installPokrovCrashHandlers(observability);
  runApp(
    PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.linux),
      bootstrapper: bootstrapper,
      observability: observability,
    ),
  );
}
