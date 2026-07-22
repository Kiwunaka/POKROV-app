# App-First Onboarding Flow

Last updated: 2026-07-22

## Document Status

This file is the living client architecture note for app-first identity, onboarding, and managed provisioning in `POKROV-app/main`.

The platform contract owner is
`C:/Users/kiwun/Documents/ai/VPN/docs/architecture/app-first-and-bonus-flows.md`.
Public download behavior belongs to
`C:/Users/kiwun/Documents/ai/VPN/docs/architecture/client-downloads-flow.md`.

## Goal

The app must give the user a real working session after `Try free`, then let the user choose how the device should work before the first live connect.

UI state alone is not enough.
The backend must create a real account, a real device record, a real app session, and a real subscription source.

## Current Flow

1. the app generates and persists `install_id`
2. the app collects soft device context
3. the user taps `Try free`
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
9. the app silently imports the managed profile
10. the app asks `How should this device work?` before the first live route activation
11. the app saves the chosen per-device route policy
12. the shell changes to `Quick Connect`
13. only after the runtime settles in `RuntimePhase.running`, the app reports
    connected runtime state and completes account onboarding through the active
    app session

UX guardrail:

- until provisioning succeeds with a real subscription payload, `Locations` stays behind an activation gate and must not render fake/demo countries
- a tap, permission prompt, timeout, or failed connection must not dismiss the
  first-connect milestone

## Account Experience And Connection Evidence

The native welcome shown before account creation is necessarily install-scoped.
Once a real app session exists, onboarding continuation and first-connection UX
belong to the account rather than a device-local flag:

- after a confirmed `RuntimePhase.running`, the app posts connected state to
  `POST /api/client/runtime/stats` and marks onboarding complete through
  `POST /api/account/experience/onboarding`
- both writes use the active app session and are best-effort UX synchronization;
  failure does not disconnect the already-running tunnel
- `GET /api/user/{tg_id}` is the current account experience read model for the
  cabinet and other authenticated continuations
- client-authored runtime state produces only `reported` progress; it cannot
  activate a trial, grant days, or prove that traffic traversed the intended
  route
- only signed backend observer evidence produces `verified` and remains the
  authority for the trusted first-connection milestone
- the local first-connect hint is persisted as complete only after the runtime
  reaches `running`; failed attempts leave it available for the next try

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

- `How should this device work?`
- `Optimize everything on this device`
- `Only selected apps`

Behavior rules:

- `Optimize everything on this device` is the default public path and stays `TUN`-first
- the device-wide lane defaults the visible `Rules` story to `All except RU`
- `Full tunnel` stays available as the alternate device-wide rule
- `Only selected apps` is the split-tunneling path and must persist selected app or process identifiers per device
- Windows should back that path with an executable or process picker
- Android should back that path with an installed-package picker
- the saved route mode must remain editable later from a dedicated route-mode screen
- if the chosen mode requires elevated rights on desktop, the app must tell the user before connect and guide a relaunch as administrator
- raw system-proxy, service-mode, and low-level transport toggles stay outside the first-layer onboarding path

Current implementation bridge:

- the client persists `Only selected apps` through backend `route_mode=selected_apps`
- the client persists both device-wide routes through backend `route_mode=all_traffic`
- the visible distinction between `All except RU` and `Full tunnel` therefore remains a client `Rules` choice until the backend grows a dedicated device-behavior field
- the app may render `ruleset_version` and `package_catalog_version` as safe
  user-facing catalog labels together with enabled/staged/locked preset states
- selected-apps is beta-active with a picker-first UI: Android uses an
  installed-package picker and Windows uses process/exe candidates, with manual
  package/process identifiers retained behind an explicit manual fallback
- the app sends `selected_apps` through backend route policy; Android
  materialization writes selected package ids into sing-box `include_package`,
  while Windows selected-process routing is kept process/exe-first in the client
- Windows `Rules` should render region/process language (`Маршруты Windows`,
  `Российский регион`, `Выбранные процессы`) instead of mobile-only presets
  such as banks, Gosuslugi, or marketplaces
- raw rule editing remains outside normal UI
- this beta implementation does not clear exact-artifact Android
  physical-device or Windows clean-VM routing proof; those remain
  `MANUAL_OWNER_TEST` release gates

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
- `warp_policy`

WARP policy rule:

- `client_policy.warp_policy` is sanitized metadata only.
- The default WARP path is client-local Hiddify-core WARP. The app may expose
  `WARP / Расширенная защита` when the local runtime lane is available; it must
  not wait for backend-provisioned WireGuard/account material before offering
  consent.
- Managed-profile `warp_policy` may still carry backend-provisioned
  WireGuard/account material as an optional operator lane, but this material is
  not the normal prerequisite for WARP.
- Before setting Hiddify `warp.enable=true`, the app must ask for explicit local
  consent and persist that choice on the device.
- Backend WARP status, consent, revoke, and event endpoints are lifecycle ledger
  surfaces. They must not reject or clear client-local WARP solely because
  server-managed material is absent.
- Production WARP claims still require Android and Windows release-build
  connect/disconnect/fallback proof.

Smart-connect fields:

- `smart_connect.shortlist_revision`
- `smart_connect.transport_profile`
- `smart_connect.profile_revision`
- `smart_connect.shortlist[*].code`
- `smart_connect.shortlist[*].probe.host`
- `smart_connect.shortlist[*].probe.port`
- `smart_connect.shortlist[*].rank_hint.health_score`
- `smart_connect.shortlist[*].rank_hint.cpu_percent`
- `smart_connect.shortlist[*].rank_hint.panel_latency_ms`
- `smart_connect.shortlist[*].rank_hint.backend_penalty`
- `smart_connect.shortlist[*].rank_hint.cpu_penalty`
- `smart_connect.shortlist[*].rank_hint.capacity_state`
- `smart_connect.shortlist[*].rank_hint.capacity_score`
- `smart_connect.shortlist[*].rank_hint.tx_ratio`
- `smart_connect.shortlist[*].rank_hint.tx_mbps`
- `smart_connect.shortlist[*].rank_hint.provisioned_clients_count`
- `smart_connect.shortlist[*].rank_hint.online_connections_hint`
- `smart_connect.selected_node_code`
- `smart_connect.stickiness.preferred_node_code`
- `smart_connect.stickiness.threshold_percent`
- `smart_connect.fallback_order`

Shortlist rules:

- premium users probe up to `SMART_CONNECT_SHORTLIST_LIMIT` eligible non-free nodes, default `8`
- free-tier users stay on `NL-free`
- shortlist eligibility rejects disabled, draining, unhealthy, stale, dataplane-down, saturated, high-loss/retransmit, overloaded, and transport-incompatible nodes while capacity-aware selection is enabled
- the client performs best-effort TCP RTT probes for shortlist items with an internal probe endpoint, then calls `POST /api/client/nodes/select` with `mode=auto` for automatic choice or `mode=manual` for saved location choice
- after a selected node is accepted, the client may refetch `GET /api/client/profile/managed?selected_node_code=...` before materializing the runtime config
- the default `20%` stickiness threshold prevents unnecessary node flapping
- `POST /api/client/nodes/latency-samples` remains compatibility telemetry for install-scoped RTT evidence and does not replace `/api/client/nodes/select`

## Support, Reward, And Recovery Continuation

### Telegram linking and reward

Related backend contracts:

- `POST /api/client/telegram/link`
- `GET /api/bonuses/summary`
- `GET /api/bonuses/referral/summary`
- `GET /api/bonuses/history`
- `GET /api/bonuses/wheel/state`
- `POST /api/bonuses/wheel/spin`
- `GET /api/bonuses/calendar`
- `POST /api/bonuses/calendar/checkin`
- `POST /api/bonuses/promo/redeem`
- `GET /api/client/promo-slots?surface=app`
- `POST /api/channel/subscriber/check`
- `POST /api/bonuses/channel/claim`

Linked Telegram identity and membership in `@pokrov_vpn` can grant `+10 days`.
Promo codes can be redeemed through the unified code entry or the app-facing
bonus promo endpoint. Bonus history is available as a compact app-safe ledger
and Account may show the latest safe reward events inside the existing bonus
summary. Wheel and calendar state endpoints can feed safe Rewards Hub previews,
but their mutating actions remain feature-gated and must stay disabled until
reward logic, rollout state, and UI copy are explicit.
The client reads `GET /api/bonuses/referral/summary` for the Rewards Hub
referral card: code, safe Telegram link, bonus days, and tier state. It may
expose copy/share/open actions for that link, but referral anti-abuse, bonus
granting, and campaign tuning remain backend-owned.
`GET /api/client/promo-slots?surface=app` may feed the same Rewards Hub with
enabled first-party slots only; third-party ads, unsafe links, and tracking
campaigns stay out of the app.

### Returning-user recovery

- returning users restore from the first-launch screen with a one-time code
  from Telegram, the cabinet, email, or an activation key
- raw connection/subscription/proxy links are not account proof and must not be
  sent through unified redeem as recovery codes
- the app shows this warning on the restore screen and locally rejects raw
  connection links before the backend call
- backend structured rejection remains the canonical fallback for any raw link
  that reaches `/api/redeem`

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
- app ticket creation attaches safe diagnostics automatically; follow-up replies attach diagnostics only after explicit one-message user confirmation
- the support-scoped AI helper calls the implemented
  `POST /api/client/support/assistant` endpoint with app-session
  authorization, a user message, optional ticket ID, and redacted safe
  diagnostics; ticket-backed operator support remains the escalation path
- the app may poll the active ticket while the support screen is open and show
  lifecycle hints such as checking, operator reply, closed, or temporarily
  offline
- diagnostics should expose only safe summaries such as route mode, route category, DNS policy, and transport profile
- diagnostics must not leak raw config, keys, or detailed topology
- when no real session exists yet, support may show prepared context and recovery entry points but must not pretend that live ticket history already exists
- support UI must not fake typing, read receipts, or operator-online presence
- recovery order in support copy stays `app -> web cabinet -> Telegram`
- public browser email continuation stays marked `soon` until sender readiness and the launch path are genuinely live

### Checkout continuation

- renewal and upgrade begin from the client UI
- the app opens the canonical hosted checkout in the external browser
- the same hosted checkout contract is shared across app, site, and bot flows
- public marketing entry into that flow is checkout-first; cabinet continuation starts after the user is known

## Download Surfaces

- the client fetches `/api/client/apps` and uses runtime URLs for Android `Play` / `APK` / mirror and Windows `EXE` / mirror, plus docs/install fallback
- release handoff updates those runtime `APP_*` URLs for the app, bot, and authenticated web surfaces
- static marketing download CTA is build-time and must be rebuilt or redeployed when public Android or Windows URLs change
- `AAB`, `MSIX`, and portable `ZIP` remain store/operator artifacts rather than first-layer client download targets
- public-facing build surfaces should present `1.0.0-beta` or an explicit
  beta patch/build label; none of those labels authorizes stable `1.0.0`
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
