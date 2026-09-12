$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$profile='C:/ProgramData/POKROV/ServiceRuntime/working/configs/managed-profile.json'
$raw=[IO.File]::ReadAllText($profile)
$leak=$raw.Contains('r126b-20260912') -or $raw.Contains('203.0.113.198')
$json=$raw|ConvertFrom-Json
[ordered]@{utc=[DateTime]::UtcNow.ToString('o');valid_json=$true;has_outbounds=(@($json.outbounds).Count -gt 0);canary_present=$leak;profile_sha256=(Get-FileHash -LiteralPath $profile).Hash.ToLowerInvariant();raw_profile_exported=$false}|ConvertTo-Json|Set-Content -LiteralPath C:/Users/Public/R126b20260912/profile-restoration.json -Encoding UTF8
if($leak){throw 'Canary remains'}
