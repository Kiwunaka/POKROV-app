# Cutover Readiness

Last updated: 2026-09-03

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
| Latest exact candidate | Private signed `pokrov-1.2.0-candidate.25`, app `1.2.0+4053`; signed supply and the bounded Windows clean-host gate pass. A later current-source precursor exposed an in-place-upgrade packaging defect, so candidate.25 remains immutable and non-promotable. Gate F remains `BLOCKED 5/14/0`. |
| Retained signed-index predecessor | Candidate.24 is immutable signed predecessor history; candidate.23 is immutable `NO_GO` for serial-pipe contention. |
| Candidate/current-main boundary | Candidate.25 binds exact client artifact source `54259b0…34b2`; candidate.27 failure and corrected candidate.28 precursor evidence belong to later current source and do not alter or receive candidate.25 runtime credit. |
| New public cutover | `BLOCKED_GATE_F_14_NON_PASS`; no public asset, Store object or stable pointer exists |
| Planned distribution if approved | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED`. No new public claim exists yet. |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed describes the `1.2.0+4053` development line with
Core `cd8f0f4…884d`; its `candidate_created=false` describes continuing `main`,
not the separate signed candidate contract. `config/cutover-readiness.seed.json`
now binds private candidate.25: platform `883cd10…ffd4`, client
`54259b0…34b2` and Core `cd8f0f4…884d`. Six build-4053 artifacts exist.
Candidate.25 strict-v2 handoff `b65b9e7e…2908`, refreshed SBOM/provenance and
signed manifest/signature/receipt `7161bae7…29b6` / `f83cf5ac…3d14` /
`2c18b318…d2cf` validate from release-index source `18d9cb4…`. Its Gate F is
`BLOCKED 5/14/0`; the bounded exact Windows clean-host gate passes, while
connected Windows and exact Android runtime are not yet proved. It
remains unpublished and unpromoted. Candidate.23 is
therefore immutable `NO_GO`. Candidate.22 and earlier rejected
candidates remain retained history.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Development package/version parity | `PASS_EXACT_CANDIDATE_25_BUILD_4053` | Candidate.25 Android and Windows artifacts are `1.2.0+4053`; the shared app-shell remains product version `1.2.0`. Rejected candidate.23 retains its historical build `4052` identity. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_25_TUPLE_PRIVATE` | Candidate.25 binds platform `883cd10…ffd4`, client `54259b0…34b2`, Core `cd8f0f4…884d` and release-index `18d9cb4…62c`; exact attached hosted checks pass. Paid GitHub branch protection remains outside the owner-solo lane. |
| Release index | `PASS_EXACT_CANDIDATE_25_ACTIONS_ARTIFACT_ONLY` | Handoff `b65b9e7e…2908`, SBOM/provenance and manifest/signature/receipt `7161bae7…29b6` / `f83cf5ac…3d14` / `2c18b318…d2cf` validate; signer run `33709201344` passes with promotion false. Public assets remain absent. |
| Core replacement | `PASS_EXACT_CANDIDATE_25_SIGNED_ARTIFACTS` | All candidate.25 Android/Windows artifacts and refreshed SBOM/provenance bind Core `cd8f0f4…884d`; the six hashes and Windows `11/11` manifest validate. |
| AWG lifecycle | `NOT_RUN_EXACT_CANDIDATE_25` | Older Windows results and the exact-Core Pi slice do not transfer to the packaged candidate.25 app lifecycle. Android, UDP, IPv6, MTU and endurance remain open. |
| AWG Windows app/service path | `NOT_RUN_EXACT_CANDIDATE_25` | Guarded candidate.25 AWG3.1/AWG2 app/service/Core replay remains open. |
| External Smart-DNS lab | `NOT_RUN_EXACT_CANDIDATE_25; PHYSICAL_AUTHENTICATED_OPEN` | Older Smart-DNS evidence does not transfer. Physical Android, authenticated sessions and leak/load/lifecycle remain open. |
| Candidate.25 LDPlayer | `NOT_RUN; HOST_TUN_NETWORK_CREDIT_EXCLUDED` | Exact x86_64 APK `7bcdc01e…9d7a`, `109951989` bytes, is signed but has no candidate.25 install/launch readback. Host-tunneled emulator networking receives no release credit. |
| Candidate handoff | `PASS_EXACT_CANDIDATE_25_STRICT_V2` | Private creation manifest `3f316f3e…4c47` and strict-v2 handoff `b65b9e7e…2908` bind build `4053`, exact sources and six artifacts. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_25_PRIVATE_SIGNING; INSTALL_IDENTITY_NOT_RUN` | Five candidate.25 Android artifacts retain production certificate SHA-256 `0A0602A7…2500`. Exact x86_64/ARM64 installed-byte identity and runtime remain open. |
| Android device proof | `NOT_RUN_EXACT_CANDIDATE_25` | Physical Wi-Fi/Beeline default, AWG, WARP, per-app, handoff, IPv6/leak, UDP53/MTU, OEM and endurance coverage remain open. |
| Android OEM limitations | `MANUAL_OWNER_TEST` | Candidate.25 background, screen-off, tile/notification, permission revoke, Doze/standby and broader OEM/endurance coverage remain manual. |
| Windows package/signing | `PASS_EXACT_CANDIDATE_25_SIGNED_SUPPLY_AND_11_OF_11`; signing `SKIPPED_BY_OWNER` | Setup `ffc9b07c…7fb3`, `29139238` bytes, binds the corrected build-4053 source. Installed 11-file identity is proved on the clean hosted runner. SmartScreen warning remains mandatory. |
| Windows clean-host proof | `PASS_EXACT_PRIVATE_CI_INSTALL_SERVICE_IPC_RESTART_UNINSTALL_IDLE_NETWORK` | GitHub-hosted Windows 2025 run `33717151777` proves silent install, `11/11`, LocalSystem service, ordinary authenticated IPC, SCM stop/restart, clean uninstall and unchanged idle route/DNS. Evidence `c6ec9d18…bfcd`; connected TUN/DNS/egress remains separate. |
| Windows in-place upgrade | `FAIL_PRECURSOR_27; PASS_PRECURSOR_28_SOURCE_FIX` | Candidate.27 precursor reproducibly aborted its first candidate.23 upgrade when original-user SID resolution failed. Candidate.28 precursor reuses only an exact validated protected owner SID for an existing installation; first-pass upgrade `11/11`, LocalSystem service, direct TUN/DNS lifecycle and connected reboot recovery pass. No successor exact candidate exists yet. |
| Linux client | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_SHIPPED_IN_CANDIDATE_25` | The non-root UI/system daemon, bounded IPC, polkit and journald exist. A dormant typed NetworkManager/resolved/nft transaction with reverse fault recovery is source-tested but not wired to `connect`; native mutation/restoration, packages, signing and clean-VM proof remain open. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `BOUNDED_CORE_SLICE_PASS; FULL_CANDIDATE_25_NOT_RUN` | Exact-Core AWG3.1/AWG2 direct-RU Pi checks pass, but no full candidate.25 authenticated RU-origin aggregate exists. |
| Hosted CI | `PASS_EXACT_CANDIDATE_25_ATTACHED_CHECKS_AND_WINDOWS_CLEAN_HOST` | Attached checks pass across exact platform, client, Core and release-index source SHAs; Windows clean-host run `33717151777` also passes its bounded exact-byte lane. |
| Runtime sync | `CANDIDATE_25_PRIVATE_NOT_PROMOTED` | Candidate.25 remains private. No public runtime switch, stable pointer or post-promotion readback exists. |
| Exact-candidate rollback drill | `CANDIDATE_25_NOT_RUN` | Older reversal evidence does not approve candidate.25. Guarded pointer/runtime rollback plus current/Brain/RU readback and health remain open. |
| Final go/no-go | `BLOCKED_GATE_F_5_PASS_14_NON_PASS_0_FAIL` | Exact candidate.25 Gate F exists and remains blocked; the current packaging correction also requires a new exact successor candidate. Gate G, public release, Store object and stable pointer are unauthorized. |

## Current Cutover Sequence

1. Merge the validated Windows upgrade-owner correction and create a new exact
   successor candidate from the resulting frozen client/platform/Core tuple.
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
