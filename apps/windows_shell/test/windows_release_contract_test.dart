import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('windows release contract requires POKROV Core 1.0.3', () async {
    final releaseConfig = File('../../config/windows-release.seed.json');
    final runtimeConfig = File('../../config/runtime-artifacts.seed.json');

    expect(await releaseConfig.exists(), isTrue);
    expect(await runtimeConfig.exists(), isTrue);

    final releaseJson =
        jsonDecode(await releaseConfig.readAsString()) as Map<String, dynamic>;
    final runtimeJson =
        jsonDecode(await runtimeConfig.readAsString()) as Map<String, dynamic>;

    final requiredFiles =
        (releaseJson['required_files'] as List<dynamic>).cast<String>();
    expect(releaseJson['channel'], 'outside_store_stable');
    expect(releaseJson['binary_name'], 'pokrov_windows.exe');
    expect(releaseJson['public_approved'], isTrue);
    expect(releaseJson['artifact_status'], 'unsigned_direct');
    expect(requiredFiles, contains('pokrov-core.dll'));
    expect(requiredFiles, contains('libcronet.dll'));
    expect(requiredFiles, contains('pokrov_tray.ico'));
    expect(requiredFiles, contains('pokrov_windows.exe'));
    expect(requiredFiles, isNot(contains('pokrov_windows_seed.exe')));

    final signing = releaseJson['signing'] as Map<String, dynamic>;
    expect(signing['status'], 'unsigned_direct_warning');
    expect(
      (signing['user_warning'] as String).toLowerCase(),
      contains('smartscreen'),
    );

    final runtime = releaseJson['runtime'] as Map<String, dynamic>;
    expect(runtime.containsKey('helper_binary'), isFalse);
    expect(runtime['core_binary'], 'pokrov-core.dll');
    expect(runtime['release_tag'], 'v1.0.3');
    expect(runtime['desktop_abi'], 2);
    expect(
      (runtime['runtime_dependencies'] as List<dynamic>).cast<String>(),
      contains('libcronet.dll'),
    );

    final core = runtimeJson['core'] as Map<String, dynamic>;
    final assets = core['assets'] as Map<String, dynamic>;
    final windows = assets['windows'] as Map<String, dynamic>;
    expect(windows.containsKey('helper'), isFalse);
    expect(core['release_tag'], 'v1.0.3');
    expect(core['activation_state'], 'active');
    expect((core['desktop_abi'] as Map<String, dynamic>)['version'], 2);
    expect(windows['sync_policy'], 'pokrov_release');
    expect(
      (windows['runtime_dependencies'] as List<dynamic>).cast<String>(),
      contains('libcronet.dll'),
    );
  });

  test('windows setup registers bounded POKROV continuation protocol',
      () async {
    final buildScript = File('../../scripts/build-windows-release.ps1');
    final runner = File('windows/runner/main.cpp');
    final window = File('windows/runner/flutter_window.cpp');
    final cmake = File('windows/CMakeLists.txt');
    final trayIcon = File('windows/runner/resources/pokrov_tray.ico');
    final scriptContent = await buildScript.readAsString();
    final runnerContent = await runner.readAsString();
    final windowContent = await window.readAsString();
    final cmakeContent = await cmake.readAsString();

    expect(scriptContent, contains('Inno Setup 6'));
    expect(scriptContent, contains('DisableDirPage=no'));
    expect(scriptContent, contains('Languages\\Russian.isl'));
    expect(scriptContent, contains('#pragma code_page 65001'));
    expect(scriptContent, contains('Write-Utf8BomFile -Path \$issPath'));
    expect(scriptContent, contains('Name: "desktopicon"'));
    expect(scriptContent, contains('Name: "autostart"'));
    expect(scriptContent, contains('Software\\Classes\\pokrov'));
    expect(scriptContent, contains('ValueName: "URL Protocol"'));
    expect(scriptContent, contains('shell\\open\\command'));
    expect(
      scriptContent,
      isNot(contains('Class=IEXPRESS')),
    );
    expect(runnerContent, contains('pokrov://acquisition/continue?'));
    expect(runnerContent, contains('SendMessageTimeoutW'));
    expect(windowContent, contains('case WM_COPYDATA'));
    expect(
      windowContent,
      contains('space.pokrov/acquisition-links'),
    );
    expect(await trayIcon.exists(), isTrue);
    expect(await trayIcon.length(), greaterThan(1024));
    expect(cmakeContent, contains('pokrov_tray.ico'));
  });

  test('windows shell gates TUN elevation and owns user preferences', () async {
    final window = File('windows/runner/flutter_window.cpp');
    final sharedShell =
        File('../../packages/app_shell/lib/src/shell/seed_shell.dart');
    final content = await window.readAsString();
    final sharedContent = await sharedShell.readAsString();

    expect(content, contains('space.pokrov/windows-shell'));
    expect(content, contains('TokenElevation'));
    expect(content, contains('ShellExecuteW'));
    expect(content, contains('L"--connect"'));
    expect(content, contains('CloseToTray'));
    expect(content, contains('CurrentVersion\\\\Run'));
    final authorizationIndex = sharedContent.indexOf(
      '!await _authorizeWindowsTunnelConnect()',
    );
    final busyIndex = sharedContent.indexOf(
      '_runtimeBusy = true;',
      authorizationIndex,
    );
    final coreConnectIndex = sharedContent.indexOf(
      '_runtimeEngine.connect',
      authorizationIndex,
    );
    expect(authorizationIndex, greaterThanOrEqualTo(0));
    expect(busyIndex, greaterThan(authorizationIndex));
    expect(coreConnectIndex, greaterThan(busyIndex));
  });
}
