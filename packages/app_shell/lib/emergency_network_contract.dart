import 'dart:convert';

import 'package:cryptography/cryptography.dart';

enum EmergencyChainMode {
  reserveDirect('reserve_direct', 'Быстрый выход'),
  reserveForeign('reserve_foreign', 'Через POKROV'),
  reserveRuForeign('reserve_ru_foreign', 'Усиленная цепочка');

  const EmergencyChainMode(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static EmergencyChainMode? tryParse(Object? value) {
    final wire = value?.toString().trim().toLowerCase() ?? '';
    for (final mode in values) {
      if (mode.wireValue == wire) {
        return mode;
      }
    }
    return null;
  }
}

enum EmergencyReserveStatus {
  working,
  checking,
  unavailable,
  stale;

  static EmergencyReserveStatus? tryParse(Object? value) {
    final wire = value?.toString().trim().toLowerCase() ?? '';
    for (final status in values) {
      if (status.name == wire) {
        return status;
      }
    }
    return null;
  }
}

enum EmergencyVerificationLevel {
  ordinary,
  syntheticBs,
  realBs;

  static EmergencyVerificationLevel? tryParse(Object? value) =>
      switch (value?.toString().trim().toLowerCase() ?? '') {
        'ordinary' => ordinary,
        'synthetic_bs' => syntheticBs,
        'real_bs' => realBs,
        _ => null,
      };
}

class EmergencyContractFailure implements Exception {
  const EmergencyContractFailure(this.code);

  final String code;

  @override
  String toString() => code;
}

class EmergencyReserve {
  const EmergencyReserve({
    required this.id,
    required this.ordinal,
    required this.countryCode,
    required this.transport,
    required this.status,
    required this.latencyMs,
    required this.checkedAt,
    required this.verification,
    required this.verificationAt,
    required this.modes,
  });

  final String id;
  final int ordinal;
  final String countryCode;
  final String transport;
  final EmergencyReserveStatus status;
  final int? latencyMs;
  final DateTime? checkedAt;
  final EmergencyVerificationLevel verification;
  final DateTime? verificationAt;
  final List<EmergencyChainMode> modes;

  bool get available =>
      status == EmergencyReserveStatus.working ||
      status == EmergencyReserveStatus.stale;
}

class EmergencyCatalog {
  const EmergencyCatalog({
    required this.revision,
    required this.issuedAt,
    required this.refreshAfter,
    required this.validUntil,
    required this.offlineValidUntil,
    required this.deviceBinding,
    required this.accessState,
    required this.accessExpiresAt,
    required this.eligibilitySource,
    required this.eligibilityCountryCode,
    required this.eligibilityValidUntil,
    required this.disclosureRevision,
    required this.items,
    required this.envelope,
  });

  final String revision;
  final DateTime issuedAt;
  final DateTime refreshAfter;
  final DateTime validUntil;
  final DateTime offlineValidUntil;
  final String deviceBinding;
  final String accessState;
  final DateTime accessExpiresAt;
  final String eligibilitySource;
  final String eligibilityCountryCode;
  final DateTime eligibilityValidUntil;
  final String disclosureRevision;
  final List<EmergencyReserve> items;
  final Map<String, dynamic> envelope;

  bool get canUseOffline => offlineValidUntil.isAfter(DateTime.now().toUtc());
}

class EmergencyProfile {
  const EmergencyProfile({
    required this.catalogRevision,
    required this.profileRevision,
    required this.issuedAt,
    required this.offlineValidUntil,
    required this.deviceBinding,
    required this.reserveId,
    required this.chainMode,
    required this.accessState,
    required this.configPayload,
    required this.envelope,
  });

  final String catalogRevision;
  final String profileRevision;
  final DateTime issuedAt;
  final DateTime offlineValidUntil;
  final String deviceBinding;
  final String reserveId;
  final EmergencyChainMode chainMode;
  final String accessState;
  final Map<String, dynamic> configPayload;
  final Map<String, dynamic> envelope;
}

class EmergencyEnvelopeVerifier {
  EmergencyEnvelopeVerifier({
    required Map<String, String> publicKeysById,
    Ed25519? algorithm,
  })  : _publicKeysById = Map<String, String>.unmodifiable(publicKeysById),
        _algorithm = algorithm ?? Ed25519();

  static const defaultKeyId = String.fromEnvironment(
    'POKROV_EMERGENCY_SIGNING_KEY_ID',
    defaultValue: 'emergency-2026-01',
  );
  static const defaultPublicKey = String.fromEnvironment(
    'POKROV_EMERGENCY_SIGNING_PUBLIC_KEY_B64',
    defaultValue: '',
  );

  factory EmergencyEnvelopeVerifier.pinned() => EmergencyEnvelopeVerifier(
        publicKeysById: defaultPublicKey.trim().isEmpty
            ? const <String, String>{}
            : const <String, String>{defaultKeyId: defaultPublicKey},
      );

  final Map<String, String> _publicKeysById;
  final Ed25519 _algorithm;

  Future<Map<String, dynamic>> verifyEnvelope(
    Object? rawEnvelope, {
    required int maximumPayloadBytes,
  }) async {
    final envelope = _map(rawEnvelope, 'envelope_invalid');
    _expectKeys(
      envelope,
      const <String>{
        'schema_version',
        'algorithm',
        'key_id',
        'payload_b64',
        'signature_b64',
      },
      'envelope_shape_invalid',
    );
    if (_integer(envelope['schema_version'], 'envelope_version_invalid') != 1 ||
        _text(envelope['algorithm']) != 'Ed25519') {
      throw const EmergencyContractFailure('envelope_algorithm_invalid');
    }
    final keyId = _text(envelope['key_id']);
    final publicKeyEncoded = _publicKeysById[keyId];
    if (publicKeyEncoded == null) {
      throw const EmergencyContractFailure('envelope_key_unknown');
    }
    final payload = _decodeBase64Url(
      _text(envelope['payload_b64']),
      maximumBytes: maximumPayloadBytes,
      exactBytes: null,
      code: 'envelope_payload_invalid',
    );
    final signatureBytes = _decodeBase64Url(
      _text(envelope['signature_b64']),
      maximumBytes: 64,
      exactBytes: 64,
      code: 'envelope_signature_invalid',
    );
    final publicKeyBytes = _decodeBase64Url(
      publicKeyEncoded,
      maximumBytes: 32,
      exactBytes: 32,
      code: 'envelope_public_key_invalid',
    );
    final verified = await _algorithm.verify(
      payload,
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
      ),
    );
    if (!verified) {
      throw const EmergencyContractFailure('envelope_signature_invalid');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payload, allowMalformed: false));
    } on Object {
      throw const EmergencyContractFailure('envelope_payload_invalid');
    }
    return _map(decoded, 'envelope_payload_invalid');
  }

  Future<String> deviceBinding(String installId) async {
    final normalized = installId.trim();
    if (normalized.length < 8 || normalized.length > 128) {
      throw const EmergencyContractFailure('install_id_invalid');
    }
    final bytes = <int>[
      ...utf8.encode('pokrov-emergency-device-binding-v1\u0000'),
      ...utf8.encode(normalized),
    ];
    final digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<EmergencyCatalog> parseCatalog(
    Object? envelope, {
    required String installId,
    DateTime? now,
  }) async {
    final payload =
        await verifyEnvelope(envelope, maximumPayloadBytes: 256 * 1024);
    _expectKeys(
      payload,
      const <String>{
        'type',
        'schema_version',
        'catalog_revision',
        'issued_at',
        'refresh_after',
        'valid_until',
        'offline_valid_until',
        'device_binding',
        'access',
        'eligibility',
        'disclosure_revision',
        'items',
      },
      'catalog_shape_invalid',
    );
    if (_text(payload['type']) != 'pokrov.emergency.catalog' ||
        _integer(payload['schema_version'], 'catalog_version_invalid') != 1) {
      throw const EmergencyContractFailure('catalog_version_invalid');
    }
    final binding = _text(payload['device_binding']);
    if (binding != await deviceBinding(installId)) {
      throw const EmergencyContractFailure('catalog_device_mismatch');
    }
    final current = (now ?? DateTime.now()).toUtc();
    final issuedAt = _time(payload['issued_at'], 'catalog_time_invalid');
    final refreshAfter =
        _time(payload['refresh_after'], 'catalog_time_invalid');
    final validUntil = _time(payload['valid_until'], 'catalog_time_invalid');
    final offlineValidUntil =
        _time(payload['offline_valid_until'], 'catalog_time_invalid');
    if (issuedAt.isAfter(current.add(const Duration(minutes: 5))) ||
        !refreshAfter.isAfter(issuedAt) ||
        !validUntil.isAfter(current) ||
        !offlineValidUntil.isAfter(current) ||
        offlineValidUntil.isAfter(validUntil)) {
      throw const EmergencyContractFailure('catalog_expired');
    }
    final access = _map(payload['access'], 'catalog_access_invalid');
    _expectKeys(
        access, const {'state', 'expires_at'}, 'catalog_access_invalid');
    final accessState = _text(access['state']);
    if (!const {'trial_premium', 'paid_unlimited'}.contains(accessState)) {
      throw const EmergencyContractFailure('catalog_access_denied');
    }
    final accessExpiry = _time(access['expires_at'], 'catalog_access_invalid');
    final eligibility =
        _map(payload['eligibility'], 'catalog_eligibility_invalid');
    _expectKeys(
      eligibility,
      const {'eligible', 'source', 'country_code', 'valid_until'},
      'catalog_eligibility_invalid',
    );
    if (eligibility['eligible'] is! bool || eligibility['eligible'] != true) {
      throw const EmergencyContractFailure('catalog_eligibility_denied');
    }
    final eligibilityExpiry =
        _time(eligibility['valid_until'], 'catalog_eligibility_invalid');
    if (offlineValidUntil.isAfter(accessExpiry) ||
        offlineValidUntil.isAfter(eligibilityExpiry)) {
      throw const EmergencyContractFailure('catalog_lease_invalid');
    }
    final rawItems = payload['items'];
    if (rawItems is! List || rawItems.length < 4 || rawItems.length > 12) {
      throw const EmergencyContractFailure('catalog_items_invalid');
    }
    final items = <EmergencyReserve>[];
    final ids = <String>{};
    for (final rawItem in rawItems) {
      final item = _map(rawItem, 'catalog_item_invalid');
      _expectKeys(
        item,
        const {
          'id',
          'ordinal',
          'country_code',
          'transport',
          'status',
          'latency_ms',
          'latency_source',
          'checked_at',
          'verification',
          'verification_at',
          'modes',
        },
        'catalog_item_invalid',
      );
      final id = _text(item['id']);
      final status = EmergencyReserveStatus.tryParse(item['status']);
      final verification =
          EmergencyVerificationLevel.tryParse(item['verification']);
      final rawModes = item['modes'];
      if (!RegExp(r'^emg_[a-f0-9]{24}$').hasMatch(id) ||
          !ids.add(id) ||
          status == null ||
          verification == null ||
          rawModes is! List ||
          rawModes.isEmpty ||
          _text(item['latency_source']) != 'server_probe') {
        throw const EmergencyContractFailure('catalog_item_invalid');
      }
      final modes =
          rawModes.map(EmergencyChainMode.tryParse).toList(growable: false);
      if (modes.any((mode) => mode == null) ||
          modes.toSet().length != modes.length) {
        throw const EmergencyContractFailure('catalog_item_invalid');
      }
      final countryCode = _text(item['country_code']);
      final transport = _text(item['transport']);
      if (!RegExp(r'^[A-Z]{2}$').hasMatch(countryCode) ||
          !const {'tcp', 'grpc'}.contains(transport)) {
        throw const EmergencyContractFailure('catalog_item_invalid');
      }
      final latency = item['latency_ms'] == null
          ? null
          : _integer(item['latency_ms'], 'catalog_item_invalid');
      if (latency != null && (latency < 0 || latency > 60000)) {
        throw const EmergencyContractFailure('catalog_item_invalid');
      }
      items.add(
        EmergencyReserve(
          id: id,
          ordinal: _integer(item['ordinal'], 'catalog_item_invalid'),
          countryCode: countryCode,
          transport: transport,
          status: status,
          latencyMs: latency,
          checkedAt: _nullableTime(item['checked_at'], 'catalog_item_invalid'),
          verification: verification,
          verificationAt:
              _nullableTime(item['verification_at'], 'catalog_item_invalid'),
          modes: modes.cast<EmergencyChainMode>(),
        ),
      );
    }
    return EmergencyCatalog(
      revision: _text(payload['catalog_revision']),
      issuedAt: issuedAt,
      refreshAfter: refreshAfter,
      validUntil: validUntil,
      offlineValidUntil: offlineValidUntil,
      deviceBinding: binding,
      accessState: accessState,
      accessExpiresAt: accessExpiry,
      eligibilitySource: _text(eligibility['source']),
      eligibilityCountryCode: _text(eligibility['country_code']),
      eligibilityValidUntil: eligibilityExpiry,
      disclosureRevision: _text(payload['disclosure_revision']),
      items: List<EmergencyReserve>.unmodifiable(items),
      envelope:
          Map<String, dynamic>.unmodifiable(_map(envelope, 'envelope_invalid')),
    );
  }

  Future<EmergencyProfile> parseProfile(
    Object? envelope, {
    required String installId,
    required String catalogRevision,
    required String reserveId,
    required EmergencyChainMode chainMode,
    DateTime? now,
  }) async {
    final payload =
        await verifyEnvelope(envelope, maximumPayloadBytes: 8 * 1024 * 1024);
    _expectKeys(
      payload,
      const <String>{
        'type',
        'schema_version',
        'catalog_revision',
        'profile_revision',
        'issued_at',
        'offline_valid_until',
        'device_binding',
        'reserve_id',
        'chain_mode',
        'route_scope',
        'access_state',
        'access_expires_at',
        'eligibility_valid_until',
        'warp',
        'quick_settings_eligible',
        'config_format',
        'config_payload',
      },
      'profile_shape_invalid',
    );
    if (_text(payload['type']) != 'pokrov.emergency.profile' ||
        _integer(payload['schema_version'], 'profile_version_invalid') != 1 ||
        _text(payload['catalog_revision']) != catalogRevision ||
        _text(payload['reserve_id']) != reserveId ||
        EmergencyChainMode.tryParse(payload['chain_mode']) != chainMode ||
        _text(payload['route_scope']) != 'all_except_ru' ||
        payload['warp'] != false ||
        payload['quick_settings_eligible'] != false ||
        _text(payload['config_format']) != 'singbox-json') {
      throw const EmergencyContractFailure('profile_contract_invalid');
    }
    final binding = _text(payload['device_binding']);
    if (binding != await deviceBinding(installId)) {
      throw const EmergencyContractFailure('profile_device_mismatch');
    }
    final current = (now ?? DateTime.now()).toUtc();
    final issuedAt = _time(payload['issued_at'], 'profile_time_invalid');
    final offlineValidUntil =
        _time(payload['offline_valid_until'], 'profile_time_invalid');
    final accessExpiry =
        _time(payload['access_expires_at'], 'profile_time_invalid');
    final eligibilityExpiry =
        _time(payload['eligibility_valid_until'], 'profile_time_invalid');
    if (!offlineValidUntil.isAfter(current) ||
        offlineValidUntil.isAfter(accessExpiry) ||
        offlineValidUntil.isAfter(eligibilityExpiry)) {
      throw const EmergencyContractFailure('profile_expired');
    }
    final accessState = _text(payload['access_state']);
    if (!const {'trial_premium', 'paid_unlimited'}.contains(accessState)) {
      throw const EmergencyContractFailure('profile_access_denied');
    }
    final config = _map(payload['config_payload'], 'profile_config_invalid');
    _validateConfig(config, chainMode);
    return EmergencyProfile(
      catalogRevision: catalogRevision,
      profileRevision: _text(payload['profile_revision']),
      issuedAt: issuedAt,
      offlineValidUntil: offlineValidUntil,
      deviceBinding: binding,
      reserveId: reserveId,
      chainMode: chainMode,
      accessState: accessState,
      configPayload: Map<String, dynamic>.unmodifiable(config),
      envelope:
          Map<String, dynamic>.unmodifiable(_map(envelope, 'envelope_invalid')),
    );
  }

  void _validateConfig(
    Map<String, dynamic> config,
    EmergencyChainMode chainMode,
  ) {
    final outbounds = config['outbounds'];
    final route = _map(config['route'], 'profile_config_invalid');
    if (outbounds is! List) {
      throw const EmergencyContractFailure('profile_config_invalid');
    }
    final tags = <String>{};
    final proxies = <String>{};
    final detours = <String, String>{};
    final auxiliaryOutbounds = <String, String>{};
    for (final raw in outbounds) {
      final outbound = _map(raw, 'profile_config_invalid');
      final tag = _text(outbound['tag']);
      if (tag.isEmpty || !tags.add(tag)) {
        throw const EmergencyContractFailure('profile_config_invalid');
      }
      if (_text(outbound['type']) == 'vless') {
        final server = _text(outbound['server']);
        final serverPort = outbound['server_port'];
        final tls = _mapOrEmpty(outbound['tls']);
        final reality = _mapOrEmpty(tls['reality']);
        if (server.isEmpty ||
            serverPort is! int ||
            serverPort < 1 ||
            serverPort > 65535 ||
            _text(outbound['uuid']).isEmpty ||
            tls['enabled'] != true ||
            reality['enabled'] != true ||
            tls['insecure'] == true) {
          throw const EmergencyContractFailure('profile_outbound_invalid');
        }
        proxies.add(tag);
        final detour = _text(outbound['detour']);
        if (detour.isNotEmpty) {
          if (outbound.containsKey('domain_resolver')) {
            throw const EmergencyContractFailure('profile_detour_dns_invalid');
          }
          detours[tag] = detour;
        }
        final transport = _mapOrEmpty(outbound['transport']);
        if (_text(transport['type']) == 'grpc' &&
            outbound.containsKey('flow')) {
          throw const EmergencyContractFailure('profile_grpc_flow_invalid');
        }
      } else {
        auxiliaryOutbounds[tag] = _text(outbound['type']);
      }
    }
    for (final entry in detours.entries) {
      if (!proxies.contains(entry.value) || entry.key == entry.value) {
        throw const EmergencyContractFailure('profile_detour_invalid');
      }
      var cursor = entry.key;
      var depth = 1;
      final visited = <String>{};
      while (detours.containsKey(cursor)) {
        if (!visited.add(cursor)) {
          throw const EmergencyContractFailure('profile_detour_cycle');
        }
        cursor = detours[cursor]!;
        depth += 1;
        if (depth > 3) {
          throw const EmergencyContractFailure('profile_detour_depth_invalid');
        }
      }
    }
    final expectedProxies = switch (chainMode) {
      EmergencyChainMode.reserveDirect => const <String>{
          'POKROV emergency reserve',
        },
      EmergencyChainMode.reserveForeign => const <String>{
          'POKROV emergency reserve',
          'POKROV owned foreign',
        },
      EmergencyChainMode.reserveRuForeign => const <String>{
          'POKROV emergency reserve',
          'POKROV owned RU',
          'POKROV owned foreign',
        },
    };
    final expectedDetours = switch (chainMode) {
      EmergencyChainMode.reserveDirect => const <String, String>{},
      EmergencyChainMode.reserveForeign => const <String, String>{
          'POKROV owned foreign': 'POKROV emergency reserve',
        },
      EmergencyChainMode.reserveRuForeign => const <String, String>{
          'POKROV owned RU': 'POKROV emergency reserve',
          'POKROV owned foreign': 'POKROV owned RU',
        },
    };
    final expectedFinal = chainMode == EmergencyChainMode.reserveDirect
        ? 'POKROV emergency reserve'
        : 'POKROV owned foreign';
    final sameProxies = proxies.length == expectedProxies.length &&
        proxies.every(expectedProxies.contains);
    final sameDetours = detours.length == expectedDetours.length &&
        detours.entries.every(
          (entry) => expectedDetours[entry.key] == entry.value,
        );
    final meta = _map(config['_meta'], 'profile_config_invalid');
    if (!sameProxies ||
        !sameDetours ||
        !_sameStringMap(
          auxiliaryOutbounds,
          const <String, String>{
            'direct': 'direct',
            'block': 'block',
            'dns-out': 'dns',
          },
        ) ||
        _text(route['final']) != expectedFinal ||
        meta['emergency'] != true ||
        _text(meta['chain_mode']) != chainMode.wireValue ||
        _text(meta['route_scope']) != 'all_except_ru' ||
        meta['quick_settings_eligible'] != false ||
        meta['warp'] != false ||
        _containsWarp(config)) {
      throw const EmergencyContractFailure('profile_config_invalid');
    }

    final ruleSets = route['rule_set'];
    final rules = route['rules'];
    if (ruleSets is! List ||
        ruleSets.length != 1 ||
        rules is! List ||
        ruleSets.first is! Map) {
      throw const EmergencyContractFailure('profile_ru_route_invalid');
    }
    final ruleSet = _map(ruleSets.first, 'profile_ru_route_invalid');
    final uri = Uri.tryParse(_text(ruleSet['url']));
    const expectedRules = <Map<String, Object>>[
      <String, Object>{
        'rule_set': <String>['geoip-ru'],
        'outbound': 'direct',
      },
      <String, Object>{'protocol': 'dns', 'outbound': 'dns-out'},
      <String, Object>{'ip_is_private': true, 'outbound': 'direct'},
    ];
    if (ruleSet['type'] != 'remote' ||
        ruleSet['tag'] != 'geoip-ru' ||
        ruleSet['format'] != 'binary' ||
        ruleSet['download_detour'] != expectedFinal ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'connect.pokrov.space' ||
        (uri.hasPort && uri.port != 443) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != '/rules/geoip-ru.srs' ||
        !_sameJsonList(rules, expectedRules)) {
      throw const EmergencyContractFailure('profile_ru_route_invalid');
    }

    final dns = _map(config['dns'], 'profile_dns_route_invalid');
    final dnsServers = dns['servers'];
    final expectedDnsServers = <Map<String, Object>>[
      <String, Object>{'tag': 'bootstrap', 'address': 'local'},
      <String, Object>{
        'tag': 'emergency-dns',
        'address': 'https://1.1.1.1/dns-query',
        'detour': expectedFinal,
      },
    ];
    if (dns['final'] != 'emergency-dns' ||
        !_sameJsonList(dnsServers, expectedDnsServers)) {
      throw const EmergencyContractFailure('profile_dns_route_invalid');
    }
  }
}

bool _sameStringMap(Map<String, String> left, Map<String, String> right) =>
    left.length == right.length &&
    left.entries.every((entry) => right[entry.key] == entry.value);

bool _sameJsonList(Object? left, List<Map<String, Object>> right) {
  if (left is! List || left.length != right.length) {
    return false;
  }
  for (var index = 0; index < right.length; index += 1) {
    final actual = _mapOrEmpty(left[index]);
    final expected = right[index];
    if (!_sameJsonValue(actual, expected)) {
      return false;
    }
  }
  return true;
}

bool _sameJsonValue(Object? left, Object? right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_sameJsonValue(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (!_sameJsonValue(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

bool _containsWarp(Object? value, {bool insideMeta = false}) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      if (key == 'warp') {
        if (insideMeta && entry.value == false) {
          continue;
        }
        return true;
      }
      if (_containsWarp(entry.value,
          insideMeta: insideMeta || key == '_meta')) {
        return true;
      }
    }
  } else if (value is List) {
    return value.any((item) => _containsWarp(item, insideMeta: insideMeta));
  }
  return false;
}

Map<String, dynamic> _map(Object? value, String code) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw EmergencyContractFailure(code);
}

Map<String, dynamic> _mapOrEmpty(Object? value) =>
    value is Map ? _map(value, 'profile_config_invalid') : <String, dynamic>{};

void _expectKeys(
    Map<String, dynamic> value, Set<String> expected, String code) {
  if (value.keys.toSet().length != expected.length ||
      !value.keys.toSet().containsAll(expected)) {
    throw EmergencyContractFailure(code);
  }
}

String _text(Object? value) => value?.toString().trim() ?? '';

int _integer(Object? value, String code) {
  if (value is int) {
    return value;
  }
  throw EmergencyContractFailure(code);
}

DateTime _time(Object? value, String code) {
  final parsed = DateTime.tryParse(_text(value));
  if (parsed == null || !parsed.isUtc) {
    throw EmergencyContractFailure(code);
  }
  return parsed.toUtc();
}

DateTime? _nullableTime(Object? value, String code) =>
    value == null ? null : _time(value, code);

List<int> _decodeBase64Url(
  String value, {
  required int maximumBytes,
  required int? exactBytes,
  required String code,
}) {
  if (value.isEmpty || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw EmergencyContractFailure(code);
  }
  try {
    final decoded = base64Url.decode(base64Url.normalize(value));
    if (decoded.isEmpty ||
        decoded.length > maximumBytes ||
        (exactBytes != null && decoded.length != exactBytes)) {
      throw EmergencyContractFailure(code);
    }
    return decoded;
  } on EmergencyContractFailure {
    rethrow;
  } on Object {
    throw EmergencyContractFailure(code);
  }
}
