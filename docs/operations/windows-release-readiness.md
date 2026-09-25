# Windows 1.2.0 acceptance

Target: `1.2.0+4054`, unsigned Windows beta, POKROV Core 1.1.0. Current public
version is 1.1.6. The 4054 installed-VM checks are still open.

On the owned Windows VM, install from a clean state and update over 1.1.6.
Connect and disconnect; reboot while VPN is connected and check that network
access returns. Finally uninstall and check network access again. Record any
failed step against the exact installer and installed Core DLL.

The VM is accessed through VirtualBox guest control and saved guest access.
Unsigned output may show SmartScreen; that is part of the beta handoff, not a
claim of trusted signing. A local debug build does not prove installed-VM
behavior.
