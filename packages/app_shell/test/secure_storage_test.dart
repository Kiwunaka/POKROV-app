import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_app_shell/src/shared/secure_storage.dart';
import 'package:pokrov_core_domain/core_domain.dart';

// The Windows backend loads and rewrites the entire DPAPI map for each key.
class _SharedFileStorage extends TestFlutterSecureStoragePlatform {
  _SharedFileStorage() : super({});

  final writing = Completer<void>();
  final finishWrite = Completer<void>();
  var writeCalls = 0;
  var readCalls = 0;
  var deleteCalls = 0;
  Object? readFailure;

  @override
  Future<void> write({required String key, required String value,
      required Map<String, String> options}) async {
    final next = {...data, key: value};
    if (++writeCalls == 1) {
      writing.complete();
      await finishWrite.future;
    }
    data..clear()..addAll(next);
  }

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async {
    readCalls++;
    if (readFailure case final error?) throw error;
    if (writing.isCompleted && !finishWrite.isCompleted) {
      throw const PathAccessException('', OSError('', 32), 'synthetic sharing conflict');
    }
    return super.read(key: key, options: options);
  }

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    deleteCalls++;
    return super.delete(key: key, options: options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows session rotation and other secure keys share one file queue', () async {
    final previous = FlutterSecureStoragePlatform.instance;
    final backend = _SharedFileStorage();
    FlutterSecureStoragePlatform.instance = backend;
    addTearDown(() => FlutterSecureStoragePlatform.instance = previous);
    final sessions = FlutterSecureAppFirstSessionSecretStore();
    final metadata = PokrovSecureStorage();
    const pair = AppFirstSessionCredentials(accessToken: 'synthetic-rotated-access',
        refreshToken: 'synthetic-rotated-refresh');
    final rotation = sessions.writeSessionPair(hostPlatform: HostPlatform.windows,
        installId: 'fixture', pair: pair);
    await backend.writing.future;
    final otherWrite = metadata.write(key: 'catalog-fixture', value: 'synthetic-catalog');
    final read = sessions.readSessionPair(hostPlatform: HostPlatform.windows, installId: 'fixture');
    final removed = metadata.delete(key: 'obsolete-fixture');
    final completion = Future.wait<Object?>([rotation, otherWrite, read, removed]);
    await Future<void>.delayed(Duration.zero);
    try {
      expect((backend.writeCalls, backend.readCalls, backend.deleteCalls), (1, 0, 0));
    } finally {
      backend.finishWrite.complete();
      await completion;
    }
    final restored = await read;
    expect((restored?.accessToken, restored?.refreshToken), (pair.accessToken, pair.refreshToken));
    expect(backend.data['catalog-fixture'], 'synthetic-catalog');
    expect(backend.data.length, 2);
  }, skip: !Platform.isWindows);

  test('Windows secure read preserves persistent failure without retries or writes', () async {
    final previous = FlutterSecureStoragePlatform.instance;
    final backend = _SharedFileStorage();
    FlutterSecureStoragePlatform.instance = backend;
    addTearDown(() => FlutterSecureStoragePlatform.instance = previous);
    const failure = PathAccessException('', OSError('', 5), 'synthetic denied');
    backend.readFailure = failure;
    final sessions = FlutterSecureAppFirstSessionSecretStore();
    for (var attempt = 0; attempt < 2; attempt++) {
      await expectLater(sessions.readSessionPair(hostPlatform: HostPlatform.windows,
          installId: 'fixture'), throwsA(same(failure)));
    }
    expect((backend.readCalls, backend.writeCalls, backend.deleteCalls), (2, 0, 0));
    backend.readFailure = null;
    backend.data['fixture'] = 'synthetic-retained';
    expect(await PokrovSecureStorage().read(key: 'fixture'), 'synthetic-retained');
  }, skip: !Platform.isWindows);
}
