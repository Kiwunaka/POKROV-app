# Android Release Audit

Status: owner-attested for outside-store beta; raw audit remains manual owner test
Last updated: 2026-07-18

## Required Dependency

Set `ANDROID_AUDIT_SERIAL` to a connected physical Android device. Emulator serials are preflight only and do not clear trusted, store, stable, or raw-audited Android release claims.

Set `ANDROID_AUDIT_PACKAGE` to `space.pokrov.pokrov_android_shell` unless a release candidate intentionally changes the package id.

## Required Checks

- Release APK installed on physical hardware.
- First launch and app-first session bootstrap.
- Connect and disconnect from app.
- Disconnect from foreground notification.
- System VPN permission revoke.
- Relaunch while connected.
- Rapid reconnect.
- Offline or DNS failure warning.
- `All except RU` route-mode smoke.
- `Full tunnel` route-mode smoke.
- DNS split and leak checks for both public routing modes.
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
flutter build apk --release --dart-define=POKROV_API_BASE_URL=https://api.pokrov.space
adb devices
$env:ANDROID_AUDIT_PACKAGE="space.pokrov.pokrov_android_shell"
$env:ANDROID_AUDIT_RELEASE_EVIDENCE="<artifact/version/checksum>"
$env:PLATFORM_REPO="C:\Users\kiwun\Documents\ai\VPN"
python "$env:PLATFORM_REPO/scripts/android_localhost_audit.py" --serial $env:ANDROID_AUDIT_SERIAL --package $env:ANDROID_AUDIT_PACKAGE --release-evidence $env:ANDROID_AUDIT_RELEASE_EVIDENCE --require-release-build --connect-wait-sec 30 --disconnect-wait-sec 15
```

## Release Rule

Android outside-store public beta uses the retained `2026-05-15` owner attestation. A fresh raw physical-device PASS remains required before trusted, store, stable, or raw-audited Android claims.
