from pathlib import Path
import datetime,hashlib,json,shutil,subprocess,time

out=Path(__file__).parent
base='/tmp/pokrov-r12-core-validation-1c8b33f6a771409a'
destination=base+'/retained-source-archives-20260912'
paths=[Path(p) for p in [
 'E:/r12-2662-source-20260911/pokrov-core-2662f76-source-review.zip',
 'E:/r12-904-source-20260911/pokrov-core-904e440-source-review.zip',
 'E:/r12-c05-source-packet/pokrov-core-8dc57a8-source-review-compact.zip',
 'E:/r12-c05-source-packet/pokrov-core-8dc57a8-source-review.zip',
 'E:/r12-current-source-20260910/pokrov-core-c7a11f7-source-review.zip']]
sha=lambda p:hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
def remote(code,timeout=120):
 p=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=8','pokrov-de','python3 -'],input=code,text=True,capture_output=True,timeout=timeout,check=True)
 return json.loads(p.stdout)
assert min(shutil.disk_usage('C:/').free,shutil.disk_usage('E:/').free)>40*2**30
report={'status':'RUNNING','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'reason':'Two current Android package attempts stopped at disk reserve; retain historical source ZIPs remotely before local relocation','destination_host':'pokrov-de','files':[],'local_deletion_performed':False}
def save(): (out/'source-archive-retention.json').write_text(json.dumps(report,indent=2)+'\n')
save()
for p in paths:
 assert p.is_file() and not p.is_symlink() and p.resolve().parent==p.parent.resolve()
 row={'local_path':str(p.resolve()),'bytes':p.stat().st_size,'sha256':sha(p)}
 target=base+'/offline-source-2662-20260912/source-review.zip' if '2662f76' in p.name else destination+'/'+p.name
 row['remote_path']=target
 check=remote("from pathlib import Path\nimport json,shutil\np=Path("+repr(target)+")\nassert shutil.disk_usage('/tmp').free>35*2**30\np.parent.mkdir(mode=0o700,exist_ok=True)\nprint(json.dumps({'exists':p.exists()}))")
 if not check['exists']:
  code="import pathlib,shutil,sys; p=pathlib.Path("+repr(target)+"); f=p.open('xb'); shutil.copyfileobj(sys.stdin.buffer,f); f.close()"
  command="python3 -c '"+code.replace("'","'\"'\"'")+"'"
  with (out/(p.stem+'-retention-upload.log')).open('wb') as log:
   proc=subprocess.Popen(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=8','pokrov-de',command],stdin=subprocess.PIPE,stdout=log,stderr=log)
   started=time.monotonic();sent=0
   with p.open('rb') as f:
    while chunk:=f.read(1024**2):
     proc.stdin.write(chunk);sent+=len(chunk)
     delay=sent/(1024**2)-(time.monotonic()-started)
     if delay>0:time.sleep(delay)
     report['upload']={'file':p.name,'bytes_sent':sent,'bytes_total':row['bytes']};save()
   proc.stdin.close();assert proc.wait(timeout=60)==0
  row['uploaded_now']=True
 else: row['uploaded_now']=False
 checked=remote("from pathlib import Path\nimport hashlib,json\np=Path("+repr(target)+")\nwith p.open('rb') as f:h=hashlib.file_digest(f,'sha256').hexdigest()\nprint(json.dumps({'bytes':p.stat().st_size,'sha256':h}))")
 assert checked['bytes']==row['bytes'] and checked['sha256']==row['sha256'] and sha(p)==row['sha256']
 row['status']='PASS_REMOTE_BYTES_VERIFIED';report['files'].append(row);save();print(json.dumps(row),flush=True)
report.pop('upload',None);report.update(status='PASS_ALL_REMOTE_ARCHIVES_VERIFIED',total_bytes=sum(r['bytes'] for r in report['files']))
save();print(json.dumps({'status':report['status'],'total_bytes':report['total_bytes']}))
