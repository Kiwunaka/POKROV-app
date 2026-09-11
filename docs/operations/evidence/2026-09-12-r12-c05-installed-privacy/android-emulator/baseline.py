from pathlib import Path
import subprocess,hashlib,json,datetime
out=Path('C:/r12-c05-ldplayer-20260912');adb='C:/Users/kiwun/AppData/Local/Android/Sdk/platform-tools/adb.exe';serial='emulator-5560';pkg='space.pokrov.pokrov_android_shell'
def run(*a):return subprocess.check_output([adb,'-s',serial,*a],timeout=35)
boot=run('shell','cat','/proc/sys/kernel/random/boot_id').strip()
indexed=subprocess.check_output(['E:/LDPlayer/LDPlayer14/ldconsole.exe','adb','--index','3','--command','shell cat /proc/sys/kernel/random/boot_id'],timeout=35).strip()
assert boot==indexed and len(boot)==36
paths=run('shell','pm','path',pkg).decode().strip().splitlines()
assert len(paths)==1 and paths[0].startswith('package:/data/app/') and paths[0].endswith('/base.apk')
path=paths[0][8:];checksum=run('shell','sha256sum',path).decode().split()[0]
r={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'emulator':True,'serial':serial,'instance_index':3,'indexed_boot_identity_matches':True,'boot_id_sha256':hashlib.sha256(boot).hexdigest(),'package':pkg,'api':run('shell','getprop','ro.build.version.sdk').decode().strip(),'abis':run('shell','getprop','ro.product.cpu.abilist').decode().strip().split(','),'previous_apk_sha256':checksum,'root_changed':False,'network_settings_changed':False,'identity_harness_note':'LDPlayer spoofs physical properties; qemu property was not assumed. Exact indexed console and SDK ADB boot identities match.'}
run('pull',path,str(out/'previous-installed-base.apk'))
with (out/'previous-installed-base.apk').open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==checksum
(out/'baseline.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r))
run('shell','am','start','-n',pkg+'/.MainActivity')
