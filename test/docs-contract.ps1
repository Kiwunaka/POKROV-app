$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Get-PhysicalLineCount {
  param([AllowEmptyString()][string]$Text)

  if ($Text.Length -eq 0) { return 0 }
  $newlineCount = [regex]::Matches($Text, "\r\n|\n|\r").Count
  $hasFinalNewline = $Text -match "(?:\r\n|\n|\r)$"
  return $newlineCount + $(if ($hasFinalNewline) { 0 } else { 1 })
}

function Test-HasByteOrderMark {
  param([byte[]]$Bytes)

  if ($Bytes.Length -ge 4) {
    if (($Bytes[0] -eq 0x00 -and $Bytes[1] -eq 0x00 -and $Bytes[2] -eq 0xFE -and $Bytes[3] -eq 0xFF) -or
        ($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE -and $Bytes[2] -eq 0x00 -and $Bytes[3] -eq 0x00)) {
      return $true
    }
  }
  if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
    return $true
  }
  if ($Bytes.Length -ge 2 -and
      (($Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) -or
       ($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE))) {
    return $true
  }
  return $false
}

function ConvertFrom-StrictDocumentBytes {
  param(
    [byte[]]$Bytes,
    [string]$Name,
    [int]$MaximumBytes,
    [int]$MaximumLines,
    [System.Collections.Generic.List[string]]$Errors
  )

  if ($Bytes.Length -gt $MaximumBytes) {
    [void]$Errors.Add("$Name exceeds $MaximumBytes UTF-8 bytes (actual: $($Bytes.Length))")
  }
  if (Test-HasByteOrderMark -Bytes $Bytes) {
    [void]$Errors.Add("$Name must not contain a byte-order mark (BOM)")
  }
  if ($Bytes -contains [byte]13) {
    [void]$Errors.Add("$Name must use LF-only line endings")
  }
  if ($Bytes.Length -eq 0 -or $Bytes[-1] -ne [byte]10) {
    [void]$Errors.Add("$Name must be non-empty and end with LF")
  }

  $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
  try {
    $text = $strictUtf8.GetString($Bytes)
  } catch {
    [void]$Errors.Add("$Name is not valid strict UTF-8: $($_.Exception.Message)")
    return $null
  }

  $lineCount = Get-PhysicalLineCount -Text $text
  if ($lineCount -gt $MaximumLines) {
    [void]$Errors.Add("$Name exceeds $MaximumLines physical lines (actual: $lineCount)")
  }

  return [pscustomobject]@{
    Text = $text
    ByteLength = $Bytes.Length
    LineCount = $lineCount
  }
}

function Get-VisibleMarkdownLines {
  param(
    [string]$Text,
    [string]$Name,
    [System.Collections.Generic.List[string]]$Errors
  )

  $physicalLines = [regex]::Split($Text, "\r\n|\n|\r")
  $visible = [System.Collections.Generic.List[object]]::new()
  $insideFence = $false
  $fenceCharacter = [char]0
  $fenceLength = 0

  for ($index = 0; $index -lt $physicalLines.Count; $index++) {
    $line = $physicalLines[$index]

    if ($insideFence) {
      $closing = [regex]::Match($line, '^ {0,3}(?<marker>`+|~+)[ \t]*$')
      if ($closing.Success) {
        $marker = $closing.Groups['marker'].Value
        if ($marker[0] -eq $fenceCharacter -and $marker.Length -ge $fenceLength) {
          $insideFence = $false
          $fenceCharacter = [char]0
          $fenceLength = 0
        }
      }
      continue
    }

    $opening = [regex]::Match($line, '^ {0,3}(?<marker>`{3,}|~{3,})(?<info>.*)$')
    if ($opening.Success) {
      $marker = $opening.Groups['marker'].Value
      $insideFence = $true
      $fenceCharacter = $marker[0]
      $fenceLength = $marker.Length
      continue
    }

    [void]$visible.Add([pscustomobject]@{
      LineNumber = $index + 1
      Text = $line
    })
  }

  if ($insideFence) {
    [void]$Errors.Add("$Name contains an unclosed fenced block")
  }

  return $visible.ToArray()
}

function ConvertFrom-MarkdownTableLine {
  param([AllowEmptyString()][string]$Line)

  $trimmed = $Line.Trim()
  if ($trimmed.Length -lt 2 -or -not $trimmed.StartsWith('|') -or -not $trimmed.EndsWith('|')) {
    return [pscustomobject]@{ IsTable = $false; Cells = @() }
  }

  $inner = $trimmed.Substring(1, $trimmed.Length - 2)
  $cells = [System.Collections.Generic.List[string]]::new()
  $builder = [Text.StringBuilder]::new()
  $codeDelimiterLength = 0
  $index = 0

  while ($index -lt $inner.Length) {
    $character = $inner[$index]

    if ($character -eq '\' -and $index + 1 -lt $inner.Length) {
      [void]$builder.Append($character)
      [void]$builder.Append($inner[$index + 1])
      $index += 2
      continue
    }

    if ($character -eq [char]96) {
      $runLength = 1
      while ($index + $runLength -lt $inner.Length -and $inner[$index + $runLength] -eq [char]96) {
        $runLength++
      }
      if ($codeDelimiterLength -eq 0) {
        $codeDelimiterLength = $runLength
      } elseif ($runLength -eq $codeDelimiterLength) {
        $codeDelimiterLength = 0
      }
      [void]$builder.Append($inner.Substring($index, $runLength))
      $index += $runLength
      continue
    }

    if ($character -eq '|' -and $codeDelimiterLength -eq 0) {
      [void]$cells.Add($builder.ToString().Trim())
      [void]$builder.Clear()
      $index++
      continue
    }

    [void]$builder.Append($character)
    $index++
  }

  [void]$cells.Add($builder.ToString().Trim())
  return [pscustomobject]@{ IsTable = $true; Cells = [string[]]$cells.ToArray() }
}

function Test-StringArraysEqual {
  param([string[]]$Left, [string[]]$Right)

  if ($Left.Count -ne $Right.Count) { return $false }
  for ($index = 0; $index -lt $Left.Count; $index++) {
    if ($Left[$index] -cne $Right[$index]) { return $false }
  }
  return $true
}

function Get-UniqueMarkdownTable {
  param(
    [object[]]$VisibleLines,
    [string[]]$Header,
    [string]$Name,
    [System.Collections.Generic.List[string]]$Errors
  )

  $headerPositions = [System.Collections.Generic.List[int]]::new()
  for ($index = 0; $index -lt $VisibleLines.Count; $index++) {
    $parsed = ConvertFrom-MarkdownTableLine -Line $VisibleLines[$index].Text
    if ($parsed.IsTable -and (Test-StringArraysEqual -Left $parsed.Cells -Right $Header)) {
      [void]$headerPositions.Add($index)
    }
  }

  if ($headerPositions.Count -ne 1) {
    [void]$Errors.Add("$Name table header must appear exactly once outside fenced blocks (actual: $($headerPositions.Count))")
  }
  if ($headerPositions.Count -eq 0) {
    return [pscustomobject]@{ Rows = @(); HeaderLine = 0; LastLine = 0 }
  }

  $headerPosition = $headerPositions[0]
  $headerLine = $VisibleLines[$headerPosition]
  if ($headerPosition + 1 -ge $VisibleLines.Count -or
      $VisibleLines[$headerPosition + 1].LineNumber -ne $headerLine.LineNumber + 1) {
    [void]$Errors.Add("$Name table lacks an adjacent delimiter row")
    return [pscustomobject]@{ Rows = @(); HeaderLine = $headerLine.LineNumber; LastLine = $headerLine.LineNumber }
  }

  $delimiterLine = $VisibleLines[$headerPosition + 1]
  $delimiter = ConvertFrom-MarkdownTableLine -Line $delimiterLine.Text
  $validDelimiter = $delimiter.IsTable -and $delimiter.Cells.Count -eq $Header.Count
  if ($validDelimiter) {
    foreach ($cell in $delimiter.Cells) {
      if ($cell -notmatch '^:?-{3,}:?$') {
        $validDelimiter = $false
        break
      }
    }
  }
  if (-not $validDelimiter) {
    [void]$Errors.Add("$Name table has an invalid delimiter row at line $($delimiterLine.LineNumber)")
  }

  $rows = [System.Collections.Generic.List[object]]::new()
  $previousPhysicalLine = $delimiterLine.LineNumber
  for ($index = $headerPosition + 2; $index -lt $VisibleLines.Count; $index++) {
    $line = $VisibleLines[$index]
    if ($line.LineNumber -ne $previousPhysicalLine + 1) { break }

    $parsed = ConvertFrom-MarkdownTableLine -Line $line.Text
    if (-not $parsed.IsTable) { break }
    if ($parsed.Cells.Count -ne $Header.Count) {
      [void]$Errors.Add("$Name row at line $($line.LineNumber) has $($parsed.Cells.Count) cells; expected $($Header.Count)")
    }
    [void]$rows.Add([pscustomobject]@{
      LineNumber = $line.LineNumber
      Cells = [string[]]$parsed.Cells
    })
    $previousPhysicalLine = $line.LineNumber
  }

  return [pscustomobject]@{
    Rows = $rows.ToArray()
    HeaderLine = $headerLine.LineNumber
    LastLine = $previousPhysicalLine
  }
}

function New-ExpectedRegistryPathClasses {
  $map = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
  $entries = @(
    'CANONICAL|docs/README.md',
    'CANONICAL|README.md',
    'CANONICAL|DESIGN.md',
    'CANONICAL|docs/product/client-product-contract.md',
    'CANONICAL|docs/architecture/app-first-onboarding-flow.md',
    'CANONICAL|docs/architecture/folder-structure.md',
    'CANONICAL|docs/architecture/package-boundaries.md',
    'CANONICAL|docs/architecture/bootstrap-workflow.md',
    'CANONICAL|docs/architecture/in-app-ai-assistant-contract.md',
    'CANONICAL|docs/design/2026-06-13-pokrov-product-ui-direction.md',
    'CANONICAL|config/product-contract.seed.json',
    'CANONICAL|config/platform-matrix.seed.json',
    'CANONICAL|config/runtime-profile.seed.json',
    'CANONICAL|config/cutover-readiness.seed.json',
    'CANONICAL|config/release-handoff.seed.json',
    'ACTIVE_EXECUTION|docs/implementation/client-release-backlog.md',
    'ACTIVE_EXECUTION|docs/operations/cutover-readiness.md',
    'ACTIVE_EXECUTION|docs/operations/android-release-audit.md',
    'ACTIVE_EXECUTION|docs/operations/windows-release-readiness.md',
    'ACTIVE_EXECUTION|docs/operations/warp-runtime-proof-checklist.md',
    'ACTIVE_EXECUTION|docs/operations/responsive-golden-capture-plan.md',
    'ACTIVE_EXECUTION|docs/operations/client-motion-performance-checklist.md',
    'ACTIVE_EXECUTION|docs/operations/apple-release-readiness.md',
    'EVIDENCE|docs/product/client-public-beta-prd.md',
    'EVIDENCE|docs/operations/2026-06-04-public-beta-operator-handoff.md',
    'EVIDENCE|docs/operations/2026-06-05-phase-6-release-beta-handoff.md',
    'EVIDENCE|docs/operations/2026-06-05-final-beta-closure-except-manual-tests-signing.md',
    'EVIDENCE|docs/operations/2026-06-13-pokrov-product-ui-plan-closure-audit.md',
    'EVIDENCE|docs/operations/client-ui-api-additions.md',
    'EVIDENCE|docs/developer/work-orders/2026-04-open-beta-v4/INDEX.md',
    'EVIDENCE|docs/implementation/2026-06-03-client-build-readiness-and-api-plan.md',
    'EVIDENCE|docs/implementation/2026-06-03-client-mvp-shell-implementation.md',
    'EVIDENCE|docs/implementation/2026-06-04-decisions-implementation-map.md',
    'EVIDENCE|docs/implementation/2026-06-05-p6-overload-correction-plan.md',
    'HISTORICAL_REFERENCE|docs/design/DESIGN.md',
    'HISTORICAL_REFERENCE|docs/specs/2026-04-18-wave-7-new-base-client-scaffold.md',
    'HISTORICAL_REFERENCE|docs/specs/2026-06-05-p5-warp-approved-design.md',
    'HISTORICAL_REFERENCE|docs/decisions/2026-06-03-hiddify-karing-happ-client-base-review.md',
    'HISTORICAL_REFERENCE|docs/decisions/2026-06-03-hiddify-core-warp-status.md',
    'HISTORICAL_REFERENCE|docs/decisions/2026-06-03-client-ux-account-rewards-master-brief.md',
    'HISTORICAL_REFERENCE|docs/decisions/2026-06-03-client-chat-responsive-warp-motion-review.md',
    'HISTORICAL_REFERENCE|docs/decisions/2026-06-03-client-best-mvp-consilium.md',
    'HISTORICAL_REFERENCE|docs/decisions/2026-06-02-karing-base-reopen.md',
    'HISTORICAL_REFERENCE|docs/decisions/2026-04-18-karing-vs-clean-room-gate.md',
    'HISTORICAL_REFERENCE|docs/design/2026-06-03-client-premium-shell-v2-brief.md',
    'HISTORICAL_REFERENCE|docs/design/2026-06-03-client-screen-component-rules.md',
    'HISTORICAL_REFERENCE|docs/design/2026-06-03-client-quiet-emerald-style-brief.md',
    'HISTORICAL_REFERENCE|docs/design/2026-06-03-client-chat-responsive-warp-motion-brief.md',
    'HISTORICAL_REFERENCE|docs/design/2026-06-03-client-best-mvp-build-brief.md',
    'HISTORICAL_REFERENCE|docs/design/2026-06-05-p5-warp-application-map.md',
    'HISTORICAL_REFERENCE|docs/design/2026-06-05-p5-application-map-consilium-review.md',
    'HISTORICAL_REFERENCE|docs/design/2026-06-05-p6-overload-ux-consilium.md',
    'HISTORICAL_REFERENCE|docs/design/assets/',
    'HISTORICAL_REFERENCE|docs/design/generated/2026-06-09-app-screen-variants/',
    'HISTORICAL_REFERENCE|docs/archive/'
  )

  foreach ($entry in $entries) {
    $parts = $entry -split '\|', 2
    $map.Add($parts[1], $parts[0])
  }
  return ,$map
}

function Test-RegistryRelativePath {
  param(
    [string]$RepositoryRoot,
    [string]$RelativePath,
    [System.Collections.Generic.List[string]]$Errors
  )

  if ([string]::IsNullOrWhiteSpace($RelativePath)) {
    [void]$Errors.Add('Registry path must not be empty')
    return
  }
  if ($RelativePath.Contains('\')) {
    [void]$Errors.Add("Registry path must use forward slashes: $RelativePath")
  }
  if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '^[A-Za-z]:') {
    [void]$Errors.Add("Registry path must be repository-relative: $RelativePath")
    return
  }
  if ($RelativePath -match '(^|/)(?:\.|\.\.)(?:/|$)') {
    [void]$Errors.Add("Registry path must not contain '.' or '..' segments: $RelativePath")
    return
  }
  if ($RelativePath -match '//|[:*?"<>|]') {
    [void]$Errors.Add("Registry path is not normalized: $RelativePath")
    return
  }

  $trimmedRelative = $RelativePath.TrimEnd('/')
  if ($trimmedRelative.Length -eq 0) {
    [void]$Errors.Add("Registry path resolves to the repository root: $RelativePath")
    return
  }

  $rootFull = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([char[]]@('\', '/'))
  $candidate = [IO.Path]::GetFullPath((Join-Path $rootFull $trimmedRelative.Replace('/', '\')))
  $rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
  if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    [void]$Errors.Add("Registry path escapes the repository: $RelativePath")
    return
  }
  if (-not (Test-Path -LiteralPath $candidate)) {
    [void]$Errors.Add("Registry path does not exist: $RelativePath")
  }
}

function Test-AgentContract {
  param(
    [string]$Text,
    [System.Collections.Generic.List[string]]$Errors
  )

  $visible = @(Get-VisibleMarkdownLines -Text $Text -Name 'AGENTS.md' -Errors $Errors)
  $h1Lines = @($visible | Where-Object { $_.Text -match '^# (?!#)' })
  if ($h1Lines.Count -ne 1 -or $h1Lines[0].Text -cne '# POKROV-app Codex Contract') {
    [void]$Errors.Add('AGENTS.md must contain exactly one canonical H1 heading')
  }

  $requiredHeadings = @(
    'Start Every Task',
    'Authority',
    'Repository Boundary',
    'Runtime And Security',
    'Evidence And Destructive Operations',
    'Release Honesty',
    'Verification And Documentation'
  )
  $headingNames = [System.Collections.Generic.List[string]]::new()
  $headingPositions = [System.Collections.Generic.List[int]]::new()
  for ($index = 0; $index -lt $visible.Count; $index++) {
    if ($visible[$index].Text -match '^## (?<name>.+?)\s*$') {
      [void]$headingNames.Add($Matches['name'])
      [void]$headingPositions.Add($index)
    }
  }
  if (-not (Test-StringArraysEqual -Left $headingNames.ToArray() -Right $requiredHeadings)) {
    [void]$Errors.Add("AGENTS.md must use the exact ordered H2 section set: $($requiredHeadings -join ', ')")
  }

  for ($headingIndex = 0; $headingIndex -lt $headingPositions.Count; $headingIndex++) {
    $start = $headingPositions[$headingIndex] + 1
    $end = $(if ($headingIndex + 1 -lt $headingPositions.Count) { $headingPositions[$headingIndex + 1] - 1 } else { $visible.Count - 1 })
    $nonEmpty = 0
    $listItems = 0
    for ($lineIndex = $start; $lineIndex -le $end; $lineIndex++) {
      if ($lineIndex -lt 0 -or $lineIndex -ge $visible.Count) { continue }
      $line = $visible[$lineIndex].Text
      if (-not [string]::IsNullOrWhiteSpace($line)) { $nonEmpty++ }
      if ($line -match '^\s*(?:- |\d+\.\s+)') { $listItems++ }
    }
    if ($nonEmpty -eq 0 -or $listItems -eq 0) {
      [void]$Errors.Add("AGENTS.md section '$($headingNames[$headingIndex])' must contain meaningful list content")
    }
  }

  foreach ($required in @(
    'POKROV-app/main',
    'docs/README.md',
    'Android',
    'Windows',
    'iOS',
    'macOS',
    'MANUAL_OWNER_TEST',
    'artifacts/releases',
    'git diff --check'
  )) {
    if (-not $Text.Contains($required)) {
      [void]$Errors.Add("AGENTS.md is missing semantic guard: $required")
    }
  }

  foreach ($forbidden in @('OpenCode', 'Fireworks', 'CODY', 'Last updated:', 'model catalog', 'active plans')) {
    if ($Text.IndexOf($forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
      [void]$Errors.Add("AGENTS.md contains forbidden volatile text: $forbidden")
    }
  }

  $forbiddenPatterns = [ordered]@{
    'dated status marker' = '(?im)^\s*(?:last\s+updated|updated|date|as\s+of)\s*:'
    'calendar-date snapshot' = '(?i)(?<!\d)(?:19|20)\d{2}[-/.](?:0?[1-9]|1[0-2])[-/.](?:0?[1-9]|[12]\d|3[01])(?!\d)'
    'month-name date snapshot' = '(?i)\b(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{1,2},?\s+(?:19|20)\d{2}\b'
    'release-version snapshot' = '(?i)(?<![A-Za-z0-9])v?\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?(?![A-Za-z0-9])'
    'named model or provider' = '(?i)(?<![A-Za-z0-9])(?:OpenCode|OpenRouter|Fireworks|CODY|DeepSeek|Kimi|Claude|Gemini|Moonshot|MiniMax|Nemotron|Mimo|GPT(?:-[A-Za-z0-9_.-]+)?|GLM(?:-[A-Za-z0-9_.-]+)?|z[-.]ai)(?![A-Za-z0-9])'
    'model/provider routing catalog' = '(?i)\b(?:model|provider)\s+(?:routing|catalog|pricing|prices|preference|preferences)\b'
    'global must-read list' = '(?im)(?:^#{1,6}\s+(?:global\s+)?must[- ]read(?:\s+(?:order|list|set))?\s*$|\bglobal\s+must[- ]read(?:\s+(?:order|list|set))?\b|\bmust[- ]read\s+(?:order|list|set)\b)'
    'active-plan inventory' = '(?im)(?:^#{1,6}\s+active\s+plans?\b|\bactive\s+plans?\s+(?:list|inventory)\b)'
  }
  foreach ($label in $forbiddenPatterns.Keys) {
    if ($Text -match $forbiddenPatterns[$label]) {
      [void]$Errors.Add("AGENTS.md contains forbidden volatile content: $label")
    }
  }
}

function Test-DocumentationRegistry {
  param(
    [string]$Text,
    [string]$RepositoryRoot,
    [System.Collections.Generic.List[string]]$Errors
  )

  $visible = @(Get-VisibleMarkdownLines -Text $Text -Name 'docs/README.md' -Errors $Errors)
  $routeHeader = @('Task', 'Read first', 'Inspect', 'Verify', 'Docs impact')
  $registryHeader = @('Class', 'Review', 'Owner', 'Path')
  $routeTable = Get-UniqueMarkdownTable -VisibleLines $visible -Header $routeHeader -Name 'Task routes' -Errors $Errors
  $registryTable = Get-UniqueMarkdownTable -VisibleLines $visible -Header $registryHeader -Name 'Document registry' -Errors $Errors

  $requiredRoutes = @(
    'Shell, UI, or copy',
    'App-first, account, or API',
    'Runtime, core, or WARP',
    'Android',
    'Windows',
    'Apple readiness',
    'Release metadata',
    'Design',
    'Docs or history'
  )
  $requiredRouteSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($route in $requiredRoutes) { [void]$requiredRouteSet.Add($route) }
  $observedRouteSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

  foreach ($row in $routeTable.Rows) {
    if ($row.Cells.Count -ne 5) { continue }
    for ($cellIndex = 0; $cellIndex -lt 5; $cellIndex++) {
      if ([string]::IsNullOrWhiteSpace($row.Cells[$cellIndex])) {
        [void]$Errors.Add("Task route row at line $($row.LineNumber) contains an empty cell")
      }
    }
    $routeName = $row.Cells[0]
    if (-not $observedRouteSet.Add($routeName)) {
      [void]$Errors.Add("Task routes contain duplicate route: $routeName")
    }
  }
  if ($routeTable.Rows.Count -ne $requiredRoutes.Count -or -not $requiredRouteSet.SetEquals($observedRouteSet)) {
    [void]$Errors.Add('Task routes do not match the exact required nine-route set')
  }

  $allowedClasses = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($value in @('CANONICAL', 'ACTIVE_EXECUTION', 'EVIDENCE', 'HISTORICAL_REFERENCE', 'OPERATOR_PLAYBOOK', 'EXPERIMENTAL')) {
    [void]$allowedClasses.Add($value)
  }
  $allowedReviews = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($value in @('RECONCILED', 'REVIEWED_NO_CHANGE', 'PENDING_COLLISION_REVIEW', 'UNRESOLVED_OWNER_DECISION')) {
    [void]$allowedReviews.Add($value)
  }

  $expectedPathClasses = New-ExpectedRegistryPathClasses
  $observedClasses = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $observedPaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $logicalRows = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $noLocalOwnerCounts = @{ OPERATOR_PLAYBOOK = 0; EXPERIMENTAL = 0 }
  $noLocalOwnerText = 'no client-local owner; platform tools do not enter the client default route'

  foreach ($row in $registryTable.Rows) {
    if ($row.Cells.Count -ne 4) { continue }
    $class = $row.Cells[0]
    $review = $row.Cells[1]
    $owner = $row.Cells[2]
    $pathCell = $row.Cells[3]

    foreach ($field in @(
      @{ Name = 'Class'; Value = $class },
      @{ Name = 'Review'; Value = $review },
      @{ Name = 'Owner'; Value = $owner },
      @{ Name = 'Path'; Value = $pathCell }
    )) {
      if ([string]::IsNullOrWhiteSpace($field.Value)) {
        [void]$Errors.Add("Document registry row at line $($row.LineNumber) has an empty $($field.Name) cell")
      }
    }

    if (-not $allowedClasses.Contains($class)) {
      [void]$Errors.Add("Document registry row at line $($row.LineNumber) has invalid class: $class")
    } else {
      [void]$observedClasses.Add($class)
    }
    if (-not $allowedReviews.Contains($review)) {
      [void]$Errors.Add("Document registry row at line $($row.LineNumber) has invalid review: $review")
    }

    $logicalSeparator = [string][char]0x001F
    $logicalSignature = $class + $logicalSeparator + $review + $logicalSeparator + $owner + $logicalSeparator + $pathCell
    if (-not $logicalRows.Add($logicalSignature)) {
      [void]$Errors.Add("Document registry contains a duplicate logical row at line $($row.LineNumber)")
    }

    if ($class -eq 'OPERATOR_PLAYBOOK' -or $class -eq 'EXPERIMENTAL') {
      $noLocalOwnerCounts[$class]++
      if ($owner -cne $noLocalOwnerText -or $pathCell -cne ([string][char]0x2014)) {
        [void]$Errors.Add("$class must use the explicit no-client-local-owner row")
      }
      continue
    }

    $pathMatches = [regex]::Matches($pathCell, '`([^`\r\n]+)`')
    if ($pathMatches.Count -eq 0) {
      [void]$Errors.Add("Document registry row at line $($row.LineNumber) has no concrete backticked path")
      continue
    }

    $formattedPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($match in $pathMatches) {
      $relativePath = $match.Groups[1].Value
      [void]$formattedPaths.Add(([string][char]96) + $relativePath + ([string][char]96))

      if (-not $observedPaths.Add($relativePath)) {
        [void]$Errors.Add("Document registry contains duplicate path: $relativePath")
      }
      if (-not $expectedPathClasses.ContainsKey($relativePath)) {
        [void]$Errors.Add("Document registry contains unexpected path: $relativePath")
      } elseif ($expectedPathClasses[$relativePath] -cne $class) {
        [void]$Errors.Add("Document registry class mismatch for ${relativePath}: expected $($expectedPathClasses[$relativePath]), got $class")
      }
      Test-RegistryRelativePath -RepositoryRoot $RepositoryRoot -RelativePath $relativePath -Errors $Errors
    }

    $canonicalPathCell = $formattedPaths -join '; '
    if ($pathCell -cne $canonicalPathCell) {
      [void]$Errors.Add("Document registry path cell at line $($row.LineNumber) contains prose or non-canonical separators")
    }
  }

  if (-not $allowedClasses.SetEquals($observedClasses)) {
    [void]$Errors.Add('Document registry must represent exactly all six documentation classes')
  }
  foreach ($class in @('OPERATOR_PLAYBOOK', 'EXPERIMENTAL')) {
    if ($noLocalOwnerCounts[$class] -ne 1) {
      [void]$Errors.Add("Document registry must contain exactly one explicit no-client-local-owner row for $class")
    }
  }
  foreach ($relativePath in $expectedPathClasses.Keys) {
    if (-not $observedPaths.Contains($relativePath)) {
      [void]$Errors.Add("Document registry is missing expected path: $relativePath")
    }
  }
}

function Invoke-ClientDocsValidation {
  param(
    [string]$RepositoryRoot,
    [byte[]]$AgentsBytes,
    [byte[]]$RegistryBytes
  )

  $errors = [System.Collections.Generic.List[string]]::new()
  $agents = ConvertFrom-StrictDocumentBytes -Bytes $AgentsBytes -Name 'AGENTS.md' -MaximumBytes 8192 -MaximumLines 120 -Errors $errors
  $registry = ConvertFrom-StrictDocumentBytes -Bytes $RegistryBytes -Name 'docs/README.md' -MaximumBytes 12288 -MaximumLines 240 -Errors $errors

  if ($null -ne $agents) {
    Test-AgentContract -Text $agents.Text -Errors $errors
  }
  if ($null -ne $registry) {
    Test-DocumentationRegistry -Text $registry.Text -RepositoryRoot $RepositoryRoot -Errors $errors
  }

  return $errors.ToArray()
}

function ConvertTo-Utf8Bytes {
  param([string]$Text)
  $encoding = [Text.UTF8Encoding]::new($false, $true)
  return ,$encoding.GetBytes($Text)
}

function Assert-ContractRejected {
  param(
    [string]$Name,
    [string]$RepositoryRoot,
    [byte[]]$AgentsBytes,
    [byte[]]$RegistryBytes,
    [string]$ExpectedErrorPattern
  )

  $validationErrors = @(Invoke-ClientDocsValidation -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes $RegistryBytes)
  if ($validationErrors.Count -eq 0) {
    throw "Contract self-test '$Name' expected rejection but validation passed"
  }
  if ($ExpectedErrorPattern) {
    $matched = $false
    foreach ($errorMessage in $validationErrors) {
      if ($errorMessage -match $ExpectedErrorPattern) {
        $matched = $true
        break
      }
    }
    if (-not $matched) {
      throw "Contract self-test '$Name' rejected for the wrong reason. Errors: $($validationErrors -join ' | ')"
    }
  }
}

function Assert-ContractAccepted {
  param(
    [string]$Name,
    [string]$RepositoryRoot,
    [byte[]]$AgentsBytes,
    [byte[]]$RegistryBytes
  )

  $validationErrors = @(Invoke-ClientDocsValidation -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes $RegistryBytes)
  if ($validationErrors.Count -ne 0) {
    throw "Contract self-test '$Name' expected acceptance. Errors: $($validationErrors -join ' | ')"
  }
}

function Invoke-ContractSelfTests {
  param(
    [string]$RepositoryRoot,
    [byte[]]$AgentsBytes,
    [byte[]]$RegistryBytes
  )

  $agentsText = [Text.UTF8Encoding]::new($false, $true).GetString($AgentsBytes)
  $registryText = [Text.UTF8Encoding]::new($false, $true).GetString($RegistryBytes)

  Assert-ContractAccepted -Name 'current contract baseline' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes $RegistryBytes

  $tokenBag = "# POKROV-app Codex Contract POKROV-app/main docs/README.md Android Windows iOS macOS MANUAL_OWNER_TEST artifacts/releases git diff --check`n"
  Assert-ContractRejected -Name 'one-line AGENTS token bag' -RepositoryRoot $RepositoryRoot -AgentsBytes (ConvertTo-Utf8Bytes $tokenBag) -RegistryBytes $RegistryBytes -ExpectedErrorPattern 'exact ordered H2 section set'

  $malformedUtf8 = New-Object byte[] ($AgentsBytes.Length + 2)
  [Array]::Copy($AgentsBytes, 0, $malformedUtf8, 0, $AgentsBytes.Length)
  $malformedUtf8[$AgentsBytes.Length] = 0xC3
  $malformedUtf8[$AgentsBytes.Length + 1] = 0x28
  Assert-ContractRejected -Name 'malformed UTF-8' -RepositoryRoot $RepositoryRoot -AgentsBytes $malformedUtf8 -RegistryBytes $RegistryBytes -ExpectedErrorPattern 'not valid strict UTF-8'

  $bomAgents = New-Object byte[] ($AgentsBytes.Length + 3)
  $bomAgents[0] = 0xEF
  $bomAgents[1] = 0xBB
  $bomAgents[2] = 0xBF
  [Array]::Copy($AgentsBytes, 0, $bomAgents, 3, $AgentsBytes.Length)
  Assert-ContractRejected -Name 'UTF-8 BOM' -RepositoryRoot $RepositoryRoot -AgentsBytes $bomAgents -RegistryBytes $RegistryBytes -ExpectedErrorPattern 'BOM'

  $routingRow = '| CANONICAL | RECONCILED | Client docs routing | `docs/README.md` |'
  $deletedRowRegistry = $registryText.Replace($routingRow + "`n", '')
  Assert-ContractRejected -Name 'deleted registry row' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $deletedRowRegistry) -ExpectedErrorPattern 'missing expected path: docs/README.md'

  $registryRowsPattern = [regex]::new('(?ms)(\| Class \| Review \| Owner \| Path \|\r?\n\| --- \| --- \| --- \| --- \|\r?\n)(?:\|.*\|\r?\n)+')
  $emptyRegistry = $registryRowsPattern.Replace($registryText, '$1', 1)
  Assert-ContractRejected -Name 'all registry rows deleted' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $emptyRegistry) -ExpectedErrorPattern 'must represent exactly all six'

  $invalidReviewRegistry = $registryText.Replace($routingRow, '| CANONICAL | APPROVED | Client docs routing | `docs/README.md` |')
  Assert-ContractRejected -Name 'invalid review enum' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $invalidReviewRegistry) -ExpectedErrorPattern 'invalid review: APPROVED'

  $invalidClassRegistry = $registryText.Replace($routingRow, '| CURRENT | RECONCILED | Client docs routing | `docs/README.md` |')
  Assert-ContractRejected -Name 'invalid registry class' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $invalidClassRegistry) -ExpectedErrorPattern 'invalid class: CURRENT'

  $invalidPathRegistry = $registryText.Replace($routingRow, '| CANONICAL | RECONCILED | Client docs routing | `../outside.md` |')
  Assert-ContractRejected -Name 'escaping registry path' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $invalidPathRegistry) -ExpectedErrorPattern "must not contain '.' or '..' segments"

  $backslashPathRegistry = $registryText.Replace($routingRow, '| CANONICAL | RECONCILED | Client docs routing | `docs\README.md` |')
  Assert-ContractRejected -Name 'non-normalized backslash registry path' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $backslashPathRegistry) -ExpectedErrorPattern 'must use forward slashes'

  $duplicateRowRegistry = $registryText.Replace($routingRow, $routingRow + "`n" + $routingRow)
  Assert-ContractRejected -Name 'duplicate registry row' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $duplicateRowRegistry) -ExpectedErrorPattern 'duplicate logical row'

  $duplicateRouteTable = @'
| Task | Read first | Inspect | Verify | Docs impact |
| --- | --- | --- | --- | --- |
'@
  $duplicateTableRegistry = $registryText.Replace('## Classes And Review State', $duplicateRouteTable + "`n## Classes And Review State")
  Assert-ContractRejected -Name 'duplicate route table' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $duplicateTableRegistry) -ExpectedErrorPattern 'header must appear exactly once'

  $unexpectedRouteRegistry = $registryText.Replace('| Shell, UI, or copy |', '| Unplanned route |')
  Assert-ContractRejected -Name 'unexpected route' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $unexpectedRouteRegistry) -ExpectedErrorPattern 'exact required nine-route set'

  $activePlansAgents = $agentsText.Replace('## Repository Boundary', "- Do not copy active plans into this contract.`n`n## Repository Boundary")
  Assert-ContractRejected -Name 'retained active-plans prohibition' -RepositoryRoot $RepositoryRoot -AgentsBytes (ConvertTo-Utf8Bytes $activePlansAgents) -RegistryBytes $RegistryBytes -ExpectedErrorPattern 'active plans'

  $genericModelAgents = $agentsText.Replace('## Repository Boundary', "- Keep the local data model explicit in code and tests.`n`n## Repository Boundary")
  Assert-ContractAccepted -Name 'generic data model wording' -RepositoryRoot $RepositoryRoot -AgentsBytes (ConvertTo-Utf8Bytes $genericModelAgents) -RegistryBytes $RegistryBytes

  $backtickFence = @'
````markdown
| Task | Read first | Inspect | Verify | Docs impact |
| --- | --- | --- | --- | --- |
```
| Class | Review | Owner | Path |
| --- | --- | --- | --- |
````
'@
  $backtickFenceRegistry = $registryText + "`n" + $backtickFence + "`n"
  Assert-ContractAccepted -Name 'long backtick fence ignores shorter marker and table examples' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $backtickFenceRegistry)

  $tildeFence = @'
~~~~markdown
| Task | Read first | Inspect | Verify | Docs impact |
| --- | --- | --- | --- | --- |
~~~
| Class | Review | Owner | Path |
| --- | --- | --- | --- |
~~~~
'@
  $tildeFenceRegistry = $registryText + "`n" + $tildeFence + "`n"
  Assert-ContractAccepted -Name 'long tilde fence ignores shorter marker and table examples' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $tildeFenceRegistry)
}

$agentsPath = Join-Path $root 'AGENTS.md'
$registryPath = Join-Path $root 'docs\README.md'
if (-not (Test-Path -LiteralPath $agentsPath -PathType Leaf)) {
  throw 'Client docs contract failed: AGENTS.md is required'
}
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
  throw 'Client docs contract failed: docs/README.md is required'
}

[byte[]]$agentsBytes = [IO.File]::ReadAllBytes($agentsPath)
[byte[]]$registryBytes = [IO.File]::ReadAllBytes($registryPath)
Invoke-ContractSelfTests -RepositoryRoot $root -AgentsBytes $agentsBytes -RegistryBytes $registryBytes

$errors = @(Invoke-ClientDocsValidation -RepositoryRoot $root -AgentsBytes $agentsBytes -RegistryBytes $registryBytes)
if ($errors.Count -gt 0) {
  throw "Client docs contract failed:`n$($errors -join "`n")"
}

Write-Host 'Client docs contract OK.' -ForegroundColor Green
