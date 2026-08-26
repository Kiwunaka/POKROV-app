# Cutover Readiness

Last updated: 2026-08-26

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
| New working target | `1.2.0+30` |
| Target state | `PRE_CANDIDATE_LOCAL` |
| Candidate created | `false` |
| New public cutover | `BLOCKED` |
| Public/store claim | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED` |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Package/version parity | `PASS_LOCAL` | Android, Windows and app-shell remain `1.2.0+30`. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `INVALIDATED_BY_CHANGES` | The AWG 3.1 source-lab and selected-service changes invalidate the previously retained tuple. Freeze a new clean platform/client/Core/release-index tuple only after promotion; no candidate is implied. |
| Release index | `IMPLEMENTED_LOCAL_UNPUBLISHED` | Public `d0bf8e8…ed15` is legacy checksum-only. Local `f07654a…9eb7` adds strict manifest/signature/same-byte validation, but owner key, review/push, hosted workflow and public readback remain blocked. |
| Core replacement | `PASS_LOCAL` | Exact reproducible `1.1.0` AAR/DLL identities are bound to signed Core revision `344b317…8f6`; the refresh includes separate bounded AWG2 and default-off AWG 3.1 contracts. No tag, candidate signing or publication is claimed. |
| Android LDPlayer source-lab rehearsal | `PASS_LOCAL_INSTALL_SETTINGS`; connect `BLOCKED_BACKEND_5XX` | Production-signed lab APK `1.2.0 (4031)`, SHA-256 `1ba37463c9549a6d5ba128850e1bf5825187fe185a621e9f8dc62c7cde1a4158`, installed byte-identically in LDPlayer 14. The installed x86_64 Core SHA-256 `f676e7e96f6e159e4da626ec51d94b438ef08fc2819e5d222b6253e51354980d` exposes the AWG2/AWG3.1 contract markers; AI/Games and configurable in-tunnel DoH settings persisted across restart. The live profile request returned 5xx, no `tun0` was created and the location catalog did not load. This is not an exact-candidate, real-AWG-server, physical-device, mobile-origin or production-connect pass. |
| Candidate handoff | `MISSING` | One strict-v2 handoff binds exact revisions, artifacts and gates. |
| Android artifact/signing | `MISSING` | Final APK identities and production signer match v2. |
| Android device proof | `MANUAL_OWNER_TEST` | Exact-candidate physical matrix passes. |
| Android OEM limitations | `EXPLICIT_MANUAL_GATE` | PB-08 and `AND-BG-001/002/003` plus `AND-VPN-004` cover safe guidance; exact-candidate background, screen-off, lockscreen, notification, tile, permission-revoke and reconnect proof remains manual. |
| Windows package/signing | `MISSING_ARTIFACT`; signing `SKIPPED_BY_OWNER` | Build the final service-first setup; strict-v2 must record the exact unsigned bytes, the `1.2.0` direct-beta-only exception and mandatory SmartScreen warning. |
| Windows clean-host proof | `MANUAL_OWNER_TEST` | TUN/DNS/egress/recovery matrix passes on a clean host. |
| Linux client | `NOT_SHIPPED_IN_1.2.0` | No Linux artifact, daemon, package, support matrix or release promise belongs to this candidate. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `NOT_REQUESTED` | Required only before an explicit RU-origin claim. |
| Hosted CI | `NOT_RUN` | Required checks pass on every frozen revision. |
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
