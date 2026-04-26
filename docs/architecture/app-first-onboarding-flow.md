# App-First Onboarding Flow

Last updated: 2026-04-25

## Document Status

This file is the living client architecture note for app-first identity, onboarding, and managed provisioning in `POKROV-app/main`.

## Goal

The app must give the user a real working session after the Russian trial-start action, then let the user choose how the device should work before the first live connect.

UI state alone is not enough.
The backend must create a real account, a real device record, a real app session, and a real subscription source.

## Current Flow

1. the app generates and persists `install_id`
2. the app collects soft device context
3. the user taps the Russian trial-start action
4. the app calls `POST /api/client/session/start-trial`
5. the backend validates anti-abuse rules
6. the backend creates:
   - `app_account`
   - `device_record`
   - `app_session`
7. the backend provisions a real subscription source
8. the backend returns:
   - `session`
   - `client_policy`
   - `access`
   - `provisioning`
   - experience payload
9. the app silently imports the managed profile
10. the app shows the short Russian three-step onboarding in `Подключение`
11. the app asks `Как должно работать это устройство?` before the first live route activation
12. the app saves the chosen per-device route policy
13. the shell changes to the main connection card

UX guardrail:

- until provisioning succeeds with a real subscription payload, `Локации` stays behind an activation gate and must not render fake/demo countries

## Contract Rules

- the client start-trial request must not send caller-controlled `trial_days`
- the backend always enforces the fixed `5-day` trial from shared truth
- W07 client behavior follows this rule: the request carries device/app context only, while the backend owns duration and entitlement issuance
- `provisioning.status` must expose whether the profile is ready immediately or still pending sync
- the app should read one additive `client_policy` contract from `start-trial`, `dashboard`, and user-refresh flows instead of inferring defaults from stale local assumptions
- the same additive contract should carry the current route-mode state so app, cabinet, and support see one device truth

Current `client_policy` fields:

- `routing_mode_default`
- `transport_profile`
- `transport_kind`
- `engine_hint`
- `profile_revision`
- `dns_policy`
- `route_mode_default`
- `route_mode_choices`
- `route_mode_requires_elevation`
- `route_mode`
- `selected_apps`
- `requires_elevated_privileges`
- `route_policy.mode`
- `route_policy.selected_apps`
- `route_policy.requires_elevated_privileges`
- `package_catalog_version`
- `ruleset_version`
- `support_context.transport`
- `support_context.routing_mode`
- `support_context.ip_version_preference`
- `support_recovery_order`

## Route-Mode Onboarding Contract

Before the first live connect, the client must ask exactly one first-layer consumer question:

- `Как должно работать это устройство?`
- `Оптимизировать все устройство`
- `Только выбранные приложения`

Client shell presentation:

- primary tabs are `Подключение`, `Локации`, `Правила`, and `Профиль`
- the onboarding is three short steps and stays free of raw subscription links, config editors, hostnames, ports, or transport names
- the visible brand mark renders from `assets/branding/pokrov-mark.png`; placeholder letter marks are not part of the client shell contract
- Windows uses a desktop sidebar with constrained cards; Android keeps the compact tab surface
- subscription, device, support, settings, bonus, and key activation cards live under `Профиль`
- `Профиль -> Настройки` exposes `System`, `Light`, and `Dark` theme choices
- visible first-layer copy should describe device behavior and next actions only; runtime-core, protocol, local-control, hostname, port, and raw profile terms belong in diagnostics, advanced settings, or support context
- the white/mint redesign is the only active shell direction for this lane; no dual old/new redesign route should be documented or tested as a user path

Behavior rules:

- `Optimize everything on this device` is the default public path and stays `TUN`-first
- the device-wide lane defaults the visible `Правила` story to `Все, кроме РФ`
- `Полный режим` stays available as the alternate device-wide rule
- `Только выбранные приложения` is the split-tunneling path and must persist selected app or process identifiers per device
- Windows should back that path with an executable or process picker
- Android should back that path with an installed-package picker
- the saved route mode must remain editable later from a dedicated route-mode screen
- if the chosen mode requires elevated rights on desktop, the app must tell the user before connect and guide a relaunch as administrator
- raw system-proxy, service-mode, and low-level transport toggles stay outside the first-layer onboarding path

Current implementation bridge:

- the client persists `Only selected apps` through backend `route_mode=selected_apps`
- the client persists both device-wide routes through backend `route_mode=all_traffic`
- the visible distinction between `All except RU` and `Full tunnel` therefore remains a client `Rules` choice until the backend grows a dedicated device-behavior field
- selected-apps is beta-limited in W07: the UI labels it honestly while picker and OS enforcement work remains open

## Managed Provisioning And Smart Connect

`GET /api/client/profile/managed` is the primary managed provisioning endpoint.

Managed-profile fields:

- `version`
- `profile_revision`
- `transport_profile`
- `transport_kind`
- `engine_hint`
- `config_format`
- `config_payload`
- `fallback_order`
- `support_context`
- `smart_connect`

Smart-connect fields:

- `smart_connect.shortlist_revision`
- `smart_connect.transport_profile`
- `smart_connect.profile_revision`
- `smart_connect.shortlist[*].code`
- `smart_connect.shortlist[*].rank_hint.health_score`
- `smart_connect.shortlist[*].rank_hint.cpu_percent`
- `smart_connect.shortlist[*].rank_hint.panel_latency_ms`
- `smart_connect.shortlist[*].rank_hint.backend_penalty`
- `smart_connect.shortlist[*].rank_hint.cpu_penalty`
- `smart_connect.stickiness.preferred_node_code`
- `smart_connect.stickiness.threshold_percent`
- `smart_connect.fallback_order`

Shortlist rules:

- premium users probe up to `5` eligible non-free nodes
- free-tier users stay on `NL-free`
- shortlist eligibility rejects disabled, draining, unhealthy, stale, overloaded, and transport-incompatible nodes
- the client compares candidates with combined RTT and backend penalties
- the `15%` stickiness threshold prevents unnecessary node flapping
- `POST /api/client/nodes/latency-samples` records install-scoped RTT evidence for operator visibility without changing the free-vs-premium pool rule

## Support, Reward, And Recovery Continuation

### Telegram linking and reward

Related backend contracts:

- `POST /api/client/telegram/link`
- `POST /api/channel/subscriber/check`
- `POST /api/bonuses/channel/claim`

Linked Telegram identity and membership in `@pokrov_vpn` can grant `+10 days`.

### Support

Support payloads should carry:

- app account context
- device record context
- platform
- app version
- last known IP when available

Support rules:

- the app should prepare context before opening the ticket flow or fallback channels
- authenticated browser and cabinet support is ticket-backed through `/api/tickets*`
- diagnostics should expose only safe summaries such as route mode, route category, DNS policy, and transport profile
- diagnostics must not leak raw config, keys, or detailed topology
- when no real session exists yet, support may show prepared context and recovery entry points but must not pretend that live ticket history already exists
- recovery order in support copy stays `app -> web cabinet -> Telegram`
- public browser email continuation stays marked `soon` until sender readiness and the launch path are genuinely live

### Checkout continuation

- renewal and upgrade begin from the client UI
- the app opens the canonical hosted checkout in the external browser
- external checkout, cabinet, Telegram, support, feedback, and redeem handoffs go through an explicit launcher abstraction; snackbar text alone is not a handoff implementation
- the same hosted checkout contract is shared across app, site, and bot flows
- public marketing entry into that flow is checkout-first; cabinet continuation starts after the user is known

## Download Surfaces

- the client fetches `/api/client/apps` and uses runtime URLs for Android `Play` / `APK` / mirror and Windows `EXE` / mirror, plus docs/install fallback
- release handoff updates those runtime `APP_*` URLs for the app, bot, and authenticated web surfaces
- static marketing download CTA is build-time and must be rebuilt or redeployed when public Android or Windows URLs change
- `AAB`, `MSIX`, and portable `ZIP` remain store/operator artifacts rather than first-layer client download targets
- public-facing build surfaces should present the beta line `0.x.x-beta`
- app handoffs for checkout, cabinet downloads, support, community, feedback, and key redemption open safe external destinations instead of exposing raw profiles or local control surfaces

## Release And Audit Expectations

- release verification must start from a clean `libcore` checkout pinned to the parent repo SHA
- `python scripts/run_client_release_gate.py preflight` is the canonical repo-local preflight before Flutter tests or artifact builds
- when Android build gates are requested, release approval also requires `python scripts/android_localhost_audit.py` against a release-installed build on physical hardware via `ANDROID_AUDIT_SERIAL`
- the latest local green `python scripts/release_orchestrator.py --gates-only` snapshot is necessary but not sufficient; Android publication still waits for production signing, the physical-device localhost audit, and separate `current-origin`, `brain-origin`, and `RU-origin` evidence

## Scope Note

This flow is the public client path for:

- `Android`
- `Windows`

For `iOS` and `macOS`, this document is readiness reference only until Apple publication is formally approved.
