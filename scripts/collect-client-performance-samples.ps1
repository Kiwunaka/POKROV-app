[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('RecordedSamples', 'WindowsIdleCpu', 'WindowsIdleMemory', 'ArtifactSize')]
  [string]$Mode,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath,

  [string]$InputPath,
  [string]$ArtifactPath,
  [int]$TargetProcessId = 0,
  [ValidateRange(1, 10000)]
  [int]$IntervalMilliseconds = 1000,
  [ValidateRange(0, 10000)]
  [int]$Warmups = 0,
  [ValidateRange(1, 10000)]
  [int]$Samples = 1
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Resolve-FullPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  return [IO.Path]::GetFullPath($Path)
}

function Assert-SafeOutputPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $fullPath = Resolve-FullPath $Path
  $retainedRoot = Resolve-FullPath (Join-Path $root 'artifacts\releases')
  $prefix = $retainedRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if ($fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
      $fullPath.Equals($retainedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Performance samples cannot be written under artifacts/releases.'
  }
  return $fullPath
}

function Convert-NumericSamples {
  param(
    [Parameter(Mandatory = $true)]$Values,
    [Parameter(Mandatory = $true)][int]$MinimumCount
  )
  $normalized = [System.Collections.Generic.List[double]]::new()
  foreach ($value in @($Values)) {
    if ($value -is [bool] -or $null -eq $value) {
      throw 'Every performance sample must be a finite non-negative number.'
    }
    $number = 0.0
    if (-not [double]::TryParse(
        [string]$value,
        [Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture,
        [ref]$number
      ) -or [double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -lt 0) {
      throw 'Every performance sample must be a finite non-negative number.'
    }
    $normalized.Add($number)
  }
  if ($normalized.Count -lt $MinimumCount) {
    throw "Performance sample count $($normalized.Count) is below required $MinimumCount."
  }
  return @($normalized)
}

function Read-RecordedSamples {
  if ([string]::IsNullOrWhiteSpace($InputPath)) {
    throw 'RecordedSamples mode requires -InputPath.'
  }
  $fullInput = Resolve-FullPath $InputPath
  if (-not (Test-Path -LiteralPath $fullInput -PathType Leaf)) {
    throw 'Recorded performance input does not exist.'
  }
  $inputFile = Get-Item -LiteralPath $fullInput
  if ($inputFile.Length -gt 2MB) {
    throw 'Recorded performance input exceeds 2 MiB.'
  }
  try {
    $value = [IO.File]::ReadAllText($fullInput) | ConvertFrom-Json
  } catch {
    throw 'Recorded performance input must be a JSON numeric array.'
  }
  return Convert-NumericSamples -Values $value -MinimumCount $Samples
}

function Read-ArtifactSize {
  if ([string]::IsNullOrWhiteSpace($ArtifactPath)) {
    throw 'ArtifactSize mode requires -ArtifactPath.'
  }
  $fullArtifact = Resolve-FullPath $ArtifactPath
  if (-not (Test-Path -LiteralPath $fullArtifact -PathType Leaf)) {
    throw 'Performance artifact does not exist.'
  }
  return @([double](Get-Item -LiteralPath $fullArtifact).Length)
}

function Read-ProcessCpuSeconds {
  param([Parameter(Mandatory = $true)]$Process)
  $counter = $Process.TotalProcessorTime
  if ($null -eq $counter -or $counter -isnot [TimeSpan]) {
    throw 'Windows CPU counter unavailable; no performance evidence can be emitted.'
  }
  return $counter.TotalSeconds
}

function Read-WindowsIdleSamples {
  param([Parameter(Mandatory = $true)][bool]$Cpu)
  if (-not $IsWindows) {
    throw 'Windows idle collection requires Windows PowerShell Core.'
  }
  if ($TargetProcessId -le 0) {
    throw 'Windows idle collection requires -TargetProcessId.'
  }
  $processorCount = [Environment]::ProcessorCount
  $retained = [System.Collections.Generic.List[double]]::new()
  $previous = Get-Process -Id $TargetProcessId
  $previousCpu = if ($Cpu) { Read-ProcessCpuSeconds -Process $previous } else { 0.0 }
  $previousAt = [Diagnostics.Stopwatch]::GetTimestamp()
  $frequency = [double][Diagnostics.Stopwatch]::Frequency
  $total = $Warmups + $Samples
  for ($index = 0; $index -lt $total; $index += 1) {
    Start-Sleep -Milliseconds $IntervalMilliseconds
    $current = Get-Process -Id $TargetProcessId
    $currentAt = [Diagnostics.Stopwatch]::GetTimestamp()
    if ($Cpu) {
      $elapsed = ($currentAt - $previousAt) / $frequency
      if ($elapsed -le 0) {
        throw 'Windows CPU sample interval was not positive.'
      }
      $currentCpu = Read-ProcessCpuSeconds -Process $current
      $cpuValue = (($currentCpu - $previousCpu) / $elapsed / $processorCount) * 100
      $value = [Math]::Max(0, $cpuValue)
    } else {
      $value = [double]$current.WorkingSet64
    }
    if ($index -ge $Warmups) {
      $retained.Add([Math]::Round($value, 6))
    }
    if ($Cpu) { $previousCpu = $currentCpu }
    $previousAt = $currentAt
  }
  return @($retained)
}

$fullOutput = Assert-SafeOutputPath $OutputPath
$values = switch ($Mode) {
  'RecordedSamples' { Read-RecordedSamples }
  'ArtifactSize' { Read-ArtifactSize }
  'WindowsIdleCpu' { Read-WindowsIdleSamples -Cpu $true }
  'WindowsIdleMemory' { Read-WindowsIdleSamples -Cpu $false }
}
$normalized = Convert-NumericSamples -Values $values -MinimumCount $Samples
$outputDirectory = Split-Path -Parent $fullOutput
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
  [IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
}
$temporaryPath = "$fullOutput.$([Guid]::NewGuid().ToString('N')).tmp"
try {
  [IO.File]::WriteAllText(
    $temporaryPath,
    ((ConvertTo-Json -InputObject @($normalized) -Compress) + [Environment]::NewLine),
    [Text.UTF8Encoding]::new($false)
  )
  Move-Item -LiteralPath $temporaryPath -Destination $fullOutput -Force
} finally {
  if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
    Remove-Item -LiteralPath $temporaryPath -Force
  }
}

Write-Host "Client performance samples: $fullOutput"
Write-Host "Mode: $Mode; retained samples: $($normalized.Count); discarded warmups: $Warmups"
