# Test Placeholder

This lane will eventually hold focused tests for the new-base client program.

Current state:

- `packages/app_shell/test/pokrov_seed_app_test.dart` covers the starter shell UI
- `seed-layout.ps1` provides a structure-first smoke test for the four-host starter skeleton
- `scripts/validate-seed.ps1` remains the fast scaffold validator

Suggested local commands:

- `powershell -ExecutionPolicy Bypass -File .\\test\\seed-layout.ps1`
- `powershell -ExecutionPolicy Bypass -File .\\scripts\\validate-seed.ps1`
- `powershell -ExecutionPolicy Bypass -File .\\scripts\\run-tests.ps1`
