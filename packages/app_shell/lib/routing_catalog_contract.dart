import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:pokrov_core_domain/core_domain.dart' show HostPlatform, RuntimeTransportFeature;

part 'smart_access_contract.dart';
part 'transport_manifest_contract.dart';
part 'transport_profile_resolution.dart';
part 'transport_payload_contract.dart';

const routingCatalogMaximumBytes = 1024 * 1024;
const _maximumRevision = 9007199254740991;

class RoutingCatalogFailure implements Exception {
  const RoutingCatalogFailure(this.code);
  final String code;

  @override
  String toString() => code;
}

/// Authenticated public catalog. This is not an entitlement or compiled policy.
/// Nested source/service assertions remain owned by the platform schema. A
/// policy compiler must validate the fields and capabilities that it consumes.
class VerifiedRoutingCatalog {
  const VerifiedRoutingCatalog._({
    required this.revision,
    required this.securityRevision,
    required this.payloadSha256,
    required this.issuedAt,
    required this.expiresAt,
    required this.envelope,
    required this.payload,
  });

  final int revision;
  final int securityRevision;
  final String payloadSha256;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final Map<String, Object?> envelope;
  final Map<String, Object?> payload;
}

class RoutingCatalogFetchResult {
  const RoutingCatalogFetchResult({required this.catalog, required this.usingCache});
  final VerifiedRoutingCatalog catalog;
  final bool usingCache;
}

class RoutingCatalogVerifier {
  RoutingCatalogVerifier({
    required Map<String, String> publicKeysById,
    required this.audience,
  }) : _publicKeysById = Map<String, String>.unmodifiable(publicKeysById);

  factory RoutingCatalogVerifier.pinned() {
    const keyId = String.fromEnvironment('POKROV_ROUTING_CATALOG_KEY_ID');
    const publicKey = String.fromEnvironment('POKROV_ROUTING_CATALOG_PUBLIC_KEY_B64');
    return RoutingCatalogVerifier(
      publicKeysById: keyId.isEmpty || publicKey.isEmpty
          ? const {}
          : const {keyId: publicKey},
      audience: const String.fromEnvironment(
        'POKROV_ROUTING_CATALOG_AUDIENCE', defaultValue: 'production',
      ),
    );
  }

  final Map<String, String> _publicKeysById;
  final String audience;
  bool get configured =>
      const {'lab', 'production'}.contains(audience) && _publicKeysById.isNotEmpty;

  Future<VerifiedRoutingCatalog> verify(
    Object? input, {
    required DateTime now,
    required int minimumRevision,
    required int minimumSecurityRevision,
    required String? currentPayloadSha256,
  }) async {
    try {
      if (!configured) throw const RoutingCatalogFailure('catalog_trust_unconfigured');
      if (minimumRevision < 0 || minimumRevision > _maximumRevision ||
          minimumSecurityRevision < 1 || minimumSecurityRevision > _maximumRevision) {
        throw const RoutingCatalogFailure('catalog_revision_floor_invalid');
      }
      // Snapshot before the first await: a caller cannot mutate signed data
      // while the digest/signature operation is in flight.
      final envelope = _freeze(input, 0);
      if (envelope is! Map<String, Object?>) {
        throw const RoutingCatalogFailure('catalog_envelope_invalid');
      }
      _keys(envelope, const {
        'algorithm', 'key_id', 'payload_sha256', 'payload', 'signature_b64',
      });
      final envelopeBytes = utf8.encode(_canonical(envelope));
      // The canonical platform output also contains a trailing newline.
      if (envelopeBytes.length + 1 > routingCatalogMaximumBytes) {
        throw const RoutingCatalogFailure('catalog_too_large');
      }
      if (envelope['algorithm'] != 'Ed25519') {
        throw const RoutingCatalogFailure('catalog_algorithm_invalid');
      }
      final payload = envelope['payload'];
      if (payload is! Map<String, Object?>) {
        throw const RoutingCatalogFailure('catalog_payload_invalid');
      }
      _keys(payload, const {
        'schema_version', 'revision', 'security_revision', 'audience',
        'issued_at', 'expires_at', 'sources', 'evidence', 'services',
      });
      if (payload['schema_version'] != 'pokrov-routing-catalog-v1') {
        throw const RoutingCatalogFailure('catalog_schema_unsupported');
      }
      if (payload['audience'] != audience) {
        throw const RoutingCatalogFailure('catalog_audience_mismatch');
      }
      final revision = _revision(payload['revision']);
      final securityRevision = _revision(payload['security_revision']);
      if (revision < minimumRevision || securityRevision < minimumSecurityRevision) {
        throw const RoutingCatalogFailure('catalog_rollback_rejected');
      }
      final issuedAt = _time(payload['issued_at']);
      final expiresAt = _time(payload['expires_at']);
      if (!expiresAt.isAfter(issuedAt) || now.toUtc().isBefore(issuedAt) ||
          !now.toUtc().isBefore(expiresAt)) {
        throw const RoutingCatalogFailure('catalog_not_current');
      }
      for (final (field, minimum, maximum) in const [
        ('sources', 1, 128), ('evidence', 0, 512), ('services', 1, 256),
      ]) {
        final rows = payload[field];
        if (rows is! List || rows.length < minimum || rows.length > maximum ||
            rows.any((row) => row is! Map<String, Object?>)) {
          throw const RoutingCatalogFailure('catalog_collection_invalid');
        }
      }
      final body = utf8.encode(_canonical(payload));
      final digest = (await Sha256().hash(body)).bytes
          .map((value) => value.toRadixString(16).padLeft(2, '0')).join();
      if (envelope['payload_sha256'] != digest) {
        throw const RoutingCatalogFailure('catalog_digest_mismatch');
      }
      if (revision == minimumRevision && currentPayloadSha256 != digest) {
        throw const RoutingCatalogFailure('catalog_same_revision_changed');
      }
      final keyId = envelope['key_id'];
      final encodedKey = keyId is String ? _publicKeysById[keyId] : null;
      if (encodedKey == null) throw const RoutingCatalogFailure('catalog_key_not_trusted');
      final publicKey = base64Decode(encodedKey);
      final encodedSignature = envelope['signature_b64'];
      if (publicKey.length != 32 || encodedSignature is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{86}$').hasMatch(encodedSignature)) {
        throw const RoutingCatalogFailure('catalog_signature_invalid');
      }
      final signature = base64Url.decode(base64Url.normalize(encodedSignature));
      if (signature.length != 64 || !await Ed25519().verify(
        [...utf8.encode('pokrov-routing-catalog-v1\n'), ...body],
        signature: Signature(signature,
          publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)),
      )) {
        throw const RoutingCatalogFailure('catalog_signature_invalid');
      }
      return VerifiedRoutingCatalog._(
        revision: revision, securityRevision: securityRevision,
        payloadSha256: digest, issuedAt: issuedAt, expiresAt: expiresAt,
        envelope: envelope, payload: payload,
      );
    } on RoutingCatalogFailure {
      rethrow;
    } on Object {
      throw const RoutingCatalogFailure('catalog_verification_failed');
    }
  }
}

void _keys(Map<String, Object?> value, Set<String> expected) {
  if (value.length != expected.length || !expected.containsAll(value.keys)) {
    throw const RoutingCatalogFailure('catalog_shape_invalid');
  }
}

int _revision(Object? value) {
  if (value is! int || value < 1 || value > _maximumRevision) {
    throw const RoutingCatalogFailure('catalog_revision_invalid');
  }
  return value;
}

DateTime _time(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$').hasMatch(value)) {
    throw const RoutingCatalogFailure('catalog_time_invalid');
  }
  final parsed = DateTime.parse(value);
  if (parsed.year < 1 || parsed.toIso8601String() != value.replaceFirst('Z', '.000Z')) {
    throw const RoutingCatalogFailure('catalog_time_invalid');
  }
  return parsed;
}

Object? _freeze(Object? value, int depth) {
  if (depth > 32) throw const RoutingCatalogFailure('catalog_nesting_invalid');
  if (value == null || value is bool || value is String) return value;
  if (value is int && value.abs() <= _maximumRevision) return value;
  if (value is List) {
    return List<Object?>.unmodifiable(value.map((item) => _freeze(item, depth + 1)));
  }
  if (value is Map<String, dynamic>) {
    if (value.keys.any((key) => !RegExp(r'^[a-z0-9_]+$').hasMatch(key))) {
      throw const RoutingCatalogFailure('catalog_field_invalid');
    }
    return Map<String, Object?>.unmodifiable(
      value.map((key, item) => MapEntry(key, _freeze(item, depth + 1))),
    );
  }
  throw const RoutingCatalogFailure('catalog_value_invalid');
}

/// Python json.dumps(sort_keys=True, ensure_ascii=True, separators=(',', ':'))
/// for the platform schema's string/bool/null/integer/list/object values.
String _canonical(Object? value) {
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return '{${keys.map((key) => '${_canonical(key)}:${_canonical(value[key])}').join(',')}}';
  }
  if (value is List) return '[${value.map(_canonical).join(',')}]';
  final encoded = jsonEncode(value);
  final result = StringBuffer();
  for (final unit in encoded.codeUnits) {
    if (unit >= 0x7f) {
      result.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
    } else {
      result.writeCharCode(unit);
    }
  }
  return result.toString();
}
