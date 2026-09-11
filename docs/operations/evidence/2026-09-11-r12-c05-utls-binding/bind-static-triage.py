from pathlib import Path
import datetime, hashlib, json, re, zipfile

out = Path(__file__).parent
current = Path('E:/r12-2662-source-20260911')
old = Path('E:/r12-c05-triage')
sha = lambda b: hashlib.sha256(b).hexdigest()
decoder = json.JSONDecoder()
def stream(path):
    raw = path.read_text(encoding='utf-8-sig')
    index = 0
    while index < len(raw):
        while index < len(raw) and raw[index].isspace(): index += 1
        if index == len(raw): break
        row, index = decoder.raw_decode(raw, index)
        yield row
def normalize(path):
    p = str(path).replace('\\', '/')
    for prefix, label in [((current / 'payload/core').as_posix() + '/', 'core/'),
                          ('E:/r12core-implementation/', 'core/'),
                          ((current / 'payload/go-module-cache').as_posix() + '/', 'module-cache/'),
                          ('C:/Users/kiwun/go/pkg/mod/', 'module-cache/')]:
        if p.startswith(prefix): return label + p[len(prefix):]
    raise AssertionError('Unmapped selected source root: ' + p)
graphs, files = {}, {}
for p in sorted(current.glob('*.offline.stdout.json')):
    name = p.name.removesuffix('.offline.stdout.json')
    graphs[name] = list(stream(p))
    for row in graphs[name]:
        for kind in ('GoFiles', 'CgoFiles', 'SFiles', 'CFiles', 'CXXFiles', 'HFiles', 'SysoFiles', 'EmbedFiles'):
            for file in row.get(kind, []):
                path = Path(row['Dir']) / file
                key = normalize(path)
                body = path.read_bytes()
                item = files.setdefault(key, {'path': key, 'sha256': sha(body), 'kinds': set(), 'targets': set(), 'local': path})
                item['kinds'].add(kind)
                item['targets'].add(name)
before = {normalize(x['path']): x for x in json.loads((old / 'source-file-inventory.json').read_bytes())}
removed = sorted(set(before)-set(files))
added = sorted(set(files)-set(before))
assert all(key.startswith(('module-cache/github.com/!psiphon-!labs/utls@','module-cache/github.com/cloudflare/circl@')) for key in removed)
embedded = sorted(key for key in added if files[key]['kinds']=={'EmbedFiles'})
changed = [key for key in set(before)&set(files) if files[key]['sha256'] != before[key]['sha256']]
assert all(key.startswith('core/') for key in changed)
pattern = re.compile(rb'\b(?:RealIP|RedirectSlashes|MultiScalarMult)\b')
matches = []
source_files = 0
for key, item in files.items():
    if not item['kinds'].intersection(('GoFiles', 'CgoFiles')): continue
    source_files += 1
    for line, text in enumerate(item['local'].read_bytes().splitlines(), 1):
        if pattern.search(text):
            matches.append({'path': key, 'line': line, 'text': text.decode().strip(), 'sha256': item['sha256']})
old_matches = json.loads((old / 'selected-source-symbol-matches.json').read_bytes())
expected = [{**{k: row[k] for k in ('line', 'text', 'sha256')}, 'path': normalize(row['path'])} for row in old_matches['matches']]
assert sorted(matches, key=lambda x:(x['path'], x['line'])) == sorted(expected, key=lambda x:(x['path'], x['line']))
# Package delta is retained by the separate five-target exact graph comparison.
for row in json.loads((old / 'edwards-importers.json').read_bytes()):
    assert files[normalize(row['path'])]['sha256'] == row['sha256']
for file in ('engine/sing-box/experimental/clashapi/server.go', 'engine/sing-box/experimental/clashapi/api_meta.go'):
    key = 'core/' + file
    assert files[key]['sha256'] == before[key]['sha256']
matrix = json.loads((old / 'package-advisory-matrix.json').read_bytes())
for item in matrix:
    for name, rows in graphs.items():
        matches_for_target = sorted({row['ImportPath'] for row in rows} & set(item['affected_packages']))
        assert matches_for_target == sorted(item['matches_by_target'][name])
osvs = {}
scan=json.loads((out/'binary-scans/pokrov-core.scan.json').read_bytes())
for binary in [scan]:
    for row in stream(Path(binary['report']['path'])):
        if 'osv' in row: osvs[row['osv']['id']] = row['osv']
claims = []
for item in matrix:
    previous = json.loads((old / 'current-advisories' / (item['id'] + '.json')).read_bytes())
    now = osvs[item['id']]
    fields = ('id', 'summary', 'details', 'affected', 'withdrawn')
    assert all(now.get(k) == previous.get(k) for k in fields), item['id']
    claims.append({'id': item['id'], 'affected_packages_and_claim_unchanged': True, 'modified': now.get('modified')})
assert set(scan['advisories']) == {x['id'] for x in matrix}
auth = Path('E:/r12-c05-module-auth/file-comparison.json')
authenticated = {(x['module'], x['version'], x['path']): x['fresh_sha256'] for x in json.loads(auth.read_bytes())}
new_module=json.loads((out/'module-download.json').read_bytes())
new_archive=zipfile.ZipFile(new_module['Zip'])
authenticated_selected = set(); newly_authenticated=set()
for rows in graphs.values():
    for row in rows:
        mod = row.get('Module', {})
        mod = mod.get('Replace') or mod
        if not mod.get('Version'): continue
        for kind in ('GoFiles', 'CgoFiles', 'SFiles', 'CFiles', 'CXXFiles', 'HFiles', 'SysoFiles', 'EmbedFiles'):
            for file in row.get(kind, []):
                path = Path(row['Dir']) / file
                rel = path.relative_to(Path(mod['Dir'])).as_posix()
                key = (mod['Path'], mod['Version'], rel)
                if mod['Path']==new_module['Path']:
                    assert mod['Version']==new_module['Version'] and mod['Sum']==new_module['Sum']
                    assert path.read_bytes()==new_archive.read(mod['Path']+'@'+mod['Version']+'/'+rel),key
                    newly_authenticated.add(key)
                else:
                    assert sha(path.read_bytes()) == authenticated[key], key
                    authenticated_selected.add(key)
result = {'status': 'PASS_BOUNDED_STATIC_TRIAGE_BINDING', 'observed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'client_binding': 'PENDING_NEW_ANDROID_ARTIFACTS', 'core_revision': scan['source_commit'], 'binary_scan_count': 1, 'new_authenticated_utls_selected_files':len(newly_authenticated), 'added_selected_paths':added, 'removed_selected_paths':removed, 'selected_source_files': len(files), 'previous_inventory_files': len(before), 'additional_embedded_inputs': embedded, 'selected_go_cgo_files': source_files, 'changed_core_files_since_triage': changed, 'external_selected_files_match_prior_authenticated_bytes': len(authenticated_selected), 'prior_auth_inventory_sha256': sha(auth.read_bytes()), 'symbol_matches': matches, 'clash_registration_and_point_consumer_unchanged': True, 'five_target_affected_package_matrix_unchanged': True, 'advisory_claims': claims, 'source_inventory_sha256': sha((old / 'source-file-inventory.json').read_bytes()), 'limits': ['Existing nine Go static dispositions remain applicable under the verified unchanged affected packages, registrations and selected external bytes.', 'No new runtime exploit test, native vulnerability assessment or whole-application clearance is established.']}
(out / 'source-triage-current-windows.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
print(json.dumps({k:v for k,v in result.items() if k not in ('symbol_matches', 'advisory_claims')}))
