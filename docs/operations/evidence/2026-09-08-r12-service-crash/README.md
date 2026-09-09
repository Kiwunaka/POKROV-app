# Windows service crash: UI state correction

**PASS_BOUNDED**, current-origin Windows 11 VM, client
`68a44e5327fdaaa42adbf1bbe9218ad755b051ff`, Core
`02a091cb0e369192a5ad0909b56ccba8aa1dce17`.
[Receipt](receipt.json) binds the local installer, all 305 package hashes and
42 retained evidence files. This is a local unsigned lab package, not a release
candidate or final-channel acceptance.

The earlier installed package retained **Connected** after forced termination
of the exact guarded POKROVService PID. SCM restarted the service and its durable
recovery removed the TUN, but the open UI did not observe the change. The failed
widget regression and the installed failure screenshot are retained.

The shell now samples local Windows status every two seconds. It permits one
background status call at a time and discards a late reply after a newer snapshot
or runtime action. An unavailable observer clears old protection proof. Polling
does not fetch a managed profile or run network probes and stops on disposal.
The regression covers a long connected session, service loss, reconnect, a held
reply crossing explicit disconnect, coalescing and disposal.

Installer `3e23609dc6866def56d38630142f264d399c9d64458aec593aa0818055b80352`
upgraded the existing isolated VM through the ordinary wizard and UAC. All 305
installed files matched; account-state bytes were preserved; reboot was not
required. SCM was Auto/LocalSystem and non-elevated owner IPC was accepted.
Only `data/app.so` changed from the preceding package. The native runner,
service and Core hashes are unchanged; runner EXE identity alone cannot prove
the new Dart implementation.

Ordinary UI connect produced one TUN with running/Core/DNS/egress readiness and
matching staged/effective identity. Forced service termination exited the old
PID; SCM returned with a new PID and a clean recovery journal at the first
matching sample, **15,588 ms**. The UI process survived, removed the Connected
claim and exposed Retry. Ordinary Retry connected successfully. Routes and DNS
matched the original baseline both after the crash and after final disconnect.
All 305 installed package hashes still matched at the end.

UI state was observed in retained screenshots, not continuously timestamped.
This does not establish a two-second end-to-end clearing SLA or a separate
tray-hidden crash result. Core is embedded in the service; this service-process
termination is not independent injected Core-panic proof.

Validation from `E:/r12client`:

- `flutter analyze --no-pub`: PASS, no issues.
- In `packages/app_shell`, `flutter test --no-pub test/pokrov_seed_app_test.dart --reporter expanded`: 188 PASS.
- In the same package, `flutter test test/connection_experience_test.dart --reporter expanded`: 14 PASS.
- In `apps/windows_shell`, `flutter test --no-pub --reporter expanded`: 24 PASS.
- `scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation`: PASS.
- `E:/r12-windows-service-crash-20260908/build.ps1` and `package.ps1`: PASS, separate local output root.
- `E:/r12-windows-service-crash-20260908/retain-evidence.py`: PASS, 305 hashes and recovery/cleanup assertions.
- `git diff --check`: PASS; `artifacts/releases/**` unchanged.

Two earlier test commands named nonexistent test files and failed. Their logs
are retained alongside the corrected passing commands. The graceful shutdown
wrapper returned exit 1 as the guest disappeared; subsequent VirtualBox
readback proved poweroff. Neither result is silently converted into a tool pass.

The complete original backend test configuration was restored, without material
or entitlement mutation. VM `e42043a3-dd4d-452b-b151-410ad5d49543` is off with
NIC none; the source VM remains off. Host route/DNS hashes are unchanged.
Previous package, pre-upgrade snapshot and both failed/passing evidence remain.

W01/W02 parents remain open for Win10, final-channel bytes, sleep, physical
network handoff, independent route and other applicable cases. WFP/IPv6 and
the saved Milan/access-status presentation are not closed by this test. The
external IP was unchanged through the host/proxy topology; no independent DE
counter proof or SSH trust bypass occurred. No push, merge, tag, signing,
publication or deploy was performed.
