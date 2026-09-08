from pathlib import Path
import collections,hashlib,json,re,subprocess,zipfile
root=Path('E:/r12-integrated-acceptance-20260908/android-access-denial')
aapt='C:/Users/kiwun/AppData/Local/Android/Sdk/build-tools/36.1.0/aapt.exe'
signer='C:/Users/kiwun/AppData/Local/Android/Sdk/build-tools/36.1.0/apksigner.bat'
expected_signer='0a0602a7df5d96a0b427909d004f3ddf26def86587634bf16694da8d654b2500'
repo=Path('E:/r12-access-denial-build-20260908')
with zipfile.ZipFile(repo/'apps/android_shell/android/app/libs/pokrov-core.aar') as z:
 core={x.split('/')[1]:hashlib.sha256(z.read(x)).hexdigest() for x in z.namelist() if x.startswith('jni/') and x.endswith('/libpokrov-core.so')}
artifacts=[]
for abi in ['universal','arm64-v8a','armeabi-v7a','x86_64']:
 p=root/f'pokrov-r12-{abi}.apk'
 signature=subprocess.run([signer,'verify','--verbose','--print-certs',str(p)],capture_output=True,text=True,check=True).stdout
 assert expected_signer in signature.lower() and 'Android Debug' not in signature
 badging=subprocess.run([aapt,'dump','badging',str(p)],capture_output=True,text=True,check=True).stdout
 package=re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'",badging,re.M)
 assert package and package.groups()==('space.pokrov.pokrov_android_shell','4053','1.2.0')
 assert not re.search(r'^application-debuggable',badging,re.M)
 with zipfile.ZipFile(p) as z:
  native={x:hashlib.sha256(z.read(x)).hexdigest() for x in z.namelist() if x.startswith('lib/') and x.endswith('.so')}
  actual=sorted({x.split('/')[1] for x in native})
  expected=sorted(['arm64-v8a','armeabi-v7a','x86_64'] if abi=='universal' else [abi])
  assert actual==expected
  for arch in expected:
   assert set(x.split('/')[-1] for x in native if x.split('/')[1]==arch)=={'libapp.so','libflutter.so','libpokrov-core.so'}
   assert native[f'lib/{arch}/libpokrov-core.so']==core[arch]
  categories=collections.Counter()
  for entry in z.infolist():
   name=entry.filename
   category=('core' if name.endswith('/libpokrov-core.so') else 'flutter' if name.endswith('/libflutter.so') else 'dart_aot' if name.endswith('/libapp.so') else 'notices' if 'notice' in name.lower() or name.endswith('/OFL.txt') else 'fonts' if name.endswith(('.ttf','.otf')) else 'assets' if name.startswith('assets/') else 'dex' if name.endswith('.dex') else 'android_resources')
   categories[category]+=entry.compress_size
  categories['zip_signing_alignment_overhead']=p.stat().st_size-sum(categories.values())
  notices={x:hashlib.sha256(z.read(x)).hexdigest() for x in z.namelist() if 'notice' in x.lower() or x.endswith('/OFL.txt')}
  assert notices and not any(x.endswith(('DebugProbesKt.bin','.exe','.dll','.pdb','.log')) for x in z.namelist())
 artifacts.append({'abi':abi,'path':p.as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size,'package':package.group(1),'version_code':4053,'version_name':'1.2.0','min_sdk':int(re.search(r"^sdkVersion:'(\d+)'",badging,re.M).group(1)),'target_sdk':int(re.search(r"^targetSdkVersion:'(\d+)'",badging,re.M).group(1)),'certificate_sha256':expected_signer,'debuggable':False,'native':native,'compressed_size_breakdown':dict(categories),'notices':notices})
universal=artifacts[0]
for artifact in artifacts[1:]:
 assert all(universal['native'][n]==h for n,h in artifact['native'].items())
 assert artifact['notices']==universal['notices']
receipt={'schema_version':1,'client_source':subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip(),'core_source':'02a091cb0e369192a5ad0909b56ccba8aa1dce17','api_base_url':'https://app.pokrov.space','scope':'local integrated ABI package audit; physical-device acceptance tracked separately; not published candidate','artifacts':artifacts,'arm64_savings_bytes':artifacts[0]['bytes']-artifacts[1]['bytes'],'arm64_savings_percent':round(100*(1-artifacts[1]['bytes']/artifacts[0]['bytes']),2)}
(root/'abi-package-audit.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','artifacts':[{'abi':a['abi'],'bytes':a['bytes'],'sha256':a['sha256']} for a in artifacts],'arm64_savings_percent':receipt['arm64_savings_percent']}))
