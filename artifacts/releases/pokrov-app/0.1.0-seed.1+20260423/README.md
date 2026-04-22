# POKROV App Alpha Bundle `0.1.0-seed.1+20260423`

Built on `2026-04-23` from the canonical next-client workspace:

- source repo: `C:/Users/kiwun/Documents/ai/POKROV-app`
- Android shell: `apps/android_shell`
- Windows shell: `apps/windows_shell`
- archive path: `C:/Users/kiwun/Documents/ai/POKROV-app/artifacts/releases/pokrov-app/0.1.0-seed.1+20260423/`

Included artifacts:

- `pokrov-app-android-release.apk`
- `pokrov-app-android-release.aab`
- `pokrov-next-windows-seed-x64-0.1.0-seed.1.zip`
- `pokrov-next-windows-seed-x64-0.1.0-seed.1.manifest.json`

Signing and release state:

- Android: `flutter build apk --release` and `flutter build appbundle --release` succeeded, but `apps/android_shell/android/app/build.gradle` still uses `signingConfig = signingConfigs.debug` for `release`, so these bundles are valid only for alpha, beta, and operator testing
- Windows: `scripts/build-windows-release.ps1` succeeded and produced the unsigned bundle zip plus manifest; trusted signing, installer packaging, and public hosting are still open blockers

Verified in this run:

- `powershell -ExecutionPolicy Bypass -File .\scripts\validate-seed.ps1`
- `powershell -ExecutionPolicy Bypass -File .\scripts\run-tests.ps1`
- `flutter analyze` in `apps/android_shell`
- `flutter build apk --release` in `apps/android_shell`
- `flutter build appbundle --release` in `apps/android_shell`
- `powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -SyncRuntime -SkipTests`

Not safe to claim:

- production Android signing
- Google Play upload readiness
- trusted Windows signing
- installer or `MSIX` publication for this lane
- public release-truth cutover away from the retained bridge lane
