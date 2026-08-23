import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'Android update bridge sends bounded identity fields and maps store handoff',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return <String, Object?>{'status': 'store_opened'};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    const update = ClientAppUpdateInfo(
      platform: 'android',
      channel: 'stable',
      latestVersion: '1.2.0',
      minSupportedVersion: '1.0.0',
      updatePolicy: 'recommended',
      url:
          'https://github.com/Kiwunaka/pokrov/releases/download/v1.2.0/pokrov-android.apk',
      sha256:
          'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      size: 123456,
      releaseNotes: '',
      releaseNotesUrl: '',
      publishedAt: '2026-08-21T00:00:00Z',
    );

    final result =
        await installPokrovClientUpdate(HostPlatform.android, update);

    expect(result, PokrovClientUpdateInstallStatus.storeOpened);
    expect(received?.method, 'runtimeEngine.installClientUpdate');
    expect(
      received?.arguments,
      <String, Object?>{
        'url': update.url,
        'sha256': update.sha256.toLowerCase(),
        'size': update.size,
        'channel': 'stable',
        'version': '1.2.0',
      },
    );
  });
}
