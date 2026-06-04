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
   `POST /api/bonuses/promo/redeem` contracts;
4. no wheel/calendar hub in UI until mutating reward logic, rollout flags, and
   copy are approved;
5. keep profile loading lazy so the app does not block startup or ordinary
   navigation on bonus data.

This slice is P0/P1 bridge work because the master brief needs bonus/account
clarity before a richer Rewards Hub can safely exist.

## P0 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Hiddify-based runtime direction | Partial | active lane uses pinned `hiddify-core v3.1.8` artifacts; clean-room POKROV shell remains current | separate Hiddify fork/spike gate: provenance packet, Android/Windows build proof, managed profile loop |
| First-launch `new / returning` split | Done for MVP | startup asks new vs returning; completion is file-backed and tested | keep wording lightweight while runtime gates evolve |
| Returning-user restore screen | Done for MVP | first-launch restore panel uses unified redeem, Telegram, cabinet, and raw-key warning | expand accepted code families on backend over time |
| Unified redeem API contract | Partial | platform `POST /api/redeem` supports access keys and promo codes; app uses `AppFirstAccountActionService.redeemCode` | expand gift/claim-token families only when backend support is explicit |
| Safe one-time claim/link semantics | Partial | app rejects raw link as normal account proof in docs; UI copy still needs first-launch warning | show raw-link warning in restore flow; backend keeps structured rejection |
| App profile basics | Partial | grouped account/profile sections, access, redeem, cabinet, Telegram, support, bonus summary, advanced gate exist | keep reducing visible account copy and add only proven states |
| Telegram `+10 days` link/check/claim | Done for MVP | app has link, channel check, claim actions and tests | keep optional, no startup wall |
| Bot parity for subscription/access | Partial | platform bots were updated in root repo; app/cabinet share app-first contracts | add parity smoke checklist before final `1.0.0-beta` handoff |
| Short-lived cabinet token | Done for MVP | app calls `POST /api/client/cabinet-token`; cabinet exchange exists | keep e2e coverage for one-time URL token removal |
| Bonus API contract and MVP endpoints | Partial | channel check/claim live; app reads `GET /api/bonuses/summary` plus safe history from `GET /api/bonuses/history`; platform exposes referral summary, promo redeem, and disabled-by-default wheel/calendar endpoint shells; compact summary/history tested; wheel/calendar UI hidden | keep wheel/calendar mutating flows hidden until reward logic and rollout flags are approved |
| Smart-connect shortlist and route-mode sync | Partial | managed profile returns smart-connect metadata; route mode persisted through backend contract; client does not run RTT loop yet | implement RTT measurement/upload loop and stickiness UI only after runtime proof |
| Claims guardrails | Done for MVP | WARP info-only, selected-apps staged, no stable/store/trusted/RU claims | keep guardrails in tests/docs with each release update |

## P1 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Rewards Hub light | Partial | compact Account summary shows Telegram/referral/promo status and recent safe bonus history; backend referral/promo/history contracts exist; wheel/calendar UI intentionally hidden | add dedicated hub only after copy proves a separate hub is clearer than the compact Account layer |
| App-facing wheel spin endpoint and UI | Partial | app endpoint shell exists and is feature-gated/disabled by default; UI not live | implement reward ledger and rollout proof before enabling UI |
| Calendar check-in endpoint and summary | Partial | app state/check-in endpoint shells exist and are feature-gated/disabled by default; UI not live | implement check-in ledger and rollout proof before enabling UI |
| Support diagnostics flow | Done for MVP create path, partial for lifecycle | chat can attach redacted diagnostics on create | add follow-up diagnostics attachment and polling/SSE after operator flow proof |
| Paywall/subscription UX cleanup | Partial | checkout handoff exists; in-app paywall not built | add paid plan surface only after pricing/copy/legal checks |
| Rules presets UI | Partial | categories shown; selected apps staged | sync backend ruleset catalog and add real enabled states |
| Email recovery polish | Partial | email/cabinet entry exists | add app email linking/recovery UI after email readiness stays green |

## P2 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Full activity calendar | Not started | hidden by design | depends on real calendar ledger, not just disabled endpoint shell |
| Achievements in app | Not started | hidden by design | depends on bonus ledger and copy |
| Rich referral UI | Not started | app-safe referral summary API exists; first-layer UI stays compact | add only if copy/design makes referral sharing useful without clutter |
| Promo slots in app | Not started | platform promo slots exist | add app-safe slot contract and feature flag |
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
- Keep roulette/calendar/referral-rich UI hidden until public app APIs,
  mutating reward logic, feature flags, and copy all exist.
- Keep current outside-store beta honesty until stronger evidence exists.
