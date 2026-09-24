import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../routing_catalog_contract.dart';

/// Retains only public policy floors and the observed clock. No service
/// selections, issued grants, account/device IDs or provider URLs are stored.
class SmartAccessPolicyStore {
  SmartAccessPolicyStore({required this.verifier, required this.enabled,
    FlutterSecureStorage? storage, DateTime Function()? now})
    : _storage = storage ?? const FlutterSecureStorage(), _now = now ?? DateTime.now;

  factory SmartAccessPolicyStore.pinned() => SmartAccessPolicyStore(
    verifier: SmartAccessVerifier.pinned(), enabled: const bool.fromEnvironment('POKROV_SMART_ACCESS_ENABLED'));

  final SmartAccessVerifier verifier;
  final bool enabled;
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;
  bool get available => enabled && verifier.configured;
  String get _key => 'pokrov-smart-access-floors-${verifier.audience}-v1';
  static final Map<String, Future<void>> _queues = {};
  static final Map<String, int> _generations = {};
  int get generation => _generations[_key] ?? 0;
  void invalidate() => _generations[_key] = generation + 1;

  Future<VerifiedSmartAccessProviderPolicy> accept(Object? input, {required int expectedGeneration}) {
    final next = (_queues[_key] ?? Future<void>.value()).then((_) async {
      if (!available) throw const RoutingCatalogFailure('smart_access_disabled');
      void requireCurrent() {
        if (generation != expectedGeneration) throw const RoutingCatalogFailure('smart_access_fetch_superseded');
      }
      requireCurrent();
      try {
        final raw = await _storage.read(key: _key);
        var revision = 0;
        var security = 1;
        String? digest;
        final now = _now().toUtc();
        if (raw != null) {
          if (raw.length > 2048) throw const FormatException();
          final value = jsonDecode(raw);
          if (value is! Map<String, dynamic> || value.length != 5 || value['version'] != 1 ||
              value['revision'] is! int || value['security_revision'] is! int ||
              value['payload_sha256'] is! String || value['last_observed_at'] is! String) throw const FormatException();
          revision = value['revision'] as int;
          security = value['security_revision'] as int;
          digest = value['payload_sha256'] as String;
          if (revision < 1 || revision > 9007199254740991 || security < 1 || security > 9007199254740991 ||
              !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) throw const FormatException();
          final observed = DateTime.parse(value['last_observed_at'] as String);
          if (!observed.isUtc || now.isBefore(observed)) throw const RoutingCatalogFailure('smart_access_clock_rollback');
        }
        final verified = await verifier.verifyProvider(input, now: now, minimumRevision: revision,
          minimumSecurityRevision: security, currentPayloadSha256: digest);
        requireCurrent();
        final completedAt = _now().toUtc();
        if (completedAt.isBefore(now) || !completedAt.isBefore(verified.expiresAt)) {
          throw const RoutingCatalogFailure('smart_access_policy_not_current');
        }
        await _storage.write(key: _key, value: jsonEncode({
          'version': 1, 'revision': verified.revision, 'security_revision': verified.securityRevision,
          'payload_sha256': verified.payloadSha256, 'last_observed_at': completedAt.toIso8601String(),
        }));
        requireCurrent();
        return verified;
      } on RoutingCatalogFailure { rethrow; }
        on Object { throw const RoutingCatalogFailure('smart_access_storage_unavailable'); }
    });
    _queues[_key] = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }
}
