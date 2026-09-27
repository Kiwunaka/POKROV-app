import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/src/shell/managed_profile_cache.dart';

void main() {
  final originalPlatform = FlutterSecureStoragePlatform.instance;
  late Map<String, String> values;
  late DateTime now;
  late ManagedProfileCache cache;
  setUp(() {
    values = <String, String>{};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(values);
    now = DateTime.utc(2026, 9, 7, 10);
    cache = ManagedProfileCache(now: () => now);
  });
  tearDown(() => FlutterSecureStoragePlatform.instance = originalPlatform);

  Future<void> save(String id, {String binding = 'account-A/install-A/route-A'}) =>
      cache.saveDownloaded(
        platform: 'android', binding: binding, revision: 'revision-$id',
        verifiedAt: now,
        payload: {'cache_entry_id': id, 'config_payload': 'private fixture $id'},
      );
  Future<Map<String, dynamic>?> read({bool preferProven = false}) => cache.read(
    platform: 'android', binding: 'account-A/install-A/route-A',
    preferProven: preferProven,
  );

  test('process restart restores protected cache without renewing its window', () async {
    await save('a');
    final saved = jsonDecode(values.values.single)['downloaded'];
    cache = ManagedProfileCache(now: () => now);
    now = now.add(const Duration(hours: 24));
    expect((await read())?['cache_entry_id'], 'a');
    expect(jsonDecode(values.values.single)['downloaded'], saved);
    now = now.add(const Duration(seconds: 1));
    expect(await read(), isNull);
    expect(jsonDecode(values.values.single)['downloaded'], saved);
  });

  test('known access expiry allows offline reuse through its following day', () async {
    final expiry = now.add(const Duration(days: 10));
    await cache.saveDownloaded(platform: 'android', binding: 'account-A/install-A/route-A',
      revision: 'a', verifiedAt: now, payload: {
        'cache_entry_id': 'a', 'access': {'expiry_at': expiry.toIso8601String()},
      });
    now = expiry.add(const Duration(hours: 24));
    cache = ManagedProfileCache(now: () => now);
    expect((await read())?['cache_entry_id'], 'a');
    now = now.add(const Duration(seconds: 1));
    final expired = await cache.readResult(platform: 'android', binding: 'account-A/install-A/route-A');
    expect(expired.payload, isNull);
    expect(expired.accessEnded, isTrue);
  });

  test('explicit denial fences downloads already in flight', () async {
    final generation = cache.generation('android');
    await save('a');
    await cache.clear('android');
    await cache.saveDownloaded(platform: 'android', binding: 'account-A/install-A/route-A',
      revision: 'late', verifiedAt: now, expectedGeneration: generation,
      payload: {'cache_entry_id': 'late', 'access': {'expiry_at': null}});
    expect(await read(), isNull);
  });

  test('failed new profile keeps the earlier proven record and its original age', () async {
    await save('a');
    await cache.markProven(platform: 'android', binding: 'account-A/install-A/route-A', entryId: 'a',
      networkSelectionKey: 'network-fixture');
    now = now.add(const Duration(hours: 1));
    await save('b');
    // A delayed proof for A cannot promote B, even with identical server revision.
    await cache.markProven(platform: 'android', binding: 'account-A/install-A/route-A', entryId: 'a');
    expect((await read())?['cache_entry_id'], 'b');
    expect((await read(preferProven: true))?['cache_entry_id'], 'a');
    expect((await read())?['proven_network_selection_key'], isNull);
    expect((await read(preferProven: true))?['proven_network_selection_key'], 'network-fixture');
    now = now.add(const Duration(hours: 23, seconds: 1));
    expect((await read(preferProven: true))?['cache_entry_id'], 'b');
    await cache.clear('android');
    expect(await read(), isNull);
  });

  test('candidate material shares binding and denial fences without replacing the winner', () async {
    const binding = 'account-A/install-A/route-A';
    Map<String, Object?> payload(String selected, {String revision = 'catalog-1', bool allowAlternate = true}) => {
      'cache_entry_id': selected, 'access': {'expiry_at': null},
      'transport_catalog': {'revision': revision, 'selected_candidate_ref': selected,
        'candidates': [
          {'candidate_ref': 'de:vless', 'node_code': 'de'},
          if (allowAlternate) {'candidate_ref': 'de:hy2', 'node_code': 'de'},
        ]},
    };
    Future<void> store(String selected, {bool candidateOnly = false, String revision = 'catalog-1',
        bool allowAlternate = true, int? generation, String accountBinding = binding}) =>
      cache.saveDownloaded(platform: 'android', binding: accountBinding, revision: selected,
          verifiedAt: now, payload: payload(selected, revision: revision, allowAlternate: allowAlternate),
          candidateOnly: candidateOnly, expectedGeneration: generation);
    await store('de:vless');
    await store('de:hy2', candidateOnly: true);
    expect((await read())?['cache_entry_id'], 'de:vless');
    expect((await cache.read(platform: 'android', binding: binding, selectedCandidateRef: 'de:hy2'))?['cache_entry_id'], 'de:hy2');
    await cache.markProven(platform: 'android', binding: binding, entryId: 'de:hy2');
    expect((await read(preferProven: true))?['cache_entry_id'], 'de:hy2');
    await store('de:vless', revision: 'catalog-2', allowAlternate: false);
    expect(await cache.read(platform: 'android', binding: binding, selectedCandidateRef: 'de:hy2'), isNull,
        reason: 'current catalog disable/revision invalidates an older candidate and its proof');
    await store('de:hy2', candidateOnly: true);
    expect(await cache.read(platform: 'android', binding: binding, selectedCandidateRef: 'de:hy2'), isNull);
    final oldGeneration = cache.generation('android');
    await cache.clear('android');
    await store('de:hy2', candidateOnly: true, generation: oldGeneration);
    expect(await read(), isNull);
    await store('de:vless', accountBinding: 'account-B/install-A/route-A');
    await store('de:hy2', candidateOnly: true);
    expect(await cache.read(platform: 'android', binding: 'account-B/install-A/route-A', selectedCandidateRef: 'de:hy2'), isNull);
  });

  test('different account, inputs, platform and clock rollback cannot reuse cache', () async {
    await save('a');
    expect(await cache.read(platform: 'windows', binding: 'account-A/install-A/route-A'), isNull);
    expect(await cache.read(platform: 'android', binding: 'account-B/install-A/route-A'), isNull);
    expect(await cache.read(platform: 'android', binding: 'account-A/install-A/route-B'), isNull);
    now = now.subtract(const Duration(seconds: 1));
    expect(await read(), isNull);
  });

  test('observed expiry cannot be undone by clock rollback after restart', () async {
    await save('a');
    final verifiedAt = now;
    now = now.add(const Duration(hours: 25));
    expect(await read(), isNull);

    cache = ManagedProfileCache(now: () => now);
    now = verifiedAt.add(const Duration(hours: 1));
    expect(await read(), isNull);
  });

  test('future cache schema is preserved on both read and write', () async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'pokrov-managed-profile-android-v1', value: jsonEncode({'version': 2}));
    expect(await read(), isNull);
    await expectLater(save('a'), throwsFormatException);
    expect(await storage.read(key: 'pokrov-managed-profile-android-v1'), jsonEncode({'version': 2}));
  });
}
