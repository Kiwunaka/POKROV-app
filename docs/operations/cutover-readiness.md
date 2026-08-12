# Cutover Readiness

Last updated: 2026-08-12

This document tracks what must be true before `POKROV-app/main` is approved as the public `Android + Windows` release lane.

Historical mapping note:

- older notes may still reference `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/` on `2026-04-22`
- those older source-lane names are now historical/bootstrap references rather than the canonical git lane

## Current Status

- cutover state: `2026-08-12 Android direct-APK candidate production-signing and release-critical physical journey PASS; publication still waits for recovery, distribution handoff, and owner gates`
- lane path: `C:/Users/kiwun/Documents/ai/POKROV-app`
- lane ownership: `canonical client development repo for POKROV-app/main`
- public scope in this document: `Android + Windows`
- Apple scope in this wave: `readiness only`
- base decision: `Karing-based candidate reopened for gated spike; clean-room lane remains current until candidate gates pass`
- Apple release state: `checked-in unsigned service lane`
- Android release state: `2026-08-12 direct APK 1.0.2+9 is release-built, non-debuggable, self-managed production-signed, independently verified, exact-hash installed, and tunnel/routing verified on physical Android 12 hardware; it is not yet distribution-approved`
- Windows release state: `unsigned outside-store beta setup EXE refreshed for 1.0.0-beta; live install/app-session smoke remains manual`
- Android and Windows engineering verification: `2026-08-12 exact Android 1.0.2+9 installed and cold-launched on physical hardware, traversed onboarding/Home/route scope, resolved packaged Core with native extraction disabled, connected to Germany, and passed smart plus both per-app routing directions; Windows remains a separate unsigned lane`
- public store readiness: `not approved`
- public cutover approval: `blocked for a new candidate`
- public Android release approval: `production signing and release-critical physical journey passed; blocked pending offline recovery, direct-download/live-smoke handoff, and owner approval gates`
- public Android release blockers: `signing-key offline recovery, direct-download publication/handoff, uploaded-artifact hash smoke, and owner approval; Play is not part of the first channel`
- public Windows release approval: `blocked pending trusted-signing PASS for the exact candidate`
- public Windows release blockers: `trusted signing, exact-artifact install smoke, and store/trusted distribution proof`
- long-term repo truth: `yes`
- repo-backed alpha or beta archive: `allowed`

This repo is already the canonical development lane for new client work.
This document tracks public release approval and cutover readiness, not whether the repo exists as engineering truth.

## Stages From Local RC To Public Release

The completed stage results below are retained evidence for their named 2026
candidates. They are not reusable approval. Effective policy for a new
candidate is fail-closed: signing evidence, artifact identity, manual gates,
and public/runtime handoff must be re-established for that exact candidate.

### Stage 0: local exact-candidate package

Status: `DONE` for `1.0.0-beta+20260605-p6`; initial refreshed local
engineering artifacts were built from commit
`c03ded35ea2dbb3e64377302d2744e640a802540`, and the Android APK was refreshed
again after the Android toolchain update at
`e494d9bbf6767780be1b39af6fc4c2785f61cda7`.

- Android release APK is built. A fresh 2026-06-05 AAB store-smoke artifact
  also builds locally, but store/operator packaging still requires a separate
  owner request and signing/release review.
- Windows unsigned setup EXE, portable ZIP, and manifest are built.
- `SHA256SUMS.txt` is retained in the local `.tmp/release-assets-1.0.0-beta/`
  staging folder; stable handoff metadata is retained at
  `artifacts/releases/release-handoff.json`.
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

Recorded status for the 2026 beta: `UNSIGNED_RELEASE_APPROVED_BY_OWNER_MANUAL_TEST_PENDING`.
Current candidate status: `PRODUCTION_SIGNING_AND_DEVICE_JOURNEY_PASS_DISTRIBUTION_PENDING`.

- The dated signing skip explains the retained beta evidence only. The current
  `1.0.2+9` direct APK passes production signing; debug signing remains an
  explicit non-public smoke path and never promotion authority.
- Retain an encrypted offline recovery copy of the production keystore and its
  password before public upload. Every direct update must use the same identity
  and a higher `versionCode`.
- Run the physical-device release-build localhost/control-surface audit.
- Attach raw evidence if replacing the existing operator attestation.
- Confirm release state JSON does not contain `session_token`; session material
  must be migrated to the app secure secret store.
- Confirm a secure-store write failure leaves the legacy JSON token untouched
  and fails closed instead of claiming that migration succeeded.
- Confirm `session_token_storage=secure` with a missing platform secret enters
  account recovery and never requests a replacement trial session.
- Confirm state-file replacement is atomic: a failed JSON write preserves the
  previous install/session locator, and an interrupted replacement restores its
  validated backup on the next launch.
- Install the exact APK that will be uploaded, then verify start-trial,
  managed profile, connect/disconnect, support, cabinet handoff, and Telegram
  bonus paths.

### Stage 3: Windows public-beta gate

Recorded status for the 2026 beta: `UNSIGNED_RELEASE_APPROVED_BY_OWNER_MANUAL_TEST_PENDING`.
Current reuse status: `BLOCKED_PENDING_EXACT_CANDIDATE_TRUSTED_SIGNING`.

- The dated unsigned-risk acceptance explains the retained beta evidence only.
  A new public Windows candidate requires trusted-signing evidence; unsigned
  output remains non-public engineering smoke with explicit warning copy.
- Install the exact setup EXE that will be uploaded.
- Confirm local runtime ports bind only to loopback, LAN access remains disabled,
  and the Clash API is disabled unless a future audited secret-gated control
  path replaces it.
- Confirm release state JSON does not contain `session_token`; session material
  must be migrated to the app secure secret store.
- Confirm a missing secure secret enters recovery rather than silently creating
  another account or trial, and restart recovery survives an interrupted state
  file replacement.
- Verify first launch, start-trial, managed profile, connect/disconnect,
  support, cabinet handoff, and recovery after reconnect.

### Stage 4: public artifact upload

Status: `DONE_PUBLIC_RELEASE_REPO_PUBLISHED`.

- Uploaded approved APK, Windows setup EXE, Windows portable ZIP, Windows
  manifest, and `SHA256SUMS.txt` to GitHub prerelease `v1.0.0-beta` on
  2026-06-05, then republished to the public release-only repository
  `Kiwunaka/pokrov` on 2026-06-07. The current Android public payload is split
  by ABI: `pokrov-android-arm64-v8a.apk` by default and
  `pokrov-android-armeabi-v7a.apk` for legacy ARMv7 devices.
- Recorded URLs and SHA-256 values in `config/release-handoff.seed.json` and
  `artifacts/releases/release-handoff.json`.
- Unauthenticated current-origin range requests return `206` for
  `SHA256SUMS.txt`, both Android split APKs, Windows setup EXE, Windows
  portable ZIP, and Windows manifest in `Kiwunaka/pokrov`.
- Smoke from `brain-origin` and `RU-origin` only when those reachability claims
  are needed for the release note.

### Stage 5: runtime handoff sync

Status: `PASS_BRAIN_RUNTIME_APP_DOWNLOAD_SMOKE_REAL_USER_MANUAL_PENDING`.

- Runtime `APP_*` points at the current `v1.0.0-beta` public release URLs on
  `brain`.
- Unauthenticated `https://api.pokrov.space/api/client/apps` returns `401`
  (`Telegram auth required`), so live handoff proof needs a real app session or
  operator-authenticated smoke.
- `2026-06-07` brain-local signed `/api/client/apps` smoke passed and returned
  the current split APK variants, hashes, sizes, Windows EXE, and docs URL. A
  real-user Telegram WebApp opening remains a manual owner test.
- Public-beta external-access preflight passes publication policy and runtime
  download checks but remains `BLOCKED_BY_ACCESS` for email/Lava live probe env:
  `EMAIL_PROBE_TO` and `LAVATOP_PROBE_EMAIL`.
- Before announcement, verify app, bot, cabinet, and download surfaces show the
  same version, URLs, and beta warnings.

### Stage 6: live beta smoke

Status: `MANUAL_OWNER_TEST`.

- Install from the public URL, not from the local build output.
- Run start-trial -> managed profile -> connect -> dashboard.
- Verify smart-connect candidates -> `/api/client/nodes/select` -> managed
  profile refresh with selected node, including manual location choice on
  reconnect and telemetry failure not blocking connect.
- Run redeem code, cabinet token handoff, support chat, Telegram bonus check,
  and checkout continuation.
- Confirm support diagnostics/export payloads redact session tokens,
  subscription URLs, WireGuard/WARP material, and raw generated configs.
- WARP/enhanced privacy and selected-apps are implemented for guarded beta use.
  Keep production WARP, DNS/leak, and exact-artifact runtime claims behind
  release-build proof.

### Stage 7: release note and monitoring

Status: `READY_GUARDRAILS_RECORDED_OPERATOR_MONITORING_AFTER_ANNOUNCEMENT`.

- Publish only outside-store beta claims.
- Do not claim Play/App Store, trusted Windows signing, raw Android audit,
  RU-origin readiness, or production WARP unless fresh evidence is attached.
- Watch support tickets, payment fulfillment, node metrics, and download
  failures after the announcement. This is an operator/live monitoring task,
  not a repo-side beta implementation blocker.

## Required Before Public Android+Windows Cutover

1. Keep the client product contract, app-first onboarding contract, route-mode behavior, support flow, and download behavior documented in this repo.
2. Prove one real native-core provenance and packaging contract for the public Android and Windows artifacts.
3. Retain the operator-attested Android release-build localhost/control-surface audit note, or replace it with raw evidence if available.
4. Require trusted Windows signing for a new public candidate; keep every
   unsigned engineering artifact non-public and show the unknown-publisher
   warning during operator smoke.
5. Verify runtime download handoff, checkout continuation, support continuation, and Telegram bonus behavior in release-mode builds.
6. Keep release handoff evidence explicit for `current-origin`, `brain-origin`, and `RU-origin` checks where reachability matters.

## Latest Local Engineering Verification

`2026-08-12` exact production-signed direct Android candidate verification:

- artifact:
  `apps/android_shell/build/app/outputs/flutter-apk/app-release.apk`
- version: `1.0.2+9`; package `space.pokrov.pokrov_android_shell`
- size: `287207515` bytes
- SHA-256:
  `9820CDA01DEA74CDBD34A9D1FA76B7CFC1DD24D0D452D8521239DFF9DA6BEACA`
- build mode: Flutter release with
  `POKROV_API_BASE_URL=https://api.pokrov.space`; `debuggable=false`
- signing evidence: `PASS_PRODUCTION_SELF_MANAGED_DIRECT_APK`; one RSA-4096
  signer, APK Signature Scheme v2, certificate SHA-256
  `0A0602A7DF5D96A0B427909D004F3DDF26DEF86587634BF16694DA8D654B2500`
- continuity and install evidence: the signer stayed unchanged; physical-device
  same-signer update passed; installed APK hash matched the local artifact; the
  session survived the update and package metadata reported `versionCode=9`
- exact-candidate UI evidence: physical cold start, app-first onboarding, Home,
  enabled `Включить VPN`, and the first-connect route-scope sheet passed through
  UI-tree-derived coordinates
- packaged-Core evidence: Android 12 installed the APK with native extraction
  disabled; candidate `+8` resolved the ABI-matched Core from the APK and removed
  the false `Core missing` state found in candidate `+7`
- log evidence: Android crash-buffer line count remained zero during the exact
  production-candidate physical pre-tunnel path
- system-surface evidence: the POKROV Quick Settings tile was added to the
  authorized phone, rendered first with a readable inactive label and
  accessibility state, and safely opened the app when no eligible staged
  profile existed; the tile and foreground-notification security-contract tests
  pass
- production egress: Germany connected on the physical phone. Smart split
  returned `RU` for its direct Russian lane and `DE` for the tunneled browser
  request; no raw address was retained
- per-app routing: Android `Except selected apps` returned `RU` in Yandex and
  `DE` in Chrome; `Only selected apps` reversed the same exact checks to `DE`
  in Yandex and `RU` in Chrome
- system surfaces: the branded Quick Settings tile starts the staged profile;
  the foreground notification exposes country, route summary, optional speed,
  open, and disconnect actions; the speed setting was disabled and restored
- support/checkout: a real phone support question received a live bounded AI
  answer, and checkout exposed the deployed `99 / 239 / 669 / 1199 / 1699 /
  1999 ₽` catalog
- supporting prior-build journey: the immediately preceding internal build
  traversed disposable trial, Home, Locations, Rules, Profile, first-connect
  scope, Android notification grant, and truthful tunnel failure. That journey
  does not replace exact production-candidate physical-device proof
- cleanup evidence: the two earlier disposable QA accounts and the final
  physical-device QA account were deleted after full PostgreSQL backups. The
  last cleanup removed seven panel mappings and 24 database rows; final
  postcheck returned zero users, access keys, and user-node mappings for it
- Google Play is `NOT_REQUESTED_DIRECT_APK_FIRST`
- direct release still requires the encrypted offline signing recovery copy,
  direct-download publication/handoff, live uploaded-APK hash smoke, and owner
  promotion approval. Google Play remains outside this direct-APK release.
- detailed evidence owner:
  `docs/operations/android-release-audit.md`

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
    were still toolchain follow-up work in this RC snapshot; see the later
    `2026-06-05` Android toolchain refresh below
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
    `apps/windows_shell/build/windows/x64/runner/Release/pokrov-core.dll`
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

- Public GitHub prerelease:
  `https://github.com/Kiwunaka/pokrov/releases/tag/v1.0.0-beta`
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
- Current public GitHub prerelease assets after the 2026-06-07 split APK
  refresh:
  - `pokrov-android-arm64-v8a.apk`:
    `9D5AB665378F563021A6FB50F9E996FB6DA1A4269D9FBC959C8E33561A4EA523`
  - `pokrov-android-armeabi-v7a.apk`:
    `28882CA1E2F57695D31658A16AF32DE901FCE2163EBA9E0469C1136CA4E52DF9`
  - `pokrov-windows-setup-x64.exe`:
    `B4CC0BF82DCFF7F021F7325E513226856B8E1D0686242744888D64D26FB82EBB`
  - `pokrov-windows-portable-x64.zip`:
    `6D854D5F6C75B4F048C8481B07BF62D35D97536DA15EDC585DAEA982BA224FEF`
  - `pokrov-windows-1.0.0-beta.manifest.json`:
    `3E20F410AEC23C18403C51FCEA2C7F015A230B63EB5C1428326820E04BC22AA0`
- Fresh Phase 6 verification:
  - `python scripts/run_client_release_gate.py preflight`: pass
  - `flutter test test/assistant_contract_test.dart test/warp_lifecycle_contract_test.dart test/app_first_runtime_bootstrap_test.dart test/pokrov_seed_app_test.dart`:
    `91 passed`
  - `flutter analyze` in `packages/app_shell`: no issues found
  - `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64`:
    pass; rebuilt release split APKs
  - `scripts/build-windows-release.ps1 -SyncRuntime -SkipTests -SkipAnalyze`:
    pass; rebuilt unsigned setup EXE, portable ZIP, and manifest
  - `gh release upload v1.0.0-beta --repo Kiwunaka/pokrov --clobber ...`:
    pass
  - old `pokrov-android-universal.apk` removed from the public release: pass
  - unauthenticated GitHub range smoke: `PASS_PUBLIC_GITHUB_RELEASES_206`

This refresh still does not prove Android physical release-build WARP,
Windows release-build WARP, production WARP, trusted Windows signing, store
readiness, or RU-origin readiness.

This is backend/client contract evidence only. It is not Android physical
release-build WARP proof, Windows release-build WARP proof, provider-side WARP
rotation proof, or production WARP readiness.

`2026-06-05` Android toolchain refresh:

- Android host versions:
  - Gradle wrapper distribution: `8.11.1`
  - Android Gradle Plugin: `8.9.1`
  - Kotlin Android plugin: `2.1.0`
- Local verification:
  - `flutter analyze` in `apps/android_shell`: no issues found
  - `flutter test` in `apps/android_shell`: `4 passed`
  - `gradlew testDebugUnitTest --no-daemon` in
    `apps/android_shell/android`: pass
  - `flutter build apk --release`: pass; rebuilt
    `apps/android_shell/build/app/outputs/flutter-apk/app-release.apk`
  - `flutter build appbundle --release`: pass; rebuilt
    `apps/android_shell/build/app/outputs/bundle/release/app-release.aab`
  - historical 2026-06-05 universal APK was replaced in the public release by
    the 2026-06-07 split APK refresh above.
- This closes the prior Flutter Gradle/AGP/Kotlin future-support warning for
  the Android host lane. It does not prove Android physical release-build WARP,
  raw Android device audit, Play/store readiness, production signing, or
  RU-origin readiness.

## Android Gate Checklist

- [x] Runtime artifacts are synced into the documented Android build lane
- [x] `flutter analyze` passes in the Android host lane
- [x] Shared runtime and widget tests pass for the public Android shell
- [x] `flutter build apk --release` succeeds
- [x] `flutter build appbundle --release` succeeds when store/operator artifacts are requested
- [x] Physical-device localhost/control-surface audit is operator-attested for this beta wave
- [ ] Raw audit evidence is attached if replacing the operator attestation
- [x] Production Android signing is `PASS` for exact direct APK `1.0.2+9`
- [ ] An encrypted offline recovery copy of the Android signing keystore and password is retained
- [x] Exact direct APK `1.0.2+9` passes the release-critical physical-device
      journey: install, launch, route scope, packaged Core, tunnel, smart split,
      both per-app directions, system surfaces, support, and checkout
- [ ] Public download handoff is re-approved for the exact signed Android `APK`; `Play` is `NOT_REQUESTED_DIRECT_APK_FIRST`
- [x] Release handoff includes runtime URL verification and origin evidence for the `2026-05-15` beta evidence pack
- [x] Any APK shown to testers is official, beta-labeled, outside-store, and not described as Play/store-ready

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

- [x] POKROV Core 1.0.2 `pokrov-core.dll` and pinned `libcronet.dll` are synced into `apps/windows_shell/windows/runner/resources/runtime`
- [x] `flutter analyze` passes in `apps/windows_shell`
- [x] Shared runtime and widget tests pass
- [x] `flutter build windows --release` succeeds
- [x] Local source-candidate release bundle contains `pokrov_windows_beta.exe`, ABI 2 `pokrov-core.dll`, and pinned `libcronet.dll`
- [x] Unsigned beta risk acceptance is retained as evidence for the recorded beta wave only
- [ ] Trusted code-signing identity and exact-candidate signing proof are available for the next public Windows distribution
- [x] EXE first-layer beta path is retained; `MSIX` / portable `ZIP` stay operator/store artifacts
- [ ] Public hosting and handoff are re-approved for the exact signed candidate
- [x] Gated beta download copy warns about Microsoft Defender SmartScreen or unknown-publisher prompts while unsigned

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
- Android direct-APK production signing is configured locally; remaining
  platform signing, notarization, and store work is explicit
- Windows now has a real local runtime build-and-bundle lane with unsigned package staging
- the `2026-06-04` local RC pack exists for engineering/operator inspection
  under `artifacts/releases/pokrov-app/0.2.0-beta.1+20260604-rc-local/`
- debug-signed Android and unsigned Windows artifacts may be used only for
  explicitly non-public engineering smoke
- the `2026-05-15` launch decision and published `1.0.0-beta` handoff remain
  exact-candidate evidence, not current rebuild or republish authority
- current Android + Windows `1.0.0-beta` assets are uploaded to the GitHub
  prerelease and authenticated download/checksum proof passes for every listed
  asset
- Android physical-device audit is accepted as `OPERATOR_ATTESTED` for this beta wave, not as raw repository evidence
- current Android direct-APK candidate has exact-candidate production-signing
  `PASS`; public promotion remains blocked on recovery, device, distribution,
  live-smoke, and owner gates

Not safe to claim now:

- credentials are configured
- Apple artifacts are signed
- Windows artifacts are production signed
- TestFlight is live
- notarization is green
- anonymous/broad public Windows hosting is approved
- signed iOS packet-tunnel execution is proven on device
- Apple store submission is ready
- Apple cutover is approved
- app-store Android release approval is complete
- trusted Windows release approval is complete
- raw Android physical-audit evidence is attached as repo-retained PASS proof
- RU-origin readiness is proven

Blocked-by note:

- the local repo bootstrap step is complete; the `2026-05-15` approval is
  retained evidence and does not authorize a new candidate
- Android is operator-attested for this beta wave; do not upgrade that to raw audit evidence unless a retained audit artifact is attached
- Android production signing and the release-critical physical journey are
  complete for the local `1.0.2+9` direct APK. Encrypted offline recovery,
  direct-download handoff, uploaded-artifact smoke, and owner approval remain
  blockers. Windows trusted signing is a separate blocker for Windows promotion
- real-user Telegram/WebApp checks, raw Android device audit replacement
  evidence, store access, and RU-origin probes remain separate manual gates
- `POKROV-app/artifacts/releases/pokrov-app/` may retain repo-backed alpha and beta bundles built directly from this lane for engineering and tester handoff
- local RC packs and the retained `v1.0.0-beta` handoff must not be promoted or
  re-synced by themselves; a new exact candidate needs fresh signing and
  live app-session `APP_*` proof
- rollback and compatibility lanes may still exist elsewhere, but this document tracks approval of the `POKROV-app` release lane itself rather than treating another repo as the primary frame
