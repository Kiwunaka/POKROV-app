# POKROV App Open Beta v4 Work Order

Status: active
Started: 2026-04-26
Branch: `codex/open-beta-v4`

This folder tracks active client-lane work for the platform Open Beta v4 plan.

## Scope

- Android and Windows are the public release target pair.
- Android remains public-blocked until physical release-build localhost/control-surface audit passes.
- Windows remains gated beta until signing, checksums, and release handoff are approved.
- iOS and macOS remain readiness-only.

## Current Decision

Do not release publicly from this branch. The client lane is ready for local docs/gate hardening, but broad distribution remains blocked by Android physical audit, signing/handoff evidence, and platform launch decision.

## Verification Entry Points

From the platform worktree:

```powershell
$env:POKROV_APP_ROOT="C:\Users\kiwun\.config\superpowers\worktrees\POKROV-app\open-beta-v4"
python scripts/run_client_release_gate.py preflight
python scripts/run_client_release_gate.py test --suite portal
```

Physical Android audit remains blocked until a release-installed build and device are available.

## Related Platform Work Order

Platform worktree:

`C:/Users/kiwun/.config/superpowers/worktrees/VPN/open-beta-v4/docs/developer/work-orders/2026-04-open-beta-v4/`
