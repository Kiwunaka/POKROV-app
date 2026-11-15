import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

import 'acquisition_links.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Modern Android canvas: draw behind the status and gesture bars. The
  // shell root annotates transparent, brightness-matched system icons and
  // its SafeArea keeps content clear of the gesture area.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Run animations at the panel's native refresh rate (90/120Hz) instead of
  // the 60Hz default some Android vendors pin Flutter to. Best-effort only.
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (_) {
    // Unsupported device or emulator - the default mode is fine.
  }
  final bootstrapper = AppFirstRuntimeBootstrapper();
  if (pokrovPrivateClient) {
    await bootstrapper.seedProvisionedSession(
      hostPlatform: HostPlatform.android,
      installId: const String.fromEnvironment('POKROV_PRIVATE_INSTALL_ID'),
      accountId: const String.fromEnvironment('POKROV_PRIVATE_ACCOUNT_ID'),
      credentials: const AppFirstSessionCredentials(
        accessToken: String.fromEnvironment('POKROV_PRIVATE_ACCESS_TOKEN'),
        refreshToken: String.fromEnvironment('POKROV_PRIVATE_REFRESH_TOKEN'),
      ),
    );
  }
  final observability = await PokrovClientObservability.start(
    hostPlatform: HostPlatform.android,
    releaseHealthService: bootstrapper,
  );
  installPokrovCrashHandlers(observability);
  final acquisitionLinks = PokrovAndroidAcquisitionLinks();
  final initialAcquisitionUri = pokrovPrivateClient ? null : await acquisitionLinks.start();
  runApp(
    PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: bootstrapper,
      observability: observability,
      initialAcquisitionUri: initialAcquisitionUri,
      acquisitionUriStream: acquisitionLinks.stream,
    ),
  );
}
