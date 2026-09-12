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


## Active TUN failure copy — 2026-09-12

When Android retains the AWG TUN after a failed egress check, the shared copy
previously claimed that VPN was disabled. It now uses the reported runtime
phase: running says the system VPN remains enabled and egress is unconfirmed.
Non-running snapshots retain their previous stop copy. Native text reports
the failed check without inferring lifecycle. Codes, health, retry and tunnel
ownership are unchanged.

[Source receipt](active-tun-copy.json) binds six source/test/owner files and
retained logs in platform evidence. Both new regressions failed before the fix.
An old native message expectation failed after the fix and was updated while
keeping the assertions that runtime stopped and failure metadata survived.
Final checks: 191 JVM tests per flavor; 82 runtime tests plus one existing
opt-in skip; 12 app-shell and 8 Android Flutter tests; runtime analyze clean.

This is source/bridge-fixture evidence. Installed APK e844bf15 predates this
change; retained-TUN device proof, remaining N05, physical Android, Windows,
RU-origin and N01/N03 gates remain open. No package or release artifact changed.
Rollback is a scoped source revert. Source promotion is not part of this receipt.


## Active TUN copy installed follow-up — 2026-09-13

[Exact receipt](active-tun-installed.json) binds client `17b9df4` / Core `6b271dec` to
[PR128](https://github.com/Kiwunaka/POKROV-app/pull/128), signed head `52d86642`
and signed main db445c69 with the same tree. Required PR run `34718776833` and
main run `34719255601` CI passed; branch protection is unchanged.

Separate production-signed version 4053 APKs are retained: ARM64 dd6ffb6f,
100926279 bytes; x86_64 ab70712a, 109718342 bytes. The compiled revision and
Core match; only classes.dex/libapp.so/baseline.prof differ from the respective
previous installed packages. Core, Flutter and four license notices match.
Nine previous canonical outputs were reverified; four overwritten outputs
were restored after retaining both APKs and the two-ABI combined package.

Huawei ADA-AL00U/API 31 install-r preserves UID 10662, first-install and Android
settings. Visible profile text hashes match, access remains active. Ordinary
Warsaw connect and refreshed tunnel/DNS/egress checks pass. Disconnect restores
exact route/rule hashes; the subsequent shell HTTPS returns 200. Phone remains
VPN off, Wi-Fi/mobile on. Private secure storage was not read.

LDPlayer 14 / index 3 remains rootless. Install-r preserves UID 10111, first-install
and boot. SPB ordinary connect plus refreshed app protection passes. Disconnect
restores Home, route/DNS hashes and IPv6 semantics. VM is off, other disks and
host routes/DNS are unchanged; disk growth 5 MiB, floor 40 GiB maintained.

These are ordinary installed controls. The exact isolated install has no
ready AWG2 or AWG3.1 material; guarded binder PLAN stops before mutation.
The retained-TUN failure case requires fresh exclusive peers/material through
the existing L3 provisioning path. No copied device keys, broader cohort or
rollout bypass was used. N05 and remaining full-plan gates stay open.


## AWG3.1 retained-TUN failure — 2026-09-13

[Exact receipt](awg31-active-tun-fault.json) uses the existing installed x64
ab70712a/client17b/Core6b bytes. Exclusive AWG3.1 material and canonical profile
readback now pass. During a180-second exact-peer owned HTTPS-path fault, native
probe failed with TUN/service retained; refreshed UI correctly showed attention
and unconfirmed egress. Repair after fault removal recovered native and UI proof
with the same canonical config. No TLS-specific event-code claim: exported
native journal only says failed. Temporary rules and lab admission removed;
root restored and verified unavailable on next boot, all VMs off, host routes/DNS
unchanged. Same-boot Android networking restored; later boot IPv6 hash differs
and is not attributed. Ordinary Frankfurt failed, SPB control succeeded.
Remaining N05 device/origin/taxonomy and full release gates stay open. AWG2
repeats are excluded by the owner; existing consumers are retained.
