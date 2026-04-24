# Wave 7 New-Base Client Scaffold

Date: 2026-04-18
Status: runnable four-host runtime lane seed, now anchored to the canonical `POKROV-app` repo
Scope: `POKROV-app/`

Historical mapping note:

- earlier retained-bootstrap notes may still refer to the pre-cutover lane names, but active commands now start from this `POKROV-app` repo root
- the same lane was then normalized to `app-next/` inside the platform repo before bootstrapping this dedicated repo
- the canonical git lane for this work is now `POKROV-app/main`; older names are bootstrap history only
- this cleanup wave does not make the lane shipping truth or release truth

## Goal

Create a new-base client program seed that gives the global rework a safe future lane without modifying the current bridge client.

## In Scope

- a dedicated future-client lane separated from the retained bridge client
- canonical repo metadata that records `POKROV-app/main` as the long-term client development lane
- a top-level README and seed metadata
- a recorded base-strategy decision for `clean-room`
- placeholder folders for Android, iOS, macOS, Windows, shared packages, config, scripts, assets, docs, and tests
- non-destructive bootstrap files that help later workers start consistently
- seed `pubspec.yaml` files and package entry points that keep the workspace resumable without choosing a final runtime architecture
- local config templates and bootstrap helpers for safe workstation setup
- a real widget-test lane for the shared app shell
- a richer shared shell that already demonstrates route-mode selection, redeem entry, support handoff, and four-variant locations
- runtime-lane documentation for native-core dependency, Apple inventory, and cutover limits

## Out Of Scope

- any edits inside `external/client-fork/app/`
- importing upstream code from `Karing` or any other base
- a production-ready Flutter app
- any further git-model migration for the current shipping client or public release lanes
- CI, trusted signing, public installer or `MSIX` publication, or deployment wiring
- public store-readiness or production-cutover claims

## Current Assumptions

- visible product naming stays `POKROV`
- the app remains `consumer-first` and `app-first`
- the clean-room lane is the chosen base and keeps four public host targets while production release wiring stays out of scope
- this wave now records that the earlier bootstrap lane names resolve to the canonical `POKROV-app/main` repo
- `sing-box` stays the default core and `xray` remains advanced fallback only
- real public cutover still depends on signed provenance, device proof, and store-ready runtime evidence
- the first-run happy path stays `open app -> Try free -> get real access -> Connect`

## Scaffold Success Criteria

The seed is complete when:

1. the canonical repo lane exists separately from the bridge client
2. the base decision is documented and resumable
3. future platform and package boundaries are visible from the folder layout
4. a simple validation script can confirm the seed is present
5. local-only bootstrap helpers can materialize config examples without touching production paths
6. regenerated `config/local/*` stays clearly local-only and disposable
7. the shared shell can run local widget tests
8. the existing bridge client remains untouched
9. the docs state the current runtime and store limits without over-claiming readiness

## Initial Structure

- `apps/android_shell`: future Android entry shell
- `apps/ios_shell`: future iOS entry shell
- `apps/macos_shell`: future macOS entry shell
- `apps/windows_shell`: future Windows entry shell
- `packages/app_shell`: future shared navigation and first-run shell
- `packages/core_domain`: future app-first entities, access state, routing mode, and smart-connect models
- `packages/platform_contracts`: future engine, permissions, platform adapters, and connect/disconnect contracts
- `packages/support_context`: future support diagnostics and escalation payload shaping

## Executable Seed Additions

- `melos.yaml`: workspace discovery for host apps and packages
- `apps/*/pubspec.yaml`: seed host package manifests
- `packages/*/pubspec.yaml`: shared package manifests
- `packages/app_shell/lib/app_shell.dart`: runnable shared shell that is now locked to `Подключение / Локации / Правила / Профиль`
- `config/platform-matrix.seed.json`: four-platform scope map with one thin host shell per public target
- `config/runtime-profile.seed.json`: runtime facts snapshot for the seed lane, including free-tier and monetization rules
- `config/templates/*`: local-only config templates
- `config/local/*`: regenerated local-only workstation config materialized from those templates
- `scripts/bootstrap-workspace.ps1`: resolves Flutter dependencies for the workspace
- `scripts/run-tests.ps1`: runs the starter widget-test lane
- `scripts/bootstrap-local.ps1`: non-destructive local config materialization
- `packages/app_shell/test/pokrov_seed_app_test.dart`: widget coverage for the shell
- `test/seed-layout.ps1`: richer seed smoke test

## Current Runtime Coverage

- The `Подключение` lane now reflects `Try free`, external checkout-only monetization, the managed `activation key -> redeem -> managed profile` story, and a live app-first bootstrap for Android and Windows.
- Route-mode UX already models `Full tunnel`, `Selected apps`, and `All except RU`, while respecting host support for split tunneling.
- Locations already show `Auto-select best` plus the fixed transport ordering `VLESS+REALITY`, `VMess`, `Trojan`, `XHTTP`, with launch gating for `XHTTP`.
- `Профиль` now owns free fallback, community bonus, redeem entry, and support-safe handoff surfaces, with any standalone support leftovers treated as transitional seed UI rather than final product IA.
- Windows now uses real `libcore` FFI loading, live managed-profile bootstrap, and build-verified runtime startup.
- Windows now also has a local unsigned build-and-package helper that verifies bundle composition and prerelease metadata.
- macOS now has bundle-aware runtime discovery and host artifact copy wiring.
- Android now has a seed `VpnService` full-tunnel lane plus runtime-bridge `initialize -> managed bootstrap -> stage -> connect -> disconnect`.
- iOS now has runtime-bridge `initialize -> stage`, shared app-group staging, a checked-in `PacketTunnelExtension` target, host-driven `NETunnelProviderManager` start/stop requests, and source-backed Libbox packet-tunnel service wiring inside the extension.

## Runtime Lane Limits

- The lane is real enough to validate package boundaries, host-shell bootstraps, shared-shell behavior, and a meaningful portion of native runtime integration.
- The lane now pins and syncs `hiddify-core v3.1.8` artifacts into the host shells through `config/runtime-artifacts.seed.json` and `scripts/fetch-libcore-assets.ps1`.
- No trusted signing, public installer or `MSIX` publication, or store automation in this subtree should be treated as production-ready.
- Public cutover stays blocked until signed Apple release proof, Apple on-device tunnel evidence, Android device validation, four-platform verification, and release automation all exist together.
- Regenerated `config/local/*`, host `build/` outputs, and staged local bundles are local verification artifacts only; they are not shipping truth or release truth.

## Apple Readiness Inventory

| Host | Present in Wave 7 | Missing before readiness |
| --- | --- | --- |
| `iOS` | host shell, placeholder release bundle ID, deployment target `12.0`, host + extension app-group entitlements, deep-link plist, bundled `Libcore.xcframework`, shared runtime staging, checked-in `PacketTunnelExtension` target scaffold, `NETunnelProviderManager` start/stop requests, checked-in Libbox command server plus service wiring, `RunnerTests` target | reviewed production entitlements, real signing team, provisioning profiles, archive/export proof, signed on-device tunnel evidence, TestFlight or App Store metadata |
| `macOS` | host shell, placeholder release bundle ID, deployment target `10.14`, tightened sandbox entitlements, hardened-runtime placeholder, deep-link plist, bundle-time copy of `libcore.dylib` and `HiddifyCli`, `RunnerTests` target | real signing team, signed archive, notarization flow execution, Gatekeeper proof, provisioning inventory, Mac App Store metadata |

These inventories should be read as implementation notes, not as ship approval.

Current concrete source-of-truth placeholders for this lane:

- `config/apple-release.seed.json`
- `config/cutover-readiness.seed.json`
- `config/release-handoff.seed.json`
- `docs/operations/apple-release-readiness.md`
- `docs/operations/cutover-readiness.md`

## Handoff Notes

- This seed now records `clean-room` as the chosen base.
- The next real implementation step should build on the current clean-room lane unless a later explicit decision re-opens the base choice.
- The first production-hardening wave after that gate should build on the pinned native-core artifact story that already exists here, instead of re-opening it.
- The next engineering focus should be signed Apple tunnel validation, Android device validation, and release automation rather than redoing seed runtime wiring.
- If later work needs shared facts, sync from the root platform source of truth instead of copying stale values by hand.
- This cleanup wave records `POKROV-app/main` as the canonical client development lane; it does not make this lane the shipping or public release truth.
