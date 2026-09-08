# Android package after explicit-denial fix

2026-09-08, **PASS_BOUNDED_BUILD_UPDATE_CONNECT_RESUME_DISCONNECT**.
Client `f479fd4` / Core `02a091c`, ARM64 APK SHA-256
`20a0781baf9bea1e9e0e55de5f4d7d5193936dfe7a9d894df98c1bc457b897af`.
[Receipt](receipt.json), [four-ABI package audit](abi-package-audit.json),
[physical acceptance](runtime-summary.json).

The common Dart fix was rebuilt into universal, ARM64, ARMv7 and x86_64 direct
APK packages (`1.2.0+4053`). All use the existing production Android certificate;
package identity, non-debuggable flag, exact native Core hashes, ABI contents
and notices passed. Native Core, Flutter and notices are unchanged from the
prior integrated APKs; Dart AOT changed. This is a local acceptance package,
not a published candidate or channel release. ARM64 size is 101,229,131 bytes.

The build used the existing direct-flavor APK command with the split-ABI
project argument, standard signing environment and existing public support /
emergency pins. Source checkout `E:/r12-access-denial-build-20260908` is at
`f479fd4`; no tracked Android/packages/config/scripts differences were present.
`source-binding.json` distinguishes checkout CRLF hashes from Git source hashes.

On the connected Huawei ADA-AL00U (Android 12 / SDK 31), `adb install -r` passed
without uninstall or data clearing. Installed bytes matched before and after
runtime checks; first-install timestamp was unchanged. Warsaw whitelist,
Russia-direct and WARP-off preferences remained visible.

The ordinary UI connected with a foreground VPN service and TUN. The protection
sheet reported confirmed tunnel, DNS and VPN exit. Sending the app to the
background and resuming it kept the active tunnel. Normal disconnect removed
VPN service/TUN and restored exact original routes and policy-rule hashes.
Wi-Fi and mobile settings were preserved; the phone is left with VPN off.
All eight runtime assertions passed. App-observed protection does not replace
independent leak or egress proof.

**Denial and session revocation: MANUAL_OWNER_TEST.** Read-only target inspection
found that the phone is linked to the primary runtime administrator account.
Its access/session was not revoked and backend data was not changed. A separate
test login was requested to exercise destructive authentication scenarios
without losing the owner's current sign-in. The Windows installed denial result
and shared source tests remain separate evidence; this Android run proves the
updated package and positive connect/resume path, not physical denial behavior.

Previous APK receipts retain their own identities. New-package AWG switching,
outage/expiry/revocation and full device/channel gates remain open. No push,
deploy, release-artifact mutation or publication occurred. Rollback APK
`88452b99…5850` remains retained locally; rollback was not needed.
