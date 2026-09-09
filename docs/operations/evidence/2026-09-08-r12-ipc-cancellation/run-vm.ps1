$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne '960ae449-036f-4166-b215-d8349145a4de'){throw 'Wrong VM'}
if(@(Get-NetAdapter).Count){throw 'Fixture requires NIC-free VM'}
$root='C:/Users/Public/R12Cancellation'
if(Test-Path -LiteralPath $root){throw 'Fixture directory already exists'}
Expand-Archive -LiteralPath C:/Users/Public/R12Cancellation.zip -DestinationPath $root
function Check-Installed {
 $expected=[IO.File]::ReadAllText('C:/Users/Public/R12Installer/v2/expected-bundle.json')|ConvertFrom-Json
 $count=0
 foreach($f in $expected.files.PSObject.Properties){
  if((Get-FileHash -LiteralPath (Join-Path 'C:/Program Files/POKROV' $f.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $f.Value){throw ('Installed mismatch '+$f.Name)}
  $count++
 }
 return $count
}
$result=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');kind='offline Debug component fixtures';status='FAIL';before_installed_count=(Check-Installed);tests=@()}
foreach($test in (Get-ChildItem -LiteralPath $root -Filter '*_test.exe')){
 $log=Join-Path $root ($test.BaseName+'.log')
 $err=Join-Path $root ($test.BaseName+'.stderr.log')
 $watch=[Diagnostics.Stopwatch]::StartNew()
 $p=Start-Process -FilePath $test.FullName -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err -PassThru
 $handle=$p.Handle
 $timedOut=-not $p.WaitForExit(30000)
 if($timedOut){$p.Kill();$p.WaitForExit()}
 $result.tests+=@{name=$test.Name;exit_code=$p.ExitCode;timeout=$timedOut;elapsed_ms=$watch.ElapsedMilliseconds;sha256=(Get-FileHash -LiteralPath $test.FullName -Algorithm SHA256).Hash.ToLowerInvariant();stdout=[IO.File]::ReadAllText($log);stderr=[IO.File]::ReadAllText($err)}
}
$result.after_installed_count=Check-Installed
$result.final_service_state=(Get-Service POKROVService).Status.ToString()
$result.final_adapter_count=@(Get-NetAdapter).Count
if($result.tests.Count -eq 12 -and @($result.tests|Where-Object {$_.exit_code -ne 0 -or $_.timeout}).Count -eq 0){$result.status='PASS_COMPONENT_FIXTURES'}
$result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath "$root/result.json" -Encoding UTF8
