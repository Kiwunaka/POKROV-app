# Bootstrap Workflow

This workflow gives client workers a consistent way to validate the canonical
`POKROV-app` tree, resolve Flutter dependencies, run local tests, and
materialize local-only config. The clean-room/Wave 7 wording below is retained
only where it explains bootstrap provenance.

Historical mapping note:

- older docs may still say `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo came from `C:/Users/kiwun/Documents/ai/VPN/app-next/`
- this workflow now documents the canonical `POKROV-app` repo rather than the former in-repo bootstrap source

## Fast Path

From `POKROV-app/`:

1. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\validate-seed.ps1`.
2. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-workspace.ps1`.
   If the ignored Android Gradle wrapper BAT or JAR is missing, bootstrap first
   creates a GUID-named project under the system temp directory with Flutter's
   supported `--no-overwrite` Android flow, copies only the missing BAT/JAR,
   and removes the verified temp directory. Flutter never repairs the tracked
   Android shell in place or replaces existing Android customization.
3. Build POKROV Core from its separate repository, then run `scripts/sync-pokrov-core-runtime.ps1 -CoreRoot <path> -Platforms android,windows`. The sync helper accepts only the exact source commit, version, sizes, and hashes pinned by the client contract. Apple artifacts must be built on macOS and remain manual.
4. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\run-tests.ps1`.
   This now covers the shared Flutter lane, `apps/android_shell` Flutter tests, and `apps/android_shell/android/gradlew.bat testDebugUnitTest`.
   On a clean checkout, the bootstrap phase materializes the ignored wrapper
   BAT and JAR before `testDebugUnitTest` runs.
5. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\build-windows-release.ps1 -SyncRuntime -CoreRoot <path>` when you want the local Windows analyze, test, build, and unsigned-package lane.
6. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-local.ps1 -DryRun`.
7. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-local.ps1` only if you want local config files under `config/local/`.
8. Treat `melos.yaml` as the future workspace entry once Flutter tooling is available.

## Generated Local Files

`bootstrap-local.ps1` copies:

- `config/templates/local.env.example` -> `config/local/local.env`
- `config/templates/device-overrides.seed.json` -> `config/local/device-overrides.json`

When either required Android Gradle wrapper file is absent,
`bootstrap-workspace.ps1` also runs Flutter's conditional `--no-overwrite`
Android generation in an isolated GUID-named temp directory and copies only:

- `apps/android_shell/android/gradlew.bat`
- `apps/android_shell/android/gradle/wrapper/gradle-wrapper.jar`

The bootstrap does not copy the generated Unix wrapper, Kotlin DSL files,
IDE metadata, Flutter metadata, or any other temporary project content. It
also skips each destination that already exists and fails if the BAT or JAR is
still absent after repair.

The generated files are git-ignored and can be deleted or regenerated freely.

Treat everything under `config/local/*` and the generated Android wrapper files
as regenerated local-only workstation state. They are useful for local
prototyping and validation, but they are not release artifacts, product truth,
shipping truth, or release truth.

## Runnable Pieces

The clean-room starter now includes:

- shared domain, platform-contract, and support-context packages
- a shared Material shell that now locks the consumer-first tab set `Protection / Locations / Rules / Profile`
- Android, iOS, macOS, and Windows host entrypoints that build the shell from shared bootstrap defaults
- a widget test lane in `packages/app_shell/test/`
- Android-shell Flutter tests in `apps/android_shell/test/`
- Android Gradle unit tests in `apps/android_shell/android/app/src/test/`

## Runtime Boundary

This workflow proves that the Flutter workspace and shared shell are runnable.
The current `1.0.0-beta` public handoff is owned by
`config/release-handoff.seed.json`; regenerated workflow output cannot replace
that candidate-specific release truth.

Current blocking dependency:

- the active runtime is the clean reproducible POKROV Core `v1.0.3` release at source commit `69a74545101708e56183c92e31f2b4c7b2509884`; clients accept only the published AAR/DLL identities pinned in `config/runtime-artifacts.seed.json`
- `Android` host now reaches a real service-backed connect lane: it can initialize POKROV Core, stage a managed profile, request VPN permission, start a foreground `VpnService`, and hand tun ownership to the native runtime through the host `PlatformInterface`
- Android runtime discovery accepts either an extracted `nativeLibraryDir/libpokrov-core.so` or the ABI-matched `lib/<abi>/libpokrov-core.so` entry in the base/split APK. This is required on physical devices that install the release APK with native-library extraction disabled; Java still loads the packaged Core through the generated bindings
- Android runtime materialization is intentionally `tun`-only in this lane; desktop loopback listener inbounds such as `mixed-in` and `dns-in` stay disabled for the mobile `VpnService` path
- Android runtime materialization now keeps backend-managed `dns` servers, selector choice, and route-rule semantics whenever they are already mobile-safe, instead of swapping the whole profile into a custom universal DNS lane
- the Android bootstrap client uses the canonical `api.pokrov.space` hostname through the platform DNS/TLS transport; provider IPs are not baked into the client
- the Android route block now forces `auto_detect_interface: false`, removes `override_android_vpn`, writes `tun.exclude_package` for `space.pokrov.pokrov_android_shell`, injects a route-level self-package bypass rule, and enforces the same package exclusion through `VpnService.Builder`; this preserves the physical uplink owner while `tun.auto_route` is active and avoids routing the core back into its own TUN
- the Android host runtime retains default-network monitor hooks for DNS, uplink diagnostics, and network-change handling, while staged Android routes deliberately do not delegate outbound-interface selection to libbox auto-detection
- the Android host runtime now registers a local DNS transport backed by Android `DnsResolver` and the current default network, which keeps the mobile lane off desktop-only loopback DNS stubs when `libbox` resolves staged profile dependencies
- an active Android DNS transport callback failure or timeout is terminal and fail-closes the core, TUN, and foreground service with a safe host snapshot; ordinary DNS response codes and canceled or stale callbacks stay non-terminal
- the Android default-network monitor now sticks to the callback-owned uplink after connect instead of re-sampling `ConnectivityManager.activeNetwork`, which keeps mobile DNS from accidentally treating the VPN network as its resolver uplink
- the Android manifest must also declare `ACCESS_NETWORK_STATE` and `CHANGE_NETWORK_STATE`, otherwise the `ConnectivityManager`-backed default-interface monitor fails before runtime start
- the Android `tun` inbound now uses the `mixed` stack instead of the desktop-oriented `system` stack, and the materialized mobile runtime no longer injects the old `android-private-dns-in` loopback bridge into the staged config
- the Android fallback DNS block preserves HTTPS DoH and its path in both the proxied remote and direct bootstrap lanes; it does not downgrade `https://1.1.1.1/dns-query` to UDP/53 or inject desktop loopback DNS surfaces
- the Android DNS block also keeps resolver caches independent so direct bootstrap lookups do not poison the remote resolver lane used for blocked-service traffic
- the Android host route planner now adds IPv4 and IPv6 default routes only for address families that are actually present in the staged profile, and `ipv4_only` sessions no longer keep an unnecessary IPv6 tunnel lane for blocked-service traffic
- the Android default-network monitor now filters out VPN networks before exposing the current uplink to `DnsResolver` or libbox, and it retries interface-index lookup before publishing interface updates
- emergency profiles use the same host/runtime ABI but a separate signed
  materialization path. Only the undetoured reserve root may receive the local
  Android bootstrap resolver; detoured RU and foreign hops must resolve through
  their preceding hop, otherwise the emergency chain leaks or fails under the
  exact blocked-network condition it is intended to recover from
- the emergency materializer accepts only the three documented acyclic chains,
  exact owned-hop placement, exact DNS/ruleset shape, no WARP and no foreign
  direct bypass. A signed catalog is necessary but not sufficient: the final
  managed profile is validated again before staging on Android or Windows
- after an online trial/paid check, the client prewarms one signed bundle for
  every fresh or still-valid signed last-known-good reserve and supported
  chain, encrypts it with a device-local key, and keeps it for at most seven
  days and never beyond account, catalog, or RU/manual-eligibility expiry
- emergency catalog and profile selection are cache-first. Starting a valid
  offline copy performs no control-plane request and does not download the
  normal client rule-set catalog before TUN start; the signed emergency
  ruleset is fetched through the selected reserve-first path after Core starts
- online refresh is best-effort and deduplicated. It replaces catalog and
  profile bundle only after every expected envelope passes signature, device,
  entitlement, revision, reserve, chain, topology, DNS, and expiry checks
- Android keeps an emergency profile's signed terminal proxy as `route.final`
  instead of wrapping it in the normal mandatory selected-outbound probe. A
  blocked control-plane probe therefore cannot tear down an otherwise usable
  emergency TUN. The profile still has no direct foreign fallback: if its
  reserve cannot carry traffic, packets remain closed inside the VPN while
  online catalog verification resumes when the control plane is reachable
- the Android host runtime snapshot now carries structured health fields for the shared shell, including default uplink interface and index, DNS readiness, route counts, package-filter counts, last failure kind, and last stop reason
- the Android lane now has a real repo-local test lane: Flutter tests assert the Android shell keeps the route-mode and runtime-diagnostics affordances visible, and Gradle unit tests cover manifest guards, platform monitoring, runtime-state handling, DNS planning, and TUN route planning
- the Android diagnostics story is now support/internal rather than first-layer UI: local smoke-profile staging and raw runtime controls stay out of the consumer shell while the physical-device gate remains separate
- the Android full-tunnel guarantee in this lane is also stronger: the mobile path stays `tun`-first, desktop loopback listeners remain stripped, backend-managed mobile-safe `dns` and `route` semantics stay intact, Android route ownership flags plus the self-package bypass remain present, and only address families present in the staged profile receive default routes
- the shared shell now treats Android `running` as cleanly healthy only when post-establish uplink/bootstrap-DNS prerequisites and the core URL test for the selected outbound are healthy; the core timeout sentinel (`65535`) is failure, not positive latency, and Android `NET_CAPABILITY_VALIDATED` remains supporting evidence because emulator/network stacks can retain it after selected-outbound egress fails
- after Android reports `running`, the shared shell polls the host-owned egress result through a bounded 750 ms interval for the Core probe window; a terminal `core_egress_probe_failed` snapshot immediately replaces the protected UI with the normal disconnected/reconnect state, while a canceled or newer connect generation cannot be overwritten by an older poll
- a terminal Android selected-outbound egress failure also invalidates the staged cached runtime profile and blocks that cache from offline fallback; the next connect must obtain and stage a fresh authorized manifest, while ordinary offline fallback remains bounded before any dataplane failure
- the Android host performs that selected-outbound fail-close as one synchronous profile-reuse invalidation: it clears the persisted Quick Settings profile and drops the staged pointer while preserving the safe failure snapshot, so a backgrounded Flutter shell cannot let the tile restart the rejected configuration
- Android Quick Settings may reuse only a freshly staged managed profile carrying Flutter's completed first-connect route-scope confirmation; legacy path-only or unconfirmed persisted records fail closed into the app
- Android service stop/start commands carry a monotonic ownership generation;
  a completed stop may release foreground state or call `stopSelf()` only when
  no newer start owns the service, so changing an emergency reserve cannot be
  torn down by the previous connection's delayed cleanup
- the Android Quick Settings tile uses Android active-tile mode, reconciles both the live TUN and the app-owned VPN-service presence before choosing start or stop, publishes only the resulting on/off state, and explicitly requests a new SystemUI listen after committed runtime transitions; the notification remains the owner of country, route and speed details
- the shared shell now refreshes Android runtime truth again on foreground resume, and keeps polling a host-owned pending-connect signal through Android notification/VPN consent even when no lifecycle resume reaches Flutter; the host bridge reconciles a live TUN back to `running` so a relaunch does not leave the button lane stuck on a stale staged snapshot as easily
- the shared shell now treats `Connect with sing-box` as a one-tap lane on supported hosts: it auto-initializes the runtime, syncs a live app-first managed profile from the platform API, stages that profile, and then requests live connect instead of forcing manual `initialize -> stage -> connect`
- Smart Connect promotes the selected direct outbound inside that authorized profile by canonical `outbound_tag` (with bounded compatibility mapping for older manifests); a second exact managed-profile fetch is a six-second fallback only when local identity cannot be proven, not part of the normal connect path
- an explicit manual location variant is materialized from the exact managed
  profile only: `direct` requires the verified canonical base outbound to be a
  member of the final selector, while a bridge id requires one unique safe
  `_meta.ru_bridge.endpoints` id/label mapping and its exact selector member.
  The client never derives a bridge target from a host, key, detour, or fuzzy
  label and fails closed when any proof is missing
- device-local catalog cache and latency refresh preserve the safe variant
  projection; the selected variant id persists beside the manual node code.
  Automatic Smart Connect remains direct-selection-compatible and does not
  inherit that manual preference
- WARP with a manual bridge/`Белые списки` variant is gated before staging
  until focused composition proof exists. There is no implicit fallback to
  direct or to WARP-off for this user-selected combination
- production `variants` are additive safe labels projected by
  `/api/client/locations`: `direct` is rendered as `Обычный`, while each
  currently available relay is rendered as a `Белые списки` choice without
  host, port, key, tag, or raw config. Device cache keeps the last non-empty
  safe catalog across transient refresh failure; removed rollout ids are
  cleared or explained instead of pretending a stale selection still applies
- materialization creates one private `pokrov-variant-probe` URL-test group
  containing the canonical selected outbound plus every exact, uniquely
  resolvable white-list variant. `_meta.runtime_variant_probe` owns the
  safe-ID-to-tag mapping inside the staged profile only. The Android host reads
  only the canonical managed-profile path, validates that mapping against the
  group, runs full or one-row refresh, and returns safe ID/status/latency/time/
  active ID. Raw tags and transport material never cross MethodChannel; missing
  or ambiguous mappings fail closed and render unavailable
- if the selected outbound fails its core-owned egress proof, the Android TUN
  remains fail-closed while one bounded full variant URL-test completes before
  teardown. Only the exact-catalog safe status/latency snapshot is retained in
  process memory for up to two minutes; it cannot reactivate a route, survives
  neither process death nor a different catalog, and reports no active variant
  after the runtime has stopped
- the `2026-08-14` production redacted readback proved `direct` plus `mini`,
  `ru`, and `ru_spb` for eligible non-US nodes and direct-only for `us`.
  Exact public-app visibility, selection, reconnect, and materialized runtime
  proof remain `MANUAL_OWNER_TEST` until the owner's phone is ADB-visible
- a confirmed selected-outbound egress failure in automatic mode quarantines the exact node for 15 minutes with an eight-node cap and at most two failover attempts; manual mode and unavailable probe evidence remain fail-closed without silent route changes
- Android reconnect now always resyncs and restages the live managed profile before start, which keeps the staged runtime config aligned with the currently selected route mode instead of trusting whatever was left from an older session
- the shared shell now keeps Android connect/disconnect transitions busy until the host actually settles, which prevents repeated taps from queueing duplicate service start or stop requests while VPN permission or teardown is still underway
- when the Android host tears down immediately after a failed start, runtime snapshot state now keeps the concrete startup failure instead of replacing it with a generic stop message
- Android stop dispatch now demotes runtime state before teardown, which reduces stale `Connected` snapshots during fast reconnect loops
- Android 14+ requires the `specialUse` foreground-service contract for that lane, so the host manifest must declare both `android.permission.FOREGROUND_SERVICE` and `android.permission.FOREGROUND_SERVICE_SPECIAL_USE` alongside the runtime service subtype metadata
- the Android runtime service now uses a non-sticky lifecycle and handles `VpnService.onRevoke()`, which keeps system-side revokes and interrupted reconnect loops from pretending the mobile runtime is still connected
- the Android foreground notification now exposes a direct `Disconnect` action, so operators and testers can stop the live runtime from the system shade without reopening the shared shell
- `All except RU` now has a client-side classification lane on both Android and Windows: the shared bootstrapper caches local sing-box `.srs` files under `getApplicationSupportDirectory()/pokrov-runtime/data/rule-set/all-except-ru-rule-sets`, injects those rule-sets into staged routing before connect, and still preserves `.ru`, `.xn--p1ai`, and `.su` suffix rules as a fail-open fallback when the cache cannot refresh
- the current `All except RU` cache pulls RU-focused geosite overlays from hydraponique `roscomvpn-geosite`, whitelist CIDR overlays from hydraponique `roscomvpn-geoip`, and the upstream `SagerNet/sing-geoip` `geoip-ru` rule-set for the broad RU IP catch-all
- selected-apps picker, route-policy sync, persistence, and runtime
  materialization are beta-active for Android and Windows; public production
  behavior remains gated on exact-artifact physical-device and clean-VM proof
- `iOS` source carries the POKROV Core packet-tunnel bridge: it stages one materialized profile in the shared app-group directory, persists a `NETunnelProviderManager`, boots `LibboxSetup`, starts or reloads `CommandServer`, and opens tun through `NEPacketTunnelFlow`; the framework build, signing, and device validation remain manual
- `macOS` stays on the desktop ABI 2 lane and expects only `pokrov-core.dylib`; the universal dylib must be built and probed on macOS before that host is runnable
- `Windows` copies the exact POKROV Core 1.0.3 `pokrov-core.dll` plus pinned `libcronet.dll` into the release bundle. Raw materialized config, WARP, `Full tunnel`, `All except RU`, and selected-process routing are owned by the shared adapter. The default remains `VPN/TUN + system`; the advanced compatibility lane can instead remove the TUN and let the loopback mixed inbound set and restore the Windows system proxy. Advanced TUN stacks are `system`, `mixed` (system TCP plus gVisor UDP), and `gvisor`
- before securing the desktop config, the Windows runtime verifies every loopback-only helper port for both TCP and UDP. A collision with Hiddify or another local proxy is remapped to an OS-selected free loopback port; external listeners and profile routing are not changed
- generated Windows VPN profiles follow the proven POKROV Core/Hiddify system-TUN shape: `address`, `stack: system` by default, `strict_route`, a first-match `port: 53 -> hijack-dns` rule before LAN/direct or user routing, route-level `sniff`, typed TCP/UDP DNS servers, and no legacy `dns-out` or TUN-level sniff/NAT fields. The final preference pass reasserts that protected rule prefix after every other transform. The explicit port match is required by the shipped Core generation because Windows sends resolver packets to a private LAN DNS address before protocol sniffing has classified them. `Full tunnel` removes inherited Internet bypass rules while retaining local/private LAN access; selected and excluded process modes use opposite route and DNS decisions as their labels promise
- Windows VPN verification is two-stage. The loopback mixed-port request proves that Core and the selected outbound work; a second forced-direct request from the normal Windows socket path proves TUN capture and DNS against the owned HTTPS marker `https://api.pokrov.space/api/public/authenticated-egress-probe`. Windows gets three bounded attempts while routes settle. The UI may enter `running` only after the exact `204` and `X-Pokrov-Egress-Probe: pokrov-authenticated-egress-v1` marker succeed. A failed system-path probe stops Core and reports `desktop_tun_egress_probe_failed` instead of showing a false protected state. In explicit system-proxy mode, successful Core start plus the mixed-port egress probe proves the selected compatibility lane; the TUN-only probe is not run because that profile deliberately has no TUN
- the desktop runtime also keeps a bounded safe event journal at `%APPDATA%/space.pokrov/POKROV/pokrov-runtime/working/pokrov-runtime-events.jsonl`. It records UTC time, platform, lifecycle/probe stage, attempt, outcome, and allowlisted failure kind only; it never records profile contents, endpoints, visited domains, IP addresses, credentials, or raw provider/Core errors. Journal failure cannot block a connection, and files over 128 KiB are reduced to the latest 300 events
- a failed Windows connect keeps its sanitized failure kind and message across subsequent runtime snapshots until an explicit restage or successful retry clears it; polling must not replace a failed `configStaged` state with the success copy `Профиль доступа готов`
- `scripts/test-windows-core-proxy-only.ps1` is the host-safe developer lane while another VPN owns Windows routes: it runs the exact bundled DLL through 100 loopback mixed-proxy start/stop cycles and never creates a TUN. A pass proves Core loading, ABI lifecycle, local proxy traffic and teardown only; Windows TUN, DNS capture and leak proof still require an isolated VM or Windows Sandbox
- source-level runtime tests cover the Windows TUN options for all three route modes; exact-candidate clean-VM routing, DNS/leak, elevation, connect, and teardown proof remains `MANUAL_OWNER_TEST`
- the regular Windows shell stays unelevated; a TUN connect first checks the process token. If elevation is required, the shared shell explains the full-device VPN/admin boundary before invoking `runas` and offers an explicit no-admin system-proxy fallback. Choosing that fallback persists the compatibility mode before profile staging; cancelling or failing `runas` cannot start Core or be presented as working TUN protection, while the accepted path relaunches the exact executable with the bounded `--connect` continuation
- `build-windows-release.ps1` verifies the Windows bundle metadata and uses Inno Setup 6 to stage a per-user unsigned setup EXE with install-directory, optional desktop-shortcut, and optional autostart choices, plus a portable ZIP and manifest under `apps/windows_shell/build/release_bundle`
- host `build/` outputs and staged local bundles remain disposable local verification artifacts; they are not release truth for any public lane
- treat future live connect, service ownership, and traffic-carrying runtime work as one shared contract owned by the lane, not four host-local improvisations

## POKROV Core 1.0.3

POKROV Core is an independent repository and release line. The client pins
`v1.0.3` and commit `69a74545101708e56183c92e31f2b4c7b2509884`.

- Android package namespace: `space.pokrov.core`.
- Android artifact: `pokrov-core.aar`.
- Windows artifact: `pokrov-core.dll` with pinned `libcronet.dll`.
- Apple artifacts are intentionally absent until built and proven on macOS.
- Desktop ABI `2` exposes `pokrovCoreAbiVersion`, `pokrovSecureFile`,
  caller-owned strings through `freeString`, and raw materialized-config start.
- Shared Dart materialization owns route modes and client-local WARP before the
  config crosses a host boundary.
- `selectedApps` materialization requires a non-empty selection before any
  route-policy sync or profile fetch. Android receives the staged route-mode
  attestation separately and rejects an empty selected-app allow-list instead
  of interpreting it as a device-wide tunnel.
- Android `excludedApps` also requires a non-empty selection. Materialization
  keeps the app itself and every selected package outside `VpnService`, then
  routes all remaining packages through the managed profile; the server still
  receives the device-wide route-policy contract.
- There is no mutable latest-release download and no hidden legacy fallback.

Exact artifacts and platform gates are owned by
`config/runtime-artifacts.seed.json` and
`docs/decisions/2026-07-23-pokrov-core-1.0.0-activation.md`.

## Update Handoff Boundary

The shared shell may present and open an update only when the metadata carries a
positive bounded byte size, a 64-hex SHA-256, and the exact canonical target
`https://github.com/Kiwunaka/pokrov/releases/download/<tag>/<asset>.apk`.
Alternate initial hosts or repositories, URL authority fields, explicit ports,
query strings, fragments, and non-APK assets fail closed, and the same
validation runs again at tap time.

On Android the native host downloads into app-private cache, follows at most
five HTTPS redirects to GitHub-owned asset hosts, verifies exact byte size and
SHA-256, and shares only the verified file through a non-exported
`FileProvider`. During the transfer it exposes only phase and byte counters to
the Flutter sheet so the user sees determinate download progress followed by
verification and installer handoff. It then opens Android's system package
installer; Android 8+ may require the user to grant install-source permission
first. The app never silently installs an APK. Windows retains the trusted
browser handoff. Signing, install, runtime, and exact-candidate proof remain
separate release gates.

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
- no trusted signing, trusted public installer or `MSIX` publishing, or deploy wiring
- no git-model migration for the shipping client or release lanes

That keeps local bootstrap work separate from public release authority. The
active client lane remains `POKROV-app/main`; historical Karing and clean-room
inputs cannot reopen it without a new owner decision.
