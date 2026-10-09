import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {

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

}
