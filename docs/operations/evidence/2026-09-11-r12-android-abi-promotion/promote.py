from pathlib import Path
import base64,datetime,hashlib,json,subprocess
out=Path(__file__).parent;root=Path('C:/r12-current-windows-source-20260911');repo='Kiwunaka/POKROV-app'
source='90337b33180b1600f0d6c25029627d0e9dc5b217';parent='d9763e8cd7aba9b215015e07c0576f667c1dec09';branch='codex/android-target-abi-signed-20260911'
paths=['apps/android_shell/android/app/build.gradle','docs/operations/android-release-audit.md']
def git(*args):return subprocess.check_output(['git','-C',str(root),*args])
def gh(*args):return json.loads(subprocess.check_output(['gh',*args],cwd=root))
assert git('rev-parse','HEAD').decode().strip()==source
assert not git('diff','--name-only','HEAD')
assert set(git('diff','--name-only',parent,source).decode().splitlines())==set(paths)
remote=gh('api',f'repos/{repo}/branches/main');assert remote['commit']['sha']==parent
protection=gh('api',f'repos/{repo}/branches/main/protection')
assert protection['required_signatures']['enabled'] and protection['enforce_admins']['enabled'] and protection['required_status_checks']['strict']
assert protection['required_status_checks']['contexts']==['cross-repository-contract']
assert protection['required_pull_request_reviews']['required_approving_review_count']==0
assert not protection['allow_force_pushes']['enabled'] and not protection['allow_deletions']['enabled']
assert protection['required_linear_history']['enabled'] and protection['required_conversation_resolution']['enabled']
audit=json.loads(Path('E:/r12-current-android-package-20260911/android-package-audit.json').read_bytes());assert audit['status']=='PASS_LOCAL_PACKAGE' and audit['source_client_sha']==source
validation=json.loads(Path('E:/r12client/docs/operations/evidence/2026-09-11-r12-current-android-arm64/validation.json').read_bytes());assert validation['status']=='PASS'
existing=gh('pr','list','--repo',repo,'--head',branch,'--state','all','--json','number,title,state,url');assert existing==[]
(out/'preflight.json').write_text(json.dumps({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':source,'parent':parent,'tree':git('rev-parse',source+'^{tree}').decode().strip(),'paths':paths,'branch_protection':protection,'local_package_sha':audit['artifact']['sha256'],'independent_review_performed':False},indent=2)+'\n',encoding='utf-8')
additions=[];hashes=[]
for path in paths:
 raw=git('show',source+':'+path);additions.append({'path':path,'contents':base64.b64encode(raw).decode()});hashes.append({'path':path,'sha256':hashlib.sha256(raw).hexdigest()})
title='Match Android native packaging to Flutter target architectures'
body='''An ARM64-only Flutter release build compiled ARM64 app code while Gradle still packaged dependency libraries for three architectures. Derive native ABI filters and split outputs from the same target-platform list, so each selected ABI has matching Flutter and Core libraries. The default three-architecture production command and its four direct APK outputs remain unchanged.

Validation: actual Gradle probes confirm ARM64-only packaging and the existing full production output configuration; release-handoff v2 passed 16 cases; validate-seed passed. A local signed ARM64 release APK passed package/version/ABI, non-debuggable manifest, native identity, notices and embedded revision checks (SHA-256 3ecff58793e0f6b354ce49eabd5f84f06052a92176cd12e4c5c7583a91cc41a0). The complete signed commit tree matches locally tested 90337b3; that APK retains its original 90337b3 diagnostics identity.

No new build option, dependency, runtime code or release pointer changes. Other package variants and installed-device acceptance remain open. Independent review was not performed under the existing owner-solo exception; required CI and branch protection remain in force.
'''
(out/'pr-body.md').write_text(body,encoding='utf-8')
request={'query':'mutation($input:CreateCommitOnBranchInput!){createCommitOnBranch(input:$input){commit{oid tree{oid} signature{isValid state}}}}','variables':{'input':{'branch':{'repositoryNameWithOwner':repo,'branchName':branch},'expectedHeadOid':parent,'message':{'headline':title},'fileChanges':{'additions':additions}}}}
request_path=out/'signed-request.json';assert not request_path.exists();request_path.write_text(json.dumps(request)+'\n',encoding='utf-8')
created=gh('api','--method','POST',f'repos/{repo}/git/refs','-f','ref=refs/heads/'+branch,'-f','sha='+parent)
(out/'branch-created.json').write_text(json.dumps(created,indent=2)+'\n',encoding='utf-8')
result=gh('api','graphql','--input',str(request_path));(out/'signed-response.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');assert not result.get('errors')
commit=result['data']['createCommitOnBranch']['commit'];assert commit['signature']['isValid'] and commit['signature']['state']=='VALID'
assert commit['tree']['oid']==git('rev-parse',source+'^{tree}').decode().strip()
url=subprocess.check_output(['gh','pr','create','--repo',repo,'--base','main','--head',branch,'--draft','--title',title,'--body-file',str(out/'pr-body.md')],cwd=root,text=True).strip()
receipt={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':source,'parent':parent,'signed_commit':commit['oid'],'tree':commit['tree']['oid'],'signature_valid':True,'pr':url,'branch':branch,'files':hashes,'local_apk_revision_remains':source,'local_apk_sha256':audit['artifact']['sha256'],'independent_review_performed':False}
(out/'source-promoted.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps(receipt),flush=True)
