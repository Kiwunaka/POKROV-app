from pathlib import Path
import json,hashlib,subprocess,re,shlex
import ui
out=Path(__file__).parent
t=ui.tree();fields=[n for n in t.iter('node') if n.get('class')=='android.widget.EditText' and n.get('enabled')=='true'];assert len(fields)==1
v=list(map(int,re.findall(r'\d+',fields[0].get('bounds'))));ui.run('shell','input','tap',str((v[0]+v[2])//2),str((v[1]+v[3])//2))
remote='/root/portal-r12-evidence/psm-runtime-20260910/android-policy-private-20260912.json'
code="import pathlib,json; p=pathlib.Path("+repr(remote)+"); assert p.stat().st_mode&0o777==0o600; print(json.loads(p.read_bytes())['activation_code'])"
r=subprocess.run(['ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-brain','/root/portal_bot/venv/bin/python -c '+shlex.quote(code)],capture_output=True,timeout=20)
assert r.returncode==0,{'exit':r.returncode,'stderr_sha256':hashlib.sha256(r.stderr).hexdigest()}
activation=r.stdout.decode().strip();assert re.fullmatch(r'PSM1-[A-Za-z0-9._-]+',activation)
try:r=subprocess.run([ui.adb,'-s',ui.serial,'shell','input','text',activation],capture_output=True,timeout=35)
except subprocess.TimeoutExpired:raise RuntimeError('Android input timeout; code omitted') from None
assert r.returncode==0,{'exit':r.returncode,'stderr_sha256':hashlib.sha256(r.stderr).hexdigest()}
result={'status':'CODE_ENTERED_IN_OBSERVED_FIELD','characters':len(activation),'code_sha256':hashlib.sha256(activation.encode()).hexdigest(),'raw_code_written_to_host_file':False,'raw_code_printed':False,'consent_not_yet_clicked':True}
(out/'code-entry.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
