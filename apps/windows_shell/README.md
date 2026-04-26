# Windows Shell Seed

Current responsibility:

- Windows-specific Flutter host entry point for the shared `POKROV` seed shell
- desktop FFI runtime integration through `pokrov_runtime_engine`
- local host-runtime sync at `windows/runner/resources/runtime`
- prerelease Windows runner metadata that identifies the binary as `POKROV Windows Seed`
- local release-build verification and unsigned bundle packaging through `..\\..\\scripts\\build-windows-release.ps1`

Current local truth:

- `flutter build windows --release` produces a runnable beta bundle with `pokrov_windows_beta.exe` and `libcore.dll`
- the shared shell keeps local runtime controls out of the first layer and uses one-tap connect from `Protection` on Windows
- the packaged output stays inside the next-client seed lane under `build/release_bundle` and is not a public release artifact

Deferred responsibility:

- Windows process-picker integration for selected-apps mode
- elevated lifecycle hardening for the real full-tunnel and selected-apps paths
- trusted code signing, installer or `MSIX` publication, and updater wiring
- public download hosting, Microsoft Store submission, and product cutover
