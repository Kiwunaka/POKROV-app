# Bootstrap Workflow

This workflow gives client workers a consistent way to validate the canonical
`POKROV-app` tree, resolve Flutter dependencies, run local tests, and
materialize local-only config. The clean-room/Wave 7 wording below is retained
only where it explains bootstrap provenance.

Ordinary Android and Windows connect/reconnect refresh the authorized managed
profile before staging, even when a reusable staged path exists. Server-side
assignment changes therefore do not depend on the repair action or a local
settings change. Transient refresh failures may reuse only the existing fresh,
authorized cache permitted by `CachedProfileFallbackGate`; the UI identifies
that fallback and does not claim the new assignment was applied. The owner's
2026-09-07 decision permits a manual retry after dataplane failure using the
last downloaded or last proven profile within its original offline window.
An explicit authorization denial is separate from an unreachable API.

After an explicit disconnect settles to a non-running snapshot without a
failure, Home returns to its ordinary Connect action. The runtime's successful
status message is not a recovery notice. A reported failure keeps its message.

Historical mapping note:

- older docs may still say `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo came from `C:/Users/kiwun/Documents/ai/VPN/app-next/`
- this workflow now documents the canonical `POKROV-app` repo rather than the former in-repo bootstrap source

## Fast Path

From `POKROV-app/`:

1. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\validate-seed.ps1`.
2. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-workspace.ps1`.
   If an ignored Android Gradle wrapper script or JAR is missing, bootstrap first
   creates a GUID-named project under the system temp directory with Flutter's
   supported `--no-overwrite` Android flow, copies only the missing
   Unix/BAT/JAR wrapper files,
   and removes the verified temp directory. Flutter never repairs the tracked
   Android shell in place or replaces existing Android customization.
3. Build POKROV Core from its separate repository, then run `scripts/sync-pokrov-core-runtime.ps1 -CoreRoot <path> -Platforms android,windows`. The sync helper accepts only the exact source commit, version, sizes, and hashes pinned by the client contract. Apple artifacts must be built on macOS and remain manual.
4. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\run-tests.ps1`.
   This now analyzes testless foundation packages, tests every test-bearing
   package/app across all 11 Flutter modules, and runs both Android
   flavor tasks through `apps/android_shell/android/gradlew.bat` on Windows or
   `apps/android_shell/android/gradlew` on Linux:
   `:app:testDirectDebugUnitTest` / `:app:testStoreDebugUnitTest` tasks.
   On a clean checkout, the bootstrap phase materializes the ignored wrapper
   scripts and JAR before the flavor-specific unit-test tasks run.
5. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\build-windows-release.ps1 -SyncRuntime -CoreRoot <path>` when you want the local Windows analyze, test, build, and unsigned-package lane.
6. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-local.ps1 -DryRun`.
7. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-local.ps1` only if you want local config files under `config/local/`.
8. Treat `melos.yaml` as the future workspace entry once Flutter tooling is available.

## Generated Local Files

`bootstrap-local.ps1` copies:

- `config/templates/local.env.example` -> `config/local/local.env`
- `config/templates/device-overrides.seed.json` -> `config/local/device-overrides.json`

When any required Android Gradle wrapper file is absent,
`bootstrap-workspace.ps1` also runs Flutter's conditional `--no-overwrite`
Android generation in an isolated GUID-named temp directory and copies only:

- `apps/android_shell/android/gradlew`
- `apps/android_shell/android/gradlew.bat`
- `apps/android_shell/android/gradle/wrapper/gradle-wrapper.jar`

The bootstrap does not copy Kotlin DSL files, IDE metadata, Flutter metadata,
or any other temporary project content. It skips each destination that already
exists, marks the Unix wrapper executable on non-Windows hosts, and fails if a
required wrapper file is still absent after repair.

The generated files are git-ignored and can be deleted or regenerated freely.

Treat everything under `config/local/*` and the generated Android wrapper files
as regenerated local-only workstation state. They are useful for local
prototyping and validation, but they are not release artifacts, product truth,
shipping truth, or release truth.

## Runnable Pieces

The clean-room starter now includes:

- shared domain, platform-contract, observability, typed diagnostic collector,
  encryption-only support-bundle, and support-context packages
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

- the active local pre-candidate runtime has exact single-source platform bindings: Android and Windows use security-fixed Core commit `6b271decead88b708e2fc03984b703b0a4e63ebd`, retaining the egress, AWG, Android outer-socket and default-off provenance-bound `pokrov.hy2.outbound.v1` lanes while correcting AWG allocated-port binding, `GO-2026-6303`, AWG endpoint use of the configured default bootstrap resolver and legacy raw-settings/error logging; raw Hysteria2 URI conversion stays disabled, AWG2/AWG 3.1 lifecycle proof is retained, and two local builds per platform produced byte-identical AAR/DLL trees
- the C05 binding uses Go 1.26.8, x/crypto 0.56.0 and tfo-go 2.3.3 to fix two reachable SSH deadlock advisories. Its Psiphon TLS ConnectionState mirror follows the pinned Go layout with a guarded live handshake/conversion test. [C05 two-build evidence](../operations/evidence/2026-09-06-r12-c05-core-binding/android-evidence.json) and [previous D05 binding](../operations/evidence/2026-09-06-r12-c05-core-binding/previous-runtime-binding.json) retain exact identities; this does not transfer candidate, device, SCM/TUN or WARP proof
- Core lifecycle errors crossing logs, status and platform ABI expose catalog codes while preserving their typed cause internally; the retained Core c8 privacy binding passed direct FFI planted-data checks; the current C02 binding preserves that source policy and records separate lifecycle/resource evidence
- managed engine log filtering runs before observable writers, subscriptions and replay buffers in normal and debug mode. Arbitrary messages and tags become `runtime_log_redacted`; only fixed AWG categories survive. The retained [D05 binding evidence](../operations/evidence/2026-09-06-r12-d05-core-binding/android-evidence.json) and [previous binding](../operations/evidence/2026-09-06-r12-d05-core-binding/previous-runtime-binding.json) preserve source and rollback identities
- device-bound `awg2_lab`, `awg31_lab` and `hy2_lab` envelopes do not participate in ordinary Smart Connect selection or automatic-node quarantine. Their typed endpoint is already the complete route decision. The bootstrapper clears `smartConnect` for those profiles and skips selection when no Smart Connect profile is present, so an unrelated VLESS egress failure cannot block a fresh lab fetch before Core starts
- Those lab envelopes may advertise ordinary `legacy_reality_fallback` in
  `fallback_order`. Only then does the client retain their exact source revision
  as a TCP fallback candidate. A confirmed `core_egress_probe_failed` can make
  one fallback request through `GET /api/client/profile/managed` with
  `fallback_from_revision`; unavailable proof and arbitrary runtime errors do
  not trigger it. The server revalidates the current device/lab revision and
  ordinary TCP provisioning. The response must identify the expected REALITY
  transport and `<source-revision>:fallback:legacy_reality_fallback`; ignored
  parameters, stale revision or an unrelated response fail before staging.
  Promote the platform API support before enabling this client recovery path;
  an older server that ignores the query cannot supply an accepted fallback.
  The same route mode, selected/excluded apps and local routing preferences are
  materialized again. Existing WARP consent/fallback policy remains its own
  boundary. The rejected lab cache cannot be used for this retry. Both the lab
  transition and subsequent automatic node retries share the existing two-retry
  budget and generation fence. A manual Home action or location change cancels
  the pending transport choice; there is no persisted cohort mutation. Native
  stage/proof checks still decide whether the new connection is protected.

- `Android` host now reaches a real service-backed connect lane: it can initialize POKROV Core, stage a managed profile, request VPN permission, start a foreground `VpnService`, and hand tun ownership to the native runtime through the host `PlatformInterface`
- Android runtime discovery accepts either an extracted `nativeLibraryDir/libpokrov-core.so` or the ABI-matched `lib/<abi>/libpokrov-core.so` entry in the base/split APK. This is required on physical devices that install the release APK with native-library extraction disabled; Java still loads the packaged Core through the generated bindings
- Android runtime materialization is intentionally `tun`-only in this lane; desktop loopback listener inbounds such as `mixed-in` and `dns-in` stay disabled for the mobile `VpnService` path
- Android runtime materialization now keeps backend-managed `dns` servers, selector choice, and route-rule semantics whenever they are already mobile-safe, instead of swapping the whole profile into a custom universal DNS lane
- the Android bootstrap client uses the owned `app.pokrov.space/api/*` ingress
  as its primary control-plane origin and retains `api.pokrov.space` as the
  bounded owned fallback; provider IPs are not baked into the client
- when both owned origins are configured, the client first requires a 2xx JSON
  response from `/api/health`, caches the selected origin for the process, and
  only then sends the real request. The preflight carries no session or request
  body. A non-idempotent request is sent once and is never replayed to the
  second origin after a transport failure
- the Android route block keeps `auto_detect_interface: false`, removes `override_android_vpn`, writes `tun.exclude_package` for `space.pokrov.pokrov_android_shell`, injects a route-level self-package bypass rule, and enforces the same package exclusion through `VpnService.Builder`; the Core AWG endpoint is the bounded exception and requests platform protection directly for its owned UDP socket without changing the global route policy
- the Android host runtime retains default-network monitor hooks for DNS, uplink diagnostics, and network-change handling; ordinary staged routes do not delegate outbound-interface selection to libbox auto-detection, while a Core-requested AWG socket protection fails closed when Android rejects `protect(fd)`
- the Android host runtime now registers a local DNS transport backed by Android `DnsResolver` and the current default network, which keeps the mobile lane off desktop-only loopback DNS stubs when `libbox` resolves staged profile dependencies
- the Core-owned AWG endpoint resolves its inner FQDN with the route's explicit `default_domain_resolver` options, so Android uses that registered default-network transport instead of an empty resolver query; TLS verification still uses the authenticated hostname and any resolver or probe failure remains fail-closed
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
- for closed AWG endpoint probes only, Android also subscribes to the Core log
  stream long enough to accept the exact bounded
  `selected endpoint URL test failed category=<closed-category>` contract. The
  host discards the initial backlog and every arbitrary line, admits only the
  fixed Core category allowlist into the existing safe protocol-diagnostic
  fields, and retains no raw log text. Once captured, the terminal egress
  category takes precedence over later transport-retry categories until the
  next connection attempt. It never overrides the result of the specific
  endpoint probe call or weakens `EGRESS-001` fail-close
- Android endpoint verification calls the additive Core `CommandServer.ProbeEndpoint`
  method on the server captured for the active lifecycle task. A delayed result
  for another invocation cannot satisfy this call, and the existing session and
  generation fences still guard its application. Shared ABI1 operational events
  remain diagnostic breadcrumbs. A missing method or unknown invocation failure returns
  `UNAVAILABLE`, never healthy. Selector/urltest groups use the per-call
  `ProbeSelectedOutbound` method, which captures the selected proxy leaf and
  rejects a changed selection, runtime replacement, timeout, direct leaf or
  cyclic group. Shared URL-test history cannot settle protection health.
  Both methods are present in the exact replacement AAR recorded by the active
  Core binding decision. Packaged and device proof remain separate gates
- after Android reports `running`, the shared shell polls the host-owned egress result through a bounded 750 ms interval for the Core probe window; a terminal `core_egress_probe_failed` snapshot immediately replaces the protected UI with the normal disconnected/reconnect state, while a canceled or newer connect generation cannot be overwritten by an older poll
- a terminal Android selected-outbound egress failure stops false protection but preserves the bounded downloaded/proven profile cache. A manual retry refreshes opportunistically and may restore the last proven profile if the API is unavailable. Automatic transport/node failover still requires a freshly selected profile and cannot loop through the same cached failed endpoint.
- the Android host performs that selected-outbound fail-close as one synchronous profile-reuse invalidation: it clears the persisted Quick Settings profile and drops the staged pointer while preserving the safe failure snapshot, so a backgrounded Flutter shell cannot let the tile restart the rejected configuration
- Android Quick Settings may reuse only a freshly staged managed profile carrying Flutter's completed first-connect route-scope confirmation; legacy path-only or unconfirmed persisted records fail closed into the app
- Android service stop/start commands carry a monotonic ownership generation;
  a completed stop may release foreground state or call `stopSelf()` only when
  no newer start owns the service, so changing an emergency reserve cannot be
  torn down by the previous connection's delayed cleanup
- the Android Quick Settings tile uses Android active-tile mode, reconciles both the live TUN and the app-owned VPN-service presence before choosing start or stop, publishes only the resulting on/off state, and explicitly requests a new SystemUI listen after committed runtime transitions; the notification remains the owner of country, route and speed details
- the shared shell now refreshes Android runtime truth again on foreground resume, and keeps polling a host-owned pending-connect signal through Android notification/VPN consent even when no lifecycle resume reaches Flutter; the host bridge reconciles a live TUN back to `running` and demotes a stale `running` snapshot when the app-owned TUN is absent, so a relaunch or interrupted service cannot leave the button lane falsely connected
- the shared shell now treats `Connect with sing-box` as a one-tap lane on supported hosts: it auto-initializes the runtime, syncs a live app-first managed profile from the platform API, stages that profile, and then requests live connect instead of forcing manual `initialize -> stage -> connect`
- Smart Connect promotes the selected direct outbound inside that authorized profile by canonical `outbound_tag` (with bounded compatibility mapping for older manifests); a second exact managed-profile fetch is a six-second fallback only when local identity cannot be proven, not part of the normal connect path
- Smart Connect probe concurrency (default three) counts unresolved probes across
  profile resolutions on the same bootstrapper. A wrapper timeout ends the wait
  but keeps the slot occupied until the original probe settles; an exhausted
  pool skips further advisory probes. The default socket probe retains its own
  timeout. A late result releases capacity without becoming a new RTT sample
- Android and Windows VPN selector/urltest chains exclude the direct outbound in
  every routing mode, including server-materialized Windows profiles. Nested
  chains retain only paths to managed transport outbounds or AWG endpoints;
  their default cannot select direct. Explicit direct route/DNS rules, LAN
  preferences and platform per-app exclusions remain separate route decisions
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
  safe catalog across transient refresh failure. After a successful refresh,
  a removed or disabled relay id on the still-selected city is reset to its
  available `direct` variant, persisted, and applied through the normal
  reconnect path instead of pretending a stale selection still applies
- materialization creates one private `pokrov-variant-probe` URL-test group
  against the POKROV-owned authenticated-egress marker, containing the
  canonical selected outbound plus every exact, uniquely resolvable white-list
  variant. `_meta.runtime_variant_probe` owns the
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
- a confirmed selected-outbound egress failure in automatic mode quarantines the exact node for 15 minutes with an eight-node cap and at most two failover attempts; manual mode and unavailable probe evidence remain fail-closed without silent route changes; retry delays use 250/500 ms backoff plus 0–250 ms jitter, and the existing owner-generation check cancels stale retries
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
- `Windows` copies `pokrov_service.exe`, the exact POKROV Core 1.1.0
  `pokrov-core.dll` and pinned `libcronet.dll` into the machine-wide release
  bundle. Raw materialized config, WARP, `Full tunnel`, `All except RU` and
  selected-process routing are owned by the shared adapter, then passed as
  bounded bytes to the authenticated service. The supported connection lane
  is `VPN/TUN`; advanced TUN stacks remain `system`, `mixed` (system TCP plus
  gVisor UDP) and `gvisor`. Legacy persisted `systemProxy` state migrates to
  this lane
- before securing the desktop config, the Windows runtime verifies every loopback-only helper port for both TCP and UDP. A collision with Hiddify or another local proxy is remapped to an OS-selected free loopback port; external listeners and profile routing are not changed
- generated Windows VPN profiles follow the proven POKROV Core/Hiddify system-TUN shape: `address`, `stack: system` by default, `strict_route`, a first-match `port: 53 -> hijack-dns` rule before LAN/direct or user routing, route-level `sniff`, typed TCP/UDP DNS servers, and no legacy `dns-out` or TUN-level sniff/NAT fields. The final preference pass reasserts that protected rule prefix after every other transform. The explicit port match is required by the shipped Core generation because Windows sends resolver packets to a private LAN DNS address before protocol sniffing has classified them. `Full tunnel` removes inherited Internet bypass rules while retaining local/private LAN access; selected and excluded process modes use opposite route and DNS decisions as their labels promise
- server-materialized Windows profiles also apply the current routing mode and
  process selection: stale process routes and DNS server choices are replaced,
  Full tunnel removes inherited Internet bypasses, and All except RU applies
  the local RU catalog. Profiles without a safe VPN path are rejected before
  staging. A missing direct outbound is added for explicit direct decisions.
  Existing inbounds and unrelated profile options remain; configured DNS
  server protocol, address, TLS and transport options are retained in the
  direct/VPN resolver lanes. With no configured network resolver, defaults
  remain TCP/UDP `1.1.1.1`. Direct resolver copies use local bootstrap instead
  of a self-reference to a generated resolver lane. DNS non-routing actions
  are preserved; user routing preferences apply afterward
- Windows VPN verification is service-owned. After Core starts, WinHTTP uses
  proxy bypass to request the owned HTTPS marker at
  `https://api.pokrov.space/api/public/authenticated-egress-probe`. Windows gets
  three bounded attempts while TUN routes settle. The service may enter
  `running` only after exact HTTP `204` and
  `X-Pokrov-Egress-Probe: pokrov-authenticated-egress-v1`. Failure stops Core,
  returns to `config_staged` and reports `core_egress_probe_failed`; raw DNS,
  provider or WinHTTP details never cross IPC
- the desktop runtime also keeps a bounded safe event journal at `%APPDATA%/space.pokrov/POKROV/pokrov-runtime/working/pokrov-runtime-events.jsonl`. It records UTC time, platform, a closed typed lifecycle event (`initialization`, `profile`, `core_start`, `tun`, `routes`, `dns`, `egress`, `recovery`, `stop`), bounded probe/stop reason, attempt, outcome, and allowlisted failure kind only; it never records profile contents, endpoints, visited domains, IP addresses, credentials, or raw provider/Core errors. Journal failure cannot block a connection, and files over 128 KiB are reduced to the latest 300 events
- The Android production and Windows release builders pass the committed Git
  revision and the pubspec build number into the operational build identity.
  They reject tracked source changes before compiling so a packaged journal
  cannot silently report zero values or attribute dirty source to `HEAD`.
  Local/candidate/channel labels keep their separate release authority.
- Android and Windows now start the shared operational-observability pipeline
  before `runApp`. Bootstrap start/finish/UI-ready, the exact
  `ConnectionExperienceReducer` phase, profile/Core/TUN/routes/DNS/egress
  proof, verified, rollback, stopped, update handoff, previous exit and crash
  marker are closed typed events. A successful attempt cannot be emitted until
  the reducer has current interface, routes/uplink, DNS and selected-outbound
  egress proof.
- Bootstrap and connection timeline events take their next sequence from the
  shared app dispatcher, including after restored Android routing counts or
  interleaved auth and entitlement refresh events. An early routing restoration
  cannot suppress the subsequent UI-ready event.
  Refresh cannot suppress a subsequent connection failure or terminal event as
  a duplicate sequence. The attempt generation stays fixed, so callbacks from
  an older attempt remain rejected.
- Every portal JSON request sends one canonical UUIDv4 `X-Correlation-ID`.
  A connection attempt keeps its attempt UUID in a zone-scoped request context,
  so managed-profile calls and the server request ID can be reconciled without
  account, install, device, destination or package identity. Requests outside
  an attempt receive a fresh UUIDv4.
- The app-private operational store remains authoritative only for diagnostics.
  Its initialization runs in the existing asynchronous writer, so a filesystem
  failure cannot stop bootstrap or a connection action. The bounded in-memory
  timeline remains available, writer failures increment `writerErrors`, and a
  later batch retries the same storage path without relocating diagnostic data.
  Its two-segment cap is 24 MiB on Android and 64 MiB on Windows. A separate
  best-effort mirror sends only the identity-free release-health projection
  after an app session already exists; observability never creates a trial or
  session. Correlation, attributes, destinations and identity are removed from
  the batch body. Portal failure cannot block local persistence or runtime.
- `previous-exit.v1.json` contains only closed run state, catalog crash code,
  fixed safe crash signature and the bounded breadcrumb ring. Crash handlers
  flush that marker synchronously because the process may terminate next.
  Clean exit overwrites it; an active marker on the next launch is reported as
  unclean. The marker is diagnostic evidence and can never restore or declare
  runtime state; host/service snapshot and recovery journal remain authority.
  Marker filesystem write failures are counted in `writeErrors` without escaping
  into bootstrap, normal exit or the crash handler; privacy validation still
  rejects unsafe values before an IO attempt.
- a failed Windows connect keeps its sanitized failure kind and message across subsequent runtime snapshots until an explicit restage or successful retry clears it; polling must not replace a failed `configStaged` state with the success copy `Профиль доступа готов`
- `scripts/test-windows-core-proxy-only.ps1` is the host-safe developer lane while another VPN owns Windows routes: it runs the exact bundled DLL through 100 loopback mixed-proxy start/stop cycles and never creates a TUN. A pass proves Core loading, ABI lifecycle, local proxy traffic and teardown only; Windows TUN, DNS capture and leak proof still require an isolated VM or Windows Sandbox
- source-level runtime tests cover the Windows TUN options for all three route
  modes; exact-candidate clean-VM SCM installation, routing, DNS/leak, connect,
  recovery and teardown proof remains `MANUAL_OWNER_TEST`
- the regular Windows shell stays unelevated and authenticates the service
  before connection. There is no process-token check, `runas`, `--connect` or
  per-user system-proxy fallback. Service absence, identity failure or protocol
  incompatibility blocks the action with bounded recovery copy
- `build-windows-release.ps1` verifies the Windows bundle metadata and uses
  Inno Setup 6 to stage an unsigned machine-wide setup EXE. Installer source
  captures the original owner SID, writes protected service configuration,
  creates/updates/starts the fixed SCM service and removes it on uninstall.
  Portable ZIP output is unsupported for this architecture. Per-user startup
  and `pokrov://` registration are owned by the ordinary UI
- host `build/` outputs and staged local bundles remain disposable local verification artifacts; they are not release truth for any public lane
- treat future live connect, service ownership, and traffic-carrying runtime work as one shared contract owned by the lane, not four host-local improvisations

## POKROV Core 1.1.0 Pre-Candidate Binding

POKROV Core is an independent repository and release line. The local client
pre-candidate pins version `1.1.0` and one Android/Windows source commit,
`cd8f0f4169d570d693992a959d81d17c2c44884d`. The version-derived `v1.1.0`
label is not a created Git tag or public release in this state. Local source
convergence is proved; candidate, signing and platform-runtime gates remain.

- Android package namespace: `space.pokrov.core`.
- Android artifact: `pokrov-core.aar`.
- Windows artifact: `pokrov-core.dll` with pinned `libcronet.dll`.
- Apple artifacts are intentionally absent until built and proven on macOS.
- Desktop ABI `2` exposes `pokrovCoreAbiVersion`, `pokrovSecureFile`,
  caller-owned strings through `freeString`, and raw materialized-config start.
  New builds add the optional `pokrovCoreCapabilities` descriptor; released
  marker-only ABI 2 remains compatible, while any present descriptor is
  validated fail-closed before setup.
- Shared Dart materialization owns route modes and client-local WARP before the
  config crosses a host boundary.
- Shared Dart materialization also owns the additive `dnsTransport` client
  preference. Missing or unknown state resolves to `vpn`. For a selected DoH
  preset, the opt-in `direct` value changes only the injected HTTPS resolver
  detour to the profile's existing direct outbound; purpose routes such as AI
  and Games continue through the active VPN/AWG target. `Automatic` injects
  nothing, so the backend-managed DNS block remains authoritative. This is not
  a second DNS owner or a standalone VPN-less resolver service.
- The additive `externalSmartDnsEnabled` laboratory preference is stricter. It
  can materialize only with a validated custom HTTPS DoH address, the direct
  DNS detour and at least one AI/Games purpose route. The resolver and those
  selected purpose-domain connections then use the existing direct outbound;
  other groups keep the VPN/AWG target and explicit user rules retain higher
  priority. Invalid combinations fail closed before native staging. This is a
  client route-policy path for a compatible Smart-DNS resolver, not such a
  resolver, not a second core and not evidence of VPN-free service access.
- `selectedApps` materialization requires a non-empty selection before any
  route-policy sync or profile fetch. Android receives the staged route-mode
  attestation separately and rejects an empty selected-app allow-list instead
  of interpreting it as a device-wide tunnel.
- Windows selected/excluded modes additionally require a non-empty set after
  process-name normalization. A selection containing only rejected identifiers
  fails before bootstrap state, API access or native staging begins.
- In Windows selected-app mode the final route is direct while the selected
  process rule may target an AWG endpoint. Client routing preferences resolve
  that referenced endpoint for VPN/DNS additions without changing the direct
  final or selecting an unused endpoint.
- Android `excludedApps` also requires a non-empty selection. Materialization
  keeps the app itself and every selected package outside `VpnService`, then
  routes all remaining packages through the managed profile; the server still
  receives the device-wide route-policy contract.
- There is no mutable latest-release download and no hidden legacy fallback.

Exact artifacts and platform gates are owned by
`config/runtime-artifacts.seed.json` and
`docs/decisions/2026-07-23-pokrov-core-1.0.0-activation.md`.

The runtime artifact manifest also binds the shared native Go notice asset to
the Core source commit, Go toolchain and notice SHA-256. The app-shell asset
declaration includes it in Android and Windows packages. Seed validation rejects
a missing asset, hash mismatch, source/toolchain mismatch or missing declaration.
The asset includes root notices, selected source-package ancestor notices and
full license comment blocks found in a bounded scan of selected source files.
It also carries the separate prebuilt license for Wintun 0.14.1, whose exact
amd64 DLL bytes are embedded in the bound Windows Core through sing-tun.
The asset also preserves the original Psiphon `u_prng.go` copyright and its
explicit uTLS license reference, linked to the already included BSD body.
Exact a24b211 local packages retain this notice; final package audits and
module-precision scan evidence are linked from that record.
Core2662 introduced authenticated uTLS7a1fc with its own root LICENSE;
the current Core880b binding retains it. The previous Core904 fork lacked that
root license. Current artifacts and remaining licensing limits are retained in
[Windows adapter cleanup evidence](../operations/evidence/2026-09-12-r12-wintun-binding/README.md).
This notice binding does not establish complete dependency licensing or
corresponding-source delivery; remaining gaps stay explicit in release readiness.

## Update Handoff Boundary

The shared shell may present and open an update only when the metadata carries a
positive bounded byte size, a 64-hex SHA-256, and the exact canonical target
`https://github.com/Kiwunaka/pokrov/releases/download/<tag>/<asset>.apk`.
Alternate initial hosts or repositories, URL authority fields, explicit ports,
query strings, fragments, and non-APK assets fail closed, and the same
validation runs again at tap time.

Android has two explicit distribution flavors with the same canonical package
ID and signing lineage. `direct` alone declares `REQUEST_INSTALL_PACKAGES` and
the non-exported `FileProvider`; it downloads into app-private cache, follows at
most five HTTPS redirects to GitHub-owned asset hosts, and verifies exact byte
size, SHA-256, package ID, requested version, increasing `versionCode`, minimum
SDK, device ABI and signing continuity before the cache commit and again before
any installer intent. `store` declares neither direct-install surface and opens
only the app's explicit Google Play listing; it never downloads or hands off an
APK. Both flavors accept only the configured stable channel and bounded
metadata.

During a direct transfer the bridge exposes only phase and byte counters. The
Flutter sheet shows bounded version, official-source and size copy followed by
verification and installer handoff; it never displays the URL, digest or signer.
Android 8+ may require the user to grant install-source permission. The app
never silently installs an APK. Windows retains the trusted browser handoff.
Signing, install, store-console, runtime, physical-device and exact-candidate
proof remain separate release gates.

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

## R12 Windows profile content identity — local implementation

Windows staging and connect use the negotiated profile-identity contract in
[platform privilege and runtime](platform-privilege-runtime-contract.md).
The service acknowledges the exact stage-request SHA-256 and accepts connect
only for that digest. Staged and effective identity are distinct; effective is
set only after proof and commit. The native UI binds subsequent polls to its
own intent and presents an explicit profile-not-applied recovery on mismatch.
This closes the local stage/start identity gap; server desired/fetched revision,
Android identity and exact packaged AWG transitions remain separate N01 proof.

### Android profile replacement identity

Android stages private config with a persisted content/options SHA-256. Normal,
permission-delayed and Quick Settings starts carry that digest; before replacing
a live session, the service verifies it against metadata and config bytes.
A same-path replacement rejects the stale intent with `profile_identity_mismatch`.
Only the active matching input can receive egress proof. Missing legacy digest
requires a new app-managed fetch/stage before Quick Settings can connect.
The host digest is local identity and does not manufacture server revision truth.

### Fetched revision to service identity

`ManagedProfilePayload.source` carries the exact managed-manifest revision and
`managedManifest` origin; validated emergency material uses
`signedEmergencyEnvelope`. Routing/materialization copies retain that upstream
source. The runtime stores the most recently supplied fetched source separately
from the source of the acknowledged stage digest. Its snapshot exposes
`fetchedProfileSource`, `stagedProfileSource` and `effectiveProfileSource`.
The last field requires running state, successful egress and the same effective,
staged and acknowledged digest. A failed stage can leave fetched B with staged
and effective A; a delayed A proof cannot confirm B. Unknown identity stays null.

This association is process-local and never reconstructed from a filename, hash,
local counter or stale session JSON. After process restart the app fetches/stages
again to restore source lineage; Quick Settings can prove only its persisted
local digest. The managed-manifest response describes desired server assignment
at fetch time, not a promise that the server has not changed it since. Offline
fallback retains its original source and the existing entitlement restrictions.

### Managed profile lifecycle owner

`src/shell/managed_profile_lifecycle.dart` owns profile-input dirtiness and the
local revision, host invalidation queue, timeout generation and disposal. Shell
composition supplies the existing host call and snapshot callback. Bursts are
coalesced into the latest requested revision; connect waits for completed host
invalidation. Timeout/disposal settle the waiter without allowing a late host
acknowledgement to update the shell. This refactor does not change server source
revision, fallback authority or the connection transaction. The module is an
ordinary import and adds no shell `part`.

`managed_profile_lifecycle_test.dart` exercises coalescing, timeout/disposal and
non-Android revision tracking independently. Existing seed-app widget tests
continue to exercise the connection/Quick Settings integration.

Normal connect and explicit protection repair both wait for the pending host
profile invalidation before staging a replacement. An invalidation timeout
ends the operation without stage/connect, even if the host responds later.
Repair also captures the local input revision and checks it after the stage
acknowledgement: if the user closes the repair sheet and changes routing while
staging is pending, the old profile stays dirty and cannot start. The user
retries with the current settings. Host content-digest checks remain separate
from this local intent fence.

### Runtime failure observations

Native failure categories pass through an exact allowlist before reaching public
messages. Offline state, unresolved network interface, DNS failure, refused
endpoint, transport timeout and handshake failure retain distinct observations.
Unknown `dns_`, `default_network_`, `vless_` or `reality_` prefixes do not establish
a cause and become generic runtime failure. A timeout alone does not identify
UDP blocking, DPI, MTU, ASN policy or a whitelist. Request-scoped protocol log
categories remain diagnostic context and cannot change runtime health.

The diagnostics presenter preserves an explicit failure code before checking
incomplete DNS/egress proofs. Failed Core startup, unavailable verifier or absent
network must not become a DNS fault merely because no proof was completed.
Without an explicit failure, existing proof-gap presentation remains available.
These mappings grant no route change or retry permission.

Android per-call Core probes also retain the exact closed `ProbeError.Error()`
observations: connection and TLS negotiation failures become
`core_egress_connect_failed` and `core_egress_tls_failed`; response-stage and
unspecified probe failures remain `core_egress_probe_failed`. Only exact known
messages from the invoked method qualify. Missing APIs and unknown exception
text remain unavailable; raw exception details never enter the snapshot.
These failures use the existing completed-failure policy: endpoint probes get
at most three attempts, group failures are terminal, and session/generation/TUN
fences still decide whether a result applies. The stop reason stays the generic
failed-egress reason while the failure kind retains the stage. Existing managed
and emergency retry limits and the closed AWG degraded-TUN exception remain.
The stage describes the check, not a proven node fault or filtering cause;
the closed exception text cannot distinguish DNS, timeout or DPI subcauses.

The shared catalog distinguishes pending profile provisioning (`API-011`),
unresolved interface (`ROUTE-005`) and an unspecified runtime failure (`CORE-009`).
Subscription refresh failure keeps its API/auth observation rather than claiming
that access is absent. Native event consumers retain typed DNS, UDP, TLS timeout
and response-stall codes from Core, including in the support timeline. Their
presence is diagnostic evidence and does not authorize automatic fallback.

The Windows service's authenticated egress check retains WinHTTP observations
through rollback and its closed IPC failure allowlist. `core_egress_dns_failed`,
`core_egress_connect_failed` and `core_egress_tls_failed` describe the failed check,
not a proven failure of the VPN node. TLS negotiation and waiting for a response
have separate `core_egress_tls_timeout` / `core_egress_response_timeout` values;
timeouts before those stages remain `core_egress_timeout`. Unknown errors and
invalid HTTP/proof responses remain `core_egress_probe_failed`. The native
callback stores only numeric errors and phases, never host names or response
text. Cancellation remains owned by the connection transaction. These codes
retain the same failed-egress retry eligibility, three verifier attempts and
bounded managed fallback; they neither publish protection nor diagnose DPI,
MTU, ASN or UDP blocking. The UI and native service ship together so their
closed allowlists agree.

### Ordinary cache outage boundary

The owner's 2026-09-07 restricted-network decision permits normal connection
when the API is unreachable but a VPN endpoint from the last downloaded profile
is still reachable. `ManagedProfileCache` stores two records in platform secure
storage: downloaded and last proven. They bind account, install, platform,
route mode, selected apps and preferred node/variant. They preserve the original
server-observation time and expire 24 hours after that observation. Future
timestamps are unavailable. Offline reads, repeated failures and host restaging
never extend that window. A cache transaction ID fences delayed proof from
promoting a different download; it is not a server revision or egress proof.

The app tries refresh on ordinary connect/reconnect, allowing at most three
seconds when a matching cached profile exists. Timeout or transient
408/429/502/503/504/no-status failure may restore that protected record through
the regular host staging transaction, including after app/process restart.
The cache is checked again after refresh failure for expiry or intervening
authorization denial. Offline preparation performs no WARP-status API call.
Known 401/403 denial and a successful subscription response with lane
`expiredOrBlocked` clear the protected cache. The subscription denial also
blocks cached reconnect and stops a running tunnel through normal disconnect;
if a native action is in flight, disconnect follows its completion. A transient
managed-profile failure cannot override that known denial. Missing credentials
or an account/input mismatch makes the cache unavailable. A dataplane failure
alone prefers the proven slot on the next manual retry and does not erase either record.

Hosts/bootstrap fixtures without the protected-cache capability retain the
legacy staged-file fallback with a 0–24-hour modification-age check. The real
app bootstrapper uses the protected records rather than resetting freshness
from a newly materialized file. Every restored profile retains its original
server revision, and every new tunnel still requires its normal route/egress
checks. An offline attempt never implies that a new server assignment applied.

This owner-approved grace is not a signed offline entitlement lease. The client
cannot learn a new remote revocation during a complete control-plane outage;
server-side credential enforcement remains authoritative. The separate signed
emergency bundle has its own account/catalog/eligibility expiry checks. Neither
path creates a new trial or subscription. Exact outage/revocation behavior still needs the
candidate and owned server scenario; a local cache test does not prove it.
