# Bootstrap Workflow

This repo is the bootstrapped clean-room client lane and gives later workers a consistent way to validate the tree, resolve Flutter dependencies, run local tests, and materialize local-only config for the four-host Wave 7 runtime lane under `POKROV-app/`.

Historical mapping note:

- older retained-bootstrap docs may still say `app-next/`, but active commands now start from this `POKROV-app` repo root
- the initial local snapshot for this repo came from `C:/Users/kiwun/Documents/ai/VPN/app-next/`
- this workflow now documents the canonical `POKROV-app` repo rather than the former in-repo bootstrap source

## Fast Path

From `POKROV-app/`:

1. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\validate-seed.ps1`.
2. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-workspace.ps1`.
3. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\fetch-libcore-assets.ps1 -Platforms @('windows') -SyncToHosts` when you want the Windows host shell refreshed against the pinned runtime artifacts.
4. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\run-tests.ps1`.
   This now covers the shared Flutter lane, `apps/android_shell` Flutter tests, and `apps/android_shell/android/gradlew.bat testDebugUnitTest`.
5. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\build-windows-release.ps1 -SyncRuntime` when you want the local Windows analyze, test, build, and unsigned-package lane.
6. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-local.ps1 -DryRun`.
7. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-local.ps1` only if you want local config files under `config/local/`.
8. Treat `melos.yaml` as the future workspace entry once Flutter tooling is available.

## Generated Local Files

`bootstrap-local.ps1` copies:

- `config/templates/local.env.example` -> `config/local/local.env`
- `config/templates/device-overrides.seed.json` -> `config/local/device-overrides.json`

The generated files are git-ignored and can be deleted or regenerated freely.

Treat everything under `config/local/*` as regenerated local-only workstation config. It is useful for local prototyping and validation, but it is not shipping truth or release truth.

## Runnable Pieces

The clean-room starter now includes:

- shared domain, platform-contract, and support-context packages
- a shared Material shell that now locks the consumer-first tab set `Подключение / Локации / Правила / Профиль`
- Android, iOS, macOS, and Windows host entrypoints that build the shell from shared bootstrap defaults
- a widget test lane in `packages/app_shell/test/`
- Android-shell Flutter tests in `apps/android_shell/test/`
- Android Gradle unit tests in `apps/android_shell/android/app/src/test/`

## Runtime Boundary

This workflow proves that the Flutter workspace and shared shell are runnable. It does not yet prove that the lane can replace the bridge release client as public release truth.

Current blocking dependency:

- the lane now has a real staged-artifact contour: `fetch-libcore-assets.ps1` pins the current `libcore` tag, syncs all four host artifacts, and the shared `runtime_engine` can verify those artifacts at runtime
- `Android` host now reaches a real service-backed connect lane: it can initialize libcore, stage a managed profile, request VPN permission, start a foreground `VpnService`, and hand tun ownership to the native runtime through the host `PlatformInterface`
- Android runtime materialization is intentionally `tun`-only in this lane; desktop loopback listener inbounds such as `mixed-in` and `dns-in` stay disabled for the mobile `VpnService` path
- Android runtime materialization now keeps backend-managed `dns` servers, selector choice, and route-rule semantics whenever they are already mobile-safe, instead of swapping the whole profile into a custom universal DNS lane
- the Android bootstrap client can preserve the HTTPS host while dialing the canonical control-plane IP for `api.pokrov.space`, which keeps emulator-grade DNS flakiness from blocking app-first session start
- the Android route block now keeps `auto_detect_interface` and `override_android_vpn` enabled and injects a self-package bypass rule for `space.pokrov.pokrov_android_shell`, so the live Android lane can preserve a working uplink owner while `tun.auto_route` is active
- the Android host runtime now advertises platform auto-detect and default-network monitor hooks, so libbox can follow Android `ConnectivityManager` state instead of falling back to a desktop netlink monitor path
- the Android host runtime now registers a local DNS transport backed by Android `DnsResolver` and the current default network, which keeps the mobile lane off desktop-only loopback DNS stubs when `libbox` resolves staged profile dependencies
- the Android default-network monitor now sticks to the callback-owned uplink after connect instead of re-sampling `ConnectivityManager.activeNetwork`, which keeps mobile DNS from accidentally treating the VPN network as its resolver uplink
- the Android manifest must also declare `ACCESS_NETWORK_STATE` and `CHANGE_NETWORK_STATE`, otherwise the `ConnectivityManager`-backed default-interface monitor fails before runtime start
- the Android `tun` inbound now uses the Hiddify-style `mixed` stack instead of the desktop-oriented `system` stack, and the materialized mobile runtime no longer injects the old `android-private-dns-in` loopback bridge into the staged config
- the Android DNS block now stays close to the Hiddify mobile default: a plain `1.1.1.1` remote resolver, a direct bootstrap resolver, and no desktop loopback DNS surfaces in the staged mobile lane
- the Android DNS block also keeps resolver caches independent so direct bootstrap lookups do not poison the remote resolver lane used for blocked-service traffic
- the Android host route planner now adds IPv4 and IPv6 default routes only for address families that are actually present in the staged profile, and `ipv4_only` sessions no longer keep an unnecessary IPv6 tunnel lane for blocked-service traffic
- the Android default-network monitor now filters out VPN networks before exposing the current uplink to `DnsResolver` or libbox, and it retries interface-index lookup before publishing interface updates
- the Android host runtime snapshot now carries structured health fields for the shared shell, including default uplink interface and index, DNS readiness, route counts, package-filter counts, last failure kind, and last stop reason
- the Android lane now has a real repo-local test lane: Flutter tests assert the Android shell keeps the route-mode and runtime-diagnostics affordances visible, and Gradle unit tests cover manifest guards, platform monitoring, runtime-state handling, DNS planning, and TUN route planning
- the Android diagnostics story is now support/internal rather than first-layer UI: local smoke-profile staging and raw runtime controls stay out of the consumer shell while the physical-device gate remains separate
- the Android full-tunnel guarantee in this lane is also stronger: the mobile path stays `tun`-first, desktop loopback listeners remain stripped, backend-managed mobile-safe `dns` and `route` semantics stay intact, Android route ownership flags plus the self-package bypass remain present, and only address families present in the staged profile receive default routes
- the shared shell now treats Android `running` as cleanly healthy only when those post-establish uplink and DNS diagnostics are healthy; otherwise it stays in a warning state instead of reporting a flat `Connected`
- the shared shell now refreshes Android runtime truth again on foreground resume, and the host bridge reconciles a live TUN back to `running` so a relaunch does not leave the button lane stuck on a stale staged snapshot as easily
- the shared shell now treats `Connect with sing-box` as a one-tap lane on supported hosts: it auto-initializes the runtime, syncs a live app-first managed profile from the platform API, stages that profile, and then requests live connect instead of forcing manual `initialize -> stage -> connect`
- Android reconnect now always resyncs and restages the live managed profile before start, which keeps the staged runtime config aligned with the currently selected route mode instead of trusting whatever was left from an older session
- the shared shell now keeps Android connect/disconnect transitions busy until the host actually settles, which prevents repeated taps from queueing duplicate service start or stop requests while VPN permission or teardown is still underway
- when the Android host tears down immediately after a failed start, runtime snapshot state now keeps the concrete startup failure instead of replacing it with a generic stop message
- Android stop dispatch now demotes runtime state before teardown, which reduces stale `Connected` snapshots during fast reconnect loops
- Android 14+ requires the `specialUse` foreground-service contract for that lane, so the host manifest must declare both `android.permission.FOREGROUND_SERVICE` and `android.permission.FOREGROUND_SERVICE_SPECIAL_USE` alongside the runtime service subtype metadata
- the Android runtime service now uses a non-sticky lifecycle and handles `VpnService.onRevoke()`, which keeps system-side revokes and interrupted reconnect loops from pretending the mobile runtime is still connected
- the Android foreground notification now exposes a direct `Disconnect` action, so operators and testers can stop the live runtime from the system shade without reopening the shared shell
- `All except RU` now has a client-side classification lane on both Android and Windows: the shared bootstrapper caches local sing-box `.srs` files under `getApplicationSupportDirectory()/pokrov-runtime/data/rule-set/all-except-ru-rule-sets`, injects those rule-sets into staged routing before connect, and still preserves `.ru`, `.xn--p1ai`, and `.su` suffix rules as a fail-open fallback when the cache cannot refresh
- the current `All except RU` cache pulls RU-focused geosite overlays from hydraponique `roscomvpn-geosite`, whitelist CIDR overlays from hydraponique `roscomvpn-geoip`, and the upstream `SagerNet/sing-geoip` `geoip-ru` rule-set for the broad RU IP catch-all
- selected-apps parity is still explicitly out of scope for this cycle in `POKROV-app`; the current hardening wave is for `Full tunnel`, and per-app Android parity remains deferred
- `iOS` host now reaches a source-backed packet-tunnel lane: it can initialize libcore, stage a managed profile into the shared app-group runtime directory, persist a `NETunnelProviderManager`, and request tunnel start or stop against the checked-in `PacketTunnelExtension` target; the provider now boots `MobileSetup` plus `LibboxSetup`, starts a Libbox command server and service, and opens tun through `NEPacketTunnelFlow`, but this still lacks signed Apple validation on a real device
- `macOS` now copies synced `libcore.dylib` and `HiddifyCli` artifacts into the app bundle and the desktop FFI lane can discover them from the built host layout
- `Windows` now copies synced `libcore.dll` into the release bundle, applies runtime options before `libcore start`, prefers a system-proxy desktop host mode in the current seed, and `build-windows-release.ps1` verifies the bundle metadata and stages an unsigned zip plus manifest under `apps/windows_shell/build/release_bundle`
- host `build/` outputs and staged local bundles remain disposable local verification artifacts; they are not release truth for any public lane
- treat future live connect, service ownership, and traffic-carrying runtime work as one shared contract owned by the lane, not four host-local improvisations

## Apple Boundary

Running the iOS or macOS shell locally only validates that the Flutter host project boots.

It does not validate:

- Apple signing
- provisioning profiles
- Network Extension targets
- packet-tunnel provider execution on device
- notarization
- App Store or Mac App Store submission readiness
- trusted Windows signing, installer, or `MSIX` publication

The Apple placeholder inputs that now shape later operator work live in:

- `config/apple-release.seed.json`
- `config/cutover-readiness.seed.json`
- `apps/ios_shell/ios/Flutter/AppleSigning.xcconfig`
- `apps/macos_shell/macos/Runner/Configs/AppleSigning.xcconfig`

## What This Does Not Do

- no production write calls beyond the app-first session and route-policy bootstrap used by Android and Windows connect
- no bridge-client reads or writes
- no Android traffic validation on a real device or emulator
- no replacement for the required Android release-build localhost/control-surface audit on physical hardware
- no reviewed iOS entitlement validation, signed shared-app-group proof, or on-device packet-flow evidence
- no trusted signing, public installer or `MSIX` publishing, or deploy wiring
- no git-model migration for the shipping client or release lanes

That keeps the seed safe whether the next wave chooses `Karing` adaptation or a clean-room client lane.
