from pathlib import Path
import ui,json,hashlib,subprocess,datetime
out=Path(__file__).parent;t=ui.tree();visible=ui.texts(t);assert any('Tab 4 of 4' in x['text'] for x in visible)
pid=ui.run('shell','pidof',ui.pkg).decode().strip();assert pid.isdigit();raw=ui.run('logcat','-d','--pid='+pid)
su=subprocess.run([ui.adb,'-s',ui.serial,'shell','su -c id'],capture_output=True,timeout=15);assert su.returncode==127
r={'status':'PASS_INSTALLED_FIXED_STARTUP','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'installed_apk_sha256':json.loads((out/'installed-apk.json').read_bytes())['installed_apk_sha256'],'ui':visible,'app_pid':int(pid),'available_app_logcat_bytes':len(raw),'available_app_logcat_sha256':hashlib.sha256(raw).hexdigest(),'unhandled_exception_count':raw.count(b'Unhandled Exception'),'fatal_exception_count':raw.count(b'FATAL EXCEPTION'),'su_exit_code':su.returncode,'root_disabled_guest_verified':True};assert r['unhandled_exception_count']==0 and r['fatal_exception_count']==0
(out/'startup-fixed.json').write_text(json.dumps(r,indent=2,ensure_ascii=False)+'\n',encoding='utf8');(out/'startup-fixed.png').write_bytes(ui.run('exec-out','screencap','-p'));print(json.dumps({k:v for k,v in r.items() if k!='ui'}))
