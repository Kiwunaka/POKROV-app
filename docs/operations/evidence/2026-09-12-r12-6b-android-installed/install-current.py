from pathlib import Path
import subprocess,hashlib,json,datetime,time,re
out=Path(__file__).parent;adb='C:/Users/kiwun/AppData/Local/Android/Sdk/platform-tools/adb.exe';serial='emulator-5560';pkg='space.pokrov.pokrov_android_shell'
def run(*a):
    p=subprocess.run([adb,'-s',serial,*a],timeout=60,capture_output=True);assert p.returncode==0,{'command':a[0],'exit':p.returncode,'stderr_sha256':hashlib.sha256(p.stderr).hexdigest()};return p.stdout
boot=run('shell','cat','/proc/sys/kernel/random/boot_id').strip()
indexed=subprocess.check_output(['E:/LDPlayer/LDPlayer14/ldconsole.exe','adb','--index','3','--command','shell cat /proc/sys/kernel/random/boot_id'],timeout=35).strip();assert boot==indexed and len(boot)==36
path=run('shell','pm','path',pkg).decode().strip().removeprefix('package:');assert re.fullmatch(r'/data/app/[A-Za-z0-9_./=~+-]+/base.apk',path)
old=run('shell','sha256sum',path).decode().split()[0];assert old=='9ffe8e83cfab393ef765acc0631579d236a9363525f3c71bd5e5d54660666fee'
apk=Path('E:/r12client/apps/android_shell/build/app/outputs/flutter-apk/app-x86_64-direct-release.apk')
with apk.open('rb') as f:sha=hashlib.file_digest(f,'sha256').hexdigest()
assert sha=='baa5202957c46e9ba92e3fff4c46418b60ff309311cfa015aef86da685ac0f52'
run('pull',path,str(out/'previous-installed-base.apk'))
with (out/'previous-installed-base.apk').open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==old
before={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'serial':serial,'instance_index':3,'indexed_boot_identity_matches':True,'boot_id_sha256':hashlib.sha256(boot).hexdigest(),'previous_apk_sha256':old,'api':run('shell','getprop','ro.build.version.sdk').decode().strip(),'abis':run('shell','getprop','ro.product.cpu.abilist').decode().strip().split(',')}
(out/'baseline.json').write_text(json.dumps(before,indent=2)+'\n')
result=run('install','-r',str(apk));assert result.strip().endswith(b'Success')
path=run('shell','pm','path',pkg).decode().strip().removeprefix('package:');assert run('shell','sha256sum',path).decode().split()[0]==sha
report={'status':'PASS_EXACT_SAME_SIGNER_ANDROID_UPGRADE','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'installed_apk_sha256':sha,'previous_apk_sha256':old,'previous_apk_retained':True,'client_source':'2aa57015783ceb3415e3be62bbf0a698729011c4','core_source':'6b271decead88b708e2fc03984b703b0a4e63ebd','install_result':result.decode().strip(),'app_data_clear':False,'host_vpn_settings_changed':False}
(out/'install.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
run('shell','am','start','-n',pkg+'/.MainActivity')
