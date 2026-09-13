# R12 C04 Windows native lifecycle evidence

Registry class: `EVIDENCE`. Captured2026-09-13 on client1ecc09b/Core0138,
Flutter3.38.5, Windows11 VM build26200. [Exact results](acceptance.json).

**FAIL_NATIVE_HIDDEN_ANIMATION**: three independent profile captures show
native hidden visibility=false, TickerMode=true and changing production modal
opacity; lifecycle remains null. The final fixture acquires real foreground
focus through a test-only Win32 input-queue attachment; hide/show still fails
to update lifecycle. blur() does not produce inactive and remains unverified.
No product source change, release acceptance, CPU/battery or frame claim.

All three guest fixtures match304 files; installed304 hashes are unchanged.
UI0/service Running/Wintun0, VM off/NICnone/snapshots13, host routes/DNS match.
The third watcher shutdown observation error is retained with a separate final
readback; no uninterrupted final-interval polling claim. Startup protocol
command/icon values were restored to the installed target, retaining fixture
values privately; no pre-first-run registry equality claim.

Raw collectors, traces and bundle hashes are retained in the platform work
order `evidence/c04-lifecycle-20260913/evidence.zip`. C04 remains active/I3;
diagnose the Windows lifecycle boundary before further acceptance. Physical
Android, runtime-tick and traffic-rate criteria remain open.
