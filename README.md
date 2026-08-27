# POKROV App

Canonical client repository for POKROV on Android and Windows. The same tree
keeps iOS and macOS readiness work without presenting either Apple host as a
public release.

Use [docs/README.md](docs/README.md) to choose a task-specific reading route.
The root [AGENTS.md](AGENTS.md) is the short Codex operating contract.

## Current Product Truth

- Client strategy: `consumer-first` and `app-first`.
- Public outside-store stable surfaces: Android and Windows.
- Retained public line: `1.1.6` (`1.1.6+29`).
- Development target: `1.2.0+34`, state `PRE_CANDIDATE_LOCAL`, replacement
  candidate not created.
- Apple surfaces: readiness, packaging, signing, and device-proof work only.
- Default runtime: `sing-box`; `xray` is an advanced compatibility fallback.
- Default device-wide rule: `All except RU`; `Full tunnel` remains available.
- `Only selected apps` is beta-active on Android and Windows. Picker, policy,
  persistence, and runtime materialization exist; exact-artifact OS proof is
  still a production gate.
- Client UI follows the `pokrov-clear` direction approved on `2026-06-13` and
  the active root [DESIGN.md](DESIGN.md).
- The support-scoped assistant uses the implemented app-session endpoint
  `POST /api/client/support/assistant`; ticket-backed operator escalation
  remains the fallback.

## Release Truth

`config/release-handoff.seed.json` is the machine-readable owner for the latest
repo-backed public handoff and the current development target. It retains the
observed public `Kiwunaka/pokrov`
GitHub Release, candidate hashes, download evidence, and manual gates without
turning old evidence into approval for a later candidate.

`config/release-rollback-catalog.seed.json` owns the stable pointer location and
the exact versioned handoffs eligible for rollback. The pointer helper is
read-only unless `-Apply` is explicit, requires the expected current release,
creates an exact backup outside retained history, and records a receipt. Local
fixture reversal is not an exact-candidate rollback drill or mutation authority.

The retained `1.1.6` publication is evidence for that exact artifact set. The
working `1.2.0+34` line is not a candidate. New public promotion and runtime
sync are blocked until clean exact revisions, the public release-index
revision, exact Core replacement artifacts, strict-v2 metadata, and required
candidate evidence exist. Android production signing is fail-closed by
default; debug signing requires an explicit non-public smoke opt-in. The
handoff does not prove:

- a `1.2.0` candidate or stable publication;
- Play, Microsoft Store, WinGet, TestFlight, App Store, or notarized delivery;
- production Android signing or trusted Windows signing and reputation;
- a fresh physical-device, clean-VM, or real-user pass for a later candidate;
- production WARP behavior on Android or Windows;
- RU-origin readiness.

Generated host outputs under `apps/**/build/`, local materializations under
`config/local/`, and other generated `build/**` trees are disposable local
verification output. They never override the release handoff or candidate
evidence. Retained bundles under `artifacts/releases/**` are evidence and must
not be edited during ordinary development or documentation work. Local
candidate assembly belongs under ignored `artifacts/candidate-staging/**`; the
signed public release index is a separate repository and is never mirrored as
client source truth.

## Authority Boundaries

This repository owns client product behavior, shell and host integration,
runtime materialization, client security, and client release readiness.

The platform repository owns backend behavior, shared public facts, public
delivery contracts, and publishing policy:

- [Platform product](C:/Users/kiwun/Documents/ai/VPN/docs/product/portal-vpn-product.md)
- [App-first and bonus flows](C:/Users/kiwun/Documents/ai/VPN/docs/architecture/app-first-and-bonus-flows.md)
- [Client downloads flow](C:/Users/kiwun/Documents/ai/VPN/docs/architecture/client-downloads-flow.md)
- [Publishing and signing guide](C:/Users/kiwun/Documents/ai/VPN/docs/operations/publishing-and-signing-guide.md)
- [Shared product facts](C:/Users/kiwun/Documents/ai/VPN/shared/product-facts.json)
- [Shared design tokens](C:/Users/kiwun/Documents/ai/VPN/shared/design-tokens.json)

When a client change alters one of those contracts, update the platform owner
in the same coordinated change. Do not copy a second source of truth here.

## Repository Map

- `apps/`: Android, Windows, iOS, and macOS host shells.
- `packages/app_shell/`: shared product shell, app-first API client, support,
  routing, and UI contracts.
- `packages/runtime_engine/`: shared runtime initialization and config
  materialization.
- `packages/core_domain/`: client domain values.
- `packages/platform_contracts/`: host boundary contracts.
- `packages/observability_contracts/`: checked platform event/error identities.
- `packages/observability_runtime/`: privacy-safe local event dispatch and bounded retention.
- `packages/support_context/`: redacted support context.
- `config/`: machine-readable product, runtime, platform, cutover, and release
  contracts.
- `docs/`: canonical docs, active execution state, evidence, and history.
- `scripts/`: local validation, runtime sync, packaging, and release checks.
- `test/`: repository-level contract and layout checks.
- `artifacts/releases/`: frozen historical lineage/evidence, not a candidate
  destination or public release index.
- `artifacts/candidate-staging/`: ignored local candidate assembly.

## Quick Validation

For docs or seed changes:

```powershell
powershell -ExecutionPolicy Bypass -File .\test\docs-contract.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\validate-seed.ps1
git diff --check
git diff --name-only -- artifacts/releases
```

For the current non-release client test lane:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-tests.ps1
```

Run host builds only when the task changes host or packaging behavior. A docs
task must not manufacture release evidence by rebuilding Android or Windows.

## Guardrails

- Keep secrets, session values, raw profiles, keys, topology, and signing
  material out of Git, logs, screenshots, fixtures, and handoffs.
- Keep local control surfaces loopback-only and authenticated where enabled.
- Preserve secure-storage migration, logout, revocation, and corrupt-state
  recovery behavior.
- Keep raw config and operator topology out of normal consumer UI.
- Treat WARP as a user-visible feature label, not permission to expose raw
  WireGuard material or claim production-proof privacy.
- Keep historical bridge/Karing/clean-room material as history. It may explain
  earlier decisions but cannot reopen the active client lane by itself.
- Never clean another worktree or rewrite retained evidence during routine
  development.

## Historical Mapping

Older records may call this lane `app-next`,
`external/pokrov-next-client`, or the clean-room Wave 7 client. Those names are
bootstrap provenance only. `POKROV-app/main` is the active client-development
and client-documentation line; retained bridge bundles are archive evidence.
