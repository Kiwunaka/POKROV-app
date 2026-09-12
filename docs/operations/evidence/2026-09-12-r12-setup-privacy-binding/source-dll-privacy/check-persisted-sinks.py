from pathlib import Path
import datetime,hashlib,json
out=Path(__file__).parent;fixture=out/'fixture'
markers={'credentials':'V01_CANARY_CREDENTIAL_7bd2','config':'V01_CANARY_CONFIG_b861','url':'https://v01.invalid/private','ip':'203.0.113.71','path':'V01_CANARY_SETUP_PATH','pii':'v01@example.invalid'}
receipt=json.loads((out/'receipt.json').read_text(encoding='utf-8-sig'));assert receipt['status']=='PASS_BOUNDED_SOURCE_DLL_FFI'
network=json.loads((out/'host-network-ffi-after.json').read_text(encoding='utf-8-sig'))
assert network['routes_match_before'] and network['dns_match_before']
source=(fixture/'input.json').read_bytes()
assert all(v.encode() in source or v.replace('\\','\\\\').encode() in source for v in markers.values())
rows=[]
for p in sorted(fixture.rglob('*')):
 if not p.is_file() or p==fixture/'input.json':continue
 assert not p.is_symlink()
 raw=p.read_bytes()
 found={k:any(candidate in raw for candidate in [v.encode(),v.replace('\\','\\\\').encode(),v.encode('utf-16le')]) for k,v in markers.items()}
 rows.append({'path':p.relative_to(fixture).as_posix(),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'contains':found})
assert rows and not any(any(r['contains'].values()) for r in rows)
result={'status':'PASS_BOUNDED_PERSISTED_SINKS','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'core_source':receipt['core_source'],'dll_sha256':receipt['child']['dll_sha256'],'files':rows,'excluded_input_fixture':{'path':'input.json','bytes':len(source),'sha256':hashlib.sha256(source).hexdigest(),'all_six_markers_present':True},'host_routes_dns_unchanged':True,'limits':'Only files created in this isolated invalid-config flow and separately captured FFI/stdout/stderr; no installed service, live connection or crash dump proof.'}
(out/'persisted-sinks.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'status':result['status'],'files':len(rows),'marker_hits':0,'routes_dns_unchanged':True}))
