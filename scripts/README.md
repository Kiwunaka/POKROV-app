# Scripts

This folder contains non-destructive client helpers.

- `validate-seed.ps1` validates the client layout, machine-readable runtime and
  release contracts, Core compatibility authority, release-handoff v2
  behavior, and the non-mutating cross-repository CI workflow. CI callers pass
  explicit `-PlatformRoot` and `-CoreRoot` values. Only a clean Core checkout
  matching the exact 1.1.0 artifact commit and toolchain reports `PASS`. The
  client workflow may read a newer Core promotion-line checkout only to prove
  its delta is confined to `.github/**`; it then materializes the exact bound
  source commit in a detached worktree for validation.
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
- `sync-pokrov-core-runtime.ps1` copies only the exact POKROV Core 1.1.0 Android and Windows pre-candidate identities from the clean separate Core checkout after verifying commit, version, sizes, and SHA-256 values.
- `configure-android-production-signing.ps1` creates the one-time self-managed direct-APK signing identity outside the repository, stores its password with Windows DPAPI for the current user, exports only the public certificate, and refuses partial or existing-state overwrite.
- `build-android-production.ps1` loads that local identity only into the current process, builds the universal direct APK plus smaller `arm64-v8a`, `armeabi-v7a`, and emulator-only `x86_64` APKs and the market-only `store` AAB. It rejects Android Debug signing, matches the APK and AAB signer fingerprint, verifies the AAB JAR signature and required Core ABI entries, and writes ignored candidate-local signing evidence beside all five artifacts. A successful AAB build records Store submission as `NOT_REQUESTED`; it does not create a candidate or a Store claim.
- `build-windows-release.ps1` can sync that pinned Windows runtime, validate the
  client and stage a local installer manifest. Unsigned output is explicitly
  non-promotable. `-RequireTrustedWindowsSigning` selects one trusted Code
  Signing identity from the Windows certificate store by exact thumbprint,
  requires an HTTPS RFC3161 timestamp, signs and verifies the staged UI,
  service, final installer and Inno embedded uninstaller, and writes only public
  certificate/hash evidence. It accepts no PFX path or password.
  `-CheckTrustedWindowsSigningReadinessOnly` runs the same store, private-key
  presence,
  subject, EKU, validity, trusted-chain and SignTool checks before any build or
  signing and emits only a public receipt with `artifacts_signed=false` and
  `candidate_created=false`.
- `test-windows-exact-candidate.ps1` hash-binds retained candidate.3,
  candidate.8 and candidate.16 installers to their separate
  reviewed inputs, signed manifest/signature identities, exact four-repository
  source tuples and eight installed-file identities. Validation mode is
  non-mutating. The manual `Windows Exact Candidate Clean Host` workflow keeps
  candidate.3 pinned to its private prerelease and fresh GitHub-hosted Windows
  runner. Candidate.8 and candidate.16 additionally permit only their explicit
  owner-authorized current-host modes with distinct confirmation tokens. Each
  current-host mode labels its
  baseline `clean_app_state_only_not_clean_os_or_vm` and cannot emit a clean-VM
  claim. Both smoke modes check install/service identity, authenticated
  UI-to-service IPC, service restart, clean uninstall, and idle
  route/DNS restoration. Sanitized evidence explicitly leaves live TUN,
  DNS capture, egress, recovery, connected uninstall, and SmartScreen as
  `MANUAL_OWNER_TEST`. A failure retains only bounded SCM codes, owner-match
  booleans, event names/outcomes, and SCM event IDs; raw SID and event-message
  content are never exported.
- `build-windows-release.ps1` configures the machine-wide service from checked
  Inno code. Every create/config/description/recovery/start command must return
  zero; a newly created partial service is deleted before the installer aborts.
- `Release v2 Contract` keeps its ordinary PR/push behavior against the active
  promotion lines. Its manual dispatch is the retained-candidate replay lane:
  it requires exact lowercase 40-character client, platform and Core commits,
  checks out that full tuple and rejects branch names, tags and shortened SHAs.
  The replay changes no release pointer or artifact.
- `test/repository-hygiene-contract.ps1` rejects tracked temporary/build output,
  candidate binaries outside the three pinned runtime dependencies, and any
  1.2.0 candidate written into retained `artifacts/releases/`.

`config/support-signing.seed.json` owns the public support-mode verification
pin. Both production build scripts resolve it through
`support-signing-pin.ps1` and inject the matching
`POKROV_SUPPORT_SIGNING_KEY_ID` and
`POKROV_SUPPORT_SIGNING_PUBLIC_KEY_B64` Dart defines. Explicit
`-SupportSigningKeyId` and `-SupportSigningPublicKeyB64` values must be supplied
together and match the tracked pin exactly; partial or different input fails
before Flutter. The pin is public verification material, never the server
private key or support-code HMAC secret. Ordinary development builds do not
load it implicitly.

POKROV Core is built and released from the separate `POKROV-core` repository.
The client repository does not apply core patches, fetch a mutable latest
release, or maintain a hidden legacy-runtime fallback.

Release-handoff schema v2 remains platform-owned. The client generator does
not copy that schema: it binds the exact client revision, shell version, Core
source/version, Android package and AAR digest, Windows desktop ABI and DLL
digest, and canonical observability hashes, then requires the platform offline
validator to accept the result.
Synthetic contract output is temporary evidence, not a release candidate.

The Windows helper does not publish a release, create an MSIX/store submission,
or deploy. Trusted output still needs the exact-candidate clean-host, recovery,
rollback and promotion gates; successful signing alone is not release proof.

The Android signing key is a long-lived update identity. The scripts never put
its private key or password in Git, but the operator must still export a secure
offline recovery copy before public distribution. Losing the key prevents a
direct APK from updating existing installs.

On a clean checkout, `run-tests.ps1` may materialize the ignored Android Gradle
wrapper scripts/JAR before invoking both flavor-specific app unit-test tasks.
It does not overwrite an existing wrapper. The release-v2 GitHub workflow runs
this same standard gate on Ubuntu after cross-repository contract validation.
