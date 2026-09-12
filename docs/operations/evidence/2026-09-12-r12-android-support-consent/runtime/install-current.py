from pathlib import Path
import datetime,hashlib,json,subprocess
import ui
out=Path(__file__).parent
old='23fa86a9421930910e6d95d0fdff85f35c5df4e94f8749b83e3457052b66935d'
binding=json.loads((out/'apk-binding.json').read_bytes());artifact=binding['artifact'];apk=Path(artifact['path'])
boot=ui.run('shell','cat','/proc/sys/kernel/random/boot_id').strip();indexed=subprocess.check_output(['E:/LDPlayer/LDPlayer14/ldconsole.exe','adb','--index','3','--command','shell cat /proc/sys/kernel/random/boot_id'],timeout=35).strip();assert boot==indexed and len(boot)==36
path=ui.run('shell','pm','path',ui.pkg).decode().strip().removeprefix('package:');assert ui.run('shell','sha256sum',path).decode().split()[0]==old
retained=json.loads(Path('C:/r12-android-flavor-packages-20260912/failed-package-retention.json').read_bytes());assert any(x['sha256']==old for x in retained['artifacts'])
assert apk.stat().st_size==artifact['size'] and hashlib.file_digest(apk.open('rb'),'sha256').hexdigest()==artifact['sha256']
r=subprocess.run([ui.adb,'-s',ui.serial,'install','-r',str(apk)],capture_output=True,timeout=90)
assert r.returncode==0 and b'Success' in r.stdout,{'exit':r.returncode,'stdout_sha256':hashlib.sha256(r.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(r.stderr).hexdigest()}
path=ui.run('shell','pm','path',ui.pkg).decode().strip().removeprefix('package:');actual=ui.run('shell','sha256sum',path).decode().split()[0];assert actual==artifact['sha256']
value={'status':'PASS_SAME_SIGNER_IN_PLACE_UPGRADE','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':binding['source'],'core':binding['core'],'previous_apk_sha256':old,'installed_apk_sha256':actual,'installed_bytes':artifact['size'],'data_cleared':False,'previous_apk_retained_private_on_owned_de':True,'startup_and_support':'PENDING'}
(out/'installed-apk.json').write_text(json.dumps(value,indent=2)+'\n');print(json.dumps(value))
