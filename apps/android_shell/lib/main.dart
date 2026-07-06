import 'package:flutter/widgets.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Run animations at the panel's native refresh rate (90/120Hz) instead of
  // the 60Hz default some Android vendors pin Flutter to. Best-effort only.
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (_) {
    // Unsupported device or emulator - the default mode is fine.
  }
  runApp(
    PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
    ),
  );
}
