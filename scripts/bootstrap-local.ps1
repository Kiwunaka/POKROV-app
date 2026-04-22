[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Force
)

$root = Split-Path -Parent $PSScriptRoot
$localDirectory = Join-Path $root "config\\local"

if (-not (Test-Path -LiteralPath $localDirectory -PathType Container)) {
  if ($DryRun) {
    Write-Host "CREATE DIR config\\local"
  } else {
    New-Item -ItemType Directory -Path $localDirectory | Out-Null
    Write-Host "Created config\\local" -ForegroundColor Green
  }
}

$copies = @(
  @{
    Source = Join-Path $root "config\\templates\\local.env.example"
    Destination = Join-Path $localDirectory "local.env"
    Label = "config\\local\\local.env"
  },
  @{
    Source = Join-Path $root "config\\templates\\device-overrides.seed.json"
    Destination = Join-Path $localDirectory "device-overrides.json"
    Label = "config\\local\\device-overrides.json"
  }
)

foreach ($copy in $copies) {
  $exists = Test-Path -LiteralPath $copy.Destination -PathType Leaf

  if ($exists -and -not $Force) {
    Write-Host "SKIP  $($copy.Label) (already exists)"
    continue
  }

  if ($DryRun) {
    $action = if ($exists) { "OVERWRITE" } else { "CREATE" }
    Write-Host "$action $($copy.Label)"
    continue
  }

  Copy-Item -LiteralPath $copy.Source -Destination $copy.Destination -Force:$Force
  Write-Host "WROTE $($copy.Label)" -ForegroundColor Green
}

Write-Host "Bootstrap complete." -ForegroundColor Green
