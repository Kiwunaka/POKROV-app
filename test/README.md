# Client Test Entrypoints

Use the narrowest check that covers the changed client contract or code.

Current state:

- `packages/app_shell/test/pokrov_seed_app_test.dart` covers the starter shell UI
- `packages/app_shell/test/connection_experience_test.dart` proves the typed
  reducer/presenter, false-green rules, explicit disconnect/reconnect
  semantics, ten-second slow-stage ownership/reset, haptic budget, and the full
  legal/illegal transition matrix
- `packages/app_shell/test/first_session_coordinator_test.dart` proves the
  choice/restore/ready owner, bounded busy state, shared handover and
  best-effort persistence behavior
- `packages/app_shell/test/account_session_coordinator_test.dart` proves
  account access/subscription ownership and that refresh clearing does not
  mutate independent access state
- `packages/app_shell/test/diagnostics_coordinator_test.dart` proves
  foreground single-flight, bounded post-connect polling and stale-generation
  rejection without interpreting connection evidence
- `packages/app_shell/test/client_experience_store_test.dart` and
  `packages/app_shell/test/app_first_runtime_bootstrap_test.dart` prove saved
  state v0-to-v1 migration, idempotence, future-version preservation and
  secure-session handling against sanitized fixtures
- `AndroidRuntimeProfileMigrationTest` proves the retained Android staged
  profile schema, safe legacy defaults, idempotent encoding and fail-closed
  future-version routing
- `packages/runtime_engine/test/runtime_engine_test.dart` proves ABI 2 legacy
  and descriptor negotiation, fail-closed capability/event contracts, typed
  lifecycle journaling, profile staging and runtime health behavior
- `seed-layout.ps1` provides a structure-first smoke test for the four-host starter skeleton
- `docs-contract.ps1` enforces the thin root contract and documentation registry budgets
- `client-presentation-boundary.ps1` keeps Home on one
  `ProtectionViewState`/`ProtectionIntents` boundary, rejects direct haptic
  calls outside the adapter, requires summary/details plus warned three-step
  repair disclosure, guards first-session acquisition/VPN-permission ownership
  and safe journey analytics, and prevents the app-shell `part` count from
  growing
- `release-handoff-v2-contract.ps1` proves deterministic client-side v2
  generation, platform validation, fail-closed mutations, and the
  retained-artifact no-write boundary
- `release-rollback-catalog-contract.ps1` validates the retained stable pointer
  against its versioned catalog target and proves dry-run, optimistic-lock,
  byte-identical backup, atomic forward switch, and exact rollback in an
  isolated fixture
- `release-v2-ci-contract.ps1` keeps the client PR/push workflow strict,
  cross-repository, and non-mutating
- `repository-hygiene-contract.ps1` enforces the source/runtime/history/local
  staging/public-index boundary and rejects tracked temp/build/candidate output
- `release-source-logging-contract.ps1` proves the real release tree is free of
  raw Dart/Android/Windows logging and verifies four fail-closed fixtures
- `scripts/validate-seed.ps1` validates required files and JSON seeds, then
  invokes Core parity, release-handoff v2, stable-pointer rollback, CI, and docs
  contracts

Suggested local commands:

- `powershell -ExecutionPolicy Bypass -File .\\test\\seed-layout.ps1 -PlatformRoot C:\\path\\to\\platform -CoreRoot C:\\path\\to\\POKROV-core`
- `powershell -ExecutionPolicy Bypass -File .\\test\\docs-contract.ps1`
- `powershell -ExecutionPolicy Bypass -File .\\test\\client-presentation-boundary.ps1`
- `powershell -ExecutionPolicy Bypass -File .\\test\\release-handoff-v2-contract.ps1 -PlatformRoot C:\\path\\to\\platform -CoreRoot C:\\path\\to\\POKROV-core`
- `powershell -ExecutionPolicy Bypass -File .\\test\\release-rollback-catalog-contract.ps1`
- `powershell -ExecutionPolicy Bypass -File .\\test\\release-v2-ci-contract.ps1`
- `powershell -ExecutionPolicy Bypass -File .\\test\\repository-hygiene-contract.ps1`
- `powershell -ExecutionPolicy Bypass -File .\\scripts\\validate-seed.ps1`
- `powershell -ExecutionPolicy Bypass -File .\\scripts\\run-tests.ps1`
