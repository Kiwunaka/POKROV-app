# Karing Vs Clean-Room Gate

Date: 2026-04-18
Status: closed
Decision owner: global rework, client lane

## Purpose

Decide whether the new-base client should begin from an adapted `Karing` base or from a `clean-room` POKROV-specific shell.

## Source Inputs

- Root product and client docs in this workspace
- Karing official repository: <https://github.com/KaringX/karing>
- Karing official site: <https://karing.app/en/>

## Observed Facts About Karing

Based on the official repo and site, `Karing` is:

- a Flutter-based GUI on top of `sing-box`
- a broad proxy utility rather than a product-specific app-first shell
- centered on imported subscriptions, routing rules, node groups, and backup/sync features
- already cross-platform, including `Android` and `Windows`

Inference:

- `Karing` likely accelerates platform-shell and engine plumbing
- `Karing` also likely brings extra generic-proxy surface area that conflicts with the narrower `POKROV` consumer-first story unless it is heavily pruned

## Decision Matrix

| Criterion | Karing base | Clean-room |
| --- | --- | --- |
| Time to first runnable shell | Faster if upstream import is acceptable | Slower at the start |
| Fit for `app-first` onboarding | Weaker without significant reshaping | Stronger by default |
| Brand and copy debt | Higher | Lower |
| Generic import or rules UI debt | Higher | Lower |
| Control over architecture | Medium | High |
| Migration risk from bridge client | Medium | Medium |
| Long-term product specificity | Medium | High |
| Short-term implementation leverage | High | Medium |

## Gate Questions

Choose `Karing` only if all of these are true:

1. the team wants to reuse an existing Flutter plus `sing-box` shell immediately
2. licensing and notice obligations are reviewed before import
3. the team accepts a focused pruning wave for generic subscription, sync, and proxy-utility surfaces
4. platform velocity matters more than starting from a narrower product model

Choose `clean-room` if any of these are true:

1. the top priority is a strict `POKROV` consumer-first shell
2. the team wants the codebase to mirror the app-first backend contracts from day one
3. minimizing inherited UI, naming, and product-scope debt matters more than initial speed
4. the team wants shared package boundaries designed around `POKROV` support, routing, and access semantics rather than general proxy tooling

## Final Decision

Proceed `clean-room`.

Reason:

- the `POKROV` product direction is specific, consumer-first, and app-first
- the official `Karing` materials describe a broader multi-subscription proxy utility with extra product-surface debt
- the current Wave 7 lane already implements the shared shell, runtime contracts, and four-platform seeds as a clean-room program, so reopening the base would add migration debt instead of reducing it

Re-open the `Karing` path only if a later explicit decision says the team accepts that pruning and migration cost.

## Recorded Follow-Up Constraints

- keep the next-client lane product-shaped around `POKROV` app-first contracts instead of generic subscription import surfaces
- do not import upstream `Karing` code into this lane unless a separate follow-up decision explicitly re-opens the base choice
- continue hardening the existing clean-room lane instead of rebuilding the same contracts on top of a different starter
