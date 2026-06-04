# POKROV App Local MVP Handoff `0.2.0-beta.1+20260603-local-mvp`

Status: local engineering handoff pack after the `2026-06-03` full-client MVP
plan run.

This folder is for local operator/testing handoff. It is not a public release
authorization, not a GitHub Release, not store readiness, not trusted Windows
signing proof, not raw Android physical-audit proof, not RU-origin readiness,
and not production WARP proof.

## Scope

- Android: debug APK smoke artifact only.
- Windows: unsigned beta setup EXE plus portable ZIP from
  `scripts/build-windows-release.ps1`.
- Version line: `0.2.0-beta.1`.
- Client repo: `C:/Users/kiwun/Documents/ai/POKROV-app`.
- Branch/HEAD when packed: `main` / `e87c03b`.
- Worktree state when packed: dirty, with current MVP changes and existing
  unrelated local changes.

## Artifacts

- `pokrov-android-debug-0.2.0-beta.1+20260603-local.apk`
- `pokrov-windows-beta-x64-0.2.0-beta.1-setup.exe`
- `pokrov-windows-beta-x64-0.2.0-beta.1.zip`
- `pokrov-windows-beta-x64-0.2.0-beta.1.manifest.json`
- `SHA256SUMS.txt`
- `release-handoff.json`

## Fresh Verification

- `python -m pytest portal_bot/tests/test_app_first_api.py -q`: `18 passed`
- `python -m pytest tests/test_api_auth_and_tickets.py -q`: `65 passed`
- `packages/app_shell`: `flutter analyze` clean, `flutter test` `49 passed`
- `apps/android_shell`: `flutter analyze` clean, `flutter test` `4 passed`
- `apps/windows_shell`: `flutter analyze` clean, `flutter test` `2 passed`
- `packages/runtime_engine`: `flutter analyze` clean, `flutter test` `11 passed`
- `packages/core_domain`: `dart analyze` clean
- `flutter build apk --debug` in `apps/android_shell`: built debug APK
- `scripts/build-windows-release.ps1 -SyncRuntime -SkipTests -SkipAnalyze`:
  built Windows release runner, staged bundle, ZIP, unsigned setup EXE, and
  manifest

## Known Warnings

- Android debug build emitted Flutter deprecation warnings for Gradle `8.3.0`,
  Android Gradle Plugin `8.1.1`, Kotlin `1.8.22`, and SDK XML version mismatch.
- `pytest` emitted a Windows atexit temp-cleanup `PermissionError` after
  `test_app_first_api.py`, while the command exited `0`.

## Manual / Operator Gates Still Open

- raw Android release-build physical-device audit
- Android release APK/AAB with production signing
- trusted Windows signing / SmartScreen reputation
- public hosting and runtime `APP_*` sync for this exact pack
- real-user Telegram/WebApp opening
- RU-origin reachability proof
- production WARP / enhanced privacy proof
- selected-apps OS enforcement proof

## Safe Local Claim

This pack is a locally verified MVP handoff for inspection/testing. It supports
the next operator decision, but it does not expand public release claims beyond
the already retained outside-store beta evidence.
