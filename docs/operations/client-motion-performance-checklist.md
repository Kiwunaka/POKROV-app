# Client Motion Performance Checklist

Last updated: 2026-09-04

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
- Busy state uses a finite sweep, not an unbounded spinner.
- Connected state settles into `connect-disc-connected-settle`.
- Error/degraded state settles into `connect-disc-error-settle` with calm warning color.
- Reduced-motion mode keeps labels and state changes understandable without decorative movement.
- Connect disc animated region remains inside a `RepaintBoundary`.

## Shell Motion

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
  `PASS`, p95 `0.749734% <= 1.0%` from 60 retained one-second samples after 30
  discarded warmups; combined working-set p95 `108158976` bytes is a new
  full-process `BASELINE_RECORDED`, not a comparison with the earlier UI-only
  baseline; normalized evidence:
  `docs/operations/evidence/candidate33-windows-combined-idle-budget.json`;
- candidate.33 Windows useful cold-process start in the same VM: `PASS`, p95
  `1499.404 ms <= 2000 ms` target and `3500 ms` stop from 20 retained launches
  after 3 discarded warmups; this is not a cold OS boot or physical/comparable
  Windows proof; normalized evidence:
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
