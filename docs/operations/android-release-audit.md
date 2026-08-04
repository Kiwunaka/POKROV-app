# Android Release Audit

Status: owner-attested for outside-store beta; raw audit remains manual owner test
Last updated: 2026-08-02

## Required Dependency

Set `ANDROID_AUDIT_SERIAL` to a connected physical Android device. Emulator serials are preflight only and do not clear trusted, store, stable, or raw-audited Android release claims.

Set `ANDROID_AUDIT_PACKAGE` to `space.pokrov.pokrov_android_shell` unless a release candidate intentionally changes the package id.

## Required Checks

- Release APK installed on physical hardware.
- First launch and app-first session bootstrap.
- Connect and disconnect from app.
- Confirm the exact APK contains POKROV Core 1.0.2 `libpokrov-core.so` from
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
# Public-candidate builds require all four operator-owned signing inputs.
$env:ANDROID_SIGNING_KEY="<absolute-keystore-path>"
$env:ANDROID_SIGNING_STORE_PASSWORD="<operator-secret>"
$env:ANDROID_SIGNING_KEY_PASSWORD="<operator-secret>"
$env:ANDROID_SIGNING_KEY_ALIAS="<operator-key-alias>"
flutter build apk --release --dart-define=POKROV_API_BASE_URL=https://api.pokrov.space
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
