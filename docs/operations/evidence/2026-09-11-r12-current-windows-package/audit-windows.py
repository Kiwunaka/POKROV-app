from pathlib import Path
import datetime, hashlib, json, re
import pefile
import subprocess

root = Path('C:/r12-current-windows-source-20260911')
out = Path('E:/r12-current-windows-package-20260911')
release = root / 'apps/windows_shell/build/release_bundle'
bundle = release / 'pokrov-windows-x64-1.2.0+4053'
manifest_path = release / 'pokrov-windows-x64-1.2.0+4053.manifest.json'
installer = release / 'pokrov-windows-x64-1.2.0+4053-setup.exe'
sha = lambda b: hashlib.sha256(b).hexdigest()
def ref(p):
    return {'path': str(p), 'size': p.stat().st_size, 'sha256': sha(p.read_bytes())}
assert not (out / 'windows-package-audit.json').exists()
revision = subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'], text=True).strip()
assert revision == 'd9763e8cd7aba9b215015e07c0576f667c1dec09'
manifest = json.loads(manifest_path.read_bytes())
app_snapshot = (bundle / 'data/app.so').read_bytes()
assert revision.encode() in app_snapshot, 'Exact client revision missing from AOT payload'
previous_revision = b'7ed18c97c43ba39ce18701220d487af1b0c5a446'
revision_binding = {'expected_revision_present_in_aot': True, 'previous_package_revision_present_in_aot': previous_revision in app_snapshot}
seed = json.loads((root / 'config/runtime-artifacts.seed.json').read_bytes())['core']
assert manifest['version'] == '1.2.0+4053'
assert manifest['signing']['status'] == 'SKIPPED_BY_OWNER'
assert sha(installer.read_bytes()) == manifest['installer_sha256'].lower()
for row in manifest['required_files']:
    p = bundle / row['path']
    assert p.stat().st_size == row['size_bytes']
    assert sha(p.read_bytes()) == row['sha256'].lower()
assert sha((bundle / 'pokrov-core.dll').read_bytes()) == seed['assets']['windows']['sha256']
assert sha((bundle / 'libcronet.dll').read_bytes()) == seed['artifact_provenance']['reproducible_build']['libcronet_sha256']
old_binding_path = Path('E:/r12-c05-flutter-native/engine-binary-binding.json')
old_binding = json.loads(old_binding_path.read_bytes())
flutter = next(r for r in old_binding['components'] if r['component'] == 'windows Flutter DLL')
assert sha((bundle / 'flutter_windows.dll').read_bytes()) == flutter['sha256']
notices = {
    'libcronet.NOTICES.txt': root / 'apps/windows_shell/windows/runner/resources/runtime/libcronet.NOTICES.txt',
    'data/flutter_assets/packages/pokrov_app_shell/assets/fonts/OFL.txt': root / 'packages/app_shell/assets/fonts/OFL.txt',
    'data/flutter_assets/packages/pokrov_app_shell/assets/licenses/native-go-NOTICES.txt': root / 'packages/app_shell/assets/licenses/native-go-NOTICES.txt',
}
for rel, source in notices.items():
    assert (bundle / rel).read_bytes() == source.read_bytes(), rel
assert (bundle / 'data/flutter_assets/NOTICES.Z').stat().st_size > 0
files = sorted(p for p in bundle.rglob('*') if p.is_file())
assert {p.relative_to(bundle).as_posix() for p in files if p.suffix.lower() == '.exe'} == {'pokrov_windows.exe', 'pokrov_service.exe'}
for p in files:
    assert not re.search(r'(?i)(?:\.(?:p12|pfx|pem|key|jks|keystore|log|pdb|lib|exp|aar)$|(?:^|/)\.env(?:\.|$))', p.relative_to(bundle).as_posix()), p.name
inventory = [{**ref(p), 'relative_path': p.relative_to(bundle).as_posix()} for p in files]
imports = []
for p in files + [installer]:
    if p.suffix.lower() not in ('.exe', '.dll'): continue
    pe = pefile.PE(str(p), fast_load=True)
    pe.parse_data_directories(directories=[pefile.DIRECTORY_ENTRY['IMAGE_DIRECTORY_ENTRY_IMPORT'], pefile.DIRECTORY_ENTRY['IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT']])
    imports.append({'file': ref(p), 'machine': pe.FILE_HEADER.Machine,
                    'imports': sorted({x.dll.decode('ascii') for kind in ('DIRECTORY_ENTRY_IMPORT', 'DIRECTORY_ENTRY_DELAY_IMPORT') for x in getattr(pe, kind, [])})})
    pe.close()
result = {'schema': 'pokrov.r12.final-windows-package-audit/v1',
          'observed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'client_revision': revision, 'core_revision': seed['source_commit'], 'aot_revision_binding': revision_binding,
          'build_log': ref(out / 'build.log'),
          'installer': ref(installer), 'packager_script': ref(Path(str(installer) + '.iss')),
          'manifest': ref(manifest_path), 'required_files_verified': len(manifest['required_files']),
          'bundle_file_count': len(files), 'bundle_inventory': inventory, 'pe_imports': imports,
          'notices': [{'entry': rel, 'source': ref(src), 'packaged': ref(bundle / rel)} for rel, src in notices.items()],
          'flutter_native_prior_binding': ref(old_binding_path),
          'signing_status': manifest['signing']['status'],
          'installer_extraction': {'status': 'NOT_RUN_KNOWN_TOOL_LIMIT', 'tool': 'available innoextract 1.9 does not support this installer generation; no new extraction claim', 'prior_tool_failure': ref(Path('E:/r12-windows-observations-package-20260911/installer-extract.log'))},
          'limits': ['Installer container and staged payload were inspected; internal payload extraction was not established.',
                     'PE import inventory and forbidden-extension checks are static and do not prove runtime privacy.',
                     'No install, SCM/TUN action, device acceptance, trusted Authenticode or public promotion was performed.']}
(out / 'windows-package-audit.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(f'PASS staged content: {len(files)} files, {len(manifest["required_files"])} required hashes, {len(imports)} PE inventories; installer extraction NOT_RUN_KNOWN_TOOL_LIMIT')
