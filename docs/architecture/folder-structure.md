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
- `observability_contracts`: exact platform-owned event/error identities and contract hashes
- `observability_runtime`: typed privacy-safe event dispatch and bounded local retention
- `support_context`: safe diagnostics, escalation metadata, and support handoff payloads

## App Shell Module Layout

`packages/app_shell/lib/app_shell.dart` stays the public library entrypoint for
the shared Flutter shell. It owns imports, exported contracts, app state,
and the library-level part map.

Shared shell modules live beside the feature folders:

| Path | Owns |
| --- | --- |
| `src/seed/` | seed app context, built-in managed profile, public bootstrap constants |
| `src/shell/` | app widget, navigation scaffolds, desktop/mobile shell layout |
| `src/shared/` | reusable sheets, cards, backdrop, status pills, connect-disc wrappers |

Large user-facing surfaces live as Dart `part` files under
`packages/app_shell/lib/src/features/`:

| Path | Owns |
| --- | --- |
| `src/features/onboarding/` | first-launch country/restore/start flow |
| `src/features/home/` | protection home, connect ritual, access strip, WARP entry tile, notices |
| `src/features/locations/` | automatic location surface and smart-connect labels |
| `src/features/rules/` | route-mode choices, Windows/process/app selection, rules copy helpers |
| `src/features/profile/` | access overview, account actions, settings rows, redeem/email sheets |
| `src/features/rewards/` | bonus hub, wheel/calendar/achievements/referral surfaces |
| `src/features/support/` | embedded support chat, lifecycle hints, AI helper suggestions |
| `src/features/warp/` | WARP consent and state sheet |

Keep these files behavior-focused and avoid moving platform/runtime contracts
into the UI feature folders. New large screens should get their own feature
part before `app_shell.dart` grows back into a single 10k-line file.

## Seed Executability

This scaffold now includes:

- `melos.yaml` as a workspace anchor for Flutter and Dart package discovery
- starter `pubspec.yaml` files for Android, iOS, macOS, and Windows host shells plus the shared packages
- a local bootstrap flow for `config/local/`
- a second validation lane in `test/seed-layout.ps1`
