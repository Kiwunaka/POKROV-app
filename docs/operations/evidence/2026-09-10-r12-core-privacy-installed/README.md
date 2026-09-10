# Installed Core privacy fix — 2026-09-10

`PASS_BOUNDED_INSTALLED_CORE_PRIVACY`. [Receipt](receipt.json) indexes 32 exact
captures and local runner/log hashes. This closes the reproduced direct-FFI
leak for the tested Windows path; full V01 and public release remain open.

## Source and coordination

Client source `d655e2a9a58cb3c833f97a327b4342cdb02edf60`, Core source
`c8b0461c1975ef96e32024774300a5829b9fdc43`. [Client PR105](https://github.com/Kiwunaka/POKROV-app/pull/105)
merged as `1acbb7509f25ce1b8fc92c8467effc33bd133122`; [Core PR10](https://github.com/Kiwunaka/pokrov-core/pull/10)
merged as `5ff9cca549d728b74bc65c44a3475ed0626945b4`. Both merge signatures
verify; both trees equal the checked source trees. The client binds the exact
Core source and Android/Windows hashes; dependencies and ABI are unchanged.

All four PR/merge workflows pass for those exact revisions. Core release-contract
first failed against the previous client/main binding; the first client merge
run failed against previous Core/main. Original failures are retained. Client
PR105 checked its exact Core SHA using the existing coordinated-PR pattern;
ordinary main checks remained strict. After both merges, failed checks were
rerun with the converged sources. No gate was skipped or weakened.

## Package and installed proof

The normal Inno wizard installed version `1.2.0+4053` in the owned Windows 11
VM. Setup SHA-256: `13743b54a79e205f53c340e59838c29821aa724bb76c1a0231788e4e7e58cd8d`.
All 304 files match the package before/after runtime; only `data/app.so`,
`pokrov-core.dll` and native Go notice source references differ from installed
`2edfbde`. User state and secure storage survived installation byte for byte.
The installer remains unsigned; this is not trusted-signing acceptance.

The original c7 DLL exposed six planted markers in FFI return and stderr with
debug disabled. The fixed component and package checks pass. A separate
PowerShell/C# subprocess called the actual installed DLL with the same rejected
synthetic profile: no credential/config/URL/IP/path/PII markers in return,
stdout or stderr; closed `CORE-005` is retained. Raw streams remained in memory;
only counts, hashes and booleans were exported. The fixture uses a separate
working directory and never changes the service's real profile.

Ordinary UI connect/disconnect passes Core/DNS/egress checks. Ten HTTPS requests
return the owned authenticated-egress marker. NIC counters grow by 24877 bytes
each direction with ambient guest traffic; this is not per-request route proof.
Default/current routes and DNS digests restore, active TUN count returns to zero,
and 44 app events carry exact source/build identity. The initial summary harness
compared string build number `4053` with an integer; corrected verification and
the failed harness result are both retained. No product change was needed.

VM is off with NIC `none`. Five original snapshots plus the two new before/after
snapshots are retained. Current account state, old packages and diagnostic
evidence are preserved. The host network and phone were not touched.

## Checks and limits

Previously retained source checks: Core `scripts/test.ps1`, two Android/Windows
builds each, 100 DLL proxy cycles; 81 runtime and 8 Android Flutter tests,
runtime analyze, seed/docs and the focused CI contract check. New package:
`build-client-windows.ps1` passes; analyze/tests/seed were explicitly skipped
inside that build because the source-equivalent checks already passed. The
four exact hosted workflows additionally ran their required suites.

`ffi-run.ps1`, `verify-wizard.ps1`, `network-v2.ps1`, `tunnel-traffic.ps1`,
`timeline.ps1` and `verify-runtime.py` pass in the scope above. Full V01 is still
open for native extended/crash, Android, other sinks and N03. The installed
client includes the earlier extended-preview fix, but runtime PSM1 signer and
extended authorization remain unconfigured. Summary uploads/admin checks from
the previous candidate are historical and were not repeated or relabeled here.
No platform deploy, source publication, tag or public client release occurred.

Final documentation checks: `scripts/validate-seed.ps1` with the exact Core
source, `test/docs-contract.ps1` and `git diff --check` pass; retained release
artifact diff is empty. Platform documentation: 33 tests, context audit and
718 local links pass. Final log hashes are recorded in the receipt.
