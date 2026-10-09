import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokrov_app_shell/app_shell.dart' hide TransportCandidate;
import 'package:pokrov_app_shell/routing_catalog_contract.dart';
import 'package:pokrov_app_shell/routing_catalog_policy.dart';
import 'package:pokrov_app_shell/src/features/rules/routing_catalog_store.dart';
import 'package:pokrov_app_shell/src/shell/managed_profile_cache.dart';
import 'package:pokrov_app_shell/src/shell/runtime_connectivity_report.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

final _candidates = List.generate(4, (index) => TransportCandidate(
  candidateRef: 'de:profile_$index', profileRef: 'profile_$index', nodeCode: 'de',
  countryCode: 'DE', protocol: 'vless', transport: 'tcp', protection: 'reality',
  priority: index, network: 'tcp', flow: '', minimumClientRelease: '1.2.0',
  minimumCoreRelease: null, platforms: {HostPlatform.android, HostPlatform.windows}, requiredFeatures: const {},
));

class _Bootstrapper implements ManagedProfileBootstrapper, AppFirstNodePreferenceService {
  _Bootstrapper({this.warpEnabled = false, this.catalog = false, this.bundle = false});
  final bool catalog;
  final bool bundle;
  Set<String>? bundledCandidateRefs;
  List<TransportCandidate> candidates = _candidates;
  Duration exactProfileDelay = Duration.zero;
  Object? exactProfileFailure;
  String accessNetworkAsn = '';
  String? materialConfigPayload;
  final cancelledExactProfiles = <String>[];
  SmartConnectProfile? smartConnect;
  final nodePreferences = <SmartConnectProfile>[];
  final resolutions = <({String selected, bool select, bool cache})>[];
  final requestedCountries = <String>[];
  final bool warpEnabled;
  Completer<void>? gate;
  Object? failure;
  StackTrace? failureStack;
  String? lastCoreRelease;
  Duration? lastProfileTimeout;
  final entered = Completer<void>();
  bool cancelled = false;

  @override
  Future<SmartConnectPreferenceResult> setPreferredSmartConnectNode({
    required HostPlatform hostPlatform, required SmartConnectProfile smartConnect, required String nodeCode,
  }) async {
    nodePreferences.add(smartConnect);
    return SmartConnectPreferenceResult(preferredNodeCode: nodeCode, acceptedSamples: 0);
  }

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const [],
    String preferredNodeCode = '',
    String preferredVariantId = 'direct',
    String preferredCountryCode = '',
    String preferredCandidateRef = '',
    Set<String> excludedNodeCodes = const {},
    String tcpFallbackFromRevision = '',
    Set<RuntimeTransportFeature> runtimeFeatures = const {},
    String? coreRelease,
    bool selectCandidate = true,
    String selectedCandidateRef = '',
    bool cacheResult = true,
    Duration? timeout,
    Future<void>? cancelled,
  }) async {
    lastCoreRelease = coreRelease;
    lastProfileTimeout = timeout;
    requestedCountries.add(preferredCountryCode);
    resolutions.add((selected: selectedCandidateRef, select: selectCandidate, cache: cacheResult));
    if (!entered.isCompleted) entered.complete();
    unawaited(cancelled?.then((_) => this.cancelled = true));
    await gate?.future;
    if (selectedCandidateRef.isNotEmpty && exactProfileDelay > Duration.zero) {
      var stopped = false;
      unawaited(cancelled?.then((_) => stopped = true));
      await Future<void>.delayed(exactProfileDelay);
      if (stopped) cancelledExactProfiles.add(selectedCandidateRef);
    }
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack ?? StackTrace.current);
    if (selectedCandidateRef.isNotEmpty && exactProfileFailure != null) throw exactProfileFailure!;
    final nodeCode = preferredNodeCode.isEmpty ? candidates.first.nodeCode : preferredNodeCode;
    final selected = candidates.firstWhere((candidate) => candidate.candidateRef ==
        (selectedCandidateRef.isEmpty ? candidates.first.candidateRef : selectedCandidateRef));
    ManagedProfilePayload material(TransportCandidate candidate) => ManagedProfilePayload(
      accessNetworkAsn: accessNetworkAsn,
      profileName: catalog ? candidate.candidateRef : '$nodeCode:profile_0',
      transportCatalog: catalog ? TransportCandidateCatalog(revision: 'test',
          selectedCandidateRef: selected.candidateRef, candidates: candidates) : null,
      materialCandidateRef: bundle ? candidate.candidateRef : '',
      smartConnect: smartConnect,
      source: RuntimeProfileSource(revision: 'test', origin: RuntimeProfileSourceOrigin.managedManifest,
          protocol: candidate.protocol),
      resolvedNodeCode: nodeCode,
      configPayload: materialConfigPayload ??
          '{"inbounds":[{"type":"tun","tag":"tun-in"}],"outbounds":[{"type":"socks","tag":"node","server":"127.0.0.1","server_port":1080},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
      materializedForRuntime: true,
      routeMode: routeMode,
      warpPolicy: WarpRuntimePolicy.clientLocalDefault.copyWith(
          mode: candidate.warpMode == 'warp_direct' ? 'warp_direct' : 'warp_over_proxy',
          id: candidate.warpMode == 'warp_direct' ? 'warp-direct:test-install' : 'p1',
          userConsented: warpEnabled),
    );
    final payload = material(selected);
    return bundle ? payload.copyWith(candidateMaterials: {
      for (final candidate in candidates)
        if (bundledCandidateRefs?.contains(candidate.candidateRef) ?? true)
          candidate.candidateRef: material(candidate),
    }) : payload;
  }
}

class _ManifestBootstrapper extends _Bootstrapper implements AppFirstTransportManifestService {
  @override
  bool get transportManifestEnabled => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CachedBootstrapper extends _Bootstrapper implements CachedManagedProfileBootstrapper {
  String? lastSuccessfulNetworkKey;
  final provenNetworks = <(String?, String?)>[];
  @override
  Future<String?> successfulCandidateRef(ManagedProfileCacheInputs inputs,
      String networkSelectionKey) async {
    lastSuccessfulNetworkKey = networkSelectionKey;
    return null;
  }
  _CachedBootstrapper({bool warpEnabled = false, bool bundle = false})
      : super(catalog: true, warpEnabled: warpEnabled, bundle: bundle);
  bool cacheAvailable = true;
  Future<void>? cacheRefreshGate;
  Object? nextCacheRefreshFailure;
  final cacheRefreshEntered = Completer<void>();
  final refreshedCoreReleases = <String?>[];
  final refreshedInputs = <ManagedProfileCacheInputs>[];
  final refreshedFeatures = <Set<RuntimeTransportFeature>>[];
  static final alternatives = [
    _candidates.first,
    for (final (index, protocol, protection) in [(1, 'awg', 'awg31'), (2, 'hysteria2', 'tls')])
      TransportCandidate(candidateRef: 'de:cached_$index', profileRef: 'cached_$index', nodeCode: 'de',
        countryCode: 'DE', protocol: protocol, transport: 'udp', protection: protection,
        priority: index, network: 'udp', flow: '', minimumClientRelease: '1.2.0',
        minimumCoreRelease: null, platforms: {HostPlatform.android, HostPlatform.windows}, requiredFeatures: const {}),
  ];

  @override
  Future<ManagedProfilePayload?> loadCachedManagedProfile(ManagedProfileCacheInputs inputs, {
    bool preferProven = false, String selectedCandidateRef = '',
    Set<RuntimeTransportFeature>? runtimeFeatures, String? coreRelease,
  }) async {
    if (!cacheAvailable) return null;
    final selected = alternatives.firstWhere((candidate) =>
        candidate.candidateRef == (selectedCandidateRef.isEmpty ? 'de:profile_0' : selectedCandidateRef));
    return ManagedProfilePayload(profileName: selected.candidateRef, cacheEntryId: selected.candidateRef,
      transportCatalog: TransportCandidateCatalog(revision: 'cached',
          selectedCandidateRef: selected.candidateRef, candidates: alternatives),
      source: RuntimeProfileSource(revision: 'cached', origin: RuntimeProfileSourceOrigin.managedManifest,
          protocol: selected.protocol),
      configPayload: materialConfigPayload ?? '{"inbounds":[{"type":"tun","tag":"tun-in"}],"outbounds":[{"type":"socks","tag":"node","server":"127.0.0.1","server_port":1080},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
      materializedForRuntime: true, routeMode: inputs.routeMode, resolvedNodeCode: 'de');
  }
  @override
  Future<void> cacheResolvedManagedProfile(ManagedProfileCacheInputs inputs, ManagedProfilePayload payload,
      {Future<void>? cancelled, bool candidateOnly = false}) async {}
  @override
  Future<void> refreshCachedManagedProfile(ManagedProfileCacheInputs inputs, {
    Set<RuntimeTransportFeature> runtimeFeatures = const {}, String? coreRelease, Future<void>? cancelled,
    String selectedCandidateRef = '', bool alternativesOnly = false,
  }) async {
    refreshedCoreReleases.add(coreRelease);
    refreshedInputs.add(inputs);
    refreshedFeatures.add(runtimeFeatures);
    if (!cacheRefreshEntered.isCompleted) cacheRefreshEntered.complete();
    await cacheRefreshGate;
    final failure = nextCacheRefreshFailure;
    nextCacheRefreshFailure = null;
    if (failure != null) throw failure;
  }
  @override
  Future<void> markManagedProfileProven(ManagedProfileCacheInputs inputs, String entryId,
      {String? networkSelectionKey, String? offlineNetworkSelectionKey}) async {
    provenNetworks.add((networkSelectionKey, offlineNetworkSelectionKey));
  }
  @override
  Future<ManagedProfileOfflineState> classifyManagedProfileFailure(ManagedProfileCacheInputs inputs,
      {bool? networkAvailable, bool? captivePortal}) async => ManagedProfileOfflineState.apiUnavailable;
}

class _StatsBootstrapper extends _Bootstrapper implements AppFirstExperienceService {
  _StatsBootstrapper({bool warpEnabled = false, bool bundle = false})
      : super(catalog: true, warpEnabled: warpEnabled, bundle: bundle);
  final reports = <Map<String, Object?>>[];
  final runtimeCalls = <Map<String, Object?>>[];
  bool failFirstRunningReport = false;
  final failedProbeReportCandidates = <String>{};
  int failedRunningReports = 0;
  Completer<void>? runningReportGate;
  Completer<void>? failedReportGate;
  final actualReports = <Map<String, Object?>>[];

  @override
  Future<void> reportRuntimeStats({
    required HostPlatform hostPlatform, required String runtimePhase,
    required bool connected, String errorCode = '', String failureKind = '',
    String selectedNodeCode = '', String routeMode = '', int? durationMs,
    int? attemptNumber, bool? retryable, String networkClass = '',
    String carrierMccMnc = '', String carrierName = '', String candidateTransport = '',
    String candidateRef = '', String candidateVariant = '',
    String accessNetworkAsn = '', List<Map<String, Object?>> candidateProbes = const [],
    RuntimeSnapshot? connectivitySnapshot,
  }) async {
    runtimeCalls.add({'runtime_phase': runtimePhase, 'error_code': errorCode});
    actualReports.add({'runtime_phase': runtimePhase, 'duration_ms': durationMs,
      'attempt_number': attemptNumber, 'error_code': errorCode, 'retryable': retryable,
      'failure_kind': failureKind, 'connectivity': runtimeConnectivityReport(connectivitySnapshot),
      'native_kind': connectivitySnapshot?.lastFailureKind,
      'candidate_ref': candidateRef, 'candidate_variant': candidateVariant,
      'selected_node_code': selectedNodeCode});
    if (runtimePhase == 'running') await runningReportGate?.future;
    if (runtimePhase == 'failed') await failedReportGate?.future;
    if (runtimePhase == 'running' && failFirstRunningReport) {
      failFirstRunningReport = false;
      failedRunningReports += 1;
      throw const BootstrapFailure('temporary stats failure', operationalCode: 'API-002');
    }
    if (candidateProbes.isNotEmpty && failedProbeReportCandidates.contains(candidateRef)) {
      throw const BootstrapFailure('temporary stats failure', operationalCode: 'API-002');
    }
    if (candidateProbes.isNotEmpty) reports.add({
      'runtime_phase': runtimePhase,
      'attempt_number': attemptNumber,
      'connected': connected,
      'candidate_ref': candidateRef,
      'candidate_transport': candidateTransport,
      'candidate_probes': candidateProbes,
    });
  }

  @override
  Future<void> completeAccountOnboarding({required HostPlatform hostPlatform}) async {}
}

class _Runtime implements PokrovRuntimeEngine, RuntimeConnectCancellation, RuntimeCandidateProbing, RuntimeProtectedHandoff, RuntimeNetworkAvailability {
  _Runtime({this.heldOperation, this.hostPlatform = HostPlatform.android});
  final String? heldOperation;
  bool supportsCandidates = false;
  bool coreInitializationPending = false;
  Duration probeDelay = Duration.zero;
  Duration probeDuration = Duration.zero;
  final probeTimeouts = <Duration>[];
  String? coreVersion;
  bool holdProbes = false;
  bool failProbeCancellation = false;
  bool failHandoff = false;
  final failedProbeProtocols = <String>{};
  final failedProbeProfiles = <String>{};
  final failedProbeCandidates = <String>{};
  final heldProbeCandidates = <String>{};
  final probedPayloads = <ManagedProfilePayload>[];
  final probedWarpModes = <String>[];
  final heldProbeProtocols = <String>{};
  final heldProbeProfiles = <String>{};
  Future<void>? alternateProbeGate;
  final probedProtocols = <String>[];
  final handoffProfiles = <String>[];
  final stagedPayloads = <ManagedProfilePayload>[];
  String? failedHandoffProfile;
  bool declineNextHandoff = false;
  bool failFirstActivation = false;
  String activationFailureKind = 'core_egress_timeout';
  RuntimeProfileSource? profileSource;
  String? profileDigest;
  DateTime? proofObservedAt;
  String? activeDisplayNodeCode;
  bool? transportProofPending;
  Object? connectFailure;
  bool restoredHandoffGuard = false;
  final probeRelease = Completer<void>();
  final probeStarted = Completer<void>();
  final alternateProbeStarted = Completer<void>();
  final handoffStarted = Completer<void>();
  Completer<void>? handoffRelease;
  final activeProbes = <String, Completer<void>>{};
  String? stagedProfile;
  int handoffCalls = 0;
  bool? networkAvailable = true;
  bool? captivePortal;
  String candidateKey = 'network-a';
  String candidateContext = 'context-a';
  String? lastStopReason;
  Completer<RuntimeCandidateNetwork>? nextNetworkRead;
  final networkReadEntered = Completer<void>();
  final probeContexts = <String>[];
  final probeStages = <String, String>{};
  final probeFailureKinds = <String, String>{};

  @override
  Future<RuntimeNetworkStatusObservation> readNetworkAvailability() async => RuntimeNetworkStatusObservation(
      networkAvailable: networkAvailable, captivePortal: captivePortal);

  @override
  Future<RuntimeCandidateNetwork> readCandidateNetwork() async {
    final gate = nextNetworkRead;
    if (gate != null) {
      nextNetworkRead = null;
      if (!networkReadEntered.isCompleted) networkReadEntered.complete();
      return gate.future;
    }
    return RuntimeCandidateNetwork(selectionKey: candidateKey, contextRef: candidateContext,
        networkAvailable: networkAvailable, captivePortal: captivePortal, networkClass: 'wifi');
  }
  @override
  Future<RuntimeCandidateProbeResult> probeCandidate({required String probeId,
      required ManagedProfilePayload payload, required Duration timeout, required String expectedNetworkContext}) async {
    probeContexts.add(expectedNetworkContext);
    probeTimeouts.add(timeout);
    expect(value(phase).transportCapabilities, isNotNull);
    final protocol = payload.source?.protocol ?? 'vless';
    probedPayloads.add(payload);
    probedProtocols.add(protocol);
    probedWarpModes.add(payload.warpPolicy.canEnableRuntime ? payload.warpPolicy.mode : '');
    final cancelled = Completer<void>();
    activeProbes[probeId] = cancelled;
    if (!probeStarted.isCompleted) probeStarted.complete();
    if (protocol != 'vless' && !alternateProbeStarted.isCompleted) alternateProbeStarted.complete();
    if (probeDelay > Duration.zero) {
      await Future.any<void>([
        Future<void>.delayed(probeDelay), cancelled.future,
      ]);
    }
    if (holdProbes) {
      if (payload.profileName == 'de:profile_1') { await Future.any([probeRelease.future, cancelled.future]); }
      else { await cancelled.future; }
    }
    if (heldProbeProtocols.contains(protocol)) await cancelled.future;
    if (heldProbeProfiles.contains(payload.profileName)) await cancelled.future;
    if (heldProbeCandidates.contains(payload.materialCandidate?.candidateRef)) {
      await Future.any([probeRelease.future, cancelled.future]);
    }
    if (alternateProbeGate != null && protocol != 'vless') {
      await Future.any([alternateProbeGate!, cancelled.future]);
    }
    activeProbes.remove(probeId);
    final success = !cancelled.isCompleted && !failedProbeProtocols.contains(protocol) &&
        !failedProbeCandidates.contains(payload.materialCandidate?.candidateRef) &&
        !failedProbeProfiles.contains(payload.profileName);
    return RuntimeCandidateProbeResult(success: success,
        failureKind: success ? '' : probeFailureKinds[payload.profileName] ?? 'cancelled',
        duration: probeDuration, probeStage: probeStages[payload.profileName]);
  }
  @override
  Future<void> cancelCandidateProbe(String probeId) async {
    final pending = activeProbes[probeId];
    if (pending != null && !pending.isCompleted) {
      if (failProbeCancellation) {
        unawaited(Future<void>.delayed(const Duration(milliseconds: 10), pending.complete));
        throw StateError('candidate_cancel_channel_unavailable');
      }
      pending.complete();
    }
  }
  @override
  Future<RuntimeSnapshot> replaceManagedProfile(ManagedProfilePayload payload, {
    required bool Function() operationIsCurrent,
    Future<String> Function(String, RuntimeSnapshot)? persistRestrictions,
  }) async {
    calls.add('replace');
    if (declineNextHandoff) {
      declineNextHandoff = false;
      phase = RuntimePhase.configStaged;
      throw StateError('protected_handoff_unavailable');
    }
    stagedProfile = payload.profileName;
    stagedPayloads.add(payload);
    handoffProfiles.add(payload.profileName);
    handoffCalls++;
    _request = 'handoff-$handoffCalls';
    expect(activeProbes, isEmpty);
    if (!handoffStarted.isCompleted) handoffStarted.complete();
    await handoffRelease?.future;
    warpEgressFailure = failHandoff || failedHandoffProfile == payload.profileName || cancelled.contains(_request);
    if (!warpEgressFailure) restoredHandoffGuard = false;
    phase = hostPlatform == HostPlatform.windows && warpEgressFailure
        ? RuntimePhase.configStaged : RuntimePhase.running;
    return value(phase);
  }

  final HostPlatform hostPlatform;
  final operationEntered = Completer<void>();
  final releaseOperation = Completer<void>();
  final stopReadEntered = Completer<void>();
  Completer<void>? releaseStopRead;
  final calls = <String>[];
  final cancelled = <String>{};
  RuntimePhase phase = RuntimePhase.artifactReady;
  int connectCalls = 0;
  bool mutationPending = false;
  bool overlappingMutation = false;
  bool pendingFirstEgress = false;
  bool warpEgressFailure = false;
  String? _request;

  RuntimeSnapshot value(RuntimePhase phase) => RuntimeSnapshot(
        hostPlatform: hostPlatform,
        lane: hostPlatform == HostPlatform.android
            ? RuntimeLane.mobileArtifact
            : RuntimeLane.windowsService,
        phase: phase,
        artifactDirectory: null,
        coreBinaryPath: null,
        helperBinaryPath: null,
        stagedConfigPath: phase.index >= RuntimePhase.configStaged.index
            ? '/test/profile.json'
            : null,
        supportsLiveConnect: true,
        protectionRetained: restoredHandoffGuard,
        canInitialize: phase == RuntimePhase.artifactReady || coreInitializationPending,
        canConnect: phase.index >= RuntimePhase.configStaged.index,
        message: '',
        lastStopReason: lastStopReason,
        fetchedProfileSource: profileSource,
        stagedProfileSource: profileSource,
        effectiveProfileSource: profileDigest != null && phase == RuntimePhase.running &&
            !warpEgressFailure && !pendingFirstEgress ? profileSource : null,
        stagedProfileDigest: stagedProfile == null ? null : profileDigest,
        effectiveProfileDigest: phase == RuntimePhase.running ? profileDigest : null,
        profileIdentityOrigin: profileDigest == null ? null : hostPlatform == HostPlatform.android
            ? 'android_private_stage_request_sha256' : 'windows_service_stage_request_sha256',
        proofObservedAt: phase == RuntimePhase.running && !warpEgressFailure ? proofObservedAt : null,
        activeDisplayNodeCode: activeDisplayNodeCode,
        transportProofPending: transportProofPending,
        transportCapabilities: supportsCandidates && phase != RuntimePhase.artifactReady && !coreInitializationPending
            ? RuntimeTransportCapabilities.fromWire(jsonEncode({'schema': 1,
                'features': RuntimeTransportFeature.values.map((feature) => feature.wireName).toList()..sort()})) : null,
        coreVersion: phase == RuntimePhase.artifactReady || coreInitializationPending ? null : coreVersion,
        hostHealth: phase == RuntimePhase.running
            ? RuntimeHostHealth.healthy
            : RuntimeHostHealth.unknown,
        dnsState: phase == RuntimePhase.running
            ? RuntimeDiagnosticState.healthy
            : RuntimeDiagnosticState.unknown,
        uplinkState: phase == RuntimePhase.running
            ? RuntimeDiagnosticState.healthy
            : RuntimeDiagnosticState.unknown,
        dnsReady: phase == RuntimePhase.running,
        coreEgressValidated:
            phase == RuntimePhase.running && !pendingFirstEgress
                ? !warpEgressFailure
                : null,
        coreEgressValidationRequired: true,
        lastFailureKind: failedHandoffProfile != null && warpEgressFailure && phase == RuntimePhase.configStaged
            ? 'core_egress_dns_failed' : failFirstActivation && connectCalls == 1 && phase == RuntimePhase.configStaged
            ? activationFailureKind : restoredHandoffGuard ? 'protected_handoff_failed' : phase == RuntimePhase.running &&
                warpEgressFailure &&
                !pendingFirstEgress
            ? 'core_egress_probe_failed'
            : null,
      );

  Future<RuntimeSnapshot> mutate(String name, RuntimePhase next) async {
    calls.add(name);
    if (mutationPending) overlappingMutation = true;
    mutationPending = true;
    if (name == heldOperation && !operationEntered.isCompleted) {
      operationEntered.complete();
      await releaseOperation.future;
    }
    mutationPending = false;
    phase = name == 'connect' && cancelled.contains(_request)
        ? RuntimePhase.configStaged
        : next;
    // The old native call can return its pre-cancellation success snapshot.
    return value(next);
  }

  @override
  Future<RuntimeSnapshot> snapshot() async {
    calls.add('snapshot');
    if (phase == RuntimePhase.running) pendingFirstEgress = false;
    if (cancelled.isNotEmpty && releaseStopRead != null) {
      if (!stopReadEntered.isCompleted) stopReadEntered.complete();
      await releaseStopRead!.future;
    }
    return value(phase);
  }

  @override
  Future<RuntimeSnapshot> initialize() {
    coreInitializationPending = false;
    return mutate('initialize', RuntimePhase.initialized);
  }
  @override
  Future<RuntimeSnapshot> stageManagedProfile(ManagedProfilePayload payload) {
    expectSync(activeProbes, isEmpty, reason: 'all candidate workers must settle before the single TUN owner starts');
    stagedProfile = payload.profileName;
    stagedPayloads.add(payload);
    return mutate('stage', RuntimePhase.configStaged);
  }
  @override
  Future<RuntimeSnapshot> invalidateManagedProfile() async {
    calls.add('invalidate');
    return value(phase);
  }
  @override
  Future<RuntimeSnapshot> connect() {
    _request = 'request-${++connectCalls}';
    if (connectFailure != null) return Future.error(connectFailure!);
    return mutate('connect', failFirstActivation && connectCalls == 1
        ? RuntimePhase.configStaged : RuntimePhase.running);
  }

  @override
  Future<RuntimeSnapshot> disconnect() =>
      mutate('disconnect', RuntimePhase.configStaged);
  @override
  Future<WarpApplyResult> applyWarp({required bool enabled}) async {
    if (heldOperation != 'warp')
      return const WarpApplyResult.notApplied(reason: 'not_used');
    calls.add('warp');
    mutationPending = true;
    operationEntered.complete();
    await releaseOperation.future;
    mutationPending = false;
    return const WarpApplyResult(
        applied: true, effectiveAt: 'next_connect', fallbackUsed: true);
  }

  @override
  Future<RuntimeLiveStats> liveStats() async =>
      const RuntimeLiveStats.unavailable();
  @override
  Future<RuntimePushToken> pushToken() async =>
      const RuntimePushToken.unavailable();
  @override
  String? get activeConnectRequestId => _request;
  @override
  String? connectRequestForSnapshot(RuntimeSnapshot snapshot) => _request;
  @override
  Future<void> cancelConnectRequest(String requestId) async {
    calls.add('cancel:$requestId');
    cancelled.add(requestId);
  }
}

class _ExperienceStore implements PokrovClientExperienceStore {
  PokrovClientExperienceState saved = const PokrovClientExperienceState.empty();
  @override
  Future<PokrovClientExperienceState> read() async =>
      const PokrovClientExperienceState.empty();
  @override
  Future<void> write(PokrovClientExperienceState state) async { saved = state; }
}

class _FirstLaunchStore implements PokrovFirstLaunchStore {
  @override
  Future<bool> isCompleted() async => true;
  @override
  Future<void> markCompleted() async {}
}

class _CatalogPickerBootstrapper extends _CachedBootstrapper implements
    AppFirstRoutingCatalogService, AppFirstClientDataService, AppFirstSmartAccessService {
  _CatalogPickerBootstrapper(this.result, {this.coldAccess = false});
  final RoutingCatalogFetchResult result;
  final bool coldAccess;
  int subscriptionReads = 0;
  int catalogReads = 0;
  ClientLocationsCatalog? locationsCatalog;
  @override
  Future<ClientLocationsCatalog> fetchLocationsCatalog({required HostPlatform hostPlatform, String query = ''}) async =>
      locationsCatalog ?? ClientLocationsCatalog.fromJson({'countries': []});
  @override
  bool get routingCatalogEnabled => true;
  @override
  bool get smartAccessEnabled => false;
  @override
  Future<ClientSubscriptionInfo> fetchClientSubscription({required HostPlatform hostPlatform,
    Duration? requestTimeout, Future<void>? cancelled}) async {
    subscriptionReads++;
    return ClientSubscriptionInfo(lane: 'trial',
      accessState: coldAccess && subscriptionReads == 1 ? '' : 'trial_premium',
      expiresAt: '', daysLeft: 4, autoRenew: false, renewUrl: null,
      plans: const [], trafficPolicy: const {});
  }
  @override
  Future<RoutingCatalogFetchResult?> fetchRoutingCatalog({required HostPlatform hostPlatform,
    bool cacheOnly = false, Future<void>? cancelled}) async {
    catalogReads++;
    return result;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CatalogPickerExperience extends _ExperienceStore {
  @override
  Future<PokrovClientExperienceState> read() async =>
      const PokrovClientExperienceState.empty().copyWith(interfaceMode: PokrovInterfaceMode.advanced);
}

Future<RoutingCatalogFetchResult> _pickerCatalog() async {
  final now = DateTime.now().toUtc();
  final issued = '${now.subtract(const Duration(minutes: 1)).toIso8601String().split('.').first}Z';
  final expires = '${now.add(const Duration(hours: 1)).toIso8601String().split('.').first}Z';
  final payload = <String, Object?>{
    'audience': 'lab', 'evidence': <Object>[], 'expires_at': expires,
    'issued_at': issued, 'revision': 1, 'schema_version': 'pokrov-routing-catalog-v1',
    'security_revision': 1,
    'services': [{
      'access_states': ['trial_premium'], 'android': <Object>[], 'categories': ['test'],
      'classification': 'unknown', 'display_name': 'Fixture service', 'domains': <Object>[],
      'enabled': false, 'evidence_ids': <Object>[], 'evidence_status': 'source_only',
      'external_gateway_policy': 'forbidden', 'networks': <Object>[], 'platforms': ['windows'],
      'provider_capability_refs': <Object>[], 'reason': 'No route authority',
      'route_intents': <Object>[], 'service_id': 'test-service', 'source_ids': ['fixture'],
      'windows': <Object>[],
    }],
    'sources': [{
      'expires_at': expires, 'license': 'test', 'retrieved_at': issued,
      'revision': 'test', 'sha256': List.filled(32, '01').join(),
      'source_id': 'fixture', 'url': 'https://fixture.invalid/catalog',
    }],
  };
  final body = utf8.encode(jsonEncode(payload));
  final algorithm = Ed25519();
  final key = await algorithm.newKeyPair();
  final public = await key.extractPublicKey();
  final signature = await algorithm.sign(
      [...utf8.encode('pokrov-routing-catalog-v1\n'), ...body], keyPair: key);
  final digest = (await Sha256().hash(body)).bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final catalog = await RoutingCatalogVerifier(publicKeysById: {'fixture': base64Encode(public.bytes)},
      audience: 'lab').verify({
    'algorithm': 'Ed25519', 'key_id': 'fixture', 'payload': payload,
    'payload_sha256': digest, 'signature_b64': base64UrlEncode(signature.bytes).replaceAll('=', ''),
  }, now: now, minimumRevision: 0, minimumSecurityRevision: 1, currentPayloadSha256: null);
  RoutingCatalogPolicy.fromVerified(catalog);
  return RoutingCatalogFetchResult(catalog: catalog, usingCache: false);
}

Future<void> _openPicker(WidgetTester tester, _CatalogPickerBootstrapper bootstrapper,
    {bool holdNativeSnapshot = false}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('space.pokrov/runtime_engine');
  messenger.setMockMethodCallHandler(channel, (call) async {
    expect(call.method, isNot(anyOf('runtimeEngine.stageManagedProfile', 'runtimeEngine.connect')));
    if (holdNativeSnapshot && bootstrapper.catalogReads > 0 && call.method == 'runtimeEngine.snapshot') {
      return Completer<Map<String, Object?>>().future;
    }
    return {'phase': 'initialized', 'coreVersion': '1.2.10',
      'supportsLiveConnect': true, 'canInitialize': false, 'canConnect': true,
      'routingCatalogWindowVersion': 1};
  });
  await tester.pumpWidget(MaterialApp(home: PokrovSeedShell(
    appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
    bootstrapper: bootstrapper, firstLaunchStore: _FirstLaunchStore(),
    clientExperienceStore: _CatalogPickerExperience(), themeMode: ThemeMode.light,
    onThemeModeChanged: (_) {}, runtimeActionTimeout: const Duration(seconds: 2),
  )));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Правила'));
  await tester.pumpAndSettle();
  final action = find.text('Выбрать сервисы и режим');
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

ConnectionManager _manager(
  _Runtime runtime,
  ManagedProfileBootstrapper bootstrapper, {
  Future<PokrovWindowsTunnelAuthorization> Function()? authorizeWindows,
  _ExperienceStore? experienceStore,
  PokrovWifiProbe? currentWifiProbe,
  PokrovForegroundConnectPolicy? foregroundConnectPolicy,
  Future<bool> Function()? authorizeAndroid,
  PokrovClientObservability? observability,
}) =>
    ConnectionManager(
      appContext: buildSeedAppContext(hostPlatform: runtime.hostPlatform),
      runtimeEngine: runtime,
      bootstrapper: bootstrapper,
      observability: observability,
      accountSessionCoordinator:
          AccountSessionCoordinator(accountActions: null),
      firstSessionCoordinator:
          FirstSessionCoordinator(store: _FirstLaunchStore()),
      clientExperienceStore: experienceStore ?? _ExperienceStore(),
      connectHintStore: const PokrovFileConnectHintStore(),
      currentWifiProbe: currentWifiProbe,
      foregroundConnectPolicy: foregroundConnectPolicy,
      authorizeAndroidConnect: authorizeAndroid ?? (() async => true),
      windowsTunnelAuthorizer: authorizeWindows,
      refreshSubscription: () async => true,
      onNotice: (_, __) {},
    );

PokrovWifiNetworkStatus _foregroundWifi(_Runtime runtime, {String? name = 'Cafe',
    bool eligible = true, bool foreground = true, bool suppressed = false}) =>
  PokrovWifiNetworkStatus(connected: true, name: name, permissionRequired: name == null, reason: null,
    foreground: foreground, autoConnectEligible: eligible, manualStopSuppressed: suppressed,
    networkContextRef: runtime.candidateContext, networkSelectionKey: runtime.candidateKey, manualStopEpoch: 0);

void main() {
  final originalHttpOverrides = HttpOverrides.current;
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = originalHttpOverrides;

  testWidgets('Rules syncs immediate Wi-Fi policy without discarding pending routing edits', (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final nativeMutations = <String>[];
    final experienceStore = _CatalogPickerExperience();
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.stageManagedProfile' || call.method == 'runtimeEngine.connect') {
        nativeMutations.add(call.method);
      }
      return {'phase': 'initialized', 'coreVersion': '1.2.10',
        'supportsLiveConnect': true, 'canInitialize': false, 'canConnect': true};
    });
    await tester.pumpWidget(MaterialApp(home: PokrovSeedShell(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: _Bootstrapper(), firstLaunchStore: _FirstLaunchStore(),
      clientExperienceStore: experienceStore, themeMode: ThemeMode.light,
      onThemeModeChanged: (_) {},
      currentWifiProbe: () async => const PokrovWifiNetworkStatus(
        connected: false, name: null, permissionRequired: false, reason: 'not_connected'),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Правила'));
    await tester.pumpAndSettle();
    final advanced = find.byKey(const ValueKey('rules-advanced-toggle'));
    await tester.scrollUntilVisible(advanced, 400, scrollable: find.descendant(
      of: find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_RulesSection'),
      matching: find.byType(Scrollable),
    ).first);
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    final auto = find.byKey(const ValueKey('rules-untrusted-wifi-auto-connect'));
    dynamic rules() => tester.widget(find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_RulesSection'));
    bool autoValue() => (tester.widget(auto) as dynamic).value as bool;
    void externalAuto(bool value) => rules().onRoutingPreferencesChanged(
      (rules().routingPreferences as PokrovRoutingPreferences).copyWith(autoConnectOnUntrustedWifi: value));
    expect(autoValue(), isFalse);
    externalAuto(true);
    await tester.pumpAndSettle();
    expect(autoValue(), isTrue);
    externalAuto(false);
    await tester.pumpAndSettle();
    await tester.ensureVisible(auto);
    await tester.pumpAndSettle();
    await tester.tap(auto);
    await tester.pumpAndSettle();
    expect(autoValue(), isTrue);
    expect(experienceStore.saved.routingPreferences.autoConnectOnUntrustedWifi, isTrue);
    expect(find.byKey(const ValueKey('rules-change-summary')), findsNothing);
    expect(find.byKey(const ValueKey('rules-apply-changes')), findsNothing);
    final dynamic dns = tester.widget(find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_DnsAndLanCard'));
    dns.onChanged((dns.preferences as PokrovRoutingPreferences).copyWith(dnsPreset: PokrovDnsPreset.cloudflare));
    await tester.pumpAndSettle();
    externalAuto(false);
    await tester.pumpAndSettle();
    expect(autoValue(), isFalse);
    expect(experienceStore.saved.routingPreferences.autoConnectOnUntrustedWifi, isFalse);
    final dynamic pendingDns = tester.widget(find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_DnsAndLanCard'));
    expect((pendingDns.preferences as PokrovRoutingPreferences).dnsPreset, PokrovDnsPreset.cloudflare);
    final summary = find.byKey(const ValueKey('rules-change-summary'));
    expect(summary, findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('DNS и локальная сеть')), findsOneWidget);
    expect(nativeMutations, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Selective first open uses trial access with Smart Access off and no prepared profile', (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final result = (await tester.runAsync(_pickerCatalog))!;
    final known = _CatalogPickerBootstrapper(result);
    await _openPicker(tester, known);
    expect(find.text('Fixture service'), findsOneWidget,
      reason: tester.widgetList<Text>(find.textContaining('Не удалось обновить каталог'))
          .map((text) => text.data).join('; '));
    expect(known.subscriptionReads, 1, reason: 'known authenticated trial does not need another access read');
    expect(known.catalogReads, 1);
    expect(find.textContaining('Не удалось обновить каталог'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final cold = _CatalogPickerBootstrapper(result, coldAccess: true);
    await _openPicker(tester, cold);
    expect(cold.subscriptionReads, 2, reason: 'unknown startup access is read normally by the picker');
    expect(cold.catalogReads, 1);
    expect(find.text('Fixture service'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Selective picker labels a native Snapshot timeout separately from catalog delivery', (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final result = (await tester.runAsync(_pickerCatalog))!;
    final bootstrapper = _CatalogPickerBootstrapper(result);
    await _openPicker(tester, bootstrapper, holdNativeSnapshot: true);
    await tester.pump(const Duration(seconds: 3));
    expect(bootstrapper.catalogReads, 1);
    expect(find.textContaining('Модуль подключения: timeout.'), findsOneWidget,
      reason: tester.widgetList<Text>(find.textContaining('Не удалось обновить каталог'))
          .map((text) => text.data).join('; '));
    expect(find.textContaining('Каталог: timeout.'), findsNothing);
    expect(find.text('Каталог недоступен'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('Android foreground network context changes reuse protected handoff without rejecting current', () async {
    final runtime = _Runtime()..supportsCandidates = true..captivePortal = false;
    final manager = _manager(runtime, _Bootstrapper(catalog: true),
        currentWifiProbe: () async => _foregroundWifi(runtime));
    addTearDown(manager.dispose);
    await manager.connect();
    runtime.candidateContext = 'context-b'; // Same selection/cache key, new native epoch.
    await manager.refresh();
    expect(runtime.handoffCalls, 1);
    expect(runtime.handoffProfiles.single, _candidates.first.candidateRef);
    expect(runtime.connectCalls, 1);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(runtime.probeContexts.last, 'context-b');
    await manager.refresh();
    expect(runtime.handoffCalls, 1, reason: 'one replacement per native context');
    manager.setRoutingPreferences(const PokrovRoutingPreferences.defaults().copyWith(
        pauseOnTrustedWifi: true, trustedWifiNames: ['cafe']));
    runtime.candidateContext = 'context-trusted';
    await manager.refresh();
    expect(runtime.handoffCalls, 1, reason: 'trusted Wi-Fi pauses before any network handoff');
    expect(runtime.calls, contains('disconnect'));
    expect(runtime.phase, RuntimePhase.configStaged);
  });

  test('Android foreground network stop supersedes an in-flight context observation', () async {
    final runtime = _Runtime()..supportsCandidates = true..captivePortal = false;
    final manager = _manager(runtime, _Bootstrapper(catalog: true),
        currentWifiProbe: () async => _foregroundWifi(runtime));
    addTearDown(manager.dispose);
    await manager.connect();
    final gate = Completer<RuntimeCandidateNetwork>();
    runtime.nextNetworkRead = gate;
    final observation = manager.refresh();
    await runtime.networkReadEntered.future;
    await manager.disconnect();
    gate.complete(const RuntimeCandidateNetwork(selectionKey: 'network-a', contextRef: 'context-b',
        networkAvailable: true, captivePortal: false));
    await observation;
    expect(runtime.handoffCalls, 0);
    expect(runtime.phase, RuntimePhase.configStaged);
  });

  test('Android foreground network untrusted Wi-Fi starts once through authorized owner flow', () async {
    final runtime = _Runtime()..captivePortal = false;
    final policies = <bool>[];
    var permissionExplanations = 0;
    final manager = _manager(runtime, _Bootstrapper(),
        currentWifiProbe: () async => _foregroundWifi(runtime),
        authorizeAndroid: () async { permissionExplanations++; return false; },
        foregroundConnectPolicy: (_, __, active) async { policies.add(active); return true; });
    addTearDown(manager.dispose);
    manager.markExperienceLoaded();
    manager.setRoutingPreferences(const PokrovRoutingPreferences.defaults().copyWith(autoConnectOnUntrustedWifi: true));
    await manager.refresh();
    expect(runtime.connectCalls, 1);
    expect(policies, [true, false]);
    expect(permissionExplanations, 0);
    await manager.disconnect();
    runtime.candidateContext = 'context-b';
    await manager.refresh();
    expect(runtime.connectCalls, 1, reason: 'stop suppresses even a new context on the same physical key');
    runtime.candidateKey = 'network-b';
    runtime.candidateContext = 'context-c';
    await manager.refresh();
    expect(runtime.connectCalls, 2);
  });

  test('Android foreground network policy skips disabled trusted unknown captive and unauthorized Wi-Fi', () async {
    final runtime = _Runtime()..captivePortal = false;
    var wifi = _foregroundWifi(runtime);
    var admissions = 0;
    final manager = _manager(runtime, _Bootstrapper(), currentWifiProbe: () async => wifi,
        foregroundConnectPolicy: (_, __, ___) async { admissions++; return true; });
    addTearDown(manager.dispose);
    manager.markExperienceLoaded();
    await manager.refresh(); // Default false.
    manager.setRoutingPreferences(const PokrovRoutingPreferences.defaults().copyWith(
        autoConnectOnUntrustedWifi: true, trustedWifiNames: ['cafe']));
    await manager.refresh();
    manager.setRoutingPreferences(const PokrovRoutingPreferences.defaults().copyWith(autoConnectOnUntrustedWifi: true));
    wifi = _foregroundWifi(runtime, name: null);
    await manager.refresh();
    wifi = _foregroundWifi(runtime, eligible: false);
    await manager.refresh();
    wifi = _foregroundWifi(runtime, foreground: false);
    await manager.refresh();
    wifi = _foregroundWifi(runtime);
    runtime.captivePortal = true;
    await manager.refresh();
    expect(runtime.connectCalls, 0);
    expect(admissions, 0);
  });

  test('Android foreground network stale policy admission cannot start after explicit stop', () async {
    final runtime = _Runtime()..captivePortal = false;
    final admitted = Completer<void>();
    final release = Completer<bool>();
    final policies = <bool>[];
    final manager = _manager(runtime, _Bootstrapper(), currentWifiProbe: () async => _foregroundWifi(runtime),
        foregroundConnectPolicy: (_, __, active) async {
          policies.add(active);
          if (!active) return true;
          admitted.complete();
          return release.future;
        });
    addTearDown(manager.dispose);
    manager.markExperienceLoaded();
    manager.setRoutingPreferences(const PokrovRoutingPreferences.defaults().copyWith(autoConnectOnUntrustedWifi: true));
    final observation = manager.refresh();
    await admitted.future;
    final stopped = manager.disconnect();
    release.complete(true);
    await Future.wait([observation, stopped]);
    expect(runtime.connectCalls, 0);
    expect(policies, [true, false], reason: 'superseded accepted policy is always cleared');
  });

  test('Android foreground network auth denial never admits a native connect', () async {
    final runtime = _Runtime()..captivePortal = false;
    final bootstrapper = _Bootstrapper()..failure = const BootstrapFailure('access denied', statusCode: 403);
    final policies = <bool>[];
    final manager = _manager(runtime, bootstrapper, currentWifiProbe: () async => _foregroundWifi(runtime),
        foregroundConnectPolicy: (_, __, active) async { policies.add(active); return true; });
    addTearDown(manager.dispose);
    manager.markExperienceLoaded();
    manager.setRoutingPreferences(const PokrovRoutingPreferences.defaults().copyWith(autoConnectOnUntrustedWifi: true));
    await manager.refresh();
    expect(runtime.connectCalls, 0);
    expect(policies, [true, false]);
  });

  test('Simple ignores saved manual pins for country Auto and Advanced probes only its exact candidate', () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final bootstrapper = _Bootstrapper(catalog: true, warpEnabled: true);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    manager.restoreConnectionPreferences(
      const PokrovClientExperienceState.empty().copyWith(
        preferredCountryCode: 'DE', preferredNodeCode: 'ch',
        preferredVariantId: 'ru-spb', preferredCandidateRef: 'ch:legacy'),
      const {},
    );
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(runtime.stagedProfile, _candidates.first.candidateRef);
    expect(runtime.stagedPayloads.last.resolvedNodeCode, 'de');
    expect(bootstrapper.requestedCountries, everyElement('DE'));
    expect(manager.transportCatalog?.selected.countryCode, 'DE');
    await manager.disconnect();
    await manager.setInterfaceMode(PokrovInterfaceMode.advanced);
    await manager.setPreferredCandidate(_candidates[2].candidateRef);
    final before = bootstrapper.resolutions.length;
    await manager.connect();
    expect(runtime.stagedProfile, _candidates[2].candidateRef);
    expect(bootstrapper.resolutions.skip(before).map((request) => request.selected),
        everyElement(_candidates[2].candidateRef));
    expect(bootstrapper.requestedCountries.last, '');
    runtime.failedProbeProfiles.add(_candidates[2].candidateRef);
    final retryBefore = bootstrapper.resolutions.length;
    await manager.reconnect();
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(bootstrapper.resolutions.skip(retryBefore).map((request) => request.selected),
        everyElement(_candidates[2].candidateRef));
    await manager.disconnect();
    await manager.setAutomaticLocation();
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(runtime.stagedProfile, _candidates.first.candidateRef);
    expect(bootstrapper.requestedCountries.last, '');
    const base = ManagedProfileCacheInputs(hostPlatform: HostPlatform.android, routeMode: RouteMode.fullTunnel);
    const country = ManagedProfileCacheInputs(hostPlatform: HostPlatform.android, routeMode: RouteMode.fullTunnel,
        preferredCountryCode: 'DE');
    const pinned = ManagedProfileCacheInputs(hostPlatform: HostPlatform.android, routeMode: RouteMode.fullTunnel,
        preferredCandidateRef: 'de:profile_2');
    expect({base.binding('a', 'i'), country.binding('a', 'i'), pinned.binding('a', 'i')}, hasLength(3));
  });

  test('Auto uses the winning material node when the bundle keeps the initial resolved hint', () async {
    final initial = TransportCandidate(candidateRef: 'pl:profile_0', profileRef: 'profile_0',
      nodeCode: 'pl', countryCode: 'PL', protocol: 'vless', transport: 'tcp',
      protection: 'reality', priority: 0, network: 'tcp', flow: '',
      minimumClientRelease: '1.2.0', minimumCoreRelease: null,
      platforms: {HostPlatform.windows}, requiredFeatures: const {});
    final winner = TransportCandidate(candidateRef: 'de2:profile_1', profileRef: 'profile_1',
      nodeCode: 'de2', countryCode: 'DE', protocol: 'vless', transport: 'tcp',
      protection: 'reality', priority: 1, network: 'tcp', flow: '',
      minimumClientRelease: '1.2.0', minimumCoreRelease: null,
      platforms: {HostPlatform.windows}, requiredFeatures: const {});
    final bootstrapper = _StatsBootstrapper(bundle: true)..candidates = [initial, winner];
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true
      ..heldProbeProfiles.add(initial.candidateRef);
    final manager = _manager(runtime, bootstrapper,
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);

    await manager.connect();

    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.transportCatalog?.selected.nodeCode, 'pl',
        reason: 'the server selection remains the initial catalog choice');
    expect(manager.materialCandidate?.nodeCode, 'de2');
    expect(manager.materialCandidate?.countryCode, 'DE');
    expect(runtime.stagedPayloads.single.resolvedNodeCode, 'de2',
        reason: 'staging and the promoted active location must name the winning material');
    expect(bootstrapper.actualReports.singleWhere((report) => report['runtime_phase'] == 'running')
        ['selected_node_code'], 'de2');
  });

  test('unexpected connection diagnostics retain only operation type and application frames', () async {
    final store = _ExperienceStore();
    final bootstrapper = _Bootstrapper()
      ..failure = StateError('synthetic-private-token https://private.example/profile')
      ..failureStack = StackTrace.fromString('''
#0 private (https://private.example/profile?token=synthetic-private-token:1:2)
#1 private (C:/private/customer-profile.dart:3:4)
#2 first (package:pokrov_app_shell/app_first_runtime_bootstrap.dart:123:9)
#3 second (package:pokrov_runtime_engine/runtime_engine.dart:456:2)
#4 third (package:pokrov_app_shell/src/connection/connection_manager.dart:789:2)
''');
    final runtime = _Runtime();
    final manager = _manager(runtime, bootstrapper, experienceStore: store);
    addTearDown(manager.dispose);
    await manager.connect();
    final event = store.saved.protectionEvents.single;
    expect(event.kind, 'connect_unexpected_managed_profile_refresh');
    expect(event.detail, 'managed_profile_refresh: StateError; app_first_runtime_bootstrap.dart:123, runtime_engine.dart:456');
    expect(event.detail.length, lessThanOrEqualTo(180));
    expect(jsonEncode(event.toJson()), isNot(contains('synthetic-private-token')));
    expect(jsonEncode(event.toJson()), isNot(contains('private.example')));
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(runtime.connectCalls, 0);
  });

  test('offline invitation cold restart uses ordinary guards without HTTP before verified Connect', () async {
    final originalStorage = FlutterSecureStoragePlatform.instance;
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(<String, String>{});
    final directory = await Directory.systemTemp.createTemp('pokrov-invitation-connect-');
    addTearDown(() async {
      await directory.delete(recursive: true);
      FlutterSecureStoragePlatform.instance = originalStorage;
    });
    final vector = jsonDecode(await File('test/fixtures/offline-invitation.v1.vector.json').readAsString()) as Map<String, dynamic>;
    final body = vector['request']['payload'] as Map;
    List<int> hex(String value) => [for (var i = 0; i < value.length; i += 2)
      int.parse(value.substring(i, i + 2), radix: 16)];
    final seeds = vector['seeds'] as Map;
    final issuer = await Ed25519().newKeyPairFromSeed(hex(seeds['issuer_private_hex'] as String));
    final trust = OfflineInvitationTrust(audience: 'production', issuerPublicKeys: {
      vector['envelope']['key_id'] as String: base64Url.encode((await issuer.extractPublicKey()).bytes).replaceAll('=', ''),
    });
    var now = DateTime.fromMillisecondsSinceEpoch((vector['envelope']['issued_at'] as int) * 1000 + 1000, isUtc: true);
    OfflineInvitationReceiver receiver() => OfflineInvitationReceiver(trust: trust, clock: () => now);
    final preparedReceiver = receiver();
    await preparedReceiver.createRequest(installId: body['install_id'] as String, platform: 'android', consent: true,
      clientRelease: body['client_release'] as String, coreRelease: body['core_release'] as String,
      runtimeFeatures: (body['runtime_features'] as List).cast<String>(), routeMode: 'full_tunnel',
      operationIsCurrent: () => true,
      proofKeyPair: await Ed25519().newKeyPairFromSeed(hex(seeds['proof_private_hex'] as String)),
      deliveryKeyPair: await X25519().newKeyPairFromSeed(hex(seeds['delivery_private_hex'] as String)),
      nonce: base64Url.decode(base64Url.normalize(body['request_nonce'] as String)));
    final stateFile = File('${directory.path}/app-first-session-android.json');
    await stateFile.writeAsString(jsonEncode({'schema_version': 1, 'install_id': body['install_id'],
      'account_id': '', 'profile_revision': '', 'managed_manifest_path': '/api/client/profile/managed'}));
    final secrets = MemoryAppFirstSessionSecretStore();
    final runtime = _Runtime()..supportsCandidates = true..coreVersion = '1.2.9';
    var prematureClientConstructions = 0;
    AppFirstRuntimeBootstrapper bootstrapper(OfflineInvitationReceiver recipient) => AppFirstRuntimeBootstrapper(
      supportDirectoryResolver: () async => directory, sessionSecretStore: secrets,
      invitationReceiver: recipient, httpClientFactory: () {
        if (!runtime.value(runtime.phase).isCleanlyHealthy) prematureClientConstructions++;
        throw StateError('synthetic API unavailable');
      });
    final importer = bootstrapper(preparedReceiver);
    final features = RuntimeTransportFeature.values.toSet();
    final packet = canonicalInvitationJson(vector['envelope']);
    await importer.importOfflineInvitation(hostPlatform: HostPlatform.android, routeMode: RouteMode.fullTunnel,
      packet: packet, runtimeFeatures: features, coreRelease: '1.2.9', operationIsCurrent: () => true);
    final pendingMetadata = await stateFile.readAsString();
    final cold = bootstrapper(receiver());
    const inputs = ManagedProfileCacheInputs(hostPlatform: HostPlatform.android, routeMode: RouteMode.fullTunnel);
    // First cold caller is the existing reporter, not a manual slot preload.
    await cold.reportRuntimeStats(hostPlatform: HostPlatform.android, runtimePhase: 'failed', connected: false);
    expect(prematureClientConstructions, 0);
    expect(cold.invitationNetworkDeferred, isTrue);
    expect(await cold.openOfflineInvitationProfile(inputs, runtimeFeatures: features, coreRelease: '1.2.9',
        operationIsCurrent: () => true), isNotNull);
    final manager = _manager(runtime, cold);
    addTearDown(manager.dispose);
    manager.selectRouteMode(RouteMode.fullTunnel);
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(prematureClientConstructions, 0);
    expect(runtime.probedProtocols, ['vless']);
    expect(runtime.stagedPayloads.single.source?.origin, RuntimeProfileSourceOrigin.managedManifest);
    expect(runtime.stagedPayloads.single.routeMode, RouteMode.fullTunnel);
    expect(runtime.stagedPayloads.single.warpPolicy.canEnableRuntime, isFalse);
    expect(runtime.connectCalls, 1);
    final released = DateTime.now().add(const Duration(seconds: 2));
    while (cold.invitationNetworkDeferred && DateTime.now().isBefore(released)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cold.invitationNetworkDeferred, isFalse);
    await manager.disconnect();
    // The normal credential-store API represents a later session replacement;
    // the old encrypted packet must not intercept that ordinary identity.
    await secrets.writeSessionPair(hostPlatform: HostPlatform.android, installId: body['install_id'] as String,
        pair: const AppFirstSessionCredentials(accessToken: 'normal-replacement-session', refreshToken: 'normal-replacement-refresh'));
    final replacement = bootstrapper(receiver());
    expect(await replacement.openOfflineInvitationProfile(inputs, runtimeFeatures: features, coreRelease: '1.2.9',
        operationIsCurrent: () => true), isNull);
    expect(replacement.invitationNetworkDeferred, isFalse);
    // Simulate a pending process exiting before native verification. Only the
    // synthetic public session metadata is replayed; authority stays separate.
    await stateFile.writeAsString(pendingMetadata);
    now = DateTime.fromMillisecondsSinceEpoch((vector['envelope']['expires_at'] as int) * 1000, isUtc: true);
    final expired = bootstrapper(receiver());
    expect(await expired.openOfflineInvitationProfile(inputs, runtimeFeatures: features, coreRelease: '1.2.9',
        operationIsCurrent: () => true), isNull);
    expect(expired.invitationNetworkDeferred, isFalse);
    expect((jsonDecode(await stateFile.readAsString()) as Map).containsKey('offline_invitation_id'), isFalse);
    expect(await expired.loadCachedManagedProfile(inputs, runtimeFeatures: features, coreRelease: '1.2.9'), isNull,
        reason: 'the invitation never forged an HTTP managed-cache record or gained 24-hour grace');
  });

  test('WFP socket denial of both API origins connects the exact cached ordinary AWG', () async {
    final originalStorage = FlutterSecureStoragePlatform.instance;
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(<String, String>{});
    final directory = await Directory.systemTemp.createTemp('pokrov-offline-awg-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
      FlutterSecureStoragePlatform.instance = originalStorage;
    });
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(request.uri.path == '/api/client/session/start-trial'
            ? {'session': {'session_token': 'awg-test-session', 'account_id': 'awg-test-account'},
                'provisioning': {'status': 'ready', 'sync_ok': true}}
            : request.uri.path == '/api/client/profile/managed' ? {
              'profile_revision': 'cached-awg', 'config_format': 'singbox-json',
              'transport_profile': 'awg31_lab', 'transport_kind': 'awg31',
              'provisioning': {'status': 'ready', 'sync_ok': true},
              'access': {'access_state': 'active',
                'expiry_at': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String()},
              'transport_catalog': {
                'schema_version': 'pokrov-transport-catalog-v1', 'revision': 'cached-awg',
                'selected_candidate_ref': 'de:awg31_lab', 'candidates': [{
                  'candidate_ref': 'de:awg31_lab', 'profile_ref': 'awg31_lab', 'node_code': 'de',
                  'country_code': 'DE', 'protocol': 'awg', 'transport': 'udp', 'protection': 'awg31',
                  'priority': 0, 'parameters': {'network': 'udp', 'flow': ''},
                  'requirements': {'minimum_client_release': pokrovClientVersion, 'minimum_core_release': null,
                    'platforms': ['windows'], 'required_features': ['pokrov_awg31_endpoint_v1']},
                }],
              },
              'config_payload': {
                '_meta': {'transport_contract': {
                  'id': 'pokrov.awg31.endpoint.v1',
                  'sha256': '1bb49b61549ba7c4a3c2d56df445e919ebb1ed12d42e04b0cb3c915d23240818',
                  'profile': 'awg31_lab', 'state': 'enabled', 'generation': 'ordinary-v1',
                }},
                'endpoints': [{'type': 'awg', 'tag': 'awg-node',
                  'contract_id': 'pokrov.awg31.endpoint.v1', 'useIntegratedTun': false}],
                'outbounds': [{'type': 'direct', 'tag': 'direct'}],
                'route': {'final': 'awg-node'},
              },
            } : {'ok': true}));
        await request.response.close();
      }
    }());
    var blocked = false;
    final blockedOrigins = <String>{};
    AppFirstRuntimeBootstrapper bootstrapper() => AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      apiFallbackBaseUrls: ['http://localhost:${server.port}/'],
      supportDirectoryResolver: () async => directory,
      allExceptRuRuleSetUrlsResolver: (_) => const [], maxRequestAttempts: 1,
      httpClientFactory: () {
        final client = HttpClient();
        if (blocked) {
          client.connectionFactory = (uri, _, __) async {
            blockedOrigins.add(uri.authority);
            throw const SocketException('synthetic WFP denial', osError: OSError('network access denied', 10013));
          };
        }
        return client;
      },
    );
    const inputs = ManagedProfileCacheInputs(hostPlatform: HostPlatform.windows,
        routeMode: RouteMode.allExceptRu, preferredCandidateRef: 'de:awg31_lab');
    final seed = bootstrapper();
    await seed.resolveManagedProfile(hostPlatform: inputs.hostPlatform, routeMode: inputs.routeMode,
      preferredCandidateRef: inputs.preferredCandidateRef, selectCandidate: false,
      runtimeFeatures: RuntimeTransportFeature.values.toSet(), coreRelease: '1.2.9');
    final cached = await seed.loadCachedManagedProfile(inputs,
      runtimeFeatures: RuntimeTransportFeature.values.toSet(), coreRelease: '1.2.9');
    expect(cached?.materialCandidate?.candidateRef, 'de:awg31_lab');
    expect(cached?.source?.protocol, 'awg31');
    blocked = true;
    final offline = bootstrapper();
    await expectLater(offline.resolveManagedProfile(hostPlatform: inputs.hostPlatform,
      routeMode: inputs.routeMode, preferredCandidateRef: inputs.preferredCandidateRef,
      runtimeFeatures: RuntimeTransportFeature.values.toSet(), coreRelease: '1.2.9'),
      throwsA(isA<BootstrapFailure>().having((error) => error.operationalErrorCode, 'code', 'API-002')
          .having((error) => error.apiFailureKind, 'kind', 'origin_socket')
          .having((error) => error.osErrorCode, 'OS error', 10013)
          .having((error) => error.statusCode, 'HTTP status', isNull)));
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true..coreVersion = '1.2.9';
    final manager = _manager(runtime, offline,
      authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);
    manager.restoreConnectionPreferences(const PokrovClientExperienceState.empty().copyWith(
      interfaceMode: PokrovInterfaceMode.advanced, preferredCandidateRef: 'de:awg31_lab'), const {});
    manager.selectRouteMode(RouteMode.allExceptRu);
    await manager.connect();
    expect(blockedOrigins, containsAll(['127.0.0.1:${server.port}', 'localhost:${server.port}']));
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.offlineState, ManagedProfileOfflineState.apiUnavailable);
    expect(runtime.probedProtocols, ['awg31']);
    expect(runtime.stagedPayloads.single.materialCandidate?.candidateRef, 'de:awg31_lab');
    expect(runtime.stagedPayloads.single.warpPolicy.canEnableRuntime, isFalse);
    expect(runtime.connectCalls, 1);
  });

  test('API outage and failed node use an authorized cached other node through expiry grace', () async {
    final originalStorage = FlutterSecureStoragePlatform.instance;
    final protectedValues = <String, String>{};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(protectedValues);
    final directory = await Directory.systemTemp.createTemp('pokrov-offline-connect-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
      FlutterSecureStoragePlatform.instance = originalStorage;
    });
    var apiUnavailable = false;
    var failedRequests = 0;
    var clientsCreated = 0;
    var delayedAlternateCompleted = false;
    late final _Runtime onlineRuntime;
    final managedQueries = <Map<String, String>>[];
    DateTime? cacheNow;
    final expiry = DateTime.now().toUtc().add(const Duration(days: 2));
    final inputs = ManagedProfileCacheInputs(hostPlatform: HostPlatform.windows,
      routeMode: buildSeedAppContext(hostPlatform: HostPlatform.windows).runtimeProfile.defaultRouteMode);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (apiUnavailable) {
          failedRequests++;
          request.response.statusCode = HttpStatus.serviceUnavailable;
          request.response.write('{"detail":"temporarily unavailable"}');
        } else if (request.uri.path == '/api/client/session/start-trial') {
          request.response.write(jsonEncode({
            'session': {'session_token': 'offline-test-session', 'account_id': 'offline-test-account'},
            'provisioning': {'status': 'ready', 'sync_ok': true},
          }));
        } else if (request.uri.path == '/api/client/profile/managed') {
          managedQueries.add(request.uri.queryParameters);
          final hy2 = request.uri.queryParameters['selected_candidate_ref'] == 'ch:hy2_lab';
          if (hy2 && !delayedAlternateCompleted) {
            // Production managed issuance can take longer than the former
            // three-second background deadline, even while the API is healthy.
            await Future<void>.delayed(const Duration(milliseconds: 3200));
            delayedAlternateCompleted = true;
          }
          request.response.write(jsonEncode({
            'profile_revision': 'offline-test-profile', 'config_format': 'singbox-json',
            'transport_profile': hy2 ? 'hy2_lab' : 'legacy_reality_fallback',
            'transport_kind': hy2 ? 'hysteria2' : 'reality',
            if (request.uri.queryParameters['catalog_version'] == '1') 'transport_catalog': {
              'schema_version': 'pokrov-transport-catalog-v1', 'revision': 'offline-test-profile',
              'selected_candidate_ref': hy2 ? 'ch:hy2_lab' : 'de:legacy_reality_fallback',
              'candidates': [{
                'candidate_ref': 'de:legacy_reality_fallback', 'profile_ref': 'legacy_reality_fallback',
                'node_code': 'de', 'country_code': 'DE', 'protocol': 'vless',
                'transport': 'tcp', 'protection': 'reality', 'priority': 0,
                'parameters': {'network': 'tcp', 'flow': ''},
                'requirements': {'minimum_client_release': '1.2.0', 'minimum_core_release': null,
                  'platforms': ['android', 'windows'],
                  'required_features': ['singbox_reality_v1', 'singbox_tls_v1', 'singbox_utls_v1', 'singbox_vless_v1']},
              }, if (onlineRuntime.connectCalls > 0) {
                'candidate_ref': 'ch:hy2_lab', 'profile_ref': 'hy2_lab',
                'node_code': 'ch', 'country_code': 'CH', 'protocol': 'hysteria2',
                'transport': 'udp', 'protection': 'tls', 'priority': 1,
                'parameters': {'network': 'udp', 'flow': ''},
                'requirements': {'minimum_client_release': '1.2.0', 'minimum_core_release': null,
                  'platforms': ['android', 'windows'], 'required_features': ['singbox_hysteria2_v1']},
              }],
            },
            'provisioning': {'status': 'ready', 'sync_ok': true},
            'access': {'access_state': 'paid_unlimited', 'expiry_at': expiry.toIso8601String()},
            'config_payload': hy2 ? {
              '_meta': {'transport_contract': {
                'id': 'pokrov.hy2.outbound.v1',
                'sha256': 'c96b38e58ea33f838f23b80a65f3a9a264e932b7248f206798df9a0b8fa0fb98',
                'profile': 'hy2_lab', 'state': 'enabled', 'generation': 'ordinary-v1',
              }},
              'outbounds': [
                {'type': 'hysteria2', 'tag': 'test-node', 'server': 'hy2.example.invalid',
                  'server_port': 443, 'password': 'synthetic-password', 'up_mbps': 10, 'down_mbps': 50,
                  'tls': {'enabled': true, 'server_name': 'hy2.example.invalid', 'insecure': false, 'alpn': ['h3']}},
                {'type': 'direct', 'tag': 'direct'},
              ],
              'route': {'final': 'test-node'},
            } : {
              'outbounds': [
                {'type': 'selector', 'tag': 'proxy', 'outbounds': ['test-node'], 'default': 'test-node'},
                {'type': 'vless', 'tag': 'test-node', 'server': 'vpn.example.test', 'server_port': 443,
                  'uuid': '11111111-1111-4111-8111-111111111111'},
              ],
              'route': {'final': 'proxy'},
            },
          }));
        } else {
          request.response.write('{"ok":true}');
        }
        await request.response.close();
      }
    }());
    AppFirstRuntimeBootstrapper bootstrapper() => AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}',
      supportDirectoryResolver: () async => directory,
      managedProfileCache: ManagedProfileCache(now: () => cacheNow ?? DateTime.now().toUtc()),
      httpClientFactory: () { clientsCreated++; return HttpClient(); },
      allExceptRuRuleSetUrlsResolver: (_) => const [], maxRequestAttempts: 1,
    );
    onlineRuntime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true..phase = RuntimePhase.configStaged;
    final onlineBootstrapper = bootstrapper();
    final previousProfile = await onlineBootstrapper.resolveManagedProfile(hostPlatform: inputs.hostPlatform,
        routeMode: inputs.routeMode, runtimeFeatures: RuntimeTransportFeature.values.toSet(), selectCandidate: false);
    await onlineBootstrapper.markManagedProfileProven(inputs, previousProfile.cacheEntryId, networkSelectionKey: 'network-a');
    final onlineManager = _manager(onlineRuntime, onlineBootstrapper,
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(onlineManager.dispose);
    expect(onlineRuntime.value(RuntimePhase.artifactReady).transportCapabilities, isNull);
    await onlineManager.connect();
    expect(onlineManager.status.phase, ConnectionPhase.connected);
    expect(delayedAlternateCompleted, isFalse, reason: 'first connect does not wait for alternative profiles');
    expect(onlineRuntime.calls, isNot(contains('initialize')));
    expect(managedQueries.first['catalog_version'], '1');
    expect(managedQueries.first['client_platform'], inputs.hostPlatform.name);
    expect(managedQueries.first['runtime_features']!.split(','),
        RuntimeTransportFeature.values.map((feature) => feature.wireName).toList()..sort());
    expect(managedQueries.first.containsKey('core_release'), isFalse);
    expect(onlineManager.transportCatalog?.selectedCandidateRef, 'de:legacy_reality_fallback');
    expect(onlineRuntime.probeStarted.isCompleted, isTrue);
    expect(onlineRuntime.probedProtocols, ['vless'], reason: 'last success is tried first; cache preparation does not probe alternatives');
    var proven = await onlineBootstrapper.loadCachedManagedProfile(inputs, preferProven: true,
        runtimeFeatures: onlineRuntime.value(onlineRuntime.phase).transportCapabilities!.features);
    expect(proven?.provenNetworkSelectionKey, 'network-a');
    final provenEntryId = proven?.cacheEntryId;
    final readyDeadline = DateTime.now().add(const Duration(seconds: 6));
    ManagedProfilePayload? alternate;
    do {
      alternate = await onlineBootstrapper.loadCachedManagedProfile(inputs,
          selectedCandidateRef: 'ch:hy2_lab', runtimeFeatures: RuntimeTransportFeature.values.toSet());
      if (alternate == null) await Future<void>.delayed(const Duration(milliseconds: 10));
    } while (alternate == null && DateTime.now().isBefore(readyDeadline));
    expect(alternate, isNotNull);
    proven = await onlineBootstrapper.loadCachedManagedProfile(inputs, preferProven: true,
        runtimeFeatures: RuntimeTransportFeature.values.toSet());
    expect(proven?.cacheEntryId, provenEntryId, reason: 'catalog refresh does not prove new profile bytes');
    expect(proven?.transportCatalog?.candidates.length, 2,
        reason: 'the proven cold-device profile sees the newly acknowledged alternative');
    expect((await onlineBootstrapper.loadCachedManagedProfile(inputs))?.transportCatalog?.selectedCandidateRef,
        'de:legacy_reality_fallback', reason: 'alternate materialization cannot replace the selected record');
    apiUnavailable = true;
    onlineRuntime.failedProbeProtocols.add('vless');
    final probesBefore = onlineRuntime.probedProtocols.length;
    await onlineManager.reconnect();
    expect(onlineManager.status.phase, ConnectionPhase.connected);
    expect(onlineRuntime.probedProtocols.skip(probesBefore), ['vless', 'hysteria2']);
    expect(onlineManager.transportCatalog?.selectedCandidateRef, 'ch:hy2_lab');
    expect(onlineRuntime.calls, isNot(contains('disconnect')));
    proven = await onlineBootstrapper.loadCachedManagedProfile(inputs, preferProven: true,
        runtimeFeatures: RuntimeTransportFeature.values.toSet());
    expect(proven?.cacheEntryId, alternate?.cacheEntryId, reason: 'offline proof promotes the existing entry');
    final downloadedProfile = onlineRuntime.stagedProfile;
    onlineRuntime.failHandoff = true;
    onlineRuntime.restoredHandoffGuard = true;
    await onlineManager.reconnect();
    expect(onlineManager.status.phase, ConnectionPhase.actionRequired);
    expect(onlineManager.retainsProtection, isTrue);
    expect(onlineRuntime.phase, RuntimePhase.configStaged);
    expect(onlineRuntime.handoffCalls, 2);
    expect(protectedValues, isNotEmpty);
    apiUnavailable = true;
    cacheNow = expiry.add(const Duration(hours: 23));
    onlineRuntime.failHandoff = false;
    await onlineManager.reconnect();
    expect(onlineManager.status.phase, ConnectionPhase.connected);
    expect(onlineManager.retainsProtection, isFalse);
    expect(onlineManager.offlineState, ManagedProfileOfflineState.apiUnavailable);
    expect(onlineRuntime.handoffCalls, 3);
    expect(onlineRuntime.calls, isNot(contains('disconnect')));
    expect(onlineRuntime.connectCalls, 1);
    final recovered = await onlineBootstrapper.loadCachedManagedProfile(inputs, preferProven: true,
        runtimeFeatures: onlineRuntime.value(onlineRuntime.phase).transportCapabilities!.features);
    expect(recovered?.cacheEntryId, proven?.cacheEntryId);
    await onlineManager.disconnect();
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..networkAvailable = null..supportsCandidates = true;
    // A fresh bootstrap instance must restore the protected record after restart.
    final manager = _manager(runtime, bootstrapper(),
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);
    await manager.connect();
    expect(failedRequests, greaterThan(0));
    expect(clientsCreated, greaterThan(1));
    expect(runtime.stagedProfile, downloadedProfile);
    expect(runtime.connectCalls, 1);
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.offlineState, ManagedProfileOfflineState.apiUnavailable,
      reason: 'unknown native network status is not evidence of no network');

    await manager.disconnect();
    cacheNow = expiry.add(const Duration(hours: 24, seconds: 1));
    runtime.networkAvailable = true;
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(manager.offlineState, ManagedProfileOfflineState.accessEnded);
    expect(runtime.connectCalls, 1, reason: 'an expired cache cannot reuse the already staged host profile');
    runtime.networkAvailable = false;
    await manager.connect();
    expect(manager.offlineState, ManagedProfileOfflineState.noNetwork);
    runtime.networkAvailable = true;
    runtime.captivePortal = true;
    await manager.connect();
    expect(manager.offlineState, ManagedProfileOfflineState.captivePortal);
    expect(runtime.calls.where((call) => call == 'stage'), hasLength(1));
  });

  test('one bundled response settles every probe and stages its exact winner without refetch', () async {
    final runtime = _Runtime()..supportsCandidates = true..holdProbes = true..failProbeCancellation = true;
    final bootstrapper = _Bootstrapper(catalog: true, bundle: true);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    final connection = manager.connect();
    await runtime.probeStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(manager.status.phase, ConnectionPhase.probing);
    expect(runtime.activeProbes, hasLength(3));
    runtime.probeRelease.complete();
    await connection;
    expect(runtime.activeProbes, isEmpty);
    expect(runtime.stagedProfile, 'de:profile_1');
    expect(bootstrapper.resolutions, hasLength(1));
    expect(bootstrapper.resolutions.every((call) => !call.select && !call.cache), isTrue);
    expect(manager.materialCandidate?.candidateRef, 'de:profile_1');
    expect(manager.transportCatalog?.selectedCandidateRef, 'de:profile_0',
        reason: 'the winning material does not rewrite authenticated catalog selection');
    expect(manager.status.phase, ConnectionPhase.connected);
  });

  test('country Auto resolves an admitted AWG missing from a partial bundle', () async {
    final vless = _candidates.first;
    final awg = _CachedBootstrapper.alternatives[1];
    final bootstrapper = _Bootstrapper(catalog: true, bundle: true)
      ..candidates = [vless, awg]
      ..bundledCandidateRefs = {vless.candidateRef};
    final runtime = _Runtime()
      ..supportsCandidates = true
      ..failedProbeProfiles.add(vless.candidateRef);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    manager.restoreConnectionPreferences(
      const PokrovClientExperienceState.empty().copyWith(preferredCountryCode: 'DE'),
      const {},
    );

    await manager.connect();

    expect(runtime.probedProtocols, ['vless', 'awg'],
        reason: 'the material bundle must not exclude another admitted candidate');
    expect(bootstrapper.resolutions, [
      (selected: '', select: false, cache: false),
      (selected: awg.candidateRef, select: false, cache: false),
    ]);
    expect(bootstrapper.requestedCountries, everyElement('DE'));
    expect(runtime.stagedProfile, awg.candidateRef);
    expect(manager.materialCandidate?.candidateRef, awg.candidateRef);
    expect(manager.transportCatalog?.candidates, [vless, awg]);
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(runtime.activeProbes, isEmpty);
  });

  test('US country Auto exhausts direct before the exact admitted bridge material', () async {
    final originalStorage = FlutterSecureStoragePlatform.instance;
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    final directory = await Directory.systemTemp.createTemp('pokrov-us-bridge-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
      FlutterSecureStoragePlatform.instance = originalStorage;
    });
    const profile = 'legacy_reality_fallback';
    const directRef = 'us:$profile';
    const bridgeRef = 'us:$profile:bridge_mini';
    const baseTag = 'US fixture';
    const bridgeLabel = 'Mini fixture';
    const bridgeTag = '$baseTag · $bridgeLabel';
    const detourTag = 'mini-fixture-ingress';
    final queries = <Map<String, String>>[];
    Map<String, Object?> leaf(String tag, {String? detour}) => {
      'type': 'vless', 'tag': tag, 'server': 'us.example.invalid', 'server_port': 443,
      'uuid': '11111111-1111-4111-8111-111111111111',
      if (detour != null) 'detour': detour,
      'tls': {'enabled': true, 'server_name': 'fixture.invalid',
        'utls': {'enabled': true, 'fingerprint': 'chrome'},
        'reality': {'enabled': true, 'public_key': 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'}},
    };
    Map<String, Object?> graph(String selectedTag) => {
      'outbounds': [
        {'type': 'selector', 'tag': 'proxy', 'outbounds': [selectedTag], 'default': selectedTag},
        leaf(baseTag), leaf(bridgeTag, detour: detourTag),
        {...leaf(detourTag), 'server': 'mini.example.invalid',
          'uuid': '22222222-2222-4222-8222-222222222222'},
      ],
      'route': {'final': 'proxy'},
      '_meta': {'ru_bridge': {'enabled': true, 'endpoints': [{'id': 'mini', 'label': bridgeLabel}]}},
    };
    Map<String, Object?> candidate(String ref, int priority, {String? bridge}) => {
      'candidate_ref': ref, 'profile_ref': profile, 'node_code': 'us', 'country_code': 'US',
      'protocol': 'vless', 'transport': 'tcp', 'protection': 'reality', 'priority': priority,
      'parameters': {'network': 'tcp', 'flow': '', if (bridge != null) 'bridge_id': bridge},
      'requirements': {'minimum_client_release': bridge == null ? '1.2.0' : '1.5.0+4116',
        'minimum_core_release': null, 'platforms': ['windows'],
        'required_features': ['singbox_vless_v1', 'singbox_tls_v1', 'singbox_utls_v1', 'singbox_reality_v1']},
    };
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response.write(jsonEncode({
            'session': {'session_token': 'synthetic-session', 'account_id': 'synthetic-account'},
            'provisioning': {'status': 'ready', 'sync_ok': true},
          }));
        } else if (request.uri.path == '/api/client/profile/managed') {
          queries.add(request.uri.queryParameters);
          request.response.write(jsonEncode({
            'profile_revision': 'us-bridge-fixture', 'config_format': 'singbox-json',
            'transport_profile': profile, 'transport_kind': 'reality', 'config_payload': graph(baseTag),
            'transport_catalog': {'schema_version': 'pokrov-transport-catalog-v1',
              'revision': 'us-bridge-fixture', 'selected_candidate_ref': directRef,
              'candidates': [candidate(directRef, 0), candidate(bridgeRef, 1, bridge: 'mini')]},
            'candidate_materials': [for (final ref in [directRef, bridgeRef]) {
              'candidate_ref': ref, 'transport_kind': 'reality',
              'config_format': 'singbox-json', 'config_payload': graph(ref == directRef ? baseTag : bridgeTag),
            }],
            'smart_connect': {'eligible': true, 'shortlist': [{'code': 'us', 'country': 'US', 'outbound_tag': baseTag}]},
            'provisioning': {'status': 'ready', 'sync_ok': true},
            'access': {'access_state': 'paid_unlimited',
              'expiry_at': DateTime.now().toUtc().add(const Duration(days: 2)).toIso8601String()},
          }));
        } else {
          request.response.write('{"ok":true}');
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(apiBaseUrl: 'http://127.0.0.1:${server.port}',
      supportDirectoryResolver: () async => directory, maxRequestAttempts: 1,
      allExceptRuRuleSetUrlsResolver: (_) => const []);
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true..coreVersion = '1.2.10'
      ..heldProbeCandidates.add(directRef)..failedProbeCandidates.add(directRef);
    final experience = _ExperienceStore();
    final manager = _manager(runtime, bootstrapper, experienceStore: experience,
      authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);
    manager.restoreConnectionPreferences(const PokrovClientExperienceState.empty().copyWith(
      interfaceMode: PokrovInterfaceMode.advanced, preferredCountryCode: 'US',
      firstRouteScopeConfirmed: true, firstRouteScopeMode: RouteMode.fullTunnel), const {});
    final connecting = manager.connect();
    await Future.any([runtime.probeStarted.future, connecting]);
    expect(runtime.probedPayloads.map((payload) => payload.materialCandidate?.candidateRef), [directRef],
      reason: 'typed bridge material must be admitted, but cannot race a still-held direct route');
    runtime.probeRelease.complete();
    await connecting;
    expect(runtime.probedPayloads.map((payload) => payload.materialCandidate?.candidateRef), [directRef, bridgeRef]);
    expect(manager.status.phase, ConnectionPhase.connected);
    final staged = runtime.stagedPayloads.single;
    expect(staged.materialCandidate?.candidateRef, bridgeRef);
    expect(staged.materialCandidate?.countryCode, 'US');
    expect(staged.resolvedNodeCode, 'us');
    final material = jsonDecode(staged.configPayload) as Map;
    final selected = (material['outbounds'] as List).cast<Map>().singleWhere((row) => row['tag'] == 'proxy');
    expect(selected['default'], bridgeTag);
    expect(selected['outbounds'], [bridgeTag]);
    final chosen = (material['outbounds'] as List).cast<Map>().singleWhere((row) => row['tag'] == bridgeTag);
    expect(chosen['detour'], detourTag);
    expect((experience.saved.preferredCountryCode, experience.saved.preferredNodeCode,
        experience.saved.preferredCandidateRef, experience.saved.preferredVariantId), ('US', '', '', 'direct'));
    expect(queries.first['selected_country_code'], 'US');
    expect(runtime.activeProbes, isEmpty);
  });

  test('first connection remembers the observed AS for a desktop uplink', () async {
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)..supportsCandidates = true;
    final bootstrapper = _CachedBootstrapper()..accessNetworkAsn = 'AS12345';
    final manager = _manager(runtime, bootstrapper,
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(bootstrapper.lastSuccessfulNetworkKey, 'asn:AS12345');
  });

  test('final stats preserve bridge identity and consume the verified attempt once', () async {
    final xhttp = TransportCandidate(candidateRef: 'de:xhttp', profileRef: 'xhttp',
      nodeCode: 'de', countryCode: 'DE', protocol: 'vless', transport: 'xhttp',
      protection: 'reality', priority: 1, network: 'tcp', flow: '',
      minimumClientRelease: '1.4.0', minimumCoreRelease: null,
      platforms: {HostPlatform.windows}, requiredFeatures: const {});
    final bootstrapper = _StatsBootstrapper()
      ..candidates = [_candidates.first, xhttp]
      ..materialConfigPayload =
          '{"inbounds":[{"type":"tun","tag":"tun-in"}],"outbounds":[{"type":"socks","tag":"node","server":"127.0.0.1","server_port":1080,"detour":"bridge"},{"type":"socks","tag":"bridge","server":"127.0.0.1","server_port":1081},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"},"_meta":{"runtime_variant_probe":{"mappings":[{"id":"ru-spb","outbound_tag":"node"}]}}}'
      ..exactProfileDelay = const Duration(milliseconds: 30);
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true
      ..failedProbeProfiles.add(_candidates.first.candidateRef);
    final manager = _manager(runtime, bootstrapper,
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);
    manager.updateLocationsCatalog(ClientLocationsCatalog.fromJson({
      'countries': [{'code': 'DE', 'country': 'Germany', 'cities': [
        {'code': 'de', 'city': 'Berlin', 'variants': [
          {'id': 'direct', 'label': 'Direct'}, {'id': 'ru-spb', 'label': 'Bridge'},
        ]},
      ]}],
    }));
    await manager.setPreferredLocation('de', 'ru-spb');
    runtime.connectFailure = StateError('native activation failed');
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(bootstrapper.actualReports.singleWhere((report) => report['runtime_phase'] == 'failed')['candidate_variant'],
        'ru-spb');
    await manager.disconnect();
    await manager.setPreferredLocation('de', 'ru-spb');
    bootstrapper.actualReports.clear();
    bootstrapper.reports.clear();
    runtime.connectFailure = null;
    final reportGate = Completer<void>();
    bootstrapper.runningReportGate = reportGate;
    addTearDown(() { if (!reportGate.isCompleted) reportGate.complete(); });
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    await manager.refresh();
    final running = bootstrapper.actualReports.where((report) => report['runtime_phase'] == 'running').toList();
    expect(running.length, greaterThan(1), reason: 'a healthy refresh overlaps the delayed success report');
    expect(running.where((report) => report['duration_ms'] != null), hasLength(1));
    reportGate.complete();
    bootstrapper.runningReportGate = null;
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (bootstrapper.reports.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(bootstrapper.reports, hasLength(1));
    expect(bootstrapper.reports.single['candidate_ref'], 'de:xhttp');
    expect(bootstrapper.reports.single['candidate_transport'], 'xhttp_reality');
    final probes = (bootstrapper.reports.single['candidate_probes'] as List).cast<Map<String, Object?>>();
    expect(probes.map((item) => item['candidate_ref']),
        containsAll(['de:profile_0', 'de:xhttp']));
    expect(probes.where((item) => item['connected'] == true).single['candidate_ref'], 'de:xhttp');
    expect(probes.map((item) => item['candidate_variant']), everyElement('ru-spb'));
    await manager.disconnect();
    bootstrapper.materialConfigPayload = null;
    final awg = TransportCandidate(candidateRef: 'ch:awg31_lab', profileRef: 'awg31_lab',
      nodeCode: 'ch', countryCode: 'CH', protocol: 'awg', transport: 'udp',
      protection: 'awg31', priority: 0, network: 'udp', flow: '',
      minimumClientRelease: '1.2.0', minimumCoreRelease: null,
      platforms: {HostPlatform.windows}, requiredFeatures: const {});
    bootstrapper.candidates = [awg];
    manager.updateLocationsCatalog(ClientLocationsCatalog.fromJson({
      'countries': [{'code': 'CH', 'country': 'Switzerland', 'cities': [
        {'code': 'ch', 'city': 'Zurich', 'variants': [{'id': 'direct', 'label': 'Direct'}]},
      ]}],
    }));
    await manager.setPreferredLocation('ch', 'direct');
    bootstrapper.actualReports.clear();
    runtime.connectFailure = StateError('new direct activation failed');
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    final failed = bootstrapper.actualReports.singleWhere((report) => report['runtime_phase'] == 'failed');
    expect(failed['candidate_ref'], awg.candidateRef);
    expect(failed['selected_node_code'], 'ch', reason: 'the attempted candidate replaces the previous active DE node in telemetry');
    expect(failed['candidate_variant'],
        isEmpty, reason: 'the new direct material must not inherit the previous active bridge');
  });

  test('routing changes supersede candidate probes without reporting exhaustion', () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-candidate-superseded-');
    addTearDown(() => directory.delete(recursive: true));
    final observability = await PokrovClientObservability.start(
      hostPlatform: HostPlatform.android, directoryResolver: () async => directory,
    );
    final bootstrapper = _StatsBootstrapper(bundle: true)
      ..candidates = [_candidates[1], _candidates[0]];
    final runtime = _Runtime()..supportsCandidates = true..holdProbes = true;
    final manager = _manager(runtime, bootstrapper, observability: observability);
    addTearDown(manager.dispose);
    final connecting = manager.connect();
    await runtime.probeStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(runtime.activeProbes, hasLength(2));
    final attempt = manager.attemptId;
    manager.setRoutingPreferences(const PokrovRoutingPreferences.defaults()
        .copyWith(autoConnectOnUntrustedWifi: true));
    expect(manager.attemptId, attempt);
    runtime.probeRelease.complete();
    await connecting;
    await observability.flush();
    expect(bootstrapper.actualReports.where((report) => report['error_code'] == 'CONN-008'),
        isEmpty, reason: 'a routing revision supersedes its probe instead of exhausting candidates');
    expect(runtime.activeProbes, isEmpty);
    expect(runtime.stagedPayloads, isEmpty);
    expect(runtime.connectCalls, 0);
    expect(manager.status.phase, ConnectionPhase.disconnected);
    final oldEvents = observability.connectionTimelineBreadcrumbs;
    expect(oldEvents.where((event) => event.name == 'app.connection.candidate_probe.finished'), isEmpty);
    expect(oldEvents.singleWhere((event) => event.name == 'app.connection.attempt.finished').outcome.wireValue,
        'cancelled');
    runtime.holdProbes = false;
    await manager.connect();
    await observability.flush();
    expect(manager.status.phase, ConnectionPhase.connected);
    final probes = observability.connectionTimelineBreadcrumbs
        .where((event) => event.name == 'app.connection.candidate_probe.finished');
    expect(probes, isNotEmpty);
    expect(probes.map((event) => event.generation), everyElement(2));
    expect(probes.map((event) => event.failureKind), everyElement('none'));
  });

  test('exhausted native candidates retain the early start and terminal Core error', () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-candidate-failure-');
    addTearDown(() => directory.delete(recursive: true));
    final observability = await PokrovClientObservability.start(
      hostPlatform: HostPlatform.android, directoryResolver: () async => directory,
    );
    final profileGate = Completer<void>();
    final bootstrapper = _StatsBootstrapper()
      ..candidates = [_candidates.first, _CachedBootstrapper.alternatives[1]]
      ..gate = profileGate;
    final runtime = _Runtime()
      ..supportsCandidates = true
      ..failedProbeProfiles.addAll(bootstrapper.candidates.map((item) => item.candidateRef))
      ..probeStages[bootstrapper.candidates.first.candidateRef] = 'proxy_dial'
      ..probeStages[bootstrapper.candidates.last.candidateRef] = 'tls_read';
    var permissionRequests = 0;
    final experienceStore = _ExperienceStore();
    final manager = _manager(runtime, bootstrapper, observability: observability,
        experienceStore: experienceStore,
        authorizeAndroid: () async { permissionRequests++; return true; });
    addTearDown(manager.dispose);

    final connecting = manager.connect();
    await bootstrapper.entered.future;
    expect(bootstrapper.runtimeCalls.single['runtime_phase'], 'connect_requested',
        reason: 'the attempt starts before managed profile preparation completes');
    profileGate.complete();
    await connecting;
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(permissionRequests, 0);
    expect(runtime.connectCalls, 0);
    expect(runtime.stagedPayloads, isEmpty);
    expect(manager.snapshot?.effectiveProfileSource, isNull);
    expect(bootstrapper.actualReports.singleWhere((call) => call['runtime_phase'] == 'failed')['candidate_ref'],
        isEmpty, reason: 'public discovery does not adopt an active candidate');
    expect(manager.transportCatalog?.candidates.map((candidate) => candidate.candidateRef),
        bootstrapper.candidates.map((candidate) => candidate.candidateRef),
        reason: 'verified choices survive first-connection probe exhaustion');
    expect(bootstrapper.runtimeCalls.singleWhere((call) => call['runtime_phase'] == 'failed'),
        {'runtime_phase': 'failed', 'error_code': 'CONN-008'});
    expect(bootstrapper.reports.single['candidate_probes'], hasLength(2));
    await observability.flush();
    final reportedProbes = (bootstrapper.reports.single['candidate_probes'] as List)
        .cast<Map<String, Object?>>();
    expect(reportedProbes.map((probe) => probe['probe_stage']),
        unorderedEquals(['proxy_dial', 'tls_read']));
    final events = await File(
      '${directory.path}/pokrov-observability/operational-events.v1.0.jsonl',
    ).readAsLines();
    final probes = events.map((line) => jsonDecode(line) as Map<String, dynamic>)
        .where((event) => event['name'] == 'app.connection.candidate_probe.finished');
    expect(probes.map((event) => (event['attributes'] as Map)['probe_stage']),
        unorderedEquals(['proxy_dial', 'tls_read']));
    final terminal = events.map((line) => jsonDecode(line) as Map<String, dynamic>)
        .singleWhere((event) => event['name'] == 'app.connection.attempt.finished');
    expect(terminal['error'], {'code': 'CONN-008', 'origin': 'core'});
    expect(terminal['outcome'], 'failed');
    await manager.setInterfaceMode(PokrovInterfaceMode.advanced);
    await manager.setPreferredCandidate(_CachedBootstrapper.alternatives[1].candidateRef);
    expect(experienceStore.saved.preferredCandidateRef, _CachedBootstrapper.alternatives[1].candidateRef);
    expect(runtime.connectCalls, 0);
    expect(runtime.stagedPayloads, isEmpty,
        reason: 'pinning AWG after failure does not start or stage another attempt');
  });

  test('current diagnostic card separates rejected candidate material from native failure', () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-candidate-prepare-');
    addTearDown(() => directory.delete(recursive: true));
    final observability = await PokrovClientObservability.start(
      hostPlatform: HostPlatform.android, directoryResolver: () async => directory,
    );
    final vless = _candidates.first;
    final awg = _CachedBootstrapper.alternatives[1];
    final bootstrapper = _StatsBootstrapper()
      ..candidates = [vless, awg]
      ..exactProfileDelay = const Duration(milliseconds: 30)
      ..exactProfileFailure = const TransportManifestFailure('transport_catalog_profile_mismatch');
    final runtime = _Runtime()
      ..supportsCandidates = true
      ..failedProbeProfiles.add(vless.candidateRef)
      ..probeFailureKinds[vless.candidateRef] = 'connect_failed'
      ..probeStages[vless.candidateRef] = 'proxy_dial';
    final manager = _manager(runtime, bootstrapper, observability: observability);
    addTearDown(manager.dispose);

    await manager.connect();
    await observability.flush();

    expect(runtime.probedProtocols, ['vless'], reason: 'rejected AWG material never reaches the native callback');
    expect(runtime.stagedPayloads, isEmpty);
    expect(runtime.connectCalls, 0);
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    final breadcrumbs = observability.connectionTimelineBreadcrumbs;
    final native = breadcrumbs.singleWhere((event) => event.name == 'app.connection.candidate_probe.finished' &&
        event.failureKind == 'connect_failed');
    expect(native.probeStage, 'proxy_dial');
    final report = PokrovDiagnosticsPresenter.fromRuntime(
      hostPlatform: HostPlatform.android, routeMode: RouteMode.fullTunnel,
      snapshot: manager.snapshot, statusLabel: 'failed', warpState: 'disabled', now: DateTime.now().toUtc(),
      appVersion: '1.5.0', buildNumber: '4115', releaseChannel: 'private', candidateLabel: 'fixture',
      encryptedDeliveryAvailable: false, timelineBreadcrumbs: breadcrumbs,
    );
    final current = report.timelineAttempts.last;
    expect(native.generation, current.generation);
    expect((current.probeFailureKind, current.probeStage), ('invalid_profile', 'parse_profile'),
        reason: 'closed material rejection must survive selector exhaustion in the current card');
    await observability.runConnectionAction(manager.disconnect, beginsWithDisconnect: true);
    await observability.flush();
    final stoppedReport = PokrovDiagnosticsPresenter.fromRuntime(
      hostPlatform: HostPlatform.windows, routeMode: RouteMode.fullTunnel,
      snapshot: manager.snapshot, statusLabel: 'stopped', warpState: 'disabled', now: DateTime.now().toUtc(),
      appVersion: '1.5.0', buildNumber: '4116', releaseChannel: 'private', candidateLabel: 'fixture',
      encryptedDeliveryAvailable: false, timelineBreadcrumbs: observability.connectionTimelineBreadcrumbs,
    );
    final ownFailedAttempt = stoppedReport.timelineAttempts
        .singleWhere((attempt) => attempt.generation == current.generation);
    expect((ownFailedAttempt.probeFailureKind, ownFailedAttempt.probeStage),
        ('invalid_profile', 'parse_profile'), reason: 'Stop must not erase the failed attempt receipt');
    expect(stoppedReport.timelineAttempts.last.generation, greaterThan(current.generation));
    expect((stoppedReport.timelineAttempts.last.probeFailureKind, stoppedReport.timelineAttempts.last.probeStage),
        (null, null), reason: 'the new Stop attempt must not inherit the old failure');
    final supportEvent = DiagnosticEventRecord(
      occurredAt: ownFailedAttempt.entries.last.occurredAtUtc, subsystem: 'candidate_probe',
      stage: ownFailedAttempt.probeStage!, outcome: 'failed',
      candidateFailureKind: ownFailedAttempt.probeFailureKind,
    ).toJson();
    expect(supportEvent['candidate_failure_kind'], 'invalid_profile');
    expect(supportEvent.containsKey('failure_kind'), isFalse);
    expect(() => DiagnosticEventRecord(
      occurredAt: DateTime.now().toUtc(), subsystem: 'candidate_probe', stage: 'probe', outcome: 'failed',
      candidateFailureKind: 'unknown_sensitive_reason',
    ), throwsArgumentError);
  });

  test('proven Windows connection retries a probe batch after stats delivery fails', () async {
    final direct = TransportCandidate(candidateRef: 'warp:warp_free:warp_direct',
      profileRef: 'warp_free', nodeCode: '', countryCode: 'ZZ', protocol: 'warp',
      transport: 'udp', protection: 'warp', priority: 0, network: 'udp', flow: '',
      minimumClientRelease: '1.5.0', minimumCoreRelease: '1.2.8',
      platforms: {HostPlatform.windows}, requiredFeatures: const {}, warpMode: 'warp_direct');
    final bootstrapper = _StatsBootstrapper(warpEnabled: true, bundle: true)
      ..candidates = [direct]..failFirstRunningReport = true;
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true..coreVersion = '1.2.9'
      ..probeDuration = const Duration(milliseconds: 321);
    final manager = _manager(runtime, bootstrapper,
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);

    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    final failureDeadline = DateTime.now().add(const Duration(seconds: 2));
    while (bootstrapper.failedRunningReports == 0 && DateTime.now().isBefore(failureDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(bootstrapper.failedRunningReports, 1);
    await manager.refresh();
    final reportDeadline = DateTime.now().add(const Duration(seconds: 2));
    while (bootstrapper.reports.isEmpty && DateTime.now().isBefore(reportDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(bootstrapper.reports, hasLength(1));
    expect(bootstrapper.reports.single['connected'], true);
    expect(bootstrapper.reports.single['candidate_ref'], direct.candidateRef);
    expect(bootstrapper.reports.single['candidate_transport'], 'warp');
    expect(bootstrapper.actualReports.where((report) => report['candidate_ref'] == direct.candidateRef)
        .map((report) => report['selected_node_code']), everyElement(isEmpty));
    final probes = (bootstrapper.reports.single['candidate_probes'] as List).cast<Map<String, Object?>>();
    expect(probes, [{'candidate_ref': direct.candidateRef, 'candidate_transport': 'warp',
      'stage': 'probe', 'connected': true, 'failure_kind': '', 'duration_ms': 321}]);
    await manager.refresh();
    expect(bootstrapper.reports, hasLength(1));

    await manager.disconnect();
    final hy2 = _CachedBootstrapper.alternatives[2];
    final awg = _CachedBootstrapper.alternatives[1];
    bootstrapper
      ..candidates = [hy2]..failFirstRunningReport = true
      ..failedProbeReportCandidates.add(hy2.candidateRef);
    runtime.probeDuration = const Duration(milliseconds: 1018);
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    final nextFailureDeadline = DateTime.now().add(const Duration(seconds: 2));
    while (bootstrapper.failedRunningReports < 2 && DateTime.now().isBefore(nextFailureDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(bootstrapper.failedRunningReports, 2);
    await manager.disconnect();
    bootstrapper.candidates = [awg];
    runtime.probeDuration = const Duration(milliseconds: 1852);
    await manager.connect();
    final nextReportDeadline = DateTime.now().add(const Duration(seconds: 2));
    while (bootstrapper.reports.length < 2 && DateTime.now().isBefore(nextReportDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(bootstrapper.reports, hasLength(2));
    expect(bootstrapper.reports.last['attempt_number'], 3);
    expect(bootstrapper.reports.last['candidate_probes'], [
      {'candidate_ref': awg.candidateRef, 'candidate_transport': 'awg31',
        'stage': 'probe', 'connected': true, 'failure_kind': '', 'duration_ms': 1852},
    ], reason: 'a failed HY2 delivery cannot enter the next AWG attempt');
  });

  test('late probe acknowledgement preserves the next attempt batch', () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-probe-ack-');
    addTearDown(() => directory.delete(recursive: true));
    final observability = await PokrovClientObservability.start(
        hostPlatform: HostPlatform.windows, directoryResolver: () async => directory);
    final hy2 = _CachedBootstrapper.alternatives[2];
    final awg = _CachedBootstrapper.alternatives[1];
    final reportGate = Completer<void>();
    addTearDown(() { if (!reportGate.isCompleted) reportGate.complete(); });
    final bootstrapper = _StatsBootstrapper()
      ..candidates = [hy2]..runningReportGate = reportGate;
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true..coreVersion = '1.2.9'
      ..probeDuration = const Duration(milliseconds: 1018);
    final manager = _manager(runtime, bootstrapper, observability: observability,
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);

    await manager.connect();
    await manager.disconnect();
    bootstrapper
      ..candidates = [awg]..runningReportGate = null;
    runtime.probeDuration = const Duration(milliseconds: 1852);
    await manager.connect();
    expect(bootstrapper.reports, isEmpty);
    reportGate.complete();
    final oldReportDeadline = DateTime.now().add(const Duration(seconds: 2));
    while (bootstrapper.reports.isEmpty && DateTime.now().isBefore(oldReportDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(bootstrapper.reports.single['attempt_number'], 1);
    expect(bootstrapper.reports.single['candidate_ref'], hy2.candidateRef);
    await manager.refresh();
    final newReportDeadline = DateTime.now().add(const Duration(seconds: 2));
    while (bootstrapper.reports.length < 2 && DateTime.now().isBefore(newReportDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(bootstrapper.reports, hasLength(2));
    expect(bootstrapper.reports.last['attempt_number'], 2);
    expect(bootstrapper.reports.last['candidate_probes'], [
      {'candidate_ref': awg.candidateRef, 'candidate_transport': 'awg31',
        'stage': 'probe', 'connected': true, 'failure_kind': '', 'duration_ms': 1852},
    ], reason: 'the old POST acknowledges only its own map objects');
    await observability.flush();
    final events = await File(
        '${directory.path}/pokrov-observability/operational-events.v1.0.jsonl').readAsLines();
    expect(events.map((line) => jsonDecode(line) as Map<String, dynamic>)
        .where((event) => event['name'] == 'app.runtime.stats_delivery.finished'), isEmpty,
        reason: 'a late acknowledgement cannot fail delivery with RangeError');
  });

  for (final platform in [HostPlatform.android, HostPlatform.windows]) {
  test('cold ${platform.name} readiness exposes cached transports before an unavailable API without Connect', () async {
    final refreshGate = Completer<void>();
    final bootstrapper = _CachedBootstrapper()..cacheRefreshGate = refreshGate.future;
    final runtime = _Runtime(hostPlatform: platform)
      ..supportsCandidates = true..coreVersion = '1.2.9'
      ..phase = platform == HostPlatform.android ? RuntimePhase.configStaged : RuntimePhase.artifactReady
      ..coreInitializationPending = platform == HostPlatform.android;
    var consentRequests = 0;
    final manager = _manager(runtime, bootstrapper,
      authorizeAndroid: () async { consentRequests++; return true; },
      authorizeWindows: () async { consentRequests++; return PokrovWindowsTunnelAuthorization.allowed; });
    addTearDown(manager.dispose);

    manager.markExperienceLoaded();
    await Future<void>.delayed(Duration.zero);
    expect(manager.transportCatalog, isNull);
    expect(bootstrapper.refreshedCoreReleases, isEmpty);
    expect(runtime.value(runtime.phase).coreVersion, isNull);
    expect(runtime.value(runtime.phase).transportCapabilities, isNull);
    if (platform == HostPlatform.android) {
      expect(runtime.value(runtime.phase).stagedConfigPath, isNotNull,
          reason: 'restoring a profile pointer does not initialize the loaded Core');
    }
    await manager.refresh();
    expect(manager.snapshot?.phase, RuntimePhase.initialized);
    expect(manager.snapshot?.coreVersion, '1.2.9');
    await bootstrapper.cacheRefreshEntered.future.timeout(const Duration(seconds: 3));
    expect(manager.transportCatalog?.candidates.map((candidate) => candidate.protocol),
        ['vless', 'awg', 'hysteria2']);
    refreshGate.completeError(const SocketException('offline'));
    await Future<void>.delayed(Duration.zero);
    await manager.refresh();
    expect(bootstrapper.refreshedCoreReleases, ['1.2.9'], reason: 'unchanged snapshots do not refetch');
    expect(manager.transportCatalog?.candidates, _CachedBootstrapper.alternatives);
    expect(runtime.stagedPayloads, isEmpty);
    expect(runtime.connectCalls, 0);
    expect(runtime.handoffCalls, 0);
    expect(runtime.calls.where((call) => call == 'initialize'), hasLength(1));
    expect(consentRequests, 0);
  });
  }

  testWidgets('Locations adopts ready cached protocols after one failed cold metadata refresh', (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final nativeMutations = <String>[];
    var nativeSnapshots = 0;
    final features = RuntimeTransportFeature.values.map((feature) => feature.wireName).toList()..sort();
    final bootstrapper = _CatalogPickerBootstrapper((await tester.runAsync(_pickerCatalog))!)
      ..cacheAvailable = false
      ..nextCacheRefreshFailure = const SocketException('offline')
      ..locationsCatalog = ClientLocationsCatalog.fromJson({
        'countries': [{'code': 'DE', 'country': 'Germany', 'cities': [
          {'code': 'de', 'city': 'Frankfurt', 'variants': [
            {'id': 'direct', 'label': 'Обычный'},
          ]},
        ]}],
      });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.snapshot') nativeSnapshots++;
      if (const {'runtimeEngine.initialize', 'runtimeEngine.stageManagedProfile', 'runtimeEngine.connect'}
          .contains(call.method)) nativeMutations.add(call.method);
      return {'phase': 'initialized', 'coreVersion': '1.2.10',
        'supportsLiveConnect': true, 'canInitialize': false, 'canConnect': true,
        'transportCapabilitiesJson': jsonEncode({'schema': 1, 'features': features})};
    });
    await tester.pumpWidget(MaterialApp(home: PokrovSeedShell(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      bootstrapper: bootstrapper, firstLaunchStore: _FirstLaunchStore(),
      clientExperienceStore: _CatalogPickerExperience(), themeMode: ThemeMode.light,
      onThemeModeChanged: (_) {},
    )));
    await tester.pumpAndSettle();
    expect(bootstrapper.refreshedInputs, hasLength(1));
    expect(bootstrapper.refreshedInputs.single.preferredVariantId, 'direct');
    expect(bootstrapper.refreshedFeatures.single,
        containsAll({RuntimeTransportFeature.awg31, RuntimeTransportFeature.hysteria2}));
    expect(bootstrapper.refreshedCoreReleases, ['1.2.10']);
    expect(bootstrapper.nextCacheRefreshFailure, isNull);
    final snapshotsBefore = nativeSnapshots;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(nativeSnapshots, greaterThan(snapshotsBefore));
    expect(bootstrapper.refreshedInputs, hasLength(1), reason: 'unchanged capabilities do not retry metadata');

    bootstrapper.cacheAvailable = true;
    await tester.tap(find.text('Локации'));
    await tester.pumpAndSettle();
    final dynamic locations = tester.widget(find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_LocationsSection'));
    expect(locations.interfaceMode, PokrovInterfaceMode.advanced);
    expect(nativeMutations, isEmpty);
    expect(locations.hasOrdinaryTransportCatalog, isTrue,
        reason: 'normal Locations entry must adopt ready protocols without a warming Connect');
    expect((locations.transportCatalog as TransportCandidateCatalog).candidates.map((candidate) => candidate.protocol),
        ['vless', 'awg', 'hysteria2']);
  });

  test('loaded Core refresh publishes the full catalog without replacing the running material', () async {
    final refreshGate = Completer<void>();
    final bootstrapper = _CachedBootstrapper()
      ..cacheAvailable = false..cacheRefreshGate = refreshGate.future;
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true..coreVersion = '1.2.9';
    final manager = _manager(runtime, bootstrapper,
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);

    manager.markExperienceLoaded();
    await Future<void>.delayed(Duration.zero);
    expect(bootstrapper.refreshedCoreReleases, isEmpty,
        reason: 'startup does not replace an authorized catalog before Core reports capabilities');
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.transportCatalog?.candidates, _candidates);
    await bootstrapper.cacheRefreshEntered.future.timeout(const Duration(seconds: 3));
    final catalogPublished = Completer<void>();
    manager.addListener(() {
      if (manager.transportCatalog?.revision == 'cached' && !catalogPublished.isCompleted) {
        catalogPublished.complete();
      }
    });
    bootstrapper.cacheAvailable = true;
    refreshGate.complete();
    await catalogPublished.future.timeout(const Duration(seconds: 3));

    expect(manager.transportCatalog?.candidates.map((candidate) => candidate.protocol),
        ['vless', 'awg', 'hysteria2']);
    expect(bootstrapper.refreshedCoreReleases, ['1.2.9']);
    expect(manager.materialCandidate?.candidateRef, _candidates.first.candidateRef);
    expect(runtime.stagedPayloads, hasLength(1));
    expect(runtime.connectCalls, 1);
    expect(runtime.handoffCalls, 0);
  });

  test('managed catalog receives the observed Core release', () async {
    final bootstrapper = _Bootstrapper(catalog: true);
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true
      ..coreVersion = '1.1.2';
    final manager = _manager(runtime, bootstrapper,
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);

    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(bootstrapper.lastCoreRelease, '1.1.2');
  });

  test('WARP candidate probes its chain and ordinary fallback stays ordinary', () async {
    final base = _candidates.first;
    final chain = TransportCandidate(candidateRef: '${base.candidateRef}:proxy_over_warp',
      profileRef: base.profileRef, nodeCode: base.nodeCode, countryCode: 'DE',
      protocol: base.protocol, transport: base.transport, protection: base.protection,
      priority: 1, network: base.network, flow: base.flow,
      minimumClientRelease: '1.4.0', minimumCoreRelease: null,
      platforms: base.platforms, requiredFeatures: base.requiredFeatures,
      warpMode: 'proxy_over_warp');
    final bootstrapper = _Bootstrapper(catalog: true, warpEnabled: true)
      ..candidates = [base, chain];
    final runtime = _Runtime()..supportsCandidates = true;
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.connect();
    expect(manager.transportCatalog?.selectedCandidateRef, chain.candidateRef);
    expect(runtime.probedWarpModes, ['proxy_over_warp']);
    expect(runtime.stagedPayloads.last.warpPolicy.canEnableRuntime, isTrue);
    runtime.failedProbeProfiles.add(chain.candidateRef);
    await manager.reconnect();
    expect(manager.transportCatalog?.selectedCandidateRef, base.candidateRef);
    expect(runtime.probedWarpModes.last, '');
    expect(runtime.stagedPayloads.last.warpPolicy.canEnableRuntime, isFalse);
    final probesBeforeApiFailure = runtime.probedWarpModes.length;
    final networkRead = Completer<RuntimeCandidateNetwork>();
    runtime.nextNetworkRead = networkRead;
    final reconnect = manager.reconnect();
    await runtime.networkReadEntered.future;
    bootstrapper.failure = const BootstrapFailure('Synthetic API socket denial',
        operationalCode: 'API-002', apiFailureKind: 'request_socket', osErrorCode: 10013);
    networkRead.complete(RuntimeCandidateNetwork(selectionKey: runtime.candidateKey,
        contextRef: runtime.candidateContext, networkAvailable: true, networkClass: 'wifi'));
    await reconnect;
    expect(bootstrapper.resolutions.last.selected, chain.candidateRef,
        reason: 'the WARP group needs its exact material after the initial ordinary reply');
    expect(runtime.probedWarpModes.skip(probesBeforeApiFailure), [''],
        reason: 'a material API failure must leave the ready ordinary group available');
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.materialCandidate?.candidateRef, base.candidateRef);
    expect(runtime.activeProbes, isEmpty);
  });

  test('hanging WARP candidates leave time for ordinary fallback', () async {
    final base = _candidates.first;
    final chains = List.generate(7, (index) => TransportCandidate(
      candidateRef: '${base.candidateRef}:proxy_over_warp:$index',
      profileRef: base.profileRef, nodeCode: base.nodeCode, countryCode: base.countryCode,
      protocol: base.protocol, transport: base.transport, protection: base.protection,
      priority: index + 1, network: base.network, flow: base.flow,
      minimumClientRelease: '1.4.0', minimumCoreRelease: null,
      platforms: base.platforms, requiredFeatures: base.requiredFeatures,
      warpMode: 'proxy_over_warp'));
    final bootstrapper = _Bootstrapper(catalog: true, warpEnabled: true)
      ..candidates = [base, ...chains];
    final runtime = _Runtime()..supportsCandidates = true
      ..heldProbeProfiles.addAll(chains.map((candidate) => candidate.candidateRef));
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    final clock = Stopwatch()..start();

    await manager.connect();

    expect(clock.elapsed, lessThan(const Duration(seconds: 9)));
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.transportCatalog?.selectedCandidateRef, base.candidateRef);
    expect(runtime.probedWarpModes, contains('proxy_over_warp'));
    expect(runtime.probedWarpModes.last, '');
    expect(runtime.activeProbes, isEmpty);
  });

  test('1.3 catalog still stages consented WARP without chain entries', () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final manager = _manager(runtime, _Bootstrapper(catalog: true, warpEnabled: true));
    addTearDown(manager.dispose);
    await manager.connect();
    expect(runtime.stagedPayloads.last.warpPolicy.canEnableRuntime, isTrue);
  });

  test('direct WARP is the consented last reserve and retries nodes next time', () async {
    final base = _candidates.first;
    final direct = TransportCandidate(candidateRef: 'warp:warp_free:warp_direct',
      profileRef: 'warp_free', nodeCode: '', countryCode: 'ZZ', protocol: 'warp',
      transport: 'udp', protection: 'warp', priority: 0, network: 'udp', flow: '',
      minimumClientRelease: '1.5.0+4099', minimumCoreRelease: '1.2.8',
      platforms: base.platforms, requiredFeatures: const {}, warpMode: 'warp_direct');
    final runtime = _Runtime()..supportsCandidates = true
      ..failedProbeProtocols.add('vless');
    final bootstrapper = _CachedBootstrapper(warpEnabled: true, bundle: true)
      ..cacheAvailable = false..candidates = [base, direct];
    final experienceStore = _ExperienceStore();
    final manager = _manager(runtime, bootstrapper, experienceStore: experienceStore);
    addTearDown(manager.dispose);
    manager.restoreConnectionPreferences(
      const PokrovClientExperienceState.empty().copyWith(preferredCountryCode: 'DE'), const {});

    await manager.connect();
    expect(runtime.probedProtocols, ['vless', 'warp']);
    expect(runtime.stagedPayloads.last.warpPolicy.mode, 'warp_direct');
    expect(runtime.stagedPayloads.last.warpPolicy.id, 'warp-direct:test-install');
    expect(manager.headline, contains('WARP · бесплатный'));
    expect(manager.materialCandidate?.nodeCode, isEmpty);
    expect(runtime.activeProbes, isEmpty);
    expect(bootstrapper.provenNetworks.last, (null, null));
    expect(experienceStore.saved.preferredCountryCode, 'DE');

    await manager.disconnect();
    runtime.failedProbeProtocols.clear();
    runtime.probedProtocols.clear();
    await manager.connect();
    expect(runtime.probedProtocols, ['vless']);
    expect(runtime.stagedPayloads.last.warpPolicy.canEnableRuntime, isFalse);
    expect(bootstrapper.provenNetworks.last.$1, 'network-a');
    await manager.disconnect();
    await manager.setInterfaceMode(PokrovInterfaceMode.advanced);
    await manager.setPreferredCandidate(direct.candidateRef);
    await manager.setInterfaceMode(PokrovInterfaceMode.simple);
    await Future<void>.delayed(Duration.zero);
    expect(experienceStore.saved.preferredCountryCode, isEmpty);

    final noConsentRuntime = _Runtime()..supportsCandidates = true
      ..failedProbeProtocols.add('vless');
    final noConsent = _manager(noConsentRuntime,
      _Bootstrapper(catalog: true, bundle: true)..candidates = [base, direct]);
    addTearDown(noConsent.dispose);
    await noConsent.connect();
    expect(noConsentRuntime.probedProtocols, ['vless']);
    expect(noConsentRuntime.connectCalls, 0);
  });

  test('WARP last does not claim the node country as its exit', () async {
    final base = _candidates.first;
    final otherCountry = TransportCandidate(candidateRef: 'pl:${base.profileRef}',
      profileRef: base.profileRef, nodeCode: 'pl', countryCode: 'PL',
      protocol: base.protocol, transport: base.transport, protection: base.protection,
      priority: 0, network: base.network, flow: base.flow,
      minimumClientRelease: base.minimumClientRelease, minimumCoreRelease: null,
      platforms: base.platforms, requiredFeatures: base.requiredFeatures);
    final otherWarp = TransportCandidate(candidateRef: '${otherCountry.candidateRef}:warp_over_proxy',
      profileRef: base.profileRef, nodeCode: 'pl', countryCode: 'ZZ',
      protocol: base.protocol, transport: base.transport, protection: base.protection,
      priority: 0, network: base.network, flow: base.flow,
      minimumClientRelease: '1.4.0', minimumCoreRelease: null,
      platforms: base.platforms, requiredFeatures: base.requiredFeatures,
      warpMode: 'warp_over_proxy');
    final warpLast = TransportCandidate(candidateRef: '${base.candidateRef}:warp_over_proxy',
      profileRef: base.profileRef, nodeCode: base.nodeCode, countryCode: 'ZZ',
      protocol: base.protocol, transport: base.transport, protection: base.protection,
      priority: 1, network: base.network, flow: base.flow,
      minimumClientRelease: '1.4.0', minimumCoreRelease: null,
      platforms: base.platforms, requiredFeatures: base.requiredFeatures,
      warpMode: 'warp_over_proxy');
    final bootstrapper = _Bootstrapper(catalog: true, warpEnabled: true)
      ..candidates = [base, otherCountry, otherWarp, warpLast];
    final runtime = _Runtime()..supportsCandidates = true;
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    manager.restoreConnectionPreferences(
      const PokrovClientExperienceState.empty().copyWith(preferredCountryCode: 'DE'), const {});
    await manager.connect();
    expect(manager.transportCatalog?.selected.nodeCode, 'de');
    expect(manager.transportCatalog?.selected.countryCode, 'ZZ');
    expect(runtime.stagedPayloads.last.warpPolicy.mode, 'warp_over_proxy');
    expect(runtime.stagedPayloads.last.warpPolicy.canEnableRuntime, isTrue);
    expect(manager.headline, contains('Страна выхода неизвестна'));
    expect(bootstrapper.resolutions.where((request) => request.selected.isNotEmpty)
        .map((request) => request.selected), everyElement(warpLast.candidateRef));
    expect(SmartConnectCandidateSelector.cacheAlternatives(warpLast, bootstrapper.candidates,
        countryOnly: true, catalog: manager.transportCatalog!), isEmpty);

    await manager.disconnect();
    runtime.failedProbeProfiles.add(warpLast.candidateRef);
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.transportCatalog?.selected.candidateRef, base.candidateRef);
    expect(runtime.stagedPayloads.last.warpPolicy.canEnableRuntime, isFalse);
    expect(runtime.probedWarpModes.last, '');
    expect(bootstrapper.resolutions.where((request) => request.selected.isNotEmpty)
        .map((request) => request.selected), isNot(contains(otherWarp.candidateRef)));
  });

  test('first Android candidate can finish after four seconds while cached probes still cancel', () async {
    final bootstrapper = _CachedBootstrapper()
      ..cacheAvailable = false
      ..candidates = [_candidates.first];
    final runtime = _Runtime()
      ..supportsCandidates = true
      ..probeDelay = const Duration(seconds: 5);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);

    await manager.connect();
    expect(runtime.probeTimeouts, [const Duration(seconds: 12)]);
    expect(manager.status.phase, ConnectionPhase.connected, reason: manager.headline);
    expect(runtime.activeProbes, isEmpty);
    expect(runtime.connectCalls, 1);

    await manager.disconnect();
    bootstrapper
      ..cacheAvailable = true
      ..failure = TimeoutException('managed API unavailable');
    runtime.probeTimeouts.clear();
    await manager.connect();
    expect(runtime.probeTimeouts, isNotEmpty);
    expect(runtime.probeTimeouts, everyElement(const Duration(seconds: 4)));
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(runtime.activeProbes, isEmpty);
    expect(runtime.connectCalls, 1);
  });

  test('Android first Connect can cancel while certificate preparation waits', () async {
    final gate = Completer<RuntimeCandidateNetwork>();
    final runtime = _Runtime()..supportsCandidates = true..nextNetworkRead = gate;
    final manager = _manager(runtime, _Bootstrapper(catalog: true));
    addTearDown(manager.dispose);
    final connecting = manager.connect();
    await runtime.networkReadEntered.future;
    await manager.disconnect().timeout(const Duration(seconds: 1));
    await connecting;
    expect(manager.busy, isFalse);
    expect(runtime.connectCalls, 0);
    expect(runtime.probeContexts, isEmpty);
    gate.complete(const RuntimeCandidateNetwork(selectionKey: 'network-a', contextRef: 'context-a',
        networkAvailable: true, captivePortal: false));
    await Future<void>.delayed(Duration.zero);
    expect(runtime.connectCalls, 0);
    expect(runtime.probeContexts, isEmpty);
  });

  test('cold candidate HTTP preparation does not consume the native probe budget', () async {
    final alternatives = _CachedBootstrapper.alternatives;
    final bootstrapper = _Bootstrapper(catalog: true)
      ..candidates = [alternatives[1], alternatives[0], alternatives[2]]
      ..exactProfileDelay = const Duration(milliseconds: 4300);
    final runtime = _Runtime()..supportsCandidates = true;
    runtime.heldProbeProtocols.addAll(['awg', 'vless']);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);

    await manager.connect();

    expect(runtime.probedProtocols, containsAll(['awg', 'vless', 'hysteria2']),
        reason: 'an initial AWG timeout must not discard pending exact TCP/HY2 profiles');
    expect(bootstrapper.cancelledExactProfiles, isEmpty,
        reason: 'the HTTP preparation is bounded by selection, not the native four-second probe');
    expect(runtime.stagedProfile, alternatives[2].candidateRef);
    expect(runtime.activeProbes, isEmpty);
    expect(manager.status.phase, ConnectionPhase.connected);
  });

  test('confirmed failure races cached alternatives before a hanging API or AWG probe', () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final bootstrapper = _CachedBootstrapper();
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.connect();
    final resolutionsBefore = bootstrapper.resolutions.length;
    final probesBefore = runtime.probedProtocols.length;
    bootstrapper.gate = Completer<void>();
    addTearDown(() => bootstrapper.gate!.complete());
    runtime.heldProbeProtocols.add('awg');
    runtime.warpEgressFailure = true;

    await runtime.handoffStarted.future.timeout(const Duration(seconds: 3), onTimeout: () {
      fail('${manager.status.phase}: ${manager.headline}; probes=${runtime.probedProtocols}; calls=${runtime.calls}');
    });
    while (manager.busy) { await Future<void>.delayed(Duration.zero); }
    expect(bootstrapper.resolutions, hasLength(resolutionsBefore), reason: 'ready cache never waits for the API');
    expect(runtime.probedProtocols.skip(probesBefore), ['awg', 'hysteria2'],
        reason: 'the confirmed failed current is not probed again');
    expect(runtime.handoffProfiles, ['de:cached_2']);
    expect(runtime.activeProbes, isEmpty, reason: 'the losing AWG probe settles before handoff');
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.connected);
  });

  test('candidate recovery keeps the selected route and DNS policy', () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final store = _ExperienceStore();
    final bootstrapper = _CachedBootstrapper()
      ..materialConfigPayload = '{"inbounds":[{"type":"tun","tag":"tun-in"}],"outbounds":[{"type":"socks","tag":"node","server":"127.0.0.1","server_port":1080},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"},"dns":{"servers":[{"tag":"dns-bootstrap","address":"tls://1.1.1.1","detour":"proxy"}]}}';
    final manager = _manager(runtime, bootstrapper, experienceStore: store);
    addTearDown(manager.dispose);
    manager.selectRouteMode(RouteMode.allExceptRu);
    manager.setRoutingPreferences(
      const PokrovRoutingPreferences.defaults().copyWith(
        purposeRoutes: {PokrovPurposeRoute.ruDirect},
        dnsPreset: PokrovDnsPreset.adguard,
      ),
    );

    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected,
        reason: store.saved.protectionEvents.map((event) => event.detail).join('; '));
    final before = jsonDecode(runtime.stagedPayloads.last.configPayload) as Map;
    runtime.warpEgressFailure = true;
    await runtime.handoffStarted.future.timeout(const Duration(seconds: 3));
    while (manager.busy) {
      await Future<void>.delayed(Duration.zero);
    }
    final recovered = runtime.stagedPayloads.last;
    final after = jsonDecode(recovered.configPayload) as Map;

    expect(recovered.routeMode, RouteMode.allExceptRu);
    expect(after['route'], before['route']);
    expect(after['dns'], before['dns']);
    expect((after['route'] as Map)['final'], 'proxy');
    expect(((after['dns'] as Map)['servers'] as List).cast<Map>()
        .singleWhere((server) => server['tag'] == 'pokrov-user-dns'), {
      'tag': 'pokrov-user-dns',
      'type': 'https',
      'server': 'dns.adguard-dns.com',
      'detour': 'proxy',
      'domain_resolver': 'dns-bootstrap',
    });
  });

  test('repeated periodic failure recovers when the UI reads the failed snapshot first', () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final bootstrapper = _CachedBootstrapper();
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.connect();
    runtime.warpEgressFailure = true;
    await runtime.handoffStarted.future.timeout(const Duration(seconds: 3));
    while (manager.busy) { await Future<void>.delayed(Duration.zero); }
    expect(runtime.handoffProfiles, ['de:cached_1']);
    expect(manager.status.phase, ConnectionPhase.connected);

    runtime.warpEgressFailure = true;
    expect((await manager.readSnapshot()).hasCoreEgressProbeFailure, isTrue);
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while ((runtime.handoffCalls < 2 || manager.busy) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(runtime.handoffProfiles, ['de:cached_1', 'de:cached_2']);
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(runtime.calls, isNot(contains('disconnect')));
  });

  for (final interrupt in ['cancel', 'deny']) {
    test('$interrupt during cached recovery cannot activate a late winner', () async {
      final runtime = _Runtime()..supportsCandidates = true;
      final bootstrapper = _CachedBootstrapper();
      final manager = _manager(runtime, bootstrapper);
      addTearDown(manager.dispose);
      await manager.connect();
      final resolutionsBefore = bootstrapper.resolutions.length;
      bootstrapper.gate = Completer<void>();
      addTearDown(() => bootstrapper.gate!.complete());
      final gate = Completer<void>();
      runtime.alternateProbeGate = gate.future;
      runtime.warpEgressFailure = true;
      await runtime.alternateProbeStarted.future.timeout(const Duration(seconds: 3));
      if (interrupt == 'cancel') {
        await manager.cancel();
      } else {
        await manager.denyAccess();
        gate.complete();
      }
      while (manager.busy) { await Future<void>.delayed(Duration.zero); }
      expect(runtime.handoffCalls, 0);
      expect(runtime.activeProbes, isEmpty);
      expect(bootstrapper.resolutions, hasLength(resolutionsBefore));
      expect(runtime.calls, isNot(contains('disconnect')));
      expect(manager.retainsProtection, isTrue);
    });
  }

  test('failed protected recovery never disconnects and explicit off releases it', () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final bootstrapper = _StatsBootstrapper();
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    await manager.refresh();
    final successful = bootstrapper.actualReports.where((report) => report['runtime_phase'] == 'running');
    expect(successful.where((report) => report['duration_ms'] != null), hasLength(1));
    expect(bootstrapper.actualReports.last['duration_ms'], isNull,
        reason: 'the healthy report already consumed the original attempt clock');
    runtime.warpEgressFailure = true;
    runtime.failHandoff = true;
    await runtime.handoffStarted.future;
    while (manager.busy) { await Future<void>.delayed(Duration.zero); }
    final failed = bootstrapper.actualReports.where((report) => report['runtime_phase'] == 'failed').toList();
    expect(failed, hasLength(1), reason: 'exhausted recovery must report after a healthy connection');
    expect(failed.single['attempt_number'], 1);
    expect(failed.single['duration_ms'], isNull, reason: 'automatic recovery cannot renew the user attempt');
    expect(failed.single['error_code'], 'core_egress_probe_failed');
    expect(failed.single['native_kind'], 'core_egress_probe_failed');
    expect(failed.single['retryable'], isTrue);
    expect(bootstrapper.actualReports.where((report) => report['runtime_phase'] == 'connect_requested'), hasLength(1));
    expect(runtime.connectCalls, 1);
    expect(runtime.handoffCalls, 3);
    expect(runtime.handoffProfiles.toSet(), hasLength(3), reason: 'activation failures advance to different candidates');
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(manager.retainsProtection, isTrue);
    await expectLater(manager.repair(), throwsA(isA<BootstrapFailure>()));
    expect(runtime.handoffCalls, inInclusiveRange(4, 6), reason: 'a retry also keeps the native guard');
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.presentation.primaryActionLabel, 'Отключить');
    expect(manager.presentation.primaryActionEnabled, isTrue);
    await manager.toggle();
    expect(runtime.calls.where((call) => call == 'disconnect'), hasLength(1));
    expect(manager.retainsProtection, isFalse);
  });

  test('fresh native proof retires a preparation-only recovery failure', () async {
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true
      ..profileDigest = 'a' * 64
      ..proofObservedAt = DateTime.utc(2026, 10, 8)
      ..profileSource = RuntimeProfileSource(revision: 'current-owner',
          origin: RuntimeProfileSourceOrigin.values.first, protocol: 'vless');
    final bootstrapper = _StatsBootstrapper();
    final manager = _manager(runtime, bootstrapper,
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    runtime.failedProbeProfiles.addAll(_candidates.map((candidate) => candidate.candidateRef));
    runtime.warpEgressFailure = true;
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while ((manager.status.phase != ConnectionPhase.actionRequired || manager.busy) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(bootstrapper.actualReports.where((report) => report['runtime_phase'] == 'failed'), hasLength(1));
    expect(runtime.stagedPayloads, hasLength(1));
    expect(runtime.connectCalls, 1);
    expect(runtime.handoffCalls, 0, reason: 'recovery exhausted before native replacement');
    expect(manager.snapshot?.phase, RuntimePhase.running);
    expect(manager.snapshot?.protectionRetained, isFalse);
    expect(manager.snapshot?.proofObservedAt, isNull);
    expect(manager.retainsProtection, isTrue, reason: 'App protects traffic while preparation fails');

    runtime.warpEgressFailure = false; // The same unbound owner passed its periodic verifier.
    runtime.proofObservedAt = DateTime.utc(2026, 10, 8, 0, 0, 1);
    await manager.refresh();
    expect(manager.snapshot?.isCleanlyHealthy, isTrue);
    expect(manager.snapshot?.lastFailureKind, isNull);
    expect(manager.snapshot?.proofObservedAt, runtime.proofObservedAt);
    expect(manager.snapshot?.stagedProfileSource, runtime.profileSource);
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.retainsProtection, isFalse);
    expect(runtime.stagedPayloads, hasLength(1));
    expect(runtime.connectCalls, 1);
    expect(runtime.handoffCalls, 0);
    expect(runtime.calls, isNot(contains('disconnect')));
  });

  test('cold healthy Android owner restores its display node without selecting a candidate', () async {
    final runtime = _Runtime()
      ..phase = RuntimePhase.running
      ..stagedProfile = 'existing-owner'
      ..profileDigest = 'b' * 64
      ..activeDisplayNodeCode = 'ch';
    final bootstrapper = _StatsBootstrapper();
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.refresh();
    expect(bootstrapper.actualReports.last['selected_node_code'], 'ch');
    expect(manager.status.routes.profileDirty, isTrue, reason: 'displaying the active owner cannot apply pending settings');
    expect(manager.materialCandidate, isNull);
    expect(manager.transportCatalog, isNull);
    expect(bootstrapper.resolutions, isEmpty);
    expect(runtime.stagedPayloads, isEmpty);
    expect(runtime.connectCalls, 0);
    expect(runtime.handoffCalls, 0);

    runtime.transportProofPending = true;
    runtime.activeDisplayNodeCode = 'de';
    await manager.refresh();
    expect(bootstrapper.actualReports.last['selected_node_code'], 'ch',
        reason: 'a pending proof cannot replace the last active display node');
  });

  test('successful probe followed by activation failure advances without disconnect', () async {
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)..supportsCandidates = true;
    final manager = _manager(runtime, _Bootstrapper(catalog: true),
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);
    await manager.connect();
    runtime.failedHandoffProfile = 'de:profile_0';
    await manager.reconnect();
    expect(runtime.handoffProfiles, ['de:profile_0', 'de:profile_1']);
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(runtime.overlappingMutation, isFalse);
  });

  test('declined protected replacement retires retention after a fresh stopped snapshot', () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final bootstrapper = _Bootstrapper(catalog: true);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.connect();
    expect(manager.materialCandidate?.candidateRef, _candidates.first.candidateRef);

    bootstrapper.candidates = [_candidates[1]];
    runtime.declineNextHandoff = true;
    await manager.reconnect();
    final replacement = runtime.calls.lastIndexOf('replace');
    expect(runtime.calls.skip(replacement + 1), contains('snapshot'),
        reason: 'decline must read the current host, not reuse the running snapshot');
    expect(manager.snapshot?.phase, RuntimePhase.configStaged);
    expect(manager.retainsProtection, isFalse);
    expect(manager.materialCandidate?.candidateRef, _candidates[1].candidateRef,
        reason: 'retire the active candidate while preserving the attempted candidate');
    expect(manager.status.phase, ConnectionPhase.actionRequired);

    await manager.connect();
    expect(runtime.calls.where((call) => call == 'replace'), hasLength(1));
    expect(runtime.connectCalls, 2);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.connected);
  });

  test('first activation egress failure retries stage and connect without protected replacement', () async {
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)
      ..supportsCandidates = true..failFirstActivation = true;
    final manager = _manager(runtime, _Bootstrapper(catalog: true),
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);
    await manager.connect();
    while (runtime.connectCalls < 2 || manager.busy) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(runtime.calls.where((call) => call == 'stage'), hasLength(2));
    expect(runtime.connectCalls, 2);
    expect(runtime.handoffCalls, 0);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(runtime.overlappingMutation, isFalse);
  });

  test('failed first activation and exhausted recovery report one terminal attempt', () async {
    final awg = _CachedBootstrapper.alternatives[1];
    final hy2 = _CachedBootstrapper.alternatives[2];
    final profileGate = Completer<void>();
    final reportGate = Completer<void>();
    final bootstrapper = _StatsBootstrapper()
      ..candidates = [awg, hy2]
      ..gate = profileGate
      ..failedReportGate = reportGate;
    final runtime = _Runtime()..supportsCandidates = true..failFirstActivation = true
      ..activationFailureKind = 'core_egress_dns_failed'
      ..profileSource = RuntimeProfileSource(revision: 'old-awg',
          origin: RuntimeProfileSourceOrigin.values.first, protocol: 'awg31')
      ..failedProbeProfiles.add(hy2.candidateRef);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(() {
      if (!profileGate.isCompleted) profileGate.complete();
      if (!reportGate.isCompleted) reportGate.complete();
      manager.dispose();
    });
    final connecting = manager.connect();
    await bootstrapper.entered.future;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    profileGate.complete();
    await connecting;
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (!bootstrapper.actualReports.any((report) => report['runtime_phase'] == 'failed') &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final failed = bootstrapper.actualReports.singleWhere((report) => report['runtime_phase'] == 'failed');
    expect(failed['error_code'], 'CONN-008');
    expect(failed['attempt_number'], 1);
    expect(failed['duration_ms'], greaterThanOrEqualTo(25));
    expect(failed['candidate_ref'], awg.candidateRef);
    expect(failed['native_kind'], 'core_egress_dns_failed',
        reason: 'recovery of the same attempt keeps its own native failure');
    expect((failed['connectivity'] as Map)['staged_protocol'], 'awg31');
    expect(failed['retryable'], isTrue);
    expect(runtime.connectCalls, 1);
    expect(manager.busy, isTrue, reason: 'recovery awaits terminal stats before finishing the attempt');
    reportGate.complete();
    while (manager.busy && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(manager.busy, isFalse);
    bootstrapper.failedReportGate = null;
    await manager.setInterfaceMode(PokrovInterfaceMode.advanced);
    await manager.setPreferredCandidate(hy2.candidateRef);
    await manager.connect();
    final freshFailure = bootstrapper.actualReports.singleWhere((report) =>
        report['runtime_phase'] == 'failed' && report['attempt_number'] == 2);
    expect(freshFailure['error_code'], 'CONN-008');
    expect(freshFailure['failure_kind'], 'candidate_selection_exhausted');
    expect(freshFailure['native_kind'], isNull);
    expect(freshFailure['connectivity'], {'proof_stage': 'unknown'},
        reason: 'a failed pre-stage HY2 probe cannot adopt the old AWG material');
    expect(freshFailure['selected_node_code'], isEmpty);
    expect(runtime.connectCalls, 1);
    expect(bootstrapper.actualReports.singleWhere((report) =>
        report['runtime_phase'] == 'connect_requested' && report['attempt_number'] == 2)
        ['connectivity'], {'proof_stage': 'unknown'});
    expect(manager.snapshot?.lastFailureKind, 'core_egress_dns_failed',
        reason: 'the native evidence is retained, only report attribution changes');
    runtime.failFirstActivation = false;
    runtime.failedProbeProfiles.clear();
    runtime.profileSource = RuntimeProfileSource(revision: 'new-hy2',
        origin: RuntimeProfileSourceOrigin.values.first, protocol: 'hysteria2');
    await manager.refresh();
    expect(bootstrapper.actualReports.where((report) => report['runtime_phase'] == 'failed'), hasLength(2));
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(bootstrapper.actualReports.where((report) => report['runtime_phase'] == 'failed'), hasLength(2));
    expect(bootstrapper.actualReports.where((report) => report['runtime_phase'] == 'connect_requested')
        .map((report) => report['attempt_number']), [1, 2, 3]);
    bootstrapper.actualReports.clear();
    await manager.disconnect();
    await manager.refresh();
    final stopped = bootstrapper.actualReports.lastWhere((report) =>
        report['runtime_phase'] == 'runtime_observed');
    expect((stopped['connectivity'] as Map)['proof_stage'], 'not_running',
        reason: 'the owned Stop response remains valid runtime evidence');
  });

  test('retry after UI restart preserves a guard without in-memory candidate state', () async {
    final runtime = _Runtime()..supportsCandidates = true..phase = RuntimePhase.running
      ..restoredHandoffGuard = true..warpEgressFailure = true..failHandoff = true;
    final manager = _manager(runtime, _Bootstrapper(catalog: true));
    addTearDown(manager.dispose);
    await manager.connect();
    expect(runtime.handoffCalls, 1);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.actionRequired);
  });

  test('healthy catalog reconnect and repair cancellation retain protection until explicit off', () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final bootstrapper = _Bootstrapper(catalog: true);
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    runtime.pendingFirstEgress = true;
    await manager.repair();
    expect(runtime.handoffCalls, 1);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.busy, isFalse);

    bootstrapper.gate = Completer<void>();
    final previousResolutions = bootstrapper.resolutions.length;
    final preparing = manager.reconnect();
    while (bootstrapper.resolutions.length == previousResolutions) {
      await Future<void>.delayed(Duration.zero);
    }
    final cancelledPreparation = manager.cancel();
    expect(runtime.calls, isNot(contains('disconnect')));
    bootstrapper.gate!.complete();
    await Future.wait([preparing, cancelledPreparation]);
    expect(runtime.phase, RuntimePhase.running);
    expect(runtime.handoffCalls, 1);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.busy, isFalse);

    bootstrapper.gate = null;
    runtime.handoffRelease = Completer<void>();
    Future<void> Function()? cancelRepair;
    final replacement = manager.repair(onCancelAvailable: (value) => cancelRepair = value);
    final interruptedRepair = expectLater(replacement, throwsA(isA<ConnectionOperationSuperseded>()));
    while (runtime.handoffCalls == 1) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(cancelRepair, isNotNull);
    final cancellation = cancelRepair!();
    await Future<void>.delayed(Duration.zero);
    expect(runtime.calls, isNot(contains('disconnect')));
    runtime.handoffRelease!.complete();
    await Future.wait([interruptedRepair, cancellation]);
    expect(cancelRepair, isNull);
    expect(runtime.phase, RuntimePhase.running);
    expect(runtime.connectCalls, 1);
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(manager.busy, isFalse);
    await manager.disconnect();
    expect(runtime.calls.where((call) => call == 'disconnect'), hasLength(1));
    expect(runtime.phase, RuntimePhase.configStaged);
  });

  test('location callback retains the running tunnel without catalog capabilities', () async {
    final runtime = _Runtime();
    final manager = _manager(runtime, _Bootstrapper());
    addTearDown(manager.dispose);
    manager.updateLocationsCatalog(ClientLocationsCatalog.fromJson({
      'countries': [
        {'code': 'CH', 'country': 'Switzerland', 'cities': [
          {'code': 'ch', 'city': 'Zurich'},
        ]},
      ],
    }));
    await manager.connect();
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.transportCatalog, isNull);
    expect(manager.snapshot?.transportCapabilities, isNull);

    await manager.setPreferredLocation('ch', 'direct');

    expect(runtime.calls, containsAllInOrder(['invalidate', 'replace']));
    expect(runtime.calls, isNot(contains('disconnect')));
    expect(runtime.calls.where((call) => call == 'stage'), hasLength(1));
    expect(runtime.connectCalls, 1);
    expect(runtime.handoffCalls, 1);
    expect(runtime.stagedProfile, 'ch:profile_0');
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.busy, isFalse);
  });

  for (final ordinaryCatalog in [true, false]) {
    test('location preference uses ${ordinaryCatalog ? 'catalog policy' : 'legacy lab'} transport metadata', () async {
      final current = SmartConnectProfile.tryParse({
        'transport_profile': 'awg31_lab', 'profile_revision': 'current-awg',
        'shortlist': [{'code': 'de'}, {'code': 'us'}],
      })!;
      final bootstrapper = _Bootstrapper(catalog: ordinaryCatalog)..smartConnect = current;
      final runtime = _Runtime()..supportsCandidates = ordinaryCatalog;
      final manager = _manager(runtime, bootstrapper);
      addTearDown(manager.dispose);
      manager.updateLocationsCatalog(ClientLocationsCatalog.fromJson({
        'transport_profile': 'legacy_reality_fallback', 'profile_revision': 'locations-policy',
        'countries': [{'code': 'US', 'country': 'USA', 'cities': [{'code': 'us', 'city': 'New York'}]}],
      }));
      await manager.connect();
      await manager.disconnect();

      await manager.setPreferredLocation('us', 'direct');

      final preference = bootstrapper.nodePreferences.single;
      expect(preference.transportProfile, ordinaryCatalog ? 'legacy_reality_fallback' : 'awg31_lab');
      expect(preference.profileRevision, ordinaryCatalog ? 'locations-policy' : 'current-awg');
      expect(preference.shortlist, same(current.shortlist));
    });
  }

  test('enabled signed transport mode cannot fall through to ordinary catalog profiles', () async {
    final runtime = _Runtime();
    final bootstrapper = _ManifestBootstrapper();
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    await manager.connect();
    expect(bootstrapper.entered.isCompleted, isFalse,
      reason: 'ordinary catalog cannot bypass the required bound ATS runtime');
    expect(runtime.calls, isNot(contains('stage')));
    expect(runtime.connectCalls, 0);
    expect(manager.presentation.isVerified, isFalse);
  });

  test('ordinary VPN tolerates an absent optional catalog and retains RU rules',
      () async {
    final originalStorage = FlutterSecureStoragePlatform.instance;
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    final directory = await Directory.systemTemp.createTemp('pokrov-optional-catalog-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
      FlutterSecureStoragePlatform.instance = originalStorage;
    });
    var catalogRequests = 0;
    var managedApiUnavailable = false;
    var failedManagedRequests = 0;
    var invalidCatalogSignature = false;
    final catalogNow = DateTime.now().toUtc();
    // Alphabetical keys match the existing canonical catalog encoding.
    final signedPayload = {
      'audience': 'production', 'evidence': <Object>[],
      'expires_at': catalogNow.add(const Duration(hours: 1)).toIso8601String(),
      'issued_at': catalogNow.subtract(const Duration(minutes: 1)).toIso8601String(),
      'revision': 1, 'schema_version': 'pokrov-routing-catalog-v1', 'security_revision': 1,
      'services': [<String, Object>{}], 'sources': [<String, Object>{}],
    };
    final catalogDigest = (await Sha256().hash(utf8.encode(jsonEncode(signedPayload))))
        .bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final downloadedRuleSets = <String>{};
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.startsWith('/rule-sets/')) {
          downloadedRuleSets.add(request.uri.pathSegments.last);
          request.response.add([1, 2, 3]);
        } else if (request.uri.path == '/api/client/session/start-trial') {
          request.response.write(jsonEncode({
            'session': {'session_token': 'synthetic-session', 'account_id': 'synthetic-account'},
            'provisioning': {'status': 'ready', 'sync_ok': true},
          }));
        } else if (request.uri.path == '/api/client/profile/managed' && managedApiUnavailable) {
          failedManagedRequests++;
          request.response.statusCode = HttpStatus.serviceUnavailable;
          request.response.write('{"detail":"temporarily unavailable"}');
        } else if (request.uri.path == '/api/client/profile/managed') {
          request.response.write(jsonEncode({
            'profile_revision': 'synthetic-profile', 'config_format': 'singbox-json',
            'transport_profile': 'legacy_reality_fallback', 'transport_kind': 'reality',
            'transport_catalog': {
              'schema_version': 'pokrov-transport-catalog-v1', 'revision': 'synthetic-profile',
              'selected_candidate_ref': 'de:legacy_reality_fallback',
              'candidates': [{
                'candidate_ref': 'de:legacy_reality_fallback', 'profile_ref': 'legacy_reality_fallback',
                'node_code': 'de', 'country_code': 'DE', 'protocol': 'vless',
                'transport': 'tcp', 'protection': 'reality', 'priority': 0,
                'parameters': {'network': 'tcp', 'flow': ''},
                'requirements': {'minimum_client_release': '1.2.0', 'minimum_core_release': null,
                  'platforms': ['windows'],
                  'required_features': ['singbox_reality_v1', 'singbox_tls_v1', 'singbox_utls_v1', 'singbox_vless_v1']},
              }],
            },
            'provisioning': {'status': 'ready', 'sync_ok': true},
            'access': {'access_state': 'paid_unlimited',
              'expiry_at': DateTime.now().toUtc().add(const Duration(days: 2)).toIso8601String()},
            'config_payload': {
              'outbounds': [
                {'type': 'selector', 'tag': 'proxy', 'outbounds': ['test-node'], 'default': 'test-node'},
                {'type': 'vless', 'tag': 'test-node', 'server': 'vpn.example.invalid', 'server_port': 443,
                  'uuid': '11111111-1111-4111-8111-111111111111'},
              ],
              'route': {'final': 'proxy'},
            },
          }));
        } else if (request.uri.path == '/api/client/routing-catalog') {
          catalogRequests++;
          if (invalidCatalogSignature) {
            request.response.write(jsonEncode({
              'schema': 'routing-catalog-response-v1',
              'envelope': {'algorithm': 'Ed25519', 'key_id': 'synthetic',
                'payload_sha256': catalogDigest, 'payload': signedPayload,
                'signature_b64': 'invalid'},
            }));
          } else {
            request.response.statusCode = HttpStatus.serviceUnavailable;
            request.response.headers.set('X-POKROV-Error', 'routing_catalog_disabled');
            request.response.write('{"detail":"routing_catalog_disabled"}');
          }
        } else {
          request.response.write('{"ok":true}');
        }
        await request.response.close();
      }
    }());
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}',
      supportDirectoryResolver: () async => directory,
      routingCatalogStore: RoutingCatalogStore(enabled: true,
        verifier: RoutingCatalogVerifier(publicKeysById: {'synthetic': base64Encode(List.filled(32, 1))},
          audience: 'production')),
      allExceptRuRuleSetUrlsResolver: (tag) => ['http://127.0.0.1:${server.port}/rule-sets/$tag.srs'],
      maxRequestAttempts: 1,
    );
    final runtime = _Runtime(hostPlatform: HostPlatform.windows)..supportsCandidates = true;
    final manager = _manager(runtime, bootstrapper,
        authorizeWindows: () async => PokrovWindowsTunnelAuthorization.allowed);
    addTearDown(manager.dispose);
    manager.selectRouteMode(RouteMode.allExceptRu);
    final phases = <ConnectionPhase>[];
    manager.addListener(() => phases.add(manager.status.phase));
    await manager.connect();
    expect(
        phases,
        containsAllInOrder([
          ConnectionPhase.preparing,
          ConnectionPhase.activating,
          ConnectionPhase.connected
        ]));
    expect(manager.presentation.isVerified, isTrue);
    expect(manager.status.routes.ipv4, isNull);
    expect(manager.status.routes.ipv6, isNull);
    expect(manager.status.dns.ready, isTrue);
    expect(manager.status.egress.validated, isTrue);
    expect(catalogRequests, greaterThan(0));
    expect(runtime.probedProtocols, ['vless']);
    final config = jsonDecode(runtime.stagedPayloads.single.configPayload) as Map;
    final route = config['route'] as Map;
    final ruleSets = (route['rule_set'] as List).cast<Map>();
    final rules = (route['rules'] as List).cast<Map>();
    const ruTags = {'pokrov-ru-domain-whitelist', 'pokrov-ru-domain-category',
      'pokrov-ru-ip-country', 'pokrov-ru-ip-whitelist'};
    expect(ruleSets.map((rule) => rule['tag']).toSet(), containsAll(ruTags));
    expect(downloadedRuleSets, containsAll(ruTags.map((tag) => '$tag.srs')));
    for (final tag in ruTags) {
      expect(rules.any((rule) => rule['outbound'] == 'direct' &&
          ((rule['rule_set'] as List?)?.contains(tag) ?? false)), isTrue);
    }
    expect(route['final'], isNot('direct'));
    await manager.disconnect();
    expect(manager.status.phase, ConnectionPhase.disconnected);
    expect(manager.busy, isFalse);
    final catalogRequestsBeforeCache = catalogRequests;
    managedApiUnavailable = true;
    await manager.connect();
    expect(failedManagedRequests, greaterThan(0), reason: 'online refresh failed before cached preparation');
    expect(catalogRequests, catalogRequestsBeforeCache, reason: 'the quick path reads the absent catalog cache only');
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(manager.presentation.isVerified, isTrue);
    expect(runtime.connectCalls, 2);
    expect(jsonDecode(runtime.stagedPayloads.last.configPayload), config,
      reason: 'authorized cached VPN material and all four RU direct rules are retained');
    await manager.disconnect();
    managedApiUnavailable = false;
    invalidCatalogSignature = true;
    await manager.connect();
    expect(catalogRequests, greaterThan(catalogRequestsBeforeCache));
    expect(manager.status.phase, ConnectionPhase.actionRequired);
    expect(manager.presentation.isVerified, isFalse);
    expect(runtime.connectCalls, 2, reason: 'signature failure cannot fall through to the VPN cache');
  });

  test('new command cancels profile work and ignores its late result',
      () async {
    final runtime = _Runtime()..supportsCandidates = true;
    final bootstrapper = _CachedBootstrapper()
      ..cacheAvailable = false
      ..gate = Completer<void>();
    final manager = _manager(runtime, bootstrapper);
    addTearDown(manager.dispose);
    final first = manager.connect();
    await bootstrapper.entered.future;
    expect(bootstrapper.lastProfileTimeout, const Duration(seconds: 40));
    final disconnect = manager.disconnect();
    await Future<void>.delayed(Duration.zero);
    expect(bootstrapper.cancelled, isTrue);
    bootstrapper.gate!.complete();
    await Future.wait([first, disconnect]);
    expect(runtime.calls, isNot(contains('stage')));
    expect(runtime.connectCalls, 0);
    expect(manager.attemptId, 2);
    expect(manager.busy, isFalse);
    const pendingMessage = 'Доступ ещё готовится. Нажмите «Подключить», чтобы повторить попытку.';
    bootstrapper.failure = const BootstrapFailure(pendingMessage,
        code: 'access_preparing', operationalCode: 'API-011');
    await manager.connect();
    expect(manager.headline, pendingMessage);
    expect(runtime.calls, isNot(contains('stage')));
    expect(runtime.connectCalls, 0);
    bootstrapper.cacheAvailable = true;
    await manager.connect();
    expect(bootstrapper.lastProfileTimeout, const Duration(seconds: 3));
    expect(manager.status.phase, ConnectionPhase.connected);
    expect(runtime.connectCalls, 1);
  });

  testWidgets('replacement joins initialize and keeps one native owner', (tester) async {
    final coldRuntime = _Runtime(heldOperation: 'initialize');
    final coldExperience = _ExperienceStore();
    final coldManager = _manager(coldRuntime, _Bootstrapper(), experienceStore: coldExperience);
    final coldConnect = coldManager.connect();
    await tester.pump();
    expect(coldRuntime.operationEntered.isCompleted, isTrue);
    await tester.pump(const Duration(seconds: 20));
    expect(coldManager.busy, isTrue);
    expect(coldManager.status.phase, isNot(ConnectionPhase.actionRequired));
    expect(coldRuntime.calls, isNot(contains('stage')));
    coldRuntime.releaseOperation.complete();
    await tester.pump();
    await coldConnect;
    expect(coldManager.status.phase, ConnectionPhase.connected,
        reason: coldExperience.saved.protectionEvents
            .where((event) => event.kind.startsWith('connect_unexpected_'))
            .map((event) => event.detail).join('; '));
    expect(coldManager.presentation.isVerified, isTrue);
    expect(coldRuntime.connectCalls, 1);
    coldManager.dispose();

    final runtime = _Runtime(heldOperation: 'initialize');
    final manager = _manager(runtime, _Bootstrapper());
    final first = manager.connect();
    await tester.pump();
    expect(runtime.operationEntered.isCompleted, isTrue);
    await tester.pump(const Duration(seconds: 20));
    final cancellation = manager.cancel();
    final replacement = manager.connect();
    final replacementId = manager.attemptId;
    await tester.pump();
    expect(runtime.overlappingMutation, isFalse);
    expect(runtime.calls, isNot(contains('stage')));
    expect(runtime.connectCalls, 0);
    runtime.releaseOperation.complete();
    await tester.pump();
    await Future.wait([first, cancellation, replacement]);
    expect(runtime.overlappingMutation, isFalse);
    expect(manager.attemptId, replacementId);
    expect(manager.presentation.isVerified, isTrue);
    expect(manager.busy, isFalse);
    expect(runtime.calls.where((call) => call == 'stage'), hasLength(1));
    expect(runtime.connectCalls, 1);
    manager.dispose();
  });

  for (final operation in ['stage', 'connect']) {
    test('replacement joins $operation and keeps one native owner', () async {
      final runtime = _Runtime(heldOperation: operation);
      if (operation == 'connect') runtime.releaseStopRead = Completer<void>();
      final manager = _manager(runtime, _Bootstrapper());
      addTearDown(manager.dispose);
      final first = manager.connect();
      await runtime.operationEntered.future;
      final cancellation = manager.cancel();
      final replacement = manager.connect();
      final replacementId = manager.attemptId;
      await Future<void>.delayed(Duration.zero);
      expect(runtime.overlappingMutation, isFalse);
      runtime.releaseOperation.complete();
      if (operation == 'connect') {
        await runtime.stopReadEntered.future;
        expect(runtime.connectCalls, 1,
            reason: 'replacement must wait for stopped readback');
        expect(manager.busy, isTrue);
        runtime.releaseStopRead!.complete();
      }
      await Future.wait([first, cancellation, replacement]);
      expect(runtime.overlappingMutation, isFalse);
      expect(manager.attemptId, replacementId);
      expect(manager.presentation.isVerified, isTrue);
      expect(manager.busy, isFalse);
      if (operation == 'connect') {
        expect(runtime.cancelled, contains('request-1'));
        expect(runtime.connectCalls, 2);
      }
    });
  }

  test('disconnect supersedes a pending Windows authorization', () async {
    final entered = Completer<void>();
    final authorization = Completer<PokrovWindowsTunnelAuthorization>();
    final runtime = _Runtime(hostPlatform: HostPlatform.windows);
    final manager = _manager(runtime, _Bootstrapper(), authorizeWindows: () {
      entered.complete();
      return authorization.future;
    });
    addTearDown(manager.dispose);
    final first = manager.connect();
    await entered.future;
    final disconnect = manager.disconnect();
    authorization.complete(PokrovWindowsTunnelAuthorization.allowed);
    await Future.wait([first, disconnect]);
    expect(runtime.connectCalls, 0);
    expect(manager.busy, isFalse);
  });

  test(
      'cancel joins post-connect WARP fallback and confirms the tunnel stopped',
      () async {
    final runtime = _Runtime(heldOperation: 'warp')
      ..pendingFirstEgress = true
      ..warpEgressFailure = true;
    final manager = _manager(runtime, _Bootstrapper(warpEnabled: true));
    addTearDown(manager.dispose);
    await manager.connect();
    await runtime.operationEntered.future;
    final cancellation = manager.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(runtime.calls, isNot(contains('disconnect')),
        reason: 'native WARP profile mutation must settle before stop');
    runtime.releaseOperation.complete();
    await cancellation;
    expect(runtime.calls, contains('disconnect'));
    expect(runtime.connectCalls, 1,
        reason: 'cancelled fallback must not reconnect');
    expect(runtime.overlappingMutation, isFalse);
    expect(manager.snapshot?.phase, isNot(RuntimePhase.running));
    expect(manager.status.phase, ConnectionPhase.disconnected);
    expect(manager.busy, isFalse);
  });
}
