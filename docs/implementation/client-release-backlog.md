# POKROV Client Release Backlog

Last updated: 2026-08-28

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains only the current client release queue. Candidate-specific
results belong in dated evidence and never become reusable release approval.

## Current Release Line

| Fact | Current state |
|---|---|
| Public retained release | Android and Windows `1.1.6`, tag `v1.1.6` |
| Working package target | `1.2.0+4044` |
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

- Android and Windows package versions match `1.2.0+4044`; app-shell reports the
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
- Build 4044 carries the opt-in direct-DoH laboratory detour and managed AWG
  endpoint materialization without changing VPN-default routing. Its Android
  AAR binds Core `f44dbe8…f90d`, whose AWG endpoint resolves probe hostnames,
  preserves the canonical `egress` event subsystem and requests Android
  platform protection only for its outer socket. It also selects the reachable
  owned app ingress through a JSON health preflight, with the canonical API
  hostname retained as a bounded fallback and no replay of non-idempotent
  requests. Two AAR builds are byte-identical. A production-signed working
  build-4044 APK was installed and exercised physically, but no strict-v2
  replacement candidate exists.
- AWG2 and AWG3.1 userspace lifecycles pass locally. After the owned DE UFW
  ingress correction, exact Core `f234bb6` proved live server handshakes for
  both profiles. Physical build 4041 received the device-bound managed profile
  but emitted no observable AWG UDP. Build 4042 then enabled global interface
  auto-detection as an experiment; LDPlayer failed immediately at Core start
  with no observable AWG UDP, so those bytes are rejected. Build 4043 reached
  an AWG userspace handshake and direct Core egress on LDPlayer, but ordinary
  system-TUN traffic timed out. On physical Beeline, the old API hostname timed
  out before profile refresh and neither owned AWG listener received a packet;
  the same connection did reach JSON through the new app ingress. Build 4044
  then refreshed through that ingress and reached both new owned listeners.
  Each guarded plain-UDP control was received and echoed 3/3 by the server but
  returned 0/3 to the phone, classifying physical AWG as
  `BLOCKED_BY_NETWORK_CURRENT_ORIGIN` on Beeline rather than a crypto mismatch.
  Direct cellular DoH resolved all three bounded AI/Games queries, while the
  generated routes correctly kept application traffic on the VPN. After lab
  unbind and VPN-default DNS restore, ordinary WARP, IP egress and DNS+egress
  passed on the same phone. Full exact-candidate tunnel DNS, leak, handoff and
  OEM proof remain open.
- Core is clean and pushed. The build-4044 client binding and scoped platform
  AWG-lab scripts are still being frozen; cross-repository preflight must be
  rerun on their committed revisions before `READY_LOCAL_FREEZE` can return.

These results mix source, live-lab and explicitly identified pre-candidate
physical evidence. None is exact replacement-candidate, hosted-CI, public
runtime, rollback or promotion proof.

## Open Gate Queue

| Order | Gate | State | Completion rule |
|---:|---|---|---|
| 1 | Clean platform, client, Core and release-index revisions | `IN_PROGRESS_LOCAL_FREEZE; PROMOTION_BLOCKED_BY_ACTIONS_BILLING` | Core `f44dbe8…f90d`, platform `e5ef03a…11db` and client source `1d670b3…9f9` are clean and pushed. Platform PR 58 and client PR 33 have zero-step GitHub failures caused by account billing/spending limits; release-index `32f560d…2d4a` remains unchanged. |
| 2 | Public release-index revision | `MISSING_REPLACEMENT_MANIFEST` | Release-index `main` retains private signed candidate.4 evidence with promotion false. It does not bind the replacement source or `1.2.0+4044`. |
| 3 | POKROV Core `1.1.0` replacement artifact | `PASS_MIXED_PLATFORM_LOCAL; PASS_LOCAL_AWG_LIFECYCLE; PASS_WORKING_ANDROID_HOST` | Android binds two byte-identical AAR builds from Core `f44dbe8…f90d`; those bytes also match the prior `54e76bb` build and include AWG hostname resolution and Android outer-socket protection. Working build 4044 proved control-plane reachability, socket protection, normal WARP and egress on the Huawei. Windows retains DLL `60fe3fad…3981` from `344b317…8f6` plus Cronet `8ef1f8bb…a6f7`. Platform-source convergence and exact-candidate host proof remain open. |
| 4 | Strict-v2 candidate metadata | `MISSING_REPLACEMENT_MANIFEST` | Candidate.4 metadata remains valid only for its exact older bytes. The replacement must bind build `4044`, the new source tuple, six new artifacts, contracts, SBOM and provenance. |
| 5 | Android exact-candidate build and signer | `PASS_WORKING_4044_SIGNER; MISSING_REPLACEMENT_CANDIDATE` | Working APK `1.2.0+4044` is production-certificate matched at SHA-256 `7417191b…f04f`; its physical evidence is retained as pre-candidate proof only. A strict-v2 replacement manifest and final candidate bytes are still missing. |
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
2. Freeze build `4044` Android and Windows artifacts into a new signed strict-v2
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
