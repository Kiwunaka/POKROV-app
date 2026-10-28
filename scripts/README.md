# Client scripts

Use [AGENTS.md](../AGENTS.md) for working/approval rules and
[cutover readiness](../docs/operations/cutover-readiness.md) for current results.
Public **1.4.5**, the seven-asset **1.5.0+4175 draft**, and private packages
are separate; these scripts do not publish a release.

## Runtime selection

Windows **4209** reuses the accepted Windows Core/guard pair from 4205. Its selection
is `-RuntimeArtifactsPath E:/POKROV-tools/temp/core-windows-4205/runtime-artifacts.json`
and `-CoreArtifactDirectory E:/POKROV-tools/temp/core-windows-4205/windows`, with
`-CoreRoot C:/Users/kiwun/Documents/ai/POKROV-core -SyncRuntime`. Retain the approved
signing arguments and production transport-trust file
`E:/POKROV-tools/temp/release-1.5.0/client-transport-trust-defines.smartdns-4186.production.json`.
Android **4209** includes the active-profile and uplink recovery fixes; both
platform packages contain the independent-bridge cache selection. Android reuses the accepted staged AAR
with `-RuntimeArtifactsPath E:/POKROV-tools/temp/core-android-4202/runtime-artifacts.json`,
without `SyncRuntime` or a Core rebuild. See cutover readiness
for the accepted source/package scope. The default
[tracked manifest](../config/runtime-artifacts.seed.json) is not the private
selected binding and must not be used to restage this private build.

- [build-android-production.ps1](build-android-production.ps1) validates an
  already staged Android runtime with `RuntimeArtifactsPath`. Copying is
  explicit: `-SyncRuntime` or `-CoreArtifactDirectory` invokes Android-only sync.
  Both production builders accept `-WindowsReleasePath` for a paired private
  release config; omission keeps the existing Windows release seed.
- [build-windows-release.ps1](build-windows-release.ps1) validates the Windows
  runtime after requested sync or restoration of missing files. Before staging,
  it checks built Core/dependency bytes against that verified runtime and both
  executable version fields against the client version. This also applies to
  `-SkipBuild`: a stale bundle requires a rebuild. Packaging requires the seed's
  complete `local-dpi` files even when a private release config is selected.
  The optional
  [reproducible wrapper](build-windows-release-reproducible.ps1) forwards arguments
  and uses a temporary `P:` mapping.
  WinDivert's driver has a separate installer entry: an identical installed
  `local-dpi/WinDivert64.sys` is retained, even when loaded. A changed driver
  that is locked uses Inno Setup's restart replacement and restart prompt;
  DPI is not accepted with the new driver until that restart. The installer
  does not stop another application's WinDivert service.
- [sync-pokrov-core-runtime.ps1](sync-pokrov-core-runtime.ps1) requires the clean
  Core checkout at the selected manifest's exact source commit, then validates
  artifact and dependency sizes/hashes before copying. Use `-Platforms android`
  or `-Platforms windows` for a single-platform change; it otherwise selects both.
  `CoreArtifactDirectory` requires exactly one platform. Never replace exact
  bindings with whichever files happen to be in Core `dist/`.
  A Slipstream Windows SDK lists `slipstream-client.exe` and
  `slipstream-LICENSE.txt` in the selected manifest's existing runtime dependencies;
  CMake installs the pair. Android receives the per-ABI executable
  `libslipstream.so` from Core's AAR and extracts native libraries for execution
  by Core. Sync also extracts that AAR's Slipstream license into an ignored
  Android license asset. Source support alone does not establish packaged readiness.
- [check-client-version-parity.ps1](check-client-version-parity.ps1) checks
  selected-platform versions and artifact identities. Pass the same
  `RuntimeArtifactsPath` as packaging; use `-Platforms android` or
  `-Platforms windows` when checking only that host.

Signing, secure-storage and runtime pin rules are unchanged. Build from the
reviewed source only when the task needs a changed binary. Packaging checks the
produced signer/debuggable/version/ABI or required Windows files/signature;
it does not replace tests, device acceptance or release approval. Outputs stay
ignored and outside Git/LFS.

## Development checks

Run `flutter analyze` and focused `flutter test` cases from the changed package
or host. [run-tests.ps1](run-tests.ps1) is the broader runner for its listed
workspace packages and both Android unit-test flavors. Do not use it to repeat
accepted unrelated checks or for documentation-only edits.

[check-release-source-logging.ps1](check-release-source-logging.ps1) is an
optional focused source scan. It does not justify printing session/auth values
or copying private runtime material into reports.
