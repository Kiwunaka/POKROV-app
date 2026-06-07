# Phase 6 Release-Beta Handoff

Date: 2026-06-05

## Scope

This closes the local `1.0.0-beta` Phase 6 evidence refresh for the active
`POKROV-app/main` client lane.

The initial Phase 6 binary refresh was built from
`c03ded35ea2dbb3e64377302d2744e640a802540`. The Android APK was refreshed again
after the Android toolchain update at
`e494d9bbf6767780be1b39af6fc4c2785f61cda7`. Later commits only update release
evidence and handoff metadata.

## Decision Scope

Included active decision sources:

- `docs/decisions/2026-06-03-client-ux-account-rewards-master-brief.md`
- `docs/decisions/2026-06-03-client-best-mvp-consilium.md`
- `docs/decisions/2026-06-03-client-chat-responsive-warp-motion-review.md`
- `docs/decisions/2026-06-03-hiddify-karing-happ-client-base-review.md`
- `docs/decisions/2026-06-03-hiddify-core-warp-status.md`
- `docs/specs/2026-06-05-p5-warp-approved-design.md`
- `docs/superpowers/plans/2026-06-05-premium-client-ai-assistant-architecture.md`
- `docs/implementation/2026-06-04-decisions-implementation-map.md`

Ignored owner-deprecated inputs:

- `docs/decisions/2026-06-02-karing-base-reopen.md`
- `docs/decisions/2026-04-18-karing-vs-clean-room-gate.md`

## What Is Implemented For Beta

- App-first first launch, returning-user restore, unified redeem, cabinet
  handoff, Telegram bonus entry, account/profile basics, and support entry.
- Embedded support chat with ticket-backed polling lifecycle, operator-reply
  hints, explicit redacted diagnostic attachment, Telegram fallback, and
  support-scoped AI helper suggestions.
- Rewards hub with bonus summary, referral, promo slots, muted wheel/calendar
  states, and live wheel/calendar actions only when backend flags mark them
  enabled.
- Rules presets and selected-apps mode with Android installed-app bridge,
  Windows running-process/discovered-exe suggestions, manual fallback, and
  platform policy plumbing.
- Smart-connect/profile bootstrap, route-mode sync, location state, and
  consumer-safe diagnostics without raw profiles, hostnames, keys, or topology.
- Guarded WARP/enhanced-protection feature: backend policy, encrypted material
  provisioning contract, consent/revoke/event lifecycle, safe local consent
  cache, hiddify-core option mapping only when runtime-ready and consented,
  fallback reporting, and redacted admin/support telemetry.
- Premium UX foundation: responsive shell at `360`, `700`, `900`, `1024`,
  `1180`, and `1440`, desktop sidebar collapse/opacity, connect-disc ritual,
  status crossfade/slide, tactile rows/chips, geometry-matched skeletons,
  muted disabled states, and Windows shortcuts.
- In-app AI assistant contract: support-scoped helper, redacted diagnostics,
  safe suggestions, escalation-aware API plan, and no fake operator presence.

## Fresh Verification

- `python scripts/run_client_release_gate.py preflight` from the platform root:
  pass.
- `flutter test test/assistant_contract_test.dart test/warp_lifecycle_contract_test.dart test/app_first_runtime_bootstrap_test.dart test/pokrov_seed_app_test.dart`
  in `packages/app_shell`: `91 passed`.
- `flutter analyze` in `packages/app_shell`: no issues found.
- `python scripts/run_client_release_gate.py build --target android-apk`:
  pass; rebuilt `apps/android_shell/build/app/outputs/flutter-apk/app-release.apk`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -SyncRuntime -SkipTests -SkipAnalyze`:
  pass; rebuilt unsigned Windows setup EXE, portable ZIP, bundle, and manifest.
- `gh release upload v1.0.0-beta ... --clobber`: pass.
- `gh release download v1.0.0-beta --pattern SHA256SUMS.txt`: pass.
- final authenticated release download smoke:
  `gh release download v1.0.0-beta --pattern SHA256SUMS.txt --pattern
  pokrov-android-universal.apk --pattern pokrov-windows-setup-x64.exe
  --pattern pokrov-windows-portable-x64.zip --pattern
  pokrov-windows-1.0.0-beta.manifest.json`: pass; all downloaded assets match
  retained SHA-256 values.

Known build warnings:

- The prior Flutter Android Gradle, Android Gradle Plugin, and Kotlin
  future-support warnings were closed by the later Android toolchain refresh:
  Gradle `8.11.1`, Android Gradle Plugin `8.9.1`, Kotlin `2.1.0`.
- Android command-line SDK XML warning remains a toolchain maintenance item.

## Uploaded Assets

Public GitHub prerelease:

`https://github.com/Kiwunaka/pokrov/releases/tag/v1.0.0-beta`

Assets:

- `pokrov-android-universal.apk`
  - size: `189689484`
  - sha256: `3676A18B06C3D5CE4BE82F9C93A4F1EA83DAB72206A06F13B066A37746A8268D`
- `pokrov-windows-setup-x64.exe`
  - size: `28291072`
  - sha256: `40D345F139185F367B28A2B7FDDD48A486A0ACB4D34BE04CFFBB624496455433`
- `pokrov-windows-portable-x64.zip`
  - size: `28384659`
  - sha256: `3D87311BBA0B8DF3D44CC9B2DA5D488157B1961D5353B1B83F1025F8374C7AAE`
- `pokrov-windows-1.0.0-beta.manifest.json`
  - size: `3381`
  - sha256: `1DF313B6ABC19C06C31D2592F3AEE6A258C421F846C5D5D756F34E432B4D2C96`

Public download note:

- The development repository remains private.
- Public user downloads now live in the release-only repository
  `Kiwunaka/pokrov`.
- Unauthenticated current-origin range requests return `206` for Android APK,
  Windows setup EXE, Windows portable ZIP, Windows manifest, and
  `SHA256SUMS.txt`.

## Remaining Manual Or Trust Gates

These are intentionally not closed by local agent work:

- Android production signing.
- Trusted Windows signing, SmartScreen reputation, Microsoft Store, WinGet, or
  stable/broad distribution claims.
- Raw Android physical-device release-build localhost/control-surface audit
  evidence if replacing the retained operator attestation.
- Android and Windows live install -> start-trial -> managed profile ->
  connect -> dashboard smoke from the exact uploaded artifacts.
- Real-user Telegram/WebApp, cabinet, checkout, redeem, Telegram bonus, and
  support flow smoke.
- App-session `/api/client/apps` runtime handoff proof for the `v1.0.0-beta`
  URLs.
- RU-origin readiness unless separately probed.
- Production WARP claim: Android/Windows release-build WARP runtime proof,
  reconnect/fallback proof, provider-side rotation proof, and support evidence
  must be attached before stronger public claims.

## Safe Release Claim

Safe now:

`POKROV 1.0.0-beta` Android + Windows outside-store beta assets are built,
uploaded to the public GitHub prerelease, and backed by local focused tests,
analyzer, client gate preflight, Android APK build, Windows unsigned packaging,
checksum proof, and unauthenticated public range smoke for all current release
assets.

Not safe:

Stable `1.0.0`, store availability, trusted Windows signing, raw Android audit
proof, RU-origin readiness, or production-ready WARP.
