from pathlib import Path
import json,subprocess
r=Path(__file__).parent
remote='''from pathlib import Path
import hashlib,json,re,subprocess,time
unit='pokrov-de-secondary-ip.service';p=Path('/etc/systemd/system')/unit;raw=p.read_text()
assert hashlib.sha256(p.read_bytes()).hexdigest()=='6a4b81507e0b4228be124b1edb0a7572c80f58537798232218d5889b0f0aa054'
redacted=re.sub(r'(?<![0-9])(?:[0-9]{1,3}\\.){3}[0-9]{1,3}(?![0-9])',lambda m:'IP_SHA256_'+hashlib.sha256(m[0].encode()).hexdigest(),raw)
assert not re.search(r'password|credential|token|private.key|https?://',redacted,re.I),'unexpected sensitive unit content'
args=['systemctl','show',unit]
for key in ['ActiveState','SubState','Result','MainPID','ExecMainCode','ExecMainStatus','ExecMainStartTimestamp','ExecMainExitTimestamp','ActiveEnterTimestamp','UnitFileState']:args+=['-p',key]
state=subprocess.run(args,capture_output=True,text=True,timeout=10);assert state.returncode==0
j=subprocess.run(['journalctl','-u',unit,'-n','30','--no-pager','-o','json'],capture_output=True,text=True,timeout=10);assert j.returncode==0
events=[]
for line in j.stdout.splitlines():
 v=json.loads(line);m=v.get('MESSAGE','');events.append({'epoch':int(v['__REALTIME_TIMESTAMP'])/1000000,'priority':v.get('PRIORITY'),'kind':'file_exists' if 'File exists' in m else 'device_missing' if 'Cannot find device' in m else 'failed' if 'Failed' in m or 'failed' in m else 'finished' if 'Finished' in m else 'starting' if 'Starting' in m else 'other','unit_result':v.get('UNIT_RESULT'),'exit_code':v.get('EXIT_CODE'),'exit_status':v.get('EXIT_STATUS')})
print(json.dumps({'captured_epoch':time.time(),'origin':'DE secondary-address service read-only','unit':unit,'unit_file_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'redacted_unit':redacted,'state':dict(x.split('=',1) for x in state.stdout.splitlines()),'journal_events':events,'production_mutation':False}))
'''
p=subprocess.run(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-de','sudo -n python3 -'],input=remote,capture_output=True,text=True,timeout=30);assert p.returncode==0,'secondary unit inspection failed'
v=json.loads(p.stdout);out=r/'candidate8-de-secondary-unit-redacted-20260912.json';assert not out.exists();out.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8');print(json.dumps(v))
