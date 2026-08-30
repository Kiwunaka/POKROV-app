# Cutover Readiness

Last updated: 2026-08-30

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
| Exact signed candidate | `pokrov-1.2.0-candidate.13`, app `1.2.0+4049`; private internal candidate, artifact-only and promotion false |
| Replacement candidate for working target | Signed release-index `true`; source seed remains `false`; public release/store/stable pointer remain absent |
| New public cutover | `BLOCKED` |
| Public/store claim | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED` |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed describes the `1.2.0+4049` development line with
Core `cd8f0f4…884d`. Separately generated strict-v2 metadata and the signed
public-index receipt own immutable private candidate.13; the seed does not
duplicate that candidate contract. Candidate.13 passes bounded LDPlayer
AWG 3.1 -> AWG2 -> default/Auto lifecycle evidence, but Gate F is not generated
without its exact physical ARM64 install binding. Older Gate F/device/Windows
results remain history and do not authorize candidate.13.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Package/version parity | `PASS_EXACT_CANDIDATE_13` | Android and Windows candidate targets are `1.2.0+4049`; the shared app-shell remains product version `1.2.0`. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_13_TUPLE` | Signed candidate.13 binds platform `7d983c0…e8d`, client `ce2581d…168`, Core `cd8f0f4…884d`, signed release-index source `440f3be…c94` and receipt source `289e887…de8f`. GitHub plan purchases and branch protection remain outside the owner-solo lane. |
| Release index | `PASS_SIGNED_CANDIDATE_13_CONTRACT` | Manifest `b8a10cf8…190c`, detached signature `ede7844c…0e4d`, receipt `fc3b1319…b295`, keyring and six artifact identities validate. Promotion is false and no tag/public assets/stable switch exists. |
| Core replacement | `PASS_EXACT_CANDIDATE_13_ARTIFACTS` | Candidate.13 binds secret-safe Core `cd8f0f4…884d`, reproducible AAR `2a9677d9…c6a69`, DLL `f284fa88…8204`, unchanged Cronet `8ef1f8bb…a6f7` and refreshed SBOM/provenance. |
| AWG lifecycle and direct DoH lab | `PASS_EXACT_CANDIDATE_13_LDPLAYER_WARM_LIFECYCLE; PHYSICAL_MANUAL; SMART_DNS_LIVE_OPEN` | Exact candidate.13 LDPlayer passes AWG 3.1, warm AWG2 and warm default/Auto in one app process with runtime-profile identity, tunnel, managed DNS, authenticated egress and clean restore. Physical Android remains manual. Smart-DNS live service/access is still open. |
| AWG current Windows-origin Core probe | `CANDIDATE_13_PACKAGE_IDENTITY_PASS; LIVE_HOST_MANUAL` | Candidate.13 contains exact Core DLL `f284fa88…8204` and an `8/8` runtime manifest. Older current-host install/service evidence belongs to different bytes; candidate.13 install, IPC, connected TUN/DNS/AWG/egress, recovery, uninstall and clean-VM proof are manual. |
| External Smart-DNS lab | `PASS_LOCAL_SOURCE_ARTIFACT_AND_EXACT_CLIENT_STATE; AUTHORITATIVE_DNS_0_OF_4` | Exact client configuration, strict policy, byte-identical server bundle and guarded PLAN/APPLY/ROLLBACK tooling are ready. The foreign frontend transport and rollback path pass, but all four delegated Timeweb servers still return `NXDOMAIN` for `dns.pokrov.space`. Certificate, resolver material, server/frontend route APPLY and ChatGPT/Gemini/Xbox access remain `NOT_RUN`. |
| Candidate.13 LDPlayer rehearsal | `PASS_EXACT_BYTES_AWG31_AWG2_DEFAULT_WARM_LIFECYCLE_CLEAN_RESTORE` | Exact x86_64 APK `73c43e21…f5ff`, `109951989` bytes, is release/non-debuggable and byte-identical after install. AWG 3.1 -> AWG2 -> ordinary Auto passes in one process. Cleanup restores default/no-lab/no-VPN state. This does not replace physical proof. |
| Candidate handoff | `PASS_SIGNED_PRIVATE_CANDIDATE_13` | Strict-v2 handoff binds build `4049`, exact four-source tuple, six artifacts, SBOM, provenance and Windows runtime manifest; output is artifact-only and promotion remains false. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_13_SIGNING; X86_64_INSTALL_PASS; ARM64_INSTALL_OPEN` | Production-signed release/non-debuggable ARM64 `9bcdbe00…cc74` and x86_64 `73c43e21…f5ff` bind the exact candidate Core. The x86_64 install reads back byte-identically; exact ARM64 physical install remains manual. |
| Android device proof | `PASS_CANDIDATE_13_LDPLAYER; PHYSICAL_MANUAL; MATRIX_OPEN` | Exact candidate.13 LDPlayer warm lifecycle and clean restore pass. Physical Android, active WARP carriage, external IPv6/leak, UDP53/MTU, multi-OEM and endurance remain open; older physical proof does not transfer. |
| Android OEM limitations | `MANUAL_OWNER_TEST` | Candidate.13 background, screen-off, tile/notification, permission revoke, Doze/standby and broader OEM/endurance coverage remain manual. |
| Windows package/signing | `PASS_EXACT_CANDIDATE_13_PACKAGE_IDENTITY`; signing `SKIPPED_BY_OWNER` | Setup `0afaf6e1…276c`, `28932793` bytes, and `8/8` manifest identity pass. The unsigned direct-beta SmartScreen exception does not permit trusted/Store/broad-stable claims; exact host runtime remains manual. |
| Windows clean-host proof | `MANUAL_OWNER_TEST` | Connected TUN/DNS/AWG/egress, recovery, connected uninstall and Windows 10/11 clean-VM matrix remain unrun. |
| Linux client | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_IN_CANDIDATE_13` | The non-root Flutter host, typed bounded Unix IPC, `SO_PEERCRED`, polkit, hardened systemd units, supported foundation matrix, secret-free journald envelope and typed transaction seam exist. Live Core/TUN, NetworkManager/resolved/nft mutation and rollback, packages, signing and clean-VM proof remain open. No Linux artifact or 1.2.0 availability claim exists. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `MANUAL_OWNER_TEST` | Direct terminal-only Raspberry Pi evidence is supporting reachability, not the canonical exact-candidate RU contour or client proof. |
| Hosted CI | `CORE_EXACT_COMMIT_AND_RELEASE_INDEX_PASS; PLATFORM_CLIENT_SKIPPED_BY_OWNER` | Exact Core commit checks and candidate.13 release-index signer execute and pass. Private platform/client jobs stop before product steps under the owner-solo/no-purchase lane and remain non-PASS. |
| Runtime sync | `NOT_REQUESTED; LDPLAYER_EGRESS_PASS; PHYSICAL_AND_WINDOWS_LIVE_OPEN` | Candidate.13 runtime metadata was not synced to production. Exact LDPlayer AWG 3.1/AWG2/default egress passes; physical Android and Windows live network remain open. |
| Exact-candidate rollback drill | `NOT_RUN` | Authorized portal and client-channel rollback use the same candidate identity; local fixture reversal is not runtime proof. |
| Final go/no-go | `GATE_F_NOT_RUN_MISSING_EXACT_ARM64_INSTALL_BINDING` | Candidate.13 Gate F is not generated because its required exact physical ARM64 install binding is absent. Current/Brain/RU origin refresh and remaining manual rows are non-PASS. Gate G, public release, store object and stable pointer are unauthorized. The Windows signing exception never becomes a trusted signing PASS. |

## Current Cutover Sequence

1. Freeze clean revisions and the release index.
2. Produce exact Core and client artifacts.
3. Generate and validate strict-v2 metadata.
4. Run hosted CI, Android device and Windows clean-host gates.
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
