import datetime,json,pathlib,subprocess
p=pathlib.Path(__file__).parent
for label,repo,run_id in [('core','Kiwunaka/pokrov-core',34662903252),('client','Kiwunaka/POKROV-app',34662156331)]:
 def gh(path):return json.loads(subprocess.check_output(['gh','api',f'repos/{repo}/'+path]))
 merge=json.loads((p/(label+'-merge-binding.json')).read_bytes())
 expected=merge['merge']
 run=gh('actions/runs/'+str(run_id))
 assert run['head_sha']==expected and run['status']=='completed' and run['conclusion']=='success' and run['event']=='push'
 jobs=gh('actions/runs/'+str(run_id)+'/jobs')['jobs'];assert jobs
 assert all(j['status']=='completed' and j['conclusion']=='success' for j in jobs)
 assert gh('branches/main')['commit']['sha']==expected
 steps=[{'job':j['name'],'name':s['name'],'conclusion':s['conclusion']} for j in jobs for s in j['steps']]
 receipt={'status':'PASS','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':expected,'phase':'main','runs':[{**{k:run[k] for k in ('id','name','head_sha','status','conclusion','event','run_attempt','html_url')},'jobs':jobs}],'non_pass_steps':[s for s in steps if s['conclusion']!='success'],'conditional_skips_are_not_pass':True,'scope':'Core880/clientc06 coordinated Wintun source promotion; later setup-path privacy fix is separate and not covered'}
 target=p/(label+'-ci-main.json');assert not target.exists();target.write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({k:v for k,v in receipt.items() if k!='runs'}))
