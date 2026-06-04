# POKROV Client Build Readiness And API Plan

Date: 2026-06-03
Status: implementation planning brief
Decision owner: owner/operator

## Purpose

Record the build-readiness consilium for the future POKROV Android/Windows
client and turn it into a practical implementation plan.

This document answers:

- what can start immediately;
- what must be decided before coding the fork;
- what API contracts are already usable;
- what API contracts must be added or wrapped by adapters;
- what must stay behind feature flags;
- what gates block the first public beta.

## Consilium Inputs

OpenCode-go models:

- `qwen3.7-max`: architecture and phase plan.
- `deepseek-v4-pro`: blockers, contradictions, release risks.
- `minimax-m3`: execution order, QA gates, feature flags.
- `glm-5.1`: backend/API integration and adapter strategy.
- `kimi-k2.6`: product simplicity, migration wording, owner decisions.
- `mimo-v2.5-pro`: lean first-build scope.

Local synthesis keeps POKROV canon above model output.

## Executive Verdict

Start with a runtime spike now.

Do not start a broad UI build until the runtime spike proves that a
Hiddify-based fork can build and run on Android and Windows with POKROV-managed
profiles.

The backend already covers most of the first app path:

- app-first trial;
- managed profile;
- smart-connect shortlist;
- latency upload;
- access-key status/redeem;
- app-facing unified redeem for access keys;
- short-lived app -> cabinet handoff token;
- Telegram link/check/claim;
- dashboard/access state;
- tickets.

The biggest immediate risk is not the visual shell. It is the fork/runtime gate:

- missing `hiddify-core/bin` artifacts;
- Windows core build requirements;
- provenance/license packet;
- Hiddify rebrand/telemetry/updater/deeplink cleanup.

The first build should be narrow:

- app-first start;
- restore/code entry;
- managed profile connect/disconnect;
- Locations;
- Rules presets;
- Profile access state;
- Telegram bonus;
- support entry.

Do not include roulette, calendar, rich referral UI, full advanced editor, or
casino-like bonus surfaces in the first build.

## Decisions To Lock Before Coding The Fork

### P0 Owner/Architecture Decisions

These should be locked before forking/copying Hiddify code:

1. Hiddify fork provenance:
   - upstream commit/tag or source snapshot;
   - GPL/notice obligations;
   - what is copied, forked, or only studied;
   - where NOTICE/LICENSE attribution appears.
2. Runtime build stack:
   - Go `1.25.6`;
   - Android NDK target ABIs;
   - Windows MinGW toolchain;
   - CI or local reproducible build path;
   - artifact naming and checksums.
3. App identity:
   - Android package name;
   - Windows app identity/product name;
   - deep link scheme, recommended `pokrov://`;
   - canonical app/cabinet handoff URLs.
4. Hiddify cleanup policy:
   - remove/replace Hiddify branding;
   - remove/replace Sentry DSN;
   - remove/replace updater endpoints;
   - replace public links, deep links, package IDs, release metadata.
5. `install_id` and session persistence:
   - where it is stored;
   - behavior after app reinstall;
   - retry/idempotency policy for `start-trial`;
   - whether repeated `start-trial` for the same `install_id` returns existing
     account/session.
6. Russia smart mode:
   - ask the user on first launch or auto-select by chosen country;
   - backend-owned ruleset catalogue and kill-switch;
   - wording approved for users in Russia.
7. Windows scope:
   - Android and Windows stay v1 targets;
   - if Windows core fails, Android can continue but Windows public claims stay
     blocked.
8. Windows signing/distribution:
   - signed beta, unsigned beta with clear warning, or delayed Windows build;
   - update path: GitHub Releases first, in-app updater later.

### Decisions That Can Be Locked During P0

- WARP/chain-like `Усиленный режим`: P1 unless runtime makes it cheap and safe.
- full tunnel as first-layer mode: keep advanced/secondary until Russia smart
  mode and selected-app mode are proven.
- app-facing roulette/calendar: feature-flagged, post-P0.
- app diagnostics upload: P1 after redaction contract.
- cabinet SSO: P0 API contract, UI may degrade until endpoint is live.

## Existing Backend Contracts Usable Now

Use these endpoints for the runtime spike and first app implementation:

- `POST /api/client/session/start-trial`
- `GET /api/client/profile/managed`
- `POST /api/client/nodes/latency-samples`
- `POST /api/client/telegram/link`
- `POST /api/channel/subscriber/check`
- `POST /api/bonuses/channel/claim`
- `GET /api/access-keys/status/{key}`
- `POST /api/access-keys/redeem`
- `POST /api/redeem`
- `POST /api/client/cabinet-token`
- `GET /api/dashboard`
- `GET /api/client/apps`
- `GET /api/nodes/status`
- `GET /api/bonuses`
- `/api/tickets/*`
- `/api/auth/email/*`

## Required API Contracts

### P0 Contracts

These are required for the intended app-first P0 experience.

#### Start Trial Idempotency

Endpoint:

```text
POST /api/client/session/start-trial
```

Must define:

- repeated request with the same `install_id`;
- whether the backend returns existing account/session with `200`;
- whether device metadata is updated on retry;
- structured response for blocked/abuse states;
- no caller-controlled trial length.

Preferred rule:

- same `install_id` returns existing app-first account/session and current access
  state, not a duplicate trial.

#### Managed Profile Schema

Endpoint:

```text
GET /api/client/profile/managed
```

Must expose stable fields for the client:

- `schema_version`;
- `profile_revision`;
- `engine_hint`;
- `config_format`;
- `config_payload`;
- `client_policy`;
- `route_policy`;
- `ruleset_version`;
- `package_catalog_version`;
- `smart_connect.shortlist`;
- feature flags relevant to this profile.

Route/rules fields must be enough to render:

- Russia smart mode;
- selected-apps mode;
- current route mode;
- app/process selection state where applicable;
- whether elevated rights are required.

#### Route Mode Read/Update

Preferred endpoint:

```text
GET /api/client/route-mode
PUT /api/client/route-mode
```

Adapter option:

- keep route mode in `client_policy` / `managed profile` if current backend
  already round-trips it.

Must support:

- `smart_ru` or equivalent;
- `selected_apps`;
- advanced/full tunnel when allowed;
- selected app package/process identifiers;
- `ruleset_version`;
- backend validation and rollback-safe response.

#### Unified Redeem

Preferred endpoint:

```text
POST /api/redeem
```

Purpose:

- one app-facing code entry for access keys, gift codes, promo codes, Telegram
  link codes, cabinet claim tokens, email magic/recovery codes.

Implementation status as of `2026-06-03`:

- `POST /api/redeem` is live for the first app-facing slice.
- supported kind: `access_key`.
- access-key redemption reuses the same backend path as
  `POST /api/access-keys/redeem` and returns the access/provisioning payload in
  `result`.
- raw subscription/proxy URLs are rejected with
  `subscription_link_not_redeem_code`.
- endpoint backpressure uses the backend `unified_redeem` rate-limit scope.
- gift, promo, Telegram link, email magic/recovery, and cabinet claim token
  routing remain follow-up kinds for the same facade.

Adapter allowed for first implementation:

- route access keys through `GET /api/access-keys/status/{key}` and
  `POST /api/access-keys/redeem`;
- route Telegram linking through `POST /api/client/telegram/link`;
- route email/recovery through existing email auth endpoints;
- keep UI stable so only the adapter changes when `/api/redeem` lands.

Security rule:

- raw subscription links are not account proof.
- raw subscription links go only to manual/recovery import with warning.

#### Short-Lived Cabinet Token

Preferred endpoint:

```text
POST /api/client/cabinet-token
```

Must define:

- TTL, target `60-120 seconds`;
- single-use behavior;
- allowed target path;
- session scope;
- revocation/failed exchange semantics;
- no long-lived token in query string.

Implementation status as of `2026-06-03`:

- `POST /api/client/cabinet-token` is live for app-session callers.
- the endpoint accepts only relative `target_path` values.
- returned handoff URLs use canonical `https://app.pokrov.space/`, even when a
  local/legacy `WEBAPP_URL` is configured.
- token TTL is clamped to `60..120` seconds and uses
  `auth_origin=app_cabinet_handoff` plus `scope=cabinet_handoff`.
- normal authenticated API calls reject the handoff token directly with
  `web_session_exchange_required`; the webapp must exchange it first.
- `POST /api/auth/cabinet-handoff/exchange` is live and single-use through a
  backend token-hash ledger; successful exchange returns the browser session
  token used by the cabinet.
- endpoint backpressure uses backend `cabinet_token` and
  `cabinet_handoff_exchange` rate-limit scopes.
- the app shell now opens cabinet through this handoff when the injected
  bootstrapper supports account actions.

#### Bonus Summary MVP

Preferred endpoint:

```text
GET /api/client/bonuses/summary
```

P0 content:

- Telegram reward status;
- bonus days total;
- recent bonus history;
- promo/redeem eligibility;
- referral summary if backend already supports it.

Adapter option:

- aggregate from `GET /api/bonuses` and `GET /api/dashboard` until summary lands.

Wheel/calendar remain out of P0.

#### Feature Flags

Preferred source:

- inside `client_policy` / managed profile response.

Alternative:

```text
GET /api/client/feature-flags
```

Must cover:

- roulette;
- calendar;
- referral summary;
- promo redeem UI;
- cabinet token;
- diagnostics upload;
- service notifications;
- Xray fallback;
- advanced settings;
- route modes.

### P1 Contracts

- `POST /api/client/diagnostics` or ticket upload adapter with redaction
  contract.
- `GET /api/client/notifications`
- `GET /api/client/referrals/summary`
- `POST /api/client/promos/redeem` if not covered by unified redeem.
- full ruleset catalogue endpoint if not fully embedded in managed profile.

### P2 Contracts

- `GET /api/client/bonuses/wheel/state`
- `POST /api/client/bonuses/wheel/spin`
- `GET /api/client/bonuses/calendar`
- `POST /api/client/bonuses/calendar/checkin`
- achievements/streak ledger.

## Runtime Spike Order

Do this before broad UI implementation.

1. Hiddify provenance and workspace decision:
   - identify exact source snapshot;
   - record license/NOTICE requirements;
   - create fork branch/worktree only after provenance is recorded.
2. Core build spike:
   - Android arm64;
   - Windows x64;
   - fixed Go/MinGW/NDK versions;
   - checksums for generated artifacts.
3. Minimal Flutter runner:
   - build Android debug;
   - build Windows debug;
   - launch without inherited Hiddify user-visible branding.
4. Managed profile parse:
   - call `GET /api/client/profile/managed`;
   - parse manifest;
   - feed sing-box config into the runtime boundary.
5. Connect/disconnect loop:
   - start tunnel;
   - verify traffic;
   - stop tunnel;
   - verify cleanup;
   - keep Xray fallback disabled by default.
6. App-first trial contour:
   - generate/persist `install_id`;
   - call `start-trial`;
   - load managed profile;
   - connect;
   - confirm dashboard/access shows `5 days`.
7. Smart-connect contour:
   - use shortlist;
   - measure RTT;
   - upload latency samples;
   - apply stickiness.
8. Rebrand smoke:
   - no Hiddify app ID;
   - no Hiddify deep links;
   - no Hiddify updater endpoint;
   - no Hiddify Sentry/project telemetry;
   - no inherited public support links.

Runtime spike exit criteria:

- Android debug connects to a test/real POKROV managed profile.
- Windows debug starts the core and either connects or produces a documented
  platform blocker.
- Rebrand smoke is clean enough to continue UI work.
- Runtime failures are documented as `BLOCKED_BY_BUILD`, not hidden behind UI.

## Implementation Phases

### Phase 0: Foundation And Runtime

- provenance/license packet;
- Hiddify fork/build workspace;
- core artifacts;
- POKROV app identity/deep links;
- basic Flutter build on Android and Windows;
- managed profile parse;
- connect/disconnect loop;
- app-first trial contour;
- rebrand smoke.

### Phase 1: POKROV Shell And Protection

- typed Flutter theme from design tokens;
- mobile four-tab shell;
- Windows rail/sidebar shell;
- circular `128dp` connect control;
- connection states;
- dashboard/access summary;
- smart-connect shortlist use;
- latency upload.

Gate:

- new install -> trial -> managed profile -> connect -> dashboard access state.

### Phase 2: Restore, Profile, Telegram Bonus

- first launch `new / returning` split;
- in-app code entry;
- `RedeemAdapter` over current endpoints or `/api/redeem`;
- Profile access summary;
- Telegram link/check/claim;
- `+10 days` bonus refresh in app/bot/cabinet.

Gate:

- restore works with access key and at least one claim/link flow.
- Telegram bonus can be claimed once and duplicate claim is safe.

### Phase 3: Locations And Rules

- Locations screen from shortlist/node status;
- manual location choice;
- route-mode read/update;
- Russia smart mode;
- selected-apps mode;
- ruleset versioning;
- backend kill-switch for risky rulesets.

Gate:

- Russia mode tested on target services from an appropriate vantage point when
  access exists.
- if RU-origin test access is unavailable, record `BLOCKED_BY_ACCESS` or
  `MANUAL_OWNER_TEST`.

### Phase 4: Support, Cabinet, Paywall

- support entry and ticket creation;
- redacted diagnostics upload or ticket attachment adapter;
- short-lived cabinet token;
- paywall after prices/plans/renewal copy are approved;
- payment/redeem continuation.

Gate:

- diagnostics are redacted;
- cabinet token is short-lived and single-use;
- paywall has no unsupported claims.

### Phase 5: Loyalty And Advanced

- bonus summary/referral/promo surfaces;
- roulette/calendar only after APIs and feature flags;
- advanced warning gate;
- Xray fallback behind advanced only;
- reset to recommended;
- validation and rollback.

Gate:

- feature flags disable unfinished surfaces without a release.
- advanced settings cannot break normal users without warning and recovery.

## Feature Flags

Default off unless noted otherwise:

- `feature.cabinet_token`
- `feature.bonus_summary`
- `feature.referral_summary`
- `feature.promo_redeem`
- `feature.roulette`
- `feature.calendar`
- `feature.service_notifications`
- `feature.diagnostics_upload`
- `feature.xray_fallback`
- `feature.raw_subscription_import`
- `feature.full_tunnel`
- `feature.selected_apps`
- `feature.russia_smart_mode`
- `feature.ad_tracker_blocking`
- `feature.auto_update`
- `feature.windows_sidebar`

Rules:

- a feature flag must gate both UI entry and API calls.
- no dead UI for disabled features.
- no feature-flagged surface may appear in public copy before backend support is
  live.
- `feature.xray_fallback` and `feature.raw_subscription_import` require advanced
  warning gate even when enabled.

## Test And Release Gates

### Build Gates

- Android core artifact builds and starts.
- Windows core artifact builds and starts, or Windows is marked blocked.
- Flutter Android debug build runs.
- Flutter Windows debug build runs.
- generated artifacts have checksums.

### Runtime Gates

- `start-trial` idempotency verified.
- managed profile parse verified.
- connect/disconnect verified.
- tunnel cleanup verified.
- latency upload verified.
- Xray fallback remains disabled by default.

### Product Gates

- first launch new path works.
- first launch returning path works.
- restore code path works.
- Telegram link/check/claim works.
- bonus days and paid days display separately.
- Profile and bot/cabinet tell the same access story.

### Route Gates

- smart-connect uses backend shortlist.
- node stickiness prevents flapping.
- route mode round-trips through backend.
- ruleset version shown in diagnostics/support context.
- Russia smart mode has current ruleset evidence or is feature-flagged off.

### Support/Security Gates

- diagnostics redact secrets.
- raw links are hidden from normal UI.
- logs do not contain tokens.
- cabinet token is short-lived/single-use.
- advanced settings require warning, checkbox, and second confirmation.
- failed advanced config rolls back.

### Release Claim Gates

Do not claim:

- store availability;
- stable `1.0.0`;
- trusted Windows signing;
- RU-origin readiness;
- raw Android physical-audit proof;
- YouTube ad-free;
- absolute anonymity;
- support SLA;

unless current evidence exists and is recorded.

## Review Reject Checklist

Reject implementation if it includes:

- Hiddify branding, deep links, updater URLs, Sentry DSN, app ID, or public
  support links in POKROV production UI/builds.
- Karing source merged into a Hiddify fork without a separate GPL/provenance
  decision.
- Xray as default core.
- Xray fallback outside advanced settings.
- raw subscription links in normal UI.
- `sing-box`, `Xray`, protocols, ports, CIDR, JSON, hostnames, or raw topology in
  normal UI.
- Telegram or email as mandatory login wall.
- restore flow that starts by forcing Telegram instead of in-app code entry.
- roulette/calendar/referral UI without backend API and feature flag.
- diagnostics upload without redaction contract.
- unsupported paywall or safety claims.
- Windows bottom tabs.
- central `VPN` tab.
- ping milliseconds on Protection.

## Owner Decisions Still Needed

1. Hiddify fork provenance:
   - source snapshot;
   - public fork strategy;
   - attribution/NOTICE handling.
2. App identity:
   - Android package;
   - Windows product ID;
   - deep link scheme.
3. Runtime build owner:
   - who owns Go/MinGW/NDK setup and proof artifacts.
4. `start-trial` retry semantics:
   - repeated `install_id` returns existing session/access state.
5. Managed profile schema:
   - route/rules fields and schema version.
6. Russia smart mode:
   - ask user vs auto by chosen region;
   - who owns ruleset updates;
   - launch enabled or feature-flagged.
7. Unified redeem:
   - `2026-06-03`: built `/api/redeem` first slice for access keys; expand
     supported code kinds later.
8. Cabinet token:
   - `2026-06-03`: built short-lived app -> cabinet handoff plus one-time
     webapp exchange.
9. Diagnostics:
   - minimum redaction policy before any upload.
10. Windows beta posture:
    - signed/unsigned/delayed.
11. WARP/Enhanced mode:
    - P1 feature flag unless runtime proves it is safe for P0.
12. Paywall:
    - approved prices, plans, renewal wording, and forbidden claims.
13. P0 bonus scope:
    - Telegram only, or Telegram + referral/promo summary if backend is ready.

## Minimal Start Checklist

Before the next coding wave starts:

- [ ] record Hiddify provenance/license decision.
- [ ] prove or fail Android `hiddify-core` build.
- [ ] prove or fail Windows `hiddify-core` build.
- [ ] create POKROV app ID/deep link constants.
- [ ] define `install_id` persistence and `start-trial` idempotency.
- [ ] define managed profile schema fields needed by the client.
- [x] decide `/api/redeem` vs `RedeemAdapter`: build `/api/redeem` first.
- [x] decide cabinet token timing: P0 short-lived handoff plus single-use
  webapp exchange are live.
- [ ] decide Russia smart-mode launch posture.
- [ ] keep roulette/calendar/referral rich UI out of P0 unless APIs are live.

## One-Line Plan

Prove the Hiddify runtime first, then build the POKROV shell around the existing
app-first backend, using adapters for redeem/bonus gaps and feature flags for
everything not backed by current API evidence.
