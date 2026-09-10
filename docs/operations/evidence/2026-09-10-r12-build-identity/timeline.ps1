$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$dir='C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV/pokrov-observability'
$marker=[IO.File]::ReadAllText("$dir/previous-exit.v1.json")|ConvertFrom-Json
$events=@();$invalid=0
foreach($line in [IO.File]::ReadAllLines("$dir/operational-events.v1.0.jsonl")){
 try{$event=$line|ConvertFrom-Json}catch{$invalid++;continue}
 if($event.correlation.run_id -ne $marker.run_id){continue}
 $events+=[ordered]@{name=$event.name;outcome=$event.outcome;stage=$event.stage;sequence=$event.correlation.sequence;generation=$event.correlation.generation;has_attempt=($null -ne $event.correlation.attempt_id);git_revision=$event.build.git_revision;build_number=$event.build.build_number;error_code=$event.error.code}
}
$result=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');scope='Allowlisted projection of current installed app run; no raw attributes or correlation identifiers';events=$events;invalid_lines_in_retained_file=$invalid;file_bytes=(Get-Item -LiteralPath "$dir/operational-events.v1.0.jsonl").Length}
$result|ConvertTo-Json -Depth 6
