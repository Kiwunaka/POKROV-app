from pathlib import Path
import datetime,json,shutil,subprocess,time,psutil
out=Path(__file__).parent
source='8067520c7b9230ab0c66823fae9ae78791f1a838'
assert subprocess.check_output(['git','-C','E:/r12client','rev-parse','HEAD'],text=True).strip()==source
assert not [p for p in psutil.process_iter(['name']) if p.info['name'].lower() in ['java.exe','virtualboxvm.exe','vboxheadless.exe']]
floor=40*2**30
assert shutil.disk_usage('C:/').free>floor+256*2**20
assert shutil.disk_usage('E:/').free>floor+3*2**30
started=time.time()
result={'status':'RUNNING','source_client':source,'source_core':'6b271decead88b708e2fc03984b703b0a4e63ebd','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'floor_bytes':floor,'abort_margin_e':2**30,'abort_margin_c':256*2**20,'poll_seconds':0.05,'direct_apk_phase':'REUSED_EXACT_VERIFIED_BYTES','samples':[],'owned_java_cleanup':[]}
owned={}
last_record=0
minc=mine=2**63
with (out/'android-driver-store-only.log').open('wb') as log:
    process=subprocess.Popen(['pwsh','-NoLogo','-NoProfile','-File',str(out/'build-android-store-only-wrapper.ps1'),'-ExpectedSource',source],stdout=log,stderr=subprocess.STDOUT,creationflags=0x08000000|0x00004000)
    result['pid']=process.pid
    while True:
        freec=shutil.disk_usage('C:/').free;freee=shutil.disk_usage('E:/').free
        minc=min(minc,freec);mine=min(mine,freee)
        now=time.time()
        if now-last_record>=1:
            for p in psutil.process_iter(['pid','name','create_time']):
                if p.info['name'].lower()=='java.exe' and p.info['create_time']>=started:
                    try:
                        cmd=p.cmdline()
                        if p.exe().replace('\\','/').lower().startswith('c:/users/kiwun/tools/jdk/17.0.18/') and 'org.gradle.launcher.daemon.bootstrap.GradleDaemon' in cmd and '8.11.1' in cmd:
                            owned[p.pid]=p.info['create_time']
                    except (psutil.NoSuchProcess,psutil.AccessDenied): pass
            result['samples'].append({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'free_c':freec,'free_e':freee})
            result.update(min_free_c=minc,min_free_e=mine)
            (out/'android-build-progress-store-only.json').write_text(json.dumps(result,indent=2)+'\n')
            last_record=now
        if freec<floor+256*2**20 or freee<floor+2**30:
            subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            for pid,created in owned.items():
                try:
                    p=psutil.Process(pid)
                    if p.create_time()==created:
                        p.kill();p.wait(timeout=15)
                        result['owned_java_cleanup'].append({'pid':pid,'status':'STOPPED_OWNED_GRADLE_DAEMON'})
                except psutil.NoSuchProcess: pass
            result.update(status='STOPPED_STORAGE_GUARD',exit_code=process.wait(timeout=30));break
        code=process.poll()
        if code is not None:
            result.update(status='PASS' if code==0 else 'FAILED',exit_code=code);break
        time.sleep(0.05)
result.update(min_free_c=minc,min_free_e=mine)
(out/'android-build-progress-store-only.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='samples'}))
assert result['status']=='PASS'
