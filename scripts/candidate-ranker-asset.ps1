function Assert-PokrovCandidateRankerAsset {
  param([Parameter(Mandatory)][string]$Path)

  $stream = [IO.File]::OpenRead($Path)
  try {
    $header = New-Object byte[] 8
    if ($stream.Length -ne 3734808 -or $stream.Read($header, 0, 8) -ne 8 -or
        [Text.Encoding]::ASCII.GetString($header) -cne 'PKRTF001') {
      throw 'Shadow model must be the fixed PKRTF001 v1/F82 artifact (3734808 bytes).'
    }
  } finally { $stream.Dispose() }
}

function Sync-PokrovCandidateRankerAsset {
  param([string]$ModelPath, [Parameter(Mandatory)][string]$RepositoryRoot)

  if ([string]::IsNullOrWhiteSpace($ModelPath)) {
    throw 'Pass -CandidateRankerModelPath with the approved exported v1 shadow model.'
  }
  $source = (Resolve-Path -LiteralPath $ModelPath -ErrorAction Stop).Path
  Assert-PokrovCandidateRankerAsset -Path $source
  $destination = Join-Path $RepositoryRoot 'packages/app_shell/assets/models/candidate-ranker-v1.bin'
  if ([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($destination)) {
    Copy-Item -LiteralPath $source -Destination $destination -Force
  }
  return $destination
}
