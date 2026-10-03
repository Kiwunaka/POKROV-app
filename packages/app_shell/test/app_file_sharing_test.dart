import 'dart:io';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_app_shell/src/features/update/app_file_sharing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'Windows sharing saves verified bytes and rejects tampering or cancellation',
      () async {
    final temporary =
        await Directory.systemTemp.createTemp('pokrov-file-sharing-');
    addTearDown(() => temporary.delete(recursive: true));
    final source = File('${temporary.path}/selected.exe');
    final saved = File('${temporary.path}/saved.exe');
    final rejected = File('${temporary.path}/rejected.exe');
    final original = Uint8List.fromList([77, 90, 1, 2, 3, 4]);
    final tampered = Uint8List.fromList([77, 90, 1, 2, 3, 5]);
    final digest = (await Sha256().hash(original))
        .bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final update = ClientAppUpdateInfo(
      platform: 'windows',
      channel: 'stable',
      latestVersion: '1.4.3',
      minSupportedVersion: '1.0.0',
      updatePolicy: 'recommended',
      url:
          'https://github.com/Kiwunaka/pokrov/releases/download/v1.4.3/pokrov-windows-setup-x64.exe',
      sha256: digest,
      size: original.length,
      releaseNotes: '',
      releaseNotesUrl: '',
      publishedAt: '2026-10-04T00:00:00Z',
    );

    const channel = MethodChannel('plugins.flutter.io/file_selector');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var saveDialogCalls = 0;
    var changeSourceAtSave = true;
    String? destination = saved.path;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'openFile':
          return [source.path];
        case 'getSavePath':
          saveDialogCalls++;
          if (changeSourceAtSave) await source.writeAsBytes(tampered);
          return destination;
        default:
          throw StateError('Unexpected file-selector method');
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await source.writeAsBytes(original);
    expect(await saveVerifiedPokrovWindowsInstaller(update), 'saved');
    expect(await saved.readAsBytes(), orderedEquals(original));
    expect(await source.readAsBytes(), orderedEquals(tampered));
    expect(saveDialogCalls, 1);

    changeSourceAtSave = false;
    destination = rejected.path;
    expect(await source.length(), original.length);
    expect(await saveVerifiedPokrovWindowsInstaller(update), 'invalid');
    expect(saveDialogCalls, 1);
    expect(await rejected.exists(), isFalse);

    await source.writeAsBytes(original);
    destination = null;
    final filesBeforeCancel =
        temporary.listSync().map((file) => file.path).toSet();
    expect(await saveVerifiedPokrovWindowsInstaller(update), 'cancelled');
    expect(saveDialogCalls, 2);
    expect(temporary.listSync().map((file) => file.path).toSet(),
        filesBeforeCancel);
    expect(await source.readAsBytes(), orderedEquals(original));
    expect(await saved.readAsBytes(), orderedEquals(original));
  });
}
