from pathlib import Path
import json,subprocess,datetime,hashlib,psutil
out=Path('C:/r12-android-flavor-installed-20260912');cli='E:/LDPlayer/LDPlayer14/ldconsole.exe';p=Path('E:/LDPlayer/LDPlayer14/vms/config/leidian3.config')
assert all(r.split(',')[4]=='0' for r in subprocess.check_output([cli,'list2'],text=True).splitlines());assert not psutil.pid_exists(21196) and not psutil.pid_exists(37064)
old=json.loads(p.read_bytes());assert old['basicSettings.rootMode'] is True and old['basicSettings.adbDebug']==1
new=dict(old);new['basicSettings.rootMode']=False;p.write_text(json.dumps(new,ensure_ascii=False,indent=4)+'\n',encoding='utf8');assert json.loads(p.read_bytes())==new
prior=json.loads((out/'root-enabled.json').read_bytes());assert all(hashlib.sha256(Path(k).read_bytes()).hexdigest()==v for k,v in prior['other_configs_sha256'].items())
r={'status':'PASS_ROOT_DISABLED_CONFIG','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'root_fields':{'basicSettings.rootMode':False},'config_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'all_other_current_config_fields_exactly_preserved':True,'method':'scoped config field update after both exact fixture processes exited','other_configs_unchanged':True,'all_instances_stopped':True,'root_disabled_guest_boot_check':'PENDING'};(out/'root-restored.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
b=out/'boot3';b.mkdir(exist_ok=True);(b/'watch-ldplayer.py').write_bytes((out/'watch-ldplayer.py').read_bytes())
