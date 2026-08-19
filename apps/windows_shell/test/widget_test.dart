import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_windows_shell/main.dart' as windows_shell;

void main() {
  test('windows release metadata is stable rather than prerelease', () async {
    final runnerResource = File('windows/runner/Runner.rc');
    expect(await runnerResource.exists(), isTrue);

    final content = await runnerResource.readAsString();
    expect(content, contains('#else\n FILEFLAGS 0x0L'));
    expect(content, isNot(contains('VS_FF_PRERELEASE')));
  });

  test('windows minimum size keeps the compact drawer lane reachable', () {
    expect(windows_shell.pokrovWindowsMinimumSize, const Size(700, 640));
  });

  test('windows tray connection label reports actionable state', () {
    expect(
      windows_shell.pokrovWindowsTrayConnectionLabel(
        attached: false,
        connected: false,
        busy: false,
      ),
      'Подключение загружается',
    );
    expect(
      windows_shell.pokrovWindowsTrayConnectionLabel(
        attached: true,
        connected: false,
        busy: false,
      ),
      'Подключить VPN',
    );
    expect(
      windows_shell.pokrovWindowsTrayConnectionLabel(
        attached: true,
        connected: true,
        busy: false,
      ),
      'Отключить VPN',
    );
  });

  test('windows tray icon resolves beside the installed executable', () {
    expect(
      windows_shell.pokrovWindowsTrayIconPath(
        executablePath: r'C:\Program Files\POKROV\pokrov_windows.exe',
      ),
      r'C:\Program Files\POKROV\pokrov_tray.ico',
    );
  });

  const windowsTrayPrivateHelperBehaviorCoverage = ['_showWindow'];

  test(
    'windows tray show window restores minimized windows before focusing',
    () async {
      expect(windowsTrayPrivateHelperBehaviorCoverage, contains('_showWindow'));
      final calls = <String>[];

      await windows_shell.pokrovWindowsShowWindow(
        isMinimized: () async {
          calls.add('isMinimized');
          return true;
        },
        restore: () async {
          calls.add('restore');
        },
        show: () async {
          calls.add('show');
        },
        focus: () async {
          calls.add('focus');
        },
      );

      expect(calls, ['isMinimized', 'restore', 'show', 'focus']);
    },
  );

  test('windows tray show window skips restore when already visible', () async {
    final calls = <String>[];

    await windows_shell.pokrovWindowsShowWindow(
      isMinimized: () async {
        calls.add('isMinimized');
        return false;
      },
      restore: () async {
        calls.add('restore');
      },
      show: () async {
        calls.add('show');
      },
      focus: () async {
        calls.add('focus');
      },
    );

    expect(calls, ['isMinimized', 'show', 'focus']);
  });

  test('windows close hides to tray while prevent-close is active', () async {
    final calls = <String>[];

    await windows_shell.pokrovWindowsHandleClose(
      isPreventClose: () async {
        calls.add('isPreventClose');
        return true;
      },
      closeToTray: () async {
        calls.add('closeToTray');
        return true;
      },
      hide: () async {
        calls.add('hide');
      },
      destroyTray: () async {
        calls.add('destroyTray');
      },
      destroyWindow: () async {
        calls.add('destroyWindow');
      },
    );

    expect(calls, ['isPreventClose', 'closeToTray', 'hide']);
  });

  test('windows close exits when close-to-tray is disabled', () async {
    final calls = <String>[];

    await windows_shell.pokrovWindowsHandleClose(
      isPreventClose: () async {
        calls.add('isPreventClose');
        return true;
      },
      closeToTray: () async {
        calls.add('closeToTray');
        return false;
      },
      hide: () async {
        calls.add('hide');
      },
      destroyTray: () async {
        calls.add('destroyTray');
      },
      destroyWindow: () async {
        calls.add('destroyWindow');
      },
    );

    expect(
      calls,
      ['isPreventClose', 'closeToTray', 'destroyTray', 'destroyWindow'],
    );
  });

  test(
    'windows close leaves the window alone when prevent-close is off',
    () async {
      final calls = <String>[];

      await windows_shell.pokrovWindowsHandleClose(
        isPreventClose: () async {
          calls.add('isPreventClose');
          return false;
        },
        closeToTray: () async {
          calls.add('closeToTray');
          return true;
        },
        hide: () async {
          calls.add('hide');
        },
        destroyTray: () async {
          calls.add('destroyTray');
        },
        destroyWindow: () async {
          calls.add('destroyWindow');
        },
      );

      expect(calls, ['isPreventClose']);
    },
  );

  test('windows tray exit destroys tray before the native window', () async {
    final calls = <String>[];

    await windows_shell.pokrovWindowsExit(
      destroyTray: () async {
        calls.add('destroyTray');
      },
      destroyWindow: () async {
        calls.add('destroyWindow');
      },
    );

    expect(calls, ['destroyTray', 'destroyWindow']);
  });

  test('windows elevated continuation is explicit and exact', () {
    expect(windows_shell.pokrovWindowsShouldAutoConnect(['--connect']), isTrue);
    expect(
      windows_shell.pokrovWindowsShouldAutoConnect(['--connected']),
      isFalse,
    );
    expect(windows_shell.pokrovWindowsShouldAutoConnect([]), isFalse);
  });

  test('windows tunnel authorization stops when UAC relaunch is denied',
      () async {
    const channel = MethodChannel('space.pokrov/windows-shell');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'isElevated' => false,
        'relaunchElevated' => false,
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(
      await requestPokrovWindowsTunnelAuthorization(HostPlatform.windows),
      PokrovWindowsTunnelAuthorization.denied,
    );
    expect(calls, ['isElevated', 'relaunchElevated']);
  });

  test('windows elevation preflight does not trigger UAC', () async {
    const channel = MethodChannel('space.pokrov/windows-shell');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'isElevated';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(
      await readPokrovWindowsProcessElevated(HostPlatform.windows),
      isTrue,
    );
    expect(calls, ['isElevated']);
  });

  testWidgets('windows shell boots the shared protection surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Защита'), findsWidgets);
    expect(find.text('POKROV'), findsWidgets);
    expect(find.byKey(const ValueKey('desktop-shell')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-sidebar-expanded')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pokrov-brand-mark')), findsWidgets);
    expect(find.text('Ваш основной регион'), findsNothing);
    expect(find.text('Новости и уведомления'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);

    expect(find.text('Prime runtime'), findsNothing);
    expect(find.text('Stage local smoke profile'), findsNothing);
    expect(find.text('Connect now'), findsNothing);
    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    expect(connectAction, findsOneWidget);
    expect(
      find.descendant(
        of: connectAction,
        matching: find.text('Пока недоступно'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-warp-tile')), findsOneWidget);
    expect(find.text('Дополнительная защита'), findsOneWidget);
  });
}
