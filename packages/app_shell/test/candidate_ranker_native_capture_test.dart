import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

/// Opt-in source-selector QA. The external helper owns actual native execution
/// on an owned guest and returns closed probe facts; no raw profile reaches Dart.
void main() {
  final catalogPath = Platform.environment['POKROV_SELECTOR_QA_CATALOG'];
  final scriptPath = Platform.environment['POKROV_SELECTOR_QA_PROBE_SCRIPT'];
  final capturePath = Platform.environment['POKROV_SELECTOR_QA_CAPTURE'];
  test('source selector captures completed owned native probes', () async {
    final input = jsonDecode(await File(catalogPath!).readAsString())
        as Map<String, dynamic>;
    expect(input['metadata_only'], true);
    expect(input['references_are_local_equality_aliases'], true);
    final candidates = [
      for (final raw in input['candidates'] as List)
        TransportCandidate(
            candidateRef: raw['candidate_ref'],
            profileRef: raw['profile_ref'],
            nodeCode: raw['node_code'],
            countryCode: 'ZZ',
            protocol: raw['protocol'],
            transport: raw['transport'],
            protection: raw['protection'],
            priority: raw['priority'],
            network: raw['network'],
            family: raw['family'],
            flow: '',
            bridgeId:
                raw['bridge_present'] == true ? raw['candidate_ref'] : null,
            minimumClientRelease: '1.5.0',
            minimumCoreRelease: null,
            platforms: {HostPlatform.windows},
            requiredFeatures: {})
    ];
    final observer = CandidateRankerShadow.capture(capturePath!);
    final selector = SmartConnectCandidateSelector(rankerShadow: observer);
    var attempts = 0;
    Object? helperError;
    try {
      await selector.select(
          catalog: TransportCandidateCatalog(
              revision: 'owned-native',
              selectedCandidateRef: candidates.first.candidateRef,
              candidates: candidates),
          network: 'owned-native-network',
          contextGeneration: 'owned-native-context',
          platform: HostPlatform.windows,
          cancelled: Completer<void>().future,
          networkClass: 'ethernet',
          ipv6Available: false,
          probeTimeout: const Duration(seconds: 8),
          selectionTimeout: const Duration(seconds: 16),
          // Guest process setup/teardown is not native probe time. This is a data
          // capture harness, not a measurement of installed App Connect latency.
          excludeProbeCleanupFromBudget: true,
          probe: (candidate, cancelled, timeout) async {
            attempts++;
            try {
              final process = await Process.run('pwsh.exe', [
                '-NoProfile',
                '-File',
                scriptPath!,
                '-Slot',
                candidate.candidateRef,
                '-TimeoutMs',
                '${timeout.inMilliseconds}'
              ]);
              expect(process.exitCode, 0,
                  reason: 'Owned native helper did not settle cleanly');
              final row =
                  jsonDecode(process.stdout as String) as Map<String, dynamic>;
              expect(row['probe_contract'], 'owned_204_64k');
              expect(row['origin'],
                  anyOf('natural_owned', 'controlled_fault_injection'));
              expect(row['core_version'], matches(r'^\d+\.\d+\.\d+$'));
              expect(row['duration_ms'], isA<int>());
              final duration =
                  Duration(milliseconds: row['duration_ms'] as int);
              return row['success'] == true
                  ? SmartConnectCandidateProbeResult.success(
                      ManagedProfilePayload(
                          profileName: candidate.candidateRef,
                          configPayload: '{}'),
                      duration: duration,
                      probeStage: row['stage'])
                  : SmartConnectCandidateProbeResult.failure(
                      row['failure_kind'],
                      duration: duration,
                      probeStage: row['stage']);
            } catch (error) {
              helperError = error;
              rethrow;
            }
          });
    } on SmartConnectSelectionExhausted {
      // Exhaustion is a measured QA outcome, not a test harness failure.
    }
    await observer.settled;
    expect(helperError, isNull);
    final rows =
        (await File(capturePath).readAsLines()).map(jsonDecode).toList();
    expect(rows.length, attempts);
    expect(attempts, greaterThan(0));
    // ignore: avoid_print
    print(jsonEncode({
      'native_attempts': attempts,
      'results': [for (final row in rows) row['outcome']['result']],
      'origin': 'source_selector_with_owned_guest_native',
      'installed_app_acceptance': false
    }));
  },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: catalogPath == null || scriptPath == null || capturePath == null
          ? 'Set POKROV_SELECTOR_QA_CATALOG, POKROV_SELECTOR_QA_PROBE_SCRIPT and POKROV_SELECTOR_QA_CAPTURE.'
          : false);
}
