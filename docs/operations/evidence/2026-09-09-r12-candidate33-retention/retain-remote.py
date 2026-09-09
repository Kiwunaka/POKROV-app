"""Retain only candidate.33's named public CI evidence; no signing keys."""
import datetime
import hashlib
import json
import pathlib
import subprocess
import zipfile

root = pathlib.Path(__file__).parent
runs = [
    ('Kiwunaka/pokrov', 33851401873),
    ('Kiwunaka/pokrov-core', 33303561763),
    ('Kiwunaka/POKROV-app', 33849479969),
]
allowed_ids = {9928470408, 9729821940, 9729818862, 9729813473, 9729751245}
allowed_names = {'release-index.json', 'release-index.json.sig', 'signing-receipt.json',
                 'core-android-evidence.json', 'core-windows-evidence.json',
                 'core-apple-evidence.json', 'pokrov-core.cdx.json', 'sing-box.cdx.json'}
records = []
for repo, run in runs:
    endpoint = f'repos/{repo}/actions/runs/{run}/artifacts'
    query = subprocess.run(['gh', 'api', endpoint], capture_output=True, text=True, encoding='utf-8')
    assert query.returncode == 0, query.stderr
    payload = json.loads(query.stdout)
    assert payload['total_count'] == len(payload['artifacts']), 'Pagination needed'
    record = {'repository': repo, 'run_id': run, 'endpoint': endpoint,
              'total_count': payload['total_count'], 'artifacts': []}
    for artifact in payload['artifacts']:
        identifier = artifact['id']
        assert identifier in allowed_ids, 'Unreviewed artifact'
        row = {k: artifact[k] for k in ['id', 'name', 'size_in_bytes', 'digest',
                                       'expired', 'created_at', 'expires_at', 'workflow_run']}
        if artifact['expired']:
            row['retention_result'] = 'EXPIRED_NOT_DOWNLOADED'
            record['artifacts'].append(row)
            continue
        assert artifact['size_in_bytes'] < 1000000, 'Unexpected archive size'
        archive_path = root / f'{identifier}.zip'
        assert not archive_path.exists(), 'Preserve existing download'
        with archive_path.open('xb') as output:
            download = subprocess.run(['gh', 'api', f'repos/{repo}/actions/artifacts/{identifier}/zip'],
                                      stdout=output, stderr=subprocess.PIPE)
        assert download.returncode == 0, 'Archive download failed; partial file retained'
        digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
        assert 'sha256:' + digest == artifact['digest'], 'Archive digest mismatch; bytes retained'
        row['local_archive'] = archive_path.name
        row['local_archive_sha256'] = digest
        row['local_archive_bytes'] = archive_path.stat().st_size
        row['files'] = []
        with zipfile.ZipFile(archive_path) as archive:
            for member in archive.infolist():
                assert member.filename in allowed_names, 'Unreviewed archive member'
                assert member.file_size < 1000000, 'Unexpected expanded size'
                data = archive.read(member)
                directory = root / str(identifier)
                directory.mkdir(exist_ok=True)
                destination = directory / member.filename
                with destination.open('xb') as output:
                    output.write(data)
                row['files'].append({'path': str(destination.relative_to(root)).replace('\\', '/'),
                                     'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        row['retention_result'] = 'ARCHIVE_DIGEST_AND_MEMBER_CRC_PASS'
        record['artifacts'].append(row)
        print(f'Retained artifact {identifier}: {len(row["files"])} files')
    records.append(record)
report = {'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'origin': 'current-origin authenticated GitHub REST', 'runs': records}
(root / 'remote-retention.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
