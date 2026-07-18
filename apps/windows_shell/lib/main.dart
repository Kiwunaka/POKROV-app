import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Tray-first desktop sizing: content is designed for >= 980x640 and the
/// window opens centered because no geometry persistence exists yet.
const Size _pokrovWindowSize = Size(1280, 720);
const Size _pokrovMinWindowSize = Size(980, 640);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await _PokrovWindowsTray.install();
  if (Platform.isWindows) {
    // Tray-first lifecycle: the ✕ button hides to tray, the VPN keeps
    // running, and only the tray «Выход» actually quits.
    await windowManager.setPreventClose(true);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: _pokrovWindowSize,
        minimumSize: _pokrovMinWindowSize,
        center: true,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  runApp(
    PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
    ),
  );
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

/// Close button semantics for the tray-first shell: with prevent-close
/// active the window hides to tray instead of quitting.
@visibleForTesting
Future<void> pokrovWindowsHandleClose({
  required Future<bool> Function() isPreventClose,
  required Future<void> Function() hide,
}) async {
  if (await isPreventClose()) {
    await hide();
  }
}

final class _PokrovWindowsTray with TrayListener, WindowListener {
  _PokrovWindowsTray._();

  static final _PokrovWindowsTray _instance = _PokrovWindowsTray._();

  static Future<void> install() async {
    if (!Platform.isWindows) {
      return;
    }
    trayManager.addListener(_instance);
    windowManager.addListener(_instance);
    await trayManager.setIcon('windows/runner/resources/app_icon.ico');
    // The tooltip doubles as the "closed to tray" hint: hovering the icon
    // explains that POKROV keeps running in the background.
    await trayManager.setToolTip('POKROV работает в фоне');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Открыть POKROV',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Выход',
          ),
        ],
      ),
    );
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
        hide: windowManager.hide,
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
      case 'exit_app':
        unawaited(trayManager.destroy());
        // destroy() bypasses prevent-close, so the runner's quit-on-close
        // path runs and the process exits cleanly.
        unawaited(windowManager.destroy());
        break;
    }
  }
}
