# C05 licensed uTLS and C02 lifecycle binding — 2026-09-11

The development client binds Core `2662f76a3303a0518bb07fbbdc449c066de2f95b`
with source tree `e85be4e008668a2d57465bf49e1f413b020ab156`.
[Binding](binding.json), [previous pin](previous-runtime-binding.json),
[Android](android-evidence.json) and [Windows](windows-evidence.json) retain
exact identities. Both native DE builds per platform match byte for byte.
The source commit remains separate from CI merge head `8bd0307`; their source
trees match. These are pre-candidate libraries, with no public release.

[Composition](artifact-composition.json) verifies the actual DLL and four
Android ELF build-info records. Only the Psiphon uTLS version changes among
retained external Go modules; Cloudflare CIRCL is no longer linked. Android
keeps all four ABIs. Windows imports KERNEL32.dll and msvcrt.dll using the
authenticated MinGW-w64 11.0.1/GCC13.2 toolchain; it does not reuse the earlier
UCRT toolchain claim. Go build settings remain equal to the previous graphs.

[Notice assembly](notices-preparation-2662f76-with-crt.json) verifies all 191
verbatim blocks, including retained license bodies, the exact new uTLS root
license, its file attribution and four compiler-runtime notice blocks.
[Compiler sources](compiler-notice-inputs.json) retain upstream Git identities.
The recorded missing uTLS root license is resolved for these module bytes.
Complete native, client and corresponding-source clearance remains separate.

The actual Windows DLL passes [ABI and 100 Dart proxy cycles](windows-abi-proxy.json)
and [300 lifecycle cycles](artifact-lifecycle-2662.json), including 600 cancelled
loopback sessions and a stable final handle window. These current-origin
checks do not mutate host routes or establish physical VPN acceptance.

The original [offline SBOM failure](artifact-build-2662-sbom-failed.json) and
[Android OOM](android-oom-status.json) remain retained. Generated source from
the failed build was [preserved and hash-verified](oom-generated-source-retained.json).
The successful [Android retry](android-serial-progress.json) serializes Go
build invocations with flock under the same 4 GiB/one-CPU limit. Compiler
arguments, pinned toolchain and product build scripts were unchanged.

[Initial Core CI](core-ci-initial-receipt.json) passed test and Android,
Windows and Apple artifact jobs. The strict release contract failed because
client/main still pinned Core 904. Coordinated promotion and installed
acceptance remain pending; the failed gate is not reported as a pass.

[Consumer checks](consumer-checks.json) passed 81 runtime tests, 8 Android
Flutter tests and explicit source seed/docs gates. [Java API comparison](android-java-api.json)
verified all 99 generated wrapper files byte for byte against the previous
AAR. Original compiler-license whitespace is preserved with a scoped Git
attribute for the notice asset.

[Five binary scans and inventories](binary-scan-retention.json) retain the
DLL and four ELF inputs, commands and results. All return the same nine Go
advisory IDs. Each stripped binary yields zero extracted symbols, so the
scanner's 21 function-trace records are module-level advisory data, not proof
that those functions are linked or reachable. The [current static binding](static-triage-binding.json)
verifies the previous affected-package matrix and relevant registrations and
consumers, 3953 unchanged authenticated external source files and 81 files
from the new authenticated uTLS archive. Five offline package graphs pass.
This does not close native or whole-application vulnerability assessment.
