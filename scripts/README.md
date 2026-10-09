# Client scripts

- `sync-pokrov-core-runtime.ps1`: copy the exact local Core AAR, DLL and
  libcronet.dll after checking their sizes and SHA-256 values.
- `check-client-version-parity.ps1`: compare Android, Windows, app shell,
  Core and release-target versions and validate local Core binaries.
- `run-tests.ps1`: run package Flutter checks and both Android unit-test
  flavors.
- `build-android-production.ps1`, `build-windows-release.ps1`: package
  release candidates locally. They check only the produced binary (signer,
  debuggable flag, version, ABI, required files, Authenticode when signing)
  and print its size and SHA-256; they write no evidence or manifest files and
  do not run tests. Outputs stay ignored until placed in GitHub Releases.
- `check-release-source-logging.ps1`: optional manual scan for session or auth
  values logged from release sources.

The current public 1.1.6 client and its rollback assets are in GitHub Releases
for `Kiwunaka/pokrov`. Core libraries are distributed through the Core
release or from the local Core checkout.
