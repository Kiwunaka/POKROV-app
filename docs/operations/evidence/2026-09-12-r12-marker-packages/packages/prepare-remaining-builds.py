from pathlib import Path
import difflib, hashlib, json, subprocess

out=Path(__file__).parent
old=Path('C:/r12-c05-setup-privacy-20260912')
root=Path('E:/r12client')
source='8067520c7b9230ab0c66823fae9ae78791f1a838'
assert subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()==source
original=(root/'scripts/build-android-production.ps1').read_bytes()
committed=subprocess.check_output(['git','-C',str(root),'show',source+':scripts/build-android-production.ps1'])
assert original.replace(b'\r\n',b'\n')==committed.replace(b'\r\n',b'\n')
text=original.decode().replace('\r\n','\n')
before='''    & flutter @commonBuildArguments
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter production universal and ABI APK build failed with exit code $LASTEXITCODE."
    }'''
after='''    $resumeProof=[IO.File]::ReadAllText('C:/r12-marker-packages-20260912/direct-apks-verified.json') | ConvertFrom-Json
    if ($resumeProof.status -ne 'PASS_FOUR_EXACT_DIRECT_APKS' -or $resumeProof.source_client -ne $clientRevision -or $resumeProof.artifacts.Count -ne 4) { throw 'Current four-APK evidence mismatch' }
    foreach ($resumeApk in $resumeProof.artifacts) {
      if ((Get-Item -LiteralPath $resumeApk.path).Length -ne $resumeApk.size -or (Get-FileHash -LiteralPath $resumeApk.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $resumeApk.sha256) { throw 'Retained direct APK changed' }
    }
    Write-Host 'STORE-ONLY RESUME: reusing four exact verified APKs.' '''.rstrip()
assert text.count(before)==1
resumed=text.replace(before,after).replace('$PSScriptRoot',"'E:/r12client/scripts'")
target=out/'build-android-store-only.ps1'
target.write_text(resumed,encoding='utf8')
(out/'store-only-resume.patch').write_text(''.join(difflib.unified_diff(text.splitlines(True),resumed.splitlines(True),fromfile='canonical-build-android-production.ps1',tofile=target.name)),encoding='utf8')
wrapper=(out/'build-direct-wrapper.ps1').read_text().replace('build-direct-only.ps1','build-android-store-only.ps1').replace('android-direct-build.log','android-build-store-only.log').replace('PASS direct build phase; separate APK verification and AAB are pending','PASS four retained APKs and current AAB build with canonical verification')
(out/'build-android-store-only-wrapper.ps1').write_text(wrapper,encoding='utf8')
watch=(old/'watch-android-store-only.py').read_text().replace('2aa57015783ceb3415e3be62bbf0a698729011c4',source)
(out/'watch-android-store-only.py').write_text(watch,encoding='utf8')
(out/'store-only-resume-preparation.json').write_text(json.dumps({'status':'PASS_CANONICAL_STORE_AND_VERIFICATION_TAIL_PRESERVED','source_client':source,'canonical_script_sha256':hashlib.sha256(original).hexdigest(),'resume_script_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'changes':['Resolve PSScriptRoot to original scripts directory','Reuse four exact verified APKs instead of rebuilding them'],'repository_script_changed':False},indent=2)+'\n')
print('Prepared store-only continuation')
