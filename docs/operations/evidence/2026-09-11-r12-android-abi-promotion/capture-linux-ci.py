from pathlib import Path
import hashlib,json,re,subprocess,sys
out=Path(__file__).parent
phase=sys.argv[1];assert phase in ('pr','merge')
ci=json.loads((out/f'client-ci-{phase}.json').read_bytes());assert ci['status']=='PASS'
run=ci['runs'][0];assert run['event']==('pull_request' if phase=='pr' else 'push')
job=run['jobs'][0]
for name in ('Validate cross-repository release-handoff v2 contract','Run client unit and Android flavor tests','Validate conditional Linux daemon foundation'):
 assert any(s['name']==name and s['status']=='completed' and s['conclusion']=='success' for s in job['steps']),name
raw=subprocess.check_output(['gh','run','view',str(run['id']),'--repo','Kiwunaka/POKROV-app','--log'])
text=raw.decode('utf-8',errors='strict')
terms=['Linux beta uses the non-root system-service boundary','Linux service packaging keeps UI non-root and mutations behind polkit','Linux support matrix has one exact foundation row and explicit backlog','Linux network transaction events stay closed and fail-closed','Linux polkit D-Bus decisions use a closed authorization trace']
selected=[]
for line in text.splitlines():
 if any(t in line for t in terms) or re.search(r'\bok\s+github\.com/Kiwunaka/pokrov-app/linux-daemon/internal/(host|auth|service)\b',line):
  selected.append(line)
for t in terms:assert any(t in line for line in selected),t
for package in ('host','auth','service'):
 assert any(re.search(r'\bok\s+github\.com/Kiwunaka/pokrov-app/linux-daemon/internal/'+package+r'\b',line) for line in selected),package
payload=('\n'.join(selected)+'\n').encode('utf-8');name=f'linux-ci-{phase}-selected.log';(out/name).write_bytes(payload)
result={'status':'PASS','run':run['html_url'],'run_id':run['id'],'source':ci['source'],'phase':phase,'required_steps':'THREE_EXECUTED_SUCCESS','selected_linux_test_names':terms,'go_packages':['internal/host','internal/auth','internal/service'],'retained_log':name,'retained_lines':len(selected),'retained_sha256':hashlib.sha256(payload).hexdigest(),'full_remote_log_sha256':hashlib.sha256(raw).hexdigest(),'full_remote_log_bytes':len(raw),'full_remote_log_retained_locally':False,'limits':'CI executes source/fixture tests and build/vet on hosted Linux, not installed Ubuntu24.04 VPN or desktop/polkit-agent proof.'}
(out/f'linux-ci-{phase}-binding.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result),flush=True)
