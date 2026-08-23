[CmdletBinding()]
param(
  [string]$Root
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = Split-Path -Parent $PSScriptRoot
}
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$violations = [System.Collections.Generic.List[string]]::new()
$scannedFiles = 0

$releaseRoots = @(
  "packages",
  "apps\android_shell",
  "apps\windows_shell"
)

function Add-SourceMatches {
  param(
    [string]$RelativePath,
    [string]$Content,
    [string]$Rule,
    [string]$Pattern
  )

  foreach ($match in [regex]::Matches($Content, $Pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
    $line = 1 + ([regex]::Matches($Content.Substring(0, $match.Index), "`n")).Count
    $violations.Add("${RelativePath}:$line [$Rule]")
  }
}

foreach ($relativeRoot in $releaseRoots) {
  $sourceRoot = Join-Path $resolvedRoot $relativeRoot
  if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    continue
  }

  foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File) {
    $relativePath = $file.FullName.Substring($resolvedRoot.Length).TrimStart("\", "/")
    $normalized = $relativePath.Replace("\", "/")
    if (
      $normalized -match "(^|/)(test|build|\.dart_tool|\.tmp|generated)(/|$)" -or
      $file.Name -match "(_test\.(cpp|cc|cxx)|GeneratedPluginRegistrant\.)"
    ) {
      continue
    }

    $extension = $file.Extension.ToLowerInvariant()
    $isDart = $extension -eq ".dart"
    $isAndroidSource =
      $normalized -match "^apps/android_shell/android/app/src/(main|direct|store)/" -and
      $extension -in @(".kt", ".java")
    $isWindowsNative =
      $normalized -match "^apps/windows_shell/windows/(runner|service)/" -and
      $extension -in @(".cpp", ".cc", ".cxx", ".c", ".h", ".hpp")
    if (-not ($isDart -or $isAndroidSource -or $isWindowsNative)) {
      continue
    }

    $scannedFiles += 1
    $content = [IO.File]::ReadAllText($file.FullName)
    if ($isDart) {
      Add-SourceMatches $relativePath $content "raw Dart stdout" "\b(?:debugPrint|print)\s*\("
      Add-SourceMatches $relativePath $content "raw Dart developer log" "(?:dart:developer|\bdeveloper\.log\s*\()"
    }
    if ($isAndroidSource) {
      Add-SourceMatches $relativePath $content "Android logcat dependency" "(?:android\.util\.Log|\bLog\.(?:v|d|i|w|e|wtf)\s*\()"
    }
    if ($isWindowsNative) {
      Add-SourceMatches $relativePath $content "raw Windows/native output" "(?:std::(?:cout|cerr|clog)|OutputDebugString(?:A|W)?\s*\(|\b(?:fprintf|printf|puts)\s*\()"
    }

    if ($normalized -match "^packages/observability_runtime/lib/") {
      Add-SourceMatches $relativePath $content "raw exception serialization" "(?:StackTrace\.current|\bstackTrace\b|\b(?:error|exception)\.toString\s*\()"
    }
  }
}

if ($violations.Count -gt 0) {
  $details = $violations | Sort-Object -Unique
  throw "Release source logging gate failed:`n$($details -join "`n")"
}

Write-Host "Release source logging gate OK: $scannedFiles production files." -ForegroundColor Green
