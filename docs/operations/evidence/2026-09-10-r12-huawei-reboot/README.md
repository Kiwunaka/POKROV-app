# Huawei connected reboot and manual recovery

**PASS_BOUNDED_MANUAL_RECONNECT_AFTER_REBOOT**, 2026-09-10 MSK / UTC 2026-09-09.
Current physical Huawei API31, client `c05b58b`, Core `c7a11f7`, installed ARM64
`d030288a…f510`. [Receipt](receipt.json) binds this run to the same installed APK
and backend `6b34dfd`; no build, install, app-data clear or account mutation.

The app confirmed Frankfurt / selected-app routing protection before `adb reboot`.
The owner confirmed availability, then manually unlocked the phone after boot.
The boot ID hash changed and `sys.boot_completed` was 1. Before relaunch there
was no POKROV VPN service or TUN. Relaunch retained Frankfurt, selected-app mode
and active-access presentation, and correctly displayed disconnected status.
Automatic VPN restart was not observed or claimed; always-on/lockdown was not enabled.

A fresh-tree tap on Connect started the foreground VPN service/TUN. Refreshing
the protection sheet confirmed tunnel, DNS and VPN egress. Disconnect removed
the service/TUN and exactly restored the post-boot, pre-connect route/rule hashes.
This baseline belongs to the new boot; equality with pre-reboot OS routes is not
claimed. Wi-Fi/mobile, APK bytes and install/update metadata matched the pre-reboot
record. Final state: Frankfurt / selected-app routing, VPN off, no TUN.

Commands: `python reboot-start.py`, owner unlock, `python reboot-after-boot.py`,
`python reboot-resume.py`, `python reboot-reconnect.py` with the shared
[collector](../2026-09-10-r12-huawei-current/README.md). All taps derive coordinates
from a fresh accessibility tree. Raw UI XML/account details are not retained.
Only allowlisted UI labels, native service state and hashes are stored.

This closes the bounded Huawei reboot/manual-recovery observation. D03 remains
open for its remaining OEM/API, permission revoke/lockdown, long-session and
battery requirements. Independent leak/egress capture and final release are separate.

Validation: `pwsh.exe -File scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation` — PASS, including client docs contract; [log](client-seed.log). `git diff --check` — PASS. No release-artifact changes.
