from pathlib import Path
import difflib, hashlib, json, subprocess

out=Path(__file__).parent
old=Path('C:/r12-c05-setup-privacy-20260912')
root=Path('E:/r12client')
source='f7115c505c314a7322481997a46343b03dae1127'
assert subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()==source
original=(root/'scripts/build-android-production.ps1').read_bytes()
committed=subprocess.check_output(['git','-C',str(root),'show',source+':scripts/build-android-production.ps1'])
assert original.replace(b'\r\n',b'\n')==committed.replace(b'\r\n',b'\n')
text=original.decode().replace('\r\n','\n')
before='''    & flutter @commonBuildArguments
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter production universal and ABI APK build failed with exit code $LASTEXITCODE."
    }'''
after='''    $resumeProof=[IO.File]::ReadAllText('C:/r12-dart-crash-packages-20260912/direct-apks-verified.json') | ConvertFrom-Json
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
win=(old/'build-windows.ps1').read_text().replace(str(old).replace('\\','/'),str(out).replace('\\','/'))
start=win.index('$taskRetention=')
end=win.index('foreach ($taskRel',start)
win=win[:start]+'''$taskRetention=[IO.File]::ReadAllText("$taskOut/prior-package-retention.json")|ConvertFrom-Json
if ($taskRetention.status -ne 'PASS_PRIOR_PACKAGE_BYTES_RETAINED') { throw 'Prior outputs were not retained' }
foreach ($taskRow in @($taskRetention.files | Where-Object {$_.name -like 'pokrov-windows-*'})) {
  if ((Get-FileHash -LiteralPath $taskRow.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskRow.sha256) { throw 'Previous Windows package changed' }
  $taskRemoteHash=(& ssh -o BatchMode=yes -o ConnectTimeout=8 pokrov-de "sha256sum $($taskRow.remote_path)")
  if ($LASTEXITCODE -ne 0 -or -not $taskRemoteHash.StartsWith($taskRow.remote_sha256+' ')) { throw 'Prior Windows remote verification failed' }
}
'''+win[end:]
win=win.replace('E:/r12-c05-setup-prior-flutter-cache-20260912','E:/r12-dart-crash-prior-flutter-cache-20260912').replace('E:\\r12-c05-setup-prior-flutter-cache-20260912','E:\\r12-dart-crash-prior-flutter-cache-20260912')
(out/'build-windows.ps1').write_text(win,encoding='utf8')
watch=(old/'watch-windows-build.py').read_text().replace('2aa57015783ceb3415e3be62bbf0a698729011c4',source)
watch=watch.replace("out/'promotion/client-candidate-coordinated.json'","Path('C:/r12-dart-crash-promotion-20260912/client-candidate.json')")
watch=watch.replace('prior-installer-retention.json','prior-package-retention.json').replace('PASS_PRIOR_INSTALLER_RETAINED','PASS_PRIOR_PACKAGE_BYTES_RETAINED')
watch=watch.replace('Focused current runtime81 Android8 seed/docs already passed; full CI and native CTest separate','Current crash test8 analyze seed/docs and exact PR CI passed; native CTest separate')
(out/'watch-windows-build.py').write_text(watch,encoding='utf8')
print('PASS prepared current store-only and Windows builders')
