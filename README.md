# POKROV App

Last updated: 2026-04-22

This directory is the canonical `POKROV-app` client repository for the new `Android + Windows` development lane.

Historical path note:

- earlier docs and work orders may still call this lane `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/` on `2026-04-22`
- `app-next/` inside the platform repo is now transition/reference material rather than the canonical git lane

This repo now carries new client product-direction work and is the only active client development and release-metadata canon.
The retired bridge bundle lineage is preserved under `artifacts/releases/bridge/` as archive evidence only.

Bridge-artifact mirror note:

- the public `Kiwunaka/PORTALapp` fork cannot accept new Git LFS release objects
- retained Android and Windows bridge bundles are mirrored into `artifacts/releases/bridge/` here as rollback-safe evidence
- treat that mirror as archive evidence only; it does not override the active `POKROV-app` release-metadata home

Next-client artifact note:

- repo-backed alpha and beta bundles produced directly from this lane should live under `artifacts/releases/pokrov-app/`
- these bundles prove that the canonical next-client repo can build Android and Windows locally, but they do not make this lane the public release-build or signing truth before formal cutover
- stable root-repo handoff metadata for this lane now lives at `config/release-handoff.seed.json`
- active release-handoff manifests live under `artifacts/releases/pokrov-app/<version>/release-handoff.json` with the stable pointer at `artifacts/releases/release-handoff.json`

## Status

- runnable app-first Flutter workspace for local validation and widget tests
- clean-room shared packages plus Android, iOS, macOS, and Windows host entrypoints
- richer shared shell for route-mode selection, redeem handoff, free-tier facts, four-variant locations, and a live managed-profile bootstrap
- Hiddify-inspired premium shell styling with accent hero, metric tiles, soft glass surfaces, and one-tap connect flow
- seed contract snapshots for product, platform matrix, and runtime profile
- pinned `hiddify-core v3.1.8` artifact contract plus fetch/sync tooling for all four host shells
- real runtime-engine integration in the shared workspace, with Windows/macOS FFI loading and mobile host-bridge method channels
- Android full-tunnel seed lane via `VpnService`, with staged managed-config content handed into `Libbox.newService(...)` through the runtime bridge instead of a path-only stub
- Android materialization now keeps the mobile lane `tun`-only; desktop-only loopback listener inbounds stay out of the Android runtime config
- Android runtime materialization now preserves the backend-managed `dns` and `route` semantics wherever they are already mobile-safe, instead of replacing the full premium profile with a seed-only universal DNS lane
- Android bootstrap now has a host-preserving TLS fallback to the canonical control-plane IP for `api.pokrov.space`, so emulator-grade DNS instability does not block app-first session bootstrap
- Android route materialization now keeps `auto_detect_interface` and `override_android_vpn` enabled and injects a self-package bypass rule for `space.pokrov.pokrov_android_shell`, so the Android runtime can keep its own control traffic off the TUN while `auto_route` is active
- Android host runtime now exposes platform auto-detect and default-network monitor hooks before live connect, so libbox can rely on Android `ConnectivityManager` state instead of a desktop netlink monitor
- Android host runtime now registers an Android-native local DNS transport before `Libbox.newService(...)`, so mobile DNS lookups can ride the current default network instead of relying on desktop-style loopback DNS surfaces
- Android default-network resolution now sticks to the callback-owned uplink instead of falling back to `ConnectivityManager.activeNetwork` after connect, which keeps mobile DNS away from the VPN network itself
- Android manifest now declares both `ACCESS_NETWORK_STATE` and `CHANGE_NETWORK_STATE`, which the platform-backed default-interface monitor needs before live connect can complete
- Android tun materialization now follows the Hiddify-style mobile lane more closely: the staged `tun` inbound uses `stack: mixed`, desktop-only Android private-DNS loopback inbounds stay out of the runtime config, and `ipv4_only` sessions no longer keep an unnecessary IPv6 tunnel lane
- Android full-tunnel materialization now keeps the consumer lane `tun`-first end to end: mobile-safe backend `dns` and `route` semantics stay intact, desktop loopback listener surfaces stay stripped, and only address families present in the staged profile receive default routes
- Android runtime snapshots now export structured host diagnostics for the shared shell, including default uplink interface and index, DNS readiness, route counts, package-filter counts, last failure kind, and last stop reason
- The shared shell now treats Android `running` as fully healthy only when post-establish uplink and DNS diagnostics are healthy; otherwise the same connect stays visible as `Connected with warnings`
- The shared shell now refreshes Android runtime state again when the app returns to the foreground, and the host bridge reconciles a live TUN back to `running` instead of leaving the UI stuck on a stale staged snapshot after relaunch
- Android runtime service now prefers a non-sticky lifecycle and handles `onRevoke()`, so repeated connect/stop cycles and system-side VPN revokes do not leave the clean-room shell in a falsely connected state as easily
- Android shared-shell diagnostics now expose a concrete `Runtime health` lane with refresh, runtime priming, local smoke-profile staging, and live connect/disconnect controls so bootstrap failures are easier to classify before device-only validation
- Android foreground notification now includes a direct `Disconnect` action so the live runtime can be stopped without reopening the app
- Android and Windows `All except RU` now classify RU traffic client-side before connect by caching local sing-box `.srs` rule-sets in the runtime-owned support tree instead of relying only on domain suffix shortcuts or node-side fallback rules
- `scripts/run-tests.ps1` now executes the real Android validation lane: Flutter tests for `apps/android_shell` plus Android Gradle unit tests for manifest guards, platform monitoring, runtime state, DNS planning, and route planning
- iOS `NETunnelProviderManager` seed connect/disconnect request lane through the runtime bridge
- macOS bundle-aware artifact discovery plus host copy wiring for `libcore.dylib` and `HiddifyCli`
- canonical client repo established from the former `app-next/` bootstrap snapshot
- no CI wiring
- no release wiring
- no bridge-client imports
- no production impact
- no store readiness
- no production cutover
- not shipping truth
- not release truth
- canonical repo target for new client development work

## Purpose

This seed creates a safe place to:

- carry the recorded base decision to proceed `clean-room`
- carry the bootstrapped clean-room client repo forward without touching the live bridge client
- keep Apple hosts present with concrete runtime and release-prep seeds without claiming signed/store-ready release state
- stage shared app-first package boundaries before deeper runtime implementation begins
- exercise the future product shell with redeem, support, route-mode, location-matrix, and app-first managed-connect flows
- seed a local `melos` workspace, local config bootstrap flow, and runnable host entry points
- keep future work resumable for other workers in the global rework

## Guardrails

- Do not treat the retired bridge repo as an active workflow target from this lane.
- Keep public naming aligned with `POKROV`; use `POKROV VPN` only for compatibility notes.
- Treat this directory as the new-base runtime lane, not as an already approved cutover candidate.
- Treat this subtree as the canonical git truth for new client development, but not yet as the shipping truth or release truth for Android, Windows, Apple, or store publication.
- Treat `app-next/` in the platform repo as historical bootstrap-source material and transition reference only.
- Keep the app shells and package code narrow enough that future refactors stay possible, but treat this lane as the chosen `clean-room` path unless a separate decision explicitly re-opens `Karing`.

## Layout

- `apps/`: future platform shells with starter Android, iOS, macOS, and Windows host entry points
- `packages/`: shared seed modules for app shell, domain, platform contracts, and support context
- `config/`: seed contract snapshots, runtime profiles, local config templates, and regenerated local-only `config/local/*` materializations
- `config/release-handoff.seed.json`: stable root-repo handoff source for canonical lane identity plus the latest repo-backed release archive
- `docs/`: scaffold spec, decision gates, and structure notes
- `assets/`: repo-local brand assets and generated launcher/icon masters
- `scripts/`: non-destructive local validation and bootstrap helpers for this scaffold
- `test/`: future focused test lane for this program

## Start Here

1. Read `docs/specs/2026-04-18-wave-7-new-base-client-scaffold.md`.
2. Read `docs/decisions/2026-04-18-karing-vs-clean-room-gate.md`.
3. Read `docs/architecture/package-boundaries.md` and `docs/architecture/bootstrap-workflow.md`.
4. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\validate-seed.ps1` from this directory when you want a quick scaffold check.
5. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-workspace.ps1` to resolve local Flutter dependencies.
6. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\fetch-libcore-assets.ps1 -Platforms @('windows','android','ios','macos') -SyncToHosts -Force` to sync the pinned native runtime artifacts.
7. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\run-tests.ps1` to execute the shared Flutter test lane plus the Android-shell Gradle unit lane.
8. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-local.ps1 -DryRun` to preview regenerated local-only config materialization under `config/local/`.
9. Read the Apple and runtime boundary notes in `docs/specs/2026-04-18-wave-7-new-base-client-scaffold.md` before claiming readiness beyond local shell validation.

## Starter Workflow

1. Validate the seed structure.
2. Bootstrap the workspace dependencies with `scripts/bootstrap-workspace.ps1`.
3. Sync the pinned native runtime artifacts into the host shells.
4. Run the shared Flutter test lane and Android-shell Gradle unit lane with `scripts/run-tests.ps1`.
5. Materialize `config/local/*` from the templates when a worker wants to prototype locally.
6. Keep production cutover behind the chosen `clean-room` path plus four-platform verification and release automation.

## Runtime Dependency Boundary

- The shared seed already models `sing-box` as the default runtime core and `xray` as advanced fallback in `config/product-contract.seed.json` and `config/runtime-profile.seed.json`.
- The lane now pins `hiddify-core v3.1.8` in `config/runtime-artifacts.seed.json`, fetches it through `scripts/fetch-libcore-assets.ps1`, and syncs it into the host shells. Windows currently consumes only `libcore.dll` from that asset lane.
- Windows and macOS use the FFI runtime lane directly; Android and iOS call into host-native runtime bridges through `space.pokrov/runtime_engine`.
- Android and Windows now fetch a real app-first managed profile from `POST /api/client/session/start-trial` and `GET /api/client/profile/managed` before connect; the old local smoke profile remains diagnostics-only.
- The desktop FFI lane now applies Hiddify-style runtime options before `libcore start`; the current Windows seed prefers a system-proxy host mode with dedicated local ports so one-tap connect can work without an elevated TUN session.
- The shared bootstrapper now reuses one `HttpClient` per connect attempt, retries short-lived `DNS/TLS/5xx` failures, and accepts `--dart-define=POKROV_API_BASE_URL=https://...` for operator or staging overrides.
- The shared shell now polls the host runtime briefly after `Connect with sing-box`, so Android can settle from permission/start into a durable `running` state instead of snapping straight back to idle UI.
- The shared shell now keeps Android connect/disconnect transitions busy until the host settles, so repeated taps cannot easily queue duplicate `START` or `STOP` requests while the system VPN permission or service teardown is still in flight.
- Android reconnects now always refresh the live managed profile before start, which prevents stale staged configs from silently reusing an older route mode when the UI already shows `Full tunnel`.
- The Android host bridge now preserves the last concrete startup failure in runtime snapshot state instead of overwriting it with a generic `service stopped` message during teardown.
- The Android service now trusts `Libbox.newService(...)` as the runtime creation boundary and avoids a redundant preflight `Libbox.checkConfig(...)` pass that can diverge from the real platform-backed startup path.
- The Android lane now keeps the backend-managed selector and route-rule semantics intact whenever possible, while still stripping Android-forbidden route keys and desktop-only local DNS listeners from staged runtime configs.
- The Android DNS lane now stays close to the Hiddify mobile default: a plain `1.1.1.1` remote resolver, a direct bootstrap resolver, and no desktop loopback DNS surfaces in the staged mobile runtime config.
- Android DNS now also keeps an independent cache per resolver lane, which reduces cross-contamination between direct bootstrap lookups and the remote resolver used for blocked-service traffic.
- The Android default-network monitor now rejects VPN networks as DNS uplinks and retries interface-index discovery before reporting the current uplink back to libbox.
- The Android host bridge now emits both raw and derived health fields in runtime snapshots, so the shared shell can render the live uplink, DNS, route, and failure state without guessing from a plain `running` phase.
- The Android lane now keeps TUN route families honest: default IPv4 and IPv6 routes are only added when the staged profile actually carries that address family, which avoids black-holing IPv6 on `ipv4_only` sessions.
- `All except RU` now has a stronger client-side lane on both Android and Windows: the shared bootstrapper caches local rule-set files under `getApplicationSupportDirectory()/pokrov-runtime/data/rule-set/all-except-ru-rule-sets`, injects them into staged sing-box `rule_set` routing before connect, and still leaves `.ru`, `.xn--p1ai`, and `.su` suffix rules in place as a fail-open fallback when the cache cannot refresh.
- The current `All except RU` cache combines hydraponique `roscomvpn-geosite` domain overlays, hydraponique `roscomvpn-geoip` whitelist CIDR overlays, and upstream `SagerNet/sing-geoip` `geoip-ru` for the broader RU IP catch-all.
- The Android validation lane now has repo-local proof points on both sides of the shell boundary: `apps/android_shell/test/` covers shell boot plus runtime-diagnostics affordances, and `apps/android_shell/android/gradlew.bat testDebugUnitTest` covers manifest guards, platform monitoring, runtime state, DNS planning, and TUN route planning.
- Stop and reconnect transitions now demote Android runtime state before teardown, which keeps the shared shell from holding onto a stale `Connected` snapshot as often during rapid reconnect loops.
- Selected-apps parity is still outside this cycle: the hardening work in this wave is for `Full tunnel`, while per-app Android parity remains a deferred follow-up.
- This is still not a release claim: Android needs production service hardening and device validation, and Apple still needs signing, entitlement, archive, and on-device verification even though the checked-in iOS provider now carries Libbox-backed service code.
- The stronger Android test lane is still not a release substitute: it proves repo-local Flutter and JVM-side invariants only, and the required physical-device localhost/control-surface audit remains a separate gate.
- Treat provenance updates, checksums, host packaging drift, and four-platform runtime verification as blocking dependencies for release candidates and public cutover.
- Treat regenerated `config/local/*`, host `build/` outputs, and staged local bundles as disposable workstation artifacts rather than shipping or release truth.

## Apple Readiness Snapshot

Current Apple host inventory in this lane is concrete release-prep plus runtime-seed wiring:

| Host | Present now | Still missing |
| --- | --- | --- |
| `iOS` | Flutter host shell, placeholder signing xcconfig, app-group entitlements, deep-link plist, `Libcore.xcframework` embedding, runtime-bridge staging, checked-in `PacketTunnelExtension`, `NETunnelProviderManager` seed connect/disconnect requests, and source-backed Libbox service wiring inside the extension | reviewed production entitlements, development team, provisioning profiles, archive/export proof, signed on-device tunnel evidence, App Store metadata |
| `macOS` | Flutter host shell, placeholder signing xcconfig, tightened entitlements, hardened-runtime placeholder, bundle-time runtime copy of `libcore.dylib` and `HiddifyCli`, `RunnerTests` target | real signing identity, notarization execution, Gatekeeper validation, provisioning inventory, Mac App Store metadata |

These inventories are readiness notes only. They do not make either Apple host store-ready.

## Current Cutover Limits

- Nothing in this subtree replaces the live bridge client for `Android` or `Windows`.
- No public download surface should point at this lane.
- No store submission, TestFlight, notarization, or Microsoft Store claim should be made from this lane yet.
- Four-platform host shells now carry real runtime seeds, but full product cutover stays blocked on Apple packet-tunnel/runtime completion, Android device validation, signing readiness, and real release automation.
- Local `config/local/*` files and host `build/` outputs are regenerated local-only artifacts; they can support local validation, but they do not define release truth.

## Current Lane Truth

- This clean-room seed now exposes four public host targets: `Android`, `iOS`, `macOS`, and `Windows`.
- The shared shell now models app-first trial, free fallback, external checkout handoff, redeem entry, four-variant locations, and live managed-profile staging for Android and Windows.
- The next-client lane now pins and syncs `libcore` artifacts for all four host shells.
- Android already has a real `VpnService` seed lane, and iOS already has a checked-in packet-tunnel extension with `NETunnelProviderManager` control plus Libbox-backed service code.
- The Apple hosts still do not have reviewed signing, notarization, or a live traffic-carrying packet-tunnel implementation, so they remain pre-release lanes.
- Nothing in this subtree authorizes public cutover by itself; retained bridge lineage remains archived under `artifacts/releases/bridge/`, while this repository is the only active git-truth target for client development and release metadata.
