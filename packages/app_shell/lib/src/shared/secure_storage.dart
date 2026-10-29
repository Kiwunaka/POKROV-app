import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Windows stores every key in one DPAPI file, including unrelated features.
class PokrovSecureStorage {
  PokrovSecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static Future<void> _windowsOperations = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    if (!Platform.isWindows) return operation();
    final next = _windowsOperations.then((_) => operation());
    // The caller receives the original failure; it must not poison later IO.
    _windowsOperations = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<String?> read({required String key}) =>
      _serialize(() => _storage.read(key: key));

  Future<void> write({required String key, required String value}) =>
      _serialize(() => _storage.write(key: key, value: value));

  Future<void> delete({required String key}) =>
      _serialize(() => _storage.delete(key: key));
}
