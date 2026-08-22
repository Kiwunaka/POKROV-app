[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$gate = Join-Path $root "scripts\check-release-source-logging.ps1"
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("pokrov-source-log-gate-" + [guid]::NewGuid().ToString("N"))
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Rejected {
  param(
    [string]$CaseName,
    [string]$RelativePath,
    [string]$Content
  )

  $caseRoot = Join-Path $fixtureRoot $CaseName
  $target = Join-Path $caseRoot $RelativePath
  [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
  [IO.File]::WriteAllText($target, $Content)
  try {
    & $gate -Root $caseRoot
    $failures.Add("$CaseName was accepted")
  } catch {
    if ($_.Exception.Message -notmatch "Release source logging gate failed") {
      $failures.Add("$CaseName failed for an unexpected reason: $($_.Exception.Message)")
    }
  }
}

try {
  & $gate -Root $root
  Assert-Rejected `
    -CaseName "dart-debug-print" `
    -RelativePath "packages\unsafe\lib\unsafe.dart" `
    -Content "void unsafe() { debugPrint('secret'); }"
  Assert-Rejected `
    -CaseName "android-logcat" `
    -RelativePath "apps\android_shell\android\app\src\main\kotlin\Unsafe.kt" `
    -Content "import android.util.Log`nfun unsafe() { Log.e(`"tag`", `"raw`") }"
  Assert-Rejected `
    -CaseName "windows-stderr" `
    -RelativePath "apps\windows_shell\windows\service\unsafe.cpp" `
    -Content "void unsafe() { std::cerr << `"raw`"; }"
  Assert-Rejected `
    -CaseName "raw-exception" `
    -RelativePath "packages\observability_runtime\lib\unsafe.dart" `
    -Content "String unsafe(Object error) => error.toString();"
} finally {
  if (Test-Path -LiteralPath $fixtureRoot -PathType Container) {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }
}

if ($failures.Count -gt 0) {
  throw "Release source logging contract failed:`n$($failures -join "`n")"
}

Write-Host "Release source logging contract OK: real tree plus 4 negative cases." -ForegroundColor Green
