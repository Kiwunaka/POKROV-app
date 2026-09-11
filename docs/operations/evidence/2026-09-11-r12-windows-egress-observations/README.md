# R12-N05 — Windows egress observations

Document class: EVIDENCE. Captured 2026-09-11. Scope: the existing Windows
WinHTTP verification path, its service/Dart boundary and automatic fallback.
This is bounded local source evidence; full N05 depends on N01/N03 and remains open.

## Defect and change

The installed Windows path uses service WinHTTP verification, independently of
the Core DLL probe. WinHTTP collapsed all request failures into
`core_egress_probe_failed`; RuntimeHost then discarded the returned reason.
A real closed-loopback-port regression and host propagation regression failed
before the fix. Both original failure logs are retained.

The service now retains only a WinHTTP numeric error and request phase. Six
closed codes cross the existing allowlists: DNS failure, connection failure,
TLS failure, TLS timeout, response timeout and general timeout. RuntimeHost
still rejects unknown/raw reasons. Dart maps them to existing diagnostic codes
and describes observations without assigning DPI, MTU, ASN or blocking as cause.
The IPC shape, fixed production URL, three probe attempts, 900/1500 ms backoff,
cancellation, rollback, managed fallback eligibility and budget are preserved.
UI and service must be shipped together to recognize the new allowed values.

The callback handling follows Microsoft's [WINHTTP_STATUS_CALLBACK contract](https://learn.microsoft.com/en-us/windows/win32/api/winhttp/nc-winhttp-winhttp_status_callback)
and [WinHTTP error definitions](https://learn.microsoft.com/en-us/windows/win32/winhttp/error-messages).
The TLS/response labels are observations of the last request phase, not a claim
about the network's cause. No raw hostname, address, URL, response or provider
payload is exposed by the new path.

## Validation and limits

- All 12 affected native targets rebuilt in Debug; CTest reports 12/12 PASS in
  64.51 seconds. The retained detailed log records the actual executable paths.
- Real closed port: `core_egress_connect_failed`. TLS ClientHello stall:
  `core_egress_tls_timeout` in 23891 ms. HTTP response stall:
  `core_egress_response_timeout` in 24734 ms. Pending-header cancellation: 62 ms.
  Tests assert all three attempts for the stall cases; proof mismatch and
  cancellation remain fail-closed. No production network was faulted.
- RuntimeHost preserves typed reasons after rollback and rejects unknown raw
  reasons. Client IPC tests accept the closed list only.
- Runtime package: 81 PASS, one existing opt-in skip. Existing Windows managed
  fallback tests: 6 PASS. Focused observability mapping: 1 PASS. Earlier focused
  subsets are retained but are not added to these totals.
- Flutter analysis of app_shell, runtime_engine and observability_runtime: no
  issues. Exact-Core seed validation and client docs contract: PASS.
- Relinking exposed a stale service integration assertion: it omitted the
  already-advertised sanitized-diagnostic capability. The test expectation was
  corrected without changing service capabilities or permissions. That failure
  is retained alongside the final all-target run; the earlier partial/stale
  binary result is not the final evidence.

Source `e9dc104` was tested locally. Fourteen code/test files are byte-identical
in the signed promotion source; the architecture document has the same task
patch, with two prior local-only annotations absent from the main baseline.
`source-byte-binding.json` distinguishes both Git hashes. An initial promotion
guard stopped before sending anything because it expected whole-document
identity; after reviewing this baseline difference, the binding was corrected.
No release tests were repeated merely because an identical tree was signed.

There is no new DLL, AAR, APK, installer, installed-device proof, Android result
or public release in this slice. The VM and phone were not used. The previously
installed a24/Core904 package predates these changes. DNS/TLS error mappings are
source/fixture results; actual DNS and certificate faults on an installed
package remain untested here. All broader N05 observations remain subject to
the original acceptance criteria; these results do not close N01/N03.

## Reproduction surfaces

Native targets use `cmake --build apps/windows_shell/build/windows/x64 --config
Debug --target <target>`; CTest runs against that build directory. Exact native
executables and outcomes are in `native-all-current-observed.log`. Dart logs
come from the existing runtime_engine suite, filtered existing app_shell
managed-fallback tests and the existing observability phase-timeline test.
`flutter analyze` ran in each of the three affected packages.

Final documentation checks use `scripts/validate-seed.ps1 -PlatformRoot
C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot C:/r12corec02`
and `test/docs-contract.ps1`. Platform checks are the existing 33 docs tests,
context audit, local-link validation and `git diff --check`.

CI and delivery are recorded in the appended final receipt. Logs preserve
original failures as well as final successes. No destructive cleanup or paid
service was used. Free space was checked against the owner's 40 GiB reserve.

## Source delivery

[PR113](https://github.com/Kiwunaka/POKROV-app/pull/113) merged `7ed18c97c43ba39ce18701220d487af1b0c5a446` from signed
`010f441cab501eebc43bde4a50ceb4b85601a480` with the same tree. [PR CI](client-ci-pr.json) and
[merge CI](client-ci-merge.json) PASS. [Final receipt](validation.json) retains
19 original local captures and seven delivery/documentation captures. The
client seed/docs and 33 platform docs tests/context audit pass. No new binary
was built or installed. Documentation/evidence commits are local; the source
fix is on main. All original failed and skipped checks retain their labels.
