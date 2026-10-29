import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_app_shell/app_shell.dart' as shell;
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

class _UnusedRuntime extends Fake implements PokrovRuntimeEngine {}
class _UnusedBootstrapper extends Fake implements ManagedProfileBootstrapper {}

shell.ConnectionManager manager(Future<CandidateRankerShadow> model) => shell.ConnectionManager(
  appContext: shell.buildSeedAppContext(hostPlatform: HostPlatform.android),
  runtimeEngine: _UnusedRuntime(), bootstrapper: _UnusedBootstrapper(),
  accountSessionCoordinator: shell.AccountSessionCoordinator(accountActions: null),
  firstSessionCoordinator: shell.FirstSessionCoordinator(store: const shell.PokrovFileFirstLaunchStore()),
  clientExperienceStore: const shell.PokrovFileClientExperienceStore(),
  connectHintStore: const shell.PokrovFileConnectHintStore(), candidateRankerShadow: model,
  authorizeAndroidConnect: () async => true, refreshSubscription: () async => true,
  onNotice: (_, __) {},
);

TransportCandidate candidate(String transport, int priority,
    {String family = 'ipv4', String? bridge}) => TransportCandidate(
  candidateRef: 'private-node:$transport:$priority', profileRef: 'private-profile',
  nodeCode: 'private-node', countryCode: 'CH', protocol: 'vless',
  transport: transport, protection: transport == 'dnstt' ? 'noise' : 'tls',
  priority: priority, network: 'tcp', flow: '', minimumClientRelease: '1.5.0',
  minimumCoreRelease: null, family: family, bridgeId: bridge,
  platforms: {HostPlatform.android, HostPlatform.windows}, requiredFeatures: {},
);

CandidateRankerModel zeroModel() {
  final bytes = Uint8List(8 + 933700 * 4);
  bytes.setRange(0, 8, 'PKRTF001'.codeUnits);
  return CandidateRankerModel.fromBytes(bytes);
}

SmartConnectCandidateProbeResult success(TransportCandidate candidate) =>
    SmartConnectCandidateProbeResult.success(ManagedProfilePayload(
      profileName: candidate.candidateRef, configPayload: '{}'),
      duration: const Duration(milliseconds: 12), probeStage: 'http_64k');

Future<CandidateRankerComparison> exercise(CandidateRankerModel model) async {
  var at = DateTime.utc(2026, 10, 29);
  final shadow = CandidateRankerShadow(model);
  final selector = SmartConnectCandidateSelector(now: () => at, rankerShadow: shadow);
  final first = candidate('dnstt', 0);
  final second = candidate('slipstream', 1);
  final excluded = candidate('dnstt', 2);
  final ipv6 = candidate('slipstream', 3, family: 'ipv6');
  final laterGroup = candidate('dnstt', 4, bridge: 'private-bridge');
  final catalog = TransportCandidateCatalog(revision: 'catalog-1',
      selectedCandidateRef: first.candidateRef,
      candidates: [first, second, excluded, ipv6, laterGroup]);
  var starts = <String>[];
  Future<void> select(String network, {String context = 'physical-generation-1'}) async {
    await selector.select(catalog: catalog, network: network,
      platform: HostPlatform.windows, cancelled: Completer<void>().future,
      contextGeneration: context,
      ipv6Available: false, excludedCandidateRefs: {excluded.candidateRef},
      probeTimeout: const Duration(seconds: 30), selectionTimeout: const Duration(seconds: 30),
      probe: (item, cancelled, timeout) async {
        starts.add(item.transport);
        if (item == first) {
          return const SmartConnectCandidateProbeResult.failure('invalid_profile',
            probeStage: 'parse_profile');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return success(item);
      });
    await shadow.settled;
    expect(shadow.lastFailure, isNull);
  }
  await select('private-physical-network');
  expect(starts, ['dnstt', 'slipstream']);
  final initial = shadow.lastComparison!;
  expect(initial.decision['history'], isEmpty);
  expect(initial.decision['network_class'], 'unknown');
  final descriptors = initial.decision['candidates'] as List<Map<String, Object?>>;
  expect(descriptors.map((item) => item['transport']), ['dnstt', 'slipstream']);
  expect(descriptors.every((item) => item['eligible'] == true && item['priority_group'] == 0), isTrue);
  expect(descriptors.every((item) => item['probe_budget_ms'] == 30000), isTrue);
  expect(jsonEncode(initial.decision), isNot(contains('private-')));

  at = at.add(const Duration(seconds: 2));
  starts = [];
  await select('private-physical-network');
  expect(starts, ['dnstt', 'slipstream']);
  final observed = shadow.lastComparison!;
  final history = observed.decision['history'] as List<Map<String, Object?>>;
  expect(history.map((item) => item['result']), ['control', 'pass']);
  expect(history.first['failure_kind'], 'invalid_profile');
  // A measured two-second age, not a synthetic history-step counter.
  expect(observed.tokens[6 * 82 + 76], closeTo(math.log(3) / math.log(3601), 1e-7));
  expect(observed.tokens[6 * 82 + 78], 1); // same candidate, equality only
  expect(observed.tokens[738 + 6 * 82 + 78], 0);

  at = at.add(const Duration(seconds: 1));
  // The last-good selection key can remain unchanged across WiFi networks
  // sharing an ASN; the physical generation must still clear model history.
  await select('private-physical-network', context: 'physical-generation-2');
  expect(shadow.lastComparison!.decision['history'], isEmpty);
  expect(shadow.lastComparison!.decision['context_generation'],
      (observed.decision['context_generation'] as int) + 1);
  return observed;
}

void main() {
  test('shadow observes actual admitted DNS probes without changing order, history labels or context', () async {
    final result = await exercise(zeroModel());
    expect(result.modelOrder, [0, 1]);
  });

  test('last-good head start does not become a learned choice', () async {
    final shadow = CandidateRankerShadow(zeroModel());
    final selector = SmartConnectCandidateSelector(rankerShadow: shadow);
    final first = candidate('dnstt', 0);
    final second = candidate('slipstream', 1);
    selector.recordSuccess('network', second.candidateRef);
    final starts = <String>[];
    await selector.select(catalog: TransportCandidateCatalog(revision: '1',
        selectedCandidateRef: first.candidateRef, candidates: [first, second]),
      network: 'network', platform: HostPlatform.android,
      cancelled: Completer<void>().future,
      probe: (item, cancelled, timeout) async {
        starts.add(item.transport);
        return success(item);
      });
    await shadow.settled;
    expect(starts, ['slipstream']);
    expect(shadow.lastComparison, isNull);
    expect(() => CandidateRankerModel.fromBytes(Uint8List(8)), throwsFormatException);
  });

  final modelPath = Platform.environment['POKROV_RANKER_MODEL'];
  final research = Platform.environment['POKROV_RANKER_RESEARCH_DIR'];
  test('private local asset reaches ConnectionManager and a failed load keeps its observer absent', () async {
    final loaded = manager(CandidateRankerShadow.loadLocal(modelPath!));
    addTearDown(loaded.dispose);
    expect(loaded.candidateRankerShadow, isNull);
    await loaded.candidateRankerReady;
    expect(loaded.candidateRankerShadow, isNotNull);
    final failed = manager(CandidateRankerShadow.loadLocal('$modelPath.missing'));
    addTearDown(failed.dispose);
    await failed.candidateRankerReady;
    expect(failed.candidateRankerShadow, isNull);
  }, skip: modelPath == null ? 'Set POKROV_RANKER_MODEL for local asset integration.' : false);

  test('owned local Transformer matches ONNX on the actual scheduler snapshot', () async {
    final observed = await exercise(CandidateRankerModel.fromBytes(
        await File(modelPath!).readAsBytes()));
    final process = await Process.start(
      Platform.environment['POKROV_RANKER_PYTHON'] ?? 'python', ['-c', r'''
import json, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, sys.argv[1])
from candidate_contract import encode_decision
from candidate_shadow import load_runtime
decision=json.load(sys.stdin)
tokens, allowed, groups=encode_decision(decision)
scores=load_runtime(Path(sys.argv[1]) / 'contract-best.onnx').run(None, {'tokens':tokens[None]})[0][0]
print(json.dumps({'tokens':tokens.reshape(-1).tolist(),'scores':scores.tolist()}))
''', research!]);
    process.stdin.write(jsonEncode(observed.decision));
    await process.stdin.close();
    final output = await process.stdout.transform(utf8.decoder).join();
    final error = await process.stderr.transform(utf8.decoder).join();
    expect(await process.exitCode, 0, reason: error);
    final reference = jsonDecode(output) as Map<String, dynamic>;
    final tokens = (reference['tokens'] as List).cast<num>();
    final scores = (reference['scores'] as List).cast<num>();
    var inputError = 0.0, scoreError = 0.0;
    for (var i = 0; i < tokens.length; i++) {
      inputError = math.max(inputError, (tokens[i] - observed.tokens[i]).abs());
    }
    for (var i = 0; i < scores.length; i++) {
      scoreError = math.max(scoreError, (scores[i] - observed.scores[i]).abs());
    }
    expect(inputError, lessThan(1e-7));
    expect(scoreError, lessThan(2e-4));
    final referenceOrder = [0, 1]..sort((a, b) => scores[b].compareTo(scores[a]));
    expect(observed.modelOrder, referenceOrder);
    // Visible only in this deliberately enabled local validation run.
    // ignore: avoid_print
    print('ranker parity: input_max_error=$inputError score_max_error=$scoreError');
  }, skip: modelPath == null || research == null ?
      'Set POKROV_RANKER_MODEL and POKROV_RANKER_RESEARCH_DIR for owned local model validation.' : false);
}
