import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../routing_catalog_contract.dart';
import '../../../smart_access_profile.dart';
import '../../../catalog_runtime_identity.dart';

class StoredSmartAccessRuntime {
  const StoredSmartAccessRuntime(this.binding, this.decisions,
      {this.catalogRevoked = false, this.catalogWithdrawn = false, this.catalogServiceRevocations = const {}});
  final SmartAccessRuntimeLeases binding;
  final Map<String, SmartAccessLeaseRevocation> decisions;
  final bool catalogRevoked;
  final bool catalogWithdrawn;
  final Set<String> catalogServiceRevocations;
}

class NativeSmartAccessRestriction {
  const NativeSmartAccessRestriction({required this.profileDigest, required this.catalogSha256,
    required this.policyAction, required this.catalogWithdrawn, required this.recoveryRequired,
    required this.scopeActions, this.expiresAt});
  final String profileDigest;
  final String catalogSha256;
  final String policyAction;
  final bool catalogWithdrawn;
  final bool recoveryRequired;
  final Map<String, String> scopeActions;
  final DateTime? expiresAt;
  bool get blocksProfile => policyAction != 'none' || catalogWithdrawn || recoveryRequired;
  bool get restricted => blocksProfile || scopeActions.isNotEmpty;
  bool affectsCatalog(String? digest) => digest != null && (catalogWithdrawn || recoveryRequired) &&
      (catalogSha256.isEmpty || catalogSha256 == digest);
  Map<String, Object?> toStored() => {'profile_digest': profileDigest, 'catalog_sha256': catalogSha256,
    'policy_action': policyAction, 'catalog_withdrawn': catalogWithdrawn, 'recovery_required': recoveryRequired,
    'expires_at': expiresAt?.toUtc().toIso8601String(), 'scope_actions': scopeActions};
}

class RetainedSmartAccessNativeJournal {
  const RetainedSmartAccessNativeJournal(this.snapshotSha256, this.restrictions,
    {required this.hasLiveWorker, required this.bindings});
  final String snapshotSha256;
  final List<NativeSmartAccessRestriction> restrictions;
  final bool hasLiveWorker;
  final List<StoredSmartAccessRuntime> bindings;
}

/// Three lease-inventory slots: running, native staged, and prepared next stage.
/// Native restrictions have a separate bounded ledger and survive slot reuse.
/// Nothing read here is a VerifiedSmartAccessLease or can authorize a route.
class SmartAccessRuntimeStore {
  SmartAccessRuntimeStore({required this.platform,
    this.audience = const String.fromEnvironment('POKROV_SMART_ACCESS_AUDIENCE', defaultValue: 'production'),
    FlutterSecureStorage? storage, DateTime Function()? now})
      : _storage = storage ?? const FlutterSecureStorage(), _now = now ?? DateTime.now;

  final String platform;
  final String audience;
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;
  static final Map<String, Future<void>> _queues = {};
  String get _key => 'pokrov-smart-access-runtime-$platform-$audience-v1';
  String get _nativeKey => 'pokrov-smart-access-native-restrictions-$platform-$audience-v1';

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final next = (_queues[_key] ?? Future<void>.value()).then((_) => operation());
    _queues[_key] = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Never _invalid() => throw const RoutingCatalogFailure('smart_access_runtime_storage_invalid');

  StoredSmartAccessRuntime _entry(Object? value) {
    if (value is! Map<String, dynamic> || !const {3, 8, 10}.contains(value.length) ||
        value['profile_digest'] is! String || value['leases'] is! List ||
        value['decisions'] is! Map<String, dynamic>) _invalid();
    final digest = value['profile_digest'] as String;
    final rawLeases = value['leases'] as List;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) || rawLeases.length > 256) _invalid();
    DateTime? catalogIssued;
    DateTime? catalogExpires;
    String? catalogSha256;
    var catalogRevoked = false;
    var catalogWithdrawn = false;
    if (value.length >= 8) {
      if (!value.containsKey('catalog_issued_at') || !value.containsKey('catalog_expires_at') ||
          !value.containsKey('catalog_sha256') ||
          value['catalog_revoked'] is! bool || value['catalog_withdrawn'] is! bool) _invalid();
      catalogRevoked = value['catalog_revoked'] as bool;
      catalogWithdrawn = value['catalog_withdrawn'] as bool;
      if (catalogWithdrawn && !catalogRevoked) _invalid();
      if (value['catalog_issued_at'] != null || value['catalog_expires_at'] != null) {
        if (value['catalog_issued_at'] is! String || value['catalog_expires_at'] is! String) _invalid();
        catalogIssued = DateTime.tryParse(value['catalog_issued_at'] as String);
        catalogExpires = DateTime.tryParse(value['catalog_expires_at'] as String);
        if (catalogIssued == null || catalogExpires == null || !catalogIssued.isUtc ||
            !catalogExpires.isUtc || !catalogExpires.isAfter(catalogIssued)) _invalid();
        if (value['catalog_sha256'] is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['catalog_sha256'] as String)) _invalid();
        catalogSha256 = value['catalog_sha256'] as String;
      } else if (value['catalog_sha256'] != null) {
        _invalid();
      }
    }
    if (rawLeases.isEmpty && catalogExpires == null) _invalid();
    CatalogRuntimeIdentity? catalogIdentity;
    Set<String> catalogServiceRevocations = const {};
    if (value.length == 10) {
      if (!value.containsKey('catalog_identity') || value['catalog_service_revocations'] is! List) _invalid();
      if (value['catalog_identity'] != null) {
        catalogIdentity = CatalogRuntimeIdentity.fromStored(value['catalog_identity']);
        if (catalogExpires == null || catalogIdentity.platform != platform || catalogIdentity.audience != audience) _invalid();
      }
      final revoked = value['catalog_service_revocations'] as List;
      if (revoked.length > 256 || revoked.toSet().length != revoked.length ||
          revoked.any((id) => id is! String || catalogIdentity?.services.containsKey(id) != true)) _invalid();
      catalogServiceRevocations = Set.unmodifiable(revoked.cast<String>());
    }
    final ids = <String>{};
    final leases = rawLeases.map(SmartAccessLeaseIdentity.fromStored).toList();
    for (final lease in leases) {
      if (lease.lease['platform'] != platform || lease.lease['audience'] != audience ||
          !ids.add(lease.leaseId)) _invalid();
    }
    final decisions = <String, SmartAccessLeaseRevocation>{};
    for (final entry in (value['decisions'] as Map<String, dynamic>).entries) {
      if (!ids.contains(entry.key) || !const {'drain', 'terminate'}.contains(entry.value)) _invalid();
      decisions[entry.key] = entry.value == 'terminate'
          ? SmartAccessLeaseRevocation.terminate : SmartAccessLeaseRevocation.drain;
    }
    return StoredSmartAccessRuntime(SmartAccessRuntimeLeases(digest, leases,
      catalogIssuedAt: catalogIssued, catalogExpiresAt: catalogExpires, catalogSha256: catalogSha256,
      catalogIdentity: catalogIdentity), Map.unmodifiable(decisions), catalogRevoked: catalogRevoked,
      catalogWithdrawn: catalogWithdrawn, catalogServiceRevocations: catalogServiceRevocations);
  }

  Future<List<StoredSmartAccessRuntime>> _read(DateTime now, {bool includeExpired = false}) async {
    if (!const {'android', 'windows'}.contains(platform) || !const {'lab', 'production'}.contains(audience)) _invalid();
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    if (raw.length > 1024 * 1024 || utf8.encode(raw).length > 1024 * 1024) _invalid();
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> || value.length != 3 || value['version'] != 1 ||
        value['last_observed_at'] is! String || value['bindings'] is! List) _invalid();
    final observed = DateTime.tryParse(value['last_observed_at'] as String);
    if (observed == null || !observed.isUtc) _invalid();
    if (now.isBefore(observed)) throw const RoutingCatalogFailure('smart_access_clock_rollback');
    final bindings = value['bindings'] as List;
    if (bindings.length > 3) _invalid();
    final entries = bindings.map(_entry).toList();
    if (entries.map((entry) => entry.binding.profileDigest).toSet().length != entries.length) _invalid();
    return includeExpired ? entries : entries.where((entry) => entry.binding.hasLiveAuthority(now)).toList();
  }

  NativeSmartAccessRestriction _nativeEntry(Object? input) {
    if (input is! Map<String, dynamic> || input.length != 7 || !input.containsKey('expires_at')) _invalid();
    final profile = input['profile_digest'];
    final catalog = input['catalog_sha256'];
    final action = input['policy_action'];
    final withdrawn = input['catalog_withdrawn'];
    final recovery = input['recovery_required'];
    final expiry = input['expires_at'];
    final scopes = input['scope_actions'];
    if (scopes is! Map<String, dynamic> || scopes.length > 256 || scopes.entries.any((entry) =>
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.key) || !const {'drain', 'terminate'}.contains(entry.value))) _invalid();
    if (profile is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(profile) ||
        catalog is! String || (catalog.isNotEmpty && !RegExp(r'^[a-f0-9]{64}$').hasMatch(catalog)) ||
        action is! String || !const {'none', 'drain', 'terminate'}.contains(action) ||
        withdrawn is! bool || recovery is! bool || (withdrawn && action != 'terminate') ||
        (expiry != null && expiry is! String)) _invalid();
    final expires = expiry == null ? null : DateTime.tryParse(expiry as String);
    if (expiry != null && (expires == null || !expires.isUtc)) _invalid();
    return NativeSmartAccessRestriction(profileDigest: profile, catalogSha256: catalog, policyAction: action,
      catalogWithdrawn: withdrawn, recoveryRequired: recovery, expiresAt: expires,
      scopeActions: Map.unmodifiable(scopes.cast<String, String>()));
  }

  Object? _decodeNative(String raw) {
    try { return jsonDecode(raw); }
    on FormatException { _invalid(); }
  }

  Object? _canonicalNative(Object? value) {
    if (value is Map<String, dynamic>) {
      final keys = value.keys.toList()..sort();
      return {for (final key in keys) key: _canonicalNative(value[key])};
    }
    if (value is List) return value.map(_canonicalNative).toList();
    return value;
  }

  Future<List<NativeSmartAccessRestriction>> _readNative(DateTime now) async {
    if (!const {'android', 'windows'}.contains(platform) || !const {'lab', 'production'}.contains(audience)) _invalid();
    final raw = await _storage.read(key: _nativeKey);
    if (raw == null) return [];
    if (raw.length > 1024 * 1024 || utf8.encode(raw).length > 1024 * 1024) _invalid();
    final value = _decodeNative(raw);
    if (value is! Map<String, dynamic> || value.length != 3 || value['version'] != 1 ||
        value['last_observed_at'] is! String || value['restrictions'] is! List) _invalid();
    final observed = DateTime.tryParse(value['last_observed_at'] as String);
    if (observed == null || !observed.isUtc || now.isBefore(observed)) {
      throw const RoutingCatalogFailure('smart_access_clock_rollback');
    }
    final entries = value['restrictions'] as List;
    if (entries.length > 256) _invalid();
    final restrictions = entries.map(_nativeEntry).toList();
    if (restrictions.any((entry) => !entry.restricted) ||
        restrictions.map((entry) => entry.profileDigest).toSet().length != restrictions.length) _invalid();
    return restrictions.where((entry) => entry.expiresAt == null || now.isBefore(entry.expiresAt!)).toList();
  }

  Future<void> _writeNative(List<NativeSmartAccessRestriction> restrictions, DateTime observed) async {
    final completed = _now().toUtc();
    if (completed.isBefore(observed)) throw const RoutingCatalogFailure('smart_access_clock_rollback');
    if (restrictions.length > 256) throw const RoutingCatalogFailure('smart_access_native_recovery_required');
    final raw = jsonEncode({'version': 1, 'last_observed_at': completed.toIso8601String(),
      'restrictions': [for (final entry in restrictions) entry.toStored()]});
    if (utf8.encode(raw).length > 1024 * 1024) _invalid();
    await _storage.write(key: _nativeKey, value: raw);
  }

  Future<List<NativeSmartAccessRestriction>> readNativeRestrictions() => _serialize(() async {
    final now = _now().toUtc();
    final retained = await _readNative(now);
    await _writeNative(retained, now);
    return List.unmodifiable(retained);
  });

  /// Same queue as the lease inventory. Native ACK is outside this transaction
  /// and is permitted only after this write and the caller's generation fence.
  Future<RetainedSmartAccessNativeJournal> retainNativeJournal(String encoded,
      {required bool Function() isCurrent, required String? activeProfileDigest,
      required Set<String> currentLeaseIds}) => _serialize(() async {
    if (!isCurrent()) throw const RoutingCatalogFailure('smart_access_recovery_superseded');
    if (utf8.encode(encoded).length > 1024 * 1024) _invalid();
    final snapshot = _decodeNative(encoded);
    if (snapshot is! Map<String, dynamic> || snapshot.length != 3 || snapshot['schema'] != 1 ||
        snapshot['snapshot_sha256'] is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(snapshot['snapshot_sha256'] as String) ||
        snapshot['entries'] is! List || (snapshot['entries'] as List).length > 3) _invalid();
    final entries = snapshot['entries'] as List;
    final received = <NativeSmartAccessRestriction>[];
    final identities = <String, List<SmartAccessLeaseIdentity>>{};
    final seen = <String>{};
    var hasLive = false;
    for (final entry in entries) {
      if (entry is! Map<String, dynamic> || entry.length != 10 || entry['generation'] is! String ||
          !RegExp(r'^[a-f0-9]{32}$').hasMatch(entry['generation'] as String) ||
          entry['pending'] is! bool || entry['live'] is! bool || entry['expires_at'] is! String ||
          (entry['expires_at'] != '' && !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$').hasMatch(entry['expires_at'] as String)) ||
          (entry['live'] == true && entry['pending'] != true) ||
          entry['leases'] is! List || (entry['leases'] as List).length > 256) _invalid();
      final record = _nativeEntry({'profile_digest': entry['profile_digest'], 'catalog_sha256': entry['catalog_sha256'],
        'policy_action': entry['policy_action'], 'catalog_withdrawn': entry['catalog_withdrawn'],
        'scope_actions': entry['scope_actions'],
        'recovery_required': entry['pending'] == true && entry['live'] == false,
        'expires_at': entry['expires_at'] == '' ? null : entry['expires_at']});
      if (record.expiresAt != null &&
          record.expiresAt!.toIso8601String().replaceFirst('.000Z', 'Z') != entry['expires_at']) _invalid();
      if (!seen.add(record.profileDigest)) _invalid();
      final leases = (entry['leases'] as List).map(SmartAccessLeaseIdentity.fromStored).toList();
      if (leases.map((lease) => lease.leaseId).toSet().length != leases.length ||
          leases.any((lease) => !lease.hasRenewalScope || lease.lease['platform'] != platform ||
            lease.lease['audience'] != audience || record.expiresAt == null || lease.activeFlowsUntil.isAfter(record.expiresAt!))) _invalid();
      identities[record.profileDigest] = leases;
      hasLive = hasLive || entry['live'] == true;
      received.add(record);
    }
    if (await smartAccessProfileSha256(jsonEncode(_canonicalNative(entries))) != snapshot['snapshot_sha256']) _invalid();
    final now = _now().toUtc();
    final retained = {for (final entry in await _readNative(now)) entry.profileDigest: entry};
    List<StoredSmartAccessRuntime> bindings;
    try { bindings = await _read(now, includeExpired: true); }
    on Object { bindings = const []; } // Preserve damaged inventory; no invented expiry for its restrictions.
    for (final record in received) {
      final previous = retained[record.profileDigest];
      if (!record.restricted && previous == null) continue;
      if (previous != null && previous.catalogSha256.isNotEmpty && record.catalogSha256.isNotEmpty &&
          previous.catalogSha256 != record.catalogSha256) _invalid();
      DateTime? expires = previous?.expiresAt;
      if (record.expiresAt != null && (expires == null || record.expiresAt!.isAfter(expires))) expires = record.expiresAt;
      for (final stored in bindings) {
        final binding = stored.binding;
        if (binding.profileDigest != record.profileDigest) continue;
        if (binding.catalogSha256 != null && record.catalogSha256.isNotEmpty && binding.catalogSha256 != record.catalogSha256) _invalid();
        final bounds = <DateTime>[if (binding.catalogExpiresAt != null) binding.catalogExpiresAt!,
          for (final lease in binding.leases) lease.activeFlowsUntil];
        for (final bound in bounds) { if (expires == null || bound.isAfter(expires)) expires = bound; }
      }
      if (expires != null && !now.isBefore(expires)) {
        retained.remove(record.profileDigest);
        continue;
      }
      final action = previous?.policyAction == 'terminate' || record.policyAction == 'terminate' ? 'terminate' :
          previous?.policyAction == 'drain' || record.policyAction == 'drain' ? 'drain' : 'none';
      final scopes = <String, String>{...?previous?.scopeActions};
      for (final scope in record.scopeActions.entries) {
        if (scopes[scope.key] != 'terminate') scopes[scope.key] = scope.value;
      }
      if (scopes.length > 256) throw const RoutingCatalogFailure('smart_access_native_recovery_required');
      retained[record.profileDigest] = NativeSmartAccessRestriction(profileDigest: record.profileDigest,
        catalogSha256: record.catalogSha256.isNotEmpty ? record.catalogSha256 : previous?.catalogSha256 ?? '',
        policyAction: action, catalogWithdrawn: record.catalogWithdrawn || (previous?.catalogWithdrawn ?? false),
        recoveryRequired: record.recoveryRequired || (previous?.recoveryRequired ?? false), expiresAt: expires,
        scopeActions: Map.unmodifiable(scopes));
    }
    if (!isCurrent()) throw const RoutingCatalogFailure('smart_access_recovery_superseded');
    final result = retained.values.toList();
    await _writeNative(result, now);
    if (!isCurrent()) throw const RoutingCatalogFailure('smart_access_recovery_superseded');
    final updated = _mergeNativeLeaseIdentities(bindings, received, identities, now,
      activeProfileDigest: activeProfileDigest, currentLeaseIds: currentLeaseIds);
    if (updated.isNotEmpty) {
      await _write(bindings, now);
      if (!isCurrent()) throw const RoutingCatalogFailure('smart_access_recovery_superseded');
    }
    return RetainedSmartAccessNativeJournal(snapshot['snapshot_sha256'] as String, List.unmodifiable(result),
      hasLiveWorker: hasLive, bindings: List.unmodifiable(updated));
  });

  // Native identities were retained before adoption, so they can include a
  // candidate Core never used. Merge metadata only; native current-ID readback
  // plus fresh signed authority still gates any following renewal.
  List<StoredSmartAccessRuntime> _mergeNativeLeaseIdentities(List<StoredSmartAccessRuntime> bindings,
      List<NativeSmartAccessRestriction> records, Map<String, List<SmartAccessLeaseIdentity>> identities,
      DateTime now, {required String? activeProfileDigest, required Set<String> currentLeaseIds}) {
    final updated = <StoredSmartAccessRuntime>[];
    for (final record in records) {
      final incoming = identities[record.profileDigest]!;
      if (incoming.isEmpty || (record.expiresAt != null && !now.isBefore(record.expiresAt!))) continue;
      final index = bindings.indexWhere((entry) => entry.binding.profileDigest == record.profileDigest);
      // Do not erase unreadable storage or fabricate a catalog/scope binding.
      // Native retains the unacknowledged identities for a later recovery.
      if (index < 0) throw const RoutingCatalogFailure('smart_access_native_recovery_required');
      final stored = bindings[index];
      final binding = stored.binding;
      if (binding.catalogIdentity == null || binding.catalogIssuedAt == null || binding.catalogExpiresAt == null ||
          binding.catalogSha256 != record.catalogSha256) _invalid();
      final merged = {for (final lease in binding.leases) lease.leaseId: lease};
      final ordered = List<SmartAccessLeaseIdentity>.of(incoming)..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
      for (final lease in ordered) {
        final existing = merged[lease.leaseId];
        if (existing != null) {
          if (!existing.matches(lease)) _invalid();
          continue;
        }
        if (lease.newFlowsUntil.isAfter(binding.catalogExpiresAt!) ||
            binding.catalogIdentity!.services[lease.lease['service_id']]?.capabilities.contains(lease.lease['capability_id']) != true ||
            !merged.values.any((anchor) => anchor.acceptsRuntimeIdentity(lease) && !lease.issuedAt.isBefore(anchor.issuedAt))) _invalid();
        merged[lease.leaseId] = lease;
      }
      final nativeIds = incoming.map((lease) => lease.leaseId).toSet();
      final retained = merged.values.where((lease) => now.isBefore(lease.activeFlowsUntil) || nativeIds.contains(lease.leaseId) ||
        (binding.profileDigest == activeProfileDigest && currentLeaseIds.contains(lease.leaseId))).toList();
      if (retained.length > 256) throw const RoutingCatalogFailure('smart_access_runtime_inventory_full');
      final ids = retained.map((lease) => lease.leaseId).toSet();
      final entry = StoredSmartAccessRuntime(SmartAccessRuntimeLeases(binding.profileDigest, retained,
        catalogIssuedAt: binding.catalogIssuedAt, catalogExpiresAt: binding.catalogExpiresAt,
        catalogSha256: binding.catalogSha256, catalogIdentity: binding.catalogIdentity),
        Map.unmodifiable({for (final decision in stored.decisions.entries) if (ids.contains(decision.key)) decision.key: decision.value}),
        catalogRevoked: stored.catalogRevoked, catalogWithdrawn: stored.catalogWithdrawn,
        catalogServiceRevocations: stored.catalogServiceRevocations);
      bindings[index] = entry;
      updated.add(entry);
    }
    return updated;
  }

  Future<void> _guardNativeStage(SmartAccessRuntimeLeases binding, DateTime now,
      {SmartAccessLeaseIdentity? renewal}) async {
    final restrictions = await _readNative(now);
    await _writeNative(restrictions, now);
    for (final record in restrictions) {
      final sameProfile = record.profileDigest == binding.profileDigest;
      final leases = renewal == null ? binding.leases : [renewal];
      final scopeBlocked = sameProfile && leases.any((lease) =>
        record.scopeActions.containsKey(lease.lease['runtime_scope_sha256']));
      if ((sameProfile && record.blocksProfile) || scopeBlocked || record.affectsCatalog(binding.catalogSha256)) {
        throw RoutingCatalogFailure(record.recoveryRequired ? 'smart_access_native_recovery_required' : 'smart_access_stage_revoked');
      }
    }
  }

  Future<void> _write(List<StoredSmartAccessRuntime> entries, DateTime observed) async {
    final completed = _now().toUtc();
    if (completed.isBefore(observed)) throw const RoutingCatalogFailure('smart_access_clock_rollback');
    final value = jsonEncode({'version': 1, 'last_observed_at': completed.toIso8601String(),
      'bindings': [for (final entry in entries) {'profile_digest': entry.binding.profileDigest,
        'catalog_issued_at': entry.binding.catalogIssuedAt?.toUtc().toIso8601String(),
        'catalog_expires_at': entry.binding.catalogExpiresAt?.toUtc().toIso8601String(),
        'catalog_revoked': entry.catalogRevoked,
        'catalog_withdrawn': entry.catalogWithdrawn,
        'catalog_sha256': entry.binding.catalogSha256,
        'catalog_identity': entry.binding.catalogIdentity?.toStored(),
        'catalog_service_revocations': entry.catalogServiceRevocations.toList()..sort(),
        'leases': [for (final lease in entry.binding.leases) lease.lease],
        'decisions': {for (final decision in entry.decisions.entries) decision.key: decision.value.name}}]});
    if (utf8.encode(value).length > 1024 * 1024) _invalid();
    await _storage.write(key: _key, value: value);
  }

  Future<StoredSmartAccessRuntime?> read(String profileDigest) => _serialize(() async {
    final now = _now().toUtc();
    final entries = await _read(now);
    // Retain the observation even after expiry, preventing clock rollback reuse.
    await _write(entries, now);
    for (final entry in entries) {
      if (entry.binding.profileDigest == profileDigest) return entry;
    }
    return null;
  });

  Future<void> prepareStage(SmartAccessRuntimeLeases binding, {required String? activeDigest,
    required String? stagedDigest,
    required bool Function() isCurrent}) => _serialize(() async {
    if (!isCurrent()) return;
    final now = _now().toUtc();
    await _guardNativeStage(binding, now);
    final entries = await _read(now);
    if (!isCurrent()) return;
    if (binding.catalogSha256 != null && entries.any((entry) => entry.catalogWithdrawn &&
        entry.binding.catalogSha256 == binding.catalogSha256)) {
      throw const RoutingCatalogFailure('catalog_stage_revoked');
    }
    if (binding.catalogSha256 != null && entries.any((entry) => entry.binding.catalogSha256 == binding.catalogSha256 &&
        entry.catalogServiceRevocations.any((id) => binding.catalogIdentity?.services.containsKey(id) == true))) {
      throw const RoutingCatalogFailure('catalog_service_stage_revoked');
    }
    final next = <StoredSmartAccessRuntime>[];
    for (final entry in entries) {
      if (entry.binding.profileDigest != binding.profileDigest &&
          (entry.binding.profileDigest == activeDigest || entry.binding.profileDigest == stagedDigest)) next.add(entry);
    }
    if (binding.leases.isNotEmpty || binding.catalogExpiresAt != null) {
      Map<String, SmartAccessLeaseRevocation> retained = const {};
      for (final entry in entries) {
        if (entry.binding.profileDigest == binding.profileDigest) {
          retained = entry.decisions;
          if (retained.isNotEmpty || entry.catalogRevoked || entry.catalogServiceRevocations.isNotEmpty) {
            throw const RoutingCatalogFailure('smart_access_stage_revoked');
          }
          if (entry.binding.leases.any((old) => now.isBefore(old.activeFlowsUntil) &&
              !binding.leases.any((lease) => lease.matches(old)))) {
            // Restaging the old bytes must not erase a renewal whose flows may
            // still be running under this same native profile digest.
            throw const RoutingCatalogFailure('smart_access_restage_requires_fresh_profile');
          }
        }
      }
      next.add(StoredSmartAccessRuntime(binding, retained));
    }
    await _write(next, now);
  });

  /// Persist before native renewal. Success retains restriction identities only;
  /// it does not mean Core accepted the next generation. An uncertain native
  /// result is retried with the same renewal, never by deleting the old identity.
  Future<StoredSmartAccessRuntime> retainRenewal(SmartAccessLeaseRenewal renewal,
    {required bool Function() isCurrent}) => _serialize(() async {
    void requireCurrent() {
      if (!isCurrent() || !renewal.next.admitsNewFlows(_now().toUtc())) {
        throw const RoutingCatalogFailure('smart_access_renewal_superseded');
      }
    }
    requireCurrent();
    final now = _now().toUtc();
    await _guardNativeStage(renewal.binding, now, renewal: renewal.previous);
    final entries = await _read(now);
    requireCurrent();
    final index = entries.indexWhere((entry) => entry.binding.profileDigest == renewal.binding.profileDigest);
    if (index < 0) throw const RoutingCatalogFailure('smart_access_runtime_binding_missing');
    final entry = entries[index];
    final binding = entry.binding;
    final previous = renewal.previous;
    final next = SmartAccessLeaseIdentity.fromGrant(renewal.next);
    final serviceId = next.lease['service_id']! as String;
    if (binding.catalogSha256 != renewal.binding.catalogSha256 ||
        binding.catalogIssuedAt != renewal.binding.catalogIssuedAt ||
        binding.catalogExpiresAt != renewal.binding.catalogExpiresAt ||
        binding.catalogExpiresAt == null || !_now().toUtc().isBefore(binding.catalogExpiresAt!) ||
        binding.catalogIdentity?.services[serviceId]?.capabilities.contains(next.lease['capability_id']) != true ||
        !binding.leases.any((lease) => lease.matches(previous))) {
      throw const RoutingCatalogFailure('smart_access_renewal_binding_missing');
    }
    if (entry.catalogRevoked || entry.catalogWithdrawn || entry.catalogServiceRevocations.contains(serviceId) ||
        entry.decisions.containsKey(previous.leaseId) || entry.decisions.containsKey(next.leaseId)) {
      throw const RoutingCatalogFailure('smart_access_renewal_revoked');
    }
    final retained = <SmartAccessLeaseIdentity>[];
    final currentIds = {...renewal.currentLeaseIds,
      ...renewal.binding.verifiedGrants.map((grant) => grant.lease['lease_id'])};
    var alreadyRetained = false;
    for (final lease in binding.leases) {
      if (lease.leaseId == next.leaseId) {
        if (!lease.matches(next)) _invalid();
        alreadyRetained = true;
      }
      if (currentIds.contains(lease.leaseId) || lease.leaseId == next.leaseId || now.isBefore(lease.activeFlowsUntil)) {
        retained.add(lease);
      }
    }
    if (!alreadyRetained) retained.add(next);
    if (retained.length > 256) throw const RoutingCatalogFailure('smart_access_runtime_inventory_full');
    final ids = retained.map((lease) => lease.leaseId).toSet();
    final updated = StoredSmartAccessRuntime(SmartAccessRuntimeLeases(binding.profileDigest, retained,
      catalogIssuedAt: binding.catalogIssuedAt, catalogExpiresAt: binding.catalogExpiresAt,
      catalogSha256: binding.catalogSha256, catalogIdentity: binding.catalogIdentity),
      Map.unmodifiable({for (final decision in entry.decisions.entries)
        if (ids.contains(decision.key)) decision.key: decision.value}),
      catalogRevoked: entry.catalogRevoked, catalogWithdrawn: entry.catalogWithdrawn,
      catalogServiceRevocations: entry.catalogServiceRevocations);
    entries[index] = updated;
    requireCurrent();
    await _write(entries, now);
    // A late write can leave harmless extra restriction metadata. It cannot
    // authorize dispatch after cancellation, expiry or a runtime change.
    requireCurrent();
    return updated;
  });

  Future<void> retainDecisions(SmartAccessRuntimeLeases binding,
    Map<String, SmartAccessLeaseRevocation> decisions,
    {bool catalogRevoked = false, bool catalogWithdrawn = false, Set<String> catalogServiceRevocations = const {}}) => _serialize(() async {
    final now = _now().toUtc();
    final entries = await _read(now);
    final index = entries.indexWhere((entry) => entry.binding.profileDigest == binding.profileDigest);
    if (index < 0) throw const RoutingCatalogFailure('smart_access_runtime_binding_missing');
    final ids = entries[index].binding.leases.map((lease) => lease.leaseId).toSet();
    final merged = Map<String, SmartAccessLeaseRevocation>.of(entries[index].decisions);
    for (final entry in decisions.entries) {
      if (!ids.contains(entry.key)) _invalid();
      if (merged[entry.key] != SmartAccessLeaseRevocation.terminate) merged[entry.key] = entry.value;
    }
    if (catalogWithdrawn && !catalogRevoked) _invalid();
    if (catalogServiceRevocations.any((id) => entries[index].binding.catalogIdentity?.services.containsKey(id) != true)) _invalid();
    entries[index] = StoredSmartAccessRuntime(entries[index].binding, Map.unmodifiable(merged),
      catalogRevoked: entries[index].catalogRevoked || catalogRevoked,
      catalogWithdrawn: entries[index].catalogWithdrawn || catalogWithdrawn,
      catalogServiceRevocations: Set.unmodifiable({...entries[index].catalogServiceRevocations, ...catalogServiceRevocations}));
    await _write(entries, now);
  });
}
