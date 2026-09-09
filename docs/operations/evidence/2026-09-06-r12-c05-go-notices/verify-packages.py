from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path('E:/r12client')
OUT = Path('E:/r12-c05-go-notices')
assembly = json.loads((OUT / 'assembly.json').read_text())
manifest = json.loads((ROOT / 'config/runtime-artifacts.seed.json').read_text())['core']
notice = (ROOT / assembly['notice_asset']['file']).read_bytes()
digest = lambda b: hashlib.sha256(b).hexdigest()
assert digest(notice) == assembly['notice_asset']['sha256'] == manifest['native_go_notices']['sha256']
assert assembly['source_commit'] == manifest['source_commit']

def check_notice(body):
    assert body == notice
    for item in assembly['verbatim_files']:
        start = item['body_offset']
        assert digest(body[start:start + item['bytes']]) == item['sha256']

android = json.loads((OUT / 'android-verification.json').read_text())
assert len(android['packages']) == 4
for package in android['packages']:
    apk = Path(package['file'])
    assert digest(apk.read_bytes()) == package['sha256']
    with zipfile.ZipFile(apk) as archive:
        check_notice(archive.read(package['notice_path']))
        for name, sha in package['core_entries'].items():
            assert digest(archive.read(name)) == sha

bundle = OUT / 'windows-bundle'
check_notice((bundle / 'data/flutter_assets/packages/pokrov_app_shell/assets/licenses/native-go-NOTICES.txt').read_bytes())
for source, target in [
    ('apps/windows_shell/windows/runner/resources/runtime/pokrov-core.dll', 'pokrov-core.dll'),
    ('apps/windows_shell/windows/runner/resources/runtime/libcronet.dll', 'libcronet.dll'),
    ('apps/windows_shell/windows/runner/resources/runtime/libcronet.NOTICES.txt', 'libcronet.NOTICES.txt'),
    ('packages/app_shell/assets/fonts/OFL.txt', 'data/flutter_assets/packages/pokrov_app_shell/assets/fonts/OFL.txt'),
]:
    assert (ROOT / source).read_bytes() == (bundle / target).read_bytes(), target
assert sorted(p.name for p in bundle.rglob('*.exe')) == ['pokrov_service.exe', 'pokrov_windows.exe']
files = {p.relative_to(bundle).as_posix(): {'bytes': p.stat().st_size, 'sha256': digest(p.read_bytes())}
         for p in sorted(bundle.rglob('*')) if p.is_file()}
prior = Path('E:/r12-c05-cronet-graph/client-bundle')
prior_files = {p.relative_to(prior).as_posix(): digest(p.read_bytes()) for p in prior.rglob('*') if p.is_file()}
assert prior_files
changed = [n for n in files if n in prior_files and files[n]['sha256'] != prior_files[n]]
added = sorted(set(files) - set(prior_files))
removed = sorted(set(prior_files) - set(files))
preserved = json.loads((OUT / 'preexisting-generated.json').read_text())
for item in preserved:
    assert digest((ROOT / item['path']).read_bytes()) == item['sha256'], item['path']
receipt = {
    'result': 'PASS', 'bundle': str(bundle), 'file_count': len(files), 'files': files,
    'notice_sha256': digest(notice), 'verbatim_body_count': len(assembly['verbatim_files']),
    'prior_bundle': str(prior), 'prior_file_count': len(prior_files),
    'changed_from_prior_bundle': changed, 'added_from_prior_bundle': added, 'removed_from_prior_bundle': removed,
    'core_cronet_cronet_notice_and_golos': 'byte-identical to bound source inputs',
    'preexisting_generated_files': 'all four byte-identical to pre-build retained copies',
    'scope': 'Local release-mode package; no installer, signing, service, TUN, device, or runtime privacy acceptance',
}
(OUT / 'windows-verification.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({k: receipt[k] for k in ['result', 'file_count', 'verbatim_body_count', 'changed_from_prior_bundle', 'added_from_prior_bundle', 'removed_from_prior_bundle']}))
