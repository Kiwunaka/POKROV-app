$ErrorActionPreference='Stop'
$taskOut='C:/r12-dart-crash-packages-20260912'
$taskBefore=@(& subst.exe)
if ($taskBefore -match '^P:') { throw 'P already mapped' }
if (Test-Path P:/) { throw 'P drive already exists' }
& subst.exe P: E:\r12client
if ($LASTEXITCODE -ne 0) { throw 'Cannot reproduce build drive mapping' }
try {
 & 'C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/ctest.exe' --test-dir P:/apps/windows_shell/build/windows/x64 -C Release --output-on-failure *> "$taskOut/windows-native-ctest-mapped.log"
 $taskCode=$LASTEXITCODE
} finally {
 $taskCurrent=@(& subst.exe)
 if ($taskCurrent -notcontains 'P:\: => E:\r12client') { throw 'P mapping changed during test' }
 & subst.exe P: /D
 if ($LASTEXITCODE -ne 0) { throw 'Cannot restore P mapping' }
}
$taskAfter=@(& subst.exe)
if (@(Compare-Object $taskBefore $taskAfter).Count) { throw 'Drive mappings changed' }
@{status=if($taskCode -eq 0){'PASS_NINE_NATIVE_TESTS'}else{'FAIL'};test_exit=$taskCode;temporary_build_drive_restored=$true;utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$taskOut/windows-native-ctest.json"
if ($taskCode -ne 0) { throw 'Native tests failed' }
tail.exe -n 8 "$taskOut/windows-native-ctest-mapped.log"
