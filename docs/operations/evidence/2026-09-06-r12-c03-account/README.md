# R12-C03 — account summary ownership

Source baseline: client `c579708`, Core `8dc57a8`. Current-origin Windows host,
synthetic account/runtime fixtures. **I3 / PARTIALLY_FIXED**, full C03 OPEN.

`AccountSessionCoordinator` is now an independent Dart library containing its
existing account/access/subscription state and the summary refresh flight.
The coordinator serializes subscription, bonus and inbox callbacks, coalesces
overlapping calls, stops subsequent reads after shell disposal and releases
the flight on completion or error. The shell retains readiness checks, API
callbacks, observability, error handling and UI updates. The former public
export through `app_shell.dart` remains available.

This is an extraction from the behavior already verified in F07, not a new
refresh, payment, session or retry policy. A handled subscription failure still
permits bonus/inbox reads; an unhandled callback failure still ends that flight.
The tests import the coordinator directly without constructing a widget.

## Verification

- PASS: `flutter test test/account_session_coordinator_test.dart
  test/pokrov_seed_app_test.dart`, cwd `packages/app_shell`, **188 tests**.
  Five coordinator tests cover independent view state, ordered/coalesced reads,
  handled/unhandled failures with retry, and disposal after subscription or
  bonus. Existing shell tests include Android/Windows cabinet return, concurrent
  resume/Profile, offline recovery and welcome inbox guards.
- PASS: `flutter analyze`, client root, no issues.
- PASS: `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-seed.ps1
  -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start
  -CoreRoot E:/r12core-implementation`, client root. Includes client docs and
  presentation boundary; performance collection uses its existing fixture.
- PASS: `git diff --check`; no `artifacts/releases/**` delta.

Bootstrap `seed_shell.dart` shrinks by 12 lines; 29 `part` directives remain.
The library entrypoint adds one import and one compatibility export. The profile
UI part loses 27 lines. These counts describe placement, not speed or memory.
Canonical owner: `docs/architecture/package-boundaries.md`.
Exact log/archive hashes and source counts are in [receipt](receipt.json).

Existing generated registrants remain outside the change, with their prior
hashes preserved. No native host, runtime artifact or API contract changes;
no package build, install, signing, push, merge, deploy, publication or new
candidate. Device/SCM/origin/CI and final candidate gates remain open. The full
C03 connection/presentation/support/checkout sequence still needs acceptance;
this account extraction does not close it. Rollback is the scoped source commit.
