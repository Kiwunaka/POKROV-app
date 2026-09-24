import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../routing_catalog_contract.dart';
import '../../../routing_catalog_policy.dart';

/// One last accepted public catalog plus retained monotonic floors. These
/// records contain no account, install ID, package inventory or credentials.
class RoutingCatalogStore {
  RoutingCatalogStore({
    required this.verifier,
    required this.enabled,
    FlutterSecureStorage? storage,
    DateTime Function()? now,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _now = now ?? DateTime.now;

  factory RoutingCatalogStore.pinned() => RoutingCatalogStore(
    verifier: RoutingCatalogVerifier.pinned(),
    enabled: const bool.fromEnvironment('POKROV_ROUTING_CATALOG_ENABLED'),
  );

  final RoutingCatalogVerifier verifier;
  final bool enabled;
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;
  bool get available => enabled && verifier.configured;
  String get _key => 'pokrov-routing-catalog-${verifier.audience}-v1';

  // Serialize all store instances in the app isolate, not just one HTTP flight.
  // A slow old response therefore cannot overwrite a newer retained floor.
  static final Map<String, Future<void>> _queues = {};
  static final Set<String> _suspended = {};
  static final Map<String, int> _invalidations = {};
  int get invalidationGeneration => _invalidations[_key] ?? 0;

  void _requireGeneration(int expected) {
    if (invalidationGeneration != expected) {
      throw const RoutingCatalogFailure('catalog_fetch_superseded');
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    if (!available) {
      return Future<T>.error(const RoutingCatalogFailure('catalog_disabled'));
    }
    final next = (_queues[_key] ?? Future<void>.value()).then((_) => operation());
    _queues[_key] = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<Map<String, dynamic>> _load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) {
      return {
        'version': 1, 'revision': 0, 'security_revision': 1,
        'payload_sha256': null, 'last_observed_at': _now().toUtc().toIso8601String(),
        'envelope': null,
      };
    }
    if (raw.length > routingCatalogMaximumBytes + 4096 ||
        utf8.encode(raw).length > routingCatalogMaximumBytes + 4096) {
      throw const RoutingCatalogFailure('catalog_cache_invalid');
    }
    Object? value;
    try {
      value = jsonDecode(raw);
    } on FormatException {
      throw const RoutingCatalogFailure('catalog_cache_invalid');
    }
    const keys = {
      'version', 'revision', 'security_revision', 'payload_sha256',
      'last_observed_at', 'envelope',
    };
    if (value is! Map<String, dynamic> || value.length != keys.length ||
        !keys.containsAll(value.keys) || value['version'] is! int ||
        value['version'] != 1 || value['revision'] is! int ||
        value['revision'] < 0 || value['revision'] > 9007199254740991 ||
        value['security_revision'] is! int || value['security_revision'] < 1 ||
        value['security_revision'] > 9007199254740991 ||
        value['last_observed_at'] is! String ||
        (value['envelope'] != null && value['envelope'] is! Map<String, dynamic>)) {
      throw const RoutingCatalogFailure('catalog_cache_invalid');
    }
    final digest = value['payload_sha256'];
    if ((value['revision'] == 0 && (digest != null || value['envelope'] != null)) ||
        (value['revision'] > 0 && (digest is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)))) {
      throw const RoutingCatalogFailure('catalog_cache_invalid');
    }
    return value;
  }

  Future<void> _write(Map<String, dynamic> value) async {
    final raw = jsonEncode(value);
    if (utf8.encode(raw).length > routingCatalogMaximumBytes + 4096) {
      throw const RoutingCatalogFailure('catalog_cache_too_large');
    }
    await _storage.write(key: _key, value: raw);
  }

  Future<DateTime> _observe(Map<String, dynamic> value) async {
    final previous = DateTime.tryParse(value['last_observed_at'] as String);
    final now = _now().toUtc();
    if (previous == null || !previous.isUtc || now.isBefore(previous)) {
      throw const RoutingCatalogFailure('catalog_clock_rollback');
    }
    // Even an expired/revoked read advances this timestamp. Clock rollback must
    // not revive policy after restart. An unreadable/future record is untouched.
    value['last_observed_at'] = now.toIso8601String();
    await _write(value);
    return now;
  }

  Future<VerifiedRoutingCatalog?> read() => _serialize(() async {
    if (_suspended.contains(_key)) return null;
    final value = await _load();
    final now = await _observe(value);
    if (value['envelope'] == null) return null;
    try {
      final catalog = await verifier.verify(
        value['envelope'], now: now,
        minimumRevision: value['revision'] as int,
        minimumSecurityRevision: value['security_revision'] as int,
        currentPayloadSha256: value['payload_sha256'] as String?,
      );
      RoutingCatalogPolicy.fromVerified(catalog);
      if (catalog.revision != value['revision'] ||
          catalog.securityRevision != value['security_revision'] ||
          _suspended.contains(_key) ||
          _now().toUtc().isBefore(now) ||
          !catalog.expiresAt.isAfter(_now().toUtc())) return null;
      return catalog;
    } on RoutingCatalogFailure {
      // Preserve revision/digest floors and retained bytes on expiry/revocation.
      return null;
    }
  });

  Future<VerifiedRoutingCatalog> accept(Object? envelope, {
    required int expectedGeneration,
  }) => _serialize(() async {
    _requireGeneration(expectedGeneration);
    final value = await _load();
    final now = await _observe(value);
    final catalog = await verifier.verify(
      envelope, now: now,
      minimumRevision: value['revision'] as int,
      minimumSecurityRevision: value['security_revision'] as int,
      currentPayloadSha256: value['payload_sha256'] as String?,
    );
    // Projection failure must not promote revision floors or replace the LKG.
    RoutingCatalogPolicy.fromVerified(catalog);
    if (_now().toUtc().isBefore(now)) {
      throw const RoutingCatalogFailure('catalog_clock_rollback');
    }
    if (!catalog.expiresAt.isAfter(_now().toUtc())) {
      throw const RoutingCatalogFailure('catalog_not_current');
    }
    _requireGeneration(expectedGeneration);
    value.addAll({
      'revision': catalog.revision, 'security_revision': catalog.securityRevision,
      'payload_sha256': catalog.payloadSha256, 'envelope': catalog.envelope,
    });
    await _write(value);
    _requireGeneration(expectedGeneration);
    _suspended.remove(_key);
    return catalog;
  });

  /// Stops local reuse after a known denial/disable; never erases rollback floors.
  Future<void> discardEnvelope() {
    if (!available) {
      return Future<void>.error(const RoutingCatalogFailure('catalog_disabled'));
    }
    // Invalidate at invocation, before waiting for a preceding crypto/write.
    // A successful response that started before this denial cannot reactivate it.
    _invalidations[_key] = invalidationGeneration + 1;
    // A failed durable write still prevents reuse for this app process.
    _suspended.add(_key);
    return _serialize(() async {
      final value = await _load();
      await _observe(value);
      value['envelope'] = null;
      await _write(value);
    });
  }
}
