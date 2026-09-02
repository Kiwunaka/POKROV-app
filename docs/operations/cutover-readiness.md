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
| Latest exact candidate | `pokrov-1.2.0-candidate.23`, app `1.2.0+4052`; six signed-private artifacts and exact Windows install/initial connection evidence are retained, but it is immutable `NO_GO` after valid service requests fail under serial-pipe contention |
| Retained signed-index predecessor | Candidate.22 is immutable `NO_GO`; its evidence does not alter candidate.23 or receive current PASS credit. |
| Candidate/current-main boundary | Candidate.23 binds exact client `df9ed85…6354`; later `main` commits do not alter or receive credit for its bytes. |
| New public cutover | `BLOCKED_NO_PROMOTABLE_CANDIDATE`; build-4053 successor not created |
| Planned distribution if approved | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED`. No new public claim exists yet. |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed describes the `1.2.0+4053` development line with
Core `cd8f0f4…884d`; its `candidate_created=false` describes continuing `main`,
not the separate signed candidate contract. `config/cutover-readiness.seed.json`
now binds local private candidate.23: platform `5ba4dba…fe68`, client
`df9ed85…6354` and Core `cd8f0f4…884d`. Six build-4052 artifacts exist. The
exact Windows setup validates `11/11` and reaches its initial authenticated
connection, but later valid requests can report `CORE-001` while the SCM
service remains running. Candidate.23 strict-v2 handoff `457bbf71…ef50`,
refreshed SBOM/provenance and signed manifest/signature/receipt
`5073c201…01a1` / `92027334…863` / `d11e24ac…8ba6` validate from release-index
source `95f9f03…`. It remains unpublished and unpromoted. Candidate.23 is
therefore immutable `NO_GO`. Candidate.22 and earlier rejected
candidates remain retained history.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Development package/version parity | `PASS_PRE_CANDIDATE_4053` | Android and Windows source targets are `1.2.0+4053`; the shared app-shell remains product version `1.2.0`. Rejected candidate.23 retains its exact build `4052` identity. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_23_TUPLE_PRIVATE` | Candidate.23 binds platform `5ba4dba…fe68`, client `df9ed85…6354` and Core `cd8f0f4…884d`; exact attached hosted checks pass. Paid GitHub branch protection remains outside the owner-solo lane. |
| Release index | `PASS_EXACT_CANDIDATE_23_ACTIONS_ARTIFACT_ONLY` | Handoff `457bbf71…`, SBOM/provenance and manifest/signature/receipt `5073c201…` / `92027334…` / `d11e24ac…` validate; signer run `33690078543` passes with promotion false. Public assets remain absent. |
| Core replacement | `PASS_EXACT_CANDIDATE_23_SIGNED_ARTIFACTS` | All candidate.23 Android/Windows artifacts and refreshed SBOM/provenance bind Core `cd8f0f4…884d`; the six hashes and Windows `11/11` manifest validate. |
| AWG lifecycle | `NOT_RUN_EXACT_CANDIDATE_23` | Candidate.22 Windows AWG3.1/AWG2 results do not transfer. Android, UDP, IPv6, MTU and endurance remain open. |
| AWG Windows app/service path | `NOT_RUN_EXACT_CANDIDATE_23` | Guarded AWG3.1/AWG2 app/service/Core replay remains open for a successor candidate. |
| External Smart-DNS lab | `NOT_RUN_EXACT_CANDIDATE_23; PHYSICAL_AUTHENTICATED_OPEN` | Candidate.22 Smart-DNS evidence does not transfer. Physical Android, authenticated sessions and leak/load/lifecycle remain open. |
| Candidate.23 LDPlayer | `NOT_RUN; HOST_TUN_NETWORK_CREDIT_EXCLUDED` | Exact x86_64 APK `9fa6727f…7e4f`, `109951989` bytes, is signed but has no candidate.23 install/launch readback. Host-tunneled emulator networking receives no release credit. |
| Candidate handoff | `PASS_EXACT_CANDIDATE_23_STRICT_V2` | Private creation manifest `de74c03a…d0e` and strict-v2 handoff `457bbf71…ef50` bind build `4052`, exact sources and six artifacts. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_23_PRIVATE_SIGNING; INSTALL_IDENTITY_NOT_RUN` | Five candidate.23 Android artifacts retain production certificate SHA-256 `0A0602A7…2500`. Exact x86_64/ARM64 installed-byte identity and runtime remain open. |
| Android device proof | `NOT_RUN_EXACT_CANDIDATE_23` | Physical Wi-Fi/Beeline default, AWG, WARP, per-app, handoff, IPv6/leak, UDP53/MTU, OEM and endurance coverage remain open. |
| Android OEM limitations | `MANUAL_OWNER_TEST` | Candidate.23 background, screen-off, tile/notification, permission revoke, Doze/standby and broader OEM/endurance coverage remain manual. |
| Windows package/signing | `NO_GO_EXACT_CANDIDATE_23_SERIAL_PIPE_CONTENTION`; signing `SKIPPED_BY_OWNER` | Setup `ded8c447…291`, `29146140` bytes, validates `11/11` and initially connects, but later valid requests can fail while the service remains running. SmartScreen warning remains mandatory. |
| Windows clean-host proof | `FAIL_EXACT_CANDIDATE_23_CORE001_SERVICE_RUNNING` | Initial UI/LocalSystem service, TUN, route/DNS change and DE egress pass. The exact client then reports `CORE-001`; connected uninstall and the broader matrix did not run. |
| Linux client | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_SHIPPED_IN_CANDIDATE_23` | The non-root UI/system daemon, bounded IPC, polkit and journald exist. A dormant typed NetworkManager/resolved/nft transaction with reverse fault recovery is source-tested but not wired to `connect`; native mutation/restoration, packages, signing and clean-VM proof remain open. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `CANDIDATE_23_NOT_RUN; OLDER_HISTORY_ONLY` | Older RU bundles and Pi plans do not transfer. No candidate.23 authenticated RU-origin aggregate exists. |
| Hosted CI | `PASS_EXACT_CANDIDATE_23_ATTACHED_CHECKS` | Attached checks pass across exact platform, client, Core and release-index source SHAs. |
| Runtime sync | `CANDIDATE_23_PRIVATE_NOT_PROMOTED` | Candidate.23 remains local private. No public runtime switch, stable pointer or post-promotion readback exists. |
| Exact-candidate rollback drill | `CANDIDATE_23_NOT_RUN` | Older reversal evidence does not approve candidate.23. Guarded pointer/runtime rollback plus current/Brain/RU readback and health remain open. |
| Final go/no-go | `NO_GO_EXACT_CANDIDATE_23_PIPE_CONTENTION` | Gate F was not generated after the exact runtime failure. Gate G, public release, Store object and stable pointer are unauthorized. |

## Current Cutover Sequence

1. Merge the build-4053 bounded pipe-retry correction and freeze the corrected
   client source with current platform and Core revisions.
2. Build and bind candidate.24 without rewriting candidate.23. Verify Android
   signing, Windows `SKIPPED_BY_OWNER`, the mandatory SmartScreen warning,
   SBOM, provenance and checksums.
3. Install the exact successor setup in the isolated Windows VM. Repeat the
   contention test through the ordinary UI, then prove connected uninstall
   closes the UI, removes every installed file and restores the ordinary network.
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
