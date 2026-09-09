# Windows upgrade shutdown and installed cancellation — 2026-09-08

The old UI intercepted installer shutdown as close-to-tray and held files open.
The v2 upgrade only completed after a manual `WM_QUIT`; its package identity
receipt explicitly records `automatic_ui_shutdown_pass=false`. The UI now
accepts `WM_QUERYENDSESSION` and destroys its native window only for a confirmed
`WM_ENDSESSION`. A cancelled session end and ordinary close-to-tray preserve
the running process. The installer deletes the exact obsolete
`pokrov_activation_protocol_test.exe` left by older packages.

The patched v3 package passed install and repeated upgrade in the isolated
Windows 11 clone: Restart Manager shut down the old UI automatically, all 305
package hashes matched, authenticated IPC ran under the ordinary account, SCM
ran as LocalSystem, and saved app state stayed unchanged. Query/cancel/tray
checks passed. This is parent `0218e89` plus recorded source-file hashes, not a
package built solely from that parent commit. [Receipt and hashes](receipt.json).

Windows Flutter 24 tests, analyze, Release build, local packaging, seed and
documentation contracts passed. The first seed invocation failed because its
default sibling Core directory did not exist; the explicit-root rerun passed.
Installer v2/v3 raw logs remain under `E:/r12-windows-managed-20260908/` with
hashes in the receipt. The initial failure is retained, not counted as a pass.

An earlier automated installer launch triggered Defender
`Behavior:Win32/SuspClickFix.G2`. The later interactive installation completed;
the final readback had zero current detections with realtime/behavior protection
enabled and signature `1.459.101.0` (initially `1.459.28.0`). Detection history is
retained. The cause is unresolved; this is not a false-positive determination
or broad antivirus compatibility PASS.

With the installed matching UI/service and an existing exact-install AWG31 lab
profile, two service observations reported running, Core/DNS/egress readiness
and matching staged/effective identity. One TUN existed; health and DNS queries
succeeded. External egress hashes were identical before, during and after the
connection, so that observation does not independently distinguish tunnel
egress from the underlying network. This is bounded runtime evidence, not full
route/privacy or independent-origin acceptance.

Disconnect completed in 625 ms. A subsequent connect received cancellation
after 150 ms and returned `operation_cancelled` in 2110 ms with no running or
effective protection. TUN count returned to zero and both route and DNS hashes
matched the original guest baseline after disconnect and cancellation. This
single measurement is not a general cancellation latency bound; blocking Core
operations still require cooperative return. Full transport switching,
sleep/crash/connected-update, WFP coexistence, Win10 and final-channel gates
remain OPEN.

The temporary server cohort and expiry were restored: the complete rollout
configuration hash matches its original value; key material and entitlement
were unchanged. Host routes/DNS also match the initial hashes. The disposable
clone is retained, powered off, with NIC disabled; its lab package and temporary
IPC probe are retained for evidence. The original VM and release artifacts were
not replaced. Guest control returned nonzero during shutdown; subsequent VBox
readback independently confirmed poweroff. No push, merge, deployment,
publication or new release candidate occurred.

Rollback: revert the scoped source change and retain matching UI/service
packaging. The exact pre-fix packages, failed upgrade receipt and isolated clone
remain available; server rollback is already complete.
