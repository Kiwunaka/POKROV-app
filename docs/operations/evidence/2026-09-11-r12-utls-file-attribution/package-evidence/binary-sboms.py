from pathlib import Path
import hashlib, json, subprocess

out = Path('E:/r12-c05-utls-license-20260911')
tool = Path('E:/POKROV-tools/go-tools/bin/cyclonedx-gomod.exe')
def ref(p):
    return {'path': str(p), 'size': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
scan = json.loads((out / 'core-scan.json').read_bytes())
results = []
for row in scan['binary_scans']:
    binary = Path(row['binary']['path'])
    assert ref(binary) == row['binary']
    sbom = out / (binary.stem + '.binary.cdx.json')
    log = out / (binary.stem + '.binary-sbom.log')
    cmd = [str(tool), 'bin', '-std', '-json', '-notimestamp', '-noserial', '-output', str(sbom), str(binary)]
    with log.open('w', encoding='utf-8') as stream:
        proc = subprocess.run(cmd, stdout=stream, stderr=subprocess.STDOUT)
    assert proc.returncode == 0
    data = json.loads(sbom.read_bytes())
    results.append({'binary': row['binary'], 'command': cmd, 'exit_code': 0, 'sbom': ref(sbom),
                    'log': ref(log), 'components': len(data.get('components', [])),
                    'license_evidence': 'NOT_INFERRED_FROM_GO_BUILDINFO'})
    print(binary.name, len(data.get('components', [])), 'components', flush=True)
(out / 'binary-sboms.json').write_text(json.dumps({'tool': ref(tool), 'results': results,
    'scope': 'Exact Go binary module inventories; complete native/Flutter/Maven components and license obligations remain separate.'}, indent=2) + '\n', encoding='utf-8')
