from pathlib import Path
import base64, datetime, hashlib, json, subprocess

out = Path(__file__).parent
client = Path('E:/r12client')
current = Path('E:/r12-904-source-20260911')
module = 'github.com/Psiphon-Labs/utls'
rev = '24497d415a8de0d11c20c3a47724fb88897ed725'
licensed_rev = '7a1fc711853d6dd31c10eca10bbd53bf3b082aac'
sha = lambda b: hashlib.sha256(b).hexdigest()
def get(name, endpoint):
    result = subprocess.run(['gh', 'api', endpoint], capture_output=True, check=True)
    data = json.loads(result.stdout)
    (out / name).write_bytes(result.stdout)
    return data
license_blob = get('upstream-license-blob.json', 'repos/Psiphon-Labs/utls/git/blobs/6a66aea5eafe0ca6a688840c47219556c552488e')
license_body = base64.b64decode(license_blob['content'])
assert hashlib.sha1(b'blob ' + str(len(license_body)).encode() + b'\0' + license_body).hexdigest() == license_blob['sha']
(out / 'upstream-LICENSE.txt').write_bytes(license_body)
history = get('license-history.json', f'repos/Psiphon-Labs/utls/commits?sha={licensed_rev}&path=LICENSE&per_page=100')
comparison = get('branch-comparison.json', f'repos/Psiphon-Labs/utls/compare/{rev}...{licensed_rev}')
assert comparison['status'] == 'diverged'
trees = {}
for label, revision in [('pinned', rev), ('licensed', licensed_rev)]:
    tree = get(label + '-tree.json', f'repos/Psiphon-Labs/utls/git/trees/{revision}?recursive=1')
    assert not tree['truncated']
    trees[label] = {x['path']: x for x in tree['tree'] if x['type'] == 'blob'}
assert 'LICENSE' not in trees['pinned']
assert trees['licensed']['LICENSE']['sha'] == license_blob['sha']
decoder = json.JSONDecoder()
def stream(raw):
    index = 0
    while index < len(raw):
        while index < len(raw) and raw[index].isspace(): index += 1
        if index == len(raw): break
        item, index = decoder.raw_decode(raw, index)
        yield item
selected = {}
for p in sorted(current.glob('*.offline.stdout.json')):
    for row in stream(p.read_text(encoding='utf8')):
        if row.get('Module', {}).get('Path') != module: continue
        root = Path(row['Module']['Dir'])
        for file in row.get('GoFiles', []):
            path = Path(row['Dir']) / file
            rel = path.relative_to(root).as_posix()
            raw = path.read_bytes()
            blob = hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()
            assert blob == trees['pinned'][rel]['sha']
            entry = selected.setdefault(rel, {'path': rel, 'git_blob': blob, 'sha256': sha(raw), 'bytes': len(raw), 'origins': [], 'same_blob_in_licensed_branch': trees['licensed'].get(rel, {}).get('sha') == blob})
            entry['origins'].append(p.name)
            if rel == 'u_prng.go':
                header = raw[:raw.index(b'*/') + 2]
                assert b'Released under utls licence:' in header
                assert b'https://github.com/refraction-networking/utls/blob/master/LICENSE' in header
                (out / 'u_prng-header.txt').write_bytes(header)
assert len(list(current.glob('*.offline.stdout.json'))) == 5
assert 'u_prng.go' in selected and len(selected['u_prng.go']['origins']) == 5
asset = (client / 'packages/app_shell/assets/licenses/native-go-NOTICES.txt').read_bytes()
assert (out / 'u_prng-header.txt').read_bytes() not in asset
assert license_body in asset
result = {'status': 'PASS_EXACT_SELECTED_SOURCE_AND_EXPLICIT_FILE_LICENSE', 'observed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'core_revision': '904e440aca98cb6419744c5c04c83223a6d6380e', 'module': module, 'module_revision': rev, 'official_licensed_branch_revision': licensed_rev, 'license_git_blob': license_blob['sha'], 'license_sha256': sha(license_body), 'license_first_commit': history[-1]['sha'], 'branches_are_diverged': True, 'root_license_in_pinned_tree': False, 'current_asset_sha256': sha(asset), 'license_body_already_in_asset': True, 'u_prng_copyright_header_in_asset': False, 'selected_files': list(selected.values()), 'selected_file_count': len(selected), 'same_blob_count_in_licensed_branch': sum(x['same_blob_in_licensed_branch'] for x in selected.values()), 'scope': 'Explicit u_prng.go license link and missing copyright attribution. Newer branch license does not establish clearance for the whole pinned fork.'}
(out / 'source-license-binding.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
print(json.dumps({k: v for k, v in result.items() if k != 'selected_files'}))
