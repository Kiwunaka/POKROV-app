# Installed Windows control-plane outage — 2026-09-08

**PASS_BOUNDED** for unchanged installed client `e88dff9` / Core `02a091c`,
Windows 11 `10.0.26200`, owned VirtualBox VM with NAT, managed AWG3.1,
current-origin. All 305 installed files match before and after. Installer
SHA-256: `29a87a13906909e400037a947f1e4f876ca59821e7e34c73060e623f2d9fbeea`.
The [receipt](receipt.json) binds 13 phase samples, 23 continuous observations,
cache comparison metadata and 44 retained artifacts. No application code or
package changed; complete N02/N07 and final channel remain open.

| Scenario | Observed result |
| --- | --- |
| Fresh online connect | Running/Core/DNS/egress proof; fresh profile saved at 06:43:49.127336 UTC |
| Established tunnel under simulated outage | 23 healthy observations over 61,023 ms; same UI and service PIDs |
| Disconnect/reconnect with outage | Fresh runtime proof; connected event identifies cached settings |
| Stop/relaunch UI, then connect with outage | New UI PID; cached connected event and fresh runtime proof |
| Remove outage and ordinary reconnect | Fresh online event; server observation updates to 06:54:39.360313 UTC |

Two exact program-scoped outbound firewall rules block TCP 80/443 from the
stock UI and a PowerShell control process. A control request fails with
ConnectFailure while a separate Curl request to owned `/health` returns 200.
Core and Curl are not targeted. This simulates unavailable client web/control
traffic; the live API is not shut down and this is not a carrier-side outage.
ActiveStore rule states are retained for every sample.

The downloaded/proven cache's original timestamp, binding hash, revision hash,
payload hash and cache-entry hash remain identical across all seven blocked
phase samples. The UI restart reloads the protected cache into a new process.
Only a later online refresh creates a new timestamp and cache entry. A read-only
collector uses DPAPI inside the same ordinary guest account and emits only
timestamps and comparison hashes. It does not write the store or export raw
profiles, credentials, keys or connection material.

All four explicit disconnects restore the original routes/DNS; TUN count is zero.
All 488 preexisting firewall rules and selected filters remain unchanged.
Both temporary rules and the click task are absent at completion, UI is stopped,
the auto LocalSystem service is running before shutdown, and 305 files match.
Original backend rollout is fully restored; VM off/NIC none, source VM off,
host routes/DNS unchanged. The existing IPC helper's embedded `0218e89` labels
only its build; its exact hash is retained separately from application identity.

Actual 24-hour expiry, explicit 401/403 and remote revocation on installed bytes,
other network-side/API-only outage variants, Win10, independent route/effective
location proof and exact final-channel acceptance remain open. The observation
does not grant indefinite offline access or replace those gates. No build,
push, promotion, publication, deploy or release-artifact mutation occurred.

Commands: guest `firewall.ps1 -Mode Prepare|Enable|Disable|Cleanup` through
ordinary UAC, `sample.ps1 -Label <phase>`, `observe-outage.ps1`,
`final-identity.ps1`; all completed successfully. The stock UI drives every
connect and disconnect. Host `python -B E:/r12-windows-api-outage-20260908/retain-evidence.py`
PASS for 13 phases, 23 healthy observations, unchanged offline cache metadata,
online renewal, route/firewall recovery and 44 artifact hashes.
`pwsh -NoProfile -File E:/r12-windows-api-outage-20260908/finish.ps1` PASS for
shutdown, isolation and host network comparison.

Documentation: the first seed gate rejected the readiness header because the
retained candidate line had moved past the first 45 lines. It was moved back to
the start without changing candidate identity. Both logs remain in the lab.
`pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation`
rerun PASS, including docs contract (`client-seed-retry.log`).
`git diff --check` PASS; existing generated registrants and release artifacts
remain untouched.
