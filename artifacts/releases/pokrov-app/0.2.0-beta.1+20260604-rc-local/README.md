# POKROV App 0.2.0-beta.1 local release candidate

Generated: 2026-06-04

This folder is the retained engineering handoff for the refreshed Android and
Windows outside-store beta assets uploaded to GitHub Releases on 2026-06-04.
It is not a store, stable, or trusted-signing release by itself.

## Artifacts

- `pokrov-android-release-smoke-0.2.0-beta.1+20260604.apk`
  - Built with `flutter build apk --release`.
  - Internal beta/release-smoke artifact only.
  - Android release currently uses the internal beta signing path in `apps/android_shell/android/app/build.gradle`.
- `pokrov-android-store-smoke-0.2.0-beta.1+20260604.aab`
  - Built with `flutter build appbundle --release`.
  - Store-format smoke artifact only until production signing and store gates are green.
- `pokrov-windows-beta-x64-0.2.0-beta.1+20260604-setup.exe`
  - Built by `scripts/build-windows-release.ps1`.
  - Unsigned Windows beta installer.
- `pokrov-windows-beta-x64-0.2.0-beta.1+20260604.zip`
  - Portable Windows beta bundle.
- `pokrov-windows-beta-x64-0.2.0-beta.1+20260604.manifest.json`
  - Windows bundle manifest copied from the packaging script output.

## Fresh verification

- `python scripts/run_client_release_gate.py preflight`
- `python scripts/run_client_release_gate.py build --target android-apk`
- `python scripts/run_client_release_gate.py build --target android-aab`
- `powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -SyncRuntime -SkipTests -SkipAnalyze`
- `apksigner verify --verbose --print-certs pokrov-android-release-smoke-0.2.0-beta.1+20260604.apk`
- `Get-AuthenticodeSignature pokrov-windows-beta-x64-0.2.0-beta.1+20260604-setup.exe`
- `gh release upload v0.2.0-beta.1 ... --clobber`
- `curl --range 0-0` against both GitHub release asset URLs
- `gh release download v0.2.0-beta.1` followed by SHA-256 comparison

## Signing truth

- Android APK verifies with APK Signature Scheme v2 and is signed by
  `C=US, O=Android, CN=Android Debug`.
- Android AAB is also signed by the Android Debug certificate and does not have
  a trusted public certificate chain.
- Windows setup EXE is `NotSigned`.
- The staged Windows runner EXE is also `NotSigned`.
- Owner decision on 2026-06-04: the current outside-store beta release is
  allowed without production Android signing and without trusted Windows
  signing, as long as public copy does not claim trusted/store distribution.

## Remaining release gates

- Production Android signing inputs are not configured in this local handoff,
  and are an accepted skip for the current outside-store beta.
- Android physical-device release-build localhost/control-surface audit remains `MANUAL_OWNER_TEST`.
- Windows trusted signing is not configured and is an accepted skip for the
  current outside-store beta; unsigned-warning copy remains required.
- Public upload, public download smoke, real-user Telegram/WebApp check, and live runtime sync remain operator release tasks.
- Public GitHub upload, current-origin public URL smoke, and brain-origin
  `/api/client/apps` smoke passed on 2026-06-04. No runtime `APP_*` mutation
  was required because the public URLs stayed stable.
- RU-origin proof remains manual and must not be claimed from this package alone.
- WARP remains an info/roadmap feature, not an enabled production feature.

## Next operator action

Use `OPERATOR_HANDOFF.md` for the manual review, install smoke, upload, and
runtime-sync checklist.
