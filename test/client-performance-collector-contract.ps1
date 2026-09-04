$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$collector = Join-Path $root 'scripts\collect-client-performance-samples.ps1'
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('pokrov-client-performance-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
$pwsh = (Get-Process -Id $PID).Path

function Assert-ExitCode {
  param(
    [Parameter(Mandatory = $true)][int]$Expected,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$Case
  )
  & $pwsh -NoProfile -ExecutionPolicy Bypass -File $collector @Arguments *> $null
  if ($LASTEXITCODE -ne $Expected) {
    throw "$Case returned $LASTEXITCODE instead of $Expected."
  }
}

try {
  $recordedInput = Join-Path $temporaryRoot 'recorded.json'
  $recordedOutput = Join-Path $temporaryRoot 'recorded-output.json'
  [IO.File]::WriteAllText($recordedInput, '[1.25,2.5,3.75]', [Text.UTF8Encoding]::new($false))
  Assert-ExitCode -Expected 0 -Case 'recorded samples' -Arguments @(
    '-Mode', 'RecordedSamples',
    '-InputPath', $recordedInput,
    '-Samples', '3',
    '-OutputPath', $recordedOutput
  )
  $recorded = @([IO.File]::ReadAllText($recordedOutput) | ConvertFrom-Json)
  if ($recorded.Count -ne 3 -or [double]$recorded[2] -ne 3.75) {
    throw 'Recorded samples were not normalized deterministically.'
  }

  $artifact = Join-Path $temporaryRoot 'candidate.bin'
  $artifactOutput = Join-Path $temporaryRoot 'artifact-output.json'
  [IO.File]::WriteAllBytes($artifact, [byte[]](1..16))
  Assert-ExitCode -Expected 0 -Case 'artifact size' -Arguments @(
    '-Mode', 'ArtifactSize',
    '-ArtifactPath', $artifact,
    '-OutputPath', $artifactOutput
  )
  $artifactJson = [IO.File]::ReadAllText($artifactOutput)
  if (-not $artifactJson.TrimStart().StartsWith('[')) {
    throw 'Artifact size collection must emit a JSON numeric array even for one sample.'
  }
  $artifactValues = @($artifactJson | ConvertFrom-Json)
  if ($artifactValues.Count -ne 1 -or [double]$artifactValues[0] -ne 16) {
    throw 'Artifact size collection did not retain the exact byte count.'
  }

  $invalidInput = Join-Path $temporaryRoot 'invalid.json'
  [IO.File]::WriteAllText($invalidInput, '[1,-2,3]', [Text.UTF8Encoding]::new($false))
  Assert-ExitCode -Expected 1 -Case 'negative sample rejection' -Arguments @(
    '-Mode', 'RecordedSamples',
    '-InputPath', $invalidInput,
    '-Samples', '3',
    '-OutputPath', (Join-Path $temporaryRoot 'invalid-output.json')
  )
} finally {
  $resolvedTemporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
  $resolvedSystemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  if (-not $resolvedTemporaryRoot.StartsWith($resolvedSystemTemp, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to remove a test directory outside the system temp root.'
  }
  if (Test-Path -LiteralPath $resolvedTemporaryRoot -PathType Container) {
    Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
  }
}

Write-Host 'Client performance collector contract OK.' -ForegroundColor Green
