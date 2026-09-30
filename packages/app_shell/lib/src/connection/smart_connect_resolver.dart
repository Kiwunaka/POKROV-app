part of '../../app_first_runtime_bootstrap.dart';

typedef SmartConnectCandidateProbe = Future<SmartConnectCandidateProbeResult> Function(
  TransportCandidate candidate, Future<void> cancelled, Duration timeout);

class SmartConnectCandidateProbeResult {
  const SmartConnectCandidateProbeResult.success(this.profile,
      {this.duration = Duration.zero}) : failureKind = '';
  const SmartConnectCandidateProbeResult.failure(this.failureKind,
      {this.duration = Duration.zero}) : profile = null;

  final ManagedProfilePayload? profile;
  final String failureKind;
  final Duration duration;
}

class SmartConnectSelectionExhausted implements Exception {
  const SmartConnectSelectionExhausted();
  @override
  String toString() => 'smart_connect_candidates_exhausted';
}

/// Ordinary catalog selection. A successful probe means an authenticated 204
/// was received through that exact candidate, never just an open TCP port.
class SmartConnectCandidateSelector {
  static List<TransportCandidate> cacheAlternatives(
      TransportCandidate selected, Iterable<TransportCandidate> candidates,
      {required bool countryOnly}) {
    final ordered = candidates.where((candidate) =>
        candidate.candidateRef != selected.candidateRef &&
        (!countryOnly || candidate.countryCode == selected.countryCode)).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    final alternatives = <TransportCandidate>[];
    final families = {selected.protocol};
    for (final candidate in ordered) {
      if (candidate.nodeCode == selected.nodeCode) continue;
      alternatives.add(candidate);
      families.add(candidate.protocol);
      break;
    }
    for (final candidate in ordered) {
      if (alternatives.length == 2) break;
      if (families.add(candidate.protocol)) alternatives.add(candidate);
    }
    return alternatives;
  }

  SmartConnectCandidateSelector({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _successful = <String, String>{};
  final _failedUntil = <(String, String), DateTime>{};
  final _udpFailedUntil = <String, DateTime>{};
  static const failureMemory = Duration(minutes: 4);
  static const _networkFailureKinds = <String>{
    'connect_failed', 'tls_failed', 'timeout', 'data_stalled',
    'probe_failed', 'unexpected_status',
    'core_egress_connect_failed', 'core_egress_tls_failed',
    'core_egress_dns_failed', 'core_egress_probe_failed',
  };

  void recordSuccess(String network, String candidateRef) {
    _successful[network] = candidateRef;
    _failedUntil.remove((network, candidateRef));
  }

  void restoreSuccess(String network, String candidateRef) {
    _successful.putIfAbsent(network, () => candidateRef);
  }

  void recordFailure(String network, String candidateRef, String failureKind) {
    if (!_networkFailureKinds.contains(failureKind)) return;
    _failedUntil[(network, candidateRef)] = _now().add(failureMemory);
  }

  Future<ManagedProfilePayload> select({
    required TransportCandidateCatalog catalog,
    required String network,
    required HostPlatform platform,
    required SmartConnectCandidateProbe probe,
    required Future<void> cancelled,
    void Function(TransportCandidate candidate, SmartConnectCandidateProbeResult result)? onProbeResult,
    Future<void> Function(TransportCandidate candidate, Future<void> cancelled)? prepare,
    String preferredCountryCode = '',
    String recoveryCandidateRef = '',
    bool? ipv6Available,
    Set<String> excludedCandidateRefs = const {},
    Duration probeTimeout = const Duration(seconds: 4),
    Duration selectionTimeout = const Duration(seconds: 12),
  }) async {
    if (network.isEmpty) throw StateError('smart_connect_network_unavailable');
    final now = _now();
    _failedUntil.removeWhere((_, expires) => !expires.isAfter(now));
    _udpFailedUntil.removeWhere((_, expires) => !expires.isAfter(now));
    final preferred = recoveryCandidateRef.isNotEmpty
        ? recoveryCandidateRef : _successful[network];
    final eligible = catalog.candidates.where((candidate) =>
      (ipv6Available != false || candidate.family != 'ipv6') &&
      !excludedCandidateRefs.contains(candidate.candidateRef) &&
      (preferredCountryCode.isEmpty || candidate.countryCode == preferredCountryCode)).toList();
    final remembered = eligible.where((candidate) =>
      candidate.candidateRef == recoveryCandidateRef ||
      !_failedUntil.containsKey((network, candidate.candidateRef))).toList();
    final candidates = (remembered.isEmpty ? eligible : remembered)
      ..sort((a, b) {
        if (a.candidateRef == preferred && b.candidateRef != preferred) return -1;
        if (b.candidateRef == preferred && a.candidateRef != preferred) return 1;
        if (_udpFailedUntil.containsKey(network) && a.network != b.network) {
          return a.network == 'tcp' ? -1 : 1;
        }
        return a.priority.compareTo(b.priority);
      });
    bool familySiblings(TransportCandidate a, TransportCandidate b) =>
        a.warpMode == null && b.warpMode == null &&
        a.deliveryEndpointId != null && b.deliveryEndpointId != null &&
        a.nodeCode == b.nodeCode && a.profileRef == b.profileRef &&
        a.family != b.family;
    final ipv6Siblings = <String, TransportCandidate>{};
    for (final candidate in candidates.where((item) => item.family == 'ipv4')) {
      for (final sibling in candidates.where((item) => item.family == 'ipv6')) {
        if (familySiblings(candidate, sibling)) {
          ipv6Siblings[candidate.candidateRef] = sibling;
          break;
        }
      }
    }
    // Keep each family's priority order, but give the direct IPv6 sibling the
    // first native attempt even when IPv4 was this network's last success.
    for (var index = 0; index < candidates.length; index++) {
      final sibling = ipv6Siblings[candidates[index].candidateRef];
      if (sibling == null) continue;
      final siblingIndex = candidates.indexOf(sibling);
      if (siblingIndex > index) {
        candidates.insert(index, candidates.removeAt(siblingIndex));
      }
    }
    final familyStarted = <String, Completer<void>>{
      for (final sibling in ipv6Siblings.values)
        sibling.candidateRef: Completer<void>(),
    };
    final familySettled = <String, Completer<void>>{
      for (final sibling in ipv6Siblings.values)
        sibling.candidateRef: Completer<void>(),
    };
    final familyClocks = <String, Stopwatch>{};
    final ended = Completer<void>();
    final probes = <Completer<void>>{};
    final settled = <Future<void>>[];
    ManagedProfilePayload? winner;
    var cancelledByOwner = false;
    var startedCount = 0;
    var failures = 0;
    final maxAttempts = recoveryCandidateRef.isEmpty ? candidates.length : 3;
    void stop() {
      if (!ended.isCompleted) ended.complete();
      for (final cancellation in probes) {
        if (!cancellation.isCompleted) cancellation.complete();
      }
    }
    unawaited(cancelled.then((_) { cancelledByOwner = true; stop(); }));
    Future<void> run(TransportCandidate candidate, Duration remainingProbeBudget,
        void Function(Duration) countProbeTime) async {
      if (ended.isCompleted) return;
      startedCount++;
      final cancellation = Completer<void>();
      probes.add(cancellation);
      var timedOut = false;
      SmartConnectCandidateProbeResult? outcome;
      Timer? timeout;
      final probeClock = Stopwatch();
      try {
        await prepare?.call(candidate, cancellation.future);
        if (ended.isCompleted) return;
        final sibling = ipv6Siblings[candidate.candidateRef];
        if (sibling != null) {
          final started = familyStarted[sibling.candidateRef]!;
          final finished = familySettled[sibling.candidateRef]!;
          await Future.any<void>([ended.future, started.future, finished.future]);
          final elapsed = familyClocks[sibling.candidateRef]?.elapsed ?? Duration.zero;
          final reserveDelay = const Duration(milliseconds: 250) - elapsed;
          if (!ended.isCompleted && !finished.isCompleted && reserveDelay > Duration.zero) {
            await Future.any<void>([ended.future, finished.future,
              Future<void>.delayed(reserveDelay)]);
          }
          if (ended.isCompleted) return;
        }
        final nativeTimeout = remainingProbeBudget < probeTimeout
            ? remainingProbeBudget : probeTimeout;
        probeClock.start();
        final familyStart = familyStarted[candidate.candidateRef];
        if (familyStart != null) {
          familyClocks[candidate.candidateRef] = probeClock;
          familyStart.complete();
        }
        timeout = Timer(nativeTimeout, () {
          timedOut = true;
          if (!cancellation.isCompleted) cancellation.complete();
        });
        // The adapter settles its profile/native IO before completing. Keep
        // this slot occupied until settlement, including timeout/cancellation.
        outcome = await probe(candidate, cancellation.future, nativeTimeout);
        if (ended.isCompleted) return;
        if (!timedOut && outcome.profile != null) {
          onProbeResult?.call(candidate, outcome);
          winner = outcome.profile;
          if (candidate.network == 'udp') _udpFailedUntil.remove(network);
          stop();
          return;
        }
      } on BootstrapFailure catch (error) {
        if (error.statusCode == HttpStatus.unauthorized || error.statusCode == HttpStatus.forbidden || error.code == 'managed_profile_superseded') {
          stop();
          rethrow;
        }
        if (ended.isCompleted) return;
      } on Object {
        if (ended.isCompleted) return;
      } finally {
        timeout?.cancel();
        if (probeClock.isRunning) {
          probeClock.stop();
          countProbeTime(probeClock.elapsed);
        }
        probes.remove(cancellation);
        final familyFinish = familySettled[candidate.candidateRef];
        if (familyFinish != null && !familyFinish.isCompleted) familyFinish.complete();
      }
      if (ended.isCompleted) return;
      failures++;
      final failureKind = timedOut ? 'probe_budget_expired' : outcome?.failureKind ?? 'unavailable';
      final failed = SmartConnectCandidateProbeResult.failure(failureKind,
          duration: outcome?.duration ?? probeClock.elapsed);
      onProbeResult?.call(candidate, failed);
      recordFailure(network, candidate.candidateRef, failureKind);
      if (candidate.network == 'udp' && _networkFailureKinds.contains(failureKind)) {
        _udpFailedUntil[network] = _now().add(failureMemory);
        final tcp = candidates.where((item) => item.network == 'tcp').toList();
        final udp = candidates.where((item) => item.network != 'tcp').toList();
        candidates..clear()..addAll(tcp)..addAll(udp);
      }
    }
    Duration preferredProbeTime = Duration.zero;
    Future<void> worker() async {
      var probeTime = preferredProbeTime;
      while (!ended.isCompleted && candidates.isNotEmpty && startedCount < maxAttempts &&
          probeTime < selectionTimeout) {
        if (failures > 0) {
          await Future.any<void>([ended.future,
            Future<void>.delayed(Duration(milliseconds: (250 << (failures - 1).clamp(0, 2))))]);
        }
        if (ended.isCompleted || candidates.isEmpty || startedCount >= maxAttempts) return;
        await run(candidates.removeAt(0), selectionTimeout - probeTime,
            (elapsed) => probeTime += elapsed);
      }
    }
    try {
      Future<void>? preferredRun;
      var preferredSettled = false;
      if (preferred != null && preferred.isNotEmpty && candidates.isNotEmpty &&
          candidates.first.candidateRef == preferred &&
          !familyStarted.containsKey(preferred)) {
        preferredRun = run(candidates.removeAt(0), selectionTimeout,
            (elapsed) => preferredProbeTime += elapsed).whenComplete(
            () => preferredSettled = true);
        settled.add(preferredRun);
        await Future.any<void>([ended.future, preferredRun,
          Future<void>.delayed(const Duration(milliseconds: 350))]);
      }
      final parallelism = const {HostPlatform.android, HostPlatform.ios}.contains(platform) ? 3 : 4;
      final workerCount = preferredRun == null || preferredSettled
          ? parallelism : parallelism - 1;
      for (var index = 0; index < workerCount; index++) {
        settled.add(worker());
      }
      await Future.wait(settled);
      if (cancelledByOwner) throw const _ManagedProfileCancelled();
      if (winner == null) throw const SmartConnectSelectionExhausted();
      return winner!;
    } finally {
      stop();
      await Future.wait(settled);
    }
  }
}

class _SmartConnectResolver {
  _SmartConnectResolver(this.bootstrapper);

  final AppFirstRuntimeBootstrapper bootstrapper;
  static const _smartConnectTelemetryMaxNodes = 8;
  int _activeSmartConnectProbes = 0;

  Future<_SmartConnectResolution> _resolveSmartConnectNode({
    required SmartConnectProfile? smartConnect,
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required DateTime deadline,
    required Set<String> excludedNodeCodes,
    required _ManagedProfileRequests requests,
  }) async {
    requests.requireActive();
    final SmartConnectLatencyProbe probe =
        bootstrapper.smartConnectLatencyProbe ??
            ((node) => _probeSmartConnectNode(node, requests: requests));
    if (smartConnect == null ||
        !smartConnect.eligible ||
        smartConnect.shortlist.isEmpty ||
        !state.hasSession) {
      return const _SmartConnectResolution.empty();
    }

    final allowedNodes = smartConnect.shortlist
        .where(
          (node) => !excludedNodeCodes.contains(
            node.code.trim().toLowerCase(),
          ),
        )
        .toList(growable: false);
    if (allowedNodes.isEmpty) {
      return const _SmartConnectResolution.empty();
    }

    final samples = await _collectSmartConnectLatencySamples(
      smartConnect: smartConnect,
      probe: probe,
      deadline: deadline,
      excludedNodeCodes: excludedNodeCodes,
      requests: requests,
    );
    requests.requireActive();
    final selection = samples.isEmpty
        ? null
        : _selectSmartConnectNode(
            smartConnect: smartConnect,
            samples: samples,
          );
    final samplePayload = samples
        .map(
          (sample) => <String, Object?>{
            'node_code': sample.nodeCode,
            'rtt_ms': sample.rttMs,
          },
        )
        .toList(growable: false);
    var selectedNodeCode = '';
    final selectionRequestBudget = _smartConnectRemaining(deadline);
    if (selectionRequestBudget > Duration.zero) {
      final selectionClient =
          requests.attach(bootstrapper._createHttpClient(hostPlatform));
      try {
        final response = await bootstrapper._requestJson(
          method: 'POST',
          path: '/api/client/nodes/select',
          client: selectionClient,
          bearerToken: state.sessionToken,
          hostPlatform: hostPlatform,
          body: <String, Object?>{
            'mode': 'auto',
            'profile_revision': smartConnect.profileRevision,
            'transport_profile': smartConnect.transportProfile,
            'selected_node_code': selection?.selectedNodeCode,
            'previous_node_code': (selection?.previousNodeCode ?? '').isEmpty
                ? null
                : selection?.previousNodeCode,
            'samples': samplePayload,
            if (excludedNodeCodes.isNotEmpty)
              'excluded_node_codes': excludedNodeCodes.toList(growable: false),
          },
        ).timeout(selectionRequestBudget);
        requests.requireActive();
        final candidate = bootstrapper
            ._readText(response['selected_node_code'])
            .toLowerCase();
        final allowedCodes = <String>{
          for (final node in allowedNodes) node.code.trim().toLowerCase(),
        };
        if (allowedCodes.contains(candidate)) {
          selectedNodeCode = candidate;
        }
      } on Object {
        requests.requireActive();
        // The exact profile refresh below can still apply the bounded local
        // choice; a slow advisory selector must not discard that identity.
      } finally {
        requests.close(selectionClient);
      }
    }
    final locallySelectedCode =
        selection?.selectedNodeCode.trim().toLowerCase() ?? '';
    if (selectedNodeCode.isEmpty &&
        locallySelectedCode.isNotEmpty &&
        !excludedNodeCodes.contains(locallySelectedCode)) {
      selectedNodeCode = locallySelectedCode;
    }
    if (selectedNodeCode.isEmpty) {
      selectedNodeCode = allowedNodes.first.code.trim().toLowerCase();
    }
    if (_smartConnectDeadlineExpired(deadline) || samples.isEmpty) {
      return _SmartConnectResolution(
        selectedNodeCode: selectedNodeCode,
        selection: selection,
        samplePayload: samplePayload,
      );
    }
    return _SmartConnectResolution(
      selectedNodeCode: selectedNodeCode,
      selection: selection,
      samplePayload: samplePayload,
    );
  }

  Future<void> _uploadSmartConnectLatencySamples({
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required SmartConnectProfile smartConnect,
    required String selectedNodeCode,
    required _SmartConnectSelection? selection,
    required List<Map<String, Object?>> samplePayload,
    required _ManagedProfileRequests requests,
  }) async {
    final client = bootstrapper._createHttpClient(hostPlatform);
    try {
      requests.attach(client);
      await bootstrapper._requestJson(
        method: 'POST',
        path: '/api/client/nodes/latency-samples',
        client: client,
        bearerToken: state.sessionToken,
        hostPlatform: hostPlatform,
        body: <String, Object?>{
          'profile_revision': smartConnect.profileRevision,
          'transport_profile': smartConnect.transportProfile,
          'selected_node_code': selectedNodeCode.isEmpty
              ? selection?.selectedNodeCode
              : selectedNodeCode,
          'previous_node_code': (selection?.previousNodeCode ?? '').isEmpty
              ? null
              : selection?.previousNodeCode,
          'stickiness_applied': selection?.stickinessApplied ?? false,
          'samples': samplePayload,
        },
      );
    } on Object {
      // RTT upload is telemetry only. The selected manifest is authoritative.
    } finally {
      requests.close(client);
    }
  }

  Future<List<_SmartConnectLatencySample>> _collectSmartConnectLatencySamples({
    required SmartConnectProfile smartConnect,
    required SmartConnectLatencyProbe probe,
    required DateTime deadline,
    Set<String> excludedNodeCodes = const <String>{},
    required _ManagedProfileRequests requests,
  }) async {
    final nodes = smartConnect.shortlist
        .take(_smartConnectTelemetryMaxNodes)
        .where((node) => node.code.trim().isNotEmpty)
        .where(
          (node) => !excludedNodeCodes.contains(
            node.code.trim().toLowerCase(),
          ),
        )
        .toList(growable: false);
    final samples = List<_SmartConnectLatencySample?>.filled(
      nodes.length,
      null,
    );
    var nextIndex = 0;
    final workerCount = min(
      max(1, bootstrapper.smartConnectProbeConcurrency),
      nodes.length,
    );

    Future<void> collectOne() async {
      while (
          nextIndex < nodes.length && !_smartConnectDeadlineExpired(deadline)) {
        requests.requireActive();
        final index = nextIndex++;
        final node = nodes[index];
        final remaining = _smartConnectRemaining(deadline);
        if (remaining <= Duration.zero) {
          return;
        }
        final probeBudget = _shorterDuration(
          bootstrapper.smartConnectProbeTimeout,
          remaining,
        );
        if (_activeSmartConnectProbes >=
            max(1, bootstrapper.smartConnectProbeConcurrency)) {
          return;
        }
        _activeSmartConnectProbes += 1;
        // Future.timeout only ends this wait. Keep its slot occupied until the
        // underlying probe settles, including across later profile resolutions.
        final pendingProbe = Future<int?>.sync(() => probe(node)).whenComplete(
          () => _activeSmartConnectProbes -= 1,
        );
        try {
          final rttMs = await pendingProbe.timeout(
            probeBudget,
          );
          requests.requireActive();
          if (rttMs == null || rttMs < 1 || rttMs > 60000) {
            continue;
          }
          samples[index] = _SmartConnectLatencySample(
            nodeCode: node.code.trim().toLowerCase(),
            rttMs: rttMs,
            cpuPenalty: node.rankHint.cpuPenalty,
            backendPenalty: node.rankHint.backendPenalty,
            rank: node.rank,
          );
        } on TimeoutException {
          requests.requireActive();
          if (probeBudget == remaining) {
            return;
          }
        } on Object {
          requests.requireActive();
          // One unavailable candidate must not hold up the profile.
        }
      }
    }

    await Future.wait<void>(
      List<Future<void>>.generate(workerCount, (_) => collectOne()),
    );
    return samples.whereType<_SmartConnectLatencySample>().toList(
          growable: false,
        );
  }

  bool _smartConnectDeadlineExpired(DateTime deadline) =>
      !DateTime.now().isBefore(deadline);

  Duration _smartConnectRemaining(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration _shorterDuration(Duration left, Duration right) =>
      left <= right ? left : right;

  Future<int?> _probeSmartConnectNode(
    SmartConnectNode node, {
    required _ManagedProfileRequests requests,
  }) async {
    requests.requireActive();
    final host = node.probeHost.trim();
    final port = node.probePort;
    if (host.isEmpty || port <= 0 || port > 65535) {
      return null;
    }

    Socket? socket;
    ConnectionTask<Socket>? connection;
    var finished = false;
    final stopwatch = Stopwatch()..start();
    try {
      connection = await Socket.startConnect(host, port);
      // DNS resolution may finish after cancellation. Attach the socket
      // listener before cancelling the returned task so its error is consumed.
      final pendingSocket = connection.socket.then((connected) {
        if (finished || requests.isCancelled) {
          connected.destroy();
          throw const _ManagedProfileCancelled();
        }
        return connected;
      });
      requests.attachConnection(connection);
      socket =
          await pendingSocket.timeout(bootstrapper.smartConnectProbeTimeout);
      requests.requireActive();
      stopwatch.stop();
      return max(1, min(60000, stopwatch.elapsedMilliseconds));
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } finally {
      finished = true;
      stopwatch.stop();
      if (connection != null) requests.closeConnection(connection);
      socket?.destroy();
    }
  }

  _SmartConnectSelection _selectSmartConnectNode({
    required SmartConnectProfile smartConnect,
    required List<_SmartConnectLatencySample> samples,
  }) {
    final ordered = List<_SmartConnectLatencySample>.from(samples)
      ..sort((left, right) {
        final scoreDelta = left.effectiveScore.compareTo(right.effectiveScore);
        if (scoreDelta != 0) {
          return scoreDelta;
        }
        return left.rank.compareTo(right.rank);
      });
    final best = ordered.first;
    final previousNodeCode =
        smartConnect.stickiness.preferredNodeCode.trim().toLowerCase();
    final thresholdPercent = smartConnect.stickiness.thresholdPercent > 0
        ? smartConnect.stickiness.thresholdPercent
        : 15;
    _SmartConnectLatencySample? stickySample;
    for (final sample in ordered) {
      if (sample.nodeCode == previousNodeCode) {
        stickySample = sample;
        break;
      }
    }
    if (stickySample != null && stickySample.nodeCode != best.nodeCode) {
      final stickyScore = max(stickySample.effectiveScore, 1);
      final improvementPercent =
          ((stickyScore - best.effectiveScore) / stickyScore) * 100;
      if (improvementPercent < thresholdPercent) {
        return _SmartConnectSelection(
          selectedNodeCode: stickySample.nodeCode,
          previousNodeCode: previousNodeCode,
          stickinessApplied: true,
        );
      }
    }
    return _SmartConnectSelection(
      selectedNodeCode: best.nodeCode,
      previousNodeCode: previousNodeCode,
      stickinessApplied: false,
    );
  }
}

class _SmartConnectLatencySample {
  const _SmartConnectLatencySample({
    required this.nodeCode,
    required this.rttMs,
    required this.cpuPenalty,
    required this.backendPenalty,
    required this.rank,
  });

  final String nodeCode;
  final int rttMs;
  final int cpuPenalty;
  final int backendPenalty;
  final int rank;

  int get effectiveScore => rttMs + cpuPenalty + backendPenalty;
}

class _SmartConnectSelection {
  const _SmartConnectSelection({
    required this.selectedNodeCode,
    required this.previousNodeCode,
    required this.stickinessApplied,
  });

  final String selectedNodeCode;
  final String previousNodeCode;
  final bool stickinessApplied;
}

class _SmartConnectResolution {
  const _SmartConnectResolution({
    required this.selectedNodeCode,
    required this.selection,
    required this.samplePayload,
  });

  const _SmartConnectResolution.empty()
      : selectedNodeCode = '',
        selection = null,
        samplePayload = const <Map<String, Object?>>[];

  final String selectedNodeCode;
  final _SmartConnectSelection? selection;
  final List<Map<String, Object?>> samplePayload;
}
