# Windows IPC cancellation — 2026-09-08

Source after `dab70de`: IPC Connect previously occupied the only service
dispatcher and the Flutter window thread. Cancellation had no handler, and
WinHTTP could wait through all retries before observing interruption.

The service now admits up to eight sessions, serves cached fail-closed status
and correlated cancellation during Connect, and rejects competing mutations
with `runtime_busy`. Cancellation matches the active session token and operation
nonce, preserves replay/deadline checks, and cannot reach a later generation.
An accepted cancellation racing final commit still triggers serial rollback.
Only one dispatcher execution accesses RuntimeHost or mutates network state.

WinHTTP uses cancellable asynchronous requests with callback lifetime retained
until handle closure. The UI uses one bounded worker queue and completes
Flutter results on the window thread. Replacement connect, profile changes
and disconnect signal the preceding connect. Window teardown requests cancel
and abandons response waiting. Matching UI/service bytes are required because
both now negotiate Cancellation capability; frame version remains 1.

Validation: 12 native Debug suites PASS; Windows Flutter 24 PASS; runtime
Flutter 80 PASS with one existing exact-DLL case SKIPPED; Windows analyze,
Release UI/service build and seed/docs PASS. The first shell run failed an
assertion about the old internal counter name. That assertion was removed;
the native integration and concurrency behavior checks remain.

In the NIC-free Windows 11 VM, 11 component fixtures passed initially.
Integration could not launch its sibling test service because that EXE was
omitted from the copied payload; supplying it made the same integration test
pass. Both results are retained. Correlated cancellation and fake network
rollback took 31 ms; pending loopback HTTP headers cancelled in 94 ms and the
peer observed socket closure. All 305 installed hashes remained unchanged;
no test processes remained, and the VM was returned to poweroff.

[Receipt, source hashes and commands](receipt.json). Debug tests use synthetic
Core/recovery and loopback HTTP; they do not prove an installed live TUN,
production TLS origin, WFP coexistence, Win10 or final candidate acceptance.
Core Start/Stop and recovery calls still must return before cooperative
interruption can proceed. No Core artifact, installed package, host VPN,
release artifact, push, merge, deployment or publication changed.

Rollback: revert the scoped source commit and package the matching UI/service
pair. Historical source, failed logs and the installed VM baseline are retained.
