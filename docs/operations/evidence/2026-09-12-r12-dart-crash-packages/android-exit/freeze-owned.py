from pathlib import Path
import datetime, hashlib, json, subprocess, time
import network, observe, ui
out=Path(__file__).parent
before=network.state('before-freeze');assert before['tun_interfaces'] and before['vpn_service_running']
pid=ui.run('shell','pidof',ui.pkg).decode().strip();assert pid.isdigit()
assert ui.run('shell','cat','/proc/'+pid+'/cmdline').rstrip(b'\0').decode()==ui.pkg
marker_before=observe.read(observe.private+'/files/pokrov-observability/previous-exit.v1.json')
result={'status':'RUNNING','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_client':observe.source,'installed_apk_sha256':before['installed_apk_sha256'],'app_pid':int(pid),'rooted_lab':True,'method':'SIGSTOP/SIGCONT on verified own process; not an Android ANR injection','samples':[]}
stopped=False;started=time.monotonic()
try:
    observe.root('kill -STOP '+pid);stopped=True
    state=ui.run('shell','cat','/proc/'+pid+'/status').decode()
    state_line=next(line for line in state.splitlines() if line.startswith('State:'))
    assert 'T' in state_line
    result['observed_process_state']=state_line
    probe=subprocess.run([ui.adb,'-s',ui.serial,'shell','env','CLASSPATH='+network.fixture+'/classes.dex','app_process',network.fixture,'OwnedHttpsProbe','1'],capture_output=True,timeout=15)
    result['probe_exit']=probe.returncode
    if probe.returncode==0:result['probe']=json.loads(probe.stdout)
    else:result['probe_output_sha256']=hashlib.sha256(probe.stdout+probe.stderr).hexdigest()
    result['same_active_marker_while_stopped']=observe.read(observe.private+'/files/pokrov-observability/previous-exit.v1.json')==marker_before
finally:
    if stopped:
        observe.root('kill -CONT '+pid)
        result['resumed']=True
        result['freeze_seconds']=time.monotonic()-started
        result['same_process_after_resume']=ui.run('shell','pidof',ui.pkg).decode().strip()==pid
        result['status']='OBSERVED_BOUNDED_PROCESS_FREEZE_AND_RESUME'
        (out/'freeze.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
