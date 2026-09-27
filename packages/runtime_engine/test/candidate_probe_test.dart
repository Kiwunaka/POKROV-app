import 'dart:async';

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
          'network_available': true,
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
    expect(network.networkAvailable, true);
    expect(network.captivePortal, null);
    final result = await runtime.probeCandidate(
        probeId: 'candidate-2',
        payload: const ManagedProfilePayload(
            profileName: 'candidate', configPayload: '{}'),
        timeout: const Duration(seconds: 3),
        expectedNetworkContext: 'context-new');
    expect(result, RuntimeCandidateProbeResult.unavailable);
  });
}
