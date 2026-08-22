import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Directory> _repositoryRoot() async {
  for (final path in <String>['.', '../..']) {
    final candidate = Directory(path).absolute;
    if (await File(
      '${candidate.path}${Platform.pathSeparator}config'
      '${Platform.pathSeparator}state-migrations.v1.json',
    ).exists()) {
      return candidate;
    }
  }
  throw const FileSystemException('Client repository root not found');
}

String _path(Directory root, String relative) =>
    '${root.path}${Platform.pathSeparator}'
    '${relative.replaceAll('/', Platform.pathSeparator)}';

Future<String> _sha256(File file) async {
  final digest = await Sha256().hash(await file.readAsBytes());
  return digest.bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
}

void main() {
  test('migration registry binds supported 1.1.x fixtures and rollback policy',
      () async {
    final root = await _repositoryRoot();
    final contractFile = File(_path(root, 'config/state-migrations.v1.json'));
    final contract =
        jsonDecode(await contractFile.readAsString()) as Map<String, dynamic>;

    expect(contract['contract_id'], 'pokrov.client-state-migrations.v1');
    expect(contract['schema_version'], 1);
    expect(contract['state'], 'PRE_CANDIDATE_LOCAL');
    expect(contract['source_product_range'], '>=1.1.0 <1.2.0');
    expect(
      contract['fixture_policy'],
      containsPair('production_data_forbidden', true),
    );
    final target = contract['target'] as Map<String, dynamic>;
    expect(target['product_version'], '1.2.0');
    expect(target['android_windows_build_number'], 30);

    final migrations =
        (contract['migrations'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(migrations, hasLength(5));
    expect(migrations.map((item) => item['id']).toSet(), hasLength(5));
    expect(migrations.map((item) => item['fixture']).toSet(), hasLength(5));

    for (final migration in migrations) {
      expect(migration['owner'], isNotEmpty);
      expect(migration['platforms'], isNotEmpty);
      expect(migration['source_schema'], contains('1.1.x'));
      expect(migration['target_schema'], isNotEmpty);
      expect(migration['migration_behavior'], isNotEmpty);
      expect(migration['rollback_policy'], isNotEmpty);
      final fixture = File(_path(root, migration['fixture'] as String));
      expect(await fixture.exists(), isTrue, reason: '${migration['id']}');
      expect(
        await _sha256(fixture),
        migration['fixture_sha256'],
        reason: '${migration['id']} fixture drift',
      );
      final testFile = File(_path(root, migration['test_file'] as String));
      expect(await testFile.exists(), isTrue, reason: '${migration['id']}');
      expect(
        await testFile.readAsString(),
        contains(migration['test_name'] as String),
        reason: '${migration['id']} lost its named regression',
      );
    }

    final nonMigrating = (contract['non_migrating_state'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      nonMigrating.map((item) => item['id']).toSet(),
      <String>{'android_update_cache', 'windows_runtime_recovery_journal'},
    );
    for (final state in nonMigrating) {
      expect(state['owner'], isNotEmpty);
      expect(state['policy'], isNotEmpty);
      expect(
        await File(_path(root, state['test_file'] as String)).exists(),
        isTrue,
      );
    }

    final appShellPubspec =
        await File(_path(root, 'packages/app_shell/pubspec.yaml'))
            .readAsString();
    final androidPubspec =
        await File(_path(root, 'apps/android_shell/pubspec.yaml'))
            .readAsString();
    final windowsPubspec =
        await File(_path(root, 'apps/windows_shell/pubspec.yaml'))
            .readAsString();
    expect(appShellPubspec, contains('version: 1.2.0'));
    expect(androidPubspec, contains('version: 1.2.0+30'));
    expect(windowsPubspec, contains('version: 1.2.0+30'));
  });
}
