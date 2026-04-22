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
    expect(requiredFiles, isNot(contains('HiddifyCli.exe')));

    final runtime = releaseJson['runtime'] as Map<String, dynamic>;
    expect(runtime.containsKey('helper_binary'), isFalse);

    final libcore = runtimeJson['libcore'] as Map<String, dynamic>;
    final assets = libcore['assets'] as Map<String, dynamic>;
    final windows = assets['windows'] as Map<String, dynamic>;
    expect(windows.containsKey('helper'), isFalse);
  });
}
