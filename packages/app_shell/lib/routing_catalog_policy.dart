import 'dart:io';
import 'dart:convert';

import 'catalog_runtime_identity.dart';
import 'routing_catalog_contract.dart';
import 'smart_access_profile.dart';

enum CatalogRoutingMode { full, smartSafe, selective, includeApps, excludeApps }
enum CatalogRouteAction { vpn, direct, approvedGateway, block }

const _modeNames = {
  'full': CatalogRoutingMode.full,
  'smart_safe': CatalogRoutingMode.smartSafe,
  'selective': CatalogRoutingMode.selective,
  'include_apps': CatalogRoutingMode.includeApps,
  'exclude_apps': CatalogRoutingMode.excludeApps,
};
const _actionNames = {
  'vpn': CatalogRouteAction.vpn,
  'direct': CatalogRouteAction.direct,
  'approved_gateway': CatalogRouteAction.approvedGateway,
  'block': CatalogRouteAction.block,
};
const _platforms = {'android', 'windows', 'linux', 'ios', 'macos'};
const _accessStates = {
  'trial_premium', 'bonus_premium', 'paid_unlimited', 'free_monthly', 'free_soft_mode',
};

class CatalogDomain {
  const CatalogDomain._(this.name, this.suffix, this.role, this.shared);
  final String name;
  final bool suffix;
  final String role;
  final bool shared;

  bool matches(String hostname) =>
      hostname == name || (suffix && hostname.endsWith('.$name'));
}

class CatalogAndroidIdentity {
  const CatalogAndroidIdentity._({
    required this.package, required this.signers, required this.lineage,
    required this.browserOrContainer,
  });
  final String package;
  final Set<String> signers;
  final List<String> lineage;
  final bool browserOrContainer;
}

class CatalogServicePolicy {
  const CatalogServicePolicy._({
    required this.id, required this.displayName, required this.classification,
    required this.enabled, required this.verified, required this.platforms,
    required this.accessStates, required this.categories, required this.intents,
    required this.domains, required this.android,
    required this.providerCapabilityRefs,
  });
  final String id;
  final String displayName;
  final String classification;
  final bool enabled;
  final bool verified;
  final Set<String> platforms;
  final Set<String> accessStates;
  final Set<String> categories;
  final Map<CatalogRoutingMode, CatalogRouteAction> intents;
  final List<CatalogDomain> domains;
  final List<CatalogAndroidIdentity> android;
  final Set<String> providerCapabilityRefs;
}

/// Validated consumer projection of the platform-owned routing_catalog.py v1.
/// Network/Windows identity metadata is checked for references but is not a
/// domain route. In particular, CIDR/ASN never become an implicit app bypass.
class RoutingCatalogPolicy {
  const RoutingCatalogPolicy._(this.catalog, this.services);
  final VerifiedRoutingCatalog catalog;
  final List<CatalogServicePolicy> services;

  factory RoutingCatalogPolicy.fromVerified(VerifiedRoutingCatalog catalog) {
    final sourceIds = <String>{};
    for (final source in _objects(catalog.payload['sources'], 1, 128)) {
      final id = _id(source['source_id']);
      if (!sourceIds.add(id)) _fail('duplicate_source');
      _digest(source['sha256']);
      _text(source['revision'], 128);
      _text(source['license'], 128);
      final rawUrl = _text(source['url'], 512);
      final url = Uri.tryParse(rawUrl);
      if (url == null || url.scheme != 'https' || url.host.isEmpty ||
          url.userInfo.isNotEmpty || url.hasQuery || url.hasFragment ||
          rawUrl.contains('\\') || rawUrl.runes.any((rune) => rune < 33)) {
        _fail('source_url');
      }
      _lifetime(source['retrieved_at'], source['expires_at'], catalog);
    }
    final evidenceOwners = <String, String>{};
    for (final evidence in _objects(catalog.payload['evidence'], 0, 512)) {
      final id = _id(evidence['evidence_id']);
      if (evidenceOwners.containsKey(id)) _fail('duplicate_evidence');
      evidenceOwners[id] = _id(evidence['service_id']);
      _digest(evidence['sha256']);
      _sourceRefs(evidence['source_ids'], sourceIds);
      _lifetime(evidence['observed_at'], evidence['expires_at'], catalog);
      final origin = _choice(evidence['origin'],
        const {'current-origin', 'brain-origin', 'RU-origin', 'synthetic'});
      if (origin == 'synthetic' && catalog.payload['audience'] == 'production') {
        _fail('synthetic_production_evidence');
      }
    }
    final services = <CatalogServicePolicy>[];
    final serviceIds = <String>{};
    for (final value in _objects(catalog.payload['services'], 1, 256)) {
      final id = _id(value['service_id']);
      if (!serviceIds.add(id)) _fail('duplicate_service');
      final platforms = _strings(value['platforms'], 1, 5, allowed: _platforms);
      final access = _strings(value['access_states'], 1, 5, allowed: _accessStates);
      final categories = _ids(value['categories'], 1, 16);
      _text(value['reason'], 500);
      _sourceRefs(value['source_ids'], sourceIds);
      final evidence = _evidenceRefs(value['evidence_ids'], evidenceOwners, id, 0, 32);
      final enabled = _boolean(value['enabled']);
      final verified = _choice(value['evidence_status'], const {'source_only', 'verified'}) == 'verified';
      if (verified && evidence.isEmpty) _fail('verified_evidence_missing');
      final classification = _choice(value['classification'],
        const {'unknown', 'ru_only', 'blocked_inside_ru', 'geo_restricted', 'ordinary'});
      final external = _choice(value['external_gateway_policy'], const {'forbidden', 'approved'});
      final providers = _ids(value['provider_capability_refs'], 0, 16);
      final intents = <CatalogRoutingMode, CatalogRouteAction>{};
      for (final intent in _objects(value['route_intents'], 0, 5)) {
        final mode = _modeNames[intent['mode']];
        final action = _actionNames[intent['action']];
        if (mode == null || action == null || intents.containsKey(mode)) _fail('route_intent');
        if (!enabled || !verified) _fail('unverified_route_authority');
        if (mode == CatalogRoutingMode.full &&
            action != CatalogRouteAction.vpn && action != CatalogRouteAction.block) _fail('full_coverage');
        if (action == CatalogRouteAction.approvedGateway &&
            (mode != CatalogRoutingMode.selective || external != 'approved' || providers.isEmpty)) {
          _fail('gateway_authority');
        }
        if (action == CatalogRouteAction.direct && classification == 'blocked_inside_ru') {
          _fail('blocked_service_direct');
        }
        intents[mode] = action;
      }
      final domains = <CatalogDomain>[];
      final domainKeys = <String>{};
      for (final domain in _objects(value['domains'], 0, 256)) {
        final name = _domain(domain['name']);
        final suffix = _choice(domain['match'], const {'exact', 'suffix'}) == 'suffix';
        final shared = _boolean(domain['shared']);
        if (!domainKeys.add('$suffix:$name') || (shared && suffix)) _fail('domain_scope');
        _sourceRefs(domain['source_ids'], sourceIds);
        final role = _choice(domain['role'], const {'auth', 'api', 'cdn', 'media', 'web'});
        if (intents.containsValue(CatalogRouteAction.approvedGateway) &&
            (name == 'pokrov.space' || name.endsWith('.pokrov.space'))) _fail('gateway_pokrov');
        domains.add(CatalogDomain._(name, suffix, role, shared));
      }
      final android = <CatalogAndroidIdentity>[];
      final packages = <String>{};
      for (final app in _objects(value['android'], 0, 16)) {
        final package = _text(app['package'], 255);
        if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$').hasMatch(package) ||
            !packages.add(package) || !platforms.contains('android')) _fail('android_identity');
        final signers = _digests(app['signer_sha256'], 1, 8);
        final lineage = _digests(app['signing_lineage_sha256'], 0, 16);
        if (lineage.isNotEmpty && (signers.length != 1 || lineage.last != signers.single)) {
          _fail('android_lineage');
        }
        if (!sourceIds.contains(_id(app['store_source_id']))) _fail('unknown_source');
        _evidenceRefs(app['evidence_ids'], evidenceOwners, id, 1, 16);
        final browser = _boolean(app['browser_or_container']);
        if (browser && intents.containsValue(CatalogRouteAction.direct)) _fail('browser_auto_direct');
        android.add(CatalogAndroidIdentity._(package: package,
          signers: Set.unmodifiable(signers), lineage: List.unmodifiable(lineage),
          browserOrContainer: browser));
      }
      final windowsIdentities = <String>{};
      for (final app in _objects(value['windows'], 0, 16)) {
        if (!platforms.contains('windows')) _fail('windows_platform');
        final policy = _choice(app['policy'], const {'user_selected_path', 'signed_publisher', 'package_family'});
        final identity = app['value'];
        if (policy == 'user_selected_path') {
          if (identity != null) _fail('windows_path_not_public');
        } else {
          _text(identity, 512);
        }
        if (!windowsIdentities.add('$policy:$identity')) _fail('duplicate_windows_identity');
        _evidenceRefs(app['evidence_ids'], evidenceOwners, id, 1, 16);
      }
      final networks = <String>{};
      for (final network in _objects(value['networks'], 0, 128)) {
        final cidr = _text(network['cidr'], 49);
        if (!networks.add(cidr)) _fail('duplicate_network');
        _boolean(network['shared']);
        _sourceRefs(network['source_ids'], sourceIds);
        // Deliberately no projection to a route. The platform owns CIDR/ASN
        // normalization; service/domain scope cannot authorize an entire ASN.
      }
      services.add(CatalogServicePolicy._(
        providerCapabilityRefs: Set.unmodifiable(providers),
        id: id, displayName: _text(value['display_name'], 100), classification: classification,
        enabled: enabled, verified: verified, platforms: Set.unmodifiable(platforms),
        accessStates: Set.unmodifiable(access), categories: Set.unmodifiable(categories),
        intents: Map.unmodifiable(intents), domains: List.unmodifiable(domains),
        android: List.unmodifiable(android),
      ));
    }
    if (evidenceOwners.values.any((id) => !serviceIds.contains(id))) _fail('unknown_evidence_service');
    services.sort((left, right) => left.id.compareTo(right.id));
    return RoutingCatalogPolicy._(catalog, List.unmodifiable(services));
  }
}

class CatalogDomainDecision {
  const CatalogDomainDecision._(this.serviceId, this.domain, this.action, this.fallbackReason, this.gatewayLeases, this.authorityAction);
  final String serviceId;
  final CatalogDomain domain;
  final CatalogRouteAction action;
  final String? fallbackReason;
  final List<VerifiedSmartAccessLease> gatewayLeases;
  final CatalogRouteAction authorityAction;
}

/// Curated layer only. OS app scope, immutable safety and explicit user rules
/// precede this layer; bounded network rules and the mode default follow it.
class CatalogDomainPolicy {
  const CatalogDomainPolicy._({
    required this.revision, required this.securityRevision, required this.payloadSha256,
    required this.audience,
    required this.issuedAt, required this.expiresAt, required this.mode,
    required this.platform, required this.accessState,
    required this.defaultAction, required this.rules, required this.selectedServiceIds,
    required this.smartAccessProfile,
    required this.vpnAvailable,
  });
  final int revision;
  final String audience;
  final int securityRevision;
  final String payloadSha256;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final CatalogRoutingMode mode;
  final String platform;
  final String accessState;
  final CatalogRouteAction defaultAction;
  final List<CatalogDomainDecision> rules;
  // Explicit service intent survives domain-rule deduplication. Consumers must
  // not infer selection from a shared domain's first retained service ID.
  final Set<String> selectedServiceIds;
  final SmartAccessProfileLeases? smartAccessProfile;
  final bool vpnAvailable;

  CatalogDomainDecision? matchDomain(String hostname, {required DateTime now}) {
    if (now.toUtc().isBefore(issuedAt) || !now.toUtc().isBefore(expiresAt)) _fail('policy_expired');
    final name = _domain(hostname.toLowerCase().replaceFirst(RegExp(r'\.$'), ''));
    for (final rule in rules) {
      if (rule.domain.matches(name)) return rule;
    }
    return null;
  }
}

CatalogDomainPolicy compileCatalogDomainPolicy({
  required RoutingCatalogPolicy policy,
  required CatalogRoutingMode mode,
  required String platform,
  required String accessState,
  required bool vpnAvailable,
  required DateTime now,
  Set<String> selectedServiceIds = const {},
  SmartAccessProfileLeases? smartAccessProfile,
}) {
  final catalog = policy.catalog;
  if (now.toUtc().isBefore(catalog.issuedAt) || !now.toUtc().isBefore(catalog.expiresAt)) _fail('policy_expired');
  if (!_platforms.contains(platform) || !_accessStates.contains(accessState)) _fail('policy_eligibility');
  if (mode != CatalogRoutingMode.selective && selectedServiceIds.isNotEmpty) _fail('service_selection_scope');
  if (mode == CatalogRoutingMode.selective && selectedServiceIds.isEmpty) _fail('service_selection_empty');
  if (smartAccessProfile != null) {
    if (mode != CatalogRoutingMode.selective ||
        smartAccessProfile.byService.keys.any((id) => !selectedServiceIds.contains(id))) _fail('gateway_scope');
    for (final entry in smartAccessProfile.byService.entries) {
      for (final grant in entry.value) {
        final lease = grant.lease;
        if (!grant.admitsNewFlows(now) || lease['catalog_sha256'] != catalog.payloadSha256 ||
            lease['catalog_revision'] != catalog.revision || lease['catalog_security_revision'] != catalog.securityRevision ||
            lease['platform'] != platform || lease['service_id'] != entry.key) _fail('gateway_binding');
      }
    }
  }
  final rules = <CatalogDomainDecision>[];
  final selected = <String>{};
  final decisions = <String, (CatalogRouteAction, String?)>{};
  final usedLeases = <String>{};
  final ruleKeys = <String>{};
  for (final service in policy.services) {
    if (mode == CatalogRoutingMode.selective && !selectedServiceIds.contains(service.id)) continue;
    if (!service.enabled || !service.verified || !service.platforms.contains(platform) ||
        !service.accessStates.contains(accessState)) continue;
    var action = service.intents[mode];
    // An explicitly classified blocked service cannot inherit a broad Direct
    // suffix from another curated service in Smart Safe.
    if (action == null && mode == CatalogRoutingMode.smartSafe && service.classification == 'blocked_inside_ru') {
      action = CatalogRouteAction.vpn;
    }
    if (action == null || service.domains.isEmpty) continue;
    if (mode == CatalogRoutingMode.selective && action == CatalogRouteAction.direct) {
      // Selective access protects the explicitly selected services. A Direct
      // intent cannot satisfy that choice; it belongs to the mode's remainder.
      _fail('selected_service_unsupported');
    }
    for (final domain in service.domains) {
      // A shared hostname is not a service identity. Applying one service's
      // intent to it would affect other tenants, even with exact matching.
      if (domain.shared) _fail('shared_domain_not_routable');
      var domainAction = action;
      String? fallback;
      List<VerifiedSmartAccessLease> gateways = const [];
      if (action == CatalogRouteAction.approvedGateway) {
        final candidates = smartAccessProfile?.byService[service.id] ?? const <VerifiedSmartAccessLease>[];
        final covered = candidates.isNotEmpty && candidates.every((candidate) => (candidate.lease['domains']! as List).any((item) =>
            item is Map && item['name'] == domain.name && item['match'] == (domain.suffix ? 'suffix' : 'exact')));
        if (covered) {
          gateways = candidates;
          usedLeases.add(service.id);
        } else {
          domainAction = vpnAvailable ? CatalogRouteAction.vpn : CatalogRouteAction.block;
          fallback = vpnAvailable ? 'gateway_unavailable_using_vpn' : 'gateway_unavailable_blocked';
        }
      } else if (action == CatalogRouteAction.vpn && !vpnAvailable) {
        domainAction = CatalogRouteAction.block;
        fallback = 'vpn_unavailable_blocked';
      }
      final key = '${domain.suffix}:${domain.name}';
      final decision = (domainAction, gateways.isEmpty ? null : gateways.map((grant) => grant.lease['lease_id']).join(','));
      // Exact overrides suffix at the same name using the ordering below.
      // Only equally specific matchers compete for the same decision slot.
      final existing = decisions[key];
      if (existing != null && existing != decision) _fail('domain_conflict');
      decisions[key] = decision;
      if (!ruleKeys.add(key)) continue;
      rules.add(CatalogDomainDecision._(service.id, domain, domainAction, fallback, gateways, action));
    }
    selected.add(service.id);
  }
  if (selectedServiceIds.any((id) => !selected.contains(id))) _fail('selected_service_unsupported');
  if (smartAccessProfile != null && smartAccessProfile.byService.keys.any((id) => !usedLeases.contains(id))) {
    _fail('gateway_service_not_eligible');
  }
  rules.sort((left, right) {
    final specificity = right.domain.name.split('.').length.compareTo(left.domain.name.split('.').length);
    if (specificity != 0) return specificity;
    final exactFirst = (left.domain.suffix ? 1 : 0).compareTo(right.domain.suffix ? 1 : 0);
    if (exactFirst != 0) return exactFirst;
    final name = left.domain.name.compareTo(right.domain.name);
    return name != 0 ? name : left.serviceId.compareTo(right.serviceId);
  });
  return CatalogDomainPolicy._(
    audience: catalog.payload['audience']! as String,
    revision: catalog.revision, securityRevision: catalog.securityRevision,
    payloadSha256: catalog.payloadSha256, issuedAt: catalog.issuedAt,
    expiresAt: catalog.expiresAt, mode: mode, platform: platform, accessState: accessState,
    defaultAction: mode == CatalogRoutingMode.selective ? CatalogRouteAction.direct
        : vpnAvailable ? CatalogRouteAction.vpn : CatalogRouteAction.block,
    rules: List.unmodifiable(rules),
    selectedServiceIds: Set.unmodifiable(selectedServiceIds),
    smartAccessProfile: smartAccessProfile,
    vpnAvailable: vpnAvailable,
  );
}

Never _fail(String code) => throw RoutingCatalogFailure('catalog_$code');

Future<String> _runtimeRuleDigest(String serviceId, CatalogDomain domain, CatalogRouteAction action) =>
    smartAccessProfileSha256(jsonEncode([serviceId, domain.name, domain.suffix, action.name]));

Future<CatalogRuntimeIdentity> catalogRuntimeIdentity(CatalogDomainPolicy policy) async {
  final rules = <String, Set<String>>{};
  final capabilities = <String, Set<String>>{};
  for (final rule in policy.rules) {
    if (rule.action == CatalogRouteAction.block) continue;
    (rules[rule.serviceId] ??= {}).add(await _runtimeRuleDigest(rule.serviceId, rule.domain, rule.authorityAction));
    for (final grant in rule.gatewayLeases) {
      final capability = grant.lease['capability_id'];
      if (capability is String) (capabilities[rule.serviceId] ??= {}).add(capability);
    }
  }
  return CatalogRuntimeIdentity.fromStored({
    'revision': policy.revision, 'security_revision': policy.securityRevision, 'audience': policy.audience,
    'platform': policy.platform, 'mode': policy.mode.name, 'access_state': policy.accessState,
    'services': {for (final entry in rules.entries) entry.key: {
      'rules': entry.value.toList(), 'capabilities': capabilities[entry.key]?.toList() ?? <String>[]}}
  });
}

/// A complete signed replacement may tighten an existing service. Additional
/// domains, display/evidence metadata and TTL renewal do not withdraw old scope.
Future<Set<String>> catalogRuntimeRevocations(CatalogRuntimeIdentity previous,
    String previousSha256, RoutingCatalogPolicy replacement, DateTime now) async {
  final catalog = replacement.catalog;
  if (now.toUtc().isBefore(catalog.issuedAt) || !now.toUtc().isBefore(catalog.expiresAt) ||
      catalog.payload['audience'] != previous.audience || catalog.revision < previous.revision ||
      catalog.securityRevision < previous.securityRevision) _fail('replacement_not_current');
  if (catalog.payloadSha256 == previousSha256) return const {};
  if (catalog.revision == previous.revision) _fail('replacement_not_current');
  final mode = CatalogRoutingMode.values.byName(previous.mode);
  final services = {for (final service in replacement.services) service.id: service};
  final revoked = <String>{};
  for (final entry in previous.services.entries) {
    final service = services[entry.key];
    if (service == null || !service.enabled || !service.verified ||
        !service.platforms.contains(previous.platform) || !service.accessStates.contains(previous.accessState)) {
      revoked.add(entry.key);
      continue;
    }
    var action = service.intents[mode];
    if (action == null && mode == CatalogRoutingMode.smartSafe && service.classification == 'blocked_inside_ru') {
      action = CatalogRouteAction.vpn;
    }
    final allowed = <String>{};
    if (action != null) {
      for (final domain in service.domains) {
        if (!domain.shared) allowed.add(await _runtimeRuleDigest(service.id, domain, action));
      }
    }
    if (!allowed.containsAll(entry.value.rules)) revoked.add(entry.key);
  }
  return Set.unmodifiable(revoked);
}

List<Map<String, Object?>> _objects(Object? value, int minimum, int maximum) {
  if (value is! List || value.length < minimum || value.length > maximum ||
      value.any((item) => item is! Map<String, Object?>)) _fail('projection_shape');
  return value.cast<Map<String, Object?>>();
}

String _text(Object? value, int maximum) {
  if (value is! String || value.isEmpty || value.runes.length > maximum) _fail('projection_text');
  return value;
}

String _id(Object? value) {
  final text = _text(value, 64);
  if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(text)) _fail('projection_id');
  return text;
}

bool _boolean(Object? value) {
  if (value is! bool) _fail('projection_boolean');
  return value;
}

String _choice(Object? value, Set<String> allowed) {
  if (value is! String || !allowed.contains(value)) _fail('projection_enum');
  return value;
}

List<String> _strings(Object? value, int minimum, int maximum, {Set<String>? allowed}) {
  if (value is! List || value.length < minimum || value.length > maximum ||
      value.any((item) => item is! String) || value.toSet().length != value.length) _fail('projection_set');
  final values = value.cast<String>();
  if (allowed != null && values.any((item) => !allowed.contains(item))) _fail('projection_enum');
  return values;
}

List<String> _ids(Object? value, int minimum, int maximum) =>
    _strings(value, minimum, maximum).map(_id).toList(growable: false);

String _digest(Object? value) {
  final text = _text(value, 64);
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(text) || text.split('').toSet().length == 1) _fail('projection_digest');
  return text;
}

List<String> _digests(Object? value, int minimum, int maximum) =>
    _strings(value, minimum, maximum).map(_digest).toList(growable: false);

void _sourceRefs(Object? value, Set<String> known) {
  if (_ids(value, 1, 16).any((id) => !known.contains(id))) _fail('unknown_source');
}

List<String> _evidenceRefs(Object? value, Map<String, String> owners, String serviceId, int minimum, int maximum) {
  final refs = _ids(value, minimum, maximum);
  if (refs.any((id) => owners[id] != serviceId)) _fail('evidence_service_mismatch');
  return refs;
}

DateTime _utc(Object? value) {
  final text = _text(value, 20);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$').hasMatch(text)) _fail('projection_time');
  final parsed = DateTime.tryParse(text);
  if (parsed == null || parsed.year < 1 ||
      parsed.toIso8601String() != text.replaceFirst('Z', '.000Z')) _fail('projection_time');
  return parsed;
}

void _lifetime(Object? start, Object? end, VerifiedRoutingCatalog catalog) {
  final observed = _utc(start);
  final expiry = _utc(end);
  if (!expiry.isAfter(observed) || observed.isAfter(catalog.issuedAt) || expiry.isBefore(catalog.expiresAt)) {
    _fail('projection_lifetime');
  }
}

String _domain(Object? value) {
  final name = _text(value, 253);
  if (!name.contains('.') || InternetAddress.tryParse(name) != null ||
      name.split('.').any((label) => !RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(label))) {
    _fail('projection_domain');
  }
  return name;
}
