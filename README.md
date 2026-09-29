# POKROV client

This repository builds the Android and Windows client. The public version is
`1.4.0+4081`: Android direct APK and unsigned Windows beta, with a
SmartScreen/unknown-publisher warning. Android and Windows use POKROV Core
1.1.2 from `C:/Users/kiwun/Documents/ai/POKROV-core`.

## Local build

Sync the Core AAR, DLL and libcronet.dll from the Core checkout, then validate
the version and artifact hashes:

```powershell
./scripts/sync-pokrov-core-runtime.ps1 -CoreRoot ../POKROV-core
./scripts/validate-seed.ps1 -CoreRoot ../POKROV-core -PlatformRoot ../VPN
```

Use `flutter analyze` and `flutter test` in changed packages. For Android
host changes, run both app unit-test flavors from
`apps/android_shell/android`. For Windows host changes, build on Windows.
Release packaging scripts are in `scripts/`.

Core libraries and client packages stay outside git and LFS. Core libraries
come from the local Core build or its GitHub Release. Public client files live
in [GitHub Releases for pokrov](https://github.com/Kiwunaka/pokrov/releases).
The 1.2.0 and 1.1.6 releases remain available for rollback.

Current release state and outstanding device checks are in
`docs/operations/cutover-readiness.md`. Product behavior is in
`docs/product/client-product-contract.md`; the document map is
`docs/README.md`.
