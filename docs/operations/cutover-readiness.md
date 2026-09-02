# Cutover Readiness

Last updated: 2026-09-02

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
| New working target | `1.2.0+4051` |
| Continuing source target | `PRE_CANDIDATE_LOCAL` on `POKROV-app/main` |
| Latest exact candidate | `pokrov-1.2.0-candidate.21`, app `1.2.0+4050`; six signed-private artifacts and bounded Windows 11 PASS evidence retained, but immutable `NO_GO` because its service lacks the rejected-session availability correction |
| Retained signed-index predecessor | Candidate.20 is immutable `NO_GO`; its evidence does not alter candidate.21 or receive current PASS credit. |
| Candidate/current-main boundary | Candidate.21 binds exact client `1e164586…cadb`; later `main` commits do not alter or receive credit for its bytes. |
| New public cutover | `BLOCKED_NO_PROMOTABLE_CANDIDATE`; build-4051 successor not created |
| Planned distribution if approved | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED`. No new public claim exists yet. |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed describes the `1.2.0+4051` development line with
Core `cd8f0f4…884d`; its `candidate_created=false` describes continuing `main`,
not the separate signed candidate contract. `config/cutover-readiness.seed.json`
now binds local private candidate.21: platform `e2608130…32c3`, client
`1e164586…cadb` and Core `cd8f0f4…884d`. Six build-4050 artifacts exist. The
exact Windows setup upgrades candidate.20's retained committed journal to
`clean`, validates `11/11` files, starts the ordinary UI and LocalSystem
service, reaches Germany through `sing-tun`, changes route/DNS and restores
egress, route, DNS and adapter fingerprints/counts exactly to the RU baseline
after disconnect. Candidate.21 strict-v2 handoff `07e0009c…55e9`, refreshed
SBOM/provenance and signed manifest/signature/receipt `ce0b8586…3dc6` /
`ef474e6e…7a58` / `aaa027cc…926f` validate from release-index source
`cae911e…`. It remains unpublished and unpromoted. Its exact production service
loop can terminate after a rejected pre-hello client session, while only later
client `main` contains the correction; candidate.21 is therefore immutable
`NO_GO`. Candidate.20 and candidates 17–19 remain retained failure history.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Development package/version parity | `PASS_PRE_CANDIDATE_4051` | Android and Windows source targets are `1.2.0+4051`; the shared app-shell remains product version `1.2.0`. Rejected candidate.21 retains its exact build `4050` identity. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_21_TUPLE_PRIVATE` | Candidate.21 binds platform `e2608130…32c3`, client `1e164586…cadb` and Core `cd8f0f4…884d`; hosted client main run `33576468801` passes. Paid GitHub branch protection remains outside the owner-solo lane. |
| Release index | `PASS_EXACT_CANDIDATE_21_ACTIONS_ARTIFACT_ONLY` | Handoff `07e0009c…`, SBOM/provenance and manifest/signature/receipt `ce0b8586…` / `ef474e6e…` / `aaa027cc…` validate; signer run `33586752995` passes with promotion false. Public assets remain absent. |
| Core replacement | `PASS_EXACT_CANDIDATE_21_SIGNED_ARTIFACTS` | All candidate.21 Android/Windows artifacts and refreshed SBOM/provenance bind Core `cd8f0f4…884d`; the six hashes and Windows `11/11` manifest validate. |
| AWG lifecycle | `CANDIDATE_21_NOT_RUN; RETAINED_HISTORY_ONLY` | Older candidate AWG2/AWG3.1 observations do not transfer. Exact candidate.21 Android and Windows protocol/runtime coverage remains open. |
| AWG Windows app/service path | `CANDIDATE_21_NOT_RUN` | Candidate.21 proves only the default Windows path and upgrade-time recovery. AWG2/AWG3.1 plus fresh in-place service-restart recovery remain open. |
| External Smart-DNS lab | `PASS_LIVE_SERVER_ROLLBACK_AND_THREE_ORIGINS; CLIENT_DEFAULT_OFF` | `dns.pokrov.space` is authoritative, the owned `it` frontend/backend and certificate are live, receipt-bound rollback/re-apply passes, and bounded DoH plus ChatGPT/Gemini/Xbox TLS/SNI checks pass from current, Brain and RU origins. Client selection remains disabled and no device/session/leak/load claim transfers. |
| Candidate.21 LDPlayer | `NOT_RUN; HOST_TUN_NETWORK_CREDIT_EXCLUDED` | Exact x86_64 APK `fc6da2ca…51e5`, `109951989` bytes, is signed but has no candidate.21 install/launch readback. Host-tunneled emulator networking receives no release credit. |
| Candidate handoff | `PASS_EXACT_CANDIDATE_21_STRICT_V2` | Private creation manifest `c79eb481…31d6` and strict-v2 handoff `07e0009c…55e9` bind build `4050`, exact sources and six artifacts. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_21_PRIVATE_SIGNING; INSTALL_IDENTITY_NOT_RUN` | Five candidate.21 Android artifacts retain production certificate SHA-256 `0A0602A7…2500`. Exact x86_64/ARM64 installed-byte identity and runtime remain open. |
| Android device proof | `NOT_RUN_EXACT_CANDIDATE_21` | Physical Wi-Fi/Beeline default, AWG, WARP, per-app, handoff, IPv6/leak, UDP53/MTU, OEM and endurance coverage remain open. |
| Android OEM limitations | `MANUAL_OWNER_TEST` | Candidate.21 background, screen-off, tile/notification, permission revoke, Doze/standby and broader OEM/endurance coverage remain manual. |
| Windows package/signing | `PASS_EXACT_CANDIDATE_21_PRIVATE_UPGRADE_DEFAULT_RUNTIME`; signing `SKIPPED_BY_OWNER` | Setup `87f90be1…dff3`, `29143633` bytes, validates `11/11`, upgrade-time startup recovery and the bounded default path. Fresh in-place service-restart recovery and the remaining matrix stay open; SmartScreen warning is mandatory. |
| Windows clean-host proof | `PASS_EXACT_CANDIDATE_21_BOUNDED_WINDOWS11` | Ordinary UI/LocalSystem service, upgrade recovery, default TUN/route/DNS/DE egress and exact RU baseline restoration pass. This is not fresh-profile, Windows 10 or full recovery-matrix proof. |
| Linux client | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_SHIPPED_IN_CANDIDATE_21` | The non-root UI/system daemon, bounded IPC, polkit and journald exist. A dormant typed NetworkManager/resolved/nft transaction with reverse fault recovery is source-tested but not wired to `connect`; native mutation/restoration, packages, signing and clean-VM proof remain open. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `CANDIDATE_21_NOT_RUN; OLDER_HISTORY_ONLY` | Older RU bundles and Pi plans do not transfer. No candidate.21 authenticated RU-origin app/runtime/admin readback exists. |
| Hosted CI | `PASS_EXACT_CLIENT_AND_SIGNER_CHAIN` | Client main run `33576468801`, release-index source run `33586691099`, signer run `33586752995` and receipt run `33586988337` pass for the exact candidate.21 tuple. |
| Runtime sync | `CANDIDATE_21_PRIVATE_NOT_PROMOTED` | Candidate.21 remains local private. No public runtime switch, stable pointer or post-promotion readback exists. |
| Exact-candidate rollback drill | `CANDIDATE_21_NOT_RUN` | Older reversal evidence does not approve candidate.21. Guarded pointer/runtime rollback plus current/Brain/RU readback and health remain open. |
| Final go/no-go | `NO_GO_EXACT_CANDIDATE_21_SERVICE_AVAILABILITY` | Its last digest-bound Gate F snapshot is `BLOCKED 5/14/0`; the later-confirmed production service-loop defect independently rejects candidate.21. Gate G, public release, Store object and stable pointer are unauthorized. |

## Current Cutover Sequence

1. Promote the build-4051 release-prep contract and freeze the corrected client
   source with current platform and Core revisions.
2. Build and bind candidate.22 without rewriting candidate.21. Verify Android
   signing, Windows `SKIPPED_BY_OWNER`, the mandatory SmartScreen warning,
   SBOM, provenance and checksums.
3. Install the exact successor setup in the isolated Windows VM and prove
   rejected-session continuity plus connected service-restart recovery.
4. Run Android device and the remaining Windows clean-host gates. A retained
   candidate must use the manual release-v2 replay with exact full client,
   platform and Core commit SHAs; a run mixing the candidate with current
   promotion lines is drift evidence, not an exact-candidate PASS.
5. Retain current-origin, Brain-origin and RU-origin proof before requesting runtime-sync authority.
6. Add the exact candidate and retained prior stable handoff to the rollback
   catalog, then run the authorized pointer/runtime rollback with retained
   backup, receipt and readback evidence.
7. Issue the evidence-based go/no-go decision. Only a generated GO may proceed
   to anonymous public downloads and stable promotion.

No later step may convert a missing, manual, blocked or skipped result into
`PASS`.

## Retained History

The previous multi-candidate checklist is preserved as
[2026-08-21-cutover-readiness-snapshot.md](history/2026-08-21-cutover-readiness-snapshot.md).
Its stage statuses are not current approval.
