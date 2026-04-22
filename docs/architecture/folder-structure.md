# Folder Structure

This scaffold separates future work by purpose instead of by current implementation details.

## Top-Level Layout

| Path | Purpose |
| --- | --- |
| `apps/` | Platform entry shells and thin host-specific glue |
| `packages/` | Shared domain, shell, support, and platform contracts |
| `config/` | Seed contracts, runtime profiles, and local config templates |
| `docs/` | Decisions, specs, operations checklists, and future implementation notes |
| `assets/` | References to canonical brand inputs, not copied release assets |
| `scripts/` | Local non-destructive helpers for this lane |
| `test/` | Future focused tests for the new-base client lane |

## Boundary Rules

- `apps/` should stay thin and platform-owned.
- `packages/` should hold reusable logic and stable contracts.
- `docs/` should explain why a structure exists before major code lands.
- `docs/operations/` should carry release-readiness and cutover checklists without implying credentials are committed.
- `config/` should prefer seed snapshots and examples over copied secrets or release material.
- `config/local/` should remain generated and git-ignored apart from `.gitkeep`.
- `assets/` should reference canonical masters from the platform repo instead of duplicating stale exports.
- `apps/` should depend on `packages/` rather than duplicating domain and support models.

## Current Package Intent

- `app_shell`: first-run shell, tab model, navigation, and session shell ownership
- `core_domain`: access state, route mode, device context, managed-profile metadata, and smart-connect model boundaries
- `platform_contracts`: engine selection, permissions, platform services, and connect lifecycle contracts
- `support_context`: safe diagnostics, escalation metadata, and support handoff payloads

## Seed Executability

This scaffold now includes:

- `melos.yaml` as a workspace anchor for Flutter and Dart package discovery
- starter `pubspec.yaml` files for Android, iOS, macOS, and Windows host shells plus the shared packages
- a local bootstrap flow for `config/local/`
- a second validation lane in `test/seed-layout.ps1`
