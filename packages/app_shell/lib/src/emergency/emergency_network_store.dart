import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pokrov_core_domain/core_domain.dart';

enum EmergencyCacheKind { catalog, profile, profileBundle }

abstract interface class EmergencyStoreSecretBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterEmergencyStoreSecretBackend
    implements EmergencyStoreSecretBackend {
  FlutterEmergencyStoreSecretBackend({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

abstract interface class EmergencyNetworkStore {
  Future<void> writeEnvelope({
    required HostPlatform hostPlatform,
    required String deviceBinding,
    required EmergencyCacheKind kind,
    required Map<String, dynamic> envelope,
  });

  Future<Map<String, dynamic>?> readEnvelope({
    required HostPlatform hostPlatform,
    required String deviceBinding,
    required EmergencyCacheKind kind,
  });

  Future<void> clear({
    required HostPlatform hostPlatform,
    required String deviceBinding,
  });
}

class EncryptedEmergencyNetworkStore implements EmergencyNetworkStore {
  EncryptedEmergencyNetworkStore({
    Future<Directory> Function()? directoryResolver,
    EmergencyStoreSecretBackend? secretBackend,
    AesGcm? cipher,
    Random? random,
  })  : _directoryResolver =
            directoryResolver ?? getApplicationSupportDirectory,
        _secretBackend = secretBackend ?? FlutterEmergencyStoreSecretBackend(),
        _cipher = cipher ?? AesGcm.with256bits(),
        _random = random ?? Random.secure();

  static const _schemaVersion = 1;
  static const _maximumEnvelopeBytes = 9 * 1024 * 1024;

  final Future<Directory> Function() _directoryResolver;
  final EmergencyStoreSecretBackend _secretBackend;
  final AesGcm _cipher;
  final Random _random;

  String _scope(HostPlatform hostPlatform, String deviceBinding) {
    final binding = deviceBinding.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(binding)) {
      throw const FormatException('Emergency device binding is invalid.');
    }
    return '${hostPlatform.name}-$binding';
  }

  String _secretKey(String scope) => 'pokrov.emergency.cache-key.$scope';

  Future<Directory> _directory() async {
    final root = await _directoryResolver();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}pokrov-emergency',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _file(String scope, EmergencyCacheKind kind) async {
    final directory = await _directory();
    return File(
      '${directory.path}${Platform.pathSeparator}$scope.${kind.name}.cache',
    );
  }

  List<int> _randomBytes(int count) =>
      List<int>.generate(count, (_) => _random.nextInt(256), growable: false);

  Future<SecretKey> _loadOrCreateKey(String scope) async {
    final keyName = _secretKey(scope);
    final stored = (await _secretBackend.read(keyName))?.trim() ?? '';
    if (stored.isNotEmpty) {
      final bytes = base64Url.decode(base64Url.normalize(stored));
      if (bytes.length != 32) {
        throw const FormatException('Emergency cache key is invalid.');
      }
      return SecretKey(bytes);
    }
    final bytes = _randomBytes(32);
    await _secretBackend.write(
        keyName, base64UrlEncode(bytes).replaceAll('=', ''));
    return SecretKey(bytes);
  }

  @override
  Future<void> writeEnvelope({
    required HostPlatform hostPlatform,
    required String deviceBinding,
    required EmergencyCacheKind kind,
    required Map<String, dynamic> envelope,
  }) async {
    final scope = _scope(hostPlatform, deviceBinding);
    final plaintext = utf8.encode(jsonEncode(envelope));
    if (plaintext.isEmpty || plaintext.length > _maximumEnvelopeBytes) {
      throw const FormatException('Emergency envelope is too large.');
    }
    final key = await _loadOrCreateKey(scope);
    final nonce = _randomBytes(12);
    final box = await _cipher.encrypt(plaintext, secretKey: key, nonce: nonce);
    final encoded = jsonEncode(<String, Object?>{
      'version': _schemaVersion,
      'nonce_b64': base64UrlEncode(box.nonce).replaceAll('=', ''),
      'ciphertext_b64': base64UrlEncode(box.cipherText).replaceAll('=', ''),
      'mac_b64': base64UrlEncode(box.mac.bytes).replaceAll('=', ''),
    });
    final file = await _file(scope, kind);
    final next = File('${file.path}.next');
    final backup = File('${file.path}.bak');
    try {
      await next.writeAsString(encoded, flush: true);
      if (await backup.exists()) {
        await backup.delete();
      }
      if (await file.exists()) {
        await file.rename(backup.path);
      }
      try {
        await next.rename(file.path);
      } on Object {
        if (!await file.exists() && await backup.exists()) {
          await backup.rename(file.path);
        }
        rethrow;
      }
      if (await backup.exists()) {
        await backup.delete();
      }
    } finally {
      if (await next.exists()) {
        await next.delete();
      }
    }
  }

  @override
  Future<Map<String, dynamic>?> readEnvelope({
    required HostPlatform hostPlatform,
    required String deviceBinding,
    required EmergencyCacheKind kind,
  }) async {
    final scope = _scope(hostPlatform, deviceBinding);
    final file = await _file(scope, kind);
    if (!await file.exists()) {
      return null;
    }
    try {
      if (await file.length() > _maximumEnvelopeBytes * 2) {
        throw const FormatException('Emergency cache is too large.');
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map ||
          decoded.keys.map((key) => key.toString()).toSet().difference(
            const {'version', 'nonce_b64', 'ciphertext_b64', 'mac_b64'},
          ).isNotEmpty ||
          decoded.length != 4 ||
          decoded['version'] != _schemaVersion) {
        throw const FormatException('Emergency cache format is invalid.');
      }
      final key = await _loadOrCreateKey(scope);
      final box = SecretBox(
        base64Url
            .decode(base64Url.normalize(decoded['ciphertext_b64'].toString())),
        nonce: base64Url
            .decode(base64Url.normalize(decoded['nonce_b64'].toString())),
        mac: Mac(base64Url
            .decode(base64Url.normalize(decoded['mac_b64'].toString()))),
      );
      final plaintext = await _cipher.decrypt(box, secretKey: key);
      if (plaintext.isEmpty || plaintext.length > _maximumEnvelopeBytes) {
        throw const FormatException('Emergency cache payload is invalid.');
      }
      final envelope =
          jsonDecode(utf8.decode(plaintext, allowMalformed: false));
      if (envelope is! Map) {
        throw const FormatException('Emergency envelope is invalid.');
      }
      return envelope.map((key, value) => MapEntry(key.toString(), value));
    } on Object {
      await _deleteFile(file);
      return null;
    }
  }

  @override
  Future<void> clear({
    required HostPlatform hostPlatform,
    required String deviceBinding,
  }) async {
    final scope = _scope(hostPlatform, deviceBinding);
    for (final kind in EmergencyCacheKind.values) {
      await _deleteFile(await _file(scope, kind));
    }
    await _secretBackend.delete(_secretKey(scope));
  }

  Future<void> _deleteFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
    final backup = File('${file.path}.bak');
    if (await backup.exists()) {
      await backup.delete();
    }
    final next = File('${file.path}.next');
    if (await next.exists()) {
      await next.delete();
    }
  }
}
