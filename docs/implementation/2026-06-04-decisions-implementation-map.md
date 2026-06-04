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

The next code slice is:

1. first-launch `new / returning` split;
2. returning-user restore surface using the unified app redeem path;
3. no raw subscription link as account proof;
4. keep the existing POKROV shell and runtime flow intact after the user chooses
   the new-user path.

This slice is P0 because the master brief explicitly says returning users must
restore existing access before ordinary route-mode setup.

## P0 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Hiddify-based runtime direction | Partial | active lane uses pinned `hiddify-core v3.1.8` artifacts; clean-room POKROV shell remains current | separate Hiddify fork/spike gate: provenance packet, Android/Windows build proof, managed profile loop |
| First-launch `new / returning` split | In progress | profile has code entry, but startup does not ask new vs returning | implement first-launch prompt and tests |
| Returning-user restore screen | In progress | profile redeem and cabinet/Telegram actions exist | add first-launch restore panel with code, Telegram, cabinet, and manual-key warning |
| Unified redeem API contract | Done for first slice | platform has `POST /api/redeem`; app uses `AppFirstAccountActionService.redeemCode` | expand accepted code families on backend over time |
| Safe one-time claim/link semantics | Partial | app rejects raw link as normal account proof in docs; UI copy still needs first-launch warning | show raw-link warning in restore flow; backend keeps structured rejection |
| App profile basics | Partial | grouped account/profile sections, access, redeem, cabinet, Telegram, support, advanced gate exist | add lighter rewards/account summary after bonus API summary lands |
| Telegram `+10 days` link/check/claim | Done for MVP | app has link, channel check, claim actions and tests | keep optional, no startup wall |
| Bot parity for subscription/access | Partial | platform bots were updated in root repo; app/cabinet share app-first contracts | add parity smoke checklist before final `1.0.0-beta` handoff |
| Short-lived cabinet token | Done for MVP | app calls `POST /api/client/cabinet-token`; cabinet exchange exists | keep e2e coverage for one-time URL token removal |
| Bonus API contract and MVP endpoints | Partial | channel check/claim live; summary contract documented; wheel/calendar hidden | implement app-facing bonus summary/referral/promo endpoints before Rewards Hub |
| Smart-connect shortlist and route-mode sync | Partial | managed profile returns smart-connect metadata; route mode persisted through backend contract; client does not run RTT loop yet | implement RTT measurement/upload loop and stickiness UI only after runtime proof |
| Claims guardrails | Done for MVP | WARP info-only, selected-apps staged, no stable/store/trusted/RU claims | keep guardrails in tests/docs with each release update |

## P1 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Rewards Hub light | Not started | wheel/calendar UI intentionally hidden | add only after bonus summary/referral endpoints exist |
| App-facing wheel spin endpoint and UI | Not started | bot/admin wheel exists, app endpoint not live | backend API plus feature flag before UI |
| Calendar check-in endpoint and summary | Not started | no app API | backend API plus feature flag before UI |
| Support diagnostics flow | Done for MVP create path, partial for lifecycle | chat can attach redacted diagnostics on create | add follow-up diagnostics attachment and polling/SSE after operator flow proof |
| Paywall/subscription UX cleanup | Partial | checkout handoff exists; in-app paywall not built | add paid plan surface only after pricing/copy/legal checks |
| Rules presets UI | Partial | categories shown; selected apps staged | sync backend ruleset catalog and add real enabled states |
| Email recovery polish | Partial | email/cabinet entry exists | add app email linking/recovery UI after email readiness stays green |

## P2 Map

| Decision | Status | Current Evidence | Next Action |
| --- | --- | --- | --- |
| Full activity calendar | Not started | hidden by design | depends on P1 calendar API |
| Achievements in app | Not started | hidden by design | depends on bonus ledger |
| Rich referral UI | Not started | no app summary endpoint | add after referral summary API |
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
- Keep roulette/calendar/referral-rich UI hidden until public app APIs and
  feature flags exist.
- Keep current outside-store beta honesty until stronger evidence exists.
