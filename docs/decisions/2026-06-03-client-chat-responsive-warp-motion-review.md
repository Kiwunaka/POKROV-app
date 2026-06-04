# Client Chat, Responsive Shell, WARP, And Motion Review

Date: 2026-06-03
Status: accepted direction, not yet implemented

## Context

The owner clarified that the current support hub is not the target support
experience. The desired client support surface is an embedded app chat similar
to the webapp: message composer, chat history, safe diagnostic/log attachment,
AI-first support bot, and later operator escalation.

The same owner review flagged three additional product-quality issues:

- the Windows layout breaks at narrow widths because the sidebar remains fixed
  while inner content collapses
- the Account section is still muddled and too row-heavy
- Home should signal WARP/enhanced privacy as a visible feature, while staying
  honest that runtime support is not wired and verified yet
- motion, responsiveness, and premium feel need another pass after layout is
  structurally sound

## Consilium Input

External OpenCode-go/Kimi reviewers were asked to critique only the compact
packet and not inspect the repository. Local synthesis keeps POKROV canon above
model output.

Consensus:

- support should become a real in-app chat surface, not a Telegram link hub
- the chat may be locally mocked, but operator history and live status must not
  be faked
- diagnostic attachments must be explicit, redacted, and user-approved
- Windows responsive layout and sidebar collapse are the highest-priority visual
  fix
- Account/Profile needs grouped IA, not a single long flat list
- WARP can appear on Home only as an honest disabled/upcoming or beta-not-active
  tile until runtime proof exists
- motion should follow layout and IA, using restrained transform/opacity
  transitions rather than decorative effects

## Decision

Proceed with the next client UI wave in this order:

1. Fix Windows responsive shell:
   - expanded sidebar only on wide desktop
   - icon rail / drawer / hamburger behavior at smaller widths
   - content minimum widths and row stacking to prevent one-letter wrapping
2. Rework Account/Profile IA:
   - split into clear sections such as Plan & Access, Security & Sync,
     App & Device, Support & Feedback
   - keep support chat as a real navigation entry
   - move technical diagnostics away from first-layer account clutter
3. Build embedded support chat shell:
   - full route or stable pane, not a raw Telegram handoff
   - message list, composer, attach diagnostics, AI helper, escalation state
   - local mock is allowed only with explicit non-live status
4. Add safe diagnostics attachment:
   - redacted app version, platform, route mode, status, recent error category
   - never raw config, keys, node topology, panel URLs, or full logs
   - user confirms what is included before sending
5. Add WARP/enhanced privacy Home signal:
   - visible tile/card/chip below primary protection state
   - disabled/upcoming wording until runtime is wired and verified
   - no active toggle and no anonymity/no-restrictions claims
6. Add motion/premium pass:
   - page/tab transitions, sidebar collapse, row/card hover and tap feedback,
     chat composer feedback, skeletons
   - transform/opacity only; respect reduced motion

## Support Chat Contract Direction

Target app-facing API shape:

- `POST /api/support/sessions`
- `GET /api/support/sessions/{id}/messages?cursor=...`
- `POST /api/support/sessions/{id}/messages`
- `POST /api/support/sessions/{id}/attachments`
- `POST /api/support/sessions/{id}/escalate`
- `GET /api/support/sessions/{id}/status`
- optional `GET /api/support/sessions/{id}/messages/stream` for SSE

Until that API exists, the client may implement:

- local chat UI
- local message store
- canned AI helper replies
- offline queue state
- redacted diagnostics preview

It must not implement fake operator replies, fake ticket ids, fake SLA timers,
or pretend cross-device chat history exists.

## WARP Rule

The earlier "do not show WARP on Home" rule is refined:

- do not show a working toggle or active state until runtime proof exists
- a first-layer Home tile is allowed when it is clearly disabled/upcoming and
  describes the feature without claiming it works
- product copy should use `Расширенная приватность`, `Дополнительная защита`, or
  similar user-facing wording, with `WARP` as secondary technical label

## Risks

- implementing chat UI before responsive fixes risks making another visibly
  broken surface
- showing WARP too strongly risks false product claims
- attaching diagnostics without a redaction manifest risks leaking sensitive
  operational data
- motion before layout stability can make the app feel more broken, not more
  premium
