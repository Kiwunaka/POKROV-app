# Cutover Readiness

Last updated: 2026-06-04

This document tracks what must be true before `POKROV-app/main` is approved as the public `Android + Windows` release lane.

Historical mapping note:

- older notes may still reference `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/` on `2026-04-22`
- those older source-lane names are now historical/bootstrap references rather than the canonical git lane

## Current Status

- cutover state: `outside-store public beta GO with accepted skips`
- lane path: `C:/Users/kiwun/Documents/ai/POKROV-app`
- lane ownership: `canonical client development repo for POKROV-app/main`
- public scope in this document: `Android + Windows`
- Apple scope in this wave: `readiness only`
- base decision: `Karing-based candidate reopened for gated spike; clean-room lane remains current until candidate gates pass`
- Apple release state: `checked-in unsigned service lane`
- Android release state: `operator-attested outside-store beta artifact, runtime handoff green for 2026-05-15 beta`
- Windows release state: `unsigned outside-store beta artifact, runtime handoff green for 2026-05-15 beta`
- Android and Windows engineering verification: `2026-05-15 beta evidence retained; 2026-06-03 local Task 8 verification passed for app-first backend tests, Flutter analyze/test, Android debug APK smoke, and Windows release build; 2026-06-04 local RC built Android release-smoke APK/AAB and unsigned Windows setup/zip/manifest; 2026-06-05 local 1.0.0-beta build refreshed Android APK and unsigned Windows setup/zip/manifest after P5/WARP pass`
- public store readiness: `not approved`
- public cutover approval: `outside-store beta only`
- public Android release approval: `outside-store beta with operator attestation`
- public Android release blockers: `raw device audit proof, store readiness, and stronger Android safety claims remain manual follow-up`
- public Windows release approval: `outside-store unsigned beta only`
- public Windows release blockers: `trusted signing is an accepted skip for the current outside-store beta; store/trusted distribution claims remain follow-up`
- long-term repo truth: `yes`
- repo-backed alpha or beta archive: `allowed`

This repo is already the canonical development lane for new client work.
This document tracks public release approval and cutover readiness, not whether the repo exists as engineering truth.

## Stages From Local RC To Public Release

### Stage 0: local exact-candidate package

Status: `DONE` for `0.2.0-beta.1+20260604-rc-local`; refreshed local
engineering artifacts are now built from the `1.0.0-beta` version line.

- Android release-smoke APK and AAB are built.
- Windows unsigned setup EXE, portable ZIP, and manifest are built.
- `SHA256SUMS.txt`, `README.md`, and `release-handoff.json` are retained in
  the local RC folder.
- Runtime sync is explicitly disabled until operator GO.
- Owner decision on `2026-06-04`: the current outside-store beta may release
  without production Android signing and without trusted Windows signing.

### Stage 1: operator artifact review

Status: `MANUAL_OWNER_TEST`.

- Owner opens the RC folder, checks names, sizes, and handoff notes.
- Owner confirms which payloads become public beta payloads:
  Android APK, Windows setup EXE, Windows ZIP, or a smaller subset.
- Owner confirms no local-only artifact should be exposed to public download
  surfaces.

### Stage 2: Android public-beta gate

Status: `UNSIGNED_RELEASE_APPROVED_BY_OWNER_MANUAL_TEST_PENDING`.

- Production Android signing is an accepted skip for the current outside-store
  beta; retain the current internal beta signing posture with explicit
  outside-store beta copy.
- Run the physical-device release-build localhost/control-surface audit.
- Attach raw evidence if replacing the existing operator attestation.
- Install the exact APK that will be uploaded, then verify start-trial,
  managed profile, connect/disconnect, support, cabinet handoff, and Telegram
  bonus paths.

### Stage 3: Windows public-beta gate

Status: `UNSIGNED_RELEASE_APPROVED_BY_OWNER_MANUAL_TEST_PENDING`.

- Trusted Windows signing is an accepted skip for the current outside-store
  beta; keep explicit SmartScreen/unknown-publisher copy.
- Install the exact setup EXE that will be uploaded.
- Verify first launch, start-trial, managed profile, connect/disconnect,
  support, cabinet handoff, and recovery after reconnect.

### Stage 4: public artifact upload

Status: `DONE_GITHUB_PRERELEASE_REFRESHED`.

- Uploaded approved APK and Windows setup EXE to GitHub prerelease
  `v0.2.0-beta.1` on 2026-06-04 using canonical asset names.
- Recorded public URLs and public SHA-256 values in the RC handoff.
- Smoked the URLs from the current operator origin with range requests.
- Downloaded the GitHub release assets back and confirmed SHA-256 values match.
- Smoke from `brain-origin` and `RU-origin` only when those reachability claims
  are needed for the release note.

### Stage 5: runtime handoff sync

Status: `DONE_URLS_UNCHANGED_BRAIN_SMOKE_PASS`.

- Runtime `APP_*` mutation was not required for this refresh because the
  GitHub URLs stayed stable.
- Brain-origin `/api/client/apps` smoke passed on 2026-06-04 and returned the
  expected Android APK, Windows EXE, and install docs URLs.
- Public-beta external-access preflight passes publication policy and runtime
  download checks but remains `BLOCKED_BY_ACCESS` for email/Lava live probe env:
  `EMAIL_PROBE_TO` and `LAVATOP_PROBE_EMAIL`.
- Before announcement, verify app, bot, cabinet, and download surfaces show the
  same version, URLs, and beta warnings.

### Stage 6: live beta smoke

Status: `MANUAL_OWNER_TEST`.

- Install from the public URL, not from the local build output.
- Run start-trial -> managed profile -> connect -> dashboard.
- Run redeem code, cabinet token handoff, support chat, Telegram bonus check,
  and checkout continuation.
- Keep WARP info-only and selected-apps staged unless their runtime gates are
  separately proven.

### Stage 7: release note and monitoring

Status: `PENDING`.

- Publish only outside-store beta claims.
- Do not claim Play/App Store, trusted Windows signing, raw Android audit,
  RU-origin readiness, or production WARP unless fresh evidence is attached.
- Watch support tickets, payment fulfillment, node metrics, and download
  failures after the announcement.

## Required Before Public Android+Windows Cutover

1. Keep the client product contract, app-first onboarding contract, route-mode behavior, support flow, and download behavior documented in this repo.
2. Prove one real native-core provenance and packaging contract for the public Android and Windows artifacts.
3. Retain the operator-attested Android release-build localhost/control-surface audit note, or replace it with raw evidence if available.
4. Keep Windows unsigned beta posture explicit; trusted signing is not required for this outside-store beta pass, but unknown-publisher warnings must be shown.
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

`2026-06-05` WARP material/provisioning local verification:

- root backend focused test:
  - `tests/test_network_rollout_api.py`: `9 passed`
  - covers encrypted-at-rest scoped WARP material provisioning,
    authenticated managed-profile material delivery, public policy redaction,
    lifecycle ledger redaction, revoke deactivation, rollout fallback,
    provisioning/rotation rate limits, stale material rejection, and admin
    WARP summary redaction
- client focused tests:
  - `packages/app_shell/test/app_first_runtime_bootstrap_test.dart`:
    `27 passed`
  - `packages/app_shell/test/pokrov_seed_app_test.dart`: `51 passed`
  - covers backend-backed WARP status/consent/event wiring, immediate local
    enabled-state clearing on revoke, and P5 connect-disc idle/connected/error
    settle states

`2026-06-05` WARP runtime/admin telemetry local verification:

- root focused tests cover redacted WARP runtime state/reason/event headers in
  `GET /api/admin/client/warp/summary`
- webapp static smoke covers admin dashboard wiring for the redacted WARP
  summary card/queue entry

`2026-06-05` local `1.0.0-beta` artifact refresh after P5/WARP pass:

- Android release APK:
  `apps/android_shell/build/app/outputs/flutter-apk/app-release.apk`
- Windows release EXE:
  `apps/windows_shell/build/windows/x64/runner/Release/pokrov_windows_beta.exe`
- Windows unsigned beta bundle:
  `apps/windows_shell/build/release_bundle/pokrov-windows-beta-x64-1.0.0-beta/`
- Windows unsigned beta ZIP:
  `apps/windows_shell/build/release_bundle/pokrov-windows-beta-x64-1.0.0-beta.zip`
- Windows unsigned beta setup EXE:
  `apps/windows_shell/build/release_bundle/pokrov-windows-beta-x64-1.0.0-beta-setup.exe`
- Windows manifest:
  `apps/windows_shell/build/release_bundle/pokrov-windows-beta-x64-1.0.0-beta.manifest.json`

This refresh still does not prove Android physical release-build WARP,
Windows release-build WARP, production WARP, trusted Windows signing, store
readiness, or RU-origin readiness.

This is backend/client contract evidence only. It is not Android physical
release-build WARP proof, Windows release-build WARP proof, provider-side WARP
rotation proof, or production WARP readiness.

## Android Gate Checklist

- [x] Runtime artifacts are synced into the documented Android build lane
- [x] `flutter analyze` passes in the Android host lane
- [x] Shared runtime and widget tests pass for the public Android shell
- [x] `flutter build apk --release` succeeds
- [x] `flutter build appbundle --release` succeeds when store/operator artifacts are requested
- [x] Physical-device localhost/control-surface audit is operator-attested for this beta wave
- [ ] Raw audit evidence is attached if replacing the operator attestation
- [x] Public download handoff is approved for Android `APK` / mirror; `Play` remains empty for outside-store beta
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
- [x] Unsigned beta risk is accepted for this outside-store beta wave
- [ ] Trusted code-signing identity is available for a later trusted Windows distribution
- [x] EXE first-layer beta path is chosen for this outside-store wave; `MSIX` / portable `ZIP` stay operator/store artifacts
- [x] Public hosting and handoff path are approved for the `2026-05-15` outside-store beta evidence pack
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
- the current Windows beta artifact may be shared only behind approved beta access with the unsigned warning
- Android + Windows outside-store public beta is `GO` as of the `2026-05-15` launch decision evidence pack
- Android physical-device audit is accepted as `OPERATOR_ATTESTED` for this beta wave, not as raw repository evidence
- Windows signing is not required for this outside-store beta wave, but trusted signing must not be claimed

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

- the local repo bootstrap step is complete, and public Android + Windows outside-store beta approval is green from the `2026-05-15` platform evidence pack
- Android is operator-attested for this beta wave; do not upgrade that to raw audit evidence unless a retained audit artifact is attached
- Windows remains unsigned beta only; trusted signing is a later trust upgrade, not a blocker for this outside-store beta pass
- real-user Telegram/WebApp checks, raw Android device audit replacement evidence, signing, store access, and RU-origin probes remain manual owner or operator checks, not blockers for local docs/code synchronization
- `POKROV-app/artifacts/releases/pokrov-app/` may retain repo-backed alpha and beta bundles built directly from this lane for engineering and tester handoff
- local RC packs must not be promoted to public runtime download truth until
  operator upload, public URL smoke, and runtime `APP_*` approval are recorded
- rollback and compatibility lanes may still exist elsewhere, but this document tracks approval of the `POKROV-app` release lane itself rather than treating another repo as the primary frame
