import datetime,json,pathlib,subprocess
r=pathlib.Path('C:/r12-c05-wintun-20260912/promotion');source=json.loads((r/'core-source-promoted.json').read_bytes());sha=source['signed_commit'];repo='Kiwunaka/pokrov-core'
def gh(path):return json.loads(subprocess.check_output(['gh','api',f'repos/{repo}/'+path]))
run=gh('actions/runs/34662208543');assert run['head_sha']==sha and run['status']=='completed' and run['conclusion']=='success'
jobs=gh('actions/runs/'+str(run['id'])+'/jobs')['jobs'];assert jobs
assert all(j['status']=='completed' and j['conclusion']=='success' for j in jobs)
steps=[{'job':j['name'],'name':s['name'],'conclusion':s['conclusion']} for j in jobs for s in j['steps']]
runs=[{**{k:run[k] for k in ('id','name','head_sha','status','conclusion','event','run_attempt','html_url')},'jobs':jobs}]
receipt={'status':'PASS','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':sha,'phase':'pr','runs':runs,'non_pass_steps':[s for s in steps if s['conclusion']!='success'],'conditional_skips_are_not_pass':True}
p=r/'core-ci-pr.json';assert not p.exists();p.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({k:v for k,v in receipt.items() if k!='runs'}))
