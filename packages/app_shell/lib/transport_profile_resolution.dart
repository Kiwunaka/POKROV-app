part of 'routing_catalog_contract.dart';

const transportProfileMaximumBytes = 1024 * 1024;
const transportProfileResponseMaximumBytes = 2 * transportProfileMaximumBytes + 16384;
const transportEndpointShortlistMaximumBytes = 65536;

class TransportEndpointShortlistQuery {
  TransportEndpointShortlistQuery(Map<String, Object?> value)
      : fields = _transportMap(_freeze(value, 0)) {
    _keys(fields, const {'platform', 'capability_ref', 'profile_ref', 'bootstrap_set_ref',
      'probe_set_ref', 'artifact_sha256', 'core_capability_revision', 'family',
      'selection_role', 'max_endpoints'});
    for (final name in const ['capability_ref', 'profile_ref', 'bootstrap_set_ref',
        'probe_set_ref', 'core_capability_revision']) {
      _transportRefs([fields[name]], 1, 1);
    }
    _transportDigest(fields['artifact_sha256']);
    if (!const {'android', 'windows', 'linux', 'ios', 'macos'}.contains(fields['platform']) ||
        !const {'ipv4', 'ipv6'}.contains(fields['family']) ||
        !const {'primary', 'cold_reserve'}.contains(fields['selection_role']) ||
        fields['max_endpoints'] is! int || (fields['max_endpoints'] as int) < 1 ||
        (fields['max_endpoints'] as int) > 64) {
      throw const TransportManifestFailure('transport_endpoint_query_invalid');
    }
  }

  final Map<String, Object?> fields;

  void requirePolicy(TransportAdmission admission) {
    final binding = admission.capabilityBindings[fields['capability_ref']];
    final platform = HostPlatform.values.firstWhere((item) => item.name == fields['platform']);
    if (binding == null || !binding.requiredFeatures.contains(RuntimeTransportFeature.atsLease) ||
        !binding.profileRefs.contains(fields['profile_ref']) ||
        binding.coreCapabilityRevision != fields['core_capability_revision'] ||
        !binding.artifacts.contains((platform, fields['artifact_sha256'])) ||
        !(admission.payload['bootstrap_set_refs'] as List).contains(fields['bootstrap_set_ref']) ||
        !(admission.payload['probe_set_refs'] as List).contains(fields['probe_set_ref']) ||
        (admission.effectiveKills['profile_refs'] as List).contains(fields['profile_ref']) ||
        (admission.effectiveKills['capability_refs'] as List).contains(fields['capability_ref']) ||
        (fields['max_endpoints'] as int) > ((admission.payload['budget'] as Map)['max_endpoints'] as int)) {
      throw const TransportManifestFailure('transport_endpoint_query_not_authorized');
    }
  }

  Map<String, Object?> request(TransportAdmission admission, String nonce) {
    requirePolicy(admission);
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(nonce)) {
      throw const TransportManifestFailure('transport_endpoint_nonce_invalid');
    }
    return _transportMap(_freeze(<String, Object?>{
      'schema_version': 'pokrov-transport-endpoint-shortlist-request-v1',
      'request_nonce': nonce,
      'policy': <String, Object?>{
        for (final key in const ['audience', 'epoch', 'revision', 'document_kind', 'payload_sha256'])
          key: admission.nextFloor[key],
        'manifest_sha256': admission.manifest['payload_sha256'],
      },
      ...fields,
    }, 0));
  }
}

class TransportEndpointHint {
  const TransportEndpointHint(this.endpointRef, this.failureDomainRef, this.transportFeature);
  final String endpointRef, failureDomainRef, transportFeature;
}

Map<String, dynamic> decodeTransportEndpointShortlistResponse(String raw) {
  try {
    if (utf8.encode(raw).length > transportEndpointShortlistMaximumBytes) throw const FormatException();
    final value = _transportMap(_freeze(jsonDecode(raw), 0));
    _keys(value, const {'schema_version', 'request', 'items'});
    if (value['schema_version'] != 'pokrov-transport-endpoint-shortlist-response-v1' ||
        raw != '${_canonical(value)}\n') {
      throw const FormatException();
    }
    return Map<String, dynamic>.from(value);
  } on Object {
    throw const TransportManifestFailure('transport_endpoint_shortlist_invalid');
  }
}

List<TransportEndpointHint> admitTransportEndpointShortlist(Map<String, dynamic> value,
    {required Map<String, Object?> request, required TransportAdmission admission}) {
  try {
    if (_canonical(value['request']) != _canonical(request)) throw const FormatException();
    final query = TransportEndpointShortlistQuery({
      for (final key in const ['platform', 'capability_ref', 'profile_ref', 'bootstrap_set_ref',
          'probe_set_ref', 'artifact_sha256', 'core_capability_revision', 'family',
          'selection_role', 'max_endpoints']) key: request[key],
    });
    query.requirePolicy(admission);
    final rows = value['items'];
    if (rows is! List || rows.length > (query.fields['max_endpoints'] as int)) throw const FormatException();
    final binding = admission.capabilityBindings[query.fields['capability_ref']]!;
    final seen = <String>{};
    final hints = <TransportEndpointHint>[];
    for (final rawItem in rows) {
      final item = _transportMap(rawItem);
      _keys(item, const {'endpoint_ref', 'failure_domain_ref', 'transport_feature'});
      _transportRefs([item['endpoint_ref']], 1, 1);
      _transportRefs([item['failure_domain_ref']], 1, 1);
      if (!seen.add(item['endpoint_ref'] as String) ||
          (admission.effectiveKills['endpoint_refs'] as List).contains(item['endpoint_ref']) ||
          !const {'singbox_reality_v1', 'singbox_grpc_v1', 'singbox_xhttp_v1'}
            .contains(item['transport_feature']) ||
          !binding.requiredFeatures.any((feature) => feature.wireName == item['transport_feature'])) {
        throw const FormatException();
      }
      hints.add(TransportEndpointHint(item['endpoint_ref'] as String,
        item['failure_domain_ref'] as String, item['transport_feature'] as String));
    }
    return List.unmodifiable(hints);
  } on Object {
    throw const TransportManifestFailure('transport_endpoint_shortlist_invalid');
  }
}

/// Non-secret selection constraints. This value never grants endpoint access.
class TransportProfileQuery {
  TransportProfileQuery(Map<String, Object?> value)
      : fields = _transportMap(_freeze(value, 0)) {
    _keys(fields, const {'platform', 'profile_ref', 'endpoint_ref', 'capability_ref',
      'bootstrap_set_ref', 'probe_set_ref', 'artifact_sha256', 'core_capability_revision',
      'route_policy_ref', 'dns_policy_ref', 'mode', 'family'});
    for (final name in const ['profile_ref', 'endpoint_ref', 'capability_ref',
        'bootstrap_set_ref', 'probe_set_ref', 'core_capability_revision', 'route_policy_ref', 'dns_policy_ref']) {
      _transportRefs([fields[name]], 1, 1);
    }
    _transportDigest(fields['artifact_sha256']);
    if (!const {'android', 'windows', 'linux', 'ios', 'macos'}.contains(fields['platform']) ||
        !const {'fullTunnel', 'selectedApps', 'excludedApps', 'allExceptRu', 'selectiveServices'}.contains(fields['mode']) ||
        !const {'ipv4', 'ipv6'}.contains(fields['family'])) {
      throw const TransportManifestFailure('transport_profile_query_invalid');
    }
  }
  final Map<String, Object?> fields;

  void requirePolicy(TransportAdmission admission) {
    final binding = admission.capabilityBindings[fields['capability_ref']];
    final platform = HostPlatform.values.firstWhere((item) => item.name == fields['platform']);
    if (binding == null || !binding.requiredFeatures.contains(RuntimeTransportFeature.atsLease) ||
        !binding.profileRefs.contains(fields['profile_ref']) ||
        binding.coreCapabilityRevision != fields['core_capability_revision'] ||
        !binding.artifacts.contains((platform, fields['artifact_sha256'])) ||
        !(admission.payload['profile_refs'] as List).contains(fields['profile_ref']) ||
        !(admission.payload['bootstrap_set_refs'] as List).contains(fields['bootstrap_set_ref']) ||
        !(admission.payload['probe_set_refs'] as List).contains(fields['probe_set_ref']) ||
        (admission.effectiveKills['profile_refs'] as List).contains(fields['profile_ref']) ||
        (admission.effectiveKills['endpoint_refs'] as List).contains(fields['endpoint_ref']) ||
        (admission.effectiveKills['capability_refs'] as List).contains(fields['capability_ref'])) {
      throw const TransportManifestFailure('transport_profile_not_authorized');
    }
  }

  Map<String, Object?> request(TransportAdmission admission, String nonce) {
    requirePolicy(admission);
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(nonce)) {
      throw const TransportManifestFailure('transport_profile_nonce_invalid');
    }
    return _transportMap(_freeze(<String, Object?>{
      'schema_version': 'pokrov-transport-profile-request-v1', 'request_nonce': nonce,
      'policy': <String, Object?>{
        for (final key in const ['audience', 'epoch', 'revision', 'document_kind', 'payload_sha256'])
          key: admission.nextFloor[key],
        'manifest_sha256': admission.manifest['payload_sha256'],
      },
      'query': fields,
    }, 0));
  }
}

Map<String, dynamic> decodeTransportProfileResponse(String raw) {
  try {
    if (raw.length > transportProfileResponseMaximumBytes ||
        utf8.encode(raw).length > transportProfileResponseMaximumBytes) {
      throw const FormatException();
    }
    final value = _transportMap(_freeze(jsonDecode(raw), 0));
    _keys(value, const {'schema_version', 'request', 'candidate_ref', 'profile_revision',
      'profile_sha256', 'endpoint_lease_ref', 'failure_domain_ref', 'authorized_from',
      'authorized_until', 'active_flows_until', 'config_format', 'config_payload'});
    if (value['schema_version'] != 'pokrov-transport-profile-response-v1' ||
        value['config_format'] != 'singbox-json' || raw != '${_canonical(value)}\n') {
      throw const FormatException();
    }
    return Map<String, dynamic>.from(value);
  } on Object {
    // Never stringify a response containing profile credentials.
    throw const TransportManifestFailure('transport_profile_response_invalid');
  }
}

RuntimeTransportFeature _resolvedTransportFeature(Map<String, dynamic> config) {
  final outbounds = config['outbounds'];
  if (outbounds is! List) throw const FormatException();
  const expectedOutbounds = <String, String>{
    'pokrov-ats': 'vless', 'direct': 'direct', 'block': 'block', 'dns-out': 'dns',
  };
  final tags = <String>{};
  for (final item in outbounds) {
    if (item is! Map || item['tag'] is! String ||
        !tags.add(item['tag'] as String) || expectedOutbounds[item['tag']] != item['type']) {
      throw const FormatException();
    }
  }
  if (tags.length != expectedOutbounds.length) throw const FormatException();
  final route = config['route'];
  final rules = route is Map ? route['rules'] : null;
  if (route is! Map || route['final'] != 'pokrov-ats' || rules is! List ||
      rules.length != 1 || rules.single is! Map ||
      (rules.single as Map).length != 2 ||
      rules.single['protocol'] != 'dns' || rules.single['outbound'] != 'dns-out') {
    throw const FormatException();
  }
  final selected = outbounds.where((item) => item is Map && item['tag'] == 'pokrov-ats').toList();
  if (selected.length != 1 || selected.single is! Map || selected.single['type'] != 'vless') {
    throw const FormatException();
  }
  final outbound = selected.single as Map;
  final tls = outbound['tls'];
  if (tls is! Map || tls['enabled'] != true || tls['utls'] is! Map ||
      (tls['utls'] as Map)['enabled'] != true) throw const FormatException();
  final reality = tls['reality'];
  final transport = outbound['transport'];
  if (reality is Map && reality['enabled'] == true && transport == null) {
    return RuntimeTransportFeature.reality;
  }
  if (reality == null && transport is Map && transport['type'] == 'grpc') {
    return RuntimeTransportFeature.grpc;
  }
  if (reality == null && transport is Map && transport['type'] == 'xhttp') {
    return RuntimeTransportFeature.xhttp;
  }
  throw const FormatException();
}

/// Validated wire material; only the owned HTTPS loader adds session authority.
class TransportResolvedProfile {
  const TransportResolvedProfile._(this.query, this.candidateRef, this.profileRevision,
      this.profileSha256, this.endpointLeaseRef, this.failureDomainRef, this.authorizedFrom,
      this.authorizedUntil, this.activeFlowsUntil, this.configPayload, this.transportFeature);
  final TransportProfileQuery query;
  final String candidateRef, profileSha256, endpointLeaseRef, failureDomainRef, configPayload;
  final RuntimeTransportFeature transportFeature;
  final int profileRevision;
  final DateTime authorizedFrom, authorizedUntil, activeFlowsUntil;

  static Future<TransportResolvedProfile> admit(Map<String, dynamic> response,
      {required Map<String, Object?> request, required TransportAdmission admission}) async {
    try {
      if (_canonical(response['request']) != _canonical(request)) {
        throw const FormatException();
      }
      final query = TransportProfileQuery(_transportMap(request['query']));
      query.requirePolicy(admission);
      for (final name in const ['candidate_ref', 'endpoint_lease_ref', 'failure_domain_ref']) {
        _transportRefs([response[name]], 1, 1);
      }
      final revision = _revision(response['profile_revision']);
      _transportDigest(response['profile_sha256']);
      final from = _time(response['authorized_from']), until = _time(response['authorized_until']);
      final active = _time(response['active_flows_until']);
      if (!from.isBefore(until) || until.isAfter(active) || active.isAfter(admission.effectiveExpiresAt) ||
          until.difference(from) > const Duration(minutes: 10) ||
          active.difference(from) > const Duration(hours: 1)) {
        throw const FormatException();
      }
      final config = response['config_payload'];
      if (config is! String || config.length > transportProfileMaximumBytes) throw const FormatException();
      final bytes = utf8.encode(config);
      if (bytes.length > transportProfileMaximumBytes) {
        throw const FormatException();
      }
      final decoded = jsonDecode(config);
      if (decoded is! Map<String, dynamic> || config != _canonical(decoded)) {
        throw const FormatException();
      }
      final feature = _resolvedTransportFeature(decoded);
      final binding = admission.capabilityBindings[query.fields['capability_ref']];
      if (binding == null || !binding.requiredFeatures.containsAll({
          RuntimeTransportFeature.atsLease, RuntimeTransportFeature.vless,
          RuntimeTransportFeature.tls, RuntimeTransportFeature.utls, feature})) {
        throw const FormatException();
      }
      final digest = (await Sha256().hash(bytes)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (digest != response['profile_sha256']) throw const FormatException();
      return TransportResolvedProfile._(query, response['candidate_ref'] as String, revision, digest,
        response['endpoint_lease_ref'] as String, response['failure_domain_ref'] as String,
        from, until, active, config, feature);
    } on Object {
      throw const TransportManifestFailure('transport_profile_binding_invalid');
    }
  }

  @override
  String toString() => 'TransportResolvedProfile(redacted)';
}
