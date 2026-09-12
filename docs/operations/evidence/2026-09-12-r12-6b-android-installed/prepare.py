from pathlib import Path
import hashlib,json,subprocess,os
out=Path(__file__).parent;prior=Path('C:/r12-c05-ldplayer-20260912')
changes={'2662':'6b20260912','198.51.100.126':'198.51.100.127','9ffe8e83cfab393ef765acc0631579d236a9363525f3c71bd5e5d54660666fee':'baa5202957c46e9ba92e3fff4c46418b60ff309311cfa015aef86da685ac0f52','212bd2f30c9f91d80fd3a6c08fb5557be8457f1c':'2aa57015783ceb3415e3be62bbf0a698729011c4','2662f76a3303a0518bb07fbbdc449c066de2f95b':'6b271decead88b708e2fc03984b703b0a4e63ebd'}
for name in ['CorePrivacyProbe.java','jni-privacy.py','startup-privacy.py']:
    text=(prior/name).read_text()
    for old,new in sorted(changes.items(),key=lambda p:-len(p[0])):text=text.replace(old,new)
    (out/name).write_text(text)
(out/'classes').mkdir();(out/'dex').mkdir()
env=os.environ.copy();env['JAVA_HOME']='C:/Users/kiwun/tools/jdk/17.0.18';env['PATH']=env['JAVA_HOME']+'/bin;'+env['PATH']
commands=[[env['JAVA_HOME']+'/bin/javac.exe','--release','8','-d',str(out/'classes'),str(out/'CorePrivacyProbe.java')],['C:/Users/kiwun/AppData/Local/Android/Sdk/build-tools/36.1.0/d8.bat','--min-api','26','--output',str(out/'dex'),str(out/'classes/CorePrivacyProbe.class')]]
for i,cmd in enumerate(commands):
    p=subprocess.run(cmd,env=env,capture_output=True);(out/f'compile-{i}.log').write_bytes(p.stdout+p.stderr);assert p.returncode==0
report={'status':'PASS_CURRENT_SYNTHETIC_JNI_FIXTURE_COMPILED','dex_sha256':hashlib.sha256((out/'dex/classes.dex').read_bytes()).hexdigest(),'source_sha256':hashlib.sha256((out/'CorePrivacyProbe.java').read_bytes()).hexdigest(),'commands':commands,'client_source':'2aa57015783ceb3415e3be62bbf0a698729011c4','core_source':'6b271decead88b708e2fc03984b703b0a4e63ebd'}
(out/'preparation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'status':report['status'],'dex_bytes':(out/'dex/classes.dex').stat().st_size}))
