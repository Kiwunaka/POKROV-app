from pathlib import Path
import json,subprocess,datetime
out=Path(__file__).parent;repo='Kiwunaka/POKROV-app';branch='codex/marker-atomicity-signed-20260912'
def gh(*args):return json.loads(subprocess.check_output(['gh',*args]))
candidate=json.loads((out/'client-candidate.json').read_bytes())
assert gh('api','repos/'+repo+'/git/ref/heads/'+branch)['object']['sha']==candidate['parent']
assert gh('api','repos/'+repo+'/branches/main')['commit']['sha']==candidate['parent']
assert gh('api','repos/'+repo+'/branches/main/protection')==json.loads((out/'client-protection-before.json').read_bytes())
result=gh('api','graphql','--input',str(out/'client-signed-request.json'))
(out/'client-signed-response.json').write_text(json.dumps(result,indent=2)+'\n')
assert not result.get('errors')
commit=result['data']['createCommitOnBranch']['commit']
assert commit['signature']['isValid'] and commit['signature']['state']=='VALID' and commit['tree']['oid']==candidate['tree']
receipt={'status':'PASS_SIGNED_EXACT_TREE','source':candidate['source'],'parent':candidate['parent'],'signed_commit':commit['oid'],'tree':commit['tree']['oid'],'signature_valid':True,'branch':branch,'file_count':len(candidate['files']),'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'initial_post':'CONNECT_TIMEOUT; authoritative branch and main remained parent before retry'}
(out/'client-source-promoted.json').write_text(json.dumps(receipt,indent=2)+'\n')
url=subprocess.check_output(['gh','pr','create','--repo',repo,'--base','main','--head',branch,'--draft','--title','Preserve previous-exit marker when replacement fails','--body-file',str(out/'client-pr-body.md')],text=True).strip()
receipt['pr']=url;(out/'client-source-promoted.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
