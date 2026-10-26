import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart' show ObservabilityPrivacyClass;
import 'package:pokrov_observability_runtime/observability_runtime.dart' show OperationalAttributePolicy;
import 'package:pokrov_runtime_engine/runtime_engine.dart';

TransportCandidate _candidate(int index, {bool udp = false, String node = 'de', String country = 'DE', String? bridge}) => TransportCandidate(
  candidateRef: '$node:profile_$index', profileRef: 'profile_$index', nodeCode: node,
  countryCode: country, protocol: udp ? 'awg' : 'vless', transport: udp ? 'udp' : 'tcp',
  protection: udp ? 'awg31' : 'reality', priority: index, network: udp ? 'udp' : 'tcp',
  flow: '', minimumClientRelease: '1.2.0', minimumCoreRelease: null, bridgeId: bridge,
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
    final awg = _candidate(1, udp: true);
    final withOtherNode = [legacy, awg, otherNode, v4, v6];
    expect(SmartConnectCandidateSelector.cacheAlternatives(v6,
        withOtherNode, countryOnly: false, catalog: _catalog(withOtherNode)).map((item) => item.candidateRef),
        [otherNode.candidateRef, v4.candidateRef, awg.candidateRef]);
  });

  test('cache follows server priority when a direct route ranks above bridges', () {
    final selected = _candidate(0, bridge: 'mini');
    final direct = _candidate(1, node: 'ch', country: 'CH');
    final bridge = _candidate(2, node: 'us', country: 'US', bridge: 'ru-spb');
    final candidates = [selected, direct, bridge];
    expect(SmartConnectCandidateSelector.cacheAlternatives(selected,
        candidates, countryOnly: false, catalog: _catalog(candidates)), [direct, bridge]);
  });

  test('ordinary cache reserves do not spend a slot on WARP', () {
    final selected = _candidate(0);
    final warp = TransportCandidate(candidateRef: 'warp:warp_free:warp_direct',
      profileRef: 'warp_free', nodeCode: '', countryCode: 'ZZ', protocol: 'warp',
      transport: 'udp', protection: 'warp', priority: 0, network: 'udp', flow: '',
      minimumClientRelease: '1.5.0+4099', minimumCoreRelease: '1.2.8',
      platforms: selected.platforms, requiredFeatures: const {}, warpMode: 'warp_direct');
    final bridge = _candidate(1, node: 'us', country: 'US', bridge: 'mini');
    final udp = _candidate(2, udp: true);
    final candidates = [selected, warp, bridge, udp];
    expect(SmartConnectCandidateSelector.cacheAlternatives(selected,
        candidates, countryOnly: false, catalog: _catalog(candidates)), [bridge, udp]);
  });

  test('country Auto caches an independent bridge that survives recovery selection', () async {
    final selected = _candidate(0, node: 'de2', bridge: 'mini-xhttp');
    final otherCountry = _candidate(1, node: 'ch', country: 'CH', bridge: 'mini-xhttp');
    final otherNode = _candidate(2, bridge: 'mini-xhttp');
    final sameBridge = _candidate(3, node: 'de2', bridge: 'mini');
    final otherCountryBridge = _candidate(4, node: 'ch', country: 'CH', bridge: 'rf2-xhttp');
    final bridge = _candidate(5, bridge: 'rf2-xhttp');
    final udp = _candidate(6, node: 'de2', udp: true);
    final naive = TransportCandidate(candidateRef: 'ch:naive_h2', profileRef: 'naive_h2',
      nodeCode: 'ch', countryCode: 'CH', protocol: 'naive', transport: 'h2', protection: 'tls',
      priority: 7, network: 'tcp', flow: '', minimumClientRelease: '1.5.0', minimumCoreRelease: null,
      platforms: selected.platforms, requiredFeatures: {RuntimeTransportFeature.naiveH2});
    final candidates = [selected, otherCountry, otherNode, sameBridge, otherCountryBridge, bridge, udp, naive];
    final saved = SmartConnectCandidateSelector.cacheAlternatives(selected,
        candidates, countryOnly: true, catalog: _catalog(candidates));
    expect(saved, [bridge, udp]);
    expect(SmartConnectCandidateSelector.cacheAlternatives(selected,
        candidates, countryOnly: false, catalog: _catalog(candidates)), [otherCountryBridge, udp, naive]);

    final probed = <String>[];
    final recovered = await SmartConnectCandidateSelector().select(
      catalog: _catalog([selected, ...saved]), network: 'cellular', platform: HostPlatform.android,
      recoveryCandidateRef: selected.candidateRef, cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async {
        probed.add(candidate.candidateRef);
        return candidate == bridge ? _success(candidate)
            : const SmartConnectCandidateProbeResult.failure('connect_failed');
      },
    );
    expect(recovered.profileName, bridge.candidateRef);
    expect(probed, contains(bridge.candidateRef),
        reason: 'the three-probe recovery cap must retain RF2 beside current Mini and UDP');
  });

  test('Auto settles bridges in server priority order before trying a remembered direct route', () async {
    final selector = SmartConnectCandidateSelector();
    final direct = _candidate(3, node: 'us', country: 'US');
    final firstBridge = _candidate(1, bridge: 'mini');
    final secondBridge = _candidate(2, node: 'ch', country: 'CH', bridge: 'ru-spb');
    selector.recordSuccess('network-a', direct.candidateRef);
    final bothStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final releaseSecond = Completer<void>();
    final started = <String>[];
    final selected = selector.select(
      catalog: _catalog([direct, secondBridge, firstBridge]),
      network: 'network-a', platform: HostPlatform.android,
      cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async {
        started.add(candidate.candidateRef);
        if (candidate.bridgeId == null) return _success(candidate);
        if (started.length == 2) bothStarted.complete();
        await (candidate == firstBridge ? releaseFirst.future : releaseSecond.future);
        return const SmartConnectCandidateProbeResult.failure('connect_failed');
      },
    );
    await bothStarted.future;
    expect(started, [firstBridge.candidateRef, secondBridge.candidateRef]);
    releaseFirst.complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, [firstBridge.candidateRef, secondBridge.candidateRef]);
    releaseSecond.complete();
    expect((await selected).profileName, direct.candidateRef);
    expect(started, [firstBridge.candidateRef, secondBridge.candidateRef, direct.candidateRef]);
  });

  test('Auto tries the load-ranked direct route before a remembered bridge and retains bridge fallback', () async {
    final direct = _candidate(0);
    final bridge = _candidate(1, bridge: 'mini');
    final outsideCountry = _candidate(2, node: 'ch', country: 'CH');
    final selector = SmartConnectCandidateSelector()..recordSuccess('network-a', bridge.candidateRef);
    final firstStarted = Completer<void>();
    final releaseDirect = Completer<void>();
    final started = <TransportCandidate>[];
    final selected = selector.select(
      catalog: _catalog([bridge, outsideCountry, direct]),
      network: 'network-a', platform: HostPlatform.windows, preferredCountryCode: 'DE',
      cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async {
        started.add(candidate);
        if (!firstStarted.isCompleted) firstStarted.complete();
        if (candidate == direct) {
          await releaseDirect.future;
          return const SmartConnectCandidateProbeResult.failure('connect_failed');
        }
        return _success(candidate);
      });
    await firstStarted.future;
    expect(started, [direct], reason: 'a remembered loaded bridge cannot override current server ranking');
    releaseDirect.complete();
    expect((await selected).profileName, bridge.candidateRef);
    expect(started, [direct, bridge], reason: 'the lower-ranked bridge remains a country-scoped fallback');

    final healthy = _candidate(3, bridge: 'healthy');
    final excludedDirect = _candidate(4);
    final loaded = _candidate(5, bridge: 'loaded');
    selector.recordSuccess('network-a', loaded.candidateRef);
    started.clear();
    await selector.select(catalog: _catalog([healthy, excludedDirect, loaded]),
      network: 'network-a', platform: HostPlatform.windows,
      excludedCandidateRefs: {excludedDirect.candidateRef}, cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async {
        started.add(candidate);
        return _success(candidate);
      });
    expect(started, [healthy], reason: 'excluding direct must not merge healthy and loaded bridge groups');
  });

  test('cold Auto admits Naive early inside its direct group after the preferred TCP family', () async {
    final healthy = _candidate(0, bridge: 'healthy');
    final outsideCountry = _candidate(1, node: 'ch', country: 'CH');
    final v4 = _familyCandidate('ipv4', priority: 10);
    final v6 = _familyCandidate('ipv6', priority: 11);
    final naive = TransportCandidate(candidateRef: 'de:naive_h2', profileRef: 'naive_h2',
      nodeCode: 'de', countryCode: 'DE', protocol: 'naive', transport: 'h2',
      protection: 'tls', priority: 20, network: 'tcp', flow: '',
      minimumClientRelease: '1.5.0', minimumCoreRelease: null,
      platforms: v4.platforms, requiredFeatures: const {});
    final loaded = _candidate(21, bridge: 'loaded');
    final selector = SmartConnectCandidateSelector()..recordSuccess('network-a', v4.candidateRef);
    final bridgeStarted = Completer<void>();
    final releaseBridge = Completer<void>();
    final naiveStarted = Completer<void>();
    final releaseNaive = Completer<void>();
    final prepared = <TransportCandidate>[];
    final selected = selector.select(
      catalog: _catalog([healthy, outsideCountry, ...List.generate(8, (i) => _candidate(i + 2)),
        v4, v6, naive, loaded]),
      network: 'network-a', platform: HostPlatform.windows, preferredCountryCode: 'DE',
      cancelled: Completer<void>().future,
      prepare: (candidate, _) async => prepared.add(candidate),
      probe: (candidate, cancelled, timeout) async {
        if (candidate == healthy) {
          bridgeStarted.complete();
          await releaseBridge.future;
          return const SmartConnectCandidateProbeResult.failure('connect_failed');
        }
        if (candidate == naive) {
          naiveStarted.complete();
          await releaseNaive.future;
          return _success(candidate);
        }
        await cancelled;
        return const SmartConnectCandidateProbeResult.failure('cancelled');
      });
    await bridgeStarted.future;
    expect(prepared, [healthy], reason: 'Naive cannot cross a healthy bridge boundary');
    releaseBridge.complete();
    await naiveStarted.future;
    expect(prepared.take(4), [healthy, v6, v4, naive],
        reason: 'blackholed TCP variants must not consume every slot before Naive');
    releaseNaive.complete();
    expect((await selected).profileName, naive.candidateRef);
    expect(prepared, isNot(contains(outsideCountry)));
    expect(prepared, isNot(contains(loaded)));
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

  test('typed network failures suppress only their candidate and network', () async {
    final catalog = _catalog([_candidate(0), _candidate(1)]);
    final selectedByFailureKind = <String, String>{};
    for (final kind in ['probe_failed', 'unexpected_status',
        'core_egress_tls_timeout', 'core_egress_response_timeout']) {
      final selector = SmartConnectCandidateSelector();
      selector.recordFailure('network-a', 'de:profile_0', kind);
      final result = await selector.select(
        catalog: catalog, network: 'network-a', platform: HostPlatform.windows,
        cancelled: Completer<void>().future,
        probe: (candidate, cancelled, timeout) async => _success(candidate),
      );
      selectedByFailureKind[kind] = result.profileName;
      final otherNetwork = await selector.select(
        catalog: catalog, network: 'network-b', platform: HostPlatform.windows,
        cancelled: Completer<void>().future,
        probe: (candidate, cancelled, timeout) async => _success(candidate),
      );
      expect(otherNetwork.profileName, 'de:profile_0', reason: kind);
    }
    final selector = SmartConnectCandidateSelector();
    for (final kind in ['core_egress_timeout', 'deadline_exceeded',
        'invalid_profile', 'cancelled', 'network_changed']) {
      selector.recordFailure('network-a', 'de:profile_0', kind);
    }
    final ignored = await selector.select(
      catalog: catalog, network: 'network-a', platform: HostPlatform.windows,
      cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async => _success(candidate),
    );
    expect(ignored.profileName, 'de:profile_0');
    expect(selectedByFailureKind.values, everyElement('de:profile_1'),
        reason: selectedByFailureKind.toString());
  });

  test('local probe budget expiry does not suppress the candidate', () async {
    const probeError = {'operation': 'read_headers', 'cause': 'closed', 'cancel_state': 'cancelled',
      'target': 'owned_reserve', 'request': 'egress_204', 'elapsed_ms': 10,
      'stage_started_ms': 10, 'duration_ms': 20};
    final selector = SmartConnectCandidateSelector();
    final catalog = _catalog([_candidate(0), _candidate(1)]);
    final reported = <String>[];
    final details = <Map<String, Object>?>[];
    await expectLater(selector.select(
      catalog: catalog, network: 'network-a', platform: HostPlatform.windows,
      cancelled: Completer<void>().future,
      probeTimeout: const Duration(milliseconds: 20),
      onProbeResult: (_, result) { reported.add(result.failureKind); details.add(result.probeError); },
      probe: (candidate, cancelled, timeout) async {
        if (candidate.priority == 0) await cancelled;
        return const SmartConnectCandidateProbeResult.failure('cancelled', probeError: probeError);
      },
    ), throwsA(isA<SmartConnectSelectionExhausted>()));
    expect(reported, contains('probe_budget_expired'));
    expect(details, everyElement(probeError));
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

  test('recovery reaches a working UDP reserve after different TCP transports fail within three attempts', () async {
    final failed = _candidate(0, bridge: 'old');
    final bridges = [for (var index = 1; index <= 2; index++) _candidate(index, bridge: 'bridge-$index')];
    final xhttp = TransportCandidate(candidateRef: 'de:xhttp', profileRef: 'xhttp', nodeCode: 'de',
      countryCode: 'DE', protocol: 'vless', transport: 'xhttp', protection: 'tls',
      priority: 3, network: 'tcp', flow: '', minimumClientRelease: '1.2.0', minimumCoreRelease: null,
      platforms: {HostPlatform.windows}, requiredFeatures: const {});
    final reserve = _candidate(4, udp: true);
    final started = <TransportCandidate>[];
    var active = 0;
    final selected = await SmartConnectCandidateSelector().select(
      catalog: _catalog([failed, ...bridges, xhttp, reserve]), network: 'network-a',
      platform: HostPlatform.windows, preferredCountryCode: 'DE',
      recoveryCandidateRef: failed.candidateRef, excludedCandidateRefs: {failed.candidateRef},
      cancelled: Completer<void>().future,
      probe: (candidate, cancelled, timeout) async {
        started.add(candidate);
        active++;
        await Future<void>.delayed(Duration.zero);
        active--;
        return candidate == reserve ? _success(candidate)
            : const SmartConnectCandidateProbeResult.failure('connect_failed');
      });
    expect(selected.profileName, reserve.candidateRef);
    expect(started, hasLength(3), reason: 'protocol diversity must fit the existing recovery limit');
    expect(started.take(2).map((candidate) => candidate.bridgeId), everyElement(isNotNull));
    expect(started, isNot(contains(failed)), reason: 'confirmed failure is not probed again');
    expect(active, 0, reason: 'the bridge probes settle before recovery returns');
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

    // Three mobile workers exhaust one IO grant, then spend longer joining
    // native cleanup. The fourth candidate still gets the second full grant.
    final candidates = List.generate(4, _candidate);
    var active = 0;
    var peak = 0;
    var settledFirstWave = 0;
    final selected = await SmartConnectCandidateSelector().select(
      catalog: _catalog(candidates), network: 'network-b', platform: HostPlatform.android,
      cancelled: Completer<void>().future, probeTimeout: const Duration(milliseconds: 40),
      selectionTimeout: const Duration(milliseconds: 80), excludeProbeCleanupFromBudget: true,
      probe: (candidate, cancelled, timeout) async {
        active++;
        if (active > peak) peak = active;
        try {
          if (candidate.priority < 3) {
            await cancelled;
            await Future<void>.delayed(const Duration(milliseconds: 60));
            settledFirstWave++;
            return const SmartConnectCandidateProbeResult.failure('cancelled');
          }
          expect(settledFirstWave, greaterThan(0));
          expect(timeout, const Duration(milliseconds: 40));
          var stopped = false;
          unawaited(cancelled.then((_) => stopped = true));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return stopped ? const SmartConnectCandidateProbeResult.failure('cancelled') : _success(candidate);
        } finally {
          active--;
        }
      });
    expect(selected.profileName, candidates.last.candidateRef);
    expect((active, peak, settledFirstWave), (0, 3, 3));
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
    final preparationErrors = <Object>[
      ManagedProfileTimeout('route_policy'),
      ManagedProfileTimeout('managed_fetch', preparation: const {
        'stage': 'http_body', 'elapsed_ms': 6001, 'http_status': 200}),
      ManagedProfileTimeout('materialize'),
      ManagedProfileTimeout('state_read'),
      ManagedProfileTimeout(null),
      TimeoutException('fixture'),
      const BootstrapFailure('fixture', apiFailureKind: 'request_timeout'),
      const BootstrapFailure('fixture', apiFailureKind: 'request_http'),
      const BootstrapFailure('fixture', apiFailureKind: 'request_socket'),
      const BootstrapFailure('fixture', apiFailureKind: 'request_tls'),
      const BootstrapFailure('fixture', apiFailureKind: 'untrusted-kind'),
      StateError('fixture'),
    ];
    final reports = <int, SmartConnectCandidateProbeResult>{};
    final selector = SmartConnectCandidateSelector();
    final candidates = List.generate(preparationErrors.length, (index) => _candidate(index, udp: index == 0));
    await expectLater(selector.select(
      catalog: _catalog(candidates), network: 'network-a', platform: HostPlatform.windows,
      cancelled: Completer<void>().future,
      prepare: (candidate, _) async => throw preparationErrors[candidate.priority],
      probe: (_, __, ___) async => throw StateError('native must not start'),
      onProbeResult: (candidate, result) => reports[candidate.priority] = result,
    ), throwsA(isA<BootstrapFailure>().having((error) => error.apiFailureKind,
        'only an API failure is aggregated', 'request_timeout')));
    expect(List.generate(preparationErrors.length, (index) => reports[index]!.failureKind),
        ['prepare_route_policy_timeout', 'prepare_managed_timeout',
          'prepare_materialize_timeout', 'prepare_state_timeout', 'prepare_timeout',
          'prepare_timeout', 'prepare_timeout', 'prepare_http', 'prepare_socket',
          'prepare_tls', 'prepare_failed', 'prepare_failed']);
    expect(reports.values.every((result) => result.duration == Duration.zero && result.probeStage == null), isTrue);
    expect(reports[1]!.preparation, {'stage': 'http_body', 'elapsed_ms': 6001, 'http_status': 200});
    for (var index = 0; index < 4; index++) {
      final report = reports[index]!;
      OperationalAttributePolicy.validate({'failure_kind': report.failureKind, 'duration_ms': 0},
          ObservabilityPrivacyClass.localOperational);
      final event = DiagnosticEventRecord(occurredAt: DateTime.now().toUtc(),
          subsystem: 'candidate_probe', stage: 'probe', outcome: 'failed',
          candidateFailureKind: report.failureKind, durationMs: 0).toJson();
      expect(event['candidate_failure_kind'], report.failureKind);
    }
    final retried = <String>[];
    await selector.select(
      catalog: _catalog([candidates.first, _candidate(99)]), network: 'network-a', platform: HostPlatform.windows,
      cancelled: Completer<void>().future,
      probe: (candidate, _, __) async { retried.add(candidate.candidateRef); return _success(candidate); },
    );
    expect(retried.first, candidates.first.candidateRef,
        reason: 'preparation failure neither quarantines the candidate nor penalizes UDP');
  });
}
