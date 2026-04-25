import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('windows release contract is libcore-only', () async {
    final releaseConfig = File('../../config/windows-release.seed.json');
    final runtimeConfig = File('../../config/runtime-artifacts.seed.json');

    expect(await releaseConfig.exists(), isTrue);
    expect(await runtimeConfig.exists(), isTrue);

    final releaseJson =
        jsonDecode(await releaseConfig.readAsString()) as Map<String, dynamic>;
    final runtimeJson =
        jsonDecode(await runtimeConfig.readAsString()) as Map<String, dynamic>;

    final requiredFiles =
        (releaseJson['required_files'] as List<dynamic>).cast<String>();
    expect(releaseJson['channel'], 'gated_beta');
    expect(releaseJson['binary_name'], 'pokrov_windows_beta.exe');
    expect(releaseJson['public_approved'], isFalse);
    expect(releaseJson['artifact_status'], 'unsigned_beta');
    expect(requiredFiles, isNot(contains('HiddifyCli.exe')));
    expect(requiredFiles, contains('pokrov_windows_beta.exe'));
    expect(requiredFiles, isNot(contains('pokrov_windows_seed.exe')));

    final signing = releaseJson['signing'] as Map<String, dynamic>;
    expect(signing['status'], 'unsigned_beta_blocker');
    expect(
      (signing['user_warning'] as String).toLowerCase(),
      contains('smartscreen'),
    );

    final runtime = releaseJson['runtime'] as Map<String, dynamic>;
    expect(runtime.containsKey('helper_binary'), isFalse);

    final libcore = runtimeJson['libcore'] as Map<String, dynamic>;
    final assets = libcore['assets'] as Map<String, dynamic>;
    final windows = assets['windows'] as Map<String, dynamic>;
    expect(windows.containsKey('helper'), isFalse);
  });
}
