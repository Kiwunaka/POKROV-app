$ErrorActionPreference='Stop'
$root='C:/r12-c05-wintun-20260912/ffi-current'
$markers=[ordered]@{credentials='V01_CANARY_CREDENTIAL_7bd2';config='V01_CANARY_CONFIG_b861';url='https://v01.invalid/private';ip='203.0.113.71';path='C:\Users\V01Fake\private';pii='v01@example.invalid'}
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName="$env:SystemRoot/System32/WindowsPowerShell/v1.0/powershell.exe"
$start.Arguments='-NoProfile -ExecutionPolicy Bypass -File C:/r12-c05-wintun-20260912/ffi-current/child.ps1'
$start.UseShellExecute=$false;$start.CreateNoWindow=$true
$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
$process=[Diagnostics.Process]::new();$process.StartInfo=$start
[void]$process.Start()
$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
if(-not $process.WaitForExit(45000)){$process.Kill();throw 'Bounded FFI subprocess timed out'}
$streams=[ordered]@{stdout=$stdout.Result;stderr=$stderr.Result}
$sinks=[ordered]@{};$leaked=$false
foreach($entry in $streams.GetEnumerator()){
 $bytes=[Text.Encoding]::UTF8.GetBytes($entry.Value);$sha=[Security.Cryptography.SHA256]::Create()
 $contains=[ordered]@{}
 foreach($marker in $markers.GetEnumerator()){$found=$entry.Value.Contains($marker.Value) -or $entry.Value.Contains($marker.Value.Replace('\','\\'));$contains[$marker.Key]=$found;$leaked=$leaked -or $found}
 $sinks[$entry.Key]=[ordered]@{bytes=$bytes.Length;sha256=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant();contains=$contains}
}
if($process.ExitCode -ne 0){[ordered]@{exit_code=$process.ExitCode;sinks=$sinks}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath "$root/subprocess-failure.json" -Encoding UTF8;throw 'FFI subprocess failed; raw streams not retained'}
$child=[IO.File]::ReadAllText("$root/child-receipt.json")|ConvertFrom-Json
foreach($entry in $child.ffi_return_contains.PSObject.Properties){$leaked=$leaked -or $entry.Value}
$result=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');status=if($leaked){'FAIL_PRIVACY'}else{'PASS_BOUNDED_PACKAGE_FFI'};origin='current-origin host isolated subprocess; invalid config before service startup; no TUN';client_source='c06cab7776dd3db5282535ba6c5309bf0119f6bb';core_source='880bff65ad665844828fe50fc395e9cfc1cd81b4';packaged_dll_path='E:/r12client/apps/windows_shell/build/release_bundle/pokrov-windows-x64-1.2.0+4053/pokrov-core.dll';child=$child;sinks=$sinks;raw_streams_retained=$false;host_network_changed=$false;live_profile_used=$false}
$result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath "$root/receipt.json" -Encoding UTF8
if($leaked -or -not $child.closed_core_code){throw 'Packaged privacy check failed'}
$result|ConvertTo-Json -Depth 8
