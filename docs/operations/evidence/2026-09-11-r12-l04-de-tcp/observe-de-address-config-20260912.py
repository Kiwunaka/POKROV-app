from pathlib import Path
import json,subprocess

r=Path(__file__).parent
remote='''from pathlib import Path
import hashlib,json,re,subprocess,time
targets={'default_delivery':'5a8735db03a9b7134a66eca92a6d2e56f20b0eac54acbb9230024804539500fc','management_delivery':'66624e15725d946c4321da789698aff1d98a64de1af16bb4dc43f2bff20bea67'}
files=[]
for root,pattern in [('/etc/netplan','*.yaml'),('/etc/systemd/network','*.network'),('/etc/network','interfaces')]:
 for p in Path(root).glob(pattern):
  raw=p.read_bytes();tokens=set(re.findall(r'(?<![0-9.])(?:[0-9]{1,3}\\.){3}[0-9]{1,3}(?![0-9.])',raw.decode(errors='replace')))
  files.append({'path':str(p),'file_sha256':hashlib.sha256(raw).hexdigest(),'target_address_present':{k:any(hashlib.sha256(x.encode()).hexdigest()==v for x in tokens) for k,v in targets.items()}})
boot=Path('/proc/stat').read_text();boot_epoch=int(next(x.split()[1] for x in boot.splitlines() if x.startswith('btime ')))
units={}
for unit in ['systemd-networkd.service','NetworkManager.service']:
 p=subprocess.run(['systemctl','is-active',unit],capture_output=True,text=True);units[unit]=p.stdout.strip()
print(json.dumps({'captured_epoch':time.time(),'origin':'owned DE read-only static-address configuration','boot_epoch':boot_epoch,'files':files,'network_units':units,'no_runtime_mutation':True}))
'''
p=subprocess.run(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-de','sudo -n python3 -'],input=remote,capture_output=True,text=True,timeout=30);assert p.returncode==0,'projection failed'
result=json.loads(p.stdout);out=r/'candidate8-de-address-config-20260912.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result))
