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

void main() {
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
            return _profile(candidate);
          }
          await cancelled;
          await Future<void>.delayed(Duration.zero);
          stopped.add(candidate.candidateRef);
          active--;
          return null;
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
        return _profile(candidate);
      });
    expect((await select('network-a')).profileName, 'de:profile_3');
    expect(starts.first, 'de:profile_3');
    starts.clear();
    expect((await select('network-b')).profileName, 'de:profile_0');
    expect(starts.first, 'de:profile_0');
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
        return candidate.nodeCode == 'ru-spb' ? _profile(candidate) : null;
      });
    expect(result.profileName, 'ru-spb:profile_2');
    expect(started, ['ru', 'ru-spb']);
  });

  test('UDP failures promote TCP and remain quarantined for thirty minutes', () async {
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
        return failUdp && candidate.network == 'udp' ? null : _profile(candidate);
      });
    expect((await select(failUdp: true)).profileName, 'de:profile_4');
    expect(starts.toSet(), hasLength(starts.length));
    starts.clear();
    expect((await select()).profileName, 'de:profile_4');
    expect(starts, isNot(contains('de:profile_0')));
    now = now.add(const Duration(minutes: 31));
    starts.clear();
    expect((await select()).profileName, 'de:profile_0');
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
        return null;
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
        return _profile(candidate);
      }), throwsA(isA<SmartConnectSelectionExhausted>()));
    expect(settled, isTrue);
  });
}
