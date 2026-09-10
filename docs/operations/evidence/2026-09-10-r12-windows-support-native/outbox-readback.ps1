$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$root='C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV/support-bundle-outbox'
$items=@(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue)
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');origin='current-origin Windows owned VM';outbox_exists=(Test-Path -LiteralPath $root);file_count=$items.Count;total_bytes=($items|Measure-Object Length -Sum).Sum;accepted_ciphertext_sha256='f2bcc4d5bb352e7c5a4f1926b30bad4a5bb08d2932ab75c50d9f0a024d7e5d57';has_accepted_envelope=$false;non_envelope_count=0}
foreach($f in $items){
 $raw=[IO.File]::ReadAllText($f.FullName);$envelope=$raw|ConvertFrom-Json
 if($envelope.schema_version -ne 1 -or -not $envelope.algorithm -or -not $envelope.ciphertext_b64){$r.non_envelope_count++}
 if((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -eq $r.accepted_ciphertext_sha256){$r.has_accepted_envelope=$true}
}
$r|ConvertTo-Json
