# In-App AI Assistant Contract

Last updated: 2026-06-05

This document defines the POKROV in-app AI helper for the `1.0.0-beta` client lane.

## Product Boundary

- The assistant is support-scoped.
- It is not a fifth top-level tab.
- It does not pretend to be a human operator.
- Operator escalation remains ticket-backed through the existing support flow.
- Telegram support remains a fallback, not the primary app UX.

## Current Client Surface

- Support chat shows compact AI helper suggestions above the composer.
- Suggestions only prefill the composer; they do not run app changes.
- Diagnostics still require the existing explicit attach action.
- Any future AI-proposed app action must be modeled as a safe action and require user confirmation before navigation, diagnostics attach, handoff opening, or setting changes.

## Client Models

The app-shell contract lives in:

- `packages/app_shell/lib/src/assistant/pokrov_ai_assistant.dart`

Current model families:

- `PokrovAssistantSession`: support-only session state and optional ticket ID.
- `PokrovAssistantMessage`: user, assistant, operator, and system message roles.
- `PokrovAssistantSuggestion`: support-scoped prompt starter.
- `PokrovAssistantDiagnosticAttachment`: redacted diagnostic payload.
- `PokrovAssistantEscalation`: ticket-backed operator escalation.
- `PokrovAssistantSafeAction`: explicit-confirmation app action.
- `PokrovAssistantApiPlan`: planned backend paths.
- `PokrovAssistantRedactor`: prompt/diagnostic redaction rules.

## Planned Backend API

The existing ticket APIs remain the fallback:

- `POST /api/tickets`
- `GET /api/tickets`
- `GET /api/tickets/{id}`
- `POST /api/tickets/{id}/messages`

If ticket APIs are not enough for live AI help, add session-scoped assistant APIs:

- `POST /api/assistant/sessions`
- `POST /api/assistant/sessions/{id}/messages`
- `GET /api/assistant/sessions/{id}/stream`
- `GET /api/assistant/sessions/{id}/status`
- `POST /api/assistant/sessions/{id}/escalate`
- `POST /api/assistant/actions/confirm`

All assistant endpoints must use the same short-lived app session token model as the app-first client APIs.

## Safety Rules

The assistant must not receive or emit:

- raw sing-box config;
- subscription URLs;
- protocol links;
- keys, tokens, UUIDs, access keys, or bearer material;
- server hostnames, IP topology, hidden node metadata, or WARP material;
- hidden routing internals not already shown in support-safe diagnostics.

The assistant may receive:

- platform;
- app version/build;
- route mode;
- user-visible connection status;
- selected public region/country label;
- support-safe health category.

## Prompt Rules

- State that AI is a helper, not a human operator.
- Prefer user-facing recovery steps: reconnect, refresh profile, change location, attach diagnostics, open ticket, or open Telegram fallback.
- Do not suggest editing raw configs to normal users.
- Do not suggest Xray unless the user is already in Advanced/recovery context.
- Do not claim anonymity, unlimited access, store readiness, trusted signing, RU-origin readiness, or production WARP proof.

## Escalation

Escalate to ticket-backed operator support when:

- user asks for a human;
- assistant confidence is low;
- payment/subscription identity is ambiguous;
- runtime repeatedly fails after basic recovery;
- diagnostics indicate unavailable backend or account state;
- user attempts to paste raw keys/configs or secrets.

The escalation payload must include only `PokrovAssistantDiagnosticAttachment.safeDiagnostics`.
