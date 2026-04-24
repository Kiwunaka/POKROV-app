# Windows Release Readiness

Last updated: 2026-04-22

This document is the concrete Windows readiness note for the `POKROV-app` lane.

Historical mapping note:

- older retained-bootstrap notes may still reference `app-next/`, but active commands now start from this `POKROV-app` repo root
- the initial local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/`
- this document now tracks the Windows readiness of the canonical `POKROV-app` repo lane

## Current Truth

- the Windows shell is not a blank stub; it boots the shared app shell and drives the desktop FFI `runtime_engine` lane
- pinned runtime artifacts are synced from `config/runtime-artifacts.seed.json` into `apps/windows_shell/windows/runner/resources/runtime`
- `flutter build windows --release` copies `libcore.dll` next to the Flutter runner in the release bundle
- `scripts/build-windows-release.ps1` now runs the local Windows verification lane: seed validation, tests, `flutter analyze`, `flutter build windows --release`, bundle verification, and unsigned zip staging
- the seed validation inside that helper now aligns with the current product canon: `Android + Windows` public scope, `iOS + macOS` readiness-only hosts
- the built executable is explicitly marked as a prerelease seed but now presents the public product name `POKROV` in Windows metadata and window chrome

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

## Expected Local Outputs

- release runner root: `apps/windows_shell/build/windows/x64/runner/Release/`
- staged unsigned bundle root: `apps/windows_shell/build/release_bundle/`
- expected release files:
  - `pokrov_windows_seed.exe`
  - `flutter_windows.dll`
  - `libcore.dll`
  - `data/app.so`
  - `data/icudtl.dat`
- staged manifest:
  - `pokrov-next-windows-seed-x64-<version>.manifest.json`

These outputs are regenerated local verification artifacts. They are useful for operator inspection and local validation, but they are not production release truth.

## Safe Claims

Safe to claim now:

- the Windows host shell uses the real desktop FFI runtime lane
- the Windows connect path now fetches a live managed profile from the app-first API before it stages and starts libcore
- the local release build bundles the pinned runtime artifacts into the Windows runner output
- the Windows seed lane has a reproducible unsigned package step with a manifest and zip for operator inspection
- the current Windows seed connect lane applies runtime options before `libcore start` and prefers a system-proxy host mode with dedicated local ports instead of assuming an elevated TUN session
- this Windows lane now lives in the canonical `POKROV-app` repo
- this Windows lane is the long-term repo target for new client development, but not yet the public release-truth lane

Not safe to claim now:

- the Windows executable is production signed
- an installer or `MSIX` publication flow is ready
- Microsoft Store, WinGet, SmartScreen reputation, or public hosting is approved
- the next-client Windows lane is ready to replace the live bridge Windows release path
- this lane is shipping truth or release truth for Windows
- this lane by itself is the canonical post-Wave-0 client repo

## External Blockers

- trusted Windows code-signing material is not wired into this lane
- installer or `MSIX` publication shape is still undecided
- public artifact hosting, updater policy, and operator handoff stay outside this seed
- the broader next-client cutover is still blocked on signed and publicly proven release evidence across all four platforms
- this wave does not migrate the current shipping git ownership or release process
