import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ManagedProfileCacheRead {
  const ManagedProfileCacheRead({this.payload, this.accessEnded = false});

  final Map<String, dynamic>? payload;
  final bool accessEnded;
}

/// Account-bound downloaded and last-proven profiles. Connection failures and
/// offline restaging never renew the original server-observation timestamp.
class ManagedProfileCache {
  ManagedProfileCache({
    FlutterSecureStorage? storage,
    DateTime Function()? now,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _now = now ?? DateTime.now;

  static const offlineWindow = Duration(hours: 24);
  static const refreshInterval = Duration(hours: 6);
  static String newEntryId() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
  }
  static const _maxBytes = 8 * 1024 * 1024;
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;
  Future<void> _writes = Future<void>.value();
  final Map<String, int> _invalidations = {};

  int generation(String platform) => _invalidations[platform] ?? 0;

  String _key(String platform) => 'pokrov-managed-profile-$platform-v1';

  Future<Map<String, dynamic>> _load(String platform) async {
    final raw = await _storage.read(key: _key(platform));
    if (raw == null) return <String, dynamic>{};
    if (raw.length > _maxBytes) throw const FormatException('Profile cache size');
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> || value['version'] != 1) {
      throw const FormatException('Profile cache version');
    }
    return value;
  }

  Future<void> _write(String platform, Map<String, dynamic> value) async {
    final raw = jsonEncode(value);
    if (utf8.encode(raw).length > _maxBytes) {
      throw const FormatException('Profile cache size');
    }
    await _storage.write(key: _key(platform), value: raw);
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<void> saveDownloaded({
    required String platform,
    required String binding,
    required String revision,
    required DateTime verifiedAt,
    required Map<String, Object?> payload,
    int? expectedGeneration,
    bool Function()? isCurrent,
    bool candidateOnly = false,
  }) =>
      _serialize(() async {
        bool current() => (expectedGeneration == null ||
            expectedGeneration == generation(platform)) && (isCurrent?.call() ?? true);
        if (!current()) return;
        final value = await _load(platform);
        final catalog = payload['transport_catalog'];
        final candidateRef = catalog is Map ? catalog['selected_candidate_ref'] : null;
        final candidates = Map<String, dynamic>.from(value['candidates'] is Map
            ? value['candidates'] as Map : const {});
        final previous = candidateOnly ? candidates[candidateRef] : value['downloaded'];
        final previousAt = previous is Map
            ? DateTime.tryParse(previous['verified_at']?.toString() ?? '')
            : null;
        if (previousAt != null && previousAt.isAfter(verifiedAt)) return;
        value['version'] = 1;
        final entry = <String, Object?>{
          'binding': binding,
          'revision': revision,
          'verified_at': verifiedAt.toUtc().toIso8601String(),
          'payload': payload,
        };
        if (candidateOnly) {
          final selected = value['downloaded'];
          final selectedPayload = selected is Map && selected['binding'] == binding
              ? selected['payload'] : null;
          final selectedCatalog = selectedPayload is Map ? selectedPayload['transport_catalog'] : null;
          if (candidateRef is! String || selectedCatalog is! Map || catalog is! Map ||
              selectedCatalog['revision'] != catalog['revision'] ||
              !(selectedCatalog['candidates'] as List).any((item) =>
                  item is Map && item['candidate_ref'] == candidateRef)) return;
          final descriptors = (selectedCatalog['candidates'] as List).whereType<Map>();
          final selectedNode = descriptors.firstWhere((item) =>
              item['candidate_ref'] == selectedCatalog['selected_candidate_ref'])['node_code'];
          if (!descriptors.any((item) => item['candidate_ref'] == candidateRef && item['node_code'] == selectedNode)) return;
        } else {
          value['downloaded'] = entry;
          final allowed = catalog is Map && catalog['candidates'] is List
              ? (catalog['candidates'] as List).whereType<Map>()
                  .map((item) => item['candidate_ref']).toSet() : null;
          candidates.removeWhere((ref, item) {
            if (item is! Map || item['binding'] != binding) return true;
            if (allowed == null) return false;
            final oldPayload = item['payload'];
            final oldCatalog = oldPayload is Map ? oldPayload['transport_catalog'] : null;
            return !allowed.contains(ref) || oldCatalog is! Map ||
                oldCatalog['revision'] != (catalog as Map)['revision'];
          });
        }
        if (candidateRef is String && candidateRef.isNotEmpty) candidates[candidateRef] = entry;
        if (candidates.isNotEmpty) value['candidates'] = candidates;
        else value.remove('candidates');
        final proven = value['proven'];
        if (proven is Map && proven['binding'] != binding) {
          value.remove('proven');
        }
        if (current()) await _write(platform, value);
      });

  Future<Map<String, dynamic>?> read({
    required String platform,
    required String binding,
    bool preferProven = false,
    String selectedCandidateRef = '',
  }) async => (await readResult(platform: platform, binding: binding,
      preferProven: preferProven, selectedCandidateRef: selectedCandidateRef)).payload;

  Future<ManagedProfileCacheRead> readResult({
    required String platform,
    required String binding,
    bool preferProven = false,
    String selectedCandidateRef = '',
  }) => _serialize(() async {
    try {
      final value = await _load(platform);
      if (value.isEmpty) return const ManagedProfileCacheRead();
      final now = _now().toUtc();
      final observedValue = value['last_observed_at'];
      final observedAt = observedValue == null
          ? null
          : DateTime.tryParse(observedValue.toString());
      if ((observedValue != null && observedAt == null) ||
          (observedAt != null && now.isBefore(observedAt))) {
        return const ManagedProfileCacheRead();
      }
      // Persist even an expired read, so a later clock rollback cannot revive it.
      value['last_observed_at'] = now.toIso8601String();
      await _write(platform, value);
      var accessEnded = false;
      final latest = value['downloaded'];
      final latestPayload = latest is Map && latest['binding'] == binding ? latest['payload'] : null;
      final latestAccess = latestPayload is Map ? latestPayload['access'] : null;
      final slots = preferProven
          ? const ['proven', 'downloaded']
          : const ['downloaded', 'proven'];
      final entries = <MapEntry<String, dynamic>>[
        for (final slot in slots) MapEntry(slot, value[slot]),
        if (selectedCandidateRef.isNotEmpty && value['candidates'] is Map)
          MapEntry('candidate', value['candidates'][selectedCandidateRef]),
      ];
      for (final row in entries) {
        final slot = row.key;
        final entry = row.value;
        if (entry is! Map || entry['binding'] != binding) continue;
        final verified = DateTime.tryParse(entry['verified_at']?.toString() ?? '');
        if (verified == null) continue;
        final age = now.difference(verified);
        if (age.isNegative) continue;
        final payload = entry['payload'];
        if (payload is! Map<String, dynamic>) continue;
        var catalog = payload['transport_catalog'];
        if (catalog is Map) {
          final latestCatalog = latestPayload is Map ? latestPayload['transport_catalog'] : null;
          final entryCandidateRef = catalog['selected_candidate_ref'];
          if (latestCatalog is! Map || latestCatalog['revision'] != catalog['revision'] ||
              !(latestCatalog['candidates'] as List).any((item) =>
                  item is Map && item['candidate_ref'] == entryCandidateRef)) continue;
          // New device credentials may become ready after this profile was
          // proven. Refresh selection metadata, retaining its original proof.
          catalog = <String, dynamic>{...Map<String, dynamic>.from(latestCatalog),
            'selected_candidate_ref': entryCandidateRef};
        }
        if (selectedCandidateRef.isNotEmpty &&
            (catalog is! Map || catalog['selected_candidate_ref'] != selectedCandidateRef)) continue;
        // The latest authorized access window also bounds an older proven profile.
        final access = latestAccess is Map && latestAccess.containsKey('expiry_at')
            ? latestAccess : payload['access'];
        if (access is Map && access.containsKey('expiry_at')) {
          final rawExpiry = access['expiry_at'];
          if (rawExpiry != null) {
            if (rawExpiry is! String || rawExpiry.isEmpty) continue;
            // Platform timestamps without a suffix are UTC, not local time.
            final expiry = DateTime.tryParse(RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(rawExpiry)
                ? rawExpiry : '${rawExpiry}Z');
            if (expiry == null) continue;
            if (now.isAfter(expiry.add(offlineWindow))) {
              accessEnded = true;
              continue;
            }
          }
        } else if (age > offlineWindow) {
          // Actual older records did not carry an access expiry.
          continue;
        }
        return ManagedProfileCacheRead(payload: {
          ...payload,
          if (catalog is Map) 'transport_catalog': catalog,
          'cache_verified_at': entry['verified_at'],
          if (slot == 'proven' && entry['network_selection_key'] is String)
            'proven_network_selection_key': entry['network_selection_key'],
        });
      }
      return ManagedProfileCacheRead(accessEnded: accessEnded);
    } on Object {
      // Unreadable/future state is unavailable and preserved, never guessed.
    }
    return const ManagedProfileCacheRead();
  });

  Future<void> markProven({
    required String platform,
    required String binding,
    required String entryId,
    String? networkSelectionKey,
  }) =>
      _serialize(() async {
        final value = await _load(platform);
        var downloaded = value['downloaded'];
        if (downloaded is Map && downloaded['binding'] == binding &&
            downloaded['payload'] is Map && downloaded['payload']['cache_entry_id'] != entryId &&
            value['candidates'] is Map) {
          for (final entry in (value['candidates'] as Map).values) {
            if (entry is Map && entry['binding'] == binding && entry['payload'] is Map &&
                entry['payload']['cache_entry_id'] == entryId) {
              downloaded = entry;
              break;
            }
          }
        }
        if (downloaded is! Map ||
            downloaded['binding'] != binding ||
            downloaded['payload'] is! Map ||
            downloaded['payload']['cache_entry_id'] != entryId ||
            entryId.isEmpty) return;
        value['proven'] = {
          ...downloaded,
          if (networkSelectionKey != null && networkSelectionKey.isNotEmpty)
            'network_selection_key': networkSelectionKey,
        };
        await _write(platform, value);
      });

  Future<void> clear(String platform) {
    _invalidations[platform] = generation(platform) + 1;
    return _serialize(() => _storage.delete(key: _key(platform)));
  }
}
