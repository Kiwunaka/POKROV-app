from pathlib import Path
import json,hashlib,subprocess,shutil,zipfile,re,os
out=Path('E:/r12-c05-maven-notices');root=Path('E:/r12client');old=Path('E:/r12-c05-flutter-native/android');sha=lambda b:hashlib.sha256(b).hexdigest();r=json.loads((out/'assembly.json').read_text());asset=root/r['asset']['path'];notice=asset.read_bytes();assert sha(notice)==r['asset']['sha256'];records=[]
for item in r['bodies']:assert sha(notice[item['body_offset']:item['body_offset']+item['bytes']])==item['sha256']
apks=list((root/'apps/android_shell/build/app/outputs/apk/direct/release').glob('*.apk'));assert len(apks)==4
for p in sorted(apks):
 dest=out/'android'/p.name;dest.parent.mkdir(exist_ok=True);assert not dest.exists();shutil.copy2(p,dest)
 with zipfile.ZipFile(dest) as z,zipfile.ZipFile(old/p.name) as previous:
  name='assets/flutter_assets/assets/licenses/maven-NOTICES.txt';assert z.read(name)==notice
  before={n:sha(previous.read(n)) for n in previous.namelist()};after={n:sha(z.read(n)) for n in z.namelist()};added=sorted(set(after)-set(before));removed=sorted(set(before)-set(after));changed=sorted(n for n in after if n in before and before[n]!=after[n]);assert added==[name] and not removed
  allowed={'assets/flutter_assets/AssetManifest.bin','assets/flutter_assets/AssetManifest.json'};assert set(changed)<=allowed,changed
  protected={n:v for n,v in after.items() if n.endswith(('.so','.dex','NOTICES.Z','native-go-NOTICES.txt'))};assert protected and all(before[n]==v for n,v in protected.items())
 cmd=['C:/Users/kiwun/AppData/Local/Android/Sdk/build-tools/34.0.0/apksigner.bat','verify','--print-certs',str(dest)];env=dict(os.environ);env['JAVA_HOME']='C:/Users/kiwun/tools/jdk/17.0.18';check=subprocess.run(cmd,capture_output=True,text=True,env=env);assert check.returncode==0 and 'CN=Android Debug' in check.stdout
 records.append({'file':str(dest),'bytes':dest.stat().st_size,'sha256':sha(dest.read_bytes()),'added':added,'changed':changed,'unchanged_entries':len(after)-len(added)-len(changed),'protected_entries':protected,'signing':{'command':cmd,'exit_code':check.returncode,'signer':'Android Debug','certificate_sha256':re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)',check.stdout).group(1)}})
for item in json.loads(Path('E:/r12-c05-go-notices/preexisting-generated.json').read_text()):assert sha((root/item['path']).read_bytes())==item['sha256']
result={'status':'PASS_LOCAL_ANDROID_NOTICE_PACKAGING','asset':r['asset'],'body_count':len(r['bodies']),'packages':records,'preexisting_registrants':'4 byte-identical','scope':'Internal Android Debug-signed Direct release-mode APKs with loopback API. No installed runtime/privacy, production signing or final candidate acceptance.'}
(out/'package-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'status':result['status'],'packages':len(records),'bodies':len(r['bodies']),'changes':[x['changed'] for x in records]}))
