# POKROV Client Release Backlog

Last updated: 2026-05-09

## Document Status

This file tracks the current public-release blockers and follow-up backlog for `POKROV-app/main`.

## Current Status

The app-first foundation and the consumer information architecture are in place in the new client repo. Android and Windows artifacts are staged for an outside-store beta on `0.2.0-beta.1`, but public Android+Windows release approval is still blocked by runtime handoff, email/payment evidence, and final platform GO.

Latest documented repo-level gate note:

- the latest recorded full `python scripts/release_orchestrator.py --gates-only` success snapshot remains the `2026-04-13` run from the platform workspace
- that local green gate snapshot does not replace runtime handoff, live-origin evidence, or payment/email proof
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

## Public Android+Windows Blockers

### Android local-surface security gate

- retain the operator-attested physical-device localhost/control-surface audit for this beta wave
- replace the attestation with raw audit evidence only if the operator supplies it
- keep negative tests for unauthorized local-client access and config or key exposure in the release path for later builds

### Route-mode, routing, and DNS verification

- keep the public routing story focused on `All except RU` and `Full tunnel`
- keep `Blocked only` internal until routing assets, DNS behavior, and leak checks are complete enough for honest verification
- finish geo-asset wiring for routing rules and DNS presets
- validate DNS split and leak behavior on Android and Windows before treating RU-specific routing copy as fully shipped
- keep the persisted route-mode contract aligned with backend-owned `route_mode`, `selected_apps`, `requires_elevated_privileges`, and `route_policy.*`

### Release branding, packaging, and hosting

- keep regenerated launcher, tray, and package assets aligned with the final `POKROV` brand set
- keep Windows package identity, executable naming, installer naming, and public artifacts on the canonical `POKROV` / `pokrov` line
- build fresh Android and Windows release candidates after the latest branding sync
- keep trusted signing as a later trust upgrade; it is not required for this outside-store beta wave
- keep Android APK runtime/public download blocked until the runtime APP_* sync and live download smoke pass
- keep Windows unsigned bundles gated and beta-labeled, with explicit SmartScreen or unknown-publisher warning text
- keep runtime download handoff aligned with the currently exposed public targets: Android `Play` / `APK` / mirror and Windows `EXE` / mirror
- keep `AAB`, `MSIX`, and portable `ZIP` aligned as store/operator artifacts unless the public payload expands

### Runtime launch and handoff verification

- verify the shipping client uses the real backend contracts for trial, profile, support, Telegram bonus, and checkout continuation in release builds
- validate final download links and release handoff values after signed artifacts are published
- confirm app, bot, and authenticated web surfaces consume the same runtime `APP_*` values after handoff
- split release-reachability evidence into `current-origin`, `brain-origin`, and `RU-origin` checks when regional reachability matters

## Karing-Based Candidate Lane

- [ ] Prove full-source Karing buildability for Android and Windows
- [ ] Implement POKROV managed mode
- [ ] Pass Android + Windows release gates before any public cutover

## Follow-Up Backlog

### User-facing wording cleanup

- remove remaining user-visible inherited `Hiddify` or legacy power-user wording from advanced surfaces
- polish Russian copy where inherited text still feels technical or legacy
- keep advanced networking controls out of first-layer onboarding and daily-use screens

### Route-mode and support UX polish

- keep the route-mode editor discoverable from the normal shell instead of hiding it behind compatibility-only settings
- make sure support diagnostics show safe summaries instead of raw topology or share-link surfaces
- keep recovery actions centered on reconnect, refresh, location change, checkout, and support rather than raw subscription copy/edit actions

### Download-surface continuity

- keep `/api/client/apps` payloads, install docs, and signed release handoff aligned
- rebuild or redeploy static download surfaces whenever public Android or Windows URLs change
- keep public-facing version labels on `0.x.x-beta` across client, docs, and release notes
- selected-apps remains a beta MVP unless Android package picking, Windows process picking, persistence, and OS enforcement are all proven

## Explicit Non-Blockers In This Wave

- internal Dart package/import cleanup remains a coordinated refactor, not a public-release blocker by itself
- `iOS` and `macOS` remain readiness-only lanes in this wave
- a local alpha/beta artifact mirror under `artifacts/releases/pokrov-app/` is useful for engineering handoff, but it does not by itself prove public release approval
