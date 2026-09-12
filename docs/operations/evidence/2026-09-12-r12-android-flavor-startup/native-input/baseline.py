from pathlib import Path
import subprocess,json,hashlib,datetime,xml.etree.ElementTree as ET,shlex,base64
import ui
out=Path(__file__).parent;private='/data/user/0/'+ui.pkg;sha=lambda b:hashlib.sha256(b).hexdigest()
def root(cmd):
 r=subprocess.run([ui.adb,'-s',ui.serial,'exec-out','su -c '+shlex.quote(cmd)],capture_output=True,timeout=30)
 assert r.returncode==0,{'exit':r.returncode,'stderr_sha256':sha(r.stderr)}
 return r.stdout
def read(path):return base64.b64decode(root('base64 '+shlex.quote(path)))
if __name__=='__main__':
 boot=ui.run('shell','cat','/proc/sys/kernel/random/boot_id').strip();indexed=subprocess.check_output(['E:/LDPlayer/LDPlayer14/ldconsole.exe','adb','--index','3','--command','shell cat /proc/sys/kernel/random/boot_id'],timeout=35).strip();assert boot==indexed
 assert b'uid=0(root)' in root('id')
 path=ui.run('shell','pm','path',ui.pkg).decode().strip().removeprefix('package:');apk=ui.run('shell','sha256sum',path).decode().split()[0];assert apk=='23fa86a9421930910e6d95d0fdff85f35c5df4e94f8749b83e3457052b66935d'
 prefs=private+'/shared_prefs/pokrov_runtime_profile.xml';raw=read(prefs);tree=ET.fromstring(raw);values={n.get('name'):n.text if n.tag=='string' else n.get('value') for n in tree}
 config=values['config_path'];assert config.startswith(private+'/files/pokrov-runtime/working/configs/') or config.startswith('/data/data/'+ui.pkg+'/files/pokrov-runtime/working/configs/')
 content=read(config);assert sha((('1' if values['core_egress_probe_required']=='true' else '0')+'\n'+values['route_mode']+'\n').encode()+content)==values['config_digest']
 fields=root('stat -c "%u %g %a" '+shlex.quote(prefs)).decode().strip().split();assert len(fields)==3 and fields[0]==fields[1] and int(fields[0])>=10000
 files=root('find '+shlex.quote(private+'/files')+' -maxdepth 3 -type f').decode().splitlines()
 public_names=[]
 for name in files:
  base=name.rsplit('/',1)[-1]
  if any(x in base.lower() for x in ['event','exit','support','state','crash','log']):public_names.append({'relative_path':name.removeprefix(private+'/'),'sha256':sha(read(name))})
 r={'status':'PASS_ROOTED_INSTALLED_BASELINE','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'apk_sha256':apk,'root_preexisting_before_task':False,'root_enabled_only_in_qa_instance':True,'uid':int(fields[0]),'prefs_mode':fields[2],'profile_sha256':sha(content),'preferences_sha256':sha(raw),'route_mode':values['route_mode'],'quick_settings_eligible':values['quick_settings_eligible'],'schema_version':values['schema_version'],'config_path_sha256':sha(config.encode()),'safe_file_inventory':public_names,'profile_content_exported':False}
 (out/'baseline.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
