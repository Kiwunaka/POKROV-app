"""Verify the packaging-only D06 change against retained pre-change APKs."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

here = Path(__file__).resolve().parent
root = Path('E:/r12client')
destination = Path('E:/r12-d06-size/apks')
destination.mkdir(parents=True, exist_ok=True)
before = json.loads((here / 'size-breakdown.json').read_text(encoding='utf-8'))
sha = lambda b: hashlib.sha256(b).hexdigest()
results = []
for item in before['packages']:
    previous = item['current']
    source = root / 'apps/android_shell/build/app/outputs/apk/direct/release' / Path(previous['file']).name
    dest = destination / source.name
    assert not dest.exists(), 'Preserve any previous output before a new run'
    shutil.copy2(source, dest)
    with zipfile.ZipFile(previous['file']) as old, zipfile.ZipFile(dest) as new:
        assert sha(Path(previous['file']).read_bytes()) == previous['sha256']
        assert len(new.namelist()) == len(set(new.namelist()))
        removed = sorted(set(old.namelist()) - set(new.namelist()))
        assert removed == ['DebugProbesKt.bin'], removed
        assert not (set(new.namelist()) - set(old.namelist()))
        changed = [n for n in new.namelist() if new.read(n) != old.read(n)]
        assert not changed, changed
        compression_changed = [n for n in new.namelist()
                               if new.getinfo(n).compress_size != old.getinfo(n).compress_size]
        assert not compression_changed, compression_changed
        entries = [e for e in previous['entries'] if e['name'] != 'DebugProbesKt.bin']
        removed_info = old.getinfo('DebugProbesKt.bin')
        payload = sum(i.compress_size for i in new.infolist())
    env = dict(os.environ)
    env['JAVA_HOME'] = 'C:/Users/kiwun/tools/jdk/17.0.18'
    signer = subprocess.run(['C:/Users/kiwun/AppData/Local/Android/Sdk/build-tools/34.0.0/apksigner.bat',
                             'verify', '--print-certs', str(dest)], env=env,
                            capture_output=True, check=True)
    assert b'CN=Android Debug' in signer.stdout
    signer_log = here / (dest.stem + '.signer.txt')
    signer_log.write_bytes(signer.stdout)
    groups = {}
    for e in entries:
        group = groups.setdefault(e['category'], dict(bytes=0, compressed_bytes=0, entries=0))
        group['bytes'] += e['bytes']
        group['compressed_bytes'] += e['compressed_bytes']
        group['entries'] += 1
    size = dest.stat().st_size
    results.append(dict(file=str(dest), sha256=sha(dest.read_bytes()), bytes=size,
                        before_sha256=previous['sha256'], saved_bytes=previous['bytes']-size,
                        removed=removed, removed_bytes=removed_info.file_size,
                        removed_compressed_bytes=removed_info.compress_size,
                        unchanged_entries=len(entries), groups=groups,
                        zip_payload_bytes=payload,
                        zip_alignment_signing_overhead_bytes=size-payload,
                        signer='Android Debug', signer_log=signer_log.name,
                        signer_log_sha256=sha(signer.stdout),
                        manifest_dex_native_assets_fonts_notices_unchanged=True))
report = dict(status='PASS_LOCAL_D06_DEBUG_RESOURCE_EXCLUSION_FINAL_ACCEPTANCE_OPEN',
              packages=results, command='python -B docs/operations/evidence/2026-09-06-r12-d06-size/verify-after.py',
              baseline_report_sha256=sha((here / 'size-breakdown.json').read_bytes()),
              verifier_sha256=sha(Path(__file__).read_bytes()),
              gradle_sha256=sha((root / 'apps/android_shell/android/app/build.gradle').read_bytes()),
              no_production_signing_candidate_installation=True)
(here / 'after-packaging.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(dict(status=report['status'], saved_bytes=[i['saved_bytes'] for i in results],
                      unchanged_entries=[i['unchanged_entries'] for i in results])))
