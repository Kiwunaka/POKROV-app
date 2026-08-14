# In-App AI Assistant Contract

Last updated: 2026-08-13

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
`client support assistant uses app-session auth and a safe wire token`.

Ticket APIs remain the operator escalation and continuity lane:

- `POST /api/tickets`
- `GET /api/tickets`
- `GET /api/tickets/{id}`
- `POST /api/tickets/{id}/messages`

The platform owns backend endpoint behavior. This client document owns how the
app invokes it and what the UI may expose.

## Current Client Surface

- Support keeps the primary screen focused on the conversation, one compact
  lifecycle status, and the composer. Diagnostic attachment stays behind the
  composer paperclip; Telegram and the optional AI sheet stay as compact app
  bar actions instead of repeating as full-width cards.
- The assistant sheet opens directly on one composer. It does not repeat a
  greeting bubble or expose auto-fill prompt chips. Safe actions returned with
  a reply render as compact, allowlisted controls: recovery/access actions ask
  a focused follow-up, diagnostics opens the existing explicit attachment
  preview, and unknown action keys stay hidden.
- Human support remains a compact manual escape while the assistant is still
  proposing recovery. It becomes the emphasized full-width action only when
  the server reply sets `shouldEscalate=true`; it is never opened
  automatically.
- The entry and sheet scope name the supported first recovery areas: WARP,
  locations, route mode, and system permissions. Detailed steps still come
  from the bounded assistant reply and remain proposals rather than automatic
  device changes.
- Ticket history uses one compact lifecycle state. Initial-load and polling
  failures expose one retry, not a second notice with a duplicate action.
- A failed ticket send keeps the draft, removes the unconfirmed optimistic
  bubble, and retries without duplicating the user's message.
- A transport failure in the assistant sheet exposes one inline retry while
  retaining the single visible user question. It does not emit the
  knowledge-base no-answer fallback unless a valid assistant response is
  actually empty or asks for escalation.
- The ticket and assistant composers, retry state, and human escape action stay
  reachable above the on-screen keyboard.
- Diagnostics require the existing explicit attach/confirmation flow.
- The user can leave the assistant for ticket-backed human support.

## Assistant Continuity

- Every assistant request sends the fixed `scope="support"`; the client does
  not let the sheet or caller select another scope.
- The assistant-session token is optional and opaque. The server binds it to
  the authenticated owner and isolates it under `surface="app"`; it is not
  authentication.
- The assistant sheet retains a returned token only for its open lifetime.
  Closing the sheet, reopening it, or restarting the app begins fresh
  continuity; no chat history is persisted by the client.
- If a continued request or its reply parsing fails, the sheet discards its
  local token before the next request so an unseen server reply cannot rejoin
  later visible context.
- Client request diagnostics remain request context only and do not enter model
  memory. The authenticated platform endpoint may add an identifier-free,
  same-account scalar snapshot for access state, days left, plan, active-device
  count, Telegram link/bonus state, and panel runtime. Server-owned facts
  override colliding client keys; the model receives no arbitrary API or DB
  access.

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
- same-account access, device-count, Telegram-bonus, and panel-runtime scalar
  facts prepared by the server without identifiers;
- optional ticket ID.

The assistant must not receive or emit:

- raw sing-box config or subscription/protocol links;
- keys, tokens, UUIDs, access keys, bearer material, or raw profiles;
- private hostnames, IP topology, hidden node metadata, or control surfaces;
- account, Telegram, or device IDs, usernames, email, and raw panel payloads;
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
