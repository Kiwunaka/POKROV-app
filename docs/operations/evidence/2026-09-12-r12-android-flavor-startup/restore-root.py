from pathlib import Path
import json,subprocess,hashlib,datetime
out=Path(__file__).parent;cli='E:/LDPlayer/LDPlayer14/ldconsole.exe';old=json.loads((out/'root-enabled.json').read_bytes())
rows=subprocess.check_output([cli,'list2'],text=True).splitlines();assert all(r.split(',')[4]=='0' for r in rows)
subprocess.run([cli,'modify','--index','3','--root','0'],check=True,capture_output=True)
p=Path('E:/LDPlayer/LDPlayer14/vms/config/leidian3.config');value=json.loads(p.read_bytes());fields={k:v for k,v in value.items() if 'root' in k.lower()};assert fields and not any(fields.values())
assert all(hashlib.sha256(Path(q).read_bytes()).hexdigest()==sha for q,sha in old['other_configs_sha256'].items())
r={'status':'PASS_ROOT_DISABLED_CONFIG','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'root_fields':fields,'config_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'other_configs_unchanged':True,'all_instances_stopped':True,'root_disabled_guest_boot_check':'PENDING'};(out/'root-restored.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
