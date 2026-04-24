# Cutover Readiness

Last updated: 2026-04-23

This document tracks what must be true before `POKROV-app/main` is approved as the public `Android + Windows` release lane.

Historical mapping note:

- older retained-bootstrap notes may still reference `app-next/`, but active commands now start from this `POKROV-app` repo root
- the initial local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/` on `2026-04-22`
- those older source-lane names are now historical/bootstrap references rather than the canonical git lane

## Current Status

- cutover state: `engineering green, local repo bootstrapped, public cutover blocked`
- lane path: `C:/Users/kiwun/Documents/ai/POKROV-app`
- lane ownership: `canonical client development repo for POKROV-app/main`
- public scope in this document: `Android + Windows`
- Apple scope in this wave: `readiness only`
- base decision: `clean-room selected`
- Apple release state: `checked-in unsigned service lane`
- Windows release state: `local unsigned bundle only`
- Android and Windows engineering verification: `green in local test/build lane`
- public store readiness: `not approved`
- public cutover approval: `not allowed`
- public Android release approval: `blocked`
- public Windows release approval: `blocked`
- long-term repo truth: `yes`
- repo-backed alpha or beta archive: `allowed`

This repo is already the canonical development lane for new client work.
This document tracks public release approval and cutover readiness, not whether the repo exists as engineering truth.

## Required Before Public Android+Windows Cutover

1. Keep the client product contract, app-first onboarding contract, route-mode behavior, support flow, and download behavior documented in this repo.
2. Prove one real native-core provenance and packaging contract for the public Android and Windows artifacts.
3. Complete the Android release-build localhost and local-control-surface audit on physical hardware.
4. Provide trusted Android and Windows signing plus public hosting or handoff evidence for the release artifacts.
5. Verify runtime download handoff, checkout continuation, support continuation, and Telegram bonus behavior in release-mode builds.
6. Keep release handoff evidence explicit for `current-origin`, `brain-origin`, and `RU-origin` checks where reachability matters.

## Android Gate Checklist

- [ ] Runtime artifacts are synced into the documented Android build lane
- [ ] `flutter analyze` passes in the Android host lane
- [ ] Shared runtime and widget tests pass for the public Android shell
- [ ] `flutter build apk --release` succeeds
- [ ] `flutter build appbundle --release` succeeds when store/operator artifacts are requested
- [ ] Release-installed build passes the physical-device localhost/control-surface audit
- [ ] Trusted Android signing material is available
- [ ] Public download handoff is approved for Android `Play` / `APK` / mirror
- [ ] Release handoff includes runtime URL verification and origin evidence

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
- [ ] Local release bundle contains `pokrov_windows_seed.exe` and `libcore.dll`
- [ ] Trusted code-signing identity is available
- [ ] Installer or `MSIX` publication path is chosen
- [ ] Public hosting and handoff path are approved

## Safe Claims

Safe to claim now:

- the local `POKROV-app` repo is bootstrapped and carries the clean-room client lane
- `app-next/` is now a historical/bootstrap source reference, not the canonical git lane
- this repo is the long-term canonical git target for new client development work
- this repo now owns the client product contract, app-first onboarding contract, and client backlog tracking under `docs/`
- public scope for this release wave remains `Android + Windows`
- Apple work in this repo is readiness and packaging preparation only for this wave
- iOS and macOS shell metadata is materially closer to a real release lane
- iOS now carries checked-in packet-tunnel service code instead of a deliberate scaffold stop
- operator work needed for signing, notarization, and store prep is now explicit
- Windows now has a real local runtime build-and-bundle lane with unsigned package staging

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
- public Android release approval is complete
- public Windows release approval is complete

Blocked-by note:

- the local repo bootstrap step is complete, but public Android and Windows release approval is still blocked on signing, artifact handoff, Android localhost-audit evidence, and final runtime verification
- `POKROV-app/artifacts/releases/pokrov-app/` may retain repo-backed alpha and beta bundles built directly from this lane for engineering and tester handoff
- rollback and compatibility lanes may still exist elsewhere, but this document tracks approval of the `POKROV-app` release lane itself rather than treating another repo as the primary frame
