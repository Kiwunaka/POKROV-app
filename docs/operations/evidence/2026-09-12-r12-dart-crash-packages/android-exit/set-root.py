from pathlib import Path
import hashlib,json,subprocess,psutil,sys,datetime
out=Path(__file__).parent;enabled=sys.argv[1]=='enable';assert sys.argv[1] in ['enable','restore']
config=Path('E:/LDPlayer/LDPlayer14/vms/config/leidian3.config');cli='E:/LDPlayer/LDPlayer14/ldconsole.exe'
rows=subprocess.check_output([cli,'list2'],text=True).splitlines()
assert all(r.split(',')[4]=='0' for r in rows)
assert next(r for r in rows if r.startswith('3,')).split(',')[1]=='pokrov-qa-120'
assert not any(p.name().lower() in ['dnplayer.exe','ld9boxheadless.exe'] for p in psutil.process_iter())
raw=config.read_bytes();old=json.loads(raw);assert old['basicSettings.adbDebug']==1
assert old['basicSettings.rootMode'] is (not enabled)
sha=lambda raw:hashlib.sha256(raw).hexdigest()
other={str(p):sha(p.read_bytes()) for i in range(3) for p in [Path(f'E:/LDPlayer/LDPlayer14/vms/config/leidian{i}.config')]}
if not enabled:
    prior=json.loads((out/'root-enabled.json').read_bytes());assert prior['other_config_sha256']==other
new=dict(old);new['basicSettings.rootMode']=enabled
config.write_text(json.dumps(new,ensure_ascii=False,indent=4)+'\n',encoding='utf8')
assert json.loads(config.read_bytes())==new
assert all(sha(Path(p).read_bytes())==v for p,v in other.items())
r={'status':'PASS_ROOT_ENABLED' if enabled else 'PASS_ROOT_RESTORED_CONFIG','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'instance':3,'before_sha256':sha(raw),'after_sha256':sha(config.read_bytes()),'root_mode':enabled,'all_other_current_fields_preserved':True,'all_instances_stopped':True,'other_config_sha256':other,'rootless_guest_check':'PENDING' if not enabled else 'NOT_YET_RESTORED'}
(out/('root-enabled.json' if enabled else 'root-restored.json')).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:v for k,v in r.items() if k!='other_config_sha256'}))
