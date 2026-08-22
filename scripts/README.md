# Scripts

This folder contains non-destructive client helpers.

- `validate-seed.ps1` validates the client layout, machine-readable runtime and
  release contracts, Core compatibility authority, release-handoff v2
  behavior, and the non-mutating cross-repository CI workflow. CI callers pass
  explicit `-PlatformRoot` and `-CoreRoot` values. A clean checkout matching the
  pinned artifact commit and toolchain reports `PASS`; a compatible Core tree
  with the declared replacement still pending reports
  `DEVELOPMENT_REPLACEMENT_PENDING` (or its dirty variant) and never becomes
  exact artifact proof.
- `new-release-handoff-v2.ps1` generates strict candidate metadata from an
  explicit input plus client-owned version/Core facts, validates it with the
  platform validator, carries the version-matched release-note summary and URL,
  refuses dirty non-test generation, and never writes into retained
  `artifacts/releases/` or another tracked client-source destination. Use
  ignored `artifacts/candidate-staging/`, a temporary directory, or the separate
  release-index checkout.
- `set-release-stable-pointer.ps1` validates the stable pointer and every exact
  target in `config/release-rollback-catalog.seed.json`. Switching is a dry run
  unless `-Apply` is explicit; apply requires an expected current release,
  same-filesystem backup outside `artifacts/releases`, atomic replacement, exact
  readback, and a non-overwriting receipt. Candidate and public gates remain
  separate authorization requirements.
- `validate-observability-contracts.ps1` verifies the platform-owned event
  schema and error catalog, then requires client and Core version/SHA snapshots
  to match before candidate metadata is generated.
- `check-release-source-logging.ps1` fails if production Dart, Android, or
  Windows source writes to raw stdout, developer logs, Logcat, native debug
  output, or serializes raw exceptions inside the observability runtime.
- `collect-client-performance-samples.ps1` emits only bounded numeric JSON
  samples. It can measure Windows idle CPU/working-set and exact artifact size,
  or normalize samples captured by approved Android/Flutter tooling. It never
  calls a provider, reads client logs, invents a cold-start timestamp, or writes
  into retained `artifacts/releases/` evidence.
- `bootstrap-workspace.ps1` restores only missing ignored Flutter/Gradle workstation files and resolves package dependencies.
- `run-tests.ps1` is the platform-correct Windows/Linux PowerShell gate. It
  analyzes testless foundation packages and tests every test-bearing module
  across all 11 modules, including both observability packages and typed diagnostic
  collectors, the encryption-only support-bundle package, the shared runtime,
  Android, Windows, and both direct/store Android JVM checks through the native
  `gradlew.bat` or `gradlew` wrapper. The observability
  and support gates cover privacy, queue, retention, legacy-reader, planted
  secret, deterministic manifest, signed-contract and encryption regressions.
- `config/state-migrations.v1.json` is validated by `validate-seed.ps1` and the
  app-shell contract suite. It checksum-binds the supported synthetic 1.1.x
  session/preferences/Android-profile fixtures to their 1.2.0 migration and
  rollback regressions; update cache and Windows recovery remain explicit
  non-migrating state with their own tests.
- `bootstrap-local.ps1` copies example local configuration without touching production paths unless explicitly forced.
- `sync-pokrov-core-runtime.ps1` copies only the exact POKROV Core 1.0.3 Android and Windows release identities from the separate core checkout after verifying commit, version, sizes, and SHA-256 values.
- `configure-android-production-signing.ps1` creates the one-time self-managed direct-APK signing identity outside the repository, stores its password with Windows DPAPI for the current user, exports only the public certificate, and refuses partial or existing-state overwrite.
- `build-android-production.ps1` loads that local identity only into the current process, builds the universal direct APK plus smaller `arm64-v8a`, `armeabi-v7a`, and emulator-only `x86_64` APKs, rejects Android Debug signing, matches the signer fingerprint, and writes ignored candidate-local signing evidence beside every APK.
- `build-windows-release.ps1` can sync that pinned Windows runtime, validate the client, build the unsigned Flutter bundle, and stage the local installer/ZIP manifest.
- `test/repository-hygiene-contract.ps1` rejects tracked temporary/build output,
  candidate binaries outside the three pinned runtime dependencies, and any
  1.2.0 candidate written into retained `artifacts/releases/`.

Both release build scripts accept the public support-key verification pair
`-SupportSigningKeyId` and `-SupportSigningPublicKeyB64`. Supply both or neither;
partial configuration fails before build. They become the matching
`POKROV_SUPPORT_SIGNING_KEY_ID` and
`POKROV_SUPPORT_SIGNING_PUBLIC_KEY_B64` Dart defines. These values are public
verification material, not recipient private keys. Leaving them blank keeps
encrypted bundle delivery disabled and preserves the short-summary support path.

POKROV Core is built and released from the separate `POKROV-core` repository.
The client repository does not apply core patches, fetch a mutable latest
release, or maintain a hidden legacy-runtime fallback.

Release-handoff schema v2 remains platform-owned. The client generator does
not copy that schema: it binds the exact client revision, shell version, Core
source/version, Android package and AAR digest, Windows desktop ABI and DLL
digest, and canonical observability hashes, then requires the platform offline
validator to accept the result.
Synthetic contract output is temporary evidence, not a release candidate.

The Windows helper remains local and unsigned. It does not create a
trusted-signed public release, MSIX, store submission, or deploy hook.

The Android signing key is a long-lived update identity. The scripts never put
its private key or password in Git, but the operator must still export a secure
offline recovery copy before public distribution. Losing the key prevents a
direct APK from updating existing installs.

On a clean checkout, `run-tests.ps1` may materialize the ignored Android Gradle
wrapper scripts/JAR before invoking both flavor-specific app unit-test tasks.
It does not overwrite an existing wrapper. The release-v2 GitHub workflow runs
this same standard gate on Ubuntu after cross-repository contract validation.
