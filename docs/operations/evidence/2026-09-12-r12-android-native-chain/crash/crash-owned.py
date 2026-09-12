from pathlib import Path
import json,subprocess,time,datetime,hashlib
import ui,network
out=Path(__file__).parent
before=network.state('before-crash');assert before['tun_interfaces'] and before['vpn_service_running']
pid=ui.run('shell','pidof',ui.pkg).decode().strip();assert pid.isdigit()
root=subprocess.run([ui.adb,'-s',ui.serial,'shell','su','-c','id'],capture_output=True);assert root.returncode==127
started=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=subprocess.run([ui.adb,'-s',ui.serial,'shell','am','crash','--user','current',pid],capture_output=True,timeout=30)
assert result.returncode==0,{'exit':result.returncode,'stderr_sha256':hashlib.sha256(result.stderr).hexdigest()}
samples=[];deadline=time.monotonic()+60
while time.monotonic()<deadline:
    current=subprocess.run([ui.adb,'-s',ui.serial,'shell','pidof',ui.pkg],capture_output=True,timeout=15)
    pids=current.stdout.decode().split();samples.append({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'old_pid_present':pid in pids,'current_pid_count':len(pids)})
    if pid not in pids:break
    time.sleep(1)
assert samples and not samples[-1]['old_pid_present']
logs=ui.run('logcat','-d','--pid='+pid)
r={'status':'PASS_CONTROLLED_OWN_PROCESS_CRASH','utc':started,'installed_apk_sha256':before['installed_apk_sha256'],'old_app_pid':int(pid),'command':'am crash --user current <verified own package PID>','command_exit':result.returncode,'old_pid_exited':True,'samples':samples,'available_logcat_bytes':len(logs),'available_logcat_sha256':hashlib.sha256(logs).hexdigest(),'fatal_exception_lines':logs.count(b'FATAL EXCEPTION'),'remote_service_exception_mentions':logs.count(b'RemoteServiceException'),'raw_logcat_exported':False,'rootless':True,'network_recovery':'PENDING','crash_bundle':'NOT_YET_PROVEN'}
(out/'crash.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:v for k,v in r.items() if k!='samples'}))
network.state('after-crash')
