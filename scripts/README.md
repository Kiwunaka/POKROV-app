# Client scripts

- `sync-pokrov-core-runtime.ps1`: copy the exact local Core AAR, DLL and
  libcronet.dll after checking their sizes and SHA-256 values.
- `check-client-version-parity.ps1`: compare Android, Windows, app shell,
  Core and release-target versions and validate local Core binaries.
- `validate-seed.ps1`: run version/artifact parity and the optional client/platform contract check.
- `run-tests.ps1`: run package Flutter checks and both Android unit-test
  flavors.
- `build-android-production.ps1`, `build-windows-release.ps1`: package
  release candidates locally. Outputs stay ignored until placed in GitHub
  Releases.

The current public 1.1.6 client and its rollback assets are in GitHub Releases
for `Kiwunaka/pokrov`. Core libraries are distributed through the Core
release or from the local Core checkout.
