from pathlib import Path
import json,subprocess
r=Path(__file__).parent
remote='''from pathlib import Path
import hashlib,json,re,subprocess,time
target='5a8735db03a9b7134a66eca92a6d2e56f20b0eac54acbb9230024804539500fc'
ip_tokens=lambda raw:re.findall(r'(?<![0-9.])(?:[0-9]{1,3}\\.){3}[0-9]{1,3}(?![0-9.])',raw)
matches=[];checked=0
for folder,pattern in [('/etc/systemd/system','*.service'),('/etc/systemd/network','*.network'),('/run/systemd/network','*.network'),('/usr/local/sbin','*'),('/etc/rc.local','')]:
 paths=[Path(folder)] if not pattern else Path(folder).glob(pattern)
 for p in paths:
  if not p.is_file() or p.stat().st_size>1024*1024:continue
  raw=p.read_bytes();checked+=1
  if any(hashlib.sha256(x.encode()).hexdigest()==target for x in ip_tokens(raw.decode(errors='replace'))):
   matches.append({'path':str(p),'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw)})
units=subprocess.run(['systemctl','list-unit-files','--no-legend','--no-pager','*address*','*extra*','*secondary*','*alias*'],capture_output=True,text=True,timeout=10);assert units.returncode==0
listeners=subprocess.run(['ss','-H','-lntp','sport = :443'],capture_output=True,text=True,timeout=10);assert listeners.returncode==0
listen_rows=[]
for line in listeners.stdout.splitlines():
 parts=line.split();listen_rows.append({'local_bind_sha256':hashlib.sha256(parts[3].encode()).hexdigest(),'wildcard':parts[3] in ['*:443','0.0.0.0:443','[::]:443'],'xray_owner':'"xray"' in line})
print(json.dumps({'captured_epoch':time.time(),'origin':'DE targeted address-owner inspection','config_files_checked':checked,'target_matches':matches,'matching_unit_files':[x.split()[:2] for x in units.stdout.splitlines()],'tcp443_listeners':listen_rows,'production_mutation':False}))
'''
p=subprocess.run(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-de','sudo -n python3 -'],input=remote,capture_output=True,text=True,timeout=30);assert p.returncode==0,'address owner inspection failed'
v=json.loads(p.stdout);out=r/'candidate8-de-address-owner-20260912.json';assert not out.exists();out.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8');print(json.dumps(v))
