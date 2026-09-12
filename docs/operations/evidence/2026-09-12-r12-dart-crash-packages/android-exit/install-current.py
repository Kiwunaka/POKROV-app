from pathlib import Path
import datetime, hashlib, json, re, shlex, subprocess
import observe, ui
out=Path(__file__).parent
proof=json.loads(Path('C:/r12-dart-crash-packages-20260912/direct-apks-verified.json').read_bytes())
apk=next(r for r in proof['artifacts'] if r['abi']=='x86_64')
assert hashlib.sha256(Path(apk['path']).read_bytes()).hexdigest()==apk['sha256']
before_apk=observe.installed();assert before_apk=='8dc6c2e6671b7ea3d2331c1ec31c5a788458fd10de9dd9a9693abfcd8eab62ad'
assert b'uid=0(root)' in observe.root('id')
ui.run('shell','am','force-stop',ui.pkg)
def preferences():
    names=observe.root('find '+shlex.quote(observe.private+'/shared_prefs')+' -maxdepth 1 -type f').decode().splitlines()
    assert names and len(names)<30
    return {observe.sha(name.encode()):observe.sha(observe.read(name)) for name in names}
before=preferences();uid=observe.root('stat -c %u '+shlex.quote(observe.private)).decode().strip()
assert uid.isdigit() and int(uid)>=10000
r=subprocess.run([ui.adb,'-s',ui.serial,'install','-r',apk['path']],capture_output=True,timeout=120)
assert r.returncode==0 and b'Success' in r.stdout,{'exit':r.returncode,'output_sha256':observe.sha(r.stdout+r.stderr)}
assert observe.installed()==apk['sha256']
after=preferences();assert before==after
assert observe.root('stat -c %u '+shlex.quote(observe.private)).decode().strip()==uid
receipt={'status':'PASS_SAME_SIGNER_CURRENT_X64_UPDATE','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_client':proof['source_client'],'source_core':proof['source_core'],'before_apk_sha256':before_apk,'after_apk_sha256':apk['sha256'],'local_certificate_sha256':apk['certificate_sha256'],'app_uid':int(uid),'uid_preserved':True,'shared_preferences_files':len(before),'preferences_unchanged':True,'private_preference_name_and_content_hashes':before,'raw_private_content_exported':False,'rooted_lab':True,'physical_arm64_proof':False}
(out/'installed.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({k:v for k,v in receipt.items() if k!='private_preference_name_and_content_hashes'}))
