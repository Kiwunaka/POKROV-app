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
source and the [retained logs](local-checks.zip). LF-normalized SHA-256 values
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
audit pass. [Final receipt](final-validation.json) binds [these logs](final-validation.zip).
Git whitespace checks, seven tested-source hashes, archive member hashes,
added local links and unchanged 83 register status/evidence/inventory tuples
are verified before commit. No release artifacts changed.
