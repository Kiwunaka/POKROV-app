import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

class _FakeDesktopBindings implements DesktopRuntimeBindings {
  _FakeDesktopBindings({
    this.setupResult = '',
    this.parseResult = '',
    this.changeOptionsResult = '',
    this.startResult = '',
    this.stopResult = '',
  });

  int setupCalls = 0;
  int parseCalls = 0;
  int changeOptionsCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  String? lastOptionsJson;
  final String setupResult;
  final String parseResult;
  final String changeOptionsResult;
  final String startResult;
  final String stopResult;

  @override
  String setup({
    required String baseDir,
    required String workingDir,
    required String tempDir,
    required int statusPort,
    required bool debug,
  }) {
    setupCalls += 1;
    return setupResult;
  }

  @override
  String parse({
    required String outputPath,
    required String tempPath,
    required bool debug,
  }) {
    parseCalls += 1;
    return parseResult;
  }

  @override
  String changeOptions({
    required String configJson,
  }) {
    changeOptionsCalls += 1;
    lastOptionsJson = configJson;
    return changeOptionsResult;
  }

  @override
  String start({
    required String configPath,
    required bool disableMemoryLimit,
  }) {
    startCalls += 1;
    return startResult;
  }

  @override
  String stop() {
    stopCalls += 1;
    return stopResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mobile lane reports artifact-missing without a synced core asset',
      () async {
    final engine = createRuntimeEngine(
      hostPlatform: HostPlatform.android,
      assetRootOverride: Directory.systemTemp.path,
    );

    final snapshot = await engine.snapshot();

    expect(snapshot.hostPlatform, HostPlatform.android);
    expect(snapshot.lane, RuntimeLane.mobileArtifact);
    expect(snapshot.phase, RuntimePhase.artifactMissing);
    expect(snapshot.supportsLiveConnect, isFalse);
  });

  test('mobile lane reports artifact-ready without a native host bridge',
      () async {
    final root =
        await Directory.systemTemp.createTemp('pokrov-runtime-mobile-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\android')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.aar').writeAsStringSync('stub');

    final engine = createRuntimeEngine(
      hostPlatform: HostPlatform.android,
      assetRootOverride: root.path,
    );

    final snapshot = await engine.snapshot();

    expect(snapshot.phase, RuntimePhase.artifactReady);
    expect(snapshot.supportsLiveConnect, isFalse);
    expect(snapshot.canInitialize, isFalse);
    expect(snapshot.coreBinaryPath, contains('libcore.aar'));
    expect(snapshot.message, contains('Модуль подключения найден'));
    expect(snapshot.message, isNot(contains('готовится')));
    expect(snapshot.message, isNot(contains('Скоро')));
  });

  test('mobile lane uses a native host bridge to initialize and stage profiles',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    String? stagedConfigPath;
    Map<Object?, Object?>? stagedArguments;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'artifactReady',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Host bridge ready.',
          };
        case 'runtimeEngine.initialize':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime bootstrap completed on the host bridge.',
          };
        case 'runtimeEngine.stageManagedProfile':
          final arguments = Map<Object?, Object?>.from(call.arguments as Map);
          stagedArguments = arguments;
          stagedConfigPath = '/host/runtime/${arguments['profileName']}.json';
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': stagedConfigPath,
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Managed profile staged on the host bridge.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final engine = createRuntimeEngine(hostPlatform: HostPlatform.android);

    final initialized = await engine.initialize();
    final staged = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'android-seed',
        configPayload: '{"outbounds":[]}',
        warpPolicy: WarpRuntimePolicy(
          enabled: true,
          runtimeReady: true,
          userConsented: true,
          state: 'consented',
          source: 'client_local',
          id: 'android-warp',
        ),
      ),
    );

    expect(initialized.phase, RuntimePhase.initialized);
    expect(initialized.supportsLiveConnect, isTrue);
    expect(staged.phase, RuntimePhase.configStaged);
    expect(staged.stagedConfigPath, stagedConfigPath);
    expect(staged.message, contains('Managed profile staged'));
    final optionsJson = stagedArguments?['runtimeOptionsJson'] as String?;
    expect(optionsJson, isNotNull);
    final options = jsonDecode(optionsJson!) as Map<String, dynamic>;
    final warp = options['warp'] as Map<String, dynamic>;
    expect(options['allow-connection-from-lan'], isFalse);
    expect(options['enable-clash-api'], isFalse);
    expect(options['mixed-port'], 22341);
    expect(options['clash-api-port'], 26756);
    expect(warp['enable'], isTrue);
    expect(warp['id'], 'android-warp');
    expect(warp['mode'], 'proxy_over_warp');
  });

  test('mobile lane forwards materialized runtime configs without re-parsing',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    Map<Object?, Object?>? stagedArguments;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.stageManagedProfile':
          stagedArguments = Map<Object?, Object?>.from(call.arguments as Map);
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/materialized.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged on the host bridge.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final engine = createRuntimeEngine(hostPlatform: HostPlatform.android);

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'materialized',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"direct","tag":"direct"}],"route":{"final":"direct"}}',
        materializedForRuntime: true,
      ),
    );

    expect(stagedArguments?['materializedForRuntime'], isTrue);
    expect(stagedArguments?['runtimeOptionsJson'], isA<String>());
  });

  test('mobile lane surfaces degraded host diagnostics from the bridge',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime service is running.',
            'hostDiagnostics': <String, Object?>{
              'health': 'degraded',
              'dnsStatus': 'degraded',
              'uplinkStatus': 'healthy',
              'summary': 'DNS degraded on the current uplink.',
            },
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final engine = createRuntimeEngine(hostPlatform: HostPlatform.android);
    final snapshot = await engine.snapshot();

    expect(snapshot.phase, RuntimePhase.running);
    expect(snapshot.hostHealth, RuntimeHostHealth.degraded);
    expect(snapshot.dnsState, RuntimeDiagnosticState.degraded);
    expect(snapshot.uplinkState, RuntimeDiagnosticState.healthy);
    expect(snapshot.hasDegradedHostDiagnostics, isTrue);
    expect(snapshot.isCleanlyHealthy, isFalse);
    expect(snapshot.phaseLabel, 'Подключено с предупреждением');
    expect(snapshot.diagnosticsLabel, 'DNS degraded on the current uplink.');
  });

  test('mobile lane derives Android diagnostics from top-level host fields',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android tun established.',
            'default_network_interface': 'wlan0',
            'default_network_index': 42,
            'dns_ready': true,
            'ipv4_route_count': 3,
            'ipv6_route_count': 1,
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final engine = createRuntimeEngine(hostPlatform: HostPlatform.android);
    final snapshot = await engine.snapshot();

    expect(snapshot.phase, RuntimePhase.running);
    expect(snapshot.hostHealth, RuntimeHostHealth.healthy);
    expect(snapshot.dnsState, RuntimeDiagnosticState.healthy);
    expect(snapshot.uplinkState, RuntimeDiagnosticState.healthy);
    expect(snapshot.defaultNetworkInterface, 'wlan0');
    expect(snapshot.defaultNetworkIndex, 42);
    expect(snapshot.dnsReady, isTrue);
    expect(snapshot.ipv4RouteCount, 3);
    expect(snapshot.ipv6RouteCount, 1);
    expect(snapshot.lastFailureKind, isNull);
    expect(snapshot.phaseLabel, 'Подключено');
    expect(
      snapshot.diagnosticsLabel,
      'Сеть wlan0 (#42) | DNS готов | Правила v4=3 v6=1',
    );
  });

  test('mobile lane uses host bridge connect and disconnect control', () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.connect':
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/android-seed.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime service is running.',
          };
        case 'runtimeEngine.disconnect':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/android-seed.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime service stopped cleanly.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final engine = createRuntimeEngine(hostPlatform: HostPlatform.android);

    final running = await engine.connect();
    final stopped = await engine.disconnect();

    expect(running.phase, RuntimePhase.running);
    expect(running.message, contains('running'));
    expect(stopped.phase, RuntimePhase.configStaged);
    expect(stopped.message, contains('stopped cleanly'));
  });

  test('desktop lane discovers a local libcore artifact directory', () async {
    final root = await Directory.systemTemp.createTemp('pokrov-runtime-test-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');

    final engine = createRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
    );

    final snapshot = await engine.snapshot();

    expect(snapshot.lane, RuntimeLane.desktopFfi);
    expect(snapshot.phase, RuntimePhase.artifactReady);
    expect(snapshot.coreBinaryPath, contains('libcore.dll'));
    expect(snapshot.helperBinaryPath, isNull);
    expect(snapshot.canInitialize, isTrue);
  });

  test(
      'desktop lane discovers a macOS runtime bundle copied into app frameworks',
      () async {
    final root = await Directory.systemTemp.createTemp('pokrov-runtime-macos-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final executableDirectory = Directory(
      '${root.path}\\Pokrov.app\\Contents\\MacOS',
    )..createSync(recursive: true);
    final runtimeDirectory = Directory(
      '${root.path}\\Pokrov.app\\Contents\\Frameworks\\Runtime',
    )..createSync(recursive: true);
    File('${runtimeDirectory.path}\\libcore.dylib').writeAsStringSync('stub');
    File('${runtimeDirectory.path}\\HiddifyCli').writeAsStringSync('stub');

    final engine = createRuntimeEngine(
      hostPlatform: HostPlatform.macos,
      assetRootOverride: executableDirectory.path,
    );

    final snapshot = await engine.snapshot();

    expect(snapshot.phase, RuntimePhase.artifactReady);
    expect(snapshot.coreBinaryPath, contains('libcore.dylib'));
    expect(snapshot.helperBinaryPath, contains('HiddifyCli'));
  });

  test('desktop lane stages a materialized runtime config without parse',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-materialized-desktop-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    final staged = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'materialized-desktop',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"direct","tag":"direct"}],"route":{"final":"direct"}}',
        materializedForRuntime: true,
      ),
    );

    expect(staged.phase, RuntimePhase.configStaged);
    expect(bindings.setupCalls, 1);
    expect(bindings.parseCalls, 0);
    final stagedFile = File(staged.stagedConfigPath!);
    expect(await stagedFile.readAsString(), contains('"inbounds"'));
    expect(
      Directory(
        '${stagedFile.parent.parent.parent.path}\\data',
      ).existsSync(),
      isTrue,
    );
    expect(
      Directory(
        '${stagedFile.parent.parent.path}\\data',
      ).existsSync(),
      isTrue,
    );
  });

  test('desktop lane keeps Windows full tunnel on TUN before libcore start',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-connect-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );

    final running = await engine.connect();

    expect(running.phase, RuntimePhase.running);
    expect(bindings.changeOptionsCalls, 1);
    expect(bindings.startCalls, 1);
    expect(bindings.lastOptionsJson, contains('"set-system-proxy":false'));
    expect(bindings.lastOptionsJson, contains('"enable-tun":true'));
  });

  test('desktop lane keeps Windows all-except-RU on TUN before libcore start',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-connect-rules-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-rules',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.allExceptRu,
      ),
    );

    final running = await engine.connect();

    expect(running.phase, RuntimePhase.running);
    expect(bindings.changeOptionsCalls, 1);
    expect(bindings.startCalls, 1);
    expect(bindings.lastOptionsJson, contains('"routing-mode":"allExceptRu"'));
    expect(bindings.lastOptionsJson, contains('"set-system-proxy":false'));
    expect(bindings.lastOptionsJson, contains('"enable-tun":true'));
  });

  test('desktop lane keeps Windows selected-app routing on TUN', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-connect-selected-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-selected',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"rules":[{"process_name":["browser.exe"],"outbound":"proxy"}],"final":"direct"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.selectedApps,
      ),
    );

    final running = await engine.connect();

    expect(running.phase, RuntimePhase.running);
    expect(bindings.changeOptionsCalls, 1);
    expect(bindings.startCalls, 1);
    expect(bindings.lastOptionsJson, contains('"routing-mode":"global"'));
    expect(bindings.lastOptionsJson, contains('"set-system-proxy":false'));
    expect(bindings.lastOptionsJson, contains('"enable-tun":true'));
  });

  test('desktop lane preserves setup errors instead of generic ready text',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-setup-error-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings(setupResult: 'setup failed');

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    final snapshot = await engine.initialize();

    expect(snapshot.phase, RuntimePhase.artifactReady);
    expect(snapshot.message, contains('setup failed'));
    expect(snapshot.canConnect, isFalse);
  });

  test('desktop lane preserves start errors after profile staging', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-start-error-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings(startResult: 'start failed');

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-start-error',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );

    final snapshot = await engine.connect();

    expect(snapshot.phase, RuntimePhase.configStaged);
    expect(snapshot.message, contains('start failed'));
    expect(snapshot.canConnect, isTrue);
  });

  test('desktop lane preserves parse errors after profile download', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-parse-error-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings(parseResult: 'parse failed');

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    final snapshot = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-parse-error',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: false,
        routeMode: RouteMode.fullTunnel,
      ),
    );

    expect(snapshot.phase, RuntimePhase.initialized);
    expect(snapshot.message, contains('parse failed'));
    expect(snapshot.canConnect, isFalse);
  });

  test('desktop lane preserves option sync errors before start', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-options-error-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings(
      changeOptionsResult: 'options failed',
    );

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-options-error',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );

    final snapshot = await engine.connect();

    expect(snapshot.phase, RuntimePhase.configStaged);
    expect(snapshot.message, contains('options failed'));
    expect(snapshot.canConnect, isTrue);
    expect(bindings.startCalls, 0);
  });

  test('desktop lane preserves disconnect errors', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-stop-error-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings(stopResult: 'stop failed');

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-stop-error',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );
    await engine.connect();

    final snapshot = await engine.disconnect();

    expect(snapshot.phase, RuntimePhase.running);
    expect(snapshot.message, contains('stop failed'));
  });

  test('desktop lane keeps runtime-ready WARP disabled without user consent',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-warp-no-consent-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-warp-no-consent',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
        warpPolicy: WarpRuntimePolicy(
          enabled: true,
          runtimeReady: true,
          state: 'ready',
          mode: 'proxy_over_warp',
          source: 'backend_managed',
          wireguardConfigJson:
              '{"private-key":"test-private-key","local-address-ipv4":"172.16.0.2","peer-public-key":"test-peer-public-key","client-id":"test-client-id"}',
          accountId: 'test-account-id',
          accessToken: 'test-access-token',
        ),
      ),
    );

    await engine.connect();

    final options =
        jsonDecode(bindings.lastOptionsJson!) as Map<String, dynamic>;
    final warp = options['warp'] as Map<String, dynamic>;
    expect(warp['enable'], isFalse);
    expect(warp.containsKey('account'), isFalse);
    expect(warp.containsKey('wireguardConfig'), isFalse);
  });

  test('desktop lane maps consented runtime-ready WARP policy into options',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-warp-consent-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-warp-consent',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
        warpPolicy: WarpRuntimePolicy(
          enabled: true,
          runtimeReady: true,
          userConsented: true,
          state: 'ready',
          mode: 'proxy_over_warp',
          source: 'backend_managed',
          wireguardConfigJson:
              '{"private-key":"test-private-key","local-address-ipv4":"172.16.0.2","peer-public-key":"test-peer-public-key","client-id":"test-client-id"}',
          accountId: 'test-account-id',
          accessToken: 'test-access-token',
        ),
      ),
    );

    await engine.connect();

    final options =
        jsonDecode(bindings.lastOptionsJson!) as Map<String, dynamic>;
    final warp = options['warp'] as Map<String, dynamic>;
    final warp2 = options['warp2'] as Map<String, dynamic>;
    expect(warp['enable'], isTrue);
    expect(warp['mode'], 'proxy_over_warp');
    expect(warp['wireguard-config'], contains('test-private-key'));
    expect((warp['wireguardConfig'] as Map<String, dynamic>)['private-key'],
        'test-private-key');
    expect((warp['account'] as Map<String, dynamic>)['account-id'],
        'test-account-id');
    expect(warp2['enable'], isFalse);
  });

  test('desktop lane enables client-local WARP without server material',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-warp-client-local-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-warp-client-local',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
        warpPolicy: WarpRuntimePolicy(
          enabled: true,
          runtimeReady: true,
          userConsented: true,
          state: 'consented',
          source: 'client_local',
          id: 'p1',
        ),
      ),
    );

    await engine.connect();

    final options =
        jsonDecode(bindings.lastOptionsJson!) as Map<String, dynamic>;
    final warp = options['warp'] as Map<String, dynamic>;
    expect(warp['enable'], isTrue);
    expect(warp['id'], 'p1');
    expect(warp['mode'], 'proxy_over_warp');
    expect(warp['wireguard-config'], '');
    expect(warp.containsKey('wireguardConfig'), isFalse);
    expect(warp.containsKey('account'), isFalse);
  });

  test('desktop lane applies WARP before the next connect', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-apply-warp-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'apply-warp-next-connect',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
        warpPolicy: WarpRuntimePolicy.clientLocalDefault,
      ),
    );

    final applied = await engine.applyWarp(enabled: true);

    expect(applied.applied, isTrue);
    expect(applied.effectiveAt, 'next_connect');
    expect(applied.fallbackUsed, isFalse);
    expect(bindings.changeOptionsCalls, 1);
    final options =
        jsonDecode(bindings.lastOptionsJson!) as Map<String, dynamic>;
    expect((options['warp'] as Map<String, dynamic>)['enable'], isTrue);
  });

  test('desktop lane exposes honest live stats without fake traffic numbers',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-live-stats-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory('${root.path}\\windows')
      ..createSync(recursive: true);
    File('${platformDirectory.path}\\libcore.dll').writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'live-stats',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
        smartConnect: SmartConnectProfile(
          eligible: true,
          fallbackRequired: false,
          shortlistReason: 'eligible',
          shortlistLimit: 1,
          shortlistRevision: 'r1',
          transportProfile: 'legacy_reality_fallback',
          profileRevision: 'p1',
          fallbackOrder: <String>[],
          shortlist: <SmartConnectNode>[
            SmartConnectNode(
              code: 'nl-ams-01',
              country: 'Netherlands',
              rank: 1,
              rankHint: SmartConnectRankHint(
                healthScore: 94,
                cpuPercent: 31,
                panelLatencyMs: 38,
                backendPenalty: 0,
                cpuPenalty: 0,
                stickyPreferred: false,
              ),
            ),
          ],
          stickiness: SmartConnectStickiness(
            preferredNodeCode: '',
            thresholdPercent: 15,
            latestSampleAt: '',
            stickinessApplied: false,
          ),
        ),
      ),
    );
    await engine.connect();

    final stats = await engine.liveStats();

    expect(stats.available, isTrue);
    expect(stats.serverCode, 'nl-ams-01');
    expect(stats.serverCountry, 'Netherlands');
    expect(stats.protocol, 'sing-box');
    expect(stats.uplinkBps, isNull);
    expect(stats.downlinkBps, isNull);
  });

  test('mobile lane forwards WARP, live stats, and push token calls', () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.applyWarp':
          return <String, Object?>{
            'applied': call.arguments is Map &&
                ((call.arguments as Map)['enabled'] == true),
            'effectiveAt': 'now',
            'fallbackUsed': false,
            'reason': null,
          };
        case 'runtimeEngine.liveStats':
          return <String, Object?>{
            'available': true,
            'uplinkBps': 10,
            'downlinkBps': 20,
            'latencyMs': 38,
            'since': '2026-06-22T10:00:00Z',
            'serverCode': 'nl-ams-01',
            'serverCountry': 'Netherlands',
            'protocol': 'sing-box',
          };
        case 'runtimeEngine.pushToken':
          return <String, Object?>{
            'token': 'push-token',
            'provider': 'fcm',
          };
      }
      return null;
    });

    const engine = MobileArtifactRuntimeEngine(
      hostPlatform: HostPlatform.android,
    );

    final applied = await engine.applyWarp(enabled: true);
    final stats = await engine.liveStats();
    final token = await engine.pushToken();

    expect(applied.applied, isTrue);
    expect(applied.effectiveAt, 'now');
    expect(stats.available, isTrue);
    expect(stats.downlinkBps, 20);
    expect(token.token, 'push-token');
    expect(token.provider, 'fcm');
  });
}
