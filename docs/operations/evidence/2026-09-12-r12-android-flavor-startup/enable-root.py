from pathlib import Path
import subprocess,json,hashlib,datetime
out=Path(__file__).parent;assert not (out/'root-enabled.json').exists();cli='E:/LDPlayer/LDPlayer14/ldconsole.exe';p=Path('E:/LDPlayer/LDPlayer14/vms/config/leidian3.config')
rows=subprocess.check_output([cli,'list2'],text=True).splitlines();assert all(r.split(',')[4]=='0' for r in rows);assert next(r for r in rows if r.startswith('3,')).split(',')[1]=='pokrov-qa-120'
raw=p.read_bytes();before=json.loads(raw);nonroot=lambda d:{k:v for k,v in d.items() if 'root' not in k.lower()};digest=lambda d:hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()
other={str(q):hashlib.sha256(q.read_bytes()).hexdigest() for i in range(3) for q in [Path(f'E:/LDPlayer/LDPlayer14/vms/config/leidian{i}.config')]}
assert not any(bool(v) for k,v in before.items() if 'root' in k.lower())
r=subprocess.run([cli,'modify','--index','3','--root','1'],capture_output=True);assert r.returncode==0
after=json.loads(p.read_bytes());roots={k:v for k,v in after.items() if 'root' in k.lower()};assert roots and any(bool(v) for v in roots.values())
assert nonroot(before)==nonroot(after);assert all(hashlib.sha256(Path(q).read_bytes()).hexdigest()==v for q,v in other.items())
report={'status':'PASS_SCOPED_ROOT_ENABLED','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'instance_index':3,'before_config_sha256':hashlib.sha256(raw).hexdigest(),'after_config_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'before_root_fields':{k:v for k,v in before.items() if 'root' in k.lower()},'after_root_fields':roots,'nonroot_config_sha256':digest(nonroot(before)),'other_configs_sha256':other,'other_configs_unchanged':True,'original_su_available':False,'restore_required':True}
(out/'root-enabled.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
