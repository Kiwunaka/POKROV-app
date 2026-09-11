from pathlib import Path
import datetime,hashlib,json,re,subprocess,zipfile
root=Path('C:/r12-current-windows-source-20260911');out=Path('E:/r12-current-android-package-20260911')
sha=lambda b:hashlib.sha256(b).hexdigest()
def ref(p):return {'path':str(p),'size':p.stat().st_size,'sha256':sha(p.read_bytes())}
revision=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
assert revision=='90337b33180b1600f0d6c25029627d0e9dc5b217'
p=root/'apps/android_shell/build/app/outputs/flutter-apk/app-direct-release.apk'
signing_path=Path(str(p)+'.signing.json');signing=json.loads(signing_path.read_bytes())
assert signing['apk_sha256'].lower()==sha(p.read_bytes())
assert signing['abi']=='arm64-v8a' and signing['version_name']=='1.2.0' and str(signing['version_code'])=='4053'
assert signing['certificate_sha256'].lower()=='0a0602a7df5d96a0b427909d004f3ddf26def86587634bf16694da8d654b2500'
aar=root/'apps/android_shell/android/app/libs/pokrov-core.aar'
with zipfile.ZipFile(aar) as z:core=sha(z.read('jni/arm64-v8a/libpokrov-core.so'))
old_binding=Path('E:/r12-c05-flutter-native/engine-binary-binding.json')
prior=json.loads(old_binding.read_bytes());flutter={r['component'].removeprefix('android Flutter '):r['packaged_sha256'] for r in prior['components'] if r['component'].startswith('android Flutter ')}
notices={'packages/pokrov_app_shell/assets/fonts/OFL.txt':root/'packages/app_shell/assets/fonts/OFL.txt','packages/pokrov_app_shell/assets/licenses/native-go-NOTICES.txt':root/'packages/app_shell/assets/licenses/native-go-NOTICES.txt','assets/licenses/maven-NOTICES.txt':root/'apps/android_shell/assets/licenses/maven-NOTICES.txt','assets/licenses/cronet-NOTICES.txt':root/'apps/android_shell/assets/licenses/cronet-NOTICES.txt'}
with zipfile.ZipFile(p) as z:
 names=z.namelist();libs=[n for n in names if n.startswith('lib/') and n.endswith('.so')]
 assert set(libs)=={'lib/arm64-v8a/'+n for n in ['libapp.so','libflutter.so','libpokrov-core.so']}
 native=[]
 for name in libs:
  data=z.read(name);digest=sha(data)
  assert data[:4]==b'\x7fELF' and int.from_bytes(data[18:20],'little')==183
  if name.endswith('/libpokrov-core.so'):assert digest==core
  if name.endswith('/libflutter.so'):assert digest==flutter['arm64-v8a']
  if name.endswith('/libapp.so'):assert revision.encode() in data
  native.append({'entry':name,'size':len(data),'sha256':digest,'elf_machine':183})
 notice_refs=[]
 for rel,source in notices.items():
  entry='assets/flutter_assets/'+rel;data=z.read(entry);assert data==source.read_bytes()
  notice_refs.append({'entry':entry,'size':len(data),'sha256':sha(data)})
 notice=z.read('assets/flutter_assets/NOTICES.Z');assert notice
 suspicious=[n for n in names if re.search(r'(?i)(?:\.(?:p12|pfx|pem|key|jks|keystore|log|pdb|exe|dll|aar)$|(?:^|/)\.env(?:\.|$))',n)]
 assert not suspicious
config={}
for label,filename in [('before','abi-injected-v2.log'),('arm64','abi-fixed-arm64.log'),('production','abi-fixed-production.log')]:
 text=(out/filename).read_text(encoding='utf-8-sig');line=next(x for x in text.splitlines() if x.startswith('R12_ABI_PROBE='));config[label]=json.loads(line.partition('=')[2])
assert len(config['before']['packageAbis'])==3 and config['arm64']['packageAbis']==['arm64-v8a']
assert len(config['production']['packageAbis'])==3 and len(config['production']['variants'][0]['outputs'])==4
budget=json.loads((out/'build-disk-and-exit.json').read_bytes());assert budget['exit_code']==0 and all(v>=40*1024**3 for v in budget['minimum_observed_free_bytes'].values())
result={'schema':'pokrov.r12.current-android-arm64-package/v1','status':'PASS_LOCAL_PACKAGE','observed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_client_sha':revision,'source_main_base':'d9763e8cd7aba9b215015e07c0576f667c1dec09','feature_fix_sha':'bf78a26ed20302189ce648f77a1a9baf55ff27fb','source_core_sha':'904e440aca98cb6419744c5c04c83223a6d6380e','artifact':ref(p),'signing_receipt':ref(signing_path),'core_aar':ref(aar),'flutter_prior_binding':ref(old_binding),'native_libraries':native,'notices':notice_refs,'flutter_notices':{'size':len(notice),'sha256':sha(notice)},'embedded_exact_revision':True,'abi_configuration':config,'disk_budget':budget,'unexpected_private_or_build_file_names':suspicious,'limits':['One local ARM64 Direct package; other three direct packages and store AAB NOT_BUILT_CURRENT_SOURCE.','Not installed on the owner phone or another device; no physical acceptance inferred.','No new public release candidate, publication, push or deployment.','Self-managed production certificate is compared to the existing local identity, not a Store or external trust claim.','Static file-name inspection is bounded, not a full secret scan or runtime privacy proof.']}
(out/'android-package-audit.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('PASS: signed ARM64 APK, three exact native components, four notices, embedded source revision, ABI regression and disk floor')
