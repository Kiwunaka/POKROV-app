import hashlib,json,pathlib,subprocess
r=pathlib.Path('/home/pokrovtest/r12-l02');client=r/'l04-client-0bcb595/client';bundle=client/'apps/linux_shell/build/linux/x64/release/bundle'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(r/'pokrov-core-08')=='979e8d77a8d41237a490ada5b129ff0b8f8a7a5cf4d754b1651196a5118aa8ce'
assert digest(r/'pokrov-linuxd-09')=='07a3a0f775a789e2399bff9f4bdeb97948f3d321696ed9bbd4a2edf6f4ff1053'
assert json.loads((r/'l04-client-build-04.json').read_bytes())['exit_code']==0
command=['python3',str(client/'apps/linux_shell/packaging/build-deb.py'),'--bundle',str(bundle),'--daemon',str(r/'pokrov-linuxd-09'),'--core',str(r/'pokrov-core-08'),'--client-revision','0bcb5953b522b4d162e77214dda0211cdbc6df95','--core-revision','97ec91e3a74c96db3ce5c0c98364b715bf344964','--package-revision','2','--output',str(r/'l04-packages')]
with (r/'l04-deb-assemble-02.log').open('w') as log:p=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
print(json.dumps({'exit_code':p.returncode,'command':command}));raise SystemExit(p.returncode)
