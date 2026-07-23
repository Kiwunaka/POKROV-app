# Scripts

This folder contains non-destructive client helpers.

- `validate-seed.ps1` validates the client layout and machine-readable runtime and release contracts.
- `bootstrap-workspace.ps1` restores only missing ignored Flutter/Gradle workstation files and resolves package dependencies.
- `run-tests.ps1` runs the shared runtime, Android, Windows, and Android JVM checks.
- `bootstrap-local.ps1` copies example local configuration without touching production paths unless explicitly forced.
- `sync-pokrov-core-runtime.ps1` copies the exact POKROV Core 1.0.0 Android and Windows artifacts from the separate core checkout after verifying its commit, version, file sizes, and SHA-256 values.
- `build-windows-release.ps1` can sync that pinned Windows runtime, validate the client, build the unsigned Flutter bundle, and stage the local installer/ZIP manifest.

POKROV Core is built and released from the separate `POKROV-core` repository.
The client repository does not apply core patches, fetch a mutable latest
release, or maintain a hidden legacy-runtime fallback.

The Windows helper remains local and unsigned. It does not create a
trusted-signed public release, MSIX, store submission, or deploy hook.

On a clean checkout, `run-tests.ps1` may materialize the ignored Android Gradle
wrapper BAT/JAR before invoking `testDebugUnitTest`. It does not overwrite an
existing wrapper.
