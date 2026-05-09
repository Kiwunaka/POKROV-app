# POKROV App Open Beta v4 Work Order

Status: active
Started: 2026-04-26
Branch: `codex/open-beta-v4`

This folder tracks active client-lane work for the platform Open Beta v4 plan.

## Scope

- Android and Windows are the public release target pair.
- Android has operator-attested physical-device audit evidence for this beta wave, but remains public-blocked until runtime `APP_*` sync approval, live download smoke, and final platform GO.
- Windows remains a gated unsigned outside-store beta until runtime evidence, checksum/handoff approval, and user-facing unknown-publisher warning copy are approved. Trusted signing is a later trust upgrade, not a blocker for this beta pass.
- iOS and macOS remain readiness-only.

## Current Decision

Do not release publicly from this branch. The client lane is ready for local docs/gate hardening, but broad distribution remains blocked by runtime download handoff, live `/api/client/apps` smoke, payment/email evidence, and the final platform launch decision.

## Verification Entry Points

From the platform worktree:

```powershell
$env:POKROV_APP_ROOT="C:\Users\kiwun\.config\superpowers\worktrees\POKROV-app\open-beta-v4"
python scripts/run_client_release_gate.py preflight
python scripts/run_client_release_gate.py test --suite portal
```

Physical Android audit is operator-attested for this beta wave; replace that with raw retained audit evidence only if a later device run is attached and validated.

## Related Platform Work Order

Platform worktree:

`C:/Users/kiwun/.config/superpowers/worktrees/VPN/open-beta-v4/docs/developer/work-orders/2026-04-open-beta-v4/`
