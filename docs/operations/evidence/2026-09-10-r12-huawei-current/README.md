# Huawei current ARM64 lifecycle, 2026-09-10 MSK

**PASS_BOUNDED_PHYSICAL_HUAWEI**. Execution timestamps remain in UTC (2026-09-09).
Client `c05b58b268bbd789aa96fb662cb46c9768558ef0`, Core
`c7a11f7d2fd974726095ad7aa0619c055273dd15`; current physical Huawei
ADA-AL00U / Android 12 / API31. No new geographic-origin determination.
[Receipt](receipt.json) binds all retained files.

## Exact bytes and account surface

The phone already contained the prepared ARM64 APK, 101229131 bytes, SHA-256
`d030288a672b654a70db593f512416113fd2e8ad12025237b94a422c9613f510`.
Version 1.2.0+4053, minSdk24 / targetSdk36, primary ABI arm64-v8a.
The exact digest matches the [existing package audit](../2026-09-09-r12-installed-current/abi-package-audit.json),
including its signer and native/notices pin. No new APK build or installation
was performed. First-install and last-update timestamps remained unchanged.

The retained profile was Frankfurt / selected-app routing / WARP off. Its
protection sheet confirmed tunnel, DNS and VPN egress after the refresh action.
The profile screen displayed Premium and Telegram, with no observed previous
load-error label. The latest platform account-timeout fix is deployed; this UI
observation does not distinguish cache from a fresh account request or measure
its API latency. No account identifiers, session values or raw profile were exported.

## Lifecycle checks

- Deep Doze was forced for 120 seconds with the app in the background. Five
  native samples at 0/30/60/90/120 seconds showed IDLE, the same process,
  foreground VpnService and tun0. USB power and screen remained on. This is
  scheduler/lifecycle proof, not normal-screen-off OEM behavior or a battery baseline.
- `dumpsys deviceidle unforce` restored ACTIVE and force=false. The app returned
  to the foreground; the protection sheet again confirmed tunnel/DNS/VPN egress
  after its refresh control was activated.
- `am force-stop space.pokrov.pokrov_android_shell` removed the VPN service/TUN;
  route and policy-rule hashes exactly matched the before-connect state.
  Relaunch and reconnect from retained state worked without clearing app data;
  the protection sheet again confirmed protection.
- Normal disconnect restored exact route/rule hashes. Final state: VPN off,
  no TUN, Wi-Fi and mobile enabled as before, same APK and timestamps, all
  animation scales 1.0. Data/account identity across the earlier installation
  was not independently compared, so this does not close the full D01 gate.

## Inspector limits and reproduction

The system ADB on the host was version 32 and modified binary screenshot
newlines. The supported SDK ADB 1.0.41 / 37.0.0-14910828 corrected the capture;
the app process and tunnel stayed running during the ADB server replacement.
The first screenshot file is invalid and was not used as visual proof.

Stock `uiautomator dump` repeatedly returned `could not get idle state` on the
connected screen. The [AOSP dumper](https://android.googlesource.com/platform/prebuilts/fullsdk/sources/android-29/+/refs/heads/main/com/android/commands/uiautomator/DumpCommand.java)
waits for an idle accessibility interval before reading the tree. Temporarily
setting animator_duration_scale to 0 did not resolve that collector failure;
the original value was restored. This attempt does not prove F03 compliance
or a product animation defect.

The task-local `R12Tree.java` reads the active accessibility root through the
existing shell UIAutomation session without waiting for the idle interval.
It changes no privileges or app permissions and installs no APK/service.
Raw XML is parsed in memory; retained records contain allowlisted labels and
hashes. Every tap derives its bounds from a fresh tree. Java/D8 outputs remain
in `E:/r12-huawei-current-20260910/`; SDK android31 stubs and the device's existing
android.test.base.jar are used. Initial helper attempts lacked a framework
annotation or returned no hierarchy; their output is not counted as product PASS.
The first exact-label profile tap found no node; the next fresh tree matched the
actual tab content-desc including its accessibility suffix.

Commands: `python doze.py`, `python recovery.py`, `python restore.py` from the
retained local runner directory. `device.py` provides native hash/service and
UI snapshots. The five-sample Doze result, force-stop recovery and restoration
are separate from the earlier candidate.33 and older APK evidence.

The Warsaw whitelist egress failure, independent leak/egress checks, remaining
network/OEM/API matrix, permission revocation, lockdown, reboot, battery and
final-channel release acceptance remain open. No release artifacts, product
source, signing identities, entitlement or rollout configuration were changed.

Validation: PowerShell Core `scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation` and `test/docs-contract.ps1` PASS; `git diff --check` PASS; no `artifacts/releases/**` delta.
