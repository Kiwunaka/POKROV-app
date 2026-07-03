# POKROV App Docs

Last updated: 2026-07-03

This folder holds the living client-repo documentation for `POKROV-app/main`.

Current direction note:

- the current app-shell source of truth is the 2026-06-13 owner product/UI
  direction: POKROV is presented plainly as a VPN app; first launch starts with
  new/returning access; Home sells `POKROV VPN`, WARP, 5-day access, and the
  Telegram bonus; admin/news promo slots render only when backend-owned JSON
  marks them visible
- the front-end rebuild is now a Premium Shell V2 reset after owner feedback rejected the first card-heavy MVP shell
- `marketing` owns public acquisition, `webapp` owns browser continuation, and the client shell stays locked to `Protection / Locations / Rules / Profile`
- public-facing wording should stay calm and non-technical even when the underlying runtime remains transport-rich
- `hiddify-core` is the pinned runtime base; WARP now uses the client-local
  core path by default, while backend lifecycle endpoints store consent/events
  and optional managed material. Production WARP claims still require
  Android/Windows release-build proof
- smart-connect now uses the platform capacity-aware contract:
  candidates -> best-effort RTT -> `/api/client/nodes/select` -> managed
  profile refresh with `selected_node_code`; manual location choice uses
  `mode=manual` and no fake RTT value

Historical mapping note:

- older notes may still reference `external/pokrov-next-client/` or `app-next/`
- the first local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/` on `2026-04-22`
- `app-next/docs/` in the platform repo now remains transition/reference material instead of the canonical client-doc lane
- completed client execution plans live under `docs/archive/`; use them as
  evidence/history, not as active task queues

The lane now includes thin host shells for `Android`, `iOS`, `macOS`, and `Windows` while remaining non-destructive and clean-room.
The shared shell also models the app-first UX basics for the consumer-first tab set `Protection / Locations / Rules / Profile`, plus route mode, redeem, checkout handoff, support, and location matrices.
The docs here should make these things explicit:

- the four-host Wave 7 runtime lane is real and locally runnable
- this repo is now the canonical client development lane for that work
- the lane now has a pinned `libcore` artifact contract plus host-sync tooling, but it still lacks reviewed production provenance and public release automation
- the Windows lane now has a local unsigned build-and-package path that verifies the real runtime bundle
- Apple metadata present in the host shells is inventory only, not store readiness
- regenerated `config/local/*` and host `build/` outputs are local-only artifacts, not release truth
- `config/release-handoff.seed.json` is the stable root-repo handoff source for canonical lane identity and latest repo-backed release metadata

Current client-doc scope:

- living client contract and release-readiness docs for `POKROV-app/main`
- public `v1` scope: `Android + Windows`
- current paid beta evidence line: `1.0.0-beta`
- Android status: `1.0.0-beta outside-store APK uploaded / live owner smoke pending`
- Windows status: `1.0.0-beta unsigned beta uploaded / SmartScreen warning and live owner smoke pending`
- `iOS` and `macOS`: readiness, packaging, and signing-preparation only in this wave
- cross-surface product facts still inherit from the platform canon under `C:/Users/kiwun/Documents/ai/VPN/docs/`
- browser continuation outside the app inherits the platform surface split: checkout-first marketing, continuation-first cabinet, and status-gated public email when the platform runtime reports delivery-ready mode

Current active anchors:

- `design/2026-06-13-pokrov-product-ui-direction.md`
- `operations/2026-06-13-pokrov-product-ui-plan-closure-audit.md`
- `product/client-product-contract.md`
- `architecture/app-first-onboarding-flow.md`
- `decisions/2026-06-03-client-ux-account-rewards-master-brief.md`
- `architecture/folder-structure.md`
- `architecture/package-boundaries.md`
- `architecture/bootstrap-workflow.md`
- `architecture/in-app-ai-assistant-contract.md`
- `implementation/client-release-backlog.md`
- `operations/android-release-audit.md`
- `operations/windows-release-readiness.md`
- `operations/2026-06-05-phase-6-release-beta-handoff.md`
- `operations/2026-06-05-final-beta-closure-except-manual-tests-signing.md`
- `operations/warp-runtime-proof-checklist.md`
- `operations/responsive-golden-capture-plan.md`
- `operations/cutover-readiness.md`
- `operations/client-motion-performance-checklist.md`
- `product/client-public-beta-prd.md`
- `design/DESIGN.md`
- `design/2026-06-03-client-screen-component-rules.md`
- root `DESIGN.md`
- root `docs/operations/client-delivery-update-content-plan.md`
- `developer/work-orders/2026-04-open-beta-v4/INDEX.md`

Completed / reference docs:

- `specs/2026-04-18-wave-7-new-base-client-scaffold.md`
- `decisions/2026-06-03-hiddify-karing-happ-client-base-review.md`
- `decisions/2026-06-03-hiddify-core-warp-status.md`
- `decisions/2026-06-03-client-chat-responsive-warp-motion-review.md`
- `decisions/2026-06-03-client-best-mvp-consilium.md`
- `implementation/2026-06-04-decisions-implementation-map.md`
- `implementation/2026-06-03-client-build-readiness-and-api-plan.md`
- `implementation/2026-06-03-client-mvp-shell-implementation.md`
- `operations/apple-release-readiness.md`
- `design/2026-06-03-client-premium-shell-v2-brief.md`
- `design/2026-06-03-client-quiet-emerald-style-brief.md`
- `design/2026-06-03-client-chat-responsive-warp-motion-brief.md`
- `design/2026-06-03-client-best-mvp-build-brief.md`
- `design/2026-06-05-p5-warp-application-map.md`
- `design/2026-06-05-p5-application-map-consilium-review.md`
- `specs/2026-06-05-p5-warp-approved-design.md`
- `archive/superpowers-plans/2026-06-05-premium-client-ai-assistant-architecture.md`

Deprecated / legacy inputs:

- `decisions/2026-06-02-karing-base-reopen.md`
- `decisions/2026-04-18-karing-vs-clean-room-gate.md`

These legacy inputs are not release blockers and should not be used as the
starting point for current `1.0.0-beta` work unless the owner explicitly
reopens them.

These docs are now the live client-documentation lane for the bootstrapped `POKROV-app` repo.
The product contract, app-first onboarding contract, consumer-first shell IA, route-mode/support/download behavior, and current Android+Windows blockers should live here instead of only in retained bridge docs.
`app-next/docs/` remains historical bootstrap context inside the platform workspace.
