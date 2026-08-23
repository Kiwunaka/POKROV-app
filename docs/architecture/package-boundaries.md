# Package Boundaries

This seed treats the shared packages as the future contract surface for a four-platform client program and now exposes one thin host shell per public target.

## Dependency Rules

Allowed dependency flow:

1. `core_domain`
2. `platform_contracts`, `observability_contracts`, and `support_context`
3. `observability_runtime` and `diagnostics_collectors`
4. `support_bundle`
5. `app_shell`
6. `apps/android_shell`, `apps/ios_shell`, `apps/macos_shell`, and `apps/windows_shell`

Rules:

- `core_domain` stays pure and does not import host or Flutter UI concerns.
- `platform_contracts` may depend on `core_domain` but should not know about widgets or navigation.
- `support_context` may depend on `core_domain` and should only expose support-safe summaries and handoff metadata.
- `observability_contracts` has no runtime dependency. It exposes only typed
  identifiers and the checked SHA snapshot of the platform-owned operational
  event schema and error catalog.
- `observability_runtime` depends only on `observability_contracts` and pure
  Dart libraries. It owns privacy validation, bounded in-process buffering,
  crash-tolerant local JSONL retention, phase timelines, previous-exit markers,
  closed failure/problem-book mappings, aggregate projection, and closed legacy
  translation. It owns only a transport callback, not credentials, session
  creation, UI, host privileges, or the portal API client.
- `diagnostics_collectors` depends only on typed observability identities. It
  accepts no source path, arbitrary field, application inventory, destination
  or raw config and emits only fixed in-memory virtual paths under hard input
  and byte bounds.
- `support_bundle` depends on `diagnostics_collectors`. It owns deterministic
  manifests/previews, category/profile budgets, redaction scanning, signed
  key/policy verification and encryption-only output. It has no plaintext ZIP,
  filesystem export or chat transport.
- `app_shell` can depend on every shared package. It owns the authenticated
  support-mode redemption, explicit-consent lifecycle, persistent state and
  indicator, cumulative usage registration, recipient resolution and
  encrypted export/delivery orchestration. Host apps stay thin: Android exposes
  one SAF document channel and Windows uses the system save dialog.
- Host apps should never contain copied business facts that already live in `config/*.seed.json`.

## Current Seed Responsibilities

| Package | Seed responsibility |
| --- | --- |
| `core_domain` | Scope, access-lane, route-mode, runtime-core, free-tier, and location-matrix facts |
| `platform_contracts` | Host bootstrap contract, permissions, core defaults, and the future native-core artifact contract |
| `observability_contracts` | Typed operational event/error identifiers plus exact platform contract hashes |
| `observability_runtime` | Non-blocking typed event dispatch, privacy guard, priority queues, breadcrumbs, phase/proof timelines, crash marker, bounded app-private retention, and identity-free release-health projection |
| `diagnostics_collectors` | Closed typed snapshots converted to fixed, bounded in-memory build/system/network/event/crash/redaction files |
| `support_bundle` | Deterministic exact preview and manifest, signed support key/policy verification, and X25519/HKDF/AES-GCM encryption-only output |
| `support_context` | Support-safe snapshot shown in the placeholder UI |
| `app_shell` | Runnable app-first shell aligned to `Protection / Locations / Rules / Profile`, with redeem and support handoff owned as Profile-level actions |

The Support preview shows a bounded `PSD1-*` code, categories, virtual files,
byte sizes and removal count before any bundle export. The short code carries
no file or identity and can be decoded without upload. The existing
support-ticket attachment is explicitly a separate five-field safe summary.
Full upload or manual export is exposed only when the release embeds an
explicit signing pin and resolves a valid signed recipient; every destination
receives the encrypted `.pokrov-support` envelope, never prepared plaintext.

## Native-Core Artifact Rule

- The four host shells should share one documented native-core dependency story.
- The retained legacy contract pins POKROV Core 1.0.3 at one exact source and
  release commit. Its hashes remain valid historical/runtime evidence, but
  those artifacts do not contain the structured event surface required by
  release 1.2.0. Android and Windows now consume the exact reproducible 1.1.0
  pre-candidate replacement bound to clean source, hashes, ABI/event contracts
  and SBOM identities. Apple artifacts remain manual until built and proven on
  macOS.
- `platform_contracts` is the only shared package that should grow the POKROV Core artifact source, version, checksum, and load-policy contract.
- Host shells should consume that contract later instead of baking host-specific runtime provenance into `Android`, `iOS`, `macOS`, or `Windows` independently.

## Runtime Host Bridge Boundary

- `runtime_engine` now owns the shared runtime snapshot and managed-profile staging contract for the next-client lane.
- `runtime_engine` is also the host-side AWG2 provenance barrier. It rejects
  missing/stale `pokrov.awg2.endpoint.v1` metadata, multiple AWG endpoints and
  integrated-TUN ownership before invoking either Android or Windows. The
  existing host route mode remains authoritative for full tunnel,
  all-except-RU and selected-app/process operation; no second service, driver,
  TUN or default-route owner is introduced.
- `Android` and `iOS` host shells register a native bridge at `space.pokrov/runtime_engine` so Dart can request `snapshot`, `initialize`, raw materialized `stageManagedProfile`, `applyWarp`, `connect`, and `disconnect` against app-owned runtime directories.
- `Android` owns the host-side `VpnService`: the bridge requests VPN permission, starts a foreground `PokrovRuntimeVpnService`, validates staged config through POKROV Core `Libbox`, and opens the app-owned tun device through `PlatformInterface` and `CommandServer`.
- `iOS` owns the packet-tunnel lane through `NETunnelProviderManager`: the bridge stages one protected materialized profile in the shared app group and the provider uses POKROV Core `LibboxSetup` plus `CommandServer.startOrReloadService`; the framework build, entitlement review, Xcode archive, and signed-device proof are still operator work.
- `macOS` stays on the desktop FFI lane and copies only `pokrov-core.dylib` under `Contents/Frameworks/Runtime`.
- `Windows` uses `RuntimeLane.windowsService`. The ordinary Flutter process
  sends only bounded typed runtime commands to the authenticated LocalSystem
  service; it does not load Core, mutate TUN/routes/DNS or elevate itself. The
  service loads the exact sibling `pokrov-core.dll` and pinned `libcronet.dll`
  from the machine-wide installation. The build helper verifies metadata,
  exact files and service-aware package staging. The retained 1.0.3 DLL remains
  an explicit `legacy_without_structured_events` compatibility identity and
  cannot satisfy a 1.2.0 candidate. The exact 1.1.0 DLL is now synchronized for
  the local pre-candidate line; clean-host TUN/DNS/egress, signing and package
  proof remain open.
- Host shells should still stay thin. Native code should implement only the host-specific bridge and packaging steps required by the shared runtime contract.

## Connection Experience Truth

- `runtime_engine` owns host evidence; `app_shell` owns the consumer-facing
  adapter. Home, Profile, Support and desktop shell controls must not interpret
  raw lifecycle values independently.
- `ConnectionExperienceReducer` maps one `RuntimeSnapshot` plus one explicit
  transition intent into typed idle, permission, preparing, connecting,
  connected-unverified, connected-verified, disconnecting, reconnecting,
  blocked or failed state.
- `ConnectionPresentation` is the single owner of connection title, primary
  CTA, semantic label, tone and connect-disc phase. Disconnecting and
  reconnecting are explicit intents; `busy && running` is not a state rule.
- Home consumes one immutable `ProtectionViewState` plus one
  `ProtectionIntents` boundary. The view retains the exact
  `ConnectionPresentation` instance and adds only protection context such as
  route, location, emergency mode, recovery notice and connect-hint state. The
  composition root must not pass parallel connection copy, CTA or callbacks
  through the Home constructor.
- `ConnectionCoordinator` owns the mutable runtime snapshot, explicit intent,
  action-in-flight flag, attempt clock/number, reducer/presenter derivation and
  runtime-action timeout. The bootstrap shell may coordinate product services
  around it, but must not restore parallel raw connection fields or derive a
  second presentation.
- `FirstSessionCoordinator` owns the welcome/restore/ready step, restore busy
  state, handover animation decision, ephemeral acquisition dedupe/status,
  Android VPN-permission explanation/recovery state, and first-home/first-
  verified-connect milestones. Opaque acquisition handles never leave this
  in-memory boundary. The shell injects account redemption, handoff consumption
  and host actions; it must not restore parallel first-launch fields, persist a
  handoff handle, or make attribution/telemetry/local-marker failure block
  trial, restore or connect.
- Account refresh and client-open telemetry wait for a completed persisted
  session, an explicit trial selection, a successful restore, or an acquisition
  continuation. Merely rendering the welcome choice must not provision access.
- Android's first connect shows a bounded explainer before the host connect lane
  can raise `VpnService.prepare`. A denied `vpn_permission_denied` snapshot
  remains disconnected, keeps safe copy and exposes one explicit Home retry; it
  cannot collapse into a generic runtime failure or dead-end the CTA.
- `AppFirstFirstSessionEventService` accepts only the fixed first-session event
  vocabulary plus bounded stage/result/error fields. Server authentication
  supplies account/device correlation; no acquisition handle, session token,
  managed profile, endpoint or raw host text belongs in the event body.
- `AccountSessionCoordinator` owns account action capability plus current
  `FreeProfileAccess` and `ClientSubscriptionInfo`. Clearing a stale
  subscription refresh must not erase independent access state or mutate local
  routing/runtime policy; the shell must not restore parallel account fields.
- `DiagnosticsCoordinator` owns foreground-refresh single-flight and bounded
  post-connect polling timer/generation/in-flight fences. It does not interpret
  health evidence or create connection truth; typed runtime snapshots still
  flow through `ConnectionCoordinator` and the existing reducer.
- `ConnectionCoordinator` also owns the ten-second per-stage timer. Progress to
  a new typed stage resets it; when one stage remains slow, Home exposes the
  current safe stage and an explicit details action and records one bounded
  protection event. Finishing or disposing the action cancels the timer.
- Protection Center is summary-first. `_ProtectionCenterController` owns its
  refresh, disclosure, repair-progress and outcome state; the widget does not
  call host data actions directly. Tunnel/DNS/egress/routes, live stats and
  history stay behind explicit details disclosure. Repair requires a
  disconnect warning and reports stop/profile/verify steps before either a
  verified result or the existing support/diagnostic path.
- `ConnectedVerified` requires a running runtime, healthy host, DNS and uplink
  states, no explicit DNS-readiness failure and selected-outbound Core egress
  proof. A host that omits the older redundant `dnsReady` boolean may use its
  typed healthy DNS state as proof. Missing egress or any unknown health state
  stays connected-unverified and never renders green.
- `PokrovHaptics` is the only direct Flutter haptic adapter used by shell,
  feature and design-system code; the boundary check rejects direct
  `HapticFeedback` calls elsewhere and prevents the app-shell `part` count from
  growing above the retained ceiling.
- The primary connect action emits one tap haptic. A transition to verified may
  emit one success outcome; disconnect completion emits no second tap, and a
  surfaced failure keeps its one outcome in the shared danger feedback path.
- The current adapter stays on desktop ABI 2. Structured Core events use the
  additive event ABI 1 on Windows and Android; ABI 3 is neither declared nor
  inferred. Persisted-state migration remains a separate compatibility slice.
- `PokrovClientObservability` observes this same reducer after state changes;
  it does not derive a parallel connection state. Generation/sequence fences
  reject superseded attempts, phase events retain durations and proof booleans,
  and aggregate transport is delegated to the existing authenticated app-first
  client with `X-Correlation-ID`.
- The shell emits explicit start/finish operational events around account auth,
  entitlement refresh, live performance sampling and encrypted support-bundle
  delivery. Those producers use the same bounded dispatcher and catalog codes;
  they do not create a second analytics or support pipeline. Performance
  `bytes_in`/`bytes_out` are one-second-equivalent byte-rate counters with
  `duration_ms=1000`, not cumulative traffic history.
- Android selected-app changes emit only the deduplicated integer
  `selected_app_count` (`0..128`). Package identifiers stay in the existing
  device-local routing store and managed-profile request; the release-health
  mirror strips every other attribute. Windows does not emit this projection.

### Core ABI and lifecycle compatibility

- POKROV Core owns `config/abi-contract.json`; the client mirrors only the
  compatibility fields it must enforce in `config/runtime-artifacts.seed.json`.
- Released marker-only ABI 2 libraries and the exact pre-structured descriptor
  remain recognizable only as legacy compatibility identities. A current Core
  that exports `pokrovCoreCapabilities` must return descriptor schema 1,
  desktop ABI 2, event ABI 1, the exact required capability set including
  `structured_operational_events`, the closed lifecycle vocabulary and the
  callback/context descriptor. The returned string is released with
  `freeString`.
- Malformed descriptors, unknown schema/event ABI versions, missing required
  capabilities and unknown lifecycle event identifiers fail closed before any
  Core setup or profile material is passed across FFI.
- Windows registers `pokrovCoreSetEventCallback` and
  `pokrovCoreSetEventContext`; Android binds the equivalent gomobile
  `OperationalEventHandler` methods. Both hosts accept only the closed event
  names/error codes and fence stale run, attempt, generation and sequence
  values. Arbitrary upstream debug lines are discarded from release evidence.
- ABI 3 is intentionally unsupported. A future ABI marker cannot become
  runnable merely by claiming familiar capabilities; it needs a separate
  client binding fixture and compatibility decision first.

## Four-Platform Shape

- `Android`, `iOS`, `macOS`, and `Windows` all have thin public host shells in this seed.
- The shared packages stay responsible for product facts and shell behavior so no host becomes the accidental source of truth.
- Apple hosts remain partial runtime shells and should not pull in reviewed signing, store automation, or full Apple tunnel-delivery claims until a later wave explicitly scopes that work.
- The current Apple host metadata is useful as inventory only: iOS now carries placeholder signing xcconfig plus app-group entitlements, while macOS also carries tighter sandbox, hardened-runtime, and notarization placeholders.
