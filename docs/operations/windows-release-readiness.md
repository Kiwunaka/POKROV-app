# Windows 1.2.0 acceptance

Published: `1.2.0+4061`, unsigned Windows beta, POKROV Core 1.1.0.
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
