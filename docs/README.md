# POKROV App Documentation Router

Use this index to load only the context required for the current client task. `POKROV-app/main` owns client implementation and client release-readiness. The platform repository owns backend behavior, shared public facts, public delivery contracts, and cross-surface policy.

## Authority Boundaries

- Resolve intended product behavior through owner-approved machine-readable contracts, canonical docs, then current code and tests. Record conflicts instead of silently choosing a winner.
- Resolve observed runtime state through current provider/runtime state and candidate-specific evidence. Runtime observation does not create product authority.
- Resolve release claims through an exact candidate, current gate evidence, required manual checks, and a current release decision. A dated handoff is evidence, not a reusable pass.
- Use history to answer why. Never let archive, completed plans, generated references, or old decisions determine what to implement now.
- Platform owners include `C:/Users/kiwun/Documents/ai/VPN/shared/`, `C:/Users/kiwun/Documents/ai/VPN/docs/product/portal-vpn-product.md`, `C:/Users/kiwun/Documents/ai/VPN/docs/architecture/app-first-and-bonus-flows.md`, `C:/Users/kiwun/Documents/ai/VPN/docs/architecture/client-downloads-flow.md`, and `C:/Users/kiwun/Documents/ai/VPN/docs/operations/publishing-and-signing-guide.md`.

## Task Routes

| Task | Read first | Inspect | Verify | Docs impact |
| --- | --- | --- | --- | --- |
| Shell, UI, or copy | `product/client-product-contract.md`; `design/2026-06-13-pokrov-product-ui-direction.md`; root `DESIGN.md` | `packages/app_shell/`; affected `apps/*_shell/`; assets and copy tests | Focused Flutter widget/copy/design tests; `scripts/validate-seed.ps1`; `git diff --check` | Product contract, current design direction, and affected host docs |
| App-first, account, or API | `architecture/app-first-onboarding-flow.md`; platform app-first contract | `packages/app_shell/`; API/session/support clients; secure storage | Focused bootstrap, assistant, auth, logout, migration, and corrupt-state tests | Client onboarding/assistant docs and the platform API owner when the contract changes |
| Runtime, core, or WARP | `architecture/bootstrap-workflow.md`; `operations/warp-runtime-proof-checklist.md`; `config/runtime-profile.seed.json` | `packages/runtime_engine/`; host bridges; runtime artifact contract | Focused runtime/WARP tests and only the affected host checks; no docs-only release build | Bootstrap/runtime architecture and WARP proof checklist |
| Android | `operations/android-release-audit.md`; `config/platform-matrix.seed.json` | `apps/android_shell/`; Android bridge, service, manifest, Gradle tests | Focused Android Flutter/JVM tests through `scripts/run-tests.ps1`; manual device gates stay explicit | Android audit plus shared runtime/onboarding docs when behavior changes |
| Windows | `operations/windows-release-readiness.md`; `config/windows-release.seed.json` | `apps/windows_shell/`; Windows FFI and packaging scripts | Focused Flutter/runtime tests; package smoke only for an authorized packaging task | Windows readiness, runtime docs, and release metadata owner |
| Apple readiness | `operations/apple-release-readiness.md`; `config/apple-release.seed.json` | `apps/ios_shell/`; `apps/macos_shell/`; entitlements and runtime bridges | Analyze/tests that do not require credentials; keep signing, archive, notarization, device, and store checks manual | Apple readiness only; never broaden public scope from inventory |
| Release metadata | `config/release-handoff.seed.json`; `operations/cutover-readiness.md`; platform publishing owner | Release/cutover seeds, packaging scripts, exact candidate evidence | `scripts/validate-seed.ps1`; artifact diff; current manual gates; no historical pass reuse | Current readiness/backlog and platform delivery/publishing owners |
| Design | Root `DESIGN.md`; `design/2026-06-13-pokrov-product-ui-direction.md` | `packages/app_shell/`; brand assets; generated references only when requested | Focused design-system and copy tests; responsive proof when layout changes | Current root design contract and direction; keep older briefs historical |
| Docs or history | This file; the registry row for the subject | Canonical owner first, then evidence/history for rationale | `test/docs-contract.ps1`; `scripts/validate-seed.ps1`; `git diff --check` | Update classification/review state without rewriting retained evidence |

## Classes And Review State

- `CANONICAL`: current product, architecture, design, operations, or machine-readable contract.
- `ACTIVE_EXECUTION`: current backlog, readiness checklist, or unresolved execution state; never product authority.
- `EVIDENCE`: audit, handoff, work-order, or completed implementation record tied to its recorded scope.
- `HISTORICAL_REFERENCE`: superseded decision, old brief, generated reference, archive, or rollback provenance.
- `OPERATOR_PLAYBOOK`: optional client-local operator workflow outside normal coding context.
- `EXPERIMENTAL`: opt-in research or helper that does not define normal behavior.

Review values are `RECONCILED`, `REVIEWED_NO_CHANGE`, `PENDING_COLLISION_REVIEW`, and `UNRESOLVED_OWNER_DECISION`.

## Document Registry

| Class | Review | Owner | Path |
| --- | --- | --- | --- |
| CANONICAL | RECONCILED | Client docs routing | `docs/README.md` |
| CANONICAL | RECONCILED | Client repository overview | `README.md` |
| CANONICAL | RECONCILED | Client design system | `DESIGN.md` |
| CANONICAL | RECONCILED | Client product | `docs/product/client-product-contract.md` |
| CANONICAL | RECONCILED | App-first onboarding | `docs/architecture/app-first-onboarding-flow.md` |
| CANONICAL | REVIEWED_NO_CHANGE | Repository structure | `docs/architecture/folder-structure.md` |
| CANONICAL | REVIEWED_NO_CHANGE | Package boundaries | `docs/architecture/package-boundaries.md` |
| CANONICAL | RECONCILED | Runtime bootstrap | `docs/architecture/bootstrap-workflow.md` |
| CANONICAL | RECONCILED | In-app assistant | `docs/architecture/in-app-ai-assistant-contract.md` |
| CANONICAL | RECONCILED | Current product/UI direction | `docs/design/2026-06-13-pokrov-product-ui-direction.md` |
| EVIDENCE | RECONCILED | Completed motion/HIG implementation record | `docs/design/2026-07-13-agent-uiux-backlog.md` |
| CANONICAL | RECONCILED | Machine product facts | `config/product-contract.seed.json` |
| CANONICAL | RECONCILED | Public/readiness platform scope | `config/platform-matrix.seed.json` |
| CANONICAL | REVIEWED_NO_CHANGE | Runtime profile facts | `config/runtime-profile.seed.json` |
| CANONICAL | RECONCILED | Cutover readiness facts | `config/cutover-readiness.seed.json` |
| CANONICAL | REVIEWED_NO_CHANGE | Release handoff facts | `config/release-handoff.seed.json` |
| ACTIVE_EXECUTION | RECONCILED | Client release execution | `docs/implementation/client-release-backlog.md` |
| ACTIVE_EXECUTION | REVIEWED_NO_CHANGE | Cutover checklist | `docs/operations/cutover-readiness.md` |
| ACTIVE_EXECUTION | RECONCILED | Android readiness | `docs/operations/android-release-audit.md` |
| ACTIVE_EXECUTION | RECONCILED | Windows readiness | `docs/operations/windows-release-readiness.md` |
| ACTIVE_EXECUTION | RECONCILED | WARP runtime proof | `docs/operations/warp-runtime-proof-checklist.md` |
| ACTIVE_EXECUTION | REVIEWED_NO_CHANGE | Responsive proof | `docs/operations/responsive-golden-capture-plan.md` |
| ACTIVE_EXECUTION | REVIEWED_NO_CHANGE | Motion/performance proof | `docs/operations/client-motion-performance-checklist.md` |
| ACTIVE_EXECUTION | REVIEWED_NO_CHANGE | Apple readiness | `docs/operations/apple-release-readiness.md` |
| EVIDENCE | REVIEWED_NO_CHANGE | Public beta product evidence | `docs/product/client-public-beta-prd.md` |
| EVIDENCE | REVIEWED_NO_CHANGE | Dated handoffs and closure audits | `docs/operations/2026-06-04-public-beta-operator-handoff.md`; `docs/operations/2026-06-05-phase-6-release-beta-handoff.md`; `docs/operations/2026-06-05-final-beta-closure-except-manual-tests-signing.md`; `docs/operations/2026-06-13-pokrov-product-ui-plan-closure-audit.md` |
| EVIDENCE | REVIEWED_NO_CHANGE | Client/API additions record | `docs/operations/client-ui-api-additions.md` |
| EVIDENCE | REVIEWED_NO_CHANGE | Retained beta work order | `docs/developer/work-orders/2026-04-open-beta-v4/INDEX.md` |
| EVIDENCE | REVIEWED_NO_CHANGE | Completed implementation maps | `docs/implementation/2026-06-03-client-build-readiness-and-api-plan.md`; `docs/implementation/2026-06-03-client-mvp-shell-implementation.md`; `docs/implementation/2026-06-04-decisions-implementation-map.md`; `docs/implementation/2026-06-05-p6-overload-correction-plan.md` |
| HISTORICAL_REFERENCE | RECONCILED | Superseded local design entry | `docs/design/DESIGN.md` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Earlier scaffold spec | `docs/specs/2026-04-18-wave-7-new-base-client-scaffold.md` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Completed WARP design spec | `docs/specs/2026-06-05-p5-warp-approved-design.md` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Retired base/runtime reviews | `docs/decisions/2026-06-03-hiddify-karing-happ-client-base-review.md`; `docs/decisions/2026-06-03-hiddify-core-warp-status.md` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Earlier UX master brief | `docs/decisions/2026-06-03-client-ux-account-rewards-master-brief.md` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Earlier responsive review | `docs/decisions/2026-06-03-client-chat-responsive-warp-motion-review.md` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Earlier MVP consilium | `docs/decisions/2026-06-03-client-best-mvp-consilium.md` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Retired Karing reopen input | `docs/decisions/2026-06-02-karing-base-reopen.md` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Retired clean-room gate input | `docs/decisions/2026-04-18-karing-vs-clean-room-gate.md` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Earlier premium-shell brief | `docs/design/2026-06-03-client-premium-shell-v2-brief.md` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Earlier visual/copy briefs | `docs/design/2026-06-03-client-screen-component-rules.md`; `docs/design/2026-06-03-client-quiet-emerald-style-brief.md`; `docs/design/2026-06-03-client-chat-responsive-warp-motion-brief.md`; `docs/design/2026-06-03-client-best-mvp-build-brief.md` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Completed application-map briefs | `docs/design/2026-06-05-p5-warp-application-map.md`; `docs/design/2026-06-05-p5-application-map-consilium-review.md`; `docs/design/2026-06-05-p6-overload-ux-consilium.md` |
| HISTORICAL_REFERENCE | UNRESOLVED_OWNER_DECISION | Generated visual references | `docs/design/assets/`; `docs/design/generated/2026-06-09-app-screen-variants/` |
| HISTORICAL_REFERENCE | REVIEWED_NO_CHANGE | Archived completed plans | `docs/archive/` |
| OPERATOR_PLAYBOOK | REVIEWED_NO_CHANGE | no client-local owner; platform tools do not enter the client default route | — |
| EXPERIMENTAL | REVIEWED_NO_CHANGE | no client-local owner; platform tools do not enter the client default route | — |

## Change Rule

When behavior changes, update the owning `CANONICAL` document in the same task. Update `ACTIVE_EXECUTION` only for execution state, attach new `EVIDENCE` to its exact candidate or scope, and leave `HISTORICAL_REFERENCE` content intact unless its classification or provenance is wrong.
