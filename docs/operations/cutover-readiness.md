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
| New working target | `1.2.0+4047` |
| Continuing source target | `PRE_CANDIDATE_LOCAL` on `POKROV-app/main` |
| Exact signed candidate | `pokrov-1.2.0-candidate.10`; private Actions artifact, promotion false |
| Candidate created | `true`; public release/store/stable pointer remain absent |
| New public cutover | `BLOCKED` |
| Public/store claim | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED` |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed now describes the `1.2.0+4047` development line
with Core `cd8f0f4…884d`; exact candidate.10
identity is read from the signed release-index contract recorded by
`config/cutover-readiness.seed.json`, not duplicated into the development
handoff seed.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Package/version parity | `PASS_LOCAL_PRE_CANDIDATE` | Android and Windows development targets are `1.2.0+4047`; the shared app-shell remains product version `1.2.0`. Exact candidate.10 remains immutable at `1.2.0+4046`. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_10_TUPLE` | Signed candidate.10 binds platform `209b8f4…720`, client `3459438…f5c`, Core `a45d69e…665e` and release-index source `fc00b26…317`. Later documentation and Linux source commits do not change that immutable tuple. GitHub plan purchases and branch protection remain outside the owner-solo lane. |
| Release index | `PASS_SIGNED_CANDIDATE_10_CONTRACT` | The signed manifest, detached signature, keyring, source tuple and all `19/19` evidence pointers validate. Promotion is false and no tag/public assets/stable switch exists. |
| Core replacement | `PASS_EXACT_CANDIDATE_10_ARTIFACTS; SUCCESSOR_PRE_CANDIDATE_LOCAL` | Candidate.10 remains bound to Core `a45d69e…665e`. The successor development line binds secret-safe Core `cd8f0f4…884d`, reproducible AAR `2a9677d9…c6a69`, DLL `f284fa88…8204`, unchanged Cronet `8ef1f8bb…a6f7` and refreshed SBOM/provenance; it has no transferred candidate/device/VM claim. |
| AWG lifecycle and direct DoH lab | `PASS_EXACT_CANDIDATE_10_LDPLAYER_AWG2_AWG31; PHYSICAL_MANUAL; SMART_DNS_LIVE_OPEN` | Exact candidate.10 LDPlayer reaches app-confirmed tunnel, DNS and selected egress for AWG2 and AWG3.1 and restores cleanly. Candidate.8 physical results remain history and do not transfer. The Smart-DNS client configuration persists on the exact APK, but live DoH/service access is not run. |
| AWG current Windows-origin Core probe | `PASS_EXACT_DLL_IDENTITY_AND_CURRENT_HOST_SERVICE; LIVE_NETWORK_OPEN` | Candidate.10 contains exact Core `53b5e82a…4652`; installed `8/8` runtime files, LocalSystem service, authenticated IPC, restart, uninstall and unchanged idle route/DNS pass on the owner Windows 11 host. No connected app/TUN/DNS/AWG/egress or clean-VM result is claimed. |
| External Smart-DNS lab | `PASS_LOCAL_SOURCE_ARTIFACT_AND_EXACT_CLIENT_STATE; AUTHORITATIVE_DNS_0_OF_4` | Exact client configuration, strict policy, byte-identical server bundle and guarded PLAN/APPLY/ROLLBACK tooling are ready. The foreign frontend transport and rollback path pass, but all four delegated Timeweb servers still return `NXDOMAIN` for `dns.pokrov.space`. Certificate, resolver material, server/frontend route APPLY and ChatGPT/Gemini/Xbox access remain `NOT_RUN`. |
| Candidate.10 LDPlayer rehearsal | `PASS_EXACT_BYTES_CATALOG_AWG2_AWG31_SMART_DNS_CONFIG_CLEAN_RESTORE` | Exact x86_64 APK `ec07ba17…2627`, `109952213` bytes, is release/non-debuggable and byte-identical after install. AWG2/AWG3.1 tunnel, DNS and selected egress pass; Smart-DNS configuration persistence passes without a live request. Cleanup restores default state and leaves no TUN. This does not replace physical proof. |
| Candidate handoff | `PASS_SIGNED_PRIVATE_CANDIDATE_10` | Strict-v2 handoff binds build `4046`, exact four-source tuple, six artifacts, SBOM, provenance and Windows runtime manifest; promotion remains false. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_10` | Production-signed release/non-debuggable ARM64 `9278c09f…572` and x86_64 `ec07ba17…2627` install/read back byte-identically as `1.2.0+4046` and bind the exact candidate Core. |
| Android device proof | `PASS_CANDIDATE_10_LDPLAYER; PHYSICAL_MANUAL; MATRIX_OPEN` | Exact candidate.10 LDPlayer AWG2/AWG3.1 and clean restore pass. Physical Android, active WARP carriage, external IPv6/leak, UDP53/MTU, multi-OEM and endurance remain open; candidate.8 physical proof is not promoted to candidate.10. |
| Android OEM limitations | `MANUAL_OWNER_TEST` | Candidate.10 background, screen-off, tile/notification, permission revoke, Doze/standby and broader OEM/endurance coverage remain manual. |
| Windows package/signing | `PASS_EXACT_CANDIDATE_10_CURRENT_HOST`; signing `SKIPPED_BY_OWNER` | The exact setup/runtime bytes pass current-host install/service/authenticated-IPC/restart/uninstall/idle-network restoration. The unsigned direct-beta SmartScreen exception does not permit trusted/Store/broad-stable claims. |
| Windows clean-host proof | `MANUAL_OWNER_TEST` | Connected TUN/DNS/AWG/egress, recovery, connected uninstall and Windows 10/11 clean-VM matrix remain unrun. |
| Linux client | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_IN_CANDIDATE_10` | The non-root Flutter host, typed bounded Unix IPC, `SO_PEERCRED`, polkit, hardened systemd units, supported foundation matrix, secret-free journald envelope and typed transaction seam exist on the successor source branch. Live Core/TUN, NetworkManager/resolved/nft mutation and rollback, packages, signing and clean-VM proof remain open. No Linux artifact or 1.2.0 availability claim exists. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `MANUAL_OWNER_TEST` | Direct terminal-only Raspberry Pi evidence is supporting reachability, not the canonical exact-candidate RU contour or client proof. |
| Hosted CI | `CORE_AND_RELEASE_INDEX_PASS; PLATFORM_CLIENT_SKIPPED_BY_OWNER` | Exact Core and release-index jobs execute and pass. Private platform/client PR jobs stop before product steps under the owner-solo/no-purchase lane and remain skipped, not PASS. |
| Runtime sync | `PASS_EXACT_CANDIDATE_BINDING_AND_LDPLAYER_EGRESS; PHYSICAL_AND_WINDOWS_LIVE_OPEN` | Candidate.10 synchronizes the exact AAR/DLL identities. LDPlayer AWG2/AWG3.1 selected egress passes; physical Android and Windows live network remain open. |
| Exact-candidate rollback drill | `NOT_RUN` | Authorized portal and client-channel rollback use the same candidate identity; local fixture reversal is not runtime proof. |
| Final go/no-go | `NO_GO_GATE_F_6_PASS_13_NONPASS_1_FAIL` | Exact candidate.10 Gate F validates all pointers but remains `NO_GO`; RU-origin is the explicit failure. Gate G, public release, store object and stable pointer are unauthorized. The Windows signing exception remains scoped to unsigned direct beta and never becomes a trusted signing PASS. |

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
