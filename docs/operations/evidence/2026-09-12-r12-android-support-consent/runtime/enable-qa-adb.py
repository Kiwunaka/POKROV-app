from pathlib import Path
import json,subprocess,hashlib,datetime
out=Path('C:/r12-android-flavor-installed-20260912');p=Path('E:/LDPlayer/LDPlayer14/vms/config/leidian3.config');cli='E:/LDPlayer/LDPlayer14/ldconsole.exe'
rows=subprocess.check_output([cli,'list2'],text=True).splitlines();assert all(x.split(',')[4]=='0' for x in rows)
old=json.loads(p.read_bytes());new=dict(old);new['basicSettings.adbDebug']=1
p.write_text(json.dumps(new,ensure_ascii=False,indent=4)+'\n',encoding='utf8');assert json.loads(p.read_bytes())==new
r={'status':'PASS_QA_ADB_ENABLED','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'instance_index':3,'previous_field':old.get('basicSettings.adbDebug'),'new_field':1,'all_other_fields_exactly_preserved':True,'before_rows':rows};(out/'adb-enabled.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
boot=out/'boot2';boot.mkdir(exist_ok=True);(boot/'watch-ldplayer.py').write_bytes((out/'watch-ldplayer.py').read_bytes())
