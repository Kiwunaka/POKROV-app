# POKROV Client Release Backlog

Last updated: 2026-07-18

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file tracks current manual gates and follow-up work for
`POKROV-app/main`. Dated build, upload, and handoff entries below are evidence
for their recorded candidate; they do not become reusable release passes.

## Current Status

The app-first foundation and the consumer information architecture are in place in the new client repo. Android and Windows artifacts are approved for the outside-store public beta on the `1.0.0-beta` line, with accepted limitations: Android raw physical-device evidence is replaced by owner attestation for this beta, Windows remains unsigned, live install/app-session smoke remains manual, and RU-origin readiness is not claimed.

As of the final `2026-06-05` closure pass, repo-side P0-P6 implementation,
authenticated GitHub release upload/checksum proof, Android build-tool refresh,
and handoff metadata alignment are closed for the current beta. The remaining
open items are manual/local release-build tests, live account/session smokes,
DNS/leak/runtime proof, and signing/trust/store work.

Latest documented repo-level gate note:

- the latest recorded full `python scripts/release_orchestrator.py --gates-only` success snapshot remains the `2026-04-13` run from the platform workspace
- the `2026-05-15` platform evidence pack adds runtime handoff, live-origin, and payment/email proof for the outside-store beta
- the `2026-06-04` local RC pack adds exact-candidate Android release-smoke
  APK/AAB and Windows unsigned packaging evidence
- the `2026-06-05` Phase 6 handoff refreshes `1.0.0-beta` Android APK,
  Windows unsigned setup/ZIP/manifest, GitHub prerelease upload, and handoff
  metadata
- the later `2026-06-05` Android toolchain refresh upgrades the Android host
  lane to Gradle `8.11.1`, Android Gradle Plugin `8.9.1`, and Kotlin
  `2.1.0`, then re-verifies Android analyze/test/APK/AAB without the older
  Flutter Gradle/AGP/Kotlin future-support warnings; the GitHub prerelease
  Android APK and `SHA256SUMS.txt` were refreshed after this rebuild
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
- Profile/Account reward rows plus the Rewards Hub for Telegram bonus,
  referral, promo slots, wheel, calendar, achievements, and history; mutating
  reward actions stay backend-flagged and quiet until rollout approval
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
- `2026-06-05` Android toolchain refresh local verification:
  - Android host versions: Gradle `8.11.1`, Android Gradle Plugin `8.9.1`,
    Kotlin `2.1.0`
  - `flutter analyze` in `apps/android_shell`: no issues found
  - `flutter test` in `apps/android_shell`: `4 passed`
  - `gradlew testDebugUnitTest --no-daemon` in
    `apps/android_shell/android`: pass
  - `flutter build apk --release`: pass; built
    `apps/android_shell/build/app/outputs/flutter-apk/app-release.apk`
  - `flutter build appbundle --release`: pass; built
    `apps/android_shell/build/app/outputs/bundle/release/app-release.aab`
  - `gh release upload v1.0.0-beta ... pokrov-android-universal.apk
    SHA256SUMS.txt --clobber`: pass
  - `gh release download v1.0.0-beta --pattern SHA256SUMS.txt --pattern
    pokrov-android-universal.apk`: pass; downloaded APK hash
    `3676A18B06C3D5CE4BE82F9C93A4F1EA83DAB72206A06F13B066A37746A8268D`
  - this closes the recorded Android build-tool future-support warning; it is
    not raw Android physical-device audit proof, store readiness, or production
    signing evidence

## Public Android+Windows Blockers

These items no longer block the already-approved outside-store beta when they
require owner hardware/accounts, exact-artifact local tests, signing/store
access, live deploy approval, or RU probe access. After the final `2026-06-05`
closure pass, they are the only remaining gates for stronger stable, store,
trusted-signing, raw Android-audit, production-WARP, or RU-origin claims.

### Android local-surface security gate

- retain the operator-attested physical-device localhost/control-surface audit for this beta wave
- replace the attestation with raw audit evidence only if the operator supplies it
- keep negative tests for unauthorized local-client access and config or key exposure in the release path for later builds

### Route-mode, routing, and DNS verification

- keep the public routing story focused on `All except RU` and `Full tunnel`
- selected-apps is implemented for beta with a picker-first UI, Android
  launchable-app bridge, Windows process/exe candidates, selected-app
  persistence, and route-policy materialization; exact-artifact runtime proof
  remains a local/manual test gate
- keep `Blocked only` internal until DNS behavior and leak checks are complete
  enough for honest verification
- validate DNS split, geo-routing behavior, and leak behavior on Android and
  Windows release builds before treating RU-specific routing copy as fully
  shipped
- keep the persisted route-mode contract aligned with backend-owned `route_mode`, `selected_apps`, `requires_elevated_privileges`, and `route_policy.*`
- keep managed-profile `smart_connect` backend-owned and passive in the client
  until a real RTT measurement/upload loop is implemented and verified
- WARP/enhanced privacy is implemented as a guarded beta feature with backend
  policy, consent/revoke/event lifecycle, safe material contracts, fallback
  reporting, and support/admin redaction; production WARP claims still require
  Android/Windows release-build runtime and recovery proof

### Release branding, packaging, and hosting

- keep regenerated launcher, tray, and package assets aligned with the final `POKROV` brand set
- keep Windows package identity, executable naming, installer naming, and public artifacts on the canonical `POKROV` / `pokrov` line
- build fresh Android and Windows release candidates after every branding,
  runtime, or release-copy sync
- keep trusted signing as a later trust upgrade; it is not required for this outside-store beta wave
- production Android signing and trusted Windows signing are accepted skips for
  the current `1.0.0-beta` outside-store beta, with explicit beta/unsigned
  copy required
- keep Android APK runtime/public download tied to the verified runtime APP_* sync and live download smoke from the current evidence pack; re-run before changing artifacts or URLs
- Android build-tool future-support warnings are closed as of the `2026-06-05`
  toolchain refresh; keep later Gradle, Android Gradle Plugin, and Kotlin
  upgrades as normal maintenance, without expanding raw-device, store, or
  signing claims
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
- validate final download links and release handoff values after any new
  artifacts are published
- confirm app, bot, and authenticated web surfaces consume the same runtime `APP_*` values after handoff
- split release-reachability evidence into `current-origin`, `brain-origin`, and `RU-origin` checks when regional reachability matters
- keep real-user Telegram/WebApp opening as a manual owner test; synthetic brain-signed init data proves backend/runtime policy, not a real user session
- on the exact Windows candidate, verify close-to-tray/reopen while connected
  and tray `Выход` runtime shutdown plus system-proxy restoration; source-level
  lifecycle ordering is complete, exact-artifact proof remains manual

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
- `2026-06-05` P3 cleanup moved selected-app manual identifiers behind an
  explicit manual row and rewrote support diagnostics preview as a safe-summary
  explanation rather than raw-key/server/config negative copy

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
- keep public-facing version labels on `1.0.0-beta` or an explicit beta-patch
  label across client, docs, and release notes; never shorten them to stable
  `1.0.0`
- selected-apps picker and policy plumbing are closed for beta; richer native
  icons/file-dialog polish and exact-artifact OS runtime proof remain follow-up
  quality/manual-test work, not repo-side beta blockers

## Explicit Non-Blockers In This Wave

- internal Dart package/import cleanup remains a coordinated refactor, not a public-release blocker by itself
- `iOS` and `macOS` remain readiness-only lanes in this wave
- a local alpha/beta artifact mirror under `artifacts/releases/pokrov-app/` is useful for engineering handoff, but it does not by itself prove public release approval
