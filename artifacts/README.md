# Release files

Client releases are stored in [GitHub Releases for pokrov](https://github.com/Kiwunaka/pokrov/releases).
The retained public version is 1.1.6. Rolling back means pointing the release
index to the 1.1.6 release assets.

Core AAR, DLL and libcronet.dll stay outside git and LFS. Their required sizes
and SHA-256 values are in `config/runtime-artifacts.seed.json`. With the Core
checkout available, run `scripts/sync-pokrov-core-runtime.ps1` to copy the
local build from `POKROV-core/dist`; the same files can be obtained from a
Core GitHub Release after publication.

Flutter build output stays in ignored `apps/**/build/`. Local candidate
assembly may use ignored `artifacts/candidate-staging/`.
