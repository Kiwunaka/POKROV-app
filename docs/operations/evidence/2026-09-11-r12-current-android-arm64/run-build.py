from pathlib import Path
import datetime,json,os,shutil,subprocess,time
out=Path('E:/r12-current-android-package-20260911'); root=Path('C:/r12-current-windows-source-20260911')
expected='90337b33180b1600f0d6c25029627d0e9dc5b217'
assert subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()==expected
assert subprocess.run(['git','-C',str(root),'diff','--quiet','HEAD','--']).returncode==0
sizes=lambda:{d:shutil.disk_usage(d+':/').free for d in ('C','E')}
before=sizes(); growth={'C':1.8,'E':0.15}; gib=1024**3
assert all(before[d]/gib-growth[d]>=40 for d in before),'Projected disk floor violated'
minimum=dict(before)
report={'source':expected,'before_bytes':before,'projected_growth_gib':growth,'minimum_required_free_gib':40,'stop_threshold_free_gib':40.25,'started_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
env=os.environ.copy();env.update({'JAVA_HOME':'C:/Users/kiwun/tools/jdk/17.0.18','GRADLE_USER_HOME':'E:/POKROV-workspace-cache/gradle-user-home','PUB_CACHE':'E:/CodexCaches/pub-cache','GRADLE_OPTS':'-Dorg.gradle.workers.max=2 -Dorg.gradle.daemon=false','ANDROID_SDK_ROOT':'C:/Users/kiwun/AppData/Local/Android/Sdk'})
env['PATH']='C:/Users/kiwun/tools/flutter/git-3.38.5/bin;'+env['JAVA_HOME']+'/bin;'+env['PATH']
pins=json.loads(Path('E:/r12-device-20260907/public-pins.json').read_bytes())
args=['pwsh','-NoProfile','-File',str(out/'build-arm64.ps1'),'-EmergencySigningKeyId',pins['key_id'],'-EmergencySigningPublicKey',pins['public_key_b64']]
with (out/'build.log').open('w',encoding='utf-8') as log:
 p=subprocess.Popen(args,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT)
 while p.poll() is None:
  current=sizes();minimum={d:min(minimum[d],current[d]) for d in current}
  if any(current[d]/gib<40.25 for d in current):
   report['stopped_by_disk_watchdog']=True
   subprocess.run(['taskkill','/PID',str(p.pid),'/T','/F'],capture_output=True)
   p.wait();break
  time.sleep(1)
 report.update(exit_code=p.returncode,after_bytes=sizes(),minimum_observed_free_bytes=minimum,finished_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
(out/'build-disk-and-exit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'exit_code':p.returncode,'min_free_gib':{d:round(minimum[d]/gib,3) for d in minimum}}),flush=True)
raise SystemExit(0 if p.returncode==0 else 1)
