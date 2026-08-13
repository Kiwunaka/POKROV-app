# Scripts

This folder contains non-destructive client helpers.

- `validate-seed.ps1` validates the client layout and machine-readable runtime and release contracts.
- `bootstrap-workspace.ps1` restores only missing ignored Flutter/Gradle workstation files and resolves package dependencies.
- `run-tests.ps1` runs the shared runtime, Android, Windows, and Android JVM checks.
- `bootstrap-local.ps1` copies example local configuration without touching production paths unless explicitly forced.
- `sync-pokrov-core-runtime.ps1` copies only the exact POKROV Core 1.0.3 Android and Windows release identities from the separate core checkout after verifying commit, version, sizes, and SHA-256 values.
- `configure-android-production-signing.ps1` creates the one-time self-managed direct-APK signing identity outside the repository, stores its password with Windows DPAPI for the current user, exports only the public certificate, and refuses partial or existing-state overwrite.
- `build-android-production.ps1` loads that local identity only into the current process, builds the universal direct APK plus smaller `arm64-v8a`, `armeabi-v7a`, and emulator-only `x86_64` APKs, rejects Android Debug signing, matches the signer fingerprint, and writes ignored candidate-local signing evidence beside every APK.
- `build-windows-release.ps1` can sync that pinned Windows runtime, validate the client, build the unsigned Flutter bundle, and stage the local installer/ZIP manifest.

POKROV Core is built and released from the separate `POKROV-core` repository.
The client repository does not apply core patches, fetch a mutable latest
release, or maintain a hidden legacy-runtime fallback.

The Windows helper remains local and unsigned. It does not create a
trusted-signed public release, MSIX, store submission, or deploy hook.

The Android signing key is a long-lived update identity. The scripts never put
its private key or password in Git, but the operator must still export a secure
offline recovery copy before public distribution. Losing the key prevents a
direct APK from updating existing installs.

On a clean checkout, `run-tests.ps1` may materialize the ignored Android Gradle
wrapper BAT/JAR before invoking `testDebugUnitTest`. It does not overwrite an
existing wrapper.
