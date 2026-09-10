# R12 V01/V03/V04 — Windows crash preview projection

Document class: EXECUTION_EVIDENCE. Scope: 2026-09-10, owned Windows VM,
client source e18fa6073d310623fae003689af439fb11d4dc5e and Core
c8b0461c1975ef96e32024774300a5829b9fdc43. Full release remains open.

## Observed gap and implementation

The deployed Windows processes already wrote bounded crash records, but the
support presenter only received crash test fixtures; previous/current app crash
marker facts were not passed to its real snapshot. The client now passes these
closed marker facts and, under a live signed PSM policy permitting crash_index,
reads at most two UI and two service records through the Windows host.

The native reader accepts only its fixed 2048-byte, 32-frame schema. It projects
UTC timestamp, catalog CRASH-001/CRASH-003, and SHA-256 of process, exception and
allowlisted module-relative frames; timestamp is excluded from the signature.
Raw frames never cross the service IPC or Flutter channel. Service files keep
their SYSTEM/admin ACL. Diagnostic capability negotiation and authenticated IPC
remain mandatory. Diagnostic disk/IPC work uses a separate instance of the
existing bounded worker; it neither takes the runtime mutation lock nor queues
behind connection commands. The diagnostic exchange has a three-second response
budget, and the Dart collection has a twelve-second overall wait limit.

Missing files produce an empty success. Invalid, unreadable or unavailable native
state produces a visibly incomplete extended preview: new upload/export is
disabled, refresh and disabling PSM for an ordinary summary remain available,
and saved encrypted report retry remains separate. Mode changes/expiry discard
in-flight native data and reset the visible preview. Source owner is updated in
docs/product/client-product-contract.md. No new dependency or raw data sink.

## Source and checks

- Integration commit c8c86aa20968b6c886da8fce7ca0325018e3df0e: 21 scoped files.
  Clean base 840e1c5; local cherry-pick 0158aa7; signed PR109 source e18fa60,
  tree d25c88eb55bc4687e896f44e6a28b9409619ff84, merge503979f. Six package trees
  and Windows runner/service trees match the tested integration source exactly.
- `flutter test test/client_observability_test.dart test/support_mode_controller_test.dart test/client_diagnostics_test.dart`
  — 25 PASS. Active/denied/expired policy read boundary, native malformed-data
  rejection, marker restart retention, incomplete-report upload/export disabled.
- `flutter test test/pokrov_seed_app_test.dart` — 191 PASS, distinct from the 25.
- app_shell analyze and observability_runtime phase tests/analyze — PASS.
- CMake Debug build of pokrov_windows_crash_profile_test,
  pokrov_service_client_test, pokrov_service_cancellation_test — PASS.
  Corresponding `ctest -C Debug --output-on-failure` — 3/3 PASS. Authenticated
  service test reads a real closed file while Connect is pending, rejects a
  corrupt canary file, and enforces diagnostic capability without changing the
  pending VPN state. These are isolated native tests, not installed-crash proof.
- `scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot C:/r12coreprivacy`
  and `test/docs-contract.ps1` — PASS. git diff --check PASS; no release artifact
  delta. Existing four generated-registrant status entries have no content delta
  and were preserved. No phone or subagent was used.
- Clean exact-source Windows bootstrap, Core sync and reproducible package build
  — PASS. Setup 29268204 bytes, SHA-256
  dfbe69491fc2a3c811be68995867bb303e3d08100a42a360910f5fa019eb1306.
  304 payload files: only UI, service and app.so differ from installed c3e70ad;
  301 files, including Core, are unchanged.
- PR Release v2 Contract run34526966174 PASS. Merge run34528129188 PASS for exact503979f; no gates were weakened.

## Installed proof

The ordinary Inno wizard installed the exact package. All 304 payload hashes
match before first launch and after runtime checks; session and secure-store
bytes survived the upgrade. This setup remains unsigned. There was no public
release, backend/Core deployment or phone operation.

In the disconnected owned Windows11 VM, the test harness verified each target
process path/hash and caused a real access violation (`c0000005`) in the installed
UI and LocalSystem service. Synthetic credential/URL/IP/path markers were placed
in that process's allocated memory; no raw memory was exported. Both native
filters wrote current closed records (92/97 bytes), without those markers.
These faults had zero allowlisted frames: native nonempty-stack capture is not
claimed; formatter/hash/frame limits also have separate native unit coverage.

The ordinary summary preview excluded crashes. A fresh audited L2 PSM1 issue for
the owned case52 permitted crash_index for Windows build4053, 15 minutes and two
bundles. The code was passed directly from root-only server storage to the guest
keyboard without clipboard, host input or secret files/screenshots. The visible
consent preceded activation. Before collection, a deliberately malformed UI
record was substituted after preserving its exact protected original. Refresh
showed an incomplete report with upload/export disabled. Restoring the original
hash and refreshing produced five files, including the crash category. The
protected backup and original records are retained.

One actual UI submission created case57 and reached `validated` on Brain25c6f7a:
3617 encrypted bytes, 2344 plaintext bytes, five files. Normal audited admin
lookup by case/diagnostic ID and one-use content access passed. Missing step-up
and grant replay were denied, Cache-Control was no-store, and temporary fixture
sessions were revoked without changing preexisting sessions. Root worker-key
in-memory validation found zero planted markers across all five files. Both
CRASH-001/UI and CRASH-003/service signatures and timestamps match the actual
native records within one millisecond; no raw frames cross IPC or upload.
The first admin harness stopped on Python's parsing of seven-digit Windows
fractional seconds. Its FAIL receipt remains. The corrected harness normalizes
only that expected timestamp to microseconds and passes, preserving source data.

With PSM active, ordinary UI connect passed Core, DNS, effective-profile and
egress checks; ten HTTPS requests returned the owned marker. NIC deltas were
25088 bytes each direction with ambient traffic, not per-request attribution.
The first connected sample predates readiness and remains historical. Disabling
PSM through its banner kept VPN connected; ordinary disconnect then restored
exact route/DNS digests and zero active TUNs. Final readback confirms all304
payload hashes, both native original hashes and an empty encrypted outbox.
The status probe's `0218e89` identifies the separate test harness; installed
candidate identity comes from the exact304-file package inventory.

VM e42043a3-dd4d-452b-b151-410ad5d49543 is gracefully off with NIC none. All eleven
snapshots are retained, latest f2fc6f94-cebf-48e3-b2fa-76d5f9d3bb74. The previous
installed snapshot a991bc7e-b99c-4466-8f0e-49661499ae7a remains rollback material.
Case57, access audits, native records and old packages remain intact.

## Commands and boundaries

`build-windows.ps1`, `prepare-package.py`, `verify-ci.py`, the ordinary wizard
and `verify-wizard.ps1` prove the scoped source/package/install chain. The build
skips duplicate analyze/tests/seed internally because equivalent-source checks
above already passed. `crash-owned-process.ps1 -Role ui/service`,
`read-native-crashes.ps1`, `corrupt-crash-input.ps1 -Action inject/restore`,
the UI consent/submission, `read-case.py 57` and `admin-scan-v2.py 57` prove the
installed crash path. Network/traffic/final readback and runtime-verification
captures prove recovery. [Receipt](receipt.json) records exact retained captures
and local scripts, screenshots and logs with SHA-256; original encodings and
failed harness outputs remain locally. Screenshots were inspected directly.

This is PASS_BOUNDED_INSTALLED_WINDOWS_CRASH_SUPPORT, not full V01/V03/V04 or
public release acceptance. Android, other origin/device/sink requirements,
nonempty native stack observations, parent dependencies, final signing and
public packaging remain open. Source is merged in main; these evidence records
are a local documentation commit. No further product code changed after e18fa60.

## Final documentation checks

`scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot C:/r12coreprivacy`
and `test/docs-contract.ps1` PASS. Platform `python -B -m pytest -p no:cacheprovider tests/test_agent_docs_contract.py tests/test_agent_context_packet_audit.py -q`
passes33 tests; `scripts/agent_context_packet_audit.py --platform-context-root .`
PASS, work-order710 local links PASS. Both repositories pass `git diff --check`;
retained release artifact delta is empty. Receipt captures and original local
inputs were rehashed successfully. Source/evidence boundaries are unchanged.
