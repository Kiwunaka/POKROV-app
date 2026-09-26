# Windows 1.2.0 acceptance

Target: `1.2.0+4059`, unsigned Windows beta, POKROV Core 1.1.0. Current public
version is 1.1.6. The earlier 4055 installed-VM checks remain historical. On
the same VM, 4053 connected to DE while 4054 timed out; replacing only Core
with the fixed DLL restored the connection. The exact 4055 installer was then
installed over 4054 on that VM: its bundled Core DLL matched the staged artifact, DE connected,
and disconnect returned the UI to the disconnected state. This verifies that
update path and connect/disconnect only; the remaining installed-VM checks
below are open.

When upgrading a legacy 1.1.6 per-user installation, the administrator
installer closes the running old POKROV UI and waits for its process to exit
before invoking its uninstaller.
It waits for the old uninstaller's second phase to remove the uninstall entry
and binary before keeping the new service installation. The old uninstaller
can return success before that second phase finishes; a running UI can also
hold its EXE and leave a broken partial upgrade.

On the owned Windows VM, install from a clean state and update over 1.1.6.
Connect and disconnect; reboot while VPN is connected and check that network
access returns. Finally uninstall and check network access again. Record any
failed step against the exact installer and installed Core DLL.

The VM is accessed through VirtualBox guest control and saved guest access.
Unsigned output may show SmartScreen; that is part of the beta handoff, not a
claim of trusted signing. A local debug build does not prove installed-VM
behavior.
