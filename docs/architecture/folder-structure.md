# Repository map

Android and Windows are the public host pair. This map locates current code;
[cutover readiness](../operations/cutover-readiness.md) owns release acceptance,
and [AGENTS.md](../../AGENTS.md) owns working and approval rules.

## Packages and source entrypoints

| Path | Owns |
| --- | --- |
| [app_shell](../../packages/app_shell/lib/app_shell.dart) | Shared Flutter composition and library part map |
| [shell state](../../packages/app_shell/lib/src/shell/seed_shell.dart) | Bootstrap, persisted user preferences, authenticated handlers and real-data wiring |
| [connection manager](../../packages/app_shell/lib/src/connection/connection_manager.dart) | Connect/cancel/recovery coordination, country selection and managed candidate admission |
| [feature adapters](../../packages/app_shell/lib/src/features/) | Home, Locations, Rules, Profile, rewards, support, Diagnostics, WARP and update flows |
| [app_ui](../../packages/app_ui/lib/pokrov_app_ui.dart) | Presentation widgets and view data; real callbacks are supplied by app_shell |
| [runtime_engine](../../packages/runtime_engine/lib/runtime_engine.dart) | Managed-profile materialization, native host bindings, probes and capability negotiation |
| [core_domain](../../packages/core_domain/README.md) / [platform_contracts](../../packages/platform_contracts/README.md) | Access/routing models, platform services, permissions and lifecycle contracts |
| [observability_contracts](../../packages/observability_contracts/README.md) / [observability_runtime](../../packages/observability_runtime/README.md) | Platform-owned event identities and bounded privacy-safe dispatch/retention |
| [diagnostics_collectors](../../packages/diagnostics_collectors/README.md) / [support_bundle](../../packages/support_bundle/README.md) / [support_context](../../packages/support_context/README.md) | Closed snapshots, encrypted reports and safe support context |

The new UI's ownership, actions and Diagnostics redaction boundary are in
[DESIGN.md](../../DESIGN.md). Product choices are in the
[product contract](../product/client-product-contract.md). Runtime preparation
and cancellation details belong to [bootstrap workflow](bootstrap-workflow.md).

## Platform hosts

| Path | Owns |
| --- | --- |
| [Android host](../../apps/android_shell/README.md) | Android entrypoint, permissions and Kotlin/JNI boundary |
| [Android runtime bridge](../../apps/android_shell/android/app/src/main/kotlin/space/pokrov/pokrov_android_shell/AndroidPlatformRuntimeBridge.kt) / [VPN service](../../apps/android_shell/android/app/src/main/kotlin/space/pokrov/pokrov_android_shell/PokrovRuntimeVpnService.kt) | Native lifecycle, TUN/network ownership and foreground VPN service |
| [Windows host](../../apps/windows_shell/README.md) / [native sources](../../apps/windows_shell/windows/) | Flutter host, installed privileged service, tray and OS integration |
| [iOS](../../apps/ios_shell/README.md), [macOS](../../apps/macos_shell/README.md), [Linux](../../apps/linux_shell/README.md) | Engineering/readiness hosts; not part of the current public pair |

Host entrypoints use the shared packages. Platform privileges and native
lifecycle stay behind the [runtime contract](platform-privilege-runtime-contract.md);
secure session and preference rules stay in [persisted state](persisted-state-contract.md).
UI widgets do not create authentication, entitlements or connection proof.

## Runtime artifacts and release tooling

| Path | Role |
| --- | --- |
| [scripts guide](../../scripts/README.md) | Platform-specific sync, validation and packaging entrypoints |
| [runtime-artifacts.seed.json](../../config/runtime-artifacts.seed.json) | Default pinned artifact/dependency identities; currently the retained Windows binding |
| [Android builder](../../scripts/build-android-production.ps1) | Production signing and version/ABI checks; supports explicit RuntimeArtifactsPath and platform-scoped sync |
| [Windows builder](../../scripts/build-windows-release.ps1) / [reproducible wrapper](../../scripts/build-windows-release-reproducible.ps1) | Existing desktop binding, packaging and optional trusted signing; wrapper uses a temporary P: mapping |
| [version parity](../../scripts/check-client-version-parity.ps1) / [runtime sync](../../scripts/sync-pokrov-core-runtime.ps1) | Exact source/version/artifact validation and explicit platform selection |
| [test runner](../../scripts/run-tests.ps1) | Listed workspace Flutter checks and Android unit-test flavors; focused checks normally run in the changed package |

Android 4180's Core AAR from `5364537` requires
`-RuntimeArtifactsPath E:/POKROV-tools/temp/core-android-mobile-auth/runtime-artifacts.android.json`.
The default manifest was not updated for Android; Windows keeps Core 1.2.14 /
`40356d4` with matching Cronet. Keep these bindings separate; preserve source
pins, dependency identities, signing and trust checks. See the scripts guide
before staging or packaging either platform.

`config/local/`, host build outputs and native artifact slots remain generated
and ignored; no credentials, raw profiles or release binaries belong in Git.
Tests live beside their owning packages or hosts. Dated decisions and receipts
remain history, not a parallel task queue or permission to repeat accepted QA.
