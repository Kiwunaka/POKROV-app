from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import zipfile
import re

ROOT = Path('E:/r12client')
OUT = Path('E:/r12-c05-header-review')
OLD = Path('E:/r12-c05-utls-review')
assembly = json.loads((OUT / 'assembly.json').read_text())
notice = (ROOT / assembly['notice_asset']['file']).read_bytes()
sha = lambda data: hashlib.sha256(data).hexdigest()
assert sha(notice) == assembly['notice_asset']['sha256']

def verify_notice(body):
    assert body == notice
    for item in assembly['verbatim_files']:
        assert sha(body[item['body_offset']:item['body_offset'] + item['bytes']]) == item['sha256']

destination = OUT / 'android'
destination.mkdir(exist_ok=True)
with zipfile.ZipFile(ROOT / assembly['artifact_binding']['android']['file']) as aar:
    core_entries = {name.replace('jni/', 'lib/', 1): sha(aar.read(name)) for name in aar.namelist() if name.startswith('jni/') and name.endswith('/libpokrov-core.so')}
apks = sorted((ROOT / 'apps/android_shell/build/app/outputs/apk/direct/release').glob('*.apk'))
assert len(apks) == 4
android = []
for apk in apks:
    path = destination / apk.name
    if path.exists():
        assert path.read_bytes() == apk.read_bytes()
    else:
        shutil.copy2(apk, path)
    with zipfile.ZipFile(path) as package:
        entry = 'assets/flutter_assets/packages/pokrov_app_shell/assets/licenses/native-go-NOTICES.txt'
        verify_notice(package.read(entry))
        assert package.read('assets/flutter_assets/packages/pokrov_app_shell/assets/fonts/OFL.txt') == (ROOT / 'packages/app_shell/assets/fonts/OFL.txt').read_bytes()
        libs = {n: sha(package.read(n)) for n in package.namelist() if n.endswith('/libpokrov-core.so')}
        assert libs and all(core_entries[n] == value for n, value in libs.items())
    command = ['C:/Users/kiwun/AppData/Local/Android/Sdk/build-tools/34.0.0/apksigner.bat', 'verify', '--print-certs', str(path)]
    run = subprocess.run(command, capture_output=True, text=True)
    assert run.returncode == 0 and 'CN=Android Debug' in run.stdout
    certificate = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)', run.stdout).group(1)
    android.append({'path': str(path), 'bytes': path.stat().st_size, 'sha256': sha(path.read_bytes()), 'notice_sha256': sha(notice), 'core_entries': libs, 'signing': {'command': command, 'exit_code': 0, 'signer': 'Android Debug', 'certificate_sha256': certificate}})

bundle = OUT / 'windows-bundle'
verify_notice((bundle / 'data/flutter_assets/packages/pokrov_app_shell/assets/licenses/native-go-NOTICES.txt').read_bytes())
for name in ['pokrov-core.dll', 'libcronet.dll', 'libcronet.NOTICES.txt']:
    assert (bundle / name).read_bytes() == (ROOT / 'apps/windows_shell/windows/runner/resources/runtime' / name).read_bytes()
assert (bundle / 'data/flutter_assets/packages/pokrov_app_shell/assets/fonts/OFL.txt').read_bytes() == (ROOT / 'packages/app_shell/assets/fonts/OFL.txt').read_bytes()
assert sorted(p.name for p in bundle.rglob('*.exe')) == ['pokrov_service.exe', 'pokrov_windows.exe']
files = {p.relative_to(bundle).as_posix(): {'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())} for p in sorted(bundle.rglob('*')) if p.is_file()}
previous = OLD / 'windows-bundle'
old_files = {p.relative_to(previous).as_posix(): sha(p.read_bytes()) for p in previous.rglob('*') if p.is_file()}
changed = [n for n in files if n in old_files and files[n]['sha256'] != old_files[n]]
assert set(files) == set(old_files)
assert changed == ['data/flutter_assets/packages/pokrov_app_shell/assets/licenses/native-go-NOTICES.txt'], changed
for item in json.loads((Path('E:/r12-c05-go-notices') / 'preexisting-generated.json').read_text()):
    assert sha((ROOT / item['path']).read_bytes()) == item['sha256']
result = {'status': 'LOCAL_PACKAGE_VERIFICATION_PASS', 'notice': assembly['notice_asset'], 'verbatim_file_count': len(assembly['verbatim_files']), 'android': android, 'windows': {'path': str(bundle), 'file_count': len(files), 'files': files, 'previous_bundle': str(previous), 'changed': changed, 'unchanged_files': len(files) - len(changed)}, 'preexisting_registrants': 'all four byte-identical', 'scope': 'Internal debug-signed Android and unsigned Windows lab packages; no candidate, installer, service, TUN or installed privacy proof'}
(OUT / 'package-verification.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'result': result['status'], 'android_packages': len(android), 'windows_files': len(files), 'unchanged_windows_files': len(files) - len(changed), 'verbatim_files': len(assembly['verbatim_files'])}))
