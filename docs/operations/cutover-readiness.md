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
| New working target | `1.2.0+4052` |
| Continuing source target | `PRE_CANDIDATE_LOCAL` on `POKROV-app/main` |
| Latest exact candidate | `pokrov-1.2.0-candidate.22`, app `1.2.0+4051`; six signed-private artifacts and bounded Windows 11 default/recovery/Smart-DNS/AWG evidence retained, but immutable `NO_GO` after connected uninstall leaves the UI and loaded binaries |
| Retained signed-index predecessor | Candidate.21 is immutable `NO_GO`; its evidence does not alter candidate.22 or receive current PASS credit. |
| Candidate/current-main boundary | Candidate.22 binds exact client `0aad6bbb…afed`; later `main` commits do not alter or receive credit for its bytes. |
| New public cutover | `BLOCKED_NO_PROMOTABLE_CANDIDATE`; build-4052 successor not created |
| Planned distribution if approved | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED`. No new public claim exists yet. |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed describes the `1.2.0+4052` development line with
Core `cd8f0f4…884d`; its `candidate_created=false` describes continuing `main`,
not the separate signed candidate contract. `config/cutover-readiness.seed.json`
now binds local private candidate.22: platform `d16087d…eedc`, client
`0aad6bbb…afed` and Core `cd8f0f4…884d`. Six build-4051 artifacts exist. The
exact Windows setup validates `11/11`, keeps the service available after a
rejected client, passes default, service-restart and reboot recovery, Smart DNS
and separate packaged AWG3.1/AWG2 runs. Candidate.22 strict-v2 handoff
`6fd9cb56…e566`, refreshed SBOM/provenance and signed
manifest/signature/receipt `81c56e9f…7d59` / `b230a442…a387` /
`65123519…2124` validate from release-index source `d45b5035…`. It remains
unpublished and unpromoted. Connected uninstall restores RU egress, removes
the service and tunnel, but leaves the running UI and 13 loaded binaries;
candidate.22 is therefore immutable `NO_GO`. Candidate.21 and earlier rejected
candidates remain retained history.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Development package/version parity | `PASS_PRE_CANDIDATE_4052` | Android and Windows source targets are `1.2.0+4052`; the shared app-shell remains product version `1.2.0`. Rejected candidate.22 retains its exact build `4051` identity. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_22_TUPLE_PRIVATE` | Candidate.22 binds platform `d16087d…eedc`, client `0aad6bbb…afed` and Core `cd8f0f4…884d`; exact attached hosted checks pass. Paid GitHub branch protection remains outside the owner-solo lane. |
| Release index | `PASS_EXACT_CANDIDATE_22_ACTIONS_ARTIFACT_ONLY` | Handoff `6fd9cb56…`, SBOM/provenance and manifest/signature/receipt `81c56e9f…` / `b230a442…` / `65123519…` validate; signer run `33656388958` passes with promotion false. Public assets remain absent. |
| Core replacement | `PASS_EXACT_CANDIDATE_22_SIGNED_ARTIFACTS` | All candidate.22 Android/Windows artifacts and refreshed SBOM/provenance bind Core `cd8f0f4…884d`; the six hashes and Windows `11/11` manifest validate. |
| AWG lifecycle | `CANDIDATE_22_WINDOWS_PASS; ANDROID_NOT_RUN` | Exact candidate.22 Windows separately reaches one packaged AWG3.1 and AWG2 tunnel with DNS and DE egress; Android, UDP, IPv6, MTU and endurance remain open. |
| AWG Windows app/service path | `PASS_EXACT_CANDIDATE_22_WINDOWS_AWG31_AND_AWG2` | Both guarded owner-lab profiles pass through the installed UI/service/Core boundary, then cleanup restores the ordinary default and zero tunnel. |
| External Smart-DNS lab | `PASS_EXACT_CANDIDATE_22_WINDOWS_IN_APP; PHYSICAL_AUTHENTICATED_OPEN` | Exact Windows UI persists custom direct DoH, external Smart DNS and AI/Games, reaches bounded allowlisted targets and restores defaults. Physical Android, authenticated sessions and leak/load/lifecycle remain open. |
| Candidate.22 LDPlayer | `NOT_RUN; HOST_TUN_NETWORK_CREDIT_EXCLUDED` | Exact x86_64 APK `31962adc…c181`, `109951985` bytes, is signed but has no candidate.22 install/launch readback. Host-tunneled emulator networking receives no release credit. |
| Candidate handoff | `PASS_EXACT_CANDIDATE_22_STRICT_V2` | Private creation manifest `852172b6…81bc` and strict-v2 handoff `6fd9cb56…e566` bind build `4051`, exact sources and six artifacts. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_22_PRIVATE_SIGNING; INSTALL_IDENTITY_NOT_RUN` | Five candidate.22 Android artifacts retain production certificate SHA-256 `0A0602A7…2500`. Exact x86_64/ARM64 installed-byte identity and runtime remain open. |
| Android device proof | `NOT_RUN_EXACT_CANDIDATE_22` | Physical Wi-Fi/Beeline default, AWG, WARP, per-app, handoff, IPv6/leak, UDP53/MTU, OEM and endurance coverage remain open. |
| Android OEM limitations | `MANUAL_OWNER_TEST` | Candidate.22 background, screen-off, tile/notification, permission revoke, Doze/standby and broader OEM/endurance coverage remain manual. |
| Windows package/signing | `NO_GO_EXACT_CANDIDATE_22_CONNECTED_UNINSTALL_RESIDUAL`; signing `SKIPPED_BY_OWNER` | Setup `effc6a8e…f409`, `29137688` bytes, validates `11/11` and passes the bounded runtime slices, but connected uninstall leaves the UI and 13 binaries. SmartScreen warning remains mandatory. |
| Windows clean-host proof | `PASS_EXACT_CANDIDATE_22_BOUNDED_WINDOWS11_EXCEPT_CONNECTED_UNINSTALL` | Ordinary UI/LocalSystem service, default TUN/DNS/DE egress, service-restart/reboot recovery, Smart DNS and AWG pass. Windows 10, sleep and broad IPv6/leak remain open; the VM exposes no sleep or IPv6 path. |
| Linux client | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_SHIPPED_IN_CANDIDATE_22` | The non-root UI/system daemon, bounded IPC, polkit and journald exist. A dormant typed NetworkManager/resolved/nft transaction with reverse fault recovery is source-tested but not wired to `connect`; native mutation/restoration, packages, signing and clean-VM proof remain open. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `CANDIDATE_22_NOT_RUN; OLDER_HISTORY_ONLY` | Older RU bundles and Pi plans do not transfer. No candidate.22 authenticated RU-origin aggregate exists. |
| Hosted CI | `PASS_EXACT_CANDIDATE_22_ATTACHED_CHECKS_10_OF_10` | Ten attached checks pass across exact platform, client, Core and release-index source SHAs. |
| Runtime sync | `CANDIDATE_22_PRIVATE_NOT_PROMOTED` | Candidate.22 remains local private. No public runtime switch, stable pointer or post-promotion readback exists. |
| Exact-candidate rollback drill | `CANDIDATE_22_NOT_RUN` | Older reversal evidence does not approve candidate.22. Guarded pointer/runtime rollback plus current/Brain/RU readback and health remain open. |
| Final go/no-go | `NO_GO_EXACT_CANDIDATE_22_CONNECTED_UNINSTALL` | Gate F remains frozen at `BLOCKED 3/16/0`; the later connected-uninstall residual independently rejects candidate.22. Gate G, public release, Store object and stable pointer are unauthorized. |

## Current Cutover Sequence

1. Merge the build-4052 connected-uninstall correction and freeze the corrected
   client source with current platform and Core revisions.
2. Build and bind candidate.23 without rewriting candidate.22. Verify Android
   signing, Windows `SKIPPED_BY_OWNER`, the mandatory SmartScreen warning,
   SBOM, provenance and checksums.
3. Install the exact successor setup in the isolated Windows VM and prove the
   connected uninstaller closes the UI, removes every installed file and
   restores the ordinary network.
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
