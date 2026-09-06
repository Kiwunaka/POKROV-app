# R12-D06 — Android APK size and debugger resource

2026-09-06. **I3 / NEEDS_RUNTIME_PROOF** for the full D06; local packaging
analysis and correction **PASS**. D01/final candidate acceptance remains open.
Client baseline `0e69b11`, Core `8dc57a8`. These are local Direct release-mode
APKs, signed with Android Debug and configured with a loopback API endpoint.
They are not production-signed packages or a new release candidate.

## Measured result

The [baseline breakdown](size-breakdown.json) accounts for every ZIP entry,
both stored/compressed sizes, each ABI, Core, Flutter, Dart AOT, assets, fonts,
Android resources and notices. APK signing/alignment/ZIP overhead is counted
separately; each total reconciles to the exact file size. The [after receipt](after-packaging.json)
proves the packaging change against the retained baseline bytes.

| Direct APK | Before bytes | After bytes | Removed bytes |
| --- | ---: | ---: | ---: |
| ARM64 | 101226830 | 101225939 | 891 |
| ARMv7 | 90741060 | 90740169 | 891 |
| x86_64 | 110235757 | 110234866 | 891 |
| Universal | 295211561 | 295210670 | 891 |

ARM64 delivery avoids 193984731 bytes versus universal (65.71%); its three
native libraries match the universal ARM64 entries byte-for-byte. The
platform source still selects ARM64 as the main download and retains universal
fallback. This is source/byte evidence, not public endpoint or installed-device proof.

ARM64 after-change compressed/stored payload:

| Component | Bytes |
| --- | ---: |
| Core | 78530968 |
| Flutter | 11107920 |
| Dart AOT | 8061872 |
| DEX | 1137399 |
| Flutter assets | 1639513 |
| Fonts | 125091 |
| License texts | 247117 |
| Android resources/manifest | 265423 |
| Other metadata/resources | 11064 |
| ZIP/alignment/signing overhead | 99572 |

Compared with the initial C05 package audit (same native binding), the
pre-D06 APKs grew by 136282 bytes each: 135592 compressed notice bytes, 65 asset
manifest bytes and 625 overhead bytes. All DEX/SO/font bytes stayed identical.
The size growth therefore does not justify removing license/source obligations.

## Correction and retained review decisions

`DebugProbesKt.bin` was the exact 1738-byte resource from
`kotlinx-coroutines-core-jvm:1.7.1`. Its [versioned upstream guidance](https://github.com/Kotlin/kotlinx.coroutines/blob/1.7.1/README.md#avoiding-including-the-debug-infrastructure-in-the-resulting-apk)
allows excluding that debugger resource without affecting normal coroutine
operation. The existing Android `packaging.resources` configuration now excludes
only this name. In every rebuilt APK, it is the only removed entry; no entry was
added or changed, and compression sizes of every retained entry also match.
The 782-byte compressed resource plus 109 bytes of overhead account for the
891-byte reduction. Manifest, DEX, native code, resources, fonts and notices
remain byte-identical. No runtime behavior or license material was cut.

[Review decisions](review-decisions.json) retain the original finding and hashes.
`META-INF/services/m2.a` is a six-byte Java service-provider record, not an ar
archive; it remains packaged. Three duplicate branded PNGs account for 211103
extra bytes. They remain because the shared `PokrovBrandMark` currently loads
the unqualified host asset path; removing that path alone would break the mark.
A wider asset-contract migration is unnecessary for this nonblocking size task.

The full filename inventory contains no desktop executables/libraries,
evidence directories, logs, dumps, PDBs, source archives or native ar archives.
The [ELF section readback](native-section-review.json) found no `.debug_*`,
`.zdebug_*` or `.gnu_debuglink` sections in all nine libraries. AAPT reports no
debuggable application flag in all four baseline APKs; unchanged binary
manifests bind that result to the after packages. This is targeted packaging
inspection, not a complete privacy/advisory/reachability assessment.

## Verification and limits

- `python -B docs/operations/evidence/2026-09-06-r12-d06-size/collect.py` — PASS,
  four retained baseline APKs and four earlier C05 APKs authenticated and compared.
- From `apps/android_shell`: `flutter test` — PASS, 8 tests.
- From `apps/android_shell`: `flutter build apk --release --flavor direct --target-platform android-arm,android-arm64,android-x64 --android-project-arg=pokrov.singleVersionSplitApks=true --dart-define=POKROV_API_BASE_URL=http://127.0.0.1:9 --dart-define=POKROV_APP_VERSION=1.2.0` — PASS, four APKs. Explicit internal debug signing; Flutter 3.38.5 and JDK 17.0.18.
- `python -B docs/operations/evidence/2026-09-06-r12-d06-size/verify-after.py` — PASS,
  377/377/383/377 retained entries identical, four signatures verified.
- From `apps/android_shell/android`: `gradlew.bat :app:testDirectDebugUnitTest :app:testStoreDebugUnitTest` — PASS,
  [186 tests per flavor](jvm-results.json), zero failures/errors/skips.

Current APKs and native section logs are retained at `E:/r12-d06-size/`;
earlier APKs remain in their C05 evidence directories. No installation, VPN,
host network change, production signing, publication, push, merge, deploy or
new candidate was performed. D01's physical ARM64 path, final signed bytes,
actual distribution readback and full C05 remain open. Rollback is the scoped
Gradle exclusion change; historical packages and evidence remain retained.

Final client checks: `validate-seed.ps1 -PlatformRoot
C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot
E:/r12core-implementation` PASS; its performance collector uses a fixture.
`git diff --cached --check` PASS; `artifacts/releases/**` has no delta.
The [receipt](receipt.json) retains exact commands, log hashes and a verified
archive of the original evidence bytes, native section output and JVM XMLs.
