from pathlib import Path
import datetime,hashlib,json,subprocess,time
r=Path('/var/tmp/r12-c05-880b-installer-20260912');setup=r/'setup.exe';expected='2e114c6ab88c8c7b898272d978c21b1608cc28c0c6cf1f2d47e2cc6392762caa';tool=Path('/var/tmp/r12-innoextract-20260910/build/innoextract')
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
(r/'payload-inventory.json').write_text(json.dumps(rows,indent=2)+'\n')
receipt={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'exit':result.returncode,'elapsed_seconds':time.monotonic()-t,'installer_sha256':expected,'extractor_sha256':hashlib.sha256(tool.read_bytes()).hexdigest(),'files':len(rows),'installer_executed':False,'origin':'current-origin owned Ubuntu lab VM; nobody; separate empty network namespace','log_sha256':hashlib.sha256((r/'extract.log').read_bytes()).hexdigest(),'status':'EXTRACTED_AWAITING_BYTE_COMPARISON' if result.returncode==0 else 'FAIL'}
(r/'extraction.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt));assert result.returncode==0
