# Client Best MVP Consilium

Date: 2026-06-03
Status: accepted synthesis for owner approval

## Context

The owner asked for the best MVP proposal before starting the full build. The
request was not just visual: external reviewers were given read-only access to
the active client repo and allowlisted backend files so they could judge the
real API surface, runtime work, support system, WARP state, and current Flutter
shell.

The consilium used only read-only inspection. It was explicitly forbidden from
reading secrets, auth files, `.env`, SSH keys, `ops-local`, deploy material, or
writing files.

## Inputs Checked

Reviewers inspected the current platform and client truth, including:

- app-first trial and managed profile API contracts.
- route-policy, smart-connect, latency upload, Telegram linking, and redeem
  surfaces.
- existing support ticket endpoints and `tickets_repo.py`.
- existing `support_ai_service.py`.
- active POKROV-app product, design, and implementation docs.
- `packages/app_shell/lib/app_shell.dart`.
- `packages/runtime_engine/lib/runtime_engine.dart`.
- `packages/support_context/lib/support_context.dart`.

## Consensus

The best MVP is not a broad feature dump. It is a tight "daily use plus help"
slice:

1. a working app-first connection contour.
2. a premium, stable Windows/mobile shell.
3. a very simple Home screen.
4. an embedded support chat.
5. safe diagnostics preview.
6. honest WARP/enhanced-privacy signalling.

The backend already has enough app-first and ticket infrastructure to support
the first approval build. The biggest immediate risks are the Windows responsive
layout, the still-link-based support surface, and any false WARP claims.

## Decision

Proceed toward a **Premium Shell V2 + Embedded Support Chat** MVP.

Build the UI approval slice first, while keeping the runtime and API contracts
honest:

- fix the Windows responsive shell before adding more surfaces.
- rebuild Account/Profile as grouped settings sections.
- expose support as an embedded chat route, not a Telegram handoff sheet.
- show WARP only as a disabled/upcoming Home tile until runtime proof exists.
- use restrained motion and skeletons after layout is stable.

## Support API Decision

The consilium split on whether the client should call `/api/tickets*` directly
or introduce `/api/client/support/*`.

Local synthesis:

- **MVP implementation may use existing `/api/tickets*` through a client-side
  `SupportService` adapter** because app-session ticket creation is already
  tested and the backend is ready.
- **The product-facing contract should remain facade-ready**. The client should
  not scatter raw ticket endpoint assumptions through widgets.
- If the backend facade is quick, prefer:
  - `POST /api/client/support/sessions`
  - `GET /api/client/support/sessions/{id}/messages`
  - `POST /api/client/support/sessions/{id}/messages`
  - `POST /api/client/support/sessions/{id}/diagnostics`
  - `POST /api/client/support/sessions/{id}/escalate`
  - `GET /api/client/support/sessions/{id}/status`
- If the facade is not ready, the same `SupportService` adapter can temporarily
  map to `/api/tickets*` without changing the chat UI.

No fake operator replies, fake ticket IDs, fake typing indicators, fake SLA
timers, or fake cross-device history are allowed.

## WARP Decision

Use Pokrov WARP as a runtime primitive, not as a raw product surface.

Current facts:

- POKROV Core `warp` and `warp2` options exist in runtime configuration.
- POKROV runtime defaults keep WARP disabled.
- POKROV has no verified backend/profile contract, WARP account/config
  provisioning, Android proof, Windows proof, or support diagnostics for an
  active WARP feature yet.

Therefore:

- MVP Home may show `Расширенная приватность` / `WARP · готовится`.
- MVP must not show an enabled toggle or active state.
- MVP must not claim additional anonymity, ad-free access, no restrictions, or
  better privacy from WARP.
- Real integration should later be controlled by backend-managed profile policy,
  for example `enhanced_privacy` / `warp_policy`, rather than raw UI settings.

## Balancing And API Decision

Do not create a large new balancer API surface for MVP.

Reuse and extend the existing app-first path:

- `GET /api/client/profile/managed` remains the main managed profile and
  smart-connect contract.
- `smart_connect` shortlist remains backend-owned.
- `POST /api/client/nodes/latency-samples` remains the client RTT upload path.
- future WARP/runtime health can extend existing profile policy and telemetry
  instead of creating many parallel endpoints.

Minimum future WARP additions:

- managed profile fields for enhanced-privacy availability and mode.
- client runtime event/status upload for WARP start failure, fallback, and
  observed latency impact.
- support diagnostics fields that say WARP intended/enabled/failed without
  exposing raw WireGuard account material.

## MVP Cuts

Cut from the first approval build:

- working WARP toggle.
- SSE/websocket support chat.
- live operator typing or presence.
- roulette, calendar, achievements, referral-rich UI.
- in-app paywall and plan purchase UI.
- full Android package picker / Windows process picker.
- raw config editor, xray fallback toggle, and advanced import outside warning
  gate.
- cabinet SSO token UI unless the endpoint lands before implementation.
- fake news feed or always-visible explanatory blocks.

## Implementation Order

1. Windows responsive shell and sidebar collapse.
2. Account/Profile grouped IA.
3. Home simplification and honest WARP tile.
4. Embedded support chat shell with local mock state.
5. Safe diagnostics preview and attachment model.
6. Support adapter integration through `/api/tickets*` or facade.
7. Motion/premium pass after layout is stable.
8. Runtime/WARP policy integration after build proof and backend contract.

## Acceptance Criteria

- Windows at narrow widths never collapses text into one-letter columns.
- Home contains only status, connect disc, location chip, route chip, and WARP
  tile; no paragraphs or duplicate CTAs.
- Account/Profile reads like grouped settings, not one long flat list.
- Support opens inside the app as a chat route with message bubbles, composer,
  diagnostics preview, and Telegram fallback.
- Diagnostics preview exposes only safe allowlisted fields.
- WARP tile is visibly disabled/upcoming.
- Motion uses transform/opacity, respects reduced motion, and does not hide
  layout instability.
