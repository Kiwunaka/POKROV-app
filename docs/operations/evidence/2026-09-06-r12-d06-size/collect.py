"""Read retained C05 APKs only; report D06 sizes, byte deltas and review items."""
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile


ROOT = Path('E:/r12client')
HERE = Path(__file__).resolve().parent
OLD = ROOT / 'docs/operations/evidence/2026-09-06-r12-c05-package-audit/package-audit.json'
NEW = ROOT / 'docs/operations/evidence/2026-09-06-r12-c05-android-cronet/package-notices.json'
AAPT = Path('C:/Users/kiwun/AppData/Local/Android/Sdk/build-tools/34.0.0/aapt.exe')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def category(name):
    p = Path(name)
    if name.startswith('lib/'):
        kind = {'libpokrov-core.so': 'core', 'libflutter.so': 'flutter',
                'libapp.so': 'dart_aot'}.get(p.name, 'other_native')
        return f'native/{name.split("/")[1]}/{kind}'
    if '/licenses/' in name or p.name in ('NOTICES.Z', 'OFL.txt', 'LICENSE.txt'):
        return 'licenses'
    if p.suffix in ('.ttf', '.otf'):
        return 'fonts'
    if name.startswith('assets/flutter_assets/'):
        return 'flutter_assets'
    if p.suffix == '.dex':
        return 'dex'
    if name.startswith('res/') or name in ('resources.arsc', 'AndroidManifest.xml'):
        return 'android_resources'
    return 'other_metadata_and_resources'


def inspect(path, expected_hash, expected_size):
    data = path.read_bytes()
    assert sha(data) == expected_hash and len(data) == expected_size, path.name
    entries = []
    groups = {}
    with zipfile.ZipFile(path) as z:
        assert len(z.namelist()) == len(set(z.namelist())), 'duplicate ZIP names'
        for i in z.infolist():
            body = z.read(i)
            group = category(i.filename)
            row = dict(name=i.filename, category=group, bytes=i.file_size,
                       compressed_bytes=i.compress_size, sha256=sha(body))
            entries.append(row)
            sizes = groups.setdefault(group, dict(bytes=0, compressed_bytes=0, entries=0))
            sizes['bytes'] += i.file_size
            sizes['compressed_bytes'] += i.compress_size
            sizes['entries'] += 1
    payload = sum(i['compressed_bytes'] for i in entries)
    overhead = len(data) - payload
    assert overhead >= 0 and payload + overhead == len(data)
    return dict(file=str(path), sha256=sha(data), bytes=len(data),
                zip_payload_bytes=payload, zip_alignment_signing_overhead_bytes=overhead,
                groups=groups, entries=entries)


old = json.loads(OLD.read_text(encoding='utf-8'))
new = json.loads(NEW.read_text(encoding='utf-8'))
old_by_abis = {tuple(p['native_abis']): p for p in old['android_packages']}
results = []
for p in new['packages']['packages']:
    current = inspect(Path(p['file']), p['sha256'], p['bytes'])
    abis = tuple(sorted({i['name'].split('/')[1] for i in current['entries']
                         if i['name'].startswith('lib/')}))
    before = old_by_abis[abis]
    previous = inspect(Path(before['artifact']), before['sha256'], before['size'])
    old_entries = {i['name']: i for i in previous['entries']}
    new_entries = {i['name']: i for i in current['entries']}
    delta = []
    for name in sorted(old_entries.keys() | new_entries.keys()):
        a, b = old_entries.get(name), new_entries.get(name)
        if a is None or b is None or a['sha256'] != b['sha256']:
            delta.append(dict(name=name, category=(b or a)['category'],
                              before=a, after=b))
    protected = [n for n in old_entries if n.endswith(('.so', '.dex', '.ttf', '.otf'))]
    assert protected and all(old_entries[n]['sha256'] == new_entries[n]['sha256']
                             for n in protected)
    assert all(i['category'] in ('licenses', 'flutter_assets') for i in delta), delta
    groups_delta = {g: current['groups'].get(g, {}).get('compressed_bytes', 0)
                   - previous['groups'].get(g, {}).get('compressed_bytes', 0)
                   for g in sorted(current['groups'].keys() | previous['groups'].keys())}
    overhead_delta = (current['zip_alignment_signing_overhead_bytes']
                      - previous['zip_alignment_signing_overhead_bytes'])
    assert sum(groups_delta.values()) + overhead_delta == current['bytes'] - previous['bytes']
    suspicious = [i for i in current['entries'] if
                  Path(i['name']).suffix.lower() in ('.exe', '.dll', '.pdb', '.dmp', '.log', '.zip', '.aar', '.a')
                  or any(part.lower() in ('evidence', 'audit-artifacts', 'debug', '.git')
                         for part in i['name'].split('/'))
                  or 'DebugProbes' in i['name']]
    image_hashes = {}
    for i in current['entries']:
        if i['name'].endswith('.png'):
            image_hashes.setdefault(i['sha256'], []).append(i)
    duplicate_images = [v for v in image_hashes.values() if len(v) > 1]
    commands = []
    for args in (['dump', 'badging', p['file']],
                 ['dump', 'xmltree', p['file'], 'AndroidManifest.xml']):
        proc = subprocess.run([str(AAPT), *args], capture_output=True, check=True)
        suffix = 'badging' if args[1] == 'badging' else 'manifest'
        log = HERE / (Path(p['file']).stem + '.' + suffix + '.txt')
        log.write_bytes(proc.stdout)
        commands.append(dict(command=[str(AAPT), *args], exit_code=proc.returncode,
                             log=log.name, sha256=sha(proc.stdout)))
        output = proc.stdout.decode('utf-8')
        if suffix == 'badging':
            assert 'application-debuggable' not in output
        else:
            debug_lines = [s.strip() for s in output.splitlines() if ':debuggable' in s]
            assert all('(type 0x12)0x0' in s for s in debug_lines), debug_lines
    results.append(dict(abis=abis, current=current,
                        previous={k: v for k, v in previous.items() if k != 'entries'},
                        changed_entries=delta, compressed_group_deltas=groups_delta,
                        overhead_delta=overhead_delta,
                        protected_native_dex_font_bytes_unchanged=True,
                        filename_review_items=suspicious, duplicate_png_groups=duplicate_images,
                        android_debuggable=False, aapt_commands=commands))

by_abi = {tuple(r['abis']): r for r in results}
arm = by_abi[('arm64-v8a',)]['current']
universal = by_abi[('arm64-v8a', 'armeabi-v7a', 'x86_64')]['current']
universal_entries = {i['name']: i for i in universal['entries']}
for i in arm['entries']:
    if i['name'].startswith('lib/'):
        assert universal_entries[i['name']]['sha256'] == i['sha256']
report = dict(schema='pokrov.r12.d06-size/v1',
              status='LOCAL_BYTE_ANALYSIS_COMPLETE_D01_FINAL_CANDIDATE_OPEN',
              client_commit=subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
              input_receipts=[dict(file=str(p), sha256=sha(p.read_bytes())) for p in (OLD, NEW)],
              collector_sha256=sha(Path(__file__).read_bytes()),
              aapt_sha256=sha(AAPT.read_bytes()), packages=results,
              arm64_vs_universal=dict(saved_bytes=universal['bytes']-arm['bytes'],
                                     saved_percent=100*(1-arm['bytes']/universal['bytes']),
                                     native_arm64_bytes_identical=True),
              limits=['Read-only analysis of internal Debug-signed release-mode APKs with loopback API.',
                      'Filename review is not a full content or privacy scan; DebugProbesKt.bin remains a review item.',
                      'ZIP compressed payload plus separately accounted alignment, headers and signing overhead equals APK size.',
                      'No build, installation, release promotion or removal of runtime/license/source material.'])
(HERE / 'size-breakdown.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(dict(status=report['status'], packages=len(results),
                      arm64_vs_universal=report['arm64_vs_universal'],
                      deltas=[r['current']['bytes']-r['previous']['bytes'] for r in results])))
