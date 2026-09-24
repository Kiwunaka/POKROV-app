part of '../../../app_first_runtime_bootstrap.dart';

typedef TransportSmartAccessGrantResolver = Future<CatalogDomainPolicy> Function(
  String baseProfile, Future<Duration> Function() remainingBudget,
  bool Function() operationIsCurrent, Future<void> cancelled);

/// Local capture shared by query admission and materialization. References are
/// random correlation handles, never hashes of apps, DNS addresses or Wi-Fi.
class TransportRoutingIntent {
  factory TransportRoutingIntent.capture({required PokrovRoutingPreferences preferences,
       required List<String> selectedApps, required RouteMode mode, required HostPlatform platform,
       required bool Function() configurationIsCurrent, CatalogDomainPolicy? catalogPolicy,
       String? catalogAccessState, TransportSmartAccessGrantResolver? smartAccessGrantResolver}) {
    if (!configurationIsCurrent() ||
        (catalogPolicy == null && catalogAccessState != null) ||
        (catalogPolicy != null && (catalogPolicy.platform != platform.name ||
          catalogPolicy.accessState != catalogAccessState))) {
      throw const TransportManifestFailure('transport_routing_intent_superseded');
    }
    final random = Random.secure();
    String ref(String prefix) => '${prefix}_${List.generate(16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    return TransportRoutingIntent._(
      PokrovRoutingPreferences.fromJson(Map<String, dynamic>.from(preferences.toJson())),
      List<String>.unmodifiable(selectedApps), mode, platform, catalogPolicy, catalogAccessState,
      ref('route'), ref('dns'), configurationIsCurrent, smartAccessGrantResolver);
  }

  const TransportRoutingIntent._(this.preferences, this.selectedApps, this.mode, this.platform,
    this.catalogPolicy, this.catalogAccessState, this.routePolicyRef, this.dnsPolicyRef,
    this._configurationIsCurrent, this.smartAccessGrantResolver);
  final PokrovRoutingPreferences preferences;
  final List<String> selectedApps;
  final RouteMode mode;
  final HostPlatform platform;
  final CatalogDomainPolicy? catalogPolicy;
  final String? catalogAccessState;
  final String routePolicyRef, dnsPolicyRef;
  final bool Function() _configurationIsCurrent;
  final TransportSmartAccessGrantResolver? smartAccessGrantResolver;

  void requireCurrent([TransportTimeWindow? now, CatalogDomainPolicy? preparedCatalog]) {
    if (!_configurationIsCurrent()) {
      throw const TransportManifestFailure('transport_routing_intent_superseded');
    }
    final catalog = preparedCatalog ?? catalogPolicy;
    if (now != null && catalog != null &&
        (now.earliest.isBefore(catalog.issuedAt) || !now.latest.isBefore(catalog.expiresAt))) {
      throw const TransportManifestFailure('transport_routing_catalog_expired');
    }
    if (now != null && catalog != null) {
      final grants = catalog.smartAccessProfile?.byService.values.expand((group) => group);
      if (grants != null && grants.any((grant) =>
          !grant.admitsNewFlows(now.earliest) || !grant.admitsNewFlows(now.latest))) {
        throw const TransportManifestFailure('transport_routing_grant_expired');
      }
    }
  }

  @override
  String toString() => 'TransportRoutingIntent(redacted)';
}

/// Exact output of the existing TUN/routing assembler, tied to its authorized
/// input. Native Core materialization still produces a separate stage digest.
class PreparedTransportProfile {
  const PreparedTransportProfile._(this.resolved, this.payload, this.routingIntent,
    this.catalogPolicy, this._isCurrent);
  final AuthenticatedTransportProfile resolved;
  final ManagedProfilePayload payload;
  final TransportRoutingIntent routingIntent;
  final CatalogDomainPolicy? catalogPolicy;
  final bool Function() _isCurrent;

  void requireCurrent(TransportManifestSelection selection, TransportTimeWindow now) {
    if (!_isCurrent()) throw const TransportManifestFailure('transport_profile_preparation_superseded');
    routingIntent.requireCurrent(now, catalogPolicy);
    resolved.requireCurrent(selection, now);
  }

  @override
  String toString() => 'PreparedTransportProfile(redacted)';
}

String _transportLeaseTime(DateTime value) {
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}T'
    '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
}

ManagedProfilePayload _bindTransportLease(ManagedProfilePayload payload, TransportResolvedProfile grant,
    String family) {
  // The issuer supplies one VLESS tag. Rename only that upstream after the
  // existing route/DNS assembler has finished, so every original route to
  // pokrov-ats now enters the lease gate and no alternate proxy is introduced.
  final decoded = jsonDecode(payload.configPayload);
  if (decoded is! Map<String, dynamic>) {
    throw const TransportManifestFailure('transport_lease_config_invalid');
  }
  final outbounds = decoded['outbounds'];
  if (outbounds is! List || outbounds.any((item) => item is! Map<String, dynamic>)) {
    throw const TransportManifestFailure('transport_lease_config_invalid');
  }
  bool referencesUpstreamTag(Object? value) {
    if (value == 'pokrov-ats-upstream') return true;
    if (value is Map) return value.values.any(referencesUpstreamTag);
    if (value is List) return value.any(referencesUpstreamTag);
    return false;
  }
  // The new tag must not make a previously dangling route or detour a direct
  // path around the lease gate.
  if (referencesUpstreamTag(decoded)) {
    throw const TransportManifestFailure('transport_lease_upstream_invalid');
  }
  final rows = outbounds.cast<Map<String, dynamic>>();
  final upstreams = rows.where((row) => row['tag'] == 'pokrov-ats' && row['type'] == 'vless').toList();
  if (upstreams.length != 1 || rows.where((row) => row['tag'] == 'pokrov-ats').length != 1) {
    throw const TransportManifestFailure('transport_lease_upstream_invalid');
  }
  final upstream = upstreams.single;
  final server = upstream['server'];
  final address = server is String ? InternetAddress.tryParse(server) : null;
  final raw = address?.rawAddress;
  final mappedIpv4 = raw != null && raw.length == 16 &&
      raw.take(10).every((byte) => byte == 0) && raw[10] == 0xff && raw[11] == 0xff;
  if (!const {'ipv4', 'ipv6'}.contains(family) || server is! String || server.isEmpty ||
      mappedIpv4 ||
      (address != null && (address.type == InternetAddressType.IPv4) != (family == 'ipv4'))) {
    throw const TransportManifestFailure('transport_endpoint_family_mismatch');
  }
  if (address == null) {
    final currentResolver = upstream['domain_resolver'];
    final route = decoded['route'];
    final routeResolver = route is Map ? route['default_domain_resolver'] : null;
    final resolver = currentResolver is String ? currentResolver :
      currentResolver is Map ? currentResolver['server'] :
      routeResolver is Map ? routeResolver['server'] : null;
    final dns = decoded['dns'];
    final servers = dns is Map ? dns['servers'] : null;
    if (resolver is! String || resolver.isEmpty || servers is! List ||
        !servers.any((item) => item is Map && item['tag'] == resolver)) {
      throw const TransportManifestFailure('transport_endpoint_resolver_unavailable');
    }
    upstream['domain_resolver'] = {'server': resolver,
      'strategy': family == 'ipv4' ? 'ipv4_only' : 'ipv6_only'};
  }
  upstream['tag'] = 'pokrov-ats-upstream';
  rows.add({
    'type': 'pokrov-ats-lease', 'tag': 'pokrov-ats', 'upstream_tag': 'pokrov-ats-upstream',
    'lease_id': grant.endpointLeaseRef, 'issued_at': _transportLeaseTime(grant.authorizedFrom),
    'new_flows_until': _transportLeaseTime(grant.authorizedUntil),
    'active_flows_until': _transportLeaseTime(grant.activeFlowsUntil),
  });
  decoded['outbounds'] = rows;
  return payload.copyWith(configPayload: jsonEncode(decoded));
}

class _TransportProfilePreparation {
  const _TransportProfilePreparation(this.bootstrapper);
  final AppFirstRuntimeBootstrapper bootstrapper;

  Future<PreparedTransportProfile> prepare({required AuthenticatedTransportProfile resolved,
      required TransportRoutingIntent routingIntent,
      required RuntimeSnapshot runtime, required RuntimeBootClockSnapshot budgetStartedAt,
      required Duration budget, required bool Function() operationIsCurrent,
      required Future<void> cancelled}) async {
    final selection = resolved.selection;
    final query = resolved.profile.query.fields;
    final platform = runtime.hostPlatform;
    if (query['platform'] != platform.name || query['artifact_sha256'] != runtime.coreModuleSha256 ||
        !const {HostPlatform.android, HostPlatform.windows, HostPlatform.linux}.contains(platform)) {
      throw const TransportManifestFailure('transport_profile_runtime_mismatch');
    }
    if (runtime.transportCapabilities?.features.contains(RuntimeTransportFeature.atsLease) != true) {
      throw const TransportManifestFailure('transport_lease_runtime_unavailable');
    }
    routingIntent.requireCurrent();
    if (routingIntent.platform != platform || query['mode'] != routingIntent.mode.name ||
        query['route_policy_ref'] != routingIntent.routePolicyRef ||
        query['dns_policy_ref'] != routingIntent.dnsPolicyRef) {
      throw const TransportManifestFailure('transport_profile_routing_mismatch');
    }
    final mode = routingIntent.mode;
    final captured = routingIntent.preferences;
    var catalogPolicy = routingIntent.catalogPolicy;
    final apps = bootstrapper._normalizeSelectedAppIdentifiers(routingIntent.selectedApps);
    if (bootstrapper._routingCatalogStore.enabled && catalogPolicy == null &&
        const {RouteMode.allExceptRu, RouteMode.selectiveServices}.contains(mode)) {
      throw const RoutingCatalogFailure('catalog_selective_policy_required');
    }
    final deadline = TransportClockDeadline(budgetStartedAt, budget);
    final ended = Completer<void>();
    var ownerCancelled = false;
    void stop() { if (!ended.isCompleted) ended.complete(); }
    void cancelByOwner() { ownerCancelled = true; stop(); }
    unawaited(cancelled.then((_) => cancelByOwner(), onError: (Object _) => cancelByOwner()));
    unawaited(selection.whenClosed.then((_) => stop()));
    final timer = Timer(budget, stop);
    Timer? nativeTimer;
    final requests = _ManagedProfileRequests(ended.future);
    final pending = <Future<void>>[];
    HttpClient? client;
    Future<T> wait<T>(Future<T> value) {
      pending.add(value.then<void>((_) {}, onError: (Object _) {}));
      return Future.any<T>([value, ended.future.then<T>((_) =>
        throw const TransportManifestFailure('transport_profile_preparation_cancelled'))]);
    }
    void current() {
      if (ended.isCompleted || !operationIsCurrent()) {
        throw const TransportManifestFailure('transport_profile_preparation_superseded');
      }
      selection.requireCurrent();
      routingIntent.requireCurrent();
      requests.requireActive();
    }
    Future<TransportTimeWindow> sample() async {
      current();
      final now = await selection.sample();
      current();
      deadline.requireCurrent(now.sample);
      resolved.requireCurrent(selection, now);
      routingIntent.requireCurrent(now);
      return now;
    }
    try {
      final start = await wait(sample());
      nativeTimer = Timer(Duration(milliseconds: deadline.expiresElapsedMs - start.sample.elapsedMilliseconds), stop);
      client = requests.attach(bootstrapper._createHttpClient(platform));
      final ruleSets = await wait(bootstrapper._ensureAllExceptRuRuleSetCatalog(
        hostPlatform: platform, routeMode: mode, client: client));
      await wait(sample());
      final config = await wait(bootstrapper._materializeRuntimeConfig(
        rawConfigPayload: resolved.profile.configPayload, hostPlatform: platform, routeMode: mode,
        selectedApps: apps, preferredNodeCode: '', preferredVariantId: 'direct', smartConnect: null,
        supportContext: const {}, clientRuleSetCatalog: ruleSets));
       await wait(sample());
       final resolveGrants = routingIntent.smartAccessGrantResolver;
       if (mode == RouteMode.selectiveServices && resolveGrants != null) {
         Future<Duration> remainingBudget() async {
           final now = await sample();
           return Duration(milliseconds: deadline.expiresElapsedMs - now.sample.elapsedMilliseconds);
         }
         final grantedPolicy = await wait(resolveGrants(config, remainingBudget,
           () { try { current(); return true; } on Object { return false; } }, ended.future));
         final baseline = routingIntent.catalogPolicy;
         if (baseline == null || grantedPolicy.payloadSha256 != baseline.payloadSha256 ||
             grantedPolicy.mode != baseline.mode || grantedPolicy.platform != baseline.platform ||
             grantedPolicy.accessState != baseline.accessState ||
             grantedPolicy.selectedServiceIds.length != baseline.selectedServiceIds.length ||
             !grantedPolicy.selectedServiceIds.containsAll(baseline.selectedServiceIds)) {
           throw const TransportManifestFailure('transport_routing_catalog_mismatch');
         }
         routingIntent.requireCurrent(await wait(sample()), grantedPolicy);
         catalogPolicy = grantedPolicy;
       }
       final assembled = applyPokrovRoutingPreferences(ManagedProfilePayload(
        profileName: 'pokrov-ats-${resolved.profile.profileRevision}', configPayload: config,
        materializedForRuntime: true, routeMode: mode,
        // ATS uses its scoped verifier stages; the legacy URL probe is outside
        // the admitted probe set and cannot settle bound protection.
        quickSettingsEligible: false, coreEgressProbeRequired: false,
      ), captured, hostPlatform: platform, catalogPolicy: catalogPolicy,
         catalogAccessState: routingIntent.catalogAccessState,
        nativeCatalogWindowVersion: runtime.routingCatalogWindowVersion,
        nativeSmartAccessLeaseVersion: runtime.smartAccessLeaseVersion);
      final payload = _bindTransportLease(assembled, resolved.profile, query['family'] as String);
      final now = await wait(sample());
       final prepared = PreparedTransportProfile._(resolved, payload, routingIntent, catalogPolicy,
        () => !ownerCancelled && operationIsCurrent());
      prepared.requireCurrent(selection, now);
      return prepared;
    } finally {
      timer.cancel();
      nativeTimer?.cancel();
      stop();
      if (client != null) requests.close(client);
      await Future.wait(pending);
    }
  }
}
