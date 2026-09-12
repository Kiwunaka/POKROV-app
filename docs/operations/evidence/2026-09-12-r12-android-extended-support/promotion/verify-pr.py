from pathlib import Path
import json,subprocess,datetime
out=Path('C:/r12-psm-consent-promotion-20260912');source=json.loads((out/'client-source-promoted.json').read_bytes())
run=json.loads(subprocess.check_output(['gh','api','repos/Kiwunaka/POKROV-app/actions/runs/34679718401']))
assert run['head_sha']==source['signed_commit'];print(json.dumps({k:run[k] for k in ['id','status','conclusion','head_sha']}))
if run['status']=='completed':
 assert run['conclusion']=='success';jobs=json.loads(subprocess.check_output(['gh','api','repos/Kiwunaka/POKROV-app/actions/runs/34679718401/jobs']))['jobs'];assert jobs and all(j['conclusion']=='success' for j in jobs)
 r={'status':'PASS','source':source['signed_commit'],'run':run,'jobs':jobs,'conditional_skips_are_not_pass':True,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()};(out/'client-ci-pr.json').write_text(json.dumps(r,indent=2)+'\n')
