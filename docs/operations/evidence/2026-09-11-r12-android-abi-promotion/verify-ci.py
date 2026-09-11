import datetime,json,subprocess,sys
from pathlib import Path
out=Path(__file__).parent
lane,phase,sha=sys.argv[1:]
assert lane in ('client','platform') and phase in ('pr','merge')
assert len(sha)==40 and all(c in '0123456789abcdef' for c in sha)
repo='Kiwunaka/POKROV-app' if lane=='client' else 'Kiwunaka/portal'
names=('Release v2 Contract',) if lane=='client' else ('Guardrails','Release v2 Contract')
def gh(path):return json.loads(subprocess.check_output(['gh','api',f'repos/{repo}/'+path]))
raw=gh('actions/runs?head_sha='+sha+'&per_page=30')['workflow_runs'];runs=[]
for name in names:
 matches=[r for r in raw if r['name']==name];assert len(matches)==1,(name,len(matches))
 run=matches[0];assert run['head_sha']==sha and run['status']=='completed' and run['conclusion']=='success',name
 item={k:run[k] for k in ('id','name','head_sha','status','conclusion','event','run_attempt','html_url')}
 item['jobs']=[{k:j[k] for k in ('id','name','status','conclusion','steps')} for j in gh('actions/runs/'+str(run['id'])+'/jobs')['jobs']]
 assert all(j['status']=='completed' and j['conclusion']=='success' for j in item['jobs'])
 runs.append(item)
r={'status':'PASS','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':sha,'phase':phase,'runs':runs}
if lane=='platform':r['release_base_isolation']='SKIPPED_NOT_PASS'
target=out/f'{lane}-ci-{phase}.json';assert not target.exists();target.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8')
print(json.dumps({**r,'runs':[{k:v for k,v in r.items() if k!='jobs'} for r in runs]}))
