# Windows Release Readiness

Last updated: 2026-06-05

This document is the concrete Windows readiness note for the `POKROV-app` lane.

Historical mapping note:

- older notes may still reference `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/`
- this document now tracks the Windows readiness of the canonical `POKROV-app` repo lane

## Current Truth

- the Windows shell is not a blank stub; it boots the shared app shell and drives the desktop FFI `runtime_engine` lane
- pinned runtime artifacts are synced from `config/runtime-artifacts.seed.json` into `apps/windows_shell/windows/runner/resources/runtime`
- `flutter build windows --release` copies `libcore.dll` next to the Flutter runner in the release bundle
- `scripts/build-windows-release.ps1` now runs the local Windows verification lane: seed validation, tests, `flutter analyze`, `flutter build windows --release`, bundle verification, unsigned portable ZIP staging, and unsigned beta setup EXE staging through Windows `iexpress.exe`
- the seed validation inside that helper now aligns with the current product canon: `Android + Windows` public scope, `iOS + macOS` readiness-only hosts
- the built executable is explicitly marked as a prerelease seed but now presents the public product name `POKROV` in Windows metadata and window chrome
- public download copy must match the actual handoff URL and signing state
- support macros must explain SmartScreen or unknown-publisher behavior for gated beta testers

## Local Verification Commands

From `POKROV-app/`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fetch-libcore-assets.ps1 -Platforms @('windows') -SyncToHosts
powershell -ExecutionPolicy Bypass -File .\scripts\run-tests.ps1
Push-Location .\apps\windows_shell
flutter analyze
flutter build windows --release
Pop-Location
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -SyncRuntime
```

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
  - `libcore.dll`
  - `data/app.so`
  - `data/icudtl.dat`
- staged manifest:
  - `pokrov-windows-beta-x64-<version>.manifest.json`
- staged unsigned beta installer:
  - `pokrov-windows-beta-x64-<version>-setup.exe`

These outputs are regenerated local verification artifacts. They are useful for operator inspection and local validation, but they are not production release truth.

Latest local packaging note:

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
- Phase 6 refreshed GitHub prerelease `v1.0.0-beta` with
  `pokrov-windows-setup-x64.exe`:
  `B4CC0BF82DCFF7F021F7325E513226856B8E1D0686242744888D64D26FB82EBB`.
  The rebuilt asset is now published in the public release-only repository
  `Kiwunaka/pokrov`; unauthenticated range smoke returns `206`.

## Safe Claims

Safe to claim now:

- the Windows host shell uses the real desktop FFI runtime lane
- the Windows connect path now fetches a live managed profile from the app-first API before it stages and starts libcore
- the local release build bundles the pinned runtime artifacts into the Windows runner output
- the Windows seed lane has a reproducible unsigned package step with a manifest, portable ZIP, and first-layer setup EXE for gated beta inspection
- the current `1.0.0-beta` unsigned setup EXE is uploaded to the public
  GitHub prerelease for outside-store beta access
- the current Windows seed connect lane applies runtime options before `libcore start` and prefers a system-proxy host mode with dedicated local ports instead of assuming an elevated TUN session
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
- this lane is shipping truth or release truth for Windows
- this lane by itself is the canonical post-Wave-0 client repo

## External Blockers

- trusted Windows code-signing material is not wired into this lane
- trusted installer signing and `MSIX` publication are still not wired into this lane
- anonymous public artifact hosting is closed through `Kiwunaka/pokrov`;
  stronger updater policy remains distribution scope, not a repo-side blocker
  for the current outside-store beta
- outside-store Windows beta distribution is no longer blocked on unsigned
  posture: the owner accepted unsigned beta risk and the setup EXE is uploaded.
  Stronger broad/trusted distribution remains blocked on signing, live
  exact-artifact runtime route-mode smoke, DNS/leak validation, and public
  anonymous hosting if that surface is required
- this wave does not migrate the current shipping git ownership or release process

## Blocked Runtime Verification

Before public Windows claims, attach evidence for:

- `Full tunnel` route-mode smoke.
- `All except RU` route-mode smoke.
- DNS split behavior and leak checks.
- Connect, reconnect, disconnect, and recovery after failure.
- current-origin, brain-origin, and RU-origin checks where runtime reachability matters.

## Release Rule

Windows outside-store beta upload is complete for `1.0.0-beta` with approved
unsigned-warning posture. Stronger trusted/stable/store claims remain blocked
until live install smoke, trusted signing/SmartScreen reputation,
support-copy evidence, and anonymous/public hosting requirements are approved
for that broader channel.
