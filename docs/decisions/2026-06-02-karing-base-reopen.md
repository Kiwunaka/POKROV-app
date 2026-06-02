# Karing Base Reopen

Date: 2026-06-02
Status: reopened for gated spike
Decision owner: owner/operator

## Decision

Reopen the earlier clean-room-only decision and evaluate a Karing-based POKROV client fork.

## Reason

The current clean-room client lane is slow to reach production confidence. Karing already provides a Flutter, cross-platform, sing-box-first client foundation that may reduce Android and Windows runtime risk.

## Gate

Karing is accepted only if the full source tree is buildable, GPL obligations are satisfied, POKROV managed onboarding works, and generic proxy-utility surfaces can be hidden without a near-total rewrite.

## Non-Goals

This does not overwrite the current POKROV-app lane. It creates a gated candidate lane first.
