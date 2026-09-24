import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'routing_catalog_contract.dart';
import 'catalog_runtime_identity.dart';

/// Hash exact UTF-8 bytes. Grant callers use the materialized base profile;
/// runtime restriction callers use the final host request, including rules.
/// These distinct bindings must not be substituted for one another.
Future<String> smartAccessProfileSha256(String profile) async =>
    (await Sha256().hash(utf8.encode(profile))).bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

class SmartAccessProfileLeases {
  SmartAccessProfileLeases._(this._baseProfile, this.profileSha256, this.byService);
  final String _baseProfile;
  final String profileSha256;
  final Map<String, List<VerifiedSmartAccessLease>> byService;

  bool matchesProfile(String profile) => profile == _baseProfile;

  static Future<SmartAccessProfileLeases> bind({
    required String baseProfile,
    required Iterable<VerifiedSmartAccessLease> leases,
  }) async {
    final accepted = List<VerifiedSmartAccessLease>.of(leases);
    if (accepted.isEmpty || accepted.length > 256) _invalid();
    final digest = await smartAccessProfileSha256(baseProfile);
    final services = <String, List<VerifiedSmartAccessLease>>{};
    final ids = <String>{};
    for (final grant in accepted) {
      final service = grant.lease['service_id'];
      if (grant.grant['profile_sha256'] != digest || grant.grant['route_mode'] != 'selective' ||
          service is! String ||
          !ids.add(grant.lease['lease_id']! as String)) _invalid();
      _validateNativeEndpoints(grant);
      final group = services.putIfAbsent(service, () => []);
      if (group.length >= 16 || group.any((member) => member.lease['provider_id'] == grant.lease['provider_id'])) _invalid();
      if (group.isNotEmpty) {
        final first = group.first;
        if (const ['platform', 'audience', 'origin', 'family', 'feature', 'transport', 'catalog_sha256'].any((field) =>
            first.lease[field] != grant.lease[field]) || !_sameGatewayDomains(first.lease['domains'], grant.lease['domains'])) _invalid();
      }
      group.add(grant);
    }
    return SmartAccessProfileLeases._(baseProfile, digest,
      Map.unmodifiable({for (final entry in services.entries) entry.key: List<VerifiedSmartAccessLease>.unmodifiable(entry.value)}));
  }
}

/// A stage acknowledgement binds these grants to the host's final profile
/// digest. It does not by itself prove that this profile is running.
class SmartAccessRuntimeLeases {
  SmartAccessRuntimeLeases(this.profileDigest, Iterable<SmartAccessLeaseIdentity> leases,
      {this.catalogIssuedAt, this.catalogExpiresAt, this.catalogSha256, this.catalogIdentity,
      Iterable<VerifiedSmartAccessLease> verifiedGrants = const []})
      : leases = List.unmodifiable(leases), verifiedGrants = List.unmodifiable(verifiedGrants);
  final String profileDigest;
  final List<SmartAccessLeaseIdentity> leases;
  // Memory only, supplied by the successful stage/renewal path. Restriction
  // storage never reconstructs these objects or serializes their private scope.
  final List<VerifiedSmartAccessLease> verifiedGrants;
  final DateTime? catalogIssuedAt;
  final DateTime? catalogExpiresAt;
  final String? catalogSha256;
  final CatalogRuntimeIdentity? catalogIdentity;
  bool get hasRestrictionMetadata => catalogExpiresAt != null || leases.isNotEmpty;
  bool hasLiveAuthority(DateTime now) =>
      (catalogExpiresAt != null && now.isBefore(catalogExpiresAt!)) ||
      leases.any((lease) => now.isBefore(lease.activeFlowsUntil));
}

/// A pending renewal is not a native acknowledgement. Its old and new identities
/// must be retained before dispatch; retries use this same fresh signed grant.
class SmartAccessLeaseRenewal {
  SmartAccessLeaseRenewal._(this.binding, this.previous, this.next, Set<String> currentLeaseIds)
      : currentLeaseIds = Set.unmodifiable(currentLeaseIds);
  final SmartAccessRuntimeLeases binding;
  final SmartAccessLeaseIdentity previous;
  final VerifiedSmartAccessLease next;
  final Set<String> currentLeaseIds;
  String get previousLeaseId => previous.lease['lease_id']! as String;
  String get nextLeaseId => next.lease['lease_id']! as String;

  factory SmartAccessLeaseRenewal.prepare({required SmartAccessRuntimeLeases binding,
    required String previousLeaseId, required VerifiedSmartAccessLease next, required DateTime now,
    required Set<String> currentLeaseIds}) {
    final matches = binding.leases.where((grant) => grant.leaseId == previousLeaseId).toList();
    if (matches.length != 1 || !RegExp(r'^[a-f0-9]{64}$').hasMatch(binding.profileDigest) ||
        !currentLeaseIds.contains(previousLeaseId) ||
        binding.catalogIssuedAt == null || binding.catalogExpiresAt == null || binding.catalogIdentity == null) {
      throw const RoutingCatalogFailure('smart_access_renewal_binding_missing');
    }
    final previous = matches.single;
    if (next.lease['lease_id'] == previousLeaseId || binding.leases.any((stored) => stored.leaseId == next.lease['lease_id']) ||
        !previous.acceptsRenewalScope(next) || !next.admitsNewFlows(now) ||
        now.toUtc().isBefore(binding.catalogIssuedAt!) || !now.toUtc().isBefore(binding.catalogExpiresAt!) ||
        next.issuedAt.isBefore(previous.issuedAt) || !next.newFlowsUntil.isAfter(previous.newFlowsUntil) ||
        next.newFlowsUntil.isAfter(binding.catalogExpiresAt!)) {
      throw const RoutingCatalogFailure('smart_access_renewal_scope_mismatch');
    }
    _validateNativeEndpoints(next);
    return SmartAccessLeaseRenewal._(binding, previous, next, currentLeaseIds);
  }
}

enum SmartAccessLeaseRevocation { drain, terminate }

/// Restriction identity and immutable scope fingerprint. It has no relay,
/// resolver, domains, device binding, nonce or signature and cannot be passed
/// to the profile compiler or treated as a verified grant.
class SmartAccessLeaseIdentity {
  SmartAccessLeaseIdentity._(this.lease, this.activeFlowsUntil);
  static const _fields = {'lease_id', 'audience', 'platform', 'service_id', 'provider_id',
    'permission_id', 'capability_id', 'provider_policy_revision', 'provider_security_revision',
    'provider_policy_sha256', 'issued_at', 'new_flows_until', 'active_flows_until'};
  static const _renewalFields = {'profile_sha256', 'route_mode', 'runtime_scope_sha256',
    'origin', 'family', 'feature', 'provider_revision', 'permission_revision',
    'catalog_revision', 'catalog_security_revision'};
  final Map<String, Object?> lease;
  final DateTime activeFlowsUntil;
  String get leaseId => lease['lease_id']! as String;
  DateTime get issuedAt => DateTime.parse(lease['issued_at']! as String);
  DateTime get newFlowsUntil => DateTime.parse(lease['new_flows_until']! as String);
  bool get hasRenewalScope => _renewalFields.every(lease.containsKey);
  bool matches(SmartAccessLeaseIdentity other) =>
      lease.length == other.lease.length && lease.entries.every((entry) => entry.value == other.lease[entry.key]);

  bool acceptsRenewalScope(VerifiedSmartAccessLease next) => acceptsRuntimeIdentity(SmartAccessLeaseIdentity.fromGrant(next));

  /// Scope/revision consistency only, never signature or grant authority.
  bool acceptsRuntimeIdentity(SmartAccessLeaseIdentity next) {
    if (!hasRenewalScope || !next.hasRenewalScope) return false;
    for (final field in const ['runtime_scope_sha256', 'profile_sha256', 'route_mode',
      'platform', 'audience', 'service_id', 'provider_id', 'permission_id', 'capability_id', 'origin', 'family', 'feature']) {
      if (lease[field] != next.lease[field]) return false;
    }
    for (final field in const ['provider_revision', 'permission_revision', 'provider_policy_revision',
      'provider_security_revision', 'catalog_revision', 'catalog_security_revision']) {
      final newer = next.lease[field];
      if (newer is! int || newer < (lease[field]! as int)) return false;
    }
    return true;
  }

  factory SmartAccessLeaseIdentity.fromGrant(VerifiedSmartAccessLease grant) =>
      SmartAccessLeaseIdentity.fromStored(grant.runtimeIdentity);

  factory SmartAccessLeaseIdentity.fromStored(Object? input) {
    if (input is! Map<String, Object?> || (input.length != _fields.length && input.length != _fields.length + _renewalFields.length) ||
        !_fields.every(input.containsKey)) _invalid();
    if (input.length != _fields.length) {
      if (!_renewalFields.every(input.containsKey) || input['route_mode'] != 'selective' ||
          !const {'ipv4', 'ipv6'}.contains(input['family']) ||
          !const {'current-origin', 'brain-origin', 'RU-origin', 'synthetic'}.contains(input['origin']) ||
          !const {'web_request', 'login', 'streaming', 'websocket', 'store', 'gameplay', 'cloud_gaming'}.contains(input['feature'])) _invalid();
      for (final field in const ['profile_sha256', 'runtime_scope_sha256']) {
        if (input[field] is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(input[field]! as String)) _invalid();
      }
      for (final field in const ['provider_revision', 'permission_revision', 'catalog_revision', 'catalog_security_revision']) {
        final value = input[field];
        if (value is! int || value < 1 || value > 9007199254740991) _invalid();
      }
    }
    for (final field in const ['service_id', 'provider_id', 'permission_id', 'capability_id']) {
      final value = input[field];
      if (value is! String || !RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(value)) _invalid();
    }
    for (final field in const ['provider_policy_revision', 'provider_security_revision']) {
      final value = input[field];
      if (value is! int || value < 1 || value > 9007199254740991) _invalid();
    }
    final id = input['lease_id'];
    final digest = input['provider_policy_sha256'];
    if (id is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
        digest is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        !const {'lab', 'production'}.contains(input['audience']) ||
        !const {'android', 'windows'}.contains(input['platform'])) _invalid();
    DateTime time(String field) {
      final value = input[field];
      final parsed = value is String ? DateTime.tryParse(value) : null;
      if (parsed == null || !parsed.isUtc) _invalid();
      return parsed;
    }
    final issued = time('issued_at');
    final newUntil = time('new_flows_until');
    final activeUntil = time('active_flows_until');
    if (!newUntil.isAfter(issued) || activeUntil.isBefore(newUntil) ||
        newUntil.difference(issued) > const Duration(minutes: 10) ||
        activeUntil.difference(issued) > const Duration(hours: 1)) _invalid();
    return SmartAccessLeaseIdentity._(Map.unmodifiable(input), activeUntil);
  }
}

/// Only a fresh, signed replacement can withdraw provider authority here.
/// Transport failures and a missing response are not revocation decisions.
Future<SmartAccessLeaseRevocation?> smartAccessLeaseRevocation({
  required SmartAccessLeaseIdentity grant,
  required VerifiedSmartAccessProviderPolicy policy,
  required DateTime now,
  VerifiedSmartAccessLease? verifiedGrant,
}) async {
  final lease = grant.lease;
  final instant = now.toUtc();
  if (instant.isBefore(policy.issuedAt) || !instant.isBefore(policy.expiresAt) ||
      policy.payload['audience'] != lease['audience'] ||
      policy.revision < (lease['provider_policy_revision']! as int) ||
      policy.securityRevision < (lease['provider_security_revision']! as int)) {
    throw const RoutingCatalogFailure('smart_access_policy_not_current');
  }
  if (policy.payloadSha256 == lease['provider_policy_sha256']) return null;
  if (policy.revision == lease['provider_policy_revision']) {
    throw const RoutingCatalogFailure('smart_access_policy_not_current');
  }

  Map<String, Object?>? row(String field, String key, Object? id) {
    final rows = (policy.payload[field]! as List).cast<Map<String, Object?>>();
    final ids = <String>{};
    Map<String, Object?>? found;
    for (final value in rows) {
      final valueId = value[key];
      if (valueId is! String || valueId.isEmpty || !ids.add(valueId)) {
        throw const RoutingCatalogFailure('smart_access_reference_invalid');
      }
      if (valueId == id) found = value;
    }
    return found;
  }

  final provider = row('providers', 'provider_id', lease['provider_id']);
  final permission = row('permissions', 'permission_id', lease['permission_id']);
  final capability = row('capabilities', 'capability_id', lease['capability_id']);
  // Removal from a complete signed replacement withdraws the old authority.
  if (provider == null || permission == null || capability == null) {
    return SmartAccessLeaseRevocation.terminate;
  }
  final issuedText = permission['issued_at'];
  final expiresText = permission['expires_at'];
  final issued = issuedText is String ? DateTime.tryParse(issuedText) : null;
  final expires = expiresText is String ? DateTime.tryParse(expiresText) : null;
  if (provider['enabled'] is! bool || capability['enabled'] is! bool ||
      permission['embedded_use_allowed'] is! bool ||
      !const {'pending', 'approved', 'revoked'}.contains(permission['status']) ||
      provider['permission_id'] is! String || permission['provider_id'] is! String ||
      capability['provider_id'] is! String || capability['service_id'] is! String ||
      issued == null || expires == null || !expires.isAfter(issued)) {
    throw const RoutingCatalogFailure('smart_access_policy_invalid');
  }
  if (provider['enabled'] == false || capability['enabled'] == false ||
      permission['status'] != 'approved' || permission['embedded_use_allowed'] == false ||
      provider['permission_id'] != lease['permission_id'] ||
      permission['provider_id'] != lease['provider_id'] ||
      capability['provider_id'] != lease['provider_id'] || capability['service_id'] != lease['service_id'] ||
      instant.isBefore(issued) || !instant.isBefore(expires) || expires.isBefore(grant.activeFlowsUntil)) {
    return SmartAccessLeaseRevocation.terminate;
  }
  // Compare original verified scope or its saved fingerprint. This comparison
  // does not remove a kill or issue authority from persisted metadata.
  if (verifiedGrant != null && grant.matches(SmartAccessLeaseIdentity.fromGrant(verifiedGrant)) &&
      _sameNativePolicyScope(verifiedGrant, provider, permission, capability, instant)) return null;
  if (grant.hasRenewalScope && await policy.matchesRetainedRuntimeScope(lease, instant)) return null;
  return SmartAccessLeaseRevocation.drain;
}

bool _sameNativePolicyScope(VerifiedSmartAccessLease grant, Map<String, Object?> provider,
    Map<String, Object?> permission, Map<String, Object?> capability, DateTime now) {
  final lease = grant.lease;
  final proofIssued = capability['observed_at'] is String ? DateTime.tryParse(capability['observed_at']! as String) : null;
  final proofExpires = capability['expires_at'] is String ? DateTime.tryParse(capability['expires_at']! as String) : null;
  if (capability['verification'] != 'verified' || proofIssued == null || proofExpires == null ||
      now.isBefore(proofIssued) || !now.isBefore(proofExpires) ||
      provider['resolver_url'] != lease['resolver_url'] ||
      permission['max_new_connections_per_minute'] != lease['max_new_connections_per_minute'] ||
      permission['max_concurrent_connections_per_lease'] != lease['max_concurrent_connections'] ||
      !smartAccessRelayConnectPoliciesMatch(permission['relay_connect_policy'], lease['relay_connect_policy']) ||
      const ['platform', 'origin', 'family', 'feature', 'transport'].any((field) => capability[field] != lease[field])) return false;
  final relays = provider['relay_addresses'];
  if (relays is! List || (lease['relay_addresses']! as List).any((relay) => !relays.contains(relay))) return false;
  final domains = capability['domains'];
  if (domains is! List || domains.length != (lease['domains']! as List).length) return false;
  final scope = <String>{};
  for (final domain in domains) {
    if (domain is! Map || domain.length != 2 || domain['name'] is! String ||
        !const {'exact', 'suffix'}.contains(domain['match']) || !scope.add('${domain['match']}:${domain['name']}')) return false;
  }
  return (lease['domains']! as List).every((domain) => scope.contains('${domain['match']}:${domain['name']}'));
}

String smartAccessOutboundTag(VerifiedSmartAccessLease grant) =>
    'pokrov-smart-access-${grant.lease['lease_id']}';
String smartAccessDnsTag(VerifiedSmartAccessLease grant) =>
    'pokrov-smart-access-dns-${grant.lease['lease_id']}';

/// The integrated subset is web requests from current-origin. Eligibility is
/// checked before equal-weight rendezvous; affinity is not a health claim.
Future<List<Map<String, Object?>>> selectSmartAccessWebCapabilities({
  required VerifiedRoutingCatalog catalog,
  required VerifiedSmartAccessProviderPolicy providers,
  required Set<String> serviceIds,
  required String platform,
  required DateTime now,
  required String selectionSeed,
  required bool Function() isCurrent,
  Map<String, String> preferredCapabilityIds = const {},
}) async {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(selectionSeed)) _invalid();
  bool current(Object? start, Object? end) {
    if (start is! String || end is! String) return false;
    final first = DateTime.tryParse(start);
    final last = DateTime.tryParse(end);
    return first != null && last != null && !now.toUtc().isBefore(first) && now.toUtc().isBefore(last);
  }
  if (!current(catalog.payload['issued_at'], catalog.payload['expires_at']) ||
      !current(providers.payload['issued_at'], providers.payload['expires_at'])) _invalid();
  final providerRows = (providers.payload['providers']! as List).cast<Map<String, Object?>>();
  final permissionRows = (providers.payload['permissions']! as List).cast<Map<String, Object?>>();
  final capabilities = (providers.payload['capabilities']! as List).cast<Map<String, Object?>>();
  final services = (catalog.payload['services']! as List).cast<Map<String, Object?>>();
  final selected = <Map<String, Object?>>[];
  for (final serviceId in serviceIds.toList()..sort()) {
    if (!isCurrent()) throw const RoutingCatalogFailure('smart_access_fetch_superseded');
    final service = services.where((row) => row['service_id'] == serviceId).single;
    final refs = service['provider_capability_refs']! as List;
    final eligible = capabilities.where((capability) {
      if (capability['service_id'] != serviceId || !refs.contains(capability['capability_id']) ||
          capability['enabled'] != true || capability['verification'] != 'verified' ||
          capability['platform'] != platform || capability['origin'] != 'current-origin' ||
          capability['feature'] != 'web_request' || capability['transport'] != 'tls_tcp_443_visible_sni' ||
          !const {'ipv4', 'ipv6'}.contains(capability['family']) ||
          !current(capability['observed_at'], capability['expires_at'])) return false;
      final matching = providerRows.where((row) => row['provider_id'] == capability['provider_id']).toList();
      if (matching.length != 1) return false;
      final provider = matching.single;
      if (provider['enabled'] != true || provider['revision'] != capability['provider_revision']) return false;
      final permissions = permissionRows.where((row) => row['permission_id'] == provider['permission_id']).toList();
      if (permissions.length != 1) return false;
      final permission = permissions.single;
      return permission['provider_id'] == provider['provider_id'] && permission['status'] == 'approved' &&
          permission['embedded_use_allowed'] == true && current(permission['issued_at'], permission['expires_at']);
    }).toList();
    if (eligible.isEmpty) continue;
    final preferred = eligible.where((row) => row['capability_id'] == preferredCapabilityIds[serviceId]).toList();
    // Retain the declared IPv4-first subset when there is no active affinity.
    // Family/origin/feature scope is not inferred from an IP, SSID or interface.
    final family = preferred.isNotEmpty ? preferred.single['family']! as String :
      eligible.any((row) => row['family'] == 'ipv4') ? 'ipv4' : 'ipv6';
    final compatible = eligible.where((row) => row['family'] == family).toList();
    final scope = [platform, serviceId, 'current-origin', 'web_request', family];
    final remaining = compatible.map((row) => row['provider_id']! as String).toSet();
    Map<String, Object?>? first;
    while (remaining.isNotEmpty) {
      final providerId = first == null && preferred.isNotEmpty ? preferred.single['provider_id']! as String :
        await _smartAccessRendezvous(remaining, [selectionSeed, ...scope, 'provider'], isCurrent);
      remaining.remove(providerId);
      final members = compatible.where((row) => row['provider_id'] == providerId &&
        (first == null || _sameGatewayDomains(row['domains'], first!['domains']))).toList();
      if (members.isEmpty) continue;
      final capabilityId = first == null && preferred.isNotEmpty ? preferred.single['capability_id']! as String :
        await _smartAccessRendezvous(members.map((row) => row['capability_id']! as String).toSet(),
          [selectionSeed, ...scope, 'capability', providerId], isCurrent);
      final candidate = members.singleWhere((row) => row['capability_id'] == capabilityId);
      first ??= candidate;
      selected.add(candidate);
    }
  }
  if (!isCurrent()) throw const RoutingCatalogFailure('smart_access_fetch_superseded');
  return List.unmodifiable(selected);
}

bool _sameGatewayDomains(Object? left, Object? right) {
  List<String>? keys(Object? value) {
    if (value is! List) return null;
    final result = <String>[];
    for (final domain in value) {
      if (domain is! Map || domain['name'] is! String || domain['match'] is! String) return null;
      result.add('${domain['match']}:${domain['name']}');
    }
    return result..sort();
  }
  final a = keys(left);
  final b = keys(right);
  if (a == null || b == null || a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) { if (a[index] != b[index]) return false; }
  return true;
}

Future<String> _smartAccessRendezvous(Set<String> candidates, List<String> scope,
    bool Function() isCurrent) async {
  var winner = '';
  var bestScore = '';
  for (final candidate in candidates) {
    if (!isCurrent()) throw const RoutingCatalogFailure('smart_access_fetch_superseded');
    final score = await smartAccessProfileSha256(jsonEncode([...scope, candidate]));
    final order = score.compareTo(bestScore);
    if (order > 0 || (order == 0 && candidate.compareTo(winner) < 0)) {
      winner = candidate;
      bestScore = score;
    }
  }
  return winner;
}

Map<String, Object?> smartAccessNativeOutbound(VerifiedSmartAccessLease grant) {
  _validateNativeEndpoints(grant);
  final lease = grant.lease;
  // The native owner keeps affinity and changes it only within an explicit
  // signed connect budget, before forwarding any ClientHello bytes.
  final relays = (lease['relay_addresses']! as List).cast<String>().toList()..sort();
  return Map.unmodifiable({
    'type': 'pokrov-smart-access', 'tag': smartAccessOutboundTag(grant),
    'lease_id': lease['lease_id'], 'issued_at': lease['issued_at'],
    'new_flows_until': lease['new_flows_until'], 'active_flows_until': lease['active_flows_until'],
    'relay_addresses': relays, 'domains': lease['domains'],
    'relay_connect_policy': lease['relay_connect_policy'],
    'max_new_connections_per_minute': lease['max_new_connections_per_minute'],
    'max_concurrent_connections': lease['max_concurrent_connections'],
  });
}

Map<String, Object?> smartAccessNativeDns(VerifiedSmartAccessLease grant, {
  required String directOutbound, required String bootstrapDnsServer,
}) {
  _validateNativeEndpoints(grant);
  if (directOutbound.isEmpty || bootstrapDnsServer.isEmpty) _invalid();
  return Map.unmodifiable({
    'tag': smartAccessDnsTag(grant), 'address': grant.lease['resolver_url'],
    'address_resolver': bootstrapDnsServer, 'detour': directOutbound,
    'strategy': grant.lease['family'] == 'ipv4' ? 'ipv4_only' : 'ipv6_only',
  });
}

void _validateNativeEndpoints(VerifiedSmartAccessLease grant) {
  final lease = grant.lease;
  final family = lease['family'];
  final relays = lease['relay_addresses'];
  if (!const {'ipv4', 'ipv6'}.contains(family) || relays is! List || relays.isEmpty ||
      relays.length > 8 || relays.toSet().length != relays.length) _invalid();
  for (final raw in relays) {
    final address = raw is String ? InternetAddress.tryParse(raw) : null;
    if (address == null || !_publicRelay(address) ||
        (address.type == InternetAddressType.IPv4) != (family == 'ipv4')) _invalid();
  }
  final rawUrl = lease['resolver_url'];
  final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
  if (rawUrl is! String || url == null || url.scheme != 'https' || url.host.isEmpty || url.port != 443 ||
      url.path != '/dns-query' || url.userInfo.isNotEmpty || url.hasQuery || url.hasFragment ||
      rawUrl.contains('\\') || rawUrl.runes.any((rune) => rune < 33)) _invalid();
  final host = url.host.replaceAll(RegExp(r'^\[|\]$'), '');
  final address = InternetAddress.tryParse(host);
  if (address != null ? !_publicRelay(address) : !_domain(host)) _invalid();
  final domains = lease['domains'];
  if (domains is! List || domains.isEmpty || domains.length > 256) _invalid();
  final seen = <String>{};
  for (final domain in domains) {
    if (domain is! Map || domain['name'] is! String || !_domain(domain['name'] as String) ||
        domain['name'] == 'pokrov.space' || (domain['name'] as String).endsWith('.pokrov.space') ||
        !const {'exact', 'suffix'}.contains(domain['match']) ||
        !seen.add('${domain['match']}:${domain['name']}')) _invalid();
  }
}

bool _domain(String value) => value.length <= 253 && value.split('.').length >= 2 &&
    value.split('.').every((label) => RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(label)) &&
    InternetAddress.tryParse(value) == null;

// Same relay boundary as Core; special/mapped/translation addresses cannot
// smuggle a private target through a signed public-provider projection.
bool _publicRelay(InternetAddress address) {
  if (address.address.contains('%')) return false;
  final bytes = address.rawAddress;
  bool inside(String cidr) {
    final parts = cidr.split('/');
    final network = InternetAddress(parts[0]).rawAddress;
    if (bytes.length != network.length) return false;
    final bits = int.parse(parts[1]);
    for (var index = 0; index < (bits + 7) ~/ 8; index++) {
      final remaining = bits - index * 8;
      final mask = remaining >= 8 ? 255 : (255 << (8 - remaining)) & 255;
      if ((bytes[index] & mask) != (network[index] & mask)) return false;
    }
    return true;
  }
  if (bytes.length == 16 && !inside('2000::/3')) return false;
  return !const [
    '0.0.0.0/8', '10.0.0.0/8', '100.64.0.0/10', '127.0.0.0/8', '169.254.0.0/16',
    '172.16.0.0/12', '192.0.0.0/24', '192.0.2.0/24', '192.88.99.0/24', '192.168.0.0/16',
    '198.18.0.0/15', '198.51.100.0/24', '203.0.113.0/24', '224.0.0.0/3',
    '2001::/23', '2001:db8::/32', '2002::/16', '3fff::/20',
  ].any(inside);
}

Never _invalid() => throw const RoutingCatalogFailure('smart_access_native_projection_invalid');
