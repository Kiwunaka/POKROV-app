# POKROV Client Release Backlog

Last updated: 2026-08-22

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains only the current client release queue. Candidate-specific
results belong in dated evidence and never become reusable release approval.

## Current Release Line

| Fact | Current state |
|---|---|
| Public retained release | Android and Windows `1.1.6`, tag `v1.1.6` |
| Working package target | `1.2.0+30` |
| Working target state | `PRE_CANDIDATE_LOCAL` |
| Candidate created | `false` |
| Public cutover allowed for a new candidate | `false` |
| Google Play | `NOT_REQUESTED` |
| Active Core artifact | POKROV Core `1.0.3` |
| Intended Core replacement | `1.1.0`, exact replacement artifact pending |

`config/release-handoff.seed.json` owns the public release and development
target. `config/cutover-readiness.seed.json` owns the current cutover verdict.

## Current Local Completion

- Android, Windows and app-shell package versions match `1.2.0+30`.
- Strict release-handoff v2 generation and client/Core parity pass locally.
- The retained `1.1.6` stable pointer is hash-bound to its versioned rollback
  target, and an isolated fixture proves byte-identical A→B→A pointer reversal.
- Release notes and visible client version share the manifest-validated
  package identity.
- Android uses separate direct and store update authorities.
- Windows uses the service-first privilege boundary in current source.
- Local observability, diagnostics and support-bundle contracts are present.

These are source and fixture results. They are not exact-candidate, device,
signing, hosted-CI, deployed-runtime or promotion proof.

## Open Gate Queue

| Order | Gate | State | Completion rule |
|---:|---|---|---|
| 1 | Clean platform, client and Core revisions | `BLOCKED` | All exact source revisions are clean and frozen. |
| 2 | Public release-index revision | `BLOCKED_BY_ACCESS` | The index exists and its exact revision is bound into v2. |
| 3 | POKROV Core `1.1.0` replacement artifact | `DEVELOPMENT_REPLACEMENT_PENDING` | Exact AAR/DLL identities match the declared Core revision. |
| 4 | Strict-v2 candidate metadata | `MISSING` | The clean client generator produces one validated handoff outside retained history. |
| 5 | Android exact-candidate build and signer | `MISSING` | Every APK matches v2 size, digest, package, version and signer. |
| 6 | Android physical-device matrix | `MANUAL_OWNER_TEST` | Huawei install, TUN/DNS/egress, WARP, per-app, handoff and endurance pass on exact bytes. |
| 7 | Windows exact-candidate package | `MISSING` | Machine-wide setup contains the service, Core and required dependencies. |
| 8 | Windows trust and clean-host recovery | `MANUAL_OWNER_TEST` | Trusted signing plus clean VM TUN/DNS/egress/crash/reboot/rollback pass. |
| 9 | Hosted cross-repository CI | `NOT_RUN` | Required checks pass on the frozen platform/client/Core/index revisions. |
| 10 | Runtime/public readback and rollback | `NOT_AUTHORIZED` | Catalog contains the exact candidate plus prior stable target; owner authorizes sync; pointer backup, receipt, manifest, API, downloads and rollback readback are retained. |
| 11 | Promotion and go/no-go | `NOT_AUTHORIZED` | All required v2 gates are `PASS` for the same artifact bytes. |

## Next Action Order

1. Clean and freeze all four repository revisions.
2. Produce the exact Core replacement artifacts.
3. Generate strict-v2 metadata and verify the artifact set.
4. Run hosted CI and exact Android/Windows manual gates.
5. Request separate authority for runtime sync, rollback drill and promotion.

## Retained History

The previous mixed backlog is preserved as
[2026-08-21-client-release-backlog-snapshot.md](history/2026-08-21-client-release-backlog-snapshot.md).
Its candidate statuses are evidence only.
