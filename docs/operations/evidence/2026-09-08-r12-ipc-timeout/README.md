# Bounded Windows pipe I/O and SCM stop — 2026-09-08

A client that sent one header byte, or sent hello without reading its response,
could monopolize the installed service's single pipe indefinitely. Both native
regression cases failed before the fix. The real ordinary-owner VM probe also
failed to acquire a second connection in 5000/5016 ms; releasing the first
handle restored access. While hello remained unread, SCM stop did not complete
within 5248 ms. [Exact evidence](receipt.json).

`service_server.cpp` now gives each frame a three-second monotonic transfer
budget shared by header and body. Timeout/SCM stop cancels and drains pending
overlapped I/O before releasing its structures. Session teardown no longer
calls blocking `FlushFileBuffers`. An incompatible hello has a bounded read
window in which its peer can consume the rejection and close; no subsequent
command is executed. The serial runtime owner, frame/capability protocol,
caller checks and profile identity remain unchanged.

Windows documents that a server-side [pipe flush waits for peer consumption](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-flushfilebuffers).
[Cancellation requires completion](https://learn.microsoft.com/en-us/windows/win32/api/ioapiset/nf-ioapiset-cancelioex)
before the overlapped structure can be freed.

The Debug IPC test mode also omits the installed runtime root and recovery
backend. This prevents the regression fixture from opening the host recovery
journal. The retained red test includes that isolation guard and the original
unbounded I/O; the two failures concern pipe availability, not runtime setup.

In the owned offline Win11 clone, a guarded replacement of only the Release
service EXE changed the same two acquisition results to PASS in 3047/3000 ms.
SCM stop with an unread response completed in 10 ms. The probe ran as ordinary
R12Standard and bound the pipe to the SCM PID. The run had no profile, TUN or
network transaction. The original installed service was then restored: all
305 bundle hashes match, LocalSystem/automatic service runs, no probe process
or TUN remains. The original installer and both service binaries are retained.

Local validation: Debug native suite 8/8 PASS, runtime Flutter 80 PASS and one
existing exact-DLL backtest SKIPPED (its environment input is unset), runtime
analyze PASS, Release service build PASS. Core DLL bytes did not change. A first
VM collector's readiness marker was buffered until child exit; its FAIL remains
retained. The successful collector used a separate marker file.

This closes the observed stalled-session/SCM-stop defect for these bytes. It
does not implement cancellation of an executing Core/network transaction.
The parsed cancel/recover/diagnostic-state IDs currently return
`runtime_not_owned`; automatic startup recovery is separate. Correlated
cancellation, concurrent mutations, WFP/other-VPN coexistence, connected crash/
sleep/handoff, Win10 and the final candidate remain OPEN. No push, merge,
production deploy, release candidate or publication was performed.

The guest remains running offline with the restored original package. Future
installed acceptance must select the new source/package explicitly. Source,
binary and collector hashes, exact commands and documentation validation are
in the receipt; retained release artifacts are unchanged.
