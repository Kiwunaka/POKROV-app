# Cutover Readiness

Last updated: 2026-09-04

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
| New working target | `1.2.0+4053` |
| Continuing source target | `PRE_CANDIDATE_LOCAL` on `POKROV-app/main` |
| Latest exact candidate | Private signed `pokrov-1.2.0-candidate.32`, app `1.2.0+4053`. Supply and bounded disconnected Windows slices pass, but exact `WIN-001` second-launch focus restoration fails. Candidate.32 is immutable `NO_GO`; Gate F is `NO_GO 2/17/2`. |
| Retained signed-index predecessor | Candidate.31 is immutable signed predecessor history. Candidate.30 and earlier rejected candidates retain their original evidence and verdicts. |
| Candidate/current-main boundary | Candidate.32 binds exact client source `2d6adfc…a1e`. Client commit `76abed9…711` fixes the focus defect and passes bounded source/VM replay, but remains pre-candidate and receives no candidate.32 credit. |
| New public cutover | `NO_GO_GATE_F_2_FAIL`; no public asset, Store object or stable pointer exists |
| Planned distribution if approved | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED`. No new public claim exists yet. |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed describes the `1.2.0+4053` development line with
Core `cd8f0f4…884d`; its `candidate_created=false` describes continuing `main`,
not the separate signed candidate contract. `config/cutover-readiness.seed.json`
now binds private candidate.32: platform `d0dd37c…1a86`, client
`2d6adfc…a1e` and Core `cd8f0f4…884d`. Six build-4053 artifacts exist.
Candidate.32 strict-v2 handoff `df85e2ee…2bef`, refreshed SBOM/provenance and
signed manifest/signature/receipt `b15938e1…a449` / `e63d8ee3…fcf4` /
`7bfaf81f…5a42` validate from release-index source `5d11fd6…53c3`.
The isolated Windows 11 VM proves exact clean install, public `1.1.6`
migration, ordinary UI/authenticated IPC and disconnected service recovery.
The later exact second-launch replay retains singleton and typed forwarding
but fails foreground focus, so Gate F is `NO_GO 2/17/2`. Candidate.32 remains
unpublished and unpromoted; candidate.31 and earlier candidates are history.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Development package/version parity | `PASS_EXACT_CANDIDATE_32_BUILD_4053` | Candidate.32 Android and Windows artifacts are `1.2.0+4053`; the shared app-shell remains product version `1.2.0`. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_32_TUPLE_PRIVATE` | Candidate.32 binds platform `d0dd37c…1a86`, client `2d6adfc…a1e`, Core `cd8f0f4…884d` and signed release-index `5d11fd6…53c3`. Paid GitHub branch protection remains outside the owner-solo lane. |
| Release index | `PASS_EXACT_CANDIDATE_32_ACTIONS_ARTIFACT_ONLY` | Handoff `df85e2ee…2bef`, SBOM/provenance and manifest/signature/receipt `b15938e1…a449` / `e63d8ee3…fcf4` / `7bfaf81f…5a42` validate; signer run `33819350778` passes with promotion false. Public assets remain absent. |
| Core replacement | `PASS_EXACT_CANDIDATE_32_SIGNED_ARTIFACTS` | All candidate.32 Android/Windows artifacts and refreshed SBOM/provenance bind Core `cd8f0f4…884d`; the six hashes and Windows `11/11` manifest validate. |
| AWG lifecycle | `NOT_RUN_EXACT_CANDIDATE_32` | Older Windows and exact-Core Pi results do not transfer to candidate.32's packaged app lifecycle. Android, UDP, IPv6, MTU and endurance remain open. |
| AWG Windows app/service path | `NOT_RUN_EXACT_CANDIDATE_32` | Candidate.32 packaged AWG3.1/AWG2 app/service/Core replay remains open. |
| External Smart-DNS lab | `NOT_RUN_EXACT_CANDIDATE_32; PHYSICAL_AUTHENTICATED_OPEN` | Older Smart-DNS evidence does not transfer. Physical Android, authenticated sessions and leak/load/lifecycle remain open. |
| Candidate.32 LDPlayer | `NOT_RUN; HOST_TUN_NETWORK_CREDIT_EXCLUDED` | Exact x86_64 APK `00e792ab…d4f5`, `109951989` bytes, is signed but has no installed identity/runtime readback. Host-tunneled emulator networking receives no release credit. |
| Candidate handoff | `PASS_EXACT_CANDIDATE_32_STRICT_V2` | Private candidate input `66598d26…0bee` and strict-v2 handoff `df85e2ee…2bef` bind build `4053`, exact sources and six artifacts. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_32_PRIVATE_SIGNING; INSTALL_IDENTITY_NOT_RUN` | Five candidate.32 Android artifacts retain production certificate SHA-256 `0A0602A7…2500`. Exact x86_64/ARM64 installed-byte identity and runtime remain open. |
| Android device proof | `NOT_RUN_EXACT_CANDIDATE_32` | Physical Wi-Fi/Beeline default, AWG, WARP, per-app, handoff, IPv6/leak, UDP53/MTU, OEM and endurance coverage remain open. |
| Android OEM limitations | `MANUAL_OWNER_TEST` | Candidate.32 background, screen-off, tile/notification, permission revoke, Doze/standby and broader OEM/endurance coverage remain manual. |
| Windows package/signing | `PASS_EXACT_CANDIDATE_32_SIGNED_SUPPLY_AND_11_OF_11`; signing `SKIPPED_BY_OWNER` | Setup `22689e3e…0574`, `29154647` bytes, binds exact client source `2d6adfc…a1e`. SmartScreen warning remains mandatory. |
| Windows disconnected install/migration/recovery | `PASS_EXACT_CANDIDATE_32_BOUNDED` | Isolated Windows 11 proves clean install, public `1.1.6` migration, `11/11`, ordinary UI/authenticated IPC, disconnected automatic service recovery and unchanged network contour. |
| Windows second-launch focus | `FAIL_EXACT_CANDIDATE_32_WIN_001` | Plain and typed second launches exit `0`, retain one original process and forward activation, but neither restores foreground focus. Client `76abed9…711` fixes the defect only in successor source/VM pre-candidate evidence. |
| Linux client | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_SHIPPED_IN_CANDIDATE_32` | The non-root UI/system daemon, bounded IPC, polkit and journald exist. The typed NetworkManager/resolved/nft transaction remains source-only and not wired to `connect`; native mutation/restoration, packages, signing and clean-VM proof remain open. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `BOUNDED_CORE_SLICE_PASS; FULL_CANDIDATE_32_NOT_RUN` | Exact-Core AWG3.1/AWG2 direct-RU Pi checks pass, but no full candidate.32 authenticated RU-origin aggregate exists. |
| Hosted CI | `MIXED_EXACT_CANDIDATE_32_7_PASS_3_BLOCKED_BY_ACCESS` | Seven of ten exact-SHA jobs pass. Three platform/client jobs have zero executed steps because of GitHub billing access and remain `BLOCKED_BY_ACCESS`, not PASS. |
| Runtime sync | `CANDIDATE_32_PRIVATE_NOT_PROMOTED` | Candidate.32 remains private. No public runtime switch, stable pointer or post-promotion readback exists. |
| Exact-candidate rollback drill | `PASS_LOCAL_FIXTURE; LIVE_NOT_AUTHORIZED` | Candidate.32 source-owned disposable A→B→A reversal is byte-identical. Live pointer/runtime rollback and current/Brain/RU readback remain open. |
| Final go/no-go | `NO_GO_GATE_F_2_PASS_17_NON_PASS_2_FAIL` | Exact candidate.32 Gate F is `NO_GO` because Gates A–E/mandatory STOP-SHIP fail on `WIN-001`. Gate G, public release, Store object and stable pointer are unauthorized. |

## Current Cutover Sequence

1. Merge the validated Windows focus correction, refresh the platform release
   truth and create a newly numbered exact candidate from the frozen tuple.
2. Run that successor's connected contention, managed TUN/DNS/egress,
   recovery and connected-uninstall checks in the isolated Windows VM.
3. Run Android device and the remaining Windows gates. A retained
   candidate must use the manual release-v2 replay with exact full client,
   platform and Core commit SHAs; a run mixing the candidate with current
   promotion lines is drift evidence, not an exact-candidate PASS.
4. Retain current-origin, Brain-origin and RU-origin proof before requesting runtime-sync authority.
5. Add the exact candidate and retained prior stable handoff to the rollback
   catalog, then run the authorized pointer/runtime rollback with retained
   backup, receipt and readback evidence.
6. Issue the evidence-based go/no-go decision. Only a generated GO may proceed
   to anonymous public downloads and stable promotion.

No later step may convert a missing, manual, blocked or skipped result into
`PASS`.

## Retained History

The previous multi-candidate checklist is preserved as
[2026-08-21-cutover-readiness-snapshot.md](history/2026-08-21-cutover-readiness-snapshot.md).
Its stage statuses are not current approval.
