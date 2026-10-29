import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

/// These are synthetic native outcomes through the actual app scheduler.
/// No Core instance, socket, profile credential, TUN or device is used.
Future<bool> _settleDelay(Duration duration, Future<void> cancelled) async {
  final settled = Completer<bool>();
  final timer = Timer(duration, () => settled.complete(true));
  unawaited(cancelled.then((_) {
    if (!settled.isCompleted) settled.complete(false);
  }));
  try {
    return await settled.future;
  } finally {
    timer.cancel();
  }
}

List<TransportCandidate> _ordinaryCatalog(Map<String, dynamic> input) {
  if (input['metadata_only'] != true || input['references_are_local_equality_aliases'] != true) {
    throw const FormatException('Only a sanitized metadata catalog is accepted');
  }
  return [for (final raw in input['candidates'] as List)
    if (raw['warp_mode'] == null && !{'dnstt', 'slipstream'}.contains(raw['transport']))
      TransportCandidate(
        candidateRef: raw['candidate_ref'], profileRef: raw['profile_ref'], nodeCode: raw['node_code'],
        // Auto-all-countries does not inspect this anonymous fixture field.
        countryCode: 'ZZ', protocol: raw['protocol'], transport: raw['transport'],
        protection: raw['protection'], priority: raw['priority'],
        network: raw['parameters']['network'], flow: '',
        family: raw['parameters']['family'] ?? 'ipv4',
        bridgeId: raw['parameters']['bridge_present'] == true
            ? raw['parameters']['bridge_alias'] : null,
        deliveryEndpointId: raw['parameters']['delivery_endpoint_present'] == true ? 'typed' : null,
        minimumClientRelease: raw['requirements']['minimum_client_release'],
        minimumCoreRelease: raw['requirements']['minimum_core_release'],
        platforms: {for (final value in raw['requirements']['platforms'])
          HostPlatform.values.singleWhere((platform) => platform.name == value)},
        requiredFeatures: {for (final value in raw['requirements']['required_features'])
          RuntimeTransportFeature.values.singleWhere((feature) => feature.wireName == value)},
      )];
}

Future<Map<String, Object?>> _runScenario(List<TransportCandidate> candidates,
    {required bool directTcpFails}) async {
  final selector = SmartConnectCandidateSelector();
  final clock = Stopwatch()..start();
  final events = <Map<String, Object?>>[];
  final activeNative = <String>{};
  var maximumNative = 0;
  void record(String event, TransportCandidate candidate, {String? result, int? budget}) {
    events.add({'event': event, 'at_ms': clock.elapsedMilliseconds,
      'candidate_alias': candidate.candidateRef,
      'path_kind': candidate.bridgeId == null ? 'direct' : 'bridge',
      'protocol': candidate.protocol, 'transport': candidate.transport,
      'family': candidate.family, 'network': candidate.network,
      if (result != null) 'result': result, if (budget != null) 'budget_ms': budget});
  }
  final selected = await selector.select(
    catalog: TransportCandidateCatalog(revision: 'controlled-global-auto',
      selectedCandidateRef: candidates.first.candidateRef, candidates: candidates),
    network: 'controlled-selection-key', contextGeneration: 'controlled-physical-generation',
    platform: HostPlatform.windows, cancelled: Completer<void>().future,
    probeTimeout: const Duration(seconds: 4), selectionTimeout: const Duration(seconds: 12),
    prepare: (candidate, cancelled) async {
      record('prepare_start', candidate);
      final finished = await _settleDelay(const Duration(milliseconds: 40), cancelled);
      record('prepare_end', candidate, result: finished ? 'ready' : 'cancelled');
    },
    probe: (candidate, cancelled, timeout) async {
      activeNative.add(candidate.candidateRef);
      if (activeNative.length > maximumNative) maximumNative = activeNative.length;
      record('native_start', candidate, budget: timeout.inMilliseconds);
      final bridge = candidate.bridgeId != null;
      final fails = bridge || directTcpFails && candidate.network == 'tcp';
      final duration = Duration(milliseconds: bridge ? 25 : fails ? 600 : 120);
      try {
        final completed = await _settleDelay(duration, cancelled);
        if (!completed) {
          record('native_cancel', candidate);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          record('native_finish', candidate, result: 'cancelled');
          return const SmartConnectCandidateProbeResult.failure('cancelled', probeStage: 'proxy_dial');
        }
        record('native_finish', candidate, result: fails ? 'connect_failed' : 'pass');
        return fails
            ? SmartConnectCandidateProbeResult.failure('connect_failed', duration: duration, probeStage: 'proxy_dial')
            : SmartConnectCandidateProbeResult.success(ManagedProfilePayload(
                profileName: candidate.candidateRef, configPayload: '{}'),
                duration: duration, probeStage: 'http_64k');
      } finally {
        activeNative.remove(candidate.candidateRef);
      }
    },
  );
  clock.stop();
  expect(activeNative, isEmpty, reason: 'Selection must join all native cleanup');
  expect(maximumNative, lessThanOrEqualTo(4));
  final bridgeFinished = events.where((row) => row['event'] == 'native_finish' && row['path_kind'] == 'bridge');
  final directPrepared = events.where((row) => row['event'] == 'prepare_start' && row['path_kind'] == 'direct');
  expect(bridgeFinished.length, candidates.where((candidate) => candidate.bridgeId != null).length);
  expect(directPrepared.first['at_ms'] as int, greaterThanOrEqualTo(bridgeFinished.last['at_ms'] as int));
  return {
    'origin': 'synthetic_scheduler_fixture', 'native_network_used': false,
    'policy': 'existing', 'scenario': directTcpFails ? 'global_tcp_failure' : 'isolated_bridge_failure',
    'platform': 'windows', 'workers': 4, 'probe_budget_ms': 4000, 'native_worker_budget_ms': 12000,
    'timings_ms': {'prepare': 40, 'bridge_failure': 25, 'direct_tcp_failure': 600,
      'healthy_direct': 120, 'cancel_cleanup': 20},
    'selected_alias': selected.profileName, 'elapsed_ms': clock.elapsedMilliseconds,
    'maximum_native_concurrency': maximumNative,
    'native_probes': events.where((row) => row['event'] == 'native_start').length,
    'first_direct_wave': directPrepared.take(4).map((row) => row['candidate_alias']).toList(),
    'events': events,
  };
}

void main() {
  final catalogPath = Platform.environment['POKROV_RANKER_CATALOG'];
  final outputPrefix = Platform.environment['POKROV_RANKER_TRACE_PREFIX'];
  test('actual global Auto scheduler records the fixed matched scenarios', () async {
    final raw = jsonDecode(await File(catalogPath!).readAsString()) as Map<String, dynamic>;
    final candidates = _ordinaryCatalog(raw);
    for (final fails in [true, false]) {
      final trace = await _runScenario(candidates, directTcpFails: fails);
      await File('$outputPrefix-${trace['scenario']}-baseline.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(trace));
      // ignore: avoid_print
      print(jsonEncode({...trace}..remove('events')));
    }
  }, timeout: const Timeout(Duration(minutes: 1)),
      skip: catalogPath == null || outputPrefix == null
          ? 'Set POKROV_RANKER_CATALOG and POKROV_RANKER_TRACE_PREFIX for the owned catalog replay.' : false);
}
