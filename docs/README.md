# POKROV App Docs

Last updated: 2026-04-24

This folder holds the living client-repo documentation for `POKROV-app/main`.

Current direction note:

- the front-end rebuild is an atlas-driven shell reset across the app shell and browser handoff surfaces
- `marketing` owns public acquisition, `webapp` owns browser continuation, and the client shell stays locked to `Protection / Locations / Rules / Profile`
- public-facing wording should stay calm and non-technical even when the underlying runtime remains transport-rich
- the active shell uses the white/mint premium utility direction and must not keep a parallel old-redesign path
- first-layer app copy must not expose protocol, runtime, local-control, raw profile, hostname, or port terms
- old subtitles and longer trial promises are stale; current client copy follows `POKROV` and `5 days`

Historical mapping note:

- older notes may still reference `external/pokrov-next-client/` or `app-next/`
- the first local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/` on `2026-04-22`
- `app-next/docs/` in the platform repo now remains transition/reference material instead of the canonical client-doc lane

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
- `iOS` and `macOS`: readiness, packaging, and signing-preparation only in this wave
- cross-surface product facts still inherit from the platform canon under `C:/Users/kiwun/Documents/ai/VPN/docs/`
- browser continuation outside the app inherits the platform surface split: checkout-first marketing, continuation-first cabinet, and public email marked `soon`

Current anchors:

- `product/client-product-contract.md`
- `architecture/app-first-onboarding-flow.md`
- `specs/2026-04-18-wave-7-new-base-client-scaffold.md`
- `decisions/2026-04-18-karing-vs-clean-room-gate.md`
- `architecture/folder-structure.md`
- `architecture/package-boundaries.md`
- `architecture/bootstrap-workflow.md`
- `implementation/client-release-backlog.md`
- `operations/apple-release-readiness.md`
- `operations/windows-release-readiness.md`
- `operations/cutover-readiness.md`

These docs are now the live client-documentation lane for the bootstrapped `POKROV-app` repo.
The product contract, app-first onboarding contract, consumer-first shell IA, route-mode/support/download behavior, and current Android+Windows blockers should live here instead of only in retained bridge docs.
`app-next/docs/` remains historical bootstrap context inside the platform workspace.
