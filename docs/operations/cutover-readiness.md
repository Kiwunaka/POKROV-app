# Cutover Readiness

Last updated: 2026-08-28

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
| New working target | `1.2.0+4046` |
| Target state | `PRE_CANDIDATE_LOCAL` |
| Candidate created | `false` |
| New public cutover | `BLOCKED` |
| Public/store claim | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED` |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Package/version parity | `PASS_LOCAL` | Android and Windows are `1.2.0+4046`; the shared app-shell remains product version `1.2.0`. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_LOCAL_EXACT_CORRECTION_TUPLE; PROMOTION_BLOCKED_BY_ACTIONS_BILLING` | Exact clean platform `9383117…64c17`, client `f3d3310…174f` and Core `f44dbe8…f90d` pass the bounded Node `22.14.0` aggregate `15/15`: Flutter `400/400`, cabinet E2E `69/69`, Admin/marketing/Web builds and static performance `9/9`. Report SHA-256 is `57ca9352…f02ed`, with `candidate_proven=false` and promotion `MANUAL_OWNER_TEST`. Hosted PR checks remain billing-blocked; release-index `32f560d…2d4a` is unchanged. |
| Release index | `PASS_PRE_CANDIDATE_CONTRACT; REPLACEMENT_MANIFEST_MISSING` | Release-index `main` retains private signed candidate.4 evidence and the active signing contract. It has no manifest for build `4046`; public readback and promotion remain blocked. |
| Core replacement | `PASS_MIXED_PLATFORM_LOCAL` | Android has two byte-identical `1.1.0` AAR builds from Core `f44dbe8…f90d`, also byte-identical to the prior `54e76bb` AAR and including AWG DNS and Android outer-socket protection; Windows retains exact DLL bytes from `344b317…8f6`. No tag, candidate signing, platform convergence or publication is claimed. |
| AWG lifecycle and direct DoH lab | `PASS_LOCAL_CURRENT_SOURCE_CONTRACT; PASS_CURRENT_ORIGIN_CORE_SERVER; PASS_4044_CONTROL_PLANE; BLOCKED_BY_NETWORK_CURRENT_BEELINE_REVERSE_UDP; FAIL_WORKING_ANDROID_ACTIVATION; PASS_DIRECT_DOH_CELLULAR; EXACT_CANDIDATE_PENDING` | Current platform `50c9d12…dde49`, client `75e82b0…e62` and Core `e8eb772…41a1` pass exact AWG2/AWG3.1 contract sync; report digests are `0caeaba4…eb44` and `3a4c318a…06f`. Ten focused Flutter tests, thirteen Android direct-release JVM tests and thirty-one Core AWG tests pass; the operator-only live Core egress test is skipped without runtime material. This proves source/host contracts, including Android and Windows route-mode generation, but no current Windows artifact or live tunnel. Earlier live alignment v2 passes for AWG2 and randomized-trailer AWG3.1. Build 4044 reached both listeners from physical Beeline, but guarded plain-UDP controls proved that each server received and echoed 3/3 while the phone received 0/3. A later explicit no-carrier readback selected AWG2 for exact physical and LDPlayer identities, while build 4044 on Wi-Fi and build 4043 on LDPlayer emitted no AWG traffic; LDPlayer also rejected the selected Frankfurt location before tunnel start. That second boundary is client activation/fallback, before cryptography. Direct HTTPS DoH resolved all three bounded AI/Games queries; application traffic still uses the VPN target. |
| External Smart-DNS lab | `PASS_LOCAL_SOURCE_ARTIFACT_AND_DEVICE_STATE; RESOLVER_RUNTIME_PROOF_MISSING` | Exact client `75e82b0…e62` accepts only HTTPS port 443 with exact `/dns-query`, no query/fragment/token, direct DNS and an AI/gaming-service purpose route. Only selected suffix DNS questions use that DoH server; normal final DNS stays unchanged. Selected service connections use the existing direct outbound, explicit user rules retain precedence and invalid state fails closed. Policy parity, analyze and `412/412` tests pass. Exact platform `2d18fd7…f78a` produces byte-identical verified server bundles; operations `ca9eb41…7334` add the tested guarded PLAN/APPLY/ROLLBACK contract. Production-signed 4046 arm64/x86_64 APKs install/read back exactly, and the Huawei/LDPlayer prerequisite/default-off state passes. No dedicated-node PLAN/deploy or live DNS/SNI/service-access/leak/lifecycle/rollback evidence exists. |
| Android LDPlayer/physical source-lab rehearsal | `PASS_4044_INSTALL_SIGNER; PASS_4044_NORMAL_WARP_EGRESS; BLOCKED_4044_AWG_REVERSE_UDP; FAIL_4044_WIFI_AWG_ACTIVATION; FAIL_4043_LDPLAYER_AWG_ACTIVATION; EXACT_CANDIDATE_PENDING` | Working APK `1.2.0+4044`, SHA-256 `7417191b9fab0469e2040ae535a5e51ca34821da9848e3af5a26aaf7a2f04f45`, matched the production certificate and installed on the Huawei. After lab unbind, WARP connected on Beeline and both IP and DNS+egress probes passed. The later no-carrier controls proved server-side AWG2 selection but not client activation: neither device produced AWG packets, the physical app returned disconnected without an Android VPN transport, and LDPlayer either connected a non-VPN fallback or rejected Frankfurt. These ad hoc bytes are not a strict-v2 candidate and do not clear the full physical matrix. |
| Android build-4045 host correction | `PASS_4045_DISCONNECTED_HOST_TRUTH; FAIL_4045_PREDEPLOY_ANDROID_ACTIVATION; FAIL_4045_LDPLAYER_SELECTED_OUTBOUND_EGRESS; EXACT_CANDIDATE_PENDING` | Production-signed build 4045 cold-started honestly disconnected on Huawei and LDPlayer. A bounded physical connect control started the POKROV service but produced no Android VPN transport after about 25 seconds; post-connect UI, DNS and HTTPS were not claimed. LDPlayer separately reached canonical `core_egress_probe_failed`: the selected outbound failed internet proof and POKROV stopped VPN fail-closed. Neither control was AWG-bound. Exact cleanup removed both POKROV services/transports, restored physical Hiddify foreground and kept phone Wi-Fi disabled. The paired platform issuance correction is not deployed. |
| Android build-4046 Smart-DNS state | `PASS_WORKING_4046_SIGNER_AND_DEVICE_STATE; EXACT_CANDIDATE_PENDING` | Production-signed arm64 APK `c7e21ca…a6f9` and x86_64 APK `4beebad0…cd4b` from client `75e82b0…e62` installed/read back byte-identically on Huawei and LDPlayer as release/non-debuggable `1.2.0+4046`. LDPlayer passed the full external Smart-DNS prerequisite/default-off/enable/restore UI state machine; the phone passed exact-package/default-off readback without changing its AdGuard/direct-DNS-off state. No connection or DNS request was started, cleanup left no POKROV service, and these working bytes are not a strict-v2 candidate. |
| Candidate handoff | `MISSING` | One strict-v2 handoff binds exact revisions, artifacts and gates. |
| Android artifact/signing | `PASS_WORKING_4046_SIGNER; MISSING_EXACT_CANDIDATE` | Production-signed arm64 and x86_64 working APKs from client `75e82b0…e62` pass package/version/ABI/non-debuggable/signer verification and install/read back byte-identically as `1.2.0+4046`. No strict-v2 candidate binds these bytes. |
| Android device proof | `MANUAL_OWNER_TEST` | Exact-candidate physical matrix passes. |
| Android OEM limitations | `EXPLICIT_MANUAL_GATE` | PB-08 and `AND-BG-001/002/003` plus `AND-VPN-004` cover safe guidance; exact-candidate background, screen-off, lockscreen, notification, tile, permission-revoke and reconnect proof remains manual. |
| Windows package/signing | `MISSING_ARTIFACT`; signing `SKIPPED_BY_OWNER` | Build the final service-first setup; strict-v2 must record the exact unsigned bytes, the `1.2.0` direct-beta-only exception and mandatory SmartScreen warning. |
| Windows clean-host proof | `MANUAL_OWNER_TEST` | TUN/DNS/egress/recovery matrix passes on a clean host. |
| Linux client | `NOT_SHIPPED_IN_1.2.0` | No Linux artifact, daemon, package, support matrix or release promise belongs to this candidate. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `NOT_REQUESTED` | Required only before an explicit RU-origin claim. |
| Hosted CI | `BLOCKED_BY_ACCESS_GITHUB_BILLING` | Replacement PR jobs stop before any step because of the account payment/spending limit. This is neither PASS nor a code failure. |
| Runtime sync | `NOT_AUTHORIZED` | Owner authorizes the exact metadata application. |
| Exact-candidate rollback drill | `NOT_RUN` | Authorized portal and client-channel rollback use the same candidate identity; local fixture reversal is not runtime proof. |
| Final go/no-go | `NO_GO` | Every required exact-candidate gate must be `PASS`; the only accepted non-PASS is the explicit Windows trusted-signing `SKIPPED_BY_OWNER` for the `1.2.0` direct beta, which never becomes a trusted/stable signing claim. |

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
