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

  if ($Bytes.Length -eq 0) { return $false }
  $prefix = [BitConverter]::ToString($Bytes, 0, [Math]::Min(4, $Bytes.Length)).Replace('-', '')
  return $prefix.StartsWith('EFBBBF') -or $prefix.StartsWith('FEFF') -or
    $prefix.StartsWith('FFFE') -or $prefix.StartsWith('0000FEFF') -or
    $prefix.StartsWith('FFFE0000')
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

function New-ExpectedRegistryManifest {
  $encodedRows = @(
    'CANONICAL|RECONCILED|Client docs routing|docs/README.md',
    'CANONICAL|RECONCILED|Client repository overview|README.md',
    'CANONICAL|RECONCILED|Client design system|DESIGN.md',
    'CANONICAL|RECONCILED|Client product|docs/product/client-product-contract.md',
    'CANONICAL|RECONCILED|App-first onboarding|docs/architecture/app-first-onboarding-flow.md',
    'CANONICAL|RECONCILED|Client persisted state and migrations|docs/architecture/persisted-state-contract.md',
    'CANONICAL|RECONCILED|Platform privilege and runtime boundaries|docs/architecture/platform-privilege-runtime-contract.md',
    'CANONICAL|REVIEWED_NO_CHANGE|Repository structure|docs/architecture/folder-structure.md',
    'CANONICAL|RECONCILED|Package boundaries|docs/architecture/package-boundaries.md',
    'CANONICAL|RECONCILED|Runtime bootstrap|docs/architecture/bootstrap-workflow.md',
    'CANONICAL|RECONCILED|Active POKROV Core 1.1.0 pre-candidate runtime binding|docs/decisions/2026-08-23-pokrov-core-1.1.0-pre-candidate-binding.md',
    'CANONICAL|RECONCILED|In-app assistant|docs/architecture/in-app-ai-assistant-contract.md',
    'CANONICAL|RECONCILED|Current product/UI direction|docs/design/2026-06-13-pokrov-product-ui-direction.md',
    'EVIDENCE|RECONCILED|Completed motion/HIG implementation record|docs/design/2026-07-13-agent-uiux-backlog.md',
    'CANONICAL|RECONCILED|Machine product facts|config/product-contract.seed.json',
    'CANONICAL|RECONCILED|Support-mode signing public trust root|config/support-signing.seed.json',
    'CANONICAL|RECONCILED|Public/readiness platform scope|config/platform-matrix.seed.json',
    'CANONICAL|REVIEWED_NO_CHANGE|Runtime profile facts|config/runtime-profile.seed.json',
    'CANONICAL|RECONCILED|Cutover readiness facts|config/cutover-readiness.seed.json',
    'CANONICAL|RECONCILED|Release handoff facts|config/release-handoff.seed.json',
    'CANONICAL|RECONCILED|Stable release pointer and rollback targets|config/release-rollback-catalog.seed.json',
    'ACTIVE_EXECUTION|RECONCILED|Client release execution|docs/implementation/client-release-backlog.md',
    'ACTIVE_EXECUTION|RECONCILED|Cutover checklist|docs/operations/cutover-readiness.md',
    'ACTIVE_EXECUTION|RECONCILED|Android readiness|docs/operations/android-release-audit.md',
    'ACTIVE_EXECUTION|RECONCILED|Windows readiness|docs/operations/windows-release-readiness.md',
    'ACTIVE_EXECUTION|RECONCILED|WARP runtime proof|docs/operations/warp-runtime-proof-checklist.md',
    'ACTIVE_EXECUTION|REVIEWED_NO_CHANGE|Responsive proof|docs/operations/responsive-golden-capture-plan.md',
    'ACTIVE_EXECUTION|REVIEWED_NO_CHANGE|Motion/performance proof|docs/operations/client-motion-performance-checklist.md',
    'ACTIVE_EXECUTION|RECONCILED|Apple readiness|docs/operations/apple-release-readiness.md',
    'EVIDENCE|RECONCILED|Readiness snapshots before current/history split|docs/implementation/history/;docs/operations/history/',
    'EVIDENCE|REVIEWED_NO_CHANGE|Public beta product evidence|docs/product/client-public-beta-prd.md',
    'EVIDENCE|REVIEWED_NO_CHANGE|Dated handoffs and closure audits|docs/operations/2026-06-04-public-beta-operator-handoff.md;docs/operations/2026-06-05-phase-6-release-beta-handoff.md;docs/operations/2026-06-05-final-beta-closure-except-manual-tests-signing.md;docs/operations/2026-06-13-pokrov-product-ui-plan-closure-audit.md',
    'EVIDENCE|REVIEWED_NO_CHANGE|Client/API additions record|docs/operations/client-ui-api-additions.md',
    'EVIDENCE|REVIEWED_NO_CHANGE|Retained beta work order|docs/developer/work-orders/2026-04-open-beta-v4/INDEX.md',
    'EVIDENCE|REVIEWED_NO_CHANGE|Completed implementation maps|docs/implementation/2026-06-03-client-build-readiness-and-api-plan.md;docs/implementation/2026-06-03-client-mvp-shell-implementation.md;docs/implementation/2026-06-04-decisions-implementation-map.md;docs/implementation/2026-06-05-p6-overload-correction-plan.md',
    'HISTORICAL_REFERENCE|RECONCILED|Superseded POKROV Core 1.0.0 runtime decision|docs/decisions/2026-07-23-pokrov-core-1.0.0-activation.md',
    'HISTORICAL_REFERENCE|RECONCILED|Superseded POKROV Core 1.0.2 runtime decision|docs/decisions/2026-08-04-pokrov-core-1.0.2-release.md',
    'HISTORICAL_REFERENCE|RECONCILED|Retained public POKROV Core 1.0.3 runtime decision|docs/decisions/2026-08-13-pokrov-core-1.0.3-release.md',
    'HISTORICAL_REFERENCE|RECONCILED|Superseded local design entry|docs/design/DESIGN.md',
    'HISTORICAL_REFERENCE|REVIEWED_NO_CHANGE|Earlier scaffold spec|docs/specs/2026-04-18-wave-7-new-base-client-scaffold.md',
    'HISTORICAL_REFERENCE|REVIEWED_NO_CHANGE|Completed WARP design spec|docs/specs/2026-06-05-p5-warp-approved-design.md',
    'HISTORICAL_REFERENCE|REVIEWED_NO_CHANGE|Earlier UX master brief|docs/decisions/2026-06-03-client-ux-account-rewards-master-brief.md',
    'HISTORICAL_REFERENCE|REVIEWED_NO_CHANGE|Earlier responsive review|docs/decisions/2026-06-03-client-chat-responsive-warp-motion-review.md',
    'HISTORICAL_REFERENCE|REVIEWED_NO_CHANGE|Earlier MVP consilium|docs/decisions/2026-06-03-client-best-mvp-consilium.md',
    'HISTORICAL_REFERENCE|REVIEWED_NO_CHANGE|Retired Karing reopen input|docs/decisions/2026-06-02-karing-base-reopen.md',
    'HISTORICAL_REFERENCE|REVIEWED_NO_CHANGE|Retired clean-room gate input|docs/decisions/2026-04-18-karing-vs-clean-room-gate.md',
    'HISTORICAL_REFERENCE|REVIEWED_NO_CHANGE|Earlier premium-shell brief|docs/design/2026-06-03-client-premium-shell-v2-brief.md',
    'HISTORICAL_REFERENCE|REVIEWED_NO_CHANGE|Earlier visual/copy briefs|docs/design/2026-06-03-client-screen-component-rules.md;docs/design/2026-06-03-client-quiet-emerald-style-brief.md;docs/design/2026-06-03-client-chat-responsive-warp-motion-brief.md;docs/design/2026-06-03-client-best-mvp-build-brief.md',
    'HISTORICAL_REFERENCE|REVIEWED_NO_CHANGE|Completed application-map briefs|docs/design/2026-06-05-p5-warp-application-map.md;docs/design/2026-06-05-p5-application-map-consilium-review.md;docs/design/2026-06-05-p6-overload-ux-consilium.md',
    'HISTORICAL_REFERENCE|UNRESOLVED_OWNER_DECISION|Generated visual references|docs/design/assets/;docs/design/generated/2026-06-09-app-screen-variants/',
    'HISTORICAL_REFERENCE|REVIEWED_NO_CHANGE|Archived completed plans|docs/archive/',
    'OPERATOR_PLAYBOOK|REVIEWED_NO_CHANGE|no client-local owner; platform tools do not enter the client default route|<NO_LOCAL_OWNER>',
    'EXPERIMENTAL|REVIEWED_NO_CHANGE|no client-local owner; platform tools do not enter the client default route|<NO_LOCAL_OWNER>'
  )

  $manifest = [System.Collections.Generic.List[object]]::new()
  $logicalKeys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $separator = [string][char]0x001F
  foreach ($encodedRow in $encodedRows) {
    $fields = $encodedRow -split '\|', 4
    if ($fields.Count -ne 4) { throw "Invalid embedded registry manifest row: $encodedRow" }
    $paths = $(if ($fields[3] -ceq '<NO_LOCAL_OWNER>') { @() } else { [string[]]($fields[3] -split ';') })
    $logicalKey = $fields[0] + $separator + $fields[2]
    if (-not $logicalKeys.Add($logicalKey)) { throw "Duplicate embedded registry logical key: $logicalKey" }
    [void]$manifest.Add([pscustomobject]@{
      Class = $fields[0]
      Review = $fields[1]
      Owner = $fields[2]
      Paths = $paths
      LogicalKey = $logicalKey
    })
  }
  if ($manifest.Count -ne 53) { throw "Embedded registry manifest must contain 53 rows, got $($manifest.Count)" }
  return $manifest.ToArray()
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

function Get-AgentContractStructure {
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

  $sections = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
  for ($headingIndex = 0; $headingIndex -lt $headingPositions.Count; $headingIndex++) {
    $start = $headingPositions[$headingIndex] + 1
    $end = $(if ($headingIndex + 1 -lt $headingPositions.Count) { $headingPositions[$headingIndex + 1] - 1 } else { $visible.Count - 1 })
    $nonEmpty = 0
    $listItems = 0
    $bodyLines = [System.Collections.Generic.List[string]]::new()
    for ($lineIndex = $start; $lineIndex -le $end; $lineIndex++) {
      if ($lineIndex -lt 0 -or $lineIndex -ge $visible.Count) { continue }
      $line = $visible[$lineIndex].Text
      [void]$bodyLines.Add($line)
      if (-not [string]::IsNullOrWhiteSpace($line)) { $nonEmpty++ }
      if ($line -match '^\s*(?:- |\d+\.\s+)') { $listItems++ }
    }
    if ($nonEmpty -eq 0 -or $listItems -eq 0) {
      [void]$Errors.Add("AGENTS.md section '$($headingNames[$headingIndex])' must contain meaningful list content")
    }
    if (-not $sections.ContainsKey($headingNames[$headingIndex])) {
      $sections.Add($headingNames[$headingIndex], ($bodyLines -join "`n"))
    }
  }

  $h1Position = -1
  if ($h1Lines.Count -eq 1) {
    for ($index = 0; $index -lt $visible.Count; $index++) {
      if ($visible[$index].LineNumber -eq $h1Lines[0].LineNumber) {
        $h1Position = $index
        break
      }
    }
  }
  $firstHeadingPosition = $(if ($headingPositions.Count -gt 0) { $headingPositions[0] } else { $visible.Count })
  $preambleLines = [System.Collections.Generic.List[string]]::new()
  for ($index = $h1Position + 1; $index -lt $firstHeadingPosition; $index++) {
    if ($index -ge 0 -and $index -lt $visible.Count) {
      [void]$preambleLines.Add($visible[$index].Text)
    }
  }
  $preamble = $preambleLines -join "`n"
  if ([string]::IsNullOrWhiteSpace($preamble)) {
    [void]$Errors.Add('AGENTS.md preamble must state the repository boundary')
  }

  return [pscustomobject]@{
    Preamble = $preamble
    Sections = $sections
    HeadingNames = $headingNames.ToArray()
  }
}

function Test-AgentContract {
  param(
    [string]$Text,
    [System.Collections.Generic.List[string]]$Errors
  )

  $structure = Get-AgentContractStructure -Text $Text -Errors $Errors
  $scopeTexts = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
  $scopeTexts.Add('Preamble', $structure.Preamble)
  foreach ($sectionName in $structure.Sections.Keys) {
    $scopeTexts.Add($sectionName, $structure.Sections[$sectionName])
  }

  $contracts = [ordered]@{
    'Preamble' = @(
      'canonical client-development lane for POKROV',
      'Promote client work through `POKROV-app/main`',
      'The separate platform repository owns backend behavior, public web surfaces, and cross-surface shared facts'
    )
    'Start Every Task' = @(
      'Classify the task with the route in `docs/README.md`',
      'State the intended write set, authority owners, verification, and documentation impact',
      'Inspect current code, tests, Git worktrees, and conflicting evidence',
      'Never edit or clean another branch or worktree'
    )
    'Authority' = @(
      'Task authority: Codex system/developer instructions',
      'Intended product authority: owner-approved decisions and machine-readable contracts',
      'current code/tests',
      'When code and intended canon disagree, record the conflict',
      'Archive and evidence can explain why a decision happened'
    )
    'Repository Boundary' = @(
      '`Android` and `Windows` are the current public outside-store client surfaces',
      '`iOS` and `macOS` are readiness tracks only',
      'Platform-owned facts and API contracts live under `C:/Users/kiwun/Documents/ai/VPN/shared/`',
      'Client product, shell, runtime, host integration, and client release-readiness truth belongs in this repository'
    )
    'Runtime And Security' = @(
      'Do not replace the default runtime core',
      'alter tunnel or WARP lifecycle',
      'tokens, credentials, signing material, private keys, raw profiles, and provider data',
      'Never downgrade secure storage to plaintext',
      'Signing identities, entitlements, provisioning, device proof, and store access are operator-owned gates'
    )
    'Evidence And Destructive Operations' = @(
      'Do not modify `artifacts/releases/**`',
      'Preserve audit evidence, retained release lineage, historical decisions, and generated references',
      'Never run broad clean, reset, stash drop, worktree removal, recursive deletion, or bulk regeneration',
      'Machine-local files are not automatically disposable'
    )
    'Release Honesty' = @(
      'Never infer stable, signed, store-ready, device-proven, WARP-proven, or publicly downloadable status',
      '`MANUAL_OWNER_TEST`, `BLOCKED_BY_ACCESS`, `SKIPPED_BY_OWNER`, `OPERATOR_ATTESTED`, or `NOT_REQUESTED`',
      'Documentation-only work must not run Android or Windows release builds'
    )
    'Verification And Documentation' = @(
      'run the narrowest relevant Flutter analyze/tests first',
      'Android host changes: run focused Flutter and Gradle tests',
      'Docs/config changes: run `powershell -ExecutionPolicy Bypass -File .\scripts\validate-seed.ps1`',
      'Every task runs `git diff --check`',
      'Update the owning canonical doc in the same task',
      'Handoff with changed files, commands and results, remaining manual gates, blockers, and rollback notes'
    )
  }

  foreach ($ownerScope in $contracts.Keys) {
    $ownerText = $(if ($scopeTexts.ContainsKey($ownerScope)) { $scopeTexts[$ownerScope] } else { '' })
    foreach ($marker in $contracts[$ownerScope]) {
      if ($ownerText.IndexOf($marker, [StringComparison]::Ordinal) -lt 0) {
        [void]$Errors.Add("AGENTS.md $ownerScope is missing section-owned semantic marker '$marker'")
      }
      foreach ($otherScope in $scopeTexts.Keys) {
        if ($otherScope -cne $ownerScope -and
            $scopeTexts[$otherScope].IndexOf($marker, [StringComparison]::Ordinal) -ge 0) {
          [void]$Errors.Add("AGENTS.md semantic marker '$marker' belongs to $ownerScope but appears in $otherScope")
        }
      }
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

  $expectedManifest = @(New-ExpectedRegistryManifest)
  $expectedPathClasses = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
  $expectedRowsByKey = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
  foreach ($expectedRow in $expectedManifest) {
    $expectedRowsByKey.Add($expectedRow.LogicalKey, $expectedRow)
    foreach ($relativePath in $expectedRow.Paths) {
      if ($expectedPathClasses.ContainsKey($relativePath)) {
        throw "Duplicate path in embedded registry manifest: $relativePath"
      }
      $expectedPathClasses.Add($relativePath, $expectedRow.Class)
    }
  }
  if ($expectedPathClasses.Count -ne 64) {
    throw "Embedded registry manifest must contain 64 concrete paths, got $($expectedPathClasses.Count)"
  }
  if ($registryTable.Rows.Count -ne $expectedManifest.Count) {
    [void]$Errors.Add("Document registry must match the exact 53-row manifest (actual rows: $($registryTable.Rows.Count))")
  }

  $observedClasses = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $observedPaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $logicalKeys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $logicalSeparator = [string][char]0x001F

  for ($rowIndex = 0; $rowIndex -lt $registryTable.Rows.Count; $rowIndex++) {
    $row = $registryTable.Rows[$rowIndex]
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

    $logicalKey = $class + $logicalSeparator + $owner
    if (-not $logicalKeys.Add($logicalKey)) {
      [void]$Errors.Add("Document registry contains a duplicate logical key at line $($row.LineNumber): $class / $owner")
    } elseif (-not $expectedRowsByKey.ContainsKey($logicalKey)) {
      [void]$Errors.Add("Document registry contains an unexpected logical key at line $($row.LineNumber): $class / $owner")
    }

    $actualPaths = [System.Collections.Generic.List[string]]::new()
    $pathMatches = [regex]::Matches($pathCell, '`([^`\r\n]+)`')
    foreach ($match in $pathMatches) {
      [void]$actualPaths.Add($match.Groups[1].Value)
    }

    if ($pathCell -ceq ([string][char]0x2014)) {
      if ($actualPaths.Count -ne 0) {
        [void]$Errors.Add("Document registry sentinel row at line $($row.LineNumber) must not contain concrete paths")
      }
    } elseif ($actualPaths.Count -eq 0) {
      [void]$Errors.Add("Document registry row at line $($row.LineNumber) has no concrete backticked path")
    } else {
      $canonicalPathCell = ConvertTo-RegistryPathCell -Paths $actualPaths.ToArray()
      if ($pathCell -cne $canonicalPathCell) {
        [void]$Errors.Add("Document registry path cell at line $($row.LineNumber) contains prose or non-canonical separators")
      }
    }

    foreach ($relativePath in $actualPaths) {
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

    if ($expectedRowsByKey.ContainsKey($logicalKey)) {
      $expectedRow = $expectedRowsByKey[$logicalKey]
      if ($review -cne $expectedRow.Review -or -not (Test-StringArraysEqual -Left $actualPaths.ToArray() -Right $expectedRow.Paths)) {
        [void]$Errors.Add("Document registry logical row '$class / $owner' does not match the embedded exact manifest")
      }
      $expectedPathCell = $(if ($expectedRow.Paths.Count -eq 0) { [string][char]0x2014 } else { ConvertTo-RegistryPathCell -Paths $expectedRow.Paths })
      if ($pathCell -cne $expectedPathCell) {
        [void]$Errors.Add("Document registry logical row '$class / $owner' does not preserve its ordered path group")
      }
    }
  }

  if (-not $allowedClasses.SetEquals($observedClasses)) {
    [void]$Errors.Add('Document registry must represent exactly all six documentation classes')
  }
  foreach ($relativePath in $expectedPathClasses.Keys) {
    if (-not $observedPaths.Contains($relativePath)) {
      [void]$Errors.Add("Document registry is missing expected path: $relativePath")
    }
  }
  foreach ($expectedRow in $expectedManifest) {
    if (-not $logicalKeys.Contains($expectedRow.LogicalKey)) {
      [void]$Errors.Add("Document registry is missing expected logical row: $($expectedRow.Class) / $($expectedRow.Owner)")
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
  $registry = ConvertFrom-StrictDocumentBytes -Bytes $RegistryBytes -Name 'docs/README.md' -MaximumBytes 12800 -MaximumLines 240 -Errors $errors

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

function ConvertTo-MarkdownTableRow {
  param([string[]]$Cells)
  return '| ' + ($Cells -join ' | ') + ' |'
}

function ConvertTo-RegistryPathCell {
  param([string[]]$Paths)

  $formatted = [System.Collections.Generic.List[string]]::new()
  foreach ($path in $Paths) {
    [void]$formatted.Add(([string][char]96) + $path + ([string][char]96))
  }
  return $formatted -join '; '
}

function Edit-MarkdownTableRows {
  param(
    [string]$Text,
    [string[]]$Header,
    [scriptblock]$Mutation,
    [int]$ExpectedMutationCount,
    [object[]]$MutationArguments = @()
  )

  $parseErrors = [System.Collections.Generic.List[string]]::new()
  $visible = @(Get-VisibleMarkdownLines -Text $Text -Name 'self-test fixture' -Errors $parseErrors)
  $table = Get-UniqueMarkdownTable -VisibleLines $visible -Header $Header -Name 'self-test table' -Errors $parseErrors
  if ($parseErrors.Count -ne 0) {
    throw "Cannot parse self-test table: $($parseErrors -join ' | ')"
  }

  $rows = [System.Collections.Generic.List[object]]::new()
  foreach ($row in $table.Rows) {
    $cellCopy = New-Object string[] $row.Cells.Count
    [Array]::Copy($row.Cells, $cellCopy, $row.Cells.Count)
    [void]$rows.Add([pscustomobject]@{ Cells = $cellCopy })
  }

  $mutationOutput = @(& $Mutation $rows @MutationArguments)
  if ($mutationOutput.Count -ne 1 -or [int]$mutationOutput[0] -ne $ExpectedMutationCount) {
    throw "Self-test mutation count mismatch. Expected $ExpectedMutationCount, got $($mutationOutput -join ', ')"
  }

  $physicalLines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in [regex]::Split($Text, "\r\n|\n|\r")) {
    [void]$physicalLines.Add($line)
  }
  $dataStartIndex = $(if ($table.Rows.Count -gt 0) { $table.Rows[0].LineNumber - 1 } else { $table.HeaderLine + 1 })
  for ($index = 0; $index -lt $table.Rows.Count; $index++) {
    $physicalLines.RemoveAt($dataStartIndex)
  }
  for ($index = 0; $index -lt $rows.Count; $index++) {
    $physicalLines.Insert($dataStartIndex + $index, (ConvertTo-MarkdownTableRow -Cells $rows[$index].Cells))
  }
  return $physicalLines -join "`n"
}

function Get-ExpectedRegistryRowByOwner {
  param([string]$Owner)

  $matches = @(New-ExpectedRegistryManifest | Where-Object { $_.Owner -ceq $Owner })
  if ($matches.Count -ne 1) {
    throw "Expected exactly one embedded manifest row for owner '$Owner', got $($matches.Count)"
  }
  return $matches[0]
}

function Find-RegistryRowIndex {
  param(
    [System.Collections.Generic.List[object]]$Rows,
    [object]$ExpectedRow
  )

  $matches = @()
  for ($index = 0; $index -lt $Rows.Count; $index++) {
    if ($Rows[$index].Cells.Count -eq 4 -and
        $Rows[$index].Cells[0] -ceq $ExpectedRow.Class -and
        $Rows[$index].Cells[2] -ceq $ExpectedRow.Owner) {
      $matches += $index
    }
  }
  if ($matches.Count -ne 1) {
    throw "Expected one parsed row for '$($ExpectedRow.Class) / $($ExpectedRow.Owner)', got $($matches.Count)"
  }
  return $matches[0]
}

function Set-RegistryRowCell {
  param([string]$Text, [string]$Owner, [int]$CellIndex, [string]$Value)

  $mutation = {
    param($rows, $ownerArgument, $cellIndexArgument, $valueArgument)
    $index = Find-RegistryRowIndex -Rows $rows -ExpectedRow (Get-ExpectedRegistryRowByOwner -Owner $ownerArgument)
    $rows[$index].Cells[$cellIndexArgument] = $valueArgument
    return 1
  }
  return Edit-MarkdownTableRows -Text $Text -Header @('Class', 'Review', 'Owner', 'Path') -Mutation $mutation -ExpectedMutationCount 1 -MutationArguments @($Owner, $CellIndex, $Value)
}

function Copy-TableCells {
  param([string[]]$Cells)

  $copy = New-Object string[] $Cells.Count
  [Array]::Copy($Cells, $copy, $Cells.Count)
  return ,$copy
}

function Move-AgentLineBetweenSections {
  param(
    [string]$Text,
    [string]$Marker,
    [string]$SourceSection,
    [string]$TargetSection
  )

  $lines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in [regex]::Split($Text, "\r\n|\n|\r")) { [void]$lines.Add($line) }
  $currentSection = 'Preamble'
  $sourceMatches = @()
  for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match '^## (?<name>.+?)\s*$') { $currentSection = $Matches['name']; continue }
    if ($currentSection -ceq $SourceSection -and $lines[$index].Contains($Marker)) { $sourceMatches += $index }
  }
  if ($sourceMatches.Count -ne 1) { throw "Expected one source marker '$Marker', got $($sourceMatches.Count)" }
  $movedLine = $lines[$sourceMatches[0]]
  $lines.RemoveAt($sourceMatches[0])

  $targetMatches = @()
  for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -ceq "## $TargetSection") { $targetMatches += $index }
  }
  if ($targetMatches.Count -ne 1) { throw "Expected one target section '$TargetSection', got $($targetMatches.Count)" }
  $lines.Insert($targetMatches[0] + 1, $movedLine)
  return $lines -join "`n"
}

function Assert-StrictBytesRejected {
  param([string]$Name, [byte[]]$Bytes, [string]$ExpectedErrorPattern)

  $fixtureErrors = [System.Collections.Generic.List[string]]::new()
  [void](ConvertFrom-StrictDocumentBytes -Bytes $Bytes -Name $Name -MaximumBytes 128 -MaximumLines 16 -Errors $fixtureErrors)
  if ($fixtureErrors.Count -eq 0 -or -not (($fixtureErrors -join ' | ') -match $ExpectedErrorPattern)) {
    throw "Strict-byte self-test '$Name' did not fail as expected: $($fixtureErrors -join ' | ')"
  }
}

function Assert-TableParserFixture {
  param([string]$Name, [string]$Text, [bool]$ShouldPass)

  $fixtureErrors = [System.Collections.Generic.List[string]]::new()
  $visible = @(Get-VisibleMarkdownLines -Text $Text -Name $Name -Errors $fixtureErrors)
  $table = Get-UniqueMarkdownTable -VisibleLines $visible -Header @('Key', 'Value') -Name $Name -Errors $fixtureErrors
  $passed = $fixtureErrors.Count -eq 0 -and $table.Rows.Count -eq 1 -and $table.Rows[0].Cells[0] -ceq 'real'
  if ($passed -ne $ShouldPass) {
    throw "Table-parser self-test '$Name' produced unexpected result. Errors: $($fixtureErrors -join ' | ')"
  }
}

function Get-GitAttributeEolRules {
  param([string[]]$Lines)

  $rules = [System.Collections.Generic.List[string]]::new()
  foreach ($rawLine in $Lines) {
    $line = $rawLine.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith('#', [StringComparison]::Ordinal)) {
      continue
    }

    [string[]]$tokens = @($line -split '\s+')
    if ($tokens.Count -lt 2) {
      continue
    }
    for ($index = 1; $index -lt $tokens.Count; $index++) {
      if ($tokens[$index] -cmatch '^eol=\S+$') {
        [void]$rules.Add($line)
      }
    }
  }
  return $rules.ToArray()
}

function Assert-GitAttributeEolParserFixture {
  param([string]$Name, [string[]]$Lines, [string[]]$ExpectedRules)

  $actualRules = @(Get-GitAttributeEolRules -Lines $Lines)
  if (-not (Test-StringArraysEqual -Left $actualRules -Right $ExpectedRules)) {
    $expectedText = $ExpectedRules -join ', '
    $actualText = $actualRules -join ', '
    throw "Git-attribute parser self-test '$Name' expected '$expectedText' but got '$actualText'"
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

  $decorativeSections = @'
# POKROV-app Codex Contract
POKROV-app/main

## Start Every Task
- docs/README.md Android Windows iOS macOS MANUAL_OWNER_TEST artifacts/releases git diff --check

## Authority
- Decorative authority words.

## Repository Boundary
- Decorative repository words.

## Runtime And Security
- Decorative runtime words.

## Evidence And Destructive Operations
- Decorative safety words.

## Release Honesty
- Decorative release words.

## Verification And Documentation
- Decorative verification words.
'@
  Assert-ContractRejected -Name 'decorative seven-section token bag' -RepositoryRoot $RepositoryRoot -AgentsBytes (ConvertTo-Utf8Bytes ($decorativeSections + "`n")) -RegistryBytes $RegistryBytes -ExpectedErrorPattern 'section-owned semantic marker'

  Assert-StrictBytesRejected -Name 'malformed UTF-8 fixture' -Bytes ([byte[]]@(0x61, 0xC3, 0x28, 0x0A)) -ExpectedErrorPattern 'not valid strict UTF-8'
  Assert-StrictBytesRejected -Name 'UTF-8 BOM fixture' -Bytes ([byte[]]@(0xEF, 0xBB, 0xBF, 0x61, 0x0A)) -ExpectedErrorPattern 'BOM'
  Assert-GitAttributeEolParserFixture -Name 'comment eol example' -Lines @('# example: eol=crlf') -ExpectedRules @()
  Assert-GitAttributeEolParserFixture -Name 'eol-shaped pattern' -Lines @('eol=fixture text') -ExpectedRules @()
  Assert-GitAttributeEolParserFixture -Name 'real eol attribute' -Lines @('AGENTS.md text eol=crlf') -ExpectedRules @('AGENTS.md text eol=crlf')

  $registryHeader = @('Class', 'Review', 'Owner', 'Path')
  $deletedRowRegistry = Edit-MarkdownTableRows -Text $registryText -Header $registryHeader -ExpectedMutationCount 1 -Mutation {
    param($rows)
    $index = Find-RegistryRowIndex -Rows $rows -ExpectedRow (Get-ExpectedRegistryRowByOwner -Owner 'Client docs routing')
    $rows.RemoveAt($index)
    return 1
  }
  Assert-ContractRejected -Name 'deleted registry row' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $deletedRowRegistry) -ExpectedErrorPattern 'exact 53-row manifest'

  $emptyRegistry = Edit-MarkdownTableRows -Text $registryText -Header $registryHeader -ExpectedMutationCount 53 -Mutation {
    param($rows)
    $removed = $rows.Count
    $rows.Clear()
    return $removed
  }
  Assert-ContractRejected -Name 'all registry rows deleted' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $emptyRegistry) -ExpectedErrorPattern 'exact 53-row manifest'

  $invalidReviewRegistry = Set-RegistryRowCell -Text $registryText -Owner 'Client docs routing' -CellIndex 1 -Value 'APPROVED'
  Assert-ContractRejected -Name 'invalid review enum' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $invalidReviewRegistry) -ExpectedErrorPattern 'invalid review: APPROVED'

  $invalidClassRegistry = Set-RegistryRowCell -Text $registryText -Owner 'Client docs routing' -CellIndex 0 -Value 'CURRENT'
  Assert-ContractRejected -Name 'invalid registry class' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $invalidClassRegistry) -ExpectedErrorPattern 'invalid class: CURRENT'

  $invalidPathRegistry = Set-RegistryRowCell -Text $registryText -Owner 'Client docs routing' -CellIndex 3 -Value (ConvertTo-RegistryPathCell -Paths @('../outside.md'))
  Assert-ContractRejected -Name 'escaping registry path' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $invalidPathRegistry) -ExpectedErrorPattern "must not contain '.' or '..' segments"

  $ownerChangedRegistry = Set-RegistryRowCell -Text $registryText -Owner 'Client docs routing' -CellIndex 2 -Value 'Client documentation routing'
  Assert-ContractRejected -Name 'live owner prose changed without manifest update' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $ownerChangedRegistry) -ExpectedErrorPattern 'unexpected logical key'

  $duplicateRowRegistry = Edit-MarkdownTableRows -Text $registryText -Header $registryHeader -ExpectedMutationCount 1 -Mutation {
    param($rows)
    $index = Find-RegistryRowIndex -Rows $rows -ExpectedRow (Get-ExpectedRegistryRowByOwner -Owner 'Client docs routing')
    $rows.Insert($index + 1, [pscustomobject]@{ Cells = (Copy-TableCells -Cells $rows[$index].Cells) })
    return 1
  }
  Assert-ContractRejected -Name 'duplicate registry row' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $duplicateRowRegistry) -ExpectedErrorPattern 'duplicate logical key'

  $unexpectedRouteRegistry = Edit-MarkdownTableRows -Text $registryText -Header @('Task', 'Read first', 'Inspect', 'Verify', 'Docs impact') -ExpectedMutationCount 1 -Mutation {
    param($rows)
    $matches = @()
    for ($index = 0; $index -lt $rows.Count; $index++) {
      if ($rows[$index].Cells[0] -ceq 'Shell, UI, or copy') { $matches += $index }
    }
    if ($matches.Count -ne 1) { throw "Expected one shell route, got $($matches.Count)" }
    $rows[$matches[0]].Cells[0] = 'Unplanned route'
    return 1
  }
  Assert-ContractRejected -Name 'unexpected route' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $unexpectedRouteRegistry) -ExpectedErrorPattern 'exact required nine-route set'

  $splitRegistry = Edit-MarkdownTableRows -Text $registryText -Header $registryHeader -ExpectedMutationCount 1 -Mutation {
    param($rows)
    $expected = Get-ExpectedRegistryRowByOwner -Owner 'Dated handoffs and closure audits'
    if ($expected.Paths.Count -ne 4) { throw "Expected four manifest paths, got $($expected.Paths.Count)" }
    $targetIndex = Find-RegistryRowIndex -Rows $rows -ExpectedRow $expected
    $firstCells = Copy-TableCells -Cells $rows[$targetIndex].Cells
    $secondCells = Copy-TableCells -Cells $rows[$targetIndex].Cells
    $firstCells[3] = ConvertTo-RegistryPathCell -Paths $expected.Paths[0..1]
    $secondCells[3] = ConvertTo-RegistryPathCell -Paths $expected.Paths[2..3]
    $rows[$targetIndex] = [pscustomobject]@{ Cells = $firstCells }
    $rows.Insert($targetIndex + 1, [pscustomobject]@{ Cells = $secondCells })
    return 1
  }
  Assert-ContractRejected -Name 'four-path registry row split' -RepositoryRoot $RepositoryRoot -AgentsBytes $AgentsBytes -RegistryBytes (ConvertTo-Utf8Bytes $splitRegistry) -ExpectedErrorPattern 'exact 53-row manifest'

  $wrongSectionAgents = Move-AgentLineBetweenSections -Text $agentsText -Marker 'Every task runs `git diff --check`' -SourceSection 'Verification And Documentation' -TargetSection 'Start Every Task'
  Assert-ContractRejected -Name 'verification marker moved to wrong section' -RepositoryRoot $RepositoryRoot -AgentsBytes (ConvertTo-Utf8Bytes $wrongSectionAgents) -RegistryBytes $RegistryBytes -ExpectedErrorPattern 'belongs to Verification And Documentation'

  $backtickFenceFixture = @'
````markdown
| Key | Value |
| --- | --- |
```
| Key | Value |
| --- | --- |
````
| Key | Value |
| --- | --- |
| real | row |
'@
  Assert-TableParserFixture -Name 'long backtick fence' -Text $backtickFenceFixture -ShouldPass $true

  $tildeFenceFixture = @'
~~~~markdown
| Key | Value |
| --- | --- |
~~~
| Key | Value |
| --- | --- |
~~~~
| Key | Value |
| --- | --- |
| real | row |
'@
  Assert-TableParserFixture -Name 'long tilde fence' -Text $tildeFenceFixture -ShouldPass $true

  $duplicateTableFixture = @'
| Key | Value |
| --- | --- |
| real | row |

| Key | Value |
| --- | --- |
| duplicate | row |
'@
  Assert-TableParserFixture -Name 'duplicate real table' -Text $duplicateTableFixture -ShouldPass $false
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

$attributesPath = Join-Path $root '.gitattributes'
if (-not (Test-Path -LiteralPath $attributesPath -PathType Leaf)) {
  $errors += '.gitattributes is required'
} else {
  $attributeLines = [IO.File]::ReadAllLines($attributesPath)
  $requiredLineEndingPaths = @(
    'AGENTS.md',
    'docs/README.md',
    'packages/app_shell/test/fixtures/app-first-session-v0.json',
    'packages/app_shell/test/fixtures/secure-session-v0.txt',
    'packages/app_shell/test/fixtures/client-experience-v0.json',
    'packages/app_shell/test/fixtures/routing-preferences-v0.json',
    'apps/android_shell/android/app/src/test/resources/runtime-profile-v0.properties'
  )
  $requiredLineEndingAttributes = @(
    $requiredLineEndingPaths | ForEach-Object { "$_ text eol=lf" }
  )

  foreach ($requiredAttribute in $requiredLineEndingAttributes) {
    $matches = @($attributeLines | Where-Object { $_ -ceq $requiredAttribute })
    if ($matches.Count -ne 1) {
      $errors += ".gitattributes must contain exactly one explicit '$requiredAttribute' rule"
    }
  }

  $lineEndingAttributeRules = @(Get-GitAttributeEolRules -Lines $attributeLines)
  $unexpectedLineEndingAttributes = @(
    $lineEndingAttributeRules | Where-Object { $requiredLineEndingAttributes -cnotcontains $_ }
  )
  if ($unexpectedLineEndingAttributes.Count -gt 0) {
    $errors += ".gitattributes must not define additional eol attributes beyond the approved client contract and migration fixture files: $($unexpectedLineEndingAttributes -join ', ')"
  }

  $effectiveAttributeOutput = @(& git -C $root check-attr text eol -- @requiredLineEndingPaths 2>&1)
  $effectiveAttributeExitCode = $LASTEXITCODE
  if ($effectiveAttributeExitCode -ne 0) {
    $errors += "git check-attr failed with exit $effectiveAttributeExitCode`: $($effectiveAttributeOutput -join ' | ')"
  } else {
    $effectiveAttributes = @{}
    $escapedEffectivePaths = ($requiredLineEndingPaths | ForEach-Object { [regex]::Escape($_) }) -join '|'
    foreach ($outputLine in $effectiveAttributeOutput) {
      $line = $outputLine.ToString()
      $match = [regex]::Match(
        $line,
        "^(?<path>$escapedEffectivePaths): (?<attribute>text|eol): (?<value>\S+)$"
      )
      if (-not $match.Success) {
        $errors += "git check-attr returned unexpected output: $line"
        continue
      }

      $key = "$($match.Groups['path'].Value)|$($match.Groups['attribute'].Value)"
      if ($effectiveAttributes.ContainsKey($key)) {
        $errors += "git check-attr returned duplicate output for $key"
        continue
      }
      $effectiveAttributes[$key] = $match.Groups['value'].Value
    }

    $requiredEffectiveAttributes = [ordered]@{}
    foreach ($requiredLineEndingPath in $requiredLineEndingPaths) {
      $requiredEffectiveAttributes["$requiredLineEndingPath|text"] = 'set'
      $requiredEffectiveAttributes["$requiredLineEndingPath|eol"] = 'lf'
    }
    foreach ($key in $requiredEffectiveAttributes.Keys) {
      if (-not $effectiveAttributes.ContainsKey($key)) {
        $errors += "git check-attr did not return $key"
      } elseif ($effectiveAttributes[$key] -cne $requiredEffectiveAttributes[$key]) {
        $errors += "git check-attr must resolve $key to '$($requiredEffectiveAttributes[$key])' (actual: '$($effectiveAttributes[$key])')"
      }
    }
  }
}

$bootstrapWorkspaceScript = [IO.File]::ReadAllText((Join-Path $root 'scripts\bootstrap-workspace.ps1'))
$androidWrapperContractStartMarker = '$androidWrapperRelativePaths = @('
$androidWrapperRepairStartMarker = 'if ($missingAndroidWrapperFiles.Count -gt 0) {'
$androidWrapperContractEndMarker = '$workspacePackages = @('
$androidWrapperContractStartIndex = $bootstrapWorkspaceScript.IndexOf($androidWrapperContractStartMarker, [StringComparison]::Ordinal)
$androidWrapperRepairStartIndex = $bootstrapWorkspaceScript.IndexOf($androidWrapperRepairStartMarker, [StringComparison]::Ordinal)
$androidWrapperContractEndIndex = $bootstrapWorkspaceScript.IndexOf($androidWrapperContractEndMarker, [StringComparison]::Ordinal)
$androidWrapperRepairCommand = 'flutter create --platforms=android --no-pub --no-overwrite --org space.pokrov --project-name pokrov_android_shell .'
$validAndroidWrapperBoundaries = $androidWrapperContractStartIndex -ge 0 -and
  $androidWrapperRepairStartIndex -gt $androidWrapperContractStartIndex -and
  $androidWrapperContractEndIndex -gt $androidWrapperRepairStartIndex
if (-not $validAndroidWrapperBoundaries) {
  $errors += 'Workspace bootstrap lacks one isolated Android wrapper repair contract block'
} else {
  $androidWrapperContractBlock = $bootstrapWorkspaceScript.Substring(
    $androidWrapperContractStartIndex,
    $androidWrapperContractEndIndex - $androidWrapperContractStartIndex
  )
  $androidWrapperRepairBlock = $bootstrapWorkspaceScript.Substring(
    $androidWrapperRepairStartIndex,
    $androidWrapperContractEndIndex - $androidWrapperRepairStartIndex
  )
  $androidWrapperRepairIndex = $androidWrapperRepairBlock.IndexOf($androidWrapperRepairCommand, [StringComparison]::Ordinal)
  if ($androidWrapperRepairIndex -lt 0) {
    $errors += 'Workspace bootstrap isolated repair lacks supported no-overwrite Flutter Android generation'
  }

  foreach ($requiredMarker in @(
    '[IO.Path]::GetTempPath()',
    '[Guid]::NewGuid().ToString("N")',
    '$androidWrapperRepairLocationPushed = $false',
    'Push-Location -LiteralPath $androidWrapperRepairPath -ErrorAction Stop',
    '$androidWrapperRepairLocationPushed = $true',
    'if ($androidWrapperRepairLocationPushed) {',
    'Pop-Location -ErrorAction Stop',
    'Copy-Item -LiteralPath $sourceAndroidWrapperFile -Destination $destinationAndroidWrapperFile -ErrorAction Stop',
    'Test-AndroidWrapperRepairPath -Path $androidWrapperRepairPath -TempRoot $androidWrapperRepairTempRoot',
    'Remove-Item -LiteralPath $androidWrapperRepairPath -Recurse -Force -ErrorAction Stop'
  )) {
    if ($androidWrapperRepairBlock.IndexOf($requiredMarker, [StringComparison]::Ordinal) -lt 0) {
      $errors += "Workspace bootstrap lacks isolated Android wrapper repair marker: $requiredMarker"
    }
  }
  if ($androidWrapperRepairBlock.IndexOf('Push-Location $androidShellPath', [StringComparison]::Ordinal) -ge 0) {
    $errors += 'Flutter Android wrapper repair must not run in the tracked Android shell project'
  }

  $exactAndroidWrapperPathBlock = @'
$androidWrapperRelativePaths = @(
  "android\gradlew",
  "android\gradlew.bat",
  "android\gradle\wrapper\gradle-wrapper.jar"
)
'@
  if ($androidWrapperContractBlock.IndexOf($exactAndroidWrapperPathBlock, [StringComparison]::Ordinal) -lt 0) {
    $errors += 'Workspace bootstrap Android wrapper copy contract must contain exactly the Unix/BAT/JAR relative path set'
  }

  if ($androidWrapperRepairIndex -ge 0) {
    $postRepairValidation = $androidWrapperRepairBlock.Substring($androidWrapperRepairIndex + $androidWrapperRepairCommand.Length)
    foreach ($requiredMarker in @(
      '$androidWrapperRepairExitCode -ne 0',
      'foreach ($androidWrapperFile in $androidWrapperFiles)',
      'Test-Path -LiteralPath $androidWrapperFile -PathType Leaf',
      'Flutter Android wrapper repair did not materialize required file'
    )) {
      if ($postRepairValidation.IndexOf($requiredMarker, [StringComparison]::Ordinal) -lt 0) {
        $errors += "Workspace bootstrap lacks post-repair Android Unix/BAT/JAR validation marker: $requiredMarker"
      }
    }

    $destinationGuard = 'if (-not (Test-Path -LiteralPath $destinationAndroidWrapperFile -PathType Leaf)) {'
    $copyCommand = 'Copy-Item -LiteralPath $sourceAndroidWrapperFile -Destination $destinationAndroidWrapperFile -ErrorAction Stop'
    $destinationGuardIndex = $postRepairValidation.IndexOf($destinationGuard, [StringComparison]::Ordinal)
    $copyCommandIndex = $postRepairValidation.IndexOf($copyCommand, [StringComparison]::Ordinal)
    if ($destinationGuardIndex -lt 0 -or $copyCommandIndex -lt 0 -or $destinationGuardIndex -gt $copyCommandIndex) {
      $errors += 'Workspace bootstrap Android wrapper copy must be guarded against destination overwrite'
    }

    $cleanupCommand = 'Remove-Item -LiteralPath $androidWrapperRepairPath -Recurse -Force -ErrorAction Stop'
    $cleanupIndex = $postRepairValidation.IndexOf($cleanupCommand, [StringComparison]::Ordinal)
    if ($cleanupIndex -lt 0) {
      $errors += 'Workspace bootstrap lacks verified Android wrapper repair temp cleanup'
    } else {
      $postCleanupValidation = $postRepairValidation.Substring($cleanupIndex + $cleanupCommand.Length)
      foreach ($requiredMarker in @(
        'Test-Path -LiteralPath $androidWrapperRepairPath',
        'Flutter Android wrapper repair temp cleanup left a directory'
      )) {
        if ($postCleanupValidation.IndexOf($requiredMarker, [StringComparison]::Ordinal) -lt 0) {
          $errors += "Workspace bootstrap lacks post-cleanup Android temp validation marker: $requiredMarker"
        }
      }
    }
  }
}

$forbiddenByFile = @{
  'README.md' = @(
    'no release wiring',
    'Selected-apps parity is still outside this cycle'
  )
  'docs\architecture\app-first-onboarding-flow.md' = @('0.x.x-beta')
  'docs\architecture\bootstrap-workflow.md' = @(
    'per-app Android parity remains deferred'
  )
  'docs\architecture\in-app-ai-assistant-contract.md' = @(
    'If ticket APIs are not enough for live AI help'
  )
}

foreach ($relativePath in $forbiddenByFile.Keys) {
  $text = [IO.File]::ReadAllText((Join-Path $root $relativePath))
  foreach ($forbidden in $forbiddenByFile[$relativePath]) {
    if ($text.Contains($forbidden)) {
      $errors += "$relativePath contains stale text: $forbidden"
    }
  }
}

$product = [IO.File]::ReadAllText((Join-Path $root 'config\product-contract.seed.json')) | ConvertFrom-Json
$platform = [IO.File]::ReadAllText((Join-Path $root 'config\platform-matrix.seed.json')) | ConvertFrom-Json
$release = [IO.File]::ReadAllText((Join-Path $root 'config\release-handoff.seed.json')) | ConvertFrom-Json
$cutover = [IO.File]::ReadAllText((Join-Path $root 'config\cutover-readiness.seed.json')) | ConvertFrom-Json
$runtime = [IO.File]::ReadAllText((Join-Path $root 'config\runtime-profile.seed.json')) | ConvertFrom-Json
$supportSigning = [IO.File]::ReadAllText((Join-Path $root 'config\support-signing.seed.json')) | ConvertFrom-Json
$windowsRelease = [IO.File]::ReadAllText((Join-Path $root 'config\windows-release.seed.json')) | ConvertFrom-Json
$androidGradle = [IO.File]::ReadAllText((Join-Path $root 'apps\android_shell\android\app\build.gradle'))
$androidProductionBuild = [IO.File]::ReadAllText((Join-Path $root 'scripts\build-android-production.ps1'))
$windowsProductionBuild = [IO.File]::ReadAllText((Join-Path $root 'scripts\build-windows-release.ps1'))
$workspaceTests = [IO.File]::ReadAllText((Join-Path $root 'scripts\run-tests.ps1'))

if ([int]$supportSigning.schema_version -ne 1 -or
    $supportSigning.algorithm -ne 'Ed25519' -or
    $supportSigning.purpose -ne 'support-mode-policy-v2' -or
    $supportSigning.status -ne 'active' -or
    $supportSigning.key_id -ne 'pokrov-support-2026-08' -or
    $supportSigning.public_key_b64url -ne 'sTi6tP7u_vBZq-zf8gR-6ocHjwZiCZSQ-h0-967J8eE' -or
    $supportSigning.public_key_sha256 -ne '44aed43310eaf5442b3493cbe566b5f0f620a5660bb84a6bd028832114f48845') {
  $errors += 'Support signing seed does not match the active public trust root'
}
foreach ($productionBuild in @($androidProductionBuild, $windowsProductionBuild)) {
  foreach ($requiredSupportPinMarker in @(
    'support-signing-pin.ps1',
    'Resolve-PokrovSupportSigningPin',
    'POKROV_SUPPORT_SIGNING_KEY_ID',
    'POKROV_SUPPORT_SIGNING_PUBLIC_KEY_B64'
  )) {
    if (-not $productionBuild.Contains($requiredSupportPinMarker)) {
      $errors += "Production build lacks support signing source-binding marker: $requiredSupportPinMarker"
    }
  }
}
if (-not $workspaceTests.Contains('test\support-signing-pin-contract.ps1')) {
  $errors += 'Workspace standard gate does not run the support signing pin contract'
}

if ($product.client_version_line -ne $release.latest_repo_backed_release.version) {
  $errors += 'Product and release version lines disagree'
}
$developmentTarget = $release.release_truth.development_target
if ($developmentTarget.product_version -ne '1.2.0' -or
    [int]$developmentTarget.platform_build -ne 30 -or
    $developmentTarget.package_version -ne '1.2.0+30' -or
    $developmentTarget.state -ne 'PRE_CANDIDATE_LOCAL' -or
    $developmentTarget.candidate_created -ne $false) {
  $errors += 'Release handoff development target must remain exact uncreated 1.2.0+30 pre-candidate truth'
}
if ($cutover.latest_repo_backed_release.github_release -ne $release.latest_repo_backed_release.github_release) {
  $errors += 'Cutover and release-handoff URLs disagree'
}
if ($cutover.latest_repo_backed_release.github_repo_visibility -ne 'public') {
  $errors += 'Cutover seed still describes the release repo as private'
}
if ($cutover.latest_repo_backed_release.anonymous_download_smoke -notmatch '^PASS_') {
  $errors += 'Cutover seed lacks public anonymous-download proof'
}
if ($product.trial_days -ne $runtime.trial_days -or
    $product.telegram_bonus_days -ne $runtime.telegram_bonus_days) {
  $errors += 'Product and runtime trial/reward facts disagree'
}

foreach ($requiredAndroidSigningMarker in @(
  'ANDROID_SIGNING_KEY',
  'ANDROID_SIGNING_STORE_PASSWORD',
  'ANDROID_SIGNING_KEY_PASSWORD',
  'ANDROID_SIGNING_KEY_ALIAS',
  'pokrov.allowInternalBetaDebugSigning',
  'hasProductionReleaseSigning',
  'releaseArtifactTaskRequested',
  '/^assemble.*Release$/',
  '/^bundle.*Release$/',
  '/^package.*Release(?:Bundle|UniversalApk)?$/',
  '/^sign.*ReleaseBundle$/',
  'releaseArtifactTaskRequested && !hasProductionReleaseSigning && !allowInternalBetaDebugSigning'
)) {
  if (-not $androidGradle.Contains($requiredAndroidSigningMarker)) {
    $errors += "Android release signing config lacks fail-closed marker: $requiredAndroidSigningMarker"
  }
}

if (-not $androidGradle.Contains('keepDebugSymbols += ["**/libpokrov-core.so"]')) {
  $errors += 'Android release packaging must preserve the exact published POKROV Core ELF identity'
}

foreach ($requiredDirectBuildMarker in @(
  '"--flavor", "direct"',
  'app-direct-release.apk',
  'app-arm64-v8a-direct-release.apk',
  'app-armeabi-v7a-direct-release.apk',
  'app-x86_64-direct-release.apk'
)) {
  if (-not $androidProductionBuild.Contains($requiredDirectBuildMarker)) {
    $errors += "Android production builder lacks direct-flavor marker: $requiredDirectBuildMarker"
  }
}
foreach ($requiredFlavorTestTask in @(
  ':app:testDirectDebugUnitTest',
  ':app:testStoreDebugUnitTest'
)) {
  if (-not $workspaceTests.Contains($requiredFlavorTestTask)) {
    $errors += "Workspace test gate lacks Android flavor task: $requiredFlavorTestTask"
  }
}

if ($windowsRelease.signing.status -ne 'MISSING' -or
    $windowsRelease.signing.blocker_code -ne 'MISSING_TRUSTED_WINDOWS_SIGNATURE' -or
    $windowsRelease.signing.required_for_candidate -ne $true -or
    $windowsRelease.signing.contract -ne 'AUTHENTICODE_SHA256_RFC3161_HTTPS_V1') {
  $errors += 'Windows release seed does not preserve the fail-closed trusted-signing contract'
}
foreach ($requiredWindowsSignedFile in @(
  'pokrov_windows.exe',
  'pokrov_service.exe',
  'pokrov-windows-x64-{version}-setup.exe',
  'unins???.exe'
)) {
  if (@($windowsRelease.signing.required_signed_files) -notcontains $requiredWindowsSignedFile) {
    $errors += "Windows signing contract lacks required signed file: $requiredWindowsSignedFile"
  }
}
foreach ($requiredWindowsSigningMarker in @(
  'RequireTrustedWindowsSigning',
  'POKROV_WINDOWS_SIGNING_CERTIFICATE_THUMBPRINT',
  'POKROV_WINDOWS_SIGNING_EXPECTED_SUBJECT',
  'POKROV_WINDOWS_SIGNING_TIMESTAMP_URL',
  'Self-signed certificates cannot satisfy trusted Windows signing.',
  'Get-AuthenticodeSignature',
  'TimeStamperCertificate',
  'SignTool=POKROV',
  'SignedUninstaller=yes',
  'SignedUninstallerDir=',
  '/SPOKROV=',
  '"PASS"',
  'MISSING_TRUSTED_WINDOWS_SIGNATURE'
)) {
  if (-not $windowsProductionBuild.Contains($requiredWindowsSigningMarker)) {
    $errors += "Windows production builder lacks fail-closed signing marker: $requiredWindowsSigningMarker"
  }
}
foreach ($forbiddenWindowsSigningMarker in @(
  'PFX_PASSWORD',
  'SIGNING_PASSWORD',
  'SecureStringToBSTR'
)) {
  if ($windowsProductionBuild.Contains($forbiddenWindowsSigningMarker)) {
    $errors += "Windows production builder must not accept private-key password material: $forbiddenWindowsSigningMarker"
  }
}

if ($release.release_truth.public_cutover_allowed -ne $cutover.public_cutover_allowed) {
  $errors += 'Cutover and release-handoff public approval disagree'
}
if (($release.latest_repo_backed_release.runtime_sync_allowed -eq $true) -and
    ($release.release_truth.public_cutover_allowed -ne $true) -and
    ($cutover.android_release.public_approved -ne $true) -and
    ($cutover.windows_release.public_approved -ne $true)) {
  $errors += 'Release handoff allows runtime sync without a public-approved platform artifact'
}
if (($cutover.public_cutover_allowed -eq $true) -and
    (($cutover.android_release.public_approved -ne $true) -or
     ($cutover.windows_release.public_approved -ne $true))) {
  $errors += 'Cutover seed allows global public cutover while a public platform gate is blocked'
}

$androidArtifacts = @($release.latest_repo_backed_release.artifacts | Where-Object { $_.platform -eq 'android' })
$windowsArtifacts = @($release.latest_repo_backed_release.artifacts | Where-Object { $_.platform -eq 'windows' })
$androidApprovedArtifacts = @($androidArtifacts | Where-Object { $_.public_approved -eq $true })
$windowsApprovedArtifacts = @($windowsArtifacts | Where-Object { $_.public_approved -eq $true })

foreach ($requiredPublicTarget in @('android', 'windows')) {
  if (@($platform.public_release_targets) -notcontains $requiredPublicTarget) {
    $errors += "Platform matrix lacks public release target: $requiredPublicTarget"
  }
}

$currentAndroidReadiness = 'direct_apk_1_1_6_public_stable_runtime_synced_exact_huawei_followup_manual'
$currentWindowsReadiness = 'outside_store_unsigned_1_1_6_public_stable_runtime_synced_new_promotion_blocked_pending_trusted_signing'
if ($platform.release_readiness.android -ne $currentAndroidReadiness) {
  $errors += 'Platform matrix Android readiness is not aligned with retained public 1.1.6 truth'
}
if ($platform.release_readiness.windows -ne $currentWindowsReadiness) {
  $errors += 'Platform matrix Windows readiness is not aligned with retained public 1.1.6 truth'
}
if ($cutover.android_release.public_approved -ne $true -and
    $platform.release_readiness.android -notmatch 'blocked') {
  $errors += 'Platform matrix does not preserve the blocked Android promotion state'
}
if ($cutover.windows_release.public_approved -ne $true -and
    $platform.release_readiness.windows -notmatch 'blocked') {
  $errors += 'Platform matrix does not preserve the blocked Windows promotion state'
}
if ($cutover.android_release.public_approved -eq $true -and
    $platform.release_readiness.android -match 'blocked') {
  $errors += 'Platform matrix keeps Android blocked while cutover approves it'
}
if ($cutover.windows_release.public_approved -eq $true -and
    $platform.release_readiness.windows -match 'blocked') {
  $errors += 'Platform matrix keeps Windows blocked while cutover approves it'
}

if ($release.latest_repo_backed_release.version -eq '1.0.0-beta') {
  if ($release.latest_repo_backed_release.recorded_publication_state -ne
      'PUBLISHED_2026_BETA_WITH_OWNER_ACCEPTED_SIGNING_SKIPS') {
    $errors += 'Retained 1.0.0-beta lacks its historical publication-state label'
  }
  if ($release.latest_repo_backed_release.reuse_for_new_promotion -ne $false) {
    $errors += 'Retained 1.0.0-beta can be reused for a new promotion'
  }
  if (($release.latest_repo_backed_release.signing_evidence.android -ne 'SKIPPED_BY_OWNER') -or
      ($release.latest_repo_backed_release.signing_evidence.windows -ne 'SKIPPED_BY_OWNER')) {
    $errors += 'Retained 1.0.0-beta signing evidence does not preserve owner-accepted skips'
  }
}

if ($androidApprovedArtifacts.Count -gt 0) {
  if ($cutover.android_release.public_approved -ne $true) {
    $errors += 'Release handoff public-approves Android while the Android cutover gate is blocked'
  }
  if ($release.latest_repo_backed_release.signing_evidence.android -ne 'PASS') {
    $errors += 'Release handoff public-approves Android without exact-candidate production-signing PASS'
  }
}

if ($cutover.android_release.public_approved -eq $true) {
  if ($androidApprovedArtifacts.Count -eq 0) {
    $errors += 'Android cutover is approved without a matching public-approved artifact'
  }
  if ($release.latest_repo_backed_release.signing_evidence.android -ne 'PASS') {
    $errors += 'Android cutover is approved without exact-candidate production-signing PASS'
  }
}

if ($windowsApprovedArtifacts.Count -gt 0) {
  if ($cutover.windows_release.public_approved -ne $true) {
    $errors += 'Release handoff public-approves Windows while the Windows cutover gate is blocked'
  }
  if (($windowsRelease.public_approved -ne $true) -or
      ($release.latest_repo_backed_release.signing_evidence.windows -ne 'PASS')) {
    $errors += 'Release handoff public-approves Windows without exact-candidate trusted-signing PASS'
  }
}

if ($cutover.windows_release.public_approved -eq $true) {
  if ($windowsApprovedArtifacts.Count -eq 0) {
    $errors += 'Windows cutover is approved without a matching public-approved artifact'
  }
  if (($windowsRelease.public_approved -ne $true) -or
      ($release.latest_repo_backed_release.signing_evidence.windows -ne 'PASS')) {
    $errors += 'Windows cutover is approved without exact-candidate trusted-signing PASS'
  }
}

$legacyDesign = [IO.File]::ReadAllText((Join-Path $root 'docs\design\DESIGN.md'))
$backlog = [IO.File]::ReadAllText((Join-Path $root 'docs\implementation\client-release-backlog.md'))
$windows = [IO.File]::ReadAllText((Join-Path $root 'docs\operations\windows-release-readiness.md'))
$warp = [IO.File]::ReadAllText((Join-Path $root 'docs\operations\warp-runtime-proof-checklist.md'))
$registry = [IO.File]::ReadAllText((Join-Path $root 'docs\README.md'))

$currentReadinessPaths = @(
  'docs\implementation\client-release-backlog.md',
  'docs\operations\cutover-readiness.md',
  'docs\operations\android-release-audit.md',
  'docs\operations\windows-release-readiness.md',
  'docs\operations\warp-runtime-proof-checklist.md',
  'docs\operations\responsive-golden-capture-plan.md',
  'docs\operations\client-motion-performance-checklist.md',
  'docs\operations\apple-release-readiness.md'
)
$historicalStatusMarkers = @(
  '`1.0.0-beta` client shell',
  'direct Android release is production-signed `1.1.2`',
  'superseded local `1.0.3+11`',
  'production-signed `1.0.4+13`',
  '## Current 2026-08-13 Candidate',
  '## Prior Builds',
  '## Retained Pre-Service'
)
foreach ($relativePath in $currentReadinessPaths) {
  $currentText = [IO.File]::ReadAllText((Join-Path $root $relativePath))
  if (-not $currentText.Contains('Registry class: `ACTIVE_EXECUTION`.')) {
    $errors += "Active readiness document lacks explicit ACTIVE_EXECUTION class: $relativePath"
  }
  foreach ($marker in $historicalStatusMarkers) {
    if ($currentText.Contains($marker)) {
      $errors += "Active readiness document mixes retained candidate state '$marker': $relativePath"
    }
  }
}

$readinessSnapshots = @(
  'docs\implementation\history\2026-08-21-client-release-backlog-snapshot.md',
  'docs\operations\history\2026-08-21-cutover-readiness-snapshot.md',
  'docs\operations\history\2026-08-19-android-release-audit-snapshot.md',
  'docs\operations\history\2026-08-21-windows-release-readiness-snapshot.md',
  'docs\operations\history\2026-08-13-warp-runtime-proof-snapshot.md',
  'docs\operations\history\2026-08-22-responsive-golden-capture-plan-snapshot.md'
)
foreach ($relativePath in $readinessSnapshots) {
  $snapshotText = [IO.File]::ReadAllText((Join-Path $root $relativePath))
  if (-not $snapshotText.Contains('Document class: `EVIDENCE`') -or
      -not $snapshotText.Contains('cannot authorize a new candidate or promotion')) {
    $errors += "Readiness snapshot lacks evidence-only boundary: $relativePath"
  }
}

foreach ($currentFact in @('`1.1.6`', '`1.2.0+30`', '`PRE_CANDIDATE_LOCAL`', '| Candidate created | `false` |')) {
  if (-not $backlog.Contains($currentFact)) {
    $errors += "Client backlog lacks current release fact: $currentFact"
  }
}

if (-not $legacyDesign.Contains('HISTORICAL_REFERENCE') -or
    -not $legacyDesign.Contains('../../DESIGN.md')) {
  $errors += 'Legacy client design doc lacks superseded pointer'
}
if ($backlog.Contains('0.x.x-beta')) {
  $errors += 'Client backlog contains stale beta version line'
}
if (-not ($windows + $warp).Contains('MANUAL_OWNER_TEST')) {
  $errors += 'Windows/WARP docs lack manual proof boundary'
}
if (-not $registry.Contains('EVIDENCE')) {
  $errors += 'Client registry lacks evidence classification'
}
if ($windows.Contains('this lane is shipping truth or release truth for Windows')) {
  $errors += 'Windows readiness contradicts current outside-store beta release truth'
}
if ($warp.Contains('Literal `WARP`, WireGuard material')) {
  $errors += 'WARP checklist still forbids the approved user-visible WARP label'
}
if ($registry.Contains('| PENDING_COLLISION_REVIEW |')) {
  $errors += 'Client registry still contains unresolved collision-review state'
}

if ($errors.Count -gt 0) {
  throw "Client docs contract failed:`n$($errors -join "`n")"
}

Write-Host 'Client docs contract OK.' -ForegroundColor Green
