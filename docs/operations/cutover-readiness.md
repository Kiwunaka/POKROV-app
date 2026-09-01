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
| Exact signed candidate | `pokrov-1.2.0-candidate.20`, app `1.2.0+4049`; private immutable Actions artifact, promotion false, Windows 11 default-path proof bounded as stated below |
| Candidate/current-main boundary | Candidate.20 remains the current candidate. Later client `main` commits do not alter or receive credit for its exact bytes. |
| New public cutover | `BLOCKED` |
| Planned distribution if approved | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED`. No new public claim exists yet. |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed describes the `1.2.0+4049` development line with
Core `cd8f0f4…884d`; its `candidate_created=false` describes continuing `main`,
not the separate signed candidate contract. `config/cutover-readiness.seed.json`
now binds immutable private candidate.20: platform `d6898e6…967`, client
`8ab9815…6e8`, Core `cd8f0f4…884d` and release-index source `61ad0b0…483`.
Candidate.20 passes signed supply and exact hosted replay. Its bounded Windows
11 default path also passes install, ordinary UI to LocalSystem service,
authenticated IPC, TUN, managed DNS, authenticated DE egress, disconnect
rollback, clean uninstall and public-1.1.6 migration. Candidates 17–19 remain
retained immutable failure history and transfer no release credit.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Package/version parity | `PASS_EXACT_CANDIDATE_20` | Android and Windows candidate targets are `1.2.0+4049`; the shared app-shell remains product version `1.2.0`. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_20_TUPLE` | Signed candidate.20 binds platform `d6898e6…967`, client `8ab9815…6e8`, Core `cd8f0f4…884d` and release-index source `61ad0b0…483`. Paid GitHub branch protection remains outside the owner-solo lane. |
| Release index | `PASS_SIGNED_CANDIDATE_20_CONTRACT` | Manifest `046d3312…770a`, detached signature `f5e81d31…90ea`, receipt `47429c2c…9479`, keyring and six artifact identities validate. Promotion is false and no tag/public assets/stable switch exists. |
| Core replacement | `PASS_EXACT_CANDIDATE_20_ARTIFACTS` | Candidate.20 binds Core `cd8f0f4…884d`, reproducible AAR `2a9677d9…c6a69`, DLL `f284fa88…8204`, unchanged Cronet `8ef1f8bb…a6f7`, 352-component SBOM and six-subject provenance. |
| AWG lifecycle | `CANDIDATE_20_NOT_RUN; RETAINED_HISTORY_ONLY` | Older candidate AWG2/AWG3.1 observations do not transfer. Exact candidate.20 Android and Windows protocol/runtime coverage remains open. |
| AWG Windows app/service path | `CANDIDATE_20_DEFAULT_PATH_PASS; AWG_NOT_RUN` | Candidate.20 proves only the Windows 11 default path. AWG2/AWG3.1, sleep/reboot/crash, connected uninstall and broader route/DNS/leak recovery remain non-PASS. |
| External Smart-DNS lab | `PASS_LIVE_SERVER_ROLLBACK_AND_THREE_ORIGINS; CLIENT_DEFAULT_OFF` | `dns.pokrov.space` is authoritative, the owned `it` frontend/backend and certificate are live, receipt-bound rollback/re-apply passes, and bounded DoH plus ChatGPT/Gemini/Xbox TLS/SNI checks pass from current, Brain and RU origins. Client selection remains disabled and no device/session/leak/load claim transfers. |
| Candidate.20 LDPlayer | `NOT_RUN; HOST_TUN_NETWORK_CREDIT_EXCLUDED` | Exact x86_64 APK `d8ae790d…264b1`, `109951989` bytes, is signed but has no candidate.20 install/launch readback. Network results from host-tunneled LDPlayer cannot receive release credit. |
| Candidate handoff | `PASS_SIGNED_PRIVATE_CANDIDATE_20` | Handoff `a8720ce0…081d` binds build `4049`, exact four-source tuple, six artifacts, SBOM, provenance and the `11/11` Windows runtime manifest; output is artifact-only and promotion remains false. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_20_SIGNING; INSTALL_IDENTITY_NOT_RUN` | Five candidate.20 Android artifacts are production-signed. Exact x86_64/ARM64 installed-byte identity and runtime remain open. |
| Android device proof | `NOT_RUN_EXACT_CANDIDATE_20` | Physical Wi-Fi/Beeline default, AWG, WARP, per-app, handoff, IPv6/leak, UDP53/MTU, OEM and endurance coverage remain open. |
| Android OEM limitations | `MANUAL_OWNER_TEST` | Candidate.20 background, screen-off, tile/notification, permission revoke, Doze/standby and broader OEM/endurance coverage remain manual. |
| Windows package/signing | `PASS_EXACT_CANDIDATE_20_WINDOWS11_DEFAULT`; signing `SKIPPED_BY_OWNER` | Setup `330b87cb…587f`, `29140987` bytes, passes `11/11` installed files and the bounded default-path VM result. The direct-beta SmartScreen warning remains mandatory. |
| Windows clean-host proof | `PASS_EXACT_CANDIDATE_20_WINDOWS11_DEFAULT_ONLY` | Ordinary UI, LocalSystem service, authenticated IPC, default TUN/DNS/DE egress, disconnect restoration, clean uninstall and public-1.1.6 migration pass. Windows 10, AWG, recovery, connected uninstall, IPv6/leak and interactive SmartScreen remain open. |
| Linux client | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_IN_CANDIDATE_20` | The non-root UI/system daemon, bounded IPC, polkit and journald exist. A dormant typed NetworkManager/resolved/nft transaction with reverse fault recovery is source-tested but not wired to `connect`; native mutation/restoration, packages, signing and clean-VM proof remain open. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `CANDIDATE_20_NOT_RUN; OLDER_HISTORY_ONLY` | Older RU bundles and Pi plans do not transfer. No candidate.20 authenticated RU-origin app/runtime/admin readback exists. |
| Hosted CI | `PASS_EXACT_CANDIDATE_20_REPLAY_AND_INDEX_SIGNING` | Signed-index run `33509003189` and post-build exact-tuple replay `33511744299` pass real steps for platform `d6898e6…`, client `8ab9815…` and Core `cd8f0f4…`. |
| Runtime sync | `CANDIDATE_20_NOT_PROMOTED` | Candidate.20 remains private and artifact-only. No public runtime switch, stable pointer or post-promotion readback exists. |
| Exact-candidate rollback drill | `CANDIDATE_20_NOT_RUN` | Older reversal evidence does not approve candidate.20. Guarded pointer/runtime rollback plus current/Brain/RU readback and health remain open. |
| Final go/no-go | `BLOCKED_EXACT_CANDIDATE_20_OPEN_GATES` | Signed supply and bounded Windows 11 default proof pass. Gate F is not regenerated; exact Android, remaining Windows, origins, provider/Operator/legal, performance, rollback and final no-open-P0/privacy evidence remain non-PASS. Gate G, public release, Store object and stable pointer are unauthorized. |

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
