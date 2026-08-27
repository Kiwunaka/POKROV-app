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
| 1 | Clean platform, client, Core and release-index revisions | `PASS_EXACT_TUPLE` | Candidate.3 binds platform `eafaca3…559`, artifact-source client `ac22825…ead`, Core `344b317…8f6` and signing release-index `6a1afa9…bb2`. Later workflow/evidence-only commits do not replace artifact source. |
| 2 | Public release-index revision | `PASS_SIGNED_CANDIDATE_3_PRIVATE` | Release-index `main` retains signed candidate.3 and clean-host evidence; manifest `a2752b6a…1090`, signature `926f0b46…7121`, promotion false. No public `v1.2.0` release was created. |
| 3 | POKROV Core `1.1.0` replacement artifact | `PASS_EXACT_ARTIFACTS` | Core source `344b317…8f6` binds AAR `da3ea378…aba9`, DLL `60fe3fad…3981` and Cronet `8ef1f8bb…a6f7`. |
| 4 | Strict-v2 candidate metadata | `PASS_SIGNED_CANDIDATE_3` | Signed manifest binds the six exact artifacts, source tuple, contracts, SBOM and provenance; unsigned Windows remains `SKIPPED_BY_OWNER`, never trusted-signed. |
| 5 | Android exact-candidate build and signer | `PASS_ARTIFACTS; PASS_EMULATOR_PREFLIGHT` | Five Android artifacts match v2 size/digest and production signer. Exact universal APK passed LDPlayer update/start/settings persistence; catalog/TUN is `BLOCKED_BY_ACCESS` on the expired emulator account. |
| 6 | Android physical-device matrix | `MANUAL_OWNER_TEST` | Huawei install, TUN/DNS/egress, WARP, per-app, handoff and endurance pass on exact bytes. |
| 7 | Windows exact-candidate package | `PASS_EXACT_CANDIDATE_3_BOUNDED` | Run `33033294889` installed EXE `9962e3e8…8021`, matched all eight files, service/IPC/restart/uninstall and idle network restoration on clean Windows. Live network remains manual. |
| 8 | Windows unsigned-beta warning and clean-host recovery | `SKIPPED_BY_OWNER; PASS_IDLE_CLEAN_HOST; MANUAL_OWNER_TEST` | Exact beta exception and warning are retained. Live TUN/DNS/egress, recovery while connected and interactive SmartScreen remain manual; trusted signing is still required for trusted/Store/broad-stable claims. |
| 9 | Hosted cross-repository CI | `PASS_EXACT_SOURCES` | Platform runs `33029917507`/`33029917498`, client source run `33032033161`, gate-contract run `33032654414`, signing run `33032397754` and release-index source runs pass. |
| 10 | Runtime/public readback and rollback | `NOT_AUTHORIZED` | Signed candidate.3 and private CI carrier exist, but public release assets, candidate catalog pointer, anonymous download readback and rollback drill have not been authorized or executed. |
| 11 | Promotion and go/no-go | `NOT_AUTHORIZED` | All required v2 gates are `PASS` for the same artifact bytes. |

## Next Action Order

1. Obtain a legitimate test entitlement and finish exact candidate.3 Android
   catalog/TUN/DNS/egress checks, then run the physical-device/OEM matrix.
2. Run the remaining Windows live-network, recovery and interactive
   SmartScreen checks on the same EXE bytes.
3. Complete current-origin, Brain-origin, payment, Operator OIDC/RBAC,
   legal/commercial and rollback gates for the same candidate.
4. Request separate authority for public same-byte candidate publication,
   anonymous readback, rollback drill and promotion.
5. Provision trusted Windows signing later before any signed, Store or
   broad-stable Windows claim.

## Retained History

The previous mixed backlog is preserved as
[2026-08-21-client-release-backlog-snapshot.md](history/2026-08-21-client-release-backlog-snapshot.md).
Its candidate statuses are evidence only.
