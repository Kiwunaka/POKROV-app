# In-App AI Assistant Contract

Last updated: 2026-07-11

This document defines the support-scoped POKROV assistant for the
`1.0.0-beta` client line.

## Product Boundary

- The assistant belongs to Support. It is not a fifth top-level tab.
- It identifies itself as an automated helper, not a human operator.
- It may explain recovery steps and return safe suggested actions.
- It cannot change settings, navigate, attach diagnostics, or open a handoff
  without explicit user confirmation.
- Ticket-backed operator escalation remains the human-support path.
- Telegram support remains a fallback, not the primary in-app flow.

## Implemented API

The app-shell calls:

```text
POST /api/client/support/assistant
Authorization: Bearer <short-lived app session token>
```

Request fields:

- `message`: non-empty user text;
- `scope`: fixed to `support`;
- `ticketId`: optional active ticket ID;
- `assistantSessionId`: optional opaque server-issued continuity token;
- `safeDiagnostics`: redacted support-safe values only.

The current client reads the assistant reply, escalation flag, and safe
suggested actions. App-session renewal follows the same client API behavior as
other app-first calls. The focused contract is covered by
`app_first_runtime_bootstrap_test.dart` under
`client support assistant uses app-session auth`.

Ticket APIs remain the operator escalation and continuity lane:

- `POST /api/tickets`
- `GET /api/tickets`
- `GET /api/tickets/{id}`
- `POST /api/tickets/{id}/messages`

The platform owns backend endpoint behavior. This client document owns how the
app invokes it and what the UI may expose.

## Current Client Surface

- Support exposes a compact assistant sheet and prompt suggestions.
- Suggestions prefill or submit support questions; they do not run app
  mutations.
- Diagnostics require the existing explicit attach/confirmation flow.
- The user can leave the assistant for ticket-backed human support.

## Assistant Continuity

- The assistant-session token is optional and opaque. The server binds it to
  the authenticated owner and `support` surface; it is not authentication.
- The assistant sheet retains a returned token only for its open lifetime.
  Closing the sheet, reopening it, or restarting the app begins fresh
  continuity; no chat history is persisted by the client.
- The four request diagnostics (`app_version`, `platform`, `route_mode`, and
  `connection_status`) remain request context only and do not enter model
  memory.

The shared client contract lives in:

- `packages/app_shell/lib/src/assistant/pokrov_ai_assistant.dart`
- `packages/app_shell/lib/app_first_runtime_bootstrap.dart`
- `packages/app_shell/lib/src/features/support/support_chat.dart`

## Data Boundary

Allowed input is limited to support-safe values such as:

- platform and app version;
- route mode and user-visible connection state;
- selected public region/country label;
- support-safe health and enhanced-protection state;
- optional ticket ID.

The assistant must not receive or emit:

- raw sing-box config or subscription/protocol links;
- keys, tokens, UUIDs, access keys, bearer material, or raw profiles;
- private hostnames, IP topology, hidden node metadata, or control surfaces;
- WireGuard keys, raw WARP material, or hidden routing internals.

Redaction is required in both client-side diagnostic construction and the
platform endpoint. A safe UI label such as `WARP` does not relax this boundary.

## Response And Action Rules

- Prefer recovery steps users can understand: reconnect, refresh profile,
  change location, attach diagnostics, open a ticket, or use Telegram fallback.
- Do not suggest raw-config editing to normal users.
- Do not suggest Xray outside an explicit Advanced/recovery context.
- Suggested actions are proposals, never automatic commands.
- Do not claim anonymity, unlimited access, stable/store readiness, trusted
  signing, RU-origin readiness, or production WARP proof.

## Escalation

Escalate to ticket-backed operator support when:

- the user asks for a human;
- assistant confidence is low;
- payment or subscription identity is ambiguous;
- runtime recovery repeatedly fails;
- diagnostics show unavailable backend/account state;
- the user attempts to paste secrets, keys, or raw configuration.

Escalation may include only the already-redacted safe diagnostic payload.
