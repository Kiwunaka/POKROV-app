from pathlib import Path
import datetime, hashlib, io, json, shutil, subprocess, tarfile, time

out = Path(__file__).parent
inventory = json.loads((out / 'core-cache-inventory.json').read_text(encoding='utf8'))
root = Path(inventory['root']).resolve()
assert root == Path('E:/POKROV-workspace-cache/gradle-user-home/caches/8.11.1/transforms').resolve()
groups = [g for g in inventory['groups'] if not g['current_core'] and g['kind'] == 'extracted_core']
assert len(groups) == 10
rows = [f for g in groups for f in g['files']]
remote = '/tmp/pokrov-r12-core-validation-1c8b33f6a771409a/retained-old-native-core-cache-20260912'
assert subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8', 'pokrov-de', 'test ! -e ' + remote]).returncode == 0
def sha(p):
    with p.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()
for row in rows:
    p = root / row['path']
    assert p.resolve().is_relative_to(root) and not p.is_symlink() and not p.is_junction()
    assert p.stat().st_size == row['bytes'] and sha(p) == row['sha256']
manifest = {'status': 'PREPARED', 'root': str(root), 'groups': groups, 'files': rows, 'reason': 'Retain only ten previous extracted POKROV Core transform caches before reclaiming the measured Android build reserve', 'current_core_groups_excluded': 2, 'bytes': sum(r['bytes'] for r in rows), 'remote_host': 'pokrov-de', 'remote_directory': remote, 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
(out / 'old-native-core-cache-retention-plan.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf8')
script = "import pathlib,shutil,sys; p=pathlib.Path('" + remote + "'); assert shutil.disk_usage('/tmp').free>8*2**30; p.mkdir(mode=0o700); f=(p/'cache.tar.gz').open('xb'); shutil.copyfileobj(sys.stdin.buffer,f); f.close()"
command = "python3 -c '" + script.replace("'", "'\"'\"'") + "'"
with (out / 'old-native-core-cache-upload.log').open('wb') as error:
    process = subprocess.Popen(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8', 'pokrov-de', command], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=error)
    started = time.monotonic()
    class Writer:
        def __init__(self):
            self.bytes = 0
            self.digest = hashlib.sha256()
            self.last = 0
        def write(self, raw):
            process.stdin.write(raw)
            self.digest.update(raw)
            self.bytes += len(raw)
            delay = self.bytes / (4 * 2**20) - (time.monotonic() - started)
            if delay > 0:
                time.sleep(min(delay, 1))
            if time.monotonic() - self.last > 10:
                self.last = time.monotonic()
                (out / 'old-native-core-cache-upload-progress.json').write_text(json.dumps({'status': 'UPLOADING', 'bytes': self.bytes, 'elapsed_seconds': round(time.monotonic() - started, 1), 'files': len(rows)}) + '\n', encoding='utf8')
            return len(raw)
        def flush(self):
            process.stdin.flush()
    writer = Writer()
    with tarfile.open(fileobj=writer, mode='w|gz', compresslevel=1) as archive:
        raw = json.dumps(manifest, indent=2).encode()
        info = tarfile.TarInfo('retention-manifest.json')
        info.size = len(raw)
        info.mode = 0o600
        archive.addfile(info, io.BytesIO(raw))
        for row in rows:
            path = root / row['path']
            info = tarfile.TarInfo(row['path'])
            info.size = row['bytes']
            info.mode = 0o600
            with path.open('rb') as f:
                archive.addfile(info, f)
            assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256']
    writer.flush()
    process.stdin.close()
    assert process.wait(timeout=60) == 0
uploaded = {'status': 'UPLOADED_AWAITING_VERIFY', 'remote_host': 'pokrov-de', 'archive': remote + '/cache.tar.gz', 'archive_sha256': writer.digest.hexdigest(), 'archive_bytes': writer.bytes, 'files': len(rows), 'file_bytes': manifest['bytes'], 'files_deleted': 0}
(out / 'old-native-core-cache-upload.json').write_text(json.dumps(uploaded, indent=2) + '\n', encoding='utf8')
verify = '''from pathlib import Path
import hashlib,json,tarfile
p=Path('ARCHIVE_PATH_INPUT_TOKEN')
with p.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
assert digest=='DIGEST'
with tarfile.open(p) as archive:
 manifest=json.load(archive.extractfile('retention-manifest.json'))
 expected={r['path']:r for r in manifest['files']};seen=set()
 for member in archive:
  if member.name=='retention-manifest.json':continue
  assert member.isfile() and member.name in expected
  with archive.extractfile(member) as f:actual=hashlib.file_digest(f,'sha256').hexdigest()
  row=expected[member.name];assert actual==row['sha256'] and member.size==row['bytes'];seen.add(member.name)
 assert seen==set(expected)
print(json.dumps({'status':'PASS_EXACT_RETIRED_NATIVE_CORE_CACHE_ARCHIVE','archive':str(p),'archive_sha256':digest,'archive_bytes':p.stat().st_size,'files':len(seen),'file_bytes':sum(r['bytes'] for r in expected.values()),'local_files_deleted':False}))
'''.replace('ARCHIVE_PATH_INPUT_TOKEN', uploaded['archive']).replace('DIGEST', uploaded['archive_sha256'])
result = subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8', 'pokrov-de', 'python3 -'], input=verify, text=True, capture_output=True, check=True, timeout=180)
receipt = json.loads(result.stdout)
assert receipt['status'] == 'PASS_EXACT_RETIRED_NATIVE_CORE_CACHE_ARCHIVE'
(out / 'old-native-core-cache-retention.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
print(json.dumps(receipt))
