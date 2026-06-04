# P5 WARP Approved Design

Date: 2026-06-05
Status: owner-approved design contract / implementation not started in this doc
Owner: POKROV-app/main

## Approval

The owner approved the P5/WARP direction after the OpenCode-go consilium pass
and requested the direction be recorded before implementation.

This contract supersedes loose chat memory for the next P5 and WARP wave. It
does not mark P5 or WARP as implemented.

## Inputs

- Current implementation map:
  [../implementation/2026-06-04-decisions-implementation-map.md](../implementation/2026-06-04-decisions-implementation-map.md)
- WARP guardrail:
  [../decisions/2026-06-03-hiddify-core-warp-status.md](../decisions/2026-06-03-hiddify-core-warp-status.md)
- Premium shell direction:
  [../design/2026-06-03-client-premium-shell-v2-brief.md](../design/2026-06-03-client-premium-shell-v2-brief.md)
- Chat/responsive/WARP/motion brief:
  [../design/2026-06-03-client-chat-responsive-warp-motion-brief.md](../design/2026-06-03-client-chat-responsive-warp-motion-brief.md)
- Application map render:
  [../design/2026-06-05-p5-warp-application-map.md](../design/2026-06-05-p5-warp-application-map.md)

OpenCode-go consilium lanes used for the review:

- `opencode-go/minimax-m3`
- `opencode-go/qwen3.7-max`
- `opencode-go/mimo-v2.5-pro`
- `opencode-go/glm-5.1`
- `opencode-go/deepseek-v4-pro`
- `opencode-go/kimi-k2.6`

## Product Verdict

P5 is a premium-feel wave, not another information-architecture rewrite. The
app should feel like a quiet daily utility: fast, tactile, predictable, and
platform-native.

WARP is not yet a working product feature. The current code has a useful policy
bridge and desktop runtime mapping, but a production-grade WARP feature still
requires provisioning, secure material handling, consent/revoke persistence,
health diagnostics, runtime fallback, Android proof, and Windows proof.

## P5 Definition Of Done

P5 is complete when the client has:

- connect-disc ritual with press scale, finite ring sweep, connected settle, and
  error settle;
- status transitions using `160-220ms` crossfade/slide without stale status
  text left in the tree;
- geometry-matched skeletons for async panels and sheets, with no layout shift;
- tactile row/chip feedback only on real actions;
- Android haptics for connect/redeem/success/selected-app added states;
- Windows sidebar hover, keyboard focus, and collapse polish;
- reduced-motion fallback for all premium motion;
- first-layer copy trimmed to short labels and values, with explanations moved
  into sheets/details;
- responsive verification across `360`, `700`, `900`, `1024`, `1180`, and
  `1440` widths.

Motion rules:

- animate only transform and opacity on hot paths;
- no particles, confetti, neon, animated gradient spectacle, or bounce-heavy
  effects;
- no layout-property animation for width, height, margin, or padding on hot
  paths;
- disabled future features stay muted and informational, not fake CTAs.

## Screen Contract

Home:

- One connect/disconnect focus.
- Current status, location chip, route-mode chip, and a calm WARP/preparing
  chip or row only when it does not compete with the primary action.
- No long paragraphs, no repeated CTA, no Telegram/cabinet/reward clutter on
  the first screen.

Rules:

- Row-based routing mode and selected-app controls.
- Android installed-app picker and Windows process/exe picker remain the normal
  custom-app path.
- Raw rule editing remains debug/advanced only behind a responsibility gate.

Locations:

- Auto location remains the default.
- Country rows stay compact with ping/load signal only when supported by real
  data.
- No transport matrix or protocol internals in normal UI.

Account:

- iOS Settings-like grouped rows for access, sync, Telegram, email, cabinet,
  devices, support, diagnostics, downloads, and advanced.
- Account should not duplicate Home connection state except as compact
  diagnostic context inside details.

Rewards:

- Wheel, calendar, achievements, referral, and promo stay backend-flag-owned.
- Disabled rewards render as muted rows/cards with short reasons.
- Active actions appear only when backend summary marks the mechanic ready.

Support:

- Embedded app chat remains primary.
- Polling lifecycle is acceptable for beta.
- No fake typing, read receipts, or operator presence.
- Diagnostic attachment must be explicit and redacted.

WARP Sheet:

- Public-facing copy should prefer product wording such as `Расширенная защита`
  or `Расширенная приватность`; literal `WARP` is acceptable in technical,
  advanced, or support contexts when clarity requires it.
- Until runtime proof exists, the sheet states that the feature is preparing or
  proof-gated.
- When ready, the sheet must show explicit consent, a one-line speed/service
  compatibility tradeoff, and a revoke/forget action.
- Never claim anonymity, no restrictions, faster internet, ad-free behavior, or
  stronger privacy without evidence and copy review.

## WARP Working-Feature Contract

Backend/platform work required:

- Add app-facing WARP endpoints:
  - `GET /api/client/warp/status` or readiness;
  - `POST /api/client/warp/consent`;
  - `POST /api/client/warp/revoke`;
  - `POST /api/client/warp/rotate`;
  - `POST /api/client/warp/events`.
- Add a WARP ledger/model for consent, material assignment, rotation, revoke,
  and event history.
- Encrypt WARP account and WireGuard material at rest.
- Keep public policy sanitized; managed material may be returned only through
  authenticated app-first managed flows and only when runtime-ready.
- Add rate limits and abuse protection for provisioning/rotation.
- Add monitoring for WARP provisioning failures, rotation failures, runtime
  errors, and active consent counts.

Client/runtime work required:

- Persist user consent safely instead of keeping it only in memory.
- Add revoke flow that clears local consent, wipes local WARP material, asks
  backend to revoke, and reconnects baseline without WARP.
- Keep WARP material out of plain user-visible diagnostics, support payloads,
  logs, screenshots, and public cache files.
- Prove the runtime material path is safe before returning real WireGuard
  private keys or access tokens to the app.
- Extend runtime state with WARP readiness, active/degraded/failure, and last
  safe error category.
- Add fallback: if WARP start or handshake fails, retry baseline without WARP
  and tell the user the enhanced path was paused.
- Verify Android host bridge receives and applies WARP-capable runtime options.
- Verify Windows `libcore.dll` accepts the WARP options and can connect,
  disconnect, fail, and recover.

Manual proof required before WARP is called working:

- Android physical release-build WARP connect/disconnect/fallback proof.
- Windows release-build WARP connect/disconnect/fallback proof.
- DNS and routing compatibility with the default route modes.
- Speed/latency tradeoff evidence sufficient for honest support wording.
- Redacted proof notes in the relevant release/audit docs.

## Implementation Order

1. P5 motion foundation in the app repo.
2. P5 screen polish and copy-density pass in the app repo.
3. WARP backend status/consent/revoke/events contract in the platform repo.
4. WARP provisioning, encrypted storage, and rotation in the platform repo.
5. WARP consent persistence, revoke UI, local secure material handling, and
   runtime state machine in the app repo.
6. WARP fallback diagnostics and support-chat redaction in both repos.
7. Android and Windows proof, docs, and release-gate updates.

Each step should update its matching docs and tests before moving to the next
step.

## Test Expectations

App tests:

- connect-disc phases and reduced-motion fallback;
- status transitions without stale text;
- skeleton geometry at target widths;
- WARP tile/sheet states: not ready, ready-to-consent, consented, revoked,
  failure/fallback;
- Android MethodChannel bridge for WARP material/options;
- Windows runtime options mapping and fallback;
- support diagnostic payload redaction.

Platform tests:

- WARP status/readiness endpoint;
- consent/revoke lifecycle;
- rotation and stale material rejection;
- event ingestion and redaction;
- managed profile returns WARP material only under authenticated runtime-ready
  conditions;
- public policy never includes secrets.

Manual tests:

- Android physical release build;
- Windows release build;
- real WARP provisioning when credentials/access are available;
- support operator visibility without leaking keys or raw configs.

## Explicit Non-Goals

- Do not fork/rewrite the whole shell during P5.
- Do not expose raw JSON, raw rules, protocol internals, hostnames, keys, or
  subscription URLs in normal UI.
- Do not make Xray a normal-user primary path.
- Do not introduce store/stable/trusted/RU-origin readiness claims.
- Do not make WARP a Home toggle until the runtime and backend proof is green.
- Do not use generated app-map text as product copy.

## Next Step

After this approved design contract is reviewed, create an implementation plan
that starts with P5 motion tests and proceeds through WARP backend/client work
in the order above.
