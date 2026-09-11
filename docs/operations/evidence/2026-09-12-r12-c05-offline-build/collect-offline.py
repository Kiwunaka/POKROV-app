from pathlib import Path
import hashlib, json, subprocess, tarfile, io, zipfile

out = Path(__file__).resolve().parent
remote = '/tmp/pokrov-r12-core-validation-1c8b33f6a771409a/offline-source-2662-20260912'
names = ['build-progress.json', 'resume-progress.json', 'build_tool_gomobile.log', 'resume_build_tool_gobind.log', 'resume_build_tool_gomobile.log', 'build_android.log', 'build_windows.log', 'tool-inputs/receipt.json', 'tool-inputs/download-progress.json', 'bin/go', 'build-offline.py', 'resume-offline.py', 'prepare-tool-inputs.py']
result = subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', 'pokrov-de', 'tar -C ' + remote + ' -cf - ' + ' '.join(names)], capture_output=True, check=True, timeout=60)
dest = out / 'native-evidence'
dest.mkdir(exist_ok=True)
with tarfile.open(fileobj=io.BytesIO(result.stdout)) as archive:
    assert sorted(x.name for x in archive.getmembers()) == sorted(names)
    for item in archive.getmembers():
        assert item.isfile()
        target = dest / item.name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(archive.extractfile(item).read())
receipt = json.loads((dest / 'resume-progress.json').read_text())
assert receipt['status'] == 'PASS_OFFLINE_CORE_AND_TOOL_REBUILD'
assert (dest / 'resume-progress.json').read_bytes() == (out / 'resume-progress-final.json').read_bytes()
for row in receipt['commands']:
    assert row['exit_code'] == 0
    assert hashlib.sha256((dest / row['log']).read_bytes()).hexdigest() == row['log_sha256']
assert hashlib.sha256((dest / 'build-progress.json').read_bytes()).hexdigest() == receipt['previous_failed_receipt_sha256']
inputs = json.loads((dest / 'tool-inputs/receipt.json').read_text())
assert hashlib.sha256((dest / 'tool-inputs/receipt.json').read_bytes()).hexdigest() == receipt['tool_input_supplement']['receipt_sha256']
paths = [x['path'] for x in inputs['files']]
result = subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', 'pokrov-de', 'tar -C ' + remote + '/tool-inputs/cache -cf - ' + ' '.join(paths)], capture_output=True, check=True, timeout=120)
supplement = out / 'gomobile-source-input-supplement.zip'
with tarfile.open(fileobj=io.BytesIO(result.stdout)) as archive, zipfile.ZipFile(supplement, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    assert sorted(x.name for x in archive.getmembers()) == sorted(paths)
    by_path = {x['path']: x for x in inputs['files']}
    for item in archive.getmembers():
        raw = archive.extractfile(item).read()
        row = by_path[item.name]
        assert len(raw) == row['bytes'] and hashlib.sha256(raw).hexdigest() == row['sha256']
        z.writestr('go-module-cache/' + item.name, raw)
    z.writestr('TOOL-SOURCE-MANIFEST.json', (dest / 'tool-inputs/receipt.json').read_bytes())
records = []
for path in sorted(dest.rglob('*')):
    if path.is_file():
        records.append({'path': path.relative_to(out).as_posix(), 'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
report = {'status': 'PASS_RETAINED_OFFLINE_BUILD_EVIDENCE', 'core_source': receipt['core_source'], 'files': records, 'supplement': {'path': supplement.name, 'bytes': supplement.stat().st_size, 'sha256': hashlib.sha256(supplement.read_bytes()).hexdigest(), 'module_count': inputs['module_count'], 'source_files': len(inputs['files'])}, 'outputs_match': len(receipt['outputs'])}
(out / 'collection.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k != 'files'}))
