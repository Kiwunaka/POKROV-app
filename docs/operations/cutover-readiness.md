# Cutover Readiness

Last updated: 2026-06-04

This document tracks what must be true before `POKROV-app/main` is approved as the public `Android + Windows` release lane.

Historical mapping note:

- older notes may still reference `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/` on `2026-04-22`
- those older source-lane names are now historical/bootstrap references rather than the canonical git lane

## Current Status

- cutover state: `public beta BLOCKED pending trusted Android and Windows signing`
- lane path: `C:/Users/kiwun/Documents/ai/POKROV-app`
- lane ownership: `canonical client development repo for POKROV-app/main`
- public scope in this document: `Android + Windows`
- Apple scope in this wave: `readiness only`
- base decision: `Karing-based candidate reopened for gated spike; clean-room lane remains current until candidate gates pass`
- Apple release state: `checked-in unsigned service lane`
- Android release state: `internal/operator-only artifact; public release blocked until production signing is configured and verified`
- Windows release state: `internal/operator-only artifact; public release blocked until trusted signing is configured and verified`
- Android and Windows engineering verification: `2026-05-15 beta evidence retained; 2026-06-03 local Task 8 verification passed for app-first backend tests, Flutter analyze/test, Android debug APK smoke, and Windows release build; 2026-06-04 local RC built Android release-smoke APK/AAB and unsigned Windows setup/zip/manifest`
- public store readiness: `not approved`
- public cutover approval: `not approved`
- public Android release approval: `blocked until production Android signing is verified`
- public Android release blockers: `production Android signing, raw device audit proof, store readiness, and stronger Android safety claims`
- public Windows release approval: `blocked until trusted Windows signing is verified`
- public Windows release blockers: `trusted signing is required before public distribution; store/trusted distribution claims remain follow-up`
- long-term repo truth: `yes`
- repo-backed alpha or beta archive: `allowed`

This repo is already the canonical development lane for new client work.
This document tracks public release approval and cutover readiness, not whether the repo exists as engineering truth.

## Stages From Local RC To Public Release

### Stage 0: local exact-candidate package

Status: `DONE` for `0.2.0-beta.1+20260604-rc-local`.

- Android release-smoke APK and AAB are built.
- Windows unsigned setup EXE, portable ZIP, and manifest are built.
- `SHA256SUMS.txt`, `README.md`, and `release-handoff.json` are retained in
  the local RC folder.
- Runtime sync is explicitly disabled until operator GO.
- Owner decision on `2026-06-04`: do not publish the current outside-store beta
  until production Android signing and trusted Windows signing are configured and
  verified.

### Stage 1: operator artifact review

Status: `MANUAL_OWNER_TEST`.

- Owner opens the RC folder, checks names, sizes, and handoff notes.
- Owner confirms which payloads become public beta payloads:
  Android APK, Windows setup EXE, Windows ZIP, or a smaller subset.
- Owner confirms no local-only artifact should be exposed to public download
  surfaces.

### Stage 2: Android public-beta gate

Status: `BLOCKED_PENDING_PRODUCTION_SIGNING`.

- Production Android signing is required before any public Android beta upload;
  debug-signed artifacts may be retained only for internal/operator testing.
- Run the physical-device release-build localhost/control-surface audit.
- Attach raw evidence if replacing the existing operator attestation.
- Install the exact APK that will be uploaded, then verify start-trial,
  managed profile, connect/disconnect, support, cabinet handoff, and Telegram
  bonus paths.

### Stage 3: Windows public-beta gate

Status: `BLOCKED_PENDING_TRUSTED_SIGNING`.

- Trusted Windows signing is required before any public Windows beta upload;
  unsigned artifacts may be retained only for internal/operator testing.
- Install the exact setup EXE that will be uploaded.
- Verify first launch, start-trial, managed profile, connect/disconnect,
  support, cabinet handoff, and recovery after reconnect.

### Stage 4: public artifact upload

Status: `BLOCKED_PENDING_SIGNED_ARTIFACTS`.

- Do not upload or advertise Android/Windows public beta assets until the exact
  APK and Windows installer are signed with trusted production credentials.
- Record public URLs and public SHA-256 values in the RC handoff only after
  signed artifacts are uploaded.
- Smoke the signed-artifact URLs from the current operator origin with range
  requests.
- Download the signed GitHub release assets back and confirm SHA-256 values match.
- Smoke from `brain-origin` and `RU-origin` only when those reachability claims
  are needed for the release note.

### Stage 5: runtime handoff sync

Status: `BLOCKED_PENDING_SIGNED_ARTIFACTS`.

- Runtime `APP_*` URLs must not be treated as public Android/Windows download
  truth until signed replacement artifacts are uploaded and verified.
- Brain-origin `/api/client/apps` must be updated or held behind operator-only
  access if it still points at debug-signed Android or unsigned Windows assets.
- Public-beta external-access preflight remains blocked by the publication
  policy until production Android signing and trusted Windows signing pass;
  email/Lava probes remain additional live-release gates when configured.
- Before announcement, verify app, bot, cabinet, and download surfaces show the
  same signed version, URLs, and beta warnings.

### Stage 6: live beta smoke

Status: `MANUAL_OWNER_TEST`.

- After signing gates pass, install from the signed public URL, not from the local build output.
- Run start-trial -> managed profile -> connect -> dashboard.
- Run redeem code, cabinet token handoff, support chat, Telegram bonus check,
  and checkout continuation.
- Keep WARP info-only and selected-apps staged unless their runtime gates are
  separately proven.

### Stage 7: release note and monitoring

Status: `PENDING`.

- Publish public beta claims only after production Android signing and trusted Windows signing pass.
- Do not claim Play/App Store, trusted Windows signing, raw Android audit,
  RU-origin readiness, or production WARP unless fresh evidence is attached.
- Watch support tickets, payment fulfillment, node metrics, and download
  failures after the announcement.

## Required Before Public Android+Windows Cutover

1. Keep the client product contract, app-first onboarding contract, route-mode behavior, support flow, and download behavior documented in this repo.
2. Prove one real native-core provenance and packaging contract for the public Android and Windows artifacts.
3. Retain the operator-attested Android release-build localhost/control-surface audit note, or replace it with raw evidence if available.
4. Require trusted Windows signing before public distribution; unsigned artifacts may be used only for internal/operator testing with unknown-publisher warnings.
5. Verify runtime download handoff, checkout continuation, support continuation, and Telegram bonus behavior in release-mode builds.
6. Keep release handoff evidence explicit for `current-origin`, `brain-origin`, and `RU-origin` checks where reachability matters.

## Latest Local Engineering Verification

`2026-06-04` staged local release-candidate verification:

- root client-gate preflight:
  - `python scripts/run_client_release_gate.py preflight`: pass
- Android release-smoke builds:
  - `python scripts/run_client_release_gate.py build --target android-apk`:
    pass; built
    `apps/android_shell/build/app/outputs/flutter-apk/app-release.apk`
  - `python scripts/run_client_release_gate.py build --target android-aab`:
    pass; built
    `apps/android_shell/build/app/outputs/bundle/release/app-release.aab`
  - Android Gradle, Android Gradle Plugin, and Kotlin future-support warnings
    remain toolchain follow-up work
- Windows packaging:
  - `scripts/build-windows-release.ps1 -SyncRuntime -SkipTests -SkipAnalyze`:
    pass; rebuilt unsigned beta setup EXE, portable ZIP, and manifest
- retained local RC pack:
  - `artifacts/releases/pokrov-app/0.2.0-beta.1+20260604-rc-local/`
  - `SHA256SUMS.txt` rechecked against every retained file
  - `release-handoff.json` and Windows manifest parse as JSON
  - `release_state=local_release_candidate_not_public_release`
  - `runtime_sync_allowed=false`

`2026-06-03` Task 8 local verification after the Premium Shell V2,
support/chat, bonus, routing, smart-connect, and WARP-staging slices:

- root backend focused tests:
  - `portal_bot/tests/test_app_first_api.py`: `18 passed`
  - `tests/test_api_auth_and_tickets.py`: `65 passed`
- client analyze/test:
  - `packages/app_shell`: analyze clean, `49 passed`
  - `apps/android_shell`: analyze clean, `4 passed`
  - `apps/windows_shell`: analyze clean, `2 passed`
  - `packages/runtime_engine`: analyze clean, `11 passed`
  - `packages/core_domain`: `dart analyze` clean
- local artifacts:
  - Android debug APK smoke:
    `apps/android_shell/build/app/outputs/flutter-apk/app-debug.apk`
  - Windows release bundle:
    `apps/windows_shell/build/windows/x64/runner/Release/pokrov_windows_beta.exe`
  - Windows runtime bundle member:
    `apps/windows_shell/build/windows/x64/runner/Release/libcore.dll`
- retained local handoff pack:
  - `artifacts/releases/pokrov-app/0.2.0-beta.1+20260603-local-mvp/`
  - checksum verification passed against `SHA256SUMS.txt`
  - `release-handoff.json` is valid JSON and explicitly sets
    `runtime_sync_allowed=false`

These are local engineering evidence, not raw Android physical-device audit
replacement, store readiness, trusted Windows signing, RU-origin readiness, or
production WARP proof.

## Android Gate Checklist

- [x] Runtime artifacts are synced into the documented Android build lane
- [x] `flutter analyze` passes in the Android host lane
- [x] Shared runtime and widget tests pass for the public Android shell
- [x] `flutter build apk --release` succeeds
- [x] `flutter build appbundle --release` succeeds when store/operator artifacts are requested
- [x] Physical-device localhost/control-surface audit is operator-attested for this beta wave
- [ ] Raw audit evidence is attached if replacing the operator attestation
- [ ] Public download handoff is blocked until the Android APK is production-signed and verified; `Play` remains empty until store readiness passes
- [x] Release handoff includes runtime URL verification and origin evidence for the `2026-05-15` beta evidence pack
- [ ] Any APK shown to testers is official, beta-labeled, outside-store, and not described as Play/store-ready

Apple checklists below remain readiness-only in this wave.
They do not expand the public `Android + Windows` release scope tracked by this document.

## iOS Gate Checklist

- [ ] Bundle ID reserved in Apple Developer
- [ ] App group reserved in Apple Developer
- [x] Packet-tunnel target created
- [x] Packet-tunnel live service wiring checked in
- [ ] Packet-tunnel entitlements reviewed
- [ ] App provisioning profile created
- [ ] Extension provisioning profile created
- [ ] Release archive succeeds on `iphoneos`
- [ ] TestFlight upload succeeds
- [ ] TestFlight build reaches internal reviewable state
- [ ] App Store Connect metadata draft is complete

## macOS Gate Checklist

- [ ] Bundle ID reserved in Apple Developer
- [ ] Distribution channel decided: Developer ID direct or Mac App Store
- [ ] Release archive succeeds
- [ ] Hardened runtime enabled on the exported release build
- [ ] Notarization succeeds
- [ ] Stapling succeeds
- [ ] `spctl -a -vv` accepts the stapled app
- [ ] Store metadata draft is complete

## Windows Gate Checklist

- [x] Runtime artifacts are synced into `apps/windows_shell/windows/runner/resources/runtime`
- [x] `flutter analyze` passes in `apps/windows_shell`
- [x] Shared runtime and widget tests pass
- [x] `flutter build windows --release` succeeds
- [x] Local release bundle contains `pokrov_windows_beta.exe` and `libcore.dll`
- [ ] Unsigned beta risk is not accepted for public distribution; trusted Windows signing is required
- [ ] Trusted code-signing identity is available for a later trusted Windows distribution
- [ ] Public Windows installer path is blocked until trusted signing is verified; `MSIX` / portable `ZIP` stay operator/store artifacts
- [ ] Public hosting and handoff path are blocked until signed Android and Windows artifacts are verified
- [ ] Gated beta download copy warns about Microsoft Defender SmartScreen or unknown-publisher prompts while unsigned

## Safe Claims

Safe to claim now:

- the local `POKROV-app` repo is bootstrapped and carries the clean-room client lane
- `app-next/` and `external/pokrov-next-client/` are now historical/bootstrap source references, not the canonical git lane
- this repo is the long-term canonical git target for new client development work
- this repo now owns the client product contract, app-first onboarding contract, and client backlog tracking under `docs/`
- public scope for this release wave remains `Android + Windows`
- Apple work in this repo is readiness and packaging preparation only for this wave
- iOS and macOS shell metadata is materially closer to a real release lane
- iOS now carries checked-in packet-tunnel service code instead of a deliberate scaffold stop
- operator work needed for signing, notarization, and store prep is now explicit
- Windows now has a real local runtime build-and-bundle lane with unsigned package staging
- the `2026-06-04` local RC pack exists for engineering/operator inspection
  under `artifacts/releases/pokrov-app/0.2.0-beta.1+20260604-rc-local/`
- the current Windows beta artifact may be used only for internal/operator testing with the unsigned warning
- Android + Windows outside-store public beta is blocked until production Android signing and trusted Windows signing pass
- Android physical-device audit is accepted as `OPERATOR_ATTESTED` for this beta wave, not as raw repository evidence
- Windows trusted signing is required before public distribution

Not safe to claim now:

- credentials are configured
- Apple artifacts are signed
- Windows artifacts are production signed
- TestFlight is live
- notarization is green
- Windows public hosting is approved
- signed iOS packet-tunnel execution is proven on device
- Apple store submission is ready
- Apple cutover is approved
- app-store Android release approval is complete
- trusted Windows release approval is complete
- raw Android physical-audit evidence is attached as repo-retained PASS proof
- RU-origin readiness is proven

Blocked-by note:

- the local repo bootstrap step is complete, but public Android + Windows outside-store beta approval is blocked pending trusted signing
- Android is operator-attested for this beta wave; do not upgrade that to raw audit evidence unless a retained audit artifact is attached
- Windows remains unsigned for internal/operator testing only; trusted signing is a blocker for public beta distribution
- real-user Telegram/WebApp checks, raw Android device audit replacement evidence, signing, store access, and RU-origin probes remain manual owner or operator checks; signing is a blocker for public release approval
- `POKROV-app/artifacts/releases/pokrov-app/` may retain repo-backed alpha and beta bundles built directly from this lane for engineering and tester handoff
- local RC packs must not be promoted to public runtime download truth until
  production Android signing, trusted Windows signing, operator upload, public
  URL smoke, and runtime `APP_*` approval are recorded
- rollback and compatibility lanes may still exist elsewhere, but this document tracks approval of the `POKROV-app` release lane itself rather than treating another repo as the primary frame
