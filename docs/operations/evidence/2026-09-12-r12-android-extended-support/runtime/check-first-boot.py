from pathlib import Path
import subprocess,json,datetime
out=Path('C:/r12-psm-consent-installed-20260912');adb='C:/Users/kiwun/AppData/Local/Android/Sdk/platform-tools/adb.exe';r=subprocess.run([adb,'-s','emulator-5560','shell','getprop','sys.boot_completed'],capture_output=True,timeout=15)
if r.returncode==0 and r.stdout.strip()==b'1':print('BOOT_READY')
else:
 progress=json.loads((out/'ldplayer-progress.json').read_bytes());assert progress['samples'][-1]['seconds']>240
 record={'status':'BLOCKED_BY_FIXTURE_ADB_OFFLINE','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'observed_seconds':progress['samples'][-1]['seconds'],'root_mode':False,'adb_debug':1,'scoped_reconnect_attempted':True,'new_apk_installed':False,'new_psm_issued':False};(out/'boot-observation.json').write_text(json.dumps(record,indent=2)+'\n');subprocess.run(['E:/LDPlayer/LDPlayer14/ldconsole.exe','quit','--index','3'],check=True,capture_output=True);print(json.dumps(record))
