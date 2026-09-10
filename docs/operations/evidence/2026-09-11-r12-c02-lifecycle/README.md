# C02 lifecycle ownership — 2026-09-11

Core 904e440 closes the discarded service owner and its five observers, keeps
command-server stop/reload restartable, and synchronizes monitoring shutdown.
The original 12-cycle source regression grew from 37 to 95 goroutines. The
fixed Windows race run retained 199 handles and 38 to 40 goroutines. This
test uses GOMAXPROCS=2 to isolate service ownership from runtime thread pools.

[Binding](binding.json), [Android](android-evidence.json),
[Windows](windows-evidence.json) and [previous pin](previous-runtime-binding.json)
retain exact identities. All five files in two builds match. Dependency graphs
and their [existing SBOMs](../2026-09-10-r12-core-privacy-binding/README.md) are
unchanged. No dependency or license-clearance claim was added.

The exact DLL's first [100-cycle sample](artifact-lifecycle.json) failed the
strict final-window handle assertion: 343 to 427 handles, 419..427 in the last
20 cycles. All 200 loopback sessions still closed. The diagnostic
[300-cycle sample](artifact-lifecycle-v2.json) retained handle types: all 600
sessions closed, file handles stayed at 22, growth was in threads/events and
timers, and the final 20 cycles plus one-second settle stayed at 438 handles.
This is PASS_BOUNDED for that finite run with default Go scheduling, not an
unbounded stability or physical VPN claim. Original failed logs are retained.

The full Core suite and supported Windows/mobile-bridge race tests pass.
Exact Linux race/fuzz/backpressure CI, consumer checks and coordinated
promotion will be appended after completion. Source/build scripts and full
original logs remain in C:/r12-c02-20260911. No device, tag or public release.

Consumer checks: 81 ordinary runtime tests and 8 Android Flutter tests PASS.
The existing isolated helper passed 100 cycles of the exact DLL through Dart.
Seed with explicit platform/Core roots and docs contract PASS. An initial
combined opt-in run used stale shared TEMP and was stopped on database retries;
its local log remains separate. Core initial test, Android/Windows two-build
and Apple build jobs passed; release-contract still requires the new client
pin. [Consumer receipt](consumer-checks.json) retains commands/results limits.
