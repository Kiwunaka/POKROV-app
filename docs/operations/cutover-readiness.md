# Cutover Readiness

Last updated: 2026-09-01

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This checklist contains only the current cutover decision for the `1.2.0`
working target. Dated candidate results live in retained evidence.

## Authority

1. `config/release-handoff.seed.json` owns public release and target identity.
2. `config/cutover-readiness.seed.json` owns the current cutover verdict.
3. `config/runtime-artifacts.seed.json` owns client/Core artifact identity.
4. The platform publishing guide owns delivery and promotion procedure.

If prose disagrees with these machine contracts, stop and reconcile the
contracts. Do not select the most optimistic status.

## Current Decision

| Fact | Current state |
|---|---|
| Canonical lane | `POKROV-app/main` |
| Retained public release | Android and Windows `1.1.6` |
| New working target | `1.2.0+4049` |
| Continuing source target | `PRE_CANDIDATE_LOCAL` on `POKROV-app/main` |
| Exact signed candidate | `pokrov-1.2.0-candidate.17`, app `1.2.0+4049`; private immutable candidate, artifact-only, promotion false and rejected after clean-VM Windows failure |
| Replacement candidate for working target | None. The corrected Windows package is a source-bound pre-candidate; candidate.18, its signed index and receipt do not exist yet. |
| New public cutover | `BLOCKED` |
| Public/store claim | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED` |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed describes the `1.2.0+4049` development line with
Core `cd8f0f4…884d`. Separately generated strict-v2 metadata and the signed
public-index receipt own immutable private candidate.17: platform
`d6898e6…967`, client `977c6ed…108`, Core `cd8f0f4…884d` and release-index
source `2df538c…b17`. Its signed supply validation and exact hosted tuple replay
pass, and its Android/Windows artifact bytes are unchanged from candidate.16.
Clean Windows 11 nevertheless exposed missing VC runtime DLLs and a false
success exit from setup, so candidate.17 is `NO_GO` and cannot be repaired in
place. The corrected Windows pre-candidate passes clean-VM and public 1.1.6
migration checks, but it is not candidate.18 and carries no promotion claim.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Package/version parity | `PASS_EXACT_CANDIDATE_17` | Android and Windows candidate targets are `1.2.0+4049`; the shared app-shell remains product version `1.2.0`. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_17_TUPLE` | Signed candidate.17 binds platform `d6898e6…967`, client `977c6ed…108`, Core `cd8f0f4…884d` and release-index source `2df538c…b17`. GitHub plan purchases and protected private-branch controls remain outside the owner-solo lane. |
| Release index | `PASS_SIGNED_CANDIDATE_17_CONTRACT` | Manifest `bea4774f…db1e`, detached signature `e58419f3…5717`, receipt `bec4c0cc…0ba1`, keyring and six artifact identities validate. Promotion is false and no tag/public assets/stable switch exists. |
| Core replacement | `PASS_EXACT_CANDIDATE_17_ARTIFACTS` | Candidate.17 binds secret-safe Core `cd8f0f4…884d`, reproducible AAR `2a9677d9…c6a69`, DLL `f284fa88…8204`, unchanged Cronet `8ef1f8bb…a6f7` and refreshed SBOM/provenance. |
| AWG lifecycle | `EXACT_ARTIFACT_REHEARSAL_RETAINED; AWG31_EGRESS_FAIL; AWG2_EGRESS_FAIL` | Candidate.17 carries the same exact x86_64 APK bytes as candidate.16. The retained LDPlayer run activates both lab profiles and forms TUN/DNS/routes, but authenticated selected egress fails without false green and cleanup succeeds. Physical runtime remains open. |
| AWG current Windows-origin Core probe | `CANDIDATE_17_WINDOWS_PACKAGE_FAIL; CORRECTED_PRE_CANDIDATE_IDLE_PASS; LIVE_NETWORK_MANUAL` | Candidate.17 contains exact Core DLL `f284fa88…8204` but cannot start it on clean Windows without the omitted VC runtime. Corrected pre-candidate setup `301d72fc…3ddc` passes `11/11`, service/IPC/restart/uninstall and idle restoration; connected TUN/DNS/AWG/egress remains manual. |
| External Smart-DNS lab | `PASS_LIVE_SERVER_ROLLBACK_AND_THREE_ORIGINS; CLIENT_DEFAULT_OFF` | `dns.pokrov.space` is authoritative, the owned `it` frontend/backend and certificate are live, receipt-bound rollback/re-apply passes, and bounded DoH plus ChatGPT/Gemini/Xbox TLS/SNI checks pass from current, Brain and RU origins. Client selection remains disabled and no device/session/leak/load claim transfers. |
| Candidate.17 LDPlayer rehearsal | `PASS_EXACT_DEFAULT; AWG31_AND_AWG2_EGRESS_FAIL; CLEAN_RESTORE` | Exact x86_64 APK `73c43e21…f5ff`, `109951989` bytes, is byte-identical to the rehearsed candidate.16 artifact. Ordinary default traffic passes. Both lab profiles form TUN/DNS/routes but fail authenticated egress and clean up without false green. |
| Candidate handoff | `PASS_SIGNED_PRIVATE_CANDIDATE_17` | Strict-v2 handoff `a7349fc1…8427` binds build `4049`, exact four-source tuple, six artifacts, SBOM, provenance and Windows runtime manifest; output is artifact-only and promotion remains false. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_17_SIGNING; X86_64_AND_ARM64_INSTALL_IDENTITY_PASS` | Candidate.17 carries the same production-signed release/non-debuggable ARM64 `9bcdbe00…cc74` and x86_64 `73c43e21…f5ff` bytes. Both retained installed base APK readbacks are byte-identical; physical runtime remains open. |
| Android device proof | `PASS_CANDIDATE_17_BYTE_IDENTICAL_DEFAULT_LDPLAYER_AND_PHYSICAL_INSTALL; RUNTIME_MATRIX_OPEN` | Candidate.17 reuses the exact rehearsed candidate.16 Android bytes. Ordinary LDPlayer traffic and physical ARM64 install identity therefore remain byte-bound evidence. Physical default/AWG/WARP/per-app/handoff, external IPv6/leak, UDP53/MTU, multi-OEM and endurance remain open. |
| Android OEM limitations | `MANUAL_OWNER_TEST` | Candidate.17 background, screen-off, tile/notification, permission revoke, Doze/standby and broader OEM/endurance coverage remain manual. |
| Windows package/signing | `FAIL_EXACT_CANDIDATE_17_CLEAN_VM`; signing `SKIPPED_BY_OWNER` | Candidate.17 setup `0afaf6e1…276c` omits three required VC runtime DLLs and cannot start its service on clean Windows; setup also returned `0`. Corrected pre-candidate `301d72fc…3ddc` passes the bounded VM gate but is not candidate.18. |
| Windows clean-host proof | `CANDIDATE_17_FAIL; PRE_CANDIDATE_IDLE_AND_MIGRATION_PASS; CONNECTED_NETWORK_MANUAL` | Corrected pre-candidate clean-VM install/service/IPC/restart/uninstall, unchanged idle network and public 1.1.6 migration pass. Connected TUN/DNS/AWG/egress, recovery, connected uninstall, interactive SmartScreen and the broader Windows matrix remain unrun. |
| Linux client | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_IN_CANDIDATE_17` | The non-root Flutter host, typed bounded Unix IPC, `SO_PEERCRED`, polkit, hardened systemd units, supported foundation matrix, secret-free journald envelope and typed transaction seam exist. Live Core/TUN, NetworkManager/resolved/nft mutation and rollback, packages, signing and clean-VM proof remain open. No Linux artifact or 1.2.0 availability claim exists. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `CANDIDATE_17_NOT_RUN; CANDIDATE_16_HISTORY_ONLY` | The retained candidate.16 ten-member RU bundle and owned-Pi install plan do not transfer to candidate.17. No candidate.17 RU run/upload/heartbeat/admin readback exists. |
| Hosted CI | `PASS_EXACT_CANDIDATE_17_HOSTED_REPLAY_AND_INDEX_SIGNING` | Manual release-v2 replay run `33463427737` passed the exact client/platform/Core tuple, and signed release-index run `33463318296` passed. This does not override runtime failures. |
| Runtime sync | `PLATFORM_READINESS_CORRECTION_DEPLOYED; CANDIDATE_17_NOT_PROMOTED` | The bounded managed-profile readiness correction is live on Brain. Candidate.17 remains private, artifact-only and rejected. Physical Android and Windows connected network remain open. |
| Exact-candidate rollback drill | `CANDIDATE_17_NOT_RUN; CANDIDATE_16_HISTORY_ONLY` | The retained candidate.16 disposable reversal does not approve candidate.17. Live pointer/kill rollback plus current/Brain readback and health remain open. |
| Final go/no-go | `NO_GO_EXACT_CANDIDATE_17_WINDOWS_PACKAGING_FAILURE` | Signed supply and exact hosted replay pass, but clean Windows cannot start the candidate.17 service and setup falsely reports success. The corrected package is only a pre-candidate. Gate G, public release, store object and stable pointer remain unauthorized. The Windows signing exception never becomes a trusted signing PASS. |

## Current Cutover Sequence

1. Freeze clean revisions and the release index.
2. Produce exact Core and client artifacts.
3. Generate and validate strict-v2 metadata.
4. Run hosted CI, Android device and Windows clean-host gates. A retained
   candidate must use the manual release-v2 replay with exact full client,
   platform and Core commit SHAs; a run mixing the candidate with current
   promotion lines is drift evidence, not an exact-candidate PASS.
5. Verify Android signing, Windows `SKIPPED_BY_OWNER`, the mandatory SmartScreen warning, SBOM, provenance, checksums and anonymous downloads.
6. Request runtime-sync authority and retain current-origin/brain-origin proof.
7. Add the exact candidate and retained prior stable handoff to the rollback
   catalog, then run the authorized pointer/runtime rollback with retained
   backup, receipt and readback evidence.
8. Issue the evidence-based go/no-go decision.

No later step may convert a missing, manual, blocked or skipped result into
`PASS`.

## Retained History

The previous multi-candidate checklist is preserved as
[2026-08-21-cutover-readiness-snapshot.md](history/2026-08-21-cutover-readiness-snapshot.md).
Its stage statuses are not current approval.
