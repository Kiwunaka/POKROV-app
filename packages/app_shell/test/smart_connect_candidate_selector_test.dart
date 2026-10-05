import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

TransportCandidate _candidate(int index, {bool udp = false, String node = 'de', String country = 'DE'}) => TransportCandidate(
  candidateRef: '$node:profile_$index', profileRef: 'profile_$index', nodeCode: node,
  countryCode: country, protocol: udp ? 'awg' : 'vless', transport: udp ? 'udp' : 'tcp',
  protection: udp ? 'awg31' : 'reality', priority: index, network: udp ? 'udp' : 'tcp',
  flow: '', minimumClientRelease: '1.2.0', minimumCoreRelease: null,
  platforms: {HostPlatform.android, HostPlatform.windows}, requiredFeatures: const {},
);

TransportCandidateCatalog _catalog(List<TransportCandidate> candidates) =>
  TransportCandidateCatalog(revision: 'test', selectedCandidateRef: candidates.first.candidateRef,
    candidates: candidates);

ManagedProfilePayload _profile(TransportCandidate candidate) => ManagedProfilePayload(
  profileName: candidate.candidateRef, configPayload: '{}');

SmartConnectCandidateProbeResult _success(TransportCandidate candidate) =>
  SmartConnectCandidateProbeResult.success(_profile(candidate));

TransportCandidate _familyCandidate(String family, {int? priority, String endpoint = 'test'}) => TransportCandidate(
  candidateRef: 'de:profile_0:endpoint_$endpoint:$family:g1', profileRef: 'profile_0',
  nodeCode: 'de', countryCode: 'DE', protocol: 'vless', transport: 'tcp',
  protection: 'reality', priority: priority ?? (family == 'ipv4' ? 0 : 1), network: 'tcp',
  flow: '', minimumClientRelease: '1.5.0', minimumCoreRelease: null,
  family: family, deliveryEndpointId: endpoint, endpointGeneration: 1,
  platforms: {HostPlatform.android, HostPlatform.windows}, requiredFeatures: const {},
);

void main() {
  test('cache reserves another node before a protocol alternative and keeps manual country', () {
    final candidates = [
      _candidate(0), _candidate(1, udp: true),
      _candidate(2, node: 'ch', country: 'CH'), _candidate(3, node: 'de2'),
    ];
    expect(SmartConnectCandidateSelector.cacheAlternatives(candidates.first,
        candidates, countryOnly: false, catalog: _catalog(candidates)).map((candidate) => candidate.candidateRef),
        ['ch:profile_2', 'de:profile_1']);
    expect(SmartConnectCandidateSelector.cacheAlternatives(candidates.first,
        candidates, countryOnly: true, catalog: _catalog(candidates)).map((candidate) => candidate.candidateRef),
        ['de2:profile_3', 'de:profile_1']);
  });

  test('cache keeps the exact opposite typed family behind another node', () {
    final legacy = _candidate(0);
    final v4 = _familyCandidate('ipv4', priority: 3, endpoint: 'v4');
    final v6 = _familyCandidate('ipv6', priority: 4, endpoint: 'v6');
    final candidates = [legacy, v4, v6];
    expect(SmartConnectCandidateSelector.cacheAlternatives(v6,
        candidates, countryOnly: true, catalog: _catalog(candidates)).map((item) => item.candidateRef),
        [v4.candidateRef]);
    final otherNode = _candidate(2, node: 'ch', country: 'CH');
    final withOtherNode = [legacy, _candidate(1, udp: true), otherNode, v4, v6];
    expect(SmartConnectCandidateSelector.cacheAlternatives(v6,
        withOtherNode, countryOnly: false, catalog: _catalog(withOtherNode)).map((item) => item.candidateRef),
        [otherNode.candidateRef, v4.candidateRef]);
  });

  for (final (platform, parallelism) in [(HostPlatform.android, 3), (HostPlatform.windows, 4)]) {
    test('$platform first successful probe cancels and joins the bounded workers', () async {
      final selector = SmartConnectCandidateSelector();
      final ownerCancelled = Completer<void>();
      final launched = <String>[];
      final stopped = <String>[];
      final winner = Completer<void>();
      var active = 0;
      var maxActive = 0;
      final selected = selector.select(catalog: _catalog(List.generate(8, _candidate)),
        network: 'network-a', platform: platform, cancelled: ownerCancelled.future,
        probe: (candidate, cancelled, timeout) async {
          launched.add(candidate.candidateRef);
          active++;
          if (active > maxActive) maxActive = active;
          if (candidate.priority == 1) {
            await winner.future;
            active--;
            return _success(candidate);
          }
          await cancelled;
          await Future<void>.delayed(Duration.zero);
          stopped.add(candidate.candidateRef);
          active--;
          return const SmartConnectCandidateProbeResult.failure('cancelled');
        });
      await Future<void>.delayed(Duration.zero);
      expect(launched, hasLength(parallelism));
      winner.complete();
      expect((await selected).profileName, 'de:profile_1');
      expect(stopped, hasLength(parallelism - 1));
      expect(maxActive, parallelism);
      expect(active, 0);
    });
  }

  test('last successful candidate is preferred only on its own network', () async {
    final selector = SmartConnectCandidateSelector();
    selector.recordSuccess('network-a', 'de:profile_3');
    final starts = <String>[];
    Future<ManagedProfilePayload> select(String network) => selector.select(
      catalog: _catalog(List.generate(5, _candidate)), network: network,
      platform: HostPlatform.android, cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async {
        starts.add(candidate.candidateRef);
        return _success(candidate);
      });
    expect((await select('network-a')).profileName, 'de:profile_3');
    expect(starts.first, 'de:profile_3');
    starts.clear();
    expect((await select('network-b')).profileName, 'de:profile_0');
    expect(starts.first, 'de:profile_0');
  });

  test('direct IPv4 reserve waits from IPv6 native start and joins bounded losers', () async {
    final v4 = _familyCandidate('ipv4');
    final v6 = _familyCandidate('ipv6');
    final selector = SmartConnectCandidateSelector();
    selector.recordSuccess('network-a', v4.candidateRef);
    final prepared = Completer<void>();
    final clock = Stopwatch();
    final starts = <String>[];
    var active = 0;
    var maxActive = 0;
    var stopped = 0;
    final selected = selector.select(
      catalog: _catalog([v4, v6, _candidate(2), _candidate(3), _candidate(4)]),
      network: 'network-a', platform: HostPlatform.windows,
      cancelled: Completer<void>().future,
      prepare: (candidate, _) async {
        if (candidate.family == 'ipv6') await prepared.future;
      },
      probe: (candidate, cancelled, _) async {
        starts.add(candidate.candidateRef);
        active++;
        if (active > maxActive) maxActive = active;
        if (candidate == v6) clock.start();
        if (candidate == v4) {
          expect(clock.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 240)));
          active--;
          return _success(candidate);
        }
        await cancelled;
        await Future<void>.delayed(Duration.zero);
        stopped++;
        active--;
        return const SmartConnectCandidateProbeResult.failure('cancelled');
      });
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(starts, isNot(contains(v4.candidateRef)));
    prepared.complete();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(starts, contains(v6.candidateRef));
    expect(starts, isNot(contains(v4.candidateRef)));
    expect((await selected).profileName, v4.candidateRef);
    expect(starts, hasLength(4));
    expect(maxActive, 4);
    expect(stopped, 3);
    expect(active, 0);
  });

  test('legacy base cannot win while its typed IPv6 sibling is preparing', () async {
    final legacy = _candidate(0);
    final v4 = _familyCandidate('ipv4', priority: 3, endpoint: 'v4');
    final v6 = _familyCandidate('ipv6', priority: 4, endpoint: 'v6');
    final starts = <String>[];
    final selected = await SmartConnectCandidateSelector().select(
      catalog: _catalog([legacy, v4, v6]), network: 'network-a',
      platform: HostPlatform.android, ipv6Available: true,
      cancelled: Completer<void>().future,
      prepare: (candidate, cancelled) async {
        if (candidate == v6) await Future.any<void>([
          cancelled, Future<void>.delayed(const Duration(milliseconds: 100)),
        ]);
      },
      probe: (candidate, _, timeout) async {
        starts.add(candidate.candidateRef);
        return _success(candidate);
      });
    expect(starts, [v6.candidateRef]);
    expect(selected.profileName, v6.candidateRef);
  });

  test('direct family failure releases reserve and an early winner skips it', () async {
    final v4 = _familyCandidate('ipv4');
    final v6 = _familyCandidate('ipv6');
    final catalog = _catalog([v4, v6]);
    final starts = <String>[];
    final clock = Stopwatch();
    final failed = await SmartConnectCandidateSelector().select(
      catalog: catalog, network: 'network-a', platform: HostPlatform.android,
      cancelled: Completer<void>().future,
      probe: (candidate, _, timeout) async {
        starts.add(candidate.candidateRef);
        if (candidate == v6) {
          clock.start();
          return const SmartConnectCandidateProbeResult.failure('connect_failed');
        }
        expect(clock.elapsed, lessThan(const Duration(milliseconds: 250)));
        return _success(candidate);
      });
    expect(failed.profileName, v4.candidateRef);
    expect(starts, [v6.candidateRef, v4.candidateRef]);
    starts.clear();
    final won = await SmartConnectCandidateSelector().select(
      catalog: catalog, network: 'network-a', platform: HostPlatform.android,
      cancelled: Completer<void>().future,
      probe: (candidate, _, timeout) async {
        starts.add(candidate.candidateRef);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _success(candidate);
      });
    expect(won.profileName, v6.candidateRef);
    expect(starts, [v6.candidateRef]);
  });

  test('unavailable IPv6 skips preparation and telemetry without poisoning later unknown availability', () async {
    final v4 = _familyCandidate('ipv4');
    final v6 = _familyCandidate('ipv6');
    final selector = SmartConnectCandidateSelector();
    selector.recordSuccess('network-a', v6.candidateRef);
    final prepared = <String>[];
    final reported = <String>[];
    Future<ManagedProfilePayload> select(bool? available) => selector.select(
      catalog: _catalog([v4, v6]), network: 'network-a', platform: HostPlatform.windows,
      cancelled: Completer<void>().future, ipv6Available: available,
      prepare: (candidate, _) async => prepared.add(candidate.candidateRef),
      onProbeResult: (candidate, _) => reported.add(candidate.candidateRef),
      probe: (candidate, _, timeout) async => _success(candidate));
    expect((await select(false)).profileName, v4.candidateRef);
    expect(prepared, [v4.candidateRef]);
    expect(reported, [v4.candidateRef]);
    prepared.clear();
    reported.clear();
    expect((await select(null)).profileName, v6.candidateRef);
    expect(reported, [v6.candidateRef]);
  });

  test('manual country includes its other nodes without changing country', () async {
    final selector = SmartConnectCandidateSelector();
    final started = <String>[];
    final result = await selector.select(catalog: _catalog([
      _candidate(0), _candidate(1, node: 'ru', country: 'RU'),
      _candidate(2, node: 'ru-spb', country: 'RU'),
    ]), network: 'network-a', platform: HostPlatform.android,
      preferredCountryCode: 'RU', cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async {
        started.add(candidate.nodeCode);
        return candidate.nodeCode == 'ru-spb' ? _success(candidate)
            : const SmartConnectCandidateProbeResult.failure('connect_failed');
      });
    expect(result.profileName, 'ru-spb:profile_2');
    expect(started, ['ru', 'ru-spb']);
  });

  test('UDP data stalls promote TCP for four minutes', () async {
    var now = DateTime.utc(2026, 9, 27);
    final selector = SmartConnectCandidateSelector(now: () => now);
    final catalog = _catalog([
      for (var index = 0; index < 4; index++) _candidate(index, udp: true),
      _candidate(4),
    ]);
    final starts = <String>[];
    Future<ManagedProfilePayload> select({bool failUdp = false}) => selector.select(
      catalog: catalog, network: 'network-a', platform: HostPlatform.android,
      cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async {
        starts.add(candidate.candidateRef);
        return failUdp && candidate.network == 'udp'
            ? const SmartConnectCandidateProbeResult.failure('data_stalled')
            : _success(candidate);
      });
    expect((await select(failUdp: true)).profileName, 'de:profile_4');
    expect(starts.toSet(), hasLength(starts.length));
    starts.clear();
    expect((await select()).profileName, 'de:profile_4');
    expect(starts, isNot(contains('de:profile_0')));
    now = now.add(const Duration(minutes: 5));
    starts.clear();
    expect((await select()).profileName, 'de:profile_0');
  });

  test('invalid profile is reported but does not quarantine its candidate', () async {
    final selector = SmartConnectCandidateSelector();
    final catalog = _catalog([_candidate(0, udp: true)]);
    final reported = <String>[];
    Future<ManagedProfilePayload> select(bool valid) => selector.select(
      catalog: catalog, network: 'network-a', platform: HostPlatform.android,
      cancelled: Completer<void>().future,
      onProbeResult: (_, result) => reported.add(result.failureKind),
      probe: (candidate, cancelled, timeout) async => valid
          ? _success(candidate)
          : const SmartConnectCandidateProbeResult.failure('invalid_profile'));
    await expectLater(select(false), throwsA(isA<SmartConnectSelectionExhausted>()));
    expect((await select(true)).profileName, 'de:profile_0');
    expect(reported, ['invalid_profile', '']);
  });

  test('probe failure and unexpected status suppress only their candidate', () async {
    final catalog = _catalog([_candidate(0), _candidate(1)]);
    for (final kind in ['probe_failed', 'unexpected_status']) {
      final selector = SmartConnectCandidateSelector();
      selector.recordFailure('network-a', 'de:profile_0', kind);
      final result = await selector.select(
        catalog: catalog, network: 'network-a', platform: HostPlatform.windows,
        cancelled: Completer<void>().future,
        probe: (candidate, cancelled, timeout) async => _success(candidate),
      );
      expect(result.profileName, 'de:profile_1');
    }
  });

  test('local probe budget expiry does not suppress the candidate', () async {
    final selector = SmartConnectCandidateSelector();
    final catalog = _catalog([_candidate(0), _candidate(1)]);
    final reported = <String>[];
    await expectLater(selector.select(
      catalog: catalog, network: 'network-a', platform: HostPlatform.windows,
      cancelled: Completer<void>().future,
      probeTimeout: const Duration(milliseconds: 20),
      onProbeResult: (_, result) => reported.add(result.failureKind),
      probe: (candidate, cancelled, timeout) async {
        if (candidate.priority == 0) await cancelled;
        return const SmartConnectCandidateProbeResult.failure('invalid_profile');
      },
    ), throwsA(isA<SmartConnectSelectionExhausted>()));
    expect(reported, contains('probe_budget_expired'));
    final selected = await selector.select(
      catalog: catalog, network: 'network-a', platform: HostPlatform.windows,
      cancelled: Completer<void>().future,
      probeTimeout: const Duration(milliseconds: 20),
      probe: (candidate, cancelled, timeout) async {
        if (candidate.priority == 1) {
          await cancelled;
          return const SmartConnectCandidateProbeResult.failure('cancelled');
        }
        return _success(candidate);
      },
    );
    expect(selected.profileName, 'de:profile_0');
  });

  test('all candidates are retried when failure memory filters the whole catalog', () async {
    final selector = SmartConnectCandidateSelector();
    final catalog = _catalog([_candidate(0), _candidate(1)]);
    for (final candidate in catalog.candidates) {
      selector.recordFailure('network-a', candidate.candidateRef, 'timeout');
    }
    final started = <String>[];
    final result = await selector.select(
      catalog: catalog, network: 'network-a', platform: HostPlatform.windows,
      cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async {
        started.add(candidate.candidateRef);
        return _success(candidate);
      });
    expect(result.profileName, 'de:profile_0');
    expect(started, contains('de:profile_0'));
  });

  test('last success gets a short head start before other candidates', () async {
    final selector = SmartConnectCandidateSelector();
    selector.recordSuccess('network-a', 'de:profile_2');
    final started = <String>[];
    final selected = selector.select(
      catalog: _catalog(List.generate(4, _candidate)), network: 'network-a',
      platform: HostPlatform.android, cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async {
        started.add(candidate.candidateRef);
        if (candidate.priority == 2) {
          await cancelled;
          return const SmartConnectCandidateProbeResult.failure('cancelled');
        }
        return _success(candidate);
      });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(started, ['de:profile_2']);
    expect((await selected).profileName, 'de:profile_0');
    expect(started, contains('de:profile_0'));
  });

  test('recovery tries the current candidate first and stops after three failures', () async {
    final selector = SmartConnectCandidateSelector();
    final firstSettles = Completer<void>();
    final starts = <String>[];
    final selection = selector.select(catalog: _catalog(List.generate(8, _candidate)),
      network: 'network-a', platform: HostPlatform.android, recoveryCandidateRef: 'de:profile_5',
      cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async {
        starts.add(candidate.candidateRef);
        if (candidate.priority == 5) await firstSettles.future;
        return const SmartConnectCandidateProbeResult.failure('connect_failed');
      });
    final expectation = expectLater(selection, throwsA(isA<SmartConnectSelectionExhausted>()));
    await Future<void>.delayed(Duration.zero);
    expect(starts, ['de:profile_5']);
    firstSettles.complete();
    await expectation;
    expect(starts, hasLength(3));
  });

  test('probe timeout cancels native work before selection completes', () async {
    final selector = SmartConnectCandidateSelector();
    var settled = false;
    await expectLater(selector.select(catalog: _catalog([_candidate(0)]),
      network: 'network-a', platform: HostPlatform.android,
      cancelled: Completer<void>().future, probeTimeout: const Duration(milliseconds: 10),
      probe: (candidate, cancelled, timeout) async {
        await cancelled;
        await Future<void>.delayed(Duration.zero);
        settled = true;
        return _success(candidate);
      }), throwsA(isA<SmartConnectSelectionExhausted>()));
    expect(settled, isTrue);
  });

  test('slow profile fetch does not consume the native probe budget', () async {
    var probed = false;
    final selected = await SmartConnectCandidateSelector().select(
      catalog: _catalog([_candidate(0)]), network: 'network-a',
      platform: HostPlatform.windows, cancelled: Completer<void>().future,
      selectionTimeout: const Duration(milliseconds: 20),
      prepare: (candidate, cancelled) => Future<void>.delayed(const Duration(milliseconds: 40)),
      probe: (candidate, cancelled, timeout) async {
        probed = true;
        expect(timeout, const Duration(milliseconds: 20));
        return _success(candidate);
      });
    expect(selected.profileName, 'de:profile_0');
    expect(probed, isTrue);
  });
}
