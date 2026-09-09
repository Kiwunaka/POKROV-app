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
    final saved = Map<String, String>.of(values);
    cache = ManagedProfileCache(now: () => now);
    now = now.add(const Duration(hours: 24));
    expect((await read())?['cache_entry_id'], 'a');
    expect(values, saved);
    now = now.add(const Duration(seconds: 1));
    expect(await read(), isNull);
    expect(values, saved);
  });

  test('failed new profile keeps the earlier proven record and its original age', () async {
    await save('a');
    await cache.markProven(platform: 'android', binding: 'account-A/install-A/route-A', entryId: 'a');
    now = now.add(const Duration(hours: 1));
    await save('b');
    // A delayed proof for A cannot promote B, even with identical server revision.
    await cache.markProven(platform: 'android', binding: 'account-A/install-A/route-A', entryId: 'a');
    expect((await read())?['cache_entry_id'], 'b');
    expect((await read(preferProven: true))?['cache_entry_id'], 'a');
    now = now.add(const Duration(hours: 23, seconds: 1));
    expect((await read(preferProven: true))?['cache_entry_id'], 'b');
    await cache.clear('android');
    expect(await read(), isNull);
  });

  test('different account, inputs, platform and clock rollback cannot reuse cache', () async {
    await save('a');
    expect(await cache.read(platform: 'windows', binding: 'account-A/install-A/route-A'), isNull);
    expect(await cache.read(platform: 'android', binding: 'account-B/install-A/route-A'), isNull);
    expect(await cache.read(platform: 'android', binding: 'account-A/install-A/route-B'), isNull);
    now = now.subtract(const Duration(seconds: 1));
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
