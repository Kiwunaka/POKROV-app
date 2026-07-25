# Package Boundaries

This seed treats the shared packages as the future contract surface for a four-platform client program and now exposes one thin host shell per public target.

## Dependency Rules

Allowed dependency flow:

1. `core_domain`
2. `platform_contracts` and `support_context`
3. `app_shell`
4. `apps/android_shell`, `apps/ios_shell`, `apps/macos_shell`, and `apps/windows_shell`

Rules:

- `core_domain` stays pure and does not import host or Flutter UI concerns.
- `platform_contracts` may depend on `core_domain` but should not know about widgets or navigation.
- `support_context` may depend on `core_domain` and should only expose support-safe summaries and handoff metadata.
- `app_shell` can depend on every shared package, but host apps should stay thin and only inject platform-specific bootstrap values.
- Host apps should never contain copied business facts that already live in `config/*.seed.json`.

## Current Seed Responsibilities

| Package | Seed responsibility |
| --- | --- |
| `core_domain` | Scope, access-lane, route-mode, runtime-core, free-tier, and location-matrix facts |
| `platform_contracts` | Host bootstrap contract, permissions, core defaults, and the future native-core artifact contract |
| `support_context` | Support-safe snapshot shown in the placeholder UI |
| `app_shell` | Runnable app-first shell aligned to `Protection / Locations / Rules / Profile`, with redeem and support handoff owned as Profile-level actions |

## Native-Core Artifact Rule

- The four host shells should share one documented native-core dependency story.
- The active contract pins POKROV Core 1.0.0 at one exact source commit. Android and Windows consume only artifacts built by that repository; Apple artifacts remain manual until built and proven on macOS.
- `platform_contracts` is the only shared package that should grow the POKROV Core artifact source, version, checksum, and load-policy contract.
- Host shells should consume that contract later instead of baking host-specific runtime provenance into `Android`, `iOS`, `macOS`, or `Windows` independently.

## Runtime Host Bridge Boundary

- `runtime_engine` now owns the shared runtime snapshot and managed-profile staging contract for the next-client lane.
- `Android` and `iOS` host shells register a native bridge at `space.pokrov/runtime_engine` so Dart can request `snapshot`, `initialize`, raw materialized `stageManagedProfile`, `applyWarp`, `connect`, and `disconnect` against app-owned runtime directories.
- `Android` owns the host-side `VpnService`: the bridge requests VPN permission, starts a foreground `PokrovRuntimeVpnService`, validates staged config through POKROV Core `Libbox`, and opens the app-owned tun device through `PlatformInterface` and `CommandServer`.
- `iOS` owns the packet-tunnel lane through `NETunnelProviderManager`: the bridge stages one protected materialized profile in the shared app group and the provider uses POKROV Core `LibboxSetup` plus `CommandServer.startOrReloadService`; the framework build, entitlement review, Xcode archive, and signed-device proof are still operator work.
- `macOS` stays on the desktop FFI lane and copies only `pokrov-core.dylib` under `Contents/Frameworks/Runtime`.
- `Windows` stays on desktop ABI 2 and copies the exact pinned POKROV-built `pokrov-core.dll` plus pinned `libcronet.dll` into the release bundle, where the build helper verifies metadata, exact files, and package staging. The `v1.0.0` dirty-build provenance exception is recorded in the active runtime decision and blocks a clean reproducibility claim until a patch release.
- Host shells should still stay thin. Native code should implement only the host-specific bridge and packaging steps required by the shared runtime contract.

## Four-Platform Shape

- `Android`, `iOS`, `macOS`, and `Windows` all have thin public host shells in this seed.
- The shared packages stay responsible for product facts and shell behavior so no host becomes the accidental source of truth.
- Apple hosts remain partial runtime shells and should not pull in reviewed signing, store automation, or full Apple tunnel-delivery claims until a later wave explicitly scopes that work.
- The current Apple host metadata is useful as inventory only: iOS now carries placeholder signing xcconfig plus app-group entitlements, while macOS also carries tighter sandbox, hardened-runtime, and notarization placeholders.
