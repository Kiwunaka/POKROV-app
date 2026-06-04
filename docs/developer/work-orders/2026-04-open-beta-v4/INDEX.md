# POKROV App Open Beta v4 Work Order

Status: outside-store public beta GO with accepted skips
Started: 2026-04-26
Branch: `codex/open-beta-v4`

This folder tracks active client-lane work for the platform Open Beta v4 plan.

## Scope

- Android and Windows are the public release target pair.
- Android has operator-attested physical-device audit evidence and runtime handoff evidence for the `2026-05-15` outside-store beta; raw device evidence remains a manual owner test before stronger claims.
- Windows is an unsigned outside-store public beta with runtime evidence and accepted unknown-publisher warning posture. Trusted signing is a later trust upgrade, not a blocker for this beta pass.
- iOS and macOS remain readiness-only.

## Current Decision

The platform launch decision is outside-store public beta `GO` as of `2026-05-15`. Do not upgrade that decision to stable, store, trusted-signing, RU-origin, or raw Android-audit claims without fresh exact-candidate evidence.

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
