import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'acquisition_links.dart';

/// Tray-first desktop sizing: the 700 px minimum keeps the canonical compact
/// drawer lane reachable; the window opens centered because geometry is not
/// persisted yet.
const Size _pokrovWindowSize = Size(1280, 720);
const Size pokrovWindowsMinimumSize = Size(700, 640);

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final startHidden = pokrovWindowsShouldStartHidden(arguments);
  final shellController = PokrovShellController();
  final acquisitionLinks = PokrovWindowsAcquisitionLinks();
  final initialAcquisitionUri = await acquisitionLinks.start();
  final bootstrapper = AppFirstRuntimeBootstrapper();
  final observability = await PokrovClientObservability.start(
    hostPlatform: HostPlatform.windows,
    releaseHealthService: bootstrapper,
  );
  installPokrovCrashHandlers(observability);
  await _PokrovWindowsTray.install(shellController);
  if (Platform.isWindows) {
    // Tray-first lifecycle: the ✕ button hides to tray, the VPN keeps
    // running, and only the tray «Выход» actually quits.
    await windowManager.setPreventClose(true);
    const options = WindowOptions(
      size: _pokrovWindowSize,
      minimumSize: pokrovWindowsMinimumSize,
      center: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (startHidden) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }
  runApp(
    PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      bootstrapper: bootstrapper,
      observability: observability,
      shellController: shellController,
      initialAcquisitionUri: initialAcquisitionUri,
      acquisitionUriStream: acquisitionLinks.stream,
      windowsShellPreferencesReader: () =>
          readPokrovWindowsShellPreferences(HostPlatform.windows),
      windowsShellPreferencesUpdater: (preferences) =>
          updatePokrovWindowsShellPreferences(
        HostPlatform.windows,
        preferences,
      ),
    ),
  );
}

@visibleForTesting
bool pokrovWindowsShouldStartHidden(Iterable<String> arguments) {
  var startup = false;
  var acquisition = false;
  for (final argument in arguments) {
    final normalized = argument.trim();
    startup = startup || normalized == '--startup';
    acquisition =
        acquisition || normalized.startsWith('pokrov://acquisition/continue?');
  }
  return startup && !acquisition;
}

@visibleForTesting
String pokrovWindowsTrayIconPath({String? executablePath}) {
  final executable = File(executablePath ?? Platform.resolvedExecutable);
  return '${executable.parent.path}${Platform.pathSeparator}pokrov_tray.ico';
}

@visibleForTesting
Future<void> pokrovWindowsShowWindow({
  required Future<bool> Function() isMinimized,
  required Future<void> Function() restore,
  required Future<void> Function() show,
  required Future<void> Function() focus,
}) async {
  if (await isMinimized()) {
    await restore();
  }
  await show();
  await focus();
}

/// Close button semantics follow the user's Windows preference: keep the VPN
/// in the tray or perform an explicit application exit.
@visibleForTesting
Future<void> pokrovWindowsHandleClose({
  required Future<bool> Function() isPreventClose,
  required Future<bool> Function() closeToTray,
  required Future<void> Function() hide,
  required Future<void> Function() destroyTray,
  required Future<void> Function() destroyWindow,
}) async {
  if (!await isPreventClose()) {
    return;
  }
  if (await closeToTray()) {
    await hide();
    return;
  }
  await pokrovWindowsExit(
    destroyTray: destroyTray,
    destroyWindow: destroyWindow,
  );
}

/// Dispose tray state before requesting native window teardown. This orders
/// shell shutdown deterministically; exact-artifact runtime and proxy
/// restoration remains a Windows release check.
@visibleForTesting
Future<void> pokrovWindowsExit({
  required Future<void> Function() destroyTray,
  required Future<void> Function() destroyWindow,
}) async {
  try {
    await destroyTray();
  } finally {
    await destroyWindow();
  }
}

@visibleForTesting
String pokrovWindowsTrayConnectionLabel({
  required bool attached,
  required bool connected,
  required bool busy,
}) {
  if (!attached) {
    return 'Подключение загружается';
  }
  if (busy) {
    return connected ? 'Отключение…' : 'Подключение…';
  }
  return connected ? 'Отключить VPN' : 'Подключить VPN';
}

final class _PokrovWindowsTray with TrayListener, WindowListener {
  _PokrovWindowsTray._();

  static final _PokrovWindowsTray _instance = _PokrovWindowsTray._();
  PokrovShellController? _shellController;
  Future<void> _menuUpdate = Future<void>.value();

  static Future<void> install(PokrovShellController shellController) async {
    if (!Platform.isWindows) {
      return;
    }
    _instance._shellController = shellController;
    shellController.addListener(_instance._scheduleMenuUpdate);
    trayManager.addListener(_instance);
    windowManager.addListener(_instance);
    await trayManager.setIcon(pokrovWindowsTrayIconPath());
    await _instance._applyControllerState();
  }

  void _scheduleMenuUpdate() {
    _menuUpdate = _menuUpdate.then((_) => _applyControllerState()).catchError(
      (_) {
        // A transient native tray failure must not break later state updates.
      },
    );
  }

  Future<void> _applyControllerState() async {
    final controller = _shellController;
    final attached = controller?.attached ?? false;
    final connected = controller?.isConnected ?? false;
    final busy = controller?.isBusy ?? false;
    await trayManager.setToolTip(
      connected ? 'POKROV подключен' : 'POKROV отключен',
    );
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show_window', label: 'Открыть POKROV'),
          MenuItem(
            key: 'toggle_connection',
            label: pokrovWindowsTrayConnectionLabel(
              attached: attached,
              connected: connected,
              busy: busy,
            ),
            disabled: controller?.canToggle != true,
          ),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: 'Выход'),
        ],
      ),
    );
  }

  Future<void> _toggleConnection() async {
    await _shellController?.toggleConnection();
    await _applyControllerState();
  }

  Future<void> _destroyTray() async {
    _shellController?.removeListener(_scheduleMenuUpdate);
    _shellController = null;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await trayManager.destroy();
  }

  Future<void> _showWindow() async {
    await pokrovWindowsShowWindow(
      isMinimized: windowManager.isMinimized,
      restore: windowManager.restore,
      show: () => windowManager.show(),
      focus: windowManager.focus,
    );
  }

  @override
  void onWindowClose() {
    unawaited(
      pokrovWindowsHandleClose(
        isPreventClose: windowManager.isPreventClose,
        closeToTray: () async {
          final preferences = await readPokrovWindowsShellPreferences(
            HostPlatform.windows,
          );
          return preferences.closeToTray;
        },
        hide: windowManager.hide,
        destroyTray: _destroyTray,
        destroyWindow: windowManager.destroy,
      ),
    );
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        unawaited(_showWindow());
        break;
      case 'toggle_connection':
        unawaited(_toggleConnection());
        break;
      case 'exit_app':
        unawaited(
          pokrovWindowsExit(
            destroyTray: _destroyTray,
            destroyWindow: windowManager.destroy,
          ),
        );
        break;
    }
  }
}
