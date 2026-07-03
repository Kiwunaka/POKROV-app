# Decisions Implementation Map

Date: 2026-06-09
Status: active execution map
Owner: POKROV-app/main

## Purpose

This file turns `docs/decisions/*` into an implementation checklist for the
`1.0.0-beta` product-readiness target.

Owner definition for this lane:

- `1.0.0-beta` means the Android and Windows product contour is implemented end
  to end, with beta reserved for quality polish, fixes, signing/store/trust
  upgrades, and final release hardening.
- It is not a stable `1.0.0` claim, not a store-availability claim, not a
  trusted Windows signing claim, and not a raw Android audit or RU-origin
  readiness claim.

## Decision Sources

- `docs/decisions/2026-06-03-client-ux-account-rewards-master-brief.md`
- `docs/decisions/2026-06-03-client-best-mvp-consilium.md`
- `docs/decisions/2026-06-03-client-chat-responsive-warp-motion-review.md`
- `docs/decisions/2026-06-03-hiddify-karing-happ-client-base-review.md`
- `docs/decisions/2026-06-03-hiddify-core-warp-status.md`

Explicitly ignored as old/archive input:

- `docs/decisions/2026-06-02-karing-base-reopen.md`
- `docs/decisions/2026-04-18-karing-vs-clean-room-gate.md`

## Current Execution Slice

The current code slice is:

1. app-facing bonus summary model and runtime adapter;
2. compact Account summary surface for Telegram, referral link/share, promo
   entry, and recent safe bonus history;
3. platform `GET /api/bonuses/summary`, `GET /api/bonuses/referral/summary`,
   `GET /api/bonuses/history`, `GET /api/bonuses/wheel/state`,
   `POST /api/bonuses/wheel/spin`, `GET /api/bonuses/calendar`,
   `POST /api/bonuses/calendar/checkin`, and
   `POST /api/bonuses/promo/redeem` contracts, plus app-safe
   `GET /api/client/promo-slots?surface=app` rendering;
4. unified app code redemption for paid access keys, legacy gift-card codes,
   and promo codes through `POST /api/redeem`;
5. support follow-up replies can explicitly attach the same safe
   `app_diagnostics` payload used for ticket creation;
6. Rules renders the safe ruleset/package-catalog version and explicit
   enabled/staged/locked preset states without exposing raw rule assets;
7. Rewards Hub opens from Account and shows safe wheel/calendar state previews,
   activity grid, achievements, referral card with safe share/copy actions,
   first-party promo slots, muted disabled states, and live spin/check-in
   actions only when backend summary state marks the mechanics enabled;
8. keep profile loading lazy so the app does not block startup or ordinary
   navigation on bonus data;
9. Rules selected-apps mode now has a picker-first UX with Android native
   launchable-app bridge support, immediate fallback suggestions, Windows
   running-process and discovered `.exe` suggestions, manual entry retained for
   unusual app IDs, and Windows TUN/process routing proof so selected `.exe`
   values go through
   POKROV while the rest of the device stays direct;
10. embedded support chat now polls the active ticket, refreshes status, and
    shows operator replies plus ticket lifecycle hints in-app without forcing
    the user back to Telegram;
11. WARP/enhanced privacy now uses the client-local Hiddify-core path by
    default, with sanitized backend metadata, optional managed-profile material,
    client parsing, and a Home consent gate that keeps Hiddify
    `warp.enable=false` until the user explicitly turns it on.
12. Account now has a compact details sheet for access/device/mode/cabinet,
    settings rows have tactile press feedback, and the desktop sidebar animates
    label opacity/width while the responsive matrix covers `360`, `700`,
    `900`, `1024`, `1180`, and `1440` widths.
13. P5 connect motion now has tested idle, connected, and error settle layers,
    and WARP operator visibility includes redacted runtime state/reason/event
    summary data in the platform admin dashboard.
14. Phase 6 refreshed the `1.0.0-beta` Android APK and Windows unsigned beta
    artifacts, uploaded the GitHub prerelease assets, and updated handoff
    metadata; signatures, live install smoke, app-session runtime handoff, and
    stronger WARP proof remain explicit manual/trust gates.

This slice is P0/P1 bridge work because the master brief needs bonus/account
clarity before a richer Rewards Hub can safely exist.

## P0 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Hiddify-based runtime direction | Done for MVP | active lane uses pinned `hiddify-core v3.1.8` artifacts through the runtime bridge; clean-room POKROV shell remains current; Android/Windows host runtime paths and managed-profile connect tests exist | separate Hiddify fork/provenance packet remains a release-hardening or replacement-lane gate, not a P0 blocker for the current shell |
| First-launch `new / returning` split | Done for MVP | startup asks new vs returning; completion is file-backed and tested | keep wording lightweight while runtime gates evolve |
| Returning-user restore screen | Done for MVP | first-launch restore panel uses unified redeem, Telegram, cabinet, and raw-key warning | expand accepted code families on backend over time |
| Unified redeem API contract | Done for MVP | platform `POST /api/redeem` supports paid access keys, legacy gift-card codes, and promo codes; app uses `AppFirstAccountActionService.redeemCode`; raw subscription/proxy links are rejected locally and by backend | claim-token/email-code families stay out until backend support is explicit |
| Safe one-time claim/link semantics | Done for MVP | first-launch restore warns that raw connection links are not account proof; app locally rejects raw subscription/proxy links before unified redeem; backend keeps structured rejection | expand accepted code families only when backend support is explicit |
| App profile basics | Done for MVP | grouped account/profile sections, access, redeem, cabinet, Telegram, support, bonus summary, and advanced gate exist; visible copy stays compact; hidden/disabled features are not surfaced as active | continue copy polish as P1/P2 quality work, not a P0 blocker |
| Telegram `+10 days` link/check/claim | Done for MVP | app has link, channel check, claim actions and tests | keep optional, no startup wall |
| Bot parity for subscription/access | Done for MVP | platform bots, cabinet, and app share app-first contracts; root `scripts/app_bot_parity_smoke.py` verifies static parity for account, cabinet, Telegram bonus, support ticket, safe redeem, and bot fallback entrypoints | keep live Telegram bot and same-account parity as owner `MANUAL_OWNER_TEST` before handoff |
| Short-lived cabinet token | Done for MVP | app calls `POST /api/client/cabinet-token`; cabinet exchange exists | keep e2e coverage for one-time URL token removal |
| Bonus API contract and MVP endpoints | Done for MVP | channel check/claim live; app reads `GET /api/bonuses/summary` plus safe history from `GET /api/bonuses/history`; platform exposes referral summary, promo redeem, unified gift redeem, and disabled-by-default wheel/calendar endpoints; under `BONUS_WHEEL_ENABLED` / `BONUS_CALENDAR_ENABLED`, wheel/calendar mutations write `RewardClaim`, extend access, refresh achievements, and return a fresh summary; compact summary/history plus wheel/calendar state parsing and mutation tests exist | keep flags off by default until rollout/copy/support approval |
| Smart-connect shortlist and route-mode sync | Done for MVP | managed profile returns smart-connect metadata plus internal probe targets; route mode persists through backend contract; client performs best-effort RTT probe/upload and applies the 15% stickiness threshold with tests | keep smart-connect hidden from first-layer UI; collect live release-build telemetry before exposing any manual controls |
| Claims guardrails | Done for MVP | WARP info-only, raw rule editing hidden from normal UI, no stable/store/trusted/RU claims | keep guardrails in tests/docs with each release update |

## P1 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Rewards Hub light | Done for P1 plus flag-gated live actions | Account summary opens a dedicated hub with Telegram/referral/promo/history context, safe wheel/calendar state, activity grid, achievements, referral card, muted disabled states, and live actions when backend summary says ready | keep copy calm and flags backend-owned |
| App-facing wheel spin endpoint and UI | Done under rollout flag | app parses wheel state from summary; disabled state is muted/non-CTA; when backend returns enabled/ready, the app calls the spin action service; backend writes `RewardClaim`, extends access, refreshes achievements, and returns a summary | keep `BONUS_WHEEL_ENABLED=false` until rollout approval |
| Calendar check-in endpoint and summary | Done under rollout flag | app parses calendar state from summary; disabled state is muted/non-CTA; when backend returns enabled/ready, the app calls the check-in action service; backend writes `RewardClaim`, extends access by `BONUS_CALENDAR_REWARD_DAYS`, refreshes achievements, and returns a summary | keep `BONUS_CALENDAR_ENABLED=false` until rollout approval |
| Support diagnostics flow | Done for P1 follow-up attachment, partial for realtime lifecycle | chat can attach redacted diagnostics on create and on the next follow-up reply after explicit user confirmation | add polling/SSE only after operator flow proof |
| Paywall/subscription UX cleanup | Done for P1 safe handoff, partial for priced paywall | Account opens a subscription sheet with current access, checkout handoff, and cabinet handoff without unsupported prices | add paid plan cards only after pricing/copy/legal checks |
| Rules presets UI | Done for P1 seed/catalog states, partial for live catalog and picker | Rules shows safe ruleset/package-catalog versions and enabled/staged/locked preset states | continue app/process picker and live backend catalog work in P3 |
| Email recovery polish | Done for P1 handoff, partial for native email auth | Account opens an email/recovery sheet with add-email, cabinet, and recovery handoffs | add native email linking only after delivery readiness stays green |

## P2 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Full activity calendar | Moved to P3 | Rewards Hub shows a compact activity grid derived from safe summary state | replace preview with ledger-backed full calendar when check-in history exists |
| Achievements in app | Moved to P3 | Rewards Hub shows safe achievement chips derived from opening, Telegram, referral, and streak state | replace preview chips with backend achievement ledger when available |
| Rich referral UI | Done for P2 safe display, partial for live referral program | App reads `GET /api/bonuses/referral/summary`, parses link/tier state, and Rewards Hub exposes copy-code, copy-link, and safe Telegram share/open actions without pushing referral spam into the first layer | keep anti-abuse, payout/bonus ledger, and referral campaign tuning backend-owned |
| Promo slots in app | Done for P2 safe display, partial for live campaigns | Rewards Hub fetches `GET /api/client/promo-slots?surface=app` best-effort, renders enabled first-party slots, and falls back to a quiet empty state | add campaign assignment, rollout QA, and feature-flag proof before relying on remote campaign content |
| Advanced raw rule editor | Moved to P3 debug-only | advanced gate exists | keep raw rule editing out of normal UI; user-facing need is covered by custom selected apps |
| Detailed cabinet/account management | Moved to P3 | cabinet continuation exists | expand webapp first, then expose app entry points |
| Windows process picker | Moved to P3 | selected app identifiers now have a manual editor and policy plumbing | implement native process/exe picker after Windows OS enforcement proof |

## P3 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Custom selected apps | Done for P3 manual identifiers, partial for richer native pickers | Rules lets the user add/remove app identifiers; selected apps auto-select the `selected_apps` route mode; app sends `selected_apps` to route policy; Android materialization writes `include_package` into sing-box TUN config; P4 picker-first UI and Android launchable-app bridge are started; Windows materialization now writes selected `process_name` route/DNS rules with direct default | replace fallback suggestions with richer native catalogs where platform proof exists |
| Full activity calendar | Done for beta ledger summary | P2 preview grid exists; backend calendar claims produce `RewardClaim` rows and safe `checked_dates` under rollout flag; Rewards Hub renders safe activity state without noisy gamification | expand the grid into a full month/ledger view only after rollout data exists |
| Achievements ledger | Done for beta safe chips | backend writes safe achievement rows for first wheel, first check-in, and seven-check-in streak under rollout flags; app renders compact safe chips | expand achievement taxonomy only after real reward tuning |
| Live wheel/calendar rewards | Done under backend rollout flags | app exposes active actions only from backend-ready state; backend mutations are ledger-backed, extend access, and return fresh summaries; disabled flags still render as muted non-CTA | keep rollout flags off by default until support/copy/operator approval |
| Promo campaign assignment | Done for beta app-safe slots, live campaign tuning post-beta | app-safe promo-slot rendering exists; platform exposes app/admin promo-slot contracts and forbids third-party ads/tracking payloads in app | add campaign assignment QA and telemetry when real campaigns are scheduled |
| Referral program hardening | Done for beta guardrails, live program tuning post-beta | app reads referral summary and exposes copy/share actions; platform owns referral bonus queue, campaign-send dedupe, and abuse/rate-limit guardrails | tune anti-abuse thresholds, payouts, and campaign rules after live referral data exists |
| Support realtime lifecycle | Done for polling lifecycle, partial for SSE | ticket-backed chat, diagnostic attachments, active-ticket polling, status freshness hints, operator-reply hints, closed/offline lifecycle states, and Telegram fallback visibility exist | add SSE or tuned cadence only after operator workflow proof; keep typing/read receipts out until real support tooling exists |
| Native email linking | Evidence-gated handoff | email/recovery handoff exists; full native form flow stays blocked on delivery/account-linking readiness | keep browser/cabinet continuation until delivery readiness is green |
| Detailed cabinet/account management | Done for P4 entrypoints | cabinet handoff exists; Account details sheet exposes access/device/mode/cabinet/downloads/email entrypoints | deeper account management remains webapp-first |
| Advanced raw rule editor | Debug-only backlog | advanced gate exists | only expose behind explicit responsibility gate for support/debug; never use it as normal app selection UI |

## P4 Map

Owner priority update on `2026-06-04`: P4 is the remaining product-completion
and verification wave after the P3 manual selected-apps bridge. These items
should improve real user capability or release confidence, not add fake active
states.

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Android installed-app picker and Windows process/exe picker | Done for P4 beta | picker-first Rules UI opens a searchable app/process sheet; Android bridge exposes `runtimeEngine.listInstalledApps` for launchable packages; source badges distinguish installed/running/suggested/file candidates; immediate fallback suggestions keep the sheet useful when bridge data is unavailable; Windows picker starts from running processes, discovered Program Files/LocalAppData `.exe` candidates, and curated suggestions; selected-app add uses restrained haptic/tactile feedback; Windows selected-apps config uses TUN process rules and direct default instead of system-proxy behavior | native icons and a true OS file-dialog picker remain polish/backlog, not a beta blocker |
| Live wheel, calendar, and achievements | Done under rollout flags | Rewards Hub has muted disabled states; app can call live wheel/check-in actions when backend summary says enabled; backend writes `RewardClaim`, extends access, refreshes safe achievements, and returns fresh summary; app tests cover live action path | keep reward flags off by default until operator rollout/copy/support approval |
| Support realtime lifecycle | Done for polling lifecycle, partial for SSE | embedded ticket-backed support chat, explicit diagnostic attachment, active-ticket polling, operator-reply hints, closed/offline lifecycle hints, and manual refresh action exist; the app updates messages/status from `GET /api/tickets/{id}` while the screen is open | add SSE or tuned polling cadence only after real operator workflow proof; do not fake typing, read receipts, or operator presence |
| Native email linking and recovery | Evidence-gated handoff for P4 beta | email/recovery handoff and cabinet continuation exist through short-lived sessions; native password/token forms remain out of app while delivery/account-linking readiness is operator-gated | implement native forms only after delivery readiness, recovery UX, and account-link semantics stay green |
| Detailed account and cabinet management | Done for P4 beta entrypoints | app opens cabinet through short-lived token, shows compact access/account summary, and has a details sheet for access/device/mode/cabinet/downloads/email | deeper cabinet management remains webapp-first |
| WARP as a working feature | Done for guarded beta feature, proof-gated for production claim | Home shows the enhanced-protection tile honestly; public `client_policy.warp_policy` is sanitized; the default runtime path is client-local Hiddify-core WARP; backend status/consent/revoke/event endpoints are a lifecycle ledger and no longer require server-managed WireGuard material for client-local consent; authenticated managed profiles may still carry optional runtime material; client bootstrap parses and normalizes `warp_policy`; the Home tile can request explicit user consent when the local runtime lane is available; desktop runtime maps consented WARP into Hiddify options with `warp.enable=true` and local `id=p1`; runtime fallback events are reported to the backend and the admin dashboard has a redacted WARP lifecycle summary | Android release-build proof, Windows release-build proof, and reconnect/recovery smoke remain required before claiming production WARP |
| Responsive/golden width verification | Done for widget matrix, visual screenshots still manual | widget tests cover `360`, `700`, `900`, `1024`, `1180`, and `1440` shell behavior, Home WARP tile, primary connect action, mobile bottom navigation, desktop icon rail, and expanded sidebar | keep screenshot/golden capture as release polish when visual baselines are approved |
| Premium motion pass | Done for P4 beta foundation | connect ritual, status switcher, geometry-matched skeletons, row/chip tactile feedback, muted disabled rewards, sidebar label opacity/width transition, and reduced-motion hooks are covered by code/tests | continue P5 taste polish without changing product claims |

## P5 Map

P5 is the premium-feel wave. It must make the app feel tactile, calm, and
platform-native without pretending that disabled features are live.

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Connect disc ritual | Done for P5 beta | brand-marked connect disc has tactile press scale, finite busy sweep, connected settle, error settle, and reduced-motion-compatible transform/opacity layers covered by widget tests | tune exact timing on physical Android/Windows builds after visual QA |
| Status transitions | Done for P5 beta foundation | Home status label and connect label use short crossfade/slide switchers without layout churn | tune copy and timing after tester feedback |
| Row and chip tactile feedback | Done for P4 rows/chips | Home chips and settings rows have transform/opacity tactile feedback without layout-property animation; selected-app add uses restrained haptic feedback | extend only where new interactive rows appear |
| Geometry-matched skeletons | Done for P5 beta | account, rewards, locations, and support loading states use stable skeleton geometry covered by focused widget tests | tune visual baselines after screenshot/golden approval |
| Disabled feature states | Done for P4 beta | WARP stays honest/gated; wheel and calendar disabled states render as muted non-CTA rows with short status instead of disabled buttons | keep active affordances tied to backend summary state |
| Account and Rewards text density | Done for P4 beta | Account first layer uses settings-style rows; details move into subscription/email/account/rewards sheets | continue copy polish from user testing |
| Windows sidebar collapse polish | Done for P4 beta | desktop sidebar has label opacity/width motion, icon rail, and narrow drawer behavior with responsive matrix coverage | keyboard/focus refinement remains polish |
| Android haptics | Done for P5 beta foundation | connect/redeem/success paths use haptics and selected-app added uses restrained tactile feedback | tune platform-specific haptic intensity on physical devices |

## Approved P5 / WARP Design Contract

Owner approval on `2026-06-05` promoted the P5 and WARP direction from chat
research into an implementation contract:

- [P5 WARP Approved Design](../specs/2026-06-05-p5-warp-approved-design.md)
- [P5 WARP Application Map](../design/2026-06-05-p5-warp-application-map.md)
- [P5 Application Map Consilium Review](../design/2026-06-05-p5-application-map-consilium-review.md)
- [Premium Client AI Assistant Architecture Plan](../archive/superpowers-plans/2026-06-05-premium-client-ai-assistant-architecture.md)

This approval has now been implemented through the Phase 6 local release-beta
refresh. The contract remains the guardrail for future polish and proof work:

1. P5 motion foundation and screen polish are implemented for beta.
2. WARP backend status/consent/revoke/events contracts are implemented as the
   lifecycle ledger for client-local WARP.
3. Optional WARP provisioning, encrypted storage, and rotation contracts remain
   implemented for operator-managed material, but are not required for the
   normal client-local WARP path.
4. WARP client consent persistence, revoke UI, client-local runtime options,
   runtime state machine, fallback diagnostics, and support redaction are
   implemented.
5. Android and Windows release-build proof remains required before any
   production WARP claim.

The generated application map is an internal review artifact. Generated text
inside the image is not product copy and must not override copy, release, or
claim guardrails.

The second-pass Product Design / Image-to-Code review tightens P5 around
public extended-protection naming, no-fake-data rules, screen-specific render
requirements, Windows progressive disclosure, and component-level motion rules.

Phase 0 of the follow-up architecture plan started on `2026-06-05`: app-shell
palette and motion contracts now live under
`packages/app_shell/lib/src/design_system/`, while the existing private
compatibility adapters keep current beta UI behavior stable. The first focused
verification for that slice passed `flutter test
test/design_system_contract_test.dart test/pokrov_seed_app_test.dart` and
`flutter analyze` in `packages/app_shell`.

## Guardrails

- Do not expose raw links, hostnames, ports, protocol names, JSON, CIDR, or
  engine internals in normal UI.
- Do not treat raw subscription links as account proof.
- Do not claim production-proven WARP/enhanced privacy until runtime start,
  failure-mode, Android release-build, and Windows release-build evidence are
  green. Client-local WARP may still be exposed as a beta feature after explicit
  user consent.
- Keep Xray fallback advanced-only.
- Roulette/calendar/referral-rich UI may appear only through backend-owned safe
  state. Mutating reward actions stay muted while flags are disabled and become
  active only when public app APIs, reward ledger, feature flags, rollout proof,
  and copy are approved.
- App promo slots are first-party only. They may open only approved POKROV or
  Telegram handoff URLs and must not introduce ad SDKs, tracking pixels, or
  third-party campaign rendering.
- Keep current outside-store beta honesty until stronger evidence exists.
