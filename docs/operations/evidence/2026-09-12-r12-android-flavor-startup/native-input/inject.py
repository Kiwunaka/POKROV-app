from pathlib import Path
import base64,datetime,json,shlex,subprocess,time,xml.etree.ElementTree as ET
import baseline as b
import ui
out=Path(__file__).parent
markers={'credential':'password=R12_ANDROID_CREDENTIAL_a9_20260912','authorization':'Authorization: Bearer R12_ANDROID_AUTH_a9_20260912','cookie':'Cookie: session=R12_ANDROID_COOKIE_a9_20260912','config':'config={private_key:R12_ANDROID_CONFIG_a9_20260912}','url':'https://example.invalid/R12_ANDROID_URL_a9_20260912?secret=synthetic','ipv4':'198.51.100.127','path':'/data/user/0/synthetic/R12_ANDROID_PATH_a9_20260912.conf','pii':'qa+R12_ANDROID_PII_a9_20260912@example.invalid','provider':'provider_payload=R12_ANDROID_PROVIDER_a9_20260912'}
def scan(raw):return {k:raw.count(v.encode()) for k,v in markers.items()}
def save(name,value):(out/name).write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
def write(path,raw):
 # Only bounded synthetic profile/preference bytes use the command line.
 assert len(raw)<4096
 b.root('printf %s '+shlex.quote(base64.b64encode(raw).decode())+' | base64 -d > '+shlex.quote(path));assert b.read(path)==raw
if __name__=='__main__':
 subprocess.run(['python',str(out/'baseline.py')],check=True,capture_output=True)
 ui.run('shell','am','force-stop',ui.pkg)
 baseline=json.loads((out/'baseline.json').read_bytes());prefs=b.private+'/shared_prefs/pokrov_runtime_profile.xml';original=b.read(prefs);tree=ET.fromstring(original)
 values={n.get('name'):n.text if n.tag=='string' else n.get('value') for n in tree};profile=values['config_path'];content=b.read(profile)
 assert b.sha(original)==baseline['preferences_sha256'] and b.sha(content)==baseline['profile_sha256']
 backup=b.private+'/files/r12-private-rollback-a9-20260912'
 b.root('mkdir -m 700 '+shlex.quote(backup))
 b.root('cp -p '+shlex.quote(profile)+' '+shlex.quote(backup+'/profile')+' && cp -p '+shlex.quote(prefs)+' '+shlex.quote(backup+'/preferences')+' && chown -R '+str(baseline['uid'])+':'+str(baseline['uid'])+' '+shlex.quote(backup)+' && chmod 600 '+shlex.quote(backup+'/profile')+' '+shlex.quote(backup+'/preferences'))
 assert b.read(backup+'/profile')==content and b.read(backup+'/preferences')==original
 save('rollback-prepared.json',{'status':'PASS','profile_sha256':b.sha(content),'preferences_sha256':b.sha(original),'backup_guest_private_only':True,'backup_uid':baseline['uid'],'backup_directory_mode':'700','backup_files_mode':'600','live_profile_exported':False})
 payload=json.dumps({'outbounds':[{'type':' | '.join(markers.values()),'tag':'proxy'}],'route':{'final':'proxy'}},separators=(',',':')).encode()
 digest=b.sha(('1\n'+values['route_mode']+'\n').encode()+payload);next(n for n in tree if n.get('name')=='config_digest').text=digest;altered=ET.tostring(tree,encoding='utf-8',xml_declaration=True)
 write(profile,payload);write(prefs,altered)
 start=datetime.datetime.now(datetime.timezone.utc).isoformat();dispatch=b.root('am start-foreground-service -n '+ui.pkg+'/.PokrovRuntimeVpnService')
 assert b'Error' not in dispatch and b'Starting service' in dispatch
 time.sleep(3)
 pid=ui.run('shell','pidof',ui.pkg).decode().strip();assert pid.isdigit();logs=ui.run('logcat','-d','--pid='+pid)
 raw=b.read(b.private+'/no_backup/observability/android-operational-v1.jsonl');records=[json.loads(x) for x in raw.splitlines()]
 fresh=[x for x in records if x['occurred_at_utc']>=start[:23]+'Z']
 assert any(x['event']=='vpn_service' and x['outcome']=='session_started' for x in fresh) and any(x['event']=='vpn_service' and x['outcome']=='failed' for x in fresh)
 r={'status':'PASS_BOUNDED_COMBINED_NATIVE_FAILURE','utc':start,'apk_sha256':baseline['apk_sha256'],'marker_values_synthetic':markers,'payload_sha256':b.sha(payload),'profile_digest':digest,'native_journal_records':fresh,'native_journal_marker_counts':scan(raw),'logcat_marker_counts':scan(logs),'logcat_bytes':len(logs),'logcat_sha256':b.sha(logs),'app_pid':int(pid),'rooted_qa_fixture':True,'private_rollback':'PREPARED_NOT_YET_RESTORED','gui_and_bundle':'PENDING'}
 assert not any(scan(logs).values()) and not any(scan(raw).values())
 save('native-input.json',r)
 # Preserve this process while opening the real app to inspect its native state.
 ui.run('shell','am','start','-n',ui.pkg+'/.MainActivity')
 print(json.dumps({'status':r['status'],'marker_categories':len(markers),'app_pid':int(pid),'rollback_required':True}))
