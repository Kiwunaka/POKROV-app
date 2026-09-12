from pathlib import Path
import base64, datetime, hashlib, json, re, shlex, subprocess, sys
import ui
out=Path(__file__).parent
source='f7115c505c314a7322481997a46343b03dae1127'
private='/data/user/0/'+ui.pkg
sha=lambda b:hashlib.sha256(b).hexdigest()
def root(cmd):
    r=subprocess.run([ui.adb,'-s',ui.serial,'exec-out','su -c '+shlex.quote(cmd)],capture_output=True,timeout=30)
    assert r.returncode==0, {'exit':r.returncode,'stderr_sha256':sha(r.stderr)}
    return r.stdout
def read(path):return base64.b64decode(root('base64 '+shlex.quote(path)))
def installed():
    boot=ui.run('shell','cat','/proc/sys/kernel/random/boot_id').strip()
    indexed=subprocess.check_output(['E:/LDPlayer/LDPlayer14/ldconsole.exe','adb','--index','3','--command','shell cat /proc/sys/kernel/random/boot_id'],timeout=35).strip()
    assert len(boot)==36 and boot==indexed
    p=ui.run('shell','pm','path',ui.pkg).decode().strip().removeprefix('package:')
    return ui.run('shell','sha256sum',p).decode().split()[0]
def snapshot(label):
    assert re.fullmatch('[a-z-]+',label)
    assert installed()=='cd9b28f6f01e6d37aa8bb8436d6c8601f23da73eb23fddb5de923d82e74418f8'
    assert b'uid=0(root)' in root('id')
    directory=private+'/files/pokrov-observability/'
    raw=read(directory+'previous-exit.v1.json');marker=json.loads(raw)
    assert set(marker)=={'schema_version','state','run_id','occurred_at_utc','error_code','crash_signature','breadcrumbs'}
    assert marker['schema_version']==1 and marker['state'] in ['active','clean','crash']
    assert marker['error_code'] is None or re.fullmatch(r'CRASH-00[123]',marker['error_code'])
    assert len(marker['breadcrumbs'])<=32
    rows=[];files=[]
    for name in ['operational-events.v1.0.jsonl','operational-events.v1.1.jsonl']:
        exists=root('if test -f '+shlex.quote(directory+name)+'; then printf present; fi')
        if exists!=b'present':continue
        data=read(directory+name);assert len(data)<8*2**20
        files.append({'name':name,'bytes':len(data),'sha256':sha(data)})
        for line in data.splitlines():
            event=json.loads(line)
            if event['build']['git_revision']!=source:continue
            name=event['name'];code=event['error']['code'] if event.get('error') else None
            assert re.fullmatch(r'[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*){2,5}',name)
            assert code is None or re.fullmatch(r'[A-Z]+(?:-[A-Z]+)*-\d{3}',code)
            rows.append({'event_id_sha256':sha(event['event_id'].encode()),'run_id_sha256':sha((event['correlation']['run_id'] or '').encode()),'name':name,'error_code':code,'sequence':event['correlation']['sequence'],'occurred_at_utc':event['occurred_at_utc'],'source_client':event['build']['git_revision'],'build_number':event['build']['build_number']})
    pid=subprocess.run([ui.adb,'-s',ui.serial,'shell','pidof',ui.pkg],capture_output=True,timeout=10).stdout.decode().strip()
    report={'status':'OBSERVED_EXACT_CURRENT_MARKER_AND_JOURNAL','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_client':source,'app_pid':int(pid) if pid else None,'marker':{'state':marker['state'],'sha256':sha(raw),'bytes':len(raw),'run_id_sha256':sha(marker['run_id'].encode()),'occurred_at_utc':marker['occurred_at_utc'],'error_code':marker['error_code'],'breadcrumb_count':len(marker['breadcrumbs'])},'journal_files':files,'current_source_events':rows,'raw_private_content_exported':False,'rooted_lab':True}
    (out/(label+'-observability.json')).write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'label':label,'state':marker['state'],'marker_breadcrumbs':len(marker['breadcrumbs']),'journal_current_source_events':len(rows),'app_pid':report['app_pid']}))
    return report
if __name__=='__main__':snapshot(sys.argv[1])
