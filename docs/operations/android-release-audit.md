# Android Release Audit

Status: blocked by missing access  
Last updated: 2026-04-26

## Required Dependency

Set `ANDROID_AUDIT_SERIAL` to a connected physical Android device. Emulator serials are preflight only and do not clear public release.

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
- No unexpected localhost/control ports exposed.
- No sensitive external control surface.
- Uninstall/reinstall cleanup.
- Battery/background sanity.
- Small-screen accessibility screenshot.

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

Android public release remains blocked until this audit is green on a physical release-installed build.
