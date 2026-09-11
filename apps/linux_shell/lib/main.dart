import 'package:flutter/widgets.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrapper = AppFirstRuntimeBootstrapper();
  runApp(
    PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.linux),
      bootstrapper: bootstrapper,
    ),
  );
}
