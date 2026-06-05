# P5 WARP Approved Design

Date: 2026-06-05
Status: owner-approved design contract / implementation in progress
Owner: POKROV-app/main

## Approval

The owner approved the P5/WARP direction after the OpenCode-go consilium pass
and requested the direction be recorded before implementation.

This contract supersedes loose chat memory for the next P5 and WARP wave. As
of 2026-06-05, backend WARP lifecycle endpoints, encrypted-at-rest scoped
provisioning, and client consent/event wiring are implemented; release-build
Android/Windows WARP proof remains an open gate.

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
- Application map consilium review:
  [../design/2026-06-05-p5-application-map-consilium-review.md](../design/2026-06-05-p5-application-map-consilium-review.md)

OpenCode-go consilium lanes used for the review:

- `opencode-go/minimax-m3`
- `opencode-go/qwen3.7-max`
- `opencode-go/mimo-v2.5-pro`
- `opencode-go/glm-5.1`
- `opencode-go/deepseek-v4-pro`
- `opencode-go/kimi-k2.6`

The application-map review also checked PNG support. `minimax-m3` and
`kimi-k2.6` reliably reviewed the attached PNG; `qwen3.7-max` was not reliable
for PNG in this run, and `mimo-v2.5-pro`, `glm-5.1`, and `deepseek-v4-pro`
reviewed the detailed Product Design / Image-to-Code visual packet.

## Product Verdict

P5 is a premium-feel wave, not another information-architecture rewrite. The
app should feel like a quiet daily utility: fast, tactile, predictable, and
platform-native.

WARP is partially implemented as a backend-backed lifecycle feature. The
current code has policy parsing, desktop runtime option mapping,
`/api/client/warp/*` status/consent/revoke/rotate/events endpoints, a sanitized
`WarpEvent` ledger, encrypted-at-rest per-user/per-install WARP material
storage with admin provisioning, and client consent/runtime-event wiring. A
production-grade WARP feature still requires provider-side provisioning
automation/rate limits, deeper health diagnostics, Android proof, and Windows
proof.

The generated application map is approved as the P5 visual direction, not as
copy, data, or a pixel-perfect implementation source. Generated labels such as
`POKROV VPN Client`, `Beta draft`, `Secure by design`, and all simulated values
are internal reference artifacts only.

## Application Map Extraction

Keep from the map:

- central tactile connect disc as the Home focus;
- neutral light surfaces with emerald used only for active/selected states;
- row-based Account, Rules, Locations, Rewards, and Support;
- bottom sheets for gated features;
- Windows sidebar plus centered main stage;
- finite ring sweep, press scale, status crossfade, geometry-matched
  skeletons, row feedback, and calm muted states.

Refine before implementation:

- public `WARP` labels become `Расширенная защита` or
  `Расширенная приватность`; literal `WARP` remains advanced/support/internal;
- generated `POKROV VPN Client`, `Beta draft`, and `Secure by design` text is
  not product copy;
- rewards wheel/calendar/balance render muted or hidden until backend flags and
  ledgers are live;
- location ping, signal bars, server load, device counts, renewal dates, timers,
  and reward balances must be live data or skeleton/empty state;
- Windows right-panel metrics default to consumer-readable state and move
  protocol/load/uptime/raw metrics behind details or Advanced;
- support chat must not imply fake operator presence, typing, read receipts, or
  SLA;
- internal labels such as `NL-free` need clearer user-facing wording or a
  first-run hint;
- app-picker icons must come from OS/source-owned/generic sources, not copied
  third-party brand assets from a generated mock.

Reject from the map:

- showing WARP as a normal active Home/sidebar feature before proof;
- active-looking rewards when the feature is off;
- fake ping/load/country/device/support values;
- any implication of stable `1.0.0`, store release, trusted signing,
  RU-origin readiness, anonymity, faster internet, ad-free behavior, or
  unrestricted access.

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

Data honesty rules:

- generated sample values from the application map are never implementation
  fixtures;
- pings, country signal bars, server load, uptime, renewal dates, device limits,
  timers, reward balances, and support presence must come from live/safe state
  or render as skeletons, empty states, or muted unavailable states;
- if a metric is useful only for support or advanced diagnosis, hide it behind
  details or Advanced by default.

## Component Architecture

Connect disc:

- Mobile target diameter: around `160dp`; Windows target diameter:
  `240-280dp`.
- Idle: white inner disc, muted/soft emerald ring, simple lightning/brand
  action icon, short action label.
- Connecting: finite ring sweep for the current attempt. No endless progress
  glow.
- Connected: solid emerald ring, check mark, and live timer only when runtime
  state is actually connected.
- Reconnecting and error are required states before P5 is complete.
- Press state uses transform scale around `0.95-0.98` over `100-150ms`.
- Connected settle may pulse once; steady connected state should be calm.

Rows:

- Standard row height: `56dp`.
- Two-line row height: `72dp`.
- Leading icon: `24dp`.
- Title: `16` regular/semibold depending on hierarchy.
- Subtitle/caption: `13` muted.
- Press state uses subtle surface tint; no layout movement.
- Dividers are hairline and may be indented after the leading icon.

Chips:

- Height: `32dp`.
- Radius: `16dp`.
- Horizontal padding: around `12dp`.
- Home should show no more than two chips. Overflow belongs in a sheet/detail.
- Labels must be user-readable.

Bottom sheets:

- Top radius: `20-24dp`.
- Drag handle: around `36-40dp x 4dp`.
- Default detent: around `60%`; expanded detent: around `85-92%`.
- Scrim: around `32-40%`.
- Tablet/desktop sheets use a max width instead of full-viewport stretch.

Windows sidebar:

- Expanded width target: `240-260dp`.
- Collapsed icon rail: around `64dp`.
- Active row uses emerald indicator or soft pill, not glow.
- Focus and keyboard navigation are part of the component, not later polish.
- Normal users should see consumer-readable status first; advanced metrics use
  progressive disclosure.

Skeletons:

- Skeletons match the geometry of the eventual content: same row height, icon
  circle, text-line count, margins, and radii.
- Shimmer may run around `1.5s`, but must not shift layout or repaint large
  scrolling surfaces excessively.

Muted/gated states:

- Use muted color, desaturated icon, short reason, and no active primary CTA.
- A future feature must look unavailable by design, not broken.

## Screen Contract

Home:

- One connect/disconnect focus.
- Current status, location chip, route-mode chip, and a calm extended
  protection/preparing chip or row only when it does not compete with the
  primary action.
- No long paragraphs, no repeated CTA, no Telegram/cabinet/reward clutter on
  the first screen.

Rules:

- Row-based routing mode and selected-app controls.
- Android installed-app picker and Windows process/exe picker remain the normal
  custom-app path.
- App icons must be OS-provided, source-owned, or generic safe icons.
- Raw rule editing remains debug/advanced only behind a responsibility gate.

Locations:

- Auto location remains the default.
- Country rows stay compact with ping/load signal only when supported by real
  data.
- Search, loading, empty, offline, and long-list states are part of the screen
  contract.
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
- The generated wheel/calendar image is a live-state target, not the beta
  default.

Support:

- Embedded app chat remains primary.
- Polling lifecycle is acceptable for beta.
- No fake typing, read receipts, SLA, or operator presence.
- Diagnostic attachment must be explicit and redacted.
- Queued/registered-ticket wording is allowed; fake online chat chrome is not.

Extended Protection Sheet:

- Public-facing copy should prefer product wording such as `Расширенная защита`
  or `Расширенная приватность`; literal `WARP` is acceptable in technical,
  advanced, or support contexts when clarity requires it.
- Until runtime proof exists, the sheet states that the feature is preparing or
  proof-gated.
- When ready, the sheet must show explicit consent, a one-line speed/service
  compatibility tradeoff, and a revoke/forget action.
- Never claim anonymity, no restrictions, faster internet, ad-free behavior, or
  stronger privacy without evidence and copy review.

Windows:

- Desktop keeps a sidebar and centered connect stage instead of stretching the
  mobile navigation pattern.
- The right panel starts with consumer-readable status and hides protocol/load,
  uptime, raw runtime fields, and support-grade metrics behind details or
  Advanced.
- Sidebar collapse uses width plus label opacity transitions with stable icon
  alignment and keyboard focus states.

## Dedicated Visual References Required

The application map is too compressed to code from directly. P5 implementation
should use screen-specific references before changing production UI:

- Home idle, connecting, connected, reconnecting, and error.
- Connect-disc component states at `1:1` scale.
- Extended protection gate sheet and ready-to-consent sheet using product
  wording.
- Rules app picker with search, long list, empty state, and selected-app tab.
- Locations search, skeleton/loading, offline/error, and long-list states.
- Account subscription/details/session-limit states.
- Rewards muted/locked state and live-flag state.
- Support empty state, sent message, attachment picker, and send error.
- Windows shell at `1280x720`, `1440x900`, and `1920x1080`, with sidebar and
  right panel collapsed/expanded.
- Motion timing sheet with easing, frame states, and reduced-motion behavior.
- Dark mode only if it enters the release scope explicitly.

## WARP Working-Feature Contract

Backend/platform work required:

- App-facing WARP lifecycle endpoints are implemented:
  - `GET /api/client/warp/status` or readiness;
  - `POST /api/client/warp/consent`;
  - `POST /api/client/warp/revoke`;
  - `POST /api/client/warp/rotate`;
  - `POST /api/client/warp/events`.
- `WarpEvent` ledger/model is implemented for consent, revoke, rotation
  request, and runtime fallback/error events with request and ledger metadata
  redaction.
- Encrypted-at-rest WARP account and WireGuard material storage is implemented
  through scoped `warp_materials` rows and `PUT /api/admin/client/warp/material`.
- Keep public policy sanitized; managed material may be returned only through
  authenticated app-first managed flows and only when runtime-ready.
- Add rate limits and abuse protection for provisioning/rotation.
- Add monitoring for WARP provisioning failures, rotation failures, runtime
  errors, and active consent counts.

Client/runtime work required:

- Persist user consent safely instead of keeping it only in memory. First
  implementation uses backend `WarpEvent` lifecycle status plus app-side cache.
- Revoke now asks backend to revoke and immediately clears the local enabled
  WARP state; physical staged-file wipe and reconnect-baseline proof remain
  open.
- Keep WARP material out of plain user-visible diagnostics, support payloads,
  logs, screenshots, and public cache files.
- The client now calls backend consent/revoke, reads backend WARP status when
  resolving managed profile, and reports runtime fallback/error events through
  `POST /api/client/warp/events` with client-side metadata sanitization.
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
   Implemented on 2026-06-05.
4. WARP provisioning, encrypted storage, and rotation in the platform repo.
   Scoped encrypted material storage and admin provisioning were implemented
   on 2026-06-05; provider-side rotation automation, stale material rejection,
   rate limits, and monitoring remain open.
5. WARP consent persistence, revoke UI, local secure material handling, and
   runtime state machine in the app repo.
   Backend-backed consent, runtime event reporting, and local enabled-state
   clearing on revoke started on 2026-06-05; physical staged material wipe and
   reconnect-on-revoke remain open.
6. WARP fallback diagnostics and support-chat redaction in both repos.
   Runtime fallback ledger reporting started on 2026-06-05; support-chat
   redaction proof remains open.
7. Android and Windows proof, docs, and release-gate updates.

Each step should update its matching docs and tests before moving to the next
step.

## Test Expectations

App tests:

- connect-disc phases and reduced-motion fallback;
- status transitions without stale text;
- skeleton geometry at target widths;
- visual golden frames for Home state matrix, extended protection sheets,
  Rules picker, Locations states, Account rows, Rewards gated/live states,
  Support states, and Windows shell states;
- copy guard that prevents public first-layer `WARP` wording from replacing
  `Расширенная защита` / `Расширенная приватность`;
- no-fake-data guard for ping, load, uptime, timers, rewards, support presence,
  and generated sample values;
- Windows sidebar collapse and right-panel progressive disclosure;
- rewards muted/live feature-flag behavior;
- support no fake typing, read receipts, SLA, or online-operator state;
- WARP tile/sheet states: not ready, ready-to-consent, consented, revoked,
  failure/fallback;
- Android MethodChannel bridge for WARP material/options;
- Windows runtime options mapping and fallback;
- support diagnostic payload redaction.

Platform tests:

- WARP status/readiness endpoint;
- consent/revoke lifecycle;
- scoped admin WARP material provisioning with encrypted-at-rest storage;
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
- Do not copy third-party app icons from generated mocks.
- Do not ship fake pings, fake load, fake dates, fake timers, fake reward
  balances, or fake support presence.
- Do not use generated app-map text as product copy.

## Next Step

After this approved design contract is reviewed, create an implementation plan
that starts with P5 motion tests and proceeds through WARP backend/client work
in the order above.
