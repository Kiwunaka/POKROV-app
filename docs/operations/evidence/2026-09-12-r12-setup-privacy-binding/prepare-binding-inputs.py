from pathlib import Path
import hashlib,json,subprocess
out=Path(__file__).parent;prior=Path('C:/r12-c05-wintun-20260912');core=Path('C:/r12corec02');client=Path('E:/r12client')
old='880bff65ad665844828fe50fc395e9cfc1cd81b4';new='6b271decead88b708e2fc03984b703b0a4e63ebd'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def stream(p):
 text=p.read_text(encoding='utf8');decoder=json.JSONDecoder();i=0
 while i<len(text):
  while i<len(text) and text[i].isspace():i+=1
  if i==len(text):break
  row,i=decoder.raw_decode(text,i);yield row
changes=subprocess.check_output(['git','-C',str(core),'diff','--name-only',old,new],text=True).splitlines()
assert sorted(changes)==['docs/architecture.md','v2/hcore/grpc_server.go','v2/hcore/privacy_test.go']
assert subprocess.check_output(['git','-C',str(core),'diff',old,new,'--','go.mod','go.sum','engine/sing-box/go.mod','engine/sing-box/go.sum'])==b''
diff=subprocess.check_output(['git','-C',str(core),'diff',old,new,'--','v2/hcore/grpc_server.go'])
(out/'setup-source-delta.patch').write_bytes(diff)
composition=json.loads((out/'final-native/audit/artifact-composition.json').read_bytes())
assert composition['status']=='PASS_EXACT_ARTIFACT_COMPOSITION' and all(r['same_dependency_versions_and_replacements'] for r in composition['binaries'])
matrix=json.loads(Path('E:/r12-c05-triage/package-advisory-matrix.json').read_bytes())
assert all(not p.startswith('github.com/Kiwunaka/POKROV-core') for x in matrix for p in x['affected_packages'])
previous_osv={r['osv']['id']:r['osv'] for r in stream(prior/'binary-scans/pokrov-core.govulncheck.jsonl') if 'osv' in r}
now_osv={r['osv']['id']:r['osv'] for r in stream(out/'binary-scans/pokrov-core.govulncheck.jsonl') if 'osv' in r}
for item in matrix:
 for key in ['id','summary','details','affected','withdrawn']:assert previous_osv[item['id']].get(key)==now_osv[item['id']].get(key)
result={'status':'PASS_BOUNDED_ADVISORY_DELTA_REVIEW','previous_source':old,'source':new,'previous_triage':{'path':str(prior/'static-triage-binding.json'),'sha256':sha(prior/'static-triage-binding.json')},'same_nine_advisory_claims':True,'source_changes':changes,'source_diff_sha256':hashlib.sha256(diff).hexdigest(),'source_review':'Only two setup log calls and a log-only local boolean change; setup inputs and socket/TLS/service calls retain their behavior. No affected module or registration changed.','go_manifests_and_sums_unchanged':True,'artifact_composition_sha256':sha(out/'final-native/audit/artifact-composition.json'),'scan_collection_sha256':sha(out/'scan-collection.json'),'limits':['Only prior bounded static dispositions carry forward; no whole-application or native-code clearance.','Five binary scans extract zero symbols; trace findings do not establish reachability.','Corrected source SBOMs provide local module identity; raw binary path/(devel) labels are not upstream versions.']}
(out/'static-triage-binding.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
manifest=json.loads((client/'config/runtime-artifacts.seed.json').read_bytes())['core'];assert manifest['source_commit']==old
notice=client/manifest['native_go_notices']['file'];assert sha(notice)==manifest['native_go_notices']['sha256']
body=notice.read_bytes();assert old.encode() in body;body=body.replace(old.encode(),new.encode())
prepared=json.loads((prior/'notices-preparation.json').read_bytes())
for row in prepared['verbatim_files']:assert hashlib.sha256(body[row['body_offset']:row['body_offset']+row['bytes']]).hexdigest()==row['sha256']
name='native-go-NOTICES.6b271de.prepared.txt';(out/name).write_bytes(body)
prepared.update(previous_source=old,source_commit=new,previous_notice_sha256=sha(notice),prepared_notice={'file':name,'bytes':len(body),'sha256':hashlib.sha256(body).hexdigest()})
(out/'notices-preparation.json').write_text(json.dumps(prepared,indent=2)+'\n',encoding='utf8')
print(json.dumps({'triage':result['status'],'unchanged_notice_bodies':len(prepared['verbatim_files']),'notice_sha256':prepared['prepared_notice']['sha256']}))
