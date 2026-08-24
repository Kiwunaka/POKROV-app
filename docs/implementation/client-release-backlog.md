# POKROV Client Release Backlog

Last updated: 2026-08-24

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
| Active pre-candidate Core artifact | POKROV Core `1.1.0`, exact AAR/DLL identities bound |
| Support-mode signing public pin | `PASS_SOURCE_CONTROL` — tracked key `pokrov-support-2026-08`; private/HMAC values are secret-only and not deployed |
| Retained public Core | `1.0.3`; rollback/history identity only |
| Windows trusted-signing decision | `SKIPPED_BY_OWNER` for the exact `1.2.0` direct-download beta; mandatory SmartScreen warning; no trusted/Store/broad-stable claim |

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
- Production packaging is source-bound to one tracked support-mode public key
  and rejects partial or different overrides before Flutter.

These are source and fixture results. They are not exact-candidate, device,
signing, hosted-CI, deployed-runtime or promotion proof.

## Open Gate Queue

| Order | Gate | State | Completion rule |
|---:|---|---|---|
| 1 | Clean platform, client, Core and release-index revisions | `REFREEZE_REQUIRED` | Current control heads are platform `36fe4a1…1fd0`, client `3cab149…13e1` before this support-pin change, Core `bdbd97f…72f` and release-index `7d5e402…66b2`; merge this pin, then freeze the replacement tuple. |
| 2 | Public release-index revision | `PASS_SOURCE_CONTROL` | Public `main` `7d5e402…66b2` retains the trust root and deterministic secret-only signer; post-merge source-contract run `32668571694` passes. No signed candidate template exists. |
| 3 | POKROV Core `1.1.0` replacement artifact | `PASS_LOCAL` | Core revision `bdbd97f…72f` produces the exact AAR/DLL identities already bound by source evidence; replacement candidate signing/device proof remains later. |
| 4 | Strict-v2 candidate metadata | `MISSING` | Generate a new beta handoff after final-source Android/Windows artifact assembly; Windows signing must remain `SKIPPED_BY_OWNER`, never `PASS`. |
| 5 | Android exact-candidate build and signer | `MISSING` | Rebuild with the tracked support pin; every APK must match v2 size, digest, package, version and production signer. |
| 6 | Android physical-device matrix | `MANUAL_OWNER_TEST` | Huawei install, TUN/DNS/egress, WARP, per-app, handoff and endurance pass on exact bytes. |
| 7 | Windows exact-candidate package | `MISSING` | Rebuild with the tracked support pin; machine-wide setup must contain the service, Core and required dependencies. |
| 8 | Windows unsigned-beta warning and clean-host recovery | `OWNER_EXCEPTION_RECORDED; MANUAL_OWNER_TEST` | Retain the exact `1.2.0` direct-beta exception and SmartScreen warning, then run clean VM install/TUN/DNS/egress/crash/reboot/rollback on the exact unsigned setup. Trusted signing remains a later gate for trusted/Store/broad-stable claims. |
| 9 | Hosted cross-repository CI | `PASS_SOURCE_CONTROLS` | Client main run `32668204355` and platform master runs `32669461958`/`32669461832` pass; repeat after this support-pin merge and again for the exact candidate. |
| 10 | Runtime/public readback and rollback | `NOT_AUTHORIZED` | Catalog contains the exact candidate plus prior stable target; owner authorizes sync; pointer backup, receipt, manifest, API, downloads and rollback readback are retained. |
| 11 | Promotion and go/no-go | `NOT_AUTHORIZED` | All required v2 gates are `PASS` for the same artifact bytes. |

## Next Action Order

1. Merge and host-verify the tracked support signing pin.
2. Freeze the replacement four-repository tuple and rebuild exact artifacts.
3. Generate strict-v2 beta metadata with Windows `SKIPPED_BY_OWNER` and run
   exact Android/Windows manual gates.
4. Request separate authority for runtime support-key deployment, candidate
   publication, readback, rollback drill and promotion.
5. Provision trusted Windows signing later before any signed, Store or
   broad-stable Windows claim.

## Retained History

The previous mixed backlog is preserved as
[2026-08-21-client-release-backlog-snapshot.md](history/2026-08-21-client-release-backlog-snapshot.md).
Its candidate statuses are evidence only.
