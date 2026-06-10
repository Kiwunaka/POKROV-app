# POKROV 0.2.0-beta.1 local RC operator handoff

Generated: 2026-06-04

## Decision

This folder records the refreshed GitHub prerelease assets, but it is blocked
from public release and runtime sync until production Android signing and
trusted Windows signing are verified.
Owner decision on 2026-06-04: debug-signed Android artifacts and unsigned
Windows artifacts must not be offered as public release downloads. GitHub
upload, current-origin URL smoke, and brain-origin runtime handoff smoke do not
override the signing block.

## Payload candidates

- Android gated beta APK:
  `pokrov-android-release-smoke-0.2.0-beta.1+20260604.apk`
- Windows gated beta installer:
  `pokrov-windows-beta-x64-0.2.0-beta.1+20260604-setup.exe`
- Windows portable/operator ZIP:
  `pokrov-windows-beta-x64-0.2.0-beta.1+20260604.zip`

The AAB is retained as store-format smoke evidence, not as a public beta
download payload.

## Local evidence already collected

- RC inventory is present.
- `SHA256SUMS.txt` matches retained files after local verification.
- `release-handoff.json` parses.
- Windows manifest parses.
- Android APK verifies with APK Signature Scheme v2.
- Android APK/AAB use Android Debug certificate.
- Windows setup EXE and runner EXE are unsigned.
- Windows ZIP contains `pokrov_windows_beta.exe`, `libcore.dll`,
  `flutter_windows.dll`, `data/app.so`, and `data/icudtl.dat`.
- Unsigned/untrusted signing state is a blocking gate before public release or
  runtime sync.
- GitHub prerelease `v0.2.0-beta.1` was refreshed with:
  - `pokrov-android-universal.apk`
  - `pokrov-windows-setup-x64.exe`
- Current-origin `curl --range 0-0` returned `206` for both public URLs.
- `gh release download` returned files whose SHA-256 values match the local RC.
- Brain-origin `/api/client/apps` smoke passed and returned the same Android,
  Windows, and docs URLs.

## Manual owner checks

1. Install the APK on a physical Android device.
2. Confirm the installed package starts and shows the expected POKROV shell.
3. Run start-trial -> profile -> connect -> dashboard.
4. Run disconnect and reconnect.
5. Confirm no localhost/control-surface is reachable without the expected app path.
6. Install the Windows setup EXE on a clean Windows user profile.
7. Confirm the unsigned SmartScreen/unknown-publisher warning copy is visible where needed.
8. Run start-trial -> profile -> connect -> dashboard on Windows.
9. Test support chat, cabinet handoff, redeem code, Telegram bonus, and checkout continuation.
10. Verify production Android signing and trusted Windows signing before any public beta upload or runtime sync.

## Remaining live smoke gate

GitHub upload and runtime URL handoff are not sufficient for release. Before any public announcement or runtime sync:

- production Android signing is verified;
- trusted Windows signing is verified;
- real-user Telegram/WebApp check is recorded;
- live install -> start-trial -> profile -> connect smoke is recorded on the
  exact production-signed APK/EXE.

## Claims allowed after this handoff

- Local Android release-smoke APK exists.
- Local Android store-smoke AAB exists.
- Local Windows unsigned setup and ZIP exist.
- Local checksums and signing truth are recorded.
- Current outside-store beta remains blocked until production Android signing
  and trusted Windows signing are verified.

## Claims still not allowed

- Android production signing is ready.
- Play/App Store release is ready.
- Windows trusted signing is ready.
- SmartScreen reputation is established.
- RU-origin readiness is proven.
- WARP is production-enabled.
- Runtime download values are safe to sync.
