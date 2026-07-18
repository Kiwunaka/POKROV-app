# POKROV Client Product Contract

Last updated: 2026-07-18

## Document Status

This file is the living client product contract for `POKROV-app/main`.

## Scope

This repo is the canonical client-development lane for `POKROV`.

- public `v1` scope: `Android + Windows`
- `iOS` and `macOS`: readiness, packaging, and signing-preparation only in this wave
- cross-surface product facts inherit from the exact platform owners listed
  below; this client contract must not fork them

Platform-owned contracts:

- product: `C:/Users/kiwun/Documents/ai/VPN/docs/product/portal-vpn-product.md`
- app-first identity and bonuses:
  `C:/Users/kiwun/Documents/ai/VPN/docs/architecture/app-first-and-bonus-flows.md`
- public client delivery:
  `C:/Users/kiwun/Documents/ai/VPN/docs/architecture/client-downloads-flow.md`
- publishing and signing:
  `C:/Users/kiwun/Documents/ai/VPN/docs/operations/publishing-and-signing-guide.md`
- shared machine facts: `C:/Users/kiwun/Documents/ai/VPN/shared/product-facts.json`

## Summary

`POKROV` is a `consumer-first`, `app-first` connectivity application.

The target user journey is:

1. open the app
2. tap `Try free`
3. choose how this device should work
4. receive a real working subscription
5. tap `Connect`

Telegram is optional for first launch, trial activation, and normal daily use.
It remains a recovery, reward, community, and fallback-support surface rather than the primary login wall.
Browser continuation currently starts from app handoff, Telegram, and the evidence-backed email continuation lane where delivery readiness is green.

## Locked Product Decisions

- product name: `POKROV`
- legacy client identifier: `POKROV VPN` only where compatibility removal is not yet feasible
- UX direction: `consumer-first`
- identity model: `app-first`
- public `v1` scope: `Android + Windows`
- Apple scope in this wave: readiness only
- default runtime core: `sing-box`
- `xray` role: advanced compatibility fallback only
- free trial: `5 days`
- Telegram reward: `+10 days`
- public user-facing version line: current paid beta evidence uses `1.0.0-beta`; patch/build labels such as `1.0.0-beta.3` are still beta labels, not stable `1.0.0` claims
- recommended public routing mode: `All except RU`
- public routing mode set: `All except RU` and `Full tunnel`
- public recovery order: `POKROV app -> web cabinet -> Telegram fallback`
- public wording may present POKROV as a VPN in client UI (owner decision `2026-06-13` in `docs/design/2026-06-13-pokrov-product-ui-direction.md`, aligned with the platform `2026-06-01` visible-wording rule); hidden/cloaked/stuffed usage and unsupported claims remain forbidden
- public browser surface split is checkout-first `marketing` plus continuation-first `webapp`
- the current client direction is `pokrov-clear`, approved on `2026-06-13`,
  and keeps the shell on `Protection / Locations / Rules / Profile` while
  public acquisition stays platform-owned

## Release Gate Reality

- `Android + Windows` remain the only public release pair for this wave
- the published `1.0.0-beta` handoff and `2026-05-15` decision pack are retained
  exact-candidate evidence; neither is reusable approval for a rebuild
- new public promotion and runtime sync are blocked until exact-candidate
  signing gates pass; a local build or an old public URL is not signing proof
- Android release builds require the operator-provided production signing
  inputs by default; debug signing is an explicit non-public smoke path only
- Windows unsigned packaging remains useful for gated engineering smoke, but
  it does not satisfy the current public-promotion signing gate
- the retained Android owner attestation is not raw physical-device evidence
  and does not prove signing for a later candidate
- the current green repo/static gate snapshot is necessary but not sufficient for future candidates; the `2026-05-15` beta pack includes runtime handoff validation, paid/email evidence, and separate `current-origin`, `brain-origin`, and accepted-skip `RU-origin` handling
- emulator or adb-only Android audits are valid preflight, not final release approval
- `iOS` and `macOS` readiness work does not block the public Android+Windows ship, but it also does not expand the public promise

## Target User Experience

### First launch

The user sees:

- a clear brand/trust message
- a `Try free` primary CTA
- short copy explaining that the trial activates on this device

The app should not require:

- Telegram login
- activation keys
- subscription URLs
- manual import as the primary path

### After trial activation

The client receives a real working profile, imports it silently, and lands on the daily-use shell.

Primary navigation:

1. `Protection`
2. `Locations`
3. `Rules`
4. `Profile`

Daily shell state language is shared across Home and support diagnostics:
`Подключаемся…`, `Подключено`, `Отключаем…`, and `Не защищено`. A disconnect
must never be described as a connection attempt. First-layer refresh copy says
that settings were updated without exposing the API hostname.

Nested under `Profile`:

- `Support`
- `Devices`
- `Subscription`
- `Settings`

Public consumer surfaces must not expose raw hostnames, ports, public IP, raw config editors, JSON/profile editors, or local-control surfaces in the first-layer path.

### Route-mode choice after activation

Before the first live route activation, the app must ask one calm consumer question:

- `How should this device work?`
- `Optimize everything on this device`
- `Only selected apps`

Product rules for that choice:

- the first choice is about device scope, not raw transport details
- `Optimize everything on this device` is the recommended default and stays `TUN`-first
- the device-wide path defaults the visible `Rules` story to `All except RU`
- `Full tunnel` stays available as the direct device-wide fallback
- `Only selected apps` is the P3 split-tunneling path for user-selected app or
  process identifiers
- Windows uses an executable/process picker for selected apps, backed by
  running-process, discovered `.exe`, and curated fallback candidates
- Android uses an installed-package picker for selected apps, with curated
  fallback candidates when the native catalog is unavailable
- manual process/package identifiers remain available only behind an explicit
  manual fallback row
- the chosen route mode must persist per device and remain editable later from a dedicated route-mode screen
- the live state must round-trip through backend-owned `route_mode`, `selected_apps`, `requires_elevated_privileges`, and mirrored `route_policy.*` fields
- current implementation exposes `All except RU`, `Full tunnel`, and
  `Only selected apps`; adding a custom app identifier auto-selects the
  selected-apps route and sends `selected_apps` through app-first route policy
- Windows `Rules` uses consumer route copy (`Режим работы`,
  `Российские сервисы`, `Выбранные приложения`) instead of Android-only bank,
  Gosuslugi, and marketplace presets
- `Rules` may show enabled/staged preset states so users know which rule
  categories are active; catalog/package versions belong in support
  diagnostics, not first-layer user copy
- `Rules` must not expose raw rule-set filenames, geo labels, CIDR, JSON,
  protocol names, ports, or engine internals in the normal UI
- selected-app picker, route-policy sync, persistence, and runtime
  materialization are beta-active on Android and Windows; public production
  behavior remains gated on exact-artifact physical-device and clean-VM proof
- raw selected-app rule editing remains hidden behind advanced/debug gates
- if the chosen desktop route mode requires elevation, the app must explain that before connect and guide the user to relaunch as administrator
- first-layer UX must not force users into raw system-proxy, service-mode, or low-level transport toggles

### Before trial activation

Before the device receives a real subscription payload:

- the onboarding card remains the primary connection surface
- `Locations` stays gated and must not show fake/demo countries
- `Support` may prepare context, but real ticket history appears only after a linked session exists
- Telegram remains optional and secondary

After activation:

- `Locations` shows `Автоматически` when the backend has not returned a
  shortlist yet
- when `smart_connect.shortlist` is present, `Locations` shows only those real
  eligible nodes and lets the user save a preferred node
- saved node choice is sent through `POST /api/client/nodes/select` with
  `mode=manual`, and the next managed profile may be fetched with
  `selected_node_code` before the runtime config is materialized
- trial and Telegram-bonus access must read as premium-pool access, never as
  `free node` access

### Renewal and purchase

- purchase and renewal stay available from the app
- the client continues payment through the canonical hosted checkout on `https://pay.pokrov.space/checkout/`
- checkout opens in the external browser or external application rather than native store billing in this wave
- Telegram purchase continuation may remain as a fallback path, not the default CTA
- public acquisition outside the app is checkout-first on `marketing`, while the cabinet stays a continuation surface rather than a second acquisition page

### Rewards and bonuses

- Account may show a compact bonus summary for Telegram reward, referrals,
  promo entry, and the latest safe bonus-history events
- Rewards Hub may show the referral code, safe Telegram referral link, tier
  state, and copy/share actions from `GET /api/bonuses/referral/summary`
- bonus history must stay compact and app-safe: no raw subscription links,
  full promo codes, tokens, hostnames, or backend event metadata
- Rewards Hub may show enabled first-party promo slots from
  `GET /api/client/promo-slots?surface=app`; disabled, third-party, or unsafe
  links must stay hidden or inactive
- wheel, roulette, activity calendar, achievements, and rich loyalty UI may be
  shown only as safe Rewards Hub previews while backend reward state is
  disabled
- wheel spin and calendar check-in buttons must remain disabled until reward
  logic, feature flags, rollout evidence, and copy are approved and backend
  state marks the mechanics enabled

## Support Direction

Support should be reachable from:

- the app
- the web cabinet
- helpbot `@pokrov_supportbot`
- `support@pokrov.space`

Support contract rules:

- support is a real ticket-backed flow, not decorative chat UI
- app support should prepare account and device context before handing the user into the ticket flow or fallback channels
- authenticated browser support should continue through `/api/tickets`, `/api/tickets/{ticket_id}`, `/api/tickets/{ticket_id}/messages`, and `/api/tickets/uploads`
- app support may attach redacted diagnostics on ticket creation and on one explicitly confirmed follow-up reply
- diagnostics should expose route mode, DNS policy, transport profile, ruleset/package-catalog version, app version, and linked Telegram state without leaking raw config, keys, or share links

## Smart Connect And Privacy Rules

Quick-connect rules:

- the backend builds the shortlist before the client starts latency checks
- premium users can probe up to `SMART_CONNECT_SHORTLIST_LIMIT` eligible non-free nodes, default `8`
- free-tier users stay on `NL-free` only
- shortlist eligibility rejects disabled, draining, unhealthy, stale, dataplane-down, saturated, high-loss/retransmit, overloaded, and transport-incompatible nodes while capacity-aware selection is enabled
- the client uses backend-provided internal probe targets and capacity hints, then posts `mode=auto` or `mode=manual` to `/api/client/nodes/select`; telemetry failure must not block connect
- the default stickiness threshold is `20%`
- explicit user-node assignments are provisioning/history state and must not reduce the premium candidate pool

Consumer privacy rules:

- normal consumer screens must not expose public IP, raw connection links, raw JSON/profile editors, sniffing terms, or low-level topology
- route labels and support diagnostics should stay safe and human-readable
- public-facing copy should prefer plain user language over transport acronyms, raw profile terms, or operator jargon
- Home and Profile may show `WARP` as the owner-approved feature label because
  the default runtime path is client-local Hiddify-core WARP. The UI must still
  avoid claiming production-proof anonymity or stronger privacy until
  Android/Windows release-build WARP evidence exists.
- raw subscription copy, edit, regenerate, or share actions stay out of the first-layer consumer path
- raw connection or subscription links must not be treated as account proof in
  first-launch restore or normal code redemption
- manual import and recovery tools may remain behind explicit compatibility or recovery surfaces

## Download And Release Continuity

Current public-facing download surfaces expose:

- Android `Play` / `APK` / mirror
- Windows `EXE` / mirror
- install/docs fallback when a direct public artifact is unavailable

Store/operator artifacts remain separate:

- Android `AAB`
- Windows `MSIX`
- Windows portable `ZIP`

Release continuity rules:

- public-facing build surfaces must present the beta line `1.0.0-beta` or an
  explicit beta patch label such as `1.0.0-beta.3`
- the `2026-05-15` Android handoff explains the retained beta publication but
  does not approve a replacement artifact; new public APK promotion requires
  exact-candidate production-signing evidence and the applicable device gates
- unsigned Windows bundles are non-public engineering smoke with a SmartScreen
  or unknown-publisher warning; public promotion requires trusted signing
- signed release builds inject updater and source metadata through the documented `PORTAL_RELEASE_*` environment variables
- local non-release builds keep updater and source-code surfaces disabled instead of falling back to a personal repository URL
- an update prompt or tap may hand off only to `https://github.com/Kiwunaka/pokrov/releases/download/<tag>/<asset>` when metadata also carries a 64-hex SHA-256 and a positive byte size; alternate hosts, repositories, URL authority fields, query strings, and fragments fail closed
- this is an external-browser handoff boundary, not downloaded-byte verification: the app does not receive or hash the browser's bytes, so checksum, install, signing, and exact-candidate runtime proof remain manual release gates
- release handoff must keep app, bot, and authenticated web surfaces aligned with the same runtime `APP_*` URLs

## Branding Requirements

All public and user-visible client surfaces must ship as `POKROV`.

Replace or keep aligned:

- app name strings
- launcher icons
- splash assets
- tray icons
- update metadata
- release artifact names
- visible inherited `Hiddify` references in UI
- the canonical public URI scheme `pokrov`

Host behavior:

- Android uses the canonical POKROV mark for adaptive launcher and Android 12+
  splash surfaces; edge-to-edge system chrome must preserve safe areas and
  theme-matched system icon contrast.
- Windows opens centered, remains resizable down to the 700 px compact/drawer
  lane, and treats window close as hide-to-tray. The explicit tray `Выход`
  action requests native teardown; exact-artifact runtime shutdown and system
  proxy restoration remain a manual release check.

Compatibility-only residue may still exist in internal identifiers, imports, namespaces, or hidden handlers such as `pokrovvpn://`, but it must not define the user-facing product story.

## v1 Scope

In scope:

- app-first trial activation
- silent profile provisioning
- route-mode onboarding with `Optimize everything on this device` and `Only selected apps`
- quick connect with smart-connect shortlist behavior
- locations list with real smart-connect shortlist selection when backend data
  is present
- device management
- subscription and renewal continuation
- in-app and cabinet-backed support continuation
- Telegram reward `+10 days`
- advanced routing modes `All except RU` and `Full tunnel`
- safe diagnostics and recovery actions

Out of scope:

- forced Telegram login
- admin tooling inside the client
- manual config import as the primary onboarding path
- public `Blocked only` routing until routing assets, DNS behavior, and leak checks are verified
- public `iOS` App Store launch
- public `macOS` distribution promise
