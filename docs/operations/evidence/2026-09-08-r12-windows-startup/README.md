# Windows useful Protection startup

**PASS_BOUNDED**, local client `e88dff94bef85650c5f0b3d31dc3ff9a5e39c38a`,
Core `02a091cb0e369192a5ad0909b56ccba8aa1dce17`, installed unsigned setup
`29a87a13906909e400037a947f1e4f876ca59821e7e34c73060e623f2d9fbeea`.
[Receipt](receipt.json) binds raw samples, collector sources, canonical gate
outputs and the expected 305-file bundle. No application code or package changed.

| Scenario | Discarded / retained | Useful UI p95 | Maximum retained | 3500 ms stop | 2000 ms target |
| --- | ---: | ---: | ---: | --- | --- |
| Fresh process, warm OS/file cache | 3 / 20 | 765.5534 ms | 818.7529 ms | PASS | Met |
| First UI process after guest power-on/login | 3 / 20 | 2311.4823 ms | 2628.5073 ms | PASS | **Not met** |

The second series performs 23 complete guest shutdown/power-on/login cycles,
discards the first three and retains twenty. Each sample has a distinct actual
Windows boot timestamp, an observed logged-out state, a guarded ordinary-owner
login, no application autorun and no existing UI process. The collector starts
two seconds after the login guard. The process-launch timer excludes OS boot,
login and automatic service startup; the service is already Running. This is
a VM post-boot distribution, not a physical disk-cache or power-cold baseline.

The terminal requires enabled, visible `Подключить` and protection-status
buttons plus `Защита` navigation, positive control rectangles, no onboarding
semantics and no accessibility errors. The collector activates MSAA through
`OBJID_CLIENT` on the exact `FLUTTERVIEW` child window, walks a bounded tree and
retains only allowlisted product labels. The identified status control was
separately clicked and opened Protection details; the screenshot is retained.
Responsive window appearance is recorded separately and never used as the
useful terminal. No tunnel is started by measurement.

Elapsed time uses Stopwatch from `Start-Process` through that terminal, including
MSAA activation and inspection overhead, with nominal 25 ms polling. It is an
observed upper bound on useful semantic readiness, not a pixel-render timestamp.
All 46 terminals and sample classifications were independently checked before
the nearest-rank canonical calculation. Warm and post-boot scenarios have
different environment fingerprints and are not a regression comparison.
The historical candidate.33 Pane-only method remains withdrawn for useful-start
credit; no old evidence was overwritten or used as a baseline.

Both runs use the owned Windows 11 Enterprise Evaluation VM, build 26200,
2 vCPU, 4274917376 bytes RAM, Balanced power, release-mode Flutter 3.38.5,
PowerShell 5.1.26100.9168, no NIC/tunnel and an ordinary non-admin collector.
Expected installed hashes were checked before the warm batch and **after**
each post-boot sample to avoid warming application files before that sample.
Final readback again verified all 305 files, UI count zero and automatic
LocalSystem service Running. Test VM off/NIC none, source VM off and unchanged
host route/DNS fingerprints are retained. Backend settings were not changed.

The early PowerShell COM walkers failed before measurement; their diagnostic
receipts remain separate. The first normalizer also refused differently
serialized but equal UTC timestamps (`.5000000Z` versus `.5Z`); comparing parsed
instants passed all 23 distinct boots without altering raw samples. Transient
VirtualBox console read failures during shutdown did not satisfy the power-off
guard; the next successful state read was required before each power-on.

The completed `python -B E:/r12-windows-startup-20260908/normalize.py` invocation
validated every sample and produced both canonical results. It refuses to
overwrite retained outputs. `performance_budget_gate.py --evidence` can
revalidate either retained evidence JSON independently. No thresholds changed.

Full R12-W05 remains open for Windows 10, physical/comparable hardware,
physical cold-cache conditions, connected/tray-hidden performance and the
final release channel. This test build is not a newly published candidate.
