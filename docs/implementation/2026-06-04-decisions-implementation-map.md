# Decisions Implementation Map

Date: 2026-06-04
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
   first-party promo slots, and disabled mutating actions until backend state
   marks the mechanics enabled;
8. keep profile loading lazy so the app does not block startup or ordinary
   navigation on bonus data;
9. Rules selected-apps mode now has a picker-first UX with Android native
   launchable-app bridge support, immediate fallback suggestions, Windows
   running-process suggestions, manual entry retained for unusual app IDs, and
   Windows TUN/process routing proof so selected `.exe` values go through
   POKROV while the rest of the device stays direct;
10. embedded support chat now polls the active ticket, refreshes status, and
    shows operator replies in-app without forcing the user back to Telegram;
11. WARP/enhanced privacy now has a backend-owned policy contract, sanitized
    public metadata, managed-profile-only runtime material, client parsing, and
    a Home consent gate that keeps Hiddify `warp.enable=false` until the user
    explicitly turns on a runtime-ready managed policy.

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
| Bonus API contract and MVP endpoints | Done for MVP | channel check/claim live; app reads `GET /api/bonuses/summary` plus safe history from `GET /api/bonuses/history`; platform exposes referral summary, promo redeem, unified gift redeem, and disabled-by-default wheel/calendar endpoint shells; compact summary/history plus wheel/calendar state parsing are tested | keep wheel/calendar mutating flows disabled until reward logic and rollout flags are approved |
| Smart-connect shortlist and route-mode sync | Done for MVP | managed profile returns smart-connect metadata plus internal probe targets; route mode persists through backend contract; client performs best-effort RTT probe/upload and applies the 15% stickiness threshold with tests | keep smart-connect hidden from first-layer UI; collect live release-build telemetry before exposing any manual controls |
| Claims guardrails | Done for MVP | WARP info-only, raw rule editing hidden from normal UI, no stable/store/trusted/RU claims | keep guardrails in tests/docs with each release update |

## P1 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Rewards Hub light | Done for P1 preview, partial for live rewards | Account summary opens a dedicated hub with Telegram/referral/promo/history context, safe wheel/calendar previews, activity grid, achievements, and referral card | add live reward mutations only after backend ledger and rollout proof |
| App-facing wheel spin endpoint and UI | Done for P1 preview, partial for live spin | app parses wheel state from summary and shows roulette UI with disabled spin action while backend returns disabled state | implement reward ledger and rollout proof before enabling spin |
| Calendar check-in endpoint and summary | Done for P1 preview, partial for live check-in | app parses calendar state from summary and shows activity calendar preview with disabled check-in action while backend returns disabled state | implement check-in ledger and rollout proof before enabling check-in |
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
| Full activity calendar | Not started for ledger-backed UI | P2 preview grid exists | add backend check-in history/ledger, then render full calendar |
| Achievements ledger | Not started for live achievements | P2 safe chips exist | add backend achievement ledger and replace preview chips |
| Live wheel/calendar rewards | Not started for mutation | disabled endpoint shells and disabled UI actions exist | enable only after reward ledger, feature flags, rollout proof, and copy |
| Promo campaign assignment | Not started for live campaigns | P2 app-safe promo-slot rendering exists | add assignment, QA, rollout flags, and campaign telemetry |
| Referral program hardening | Not started for live program tuning | P2 referral summary/share UI exists | add anti-abuse, bonus/payout ledger, and campaign tuning |
| Support realtime lifecycle | Started with client polling | ticket-backed chat, diagnostic attachments, and active-ticket polling exist; operator replies and status changes appear in the app after refresh | add SSE/status freshness hints and operator escalation/offline states after operator workflow proof |
| Native email linking | Not started | email/recovery handoff exists | add native email auth only after delivery readiness |
| Detailed cabinet/account management | Not started in app | cabinet handoff exists | expand webapp account management first, then app entry points |
| Advanced raw rule editor | Debug-only backlog | advanced gate exists | only expose behind explicit responsibility gate for support/debug; never use it as normal app selection UI |

## P4 Map

Owner priority update on `2026-06-04`: P4 is the remaining product-completion
and verification wave after the P3 manual selected-apps bridge. These items
should improve real user capability or release confidence, not add fake active
states.

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Android installed-app picker and Windows process/exe picker | Started, with route proof | picker-first Rules UI opens a searchable app/process sheet; Android bridge exposes `runtimeEngine.listInstalledApps` for launchable packages; immediate fallback suggestions keep the sheet useful when bridge data is unavailable; Windows picker starts from running processes plus curated `.exe` suggestions; Windows selected-apps config now uses TUN process rules and direct default instead of system-proxy behavior | expand Android/Windows catalogs with richer labels/icons and native exe path selection as platform proof becomes available |
| Live wheel, calendar, and achievements | Not started for live mutations | Rewards Hub preview, disabled wheel/calendar endpoint shells, compact calendar grid, and safe achievement chips exist | add reward ledger, feature flags, rollout proof, and copy before enabling spin/check-in/achievement claims |
| Support realtime lifecycle | Started | embedded ticket-backed support chat, explicit diagnostic attachment, and active-ticket polling exist; the app updates messages/status from `GET /api/tickets/{id}` while the screen is open | add SSE or tuned polling cadence, stale/offline indicator, and operator escalation states without fake operator presence |
| Native email linking and recovery | Not started for native app flow | email/recovery handoff and cabinet continuation exist | add native email linking/recovery only after delivery readiness and account-linking semantics are green |
| Detailed account and cabinet management | Not started in app | app opens cabinet through short-lived token and shows compact access/account summary | expose detailed account management through app-safe entrypoints or a polished cabinet continuation, without turning Account into a dense dashboard |
| WARP as a working feature | Started as guarded policy/runtime/consent bridge | Home can show an honest disabled/upcoming WARP tile; public `client_policy.warp_policy` is sanitized; authenticated managed profiles may carry runtime-ready WARP material; client bootstrap parses `warp_policy`; the Home tile can request explicit user consent only for runtime-ready policy; desktop runtime maps WARP into Hiddify options only when policy is ready and consented, while incomplete or non-consented policy stays disabled | add live WARP provisioning, safe storage/rotation, fallback diagnostics, Android proof, Windows proof, and reconnect/recovery UX before claiming WARP as working |
| Responsive/golden width verification | Not started for the full matrix | widget tests cover key shell behavior, but not the full visual matrix | capture and review `360`, `700`, `900`, `1024`, `1180`, and `1440` widths for Russian text, Home density, sidebar behavior, and no one-letter wrapping |
| Premium motion pass | Partial foundation only | motion policy, reduced-motion hooks, skeleton components, and connect-disc structure exist | finish connect ritual, skeleton consistency, status transitions, sidebar collapse, and row/chip feedback as a dedicated quality pass |

## P5 Map

P5 is the premium-feel wave. It must make the app feel tactile, calm, and
platform-native without pretending that disabled features are live.

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Connect disc ritual | Partial foundation | brand-marked connect disc exists | add press scale, finite ring sweep, connected settle, and error settle using transform/opacity and reduced-motion fallback |
| Status transitions | Not started as a dedicated pass | connection statuses render in the shell | add `160-220ms` crossfade/slide transitions without leaving stale status text in the tree |
| Row and chip tactile feedback | Not started as a dedicated pass | rows and chips exist across Home, Locations, Rules, Rewards, and Account | add short press feedback for rows/chips without bounce, glow, or layout-property animation |
| Geometry-matched skeletons | Partial | motion skeleton components exist | ensure skeleton dimensions match final rows/cards/chips so lazy loading causes no layout shift |
| Disabled feature states | Partial | WARP, wheel, and calendar stay disabled/upcoming instead of active | make disabled WARP/wheel/calendar look muted and non-CTA, with one short reason and no active affordance |
| Account and Rewards text density | Partial | grouped Account and Rewards Hub exist | reduce first-layer copy, prefer iOS Settings-style rows and values, and move explanations into sheets/details |
| Windows sidebar collapse polish | Partial | desktop sidebar, narrow drawer, and collapse behavior exist | add label opacity and width transitions without content jumps, and verify keyboard/focus behavior |
| Android haptics | Not started | Android shell can host platform feedback | add restrained haptics for connect, redeem success, selected-app added, and other clear success states |

## Guardrails

- Do not expose raw links, hostnames, ports, protocol names, JSON, CIDR, or
  engine internals in normal UI.
- Do not treat raw subscription links as account proof.
- Do not claim active WARP/enhanced privacy until backend policy, safe storage,
  runtime start, failure-mode, Android, and Windows evidence are green.
- Keep Xray fallback advanced-only.
- Roulette/calendar/referral-rich UI may appear only as a safe Rewards Hub
  preview while backend state is disabled. Mutating reward actions stay disabled
  until public app APIs, reward ledger, feature flags, rollout proof, and copy
  all exist.
- App promo slots are first-party only. They may open only approved POKROV or
  Telegram handoff URLs and must not introduce ad SDKs, tracking pixels, or
  third-party campaign rendering.
- Keep current outside-store beta honesty until stronger evidence exists.
