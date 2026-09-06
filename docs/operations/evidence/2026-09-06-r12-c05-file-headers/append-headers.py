from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path('E:/r12client'); OUT=Path('E:/r12-c05-header-review')
prior=json.loads(Path('E:/r12-c05-utls-review/assembly.json').read_text())
candidates=json.loads((OUT/'header-candidates.json').read_text())
groups=json.loads((OUT/'body-review.json').read_text())['groups']
by_hash={b['sha256_normalized']:b for b in candidates['blocks']}
modules=json.loads(Path('E:/r12-c05-package-artifacts/linked-module-notices.json').read_text())['modules']
roots=[(Path('C:/Users/kiwun/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.26.8.windows-amd64').resolve(),'go1.26.8')]
for m in modules:
    identity=m['identity']['replacement'] or m['identity']
    roots.append((Path(m['source_dir']).resolve(),identity['module']+'@'+str(identity.get('version') or prior['source_commit'])))
roots.sort(key=lambda item:len(str(item[0])),reverse=True)
def ref(path):
    p=Path(path).resolve()
    for boundary,name in roots:
        if p.is_relative_to(boundary): return name+'/'+p.relative_to(boundary).as_posix()
    raise AssertionError(path)
missing=[g for g in groups if g['disposition']=='missing_body']
selected=[g for g in missing if not any(g is not other and g['body'] in other['body'] for other in missing)]
assert len(selected)==12
asset_path=ROOT/prior['notice_asset']['file']; original=asset_path.read_bytes()
assert hashlib.sha256(original).hexdigest()==prior['notice_asset']['sha256']
assert candidates['notice_sha256']==prior['notice_asset']['sha256']
client_before=subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
assert client_before=='64a26c394a8d85c79f32877f1beb1c6f7ae3939f'
data=bytearray(original)
data.extend(b'\nAdditional notices retained from selected source-file comments\n\n'
            b'These original comment blocks preserve file-specific copyright and license\n'
            b'texts from the recorded Android/Windows Go source graphs. Shared texts may\n'
            b'cover several files; source references are retained below. This supplement\n'
            b'does not establish complete native, source-delivery or license clearance.\n')
added=[]
for group in selected:
    representative=by_hash[group['blocks'][0]]
    source=representative['sources'][0]
    raw=representative['text'].encode('utf-8')
    file_data=Path(source['path']).read_bytes()
    assert raw in file_data,source['path']
    refs=sorted({ref(s['path']) for g in missing if g['body'] in group['body'] for h in g['blocks'] for s in by_hash[h]['sources']})
    data.extend(('\n'+'='*78+'\nSources:\n'+'\n'.join(refs)+'\n'+'='*78+'\n\n').encode())
    offset=len(data);data.extend(raw);data.extend(b'\n')
    added.append({'source_ref':ref(source['path'])+'#L'+str(source['line']), 'covered_source_refs':refs,'body_offset':offset,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'source_file_sha256':hashlib.sha256(file_data).hexdigest()})
files=prior['verbatim_files']+added
assert data[:len(original)]==original
for entry in files: assert hashlib.sha256(data[entry['body_offset']:entry['body_offset']+entry['bytes']]).hexdigest()==entry['sha256']
receipt=dict(prior)
receipt.update({'schema':'pokrov.native-go-notices/v3','client_before':client_before,'previous_notice':prior['notice_asset'],'notice_asset':{'file':prior['notice_asset']['file'],'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()},'verbatim_files':files,'added_notice_count':len(added),'file_header_scope':'Full permission/redistribution comment blocks in the first 160 lines of 6751 hash-verified selected sources; literal body matching and subset grouping only. Not all headers, native includes, SPDX-only references or corresponding source obligations.'})
(OUT/'previous-native-go-NOTICES.txt').write_bytes(original)
asset_path.write_bytes(data)
manifest_path=ROOT/'config/runtime-artifacts.seed.json'
manifest=json.loads(manifest_path.read_text());manifest['core']['native_go_notices']['sha256']=receipt['notice_asset']['sha256']
manifest['core']['native_go_notices']['scope']='Verbatim root, selected source-package and bounded full file-header license/patent notices for recorded Android/Windows Go inputs; complete native, file-header and corresponding-source clearance remains separate'
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
(OUT/'assembly.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'asset':receipt['notice_asset'],'added':len(added),'total':len(files),'all_prior_bytes_retained':True}))
