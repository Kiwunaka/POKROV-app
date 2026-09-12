from pathlib import Path
import hashlib,json,difflib,subprocess
out=Path(__file__).parent
root=Path('E:/r12client')
source='2aa57015783ceb3415e3be62bbf0a698729011c4'
original=(root/'scripts/build-android-production.ps1').read_bytes()
committed=subprocess.check_output(['git','-C',str(root),'show',source+':scripts/build-android-production.ps1'])
assert original.replace(b'\r\n',b'\n')==committed.replace(b'\r\n',b'\n')
text=original.decode().replace('\r\n','\n')
old='''    & flutter @commonBuildArguments
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter production universal and ABI APK build failed with exit code $LASTEXITCODE."
    }'''
new='''    $resumeProof=[IO.File]::ReadAllText('C:/r12-c05-setup-privacy-20260912/direct-apks-verified.json') | ConvertFrom-Json
    if ($resumeProof.status -ne 'PASS_FOUR_EXACT_DIRECT_APKS' -or $resumeProof.source_client -ne $clientRevision -or $resumeProof.artifacts.Count -ne 4) { throw 'Current four-APK evidence mismatch' }
    foreach ($resumeApk in $resumeProof.artifacts) {
      if ((Get-Item -LiteralPath $resumeApk.path).Length -ne $resumeApk.size -or (Get-FileHash -LiteralPath $resumeApk.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $resumeApk.sha256) { throw 'Retained direct APK changed' }
    }
    Write-Host 'STORE-ONLY RESUME: reusing four exact verified APKs; APK build invocation skipped.'
'''.rstrip()
assert text.count(old)==1
resumed=text.replace(old,new).replace('$PSScriptRoot',"'E:/r12client/scripts'")
target=out/'build-android-store-only.ps1'
target.write_text(resumed,encoding='utf-8',newline='\n')
(out/'store-only-resume.patch').write_text(''.join(difflib.unified_diff(text.splitlines(True),resumed.splitlines(True),fromfile='canonical-build-android-production.ps1',tofile=target.name)),encoding='utf-8')
wrapper=(out/'build-android-retained-cache-retry.ps1').read_text().replace('& "$taskRoot/scripts/build-android-production.ps1"','& "$taskOut/build-android-store-only.ps1"').replace('android-build-retained-cache-retry.log','android-build-store-only.log').replace("$taskRoot='E:/r12client'", "$env:GRADLE_OPTS='-Dorg.gradle.daemon=false'\n$taskRoot='E:/r12client'")
(out/'build-android-store-only-wrapper.ps1').write_text(wrapper,encoding='utf-8')
(out/'store-only-resume-preparation.json').write_text(json.dumps({'status':'PASS_CANONICAL_STORE_AND_VERIFICATION_TAIL_PRESERVED','source_client':source,'canonical_script_sha256':hashlib.sha256(original).hexdigest(),'resume_script_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'changes':['Resolve PSScriptRoot to original scripts directory','Replace APK build invocation with retained four APK size and SHA-256 verification'],'repository_script_changed':False},indent=2)+'\n')
print('PASS prepared exact canonical store-only resumer')
