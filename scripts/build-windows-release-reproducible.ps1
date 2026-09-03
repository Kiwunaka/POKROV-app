$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$forwardedArguments = @($args)
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$stableDrive = "P:"
$stableScript = "$stableDrive\\scripts\\build-windows-release.ps1"
$mapped = $false

if (Get-PSDrive -Name $stableDrive.TrimEnd(":") -ErrorAction SilentlyContinue) {
  throw "$stableDrive is already in use; reproducible Windows build aborted."
}

try {
  & subst.exe $stableDrive $repositoryRoot
  if ($LASTEXITCODE -ne 0) {
    throw "Could not map $stableDrive to the POKROV client repository."
  }
  $mapped = $true

  & pwsh -NoLogo -NoProfile -File $stableScript @forwardedArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Reproducible Windows release build failed with exit code $LASTEXITCODE."
  }
} finally {
  if ($mapped) {
    $mapping = (& subst.exe) -join "`n"
    if ($LASTEXITCODE -ne 0 -or
        $mapping -notmatch ("(?im)^P:\\: => " +
          [regex]::Escape($repositoryRoot) + "$") ) {
      throw "Refusing to remove an unexpected $stableDrive mapping."
    }
    & subst.exe $stableDrive /D
    if ($LASTEXITCODE -ne 0) {
      throw "Could not remove the temporary $stableDrive mapping."
    }
  }
}
