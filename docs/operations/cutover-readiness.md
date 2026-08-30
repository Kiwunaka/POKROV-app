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
| New working target | `1.2.0+4046` |
| Continuing source target | `PRE_CANDIDATE_LOCAL` on `POKROV-app/main` |
| Exact signed candidate | `pokrov-1.2.0-candidate.8`; private Actions artifact, promotion false |
| Candidate created | `true`; public release/store/stable pointer remain absent |
| New public cutover | `BLOCKED` |
| Public/store claim | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED` |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed describes the development line; exact candidate.8
identity is read from the signed release-index contract recorded by
`config/cutover-readiness.seed.json`, not duplicated into the development
handoff seed.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Package/version parity | `PASS_LOCAL` | Android and Windows are `1.2.0+4046`; the shared app-shell remains product version `1.2.0`. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_8_TUPLE` | Signed candidate.8 binds platform `241a83b…c39`, client `3459438…f5c`, Core `a45d69e…665e` and release-index source `b242e0a…a8`; the exact local aggregate passes `15/15`. GitHub plan purchases, branch protection and public-repository conversion remain outside the owner-solo 1.2.0 lane. |
| Release index | `PASS_SIGNED_CANDIDATE_8_CONTRACT` | Manifest `f0006cec…a6fbc`, detached signature `5fcae067…24f6` and receipt `4109bb34…1fc` validate. Promotion is false and no tag/public assets/stable switch exist. |
| Core replacement | `PASS_EXACT_CANDIDATE_ARTIFACTS` | Candidate.8 binds Core `a45d69e…665e`, reproducible AAR `ce82f54b…54dd`, DLL `53b5e82a…4652`, unchanged Cronet `8ef1f8bb…a6f7`, SBOM/provenance and zero reachable findings in the scanned module roots. |
| AWG lifecycle and direct DoH lab | `PASS_EXACT_CANDIDATE_8_AWG2_AWG31; SMART_DNS_LIVE_OPEN` | Exact candidate.8 reaches app-confirmed tunnel, DNS and selected egress for AWG2 and AWG3.1 on physical Beeline and LDPlayer. The emulator ordinary control separately fails closed at its origin boundary. Direct/Smart-DNS source and isolated fixture evidence do not prove live service access; foreign frontend APPLY and runtime material remain unauthorized/open. |
| AWG current Windows-origin Core probe | `PASS_EXACT_DLL_IDENTITY_AND_CURRENT_HOST_SERVICE; LIVE_NETWORK_OPEN` | Candidate.8 setup contains exact Core `53b5e82a…4652`; installed `8/8` runtime files, LocalSystem service, authenticated IPC, restart, uninstall and unchanged idle route/DNS pass on the owner Windows 11 host. No connected app/TUN/DNS/AWG/egress or clean-VM result is claimed. |
| External Smart-DNS lab | `PASS_LOCAL_SOURCE_ARTIFACT_AND_DEVICE_STATE; RESOLVER_RUNTIME_PROOF_MISSING` | Exact client `75e82b0…e62` accepts only HTTPS port 443 with exact `/dns-query`, no query/fragment/token, direct DNS and an AI/gaming-service purpose route. Only selected suffix DNS questions use that DoH server; normal final DNS stays unchanged. Selected service connections use the existing direct outbound, explicit user rules retain precedence and invalid state fails closed. Policy parity, analyze and `412/412` tests pass. Exact platform `2d18fd7…f78a` produces byte-identical verified server bundles; operations `ca9eb41…7334` add the tested guarded PLAN/APPLY/ROLLBACK contract. Production-signed 4046 arm64/x86_64 APKs install/read back exactly, and the Huawei/LDPlayer prerequisite/default-off state passes. No dedicated-node PLAN/deploy or live DNS/SNI/service-access/leak/lifecycle/rollback evidence exists. |
| Android LDPlayer/physical source-lab rehearsal | `PASS_4044_INSTALL_SIGNER; PASS_4044_NORMAL_WARP_EGRESS; BLOCKED_4044_AWG_REVERSE_UDP; FAIL_4044_WIFI_AWG_ACTIVATION; FAIL_4043_LDPLAYER_AWG_ACTIVATION; EXACT_CANDIDATE_PENDING` | Working APK `1.2.0+4044`, SHA-256 `7417191b9fab0469e2040ae535a5e51ca34821da9848e3af5a26aaf7a2f04f45`, matched the production certificate and installed on the Huawei. After lab unbind, WARP connected on Beeline and both IP and DNS+egress probes passed. The later no-carrier controls proved server-side AWG2 selection but not client activation: neither device produced AWG packets, the physical app returned disconnected without an Android VPN transport, and LDPlayer either connected a non-VPN fallback or rejected Frankfurt. These ad hoc bytes are not a strict-v2 candidate and do not clear the full physical matrix. |
| Android build-4045 host correction | `PASS_4045_DISCONNECTED_HOST_TRUTH; FAIL_4045_PREDEPLOY_ANDROID_ACTIVATION; FAIL_4045_LDPLAYER_SELECTED_OUTBOUND_EGRESS; EXACT_CANDIDATE_PENDING` | Production-signed build 4045 cold-started honestly disconnected on Huawei and LDPlayer. A bounded physical connect control started the POKROV service but produced no Android VPN transport after about 25 seconds; post-connect UI, DNS and HTTPS were not claimed. LDPlayer separately reached canonical `core_egress_probe_failed`: the selected outbound failed internet proof and POKROV stopped VPN fail-closed. Neither control was AWG-bound. Exact cleanup removed both POKROV services/transports, restored physical Hiddify foreground and kept phone Wi-Fi disabled. The paired platform issuance correction is not deployed. |
| Android build-4046 Smart-DNS state | `PASS_WORKING_4046_SIGNER_AND_DEVICE_STATE; EXACT_CANDIDATE_PENDING` | Production-signed arm64 APK `c7e21ca…a6f9` and x86_64 APK `4beebad0…cd4b` from client `75e82b0…e62` installed/read back byte-identically on Huawei and LDPlayer as release/non-debuggable `1.2.0+4046`. LDPlayer passed the full external Smart-DNS prerequisite/default-off/enable/restore UI state machine; the phone passed exact-package/default-off readback without changing its AdGuard/direct-DNS-off state. No connection or DNS request was started, cleanup left no POKROV service, and these working bytes are not a strict-v2 candidate. |
| Candidate.8 LDPlayer rehearsal | `PASS_EXACT_BYTES_CATALOG_AWG2_AWG31_CLEAN_RESTORE` | Exact x86_64 APK `ec07ba17…2627`, `109952213` bytes, is release/non-debuggable and byte-identical after install. Seven locations display. AWG2/AWG3.1 each confirm tunnel, DNS and selected egress; ordinary egress fails closed. Guarded restore removes lab material/membership and leaves no TUN. This does not replace physical proof. |
| Candidate handoff | `PASS_SIGNED_PRIVATE_CANDIDATE_8` | Strict-v2 handoff binds build `4046`, exact four-source tuple, six artifacts, SBOM, provenance and Windows runtime manifest; promotion remains false. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_8` | Production-signed release/non-debuggable ARM64 `9278c09f…572` and x86_64 `ec07ba17…2627` install/read back byte-identically as `1.2.0+4046` and bind the exact candidate Core. |
| Android device proof | `PASS_NAMED_CANDIDATE_8_ROWS_INCLUDING_EXCLUDED_APP; MATRIX_OPEN` | Physical ordinary/AWG2/AWG3.1, selected-app and inverse excluded-app traffic/bypass, uplink/lifecycle/Doze/standby, Private DNS and WARP fallback/revoke pass. LDPlayer rehearsal passes separately. Active WARP carriage, external IPv6/leak, UDP53/MTU, multi-OEM and endurance remain open. |
| Android OEM limitations | `PASS_ONE_HUAWEI_LIFECYCLE; MULTI_OEM_OPEN` | Screen-off, tile/notification, permission revoke, forced Doze and app standby pass on one exact Huawei. Broader OEM/background coverage and endurance remain manual. |
| Windows package/signing | `PASS_EXACT_CANDIDATE_8_CURRENT_HOST`; signing `SKIPPED_BY_OWNER` | Setup `26ec26d8…4668`, `28929376` bytes, packages exact runtime and passes current-host install/service/authenticated-IPC/restart/uninstall/idle-network restoration. The unsigned direct-beta SmartScreen exception does not permit trusted/Store/broad-stable claims. |
| Windows clean-host proof | `MANUAL_OWNER_TEST` | Connected TUN/DNS/AWG/egress, recovery, connected uninstall and Windows 10/11 clean-VM matrix remain unrun. |
| Linux client | `NOT_SHIPPED_IN_1.2.0` | No Linux artifact, daemon, package, support matrix or release promise belongs to this candidate. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `MANUAL_OWNER_TEST` | Direct terminal-only Raspberry Pi evidence is supporting reachability, not the canonical exact-candidate RU contour or client proof. |
| Hosted CI | `CORE_AND_RELEASE_INDEX_PASS; PLATFORM_CLIENT_SKIPPED_BY_OWNER` | Exact Core and release-index jobs execute and pass. Private platform/client PR jobs stop before product steps under the owner-solo/no-purchase lane and remain skipped, not PASS. |
| Runtime sync | `PASS_EXACT_CANDIDATE_BINDING_AND_ANDROID_EGRESS; WINDOWS_LIVE_OPEN` | Candidate.8 synchronizes the exact AAR/DLL identities. Physical and LDPlayer AWG2/AWG3.1 selected egress pass; ordinary LDPlayer is an origin-specific fail-closed control. Windows live network remains open. |
| Exact-candidate rollback drill | `NOT_RUN` | Authorized portal and client-channel rollback use the same candidate identity; local fixture reversal is not runtime proof. |
| Final go/no-go | `BLOCKED_GATE_F_6_PASS_13_NONPASS_0_FAIL` | Exact candidate.8 Gate F is structurally valid but blocked. Gate G, public release, store object and stable pointer are unauthorized. The Windows signing exception remains scoped to unsigned direct beta and never becomes a trusted signing PASS. |

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
