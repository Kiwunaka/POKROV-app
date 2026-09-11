# Core2662 installed startup and JNI log privacy — 2026-09-12

Document class: EXECUTION_EVIDENCE.
**PASS_BOUNDED_INSTALLED_STARTUP_AND_JNI_LOG_PRIVACY**.
Client source `212bd2f30c9f91d80fd3a6c08fb5557be8457f1c`, Core
`2662f76a3303a0518bb07fbbdc449c066de2f95b`, development `1.2.0+4053`.
[Receipt](receipt.json) records exact capture hashes and scope.

## Windows

The owner made the PC available and authorized control of the existing guest.
The ordinary setup wizard updated the existing installation. Before launch
and after the main screen appeared, [all 304 installed files](windows/installed-after-launch.json)
matched the current package; LocalSystem service was running, outbox empty,
and session/secure-storage hashes were unchanged from the
[prior baseline](../2026-09-12-r12-c05-package-ffi/baseline.json).
The [startup journal projection](windows/startup-timeline.json) identifies
client212 and successful initialization/UI readiness. It also retains the
previous-exit detection and failed API/update refreshes with the guest NIC off.

The exact current DLL already passes the separate
[six-marker FFI regression](../2026-09-12-r12-c05-package-ffi/README.md).
This installed slice proves startup and preservation, not a current TUN test.
Changing the disabled NIC attachment while running failed without changing it.
The shutdown wrapper returned exit 1 as the guest stopped; independent
[native readback](windows/installed-vm-restoration.json) proves poweroff/NIC none.
All [13 snapshots](windows/snapshot-lineage.json) and the old rollback-leaf
hash remain intact. Restart growth was 580911104 bytes within 805306368.

## Physical Android

`adb -d install -r` installed the current ARM64 direct APK, SHA-256
`45a943dca23587e7b710b33e29ac39b90bf0aaa614566c374f651bb4ceadc348`.
Both old and current APKs pass apksigner verification with the same certificate.
The previous APK remains in the local rollback directory. No app data was cleared.
[Installed readback](android-physical/installed.json) and
[UI observation](android-physical/ui-observation.json) show successful startup
with the same visible settings. Account-bearing screenshots remain local.
The owner took the phone until morning before tunnel/logging acceptance;
there were no further phone actions. Existing third-party VPN state was untouched.

## Android emulator

Only the existing `pokrov-qa-120` instance was started. SDK ADB and the indexed
LDPlayer console were bound by matching boot identities; physical-looking
LDPlayer properties were not treated as proof of a physical device.
The current x86_64 APK, SHA-256
`9ffe8e83cfab393ef765acc0631579d236a9363525f3c71bd5e5d54660666fee`,
was installed with the same signing certificate and no app-data clear.
The main screen and stored location/routing survived. The test entitlement
requires renewal; no paid action or entitlement bypass was performed.

The [startup log scan](android-emulator/startup-privacy.json) inspected 13433
bytes from the current main process in memory. Six defined secret-pattern
classes returned zero matches; no fatal exception or ANR was observed.
This is a bounded regex scan, not exhaustive confidentiality proof.

[CorePrivacyProbe.java](android-emulator/CorePrivacyProbe.java) was compiled
with JDK17 `javac --release 8`, then SDK36.1 D8 `--min-api 26`.
A separate shell `app_process` loads the exact installed APK through
`PathClassLoader`, calls native `Libbox.setup(debug=false)` with an isolated
temporary directory, then `checkConfig` with six synthetic markers in an
invalid outbound type. No VPN service or live profile is started.
[JNI result](android-emulator/jni-privacy.json): the config was rejected;
stdout, stderr and the child's 5449-byte logcat contain none of the markers.
The JNI exception returned to the caller **does contain all six markers**.
The harness catches it and exports booleans only. This does not claim that
raw JNI errors are safe to display/log, or prove every consumer error path.
The retained [driver](android-emulator/jni-privacy.py) keeps raw streams in memory.

The emulator was shut down; disk growth was 295698432 bytes within 402653184.
[Host route/DNS hashes](android-emulator/host-network-after.json) are unchanged.
Root settings, host Hiddify and other emulator instances were not changed.
LDPlayer was not installed inside Windows VM: available headroom above the
40 GiB disk floor is insufficient for its published 36 GB free-space minimum.

Current installed tunnel/recovery, physical ARM runtime/privacy, extended/crash
sinks, full license/source assessment and source publication remain open.
No new public release, store submission or production deploy occurred.
