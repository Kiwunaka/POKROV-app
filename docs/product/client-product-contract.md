# POKROV Client Product Contract

Last updated: 2026-04-25

## Document Status

This file is the living client product contract for `POKROV-app/main`.

## Scope

This repo is the canonical client-development lane for `POKROV`.

- public `v1` scope: `Android + Windows`
- `iOS` and `macOS`: readiness, packaging, and signing-preparation only in this wave
- cross-surface product facts inherit from the platform canon in `C:/Users/kiwun/Documents/ai/VPN/docs/`

## Summary

`POKROV` is a `consumer-first`, `app-first` connectivity application.

The target user journey is:

1. open the app
2. complete the short three-step Russian onboarding
3. choose how this device should work
4. receive a real working subscription
5. tap the main connection action

Telegram is optional for first launch, trial activation, and normal daily use.
It remains a recovery, reward, community, and fallback-support surface rather than the primary login wall.
Browser continuation currently starts from app handoff and Telegram.
Additive email auth for the site and cabinet is marked `soon` and must stay explicitly labeled that way until the public launch path is really live.

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
- public user-facing version line: current paid beta evidence uses `0.2.0-beta.1`, preserving the `0.x.x-beta` train
- recommended public routing mode: `All except RU`
- public routing mode set: `All except RU` and `Full tunnel`
- public recovery order: `POKROV app -> web cabinet -> Telegram fallback`
- public wording must avoid direct-meaning `VPN` copy outside legacy compatibility labels
- public browser surface split is checkout-first `marketing` plus continuation-first `webapp`, with public email continuation still marked `soon`
- the current front-end reset is atlas-driven and keeps the client shell locked to `Подключение / Локации / Правила / Профиль` while public acquisition moves to `marketing`

## Release Gate Reality

- `Android + Windows` remain the only public release pair for this wave
- `Windows` may proceed when its documented release gates are green
- `Android` remains blocked until a release-installed build passes the localhost and local-control-surface audit on physical hardware
- the current green repo/static gate snapshot is necessary but not sufficient; public release still needs production signing, runtime handoff validation, and separate `current-origin`, `brain-origin`, and `RU-origin` evidence
- emulator or adb-only Android audits are valid preflight, not final release approval
- `iOS` and `macOS` readiness work does not block the public Android+Windows ship, but it also does not expand the public promise

## Target User Experience

### First launch

The user sees:

- a clear brand/trust message
- the real POKROV mark from the checked-in brand asset
- a Russian trial-start primary CTA
- short copy explaining that the trial activates on this device

The app should not require:

- Telegram login
- activation keys
- subscription URLs
- manual import as the primary path

### After trial activation

The client receives a real working profile, imports it silently, and lands on the daily-use shell.

Primary navigation in the Russian client shell:

1. `Подключение`
2. `Локации`
3. `Правила`
4. `Профиль`

Nested under `Профиль`:

- `Поддержка`
- `Устройства`
- `Подписка`
- `Настройки`

Shell design rule:

- the current Flutter shell uses the white/mint premium utility direction
- Android uses the compact tab layout
- Windows uses a desktop sidebar and constrained card-grid surface instead of a stretched phone layout
- the app exposes `System`, `Light`, and `Dark` theme choices from `Профиль -> Настройки`
- first-layer copy is Russian and avoids raw protocol, config, host, or personal-link internals
- the shell has one current redesign contract; do not preserve a separate old redesign path or alternate subtitle treatment
- visible brand copy stays `POKROV`; old subtitle lines and longer trial promises are stale

Public consumer surfaces must not expose raw hostnames, ports, public IP, raw config editors, JSON/profile editors, or local-control surfaces in the first-layer path.

### Route-mode choice after activation

Before the first live route activation, the app must ask one calm consumer question:

- `How should this device work?`
- `Optimize everything on this device`
- `Only selected apps`

Product rules for that choice:

- the first choice is about device scope, not raw transport details
- `Optimize everything on this device` is the recommended default and stays `TUN`-first
- the device-wide path defaults the visible `Правила` story to `Все, кроме РФ`
- `Full tunnel` stays available as the direct device-wide fallback
- `Only selected apps` is the split-tunneling path
- Windows should use an executable or process picker for selected apps
- Android should use an installed-package picker for selected apps
- the chosen route mode must persist per device and remain editable later from a dedicated route-mode screen
- the live state must round-trip through backend-owned `route_mode`, `selected_apps`, `requires_elevated_privileges`, and mirrored `route_policy.*` fields
- current implementation keeps both device-wide routes on the existing backend `route_mode=all_traffic` lane, while the split path writes `route_mode=selected_apps`
- current selected-apps beta MVP is explicit: route-mode sync exists, but Android package picking, Windows process picking, persistence, and OS-level enforcement are not yet complete
- if the chosen desktop route mode requires elevation, the app must explain that before connect and guide the user to relaunch as administrator
- first-layer UX must not force users into raw system-proxy, service-mode, or low-level transport toggles

### Before trial activation

Before the device receives a real subscription payload:

- the onboarding card remains the primary connection surface
- `Локации` stays gated and must not show fake/demo countries
- `Support` may prepare context, but real ticket history appears only after a linked session exists
- Telegram remains optional and secondary

### Renewal and purchase

- purchase and renewal stay available from the app
- the client continues payment through the canonical hosted checkout on `https://pay.pokrov.space/checkout/`
- checkout opens in the external browser or external application rather than native store billing in this wave
- browser, Telegram, feedback, support, and redeem handoffs should call a real external-link launcher; where a host has not implemented a launcher plugin yet, the shared shell must keep an explicit testable launcher abstraction instead of relying on snackbar-only copy
- Telegram purchase continuation may remain as a fallback path, not the default CTA
- public acquisition outside the app is checkout-first on `marketing`, while the cabinet stays a continuation surface rather than a second acquisition page

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
- diagnostics should expose route mode, DNS policy, transport profile, ruleset/package-catalog version, app version, and linked Telegram state without leaking raw config, keys, or share links

## Smart Connect And Privacy Rules

Quick-connect rules:

- the backend builds the shortlist before the client starts latency checks
- premium users probe up to `5` eligible non-free nodes
- free-tier users stay on `NL-free` only
- shortlist eligibility rejects disabled, draining, unhealthy, stale, overloaded, and transport-incompatible nodes
- the client combines device RTT with backend CPU and health penalties and uses a `15%` stickiness threshold before changing nodes
- explicit user-node assignments still take precedence

Consumer privacy rules:

- normal consumer screens must not expose public IP, raw connection links, raw JSON/profile editors, sniffing terms, or low-level topology
- route labels and support diagnostics should stay safe and human-readable
- public-facing copy should prefer plain user language over transport acronyms, raw profile terms, or operator jargon
- raw subscription copy, edit, regenerate, or share actions stay out of the first-layer consumer path
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

- public-facing build surfaces must present the beta line `0.x.x-beta`
- Android APK distribution is internal beta only until trusted signing and physical localhost/control-surface audit pass
- Windows unsigned bundles may be gated to beta users only with a SmartScreen or unknown-publisher warning
- signed release builds inject updater and source metadata through the documented `PORTAL_RELEASE_*` environment variables
- local non-release builds keep updater and source-code surfaces disabled instead of falling back to a personal repository URL
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

Compatibility-only residue may still exist in internal identifiers, imports, namespaces, or hidden handlers such as `pokrovvpn://`, but it must not define the user-facing product story.

## v1 Scope

In scope:

- app-first trial activation
- silent profile provisioning
- route-mode onboarding with `Optimize everything on this device` and `Only selected apps`
- quick connect with smart-connect shortlist behavior
- locations list
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
