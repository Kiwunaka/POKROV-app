# POKROV Client Release Backlog

Last updated: 2026-08-30

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains only the current client release queue. Candidate-specific
results belong in dated evidence and never become reusable release approval.

## Current Release Line

| Fact | Current state |
|---|---|
| Public retained release | Android and Windows `1.1.6`, tag `v1.1.6` |
| Working package target | `1.2.0+4047` |
| Working source target state | `PRE_CANDIDATE_LOCAL` on continuing `main` |
| Exact signed candidate | `pokrov-1.2.0-candidate.10`; private Actions artifact, promotion false |
| Candidate created | `false` |
| Public cutover allowed for a new candidate | `false` |
| Google Play | `NOT_REQUESTED` |
| Active pre-candidate Core artifact | Secret-safe POKROV Core `1.1.0` at `cd8f0f4…884d`; exact reproducible AAR/DLL identities and refreshed SBOMs bound. Exact candidate.10 remains on immutable `a45d69e…665e`. |
| Support-mode signing public pin | `PASS_SOURCE_CONTROL` — tracked key `pokrov-support-2026-08`; private/HMAC values are secret-only and not deployed |
| Retained public Core | `1.0.3`; rollback/history identity only |
| Windows trusted-signing decision | `SKIPPED_BY_OWNER` for the exact `1.2.0` direct-download beta; mandatory SmartScreen warning; no trusted/Store/broad-stable claim |
| Conditional Linux beta | `IMPLEMENTED_PARTIAL_SOURCE_ONLY`; non-public and absent from the current candidate |

`config/release-handoff.seed.json` owns the public release and continuing
development target. `config/cutover-readiness.seed.json` owns the cutover
verdict. Exact candidate.10 identity comes only from the signed public
release-index manifest/receipt; the client seed does not duplicate that
candidate contract.
This `false` applies to the continuing `main` target. Signed candidate.10 is
separate immutable release-index evidence and is not recreated by this branch.

## Current Local Completion

- Core `cd8f0f4…884d` retains the `GO-2026-6303` dependency correction and
  makes the Core-owned AWG endpoint use the configured default domain-resolver
  transport and strategy for its inner FQDN. Hostname-authenticated TLS and
  fail-close remain unchanged. It also removes legacy raw-settings/error
  logging and retains explicit AWG2/AWG 3.1 start/close coverage. Both module roots retain
  `golang.org/x/crypto v0.55.0` and the compatible dependency
  closure. Module verification, focused tests, full Core tests, `go vet` and
  root/embedded reachable-vulnerability scans pass locally.
- Android AAR `2a9677d9…c6a69`, size `107419397`, and Windows DLL
  `f284fa88…8204`, size `55426048`, are each byte-identical across two clean
  builds from that source. The bundled artifacts and machine contract match.
- The exact Windows DLL exposes all 15 required symbols and passes 100
  proxy-only start/stop cycles. This does not prove SCM, TUN, DNS, leak,
  recovery or clean-host behavior.
- Prior production-signed ARM64 APK `7d1d4093…58ee5` from client `064fcd0...`
  embeds Core `547f096...`, installs/readbacks exactly on physical Huawei and
  passes ordinary Frankfurt on Beeline. AWG2/AWG3.1 each pass fresh handshake
  plus bidirectional TCP/UDP payload, but Android selected-endpoint verification
  remains `EGRESS-001`; this is transport PASS and end-to-end FAIL.
- Later production-signed diagnostic client `f078625...` with the same Core
  retained exact terminal category `egress_probe_dns_lookup` for both profiles.
  Corrected Core `a45d69e...` plus production-signed client `68779c4...` produces
  ARM64 APK `b583205d…7296`, installs/readbacks exactly, and reaches retained
  green selected-endpoint state for AWG2 and AWG3.1 on physical Beeline. The
  same source passes both profiles in LDPlayer. This closes the common resolver
  defect, not the remaining Android device matrix or candidate gate.
- Core hosted run `33227157016` passes all five jobs. The exact client hosted
  run contains zero executed steps and remains `BLOCKED_BY_ACCESS`, not PASS.
- Exact candidate.10 x86_64 APK `ec07ba17…2627`, `109952213` bytes, installed
  and read back byte-identically on LDPlayer as release/non-debuggable
  `1.2.0+4046`. All seven locations were visible. The ordinary Frankfurt
  control stopped fail-closed at the emulator-origin egress boundary; separate
  guarded AWG2 and AWG3.1 binds each reached app-confirmed tunnel, DNS and
  selected egress. Final guarded restore removed both lab materials and
  membership and left the app disconnected with no TUN.
- Clean client `b4c9117…9f0` produced unsigned setup `6ef7899d…cbe9`, size
  `28918848`, with manifest `8dced605…f74b`; all eight files match and the
  embedded DLL is exact. Signing remains `SKIPPED_BY_OWNER` with mandatory
  SmartScreen warning. Clean-host runtime proof is open.

## Retained Pre-Convergence Evidence

- Android and Windows development package versions match `1.2.0+4047`; app-shell reports the
  shared product version `1.2.0`.
- Strict release-handoff v2 generation and client/Core parity pass locally.
- The retained `1.1.6` stable pointer is hash-bound to its versioned rollback
  target, and an isolated fixture proves byte-identical A→B→A pointer reversal.
- Release notes and visible client version share the manifest-validated
  package identity.
- Android uses separate direct and store update authorities.
- Windows uses the service-first privilege boundary in current source.
- Linux has a non-root Flutter host and a fail-closed systemd/polkit daemon
  foundation; live connect remains disabled until Core/network rollback proof.
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
| 1 | Clean platform, client, Core and release-index revisions | `PASS_EXACT_CANDIDATE_10_TUPLE` | Candidate.10 binds platform `209b8f4…720`, client `3459438…f5c`, Core `a45d69e…665e` and signed release-index source `fc00b26…317`. Later documentation and Linux source work do not replace that immutable tuple. |
| 2 | Public release-index revision | `PASS_SIGNED_CANDIDATE_10_MANIFEST` | The signed candidate.10 manifest, detached signature, keyring, source tuple and all `19/19` evidence pointers validate. Promotion remains false. |
| 3 | POKROV Core `1.1.0` replacement artifact | `PASS_EXACT_CANDIDATE_ARTIFACTS` | Candidate.10 retains reproducible AAR `ce82f54b…54dd`, DLL `53b5e82a…4652`, unchanged Cronet `8ef1f8bb…a6f7`, exact SBOM/provenance and zero reachable findings in the scanned module roots. |
| 4 | Conditional Linux beta runtime and package | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_IN_CANDIDATE_10` | The current source branch contains the non-root Flutter host plus fail-closed systemd/socket/polkit daemon foundation and typed network-transaction seam. Live Core/TUN, NetworkManager/resolved/nft mutation and rollback, signed packages and clean-VM proof remain absent. Candidate.10 and public facts exclude Linux. |
| 5 | Strict-v2 candidate metadata | `PASS_SIGNED_CANDIDATE_10` | Strict-v2 handoff binds build `4046`, the exact four-source tuple, six artifacts, SBOM, provenance and Windows runtime manifest. |
| 6 | Android exact-candidate build and signer | `PASS_EXACT_ARM64_AND_X86_64_INSTALL` | Production-signed, release/non-debuggable ARM64 APK `9278c09f…572`, `101366934` bytes, and x86_64 APK `ec07ba17…2627`, `109952213` bytes, install and read back byte-identically as `1.2.0+4046`. |
| 7 | Android device matrix | `PASS_CANDIDATE_10_LDPLAYER_AWG2_AWG31; PHYSICAL_MANUAL; MATRIX_OPEN` | Exact candidate.10 LDPlayer AWG2/AWG3.1 tunnel, DNS, selected egress, routes and clean restore pass. Candidate.8 physical results are retained history and do not transfer into candidate.10. Physical Android, active WARP traffic, external IPv6/leak, UDP 53/MTU, broader OEM coverage and endurance remain open. |
| 8 | Windows exact-candidate package | `PASS_EXACT_PACKAGE_IDENTITY; CLEAN_VM_LIVE_NETWORK_OPEN` | Candidate.10 carries the same exact setup/runtime bytes already proven for install, `8/8` file identity, LocalSystem service, authenticated IPC, restart, uninstall and unchanged idle route/DNS on the owner Windows 11 host. Connected TUN/DNS/AWG/egress and clean Windows 10/11 proof remain manual. |
| 9 | Windows unsigned-beta warning and clean-host recovery | `OWNER_ACCEPTED_UNSIGNED_DIRECT_BETA_ONLY; LIVE_RECOVERY_OPEN` | The direct-beta warning/SmartScreen exception is explicit. Authenticode is `NotSigned`; trusted/Store/broad-stable claims remain forbidden. Connected recovery, sleep/reboot/crash, connected uninstall and interactive SmartScreen remain manual. |
| 10 | Hosted cross-repository CI | `CORE_AND_RELEASE_INDEX_PASS; PLATFORM_CLIENT_SKIPPED_BY_OWNER` | Exact Core and release-index jobs execute real steps and pass. Platform/client private jobs stop before product steps under the no-purchase owner-solo exception; they remain skipped, not PASS. |
| 11 | Runtime/public readback and rollback | `NOT_AUTHORIZED` | No tag, public candidate assets, stable catalog pointer, anonymous readback or post-public rollback drill exists. |
| 12 | Promotion and go/no-go | `NO_GO_GATE_F_6_PASS_13_NONPASS_1_FAIL` | Candidate.10 Gate F validates all pointers but remains `NO_GO`; current RU-origin is `FAIL 9/11`. Gate G, public release and stable pointer are not authorized. |

## Next Action Order

1. Publish `dns.pokrov.space` on all four delegated servers, then run the
   guarded Smart-DNS certificate/runtime/server/frontend sequence and actual
   ChatGPT/Gemini/Xbox access, attribution, leak, lifecycle and rollback proof.
2. Pursue new RU route/provider evidence for the bounded NL and RU-SPB path
   failures without repeating unchanged probes.
3. Run exact candidate.10 physical Android and clean Windows live-network,
   recovery and endurance matrices. Finish Linux live Core/TUN ownership,
   NetworkManager/resolved/nft rollback, packaging and VM proof only on a
   successor tuple if Linux is approved for shipment.
4. Complete payment, Operator OIDC/RBAC/action-intent, legal/commercial,
   comparable performance and no-open-P0 attestations for candidate.10.
5. Refresh Gate F only from exact retained results; every skip, inaccessible
   environment and unrun manual row remains non-PASS.
6. Request separate authority for public same-byte candidate publication,
   anonymous readback, rollback drill and promotion.
7. Provision trusted Windows signing later before any signed, Store or
   broad-stable Windows claim.

## Retained History

The previous mixed backlog is preserved as
[2026-08-21-client-release-backlog-snapshot.md](history/2026-08-21-client-release-backlog-snapshot.md).
Its candidate statuses are evidence only.
