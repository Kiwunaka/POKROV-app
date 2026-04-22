# Cutover Readiness

Last updated: 2026-04-22

This document tracks what must be true before `POKROV-app/main` can replace the retained legacy bridge client as the public Android+Windows release truth.

Historical mapping note:

- older notes may still reference `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/` on `2026-04-22`
- those older source-lane names are now historical/bootstrap references rather than the canonical git lane

## Current Status

- cutover state: `engineering green, local repo bootstrapped, public cutover blocked`
- lane path: `C:/Users/kiwun/Documents/ai/POKROV-app`
- lane ownership: `canonical client development repo for POKROV-app/main`
- base decision: `clean-room selected`
- Apple release state: `checked-in unsigned service lane`
- Windows release state: `local unsigned bundle only`
- Android and Windows engineering verification: `green in local test/build lane`
- public store readiness: `not approved`
- public cutover approval: `not allowed`
- shipping truth: `no`
- release truth: `no`
- long-term repo truth by itself: `yes`
- bridge-period repo-backed artifact mirror: `yes`

## Required Before Public Cutover

1. Document one real native-core provenance and packaging contract for `iOS`, `macOS`, `Android`, and `Windows`.
2. Review and prove the Apple connectivity path, especially live `NEPacketTunnelFlow` behavior on device.
3. Provision the real Apple team, bundle IDs, app groups, profiles, and signing identities.
4. Produce signed Apple artifacts from a Mac and keep the evidence in the handoff.
5. Complete TestFlight, App Store, notarization, and Gatekeeper validation.
6. Finish store metadata, screenshots, support mailbox, and privacy answers.
7. Provide trusted Windows signing, installer or `MSIX` packaging, and public hosting evidence for the Windows lane.

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
- `app-next/` and `external/pokrov-next-client/` are now historical/bootstrap source references, not the canonical git lane
- this repo is the long-term canonical git target for new client development work
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
- this lane has become shipping truth or release truth
- this repo already replaced the old bootstrap-source lane as the canonical development target, but it has not yet replaced the bridge lane as public release truth

Blocked-by note:

- the local repo bootstrap step is complete, but signed release evidence, Windows publication readiness, Apple validation, and formal cutover approval are still open
- until those release and signing gates close, legacy bridge packaging/signing remains the rollback-safe public release truth even though new product-direction work now lands in `POKROV-app`
- until that cutover closes, `POKROV-app/artifacts/releases/bridge/` may retain repo-backed Android and Windows alpha/beta bundles mirrored from the bridge lane without changing the fact that build/signing truth still lives in `external/client-fork/app`
