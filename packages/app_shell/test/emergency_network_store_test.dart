import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/src/emergency/emergency_network_store.dart';
import 'package:pokrov_core_domain/core_domain.dart';

class _MemorySecrets implements EmergencyStoreSecretBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  test('encrypted emergency store round-trips, separates kinds and clears',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('pokrov-emergency-store');
    addTearDown(() => directory.delete(recursive: true));
    final secrets = _MemorySecrets();
    final store = EncryptedEmergencyNetworkStore(
      directoryResolver: () async => directory,
      secretBackend: secrets,
    );
    const binding =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final catalog = <String, dynamic>{'kind': 'catalog', 'payload_b64': 'safe'};
    final profile = <String, dynamic>{
      'kind': 'profile',
      'payload_b64': 'secret'
    };
    final profileBundle = <String, dynamic>{
      'schema_version': 1,
      'profiles': <Object?>[
        <String, Object?>{'reserve_id': 'reserve-1', 'envelope': profile},
      ],
    };

    await store.writeEnvelope(
      hostPlatform: HostPlatform.android,
      deviceBinding: binding,
      kind: EmergencyCacheKind.catalog,
      envelope: catalog,
    );
    await store.writeEnvelope(
      hostPlatform: HostPlatform.android,
      deviceBinding: binding,
      kind: EmergencyCacheKind.profile,
      envelope: profile,
    );
    await store.writeEnvelope(
      hostPlatform: HostPlatform.android,
      deviceBinding: binding,
      kind: EmergencyCacheKind.profileBundle,
      envelope: profileBundle,
    );

    expect(
      await store.readEnvelope(
        hostPlatform: HostPlatform.android,
        deviceBinding: binding,
        kind: EmergencyCacheKind.catalog,
      ),
      catalog,
    );
    expect(
      await store.readEnvelope(
        hostPlatform: HostPlatform.android,
        deviceBinding: binding,
        kind: EmergencyCacheKind.profile,
      ),
      profile,
    );
    expect(
      await store.readEnvelope(
        hostPlatform: HostPlatform.android,
        deviceBinding: binding,
        kind: EmergencyCacheKind.profileBundle,
      ),
      profileBundle,
    );
    final rawFiles = directory
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.readAsStringSync())
        .join();
    expect(rawFiles, isNot(contains('secret')));
    expect(rawFiles, isNot(contains('payload_b64')));

    await store.clear(
      hostPlatform: HostPlatform.android,
      deviceBinding: binding,
    );
    expect(
      await store.readEnvelope(
        hostPlatform: HostPlatform.android,
        deviceBinding: binding,
        kind: EmergencyCacheKind.profile,
      ),
      isNull,
    );
    expect(secrets.values, isEmpty);
  });

  test('tampered cache is discarded instead of returned', () async {
    final directory =
        await Directory.systemTemp.createTemp('pokrov-emergency-tamper');
    addTearDown(() => directory.delete(recursive: true));
    final store = EncryptedEmergencyNetworkStore(
      directoryResolver: () async => directory,
      secretBackend: _MemorySecrets(),
    );
    const binding =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    await store.writeEnvelope(
      hostPlatform: HostPlatform.windows,
      deviceBinding: binding,
      kind: EmergencyCacheKind.profile,
      envelope: const <String, dynamic>{'payload': 'signed'},
    );
    final file = directory.listSync(recursive: true).whereType<File>().single;
    final raw = file.readAsStringSync();
    file.writeAsStringSync('${raw.substring(0, raw.length - 3)}xxx');

    expect(
      await store.readEnvelope(
        hostPlatform: HostPlatform.windows,
        deviceBinding: binding,
        kind: EmergencyCacheKind.profile,
      ),
      isNull,
    );
    expect(file.existsSync(), isFalse);
  });
}
