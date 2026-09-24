part of 'routing_catalog_contract.dart';

const transportManifestMaximumBytes = 512 * 1024;
const transportManifestResponseMaximumBytes = 2 * transportManifestMaximumBytes + 1024;
const transportBootstrapResponseMaximumBytes = 4 * transportManifestMaximumBytes + 4096;
const transportTrustConfigurationMaximumBytes = 16 * 1024;

/// Release-pinned public keys, never keys learned from a policy/API response.
/// Exact canonical JSON gives the Python and Dart configs duplicate-key parity.
Map<String, String> decodeTransportTrustKeys(String raw) {
  try {
    if (raw.isEmpty) return const {};
    if (raw.length > transportTrustConfigurationMaximumBytes ||
        utf8.encode(raw).length > transportTrustConfigurationMaximumBytes) {
      throw const TransportManifestFailure('transport_trust_invalid');
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic>) {
      throw const TransportManifestFailure('transport_trust_invalid');
    }
    final keys = _transportTrustKeys(value.cast<String, String>());
    if (_canonical(keys) != raw) {
      throw const TransportManifestFailure('transport_trust_invalid');
    }
    return keys;
  } on Object {
    throw const TransportManifestFailure('transport_trust_invalid');
  }
}

Map<String, String> _transportTrustKeys(Map<String, String> input) {
  try {
    if (utf8.encode(_canonical(input)).length > transportTrustConfigurationMaximumBytes) {
      throw const TransportManifestFailure('transport_trust_invalid');
    }
    for (final entry in input.entries) {
      if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(entry.key) ||
          !RegExp(r'^[A-Za-z0-9+/]{43}=$').hasMatch(entry.value)) {
        throw const TransportManifestFailure('transport_trust_invalid');
      }
      final bytes = base64Decode(entry.value);
      if (bytes.length != 32 || base64Encode(bytes) != entry.value) {
        throw const TransportManifestFailure('transport_trust_invalid');
      }
    }
    return Map<String, String>.unmodifiable(input);
  } on Object {
    throw const TransportManifestFailure('transport_trust_invalid');
  }
}

/// Freshness is established by the loader's owned HTTPS request/nonce, not by
/// decoding a file. This response must never be reused as an enrollment token.
Map<String, dynamic> decodeTransportBootstrapResponse(String raw) {
  try {
    if (raw.length > transportBootstrapResponseMaximumBytes ||
        utf8.encode(raw).length > transportBootstrapResponseMaximumBytes) {
      throw const TransportManifestFailure('transport_response_too_large');
    }
    final value = _transportMap(_freeze(jsonDecode(raw), 0));
    _keys(value, const {'schema', 'manifest', 'rollback', 'floor', 'observed_at', 'request_nonce'});
    if (value['schema'] != 'transport-bootstrap-response-v1' ||
        value['manifest'] is! Map<String, Object?> || value['floor'] is! Map<String, Object?> ||
        (value['rollback'] != null && value['rollback'] is! Map<String, Object?>) ||
        value['request_nonce'] is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(value['request_nonce'] as String) ||
        raw != '${_canonical(value)}\n') {
      throw const TransportManifestFailure('transport_response_invalid');
    }
    _time(value['observed_at']);
    return value;
  } on TransportManifestFailure {
    rethrow;
  } on Object {
    throw const TransportManifestFailure('transport_response_invalid');
  }
}

/// The transport endpoint emits canonical JSON plus exactly one newline.
/// Re-encoding equality rejects duplicate keys, ambiguous numbers, extra
/// whitespace and escaped aliases without a second handwritten JSON parser.
Map<String, dynamic> decodeTransportManifestResponse(String raw) {
  try {
    if (raw.length > transportManifestResponseMaximumBytes ||
        utf8.encode(raw).length > transportManifestResponseMaximumBytes) {
      throw const TransportManifestFailure('transport_response_too_large');
    }
    final value = _transportMap(_freeze(jsonDecode(raw), 0));
    _keys(value, const {'schema', 'manifest', 'rollback'});
    if (value['schema'] != 'transport-manifest-response-v1' ||
        value['manifest'] is! Map<String, Object?> ||
        (value['rollback'] != null && value['rollback'] is! Map<String, Object?>) ||
        raw != '${_canonical(value)}\n') {
      throw const TransportManifestFailure('transport_response_invalid');
    }
    return value;
  } on TransportManifestFailure {
    rethrow;
  } on Object {
    throw const TransportManifestFailure('transport_response_invalid');
  }
}

class TransportManifestFetchResult {
  const TransportManifestFetchResult({required this.admission, required this.usingCache});
  final TransportAdmission admission;
  final bool usingCache;
}

class TransportManifestFailure implements Exception {
  const TransportManifestFailure(this.code);
  final String code;
  @override
  String toString() => code;
}

/// Public signed policy only. Admission neither grants access nor starts traffic.
class TransportAdmission {
  const TransportAdmission._(this.manifest, this.rollback, this.nextFloor,
      this.effectiveExpiresAt, this.effectiveKills, this.capabilityBindings);
  final Map<String, Object?> manifest;
  final Map<String, Object?>? rollback;
  final Map<String, Object?> nextFloor;
  final DateTime effectiveExpiresAt;
  final Map<String, Object?> effectiveKills;
  final Map<String, TransportCapabilityBinding> capabilityBindings;
  Map<String, Object?> get payload => manifest['payload'] as Map<String, Object?>;
}

class TransportManifestVerifier {
  TransportManifestVerifier({required Map<String, String> publicKeysById,
      required this.audience, required this.clientRelease, required this.coreRelease})
      : _keysById = _transportTrustKeys(publicKeysById);

  factory TransportManifestVerifier.pinned({required String clientRelease,
      required String coreRelease}) {
    const keysJson = String.fromEnvironment('POKROV_TRANSPORT_TRUSTED_KEYS_JSON');
    return TransportManifestVerifier(
      publicKeysById: decodeTransportTrustKeys(keysJson),
      audience: const String.fromEnvironment('POKROV_TRANSPORT_AUDIENCE', defaultValue: 'production'),
      clientRelease: clientRelease, coreRelease: coreRelease,
    );
  }

  final Map<String, String> _keysById;
  final String audience;
  final String clientRelease;
  final String coreRelease;
  bool get configured => const {'lab', 'production'}.contains(audience) && _keysById.isNotEmpty;

  /// Validate retained state without resetting corrupt or unsupported floors.
  Map<String, Object?> validateFloor(Object? input) {
    try {
      final floor = _transportMap(_freeze(input, 0));
      _keys(floor, const {'schema_version', 'audience', 'epoch', 'revision',
        'document_kind', 'payload_sha256', 'last_observed_at', 'kills'});
      if (floor['schema_version'] != 'pokrov-transport-floor-v1' ||
          floor['audience'] != audience ||
          !const {'manifest', 'rollback'}.contains(floor['document_kind'])) {
        throw const TransportManifestFailure('transport_floor_invalid');
      }
      _revision(floor['epoch']);
      _revision(floor['revision']);
      _transportDigest(floor['payload_sha256']);
      _time(floor['last_observed_at']);
      _transportKills(floor['kills']);
      return floor;
    } on Object {
      throw const TransportManifestFailure('transport_floor_invalid');
    }
  }

  Future<TransportAdmission> admit(Object? input, {required DateTime now,
      required Object? floor, Object? rollback, DateTime? earliestNow}) async {
    try {
      if (!configured) throw const TransportManifestFailure('transport_trust_unconfigured');
      // Freeze every caller-owned input before any asynchronous crypto work.
      final manifest = _transportMap(_freeze(input, 0));
      final authorization = rollback == null ? null : _transportMap(_freeze(rollback, 0));
      final previous = floor == null ? null : validateFloor(floor);
      now = now.toUtc();
      earliestNow = (earliestNow ?? now).toUtc();
      if (earliestNow.isAfter(now)) throw const TransportManifestFailure('transport_clock_invalid');
      if (previous != null && now.isBefore(_time(previous['last_observed_at']))) {
        throw const TransportManifestFailure('transport_clock_rollback');
      }
      final capabilityBindings = await _verify(manifest, now, false, earliestNow);
      final payload = _transportMap(manifest['payload']);
      var current = manifest;
      var kind = 'manifest';
      var kills = _transportMap(payload['kills']);
      var expiry = _time(payload['expires_at']);
      if (authorization != null) {
        await _verify(authorization, now, true, earliestNow);
        final target = _transportMap(authorization['payload']);
        if (target['target_epoch'] != payload['epoch'] ||
            target['target_revision'] != payload['revision'] ||
            target['target_payload_sha256'] != manifest['payload_sha256']) {
          throw const TransportManifestFailure('transport_rollback_target_mismatch');
        }
        current = authorization;
        kind = 'rollback';
        kills = {for (final name in _transportKillFields) name: <String>{
          ..._transportRefs(kills[name], 0, 4096),
          ..._transportRefs(_transportMap(target['kills'])[name], 0, 4096),
          if (previous != null) ..._transportRefs(_transportMap(previous['kills'])[name], 0, 4096),
        }.toList()..sort()};
        _transportKills(kills);
        final rollbackExpiry = _time(target['expires_at']);
        if (rollbackExpiry.isBefore(expiry)) expiry = rollbackExpiry;
      }
      final version = _transportMap(current['payload']);
      if (previous != null) {
        final order = _transportVersionCompare(version, previous);
        if (order < 0) throw const TransportManifestFailure('transport_revision_rollback');
        if (order == 0 && (kind != previous['document_kind'] ||
            current['payload_sha256'] != previous['payload_sha256'])) {
          throw const TransportManifestFailure('transport_revision_equivocation');
        }
      }
      final frozenKills = _transportMap(_freeze(kills, 0));
      final next = validateFloor({
        'schema_version': 'pokrov-transport-floor-v1', 'audience': audience,
        'epoch': version['epoch'], 'revision': version['revision'],
        'document_kind': kind, 'payload_sha256': current['payload_sha256'],
        'last_observed_at': now.toIso8601String().split('.')[0] + 'Z',
        'kills': frozenKills,
      });
      return TransportAdmission._(manifest, authorization, next, expiry, frozenKills, capabilityBindings);
    } on TransportManifestFailure {
      rethrow;
    } on Object {
      throw const TransportManifestFailure('transport_manifest_invalid');
    }
  }

  Future<Map<String, TransportCapabilityBinding>> _verify(Map<String, Object?> envelope, DateTime now, bool rollback, DateTime earliestNow) async {
    _keys(envelope, const {'algorithm', 'key_id', 'payload_sha256', 'payload', 'signature_b64'});
    if (utf8.encode(_canonical(envelope)).length + 1 > transportManifestMaximumBytes) {
      throw const TransportManifestFailure('transport_document_too_large');
    }
    final payload = _transportMap(envelope['payload']);
    _keys(payload, {
      'schema_version', 'audience', 'signer_key_id', 'epoch', 'revision',
      'issued_at', 'not_before', 'expires_at', 'minimum_client_release',
      'minimum_core_release', 'kills',
      if (rollback) ...{'target_epoch', 'target_revision', 'target_payload_sha256'}
      else ...{'capability_refs', 'capability_bindings', 'profile_refs', 'bootstrap_set_refs', 'probe_set_refs', 'budget'},
    });
    final schema = rollback ? 'pokrov-transport-rollback-v1' : 'pokrov-transport-manifest-v1';
    if (envelope['algorithm'] != 'Ed25519' || payload['schema_version'] != schema ||
        payload['audience'] != audience || envelope['key_id'] != payload['signer_key_id']) {
      throw const TransportManifestFailure('transport_document_invalid');
    }
    final keyId = envelope['key_id'];
    if (keyId is! String || !RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(keyId)) {
      throw const TransportManifestFailure('transport_signer_invalid');
    }
    _revision(payload['epoch']);
    _revision(payload['revision']);
    final issued = _time(payload['issued_at']);
    final start = _time(payload['not_before']);
    final expiry = _time(payload['expires_at']);
    if (issued.isAfter(start) || !start.isBefore(expiry) || earliestNow.isBefore(start) || !now.isBefore(expiry)) {
      throw const TransportManifestFailure('transport_document_not_current');
    }
    if (_transportReleaseCompare(clientRelease, payload['minimum_client_release']) < 0 ||
        _transportReleaseCompare(coreRelease, payload['minimum_core_release']) < 0) {
      throw const TransportManifestFailure('transport_release_incompatible');
    }
    _transportKills(payload['kills']);
    Map<String, TransportCapabilityBinding> capabilityBindings = const {};
    if (rollback) {
      _transportDigest(payload['target_payload_sha256']);
      final target = {'epoch': _revision(payload['target_epoch']), 'revision': _revision(payload['target_revision'])};
      if (_transportVersionCompare(target, payload) >= 0) {
        throw const TransportManifestFailure('transport_rollback_target_order');
      }
    } else {
      final capabilityRefs = _transportRefs(payload['capability_refs'], 1, 256);
      final profileRefs = _transportRefs(payload['profile_refs'], 1, 1024);
      capabilityBindings = _transportCapabilityBindings(payload['capability_bindings'], capabilityRefs, profileRefs);
      _transportRefs(payload['bootstrap_set_refs'], 1, 64);
      _transportRefs(payload['probe_set_refs'], 1, 64);
      _transportBudget(payload['budget']);
    }
    _transportDigest(envelope['payload_sha256']);
    final body = utf8.encode(_canonical(payload));
    final digest = (await Sha256().hash(body)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (digest != envelope['payload_sha256']) throw const TransportManifestFailure('transport_digest_mismatch');
    final encodedKey = _keysById[keyId];
    if (encodedKey == null) throw const TransportManifestFailure('transport_signer_untrusted');
    final publicKey = base64Decode(encodedKey);
    final signature = envelope['signature_b64'];
    if (publicKey.length != 32 || signature is! String || !RegExp(r'^[A-Za-z0-9_-]{86}$').hasMatch(signature)) {
      throw const TransportManifestFailure('transport_signature_invalid');
    }
    if (!await Ed25519().verify([...utf8.encode('$schema\n'), ...body],
        signature: Signature(base64Url.decode(base64Url.normalize(signature)),
          publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)))) {
      throw const TransportManifestFailure('transport_signature_invalid');
    }
    return capabilityBindings;
  }
}

class TransportCapabilityBinding {
  TransportCapabilityBinding._({required this.capabilityRef, required this.coreCapabilityRevision,
      required Set<RuntimeTransportFeature> requiredFeatures,
      required Set<(HostPlatform, String)> artifacts, required Set<String> profileRefs})
      : requiredFeatures = Set.unmodifiable(requiredFeatures), artifacts = Set.unmodifiable(artifacts),
        profileRefs = Set.unmodifiable(profileRefs);

  final String capabilityRef, coreCapabilityRevision;
  final Set<RuntimeTransportFeature> requiredFeatures;
  /// Exact executable/module digest, not a filename or a container's digest.
  final Set<(HostPlatform, String)> artifacts;
  final Set<String> profileRefs;
}

Map<String, TransportCapabilityBinding> _transportCapabilityBindings(Object? input,
    List<String> capabilityRefs, List<String> profileRefs) {
  Never invalid() => throw const TransportManifestFailure('transport_capability_binding_invalid');
  if (input is! List || input.length != capabilityRefs.length) invalid();
  final bindings = <String, TransportCapabilityBinding>{};
  final revisions = <(HostPlatform, String), String>{};
  final allowedProfiles = profileRefs.toSet();
  for (var index = 0; index < input.length; index++) {
    final value = _transportMap(input[index]);
    _keys(value, const {'capability_ref', 'core_capability_revision', 'required_features', 'artifacts', 'profile_refs'});
    if (value['capability_ref'] != capabilityRefs[index]) invalid();
    final revision = _transportRefs([value['core_capability_revision']], 1, 1).single;
    final profiles = _transportRefs(value['profile_refs'], 1, 1024).toSet();
    if (!allowedProfiles.containsAll(profiles)) invalid();
    final rawFeatures = value['required_features'];
    if (rawFeatures is! List || rawFeatures.isEmpty || rawFeatures.length > RuntimeTransportFeature.values.length) invalid();
    final features = <RuntimeTransportFeature>{};
    String? previousFeature;
    for (final name in rawFeatures) {
      if (name is! String || (previousFeature != null && previousFeature.compareTo(name) >= 0)) invalid();
      final known = RuntimeTransportFeature.values.where((feature) => feature.wireName == name);
      if (known.isEmpty) invalid();
      features.add(known.single);
      previousFeature = name;
    }
    final rawArtifacts = value['artifacts'];
    if (rawArtifacts is! List || rawArtifacts.isEmpty || rawArtifacts.length > 64) invalid();
    final artifacts = <(HostPlatform, String)>{};
    String? previousArtifact;
    for (final raw in rawArtifacts) {
      final artifact = _transportMap(raw);
      _keys(artifact, const {'platform', 'artifact_sha256'});
      final platform = HostPlatform.values.where((item) => item.name == artifact['platform']);
      if (platform.isEmpty) invalid();
      _transportDigest(artifact['artifact_sha256']);
      final digest = artifact['artifact_sha256'] as String;
      final order = '${platform.single.name}:$digest';
      if (previousArtifact != null && previousArtifact.compareTo(order) >= 0) invalid();
      previousArtifact = order;
      final key = (platform.single, digest);
      final previousRevision = revisions[key];
      if (previousRevision != null && previousRevision != revision) invalid();
      revisions[key] = revision;
      artifacts.add(key);
    }
    final ref = capabilityRefs[index];
    bindings[ref] = TransportCapabilityBinding._(capabilityRef: ref, coreCapabilityRevision: revision,
        requiredFeatures: features, artifacts: artifacts, profileRefs: profiles);
  }
  return Map.unmodifiable(bindings);
}

const _transportKillFields = {'profile_refs', 'endpoint_refs', 'capability_refs'};

Map<String, Object?> _transportMap(Object? value) {
  if (value is! Map<String, Object?>) throw const TransportManifestFailure('transport_shape_invalid');
  return value;
}

void _transportDigest(Object? value) {
  if (value is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw const TransportManifestFailure('transport_digest_invalid');
  }
}

List<String> _transportRefs(Object? input, int minimum, int maximum) {
  if (input is! List || input.length < minimum || input.length > maximum) {
    throw const TransportManifestFailure('transport_refs_invalid');
  }
  final refs = <String>[];
  for (final value in input) {
    if (value is! String || !RegExp(r'^[a-z][a-z0-9_]{1,23}_[0-9a-f]{16,64}$').hasMatch(value) ||
        (refs.isNotEmpty && refs.last.compareTo(value) >= 0)) {
      throw const TransportManifestFailure('transport_refs_invalid');
    }
    refs.add(value);
  }
  return refs;
}

void _transportKills(Object? input) {
  final kills = _transportMap(input);
  _keys(kills, _transportKillFields);
  for (final name in _transportKillFields) { _transportRefs(kills[name], 0, 4096); }
}

int _transportVersionCompare(Map<String, Object?> a, Map<String, Object?> b) {
  final epoch = (a['epoch'] as int).compareTo(b['epoch'] as int);
  return epoch != 0 ? epoch : (a['revision'] as int).compareTo(b['revision'] as int);
}

int _transportReleaseCompare(Object? a, Object? b) {
  final pattern = RegExp(r'^(0|[1-9][0-9]{0,4})\.(0|[1-9][0-9]{0,4})\.(0|[1-9][0-9]{0,4})$');
  if (a is! String || b is! String || !pattern.hasMatch(a) || !pattern.hasMatch(b)) {
    throw const TransportManifestFailure('transport_release_invalid');
  }
  final left = a.split('.').map(int.parse).toList();
  final right = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final order = left[i].compareTo(right[i]);
    if (order != 0) return order;
  }
  return 0;
}

void _transportBudget(Object? input) {
  final budget = _transportMap(input);
  _keys(budget, const {'policy_ref', 'total_deadline_ms', 'stage_caps_ms',
    'max_attempts', 'max_endpoints', 'max_concurrency', 'max_diagnostic_bytes',
    'cooldown_ms', 'hints_ttl_ms', 'max_repairs'});
  _transportRefs([budget['policy_ref']], 1, 1);
  for (final (name, minimum, maximum) in const [
    ('total_deadline_ms', 1, 86400000), ('max_attempts', 1, 10000),
    ('max_endpoints', 1, 10000), ('max_concurrency', 1, 256),
    ('max_diagnostic_bytes', 0, 67108864), ('cooldown_ms', 0, 86400000),
    ('hints_ttl_ms', 1, 2678400000), ('max_repairs', 0, 10000),
  ]) {
    final value = budget[name];
    if (value is! int || value < minimum || value > maximum) {
      throw const TransportManifestFailure('transport_budget_invalid');
    }
  }
  final stages = _transportMap(budget['stage_caps_ms']);
  _keys(stages, const {'profile', 'transport', 'dns', 'payload', 'egress'});
  for (final value in stages.values) {
    if (value is! int || value < 1 || value > (budget['total_deadline_ms'] as int)) {
      throw const TransportManifestFailure('transport_budget_invalid');
    }
  }
  if ((budget['max_repairs'] as int) > (budget['max_attempts'] as int)) {
    throw const TransportManifestFailure('transport_budget_invalid');
  }
}
