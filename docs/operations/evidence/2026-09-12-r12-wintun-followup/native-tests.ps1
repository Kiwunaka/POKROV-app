$ErrorActionPreference = 'Stop'
$taskRoot = 'E:\r12client'
$taskCtest = 'C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/ctest.exe'
if (Get-PSDrive -Name P -ErrorAction SilentlyContinue) { throw 'P drive already exists.' }
& subst.exe P: $taskRoot
if ($LASTEXITCODE -ne 0) { throw 'Mapping failed.' }
try {
    & $taskCtest --test-dir P:/apps/windows_shell/build/windows/x64 -C Release --output-on-failure *> C:/r12-c05-wintun-20260912/windows-native-tests.log
    $taskTestExit = $LASTEXITCODE
} finally {
    $taskMapping = (& subst.exe) -join "`n"
    if ($taskMapping -notmatch ('(?im)^P:\\: => ' + [regex]::Escape($taskRoot) + '$')) { throw 'Unexpected P mapping; retained.' }
    & subst.exe P: /D
}
exit $taskTestExit
