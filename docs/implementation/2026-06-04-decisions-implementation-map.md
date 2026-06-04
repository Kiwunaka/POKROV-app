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
2. compact Account summary surface for Telegram, referrals, promo entry, and
   recent safe bonus history;
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
   activity grid, achievements, referral card, first-party promo slots, and
   disabled mutating actions until backend state marks the mechanics enabled;
8. keep profile loading lazy so the app does not block startup or ordinary
   navigation on bonus data.

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
| Claims guardrails | Done for MVP | WARP info-only, selected-apps staged, no stable/store/trusted/RU claims | keep guardrails in tests/docs with each release update |

## P1 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Rewards Hub light | Done for P1 preview, partial for live rewards | Account summary opens a dedicated hub with Telegram/referral/promo/history context, safe wheel/calendar previews, activity grid, achievements, and referral card | add live reward mutations only after backend ledger and rollout proof |
| App-facing wheel spin endpoint and UI | Done for P1 preview, partial for live spin | app parses wheel state from summary and shows roulette UI with disabled spin action while backend returns disabled state | implement reward ledger and rollout proof before enabling spin |
| Calendar check-in endpoint and summary | Done for P1 preview, partial for live check-in | app parses calendar state from summary and shows activity calendar preview with disabled check-in action while backend returns disabled state | implement check-in ledger and rollout proof before enabling check-in |
| Support diagnostics flow | Done for P1 follow-up attachment, partial for realtime lifecycle | chat can attach redacted diagnostics on create and on the next follow-up reply after explicit user confirmation | add polling/SSE only after operator flow proof |
| Paywall/subscription UX cleanup | Done for P1 safe handoff, partial for priced paywall | Account opens a subscription sheet with current access, checkout handoff, and cabinet handoff without unsupported prices | add paid plan cards only after pricing/copy/legal checks |
| Rules presets UI | Done for P1 seed/catalog states, partial for live catalog and picker | Rules shows safe ruleset/package-catalog versions, enabled/staged/locked preset states, and selected apps remains staged | wire live backend catalog sync and add Android package / Windows process picker only after OS enforcement proof |
| Email recovery polish | Done for P1 handoff, partial for native email auth | Account opens an email/recovery sheet with add-email, cabinet, and recovery handoffs | add native email linking only after delivery readiness stays green |

## P2 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Full activity calendar | Partial | Rewards Hub shows a compact activity grid derived from safe summary state | replace preview with ledger-backed full calendar when check-in history exists |
| Achievements in app | Partial | Rewards Hub shows safe achievement chips derived from opening, Telegram, referral, and streak state | replace preview chips with backend achievement ledger when available |
| Rich referral UI | Partial | Rewards Hub shows referral code/card and copy action without pushing referral spam into the first layer | add share link/deep-link once referral summary contract is wired into app shell |
| Promo slots in app | Done for P2 safe display, partial for live campaigns | Rewards Hub fetches `GET /api/client/promo-slots?surface=app` best-effort, renders enabled first-party slots, and falls back to a quiet empty state | add campaign assignment, rollout QA, and feature-flag proof before relying on remote campaign content |
| Advanced raw rule editor | Not started | advanced gate exists | keep out of normal UI until support/debug need is proven |
| Detailed cabinet/account management | Partial | cabinet continuation exists | expand webapp first, then expose app entry points |
| Windows process picker | Not started | selected-apps staged only | implement with OS enforcement proof |

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
