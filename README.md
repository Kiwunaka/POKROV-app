# POKROV client

Android and Windows are the public client platforms. Public **1.4.5**, draft
**1.5.0+4175 / seven assets**, and private **Android/Windows 1.5.0+4180** are
separate states. Current package results, device limits and release decisions
live in [cutover readiness](docs/operations/cutover-readiness.md).

Start with [AGENTS.md](AGENTS.md), the [document index](docs/README.md), and the
[repository map](docs/architecture/folder-structure.md). The product contract
is [here](docs/product/client-product-contract.md); UI ownership and data
boundaries are in [DESIGN.md](DESIGN.md).

## Local work and packaging

Run `flutter analyze` and focused `flutter test` cases from the changed package
directory. [scripts/run-tests.ps1](scripts/run-tests.ps1) is the broader workspace
runner, including Android unit-test flavors; it is not required for a docs-only
change. Tests cover behavior such as lifecycle, candidate selection, secure
state, UI actions and accessibility. Build only when the task requires a changed
binary, using the existing [packaging scripts](scripts/README.md).

**Android 4180 uses the new Core AAR from `5364537`.** Any repeat Android
packaging must pass
`-RuntimeArtifactsPath E:/POKROV-tools/temp/core-android-mobile-auth/runtime-artifacts.android.json`.
The default [tracked manifest](config/runtime-artifacts.seed.json) was not
updated: Windows retains Core 1.2.14 / `40356d4` and matching Cronet. Do not use
the default manifest to restage the older Android AAR, or pass the Android
override to Windows. Existing source pins, binary/dependency checks, signing,
trust defines and secure-storage rules remain required.

Core libraries and client packages stay outside git and LFS. Core libraries
come from the pinned Core artifacts, not an arbitrary checkout's latest output.
Public client files live
in [GitHub Releases for pokrov](https://github.com/Kiwunaka/pokrov/releases).
