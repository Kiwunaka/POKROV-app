import hashlib,json,os,pathlib,subprocess,tarfile,time
r=pathlib.Path('/home/pokrovtest/r12-l02');archive=r/'linux-client-b5080d7.tar.gz';dest=r/'l04-client-b5080d7'
assert hashlib.sha256(archive.read_bytes()).hexdigest()=='35cb06b08605470e5580a59602f16365b8317e5aabf7a9e207d000e4af431891'
dest.mkdir()
with tarfile.open(archive) as tar:tar.extractall(dest,filter='data')
client=dest/'client';app=client/'apps/linux_shell';sdk=r/'flutter-3.38.5'
pins=json.loads((client/'config/support-signing.seed.json').read_bytes())
defines={'POKROV_API_BASE_URL':'https://app.pokrov.space','POKROV_APP_VERSION':'1.2.0+30','POKROV_BUILD_NUMBER':'30','POKROV_GIT_REVISION':'b5080d750ab40c53deb35062720500b532e8cc18','POKROV_EMERGENCY_SIGNING_KEY_ID':'emg-20260815-v1','POKROV_EMERGENCY_SIGNING_PUBLIC_KEY_B64':'770Pe3OXijrq4zlq4NBfF83Hp4HZ-1CpJNwvtCAJcbU','POKROV_SUPPORT_SIGNING_KEY_ID':pins['key_id'],'POKROV_SUPPORT_SIGNING_PUBLIC_KEY_B64':pins['public_key_b64url']}
definepath=r/'l04-public-build-defines.json';definepath.write_text(json.dumps(defines,indent=2)+'\n')
env=dict(os.environ,PATH=str(sdk/'bin')+':'+os.environ['PATH'],PUB_CACHE=str(r/'l04-pub-cache'),CMAKE_BUILD_PARALLEL_LEVEL='2')
steps=[]
commands=[['flutter','pub','get','--enforce-lockfile'],['flutter','build','linux','--release','--no-pub','--dart-define-from-file='+str(definepath)]]
with (r/'l04-client-build-01.log').open('w') as log:
 for command in commands:
  start=time.monotonic();p=subprocess.run(command,cwd=app,env=env,stdout=log,stderr=subprocess.STDOUT)
  steps.append({'command':command,'exit_code':p.returncode,'seconds':round(time.monotonic()-start,2)})
  if p.returncode:break
receipt={'client_revision':defines['POKROV_GIT_REVISION'],'source_archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'flutter_revision':'f6ff1529fd6d8af5f706051d9251ac9231c83407','steps':steps,'exit_code':steps[-1]['exit_code']}
(r/'l04-client-build-01.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt));raise SystemExit(receipt['exit_code'])
