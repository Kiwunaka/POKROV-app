from pathlib import Path
import json,subprocess,hashlib,datetime,xml.etree.ElementTree as ET
out=Path('C:/r12-android-flavor-installed-20260912');p=Path('E:/LDPlayer/LDPlayer14/vms/config/leidian3.config');cli='E:/LDPlayer/LDPlayer14/ldconsole.exe'
old=json.loads(p.read_bytes());prior=json.loads(Path('C:/r12-android-extended-20260912/root-restored.json').read_bytes());assert hashlib.sha256(p.read_bytes()).hexdigest()==prior['config_sha256']
rows=subprocess.check_output([cli,'list2'],text=True).splitlines();assert all(x.split(',')[4]=='0' for x in rows)
other={str(q):hashlib.sha256(q.read_bytes()).hexdigest() for i in range(3) for q in [p.parent/f'leidian{i}.config']}
# Restore the exact previous display tuple and retain the actual vbox CPU/RAM values.
x=ET.parse('E:/LDPlayer/LDPlayer14/vms/leidian3/leidian.vbox');cpu=next(n for n in x.iter() if n.tag.endswith('}CPU'));ram=next(n for n in x.iter() if n.tag.endswith('}Memory'));assert cpu.get('count')=='4' and ram.get('RAMSize')=='4096'
subprocess.run([cli,'modify','--index','3','--resolution','1080,1920,480','--cpu','4','--memory','4096','--root','0'],check=True,capture_output=True)
subprocess.run([cli,'rename','--index','3','--title','pokrov-qa-120'],check=True,capture_output=True)
new=json.loads(p.read_bytes());assert all(new.get(k)==v for k,v in old.items() if k.startswith('propertySettings.'));assert all(hashlib.sha256(Path(k).read_bytes()).hexdigest()==v for k,v in other.items())
rowsafter=subprocess.check_output([cli,'list2'],text=True).splitlines();row=next(r for r in rowsafter if r.startswith('3,')).split(',');assert row[1]=='pokrov-qa-120' and row[7:]==['1080','1920','480']
r={'status':'PASS_QA_DISPLAY_RESTORED','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'before':rows,'after':rowsafter,'prior_root_restoration_sha256_matched':True,'cpu':4,'memory_mib':4096,'device_property_fields_unchanged':True,'other_configs_unchanged':True,'after_config_sha256':hashlib.sha256(p.read_bytes()).hexdigest()};(out/'fixture-display-restored.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
