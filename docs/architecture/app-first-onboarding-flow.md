# App-First Onboarding Flow

Last updated: 2026-09-06

## Document Status

This file is the living client architecture note for app-first identity, onboarding, and managed provisioning in `POKROV-app/main`.

The platform contract owner is
`C:/Users/kiwun/Documents/ai/VPN/docs/architecture/app-first-and-bonus-flows.md`.
Public download behavior belongs to
`C:/Users/kiwun/Documents/ai/VPN/docs/architecture/client-downloads-flow.md`.

## Automatic access-network context (owner decision 2026-09-07)

Android reports source-network context on app open/connect/running/failure,
at most once per minute per account in a process. `AndroidNetworkDiagnostics`
uses the latency probe's physical `NOT_VPN` network and `Network.openConnection`
to fixed owned HTTPS hosts, without proxy, redirects or default-network
fallback. Carrier comes from the default data subscription; Wi-Fi is not
labeled with the SIM operator. No GPS or additional permission is requested.
The source IP remains server-side, never in Dart, logs or consumer UI.

If the direct path fails, ordinary authenticated transport sends carrier/class
with `direct_observation=false`; its IP cannot become the underlying address.
Unknown stays unknown. This best-effort observation cannot gate connect,
renew a session or confer access. Platform owns local coarse geography,
sensitive-role reads/audit and capped 72-hour raw data retention. First launch
and the linked privacy policy disclose collection. Manual support bundles
retain separate consent/custody. Network observations are not persisted as
client state or added to the operational event journal.

## POST12 signed Routing Catalog transport (NOT_VERIFIED)

`AppFirstRoutingCatalogService.fetchRoutingCatalog` is implemented by the
existing bootstrapper. It uses `GET /api/client/routing-catalog` with the current
session and owned API transport; it does not create a trial or replace a denied
session. Duplicate requests for the same host platform share a flight. Before
returning, the bootstrapper rechecks account/install/session identity against
the starting state.

The feature is default-off under the compile-time
`POKROV_ROUTING_CATALOG_ENABLED`. The pin is explicitly supplied through
`POKROV_ROUTING_CATALOG_KEY_ID` and `POKROV_ROUTING_CATALOG_PUBLIC_KEY_B64`;
`POKROV_ROUTING_CATALOG_AUDIENCE` defaults to `production` and permits `lab`.
No key is generated or inferred from a response. No HTTP request is made when
the feature is off or trust is unconfigured. An enabled feature without trust
returns an error rather than silently using legacy routing. Injected verifier instances support
an explicit map of multiple trusted public keys for rotation.

The verifier checks the exact envelope and top-level v1 shape, canonical ASCII
JSON SHA-256, Ed25519 signing context, audience, UTC lifetime and retained
catalog/security revisions. It snapshots the input before asynchronous crypto
and returns recursively immutable content. This authenticates publisher
assertions. `RoutingCatalogPolicy.fromVerified` separately checks the consumer
projection: source/evidence references and lifetimes, service ownership,
synthetic-production boundary, classification and mode constraints, domain
scope, package signer sets/lineage and browser Direct prohibition. Store accept
and read require this projection; invalid nested policy cannot replace the last
accepted envelope or advance its revision floors. Network metadata does not
produce CIDR/ASN routes; Windows identities are not yet matched to installed apps.

On a transient transport failure or retryable HTTP outage, only a currently
verifiable cached envelope can return, with `usingCache=true`. TLS failures,
malformed replies and invalid signatures do not become cached success.
401/403 or a fixed `routing_catalog_*` code in `X-POKROV-Error` prevent fallback
and discard the retained envelope while preserving revision floors. This
distinguishes a known server disable/revocation from an unclassified 503 outage.
The shared transport retains the existing auth-error header as a fallback for
older endpoints.

Ordinary connection preparation now calls this API when enabled and feeds the
verified catalog to the [profile assembler](bootstrap-workflow.md#connection-preparation-with-the-catalog-not_verified).
Cached managed-profile restoration explicitly requests `cacheOnly`: no HTTP,
the same session fence, and fresh verification of retained keys/lifetime/floors.
No valid cached envelope means preparation fails. Fetching metadata alone still
does not mutate a native host. No app inventory is sent or provider lease granted.
The feature remains disabled and artifact pins are unchanged; tests/builds/runtime
checks are deferred to the separate validation phase.

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
9. the shell changes to `Quick Connect`
10. the app asks `How should this device work?` before the first live route activation
11. the app saves the chosen per-device route policy
12. the app resolves and silently imports the managed profile
13. on Android, the app explains the system VPN permission and only then lets
    the host show `VpnService.prepare`; dismissal leaves Home disconnected and
    denial exposes an explicit retry instead of a dead end
14. the host starts the requested connection
15. only after the runtime settles in a cleanly verified running state, the app reports
    connected runtime state and completes account onboarding through the active
    app session

UX guardrail:

- until provisioning succeeds with a real subscription payload, `Locations` stays behind an activation gate and must not render fake/demo countries
- a tap, permission prompt, timeout, or failed connection must not dismiss the
  first-connect milestone
- rendering the welcome gate alone must not start a trial or authenticated
  account refresh; access creation begins after trial selection, a valid
  acquisition continuation, successful restore, or a persisted completed flow
- invalid, expired, replayed, or wrong-host acquisition continuation never
  hides or disables either `Начать бесплатно` or restore
- authenticated first-session analytics use the server-derived account/device
  identity and a fixed safe vocabulary. The client never sends the opaque
  acquisition handle, session token, profile, endpoint, or raw host detail.

## Account Experience And Connection Evidence

When an established app flow returns to the foreground (including a cabinet
browser return), the shell refreshes its existing account subscription,
bonus summary and inbox without changing the selected tab. Access changes come
only from the authenticated server response; closing the browser never means payment
succeeded. The welcome/restore choice does not start an authenticated refresh
merely because the app resumes. Pending Telegram verification keeps its existing
dedicated refresh path.

Foreground, profile-tab and initial account-summary requests share one in-flight
refresh, keeping subscription, bonus and inbox reads sequential. Inbox reads
also wait for the access choice because their session helper can create a trial
when no app session exists. A failed refresh retains the previously observed
account view and permits another foreground or
profile refresh; it does not clear access, claim payment or reset navigation.
These reads use the existing bounded app-first HTTP request path. Native browser,
tray, upgrade and payment acceptance still require exact installed-package proof.

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
- Windows installation or explicit service repair may require UAC; ordinary
  connect must keep the UI unelevated and use the authenticated installed
  service
- raw service controls and low-level transport toggles stay outside the
  first-layer onboarding path; the retired system-proxy mode is migration-only

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
- `access` plus legacy `free_caps` compatibility facts

Legacy free-tier rendering (delivery retired):

- current production projects post-trial and expired accounts to `expired_or_blocked`; no free node or basic-access promise is shown

- `free_caps.transition_state` and the matching `access.free_profile_*` facts
  are parsed together; a mismatch or unknown value is shown conservatively as
  an access status that needs refresh
- `soft_transition_pending` and `reset_pending` tell the user that the basic
  access update is still in progress; `error` offers the fixed refresh/support
  recovery message without exposing an internal error code
- only confirmed `free_soft_mode` / `soft_active` renders as basic access
  after the limit; it must never be described as premium access

Internal staged `support_context` controls:

- `reality_tls_fragment.enabled`, `fragment`, `record_fragment`, and optional
  `fragment_fallback_delay` apply only to VLESS + REALITY over TCP. The control
  defaults off and is not a public user setting; production activation requires
  PCAP and RU LTE/5G evidence.
- `tun_mtu` accepts any integer in `1280..1500`. Missing, malformed and
  out-of-range values use the conservative `1280` default. The Android host
  validates the range again and applies a usable active-interface MTU ceiling
  immediately before TUN creation; `9000` is never a fallback.

WARP policy rule:

- `client_policy.warp_policy` is sanitized metadata only.
- The default WARP path is client-local Pokrov-core WARP. The app may expose
  `WARP / Расширенная защита` when the local runtime lane is available; it must
  not wait for backend-provisioned WireGuard/account material before offering
  consent.
- Managed-profile `warp_policy` may still carry backend-provisioned
  WireGuard/account material as an optional operator lane, but this material is
  not the normal prerequisite for WARP.
- Before setting Pokrov `warp.enable=true`, the app must ask for explicit local
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
- expired users receive no node shortlist; legacy free states never fall back to premium nodes
- shortlist eligibility rejects disabled, draining, unhealthy, stale, dataplane-down, saturated, high-loss/retransmit, overloaded, and transport-incompatible nodes while capacity-aware selection is enabled
- the client performs best-effort TCP RTT probes for shortlist items with an internal probe endpoint, bounded concurrency and one global deadline; a worker that consumes the remaining global budget stops without starting another probe, then the client calls `POST /api/client/nodes/select` with `mode=auto` for automatic choice or `mode=manual` for saved location choice
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

Linked Telegram identity and membership in `@pokrov_vpn` can grant the current
one-time `+5 days` acquisition bonus.
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

A Telegram-authenticated account is already linked by definition. The profile
reads that state from `/api/client/subscription`, shows the safe username (or
`Привязан`), and does not open a redundant bot-link flow. Telegram does not
provide an email address; email remains an independent verified identity.
For an app-first account, `POST /api/client/telegram/link` creates a one-time
15-minute bot handoff. The client records only allowlisted handoff diagnostics,
then re-reads `/api/client/subscription` after returning to the foreground or
after an explicit `Проверить`; opening Telegram alone is never treated as a
successful link.

### Returning-user recovery

- returning users restore from the first-launch screen with a one-time device
  code issued by the canonical main bot or cabinet, or with an activation code
  received through Telegram, site, email, or an operator
- an operator may issue the same ten-minute device code from the guarded admin
  user card for a legacy account; successful claim preserves entitlement,
  creates a new revocable device session, replaces the local trial session, and
  refreshes the visible subscription/profile identity before success is shown
- the first-launch `Получить код в боте` action opens
  `@pokrov_vpnbot` with `start=pair_device`; the bot exposes the same explicit
  action in its device picker and issues an eight-character single-use code
  with a ten-minute TTL
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
- mobile opens the canonical hosted checkout in an OS-backed in-app browser
  view; desktop opens it in the external browser
- the same hosted checkout contract is shared across app, site, and bot flows
- public marketing entry into that flow is checkout-first; cabinet continuation starts after the user is known

## Download Surfaces

- the client fetches `/api/client/apps` and uses runtime URLs for Android `Play` / `APK` / mirror and Windows `EXE` / mirror, plus docs/install fallback
- release handoff updates those runtime `APP_*` URLs for the app, bot, and authenticated web surfaces
- static marketing download CTA is build-time and must be rebuilt or redeployed when public Android or Windows URLs change
- `AAB`, `MSIX`, and portable `ZIP` remain store/operator artifacts rather than first-layer client download targets
- public-facing build surfaces should present `1.0.0-beta` or an explicit
  beta patch/build label; none of those labels authorizes stable `1.0.0`
- Android keeps owned cabinet and documentation handoffs in the app-owned,
  origin-visible web surface; payment providers, Telegram, mail, downloads,
  and other non-owned destinations leave the app explicitly. Desktop retains
  safe external handoffs. No path exposes raw profiles or local control
  surfaces.

### Acquisition continuation

Official Android and Windows links may carry an opaque `acq` continuation
handle issued by the POKROV backend. The client accepts it only from the
allowlisted POKROV deep-link/command-line surface and posts it once to
`/api/acquisition/handoffs/consume` with its exact platform purpose. The handle
contains no identity or product access, expires server-side after `72 hours`,
and failure or absence never blocks app startup, trial, sign-in, or connect.

The client does not fingerprint the device or infer attribution from IP, user
agent, or timestamps. Only a successfully consumed server handoff may connect a
browser campaign to an install/account. A missing, expired, replayed, or wrong
purpose handle remains `unknown`.

While the welcome gate is visible, the app may show only a safe `confirming`,
`linked`, or `not applied` acquisition notice. It never displays a manual
handoff code. Consumption and duplicate suppression live in the shared
first-session coordinator; a failed consume leaves both normal access choices
active. The first-session events are `app_first_open`,
`acquisition_handoff_received|failed`, `trial_start_selected`,
`existing_access_selected`, `vpn_permission_explainer_shown`,
`vpn_permission_result`, `first_home_seen`, `connect_requested`, and
`first_verified_connect`. First-open/home/verified milestones do not replay
after their persisted local completion boundary.

### Emergency offline readiness

- once `/api/client/subscription` confirms `trialPremium` or `paidUnlimited`,
  the app refreshes the authenticated signed emergency bundle with the
  explicit precache flag in the background without blocking the home screen
- the precached bundle stays hidden until trusted RU evidence or the user's
  `Ограниченная сеть` confirmation; precaching is not automatic country proof
- a valid encrypted bundle is reused immediately on cold start when POKROV
  control-plane domains are unavailable; server refresh resumes whenever the
  normal network is reachable
- a reserve whose probe age is marked `stale` remains a selectable signed
  last-known-good path until the bounded catalog lease expires
- on Android, an offline emergency connection probes only the root reserve on
  the active non-VPN network before starting Core. An unreachable root is
  rejected without creating a TUN, and the app rotates through the other
  signed compatible reserves before reporting that none work on this network
- the bundle binds to the active paired-device install from the access token,
  contains no authorization for a different install, and expires no
  later than the confirmed trial/subscription. A new or reset device still
  needs one successful online activation before it can work offline

## Local Smart Access grant receipt (NOT_VERIFIED)

The existing bootstrapper exposes `AppFirstSmartAccessService` for a fresh
provider-policy read and a device-bound lease request. It uses normal existing
session credentials; no trial/account bootstrap or automatic session replacement
is performed. Public provider policies and grants have separate Ed25519 pins
and signing contexts. Build flag `POKROV_SMART_ACCESS_ENABLED` is default-off;
provider key ID/public-key, grant key ID/public-key and audience must be supplied
explicitly. These pins do not inherit catalog/release/support trust.

Provider reads and lease POSTs have bounded response sizes and no automatic
retry. The POST binds the verified catalog/provider digests, exact capability,
requested platform/origin/family/feature, effective-profile hash and a random
nonce. The platform supplies current access/expiry and verifies an active
paired device. The client verifies signature, per-request account/install
binding, nonce, profile, policy revisions/digests, capability and nonshared
service domains. It rejects expired grants and limits new admission to 10
minutes and active lifetime to one hour, additionally bounded by authority.

Both operations require an `operationIsCurrent` callback from the existing
caller and recheck account/install/session around async work. Known denial
invalidates pending work without deleting retained provider floors. This is
receipt plumbing; coordinator selection, native route/flow enforcement and
revocation delivery remain open. No live provider request, API, build or test
was executed for this implementation.

## Local ATS shortlist and profile resolution (NOT_VERIFIED)

The optional transport selection now has a session-owned HTTPS shortlist read
for opaque endpoint refs in the signed capability/profile/family scope. It
checks the original operation clock, exact request echo, canonical response,
 current session and signed endpoint budget. A hint carries no lease or address;
 profile resolution still obtains one server-issued endpoint grant and must
 match the hint's failure domain. Within the budget, the selector prefers the
 last healthy path on the same network and then untried failure domains. Both sides
reject new-flow windows over 10 minutes and active-flow windows over one hour.
The client requests a one-item cold-reserve shortlist when the signed endpoint
budget has room, retaining a slot after primary hints; if no reserve exists it
uses the remaining primary slot. A failed optional reserve read cannot erase
valid primary hints; session or policy withdrawal still closes the selection.
The same attempt and endpoint counters apply to
both roles, and neither hint provides a lease until profile resolution.
Endpoint-specific denial may let the selector try another candidate within its
original budget; policy or session denial closes it. With the explicit
`POKROV_TRANSPORT_ENABLED` build flag and pinned trust keys, ordinary Full Tunnel
and Smart Safe Connect on Android and Windows invoke this source path. Selective
Services on Android and Windows joins it with the verified catalog and confirmed
service selection. Android per-app modes also use it when the verified RU-app
preset is not selected. When the catalog is enabled, Full Tunnel uses the same
verified catalog layer as its existing path; Smart Safe and Selective Services
require it. Catalog modes bind fresh authenticated access within the same
operation deadline. For a fresh Selective Services catalog, the client requests
approved-gateway grants only after materializing the exact base ATS profile,
then binds them to its digest before assembling routing rules. A cached catalog
or temporarily unavailable provider authority uses the catalog's declared VPN
fallback. The final policy and grant windows reach native restriction persistence
and runtime control. The verified RU-app preset and remaining route modes retain
their existing path. The selector can enroll a missing floor only through the authenticated
online nonce exchange, then uses the signed shortlist and bounded candidate
attempts. A signed capability must require the Core
`pokrov_ats_lease_v1` feature. After routing assembly, the client places the
single VLESS upstream behind `pokrov-ats-lease`, preserving route/DNS references
to its original tag. Core source enforces the approved new/active flow windows.
Android, Windows and Linux source paths now transfer an exact proven request to
the loaded Core gate and an active lease watchdog; the coordinator retains exact
stop ownership until it accepts the transfer. A committed signed kill or removed
capability/profile binding fences the client presentation and revokes the exact
native lease, terminating active flows. Uncertain acknowledgement requests exact
runtime stop. While this ATS path runs, a bounded manifest refresh occurs
once per minute; offline Core deadlines remain the final boundary. Native proof
support is required before Android asks for VPN permission or this path starts
a TUN. A zero diagnostic-byte budget is rejected before selection. Full wire
accounting must include DNS, transport handshakes, headers and retransmissions;
the current Core reservation ledger and native hosts do not enforce it. A new UI
owner observing a running ATS runtime with native proof pending requests disconnect
before presenting protection; a failed stop remains unverified. Native proof
production, host process-restart reconciliation and runtime validation remain
open. No build or test has run for these changes.

## Release And Audit Expectations

- release verification must start from a clean POKROV Core checkout pinned to the exact client contract SHA
- `python scripts/run_client_release_gate.py preflight` is the canonical repo-local preflight before Flutter tests or artifact builds
- when Android build gates are requested, release approval also requires `python scripts/android_localhost_audit.py` against a release-installed build on physical hardware via `ANDROID_AUDIT_SERIAL`
- the latest local green `python scripts/release_orchestrator.py --gates-only` snapshot is necessary but not sufficient; Android publication still waits for production signing, the physical-device localhost audit, and separate `current-origin`, `brain-origin`, and `RU-origin` evidence

## Scope Note

This flow is the public client path for:

- `Android`
- `Windows`

For `iOS` and `macOS`, this document is readiness reference only until Apple publication is formally approved.
