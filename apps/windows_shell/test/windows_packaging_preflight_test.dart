import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _abcSha256 =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

Future<Directory> _runtimeFixture(
    {required bool staged,
    bool badDependency = false,
    bool builtBundle = false}) async {
  final fixture =
      await Directory.systemTemp.createTemp('pokrov-windows-preflight-');
  addTearDown(() async {
    final path = await fixture.resolveSymbolicLinks();
    final temp = await Directory.systemTemp.resolveSymbolicLinks();
    expect(path.startsWith('$temp${Platform.pathSeparator}'), isTrue);
    await fixture.delete(recursive: true);
  });
  final root = Directory('../..').absolute;
  for (final relative in [
    'scripts/build-windows-release.ps1',
    'scripts/candidate-ranker-asset.ps1',
    'scripts/check-client-version-parity.ps1',
    'scripts/support-signing-pin.ps1',
    'config/release-handoff.seed.json',
    'config/support-signing.seed.json',
    'apps/android_shell/pubspec.yaml',
    'apps/windows_shell/pubspec.yaml',
    'packages/app_shell/pubspec.yaml',
  ]) {
    final target = File('${fixture.path}/$relative');
    await target.parent.create(recursive: true);
    await File('${root.path}/$relative').copy(target.path);
  }
  final windows = jsonDecode(
      await File('${root.path}/config/windows-release.seed.json')
          .readAsString()) as Map<String, dynamic>;
  final runtime = windows['runtime'] as Map<String, dynamic>;
  runtime['artifact_directory'] = 'fixture-runtime';
  runtime['core_binary'] = 'pokrov-core.dll';
  runtime['runtime_dependencies'] = ['libcronet.dll'];
  runtime.remove('helper_binary');
  // Stop immediately after runtime preparation: no compiler, signing, archive,
  // installer or installed/private runtime is ever reached by this fixture.
  (windows['app_local_msvc_runtime'] as Map)['required_files'] =
      builtBundle ? ['fixture-msvc.dll'] : [];
  if (builtBundle) {
    windows['bundle_root'] = 'fixture-build';
    windows['required_files'] = [
      'pokrov_windows.exe',
      'pokrov-core.dll',
      'libcronet.dll',
      'fixture-msvc.dll'
    ];
    await Directory('${fixture.path}/fixture-build').create();
    await File('${fixture.path}/fixture-build/pokrov_windows.exe')
        .writeAsString('not a PE executable');
    await File('${fixture.path}/fixture-build/pokrov-core.dll')
        .writeAsString('abc');
    await File('${fixture.path}/fixture-build/libcronet.dll')
        .writeAsString('old');
    await Directory('${fixture.path}/fixture-msvc').create();
    await File('${fixture.path}/fixture-msvc/fixture-msvc.dll')
        .writeAsString('abc');
    // Stub only the OS signer check for the fake MSVC fixture. The real builder
    // must reject stale Core dependencies before reaching the non-PE executable.
    await File('${fixture.path}/bundle-preflight.ps1').writeAsString(r'''
function Get-AuthenticodeSignature {
  param([string]$FilePath)
  if ((Split-Path -Leaf $FilePath) -ne 'fixture-msvc.dll') { throw 'Unexpected signer check.' }
  [pscustomobject]@{
    Status = [System.Management.Automation.SignatureStatus]::Valid
    SignerCertificate = [pscustomobject]@{ Subject = 'Microsoft test fixture' }
  }
}
& (Join-Path $PSScriptRoot 'scripts/build-windows-release.ps1') `
  -SkipBuild -SkipZip -SkipInstaller -SyncRuntime `
  -CandidateRankerModelPath (Join-Path $PSScriptRoot 'ranker.bin') `
  -RuntimeArtifactsPath (Join-Path $PSScriptRoot 'runtime.json') `
  -CoreArtifactDirectory (Join-Path $PSScriptRoot 'source-runtime') `
  -MsvcRuntimeDirectory (Join-Path $PSScriptRoot 'fixture-msvc')
''');
  }
  await File('${fixture.path}/config/windows-release.seed.json')
      .writeAsString(jsonEncode(windows));
  final manifest = jsonDecode(
      await File('${root.path}/config/runtime-artifacts.seed.json')
          .readAsString()) as Map<String, dynamic>;
  (manifest['core']['assets'] as Map)['windows'] = {
    'entry': 'pokrov-core.dll',
    'sync_destination': 'fixture-runtime',
    'size': 3,
    'sha256': _abcSha256,
    'runtime_dependencies': ['libcronet.dll'],
    'runtime_dependency_size': {'libcronet.dll': 3},
    'runtime_dependency_sha256': {'libcronet.dll': _abcSha256},
  };
  await File('${fixture.path}/runtime.json')
      .writeAsString(jsonEncode(manifest));
  // The builder validates the model's header/length before runtime preflight.
  // These fixture bytes are never used for inference or an application build.
  await Directory('${fixture.path}/packages/app_shell/assets/models')
      .create(recursive: true);
  final model = File('${fixture.path}/ranker.bin');
  await model.writeAsBytes(utf8.encode('PKRTF001'));
  final modelHandle = await model.open(mode: FileMode.append);
  await modelHandle.truncate(3734808);
  await modelHandle.close();
  if (builtBundle) {
    final builtModel = File('${fixture.path}/fixture-build/data/flutter_assets/'
        'packages/pokrov_app_shell/assets/models/candidate-ranker-v1.bin');
    await builtModel.parent.create(recursive: true);
    await model.copy(builtModel.path);
  }
  await Directory('${fixture.path}/source-runtime').create();
  await File('${fixture.path}/source-runtime/pokrov-core.dll')
      .writeAsString('abc');
  await File('${fixture.path}/source-runtime/libcronet.dll')
      .writeAsString(badDependency ? 'bad' : 'abc');
  if (staged) {
    await Directory('${fixture.path}/fixture-runtime').create();
    await File('${fixture.path}/fixture-runtime/pokrov-core.dll')
        .writeAsString('old');
    await File('${fixture.path}/fixture-runtime/libcronet.dll')
        .writeAsString('old');
  }
  await File('${fixture.path}/scripts/sync-pokrov-core-runtime.ps1')
      .writeAsString(r'''
param($CoreRoot, $RuntimeArtifactsPath, $CoreArtifactDirectory, [string[]]$Platforms)
$ErrorActionPreference = 'Stop'
if (($Platforms -join ',') -ne 'windows') { throw 'Fixture permits Windows-only sync.' }
$root = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $root 'fixture-runtime'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
foreach ($name in @('pokrov-core.dll', 'libcronet.dll')) {
  Copy-Item -LiteralPath (Join-Path $CoreArtifactDirectory $name) -Destination $destination -Force
}
$global:LASTEXITCODE = 0
''');
  return fixture;
}

Future<ProcessResult> _preflight(Directory fixture,
        {required bool sync, bool builtBundle = false}) =>
    Process.run('pwsh', [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-File',
      if (builtBundle)
        '${fixture.path}/bundle-preflight.ps1'
      else ...[
        '${fixture.path}/scripts/build-windows-release.ps1',
        '-SkipBuild',
        '-SkipZip',
        '-SkipInstaller',
        '-CandidateRankerModelPath',
        '${fixture.path}/ranker.bin',
        if (sync) '-SyncRuntime',
        '-RuntimeArtifactsPath',
        '${fixture.path}/runtime.json',
        '-CoreArtifactDirectory',
        '${fixture.path}/source-runtime',
      ],
    ], environment: {
      'POKROV_WINDOWS_SIGNING_CERTIFICATE_THUMBPRINT': '',
      'POKROV_WINDOWS_SIGNING_EXPECTED_SUBJECT': '',
      'POKROV_WINDOWS_SIGNING_TIMESTAMP_URL': '',
      'POKROV_SUPPORT_SIGNING_KEY_ID': '',
      'POKROV_SUPPORT_SIGNING_PUBLIC_KEY_B64': '',
    });

void main() {
  test('runtime sync keeps the selected Zapret2 dependency subdirectory', () async {
    final fixture = await _runtimeFixture(staged: true);
    final sourceRoot = Directory('../..').absolute;
    await File('${sourceRoot.path}/scripts/sync-pokrov-core-runtime.ps1')
        .copy('${fixture.path}/scripts/sync-pokrov-core-runtime.ps1');
    final core = Directory('${fixture.path}/core');
    await core.create();
    await File('${core.path}/VERSION').writeAsString('1.2.14\n');
    for (final args in [
      ['init', '--quiet', core.path],
      ['-C', core.path, 'add', 'VERSION'],
      ['-C', core.path, '-c', 'commit.gpgSign=false', '-c', 'user.name=Packaging fixture',
        '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '-m', 'fixture'],
    ]) {
      expect((await Process.run('git', args)).exitCode, 0);
    }
    final commit = await Process.run('git', ['-C', core.path, 'rev-parse', 'HEAD']);
    expect(commit.exitCode, 0);
    final manifestFile = File('${fixture.path}/runtime.json');
    final manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    final selectedCore = manifest['core'] as Map<String, dynamic>;
    selectedCore['source_commit'] = (commit.stdout as String).trim();
    final windows = selectedCore['assets']['windows'] as Map<String, dynamic>;
    const nested = 'local-dpi/winws2.exe';
    (windows['runtime_dependencies'] as List).add(nested);
    (windows['runtime_dependency_size'] as Map)[nested] = 3;
    (windows['runtime_dependency_sha256'] as Map)[nested] = _abcSha256;
    await manifestFile.writeAsString(jsonEncode(manifest));
    final nestedSource = File('${fixture.path}/source-runtime/$nested');
    await nestedSource.parent.create();
    await nestedSource.writeAsString('abc');
    final result = await Process.run('pwsh', [
      '-NoLogo', '-NoProfile', '-NonInteractive', '-File',
      '${fixture.path}/scripts/sync-pokrov-core-runtime.ps1',
      '-CoreRoot', core.path, '-RuntimeArtifactsPath', manifestFile.path,
      '-CoreArtifactDirectory', '${fixture.path}/source-runtime', '-Platforms', 'windows',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(await File('${fixture.path}/fixture-runtime/$nested').readAsString(), 'abc');
    expect(await File('${fixture.path}/fixture-runtime/winws2.exe').exists(), isFalse);
  }, skip: !Platform.isWindows);

  test('packaging excludes old engines and unselected local DPI files', () async {
    final fixture = await _runtimeFixture(staged: true, builtBundle: true);
    await File('${fixture.path}/fixture-build/libcronet.dll').writeAsString('abc');
    final configFile = File('${fixture.path}/config/windows-release.seed.json');
    final config = jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    (config['required_files'] as List).addAll(['local-dpi/winws2.exe', 'local-dpi/zapret-lib.lua']);
    await configFile.writeAsString(jsonEncode(config));
    final dpi = Directory('${fixture.path}/fixture-build/local-dpi');
    await dpi.create();
    for (final name in ['winws2.exe', 'zapret-lib.lua', 'winws.exe', 'install.bat']) {
      await File('${dpi.path}/$name').writeAsString('fixture');
    }
    final wrapper = File('${fixture.path}/bundle-preflight.ps1');
    final preflight = await wrapper.readAsString();
    // Fake executable metadata only; this fixture never runs a client binary.
    await wrapper.writeAsString(r'''
function Get-Item {
  param([string]$LiteralPath)
  $item = Microsoft.PowerShell.Management\Get-Item -LiteralPath $LiteralPath
  if ($LiteralPath -like '*fixture-build*pokrov_windows.exe') {
    $config = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'config/windows-release.seed.json')) | ConvertFrom-Json
    $versionText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'apps/windows_shell/pubspec.yaml'))
    $version = [regex]::Match($versionText, '(?m)^version:\s*(\S+)').Groups[1].Value
    return [pscustomobject]@{ VersionInfo = [pscustomobject]@{
      CompanyName = $config.metadata.company_name; FileDescription = $config.metadata.file_description
      ProductName = $config.metadata.product_name; FileVersion = $version; ProductVersion = $version
    } }
  }
  return $item
}
''' + preflight);
    final result = await _preflight(fixture, sync: true, builtBundle: true);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final stageRoot = Directory('${fixture.path}/apps/windows_shell/build/release_bundle');
    final bundle = (await stageRoot.list().where((entry) => entry is Directory).first).path;
    expect((await Directory('$bundle/local-dpi').list().map((f) => f.uri.pathSegments.last).toList())..sort(),
        ['winws2.exe', 'zapret-lib.lua']);
  }, skip: !Platform.isWindows);

  for (final staged in [true, false]) {
    test(
        staged
            ? 'explicit sync replaces old runtime before binding validation'
            : 'missing runtime is restored before binding validation',
        () async {
      final fixture = await _runtimeFixture(staged: staged);
      final result = await _preflight(fixture, sync: staged);
      expect(result.exitCode, isNot(0));
      expect(
          '${result.stdout}\n${result.stderr}',
          contains(
              'Windows release config must declare app-local Microsoft VC runtime files.'));
      expect(
          await File('${fixture.path}/fixture-runtime/pokrov-core.dll')
              .readAsString(),
          'abc');
      expect(
          await File('${fixture.path}/fixture-runtime/libcronet.dll')
              .readAsString(),
          'abc');
    }, skip: !Platform.isWindows);
  }
  test('synced dependency still has to match the selected manifest', () async {
    final fixture = await _runtimeFixture(staged: true, badDependency: true);
    final result = await _preflight(fixture, sync: true);
    expect(result.exitCode, isNot(0));
    expect('${result.stdout}\n${result.stderr}',
        contains('Core artifact does not match the release binding:'));
    expect(
        await File('${fixture.path}/fixture-runtime/pokrov-core.dll')
            .readAsString(),
        'abc');
    expect(
        await File('${fixture.path}/fixture-runtime/libcronet.dll')
            .readAsString(),
        'bad');
  }, skip: !Platform.isWindows);
  test('repackaging rejects a stale built dependency after runtime sync',
      () async {
    final fixture = await _runtimeFixture(staged: true, builtBundle: true);
    final stale = await _preflight(fixture, sync: true, builtBundle: true);
    expect(stale.exitCode, isNot(0));
    expect(
        '${stale.stdout}\n${stale.stderr}',
        contains(
            'Built Windows runtime differs from the selected binding: libcronet.dll'));

    await File('${fixture.path}/fixture-build/libcronet.dll')
        .writeAsString('abc');
    final matching = await _preflight(fixture, sync: true, builtBundle: true);
    expect(matching.exitCode, isNot(0));
    expect('${matching.stdout}\n${matching.stderr}',
        contains('CompanyName must be'));
    expect(
        await Directory(
                '${fixture.path}/apps/windows_shell/build/release_bundle')
            .exists(),
        isFalse);
  }, skip: !Platform.isWindows);
  test('repackaging cannot label an executable with a different client version',
      () async {
    final fixture = await _runtimeFixture(staged: true, builtBundle: true);
    await File('${fixture.path}/fixture-build/libcronet.dll')
        .writeAsString('abc');
    final wrapper = File('${fixture.path}/bundle-preflight.ps1');
    final preflight = await wrapper.readAsString();
    // Use an existing public PE, without compiling or reading a client build.
    // Its identity matches the fixture contract; only its release is different.
    await wrapper.writeAsString(r'''
$sample = Get-Item -LiteralPath (Join-Path $PSHOME 'pwsh.exe')
Copy-Item -LiteralPath $sample.FullName -Destination (Join-Path $PSScriptRoot 'fixture-build/pokrov_windows.exe')
$configPath = Join-Path $PSScriptRoot 'config/windows-release.seed.json'
$config = [IO.File]::ReadAllText($configPath) | ConvertFrom-Json
$config.metadata.company_name = $sample.VersionInfo.CompanyName
$config.metadata.file_description = $sample.VersionInfo.FileDescription
$config.metadata.product_name = $sample.VersionInfo.ProductName
[IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Depth 10))
''' +
        preflight);
    final result = await _preflight(fixture, sync: true, builtBundle: true);
    expect(result.exitCode, isNot(0));
    expect(
        '${result.stdout}\n${result.stderr}', contains('FileVersion must be'));
    expect('${result.stdout}\n${result.stderr}',
        contains('ProductVersion must be'));
    expect(
        await Directory(
                '${fixture.path}/apps/windows_shell/build/release_bundle')
            .exists(),
        isFalse);
  }, skip: !Platform.isWindows);
}
