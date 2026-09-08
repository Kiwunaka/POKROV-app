# Client Motion Performance Checklist

Last updated: 2026-09-08

Registry class: `ACTIVE_EXECUTION`.

Use this checklist for the `1.2.x` Android/Windows client after motion,
connection or observability changes. The platform-owned contract is
`shared/contracts/performance/performance-budgets.v1.json` in the sibling
platform repository; this document owns the client capture procedure only.

## Scope

- Android outside-store APK visual QA.
- Windows outside-store unsigned exact-candidate visual QA.
- Shared Flutter shell surfaces: Protection, Locations, Rules, Profile, Support chat, Rewards, WARP / enhanced privacy tile.

## Required Viewports

- Android narrow: `360` logical px wide.
- Android wide/tablet preview: `700` logical px wide.
- Windows compact: `700` and `900` px wide.
- Windows desktop: `1024`, `1180`, and `1440` px wide.

## Connect Ritual

- Press feedback scales the connect disc immediately and settles without layout shift.
- Busy sweep runs only while the connection phase is busy and the app is active;
  test environments use the finite pass unless looping motion is explicitly enabled.
- Connected state settles into `connect-disc-connected-settle`.
- Error/degraded state settles into `connect-disc-error-settle` with calm warning color.
- Reduced-motion mode keeps labels and state changes understandable without decorative movement.
- Connect disc animated region remains inside a `RepaintBoundary`.

## Shell Motion

- Losing focus (`inactive`), hiding or pausing the app mutes tickers across the
  navigator and modal routes; returning to `resumed` preserves visible state.
  Verify this on the reference Windows/Android host with an open modal as well
  as the connect screen. The local animation-value regression proves Flutter
  lifecycle behavior only, not host CPU or battery savings.

- Sidebar collapse changes width and label opacity without shifting page content unexpectedly.
- Rows and chips use tactile feedback only on real interactive controls.
- Skeletons match final content geometry and do not resize surrounding layout.
- Disabled WARP, rewards, wheel, and calendar states stay muted and do not look like active CTAs.

## Evidence Notes

- Record platform, build type, viewport width, and changed screen.
- Keep screenshots free of raw configs, subscription links, keys, hostnames, or hidden topology.
- If performance tooling is available, capture whether animation stays near 60 FPS during connect, sidebar collapse, support chat open, and rewards hub open.
- If a check requires a physical device, record it as `MANUAL_OWNER_TEST` rather than blocking local code review.

## Versioned capture protocol

Every retained run names the exact app version, candidate label, 40-character
client revision, artifact SHA-256, clean/dirty state, platform/OS/device/CPU
architecture, release/profile mode, power mode, network profile, collector
version and UTC capture time. Compare a regression only when the gate-produced
environment fingerprints match. Three warmups and 20 retained runs are the
minimum for cold start/connect/rollback; frame evidence discards 60 frames and
retains at least 600; idle evidence stabilizes for 30 samples and retains 60.

Capture these raw values:

- Android/Windows cold start: OS process launch to the first useful Protection
  frame. `adb am start -W` alone is not accepted because it cannot prove the
  useful POKROV frame.
- Connect/reconnect/disconnect: monotonic time from the user intent to the
  matching verified/rollback terminal event for the same generation. A green UI
  label without DNS and egress proof is not a terminal sample.
- Frame build/raster: Flutter profile-mode `FrameTiming` values while scrolling
  Locations, Rules and Profile and while exercising the connect ritual. Debug
  mode and six-frame `gfxinfo` samples are not release evidence.
- Windows idle: after stabilization, collect CPU or working-set samples from the
  exact UI/service processes with the client helper. Android idle CPU/PSS uses
  the selected physical-device profiler; record no domains, config or process
  command lines.
  Every CPU counter must be readable at every observation; an unavailable
  counter is an error, never zero. Use an appropriately privileged collector
  for LocalSystem services without changing the ordinary UI process identity.
- APK/installer size: collect the exact candidate byte length, then compare it
  with the prior same-kind artifact baseline.

The client helper writes numeric arrays only:

```powershell
pwsh -File .\scripts\collect-client-performance-samples.ps1 `
  -Mode WindowsIdleCpu -TargetProcessId <pid> -Warmups 30 -Samples 60 `
  -OutputPath <temporary-path>\windows-idle-cpu.json

pwsh -File .\scripts\collect-client-performance-samples.ps1 `
  -Mode ArtifactSize -ArtifactPath <exact-candidate> `
  -OutputPath <temporary-path>\artifact-size.json
```

For Android/profile-mode sources, first export a numeric JSON array from the
approved profiler, then use `-Mode RecordedSamples -InputPath ... -Samples ...`.
Normalize each array with the platform
`scripts/new_performance_evidence.py`; validate it with
`scripts/performance_budget_gate.py`. The builder never turns
`MANUAL_OWNER_TEST` or `BLOCKED_BY_ACCESS` into `PASS`.

## Current 1.2.0 evidence state

- capture contract, numeric client helper and its executable contract test:
  `PASS` locally;
- candidate.33 Windows UI idle CPU on the dedicated headless Windows 11 VM:
  `PASS`, p95 `1.0% <= 1.0%` from 60 retained one-second samples after 30
  discarded warmups; working-set p95 `98693120` bytes is
  `BASELINE_RECORDED`, not a regression PASS; normalized evidence:
  `docs/operations/evidence/candidate33-windows-idle-budget.json`;
- candidate.33 combined Windows UI plus automatic service idle on the same VM:
  CPU `INVALID_METHOD`, previous PASS withdrawn: the ordinary-user harness
  cast an unavailable LocalSystem CPU counter to zero. Its 60 retained CPU
  values cannot establish combined CPU usage. Working-set p95 `108158976` bytes is a new
  full-process `BASELINE_RECORDED`, not a comparison with the earlier UI-only
  baseline; normalized evidence:
  `docs/operations/evidence/candidate33-windows-combined-idle-budget.json`;
- candidate.33 combined Windows UI/service idle, fresh raw-WMI repeat:
  CPU `PASS`, p95 `0.751195% <= 1.0%`; 30 discarded warmups and 60 retained
  samples over `62.5179899` seconds. Both cumulative CPU counters are readable;
  all 90 deltas were independently recomputed and native UI counter readback
  matched. Working-set p95 `107057152` bytes is `BASELINE_RECORDED` for this
  collection method, not a regression PASS. Subsequent cleanup readback proves
  UI count zero, service Running and no tunnel. The earlier invalid CPU run
  remains withdrawn; evidence:
  `docs/operations/evidence/candidate33-windows-wmi-idle-budget.json`;
- candidate.33 historical Windows process-start observation in the same VM:
  p95 `1499.404 ms` from 20 retained launches after 3 discarded warmups.
  **Useful-start credit withdrawn on 2026-09-08:** the collector terminal only
  required a responsive window and visible UIA Pane, without useful Protection
  controls. The historical normalized PASS is retained as provenance, not a
  current useful cold-start gate; normalized evidence:
  `docs/operations/evidence/candidate33-windows-cold-start-budget.json`;
- candidate.33 signed universal APK `295370161` bytes and owner-accepted
  unsigned Windows installer `29153792` bytes: both exact hashes match the
  signed private release index and both are `BASELINE_RECORDED`, not regression
  passes; normalized evidence:
  `docs/operations/evidence/candidate33-artifact-size-baseline.json`;
- Android exact-candidate cold start, Windows cold OS boot, verified connect and
  frame baselines, Android idle, physical/comparable Windows idle and memory
  regression comparison: `MANUAL_OWNER_TEST`;
- later same-kind artifact-size comparison: `MANUAL_OWNER_TEST`.

## R12 Windows idle follow-up — 2026-09-08

[Exact receipt and method](evidence/2026-09-08-r12-windows-idle/README.md):
local client `e88dff9` / Core `02a091c`, owned offline Windows 11 VM, same warm
OS boot. Skipping unchanged two-second runtime notifications reduced observed
combined UI/service CPU p95 from `1.498296%` (FAIL) to `0.749983%` (PASS at 1%).
Both runs discarded 30 intervals and retained 60; both process counters were
readable and all 90 deltas were independently recomputed. Memory p95 moved
from `117440512` to `120459264` bytes; the canonical matching-fingerprint
comparison passes with `2.570452%` growth, below 10%.

305 installed package hashes matched; saved state was preserved. Cleanup left
the VM off/NIC none and host routes/DNS unchanged. This closes the named idle
observation only. Semantic useful-start, separate warm/cold/post-reboot
distributions, Windows 10, connected/tray-hidden and physical/comparable-device
performance remain open for R12-W05 and the final release candidate.

## R12 Windows useful-start follow-up — 2026-09-08

[Method and exact receipt](evidence/2026-09-08-r12-windows-startup/README.md):
the same installed `e88dff9` package now has two separate useful Protection
startup distributions. Warm OS/file-cache fresh process p95 is `765.5534 ms`;
first UI process after full guest power-on/login p95 is `2311.4823 ms`.
Both discard three warmups and retain twenty samples. The canonical 3500 ms
stop passes for both; the 2000 ms target is unmet after guest boot.

The terminal requires enabled visible Connect and protection-status buttons,
Protection navigation and no onboarding/accessibility errors through MSAA on
the exact Flutter window. The status button was also exercised separately.
Timing includes semantic inspection; OS boot/login and service autostart are
excluded. The 23 post-boot samples have distinct boot identities and installed
hash verification after each capture. Warm and post-boot fingerprints differ;
this is no comparison with the withdrawn Pane-only candidate.33 method.
All 305 installed files match; VM off/NIC none and host network unchanged.
Windows 10, physical cold-cache/comparable hardware, connected/tray-hidden
performance and exact final-channel acceptance remain open. The earlier idle
report above records its own state before this follow-up.
