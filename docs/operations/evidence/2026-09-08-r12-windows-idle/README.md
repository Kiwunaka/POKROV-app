# Windows idle CPU and memory after status notification fix

**PASS_BOUNDED**, client `e88dff94bef85650c5f0b3d31dc3ff9a5e39c38a`,
Core `02a091cb0e369192a5ad0909b56ccba8aa1dce17`, current-origin owned
Windows 11 VM. [Receipt](receipt.json) binds 305 installed package hashes,
the raw samples, canonical gate outputs and 41 retained local artifacts.
This unsigned package is a local test build, not a published release candidate.

The two-second Windows observer notified the shell and tray on every poll,
even when all runtime state was unchanged. The regression observed 60 redundant
notifications in two minutes. The fix compares all 35 public snapshot fields,
including source origin/revision, and skips only identical state. Health,
profile, phase and service-loss changes still notify; polling and reply fencing
remain active. The regression now observes zero unchanged notifications and
still covers protection loss, recovery and a late reply across disconnect.

| Exact local build | UI CPU p95 | Service CPU p95 | Combined CPU p95 | Combined working set p95 |
| --- | ---: | ---: | ---: | ---: |
| Before: `68a44e5` | 1.498057% | 0% | **1.498296% — FAIL** | 117,440,512 B |
| After: `e88dff9` | 0.748937% | 0.749664% | **0.749983% — PASS** | 120,459,264 B |

The separate process percentiles are not additive. The before service p95 of
zero comes from readable, sometimes unchanged cumulative counters; unavailable
counters invalidate a run. Every one of the 90 interval deltas was recomputed.
Native UI CPU readback matched WMI exactly at all retained observations.

Both runs used the same boot of the two-vCPU, 4-GiB Windows 11 VM, Balanced
power, no network adapter or tunnel, a foreground disconnected UI and the
LocalSystem service. Each discarded 30 warmup intervals and retained 60,
with nominal one-second sleeps. Retained elapsed times were 62.5838301 and
62.6141668 seconds. CPU is normalized by logical processor count; p95 uses
nearest rank. The canonical 1% stop and target both pass after the fix.
The memory fingerprint matches the before baseline: growth is **2.570452%**,
so the canonical <=10% comparison passes. This is no absolute RAM budget or
general performance claim for other devices/states.

The installer changed only `data/app.so`. Normal wizard/UAC upgrade preserved
saved-state bytes and verified all 305 installed files; no reboot was required.
Ordinary owner IPC was trusted and accepted. Restart Manager reopened the old
UI, causing the first collector attempt to refuse sampling; that attempt is
retained separately. After closing that exact UI process, the measured run
completed normally. Final readback verified all 305 hashes, UI count zero and
the service Running. The test VM is now off with NIC none; the source VM stayed
off; host routes/DNS hashes are unchanged. No backend setting changed.

Validation: shell 188 PASS; runtime 81 PASS and one opt-in skip; Windows Flutter
24 PASS; analyze no issues; explicit-root seed validation PASS; local release
build/package PASS. Logs and exact collector hashes are in the receipt.

Useful cold start remains open. The historical candidate.33 collector accepted
a responsive window with a visible UIA Pane; it did not establish useful
Protection controls. Current direct and interactive UIA inspection also exposed
only a Pane. Historical samples are preserved, but their 1499.404 ms result
does not receive semantic useful-start credit. Warm/cold/post-reboot
distributions, Windows 10, physical/comparable hardware, connected/tray-hidden
states and final-channel acceptance remain open. Full R12-W05 is not complete.
