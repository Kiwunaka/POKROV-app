# Karing Base Reopen

Date: 2026-06-02
Status: superseded by `2026-06-03-hiddify-karing-happ-client-base-review.md`
Decision owner: owner/operator

## Decision

Reopen the earlier clean-room-only decision and evaluate a Karing-based POKROV client fork.

## Reason

The current clean-room client lane is slow to reach production confidence. Karing already provides a Flutter, cross-platform, sing-box-first client foundation that may reduce Android and Windows runtime risk.

## Gate

Karing is accepted only if the full source tree is buildable, GPL obligations are satisfied, POKROV managed onboarding works, and generic proxy-utility surfaces can be hidden without a near-total rewrite.

## Outcome

The local `karing original app` source tree did not pass the buildable-source
gate because the sibling `vpn-service` package and multiple internal/private
imports are missing locally.

Karing remains useful as a feature reference for rules, DNS, diagnostics,
per-app routing, backup/sync, and novice mode. The preferred spike direction
after the broader Hiddify/Karing/Happ review is Hiddify as the base candidate,
Karing as feature reference, and Happ as UX/packaging reference.

## Non-Goals

This does not overwrite the current POKROV-app lane. It creates a gated candidate lane first.
