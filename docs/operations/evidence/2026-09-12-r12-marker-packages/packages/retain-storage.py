from pathlib import Path
import datetime,hashlib,json,shlex,shutil,subprocess,psutil,time
out=Path(__file__).parent
assert not any((p.info['name'] or '').lower() in ['java.exe','dart.exe'] for p in psutil.process_iter(['name']))
root=Path('E:/r12client/apps/android_shell/build/app/intermediates').resolve()
groups=['merged_native_libs/storeRelease','intermediary_bundle/storeRelease','module_bundle/storeRelease']
rows=[]
for g in groups:
 base=(root/g).resolve();assert base.is_relative_to(root) and base.is_dir()
 for p in base.rglob('*'):
  assert not p.is_symlink()
  if p.is_file():
   with p.open('rb') as f:h=hashlib.file_digest(f,'sha256').hexdigest()
   rows.append({'path':str(p.resolve()),'relative':p.relative_to(root).as_posix(),'bytes':p.stat().st_size,'sha256':h})
remote='/root/portal-r12-evidence/marker-atomicity-20260912/prior-store-intermediates.tar.gz'
ssh=['ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-de']
subprocess.run(ssh+['test ! -e '+shlex.quote(remote)],check=True,timeout=25)
(out/'storage-retention-plan.json').write_text(json.dumps({'groups':groups,'files':rows,'remote':remote,'reason':'Android direct build storage guard stopped; preserve old store intermediates before scoped removal'},indent=2)+'\n')
pack=subprocess.Popen(['tar.exe','-czf','-','-C',str(root),*groups],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
put=subprocess.Popen(ssh+['umask 077; cat > '+shlex.quote(remote)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
h=hashlib.sha256();count=0;started=time.time()
while b:=pack.stdout.read(1024*1024):
 h.update(b);put.stdin.write(b);count+=len(b)
 # Keep evidence upload below 32 Mbps.
 delay=count/(4*2**20)-(time.time()-started)
 if delay>0:time.sleep(min(delay,0.25))
put.stdin.close();assert pack.wait()==0 and put.wait()==0
rh=subprocess.check_output(ssh+['sha256sum '+shlex.quote(remote)],timeout=25).decode().split()[0];assert rh==h.hexdigest()
code='import tarfile,hashlib,json; t=tarfile.open('+repr(remote)+'); print(json.dumps({m.name:hashlib.sha256(t.extractfile(m).read()).hexdigest() for m in t.getmembers() if m.isfile()}))'
verified=json.loads(subprocess.check_output(ssh+['python3 -c '+shlex.quote(code)],timeout=50));assert verified=={r['relative']:r['sha256'] for r in rows}
prior=json.loads((out/'prior-android-retention.json').read_bytes())
for r in prior['files']:
 p=Path(r['path']).resolve();assert p.is_relative_to(Path('E:/r12client/apps/android_shell/build').resolve())
 with p.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==r['sha256']
 actual=subprocess.check_output(ssh+['sha256sum '+shlex.quote(r['remote_path'])],timeout=25).decode().split()[0];assert actual==r['sha256']
 rows.append({'path':str(p),'bytes':r['bytes'],'sha256':r['sha256'],'retention':r['remote_path']})
receipt={'status':'PASS_RETAINED_AND_HASH_VERIFIED_BEFORE_REMOVAL','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'archive_remote':remote,'archive_sha256':rh,'archive_bytes':count,'files':rows,'total_bytes':sum(r['bytes'] for r in rows),'local_deleted':False}
(out/'storage-retention.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'status':receipt['status'],'files':len(rows),'retained_bytes':receipt['total_bytes'],'compressed_bytes':count}),flush=True)
