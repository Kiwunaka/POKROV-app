# Windows SCM and Core initialization — 2026-09-07

`PASS_COMPONENT_ONLY` on the owned offline Win11 clone. [Receipt](receipt.json)
binds client `40e005e`, bundle source `98c39d6`, Core `8dc57a8` and exact DLL/EXE
hashes. This is a component install under Program Files, real LocalSystem SCM,
and production IPC client code in a dedicated probe. It does not use a synthetic
Core or service backend. No profile, connection, TUN or network was requested.

The limited probe rejects an elevated process token. It verifies owner binding,
rejects an attempted write to the protected installation directory, sends
Status → Initialize → Status, and returns 0 only if initialization is accepted,
Core is ready and no connection is possible without a profile. Service start,
initialization and clean stop have successful timestamp-filtered journal events.
The final service is stopped/manual; service processes, up adapters and POKROV
adapters are all zero. This uses the filtered token of the existing administrator
account, so it is not a separate non-admin-account installer acceptance.

Two earlier fixture/collector failures are retained. The first fixture
registered a forward-slash SCM path, unlike the stock installer, and IPC rejected
its identity. The second corrected the path, passed IPC, but wrongly required
Core to be initialized before sending Initialize. The third performs the actual
initialization sequence. No application code was changed for these corrections.
The original summary's untyped event parsing also treated Core timestamps as
service event names; the independent final collector filters both schema and
v3 start time and retains 25 service events plus two Core initialization events.

Commands: CMake configure/build of the retained probe sources with Visual Studio
17 2022 x64, Release, `/W4 /WX`; clone-pinned `scm-smoke-v3.ps1` with guest UAC;
non-elevated `limited-probe-v3.ps1`; schema-aware `collect-final.ps1`.
Exact scripts, sources, build logs, raw rejected/successful receipts and hashes
are indexed in the receipt. The guest-only collection uses existing local lab
credentials without printing them.

After completion Windows evaluation licensing (`wlms.exe`, System event 1074)
shut the VM down at 19:36:19Z. The clone was restarted; the journal and stopped
manual service survived. This is not connected reboot/recovery evidence and
limits long-running tests on this evaluation image. The original VM is unchanged.
Fixture files, owner binding and private service database remain for inspection.

Open: packaged standard-account UI + SCM, real managed transport/TUN/DNS/IPv6/
routes, crash/sleep/handoff, Windows 10 and exact install/update/uninstall channel.
No push, merge, production mutation or retained-release-artifact change.

Validation: client seed/docs PASS; platform docs 33 PASS; context audit PASS;
package imports/83 R12/378 legacy/278 links PASS; diff check PASS. Retained
release artifacts have no delta. Validation logs are bound in the receipt.
