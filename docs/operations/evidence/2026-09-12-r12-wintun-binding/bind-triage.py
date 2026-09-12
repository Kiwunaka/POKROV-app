from pathlib import Path
import hashlib, json, subprocess

out=Path(__file__).parent;core=Path('C:/r12corec02')
old='2662f76a3303a0518bb07fbbdc449c066de2f95b';new='880bff65ad665844828fe50fc395e9cfc1cd81b4'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def stream(p):
    text=p.read_text(); decoder=json.JSONDecoder(); i=0
    while i<len(text):
        while i<len(text) and text[i].isspace():i+=1
        if i==len(text):break
        row,i=decoder.raw_decode(text,i);yield row
changes=subprocess.check_output(['git','-C',str(core),'diff','--name-only',old,new],text=True).splitlines()
outside=[p for p in changes if not p.startswith('engine/sing-box/replace/sing-tun/')]
assert sorted(outside)==sorted(['.gitattributes','docs/architecture.md','engine/sing-box/go.mod','go.mod','scripts/test.ps1'])
assert subprocess.check_output(['git','-C',str(core),'diff',old,new,'--','go.sum','engine/sing-box/go.sum'])==b''
composition=json.loads((out/'final-native/audit/artifact-composition.json').read_bytes())
assert composition['status']=='PASS_EXACT_ARTIFACT_COMPOSITION' and not composition['errors']
matrix=json.loads(Path('E:/r12-c05-triage/package-advisory-matrix.json').read_bytes())
assert all(not p.startswith('github.com/sagernet/sing-tun') for x in matrix for p in x['affected_packages'])
oldroot=Path('C:/r12-c05-utls-update-20260911')
previous_osv={r['osv']['id']:r['osv'] for r in stream(oldroot/'binary-scans/pokrov-core.govulncheck.jsonl') if 'osv' in r}
now_osv={r['osv']['id']:r['osv'] for r in stream(out/'binary-scans/pokrov-core.govulncheck.jsonl') if 'osv' in r}
for item in matrix:
    for key in ['id','summary','details','affected','withdrawn']:
        assert previous_osv[item['id']].get(key)==now_osv[item['id']].get(key)
prior=oldroot/'static-triage-binding.json'
assert prior.exists()
result={'status':'PASS_BOUNDED_ADVISORY_DELTA_REVIEW','previous_source':old,'source':new,'previous_triage':{'path':str(prior),'sha256':sha(prior)},'same_nine_advisory_claims':True,'source_changes_outside_new_local_sing_tun':outside,'affected_package_source_and_registrations_unchanged':True,'go_sums_unchanged':True,'artifact_composition_sha256':sha(out/'final-native/audit/artifact-composition.json'),'scan_collection_sha256':sha(out/'scan-collection.json'),'limits':['Carries forward only prior bounded static dispositions; no whole-application or native-code clearance.','All five scans extract zero symbols; finding traces do not prove reachability.','Raw binary SBOMs label local replacements by filesystem path and (devel); use corrected source SBOMs and native Go build info for source identity.','New sing-tun replacement fixes two Windows cleanup defects; native TUN acceptance for these DLL bytes remains pending.']}
(out/'static-triage-binding.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
