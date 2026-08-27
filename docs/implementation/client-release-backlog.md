# POKROV Client Release Backlog

Last updated: 2026-08-27

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains only the current client release queue. Candidate-specific
results belong in dated evidence and never become reusable release approval.

## Current Release Line

| Fact | Current state |
|---|---|
| Public retained release | Android and Windows `1.1.6`, tag `v1.1.6` |
| Working package target | `1.2.0+36` |
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

- Android and Windows package versions match `1.2.0+36`; app-shell reports the
  shared product version `1.2.0`.
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
- Build 36 carries the opt-in direct-DoH laboratory detour and managed AWG
  endpoint materialization without changing VPN-default routing. Its Android
  AAR binds Core `f234bb6…c171`, whose AWG endpoint now resolves probe hostnames
  through the Core DNS router and preserves the canonical `egress` event
  subsystem. Core focused and full gates pass; exact APK interop remains open.
- AWG2 and AWG3.1 userspace lifecycles pass locally. Build 35 additionally
  proved real server handshakes for AWG2 and AWG3.1 but no decrypted IP packets;
  build 36 must prove the Core DNS fix on LDPlayer before this gate advances.
- Core is clean and pushed. The build-36 client binding and scoped platform
  AWG-lab scripts are still being frozen; cross-repository preflight must be
  rerun on their committed revisions before `READY_LOCAL_FREEZE` can return.

These are source and fixture results. They are not exact-candidate, device,
signing, hosted-CI, deployed-runtime or promotion proof.

## Open Gate Queue

| Order | Gate | State | Completion rule |
|---:|---|---|---|
| 1 | Clean platform, client, Core and release-index revisions | `IN_PROGRESS_LOCAL_FREEZE; PROMOTION_BLOCKED` | Core `f234bb6…c171` is clean and pushed. Client build-36 binding and the scoped platform AWG-lab scripts must be committed and pass the cross-repository preflight; release-index `32f560d…2d4a` remains unchanged. |
| 2 | Public release-index revision | `MISSING_REPLACEMENT_MANIFEST` | Release-index `main` retains private signed candidate.4 evidence with promotion false. It does not bind the replacement source or `1.2.0+36`. |
| 3 | POKROV Core `1.1.0` replacement artifact | `PASS_MIXED_PLATFORM_LOCAL; PASS_LOCAL_AWG_LIFECYCLE` | Android binds two byte-identical AAR builds from Core `f234bb6…c171`, including AWG hostname resolution; Windows retains DLL `60fe3fad…3981` from `344b317…8f6` plus Cronet `8ef1f8bb…a6f7`. Platform-source convergence and exact APK/host interop remain open. |
| 4 | Strict-v2 candidate metadata | `MISSING_REPLACEMENT_MANIFEST` | Candidate.4 metadata remains valid only for its exact older bytes. The replacement must bind build `36`, the new source tuple, six new artifacts, contracts, SBOM and provenance. |
| 5 | Android exact-candidate build and signer | `MISSING_REPLACEMENT_ARTIFACTS` | Earlier production-signed artifacts and LDPlayer results are supporting evidence only. Build `36` requires new exact APK/AAB identities, signer verification and AWG/DNS interop proof. |
| 6 | Android physical-device matrix | `MANUAL_OWNER_TEST` | Huawei install, TUN/DNS/egress, WARP, per-app, handoff and endurance pass on exact bytes. |
| 7 | Windows exact-candidate package | `MISSING_REPLACEMENT_ARTIFACT` | Candidate.3 clean-host run `33033294889` is retained supporting evidence only. Build `36` requires a converged Core DLL, new setup identity and bounded clean-host run. |
| 8 | Windows unsigned-beta warning and clean-host recovery | `SKIPPED_BY_OWNER; REPLACEMENT_PROOF_MISSING` | The `1.2.0` direct-beta exception and warning remain applicable. Replacement live TUN/DNS/egress, recovery while connected and interactive SmartScreen are manual; trusted signing is still required for trusted/Store/broad-stable claims. |
| 9 | Hosted cross-repository CI | `BLOCKED_BY_ACCESS_GITHUB_BILLING` | Candidate.3 source runs are retained. Replacement platform/client PR jobs currently stop before steps because of the GitHub account payment/spending limit; they are neither PASS nor code failures. |
| 10 | Runtime/public readback and rollback | `NOT_AUTHORIZED` | Candidate.3 private evidence exists, but no replacement candidate, public assets, catalog pointer, anonymous readback or rollback drill exists. |
| 11 | Promotion and go/no-go | `NOT_AUTHORIZED` | All required v2 gates are `PASS` for the same artifact bytes. |

## Next Action Order

1. Freeze the replacement platform/client/Core/release-index source tuple and
   keep AWG2, AWG3.1 plus AI/Games/DoH contracts green on the exact client
   revision.
2. Produce build `36` Android and Windows artifacts and a new signed strict-v2
   manifest; do not reuse candidate.3 artifact evidence.
3. Run LDPlayer rehearsal, then the physical-device/OEM and Windows clean-host
   network/recovery/SmartScreen matrices on the replacement bytes.
4. Complete current-origin, Brain-origin, payment, Operator OIDC/RBAC,
   legal/commercial and rollback gates for the same candidate.
5. Request separate authority for public same-byte candidate publication,
   anonymous readback, rollback drill and promotion.
6. Provision trusted Windows signing later before any signed, Store or
   broad-stable Windows claim.

## Retained History

The previous mixed backlog is preserved as
[2026-08-21-client-release-backlog-snapshot.md](history/2026-08-21-client-release-backlog-snapshot.md).
Its candidate statuses are evidence only.
