# POKROV Client Release Backlog

Last updated: 2026-08-29

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains only the current client release queue. Candidate-specific
results belong in dated evidence and never become reusable release approval.

## Current Release Line

| Fact | Current state |
|---|---|
| Public retained release | Android and Windows `1.1.6`, tag `v1.1.6` |
| Working package target | `1.2.0+4046` |
| Working target state | `PRE_CANDIDATE_LOCAL` |
| Candidate created | `false` |
| Public cutover allowed for a new candidate | `false` |
| Google Play | `NOT_REQUESTED` |
| Active pre-candidate Core artifact | Security-fixed POKROV Core `1.1.0` at `547f096…8cd`; exact reproducible AAR/DLL identities bound |
| Support-mode signing public pin | `PASS_SOURCE_CONTROL` — tracked key `pokrov-support-2026-08`; private/HMAC values are secret-only and not deployed |
| Retained public Core | `1.0.3`; rollback/history identity only |
| Windows trusted-signing decision | `SKIPPED_BY_OWNER` for the exact `1.2.0` direct-download beta; mandatory SmartScreen warning; no trusted/Store/broad-stable claim |

`config/release-handoff.seed.json` owns the public release and development
target. `config/cutover-readiness.seed.json` owns the current cutover verdict.

## Current Local Completion

- Core `547f096…8cd` fixes reachable advisory `GO-2026-6303` by updating both
  module roots to `golang.org/x/crypto v0.55.0` and the compatible dependency
  closure. Module verification, focused tests, full Core tests, `go vet` and
  root/embedded reachable-vulnerability scans pass locally.
- Android AAR `7895b2f7…1a63`, size `107414253`, and Windows DLL
  `6bf2243f…c45`, size `55424000`, are each byte-identical across two clean
  builds from that source. The bundled artifacts and machine contract match.
- The exact Windows DLL exposes all 15 required symbols and passes 100
  proxy-only start/stop cycles. This does not prove SCM, TUN, DNS, leak,
  recovery or clean-host behavior.
- Production-signed ARM64 APK `7d1d4093…58ee5` from client `064fcd0...` embeds
  active Core `547f096...`, installs/readbacks exactly on physical Huawei and
  passes ordinary Frankfurt on Beeline. AWG2/AWG3.1 each pass fresh handshake
  plus bidirectional TCP/UDP payload, but Android selected-endpoint verification
  remains `EGRESS-001`; this is transport PASS and end-to-end FAIL.
- Core hosted run `33227157016` passes all five jobs. The exact client hosted
  run contains zero executed steps and remains `BLOCKED_BY_ACCESS`, not PASS.
- Clean client `b4c9117…9f0` produced unsigned setup `6ef7899d…cbe9`, size
  `28918848`, with manifest `8dced605…f74b`; all eight files match and the
  embedded DLL is exact. Signing remains `SKIPPED_BY_OWNER` with mandatory
  SmartScreen warning. Clean-host runtime proof is open.

## Retained Pre-Convergence Evidence

- Android and Windows package versions match `1.2.0+4046`; app-shell reports the
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
- Build 4045 carries the opt-in direct-DoH laboratory detour and managed AWG
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
  passed on the same phone. A later explicit no-carrier readback selected AWG2
  for exact physical and LDPlayer identities, but build 4044 on Wi-Fi and build
  4043 on LDPlayer emitted no AWG traffic. LDPlayer additionally rejected the
  selected Frankfurt location before tunnel start. The common managed-profile
  activation/fallback path is therefore a pre-candidate failure; AWG3.1 was not
  repeated above the same unmet AWG2 precondition. Full exact-candidate tunnel
  DNS, leak, handoff and OEM proof remain open.
- Core is clean and pushed. Platform head `42522fe…a3d9` now bypasses the
  ordinary Smart Connect shortlist when issuing device-bound AWG2/AWG3.1 lab
  material, while working build 4045 demotes stale Android `running` state when
  no app-owned TUN exists. These corrections are source-only until the platform
  deploy and exact Android device proof; cross-repository preflight must be
  rerun on their committed revisions before `READY_LOCAL_FREEZE` can return.
- Exact client source `75e82b0…e62` adds an opt-in external Smart-DNS
  laboratory route.
  It is accepted only with exact HTTPS port 443 `/dns-query` without a
  query/fragment/token, direct DNS and an enabled AI or gaming-service group.
  Only selected suffix DNS questions use that resolver while normal final DNS
  stays unchanged; selected service connections use the existing direct
  outbound, other groups keep VPN and explicit user rules keep precedence.
  The client/platform policy bytes match and app-shell analyze plus `412/412`
  tests pass. Production-signed arm64/x86_64 working APKs were installed and
  read back byte-identically on the Huawei and LDPlayer. LDPlayer passed the
  prerequisite/default-off/enable/restore state machine; the phone passed the
  exact-package/default-off gate without a setting change. Platform
  `2d18fd7…f78a` produces a byte-reproducible verified server bundle, and the
  platform operations `ca9eb41…7334` add the tested guarded
  PLAN/APPLY/ROLLBACK source contract. No dedicated-node PLAN, installed owned
  resolver/relay or live service-access proof exists.
- A fresh AWG source/host-contract retest binds platform `50c9d12…dde49`,
  client `75e82b0…e62` and Core `e8eb772…41a1`. AWG2 and AWG3.1 contract-sync
  reports pass with digests `0caeaba4…eb44` and `3a4c318a…06f`; ten focused
  Flutter tests, thirteen Android direct-release JVM tests and thirty-one Core
  AWG tests pass. The operator-only live Core egress test remains skipped
  without runtime material. This is local source/host contract evidence only:
  Windows still lacks a converged Core artifact, and neither server deploy nor
  device tunnel was run.
- A separate exact-Core live interop from the current Windows origin emitted
  outer packets for AWG2 and AWG3.1 but received no outer response. Concurrent
  address-free AWG2 server capture counted `34` inbound and `8` outbound
  packets, including `8` initiation and `8` response-sized packets, with no
  handshake. AWG2 is therefore
  `BLOCKED_BY_NETWORK_CURRENT_WINDOWS_ORIGIN_REVERSE_UDP`; AWG3.1 keeps the
  narrower `FAIL_NO_OUTER_RESPONSE_CURRENT_WINDOWS_ORIGIN` because its server
  capture was not repeated. This Core-only probe did not exercise the Windows
  app, TUN or DNS and changed no rollout/device binding.

These results mix source, live-lab and explicitly identified pre-candidate
physical evidence. None is exact replacement-candidate, hosted-CI, public
runtime, rollback or promotion proof.

## Open Gate Queue

| Order | Gate | State | Completion rule |
|---:|---|---|---|
| 1 | Clean platform, client, Core and release-index revisions | `IN_PROGRESS_SECURITY_FIXED_TUPLE` | Platform `25eda3c…`, Core `547f096…8cd` and this client update must be committed, promoted through their owner-solo lanes and rerun through the exact aggregate gate. The previous `15/15` report predates the security-fixed Core and is supporting evidence only. |
| 2 | Public release-index revision | `MISSING_REPLACEMENT_MANIFEST` | Release-index `main` retains private signed candidate.4 evidence with promotion false. It does not bind the replacement source or `1.2.0+4046`. |
| 3 | POKROV Core `1.1.0` replacement artifact | `PASS_SINGLE_SOURCE_LOCAL_SECURITY_FIXED` | Android and Windows bind reproducible artifacts from Core `547f096…8cd`: AAR `7895b2f7…1a63`, DLL `6bf2243f…c45`, unchanged Cronet `8ef1f8bb…a6f7`, exact SBOMs and zero reachable findings in both scanned module roots. Candidate packaging and platform proof remain open. |
| 4 | Strict-v2 candidate metadata | `MISSING_REPLACEMENT_MANIFEST` | Candidate.4 metadata remains valid only for its exact older bytes. The replacement must bind build `4046`, the new source tuple, six new artifacts, contracts, SBOM and provenance. |
| 5 | Android exact-candidate build and signer | `PASS_PRODUCTION_SIGNED_PRE_CANDIDATE_ARTIFACT; CANDIDATE_MISSING` | Production-signed ARM64 APK `7d1d4093…58ee5` from client `064fcd0...` binds exact AAR `7895b2f7…1a63`, installs/readbacks byte-identically as release/non-debuggable `1.2.0+4046`; no strict-v2 candidate exists. |
| 6 | Android physical-device matrix | `PASS_ORDINARY_AND_AWG_TRANSPORT; FAIL_AWG_EGRESS_001; MATRIX_OPEN` | On exact active bytes and physical Beeline, ordinary Frankfurt reaches verified green; AWG2/AWG3.1 pass handshake and bidirectional TCP/UDP payload but both fail selected-endpoint egress verification. Correct that common URL-test path, then run WARP, per-app, handoff, OEM/lifecycle and endurance before candidate proof. |
| 7 | Windows exact-candidate package | `PASS_PRE_CANDIDATE_ARTIFACT; CLEAN_HOST_OPEN` | Clean client `b4c9117…9f0` packages exact DLL `6bf2243f…c45` in unsigned setup `6ef7899d…cbe9`; manifest `8dced605…f74b` binds all eight files. This is not strict-v2 candidate or clean-host proof. |
| 8 | Windows unsigned-beta warning and clean-host recovery | `SKIPPED_BY_OWNER; REPLACEMENT_PROOF_MISSING` | The `1.2.0` direct-beta exception and warning remain applicable. Replacement live TUN/DNS/egress, recovery while connected and interactive SmartScreen are manual; trusted signing is still required for trusted/Store/broad-stable claims. |
| 9 | Hosted cross-repository CI | `CORE_PASS; PLATFORM_CLIENT_BLOCKED_BY_ACCESS` | Core run `33227157016` passes all five exact-source jobs. Platform/client Actions stop before product steps under the owner-solo access policy and are neither PASS nor code failures. No purchase or protected-branch setup is required by owner decision; every non-run remains explicit. |
| 10 | Runtime/public readback and rollback | `NOT_AUTHORIZED` | Candidate.3 private evidence exists, but no replacement candidate, public assets, catalog pointer, anonymous readback or rollback drill exists. |
| 11 | Promotion and go/no-go | `NOT_AUTHORIZED` | All required v2 gates are `PASS` for the same artifact bytes. |

## Next Action Order

1. Correct the common Android/Core selected-endpoint `EGRESS-001` path while
   retaining fail-closed verified-state semantics, then repeat AWG2/AWG3.1 on
   exact active bytes.
2. Run the remaining Android lifecycle/OEM/WARP/per-app matrix and the Windows
   live app/service/TUN/DNS/AWG clean-host matrix.
3. Rerun the exact local aggregate after the endpoint correction; Core hosted
   CI is already green for `547f096...`, while platform/client access stops
   remain explicit.
4. Freeze build `4046` Android and Windows artifacts into a new signed strict-v2
   manifest; do not reuse candidate.3 artifact evidence.
5. Complete current-origin, Brain-origin, payment, Operator OIDC/RBAC,
   legal/commercial and rollback gates for the same candidate.
6. Request separate authority for public same-byte candidate publication,
   anonymous readback, rollback drill and promotion.
7. Provision trusted Windows signing later before any signed, Store or
   broad-stable Windows claim.

## Retained History

The previous mixed backlog is preserved as
[2026-08-21-client-release-backlog-snapshot.md](history/2026-08-21-client-release-backlog-snapshot.md).
Its candidate statuses are evidence only.
