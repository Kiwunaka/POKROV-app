# Android Shell Seed

Current responsibility:

- Android-specific Flutter host entry point
- wiring the shared `app_shell` package into an Android-facing starter
- hosting the runtime bridge at `space.pokrov/runtime_engine`
- requesting `VpnService` permission and starting the foreground runtime lane
- supporting one-tap `connect` from the shared shell by auto-initializing libcore, syncing a live managed profile, and staging that profile before runtime start
- keeping the Android consumer lane `tun`-first, with desktop loopback listener surfaces stripped from the staged mobile runtime config and only present address families receiving default routes
- preserving backend-managed mobile-safe `dns` and `route` semantics instead of collapsing Android into a seed-only universal DNS profile
- keeping Android route ownership explicit with `auto_detect_interface`, `override_android_vpn`, and a self-package bypass rule for `space.pokrov.pokrov_android_shell`, so live control traffic does not fold back into the TUN
- letting `All except RU` classify RU traffic on-device before connect by consuming cached local sing-box `.srs` rule-sets from the shared bootstrapper, while still keeping the older `.ru`, `.xn--p1ai`, and `.su` suffix bypass rules as a fallback if the cache cannot refresh
- exposing the stronger `Runtime health` diagnostics lane in `Quick Connect`, including refresh, runtime priming, local smoke-profile staging, and direct connect or disconnect controls
- exporting structured Android host diagnostics into the shared runtime snapshot, including uplink interface and index, DNS readiness, route counts, package-filter counts, and the last failure or stop reason
- treating Android `running` as healthy only when the post-establish uplink and DNS diagnostics are healthy; otherwise the shell keeps the connect visible as `Connected with warnings`
- refreshing runtime truth again when the app returns to the foreground and reconciling a live TUN back to `running`, so relaunches do not leave the shared shell stuck on a stale staged state as easily
- exposing a direct `Disconnect` action from the Android foreground notification
- carrying the Android 14 `specialUse` foreground-service permission contract required by `PokrovRuntimeVpnService`

Validation lane:

- `flutter test` in `apps/android_shell/` covers shell boot plus the visible route-mode and runtime-diagnostics affordances
- `android\\gradlew.bat testDebugUnitTest` covers manifest guards, platform monitoring, runtime-state preservation, DNS planning, and TUN route planning
- `..\\..\\scripts\\run-tests.ps1` is the canonical wrapper that runs both the Android-shell Flutter lane and the Android Gradle unit lane alongside the shared workspace tests
- the current repo-local lane now covers Android `Full tunnel` plus the shared Android or Windows `All except RU` materialization contract; selected-apps parity is still not claimed by this test pack
- this test lane is repo-local proof only; it does not replace the required physical-device release-build localhost/control-surface audit

Deferred responsibility:

- Android route-mode picker integration
- production-grade split-tunneling parity, including selected-apps Android parity beyond the current no-op future-lane state
- signed release packaging and public-store wiring
