from device import *
import shutil
before=json.loads((ROOT/'pre-install-home.json').read_bytes())
assert not before['vpn_service'] and not before['tun_interfaces']
assert min(shutil.disk_usage(x).free for x in ('C:/','E:/'))>40*1024**3+150*1024**2
audit=json.loads(Path('C:/r12-dart-crash-packages-20260912/android-package-audit.json').read_bytes())
assert audit['source_client']=='f7115c505c314a7322481997a46343b03dae1127'
artifact=next(x['artifact'] for x in audit['artifacts'] if x.get('abis')==['arm64-v8a'])
apk=Path(artifact['path']);assert hashlib.sha256(apk.read_bytes()).hexdigest()==artifact['sha256']
signing=json.loads(Path(str(apk)+'.signing.json').read_bytes())
remote=run('shell','pm','path',PACKAGE).removeprefix('package:')
assert run('shell','sha256sum',remote).split()[0]==before['apk_sha256']
rollback=ROOT/'android-before.apk';assert not rollback.exists()
subprocess.run([ADB,'-s',SERIAL,'pull',remote,str(rollback)],capture_output=True,check=True,timeout=100)
assert hashlib.sha256(rollback.read_bytes()).hexdigest()==before['apk_sha256']
signer='C:/Users/kiwun/AppData/Local/Android/Sdk/build-tools/36.1.0/apksigner.bat'
cert=subprocess.check_output([signer,'verify','--print-certs',str(rollback)],text=True,timeout=40)
assert signing['certificate_sha256'].lower() in cert.lower()
save('install-start',{'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'before_sha256':before['apk_sha256'],'after_expected':artifact['sha256'],'same_signer':True,'mode':'adb install -r','rollback_apk':rollback.name})
p=subprocess.run([ADB,'-s',SERIAL,'install','-r',str(apk)],capture_output=True,text=True,timeout=150)
(ROOT/'install.log').write_text(p.stdout+p.stderr,encoding='utf8')
assert p.returncode==0 and 'Success' in p.stdout
after=snapshot('installed',False)
checks={'installed_exact_apk':after['apk_sha256']==artifact['sha256'],'same_uid':before['package_fields']['userId']==after['package_fields']['userId'],'same_first_install_time':before['package_fields']['firstInstallTime']==after['package_fields']['firstInstallTime'],'same_android_settings':all(before[k]==after[k] for k in ('wifi_on','mobile_data','always_on','lockdown'))}
save('install-result',{'status':'PASS' if all(checks.values()) else 'FAIL','checks':checks,'client_source':audit['source_client'],'core_source':audit['source_core'],'signer_sha256':signing['certificate_sha256'],'app_data_clear_requested':False,'limits':['Same-version local replacement; not release-channel update.','Account and preferences need visible UI readback.']})
print(json.dumps(checks));assert all(checks.values())
