# Marker replacement: current packages and source promotion

Document class: EVIDENCE. [Receipt and captured hashes](receipt.json).
The [source fix](../2026-09-12-r12-marker-atomicity/README.md) removes the
pre-rename deletion of the previous crash marker. Two fault tests first
reproduced loss of the old file, then passed with the fix; all 31 package tests
and analysis pass. A native Windows sharing-violation fixture preserves the
old bytes on failure and replaces the existing target after the lock is released.
This proves the tested failure mode, not power-loss durability.

PR125 and main d6c7c3de have successful exact CI, verified signed tree equality
and unchanged branch protections. Active package source is 8067520c/Core6b;
the retained promotion binding distinguishes the compiled local commit from
its equivalent promoted active source. Conditional CI skips remain skips.

Four production-signed direct APKs and one store AAB pass version4053, intended
ABI, current compiled Dart revision, Core/Flutter identity and four source
notice checks. Current DEX bytes match previously parsed inputs. Windows setup
and all304 staged/extracted payload files match; only data/app.so changed from
the preceding package, with all303 other payload files unchanged. Nine Release
CTest cases pass. Authenticode remains SKIPPED_BY_OWNER. No store submission,
public artifact distribution or current package installation occurred.

The first direct build stopped at its storage guard; its original logs and
measured minima remain under stopped-* names. Both drives stayed above40GiB.
Five prior Android packages were hash-verified on owned private DE storage.
Three old store intermediate groups were streamed to a private archive and
every member hash verified before17 exact retained local files were removed.
Native intermediate compression preserved file hashes. Four proven duplicate
new APK copies were removed with the verified primary APKs retained. The
subsequent direct and store build guards passed. Prior Windows setup and
manifest remain in local rollback storage with exact retained hashes.

The installer extractor used nobody with an empty network namespace in the
owned Ubuntu VM, never executed the installer, and shut down within budget.
Before this source fix, the Windows acceptance attempt could not capture the
VM window correctly. No installer was launched; the VM was returned off and
its snapshots retained. That record is in the platform work-order evidence.
The prior physical Huawei F711 run and earlier Windows installation remain
valid only for their exact prior bytes. New806 installed acceptance, full
privacy/license and release gates remain open.
