from pathlib import Path
import datetime, hashlib, json, subprocess, zipfile

root = Path('E:/r12utls')
out = Path('E:/r12-c05-utls-license-20260911')
native = out / 'native'
native.mkdir(exist_ok=True)
scanner = Path('E:/r12-c05-artifacts/tools/govulncheck.exe')
go = Path('C:/Users/kiwun/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.26.8.windows-amd64/bin/go.exe')
seed = json.loads((root / 'config/runtime-artifacts.seed.json').read_bytes())['core']
sha = lambda data: hashlib.sha256(data).hexdigest()
def ref(p):
    return {'path': str(p), 'size': p.stat().st_size, 'sha256': sha(p.read_bytes())}
def stream(p):
    text = p.read_text(encoding='utf-8-sig'); decoder = json.JSONDecoder(); rows = []
    while text.strip():
        row, end = decoder.raw_decode(text.lstrip()); rows.append(row); text = text.lstrip()[end:]
    return rows

aar = Path('C:/r12corec02/dist/android/pokrov-core.aar')
assert sha(aar.read_bytes()) == seed['assets']['android']['sha256']
inputs = []
with zipfile.ZipFile(aar) as archive:
    for abi in ['armeabi-v7a', 'arm64-v8a', 'x86_64']:
        dest = native / f'libpokrov-core-{abi}.so'
        dest.write_bytes(archive.read(f'jni/{abi}/libpokrov-core.so'))
        inputs.append(dest)
dll = root / 'apps/windows_shell/windows/runner/resources/runtime/pokrov-core.dll'
assert sha(dll.read_bytes()) == seed['assets']['windows']['sha256']
inputs.append(dll)
results = []
for binary in inputs:
    report = out / (binary.stem + '.govulncheck.jsonl')
    errors = out / (binary.stem + '.govulncheck.stderr.log')
    buildinfo = out / (binary.stem + '.buildinfo.log')
    cmd = [str(scanner), '-mode', 'binary', '-json', str(binary)]
    with report.open('w', encoding='utf-8') as stdout, errors.open('w', encoding='utf-8') as stderr:
        run = subprocess.run(cmd, stdout=stdout, stderr=stderr)
    assert run.returncode == 0, f'scanner failed for {binary.name}'
    with buildinfo.open('w', encoding='utf-8') as stdout:
        info = subprocess.run([str(go), 'version', '-m', str(binary)], stdout=stdout, stderr=subprocess.STDOUT)
    assert info.returncode == 0
    rows = stream(report)
    findings = [r['finding'] for r in rows if 'finding' in r]
    ids = sorted({r['osv'] for r in findings})
    results.append({'binary': ref(binary), 'command': cmd, 'exit_code': run.returncode,
                    'report': ref(report), 'stderr': ref(errors), 'buildinfo': ref(buildinfo),
                    'advisories': ids,
                    'symbol_findings': sum(bool(r.get('trace', [{}])[0].get('function')) for r in findings)})
    print(binary.name, 'advisory IDs:', len(ids), flush=True)
sboms = []
for expected in seed['artifact_provenance']['artifact_evidence']['sbom']:
    p = Path('E:/r12client/docs/operations/evidence/2026-09-10-r12-core-privacy-binding') / expected['name']
    assert sha(p.read_bytes()) == expected['sha256']
    sboms.append(ref(p))
result = {'schema': 'pokrov.r12.final-core-scan/v1',
          'observed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'client_revision': subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip(),
          'core_revision': seed['source_commit'], 'scanner': ref(scanner), 'go': ref(go),
          'source_sboms': sboms, 'binary_scans': results,
          'limits': ['Go module and symbol scan only; native Cronet/Flutter libraries require separate assessment.',
                     'No installed-runtime privacy, device, trusted Windows signing or publication claim.',
                     'Module-only findings are not proof of reachable vulnerable code or a clean bill of health.']}
(out / 'core-scan.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
