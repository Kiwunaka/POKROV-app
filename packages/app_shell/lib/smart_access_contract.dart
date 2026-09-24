part of 'routing_catalog_contract.dart';

const smartAccessPolicyMaximumBytes = 512 * 1024;
const smartAccessLeaseMaximumBytes = 64 * 1024;
const smartAccessControlMaximumBytes = 8 * 1024;

bool smartAccessRelayConnectPoliciesMatch(Object? left, Object? right) => _canonical(left) == _canonical(right);

void _validateRelayConnectPolicy(Object? value) {
  if (value == null) return; // No retry/breaker budget was authorized.
  const fields = {'failure_threshold', 'failure_window_ms', 'cooldown_ms',
    'connect_timeout_ms', 'total_timeout_ms', 'max_attempts'};
  if (value is! Map<String, Object?> || value.length != fields.length ||
      !fields.every(value.containsKey)) throw const RoutingCatalogFailure('smart_access_relay_budget_invalid');
  for (final field in fields) {
    final number = value[field];
    final maximum = field == 'failure_threshold' ? 10000 : field == 'max_attempts' ? 8 : 600000;
    if (number is! int || number < 1 || number > maximum) {
      throw const RoutingCatalogFailure('smart_access_relay_budget_invalid');
    }
  }
  if ((value['connect_timeout_ms']! as int) > (value['total_timeout_ms']! as int)) {
    throw const RoutingCatalogFailure('smart_access_relay_budget_invalid');
  }
}

// Validate fields consumed by provider selection and the evidence view before
// exposing them as verified metadata. Endpoint enforcement remains in the native
// projection and the exact signed-grant checks.
void _validateProviderRows(Map<String, Object?> payload) {
  Never invalid() => throw const RoutingCatalogFailure('smart_access_policy_invalid');
  String id(Object? value) {
    if (value is! String || !RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(value)) invalid();
    return value;
  }
  void digest(Object? value) {
    if (value is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value) || value.split('').toSet().length == 1) invalid();
  }
  void lifetime(Object? start, Object? end) {
    if (!_time(start).isBefore(_time(end))) invalid();
  }
  Map<String, Map<String, Object?>> rows(String collection, String identity, Set<String> keys) {
    final result = <String, Map<String, Object?>>{};
    for (final row in (payload[collection]! as List).cast<Map<String, Object?>>()) {
      _keys(row, keys);
      final key = id(row[identity]);
      if (result.containsKey(key)) invalid();
      result[key] = row;
    }
    return result;
  }
  final permissions = rows('permissions', 'permission_id', const {'permission_id', 'provider_id', 'revision',
    'status', 'embedded_use_allowed', 'review_ref', 'review_sha256', 'issued_at', 'expires_at',
    'max_new_connections_per_minute', 'max_concurrent_connections_per_lease', 'relay_connect_policy'});
  for (final permission in permissions.values) {
    id(permission['provider_id']); id(permission['review_ref']); digest(permission['review_sha256']);
    _revision(permission['revision']); lifetime(permission['issued_at'], permission['expires_at']);
    if (!const {'pending', 'approved', 'revoked'}.contains(permission['status']) ||
        permission['embedded_use_allowed'] is! bool ||
        (permission['status'] == 'approved' && permission['embedded_use_allowed'] != true)) invalid();
    for (final (field, maximum) in const [('max_new_connections_per_minute', 10000), ('max_concurrent_connections_per_lease', 256)]) {
      final value = permission[field];
      if (value is! int || value < 1 || value > maximum) invalid();
    }
    _validateRelayConnectPolicy(permission['relay_connect_policy']);
  }
  final providers = rows('providers', 'provider_id', const {'provider_id', 'revision', 'kind', 'enabled',
    'permission_id', 'resolver_url', 'relay_addresses', 'privacy_review_ref', 'privacy_review_sha256'});
  for (final provider in providers.values) {
    _revision(provider['revision']); id(provider['privacy_review_ref']); digest(provider['privacy_review_sha256']);
    final permission = permissions[id(provider['permission_id'])];
    final relays = provider['relay_addresses'];
    final resolver = provider['resolver_url'];
    if (permission == null || permission['provider_id'] != provider['provider_id'] ||
        provider['enabled'] is! bool || !const {'owned', 'external'}.contains(provider['kind']) ||
        resolver is! String || resolver.isEmpty || resolver.length > 512 ||
        relays is! List || relays.isEmpty || relays.length > 8 || relays.any((value) => value is! String)) invalid();
  }
  final capabilities = rows('capabilities', 'capability_id', const {'capability_id', 'provider_id',
    'provider_revision', 'service_id', 'enabled', 'verification', 'checks', 'platform', 'origin', 'family',
    'feature', 'transport', 'domains', 'proof_ref', 'proof_sha256', 'observed_at', 'expires_at'});
  for (final capability in capabilities.values) {
    id(capability['service_id']); id(capability['proof_ref']); digest(capability['proof_sha256']);
    _revision(capability['provider_revision']); lifetime(capability['observed_at'], capability['expires_at']);
    final provider = providers[id(capability['provider_id'])];
    final domains = capability['domains'];
    final checks = capability['checks'];
    if (provider == null || provider['revision'] != capability['provider_revision'] ||
        capability['enabled'] is! bool || !const {'source_only', 'verified'}.contains(capability['verification']) ||
        !const {'android', 'windows'}.contains(capability['platform']) ||
        !const {'current-origin', 'brain-origin', 'RU-origin', 'synthetic'}.contains(capability['origin']) ||
        !const {'ipv4', 'ipv6'}.contains(capability['family']) ||
        !const {'web_request', 'login', 'streaming', 'websocket', 'store', 'gameplay', 'cloud_gaming'}.contains(capability['feature']) ||
        capability['transport'] != 'tls_tcp_443_visible_sni' ||
        (provider['kind'] == 'owned' && capability['family'] != 'ipv4') ||
        (payload['audience'] == 'production' && capability['origin'] == 'synthetic') ||
        domains is! List || domains.isEmpty || domains.length > 256 || checks is! Map<String, Object?>) invalid();
    _keys(checks, const {'resolver_transport', 'dns_answer', 'tls_certificate', 'feature_request'});
    if (checks.values.any((value) => !const {'PASS', 'FAIL', 'NOT_VERIFIED', 'MANUAL_OWNER_TEST',
        'OPERATOR_ATTESTED', 'SKIPPED_BY_OWNER', 'SKIPPED_BY_OPERATOR', 'BLOCKED_BY_ACCESS', 'NOT_REQUESTED'}.contains(value)) ||
        (capability['verification'] == 'verified' && checks.values.any((value) => value != 'PASS'))) invalid();
    for (final domain in domains) {
      if (domain is! Map<String, Object?> || domain['name'] is! String ||
          !const {'exact', 'suffix'}.contains(domain['match'])) invalid();
      _keys(domain, const {'name', 'match'});
    }
  }
}

class VerifiedSmartAccessControl {
  const VerifiedSmartAccessControl._(this.profileDigest, this.action, this.reason, this.expiresAt);
  final String profileDigest;
  final String action;
  final String reason;
  final DateTime expiresAt;
}

class VerifiedSmartAccessProviderPolicy {
  const VerifiedSmartAccessProviderPolicy._(this.envelope, this.payload, this.payloadSha256,
    this.revision, this.securityRevision, this.issuedAt, this.expiresAt);
  final Map<String, Object?> envelope;
  final Map<String, Object?> payload;
  final String payloadSha256;
  final int revision;
  final int securityRevision;
  final DateTime issuedAt;
  final DateTime expiresAt;

  /// Compare only scope from this verified replacement. This does not issue a
  /// grant or extend a lease; the caller still evaluates disable/permission kills.
  Future<bool> matchesRetainedRuntimeScope(Map<String, Object?> identity, DateTime now) async {
    if (identity['runtime_scope_sha256'] is! String) return false;
    Map<String, Object?>? row(String collection, String key, Object? id) {
      final rows = (payload[collection]! as List).cast<Map<String, Object?>>()
          .where((value) => value[key] == id).toList();
      return rows.length == 1 ? rows.single : null;
    }
    final provider = row('providers', 'provider_id', identity['provider_id']);
    final permission = row('permissions', 'permission_id', identity['permission_id']);
    final capability = row('capabilities', 'capability_id', identity['capability_id']);
    if (provider == null || permission == null || capability == null ||
        capability['verification'] != 'verified' ||
        now.isBefore(_time(capability['observed_at'])) || !now.isBefore(_time(capability['expires_at'])) ||
        (provider['revision']! as int) < (identity['provider_revision']! as int) ||
        (permission['revision']! as int) < (identity['permission_revision']! as int)) return false;
    final relays = (provider['relay_addresses']! as List).cast<String>().where((address) =>
      address.contains(':') == (capability['family'] == 'ipv6')).toList();
    final scope = <String, Object?>{'schema_version': 'pokrov-smart-access-lease-v1', 'audience': payload['audience'],
      'provider_id': provider['provider_id'], 'permission_id': permission['permission_id'],
      for (final field in const ['capability_id', 'service_id', 'platform', 'origin', 'family', 'feature', 'transport', 'domains'])
        field: capability[field],
      'resolver_url': provider['resolver_url'], 'relay_addresses': relays,
      'max_new_connections_per_minute': permission['max_new_connections_per_minute'],
      'max_concurrent_connections': permission['max_concurrent_connections_per_lease'],
      'relay_connect_policy': permission['relay_connect_policy']};
    return await _smartAccessRuntimeScopeSha256(
      {'profile_sha256': identity['profile_sha256'], 'route_mode': identity['route_mode']}, scope) == identity['runtime_scope_sha256'];
  }
}

class VerifiedSmartAccessLease {
  const VerifiedSmartAccessLease._(this.envelope, this.grant, this.lease,
    this.issuedAt, this.newFlowsUntil, this.activeFlowsUntil, this.runtimeScopeSha256);
  final Map<String, Object?> envelope;
  final Map<String, Object?> grant;
  final Map<String, Object?> lease;
  final DateTime issuedAt;
  final DateTime newFlowsUntil;
  final DateTime activeFlowsUntil;
  final String runtimeScopeSha256;
  bool admitsNewFlows(DateTime now) => !now.toUtc().isBefore(issuedAt) && now.toUtc().isBefore(newFlowsUntil);

  /// Non-secret recovery projection. The signed envelope stays memory-only.
  Map<String, Object?> get runtimeIdentity => Map.unmodifiable({
    for (final field in const ['lease_id', 'audience', 'platform', 'service_id', 'provider_id',
      'permission_id', 'capability_id', 'provider_policy_revision', 'provider_security_revision',
      'provider_policy_sha256', 'issued_at', 'new_flows_until', 'active_flows_until',
      'origin', 'family', 'feature', 'provider_revision', 'permission_revision',
      'catalog_revision', 'catalog_security_revision']) field: lease[field],
    'profile_sha256': grant['profile_sha256'], 'route_mode': grant['route_mode'],
    'runtime_scope_sha256': runtimeScopeSha256});

  /// Both objects must come from signature verification. Revisions may advance,
  /// but renewal cannot change the configuration of the already running graph.
  bool hasSameRuntimeScope(VerifiedSmartAccessLease previous) {
    if (runtimeScopeSha256 != previous.runtimeScopeSha256) return false;
    for (final field in const ['provider_revision', 'permission_revision',
      'provider_policy_revision', 'provider_security_revision', 'catalog_revision',
      'catalog_security_revision']) {
      final next = lease[field];
      final old = previous.lease[field];
      if (next is! int || old is! int || next < old) return false;
    }
    return true;
  }
}

// Only called after full signature, binding and policy verification. Dates and
// advancing revisions are checked separately; domain order is not scope.
Future<String> _smartAccessRuntimeScopeSha256(Map<String, Object?> grant, Map<String, Object?> lease) async {
  final domains = (lease['domains']! as List).map(_canonical).toList()..sort();
  final scope = {'profile_sha256': grant['profile_sha256'], 'route_mode': grant['route_mode'],
    for (final field in const ['schema_version', 'audience', 'provider_id',
      'permission_id', 'capability_id', 'service_id', 'platform', 'origin',
      'family', 'feature', 'transport', 'resolver_url', 'relay_addresses',
      'max_new_connections_per_minute', 'max_concurrent_connections', 'relay_connect_policy']) field: lease[field],
    'domains': domains};
  return (await Sha256().hash(utf8.encode('pokrov-smart-access-runtime-scope-v1\n${_canonical(scope)}')))
      .bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

/// Public policy and device grants have separate pins and signing contexts.
/// Verification supplies no native route, health proof or retry policy.
class SmartAccessVerifier {
  SmartAccessVerifier({required Map<String, String> providerKeysById,
    required Map<String, String> leaseKeysById, required this.audience})
    : _providerKeys = Map.unmodifiable(providerKeysById), _leaseKeys = Map.unmodifiable(leaseKeysById);

  factory SmartAccessVerifier.pinned() {
    const providerId = String.fromEnvironment('POKROV_SMART_ACCESS_PROVIDER_KEY_ID');
    const providerKey = String.fromEnvironment('POKROV_SMART_ACCESS_PROVIDER_PUBLIC_KEY_B64');
    const leaseId = String.fromEnvironment('POKROV_SMART_ACCESS_LEASE_KEY_ID');
    const leaseKey = String.fromEnvironment('POKROV_SMART_ACCESS_LEASE_PUBLIC_KEY_B64');
    return SmartAccessVerifier(
      providerKeysById: providerId.isEmpty || providerKey.isEmpty ? const {} : const {providerId: providerKey},
      leaseKeysById: leaseId.isEmpty || leaseKey.isEmpty ? const {} : const {leaseId: leaseKey},
      audience: const String.fromEnvironment('POKROV_SMART_ACCESS_AUDIENCE', defaultValue: 'production'),
    );
  }

  final Map<String, String> _providerKeys;
  final Map<String, String> _leaseKeys;
  final String audience;
  bool get configured => const {'lab', 'production'}.contains(audience)
    && _providerKeys.isNotEmpty && _leaseKeys.isNotEmpty;
  bool get controlConfigured => const {'lab', 'production'}.contains(audience)
    && _leaseKeys.isNotEmpty;

  /// The caller obtained this delegation over its authenticated API connection.
  /// Only local lease pins are forwarded; the response cannot supply trust keys.
  /// The result is a sensitive memory-only native command, never profile data.
  String runtimeControlConfig(Map<String, dynamic> response, {required String nonce,
    required String? catalogSha256,
    required String profileDigest, required String platform, required String apiBaseUrl, required DateTime now}) {
    try {
      _keys(response, const {'schema', 'request_nonce', 'profile_digest', 'platform', 'capability', 'issued_at', 'expires_at'});
      final capability = response['capability'];
      if (!controlConfigured || response['schema'] != 'smart-access-runtime-capability-response-v1' ||
          response['request_nonce'] != nonce || response['profile_digest'] != profileDigest || response['platform'] != platform ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(profileDigest) || !const {'android', 'windows'}.contains(platform) ||
          (catalogSha256 != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(catalogSha256)) ||
          capability is! String || capability.length > 4096 ||
          !RegExp(r'^pkr_src1\.[A-Za-z0-9_-]+\.[a-f0-9]{64}$').hasMatch(capability)) {
        throw const RoutingCatalogFailure('smart_access_runtime_capability_invalid');
      }
      final issued = _time(response['issued_at']);
      final expires = _time(response['expires_at']);
      if (!issued.isBefore(expires) || now.toUtc().isBefore(issued) || !now.toUtc().isBefore(expires)) {
        throw const RoutingCatalogFailure('smart_access_runtime_capability_expired');
      }
      final uri = Uri.parse(apiBaseUrl);
      if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
          uri.hasQuery || uri.hasFragment || (uri.path.isNotEmpty && uri.path != '/') || uri.port != 443) {
        throw const RoutingCatalogFailure('smart_access_runtime_origin_invalid');
      }
      return jsonEncode({'schema_version': 'pokrov-smart-access-runtime-worker-v1',
        'catalog_sha256': catalogSha256 ?? '',
        'profile_digest': profileDigest, 'platform': platform, 'audience': audience,
        'api_base_url': apiBaseUrl, 'dns_resolver': 'dns-direct', 'capability': capability,
        'issued_at': response['issued_at'], 'expires_at': response['expires_at'], 'lease_keys_by_id': _leaseKeys});
    } on RoutingCatalogFailure { rethrow; }
      on Object { throw const RoutingCatalogFailure('smart_access_runtime_capability_invalid'); }
  }

  String runtimeRenewalConfig(Map<String, dynamic> response, {required String nonce,
    required String profileDigest, required String platform, required VerifiedSmartAccessLease grant,
    required VerifiedRoutingCatalog catalog, required DateTime now}) {
    try {
      _keys(response, const {'schema', 'request_nonce', 'profile_digest', 'platform',
        'lease_id', 'runtime_scope_sha256', 'capability', 'issued_at', 'expires_at'});
      final capability = response['capability'];
      if (!configured || response['schema'] != 'smart-access-runtime-renewal-capability-response-v1' ||
          response['request_nonce'] != nonce || response['profile_digest'] != profileDigest ||
          response['platform'] != platform || grant.lease['platform'] != platform || grant.lease['audience'] != audience ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(profileDigest) || !const {'android', 'windows'}.contains(platform) ||
          response['lease_id'] != grant.lease['lease_id'] || response['runtime_scope_sha256'] != grant.runtimeScopeSha256 ||
          grant.lease['catalog_sha256'] != catalog.payloadSha256 ||
          capability is! String || capability.length > 4096 ||
          !RegExp(r'^pkr_srn1\.[A-Za-z0-9_-]+\.[a-f0-9]{64}$').hasMatch(capability)) {
        throw const RoutingCatalogFailure('smart_access_runtime_renewal_capability_invalid');
      }
      final issued = _time(response['issued_at']);
      final expires = _time(response['expires_at']);
      if (!issued.isBefore(expires) || now.toUtc().isBefore(issued) || !now.toUtc().isBefore(expires) ||
          !grant.admitsNewFlows(now) || now.toUtc().isBefore(catalog.issuedAt) ||
          !now.toUtc().isBefore(catalog.expiresAt) || expires.isAfter(catalog.expiresAt)) {
        throw const RoutingCatalogFailure('smart_access_runtime_renewal_capability_expired');
      }
      return jsonEncode({'schema_version': 'pokrov-smart-access-runtime-renewal-worker-v1',
        'profile_digest': profileDigest, 'capability': capability, 'issued_at': response['issued_at'],
        'expires_at': response['expires_at'], 'lease': grant.runtimeIdentity});
    } on RoutingCatalogFailure { rethrow; }
      on Object { throw const RoutingCatalogFailure('smart_access_runtime_renewal_capability_invalid'); }
  }

  Future<Map<String, Object?>> _verifyEnvelope(Object? input, {
    required Map<String, String> pins, required String context, required int maximumBytes,
  }) async {
    if (!const {'lab', 'production'}.contains(audience) || pins.isEmpty) {
      throw const RoutingCatalogFailure('smart_access_trust_unconfigured');
    }
    final envelope = _freeze(input, 0);
    if (envelope is! Map<String, Object?>) throw const RoutingCatalogFailure('smart_access_envelope_invalid');
    _keys(envelope, const {'algorithm', 'key_id', 'payload_sha256', 'payload', 'signature_b64'});
    if (utf8.encode(_canonical(envelope)).length + 1 > maximumBytes || envelope['algorithm'] != 'Ed25519') {
      throw const RoutingCatalogFailure('smart_access_envelope_invalid');
    }
    final payload = envelope['payload'];
    final keyId = envelope['key_id'];
    final encoded = keyId is String ? pins[keyId] : null;
    final signatureText = envelope['signature_b64'];
    if (payload is! Map<String, Object?> || encoded == null || signatureText is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{86}$').hasMatch(signatureText)) {
      throw const RoutingCatalogFailure('smart_access_signature_invalid');
    }
    final key = base64Decode(encoded);
    final body = utf8.encode(_canonical(payload));
    final digest = (await Sha256().hash(body)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (envelope['payload_sha256'] != digest || key.length != 32 || !await Ed25519().verify(
      [...utf8.encode(context), ...body], signature: Signature(base64Url.decode(base64Url.normalize(signatureText)),
        publicKey: SimplePublicKey(key, type: KeyPairType.ed25519)))) {
      throw const RoutingCatalogFailure('smart_access_signature_invalid');
    }
    return envelope;
  }

  Future<VerifiedSmartAccessProviderPolicy> verifyProvider(Object? input, {
    required DateTime now, required int minimumRevision, required int minimumSecurityRevision,
    required String? currentPayloadSha256,
  }) async {
    try {
      if (minimumRevision < 0 || minimumRevision > _maximumRevision ||
          minimumSecurityRevision < 1 || minimumSecurityRevision > _maximumRevision) {
        throw const RoutingCatalogFailure('smart_access_floor_invalid');
      }
      final envelope = await _verifyEnvelope(input, pins: _providerKeys,
        context: 'pokrov-smart-access-providers-v1\n', maximumBytes: smartAccessPolicyMaximumBytes);
      final payload = envelope['payload']! as Map<String, Object?>;
      _keys(payload, const {'schema_version', 'revision', 'security_revision', 'audience',
        'issued_at', 'expires_at', 'permissions', 'providers', 'capabilities'});
      final revision = _revision(payload['revision']);
      final security = _revision(payload['security_revision']);
      final issued = _time(payload['issued_at']);
      final expires = _time(payload['expires_at']);
      final digest = envelope['payload_sha256']! as String;
      if (payload['schema_version'] != 'pokrov-smart-access-providers-v1' || payload['audience'] != audience ||
          revision < minimumRevision || security < minimumSecurityRevision ||
          (revision == minimumRevision && currentPayloadSha256 != digest) ||
          !expires.isAfter(issued) || now.toUtc().isBefore(issued) || !now.toUtc().isBefore(expires)) {
        throw const RoutingCatalogFailure('smart_access_policy_not_current');
      }
      for (final (field, maximum) in const [('permissions', 32), ('providers', 32), ('capabilities', 256)]) {
        final rows = payload[field];
        if (rows is! List || rows.length > maximum || rows.any((row) => row is! Map<String, Object?>)) {
          throw const RoutingCatalogFailure('smart_access_policy_invalid');
        }
      }
      _validateProviderRows(payload);
      return VerifiedSmartAccessProviderPolicy._(envelope, payload, digest, revision, security, issued, expires);
    } on RoutingCatalogFailure { rethrow; }
      on Object { throw const RoutingCatalogFailure('smart_access_verification_failed'); }
  }

  Future<VerifiedSmartAccessControl> verifyControl(Object? input, {
    required Map<String, Object?> request, required String accountId, required String installId,
    required DateTime now,
  }) async {
    try {
      final nonce = request['request_nonce'];
      final profile = request['profile_digest'];
      if (request['schema_version'] != 'pokrov-smart-access-control-request-v1' ||
          nonce is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(nonce) ||
          profile is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(profile) ||
          !const {'android', 'windows'}.contains(request['platform']) || accountId.isEmpty || installId.isEmpty) {
        throw const RoutingCatalogFailure('smart_access_control_request_invalid');
      }
      final envelope = await _verifyEnvelope(input, pins: _leaseKeys,
        context: 'pokrov-smart-access-control-v1\n', maximumBytes: smartAccessControlMaximumBytes);
      final payload = envelope['payload']! as Map<String, Object?>;
      _keys(payload, const {'schema_version', 'request_nonce', 'device_binding', 'profile_digest',
        'platform', 'audience', 'action', 'reason', 'issued_at', 'expires_at'});
      final binding = (await Sha256().hash(utf8.encode(
        'pokrov-smart-access-device-v1\u0000$nonce\u0000$accountId\u0000$installId'))).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      const actions = {'current': 'none', 'issuance_disabled': 'drain', 'access_denied': 'terminate',
        'provider_policy_disabled': 'terminate', 'catalog_disabled': 'terminate'};
      final reason = payload['reason'];
      final action = payload['action'];
      if (payload['schema_version'] != 'pokrov-smart-access-control-v1' || payload['request_nonce'] != nonce ||
          payload['device_binding'] != binding || payload['profile_digest'] != profile ||
          payload['platform'] != request['platform'] || payload['audience'] != audience ||
          reason is! String || !actions.containsKey(reason) || action != actions[reason]) {
        throw const RoutingCatalogFailure('smart_access_control_binding_mismatch');
      }
      final issued = _time(payload['issued_at']);
      final expires = _time(payload['expires_at']);
      if (!expires.isAfter(issued) || expires.difference(issued) > const Duration(seconds: 60) ||
          now.toUtc().isBefore(issued) || !now.toUtc().isBefore(expires)) {
        throw const RoutingCatalogFailure('smart_access_control_not_current');
      }
      return VerifiedSmartAccessControl._(profile, action! as String, reason, expires);
    } on RoutingCatalogFailure { rethrow; }
      on Object { throw const RoutingCatalogFailure('smart_access_verification_failed'); }
  }

  Future<VerifiedSmartAccessLease> verifyLease(Object? input, {
    required Map<String, Object?> request, required String accountId, required String installId,
    required VerifiedRoutingCatalog catalog, required VerifiedSmartAccessProviderPolicy providerPolicy,
    required DateTime now,
  }) async {
    try {
      final expected = _freeze(request, 0)! as Map<String, Object?>;
      if (!configured) throw const RoutingCatalogFailure('smart_access_trust_unconfigured');
      final envelope = await _verifyEnvelope(input, pins: _leaseKeys,
        context: 'pokrov-smart-access-grant-v1\n', maximumBytes: smartAccessLeaseMaximumBytes);
      final grant = envelope['payload']! as Map<String, Object?>;
      _keys(grant, const {'schema_version', 'request_nonce', 'device_binding', 'profile_sha256', 'route_mode', 'lease'});
      final nonce = expected['request_nonce'];
      if (nonce is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(nonce) || accountId.isEmpty || installId.isEmpty) {
        throw const RoutingCatalogFailure('smart_access_request_invalid');
      }
      final binding = (await Sha256().hash(utf8.encode(
        'pokrov-smart-access-device-v1\u0000$nonce\u0000$accountId\u0000$installId'))).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (grant['schema_version'] != 'pokrov-smart-access-grant-v1' || grant['request_nonce'] != nonce ||
          grant['device_binding'] != binding || grant['profile_sha256'] != expected['profile_sha256'] ||
          grant['route_mode'] != 'selective' || expected['route_mode'] != 'selective') {
        throw const RoutingCatalogFailure('smart_access_grant_binding_mismatch');
      }
      final lease = grant['lease'];
      if (lease is! Map<String, Object?>) throw const RoutingCatalogFailure('smart_access_lease_invalid');
      _keys(lease, const {'schema_version', 'lease_id', 'audience', 'provider_id', 'provider_revision',
        'permission_id', 'permission_revision', 'capability_id', 'provider_policy_revision', 'provider_security_revision',
        'provider_policy_sha256', 'catalog_revision', 'catalog_security_revision', 'catalog_sha256', 'service_id',
        'platform', 'origin', 'family', 'feature', 'transport', 'issued_at', 'new_flows_until', 'active_flows_until',
        'resolver_url', 'relay_addresses', 'domains', 'max_new_connections_per_minute', 'max_concurrent_connections',
        'relay_connect_policy'});
      _validateRelayConnectPolicy(lease['relay_connect_policy']);
      if (lease['schema_version'] != 'pokrov-smart-access-lease-v1' || lease['audience'] != audience ||
          catalog.payload['audience'] != audience || providerPolicy.payload['audience'] != audience ||
          lease['catalog_sha256'] != catalog.payloadSha256 || expected['catalog_sha256'] != catalog.payloadSha256 ||
          lease['provider_policy_sha256'] != providerPolicy.payloadSha256 ||
          expected['provider_policy_sha256'] != providerPolicy.payloadSha256 ||
          lease['catalog_revision'] != catalog.revision || lease['catalog_security_revision'] != catalog.securityRevision ||
          lease['provider_policy_revision'] != providerPolicy.revision ||
          lease['provider_security_revision'] != providerPolicy.securityRevision ||
          lease['transport'] != 'tls_tcp_443_visible_sni' ||
          const ['capability_id', 'platform', 'origin', 'family', 'feature'].any((key) => lease[key] != expected[key])) {
        throw const RoutingCatalogFailure('smart_access_lease_scope_mismatch');
      }
      final issued = _time(lease['issued_at']);
      final newUntil = _time(lease['new_flows_until']);
      final activeUntil = _time(lease['active_flows_until']);
      if (!newUntil.isAfter(issued) || activeUntil.isBefore(newUntil) ||
          newUntil.difference(issued) > const Duration(minutes: 10) ||
          activeUntil.difference(issued) > const Duration(hours: 1) ||
          now.toUtc().isBefore(issued) || !now.toUtc().isBefore(newUntil) ||
          issued.isBefore(catalog.issuedAt) || issued.isBefore(providerPolicy.issuedAt) ||
          newUntil.isAfter(catalog.expiresAt) || newUntil.isAfter(providerPolicy.expiresAt)) {
        throw const RoutingCatalogFailure('smart_access_lease_not_current');
      }
      // Endpoints/domains come from the authenticated exact provider capability,
      // not from an independently supplied route or URL.
      Map<String, Object?> row(String field, String key, Object? id) {
        final matches = (providerPolicy.payload[field]! as List).cast<Map<String, Object?>>()
          .where((value) => value[key] == id).toList();
        if (matches.length != 1) throw const RoutingCatalogFailure('smart_access_reference_invalid');
        return matches.single;
      }
      final capability = row('capabilities', 'capability_id', lease['capability_id']);
      final provider = row('providers', 'provider_id', lease['provider_id']);
      final permission = row('permissions', 'permission_id', lease['permission_id']);
      final relays = lease['relay_addresses'];
      final providerRelays = provider['relay_addresses'];
      if (provider['enabled'] != true || capability['enabled'] != true || capability['verification'] != 'verified' ||
          permission['status'] != 'approved' || permission['embedded_use_allowed'] != true ||
          provider['permission_id'] != lease['permission_id'] || permission['provider_id'] != lease['provider_id'] ||
          provider['revision'] != lease['provider_revision'] || permission['revision'] != lease['permission_revision'] ||
          capability['provider_revision'] != lease['provider_revision'] ||
          capability['provider_id'] != lease['provider_id'] || capability['service_id'] != lease['service_id'] ||
          const ['platform', 'origin', 'family', 'feature', 'transport'].any((key) => capability[key] != lease[key]) ||
          _canonical(capability['domains']) != _canonical(lease['domains']) ||
          provider['resolver_url'] != lease['resolver_url'] || relays is! List || providerRelays is! List ||
          relays.isEmpty || relays.length > 8 || relays.any((value) => value is! String || !providerRelays.contains(value)) ||
          lease['max_new_connections_per_minute'] != permission['max_new_connections_per_minute'] ||
          lease['max_concurrent_connections'] != permission['max_concurrent_connections_per_lease'] ||
          !smartAccessRelayConnectPoliciesMatch(lease['relay_connect_policy'], permission['relay_connect_policy']) ||
          issued.isBefore(_time(permission['issued_at'])) || issued.isBefore(_time(capability['observed_at'])) ||
          activeUntil.isAfter(_time(permission['expires_at'])) || newUntil.isAfter(_time(capability['expires_at']))) {
        throw const RoutingCatalogFailure('smart_access_capability_mismatch');
      }
      final leaseId = lease['lease_id'];
      final perMinute = lease['max_new_connections_per_minute'];
      final concurrent = lease['max_concurrent_connections'];
      final domains = lease['domains'];
      if (leaseId is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(leaseId) ||
          perMinute is! int || perMinute < 1 || perMinute > 10000 ||
          concurrent is! int || concurrent < 1 || concurrent > 256 ||
          domains is! List || domains.isEmpty || domains.length > 256) {
        throw const RoutingCatalogFailure('smart_access_lease_invalid');
      }
      final services = (catalog.payload['services']! as List).cast<Map<String, Object?>>()
        .where((value) => value['service_id'] == lease['service_id']).toList();
      if (services.length != 1) throw const RoutingCatalogFailure('smart_access_service_not_eligible');
      final service = services.single;
      final capabilityRefs = service['provider_capability_refs'];
      final intents = service['route_intents'];
      final platforms = service['platforms'];
      final serviceDomains = service['domains'];
      if (service['enabled'] != true || service['evidence_status'] != 'verified' ||
          service['external_gateway_policy'] != 'approved' || platforms is! List ||
          !platforms.contains(lease['platform']) || capabilityRefs is! List ||
          !capabilityRefs.contains(lease['capability_id']) || intents is! List ||
          !intents.any((item) => item is Map && item['mode'] == 'selective' && item['action'] == 'approved_gateway') ||
          serviceDomains is! List || domains.any((domain) => domain is! Map ||
            domain.length != 2 || domain['name'] is! String || !const {'exact', 'suffix'}.contains(domain['match']) ||
            !serviceDomains.any((candidate) => candidate is Map && candidate['shared'] == false &&
              candidate['name'] == domain['name'] && candidate['match'] == domain['match']))) {
        throw const RoutingCatalogFailure('smart_access_service_not_eligible');
      }
      final scopeSha256 = await _smartAccessRuntimeScopeSha256(grant, lease);
      return VerifiedSmartAccessLease._(envelope, grant, lease, issued, newUntil, activeUntil, scopeSha256);
    } on RoutingCatalogFailure { rethrow; }
      on Object { throw const RoutingCatalogFailure('smart_access_verification_failed'); }
  }
}
