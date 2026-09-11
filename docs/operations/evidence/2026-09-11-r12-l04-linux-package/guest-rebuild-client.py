import hashlib,json,os,pathlib,subprocess,time
r=pathlib.Path('/home/pokrovtest/r12-l02');app=r/'l04-client-b5080d7/client/apps/linux_shell';sdk=r/'flutter-3.38.5'
env=dict(os.environ,PATH=str(sdk/'bin')+':'+os.environ['PATH'],PUB_CACHE=str(r/'l04-pub-cache'),CMAKE_BUILD_PARALLEL_LEVEL='2')
command=['flutter','build','linux','--release','--no-pub','--dart-define-from-file='+str(r/'l04-public-build-defines.json')]
log=r/'l04-client-build-02.log';assert not log.exists();start=time.monotonic()
with log.open('w') as stream:p=subprocess.run(command,cwd=app,env=env,stdout=stream,stderr=subprocess.STDOUT)
receipt={'client_revision':'b5080d750ab40c53deb35062720500b532e8cc18','command':command,'exit_code':p.returncode,'seconds':round(time.monotonic()-start,2)}
if p.returncode==0:
 bundle=app/'build/linux/x64/release/bundle'
 receipt['files']=[{'path':str(f.relative_to(bundle)),'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in sorted(bundle.rglob('*')) if f.is_file()]
(r/'l04-client-build-02.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({k:v for k,v in receipt.items() if k!='files'}));raise SystemExit(p.returncode)
