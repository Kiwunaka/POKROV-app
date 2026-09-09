# Installed client checks, 2026-09-09

Client `c05b58b268bbd789aa96fb662cb46c9768558ef0`, Core source
`c7a11f7d2fd974726095ad7aa0619c055273dd15` (same tree as promoted `7444e53`).
These are development bytes, not a new candidate or a replacement verdict
for retained candidate.33. [Receipt](receipt.json) binds the retained files.

## Physical Huawei — RU-origin

All four Android ABI packages passed their signer, native pin and notices audit.
The ARM64 APK SHA-256
`d030288a672b654a70db593f512416113fd2e8ad12025237b94a422c9613f510`
was installed with `adb install -r` on Huawei ADA-AL00U, API31, preserving app data.
The prior APK remains locally available for rollback. This installation receipt
preceded runtime testing and correctly retains its original PENDING fields.

Warsaw whitelist profile: FAIL_EGRESS_UNCONFIRMED. DNS and routes were ready,
but the UI withheld the protected claim and showed a warning. This failure is
retained separately; the successful Frankfurt checks do not erase it.

Frankfurt ordinary profile: three samples at 06:35:55, 06:36:35 and 06:37:33 UTC
show foreground VpnService, tun0, assigned routes, DNS ready, confirmed egress
and protection. Wi-Fi was on, then off with mobile data enabled, then restored.
The diagnostics sheet was manually refreshed after each network change. These
samples support that bounded network-switch check, not a whole platform matrix.
`checked_time` is null because the capture parser did not read the content-desc
time field; the transport-types list contains reported capabilities, not a
unique assertion of the active physical network. Wi-Fi was restored afterwards.

The profile screen still lacked subscription and Telegram-link data. An owned
account API read took 16.102 seconds, exceeding the client's 15-second timeout;
the platform fix is PR #247 and remains under validation. Installed AWG, the
Warsaw defect, full final-candidate checks and public release remain open.

## Windows

The current source built and packaged locally, but its installer did not complete
in the existing managed Windows VM: UAC dispatch ended with
`DISPATCH_FAILED / InvalidOperationException` after computer control was stopped.
The previous service remained installed. No PASS for current installation,
Authenticode or current Windows connectivity follows from the package build.
The owner-accepted unsigned beta exception remains a skip of trusted signing.

After the owner explicitly resumed VM testing, the same installer completed with
exit 0 at 07:04:35 UTC. Readback matched all 304 expected files; persisted session
and secure-store hashes were unchanged, and POKROVService was Running as
LocalSystem. This supersedes only the installation blocker above; the failed
first dispatch remains retained. Current connectivity checks are still running.

Validation: `pwsh -NoProfile -File scripts/validate-seed.ps1 -PlatformRoot
C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot
E:/r12core-implementation` — PASS; `git diff --check` — PASS; no release artifact
delta. Earlier validation attempts failed on missing inferred Core path, .NET API
in Windows PowerShell, and placement of the new note beyond the docs header
budget. Explicit paths, PowerShell Core and moving the note below the candidate
table resolved those failures without changing product code.
