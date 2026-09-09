# Windows firewall and local application coexistence — 2026-09-08

**PASS_BOUNDED** for the installed local client `e88dff9` / Core `02a091c`,
Windows 11 `10.0.26200`, owned VirtualBox VM with NAT, current-origin.
The unchanged `1.2.0+4053` installer SHA-256 is
`29a87a13906909e400037a947f1e4f876ca59821e7e34c73060e623f2d9fbeea`;
all 305 installed files match before and after. [Receipt](receipt.json) retains
35 source/observation/screenshot hash references. No application code or package
changed in this slice. Full W06 remains open.

| Managed AWG3.1 phase | Health before | Firewall block | Health restored | Local HTTP responses | TUN |
| --- | --- | --- | --- | --- | --- |
| Before connection | 200 | ConnectFailure | 200 | 200 / 200 / 200 | 0 |
| Connected | 200 | ConnectFailure | 200 | 200 / 200 / 200 | 1 |
| After disconnect | 200 | ConnectFailure | 200 | 200 / 200 / 200 | 0 |

The foreign fixture rule targets only the PowerShell executable, TCP 443 and
resolved IPv4 addresses of owned `app.pokrov.space`. Each request uses a new
direct connection, TLS 1.2 and an eight-second deadline. ActiveStore confirms
the block is enabled; disabling it immediately restores HTTP 200. An ordinary
user's loopback-only HTTP listener remains reachable throughout. This tests
local application reachability, not loopback firewall enforcement.

All 488 preexisting PersistentStore rules and selected associated application,
address, port, service, interface, security and profile fields have the same
aggregate and component hashes before connection, during connection, after
disconnect and after fixture removal. Raw policy is not exported. The connected
SCM observation confirms running/Core/DNS/egress readiness and effective/staged
agreement before and after the block. The existing read-only IPC helper's
embedded `0218e89` labels its own build; its retained SHA identifies that helper,
not the current installed application source.

The first fixture preparation failed before rule creation because Firewall
rejected a forward-slash Program path. The retained v2 uses a native Windows
path. Both receipts remain available. A disabled VM NIC could not be changed
while running; NAT was applied only after confirmed graceful shutdown.

Cleanup: both exact fixture rules removed, listener stopped, launched UI PID
stopped after explicit disconnect, 305 package hashes rechecked, original backend
rollout fully restored. Guest routes/DNS equal the preconnection hashes.
VM off/NIC none, source VM off, host routes/DNS unchanged. No promotion,
publication, release build, deploy or release-artifact change occurred.

Other VPN coexistence, third-party native WFP providers/sublayers, LAN/IPv6,
Win10, independent route/effective location proof and final-channel W06 remain
open. This is one retained sample per phase, not a stress or exhaustive WFP test.

Commands: guest `coexist-v2.ps1 -Mode Prepare -Label prepare-v2`, then
`-Mode Observe -Label before|connected|after`, and `-Mode Cleanup -Label cleanup`:
five successful exits. Normal user drives the stock UI; firewall fixture uses
ordinary UAC elevation. Host `python -B E:/r12-windows-coexistence-20260908/retain-evidence.py`
PASS: three phase oracles, 488 rules, 305 files, return state and 35 artifact
hashes. `pwsh -NoProfile -File E:/r12-windows-coexistence-20260908/finish.ps1`
PASS for shutdown, isolation and host network comparison.

Documentation gate: `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation`
PASS, including client docs contract; log retained in the lab directory.
`git diff --check` PASS and `artifacts/releases/**` unchanged. Existing generated
registrants remain outside this evidence commit.
