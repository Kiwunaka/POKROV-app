# POKROV Client Product Contract

Last updated: 2026-08-18

## Document Status

This file is the living client product contract for `POKROV-app/main`.

## Scope

This repo is the canonical client-development lane for `POKROV`.

- public `v1` scope: `Android + Windows`
- native `iOS` and `macOS`: readiness, packaging, and signing-preparation only in this wave; Apple users keep a platform-owned authenticated compatible-client key path until those clients ship
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
- Android and Windows onboarding uses only the official APK/EXE plus managed login; raw subscription keys are reserved for the authenticated Apple compatibility path
- default runtime core: `sing-box`
- `xray` role: advanced compatibility fallback only
- free trial: `5 days`
- Telegram acquisition reward: `+5 days` once per account before or after the
  first payment. Wheel, calendar, and referral rewards remain paid-only. Already-issued
  `+10 days` grants remain grandfathered and must render with their
  backend-returned value
- public user-facing version line: `1.1.2` release candidate; `1.1.1` remains the stable runtime until exact artifacts are uploaded and synchronized; beta/prerelease candidates
  are an explicit opt-in lane and never replace stable metadata implicitly
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
  historical exact-candidate evidence; neither is reusable approval for a rebuild
- `v1.1.1` is the current public stable direct release and its production
  runtime sync is complete. Every later promotion still requires fresh
  exact-candidate signing and release proof; a local build or old public URL is
  not signing proof
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

Home uses the owner-selected `2026-08-13` composition: a compact brand/access
top row, one centered circular connect action with a thin non-glowing border,
in-control status and a finite hourglass busy state, then two quick controls,
WARP and an optional remote campaign above navigation. The premium-day pill
opens Profile, where subscription details and renewal remain explicit. A visible
notification bell opens the cached/refreshed in-app inbox from Home. Telegram
reward does not occupy Home's first layer.

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
- `Only selected apps` requires at least one selected app. An empty selection
  blocks connect and route-policy sync, keeps the device unprotected, and
  directs the user to add an app in `Rules`; it must never fall back to a
  device-wide tunnel.
- Android also exposes `Except selected apps`: selected packages bypass
  `VpnService`, while every other package uses POKROV. It requires a non-empty
  selection and is materialized locally; backend route policy remains the
  device-wide contract and must not reinterpret the excluded list as an
  allow-list.
- Windows uses an executable/process picker for selected apps, backed by
  running-process, discovered `.exe`, and curated fallback candidates
- Android uses a searchable installed-package picker for selected apps and
  keeps every launcher package discoverable; native icon encoding is bounded
  independently so large Huawei catalogs do not disappear behind slow bitmap
  work. Curated fallback candidates remain available when the native catalog
  is unavailable
- Android locally matches installed launcher packages against the reviewed,
  versioned exact-ID RU catalog. Known RU apps sort first and can be filtered;
  an unknown app remains searchable and is never classified from its display
  name alone. Neither the installed list nor the matches leave the device
- two explicit confirmed presets are available: `RU-приложения напрямую,
  остальные через VPN` materializes Android `Except selected apps`; `Только
  выбранные RU-приложения через VPN` materializes `Only selected apps`. The
  preview names every matched app and an empty match cannot be applied silently
- manual process/package identifiers remain available only behind an explicit
  manual fallback row
- the chosen route mode must persist per device and remain editable later from a dedicated route-mode screen
- the live state must round-trip through backend-owned `route_mode`, `selected_apps`, `requires_elevated_privileges`, and mirrored `route_policy.*` fields
- current implementation exposes `All except RU`, `Full tunnel`, and
  `Only selected apps` on both clients, plus Android-only `Except selected
  apps`; adding a custom app identifier auto-selects the selected-apps route
  and sends `selected_apps` through app-first route policy
- selected-app identifiers are device-local, survive app restart, normalized,
  and capped at 128; an empty selected-apps list still blocks connection
- Windows `Rules` uses consumer route copy (`Режим работы`,
  `Российские сервисы`, `Выбранные приложения`) instead of Android-only bank,
  Gosuslugi, and marketplace presets
- `Rules` may show enabled/staged preset states so users know which rule
  categories are active; catalog/package versions belong in support
  diagnostics, not first-layer user copy
- `Rules` must not expose raw rule-set filenames, geo labels, CIDR, JSON,
  protocol names, ports, or engine internals in the normal UI
- selected-app picker, route-policy sync, persistence, and runtime
  materialization are active on Android and Windows. Exact physical-device and
  clean-VM evidence remains required for stronger platform-wide claims
- picker rows disambiguate duplicate consumer labels without exposing package
  or executable identifiers, announce selected/available state to assistive
  technology, and remain usable above the on-screen keyboard
- raw selected-app rule editing remains hidden behind advanced/debug gates
- if the chosen desktop route mode requires elevation, the app must explain that before connect and guide the user to relaunch as administrator
- first-layer UX must not force users into raw system-proxy, service-mode, or low-level transport toggles

### Before trial activation

Before the device receives a real subscription payload:

- the onboarding card remains the primary connection surface
- `Locations` may show only a real backend or cached catalog for search and
  favorites, never fake/demo countries; server selection stays locked until a
  managed access payload and Smart Connect profile exist, with an explicit
  first-connect explanation instead of a silently ignored tap
- `Support` may prepare context, but real ticket history appears only after a linked session exists
- Telegram remains optional and secondary

After activation:

- `Locations` shows `Автоматически` when the backend has not returned a
  shortlist yet
- cached location latency/load values render only while their measurement is
  fresh; stale, future-dated, or invalid timestamps keep a neutral freshness
  warning but suppress numeric and qualitative health values plus any
  healthy-colored signal indicator; missing or out-of-range health scores also
  stay neutral
- when `smart_connect.shortlist` is present, `Locations` shows only those real
  eligible nodes and lets the user save a preferred node
- saved node choice is sent through `POST /api/client/nodes/select` with
  `mode=manual`, and the next managed profile may be fetched with
  `selected_node_code` before the runtime config is materialized
- a catalog city may carry a safe additive `variants` list. One available
  variant keeps the one-tap location path; multiple available variants open a
  compact `Обычный` / `Белые списки` choice. The selected stable variant id is
  device-local and persists alongside the explicit preferred node; it is
  cleared when the person returns to `Автоматически`
- for the selected city, Android probes the exact already-staged private
  URL-test group and projects only safe variant ID, availability, measured
  latency/freshness and active variant ID. Endpoint/tag/key/profile material
  never crosses the host bridge. The sheet distinguishes `Выбрано` from
  `Сейчас работает`, shows red unavailable state, fresh/stale age, supports
  refresh-all and per-row retry, and sorts available/fast before unknown,
  stale and unavailable. A URL-test is reachability evidence for that outbound,
  not proof of Chrome or another app's egress
- when the selected variant itself fails, Android keeps the TUN fail-closed for
  one bounded all-variant URL-test before stopping. The sheet may then reuse
  only the exact-catalog in-memory safe snapshot for two minutes, with no
  `Сейчас работает` claim after teardown; raw topology is never persisted
- when multiple variants exist, the city row itself names `Обычный / Белые
  списки` (or an equally explicit short list) before the person taps it. A bare
  numeric variant count is not sufficient discovery and must not make the live
  capability look absent
- a manual `Обычный` choice resolves only to the canonical base outbound for
  that node. A `Белые списки` choice resolves only through a unique safe
  `_meta.ru_bridge.endpoints[{id,label}]` entry and the exact corresponding
  member of the final selector. Missing, ambiguous, stale, or non-member
  mappings fail closed without exposing or guessing raw topology
- an explicit saved node is fail-closed: its code must remain in the returned
  eligible Smart Connect shortlist and map unambiguously to a direct proxy in
  the returned profile. The canonical identity is the shortlist item's
  `outbound_tag`; while older deployed servers omit that field, the client may
  use the raw node code, the deterministic legacy localized tag, or a unique
  probe host/port match in that order. The resolved tag must still be a member
  of the final selector. A mismatch, ambiguity, or stale cached profile must
  show that the selected location is unavailable instead of connecting
  through a different displayed location
- when a saved manual location becomes unavailable, `Locations` still lets the
  user explicitly return to `Автоматически` before the first successful
  connection; that action clears the device-local manual preference and the
  next managed-profile request uses Smart Connect without a manual node code
- server-reported Smart Connect stickiness is an automatic routing hint and
  must not be persisted as a device-local manual location; only an explicit
  user selection may add `selected_node_code` to later profile requests
- the node resolved by an automatic connection is runtime evidence, not a
  saved manual preference. After disconnect or cold restart the client must
  still show and request `Автоматически`; while connected it may show the exact
  verified city selected for that tunnel
- while a tunnel is already running, a manual choice is pending for the next
  reconnect: Home keeps the last verified active city and states that the
  change applies after reconnect; it must not attest that the new city is
  active before a fresh profile is staged and the runtime connects
  successfully
- the active location label may include the verified non-direct variant, but a
  pending node or variant must not replace the last proven live combination
- automatic selection keeps its existing semantics and never persists a
  server-selected bridge/direct variant as a manual preference
- WARP plus a manual `Белые списки` variant is blocked before runtime staging
  until that composition has focused runtime proof; the app tells the person
  to disable WARP or choose `Обычный` and never silently changes either choice
- after that successful reconnect, the home location chip shows the selected
  city from the live or cached catalog; it must not keep claiming
  `Автоматически` or expose a technical node code. Cached, stale, or unknown
  runtime evidence must remain unverified rather than reusing the pending city
- trial and Telegram-bonus access must read as premium-pool access, never as
  `free node` access

### Whitelist mode

- `Режим белых списков` is a separate nested surface under Locations for trial and
  paid accounts in Russia. It is not a fifth main tab and it does not replace
  normal Smart Connect.
- Eligibility uses a bounded server-cached country observation, while the
  recovery surface itself assumes a limited network without asking the person
  to understand or toggle that internal state. If ordinary profile resolution
  fails transiently, Home offers this mode directly.
- The app accepts only an Ed25519-signed server-owned catalog with 4–20 unique,
  recently authenticated non-RU reserve exits. The signing key id and public
  key are release-time constants; missing or malformed constants fail closed.
- Raw reserve addresses, credentials and third-party source material never
  appear in the list, diagnostics, telemetry or support context. The first
  connection for a catalog revision calmly explains that the direct emergency
  path uses independently supplied reserve infrastructure and requires explicit
  consent.
- The three supported routes are exactly reserve → internet, reserve → POKROV
  foreign node, and reserve → POKROV RU hop → POKROV foreign node. Emergency
  profiles cannot contain WARP, direct foreign bypasses, an unexpected ruleset,
  extra auxiliary outbounds or a different DNS detour.
- After an eligible online session, the app proactively stores one complete,
  device-bound encrypted bundle covering every fresh or still-valid signed
  last-known-good reserve and advertised chain mode. Catalog and exact profile
  selection are cache-first, so connect does not wait for or require
  `api.pokrov.space` when the signed copy is valid. A `stale` row remains
  selectable until the signed lease expires; its label stays honest.
- The offline lease is at most seven days and is always capped by the active
  trial/subscription, catalog, and eligibility expiry. A fresh paired device
  may precache after one authenticated online activation, but that copy stays
  hidden until trusted RU evidence or explicit `Ограниченная сеть`
  confirmation; it cannot silently authorize a non-RU session.
  Invalid signatures, expired material, or an exact profile mismatch clear the
  affected emergency cache and fail closed.
- The first layer shows one readiness summary, one connect action, and one
  collapsed route control. Automatic mode prefers reserve → POKROV foreign
  exit, then reserve → internet, then reserve → POKROV RU hop → POKROV foreign
  exit. A person may instead pin one of those three exact routes; that choice
  persists locally and fallback then rotates only through compatible reserves,
  never through a different route shape. Per-channel status and latency stay
  inside a separate collapsed diagnostics section without provider or geography
  claims. Those values describe the last server-side POKROV check, not a live
  measurement from the current device.
- While whitelist mode is the active Android runtime, Home replaces the normal
  location, route and WARP controls with one explicit `Режим белых списков`
  status card naming the active route (`Через POKROV`, `Через белый канал`, or
  `Усиленная цепочка`). It must not imply that normal location, route or WARP
  choices apply to that tunnel.
- Ordinary DNS overrides, WARP, and per-app rules do not modify the signed
  whitelist-mode profile.
- After signature verification, the runtime normalizes emergency DNS to
  literal-IP DoH inside the selected encrypted reserve-first chain. This
  also keeps already cached signed DoH profiles usable after the update while
  avoiding local-RU DNS and stale HTTP/2 transport across Wi-Fi/LTE changes.
  The emergency resolver uses IPv4-only answers because the current reserve
  chain is IPv4-authoritative and must not launch paired A/AAAA requests on a
  constrained first hop. The DoH transport remains encapsulated by the
  encrypted VLESS reserve path rather than leaving through the local network.
- Emergency connect never requires a live POKROV API probe after the signed
  offline bundle has passed local validation. Android keeps the exact signed
  terminal proxy as the runtime final and does not stop that TUN merely because
  a control-plane health URL is blocked. Before Core or the TUN starts, Android
  requires the root reserve endpoint to be reachable on the active non-VPN
  network. A failed root check cannot produce a green system VPN: the client
  automatically tries each other signed compatible reserve once, then shows a
  bounded current-network error. Detoured POKROV hops are not incorrectly
  required to be directly reachable outside that root reserve. There is no
  direct foreign fallback; online catalog checks resume opportunistically.
- An operator distribution stop prevents new catalog delivery and automatic
  worker promotion. A previously issued signed offline copy cannot be recalled
  and may remain usable only until its existing expiry.

### Renewal and purchase

- purchase and renewal stay available from the app
- the client continues payment through the canonical hosted checkout on `https://pay.pokrov.space/checkout/`
- Android cabinet and owned POKROV documentation continue inside an
  app-owned WebView surface with a visible `pokrov.space` origin, back and
  close controls, strict owned-origin navigation, and external handoff for
  payment, Telegram, and mail destinations. iOS keeps the OS-backed in-app
  browser view and desktop keeps the external browser. This is hosted
  checkout, not native store billing.
- Telegram purchase continuation may remain as a fallback path, not the default CTA
- public acquisition outside the app is checkout-first on `marketing`, while the cabinet stays a continuation surface rather than a second acquisition page

### Rewards and bonuses

- Account may show a compact bonus summary for Telegram reward, referrals,
  promo entry, and the latest safe bonus-history events
- Rewards Hub may show the referral code, safe Telegram referral link, tier
  state, and copy/share actions from `GET /api/bonuses/referral/summary`
- bonus history must stay compact and app-safe: no raw subscription links,
  full promo codes, tokens, hostnames, or backend event metadata
- trial may claim the one-time Telegram `+5 days` acquisition reward; the UI
  must keep that action enabled while explaining that wheel, calendar, and
  referral rewards open after payment
- grandfathered historical Telegram claims remain readable
- referral grants `+10 days` only to the referrer after the friend's first
  successful payment and hold; install, trial and connection grant nothing
- Rewards Hub may show enabled operator-authored promo slots from
  `GET /api/client/promo-slots?surface=app`; every eligible server-prioritized
  slot remains visible rather than being silently truncated. The shared
  renderer accepts first-party static/animated/video media, poster/fallback,
  `logo|banner|media_only`, optional copy/CTA, server-aligned countdown and
  dismissible or mandatory policy. External media hosts, unsafe schemes and
  third-party ad SDKs remain forbidden
- the paid roulette is visible from backend state, runs at most once per `336`
  hours and may execute only when `eligible && can_spin`; calendar remains an
  independent backend-controlled feature
- achievements use real icons and restrained unlock motion; reduced-motion
  users receive the final state without the animation

## Support Direction

Support should be reachable from:

- the app
- the web cabinet
- helpbot `@pokrov_supportbot`
- `support@pokrov.space`

Support contract rules:

- support is a real ticket-backed flow, not decorative chat UI
- `Атлас приложения` opens the owned in-app surface at
  `/guides/pokrov-app/` directly and uses real redacted Android screenshots;
  the generic guide catalog and three-step illustration cards are not a
  substitute for that app-screen atlas
- app support should prepare account and device context before handing the user into the ticket flow or fallback channels
- authenticated browser support should continue through `/api/tickets`, `/api/tickets/{ticket_id}`, `/api/tickets/{ticket_id}/messages`, and `/api/tickets/uploads`
- app support may attach redacted diagnostics on ticket creation and on one explicitly confirmed follow-up reply
- diagnostics should expose route mode, DNS policy, transport profile, ruleset/package-catalog version, app version, and linked Telegram state without leaking raw config, keys, or share links
- ticket history restores into the existing conversation; loading and offline
  states keep one lifecycle hint and one retry instead of duplicate notices
- a failed ticket send keeps the draft and removes its unconfirmed optimistic
  bubble, so retry produces one user message after backend acceptance
- the AI helper handles WARP, location, route-mode, and system-permission
  recovery before human escalation. A transport failure is shown as a retryable
  request failure, not as a fabricated or missing-answer response
- the ticket screen keeps the embedded operator chat primary and exposes a
  quiet native `Оставить отзыв` form for ideas and problems. Telegram is a
  fallback only when embedded support is unavailable, not a permanent button
  beside the chat. The assistant remains first, diagnostics require
  confirmation, and neither the AI nor a FAQ answer opens an external bot or
  creates a ticket automatically
- AI continuity remains sheet-local; retry reuses the one visible question,
  while closing and reopening the sheet begins a fresh assistant conversation

## Smart Connect And Privacy Rules

Quick-connect rules:

- the backend builds the shortlist before the client starts latency checks
- premium users can probe up to `SMART_CONNECT_SHORTLIST_LIMIT` eligible non-free nodes, default `8`
- expired users receive no node shortlist; legacy free states remain parse-only compatibility and never fall back to premium nodes
- shortlist eligibility rejects disabled, draining, unhealthy, stale, dataplane-down, saturated, high-loss/retransmit, overloaded, and transport-incompatible nodes while capacity-aware selection is enabled
- the client uses backend-provided internal probe targets and capacity hints, then posts `mode=auto` or `mode=manual` to `/api/client/nodes/select`; telemetry failure must not block connect
- after automatic selection the client promotes the selected direct outbound
  inside the already authorized managed profile. It may perform one bounded
  exact-profile refetch only when local identity mapping cannot be proven; the
  normal path must not depend on a duplicate full profile request
- an exact selected-outbound egress failure in automatic mode quarantines that
  node locally for 15 minutes and permits at most two bounded failover attempts;
  the quarantine stores at most eight nodes. Manual selection, unavailable
  egress evidence, and telemetry-only failure do not silently change location
- the default stickiness threshold is `20%`
- explicit user-node assignments are provisioning/history state and must not reduce the premium candidate pool

Consumer privacy rules:

- normal consumer screens must not expose public IP, raw connection links, raw JSON/profile editors, sniffing terms, or low-level topology
- route labels and support diagnostics should stay safe and human-readable
- public-facing copy should prefer plain user language over transport acronyms, raw profile terms, or operator jargon
- Home and Profile may show `WARP` as the owner-approved feature label because
  the default runtime path is client-local Pokrov-core WARP. The UI must still
  avoid claiming production-proof anonymity or stronger privacy until
  Android/Windows release-build WARP evidence exists.
- raw subscription copy, edit, regenerate, or share actions stay out of the first-layer consumer path
- raw connection or subscription links must not be treated as account proof in
  first-launch restore or normal code redemption
- manual import and recovery tools may remain behind explicit compatibility or recovery surfaces

## Protection, Routing And Recovery Contract

The Android and Windows client now treats protection as several independent,
observable checks instead of one decorative connected badge:

- tunnel lifecycle comes from the runtime snapshot;
- bootstrap DNS readiness comes from runtime-owned diagnostics and is labelled
  separately; it must not claim that application DNS inside the VPN works;
- selected-outbound egress health, including the user-facing VPN internet check,
  comes from the core-owned bounded URL test; the timeout sentinel is failure;
- the bounded HTTPS probe to the configured POKROV API is a separate
  control-plane check and is not tunnel-egress proof when the app UID is
  excluded from its own VPN;
- route ownership is described from the active runtime profile and routing mode;
- unknown or stale evidence stays unknown and cannot render as healthy;
- one repair action runs at most one staged cycle: disconnect, resolve a fresh
  managed profile, stage, connect, then refresh the checks. It has no retry loop
  and cannot overlap another repair.
- first-layer recovery copy must stay actionable and must not expose raw
  exceptions, endpoint hostnames, IP addresses, ports, protocol details, or
  engine internals; those details belong only in bounded support diagnostics.

The client persists only bounded local experience state: favorites, recent
locations, cached location/inbox responses with timestamps, the last 20 local
protection events, up to six user-owned HTTPS shortcuts, and validated routing
preferences. Cached content is explicitly marked as cached or stale when a
refresh fails.

Routing preferences are applied to the resolved sing-box profile before it is
staged. They include:

- purpose groups for Video, AI, Social, Games, and RU-direct;
- explicit domain, IP, and subnet overrides to VPN or direct;
- Automatic, Cloudflare, Google, AdGuard, and validated custom DoH. The
  `Блокировать рекламу` toggle selects AdGuard's filtering DoH endpoint as the
  final resolver through the active VPN outbound. This blocks requests to
  domains present in that DNS service's filtering policy; it does not promise
  removal of first-party, baked-in, or otherwise non-DNS in-app advertising;
- LAN direct access;
- trusted Wi-Fi names with optional disconnect on an exact current-SSID match.

Changing a route, DNS, or LAN preference marks the managed profile dirty and
takes effect on the next connection. The route explainer uses the same
validated preferences and reports a routing-lesson completion event on a
best-effort basis. Android Wi-Fi inspection requests the platform permission
when required; Windows uses the current WLAN interface. Failure to identify a
network never counts as a trusted match.

Android exposes a Quick Settings tile backed by the same runtime service and
permission handoff as the main connect action. Windows tray connect/disconnect
delegates to the same shell controller. Neither host control owns a second VPN
state machine. The Android tile resolves the authoritative TUN plus the
app-owned VPN-service presence on every tap before choosing start or stop. It
publishes only an honest on/off state. The service uses Android's active-tile
mode and asks SystemUI to listen again after each committed runtime transition,
so an OEM-cached highlight cannot remain
the sole source of truth. The foreground notification owns the detailed live
status, country, route mode and speed. A user change to location, routing,
selected apps, or WARP
invalidates Android's reusable Quick Settings profile without stopping a live
tunnel: the tile can still stop that tunnel, but after stop it opens the app
until a fresh managed-profile stage saves the new reusable profile.
Quick Settings may start only a freshly staged Android profile whose persisted
metadata proves Flutter completed the first-connect route-scope choice; legacy
path-only and unconfirmed records, as well as any profile rejected by the
selected-outbound egress probe, open the app until a fresh stage completes.

Device continuation uses a short-lived, one-time pairing code created by an
already authenticated device or cabinet. The new device receives its own
revocable session and still obeys the account device limit. The app never
shares an Apple Account or a reusable raw subscription secret for pairing.
An authorized operator may issue the same ten-minute code for an existing
legacy user through the guarded admin surface. After claim, the client switches
to the returned canonical account session and refreshes subscription identity;
it must not keep showing the abandoned local trial profile.
Account device labels use a human-safe platform identity: Android contributes
manufacturer and model, while serial numbers, hardware IDs and install IDs
remain hidden. Generic runtime hostnames such as `localhost` are never shown as
a user-facing device name.

The rewards surface may show backend-confirmed referral conversion/history,
achievements, and useful quests. Product quests do not grant money or days
automatically. Wheel discounts are server-owned, one-use, non-stackable, and
the maximum day result remains 30 days. The approved wheel preset is
fortnightly and deliberately conservative.

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

- the default updater lane is `stable`; beta/prerelease metadata is an explicit
  opt-in lane and must never be returned as the stable candidate
- update discovery uses anonymous `GET /api/public/client-apps` and must not
  create, refresh, or repair an account session merely to discover an update
- stable candidates after installed `1.0.5` beta builds use a strictly newer
  semantic version. `1.1.1+24` is the current public source and its exact
  `v1.1.1` assets are the stable direct release. Production synchronization sets
  both `latest_version` and `min_supported_version` to `1.1.1`; older clients
  receive a required Russian update prompt. The exact `2026-08-17` runtime
  readback, in-app progress UI, and Android Package Installer handoff are PASS
- the `2026-05-15` Android handoff explains the retained beta publication but
  does not approve a replacement artifact; new public APK promotion requires
  exact-candidate production-signing evidence and the applicable device gates
- unsigned Windows bundles are non-public engineering smoke with a SmartScreen
  or unknown-publisher warning; public promotion requires trusted signing
- signed release builds inject updater and source metadata through the documented `PORTAL_RELEASE_*` environment variables
- the shared runtime identity is `pokrovClientVersion`; release builds pass
  `--dart-define=POKROV_APP_VERSION=<host pubspec version without +build>` so
  provisioning, update checks, diagnostics, and visible version text match the
  package. Local builds use the current package base-version fallback `1.1.1`;
  production packaging passes that value explicitly through `POKROV_APP_VERSION`.
- local non-release builds keep updater and source-code surfaces disabled instead of falling back to a personal repository URL
- an update prompt or tap may use only
  `https://github.com/Kiwunaka/pokrov/releases/download/<tag>/<asset>.apk`
  when metadata also carries a 64-hex SHA-256 and a positive bounded byte size;
  alternate initial hosts, repositories, URL authority fields, query strings,
  fragments, and non-APK assets fail closed
- Android downloads into app-private cache, permits only bounded HTTPS
  redirects to GitHub-owned asset hosts, and verifies exact byte size plus
  SHA-256 before exposing the file through a non-exported `FileProvider`. The
  update sheet polls the native downloader and shows downloaded-byte progress,
  then an explicit verification/installing phase; only after verification does
  it open Android's required package-installer confirmation. Android 8+ may
  first require the owner to grant POKROV install-source permission.
  Windows continues through the trusted browser download lane.
- downloaded-byte verification does not replace production-signing, install,
  runtime, or exact-candidate release proof
- update prompts, release notes, remote banners, and Telegram release notices
  for `1.1.1` use short Russian copy; the default client channel remains
  `stable`, without a permanent beta label
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
- visible inherited `Pokrov` references in UI
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
- Telegram reward `+5 days` for new grants; historical backend-confirmed
  `+10 days` grants remain visible as issued
- advanced routing modes `All except RU` and `Full tunnel`
- safe diagnostics and recovery actions

Out of scope:

- forced Telegram login
- admin tooling inside the client
- manual config import as the primary onboarding path
- public `Blocked only` routing until routing assets, DNS behavior, and leak checks are verified
- public `iOS` App Store launch
- public `macOS` distribution promise
