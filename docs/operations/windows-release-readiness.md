# Windows acceptance

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
