[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$tracked = @(& git -C $root ls-files)
$deleted = @(& git -C $root diff --cached --name-only --diff-filter=D)
$active = @($tracked | Where-Object { $deleted -notcontains $_ })

$removedPaths = @(
  "artifacts/releases/",
  "docs/operations/evidence/",
  "docs/operations/history/",
  "apps/android_shell/android/app/libs/pokrov-core.aar",
  "apps/windows_shell/windows/runner/resources/runtime/pokrov-core.dll",
  "apps/windows_shell/windows/runner/resources/runtime/libcronet.dll"
)
foreach ($path in $active) {
  foreach ($removed in $removedPaths) {
    if ($path -eq $removed -or $path.StartsWith($removed, [StringComparison]::Ordinal)) {
      throw "Retired artifact remains tracked: $path"
    }
  }
}

$ignore = [IO.File]::ReadAllText((Join-Path $root ".gitignore"))
foreach ($path in $removedPaths[3..5]) {
  if (-not ($ignore -split "`r?`n").Contains($path)) {
    throw "Core runtime asset must remain local: $path"
  }
}

Write-Output "Client repository artifact boundary OK."
