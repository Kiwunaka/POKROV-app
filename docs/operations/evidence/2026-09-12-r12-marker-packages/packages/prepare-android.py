from pathlib import Path
import hashlib,json,subprocess
out=Path(__file__).parent;prior=Path('C:/r12-dart-crash-packages-20260912');source='8067520c7b9230ab0c66823fae9ae78791f1a838'
names=['build-direct-only.ps1','build-direct-wrapper.ps1','watch-direct.py','verify-direct-apks.py','prepare-remaining-builds.py','audit-android.py','bind-current-dex.py'];rows=[]
for name in names:
 text=(prior/name).read_text().replace('C:/r12-dart-crash-packages-20260912',str(out).replace('\\','/')).replace('C:/r12-dart-crash-promotion-20260912','C:/r12-marker-atomicity-promotion-20260912').replace('f7115c505c314a7322481997a46343b03dae1127',source)
 if name=='build-direct-wrapper.ps1':text=text.replace('prior-package-retention.json','prior-android-retention.json')
 if name=='watch-direct.py':text=text.replace('FOUR_CURRENT_APKS_AAB_WINDOWS_PENDING','FOUR_CURRENT_APKS_AAB_PENDING_WINDOWS_ALREADY_BUILT')
 if name=='prepare-remaining-builds.py':text=text[:text.index('win=(old/')]+"print('Prepared store-only continuation')\n"
 (out/name).write_text(text);rows.append({'name':name,'sha256':hashlib.sha256((out/name).read_bytes()).hexdigest()})
unchanged=subprocess.check_output(['git','-C','E:/r12client','diff','--name-only','f7115c505c314a7322481997a46343b03dae1127',source,'--','scripts/build-android-production.ps1']).strip()==b''
assert unchanged
(out/'android-builder-preparation.json').write_text(json.dumps({'source':source,'builders':rows,'canonical_build_script_unchanged':unchanged},indent=2)+'\n')
print('Android builders prepared; build waits for retained prior bytes')
