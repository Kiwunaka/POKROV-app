import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android manifest declares special-use foreground service permission', () async {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(await manifest.exists(), isTrue);

    final content = await manifest.readAsString();
    expect(
      content,
      contains('android.permission.FOREGROUND_SERVICE_SPECIAL_USE'),
    );
    expect(
      content,
      contains('android:foregroundServiceType="specialUse"'),
    );
  });

  test('android runtime service source hardens foreground start failures', () async {
    final serviceSource = File(
      'android/app/src/main/kotlin/space/pokrov/pokrov_android_shell/PokrovRuntimeVpnService.kt',
    );
    expect(await serviceSource.exists(), isTrue);

    final content = await serviceSource.readAsString();
    expect(content, contains('FOREGROUND_SERVICE_TYPE_SPECIAL_USE'));
    expect(content, contains('Android runtime foreground start failed:'));
  });
}
