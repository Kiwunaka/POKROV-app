# Retained Android release audit snapshot

Document class: `EVIDENCE`
Snapshot date: 2026-08-19

This file preserves the exact readiness/backlog text that existed before
`WO-003G` separated current execution state from candidate-specific history.
Every status below is evidence for its named date or candidate. It is not the
current release decision and cannot authorize a new candidate or promotion.

---

# Android Release Audit

Status: direct APK 1.1.6+29 public stable PASS for production signing, exact GitHub size/digest, anonymous downloads and production update handoff; exact Huawei install, WARP/per-app/uplink repetition and long-cycle proof remain manual
Last updated: 2026-08-19

## Required Dependency

Set `ANDROID_AUDIT_SERIAL` to a connected physical Android device. Emulator serials are preflight only and do not clear trusted, store, stable, or raw-audited Android release claims.

Set `ANDROID_AUDIT_PACKAGE` to `space.pokrov.pokrov_android_shell` unless a release candidate intentionally changes the package id.

## Required Checks

- Release APK installed on physical hardware.
- First launch and app-first session bootstrap.
- Connect and disconnect from app.
- Confirm the exact APK contains POKROV Core 1.0.3 `libpokrov-core.so` from
  the pinned `pokrov-core.aar`.
- Disconnect from foreground notification.
- System VPN permission revoke.
- Relaunch while connected.
- Rapid reconnect.
- Wi-Fi to LTE/5G and LTE/5G to Wi-Fi handoff while connected; record uplink,
  DNS readiness, traffic recovery, and whether a stale session survives.
- Offline or DNS failure warning.
- Block UDP/53 and prove the HTTPS DoH remote and direct-bootstrap lanes still
  resolve and carry traffic without a silent plaintext DNS downgrade.
- `All except RU` route-mode smoke.
- `Full tunnel` route-mode smoke.
- `Only selected apps` route-mode smoke with one selected installed package.
- `Except selected apps` route-mode smoke with the same package and reverse
  country result versus a non-selected browser.
- DNS split and leak checks for both public routing modes.
- Enable client-local WARP, reconnect, verify traffic and fallback behavior,
  then disable it and verify the original managed profile is restored.
- VLESS + REALITY Vision traffic smoke on Russian mobile data where that
  protocol is part of the exact managed profile; small initial transfer is not
  sufficient proof of a healthy session.
- For the staged TLS-fragment experiment, retain PCAP for disabled versus
  record-fragment enabled behavior on RU LTE/5G. Do not enable the managed
  production policy from config-shape tests alone.
- Run MTU `1280/1400/1492/1500/9000` under blocked ICMP with a large transfer
  and QUIC; record failures and throughput before changing the default.
- Run 100 start/stop cycles, Wi-Fi to LTE and back, airplane mode, sleep/resume,
  and VPN-permission revoke/regrant. Fix only failures reproduced by POKROV's
  exact APK and retain the failing logs.
- No raw config in UI or logcat.
- No `session_token` in app-first JSON state; migrated session material must live in the app secure secret store.
- Android backup and device-transfer rules exclude all local app state so encrypted session material cannot be restored without its Keystore key.
- No unexpected localhost/control ports exposed.
- No sensitive external control surface.
- Uninstall/reinstall cleanup.
- Battery/background sanity.
- Small-screen accessibility screenshot.
- Adaptive launcher mask keeps the POKROV mark inside the safe zone on the
  device launchers in scope.
- Android 12+ light and dark splash surfaces use the canonical mark and the
  matching POKROV canvas color without clipping or a flash of the wrong theme.
- Edge-to-edge status/navigation bars preserve safe-area content and readable
  system icons in light and dark themes.
- Predictive-back navigation returns through onboarding, sheets, support, and
  the main shell without closing or exposing an invalid state.

## Commands

```powershell
# Run once from the repository root. Existing signing state is never overwritten.
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure-android-production-signing.ps1

# Canonical direct-APK build loads the DPAPI secret only into the build process,
# verifies the signer, and writes ignored evidence beside the APK.
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-android-production.ps1

adb devices
$env:ANDROID_AUDIT_PACKAGE="space.pokrov.pokrov_android_shell"
$env:ANDROID_AUDIT_RELEASE_EVIDENCE="<artifact/version/checksum>"
$env:PLATFORM_REPO="C:\Users\kiwun\Documents\ai\VPN"
python "$env:PLATFORM_REPO/scripts/android_localhost_audit.py" --serial $env:ANDROID_AUDIT_SERIAL --package $env:ANDROID_AUDIT_PACKAGE --release-evidence $env:ANDROID_AUDIT_RELEASE_EVIDENCE --require-release-build --connect-wait-sec 30 --disconnect-wait-sec 15
```

For an explicitly non-public local rehearsal only, set
`POKROV_ALLOW_INTERNAL_BETA_DEBUG_SIGNING=true` around the build and remove it
afterwards. That artifact may exercise the audit flow, but its signing result is
`NOT_REQUESTED`: production signing was not part of that internal smoke. It cannot
be promoted, synced, or described as public, trusted, store-ready, or stable.

## Current 2026-08-13 Production-Signed Candidate

The current direct-distribution candidate is `1.0.4+13` against
`https://api.pokrov.space`. The canonical split artifacts are:

| ABI | Size, bytes | SHA-256 | Version code |
| --- | ---: | --- | ---: |
| ARM64 | `99117667` | `48EAC0BE655D4D85D31134908E7A8CAEC881ED91AAE049FB7CF72206EFD99E6C` | `2013` |
| ARMv7 | `88427581` | `598916EFCFAA6E32465627EB984390E10A2C2C97DB9936A34E9030F1179E75E5` | `1013` |
| x86_64 | `107631522` | `6B8F38B3498FFF693E8C1A0C20200A37C570CC3E3B233F331B14003D3B05B2B7` | `4013` |
| universal | `289838426` | `7B7688185D03ED3E54A7D1EE0B15D774F97AD66C25C221135B895421146068B9` | `13` |

- production signing: `PASS`. Every APK is non-debuggable, has package
  `space.pokrov.pokrov_android_shell`, target SDK `36`, and certificate
  SHA-256
  `0A0602A7DF5D96A0B427909D004F3DDF26DEF86587634BF16694DA8D654B2500`.
- exact Huawei identity: `PASS`. The installed base APK on the authorized
  Android 12 Huawei matched the ARM64 SHA-256 byte for byte; package metadata
  reported `versionName=1.0.4`, `versionCode=2013`.
- exact final UI: `PASS`. Home, premium-to-checkout affordance, locations,
  the four-choice Milan variant sheet, and the support AI sheet were exercised
  on the installed artifact. The last variant is fully visible, tappable, and
  persists. The live AI answered a WARP failure with concrete recovery first,
  exposed bounded follow-up/diagnostics actions, and kept human escalation as
  a secondary escape instead of immediately creating a ticket.
- exact final ordinary runtime: `PASS`. The production-signed ARM64 candidate
  established the Android VPN service and selected outbound. After one
  fail-closed transient immediately following a variant change, the explicit
  retry succeeded and three further stop/start cycles each stopped cleanly,
  restored the foreground service, and completed the outbound probe as
  `healthy`.
- exact final system UX: `PASS`. The foreground notification fits the Huawei
  shade with status, route summary, fresh down/up speed, Open, and Disconnect;
  the Disconnect action stops the service. No new device ANR was recorded
  after the `23:36:40` candidate install.
- immediately preceding same-version supporting run: `PASS_SUPPORTING_NOT_EXACT_FINAL`.
  The production-signed `1.0.4+13` build immediately before the final
  location-sheet and AI-only Flutter changes proved WARP traffic, manual
  locations, excluded-app routing (`Яндекс` direct while Chrome used the
  foreign exit), Wi-Fi to LTE to Wi-Fi continuity, Quick Settings start/stop,
  notification actions, screen-off background operation, and fresh-process
  browser egress. No raw address is retained here.
- exact-final WARP, per-app egress, and uplink repetition:
  `MANUAL_OWNER_TEST`. The final APK differs in hash even though the subsequent
  changes were limited to locations/support UI. The supporting run is not
  relabelled as exact-candidate evidence.
- retained ignored evidence:
  `E:/POKROV-ops-evidence/2026-08-13-goal-continuation/huawei-exact-final/`.
- signing recovery: `MANUAL_OWNER_TEST`. The production keystore and
  DPAPI-protected password remain outside Git. An encrypted offline copy on
  owner-controlled external media is still required.
- publication and runtime handoff: `PASS`. Public prerelease
  `v1.0.4-beta.1` exposes all four APKs; every asset completed an anonymous
  full-size SHA-256 match. Production backend/static deploy and post-deploy
  verification passed, and a brain-origin synthetic signed app session
  returned the exact ARM64/ARMv7/x86_64/universal URLs and hashes. This does
  not replace a real Telegram-user WebApp session.
- Google Play: `NOT_REQUESTED_DIRECT_APK_FIRST`.

## Prior 2026-08-12 Production-Signed Direct APK

The current direct-distribution release is `1.0.2+9` and uses the production
API base `https://api.pokrov.space`:

- APK: `287207515` bytes, SHA-256
  `9820cda01dea74cdbd34a9d1fa76b7cfc1dd24d0d452d8521239dff9da6beaca`.
- package: `space.pokrov.pokrov_android_shell`; minimum SDK `24`; target SDK
  `36`; `debuggable=false`.
- signing: `PASS_PRODUCTION_SELF_MANAGED_DIRECT_APK`. Independent `apksigner`
  verification reports one RSA-4096 signer, APK Signature Scheme v2, subject
  `CN=POKROV, O=POKROV, C=RU`, and certificate SHA-256
  `0a0602a7df5d96a0b427909d004f3ddf26def86587634bf16694da8d654b2500`.
- signer continuity: the one-time configure script was rerun idempotently and
  the keystore SHA-256 remained unchanged. The same production signer updated
  the previously installed candidate on physical hardware without clearing the
  app session.
- exact-artifact install identity: `PASS`. The installed base APK on the
  authorized Android 12 Huawei device matched the local APK SHA-256 byte for
  byte; package metadata reported `versionCode=9`, `versionName=1.0.2`, target
  SDK `36`, and no `DEBUGGABLE` flag.
- exact-artifact UI preflight: `PASS`. Cold launch, app-first onboarding, Home,
  the primary `Включить VPN` control, and the first-connect route-scope sheet
  were traversed from UI-tree coordinates; the crash-buffer line count remained
  zero.
- physical runtime discovery: `PASS`. The phone installs the APK with native
  extraction disabled, so `nativeLibraryDir` is empty. Candidate `+8` resolves
  the ABI-matched packaged `libpokrov-core.so` directly from the APK and enables
  the connect lane instead of reporting missing Core.
- Quick Settings pre-tunnel behavior: `PASS`. The POKROV tile was added to the
  authorized phone, appeared first in the expanded grid with the readable
  inactive label `POKROV` and accessibility state `Выключено`, and a physical
  click without an eligible staged profile opened the app instead of starting a
  stale or unverified tunnel. The exact tile service and foreground-notification
  security-contract tests also pass.
- Chrome egress preflight: `PASS_PRECONDITION_ONLY`. Chrome opened the HTTPS IP
  check endpoint and reported a secure connection. The page content is not
  exposed through Android's accessibility tree, so no raw mobile address was
  retained; changed egress plus selected paid-node country/ASN remain part of
  the online tunnel retest.
- production tunnel and routing: `PASS`. Germany connected on the authorized
  Android 12 Huawei phone. Smart split returned `RU` for the direct Russian
  lane and `DE` for a non-Russian browser request; no raw address was retained.
- per-app routing: `PASS`. With `Яндекс Браузер` excluded, Yandex returned `RU`
  while Chrome returned `DE`. With `Only selected apps`, the results reversed:
  Yandex returned `DE` and Chrome returned `RU`.
- system controls: `PASS`. The branded Quick Settings tile starts the staged
  profile, and the foreground notification shows country, route summary,
  optional speed, open, and disconnect actions. Notification speed visibility
  was disabled and restored from in-app settings.
- support and commercial journey: `PASS`. A real in-app support question
  received a live bounded answer from the deployed support agent; checkout
  opened the production card and exposed the current `99 / 239 / 669 / 1199 /
  1699 / 1999 ₽` catalog for welcome, 1, 3, 6, 9, and 12 months.
- destructive QA cleanup: `PASS`. The final transient app user was removed
  from all seven panels and 24 related database rows after a fresh full
  PostgreSQL backup; postcheck returned zero users, keys, and node mappings.
- remaining endurance evidence: `MANUAL_OWNER_TEST`. The 100-cycle,
  Wi-Fi/mobile handoff, blocked-UDP/53, WARP, battery, sleep/resume, and MTU
  matrix remain separate endurance gates and are not claimed by this journey.
- retained local evidence: ignored directory
  `apps/android_shell/build/qa/device-release-20260812/` contains screenshots,
  UI trees, route-country results, and final installed-artifact evidence.
- signing recovery: `MANUAL_OWNER_TEST`. The private key and DPAPI-protected
  password are outside Git under `%LOCALAPPDATA%\POKROV\android-signing`; a
  separate encrypted offline copy of both the keystore and its password must be
  retained before public upload.
- Google Play: `NOT_REQUESTED_DIRECT_APK_FIRST`. This candidate is prepared for
  direct APK distribution and does not claim Play readiness.
- public distribution: `PASS`. Public prerelease
  `https://github.com/Kiwunaka/pokrov/releases/tag/v1.0.2-beta.1` contains only
  `pokrov-android-universal.apk`; GitHub reports the exact digest above, and a
  fresh anonymous full download matched both `287207515` bytes and SHA-256.

Every future direct APK update for existing installs must use this same signing
identity and a higher `versionCode`. Losing or replacing the key forces users to
uninstall before installing a differently signed build.

## Prior 2026-08-11 Internal Build

The `1.0.2-core-test.1+6` client was built from the current workspace with the
explicit internal debug-signing override and API base
`https://api.pokrov.space`. This is local emulator evidence only:

- APK: `287255467` bytes, SHA-256
  `761fc44d969f8324137f060d7cdfb2f04bb75e2bec1b8dd7bc402e125a0f79e2`.
- installed base APK identity: `PASS`; the LDPlayer package hash matched the
  local APK byte for byte.
- signing state: `BLOCKED_BY_ACCESS`; all four canonical `ANDROID_SIGNING_*`
  inputs are absent and no production keystore was found in the inspected
  client paths. `apksigner` reports `C=US, O=Android, CN=Android Debug` with
  certificate SHA-256
  `55d2e71b9871459a3d436563f02de5150336201b848f4d9f22d5e247e1520e74`.
- store publication: `NOT_REQUESTED`.
- physical-device audit: `MANUAL_OWNER_TEST`.

The exact APK was installed in LDPlayer 14 instance 0 and its installed base APK
matched the same SHA-256. A clean cold-start sample completed in `1200 ms`. A
fresh disposable production app session traversed Home, Locations, Rules,
Profile, the first-connect route-scope sheet, and Android notification
permission from UI-tree coordinates. The compact Home CTA, neutral disconnected
state, full auto-location heading, readable narrow-phone location rows, and
short route-scope actions rendered without observed clipping.

The exact installed package also passed a launch-only rehearsal of
`android_localhost_audit.py`: `versionName=1.0.2-core-test.1`, `versionCode=6`,
`debuggable=no`, zero baseline listeners, zero listeners after launch, and zero
failures. The report is machine-local at
`%LOCALAPPDATA%/Temp/pokrov-android-localhost-audit-20260811-ldplayer-launch.json`.
During Connect, logcat proved that the Android VPN service started and established
`tun0`. The selected-outbound egress probe then failed in LDPlayer, so the service
stopped the VPN and the UI returned to `Не защищено` with bounded recovery copy.
This is `PASS` for truthful fail-closed behavior and `BLOCKED_BY_ACCESS` for a
working emulator tunnel. Logcat contained no fatal exception, ANR, process death,
or Flutter error. The two disposable QA accounts and all 14 of their panel
mappings were deleted after a production database backup; postcheck returned
zero app-origin users. A later retirement audit found two active orphan
`access_keys` created for those deleted accounts by the legacy capacity-domain
backfill. The backend now classifies bounded trial snapshots as `premium_pool`,
fails closed for non-trial `FREE` snapshots while free delivery is disabled,
and user purge deletes matching access keys. The two exact QA-window orphan
rows were deleted after a second production backup; final postcheck returned
zero active free keys and zero orphan active keys. This emulator preflight does
not replace the mandatory physical-device audit.

The immediately preceding current-workspace APK (`287239083` bytes, SHA-256
`a31e8e5c8b3dd5e57a7f3e1d118bf3972b69ae406381de7746e59d4b17839b3a`)
had the same connect control but predated the narrow-phone access-summary fix.
While its session was still valid, Home, Locations, Rules, Profile, subscription
extension, theme switching, route-mode selection, location selection, and WARP
toggling were traversed from UI-tree coordinates:

- `PASS`: predecessor install, launch, navigation, state persistence, and bounded
  failure presentation.
- `PASS`: Connect entered a truthful busy state and returned to `Не защищено`
  after the LDPlayer runtime failed to establish the tunnel; it never reported a
  protected state.
- `PASS`: logcat contained no fatal exception, ANR, or process death during the
  retained journey.
- `PASS`: the exposed `gfxinfo` sample contained no modern janky frames; the
  sample was only six frames and is not performance-release proof.
- `PASS`: measured total PSS was `93579 KB`; this is an emulator spot check, not
  a physical-device battery or memory gate.
- `BLOCKED_BY_ACCESS`: the working tunnel, reconnect, notification disconnect,
  uplink handoff, DNS, WARP traffic, and long-cycle checks remain unavailable in
  this LDPlayer environment. The predecessor journey is supporting evidence, not
  a substitute for those gates on the latest exact APK.

The live subscription-extension journey opened
`https://pay.pokrov.space/checkout/?plan=1_month` and showed the one-time `99 ₽`
welcome offer as intended. A separate mobile-header wrapping issue found there
was fixed and included in the verified production static deployment. The live
plan catalog returned `239 / 669 / 1199 / 1699 / 1999 ₽` for
`1 / 3 / 6 / 9 / 12` months.

## Current 2026-08-04 Internal Build

The `1.0.2-core-test.1+6` client was built with the explicit internal
debug-signing override. These artifacts are local QA inputs only:

- APK: `287255351` bytes, SHA-256
  `8ece62a64c8f8e7ee45a21778c7c77450406d3150c1aa5a2b70c6fe10c420ba7`.
- AAB: `120573883` bytes, SHA-256
  `7d4351e3a5f9658e6ea7a213d69c80beac8559280b2b2182810660f4683b7e92`.
- production signing: `NOT_REQUESTED`.
- store publication: `NOT_REQUESTED`.

The exact APK was installed over the existing app in LDPlayer 14.0.15 instance
0 and launched successfully. Home, Locations, Rules, and Profile rendered
without a crash. Cached stale locations stayed neutral (`замер устарел`) and did
not expose old latency or health claims. A Connect attempt prepared the profile
but remained fail-closed as `Не защищено` when the device runtime could not
finish, with the bounded message `POKROV не смог завершить действие на
устройстве.` This is `PASS` for exact-artifact install, launch, navigation, and
truthful failure presentation; the real tunnel journey remains
`BLOCKED_BY_ACCESS` in this LDPlayer environment.

## Current Emulator Preflight

The current `2026-08-02` LDPlayer rehearsal candidate is the internal debug APK
with SHA-256
`32387f2054ab0feef8b7112f67cf4c834f5089ffdce0c9ac4d6e2f3628b30785`
and size `401415824` bytes. Production signing and store release were
`NOT_REQUESTED` for this candidate.

- `PASS`: the exact APK installed and launched in LDPlayer 14.0.15 instance 0.
- `PASS`: when the emulator could not reach the control plane, Connect stayed
  fail-closed, did not report a protected state, and showed the bounded recovery
  copy `Не удалось связаться с сервисом. Проверьте сеть и попробуйте ещё раз.`
- `PASS`: cached stale locations rendered without old ping/load or qualitative
  health claims, with neutral signal bars and Russian client-owned access labels.
- `PASS`: the installed-app picker opened over the current Rules state, exposed
  the named search field, listed real installed apps without package identifiers,
  and closed without changing the preserved selected-app state.
- `PASS`: a full LDPlayer instance reboot preserved the selected Amsterdam
  location and trial state; a repeated Connect attempt remained fail-closed and
  restored the same bounded recovery copy instead of reporting protection.
- `BLOCKED_BY_ACCESS`: LDPlayer already had `ADB debugging -> Local connection`
  selected, but its bundled ADB never registered `emulator-5554`. Restarting the
  bundled ADB daemon and rebooting instance 0 did not restore the transport, so
  logcat, UI-tree, gfxinfo, Perfetto, and memory evidence remain unavailable for
  this candidate.
- `BLOCKED_BY_ACCESS`: the full online bootstrap, VPN-permission, tunnel,
  selected-node, reconnect, and disconnect journey was not executed because
  LDPlayer `newNat` selected the active host Hiddify TUN while the guest had no
  usable external path. The bounded recovery is a per-instance LDPlayer bridge
  to the physical adapter, but enabling it can install a bridge driver and sends
  guest traffic directly outside Hiddify; it requires explicit owner approval.

This emulator result is preflight evidence only. It does not supersede the
physical-device and exact release-candidate requirements above.

## Release Rule

The retained `2026-05-15` owner attestation explains the published beta wave;
its exact-candidate production-signing state remains `SKIPPED_BY_OWNER`, and it
does not authorize a rebuild. A new public Android candidate requires
production-signing `PASS` for that exact artifact plus the applicable manual
device gates. A fresh raw physical-device `PASS` remains required before
trusted, store, stable, or raw-audited Android claims.
