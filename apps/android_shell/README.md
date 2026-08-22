# Android Shell Seed

Current responsibility:

- Android-specific Flutter host entry point
- wiring the shared `app_shell` package into an Android-facing starter
- hosting the runtime bridge at `space.pokrov/runtime_engine`
- requesting `VpnService` permission and starting the foreground runtime lane
- supporting one-tap `connect` from the shared shell by auto-initializing POKROV Core, syncing a live managed profile, and staging that profile before runtime start
- keeping the Android consumer lane `tun`-first, with desktop loopback listener surfaces stripped from the staged mobile runtime config and only present address families receiving default routes
- preserving backend-managed mobile-safe `dns` and `route` semantics instead of collapsing Android into a seed-only universal DNS profile
- keeping Android route ownership explicit by disabling sing-box interface auto-detection, writing `exclude_package` for `space.pokrov.pokrov_android_shell`, enforcing the same exclusion through `VpnService.Builder`, and retaining the route-level self-package bypass rule, so control and core uplink traffic cannot fold back into the TUN
- letting `All except RU` classify RU traffic on-device before connect by consuming cached local sing-box `.srs` rule-sets from the shared bootstrapper, while still keeping the older `.ru`, `.xn--p1ai`, and `.su` suffix bypass rules as a fallback if the cache cannot refresh
- keeping raw runtime diagnostics and local smoke-profile controls out of the first-layer shell; release diagnostics remain support/internal
- exporting structured Android host diagnostics into the shared runtime snapshot, including uplink interface and index, DNS readiness, route counts, package-filter counts, and the last failure or stop reason
- binding Core event ABI 1 with run/attempt/generation/sequence fencing; unknown
  or stale callbacks and arbitrary Core debug lines are discarded from release
  evidence
- writing release-safe Android operational breadcrumbs only to the app-private,
  no-backup `observability/android-operational-v1.jsonl` journal; the closed
  schema covers VPN lifecycle and permissions, default-network callbacks,
  Doze/app-standby state, a stack-free main-thread watchdog and direct-updater
  identity results, with one bounded previous file and no free-form payload
- treating Android `running` as healthy only when uplink/bootstrap-DNS prerequisites and the core URL test for the selected outbound are healthy; the core timeout sentinel (`65535`) is a failed probe, and a confirmed failed selected-outbound probe or active Android DNS transport callback/timeout fail-closes the host by stopping the core, TUN, and foreground service rather than leaving a dead VPN active; ordinary DNS response codes and canceled requests remain non-terminal; Android VPN validation remains a supporting signal because emulators can retain it after egress fails
- keeping all redacted request-scoped core events advisory because they do not identify the selected outbound; the bounded selected-outbound probe owns global egress health
- refreshing runtime truth again when the app returns to the foreground and reconciling a live TUN back to `running`, so relaunches do not leave the shared shell stuck on a stale staged state as easily
- exposing a direct `Disconnect` action from the Android foreground notification
- carrying the Android 14 `specialUse` foreground-service permission contract required by `PokrovRuntimeVpnService`

Validation lane:

- `flutter test` in `apps/android_shell/` covers shell boot plus the visible route-mode and runtime-diagnostics affordances
- `android\\gradlew.bat :app:testDirectDebugUnitTest :app:testStoreDebugUnitTest` covers both distribution identities, manifest guards, platform monitoring, the private journal/rotation/watchdog contract, runtime-state preservation, DNS planning, TUN route planning, and package allow/exclude planning
- `..\\..\\scripts\\run-tests.ps1` is the canonical wrapper that runs both the Android-shell Flutter lane and the Android Gradle unit lane alongside the shared workspace tests
- the current repo-local lane covers Android `Full tunnel`, `All except RU`, and selected-app package routing, plus the matching shared Windows materialization contracts
- this test lane is repo-local proof only; it does not replace the required physical-device release-build localhost/control-surface audit

Deferred responsibility:

- Android route-mode picker integration
- production-grade split-tunneling parity, including selected-apps Android parity beyond the current no-op future-lane state
- signed public-store packaging and submission; the repo-local `store` flavor already excludes direct-install permission/code and delegates updates to Google Play
