$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()

function Require-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { $errors.Add($Message) }
}

function Get-PhysicalLineCount {
  param([AllowEmptyString()][string]$Text)
  if ($Text.Length -eq 0) { return 0 }
  $newlineCount = [regex]::Matches($Text, "\r\n|\n|\r").Count
  $hasFinalNewline = $Text -match "(?:\r\n|\n|\r)$"
  return $newlineCount + $(if ($hasFinalNewline) { 0 } else { 1 })
}

$agentsPath = Join-Path $root "AGENTS.md"
Require-True (Test-Path -LiteralPath $agentsPath -PathType Leaf) "AGENTS.md is required"

if (Test-Path -LiteralPath $agentsPath) {
  $agents = [IO.File]::ReadAllText($agentsPath)
  $bytes = [Text.Encoding]::UTF8.GetByteCount($agents)
  $lines = Get-PhysicalLineCount $agents
  Require-True ($bytes -le 8192) "AGENTS.md exceeds 8192 UTF-8 bytes"
  Require-True ($lines -le 120) "AGENTS.md exceeds 120 physical lines"

  foreach ($required in @(
    "POKROV-app/main",
    "docs/README.md",
    "Android",
    "Windows",
    "iOS",
    "macOS",
    "MANUAL_OWNER_TEST",
    "artifacts/releases",
    "git diff --check"
  )) {
    Require-True ($agents.Contains($required)) "AGENTS.md is missing semantic guard: $required"
  }

  foreach ($forbidden in @(
    "OpenCode",
    "Fireworks",
    "CODY",
    "Last updated:",
    "model catalog",
    "active plans"
  )) {
    Require-True (-not $agents.Contains($forbidden)) "AGENTS.md contains volatile content: $forbidden"
  }

  Require-True ($agents -notmatch '\b\d+\.\d+\.\d+(?:-[A-Za-z0-9.]+)?\b') "AGENTS.md must not contain a release-version snapshot"
}

$registry = [IO.File]::ReadAllText((Join-Path $root "docs\README.md"))
$registryBytes = [Text.Encoding]::UTF8.GetByteCount($registry)
$registryLines = Get-PhysicalLineCount $registry
Require-True ($registryBytes -le 12288) "docs/README.md exceeds 12288 UTF-8 bytes"
Require-True ($registryLines -le 240) "docs/README.md exceeds 240 physical lines"
foreach ($class in @(
  "CANONICAL",
  "ACTIVE_EXECUTION",
  "EVIDENCE",
  "HISTORICAL_REFERENCE",
  "OPERATOR_PLAYBOOK",
  "EXPERIMENTAL"
)) {
  Require-True ($registry.Contains($class)) "docs/README.md is missing class $class"
}
Require-True ($registry.Contains("| Task | Read first | Inspect | Verify | Docs impact |")) "docs/README.md lacks task routes"
Require-True ($registry.Contains("| Class | Review | Owner | Path |")) "docs/README.md lacks document registry"

if ($errors.Count -gt 0) {
  throw "Client docs contract failed:`n$($errors -join "`n")"
}

Write-Host "Client docs contract OK." -ForegroundColor Green
