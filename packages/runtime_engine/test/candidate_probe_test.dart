import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('space.pokrov/runtime_engine');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
      'candidate probe uses the exact WARP chain and leaves ordinary payload alone',
      () async {
    const base =
        '{"outbounds":[{"type":"vless","tag":"node"},{"type":"direct","tag":"direct"}],"route":{"final":"node"}}';
    final sent = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent.add((call.arguments as Map)['configContent'] as String);
      return {'success': true, 'failure_kind': '', 'duration_ms': 1};
    });
    final runtime =
        MobileArtifactRuntimeEngine(hostPlatform: HostPlatform.android);
    for (final mode in ['proxy_over_warp', 'warp_over_proxy']) {
      await runtime.probeCandidate(
          probeId: 'candidate-$mode',
          payload: ManagedProfilePayload(
              profileName: 'candidate',
              configPayload: base,
              warpPolicy: WarpRuntimePolicy(
                  enabled: true,
                  runtimeReady: true,
                  userConsented: true,
                  state: 'consented',
                  source: 'client_local',
                  mode: mode)),
          timeout: const Duration(seconds: 3),
          expectedNetworkContext: 'network-context');
    }
    await runtime.probeCandidate(
        probeId: 'candidate-ordinary',
        payload: const ManagedProfilePayload(
            profileName: 'candidate', configPayload: base),
        timeout: const Duration(seconds: 3),
        expectedNetworkContext: 'network-context');
    final before = jsonDecode(sent[0]) as Map<String, dynamic>;
    final after = jsonDecode(sent[1]) as Map<String, dynamic>;
    expect((before['route'] as Map)['final'], 'node');
    expect(
        ((before['outbounds'] as List).first as Map)['detour'], 'pokrov-warp');
    expect(((after['endpoints'] as List).single as Map)['detour'], 'node');
    expect((after['route'] as Map)['final'], 'pokrov-warp');
    expect(sent[2], base);
  });

  test('Windows selected-apps probe targets the protected process outbound',
      () async {
    const config =
        '{"outbounds":[{"type":"selector","tag":"🌍 Страны","outbounds":["de"]},'
        '{"type":"direct","tag":"direct"}],"route":{"final":"direct",'
        '"rules":[{"process_name":["discord.exe"],"outbound":"🌍 Страны"}]}}';
    String? probedConfig;
    messenger.setMockMethodCallHandler(channel, (call) async {
      probedConfig = (call.arguments as Map)['configContent'] as String;
      return {'success': true, 'failure_kind': '', 'duration_ms': 1};
    });
    final runtime =
        MobileArtifactRuntimeEngine(hostPlatform: HostPlatform.windows);
    await runtime.probeCandidate(
        probeId: 'candidate-selected-apps',
        payload: const ManagedProfilePayload(
            profileName: 'candidate',
            configPayload: config,
            routeMode: RouteMode.selectedApps),
        timeout: const Duration(seconds: 3),
        expectedNetworkContext: 'network-context');
    final probed = jsonDecode(probedConfig!) as Map<String, dynamic>;
    expect((probed['route'] as Map)['final'], '🌍 Страны');
    expect((jsonDecode(config)['route'] as Map)['final'], 'direct');
  });

  test('candidate cancellation awaits native settlement without staging TUN',
      () async {
    final cancellationStarted = Completer<void>();
    final nativeSettled = Completer<void>();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'runtimeEngine.probeCandidate') {
        expect((call.arguments as Map)['expectedNetworkContext'],
            'network-context');
        await nativeSettled.future;
        return {
          'success': false,
          'failure_kind': 'cancelled',
          'duration_ms': 4
        };
      }
      if (call.method == 'runtimeEngine.cancelCandidateProbe') {
        cancellationStarted.complete();
        await nativeSettled.future;
        return null;
      }
      fail('candidate probe called ${call.method}');
    });
    final runtime =
        MobileArtifactRuntimeEngine(hostPlatform: HostPlatform.android);
    final probe = runtime.probeCandidate(
        probeId: 'candidate-1',
        payload: const ManagedProfilePayload(
            profileName: 'candidate', configPayload: '{}'),
        timeout: const Duration(seconds: 3),
        expectedNetworkContext: 'network-context');
    var cancelReturned = false;
    final cancel = runtime
        .cancelCandidateProbe('candidate-1')
        .then((_) => cancelReturned = true);
    await cancellationStarted.future;
    expect(cancelReturned, false);
    nativeSettled.complete();
    await cancel;
    expect((await probe).failureKind, 'cancelled');
    expect(calls,
        ['runtimeEngine.probeCandidate', 'runtimeEngine.cancelCandidateProbe']);
  });

  test('candidate bridge accepts only a safe result and nullable OS facts',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.candidateNetwork') {
        return {
          'selection_key': 'uplink-stable',
          'context_ref': 'context-new',
          'network_class': 'ethernet',
          'mcc_mnc': 'not-a-code',
          'network_available': true,
          'ipv6_available': false,
          'captive_portal': null
        };
      }
      return {
        'success': true,
        'failure_kind': 'raw native detail',
        'duration_ms': 3
      };
    });
    final runtime =
        MobileArtifactRuntimeEngine(hostPlatform: HostPlatform.windows);
    final network = await runtime.readCandidateNetwork();
    expect(network.selectionKey, 'uplink-stable');
    expect(network.networkClass, 'ethernet');
    expect(network.mccMnc, isNull);
    expect(network.networkAvailable, true);
    expect(network.ipv6Available, false);
    expect(network.captivePortal, null);
    final result = await runtime.probeCandidate(
        probeId: 'candidate-2',
        payload: const ManagedProfilePayload(
            profileName: 'candidate', configPayload: '{}'),
        timeout: const Duration(seconds: 3),
        expectedNetworkContext: 'context-new');
    expect(result, RuntimeCandidateProbeResult.unavailable);
  });

  test('candidate bridge retains closed native stages and accepts stage-less replies', () async {
    Object? nativeStage;
    Object? nativeHttp64kFailure;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'runtimeEngine.probeCandidate');
      return jsonEncode({
        'success': false,
        'failure_kind': 'probe_failed',
        'duration_ms': 777,
        if (nativeStage != null) 'stage': nativeStage,
        if (nativeHttp64kFailure != null) 'http_64k_failure': nativeHttp64kFailure,
      });
    });
    final runtime = MobileArtifactRuntimeEngine(hostPlatform: HostPlatform.windows);
    final stages = <String?>[];
    for (final stage in ['proxy_dial', 'tls_read', 'unknown_phase', null]) {
      nativeStage = stage;
      final result = await runtime.probeCandidate(
        probeId: 'candidate-stage',
        payload: const ManagedProfilePayload(profileName: 'candidate', configPayload: '{}'),
        timeout: const Duration(seconds: 3),
        expectedNetworkContext: 'network-context',
      );
      expect(result.success, false);
      expect(result.failureKind, 'probe_failed');
      expect(result.duration, const Duration(milliseconds: 777));
      stages.add(result.probeStage);
    }
    expect(stages, ['proxy_dial', 'tls_read', null, null]);
    nativeStage = 'http_64k';
    nativeHttp64kFailure = 'body_short';
    Future<RuntimeCandidateProbeResult> detailedProbe() => runtime.probeCandidate(
      probeId: 'candidate-http-detail',
      payload: const ManagedProfilePayload(profileName: 'candidate', configPayload: '{}'),
      timeout: const Duration(seconds: 3), expectedNetworkContext: 'network-context',
    );
    final detailed = await detailedProbe();
    expect((detailed.failureKind, detailed.probeStage, detailed.http64kFailure),
        ('probe_failed', 'http_64k', 'body_short'));
    nativeHttp64kFailure = 'unknown_detail';
    final unknown = await detailedProbe();
    expect((unknown.failureKind, unknown.http64kFailure), ('probe_failed', null));
  });

  test('candidate bridge preserves cellular carrier and Core data stall', () async {
    var carrier = ' Test Carrier ';
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.candidateNetwork') {
        return {
          'selection_key': 'android:cellular:25099',
          'context_ref': 'context-cellular',
          'network_class': 'cellular',
          'mcc_mnc': '25099',
          'carrier': carrier,
        };
      }
      return {'success': false, 'failure_kind': 'data_stalled', 'duration_ms': 2000};
    });
    final runtime = MobileArtifactRuntimeEngine(hostPlatform: HostPlatform.android);
    final network = await runtime.readCandidateNetwork();
    expect(network.carrierName, 'Test Carrier');
    expect(network.ipv6Available, isNull);
    carrier = List.filled(81, 'x').join();
    expect((await runtime.readCandidateNetwork()).carrierName, isNull);
    final result = await runtime.probeCandidate(
      probeId: 'candidate-stalled',
      payload: const ManagedProfilePayload(profileName: 'candidate', configPayload: '{}'),
      timeout: const Duration(seconds: 3),
      expectedNetworkContext: 'context-cellular',
    );
    expect(result.failureKind, 'data_stalled');
  });
}
