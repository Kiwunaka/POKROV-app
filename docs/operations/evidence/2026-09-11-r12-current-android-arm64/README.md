# Current ARM64 package and target ABI correction

**PASS_LOCAL_PACKAGE**, 2026-09-11. APK SHA-256 `3ecff58793e0f6b354ce49eabd5f84f06052a92176cd12e4c5c7583a91cc41a0`,
101,301,451 bytes (96.6 MiB), Android Direct `1.2.0+4053`.
Built from `90337b33180b1600f0d6c25029627d0e9dc5b217`: current main base
`d9763e8` plus the target ABI fix and its owner documentation. The equivalent
feature commit is `bf78a26`; product trees match across apps/packages/scripts/config.
Core remains exact `904e440aca98cb6419744c5c04c83223a6d6380e`.

Artifact: `C:/r12-current-windows-source-20260911/apps/android_shell/build/app/outputs/flutter-apk/app-direct-release.apk`.
See [receipt](receipt.json), [package audit](android-package-audit.json) and
[Android owner](../../android-release-audit.md).

## Observed defect and correction

With `target-platform=android-arm64`, Flutter compiled ARM64 application code,
but the old Gradle configuration retained three native dependency ABIs.
The actual configuration probe also showed that `android.injected.build.abi`
did not narrow release packaging. Native filters and split outputs now follow
the same Flutter target list. The ARM64 probe returns only `arm64-v8a`.
The unchanged production command still reports three ABIs and four APK outputs.
This is configuration regression proof for the full command, not five newly
built production artifacts. No new dependency or permanent build option was added.

## Package checks

The scoped harness reuses canonical signing, version, manifest and APK checks,
selecting only ARM64 Direct and omitting the full APK batch and store AAB.
`apksigner` passed and matched the existing self-managed certificate
`0a0602a7df5d96a0b427909d004f3ddf26def86587634bf16694da8d654b2500`.
Package/version/ABI match; manifest is not debuggable. ZIP audit found exactly
three native libraries, all ELF AArch64: libapp, libflutter and libpokrov-core.
Core bytes match the bound AAR; Flutter bytes match the retained official binary
binding. The AOT payload contains the full compiled client revision.
All four required source notices and Flutter NOTICES.Z are present.

Commands and results:

```text
gradlew --offline --no-daemon --max-workers=2 -I abi-probe.gradle -Ptarget-platform=android-arm64 :app:r12AbiProbe
gradlew --offline --no-daemon --max-workers=2 -I abi-probe.gradle -Ptarget-platform=android-arm,android-arm64,android-x64 -Ppokrov.singleVersionSplitApks=true :app:r12AbiProbe
pwsh -NoProfile -File test/release-handoff-v2-contract.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot C:/r12corec02
pwsh -NoProfile -File scripts/validate-seed.ps1 -CoreRoot C:/r12corec02 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start
python -B E:/r12-current-android-package-20260911/run-build.py
python -B E:/r12-current-android-package-20260911/audit-android.py
```

Both configuration probes PASS, release-handoff contract 16 PASS, seed PASS,
package build/signing/audit PASS. [Final documentation checks](validation.json)
retain their commands, exit codes and log hashes.

## Capacity and limits

The full previous five-package build occupied approximately 4.48 GiB and did
not fit the required 40 GiB floor. This build reused the current C: checkout
and existing exact AAR, with projected growth 1.8 GiB C: / 0.15 GiB E:.
A watchdog measured every second and would stop below 40.25 GiB. Actual minima
were C: 40.977 / E: 40.365 GiB.
No cache deletion, new checkout, Core rebuild, VM start or phone action occurred.

Two external-harness pre-build failures are retained: wrong support seed root,
then missing initial LASTEXITCODE in isolated PowerShell. Both were corrected
in the external harness; the signing/version guards remained intact. During
compilation Kotlin incremental caches reported different C/E roots; compiler
fallback completed and the build exited 0 in 150.2 seconds. The raw log is kept.
The six earlier LFS/CRLF stat entries remain; logical source diff is empty.

This APK is not installed or published. Other current direct APKs and the store
AAB are NOT_BUILT_CAPACITY_FLOOR. Existing device results apply to their earlier
hashes. R12-D01/C04/Q01 and the full release goal remain open. No CI run is claimed
for this new local commit, no release metadata/public pointer changed, and no
push, merge, deployment or distribution occurred.
