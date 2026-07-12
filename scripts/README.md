# Scripts

This folder is for non-destructive local helpers only.

Current helpers:

- `validate-seed.ps1`: checks that the Wave 7 scaffold files, four host shells, starter packages, and JSON config seeds exist
- `bootstrap-workspace.ps1`: conditionally creates an isolated GUID-named temporary Flutter Android project with `--no-overwrite`, copies only a missing ignored Gradle wrapper BAT/JAR into the existing shell, removes the verified temporary directory, then runs `flutter pub get` across the clean-room packages and four host entrypoints; pass `-OfflinePubGet` when an old Flutter/Dart pub advisory fetch breaks online dependency resolution but the local package cache is already populated
- `run-tests.ps1`: bootstraps the workspace, runs the shared, runtime, Android, and Windows Flutter tests, then runs Android `testDebugUnitTest`; accepts `-OfflinePubGet` and forwards it to bootstrap
- `bootstrap-local.ps1`: copies example config seeds into `config/local/` without touching production paths unless explicitly forced
- `build-windows-release.ps1`: validates the seed, optionally syncs Windows runtime artifacts, runs analyze and tests, builds `flutter build windows --release`, verifies the release bundle, and stages an unsigned setup EXE, portable ZIP, and manifest under `apps/windows_shell/build/release_bundle`; accepts `-OfflinePubGet` for known-good cached release reruns when online pub advisories are broken

The Windows helper is still local and unsigned. It does not create a trusted-signed public release, `MSIX`, store submission, or deploy hook.

On a clean checkout, `run-tests.ps1` materializes the ignored `apps/android_shell/android/gradlew.bat` and `apps/android_shell/android/gradle/wrapper/gradle-wrapper.jar` before invoking `testDebugUnitTest`. Repair runs outside the tracked app project and never overwrites an existing destination file. These generated workstation files are not tracked release artifacts or product truth.
