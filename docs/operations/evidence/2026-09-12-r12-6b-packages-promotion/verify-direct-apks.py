from pathlib import Path
import datetime, hashlib, json, re, subprocess, zipfile

out = Path(__file__).parent
root = Path('E:/r12client')
android = root / 'apps/android_shell'
source = '2aa57015783ceb3415e3be62bbf0a698729011c4'
assert subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip() == source
subprocess.run(['git', '-C', str(root), 'diff', '--quiet', 'HEAD', '--'], check=True)
seed = json.loads((root / 'config/runtime-artifacts.seed.json').read_bytes())['core']
assert seed['source_commit'] == '6b271decead88b708e2fc03984b703b0a4e63ebd'
metadata = json.loads(Path('C:/Users/kiwun/AppData/Local/POKROV/android-signing/pokrov-production.metadata.json').read_text(encoding='utf-8-sig'))
expected_cert = metadata['certificate_sha256'].replace(':', '').lower()
tools = Path('C:/Users/kiwun/AppData/Local/Android/Sdk/build-tools/36.1.0')
def sha(p):
    with p.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()
with zipfile.ZipFile('C:/r12corec02/dist/android/pokrov-core.aar') as archive:
    native = {abi: hashlib.sha256(archive.read('jni/' + abi + '/libpokrov-core.so')).hexdigest() for abi in ['armeabi-v7a', 'arm64-v8a', 'x86_64']}
notices = (root / seed['native_go_notices']['file']).read_bytes()
artifacts = []
mapping = [('universal', 'app-direct-release.apk', 'app-direct-universal-release.apk'), ('arm64-v8a', 'app-arm64-v8a-direct-release.apk', 'app-direct-arm64-v8a-release.apk'), ('armeabi-v7a', 'app-armeabi-v7a-direct-release.apk', 'app-direct-armeabi-v7a-release.apk'), ('x86_64', 'app-x86_64-direct-release.apk', 'app-direct-x86_64-release.apk')]
for label, name, duplicate_name in mapping:
    p = android / 'build/app/outputs/flutter-apk' / name
    duplicate = android / 'build/app/outputs/apk/direct/release' / duplicate_name
    digest = sha(p)
    assert p.stat().st_size == duplicate.stat().st_size and digest == sha(duplicate)
    expected_abis = sorted(native) if label == 'universal' else [label]
    verified = subprocess.run([str(tools / 'apksigner.bat'), 'verify', '--verbose', '--print-certs', str(p)], capture_output=True, check=True)
    verification = (verified.stdout + verified.stderr).decode('utf8', errors='replace')
    match = re.search(r'certificate SHA-256 digest:\s*([0-9a-fA-F]{64})', verification)
    assert match and match.group(1).lower() == expected_cert and 'Android Debug' not in verification
    badging = subprocess.run([str(tools / 'aapt.exe'), 'dump', 'badging', str(p)], capture_output=True, check=True)
    text = badging.stdout.decode('utf8', errors='replace')
    package = re.search(r"(?m)^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", text)
    assert package and package.groups() == ('space.pokrov.pokrov_android_shell', '4053', '1.2.0')
    assert not re.search(r'(?m)^application-debuggable', text)
    with zipfile.ZipFile(p) as archive:
        names = archive.namelist()
        assert len(set(names)) == len(names)
        abis = sorted({name.split('/')[1] for name in names if name.startswith('lib/') and name.endswith('/libpokrov-core.so')})
        assert abis == expected_abis
        for abi in abis:
            assert hashlib.sha256(archive.read('lib/' + abi + '/libpokrov-core.so')).hexdigest() == native[abi]
            assert source.encode() in archive.read('lib/' + abi + '/libapp.so'), 'Expected compiled diagnostic revision absent'
        assert archive.read('assets/flutter_assets/packages/pokrov_app_shell/assets/licenses/native-go-NOTICES.txt') == notices
        assert not any(re.search(r'(?i)(?:\.(?:p12|pfx|pem|key|jks|keystore|log|pdb)$|(?:^|/)\.env(?:\.|$))', name) for name in names)
    artifacts.append({'abi': label, 'path': str(p), 'size': p.stat().st_size, 'sha256': digest, 'duplicate_path': str(duplicate), 'duplicate_sha256': digest, 'package_name': package.group(1), 'version_code': package.group(2), 'version_name': package.group(3), 'certificate_sha256': expected_cert, 'signature_verified': True, 'debuggable': False, 'native_abis': abis, 'current_core_hashes_verified': True, 'compiled_revision_present': True, 'native_notices_exact': True, 'verification_output_sha256': hashlib.sha256(verified.stdout + verified.stderr).hexdigest(), 'aapt_output_sha256': hashlib.sha256(badging.stdout).hexdigest()})
    print('PASS direct APK ' + label, flush=True)
report = {'status': 'PASS_FOUR_EXACT_DIRECT_APKS', 'source_client': source, 'source_core': seed['source_commit'], 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'artifacts': artifacts, 'aab': 'INCOMPLETE_STORAGE_STOP', 'device_install': 'NOT_PERFORMED_CURRENT_APKS'}
(out / 'direct-apks-verified.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
print(json.dumps({'status': report['status'], 'artifacts': len(artifacts), 'total_apk_bytes': sum(x['size'] for x in artifacts)}))
