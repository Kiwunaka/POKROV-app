# Cutover Readiness

Last updated: 2026-05-09

This document tracks what must be true before `POKROV-app/main` is approved as the public `Android + Windows` release lane.

Historical mapping note:

- older notes may still reference `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/` on `2026-04-22`
- those older source-lane names are now historical/bootstrap references rather than the canonical git lane

## Current Status

- cutover state: `paid beta evidence lane, public cutover blocked`
- lane path: `C:/Users/kiwun/Documents/ai/POKROV-app`
- lane ownership: `canonical client development repo for POKROV-app/main`
- public scope in this document: `Android + Windows`
- Apple scope in this wave: `readiness only`
- base decision: `Karing-based candidate reopened for gated spike; clean-room lane remains current until candidate gates pass`
- Apple release state: `checked-in unsigned service lane`
- Android release state: `operator-attested outside-store beta artifact, runtime sync pending`
- Windows release state: `gated unsigned outside-store beta artifact, runtime sync pending`
- Android and Windows engineering verification: `requires fresh W07 gate run`
- public store readiness: `not approved`
- public cutover approval: `not allowed`
- public Android release approval: `staged outside-store beta only`
- public Android release blockers: `runtime APP_* sync approval, live download smoke, and final platform GO`
- public Windows release approval: `staged outside-store unsigned beta only`
- public Windows release blockers: `runtime evidence, unsigned-warning copy, and handoff approval`
- long-term repo truth: `yes`
- repo-backed alpha or beta archive: `allowed`

This repo is already the canonical development lane for new client work.
This document tracks public release approval and cutover readiness, not whether the repo exists as engineering truth.

## Required Before Public Android+Windows Cutover

1. Keep the client product contract, app-first onboarding contract, route-mode behavior, support flow, and download behavior documented in this repo.
2. Prove one real native-core provenance and packaging contract for the public Android and Windows artifacts.
3. Retain the operator-attested Android release-build localhost/control-surface audit note, or replace it with raw evidence if available.
4. Keep Windows unsigned beta posture explicit; trusted signing is not required for this outside-store beta pass, but unknown-publisher warnings must be shown.
5. Verify runtime download handoff, checkout continuation, support continuation, and Telegram bonus behavior in release-mode builds.
6. Keep release handoff evidence explicit for `current-origin`, `brain-origin`, and `RU-origin` checks where reachability matters.

## Android Gate Checklist

- [ ] Runtime artifacts are synced into the documented Android build lane
- [ ] `flutter analyze` passes in the Android host lane
- [ ] Shared runtime and widget tests pass for the public Android shell
- [ ] `flutter build apk --release` succeeds
- [ ] `flutter build appbundle --release` succeeds when store/operator artifacts are requested
- [x] Physical-device localhost/control-surface audit is operator-attested for this beta wave
- [ ] Raw audit evidence is attached if replacing the operator attestation
- [ ] Public download handoff is approved for Android `APK` / mirror; `Play` remains empty for outside-store beta
- [ ] Release handoff includes runtime URL verification and origin evidence
- [ ] Any APK shown to testers is cabinet-gated, beta-labeled, and explicitly marked internal only

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

- [ ] Runtime artifacts are synced into `apps/windows_shell/windows/runner/resources/runtime`
- [ ] `flutter analyze` passes in `apps/windows_shell`
- [ ] Shared runtime and widget tests pass
- [ ] `flutter build windows --release` succeeds
- [ ] Local release bundle contains `pokrov_windows_beta.exe` and `libcore.dll`
- [x] Unsigned beta risk is accepted for this outside-store beta wave
- [ ] Trusted code-signing identity is available for a later trusted Windows distribution
- [x] EXE first-layer beta path is chosen for this outside-store wave; `MSIX` / portable `ZIP` stay operator/store artifacts
- [ ] Public hosting and handoff path are approved
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
- the current Windows beta artifact may be shared only behind approved beta access with the unsigned warning
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
- broad public Android release approval is complete
- broad public Windows release approval is complete

Blocked-by note:

- the local repo bootstrap step is complete, but public Android and Windows release approval is still blocked on runtime APP_* sync approval, live download smoke, payment/email evidence, and final platform GO
- Android is operator-attested for this beta wave; do not upgrade that to raw audit evidence unless a retained audit artifact is attached
- Windows remains unsigned-gated beta only until runtime evidence and public handoff are ready; trusted signing is a later trust upgrade, not a blocker for this outside-store beta pass
- `POKROV-app/artifacts/releases/pokrov-app/` may retain repo-backed alpha and beta bundles built directly from this lane for engineering and tester handoff
- rollback and compatibility lanes may still exist elsewhere, but this document tracks approval of the `POKROV-app` release lane itself rather than treating another repo as the primary frame
