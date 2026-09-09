# New AWG Core installed on Windows — 2026-09-08

**PASS_BOUNDED** for client `295ceace0b8dfbe9af5cfc9c3fa06eda45ce5747`
and Core `02a091cb0e369192a5ad0909b56ccba8aa1dce17` in the owned Win11 VM.
The [receipt](receipt.json) binds the installed bytes and 42 retained artifacts.
This advances installed Windows proof after the A03 validator correction.
The earlier package and VM snapshot remain available for rollback.

The unsigned local installer `ef4bc953…70cfa` upgraded the existing lab to
the new DLL `0409da47…d0371`. All 305 installed files matched the new package;
saved client state was unchanged, no restart was required, and the service
remained automatic LocalSystem. Non-elevated owner IPC passed. This owner is
the filtered lab administrator; separate standard-account proof belongs to
the earlier installer evidence and is not transferred to these new bytes.

Ordinary UI reconnects AWG3.1 → AWG2 → AWG3.1 produced three running service
observations with Core/DNS/egress readiness, staged/effective identity match,
one TUN, health HTTP 200 and successful DNS. An elevated read-only sampler
recorded protected profile hashes and field names without exporting secrets.
The first and last profile hashes match exactly; AWG2 differs. Its identity
combines the guarded server assignment and endpoint shape because its existing
renderer omits `contract_id`. The unchanged IPC probe's `0218e89` label is its
own source identity, not the current packaged UI or Core.

All three disconnects removed TUN and restored the exact baseline route/DNS
hashes. The final 305 package hashes match. Full original rollout configuration
was restored; endpoint material and entitlement were not changed. Sampler count
is zero. The clone is powered off with NIC none; the source VM is still off.
Host route/DNS hashes match their pre-test values.

Commands and outputs are retained under `E:/r12-windows-awg-crossfield-20260908`:
`build.ps1` runs Flutter Windows release build with the actual API origin;
`package.ps1` uses the canonical packager with only a separate local output root.
Windows Flutter tests (24), analyze, build and package passed. The VM used the
normal installer wizard/UAC, `lab-control.py switch` for the three assignments,
UI connect/disconnect, `network.ps1`, `read-profile.ps1`, `final-identity.ps1`,
and `lab-control.py restore`. `retain-evidence.py` validates the retained results.
The first live NIC enable from an absent adapter required a powered-off
configuration change; only the subsequent boot supplied network evidence.

Final client `validate-seed.ps1` with explicit platform/Core roots passed.
Platform documentation tests: 33 PASS; context audit and package validation
(83 R12 IDs, 303 links) PASS. The receipt also hashes these four check logs.

Independent route proof remains open: the external egress hash is identical
with and without TUN. The previously unverified DE SSH key change is unresolved;
no trust bypass or server-counter read was performed. The UI retains saved
Milan and unresolved access status under the fixed DE lab transport. These
observations do not close effective-location, whole-path MTU, physical Android
on the new bytes, Win10, crash/sleep, WFP, IPv6 or final channel acceptance.
No push, merge, tag, signing, publication, release candidate or deployment.
