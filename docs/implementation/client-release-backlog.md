# POKROV Client Release Backlog

Last updated: 2026-06-05

## Document Status

This file tracks the current public-release blockers and follow-up backlog for `POKROV-app/main`.

## Current Status

The app-first foundation and the consumer information architecture are in place in the new client repo. Android and Windows artifacts are approved for the outside-store public beta on the `1.0.0-beta` line, with accepted limitations: Android raw physical-device evidence is replaced by owner attestation for this beta, Windows remains unsigned, live install/app-session smoke remains manual, and RU-origin readiness is not claimed.

Latest documented repo-level gate note:

- the latest recorded full `python scripts/release_orchestrator.py --gates-only` success snapshot remains the `2026-04-13` run from the platform workspace
- the `2026-05-15` platform evidence pack adds runtime handoff, live-origin, and payment/email proof for the outside-store beta
- the `2026-06-04` local RC pack adds exact-candidate Android release-smoke
  APK/AAB and Windows unsigned packaging evidence
- the `2026-06-05` Phase 6 handoff refreshes `1.0.0-beta` Android APK,
  Windows unsigned setup/ZIP/manifest, GitHub prerelease upload, and handoff
  metadata
- owner decision on `2026-06-04`: current outside-store beta release is
  allowed without production Android signing and without trusted Windows
  signing; this does not authorize store/trusted/stable claims
- live app-session runtime download smoke still needs owner/operator proof for
  the exact `1.0.0-beta` payload rather than relying on local green snapshots
- Android physical-device audit is operator-attested for this beta wave; do not describe it as raw repo evidence unless a retained audit artifact is attached

Already verified locally by the current engineering lane:

- app-first `Try free` bootstrap with real session persistence
- client no longer sends caller-controlled `trial_days`; the backend owns the canonical 5-day trial
- silent managed-profile import and activation
- quick-connect shell flow
- route-mode onboarding groundwork
- consumer-first `Protection / Locations / Rules / Profile` shell structure
- browser checkout continuation from the app
- support context preparation and ticket-backed continuation contracts
- native support inbox adapter for ticket list, ticket load, first ticket
  creation, follow-up replies, and redacted diagnostics-on-create
- native profile code entry through `POST /api/redeem` for access keys
- app -> cabinet continuation through short-lived `POST /api/client/cabinet-token`
  handoff URLs and one-time `POST /api/auth/cabinet-handoff/exchange`
- native Telegram reward actions through `POST /api/client/telegram/link`,
  `POST /api/channel/subscriber/check`, and
  `POST /api/bonuses/channel/claim`
- Profile/Account link/check/claim rows for the `+10 days` Telegram reward,
  with wheel and activity-calendar UI still absent from the MVP
- `2026-06-03` Task 8 local verification:
  - root backend focused tests: `18 passed` for app-first API and `65 passed`
    for auth/tickets
  - `packages/app_shell`: analyze clean, `49 passed`
  - `apps/android_shell`: analyze clean, `4 passed`
  - `apps/windows_shell`: analyze clean, `2 passed`
  - `packages/runtime_engine`: analyze clean, `11 passed`
  - `packages/core_domain`: `dart analyze` clean
  - Android debug APK smoke built at
    `apps/android_shell/build/app/outputs/flutter-apk/app-debug.apk`
  - Windows release build produced
    `apps/windows_shell/build/windows/x64/runner/Release/pokrov_windows_beta.exe`
    with `libcore.dll` present in the same release bundle
  - final local handoff pack retained under
    `artifacts/releases/pokrov-app/0.2.0-beta.1+20260603-local-mvp/`
    with verified checksums and a non-public `release-handoff.json`
- `2026-06-04` staged release-candidate local verification:
  - `python scripts/run_client_release_gate.py preflight`: pass
  - `python scripts/run_client_release_gate.py build --target android-apk`:
    built `apps/android_shell/build/app/outputs/flutter-apk/app-release.apk`
  - `python scripts/run_client_release_gate.py build --target android-aab`:
    built `apps/android_shell/build/app/outputs/bundle/release/app-release.aab`
  - `scripts/build-windows-release.ps1 -SyncRuntime -SkipTests -SkipAnalyze`:
    rebuilt the unsigned Windows setup EXE, portable ZIP, and manifest
  - local RC pack retained under
    `artifacts/releases/pokrov-app/0.2.0-beta.1+20260604-rc-local/`
    with verified `SHA256SUMS.txt`, valid `release-handoff.json`, and
    `runtime_sync_allowed=false`
  - GitHub prerelease `v0.2.0-beta.1` refreshed with
    `pokrov-android-universal.apk` and `pokrov-windows-setup-x64.exe`
  - current-origin public URL range smoke returned `206` for both assets
  - `gh release download` confirmed published SHA-256 values match the RC
  - brain-origin runtime app-download smoke passed against `/api/client/apps`;
    no runtime `APP_*` mutation was required because URLs stayed stable
  - public-beta external-access preflight passes publication policy and runtime
    checks, but remains `BLOCKED_BY_ACCESS` for missing `EMAIL_PROBE_TO` and
    `LAVATOP_PROBE_EMAIL` live probe env

## Public Android+Windows Blockers

These items no longer block the already-approved outside-store beta when they require owner hardware/accounts, signing/store access, live deploy approval, or RU probe access. They remain blockers for stable, store, trusted-signing, raw Android-audit, or RU-origin claims.

### Android local-surface security gate

- retain the operator-attested physical-device localhost/control-surface audit for this beta wave
- replace the attestation with raw audit evidence only if the operator supplies it
- keep negative tests for unauthorized local-client access and config or key exposure in the release path for later builds

### Route-mode, routing, and DNS verification

- keep the public routing story focused on `All except RU` and `Full tunnel`
- keep selected-apps as `Приложения · Скоро` only until Android package picker,
  Windows process picker, persistence, and OS-level enforcement are proven per
  platform
- keep `Blocked only` internal until routing assets, DNS behavior, and leak checks are complete enough for honest verification
- finish geo-asset wiring for routing rules and DNS presets
- validate DNS split and leak behavior on Android and Windows before treating RU-specific routing copy as fully shipped
- keep the persisted route-mode contract aligned with backend-owned `route_mode`, `selected_apps`, `requires_elevated_privileges`, and `route_policy.*`
- keep managed-profile `smart_connect` backend-owned and passive in the client
  until a real RTT measurement/upload loop is implemented and verified
- keep WARP/enhanced privacy disabled/info-only until runtime proof, backend
  profile policy, safe storage, and Android/Windows failure-mode evidence exist

### Release branding, packaging, and hosting

- keep regenerated launcher, tray, and package assets aligned with the final `POKROV` brand set
- keep Windows package identity, executable naming, installer naming, and public artifacts on the canonical `POKROV` / `pokrov` line
- build fresh Android and Windows release candidates after every branding,
  runtime, or release-copy sync
- keep trusted signing as a later trust upgrade; it is not required for this outside-store beta wave
- production Android signing and trusted Windows signing are accepted skips for
  the current `0.2.0-beta.1` outside-store beta, with explicit beta/unsigned
  copy required
- keep Android APK runtime/public download tied to the verified runtime APP_* sync and live download smoke from the current evidence pack; re-run before changing artifacts or URLs
- upgrade Gradle, Android Gradle Plugin, and Kotlin before stronger Android
  release/toolchain claims; the `2026-06-03` debug APK smoke passed but emitted
  Flutter deprecation warnings for the current versions
- keep Windows unsigned bundles gated and beta-labeled, with explicit SmartScreen or unknown-publisher warning text
- keep runtime download handoff aligned with the currently exposed public targets: Android `Play` / `APK` / mirror and Windows `EXE` / mirror
- keep `AAB`, `MSIX`, and portable `ZIP` aligned as store/operator artifacts unless the public payload expands
- treat `0.2.0-beta.1+20260603-local-mvp` as local engineering handoff only;
  do not sync public runtime `APP_*` values from it without separate operator
  GO and hosting evidence
- treat `1.0.0-beta+20260605-p6` as the latest repo-backed beta handoff
  evidence; Android remains internal beta/release-smoke signed, Windows remains
  unsigned, and live install/connect smoke plus real-user Telegram/WebApp
  verification remain manual

### Runtime launch and handoff verification

- verify the shipping client uses the real backend contracts for trial, profile, native redeem, cabinet handoff, support, Telegram bonus, and checkout continuation in release builds
- verify the release build keeps Telegram reward optional and action-driven:
  no app startup gate, no membership polling loop, and no wheel/calendar UI
  before public APIs and feature flags exist
- validate final download links and release handoff values after signed artifacts are published
- confirm app, bot, and authenticated web surfaces consume the same runtime `APP_*` values after handoff
- split release-reachability evidence into `current-origin`, `brain-origin`, and `RU-origin` checks when regional reachability matters
- keep real-user Telegram/WebApp opening as a manual owner test; synthetic brain-signed init data proves backend/runtime policy, not a real user session

## Archived Karing-Based Candidate Lane

Owner status on 2026-06-05: not part of the active `1.0.0-beta` client release
gate.

Retained only as fork/reference hardening backlog:

- prove full-source Karing buildability for Android and Windows if the lane is
  deliberately reopened;
- confirm GPL compliance and no Karing-name association before any derivative
  distribution;
- implement POKROV managed mode if that fork ever becomes active;
- hide generic proxy-utility surfaces from the normal POKROV user path;
- pass Android + Windows release gates before any public cutover from that lane.

## Follow-Up Backlog

### User-facing wording cleanup

- remove remaining user-visible inherited `Hiddify` or legacy power-user wording from advanced surfaces
- polish Russian copy where inherited text still feels technical or legacy
- keep advanced networking controls out of first-layer onboarding and daily-use screens

### Route-mode and support UX polish

- keep the route-mode editor discoverable from the normal shell instead of hiding it behind compatibility-only settings
- make sure support diagnostics show safe summaries instead of raw topology or share-link surfaces
- add lifecycle-safe periodic support refresh or SSE after real operator flow
  proves the polling cadence and UI states
- keep recovery actions centered on reconnect, refresh, location change, checkout, and support rather than raw subscription copy/edit actions
- keep any further `/api/redeem` expansion beyond the current access-key,
  gift-card, and promo families from reintroducing raw subscription links as
  account proof
- keep cabinet handoff exchange covered by e2e because the URL token is
  intentionally one-time and should be removed before normal cabinet use

### Download-surface continuity

- keep `/api/client/apps` payloads, install docs, and signed release handoff aligned
- rebuild or redeploy static download surfaces whenever public Android or Windows URLs change
- keep public-facing version labels on `0.x.x-beta` across client, docs, and release notes
- selected-apps remains a beta MVP unless Android package picking, Windows process picking, persistence, and OS enforcement are all proven

## Explicit Non-Blockers In This Wave

- internal Dart package/import cleanup remains a coordinated refactor, not a public-release blocker by itself
- `iOS` and `macOS` remain readiness-only lanes in this wave
- a local alpha/beta artifact mirror under `artifacts/releases/pokrov-app/` is useful for engineering handoff, but it does not by itself prove public release approval
