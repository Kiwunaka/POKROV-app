import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android manifest declares special-use foreground service permission',
      () async {
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
    expect(content, contains('android.permission.POST_NOTIFICATIONS'));
  });

  test('android backup rules exclude secure session material', () async {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final extractionRules = File(
      'android/app/src/main/res/xml/pokrov_data_extraction_rules.xml',
    );

    expect(await manifest.exists(), isTrue);
    expect(await extractionRules.exists(), isTrue);

    final manifestContent = await manifest.readAsString();
    expect(manifestContent, contains('android:allowBackup="false"'));
    expect(manifestContent, contains('android:fullBackupContent="false"'));
    expect(
      manifestContent,
      contains(
        'android:dataExtractionRules="@xml/pokrov_data_extraction_rules"',
      ),
    );

    final rulesContent = await extractionRules.readAsString();
    expect(rulesContent, contains('<cloud-backup'));
    expect(rulesContent, contains('<device-transfer'));
    for (final domain in <String>[
      'root',
      'file',
      'database',
      'sharedpref',
      'external',
      'device_root',
      'device_file',
      'device_database',
      'device_sharedpref',
    ]) {
      expect(
        RegExp('<exclude domain="$domain" path="\\."').allMatches(rulesContent),
        hasLength(2),
        reason:
            '$domain must be excluded from cloud backup and device transfer',
      );
    }
  });

  test('android acquisition continuation is an exact browsable deep link',
      () async {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final activity = File(
      'android/app/src/main/kotlin/space/pokrov/pokrov_android_shell/MainActivity.kt',
    );
    final manifestContent = await manifest.readAsString();
    final activityContent = await activity.readAsString();

    expect(manifestContent, contains('android:scheme="pokrov"'));
    expect(manifestContent, contains('android:host="acquisition"'));
    expect(manifestContent, contains('android:path="/continue"'));
    expect(manifestContent, contains('android.intent.category.BROWSABLE'));
    expect(
      activityContent,
      contains('const val ACQUISITION_LINKS_CHANNEL_NAME'),
    );
    expect(activityContent, contains('uri.path != "/continue"'));
    expect(activityContent, isNot(contains('Log.')));
  });

  test('android runtime service source keeps foreground failures sanitized',
      () async {
    final serviceSource = File(
      'android/app/src/main/kotlin/space/pokrov/pokrov_android_shell/PokrovRuntimeVpnService.kt',
    );
    expect(await serviceSource.exists(), isTrue);

    final content = await serviceSource.readAsString();
    expect(content, contains('FOREGROUND_SERVICE_TYPE_SPECIAL_USE'));
    expect(content, contains('AndroidRuntimeSafety.publicFailureMessage('));
    expect(
      content,
      isNot(contains('Android runtime foreground start failed:", error')),
    );
  });

  test('quick settings tile uses active mode and a monochrome vector icon',
      () async {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final tileIcon = File(
      'android/app/src/main/res/drawable/ic_pokrov_system.xml',
    );

    final manifestContent = await manifest.readAsString();
    final iconContent = await tileIcon.readAsString();

    expect(
      manifestContent,
      contains('android:icon="@drawable/ic_pokrov_system"'),
    );
    expect(
      manifestContent,
      contains('android:name="android.service.quicksettings.ACTIVE_TILE"'),
    );
    expect(
      manifestContent,
      isNot(
        contains(
            'android:name="android.service.quicksettings.TOGGLEABLE_TILE"'),
      ),
    );
    expect(iconContent, contains('<vector'));
    expect(iconContent, contains('android:width="24dp"'));
    expect(iconContent, contains('android:height="24dp"'));
    expect(iconContent, contains('android:fillColor="#FFFFFFFF"'));
  });

  test('quick settings tile refreshes when first added', () async {
    final serviceSource = File(
      'android/app/src/main/kotlin/space/pokrov/pokrov_android_shell/PokrovQuickSettingsTileService.kt',
    );

    final content = await serviceSource.readAsString();
    expect(content, contains('override fun onTileAdded()'));
    expect(content, contains('super.onTileAdded()'));
    expect(content, contains('transitionHandler.post(::refreshTile)'));
  });
}
