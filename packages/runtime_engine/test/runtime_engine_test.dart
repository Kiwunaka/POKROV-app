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
  });

  int setupCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int secureFileCalls = 0;
  final String setupResult;

  @override
  String secureFile(String path) {
    secureFileCalls += 1;
    return '';
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
    return '';
  }

  @override
  String stop() {
    stopCalls += 1;
    return '';
  }
}

RuntimeSnapshot _runningSnapshot({
  required HostPlatform hostPlatform,
  bool? coreEgressValidated,
  String? effectiveProfileRevision,
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
    effectiveProfileSource: effectiveProfileRevision == null
        ? null
        : RuntimeProfileSource(
            revision: effectiveProfileRevision,
            origin: RuntimeProfileSourceOrigin.managedManifest,
          ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('mobile lane uses a native host bridge to initialize and stage profiles',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    String? stagedConfigPath;
    Map<Object?, Object?>? stagedArguments;
    final profileDigest = 'a'.padLeft(64, 'a');
    final leaseId = 'b'.padLeft(32, 'b');
    final selection = <String, Object?>{
      'service_id': 'gemini', 'lease_id': leaseId, 'selection_index': 0,
      'state': 'gateway', 'available': true,
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.readSmartAccessLeases':
          expect((call.arguments as Map)['profileDigest'], profileDigest);
          return <String, Object?>{
            'schema': 1, 'profileDigest': profileDigest,
            'leaseIdsJson': jsonEncode({
              'schema': 1, 'lease_ids': [leaseId], 'selections': [selection],
            }),
          };
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
          mode: 'warp_over_proxy',
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

    final control = engine as RuntimeSmartAccessBackgroundControl;
    expect((await control.readSmartAccessLeases(profileDigest))
        .selections['gemini']!.readiness, isNull);
    selection['readiness'] = null;
    expect((await control.readSmartAccessLeases(profileDigest))
        .selections['gemini']!.readiness, isNull);
    final stages = <Map<String, Object?>>[
      for (final stage in ['resolver', 'dns', 'tls'])
        {'stage': stage, 'result': 'pass', 'observed_at_ms': 1010,
         'duration_ms': 0},
    ];
    final readiness = <String, Object?>{
      'probe_id': 7, 'lease_id': leaseId, 'started_at_ms': 1000,
      'completed_at_ms': 1020, 'status': 'pass', 'stages': stages,
      'fallback_guard_closed': false,
    };
    selection['readiness'] = readiness;
    readiness['completed_at_ms'] = null;
    readiness['status'] = 'pending';
    readiness['stages'] = [stages.first];
    expect((await control.readSmartAccessLeases(profileDigest))
        .selections['gemini']!.readiness!.hasCompletedStagePasses, isFalse);
    readiness['completed_at_ms'] = 1020;
    readiness['status'] = 'pass';
    readiness['stages'] = stages;
    var observed = (await control.readSmartAccessLeases(profileDigest))
        .selections['gemini']!.readiness!;
    expect(observed.hasCompletedStagePasses, isTrue);
    expect(observed.probeId, 7);
    expect(observed.leaseId, leaseId);
    expect(observed.stages.map((stage) => stage.stage), ['resolver', 'dns', 'tls']);
    expect(observed.stages.last.durationMs, 0);

    stages.removeLast();
    await expectLater(control.readSmartAccessLeases(profileDigest), throwsStateError);
    stages.last['result'] = 'failure';
    stages.last['reason'] = 'dns_lookup';
    readiness['status'] = 'failure';
    readiness['fallback_guard_closed'] = true;
    observed = (await control.readSmartAccessLeases(profileDigest))
        .selections['gemini']!.readiness!;
    expect(observed.hasCompletedStagePasses, isFalse);
    expect(observed.stages.last.reason, 'dns_lookup');
    expect(observed.fallbackGuardClosed, isTrue);

    stages.last['reason'] = 'unknown_sensitive_reason';
    await expectLater(control.readSmartAccessLeases(profileDigest), throwsStateError);
    stages.last['reason'] = 'dns_lookup';
    readiness['unknown_field'] = 'sensitive';
    await expectLater(control.readSmartAccessLeases(profileDigest), throwsStateError);
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
            '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"direct","tag":"direct"}],"route":{"rules":[{"ip_is_private":true,"outbound":"direct"},{"protocol":"dns","action":"hijack-dns"}],"final":"direct"},"experimental":{"cache_file":{"enabled":true}},"_meta":{"title":"display only","local_dpi":{"catalog_envelope":"original signed bytes"},"runtime_variant_probe":{"group_tag":"probe","mappings":[{"id":"direct","outbound_tag":"direct"}]}}}',
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
      'local_dpi': <String, dynamic>{'catalog_envelope': 'original signed bytes'},
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

  test('running egress failure preserves its observation without claiming a stop',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final cases = <String, String>{
      'core_egress_probe_failed': 'POKROV не подтвердил защищенное подключение',
      'core_egress_connect_failed': 'Не удалось соединиться с сервером проверки',
      'core_egress_tls_timeout': 'Согласование TLS с сервером проверки не завершилось вовремя',
      'core_egress_probe_unavailable': 'POKROV не завершил проверку защищенного подключения',
    };
    for (final entry in cases.entries) {
      messenger.setMockMethodCallHandler(channel, (call) async => {
            'phase': 'running',
            'last_failure_kind': entry.key,
            'core_egress_validated': false,
          });
      final snapshot =
          await createRuntimeEngine(hostPlatform: HostPlatform.android).snapshot();
      expect(snapshot.phase, RuntimePhase.running);
      expect(snapshot.lastFailureKind, entry.key);
      expect(snapshot.isCleanlyHealthy, isFalse);
      expect(snapshot.message, contains(entry.value));
      expect(snapshot.message, isNot(contains('отключил')));
      expect(snapshot.message, contains('VPN остаётся включённым'));
    }
  });

  test('mobile lane redacts native runtime details from public snapshots',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var nativeFailure = _sensitiveRuntimeDetail;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.snapshot') {
        return <String, Object?>{
          'phase': 'running',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': _sensitiveRuntimeDetail,
          'default_network_interface': _sensitiveRuntimeDetail,
          'last_failure_kind': nativeFailure,
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
    final closed = <String, String?>{};
    for (final kind in ['core_start_failed', 'local_dpi_withdraw_failed',
        'recovery_network_restore_failed']) {
      nativeFailure = kind;
      final windows = await createRuntimeEngine(hostPlatform: HostPlatform.windows).snapshot();
      closed[kind] = windows.lastFailureKind;
      _expectNoSensitiveRuntimeDetail(windows.message);
    }
    expect(closed, {
      'core_start_failed': 'core_start_failed',
      'local_dpi_withdraw_failed': 'local_dpi_withdraw_failed',
      'recovery_network_restore_failed': 'recovery_network_restore_failed',
    });
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
    expect(snapshot.protectionRetained, isFalse);
    expect(snapshot.phase, RuntimePhase.artifactReady);
    expect(snapshot.helperBinaryPath, 'service://pokrov_service.exe');
    expect(snapshot.coreBinaryPath, isNull);
    expect(snapshot.canInitialize, isTrue);
    expect(snapshot.coreEgressValidated, isFalse);
    expect(snapshot.isCleanlyHealthy, isFalse);
    expect(calls, ['runtimeEngine.snapshot']);
    expect(snapshot.windowsLocalDpiAdmissionVersion, 0);
    messenger.setMockMethodCallHandler(channel, (call) async => <String, Object?>{
          'phase': 'configStaged',
          'canConnect': true,
          'coreEgressValidated': false,
          'dnsReady': false,
          'lastFailureKind': 'core_egress_response_timeout',
          'protectionRetained': true,
          'windowsLocalDpiAdmissionVersion': 1,
        });
    final failed = await engine.snapshot();
    expect(failed.windowsLocalDpiAdmissionVersion, 1);
    expect(failed.lastFailureKind, 'core_egress_response_timeout');
    expect(failed.protectionRetained, isTrue);
    expect(failed.hasCoreEgressProbeFailure, isTrue);
    expect(failed.isCleanlyHealthy, isFalse);
    expect(failed.message,
        'Сервер проверки не ответил вовремя после установки соединения. POKROV отключил VPN. Причина не установлена.');
  });

  test('windows DPI runtime observation decodes by value and stays unknown when invalid',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final response = <String, Object?>{'phase': 'running'};
    messenger.setMockMethodCallHandler(channel, (call) async => response);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final engine = createRuntimeEngine(hostPlatform: HostPlatform.windows);
    expect((await engine.snapshot()).windowsLocalDpiRuntime, isNull);

    final observation = <String, int>{
      'services': 1,
      'admitted': 0,
      'failed': 0,
      'withdraw_completed': 1,
      'local_handoffs': 2,
      'vpn_handoffs': 0,
    };
    response['windowsLocalDpiRuntime'] = observation;
    final withdrawn = await engine.snapshot();
    expect(withdrawn.windowsLocalDpiRuntime?.withdrawCompleted, 1);
    expect(withdrawn.windowsLocalDpiRuntime?.localHandoffs, 2);
    expect(withdrawn.hasSameStateAs(await engine.snapshot()), isTrue);

    observation['vpn_handoffs'] = 1;
    final vpnObserved = await engine.snapshot();
    expect(vpnObserved.windowsLocalDpiRuntime?.vpnHandoffs, 1);
    expect(withdrawn.hasSameStateAs(vpnObserved), isFalse);
    expect(withdrawn.windowsLocalDpiRuntime?.vpnHandoffs, 0);

    response['connectionPending'] = true;
    expect((await engine.snapshot()).windowsLocalDpiRuntime, isNull);
    response['connectionPending'] = false;
    observation['admitted'] = 1;
    expect((await engine.snapshot()).windowsLocalDpiRuntime, isNull);
  });

  test('negative bound Connect preserves the matched native cause through failed cleanup', () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final core = 'a' * 64;
    final profile = 'b' * 64;
    const boot = 'windows:0123456789abcdef0123456789abcdef';
    String? requestId;
    var stopConfirmed = false;
    var stops = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map? ?? {};
      if (call.method == 'runtimeEngine.clockSnapshot') {
        return {'schema': 1, 'boot_ref': boot, 'elapsed_ms': 1000, 'quantum_ms': 1};
      }
      if (call.method == 'runtimeEngine.connectWithCoreIdentity') {
        requestId = args['requestId'] as String;
        throw PlatformException(code: 'core_identity_connect_failed', message: _sensitiveRuntimeDetail,
          details: {'schema': 1, 'requestId': requestId, 'operation': 'core_connect',
            'nativePhase': 'config_staged', 'failureKind': 'core_egress_tls_failed',
            'moduleMatches': true, 'profileMatches': true});
      }
      if (call.method == 'runtimeEngine.cancelAndConfirmConnectStopped') {
        expect(args['requestId'], requestId);
        stops++;
        return {'schema': 1, 'requestId': requestId, 'settled': stopConfirmed};
      }
      throw StateError('unexpected_test_runtime_call');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final engine = createRuntimeEngine(hostPlatform: HostPlatform.windows);
    try {
      Object? failure;
      try {
        await (engine as RuntimeCoreIdentityConnect).connectWithCoreIdentity(
          expectedCoreModuleSha256: core, expectedProfileDigest: profile,
          expectedNetworkContextRef: 'network_0123456789abcdef0123456789abcdef',
          budgetStartedAt: RuntimeBootClockSnapshot.fromWire(
            {'schema': 1, 'boot_ref': boot, 'elapsed_ms': 1000, 'quantum_ms': 1}, HostPlatform.windows),
          budget: const Duration(seconds: 18), onRequestCreated: (_) {});
      } on Object catch (error) { failure = error; }
      expect(stops, 1);
      expect((engine as RuntimeConnectCancellation).activeConnectRequestId, requestId,
        reason: 'unconfirmed cleanup must retain the exact owner');
      expect(failure, isA<RuntimeBoundConnectFailure>()
        .having((value) => value.failureKind, 'primary cause', 'core_egress_tls_failed')
        .having((value) => value.nativePhase, 'native phase', 'config_staged')
        .having((value) => value.moduleMatches && value.profileMatches, 'identity matched', isTrue)
        .having((value) => value.cleanupConfirmed, 'cleanup', isFalse));
      expect(failure.toString(), contains('core_egress_tls_failed'));
      expect(failure.toString(), contains('core_identity_connect_cancel_unconfirmed'));
      _expectNoSensitiveRuntimeDetail(failure.toString());
    } finally {
      stopConfirmed = true;
      if (requestId != null) {
        expect(await (engine as RuntimeConnectSettlement).cancelAndConfirmConnectStopped(requestId!), isTrue);
      }
    }
  });

  test('windows profile mismatch remains unprotected with explicit recovery',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final digest = 'a' * 64;
    messenger.setMockMethodCallHandler(
        channel,
        (call) async => <String, Object?>{
              'phase': 'configStaged',
              'supportsLiveConnect': true,
              'canConnect': false,
              'lastFailureKind': 'profile_identity_mismatch',
              'coreEgressValidated': false,
              'coreEgressValidationRequired': true,
              'stagedProfileDigest': digest,
              'effectiveProfileDigest': '',
              'profileIdentityOrigin': 'windows_service_stage_request_sha256',
            });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final engine = createRuntimeEngine(hostPlatform: HostPlatform.windows);
    final snapshot = await engine.connect();
    expect(snapshot.stagedProfileDigest, digest);
    expect(snapshot.effectiveProfileDigest, isNull);
    expect(
        snapshot.profileIdentityOrigin, 'windows_service_stage_request_sha256');
    expect(snapshot.isCleanlyHealthy, isFalse);
    expect(snapshot.canConnect, isFalse);
    expect(snapshot.message, contains('Изменение профиля не применено'));
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

}

