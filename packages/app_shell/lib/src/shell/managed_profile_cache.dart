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
  }) =>
      _serialize(() async {
        bool current() => (expectedGeneration == null ||
            expectedGeneration == generation(platform)) && (isCurrent?.call() ?? true);
        if (!current()) return;
        final value = await _load(platform);
        final previous = value['downloaded'];
        final previousAt = previous is Map
            ? DateTime.tryParse(previous['verified_at']?.toString() ?? '')
            : null;
        if (previousAt != null && previousAt.isAfter(verifiedAt)) return;
        value['version'] = 1;
        value['downloaded'] = <String, Object?>{
          'binding': binding,
          'revision': revision,
          'verified_at': verifiedAt.toUtc().toIso8601String(),
          'payload': payload,
        };
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
  }) async => (await readResult(platform: platform, binding: binding,
      preferProven: preferProven)).payload;

  Future<ManagedProfileCacheRead> readResult({
    required String platform,
    required String binding,
    bool preferProven = false,
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
      for (final slot in preferProven
          ? const ['proven', 'downloaded']
          : const ['downloaded', 'proven']) {
        final entry = value[slot];
        if (entry is! Map || entry['binding'] != binding) continue;
        final verified = DateTime.tryParse(entry['verified_at']?.toString() ?? '');
        if (verified == null) continue;
        final age = now.difference(verified);
        if (age.isNegative) continue;
        final payload = entry['payload'];
        if (payload is! Map<String, dynamic>) continue;
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
        final downloaded = value['downloaded'];
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
