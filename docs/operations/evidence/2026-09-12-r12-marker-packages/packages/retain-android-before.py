from pathlib import Path
import datetime,hashlib,json,subprocess,shlex
out=Path(__file__).parent;audit=json.loads(Path('C:/r12-dart-crash-packages-20260912/android-package-audit.json').read_bytes())
assert audit['source_client']=='f7115c505c314a7322481997a46343b03dae1127'
rows=[]
for item in audit['artifacts']:
 a=item['artifact'];p=Path(a['path']);assert p.stat().st_size==a['size'] and hashlib.file_digest(p.open('rb'),'sha256').hexdigest()==a['sha256']
 rows.append({'path':str(p),'name':p.name,'bytes':a['size'],'sha256':a['sha256']})
assert len(rows)==5 and sum(r['name'].endswith('.aab') for r in rows)==1
remote='/root/portal-r12-evidence/marker-atomicity-20260912/prior-android'
code='import pathlib,shutil; p=pathlib.Path('+repr(remote)+'); assert shutil.disk_usage(p.parents[1]).free>8*2**30; p.parent.mkdir(mode=0o700,exist_ok=False); p.mkdir(mode=0o700,exist_ok=False)'
subprocess.run(['ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-de','python3 -c '+shlex.quote(code)],capture_output=True,check=True,timeout=25)
(out/'prior-android-plan.json').write_text(json.dumps({'status':'PREPARED','source_client':audit['source_client'],'remote_host':'pokrov-de','files':rows},indent=2)+'\n')
for row in rows:
 target=remote+'/'+row['name'];subprocess.run(['scp.exe','-q','-l','32768','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes',row['path'],'pokrov-de:'+target],capture_output=True,check=True,timeout=180)
 value=subprocess.check_output(['ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-de','chmod 600 '+shlex.quote(target)+' && sha256sum '+shlex.quote(target)],timeout=25).decode().split()[0]
 assert value==row['sha256'] and hashlib.file_digest(Path(row['path']).open('rb'),'sha256').hexdigest()==value
 row.update(remote_path=target,remote_sha256=value)
 (out/'prior-android-progress.json').write_text(json.dumps({'completed':[r for r in rows if 'remote_sha256' in r]},indent=2)+'\n')
 print('Retained '+row['name'],flush=True)
r={'status':'PASS_PRIOR_PACKAGE_BYTES_RETAINED','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_client':audit['source_client'],'remote_host':'pokrov-de','files':rows,'local_deleted':False}
(out/'prior-android-retention.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'status':r['status'],'files':len(rows),'bytes':sum(x['bytes'] for x in rows)}))
