# Windows adapter cleanup binding — 2026-09-12

`binding.json` binds Core 880bff65ad665844828fe50fc395e9cfc1cd81b4 to the
development Android/Windows consumer. Earlier device/package receipts retain
their original binary identities.

- `native/`: exact reproducible builds, raw and corrected source SBOMs,
  corrected evidence receipts, binary composition and native Go build info.
- `native-test-result.json`, source inventories and probe logs: both original
  cleanup failures, fixed callback tests, and bounded native Core checks.
  The native test receipt explicitly records that full raw output was not retained.
- `windows-abi-proxy.json` and host network digests: exact DLL ABI and 100 Dart
  proxy cycles with unchanged host routes/DNS; no host TUN test.
- `binary-scans/` and `static-triage-binding.json`: five current Go scans and
  bounded comparison with the previous nine-advisory review. Zero extracted
  symbols does not establish zero reachable vulnerabilities. Raw binary SBOM
  local path/(devel) identifiers are not authoritative upstream source versions.
- `notices-preparation.json`: 191 unchanged verbatim license blocks. Its old
  source_ref labels identify the input inventory; the shipped notice references
  the current Core commit. Complete licensing/source clearance remains open.

Consumer checks pass: 81 runtime Flutter tests (one optional DLL test skipped in
the generic run and passed separately), 8 Android Flutter tests, seed/docs
contracts and exact runtime sync. Installed acceptance remains pending. No public release or
promotion is established by this directory.
