# POKROV App Docs

This folder holds the living client-repo documentation for `POKROV-app/main`.

Historical mapping note:

- older notes may still reference `external/pokrov-next-client/`
- the first local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/` on `2026-04-22`
- `app-next/docs/` in the platform repo now remains transition/reference material instead of the canonical client-doc lane

The lane now includes thin host shells for `Android`, `iOS`, `macOS`, and `Windows` while remaining non-destructive and clean-room.
The shared shell also models the app-first UX basics for route mode, redeem, checkout handoff, support, and location matrices.
The docs here should make five things explicit:

- the four-host Wave 7 runtime lane is real and locally runnable
- this repo is now the canonical client development lane for that work
- the lane now has a pinned `libcore` artifact contract plus host-sync tooling, but it still lacks reviewed production provenance and public release automation
- the Windows lane now has a local unsigned build-and-package path that verifies the real runtime bundle
- Apple metadata present in the host shells is inventory only, not store readiness
- regenerated `config/local/*` and host `build/` outputs are local-only artifacts, not release truth

Current anchors:

- `specs/2026-04-18-wave-7-new-base-client-scaffold.md`
- `decisions/2026-04-18-karing-vs-clean-room-gate.md`
- `architecture/folder-structure.md`
- `architecture/package-boundaries.md`
- `architecture/bootstrap-workflow.md`
- `operations/apple-release-readiness.md`
- `operations/windows-release-readiness.md`
- `operations/cutover-readiness.md`

Nothing here changes the current bridge client or bridge-period release truth. These docs are now the live documentation lane for the bootstrapped `POKROV-app` repo, while `app-next/docs/` remains historical bootstrap context inside the platform workspace.
