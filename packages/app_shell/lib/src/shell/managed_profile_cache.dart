import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Account-bound downloaded and last-proven profiles. Connection failures and
/// offline restaging never renew the original server-observation timestamp.
class ManagedProfileCache {
  ManagedProfileCache({
    FlutterSecureStorage? storage,
    DateTime Function()? now,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _now = now ?? DateTime.now;

  static const offlineWindow = Duration(hours: 24);
  static String newEntryId() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
  }
  static const _maxBytes = 8 * 1024 * 1024;
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;
  Future<void> _writes = Future<void>.value();

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
  }) =>
      _serialize(() async {
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
        await _write(platform, value);
      });

  Future<Map<String, dynamic>?> read({
    required String platform,
    required String binding,
    bool preferProven = false,
  }) => _serialize(() async {
    try {
      final value = await _load(platform);
      if (value.isEmpty) return null;
      final now = _now().toUtc();
      final observedValue = value['last_observed_at'];
      final observedAt = observedValue == null
          ? null
          : DateTime.tryParse(observedValue.toString());
      if ((observedValue != null && observedAt == null) ||
          (observedAt != null && now.isBefore(observedAt))) return null;
      // Persist even an expired read, so a later clock rollback cannot revive it.
      value['last_observed_at'] = now.toIso8601String();
      await _write(platform, value);
      for (final slot in preferProven
          ? const ['proven', 'downloaded']
          : const ['downloaded', 'proven']) {
        final entry = value[slot];
        if (entry is! Map || entry['binding'] != binding) continue;
        final verified = DateTime.tryParse(entry['verified_at']?.toString() ?? '');
        if (verified == null) continue;
        final age = now.difference(verified);
        if (age.isNegative || age > offlineWindow) continue;
        final payload = entry['payload'];
        if (payload is Map<String, dynamic>) return payload;
      }
    } on Object {
      // Unreadable/future state is unavailable and preserved, never guessed.
    }
    return null;
  });

  Future<void> markProven({
    required String platform,
    required String binding,
    required String entryId,
  }) =>
      _serialize(() async {
        final value = await _load(platform);
        final downloaded = value['downloaded'];
        if (downloaded is! Map ||
            downloaded['binding'] != binding ||
            downloaded['payload'] is! Map ||
            downloaded['payload']['cache_entry_id'] != entryId ||
            entryId.isEmpty) return;
        value['proven'] = downloaded;
        await _write(platform, value);
      });

  Future<void> clear(String platform) =>
      _serialize(() => _storage.delete(key: _key(platform)));
}
