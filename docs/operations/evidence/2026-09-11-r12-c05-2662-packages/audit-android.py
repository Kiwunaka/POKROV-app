from pathlib import Path
import datetime, hashlib, json, re, zipfile

root = Path('E:/r12client')
out = Path('C:/r12-c05-packages-20260911')
sha = lambda b: hashlib.sha256(b).hexdigest()
def ref(p):
    return {'path': str(p), 'size': p.stat().st_size, 'sha256': sha(p.read_bytes())}
apk_root = root / 'apps/android_shell/build/app/outputs/flutter-apk'
files = sorted(apk_root.glob('*.apk')) + [root / 'apps/android_shell/build/app/outputs/bundle/storeRelease/app-store-release.aab']
assert len(files) == 5
notices = {
    'packages/pokrov_app_shell/assets/fonts/OFL.txt': root / 'packages/app_shell/assets/fonts/OFL.txt',
    'packages/pokrov_app_shell/assets/licenses/native-go-NOTICES.txt': root / 'packages/app_shell/assets/licenses/native-go-NOTICES.txt',
    'assets/licenses/maven-NOTICES.txt': root / 'apps/android_shell/assets/licenses/maven-NOTICES.txt',
    'assets/licenses/cronet-NOTICES.txt': root / 'apps/android_shell/assets/licenses/cronet-NOTICES.txt',
}
old_binding_path = Path('E:/r12-c05-flutter-native/engine-binary-binding.json')
old_binding = json.loads(old_binding_path.read_bytes())
flutter = {r['component'].removeprefix('android Flutter '): r['packaged_sha256'] for r in old_binding['components'] if r['component'].startswith('android Flutter ')}
expected_core = {abi: sha((Path('C:/r12-c05-utls-update-20260911/binary-scans/native') / f'libpokrov-core-{abi}.so').read_bytes()) for abi in flutter}
rows = []
for p in files:
    signing_path = Path(str(p) + '.signing.json')
    signing = json.loads(signing_path.read_bytes())
    digest = sha(p.read_bytes())
    assert signing.get('apk_sha256', signing.get('aab_sha256', '')).lower() == digest
    assert signing['certificate_sha256'].lower() == '0a0602a7df5d96a0b427909d004f3ddf26def86587634bf16694da8d654b2500'
    assert signing['version_name'] == '1.2.0' and str(signing['version_code']) == '4053'
    prefix = 'base/' if p.suffix == '.aab' else ''
    with zipfile.ZipFile(p) as z:
        names = z.namelist()
        libs = [n for n in names if n.startswith(prefix + 'lib/') and n.endswith('.so')]
        expected_abis = set(flutter) if p.suffix == '.aab' or signing['abi'] == 'universal' else {signing['abi']}
        assert {n.split('/')[-2] for n in libs} == expected_abis
        binaries = []
        for n in libs:
            b = z.read(n); abi = n.split('/')[-2]; digest_lib = sha(b)
            if n.endswith('/libpokrov-core.so'): assert digest_lib == expected_core[abi]
            elif n.endswith('/libflutter.so'): assert digest_lib == flutter[abi]
            else: assert n.endswith('/libapp.so'), f'Unclassified library: {n}'
            binaries.append({'entry': n, 'size': len(b), 'sha256': digest_lib})
        for abi in expected_abis:
            assert {n.rsplit('/', 1)[1] for n in libs if n.split('/')[-2] == abi} == {'libapp.so', 'libflutter.so', 'libpokrov-core.so'}
        notice_refs = []
        for rel, source in notices.items():
            entry = prefix + 'assets/flutter_assets/' + rel
            data = z.read(entry)
            assert data == source.read_bytes(), entry
            notice_refs.append({'entry': entry, 'sha256': sha(data), 'size': len(data), 'source': str(source)})
        notice = z.read(prefix + 'assets/flutter_assets/NOTICES.Z')
        assert notice
        suspicious = [n for n in names if re.search(r'(?i)(?:\.(?:p12|pfx|pem|key|jks|keystore|log|pdb|exe|dll|aar)$|(?:^|/)\.env(?:\.|$))', n)]
        assert not suspicious, 'Unexpected private/build file extensions in Android package'
        rows.append({'artifact': ref(p), 'signing_receipt': ref(signing_path), 'abis': sorted(expected_abis),
                     'libraries': binaries, 'source_notices': notice_refs,
                     'flutter_notices': {'size': len(notice), 'sha256': sha(notice)},
                     'unexpected_private_or_build_file_names': suspicious})
dex = '\n'.join((out / ('android-dex-packages-' + label + '.log')).read_text(encoding='utf-8-sig') for label in ('direct','store'))
assert json.loads((out/'android-dex-parsing.json').read_bytes())['status']=='PASS_TWO_EXACT_DEX_INPUTS_PARSED'
patterns = ['com.google.android.gms.ads', 'com.google.firebase.analytics', 'com.facebook.ads',
            'com.appsflyer', 'com.adjust.sdk', 'io.appmetrica', 'com.yandex.metrica']
matches = [p for p in patterns if p in dex]
assert not matches
result = {'schema': 'pokrov.r12.final-android-package-audit/v1',
          'observed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'artifacts': rows,
          'flutter_native_prior_binding': ref(old_binding_path),
          'dex_namespace_check': {'patterns': patterns, 'matches': matches, 'logs': [ref(out / ('android-dex-packages-' + label + '.log')) for label in ('direct','store')], 'identity_and_parsing': ref(out/'android-dex-parsing.json')},
          'limits': ['File-name and seven DEX namespace checks are bounded static privacy evidence, not a full secret scan or installed runtime audit.',
                     'Flutter binary equivalence reuses retained official-download evidence after exact hash comparison; native source reproduction was not performed.',
                     'Packages use the development version 1.2.0+4053; no successor release manifest, public distribution or store submission was created.']}
(out / 'android-package-audit.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print('PASS: 5 Android packages, exact Core/Flutter native identity, four notice sources, bounded static privacy checks')
