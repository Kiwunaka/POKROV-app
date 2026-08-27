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
| Working package target | `1.2.0+31` |
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

- Android and Windows package versions match `1.2.0+31`; app-shell reports the
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

These are source and fixture results. They are not exact-candidate, device,
signing, hosted-CI, deployed-runtime or promotion proof.

## Open Gate Queue

| Order | Gate | State | Completion rule |
|---:|---|---|---|
| 1 | Clean platform, client, Core and release-index revisions | `PREPARING_REPLACEMENT_TUPLE` | Candidate.3 retains platform `eafaca3…559`, artifact-source client `ac22825…ead`, Core `344b317…8f6` and signing release-index `6a1afa9…bb2`. The replacement source adds support polling and package build `31`; its final committed client revision is not frozen yet. |
| 2 | Public release-index revision | `MISSING_REPLACEMENT_MANIFEST` | Release-index `main` retains signed candidate.3 evidence; manifest `a2752b6a…1090`, signature `926f0b46…7121`, promotion false. It does not bind the replacement source or `1.2.0+31`. |
| 3 | POKROV Core `1.1.0` replacement artifact | `PASS_EXACT_ARTIFACTS` | Core source `344b317…8f6` binds AAR `da3ea378…aba9`, DLL `60fe3fad…3981` and Cronet `8ef1f8bb…a6f7`. |
| 4 | Strict-v2 candidate metadata | `MISSING_REPLACEMENT_MANIFEST` | Candidate.3 metadata remains valid only for its exact older bytes. The replacement must bind build `31`, the new source tuple, six new artifacts, contracts, SBOM and provenance. |
| 5 | Android exact-candidate build and signer | `MISSING_REPLACEMENT_ARTIFACTS` | Candidate.3 production-signed artifacts and LDPlayer persistence are supporting evidence only. Build `31` requires new exact APK/AAB identities and signer verification. |
| 6 | Android physical-device matrix | `MANUAL_OWNER_TEST` | Huawei install, TUN/DNS/egress, WARP, per-app, handoff and endurance pass on exact bytes. |
| 7 | Windows exact-candidate package | `MISSING_REPLACEMENT_ARTIFACT` | Candidate.3 clean-host run `33033294889` is retained supporting evidence only. Build `31` requires a new setup identity and bounded clean-host run. |
| 8 | Windows unsigned-beta warning and clean-host recovery | `SKIPPED_BY_OWNER; REPLACEMENT_PROOF_MISSING` | The `1.2.0` direct-beta exception and warning remain applicable. Replacement live TUN/DNS/egress, recovery while connected and interactive SmartScreen are manual; trusted signing is still required for trusted/Store/broad-stable claims. |
| 9 | Hosted cross-repository CI | `BLOCKED_BY_ACCESS_GITHUB_BILLING` | Candidate.3 source runs are retained. Replacement platform/client PR jobs currently stop before steps because of the GitHub account payment/spending limit; they are neither PASS nor code failures. |
| 10 | Runtime/public readback and rollback | `NOT_AUTHORIZED` | Candidate.3 private evidence exists, but no replacement candidate, public assets, catalog pointer, anonymous readback or rollback drill exists. |
| 11 | Promotion and go/no-go | `NOT_AUTHORIZED` | All required v2 gates are `PASS` for the same artifact bytes. |

## Next Action Order

1. Freeze the replacement platform/client/Core/release-index source tuple and
   keep AWG 3.1 plus AI/Games/DoH contracts green on the exact client revision.
2. Produce build `31` Android and Windows artifacts and a new signed strict-v2
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
