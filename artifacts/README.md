# Runtime Artifacts

Committed client runtime binaries live only in their host bundle paths:

- Android: `apps/android_shell/android/app/libs/pokrov-core.aar`
- Windows: `apps/windows_shell/windows/runner/resources/runtime/pokrov-core.dll`
- Windows dependency: `apps/windows_shell/windows/runner/resources/runtime/libcronet.dll`

Their exact source commit, sizes, and SHA-256 values are owned by
`config/runtime-artifacts.seed.json`. Use
`scripts/sync-pokrov-core-runtime.ps1` to copy them from the separate
POKROV Core checkout.

`artifacts/releases/**` is retained release evidence. Runtime sync and normal
client development must not modify it.

Generated build output and local caches are not release truth and remain
untracked.
