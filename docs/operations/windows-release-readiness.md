# Windows acceptance

Private unsigned Windows `1.5.0+4144` was built once from App `f1466ff8` on
2026-10-12, reusing the exact 4142 Core `1.2.14` / Cronet artifacts. Package
checks passed; the installer is 28,665,967 bytes. The owned Clean VM upgraded
through its normal installer after owner-confirmed UAC: terminal success and
exit 0, version 4144, preserved identity/owner and Running/Auto/LocalSystem
service were confirmed. W32Time Auto now uses `time.windows.com,0x8`, with
subsequent automatic synchronization confirmed. After SaveState/resume, run
ordinary elevated `w32tm /resync /rediscover` and require NTP residuals below
one second before authentication; the latest three samples were within 37 ms.
Leap 0 and Last Sync Error 0 were confirmed after the peer fix. The
owner-approved test-VM policy is now
`ConsentPromptBehaviorAdmin=0`, with `EnableLUA=1` and
`PromptOnSecureDesktop=1`; normal RunAs administrator access passed without a
prompt. Original DWORD 5 is retained in guest
`Downloads/windows4144-admin-policy.safe.json`. Host time and Hiddify remain.

One ordinary audited 48-hour extension activated the existing account until
2026-10-14 04:58:28 UTC without charge or identity/key reset; UI refresh showed
two days. The first real Auto attempt ended before TUN with `access_preparing`
/ `API-011`: expiry had disabled all six assignments, leaving zero sync targets.
That cause is closed; audited restoration confirmed canonical ACKs and mappings
6/6 with account, keys and expiry preserved. After the backend fix was released,
one Auto connected, with native tunnel/DNS/egress readiness and real browser
HTTPS 204/64 KiB passing. Its UI label was Germany; external DE geography and
the exact automatic route were not observed, and Auto was not repeated.

Four ordinary US catalog pins passed separately: VLESS REALITY, AWG 3.1,
Hysteria 2 and VLESS XHTTP. Each reached native running/DNS/egress readiness,
TUN plus nine routes, then browser 204/200 with the exact 65,536-byte marker
body and increased TUN traffic. The REALITY connection also returned public
Cloudflare `loc=US`; this is observed geolocation, not exact-node attestation.
Every Stop restored TUN 0, routes 16 and DNS counts 1/0. Gemini opened an unsigned
editor, but the test text remained pending after native keyboard entry and an
enabled Send click, with no response or public error; functionality is UNKNOWN.
Country/protocol Auto and WARP variants remain open.

A new Smart DNS case used a fresh public source fetch on Brain after the host's
Hiddify fake-IP was rejected by the normal source guard. Reviewed catalog 25 /
security 2 and private provider policy 26 / security 1 passed signature checks;
the catalog was published once, with public provider and issuer OFF and the
provider pointer NULL. Four source-only checks remained `NOT_VERIFIED`. After
natural access-token expiry, ordinary same-account refresh gave 857 seconds of
parent coverage. One audited, nonrenewable 600-second admission matched the
actual 4144/Core module and expired at 08:30:43 UTC.

QA Start at 08:22:24 UTC failed at 08:22:34 during `core_connect`, candidate
phase `http_64k`: the timeline showed `CONN-005`, the support rule `CONN-008`,
and native status `core_egress_probe_unavailable`. Native rollback left no TUN
or VPN routes. The admission was claimed; no control/proof context or Gemini
request was obtained, and no second Start or renewal was made. This is an early
Core connect failure, distinct from the historical case 781 control POST failure;
the underlying native branch remains unknown.
The subsequent native regression reproduced rejection of the current Dart
producer's paired API rules. The parser now accepts their exact matching
TCP/443 and DNS scope, with negative-boundary checks passing. A new installed
candidate and fresh runtime acceptance are still required; the old case is closed.

At 08:27:34 UTC the VM baseline was restored: app, auxiliary processes, TUN,
VPN routes, WinDivert and consent prompts were absent; routes were 16, DNS
counts 1/0, DHCP4/6 enabled and proxy off. Guest sessions were zero; SaveState
reached EOF with exit 0 and Saved/Unlocked with an empty session was confirmed.
Operator sessions were revoked; the deploy lease was released with six current
ACKs and fresh health at 08:28:02 UTC. Only the owned browser test tabs were closed.
The Intel bridge and GetHostTimeDisabled setting remain; the corrected NTP
source and owner-approved admin consent policy are the new guest baseline.

Private unsigned Windows `1.5.0+4143` was built once from App `f581aa68` to
preserve the first Smart DNS control rejection across service, runner and Dart.
The build and runner compilation passed; the installer is 28,661,152 bytes and
reuses the exact 4142 Core `1.2.14` / Cronet artifacts. Version, required files,
source/trust pins and runtime binding checks passed. The source regression file
passed 32 tests, analysis passed, and native service runtime/client tests passed.
This diagnostic change does not establish the cause of case 779.

Case 781 ran once on 2026-10-12 with the corrected guest clock (56–57 ms NTP
offset), a fresh parent session (880/879 seconds before admission) and the
independent physical bridge. QA Start at 01:04:19 UTC reached ordinary
Core/TUN/routes/DNS/egress READY, then reported `control_delivery=failed` and
`api_failure_kind=request_socket`. Operation, HTTP status, errno and the
preparation reason were not displayed. Current bound Smart DNS proof was not
obtained; no Gemini query was submitted. The source places this exception at
the QA control POST; the underlying socket cause remains unknown.

The client exited normally at 01:08:28 UTC. Fresh guest baseline at 01:08:59
confirmed no app/auxiliary process, TUN, VPN route or WinDivert, with 16 routes,
DNS counts 1/0, DHCP enabled and proxy off. Guest sessions closed, SaveState
completed with exit 0 and Saved/Unlocked was confirmed. Bridge, guest time
correction, identity, preferences and browser were preserved; host Hiddify and
host time were unchanged. Case 781 is closed without replay or renewal;
real Gemini functionality remains unverified.

On 2026-10-12 private unsigned Windows `1.5.0+4142` was built from App
`89674dcd` with Core `1.2.14` (`7db9519`) and the unchanged pinned Cronet.
The single DLL and installer builds completed successfully; the 48 required
Core exports, ABI 2, package versions/files, Core/Cronet binding and compiled
native/Dart trust pins passed. The Core suite had one zero-millisecond
`lightReserve` timing assertion failure; the test now accepts a valid zero-ms
result and its focused run passed. Windows `service_runtime` passed;
`candidate_probe` stopped because the host token could not read the privileged
boot clock. Public version remains `1.4.5`.

The owned bridged Clean VM installed 4142 successfully. Case 779 used a fresh
session (809/808 seconds remaining before admission) and corrected guest time
(NTP offset 57–58 ms), without changing host Hiddify or the host clock. One QA
Start at 00:16:57 UTC reached profile/Core/TUN/routes/DNS/egress READY, then
reported `control_delivery=failed`, `control_reason=unclassified`. Current
Smart DNS proof and a real Gemini answer were not obtained; no browser query
or second Start was made. The client exited normally; OS baseline at 00:23:13
had no app/auxiliary process, TUN, VPN route or WinDivert, with 16 routes,
DNS counts 1/0, DHCP enabled and proxy off. Guest sessions closed and
SaveState completed with exit 0; Saved/Unlocked was confirmed. The physical
bridge, clock correction, identity, preferences and browser were preserved.
This case is closed; the underlying control failure is still unknown.

On 2026-10-08 the owned Clean VM upgraded from 4105 to private unsigned
1.5.0+4107 (App code `d09f555c`, unchanged Core `dbc73e1` / 1.2.9).
Direct UAC/terminal installer success, actual AOT/Core/Cronet, stable
Auto/LocalSystem service and preserved identity/owner passed. One Auto reached
protected Home and normal Diagnostics confirmed tunnel/routes/DNS/egress.
The NIC was off for 10.084 seconds: the loss frame needed attention, then Home
returned to Connected/Germany 10.08 seconds after cable-on. Fresh native proof
within 60 seconds and the exact source-fix branch were not observed; the earlier
4105 blocked-traffic cause remains unknown. Normal Stop cleared TUN/routes/DNS,
with service/PID stable; original preferences, cable-on and closed sessions were
confirmed. BFE remains unknown; its rejected reader was not repeated. Unchanged
4103 reboot/uninstall acceptance is carried. This does not accept a fresh user,
the full 1.5.0 release or public signing.
Public version remains `1.4.5`. Historical `1.2.0+4061` was an unsigned Windows beta with Core 1.1.0.
Version 1.1.6 remains available for rollback. The earlier 4055 installed-VM checks remain historical. On
the same VM, 4053 connected to DE while 4054 timed out; replacing only Core
with the fixed DLL restored the connection. The exact 4055 installer was then
installed over 4054 on that VM: its bundled Core DLL matched the staged artifact, DE connected,
and disconnect returned the UI to the disconnected state. This verifies that
historical update path and connect/disconnect only. Current acceptance is recorded below.

When upgrading a legacy 1.1.6 per-user installation, the administrator
installer closes the running old POKROV UI and waits for its process to exit
before invoking its uninstaller.
It waits for the old uninstaller's second phase to remove the uninstall entry
and binary before keeping the new service installation. The old uninstaller
can return success before that second phase finishes; a running UI can also
hold its EXE and leave a broken partial upgrade.

Legacy cleanup finishes before the final service setup. The installer snapshots
the previous owner first, then checks service existence again after cleanup and
applies the saved owner and ACLs before creating/configuring and starting the
service. It waits up to 30 seconds for `POKROVService` to reach `Running` and
fails the installation if that state is not confirmed. Installed QA separately
checks the public service status and owner identity.

Before installing files, Setup uses the existing scoped `Stop-Service` pattern,
waits up to 30 seconds for `Stopped`, and confirms that state with `Refresh`.
An absent or already stopped service is valid; failure stops preparation before
file installation. The log retains the stop request, launch result and exit code.
This change does not establish the cause of an earlier abrupt Setup exit.

An upgrade preserves a valid `InstallOwnerSid` already recorded in
`HKLM64\Software\space.pokrov\POKROV\Service`, including when another
administrator launches the installer. The installer queries the original
launcher SID only when no valid installation owner is recorded. This keeps the
existing user's service access across upgrades.

On the owned Windows VM, install from a clean state and update over 1.1.6.
Connect and disconnect; reboot while VPN is connected and check that network
access returns. Finally uninstall and check network access again. Record any
failed step against the exact installer and installed Core DLL.

The VM is accessed through VirtualBox guest control and saved guest access.
Unsigned output may show SmartScreen; that is part of the beta handoff, not a
claim of trusted signing. A local debug build does not prove installed-VM
behavior.

## 4061 acceptance, 2026-09-27

The final `be0f86a` installer passed on the owned VT-x VM (4 vCPU, 8 GB),
with host builds stopped: update over running 1.1.6 with the trial preserved;
true clean installation, visible welcome on its first launch and a new trial;
DE and CH in ordinary mode with «Россия напрямую»; reboot with CH active;
and uninstall with VPN and UI active. Both nodes passed Core egress checks
and fresh owned API HTTP 200 requests. Reboot restored ordinary networking
before login; VPN does not automatically reconnect. Manual reconnection passed.
Uninstall removed the EXE, service, processes, registration and TUN while
network access remained available. The VM was left without POKROV.

The first 4060 clean launch had an invisible welcome until reopening. A focused
regression test reproduced muted animation tickers leaving opacity at zero;
`22e9db9` fixed that path, and the first clean 4061 launch confirmed the fix.
The owner approved publication on 2026-09-27. The same installer is available
in `Kiwunaka/pokrov` release `v1.2.0`, with the SmartScreen warning.
