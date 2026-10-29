import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

Map<String, dynamic> _withoutWallTime(Map snapshot) {
  final copy = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
  (copy['decision'] as Map).remove('at_ms');
  return copy;
}

int _advisedSlot(Map snapshot, Map bundle) {
  final decision = snapshot['decision'] as Map;
  final candidates = decision['candidates'] as List;
  // This QA path covers a fresh ordinary wave only. Recovery, family races,
  // remembered success and an already committed wave remain native policy.
  expect(snapshot['native_schedule_pending'], false);
  expect(snapshot['mandatory_preferred'], false);
  expect(decision['history'], isEmpty);
  expect(candidates.length,
      lessThanOrEqualTo(candidates.first['worker_parallelism']));
  for (final item in candidates) {
    expect(item['eligible'], true);
    expect(item['policy_fixed'], false);
    expect(item['last_good_current'], false);
    expect(item['recovery'], false);
    expect(item['family'], 'ipv4');
    expect(item['path_kind'], 'direct');
    expect(item['priority_group'], candidates.first['priority_group']);
    expect(item['selector_memory']['failed_self'], 0);
  }
  expect(
      _withoutWallTime(snapshot), _withoutWallTime(bundle['preaction'] as Map));
  final advice = bundle['decider_advice'] as Map;
  expect(advice['status'], 'advice');
  expect(advice['role'], 'candidate_choice');
  expect(advice['applied'], false);
  final probabilities = advice['probabilities'] as Map;
  final allowed = {
    for (final item in candidates) 'candidate_${item['candidate_ref']}'
  };
  expect(probabilities.keys.toSet(), allowed);
  expect(allowed, contains(advice['choice']));
  var total = 0.0;
  for (final probability in probabilities.values) {
    expect(probability, isA<num>());
    expect((probability as num).isFinite, true);
    expect(probability, inInclusiveRange(0, 1));
    expect(probabilities[advice['choice']], greaterThanOrEqualTo(probability));
    total += probability;
  }
  expect(total, closeTo(1, .01));
  return int.parse((advice['choice'] as String).substring('candidate_'.length));
}

/// Opt-in source-selector QA. The external helper owns actual native execution
/// on an owned guest and returns closed probe facts; no raw profile reaches Dart.
void main() {
  test('owned advice rejects native policy, changed state and unlisted choices',
      () {
    Map snapshot() => {
          'native_schedule_pending': false,
          'mandatory_preferred': false,
          'decision': {
            'at_ms': 10,
            'history': [],
            'candidates': [
              for (var slot = 0; slot < 2; slot++)
                {
                  'candidate_ref': slot,
                  'worker_parallelism': 4,
                  'eligible': true,
                  'policy_fixed': false,
                  'last_good_current': false,
                  'recovery': false,
                  'family': 'ipv4',
                  'path_kind': 'direct',
                  'priority_group': 0,
                  'priority': slot,
                  'selector_memory': {'failed_self': 0},
                },
            ]
          },
        };
    final bundle = {
      'preaction': snapshot(),
      'decider_advice': {
        'status': 'advice',
        'role': 'candidate_choice',
        'applied': false,
        'choice': 'candidate_1',
        'probabilities': {'candidate_0': .1, 'candidate_1': .9},
      }
    };
    expect(_advisedSlot(snapshot(), bundle), 1);
    final protected = snapshot();
    protected['decision']['candidates'][0]['recovery'] = true;
    expect(() => _advisedSlot(protected, bundle), throwsA(isA<TestFailure>()));
    final changed = snapshot();
    changed['decision']['candidates'][0]['priority'] = 4;
    expect(() => _advisedSlot(changed, bundle), throwsA(isA<TestFailure>()));
    (bundle['decider_advice'] as Map)['choice'] = 'candidate_9';
    expect(() => _advisedSlot(snapshot(), bundle), throwsA(isA<TestFailure>()));
  });
  final catalogPath = Platform.environment['POKROV_SELECTOR_QA_CATALOG'];
  final scriptPath = Platform.environment['POKROV_SELECTOR_QA_PROBE_SCRIPT'];
  final capturePath = Platform.environment['POKROV_SELECTOR_QA_CAPTURE'];
  final preactionPath = Platform.environment['POKROV_SELECTOR_QA_PREACTION'];
  final advicePath = Platform.environment['POKROV_SELECTOR_QA_ADVICE'];
  test('source selector captures completed owned native probes', () async {
    final exportOnly = preactionPath != null && advicePath == null;
    final bundle = advicePath == null
        ? null
        : jsonDecode(await File(advicePath).readAsString()) as Map;
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
    final cancelled = Completer<void>();
    Map<String, Object?>? initialSnapshot;
    Future<void>? snapshotWritten;
    int? advisedSlot;
    String? nativeSelectedRef;
    var stoppedAfterAdvisedFailure = false;
    int? nativeStartedAtMs;
    final caseClock = Stopwatch()..start();
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
          cancelled: cancelled.future,
          networkClass: 'ethernet',
          ipv6Available: false,
          probeTimeout: const Duration(seconds: 8),
          selectionTimeout: const Duration(seconds: 16),
          // Guest process setup/teardown is not native probe time. This is a data
          // capture harness, not a measurement of installed App Connect latency.
          excludeProbeCleanupFromBudget: true,
          prepare: preactionPath == null && bundle == null
              ? null
              : (candidate, stop) async {
                  final snapshot = observer.lastPreAction!;
                  final slot =
                      ((snapshot['decision'] as Map)['candidates'] as List)
                          .first['candidate_ref'];
                  try {
                    if (initialSnapshot == null) {
                      initialSnapshot = snapshot;
                      if (bundle != null)
                        advisedSlot = _advisedSlot(snapshot, bundle);
                      snapshotWritten = preactionPath == null
                          ? Future<void>.value()
                          : File(preactionPath)
                              .writeAsString(jsonEncode(snapshot))
                              .then((_) {});
                    }
                    await snapshotWritten;
                    if (exportOnly)
                      throw const SmartConnectSelectionExhausted();
                    if (helperError != null)
                      throw StateError('owned_advice_rejected');
                    if (slot == advisedSlot) {
                      nativeSelectedRef = candidate.candidateRef;
                      return;
                    }
                    // No counterfactual network label: other admitted slots remain
                    // in preparation until the one advised native attempt settles.
                    await stop;
                  } on SmartConnectSelectionExhausted {
                    rethrow;
                  } catch (error) {
                    helperError = error;
                    rethrow;
                  }
                },
          onProbeResult: (candidate, result) {
            if (bundle != null &&
                result.profile == null &&
                candidate.candidateRef == nativeSelectedRef) {
              stoppedAfterAdvisedFailure = true;
              cancelled.complete();
            }
          },
          probe: (candidate, cancelled, timeout) async {
            if (bundle != null)
              expect(candidate.candidateRef, nativeSelectedRef);
            nativeStartedAtMs ??= DateTime.now().millisecondsSinceEpoch;
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
    } catch (_) {
      if (!stoppedAfterAdvisedFailure) rethrow;
    }
    await observer.settled;
    expect(helperError, isNull);
    final rows =
        (await File(capturePath).readAsLines()).map(jsonDecode).toList();
    if (exportOnly) {
      expect(attempts, 0);
      expect(
          rows.every((row) => row['outcome']['native_started'] == false), true);
    } else if (bundle != null) {
      expect(attempts, 1);
      expect(
          rows.where((row) => row['outcome']['native_started'] == true).length,
          1);
    } else {
      expect(rows.length, attempts);
      expect(attempts, greaterThan(0));
    }
    // ignore: avoid_print
    print(jsonEncode({
      'native_attempts': attempts,
      'results': [for (final row in rows) row['outcome']['result']],
      'origin': exportOnly
          ? 'source_selector_preaction_only'
          : 'source_selector_with_owned_guest_native',
      'installed_app_acceptance': false,
      if (initialSnapshot != null)
        'advice_native_qa': {
          'export_only': exportOnly,
          'decider_choice': bundle?['decider_advice']['choice'],
          'decider_request_latency_ms': bundle?['decider_request_latency_ms'],
          'local_model': bundle?['local_model'],
          'native_outcome': exportOnly
              ? null
              : rows.singleWhere(
                  (row) => row['outcome']['native_started'] == true)['outcome'],
          'native_started_at_ms': nativeStartedAtMs,
          'source_preaction_at_ms':
              (initialSnapshot!['decision'] as Map)['at_ms'],
          'case_wall_ms': caseClock.elapsedMilliseconds,
          'applied_to_default_selector': false,
          'ready_within_live_backoff': false,
        }
    }));
  },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: catalogPath == null ||
              (scriptPath == null && preactionPath == null) ||
              capturePath == null
          ? 'Set POKROV_SELECTOR_QA_CATALOG, POKROV_SELECTOR_QA_PROBE_SCRIPT and POKROV_SELECTOR_QA_CAPTURE.'
          : false);
}
