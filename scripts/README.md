# Client scripts

Use [AGENTS.md](../AGENTS.md) for working/approval rules and
[cutover readiness](../docs/operations/cutover-readiness.md) for current results.
Public **1.4.5**, the seven-asset **1.5.0+4175 draft**, and private **4181**
packages are separate; these scripts do not publish a release.

## Runtime selection

**Both private 4181 packages use Core 1.2.14 from `0f159bb`.** Pass
`-RuntimeArtifactsPath E:/POKROV-tools/temp/core-urltest-history-0f159bb/runtime-artifacts.json`
to repeat Android and Windows packaging commands, retaining the approved signing
and transport-trust arguments. Set `CoreArtifactDirectory` to that folder's
`android` or `windows` subdirectory respectively, with
`-CoreRoot C:/Users/kiwun/Documents/ai/POKROV-core`; Windows also needs `-SyncRuntime`.
The default [tracked manifest](../config/runtime-artifacts.seed.json) was not
updated and must not be used to restage older runtime artifacts for 4181.

- [build-android-production.ps1](build-android-production.ps1) validates an
  already staged Android runtime with `RuntimeArtifactsPath`. Copying is
  explicit: `-SyncRuntime` or `-CoreArtifactDirectory` invokes Android-only sync.
- [build-windows-release.ps1](build-windows-release.ps1) validates the Windows
  runtime after requested sync or restoration of missing files. Before staging,
  it checks built Core/dependency bytes against that verified runtime and both
  executable version fields against the client version. This also applies to
  `-SkipBuild`: a stale bundle requires a rebuild. The optional
  [reproducible wrapper](build-windows-release-reproducible.ps1) forwards arguments
  and uses a temporary `P:` mapping.
- [sync-pokrov-core-runtime.ps1](sync-pokrov-core-runtime.ps1) requires the clean
  Core checkout at the selected manifest's exact source commit, then validates
  artifact and dependency sizes/hashes before copying. Use `-Platforms android`
  or `-Platforms windows` for a single-platform change; it otherwise selects both.
  `CoreArtifactDirectory` requires exactly one platform. Never replace exact
  bindings with whichever files happen to be in Core `dist/`.
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
