from pathlib import Path
import json,subprocess,datetime
out=Path('C:/r12-psm-consent-promotion-20260912');source=json.loads((out/'client-source-promoted.json').read_bytes());merge=json.loads((out/'client-merge-binding.json').read_bytes());repo='Kiwunaka/POKROV-app'
def gh(path):return json.loads(subprocess.check_output(['gh','api','repos/'+repo+'/'+path]))
run=gh('actions/runs/34680765949')
print(json.dumps({k:run[k] for k in ['id','status','conclusion','head_sha']}))
if run['status']=='completed':
 assert run['conclusion']=='success' and run['head_sha']==merge['merge']
 jobs=gh('actions/runs/34680765949/jobs')['jobs'];assert jobs and all(j['conclusion']=='success' for j in jobs)
 r={'status':'PASS','source':run['head_sha'],'run':run,'jobs':jobs,'conditional_skips_are_not_pass':True,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()};(out/'client-ci-main.json').write_text(json.dumps(r,indent=2)+'\n')
 after=gh('branches/main/protection');before=json.loads((out/'client-protection-before.json').read_bytes());(out/'client-protection-after.json').write_text(json.dumps(after,indent=2)+'\n')
 assert before==after
 (out/'protection-comparison.json').write_text(json.dumps({'status':'PASS_EXACT_UNCHANGED','strict_signed_policy_unchanged':True},indent=2)+'\n')
