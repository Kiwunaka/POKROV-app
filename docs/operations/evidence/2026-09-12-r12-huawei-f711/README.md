# Current F711 ARM64: Huawei install and recovery

Document class: EVIDENCE. [Result](result.json), [receipt and file hashes](receipt.json).
Compiled client f7115c505c314a7322481997a46343b03dae1127, Core
6b271decead88b708e2fc03984b703b0a4e63ebd. [Package and source promotion evidence](../2026-09-12-r12-dart-crash-packages/README.md).

The exact primary ARM64 APK 78d7a1361d03d808c6f6554fb65bc7411a9b411ed436c6ccbf79114d13737c91
was installed on the owner's Huawei ADA-AL00U, Android API31, with adb install -r.
The previous APK45a943dc was retained locally and its signer verified before the
update. Package, production signer, version4053, ARM64 ABI, minSdk24/targetSdk36,
UID, original install time and system VPN/Wi-Fi/mobile settings remain continuous.
The installed bytes match the audited APK, not the universal package.

Access remains active without login. All visible profile text hashes match before
and after; the home retains Warsaw and the visible routing controls. No private
account text, secure-storage files or raw connection material were exported.
This verifies visible state and access, not byte equality of private storage.

Ordinary connect/reconnect creates foreground VPN service and tun0. Refreshed
in-app checks confirm tunnel, DNS and VPN egress. Ordinary disconnect restores
exact route and rule hashes. Home/background resume preserves the active tunnel
and refreshed protection. Android am force-stop removes TUN/service and restores
the exact baseline; an independent shell HTTPS probe succeeds. Cold relaunch and
ordinary reconnect again pass refreshed protection. Final disconnect restores
exact routes/rules and all four Android settings; three HTTPS requests return200
in346/363/367ms. VPN is OFF, Wi-Fi/mobile ON, always-on/lockdown OFF. No observer
process remains. The host VPN and its network configuration were not operated.

The original 750ms UI helper returned no active app root; the retained direct
accessibility helper succeeded. SDK ADB replaced the older server and briefly
had no device; installation began only after the physical model was verified.
The initial launcher sample is not application acceptance evidence.

Limits: same-version local replacement, not release-channel delivery or successor
version upgrade; one OEM/API/ABI; no new handoff, IPv6-only/NAT64, MTU, UDP53,
captive portal, reboot, Doze or battery run. Force-stop is controlled termination,
not uncaught native/Dart crash or ANR proof. No public artifact or store action.
The complete D01 delivery gate and D02/D03 matrices remain open.

Executed: python -X utf8 install.py; recovery.py; finish.py, plus retained
device.py snapshots and fresh-accessibility-tree taps. install-result.json,
forced-stop-result.json and final-restoration.json contain successful checks.
Documentation validation: test/docs-contract.ps1; scripts/validate-seed.ps1 with
explicit platform/Core roots; git diff --check and release-artifact boundary.
