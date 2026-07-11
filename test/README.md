# Client Test Entrypoints

Use the narrowest check that covers the changed client contract or code.

Current state:

- `packages/app_shell/test/pokrov_seed_app_test.dart` covers the starter shell UI
- `seed-layout.ps1` provides a structure-first smoke test for the four-host starter skeleton
- `docs-contract.ps1` enforces the thin root contract and documentation registry budgets
- `scripts/validate-seed.ps1` validates required files and JSON seeds, then invokes `docs-contract.ps1`

Suggested local commands:

- `powershell -ExecutionPolicy Bypass -File .\\test\\seed-layout.ps1`
- `powershell -ExecutionPolicy Bypass -File .\\test\\docs-contract.ps1`
- `powershell -ExecutionPolicy Bypass -File .\\scripts\\validate-seed.ps1`
- `powershell -ExecutionPolicy Bypass -File .\\scripts\\run-tests.ps1`
