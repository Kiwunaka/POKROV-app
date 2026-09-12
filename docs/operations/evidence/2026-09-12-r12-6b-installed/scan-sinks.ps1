$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$service='C:/ProgramData/POKROV/ServiceRuntime'
$app='C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV/pokrov-observability'
$files=@(Get-ChildItem -LiteralPath $service -File -Recurse | Where-Object{$_.Extension -eq '.log'})
$files+=@(Get-ChildItem -LiteralPath $app -File | Where-Object{$_.Extension -in '.json','.jsonl'})
$results=@();$leaks=0;$coreFailures=0;$serviceFailures=0
foreach($file in $files){
 $raw=[IO.File]::ReadAllText($file.FullName)
 $hits=0
 foreach($marker in @('r126b-20260912','203.0.113.198')){if($raw.Contains($marker)){$hits++}}
 $leaks+=$hits
 $coreFailures+=([regex]::Matches($raw,'CORE-005')).Count
 $serviceFailures+=([regex]::Matches($raw,'runtime_core_start\|failed')).Count
 $relative=if($file.FullName.StartsWith($service.Replace('/','\'))){'service/'+$file.FullName.Substring($service.Length+1).Replace('\','/')}else{'app/'+$file.Name}
 $results+=[ordered]@{sink=$relative;size=$file.Length;sha256=(Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant();canary_matches=$hits}
}
[ordered]@{utc=[DateTime]::UtcNow.ToString('o');file_count=$results.Count;canary_matches=$leaks;core_005_occurrences=$coreFailures;service_start_failure_occurrences=$serviceFailures;files=$results;raw_content_exported=$false}|ConvertTo-Json -Depth 6
if($leaks){throw 'Canary detected in diagnostic sink; raw content suppressed'}
