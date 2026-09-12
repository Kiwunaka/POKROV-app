from pathlib import Path
import json,time,datetime,xml.etree.ElementTree as ET,shlex,base64,subprocess
import baseline as b
import ui
out=Path(__file__).parent
markers={
 'token':'token=R12_ANDROID_TOKEN_6b_20260912',
 'authorization':'Authorization: Bearer R12_ANDROID_AUTH_6b_20260912',
 'cookie':'Cookie: session=R12_ANDROID_COOKIE_6b_20260912',
 'url':'https://example.invalid/R12_ANDROID_URL_6b_20260912?secret=synthetic',
 'ipv4':'198.51.100.127',
 'provider':'provider_payload=R12_ANDROID_PROVIDER_6b_20260912',
}
def save(name,value):
 (out/name).write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
def scan(raw):return {k:raw.count(v.encode()) for k,v in markers.items()}
def write_existing(path,content):
 b.root('printf %s '+shlex.quote(base64.b64encode(content).decode())+' | base64 -d > '+shlex.quote(path))
 assert b.read(path)==content
def force_stop():ui.run('shell','am','force-stop',ui.pkg)
def journal():
 names=b.root('find '+shlex.quote(b.private+'/no_backup/observability')+' -maxdepth 1 -type f').decode().splitlines()
 return {p:b.read(p) for p in names}
if __name__=='__main__':
 subprocess.run(['python',str(out/'baseline.py')],check=True,capture_output=True)
 force_stop()
 prefs=b.private+'/shared_prefs/pokrov_runtime_profile.xml'
 original=b.read(prefs);tree=ET.fromstring(original)
 values={n.get('name'):n.text if n.tag=='string' else n.get('value') for n in tree}
 profile=values['config_path'];content=b.read(profile)
 baseline=json.loads((out/'baseline.json').read_bytes())
 assert b.sha(original)==baseline['preferences_sha256'] and b.sha(content)==baseline['profile_sha256']
 backup=b.private+'/files/r12-private-rollback-6b-20260912'
 b.root('mkdir -m 700 '+shlex.quote(backup))
 b.root('cp -p '+shlex.quote(profile)+' '+shlex.quote(backup+'/profile')+' && cp -p '+shlex.quote(prefs)+' '+shlex.quote(backup+'/preferences')+' && chown -R '+str(baseline['uid'])+':'+str(baseline['uid'])+' '+shlex.quote(backup)+' && chmod 600 '+shlex.quote(backup+'/profile')+' '+shlex.quote(backup+'/preferences'))
 assert b.read(backup+'/profile')==content and b.read(backup+'/preferences')==original
 save('rollback-prepared.json',{'status':'PASS','profile_sha256':b.sha(content),'preferences_sha256':b.sha(original),'backup_guest_private_only':True,'backup_uid':baseline['uid'],'backup_directory_mode':'700','backup_files_mode':'600','live_profile_exported':False})
 results=[]
 try:
  for category,marker in markers.items():
   force_stop()
   before=journal()
   payload=json.dumps({'outbounds':[{'type':marker,'tag':'proxy'}],'route':{'final':'proxy'}},separators=(',',':')).encode()
   tree=ET.fromstring(original)
   digest=b.sha(('1\n'+values['route_mode']+'\n').encode()+payload)
   next(n for n in tree if n.get('name')=='config_digest').text=digest
   altered=ET.tostring(tree,encoding='utf-8',xml_declaration=True)
   write_existing(profile,payload);write_existing(prefs,altered)
   started=datetime.datetime.now(datetime.timezone.utc).isoformat()
   dispatch=b.root('am start-foreground-service -n '+ui.pkg+'/.PokrovRuntimeVpnService')
   assert b'Error' not in dispatch and b'Starting service' in dispatch,{'dispatch_sha256':b.sha(dispatch)}
   time.sleep(3)
   pid=ui.run('shell','pidof',ui.pkg).decode().strip();assert pid.isdigit()
   logs=ui.run('logcat','-d','--pid='+pid)
   after=journal();fresh=[]
   for path,raw in after.items():
    old=before.get(path,b'');delta=raw[len(old):] if raw.startswith(old) else raw
    fresh.extend(json.loads(x) for x in delta.splitlines() if x)
   failures=[x for x in fresh if x.get('event')=='vpn_service' and x.get('outcome')=='failed']
   sessions=[x for x in fresh if x.get('event')=='vpn_service' and x.get('outcome')=='session_started']
   tun=ui.run('shell','ip','link','show').decode()
   entry={'category':category,'utc':started,'payload_sha256':b.sha(payload),'profile_digest':digest,'dispatch_success':True,'app_pid':int(pid),'session_started':bool(sessions),'failed_recorded':bool(failures),'tun_absent':'tun0' not in tun,'logcat_bytes':len(logs),'logcat_sha256':b.sha(logs),'logcat_markers':scan(logs),'native_journal_markers':scan(b'\n'.join(after.values())),'native_journal_new_records':fresh,'fatal_exception':'FATAL EXCEPTION' in logs.decode(errors='replace')}
   results.append(entry);save('native-canaries.json',{'status':'RUNNING','cases':results,'marker_values_synthetic':markers,'actual_installed_apk':baseline['apk_sha256'],'rooted_qa_fixture':True})
   assert sessions and failures and entry['tun_absent'] and not any(entry['logcat_markers'].values()) and not any(entry['native_journal_markers'].values()) and not entry['fatal_exception'],{'case':category,'status':'FAILED_EXPECTATION'}
  # Keep the final app process alive so support UI can consume native in-memory events.
  save('native-canaries.json',{'status':'PASS_BOUNDED_NATIVE_START_FAILURE_PRIVACY','cases':results,'marker_values_synthetic':markers,'actual_installed_apk':baseline['apk_sha256'],'rooted_qa_fixture':True,'logcat_scope':'available buffer for each observed app PID','jni_return_exception_not_claimed_redacted':True,'support_bundle_check':'PENDING'})
 finally:
  # Force-stop avoids cached SharedPreferences racing with exact rollback.
  force_stop();write_existing(profile,content);write_existing(prefs,original)
  save('profile-restored.json',{'status':'PASS_BYTE_EXACT_PRIVATE_ROLLBACK','profile_sha256':b.sha(b.read(profile)),'preferences_sha256':b.sha(b.read(prefs)),'backup_retained_guest_private':True,'app_force_stopped':True,'in_memory_core_events_lost_by_restart':True})
 print(json.dumps({'completed_cases':len(results),'restored':True}))
