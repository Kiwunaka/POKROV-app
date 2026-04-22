# Scripts

This folder is for non-destructive local helpers only.

Current helpers:

- `validate-seed.ps1`: checks that the Wave 7 scaffold files, four host shells, starter packages, and JSON config seeds exist
- `bootstrap-workspace.ps1`: runs `flutter pub get` across the clean-room packages and four host entrypoints
- `run-tests.ps1`: bootstraps the workspace and runs the shared shell widget tests
- `bootstrap-local.ps1`: copies example config seeds into `config/local/` without touching production paths unless explicitly forced
- `build-windows-release.ps1`: validates the seed, optionally syncs Windows runtime artifacts, runs analyze and tests, builds `flutter build windows --release`, verifies the release bundle, and stages an unsigned zip plus manifest under `apps/windows_shell/build/release_bundle`

The Windows helper is still local and unsigned. It does not create a public release, trusted installer, `MSIX`, store submission, or deploy hook.
