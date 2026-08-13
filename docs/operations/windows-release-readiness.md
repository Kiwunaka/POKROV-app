# Windows Release Readiness

Last updated: 2026-08-13

This document is the concrete Windows readiness note for the `POKROV-app` lane.

Historical mapping note:

- older notes may still reference `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/`
- this document now tracks the Windows readiness of the canonical `POKROV-app` repo lane

## Current Truth

- the Windows shell is not a blank stub; it boots the shared app shell and drives the desktop FFI `runtime_engine` lane
- the active runtime is POKROV Core `v1.0.3` desktop ABI 2; its exact release commit, DLL hash, and `libcronet.dll` hash are pinned in `config/runtime-artifacts.seed.json`
- `flutter build windows --release` copies `pokrov-core.dll` and `libcronet.dll` next to the Flutter runner
- `scripts/sync-pokrov-core-runtime.ps1` accepts only the exact locally built core commit and artifacts before syncing them into the host
- `scripts/build-windows-release.ps1` now runs the local Windows verification lane: seed validation, tests, `flutter analyze`, `flutter build windows --release`, bundle verification, unsigned portable ZIP staging, and unsigned beta setup EXE staging through Windows `iexpress.exe`
- the seed validation inside that helper now aligns with the current product canon: `Android + Windows` public scope, `iOS + macOS` readiness-only hosts
- the built executable is explicitly marked as a prerelease seed but now presents the public product name `POKROV` in Windows metadata and window chrome
- app-first session secrets must not remain in plaintext JSON state; the current source implements legacy `session_token` migration into platform secure storage, atomically replaces the JSON state, and writes only a `session_token_storage=secure` marker after a durable write; a marker whose platform secret is missing enters recovery instead of minting another trial, while exact-artifact restart proof remains a release gate
- local runtime/control surfaces must stay loopback-only: mixed/system-proxy ports bind to `127.0.0.1`, Clash/control APIs stay disabled unless explicitly protected by a per-install random secret, and no unauthenticated LAN listener is release-acceptable
- public download copy must match the actual handoff URL and signing state
- support macros must explain SmartScreen or unknown-publisher behavior for gated beta testers
- the shell opens centered at 1280x720, permits resize down to 700x640 so the
  canonical compact drawer remains reachable, and hides to tray on window
  close; tray `Выход` disposes tray state before requesting native teardown
- source and widget tests prove lifecycle ordering, but connected exact-artifact
  tray exit still requires runtime/TUN teardown and any compatibility
  system-proxy restoration proof

## Current 2026-08-13 Candidate State

- The current public outside-store Windows beta is `v1.0.3-beta.2`. Its
  unsigned setup SHA-256 is
  `7EE28D1FF058E3E09FEF05EDB496E6C44B2783235FFB1A4C25A3925E523CF70A`;
  its portable ZIP SHA-256 is
  `66D2081D1674C96F3E9F24EDE4CB3F0909397C49C3CD167FE00241141A97B7A8`.
  These hashes describe the published candidate only.
- Current source is newer than that public candidate. A fresh local
  `1.0.3-beta.2+11` build hides paid-only Telegram/reward actions on trial,
  labels the trial reward gate explicitly, and keeps paid referral share/copy
  actions available. Shared-shell widget tests pass and the rebuilt EXE was
  visually checked at `1600x900`.
- The source-newer local setup SHA-256 is
  `800DD66313A2972609BA0572C0AF05EB991BF01A9B52FA2813492B119114BBC1`;
  its portable ZIP SHA-256 is
  `717FD7AEDE508C1FA7F3FCD3F34816EABC1EC17173020A874A8A7567E822A74D`.
  It deliberately shares the old build version while QA is still active and
  must not overwrite the public `beta.2`; publication requires a new version.
- The rebuilt setup remains `NotSigned`. The accepted outside-store beta risk
  does not turn that result into trusted signing or SmartScreen reputation.
- Retained visual evidence is under
  `E:/POKROV-ops-evidence/2026-08-13-goal-continuation/windows-app-audit/`.

## Local Verification Commands

From `POKROV-app/`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-pokrov-core-runtime.ps1 -CoreRoot '<POKROV-core checkout>' -Platforms windows
powershell -ExecutionPolicy Bypass -File .\scripts\run-tests.ps1
Push-Location .\apps\windows_shell
flutter analyze
flutter build windows --release
Pop-Location
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -SyncRuntime
```

After launching the exact candidate once, resolve its live application-support
directory from diagnostics and inspect the state file there:

```powershell
$statePath = '<application-support-path>\app-first-session-windows.json'
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
if ($null -ne $state.session_token) { throw 'Raw session_token remains in JSON state.' }
if ($state.session_token_storage -ne 'secure') { throw 'Secure-storage marker is missing.' }
```

Restart the candidate and perform an authenticated profile refresh before
accepting this check. Expected result: no raw `session_token` value in app
state, support export, or logs, and the existing session still works.
The runtime options test must also keep LAN control exposure closed:
`allow-connection-from-lan=false`, `enable-clash-api=false`, and local ports on
`127.0.0.1` only unless a future release explicitly documents a protected
control API.

For a gated beta packaging smoke where tests/analyze already ran:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -SyncRuntime -SkipTests -SkipAnalyze
```

If the local Flutter/Dart toolchain fails in the online `pub.dev` security-advisory report while the dependency cache is already populated, rerun with `-OfflinePubGet`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -SyncRuntime -OfflinePubGet
```

## Expected Local Outputs

- release runner root: `apps/windows_shell/build/windows/x64/runner/Release/`
- staged unsigned bundle root: `apps/windows_shell/build/release_bundle/`
- expected release files:
  - `pokrov_windows_beta.exe`
  - `flutter_windows.dll`
  - `pokrov-core.dll`
  - `libcronet.dll`
  - `data/app.so`
  - `data/icudtl.dat`
- staged manifest:
  - `pokrov-windows-beta-x64-<version>.manifest.json`
- staged unsigned beta installer:
  - `pokrov-windows-beta-x64-<version>-setup.exe`

These outputs are regenerated local verification artifacts. They are useful for operator inspection and local validation, but they are not production release truth.

Historical local packaging notes:

- `2026-06-03`: `scripts/build-windows-release.ps1 -SyncRuntime -SkipTests -SkipAnalyze`
  succeeded after the full Task 8 verification run.
- The generated unsigned setup EXE, portable ZIP, manifest, and the Android
  debug smoke APK were retained in
  `artifacts/releases/pokrov-app/0.2.0-beta.1+20260603-local-mvp/`.
- This retained pack remains local engineering handoff, not trusted signing or
  public hosting approval.
- `2026-06-04`: the same packaging command succeeded again for the local RC
  pass after Android release-smoke APK/AAB builds. The generated unsigned setup
  EXE, portable ZIP, and manifest were retained in
  `artifacts/releases/pokrov-app/0.2.0-beta.1+20260604-rc-local/` with
  verified checksums and `runtime_sync_allowed=false`.
- Owner decision on `2026-06-04`: trusted Windows signing is an accepted skip
  for the current outside-store beta, but trusted signing, SmartScreen
  reputation, Microsoft Store, WinGet, and broad stable-distribution claims are
  still not allowed.
- `2026-06-05`: `scripts/build-windows-release.ps1 -SyncRuntime -SkipTests
  -SkipAnalyze` succeeded after the P5/WARP pass and produced local
  `1.0.0-beta` unsigned artifacts under
  `apps/windows_shell/build/release_bundle/pokrov-windows-beta-x64-1.0.0-beta*`.
- Phase 6 uploaded `pokrov-windows-setup-x64.exe` on `2026-06-05`; its
  recorded hash is dated evidence and was superseded by the `2026-06-08`
  refresh. Read `config/release-handoff.seed.json` for the current exact
  filename, hash, size, public repository, and download-smoke state.

## Current 2026-08-13 Core Gate

The exact POKROV Core `v1.0.3` DLL pinned in
`config/runtime-artifacts.seed.json` completed 100 serial raw start/stop cycles
through the real desktop bindings. This is `PASS` for DLL loading and lifecycle
shutdown only. A new packaged Windows client candidate, private ACL, TUN
traffic, route modes, DNS/leak, real WARP, sleep/resume, and clean-machine
checks remain required.

## Retained 2026-08-04 Internal Build

The unsigned `1.0.2-core-test.1` Windows client completed the canonical local
release pipeline. The exact local QA artifacts are:

- portable ZIP: `37506815` bytes, SHA-256
  `4a37bc459c582c3ebd368dbc3875382893a7dd951a053fbaf9b39b7624bbbd94`.
- setup EXE: `37392384` bytes, SHA-256
  `27ac017896eeba18b7b5ad9077f731effefe425e556160ee6bfca41fbcbc9570`.
- manifest: `2675` bytes, SHA-256
  `903ebd2de8ae471479e1c133abaf618fe205d75d7109d69d09a1d24b61840d99`.
- trusted signing and public publication: `NOT_REQUESTED`.

The exact bundled DLL also passed the 100-cycle local runtime gate. Packaged
TUN traffic, elevation, sleep/resume, and clean-machine installation remain
manual exact-candidate checks.

## Safe Claims

Safe to claim now:

- the Windows host shell uses the real desktop FFI runtime lane
- the Windows connect path fetches a live managed profile, materializes route mode and optional WARP in Dart, secures the staged file, and starts POKROV Core through desktop ABI 2
- the local release build bundles the pinned POKROV DLL and `libcronet.dll` into the Windows runner output
- the Windows seed lane has a reproducible unsigned package step with a manifest, portable ZIP, and first-layer setup EXE for gated beta inspection
- the current `v1.0.3-beta.2` unsigned setup EXE and portable ZIP are uploaded
  to the public GitHub prerelease for outside-store beta access
- the current Windows source materializes `Full tunnel`, `All except RU`,
  selected-process routing, and client-local WARP into raw config before the
  POKROV Core start call; system proxy remains a disabled compatibility-only path
- this source-level change does not prove elevation, route capture, DNS/leak
  behavior, or teardown on the published or any future exact candidate
- this Windows lane now lives in the canonical `POKROV-app` repo
- this Windows lane is the current repo-backed outside-store beta release truth
  for Windows, but not a trusted-signed, store, or broad stable distribution
  lane
- unsigned Windows builds may be used for gated beta only with explicit SmartScreen or unknown-publisher warning guidance

Not safe to claim now:

- the Windows executable is production signed
- a trusted-signed production installer or `MSIX` publication flow is ready
- Microsoft Store, WinGet, or SmartScreen reputation is approved
- the Windows lane is approved for broad public distribution
- this lane is trusted-signed, store, or stable release truth for Windows
- this repo alone authorizes a later candidate without its own current handoff
  and evidence

## External Blockers

- trusted Windows code-signing material is not wired into this lane
- trusted installer signing and `MSIX` publication are still not wired into this lane
- anonymous public artifact hosting is closed through `Kiwunaka/pokrov`;
  stronger updater policy remains distribution scope, not a repo-side blocker
  for the current outside-store beta
- outside-store Windows beta distribution is no longer blocked on unsigned
  posture: the owner accepted unsigned beta risk and the setup EXE is uploaded.
  Stronger broad/trusted distribution remains blocked on signing, live
  exact-artifact runtime route-mode smoke, and DNS/leak validation
- platform publishing policy remains outside this client readiness document

## Blocked Runtime Verification

The current outside-store beta handoff remains valid for its recorded
candidate. Before reusing that result for a later candidate or making stronger
trusted/stable claims, attach:

- exact-artifact install, restart, session restore, secure-storage, and
  selected-app process-routing smoke: `MANUAL_OWNER_TEST`.
- POKROV Core ABI/export/hash probe is locally complete; clean-profile traffic,
  Naive/libcronet loading, Windows version compatibility, and user-only ACL
  behavior inside the packaged exact candidate remain `MANUAL_OWNER_TEST`.
- The rebuilt exact DLL completed 100 serial raw start/stop cycles locally.
  This is `PASS` for the narrow DLL shutdown backtest only; sleep/resume,
  interface changes, permission/elevation, real WARP, Naive/Cronet, and packaged
  TUN behavior remain `MANUAL_OWNER_TEST`.
- `Only selected apps` picker, persistence, route-policy echo, and generated
  `process_name` / `process_path` behavior.
- `Full tunnel` route-mode smoke.
- `All except RU` route-mode smoke.
- DNS split behavior and leak checks.
- Connect, reconnect, disconnect, and recovery after failure.
- Close while connected -> hidden tray state -> reopen without losing the
  running session; then tray `Выход` -> process/runtime and TUN stop, plus any
  compatibility system-proxy restoration: `MANUAL_OWNER_TEST` for the exact
  candidate.
- current-origin, brain-origin, and RU-origin checks where runtime reachability matters.

## Release Rule

Windows outside-store beta upload is complete for `v1.0.3-beta.2` with approved
unsigned-warning posture. Current source is newer and cannot reuse that release
identity. Stronger trusted/stable/store claims remain blocked until the next
exact artifact passes live install/restart/secure-storage smoke, trusted
signing/SmartScreen reputation, support-copy evidence, and the target channel's
publishing requirements are approved.
