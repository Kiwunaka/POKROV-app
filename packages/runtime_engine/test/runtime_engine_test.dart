import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

const _sensitiveRuntimeDetail =
    'vless://9f4a4b2c-7e10-4e9b-9df3-1a2b3c4d5e6f@203.0.113.17:443?token=runtime-test-token';

void _expectNoSensitiveRuntimeDetail(String value) {
  expect(value, isNot(contains('vless://')));
  expect(value, isNot(contains('203.0.113.17:443')));
  expect(value, isNot(contains('9f4a4b2c-7e10-4e9b-9df3-1a2b3c4d5e6f')));
  expect(value, isNot(contains('runtime-test-token')));
}

String _coreCapabilityDescriptor({
  int schemaVersion = 1,
  int desktopAbi = 2,
  int eventAbi = 1,
  Set<String> capabilities = CoreRuntimeCompatibility.supportedCapabilities,
  Set<String> lifecycleEvents =
      CoreRuntimeCompatibility.supportedLifecycleEvents,
}) {
  return jsonEncode(<String, Object?>{
    'schema_version': schemaVersion,
    'desktop_abi': desktopAbi,
    'event_abi': eventAbi,
    'capabilities': capabilities.toList()..sort(),
    'lifecycle_events': lifecycleEvents.toList(),
  });
}

class _FakeDesktopBindings implements DesktopRuntimeBindings {
  _FakeDesktopBindings({
    this.setupResult = '',
    this.secureFileResult = '',
    this.startResult = '',
    this.stopResult = '',
  });

  int setupCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int secureFileCalls = 0;
  final String setupResult;
  final String secureFileResult;
  final String startResult;
  final String stopResult;

  @override
  String secureFile(String path) {
    secureFileCalls += 1;
    return secureFileResult;
  }

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

RuntimeSnapshot _runningSnapshot({
  required HostPlatform hostPlatform,
  bool? coreEgressValidated,
}) {
  return RuntimeSnapshot(
    hostPlatform: hostPlatform,
    lane: hostPlatform == HostPlatform.windows
        ? RuntimeLane.desktopFfi
        : RuntimeLane.mobileArtifact,
    phase: RuntimePhase.running,
    artifactDirectory: '/host/runtime',
    coreBinaryPath: '/host/runtime/pokrov-core',
    helperBinaryPath: null,
    stagedConfigPath: '/host/runtime/pokrov-seed-runtime.json',
    supportsLiveConnect: true,
    canInitialize: true,
    canConnect: true,
    message: 'Runtime service is running.',
    hostHealth: RuntimeHostHealth.healthy,
    dnsState: RuntimeDiagnosticState.healthy,
    uplinkState: RuntimeDiagnosticState.healthy,
    dnsReady: true,
    coreEgressValidated: coreEgressValidated,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('desktop ABI 2 retains the released marker-only compatibility lane', () {
    final decision = CoreRuntimeCompatibility.negotiate(
      desktopAbi: 2,
    );

    expect(decision.mode, CoreRuntimeCompatibilityMode.legacyAbi2);
    expect(decision.contract, isNull);
  });

  test('desktop ABI 2 negotiates the exact capability and event contract', () {
    final decision = CoreRuntimeCompatibility.negotiate(
      desktopAbi: 2,
      descriptorJson: _coreCapabilityDescriptor(),
    );

    expect(decision.mode, CoreRuntimeCompatibilityMode.negotiated);
    expect(decision.contract?.schemaVersion, 1);
    expect(decision.contract?.eventAbi, 1);
    expect(
      decision.contract?.lifecycleEvents,
      CoreRuntimeCompatibility.supportedLifecycleEvents,
    );
    expect(
      RuntimeLifecycleEventType.values.map((event) => event.wireName).toSet(),
      CoreRuntimeCompatibility.supportedLifecycleEvents,
    );
  });

  test('desktop ABI negotiation fails closed on future contract versions', () {
    expect(
      () => CoreRuntimeCompatibility.negotiate(
        desktopAbi: 3,
        descriptorJson: _coreCapabilityDescriptor(desktopAbi: 3),
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      () => CoreRuntimeCompatibility.negotiate(
        desktopAbi: 2,
        descriptorJson: _coreCapabilityDescriptor(schemaVersion: 2),
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      () => CoreRuntimeCompatibility.negotiate(
        desktopAbi: 2,
        descriptorJson: _coreCapabilityDescriptor(eventAbi: 2),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test(
      'desktop ABI negotiation rejects missing capabilities and unknown events',
      () {
    expect(
      () => CoreRuntimeCompatibility.negotiate(
        desktopAbi: 2,
        descriptorJson: _coreCapabilityDescriptor(
          capabilities: <String>{
            ...CoreRuntimeCompatibility.supportedCapabilities,
          }..remove('secure_profile_file'),
        ),
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      () => CoreRuntimeCompatibility.negotiate(
        desktopAbi: 2,
        descriptorJson: _coreCapabilityDescriptor(
          lifecycleEvents: <String>{
            ...CoreRuntimeCompatibility.supportedLifecycleEvents,
            'future_unknown_event',
          },
        ),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('parses the managed-profile free access contract conservatively', () {
    final pending = FreeProfileAccess.tryParse(
      access: <String, Object?>{
        'access_state': 'free_monthly',
        'soft_mode_active': false,
        'free_profile_state': 'soft_transition_pending',
        'free_profile_active_role': 'free_standard',
        'free_profile_job_id': 81,
      },
      freeCaps: <String, Object?>{
        'transition_state': 'soft_transition_pending',
        'active_role': 'free_standard',
        'provisioning_job_id': 81,
      },
    );
    expect(pending?.isPending, isTrue);
    expect(pending?.isFreeAccess, isTrue);
    expect(pending?.provisioningJobId, 81);

    final soft = FreeProfileAccess.tryParse(
      access: <String, Object?>{
        'access_state': 'free_soft_mode',
        'soft_mode_active': true,
        'free_profile_state': 'soft_active',
        'free_profile_active_role': 'free_soft',
      },
      freeCaps: <String, Object?>{
        'transition_state': 'soft_active',
        'active_role': 'free_soft',
      },
    );
    expect(soft?.isConfirmedSoftMode, isTrue);

    final mismatch = FreeProfileAccess.tryParse(
      access: <String, Object?>{
        'access_state': 'free_monthly',
        'free_profile_state': 'standard',
      },
      freeCaps: <String, Object?>{
        'transition_state': 'soft_active',
      },
    );
    expect(mismatch?.needsConservativePresentation, isTrue);

    final unknown = FreeProfileAccess.tryParse(
      access: <String, Object?>{'access_state': 'future_access_state'},
      freeCaps: <String, Object?>{'transition_state': 'future_transition'},
    );
    expect(unknown?.needsConservativePresentation, isTrue);
  });

  test('clean health requires DNS and selected-outbound egress proof', () {
    final pending = _runningSnapshot(
      hostPlatform: HostPlatform.android,
    );
    final failed = _runningSnapshot(
      hostPlatform: HostPlatform.android,
      coreEgressValidated: false,
    );
    final validated = _runningSnapshot(
      hostPlatform: HostPlatform.android,
      coreEgressValidated: true,
    );
    final windows = _runningSnapshot(
      hostPlatform: HostPlatform.windows,
      coreEgressValidated: true,
    );
    final windowsWithoutProof =
        _runningSnapshot(hostPlatform: HostPlatform.windows);
    final explicitDnsFailure = RuntimeSnapshot(
      hostPlatform: HostPlatform.windows,
      lane: RuntimeLane.desktopFfi,
      phase: RuntimePhase.running,
      artifactDirectory: '/host/runtime',
      coreBinaryPath: '/host/runtime/pokrov-core',
      helperBinaryPath: null,
      stagedConfigPath: '/host/runtime/pokrov-seed-runtime.json',
      supportsLiveConnect: true,
      canInitialize: true,
      canConnect: true,
      message: 'Runtime service is running.',
      hostHealth: RuntimeHostHealth.healthy,
      dnsState: RuntimeDiagnosticState.healthy,
      uplinkState: RuntimeDiagnosticState.healthy,
      dnsReady: false,
      coreEgressValidated: true,
    );

    expect(pending.isCoreEgressValidationPending, isTrue);
    expect(pending.hasDegradedHostDiagnostics, isFalse);
    expect(pending.isCleanlyHealthy, isFalse);
    expect(pending.phaseLabel, 'Проверяем выход через VPN');

    expect(failed.hasCoreEgressValidationFailure, isTrue);
    expect(failed.hasDegradedHostDiagnostics, isTrue);
    expect(failed.isCleanlyHealthy, isFalse);
    expect(failed.phaseLabel, 'Подключено с предупреждением');

    expect(validated.isCleanlyHealthy, isTrue);
    expect(validated.phaseLabel, 'Подключено');

    expect(windows.requiresCoreEgressValidation, isFalse);
    expect(windows.isCleanlyHealthy, isTrue);
    expect(windows.phaseLabel, 'Подключено');
    expect(windowsWithoutProof.isCleanlyHealthy, isFalse);
    expect(windowsWithoutProof.phaseLabel, 'Проверяем выход через VPN');
    expect(explicitDnsFailure.isCleanlyHealthy, isFalse);
    expect(explicitDnsFailure.phaseLabel, 'Подключено с предупреждением');
  });

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

    final platformDirectory = Directory(p.join(root.path, 'android'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.aar'))
        .writeAsStringSync('stub');

    final engine = createRuntimeEngine(
      hostPlatform: HostPlatform.android,
      assetRootOverride: root.path,
    );

    final snapshot = await engine.snapshot();

    expect(snapshot.phase, RuntimePhase.artifactReady);
    expect(snapshot.supportsLiveConnect, isFalse);
    expect(snapshot.canInitialize, isFalse);
    expect(snapshot.coreBinaryPath, contains('pokrov-core.aar'));
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
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Host bridge ready.',
          };
        case 'runtimeEngine.initialize':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
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
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
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
        configPayload:
            '{"outbounds":[{"type":"vless","tag":"node"},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        quickSettingsEligible: true,
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
    expect(staged.message, 'Настройки POKROV готовы.');
    expect(stagedArguments?['runtimeOptionsJson'], isNull);
    expect(stagedArguments?['quickSettingsEligible'], isTrue);
    expect(stagedArguments?['coreEgressProbeRequired'], isTrue);
    final config = jsonDecode(stagedArguments?['configPayload']! as String)
        as Map<String, dynamic>;
    final endpoints = config['endpoints'] as List<dynamic>;
    final warp = endpoints.single as Map<String, dynamic>;
    expect(warp['type'], 'warp');
    expect(warp['unique_identifier'], 'android-warp');
    expect(warp['detour'], 'proxy');
    final node =
        (config['outbounds'] as List<dynamic>).first as Map<String, dynamic>;
    expect(node['detour'], isNull);
    expect((config['route'] as Map<String, dynamic>)['final'], 'pokrov-warp');
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
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
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
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"direct","tag":"direct"}],"route":{"rules":[{"ip_is_private":true,"outbound":"direct"},{"protocol":"dns","action":"hijack-dns"}],"final":"direct"},"experimental":{"cache_file":{"enabled":true}},"_meta":{"title":"display only","runtime_variant_probe":{"group_tag":"probe","mappings":[{"id":"direct","outbound_tag":"direct"}]}}}',
        materializedForRuntime: true,
        coreEgressProbeRequired: false,
      ),
    );

    expect(stagedArguments?['materializedForRuntime'], isTrue);
    expect(stagedArguments?['quickSettingsEligible'], isFalse);
    expect(stagedArguments?['coreEgressProbeRequired'], isFalse);
    expect(stagedArguments?['runtimeOptionsJson'], isNull);
    expect(stagedArguments?['configPayload'], isA<String>());
    final stagedConfig =
        jsonDecode(stagedArguments?['configPayload']! as String)
            as Map<String, dynamic>;
    expect(stagedConfig['_meta'], <String, dynamic>{
      'runtime_variant_probe': <String, dynamic>{
        'group_tag': 'probe',
        'mappings': <Map<String, String>>[
          <String, String>{'id': 'direct', 'outbound_tag': 'direct'},
        ],
      },
    });
    expect(stagedConfig, isNot(contains('experimental')));
    final route = stagedConfig['route'] as Map<String, dynamic>;
    final rules = (route['rules'] as List).cast<Map<String, dynamic>>();
    expect(rules.first, <String, dynamic>{
      'protocol': 'dns',
      'action': 'hijack-dns',
    });
    expect(rules[1]['ip_is_private'], isTrue);
  });

  test('mobile lane accepts only the current AWG2 lab contract', () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    Map<Object?, Object?>? stagedArguments;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.stageManagedProfile') {
        stagedArguments = Map<Object?, Object?>.from(call.arguments as Map);
        return <String, Object?>{
          'phase': 'configStaged',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/awg2.json',
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
      ManagedProfilePayload(
        profileName: 'awg2-lab',
        configPayload: jsonEncode(<String, Object?>{
          'endpoints': <Object?>[
            <String, Object?>{
              'type': 'awg',
              'tag': 'awg2-lab',
              'useIntegratedTun': false,
            },
          ],
          'route': <String, Object?>{'final': 'awg2-lab'},
          '_meta': <String, Object?>{
            'transport_contract': <String, Object?>{
              'id': 'pokrov.awg2.endpoint.v1',
              'sha256':
                  '3beb57eccd8d5e15ce7466496208fe1945f353b3417be58644911d1ded125a83',
              'profile': 'awg2_lab',
              'state': 'enabled',
              'generation': 'awg2-lab-v1',
            },
          },
        }),
        materializedForRuntime: true,
      ),
    );

    final stagedConfig =
        jsonDecode(stagedArguments?['configPayload']! as String)
            as Map<String, dynamic>;
    expect(
      (stagedConfig['endpoints'] as List<dynamic>).single,
      containsPair('type', 'awg'),
    );
    expect(stagedConfig, isNot(contains('_meta')));
  });

  test('Android and Windows keep AWG2 inside existing outer route modes',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final staged = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.stageManagedProfile') {
        final arguments = Map<Object?, Object?>.from(call.arguments as Map);
        final config = jsonDecode(arguments['configPayload']! as String)
            as Map<String, dynamic>;
        final endpoint = (config['endpoints'] as List<dynamic>).single
            as Map<String, dynamic>;
        staged.add(
          '${arguments['routeMode']}:${endpoint['type']}:${endpoint['useIntegratedTun']}',
        );
        return <String, Object?>{
          'phase': 'configStaged',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'staged',
        };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    final configPayload = jsonEncode(<String, Object?>{
      'endpoints': <Object?>[
        <String, Object?>{
          'type': 'awg',
          'tag': 'awg2-lab',
          'useIntegratedTun': false,
        },
      ],
      'route': <String, Object?>{'final': 'awg2-lab'},
      '_meta': <String, Object?>{
        'transport_contract': <String, Object?>{
          'id': 'pokrov.awg2.endpoint.v1',
          'sha256':
              '3beb57eccd8d5e15ce7466496208fe1945f353b3417be58644911d1ded125a83',
          'profile': 'awg2_lab',
          'state': 'enabled',
          'generation': 'awg2-lab-v1',
        },
      },
    });

    for (final platform in <HostPlatform>[
      HostPlatform.android,
      HostPlatform.windows,
    ]) {
      final engine = createRuntimeEngine(hostPlatform: platform);
      for (final routeMode in <RouteMode>[
        RouteMode.fullTunnel,
        RouteMode.allExceptRu,
        RouteMode.selectedApps,
      ]) {
        await engine.stageManagedProfile(
          ManagedProfilePayload(
            profileName: 'awg2-${platform.name}-${routeMode.name}',
            configPayload: configPayload,
            materializedForRuntime: true,
            routeMode: routeMode,
          ),
        );
      }
    }

    expect(staged, <String>[
      'fullTunnel:awg:false',
      'allExceptRu:awg:false',
      'selectedApps:awg:false',
      'fullTunnel:awg:false',
      'allExceptRu:awg:false',
      'selectedApps:awg:false',
    ]);
  });

  for (final rejectedCase in <Map<String, Object?>>[
    <String, Object?>{
      'name': 'missing provenance',
      'transport_contract': null,
      'use_integrated_tun': false,
    },
    <String, Object?>{
      'name': 'stale contract hash',
      'transport_contract': <String, Object?>{
        'id': 'pokrov.awg2.endpoint.v1',
        'sha256': List<String>.filled(64, '0').join(),
        'profile': 'awg2_lab',
        'state': 'enabled',
        'generation': 'awg2-lab-v1',
      },
      'use_integrated_tun': false,
    },
    <String, Object?>{
      'name': 'integrated TUN ownership',
      'transport_contract': <String, Object?>{
        'id': 'pokrov.awg2.endpoint.v1',
        'sha256':
            '3beb57eccd8d5e15ce7466496208fe1945f353b3417be58644911d1ded125a83',
        'profile': 'awg2_lab',
        'state': 'enabled',
        'generation': 'awg2-lab-v1',
      },
      'use_integrated_tun': true,
    },
  ]) {
    test('mobile lane rejects AWG2 ${rejectedCase['name']}', () async {
      const channel = MethodChannel('space.pokrov/runtime_engine');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var stageCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'runtimeEngine.stageManagedProfile') {
          stageCalls += 1;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });

      final engine = createRuntimeEngine(hostPlatform: HostPlatform.android);
      await expectLater(
        engine.stageManagedProfile(
          ManagedProfilePayload(
            profileName: 'awg2-lab-rejected',
            configPayload: jsonEncode(<String, Object?>{
              'endpoints': <Object?>[
                <String, Object?>{
                  'type': 'awg',
                  'tag': 'awg2-lab',
                  'useIntegratedTun': rejectedCase['use_integrated_tun'],
                },
              ],
              'route': <String, Object?>{'final': 'awg2-lab'},
              if (rejectedCase['transport_contract'] != null)
                '_meta': <String, Object?>{
                  'transport_contract': rejectedCase['transport_contract'],
                },
            }),
            materializedForRuntime: true,
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(stageCalls, 0);
    });
  }

  test('mobile invalidation removes the reusable host profile before restaging',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'runtimeEngine.stageManagedProfile':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/managed.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged.',
          };
        case 'runtimeEngine.invalidateManagedProfile':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Reusable profile invalidated.',
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
        profileName: 'managed',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"direct","tag":"direct"}],"route":{"final":"direct"}}',
        materializedForRuntime: true,
      ),
    );
    final invalidated = await engine.invalidateManagedProfile();

    expect(
      calls,
      containsAllInOrder(const <String>[
        'runtimeEngine.stageManagedProfile',
        'runtimeEngine.invalidateManagedProfile',
      ]),
    );
    expect(invalidated.stagedConfigPath, isNull);
    expect(invalidated.canConnect, isFalse);
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
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
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
    expect(snapshot.diagnosticsLabel, 'DNS требует проверки');
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
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android tun established.',
            'default_network_interface': 'wlan0',
            'default_network_index': 42,
            'dns_ready': true,
            'core_egress_validated': false,
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
    expect(snapshot.defaultNetworkInterface, 'network_available');
    expect(snapshot.defaultNetworkIndex, isNull);
    expect(snapshot.dnsReady, isTrue);
    expect(snapshot.coreEgressValidated, isFalse);
    expect(snapshot.ipv4RouteCount, 3);
    expect(snapshot.ipv6RouteCount, 1);
    expect(snapshot.lastFailureKind, isNull);
    expect(snapshot.hasDegradedHostDiagnostics, isTrue);
    expect(snapshot.isCleanlyHealthy, isFalse);
    expect(snapshot.phaseLabel, 'Подключено с предупреждением');
    expect(
      snapshot.diagnosticsLabel,
      'Сеть доступна | DNS готов | Правила v4=3 v6=1',
    );
    expect(snapshot.diagnosticsLabel, isNot(contains('#42')));
  });

  test('WARP effective time accepts only the bridge wire enum', () {
    for (final effectiveAt in <String>['now', 'next_connect', 'none']) {
      final result = WarpApplyResult.fromMap(<String, Object?>{
        'applied': true,
        'effectiveAt': effectiveAt,
      });
      expect(result.effectiveAt, effectiveAt);
    }

    final hostile = WarpApplyResult.fromMap(<String, Object?>{
      'applied': true,
      'effectiveAt': _sensitiveRuntimeDetail,
    });

    expect(hostile.effectiveAt, 'none');
    _expectNoSensitiveRuntimeDetail(hostile.effectiveAt);
    _expectNoSensitiveRuntimeDetail(hostile.toString());
  });

  test('mobile lane redacts native runtime details from public snapshots',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.snapshot') {
        return <String, Object?>{
          'phase': 'running',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': _sensitiveRuntimeDetail,
          'default_network_interface': _sensitiveRuntimeDetail,
          'last_failure_kind': _sensitiveRuntimeDetail,
          'last_stop_reason': _sensitiveRuntimeDetail,
          'hostDiagnostics': <String, Object?>{
            'summary': _sensitiveRuntimeDetail,
          },
        };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final snapshot =
        await createRuntimeEngine(hostPlatform: HostPlatform.android)
            .snapshot();
    final warp = WarpApplyResult.fromMap(<String, Object?>{
      'applied': false,
      'reason': _sensitiveRuntimeDetail,
    });

    expect(
        snapshot.message, 'POKROV не смог завершить действие на устройстве.');
    expect(snapshot.defaultNetworkInterface, 'network_available');
    expect(snapshot.lastFailureKind, 'runtime_failure');
    expect(snapshot.lastStopReason, 'runtime_stopped');
    expect(warp.reason, 'runtime_failure');
    for (final value in <String>[
      snapshot.message,
      snapshot.diagnosticsLabel ?? '',
      snapshot.defaultNetworkInterface ?? '',
      snapshot.lastFailureKind ?? '',
      snapshot.lastStopReason ?? '',
      snapshot.toString(),
      warp.reason ?? '',
      warp.toString(),
    ]) {
      _expectNoSensitiveRuntimeDetail(value);
    }
  });

  test('mobile lane preserves the safe emergency endpoint failure kind',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.snapshot') {
        return <String, Object?>{
          'phase': 'configStaged',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'Этот резерв недоступен в текущей сети.',
          'last_failure_kind': 'emergency_endpoint_unreachable',
        };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final snapshot =
        await createRuntimeEngine(hostPlatform: HostPlatform.android)
            .snapshot();

    expect(snapshot.lastFailureKind, 'emergency_endpoint_unreachable');
  });

  test('mobile lane preserves actionable VPN permission denial', () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.snapshot') {
        return <String, Object?>{
          'phase': 'configStaged',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': _sensitiveRuntimeDetail,
          'last_failure_kind': 'vpn_permission_denied',
        };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final snapshot =
        await createRuntimeEngine(hostPlatform: HostPlatform.android)
            .snapshot();

    expect(snapshot.lastFailureKind, 'vpn_permission_denied');
    expect(snapshot.message, contains('Разрешить VPN'));
    _expectNoSensitiveRuntimeDetail(snapshot.message);
  });

  test('mobile lane redacts PlatformException details after fallback fails',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: _sensitiveRuntimeDetail,
        message: _sensitiveRuntimeDetail,
        details: _sensitiveRuntimeDetail,
      );
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final snapshot =
        await createRuntimeEngine(hostPlatform: HostPlatform.android).connect();

    expect(snapshot.message, 'Не удалось связаться с системным модулем.');
    _expectNoSensitiveRuntimeDetail(snapshot.message);
    _expectNoSensitiveRuntimeDetail(snapshot.toString());
  });

  test('mobile lane survives 100 serial host bridge start-stop cycles',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var connectCalls = 0;
    var disconnectCalls = 0;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.connect':
          connectCalls += 1;
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/android-seed.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime service is running.',
          };
        case 'runtimeEngine.disconnect':
          disconnectCalls += 1;
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
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

    for (var cycle = 0; cycle < 100; cycle += 1) {
      final running = await engine.connect();
      final stopped = await engine.disconnect();

      expect(running.phase, RuntimePhase.running, reason: 'cycle $cycle');
      expect(running.message, 'POKROV включен.', reason: 'cycle $cycle');
      expect(stopped.phase, RuntimePhase.configStaged, reason: 'cycle $cycle');
      expect(stopped.message, 'Настройки POKROV готовы.',
          reason: 'cycle $cycle');
    }
    expect(connectCalls, 100);
    expect(disconnectCalls, 100);
  });

  test(
    'real Windows POKROV Core 1.1.0 survives 100 start-stop cycles',
    () async {
      final artifactRoot =
          Platform.environment['POKROV_REAL_CORE_ROOT']!.trim();
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final listenPort = socket.port;
      await socket.close();

      final engine = DesktopRuntimeEngine(
        hostPlatform: HostPlatform.windows,
        assetRootOverride: artifactRoot,
        connectivityProbe: () async => null,
      );
      final staged = await engine.stageManagedProfile(
        ManagedProfilePayload(
          profileName: 'pokrov-core-real-start-stop-backtest',
          configPayload: jsonEncode(<String, Object?>{
            'log': <String, Object?>{'disabled': true},
            'dns': <String, Object?>{
              'servers': <Object?>[
                <String, Object?>{
                  'type': 'udp',
                  'tag': 'dns-direct',
                  'server': '1.1.1.1',
                },
              ],
              'final': 'dns-direct',
            },
            'inbounds': <Object?>[
              <String, Object?>{
                'type': 'mixed',
                'tag': 'mixed-in',
                'listen': '127.0.0.1',
                'listen_port': listenPort,
              },
            ],
            'outbounds': <Object?>[
              <String, Object?>{'type': 'direct', 'tag': 'direct'},
            ],
            'route': <String, Object?>{
              'rules': <Object?>[
                <String, Object?>{'action': 'sniff'},
                <String, Object?>{
                  'protocol': 'dns',
                  'action': 'hijack-dns',
                },
              ],
              'final': 'direct',
              'default_domain_resolver': <String, Object?>{
                'server': 'dns-direct',
                'strategy': 'ipv4_only',
              },
            },
          }),
          materializedForRuntime: true,
        ),
      );
      expect(staged.phase, RuntimePhase.configStaged);

      for (var cycle = 0; cycle < 100; cycle += 1) {
        final running = await engine.connect();
        expect(running.phase, RuntimePhase.running, reason: 'cycle $cycle');
        final stopped = await engine.disconnect();
        expect(stopped.phase, RuntimePhase.configStaged,
            reason: 'cycle $cycle');
      }
    },
    skip: !Platform.isWindows ||
            (Platform.environment['POKROV_REAL_CORE_ROOT'] ?? '').trim().isEmpty
        ? 'Set POKROV_REAL_CORE_ROOT to run the exact DLL backtest.'
        : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test('windows factory uses the authenticated service bridge', () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return <String, Object?>{
        'phase': 'artifactReady',
        'helperBinaryPath': 'service://pokrov_service.exe',
        'supportsLiveConnect': true,
        'canInitialize': true,
        'canConnect': false,
        'coreEgressValidated': false,
        'coreEgressValidationRequired': true,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final engine = createRuntimeEngine(hostPlatform: HostPlatform.windows);
    final snapshot = await engine.snapshot();

    expect(snapshot.lane, RuntimeLane.windowsService);
    expect(snapshot.phase, RuntimePhase.artifactReady);
    expect(snapshot.helperBinaryPath, 'service://pokrov_service.exe');
    expect(snapshot.coreBinaryPath, isNull);
    expect(snapshot.canInitialize, isTrue);
    expect(snapshot.coreEgressValidated, isFalse);
    expect(snapshot.isCleanlyHealthy, isFalse);
    expect(calls, ['runtimeEngine.snapshot']);
  });

  test('desktop lane does not silently activate a foreign runtime artifact',
      () async {
    final root = await Directory.systemTemp.createTemp('pokrov-runtime-test-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'foreign-core.dll'))
        .writeAsStringSync('stub');

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
    );

    final snapshot = await engine.snapshot();

    expect(snapshot.lane, RuntimeLane.desktopFfi);
    expect(snapshot.phase, RuntimePhase.artifactMissing);
    expect(snapshot.coreBinaryPath, isNull);
    expect(snapshot.helperBinaryPath, isNull);
    expect(snapshot.canInitialize, isFalse);
  });

  test('desktop lane discovers the active POKROV Core artifact', () async {
    final root =
        await Directory.systemTemp.createTemp('pokrov-core-runtime-test-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(
      p.join(root.path, 'artifacts', 'pokrov-core', 'v1.1.0', 'windows'),
    )..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
    );

    final snapshot = await engine.snapshot();

    expect(snapshot.phase, RuntimePhase.artifactReady);
    expect(snapshot.coreBinaryPath, contains('pokrov-core.dll'));
    expect(snapshot.helperBinaryPath, isNull);
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
      p.join(root.path, 'Pokrov.app', 'Contents', 'MacOS'),
    )..createSync(recursive: true);
    final runtimeDirectory = Directory(
      p.join(root.path, 'Pokrov.app', 'Contents', 'Frameworks', 'Runtime'),
    )..createSync(recursive: true);
    File(p.join(runtimeDirectory.path, 'pokrov-core.dylib'))
        .writeAsStringSync('stub');

    final engine = createRuntimeEngine(
      hostPlatform: HostPlatform.macos,
      assetRootOverride: executableDirectory.path,
    );

    final snapshot = await engine.snapshot();

    expect(snapshot.phase, RuntimePhase.artifactReady);
    expect(snapshot.coreBinaryPath, contains('pokrov-core.dylib'));
    expect(snapshot.helperBinaryPath, isNull);
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

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
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
    final stagedFile = File(staged.stagedConfigPath!);
    expect(stagedFile.uri.pathSegments.last, 'managed-profile.json');
    expect(await stagedFile.readAsString(), contains('"inbounds"'));
    expect(
      Directory(
        p.join(stagedFile.parent.parent.parent.path, 'data'),
      ).existsSync(),
      isTrue,
    );
    expect(
      Directory(
        p.join(stagedFile.parent.parent.path, 'data'),
      ).existsSync(),
      isTrue,
    );
  });

  test('POKROV Core desktop ABI starts only a materialized profile', () async {
    final root = await Directory.systemTemp.createTemp('pokrov-core-connect-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'pokrov-core-materialized',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"direct","tag":"direct"}],"route":{"final":"direct"}}',
        materializedForRuntime: true,
      ),
    );
    final running = await engine.connect();

    expect(running.phase, RuntimePhase.running);
    expect(bindings.startCalls, 1);
  });

  test('POKROV Core health probe uses the materialized loopback mixed port',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-core-probe-',
    );
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await proxy.close(force: true);
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      mixedProxyProbe: () async => null,
      systemTunnelProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      ManagedProfilePayload(
        profileName: 'pokrov-core-probe',
        configPayload: jsonEncode(<String, Object?>{
          'inbounds': <Object?>[
            <String, Object?>{'type': 'tun'},
            <String, Object?>{
              'type': 'mixed',
              'listen': '127.0.0.1',
              'listen_port': proxy.port,
            },
          ],
          'outbounds': <Object?>[
            <String, Object?>{'type': 'direct', 'tag': 'direct'},
          ],
          'route': <String, Object?>{'final': 'direct'},
        }),
        materializedForRuntime: true,
      ),
    );

    final running = await engine.connect();

    expect(running.phase, RuntimePhase.running);
    expect(bindings.startCalls, 1);
  });

  test('POKROV Core desktop ABI rejects a nonmaterialized profile', () async {
    final root = await Directory.systemTemp.createTemp('pokrov-core-parse-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    final snapshot = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'pokrov-core-unmaterialized',
        configPayload: 'vless://example',
        materializedForRuntime: false,
      ),
    );

    expect(snapshot.phase, RuntimePhase.initialized);
    expect(snapshot.canConnect, isFalse);
    expect(snapshot.message, contains('уже собранный sing-box профиль'));
  });

  test('POKROV Core materializes client-local WARP before start', () async {
    final root = await Directory.systemTemp.createTemp('pokrov-core-warp-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'pokrov-core-warp',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"vless","tag":"node"},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
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
    final snapshot = await engine.connect();

    expect(snapshot.phase, RuntimePhase.running);
    expect(bindings.startCalls, 1);
    final stagedConfig = jsonDecode(
      await File(snapshot.stagedConfigPath!).readAsString(),
    ) as Map<String, dynamic>;
    expect(
      ((stagedConfig['endpoints'] as List<dynamic>).single
          as Map<String, dynamic>)['type'],
      'warp',
    );
    expect(
      ((stagedConfig['outbounds'] as List<dynamic>).first
          as Map<String, dynamic>)['detour'],
      isNull,
    );
    expect(
      (stagedConfig['route'] as Map<String, dynamic>)['final'],
      'pokrov-warp',
    );
    expect(bindings.secureFileCalls, 1);
  });

  test('POKROV Core WARP-over-proxy preserves selected-app direct routing',
      () async {
    final root =
        await Directory.systemTemp.createTemp('pokrov-core-warp-chain-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      systemTunnelProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    final staged = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'pokrov-core-warp-over-proxy',
        configPayload:
            '{"outbounds":[{"type":"vless","tag":"node"},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"dns":{"servers":[{"tag":"remote","address":"1.1.1.1","detour":"proxy"}]},"route":{"rules":[{"process_name":["browser.exe"],"outbound":"proxy"}],"final":"direct"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.selectedApps,
        warpPolicy: WarpRuntimePolicy(
          enabled: true,
          runtimeReady: true,
          userConsented: true,
          state: 'consented',
          mode: 'warp_over_proxy',
          source: 'backend_managed',
          id: 'account-warp',
          accountId: 'account-id',
          accessToken: 'access-token',
        ),
      ),
    );

    final config = jsonDecode(
      await File(staged.stagedConfigPath!).readAsString(),
    ) as Map<String, dynamic>;
    final endpoint =
        (config['endpoints'] as List<dynamic>).single as Map<String, dynamic>;
    expect(endpoint['detour'], 'proxy');
    expect((endpoint['profile'] as Map<String, dynamic>)['detour'], 'proxy');
    expect((endpoint['profile'] as Map<String, dynamic>)['id'], 'account-id');
    final route = config['route'] as Map<String, dynamic>;
    expect(route['final'], 'direct');
    expect(
      ((route['rules'] as List<dynamic>).single
          as Map<String, dynamic>)['outbound'],
      'pokrov-warp',
    );
    expect(
      (((config['dns'] as Map<String, dynamic>)['servers'] as List<dynamic>)
          .single as Map<String, dynamic>)['detour'],
      'pokrov-warp',
    );
    expect(
      ((config['experimental'] as Map<String, dynamic>)['cache_file']
          as Map<String, dynamic>)['store_warp_config'],
      isTrue,
    );
  });

  test('POKROV Core disabling WARP restores the staged base config', () async {
    final root = await Directory.systemTemp.createTemp('pokrov-core-warp-off-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );
    final staged = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'pokrov-core-warp-toggle',
        configPayload:
            '{"outbounds":[{"type":"vless","tag":"node"},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        warpPolicy: WarpRuntimePolicy.clientLocalDefault,
      ),
    );

    expect((await engine.applyWarp(enabled: true)).applied, isTrue);
    var config = jsonDecode(
      await File(staged.stagedConfigPath!).readAsString(),
    ) as Map<String, dynamic>;
    expect(config['endpoints'], isNotEmpty);
    expect(
      ((config['outbounds'] as List<dynamic>).first
          as Map<String, dynamic>)['detour'],
      isNull,
    );
    expect((config['route'] as Map<String, dynamic>)['final'], 'pokrov-warp');

    expect((await engine.applyWarp(enabled: false)).applied, isTrue);
    config = jsonDecode(
      await File(staged.stagedConfigPath!).readAsString(),
    ) as Map<String, dynamic>;
    expect(config.containsKey('endpoints'), isFalse);
    expect(
      ((config['outbounds'] as List<dynamic>).first
          as Map<String, dynamic>)['detour'],
      isNull,
    );
    expect(bindings.secureFileCalls, 3);
  });

  test('desktop lane keeps Windows full tunnel on TUN before core start',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-connect-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      systemTunnelProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    final staged = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );

    final running = await engine.connect();
    final config = jsonDecode(
      await File(staged.stagedConfigPath!).readAsString(),
    ) as Map<String, dynamic>;

    expect(running.phase, RuntimePhase.running);
    expect(bindings.startCalls, 1);
    expect(
      ((config['inbounds'] as List<dynamic>).single
          as Map<String, dynamic>)['type'],
      'tun',
    );
    expect((config['route'] as Map<String, dynamic>)['final'], 'proxy');
  });

  test('desktop lane remaps a busy loopback port before core start', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-port-conflict-',
    );
    final occupied = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    addTearDown(() async {
      await occupied.close();
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    final staged = await engine.stageManagedProfile(
      ManagedProfilePayload(
        profileName: 'connect-desktop-port-conflict',
        configPayload: jsonEncode(<String, Object?>{
          'inbounds': <Object?>[
            <String, Object?>{
              'type': 'tun',
              'tag': 'tun-in',
            },
            <String, Object?>{
              'type': 'mixed',
              'tag': 'mixed-in',
              'listen': '127.0.0.1',
              'listen_port': occupied.port,
            },
          ],
          'outbounds': <Object?>[
            <String, Object?>{'type': 'direct', 'tag': 'direct'},
          ],
          'route': <String, Object?>{'final': 'direct'},
        }),
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );
    final config = jsonDecode(
      await File(staged.stagedConfigPath!).readAsString(),
    ) as Map<String, dynamic>;
    final mixed =
        (config['inbounds'] as List<dynamic>)[1] as Map<String, dynamic>;

    expect(staged.phase, RuntimePhase.configStaged);
    expect(mixed['listen_port'], isNot(occupied.port));
    expect(mixed['listen_port'], inInclusiveRange(1, 65535));
  });

  test('desktop lane keeps Windows all-except-RU on TUN before core start',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-connect-rules-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      systemTunnelProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-rules',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"selector","tag":"proxy"},{"type":"direct","tag":"direct"}],"route":{"rules":[{"domain_suffix":["ru","xn--p1ai","su"],"outbound":"direct"}],"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.allExceptRu,
      ),
    );

    final running = await engine.connect();
    final config = jsonDecode(
      await File(running.stagedConfigPath!).readAsString(),
    ) as Map<String, dynamic>;
    final route = config['route'] as Map<String, dynamic>;
    final rule =
        (route['rules'] as List<dynamic>).single as Map<String, dynamic>;

    expect(running.phase, RuntimePhase.running);
    expect(bindings.startCalls, 1);
    expect(
        rule['domain_suffix'], containsAll(<String>['ru', 'xn--p1ai', 'su']));
    expect(rule['outbound'], 'direct');
    expect(route['final'], 'proxy');
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

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      systemTunnelProbe: () async => null,
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
    final config = jsonDecode(
      await File(running.stagedConfigPath!).readAsString(),
    ) as Map<String, dynamic>;
    final route = config['route'] as Map<String, dynamic>;
    final rule =
        (route['rules'] as List<dynamic>).single as Map<String, dynamic>;

    expect(running.phase, RuntimePhase.running);
    expect(bindings.startCalls, 1);
    expect(rule['process_name'], <String>['browser.exe']);
    expect(rule['outbound'], 'proxy');
    expect(route['final'], 'direct');
  });

  test('desktop lane redacts setup errors instead of generic ready text',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-setup-error-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings(setupResult: _sensitiveRuntimeDetail);

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    final snapshot = await engine.initialize();

    expect(snapshot.phase, RuntimePhase.artifactReady);
    expect(snapshot.message, 'Не удалось подготовить подключение.');
    expect(snapshot.lastFailureKind, 'runtime_initialization_failed');
    _expectNoSensitiveRuntimeDetail(snapshot.message);
    expect(snapshot.canConnect, isFalse);
  });

  test('desktop lane redacts start errors after profile staging', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-start-error-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings(startResult: _sensitiveRuntimeDetail);

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
    expect(snapshot.message, 'POKROV не смог подключиться на этом устройстве.');
    expect(snapshot.lastFailureKind, 'runtime_start_failed');
    _expectNoSensitiveRuntimeDetail(snapshot.message);
    expect(snapshot.canConnect, isTrue);
  });

  test('desktop lane rejects invalid materialized core config', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-parse-error-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    final snapshot = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-parse-error',
        configPayload: 'not-json',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );

    expect(snapshot.phase, RuntimePhase.initialized);
    expect(snapshot.message, contains('не прошел проверку'));
    expect(snapshot.canConnect, isFalse);
  });

  test('desktop lane redacts secure-file errors before start', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-options-error-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings(
      secureFileResult: _sensitiveRuntimeDetail,
    );

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    final snapshot = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'connect-desktop-options-error',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );

    expect(snapshot.phase, RuntimePhase.initialized);
    expect(snapshot.message, 'POKROV не смог защитить файл профиля.');
    expect(snapshot.lastFailureKind, 'profile_staging_failed');
    _expectNoSensitiveRuntimeDetail(snapshot.message);
    expect(snapshot.canConnect, isFalse);
    expect(bindings.startCalls, 0);
  });

  test('desktop lane redacts disconnect errors', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-stop-error-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings(stopResult: _sensitiveRuntimeDetail);

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
    expect(snapshot.message, 'POKROV не смог отключиться.');
    _expectNoSensitiveRuntimeDetail(snapshot.message);
  });

  test('desktop lane redacts hostile probe failures', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-probe-redaction-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => _sensitiveRuntimeDetail,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'probe-redaction',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );
    final snapshot = await engine.connect();

    expect(snapshot.phase, RuntimePhase.configStaged);
    expect(snapshot.message, 'POKROV запустил модуль, но трафик не проходит.');
    expect(snapshot.lastFailureKind, 'core_egress_probe_failed');
    expect(bindings.stopCalls, 1);
    _expectNoSensitiveRuntimeDetail(snapshot.message);
    _expectNoSensitiveRuntimeDetail(snapshot.toString());
  });

  test(
      'desktop lane never reports running when proxy passes but Windows TUN fails',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-tun-probe-failure-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    var mixedProbeCalls = 0;
    var systemProbeCalls = 0;
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      mixedProxyProbe: () async {
        mixedProbeCalls += 1;
        return null;
      },
      systemTunnelProbe: () async {
        systemProbeCalls += 1;
        return 'host path unavailable';
      },
      bindingsLoader: (_) => bindings,
    );

    final staged = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'windows-tun-probe-failure',
        configPayload:
            '{"inbounds":[{"type":"tun","tag":"tun-in"},{"type":"mixed","tag":"mixed-in","listen":"127.0.0.1","listen_port":12334}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );
    final snapshot = await engine.connect();

    expect(mixedProbeCalls, 1);
    expect(systemProbeCalls, 3);
    expect(snapshot.phase, RuntimePhase.configStaged);
    expect(snapshot.lastFailureKind, 'desktop_tun_egress_probe_failed');
    expect(snapshot.message, contains('Windows не пропускает трафик'));
    expect(bindings.startCalls, 1);
    expect(bindings.stopCalls, 1);

    final refreshed = await engine.snapshot();
    expect(refreshed.phase, RuntimePhase.configStaged);
    expect(refreshed.lastFailureKind, 'desktop_tun_egress_probe_failed');
    expect(refreshed.message, contains('Windows не пропускает трафик'));
    expect(refreshed.message, isNot(contains('Профиль доступа готов')));
    final journal = File(
      '${File(staged.stagedConfigPath!).parent.parent.path}'
      '${Platform.pathSeparator}pokrov-runtime-events.jsonl',
    );
    expect(await journal.exists(), isTrue);
    final journalText = await journal.readAsString();
    expect(journalText, contains('"event":"egress"'));
    expect(journalText, contains('"probe":"mixed_proxy"'));
    expect(journalText, contains('"probe":"windows_tun"'));
    expect(journalText, contains('"event":"recovery"'));
    expect(journalText, contains('"attempt":3'));
    expect(
      journalText,
      contains('"failure_kind":"desktop_tun_egress_probe_failed"'),
    );
    _expectNoSensitiveRuntimeDetail(journalText);
  });

  test('desktop lane waits for a late Windows TUN route before passing',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-tun-probe-late-success-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    var systemProbeCalls = 0;
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      mixedProxyProbe: () async => null,
      systemTunnelProbe: () async {
        systemProbeCalls += 1;
        return systemProbeCalls < 3 ? 'host path not ready' : null;
      },
      bindingsLoader: (_) => bindings,
    );

    final staged = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'windows-tun-probe-late-success',
        configPayload:
            '{"inbounds":[{"type":"tun","tag":"tun-in"},{"type":"mixed","tag":"mixed-in","listen":"127.0.0.1","listen_port":12334}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );
    final snapshot = await engine.connect();

    expect(systemProbeCalls, 3);
    expect(snapshot.phase, RuntimePhase.running);
    expect(snapshot.lastFailureKind, isNull);
    expect(snapshot.hostHealth, RuntimeHostHealth.healthy);
    expect(snapshot.dnsState, RuntimeDiagnosticState.healthy);
    expect(snapshot.uplinkState, RuntimeDiagnosticState.healthy);
    expect(snapshot.dnsReady, isTrue);
    expect(snapshot.coreEgressValidated, isTrue);
    expect(snapshot.isCleanlyHealthy, isTrue);
    expect(bindings.startCalls, 1);
    expect(bindings.stopCalls, 0);

    final stopped = await engine.disconnect();
    expect(stopped.phase, RuntimePhase.configStaged);
    expect(stopped.hostHealth, RuntimeHostHealth.unknown);
    expect(stopped.dnsState, RuntimeDiagnosticState.unknown);
    expect(stopped.uplinkState, RuntimeDiagnosticState.unknown);
    expect(stopped.coreEgressValidated, isNull);
    final journal = File(
      '${File(staged.stagedConfigPath!).parent.parent.path}'
      '${Platform.pathSeparator}pokrov-runtime-events.jsonl',
    );
    final journalText = await journal.readAsString();
    for (final event in <String>[
      'initialization',
      'profile',
      'core_start',
      'tun',
      'routes',
      'dns',
      'egress',
      'recovery',
      'stop',
    ]) {
      expect(journalText, contains('"event":"$event"'));
    }
    expect(journalText, contains('"stop_reason":"completed"'));
    _expectNoSensitiveRuntimeDetail(journalText);
  });

  test('desktop lane classifies Windows TUN startup failures', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-tun-start-error-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings(
      startResult: 'start inbound/tun: create Wintun adapter failed',
    );
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'windows-tun-start-error',
        configPayload:
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
      ),
    );
    final snapshot = await engine.connect();

    expect(snapshot.phase, RuntimePhase.configStaged);
    expect(snapshot.lastFailureKind, 'desktop_tun_start_failed');
    expect(snapshot.message, contains('Закройте другие VPN'));
  });

  test('desktop lane blocks a known competing Windows VPN before Core start',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-competing-vpn-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      competingVpnProbe: () async => true,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'windows-competing-vpn',
        configPayload:
            '{"inbounds":[{"type":"tun","tag":"tun-in"}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );
    final snapshot = await engine.connect();

    expect(snapshot.phase, RuntimePhase.configStaged);
    expect(snapshot.lastFailureKind, 'desktop_competing_vpn_active');
    expect(snapshot.message, contains('Другой системный VPN'));
    expect(bindings.startCalls, 0);
  });

  test('desktop system-proxy mode ignores a competing TUN preflight', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-system-proxy-with-other-tun-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      competingVpnProbe: () async => true,
      mixedProxyProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'windows-system-proxy-with-other-tun',
        configPayload:
            '{"inbounds":[{"type":"mixed","listen":"127.0.0.1","listen_port":12334,"set_system_proxy":true}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );
    final snapshot = await engine.connect();

    expect(snapshot.phase, RuntimePhase.running);
    expect(bindings.startCalls, 1);
  });

  test('desktop system-proxy mode skips the Windows TUN-only probe', () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-system-proxy-success-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();
    var mixedProbeCalls = 0;
    var systemProbeCalls = 0;
    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      mixedProxyProbe: () async {
        mixedProbeCalls += 1;
        return null;
      },
      systemTunnelProbe: () async {
        systemProbeCalls += 1;
        return 'TUN probe must not run in system-proxy mode';
      },
      bindingsLoader: (_) => bindings,
    );

    final staged = await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'windows-system-proxy-success',
        configPayload:
            '{"inbounds":[{"type":"mixed","tag":"mixed-in","listen":"127.0.0.1","listen_port":12334,"set_system_proxy":true}],"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
      ),
    );
    final snapshot = await engine.connect();

    expect(mixedProbeCalls, 1);
    expect(systemProbeCalls, 0);
    expect(snapshot.phase, RuntimePhase.running);
    expect(snapshot.lastFailureKind, isNull);
    expect(bindings.startCalls, 1);
    expect(bindings.stopCalls, 0);
    final journal = File(
      '${File(staged.stagedConfigPath!).parent.parent.path}'
      '${Platform.pathSeparator}pokrov-runtime-events.jsonl',
    );
    expect(await journal.readAsString(), contains('"windows_system_proxy"'));
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

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    final staged = await engine.stageManagedProfile(
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

    final stagedText = await File(staged.stagedConfigPath!).readAsString();
    final config = jsonDecode(stagedText) as Map<String, dynamic>;
    expect(config.containsKey('endpoints'), isFalse);
    expect(stagedText, isNot(contains('test-private-key')));
    expect(stagedText, isNot(contains('test-access-token')));
  });

  test('desktop lane maps consented runtime-ready WARP into core endpoint',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'pokrov-runtime-desktop-warp-consent-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    final staged = await engine.stageManagedProfile(
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

    final config = jsonDecode(
      await File(staged.stagedConfigPath!).readAsString(),
    ) as Map<String, dynamic>;
    final endpoint =
        (config['endpoints'] as List<dynamic>).single as Map<String, dynamic>;
    final profile = endpoint['profile'] as Map<String, dynamic>;
    expect(endpoint['type'], 'warp');
    expect(endpoint['unique_identifier'], 'p1');
    expect(profile['id'], 'test-account-id');
    expect(profile['auth_token'], 'test-access-token');
    expect(profile['private_key'], 'test-private-key');
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

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
    final bindings = _FakeDesktopBindings();

    final engine = DesktopRuntimeEngine(
      hostPlatform: HostPlatform.windows,
      assetRootOverride: root.path,
      connectivityProbe: () async => null,
      bindingsLoader: (_) => bindings,
    );

    final staged = await engine.stageManagedProfile(
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

    final config = jsonDecode(
      await File(staged.stagedConfigPath!).readAsString(),
    ) as Map<String, dynamic>;
    final endpoint =
        (config['endpoints'] as List<dynamic>).single as Map<String, dynamic>;
    final profile = endpoint['profile'] as Map<String, dynamic>;
    expect(endpoint['type'], 'warp');
    expect(endpoint['unique_identifier'], 'p1');
    expect(profile.containsKey('id'), isFalse);
    expect(profile.containsKey('auth_token'), isFalse);
    expect(profile.containsKey('private_key'), isFalse);
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

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
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
    final config = jsonDecode(
      await File((await engine.snapshot()).stagedConfigPath!).readAsString(),
    ) as Map<String, dynamic>;
    final endpoint =
        (config['endpoints'] as List<dynamic>).single as Map<String, dynamic>;
    expect(endpoint['type'], 'warp');
    expect(endpoint['unique_identifier'], 'p1');
    expect(bindings.secureFileCalls, 2);
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

    final platformDirectory = Directory(p.join(root.path, 'windows'))
      ..createSync(recursive: true);
    File(p.join(platformDirectory.path, 'pokrov-core.dll'))
        .writeAsStringSync('stub');
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
        case 'runtimeEngine.stageManagedProfile':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/profile.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'staged',
          };
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
            'counterState': 'available',
            'uplinkBps': 10,
            'downlinkBps': 20,
            'uplinkTotalBytes': 1000,
            'downlinkTotalBytes': 2000,
            'latencyMs': 38,
            'since': '2026-06-22T10:00:00Z',
            'serverCode': 'nl-ams-01',
            'serverCountry': 'NL',
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

    final engine = MobileArtifactRuntimeEngine(
      hostPlatform: HostPlatform.android,
    );

    await engine.stageManagedProfile(
      const ManagedProfilePayload(
        profileName: 'mobile-warp',
        configPayload:
            '{"outbounds":[{"type":"vless","tag":"node"},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        warpPolicy: WarpRuntimePolicy.clientLocalDefault,
      ),
    );
    final applied = await engine.applyWarp(enabled: true);
    final stats = await engine.liveStats();
    final token = await engine.pushToken();

    expect(applied.applied, isTrue);
    expect(applied.effectiveAt, 'now');
    expect(stats.available, isTrue);
    expect(stats.counterState, RuntimeTrafficCounterState.available);
    expect(stats.downlinkBps, 20);
    expect(stats.uplinkTotalBytes, 1000);
    expect(stats.downlinkTotalBytes, 2000);
    expect(stats.serverCode, 'nl-ams-01');
    expect(stats.serverCountry, 'NL');
    expect(stats.protocol, 'sing-box');
    expect(token.token, 'push-token');
    expect(token.provider, 'fcm');
  });

  test('live stats expose explicit reset and reject unknown counter states',
      () {
    final reset = RuntimeLiveStats.fromMap(<String, Object?>{
      'available': true,
      'counter_state': 'reset',
      'uplink_total_bytes': 42,
      'downlink_total_bytes': 84,
    });
    final unknown = RuntimeLiveStats.fromMap(<String, Object?>{
      'available': false,
      'counterState': 'future_state',
    });

    expect(reset.counterState, RuntimeTrafficCounterState.reset);
    expect(reset.uplinkTotalBytes, 42);
    expect(reset.downlinkTotalBytes, 84);
    expect(unknown.counterState, RuntimeTrafficCounterState.unavailable);
  });

  test('mobile live stats retain only allowlisted public labels', () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var response = <String, Object?>{
      'available': true,
      'serverCode': 'NL-AMS-01',
      'serverCountry': 'nl',
      'protocol': 'sing-box',
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      return call.method == 'runtimeEngine.liveStats' ? response : null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final engine =
        MobileArtifactRuntimeEngine(hostPlatform: HostPlatform.android);
    final benign = await engine.liveStats();
    response = <String, Object?>{
      'available': true,
      'serverCode': _sensitiveRuntimeDetail,
      'serverCountry': _sensitiveRuntimeDetail,
      'protocol': _sensitiveRuntimeDetail,
    };
    final hostile = await engine.liveStats();

    expect(benign.serverCode, 'nl-ams-01');
    expect(benign.serverCountry, 'NL');
    expect(benign.protocol, 'sing-box');
    expect(hostile.serverCode, isEmpty);
    expect(hostile.serverCountry, isEmpty);
    expect(hostile.protocol, isEmpty);
    for (final value in <String>[
      hostile.serverCode,
      hostile.serverCountry,
      hostile.protocol,
      hostile.toString(),
    ]) {
      _expectNoSensitiveRuntimeDetail(value);
    }
  });
}
