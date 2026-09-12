# Android per-call probe observations — 2026-09-12

Status: **PASS_LOCAL_SOURCE_CHECKS_NOT_INSTALLED_PACKAGE_PROOF**.

Core already returns closed stage messages from its synchronous probe methods.
Android reflection previously treated every exception as an unavailable API.
The initial regression reproduced that loss: 13 tests, one failure; a completed
response failure was `UNAVAILABLE` instead of `FAILED`.

The host now accepts only the four exact Core stage messages. Connection and
TLS negotiation retain their existing public failure codes; response and generic
probe failures retain `core_egress_probe_failed`. Unknown text and missing APIs
remain unavailable. No raw exception or inferred filtering cause is exported.
Endpoint retries, terminal group failure, generation fences, fail-close and
the AWG degraded-TUN exception keep their completed-failure semantics. Two
Android shell retry conditions now use the existing shared failed-egress set.
The stop reason stays generic; the failure kind carries the observation.

[Receipt](local-receipt.json) binds the seven tested source/test files, the Core
source and the [retained logs](C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start/docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/evidence/n05-android-probe-observations-20260912/local-checks.zip). LF-normalized SHA-256 values
allow checking the same source through Git's existing line-ending conversion.
The [runtime owner](../../../architecture/bootstrap-workflow.md) defines behavior.

Commands from the affected package directories, using Flutter 3.38.5:

- `flutter test test/runtime_engine_test.dart --plain-name 'mobile lane distinguishes observed network failures without guessing' --no-pub`: PASS, 1.
- `flutter test test/pokrov_seed_app_test.dart --name 'managed fallback on|emergency connect rotates after|android.*(egress|fail.close)' --no-pub`: PASS, 11; includes typed failure fallback, unavailable proof and refused fallback.
- `flutter test --no-pub` in `apps/android_shell`: PASS, 8.
- `flutter analyze --no-pub` in `packages/app_shell` and `packages/runtime_engine`: PASS, no issues.
- `gradlew.bat :app:testDirectDebugUnitTest :app:testStoreDebugUnitTest --offline --no-daemon --max-workers=2`: PASS, 190 tests in each flavor, no skips; 51 seconds. Includes call isolation, exact-string rejection, retry bounds and stale-generation checks.

These are local reflection fixtures and host/source tests. No new APK, AAR,
DLL or installer was produced or installed. The existing device package does
not contain this change. Physical Android, installed gomobile behavior, Windows,
RU-origin and full N05/N01/N03 acceptance receive no new pass. No push, deploy,
production mutation or expense occurred. Rollback is a scoped source revert;
release artifacts and previous runtime evidence are unchanged.


Final checks: the other two callers of the changed failed-egress fixture also
pass (`flutter test test/pokrov_seed_app_test.dart --name 'failed WARP connect falls back to ordinary VPN|manual retry after egress failure retains' --no-pub`).
The total is 22 focused Flutter tests. `validate-seed.ps1` with PowerShell Core,
the exact platform/Core roots, 33 platform docs/context tests and the context
audit pass. [Final receipt](final-validation.json) binds [these logs](C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start/docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/evidence/n05-android-probe-observations-20260912/final-validation.zip).
Git whitespace checks, seven tested-source hashes, archive member hashes,
added local links and unchanged 83 register status/evidence/inventory tuples
are verified before commit. No release artifacts changed.


## Installed Android follow-up

The source-only checks above are followed by this separate installed observation.
[Result](installed-result.json), [file receipt](installed-files.json) and
[instruments/logs](C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start/docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/evidence/n05-android-probe-observations-20260912/installed-evidence.zip) bind source c2d2e02/Core6b, signed
[PR127](https://github.com/Kiwunaka/POKROV-app/pull/127) head c1353986 and signed
merge f31ecb22. Both exact CI runs pass on the same tree; branch protection is
unchanged. Seven tested code/test files match exactly. Only the task patch is
applied to the architecture owner; an older local licensing paragraph is excluded.

The separate x86_64 APK e844bf15 is109718342 bytes, same signer/version4053,
non-debuggable and bound to the current Core. DEX contains the new closed stage
strings. Compared with b93, only classes.dex, libapp.so and baseline.prof change.
Four notices and the native Core/Flutter libraries match. Three overwritten
build outputs are restored; all nine prior outputs/rollback files are verified.

Normal rootless install-r preserves UID10111, first-install time and boot identity.
On this APK, manual New York/Full Connect reaches the exact new connection-stage
[failure copy](installed-connect-failure.png), Retry and a stopped TUN/service.
The underlying path failure is not fixed. Raw native exception text is not
exported; the observation is the bounded public copy through the installed
Core/host path. No filtering cause is inferred.

Normal SPB/ordinary Retry in Full mode [recovers](installed-recovery.png), with
active tun0/service, successful host protection checks and no previous failure.
This is host/Core proof, not a new independent HTTPS, leak or per-UID oracle.
Back/Disconnect and Russia-direct [restore Home](installed-restored.png).
Root stays false; no new guest instrument is installed. Guest route/DNS hashes,
normalized IPv6 and host route/DNS hashes match. All emulators stop; other disks
are unchanged; growth13MiB and sampled40GiB floors pass. The new APK is kept.
The ineffective Dismiss-handle tap and subsequent pre-input lookup failure are
retained as a harness adjustment; normal Back closes the sheet.

Installed TLS/response/timeout faults, physical Android, Windows, RU-origin,
N01/N03 and full N05 remain open. No earlier routing matrix is transferred to
this new package. Source is merged; release publication/pointers, production
configuration and paid settings are unchanged. Budget $0.


The post-commit seed check rejected the two earlier tracked ZIP logs under the
client's repository-hygiene rule. All three exact archives are now retained in
platform evidence; receipts and links point there, and hashes are unchanged.
The initial failed check and relocation receipt are preserved in that directory.
No hygiene allowlist or release-history exception was added.

Final [post-relocation gates](C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start/docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/evidence/n05-android-probe-observations-20260912/final-gates.json) pass: client seed/docs, 33 platform tests and context audit. All three archive hashes and71 member hashes are verified in Git indexes; the original two committed archives match the platform copies exactly. The direct result JSON records Git LF normalization separately, with identical JSON values. All83 registry status/evidence/inventory tuples and release artifacts remain unchanged.
