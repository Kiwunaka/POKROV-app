from pathlib import Path
import subprocess,hashlib,json,datetime,shlex,re,shutil
out=Path(__file__).parent;adb='C:/Users/kiwun/AppData/Local/Android/Sdk/platform-tools/adb.exe';serial='emulator-5560';pkg='space.pokrov.pokrov_android_shell';fixture='/data/local/tmp/r12c05jni6b20260912'
markers=[b'R12_CREDENTIAL_6b20260912',b'R12_CONFIG_6b20260912',b'https://r12-url-6b20260912.invalid/private',b'198.51.100.127',b'/r12-private-path-6b20260912',b'r12-person-6b20260912@example.invalid']
def run(*a,timeout=35):return subprocess.run([adb,'-s',serial,*a],timeout=timeout,capture_output=True)
def checked(*a):
 r=run(*a);assert r.returncode==0,(a[0],r.returncode);return r.stdout
assert shutil.disk_usage('E:/').free>40*2**30
baseline=json.loads((out/'baseline.json').read_text())
assert hashlib.sha256(checked('shell','cat','/proc/sys/kernel/random/boot_id').strip()).hexdigest()==baseline['boot_id_sha256']
path=checked('shell','pm','path',pkg).decode().strip().removeprefix('package:')
assert re.fullmatch(r'/data/app/[A-Za-z0-9_./=~+-]+/base.apk',path)
checksum=checked('shell','sha256sum',path).decode().split()[0]
assert checksum=='baa5202957c46e9ba92e3fff4c46418b60ff309311cfa015aef86da685ac0f52'
checked('shell','mkdir',fixture)
checked('push',str(out/'dex/classes.dex'),fixture+'/classes.dex')
checked('shell','chmod','444',fixture+'/classes.dex')
command=['env','CLASSPATH='+fixture+'/classes.dex','app_process',fixture,'CorePrivacyProbe',path,fixture]
r=run('shell',' '.join(shlex.quote(x) for x in command),timeout=60)
child=None
for line in r.stdout.splitlines():
 try:
  parsed=json.loads(line)
  if isinstance(parsed,dict) and 'check_config_invoked' in parsed:child=parsed
 except (ValueError,UnicodeDecodeError):pass
logs=b''
if child:logs=checked('logcat','-d','--pid='+str(child['pid']),'-v','threadtime')
streams={name:{'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'marker_present':[m in raw for m in markers]} for name,raw in [('stdout',r.stdout),('stderr',r.stderr),('child_logcat',logs)]}
result={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PASS_BOUNDED_ANDROID_JNI_LOG_PRIVACY' if r.returncode==0 and child and child['rejected'] and all(not any(x['marker_present']) for x in streams.values()) else 'FAILED','installed_apk_sha256':checksum,'client_source':'2aa57015783ceb3415e3be62bbf0a698729011c4','core_source':'6b271decead88b708e2fc03984b703b0a4e63ebd','exit_code':r.returncode,'fixture':'separate Android shell app_process, production APK PathClassLoader, six synthetic markers, debug false','dex_sha256':hashlib.sha256((out/'dex/classes.dex').read_bytes()).hexdigest(),'child':child,'streams':streams,'error_categories':[x for x in ['ClassNotFoundException','UnsatisfiedLinkError','NoSuchMethodException','InvocationTargetException','SecurityException'] if x.encode() in r.stderr],'raw_streams_exported':False,'subscription_bypassed':False,'network_request_made_by_fixture':False,'host_vpn_modified':False}
(out/'jni-privacy.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result));assert result['status']=='PASS_BOUNDED_ANDROID_JNI_LOG_PRIVACY'
