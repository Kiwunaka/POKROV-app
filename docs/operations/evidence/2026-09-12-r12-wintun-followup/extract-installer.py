from pathlib import Path
import datetime,hashlib,json,paramiko,subprocess
out=Path('C:/r12-c05-wintun-20260912');lab=Path('E:/r12-b08-linux-lab')
remote='/var/tmp/r12-c05-880b-installer-20260912';unit='pokrov-r12-c05-extract-880b-20260912'
audit=json.loads((out/'windows-package-audit.json').read_bytes());installer=Path(audit['installer']['path']);digest=audit['installer']['sha256']
assert hashlib.sha256(installer.read_bytes()).hexdigest()==digest
s=paramiko.SSHClient();s.load_host_keys(str(lab/'known_hosts'))
s.connect('127.0.0.1',port=55228,username='root',key_filename=str(lab/'private/client.key'),allow_agent=False,look_for_keys=False,timeout=15,disabled_algorithms={'keys':['ssh-ed25519','ecdsa-sha2-nistp256','ecdsa-sha2-nistp384','ecdsa-sha2-nistp521','ssh-rsa']})
def run(cmd):
 _,o,e=s.exec_command(cmd,timeout=120);raw=o.read()+e.read();code=o.channel.recv_exit_status();return code,raw
code,raw=run("python3 - <<'PY'\nfrom pathlib import Path\nimport hashlib,json,shutil\np=Path('/var/tmp/r12-innoextract-20260910/build/innoextract'); print(json.dumps({'extractor_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'free_bytes':shutil.disk_usage('/var/tmp').free}))\nPY")
assert code==0;before=json.loads(raw);assert before['extractor_sha256']=='50ae7bf7b3ae76aed6592c816d5f5eccca0ed14282eaa39dbee344ac81a67322' and before['free_bytes']>1024**3
(out/'extractor-guest-before.json').write_text(json.dumps(before,indent=2)+'\n')
code,raw=run(f'test ! -e {remote} && install -d -m 700 -o nobody -g nogroup {remote}')
assert code==0,raw.decode(errors='replace')
driver="""from pathlib import Path
import datetime,hashlib,json,subprocess,time
r=Path('REMOTE');setup=r/'setup.exe';expected='DIGEST';tool=Path('/var/tmp/r12-innoextract-20260910/build/innoextract')
assert hashlib.sha256(setup.read_bytes()).hexdigest()==expected
assert hashlib.sha256(tool.read_bytes()).hexdigest()=='50ae7bf7b3ae76aed6592c816d5f5eccca0ed14282eaa39dbee344ac81a67322'
t=time.monotonic()
with (r/'extract.log').open('wb') as log:
 result=subprocess.run(['unshare','--net','runuser','-u','nobody','--',str(tool),'--test','--extract','--output-dir',str(r/'extracted'),str(setup)],stdout=log,stderr=subprocess.STDOUT)
rows=[]
if result.returncode==0:
 for p in sorted((r/'extracted').rglob('*')):
  if p.is_file():
   assert not p.is_symlink();rows.append({'path':p.relative_to(r/'extracted').as_posix(),'size':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
assert hashlib.sha256(setup.read_bytes()).hexdigest()==expected
(r/'payload-inventory.json').write_text(json.dumps(rows,indent=2)+'\\n')
receipt={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'exit':result.returncode,'elapsed_seconds':time.monotonic()-t,'installer_sha256':expected,'extractor_sha256':hashlib.sha256(tool.read_bytes()).hexdigest(),'files':len(rows),'installer_executed':False,'origin':'current-origin owned Ubuntu lab VM; nobody; separate empty network namespace','log_sha256':hashlib.sha256((r/'extract.log').read_bytes()).hexdigest(),'status':'EXTRACTED_AWAITING_BYTE_COMPARISON' if result.returncode==0 else 'FAIL'}
(r/'extraction.json').write_text(json.dumps(receipt,indent=2)+'\\n');print(json.dumps(receipt));assert result.returncode==0
""".replace('REMOTE',remote).replace('DIGEST',digest)
(out/'guest-extract.py').write_text(driver)
with s.open_sftp() as f:
 f.put(str(installer),remote+'/setup.exe');f.chown(remote+'/setup.exe',65534,65534);f.chmod(remote+'/setup.exe',0o600)
 f.put(str(out/'guest-extract.py'),remote+'/driver.py')
(out/'extractor-dispatch.json').write_text(json.dumps({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'unit':unit,'remote':remote,'installer_sha256':digest,'status':'DISPATCHING'},indent=2)+'\n')
code,raw=run(f'systemd-run --unit={unit} --wait --pipe /usr/bin/python3 {remote}/driver.py')
(out/'extractor-unit.log').write_bytes(raw)
with s.open_sftp() as f:
 for name in ('payload-inventory.json','extraction.json','extract.log'):f.get(remote+'/'+name,str(out/name))
s.close();assert code==0
print(json.loads((out/'extraction.json').read_bytes())['status'])
