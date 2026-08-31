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
| Exact signed candidate | `pokrov-1.2.0-candidate.16`, app `1.2.0+4049`; private internal candidate, artifact-only and promotion false |
| Replacement candidate for working target | Signed release-index `true`; source seed remains `false`; public release/store/stable pointer remain absent |
| New public cutover | `BLOCKED` |
| Public/store claim | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED` |

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed describes the `1.2.0+4049` development line with
Core `cd8f0f4…884d`. Separately generated strict-v2 metadata and the signed
public-index receipt own immutable private candidate.16; the seed does not
duplicate that candidate contract. Candidate.16 passes the ordinary LDPlayer
path. Both exact AWG profiles activate and form TUN/DNS/routes but fail
authenticated egress without false green. Its exact physical ARM64 install
binding now passes, while physical runtime and the rest of the release matrix
remain open. Candidate.16 Gate F validates all `19/19` pointers and returns
`NO_GO 2/17/2` with zero validation errors. Older Gate F/device/Windows results
remain history and do not authorize candidate.16.

## Current 1.2.0 Gate Matrix

| Gate | State | Required evidence |
|---|---|---|
| Package/version parity | `PASS_EXACT_CANDIDATE_16` | Android and Windows candidate targets are `1.2.0+4049`; the shared app-shell remains product version `1.2.0`. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_16_TUPLE` | Signed candidate.16 binds platform `719e23d…e3e3`, client `75ba7e7…6722`, Core `cd8f0f4…884d`, signed release-index source `54cfa03…f20c` and receipt source `f321a8c…cfaa`. GitHub plan purchases and protected private-branch controls remain outside the owner-solo lane. |
| Release index | `PASS_SIGNED_CANDIDATE_16_CONTRACT` | Manifest `ae1906e6…ffe6`, detached signature `f5df6357…07a9`, receipt `1231ab69…2de4`, keyring and six artifact identities validate. Promotion is false and no tag/public assets/stable switch exists. |
| Core replacement | `PASS_EXACT_CANDIDATE_16_ARTIFACTS` | Candidate.16 binds secret-safe Core `cd8f0f4…884d`, reproducible AAR `2a9677d9…c6a69`, DLL `f284fa88…8204`, unchanged Cronet `8ef1f8bb…a6f7` and refreshed SBOM/provenance. |
| AWG lifecycle | `EXACT_PROFILE_ACTIVATION_PASS; AWG31_EGRESS_FAIL; AWG2_EGRESS_FAIL` | Exact candidate.16 LDPlayer activates each requested AWG profile, creates TUN, managed DNS and routes, then fails authenticated selected egress without false green and removes the VPN. Final ordinary default reconnect/disconnect passes. The physical exact install is present but no physical runtime ran. |
| AWG current Windows-origin Core probe | `CANDIDATE_16_PACKAGE_AND_IDLE_HOST_PASS; LIVE_NETWORK_MANUAL` | Candidate.16 contains exact Core DLL `f284fa88…8204`. Current-host setup, `8/8` files, service/owner binding, authenticated IPC, restart, uninstall and idle route/DNS restoration pass. Connected TUN/DNS/AWG/egress, recovery and clean-VM proof remain manual. |
| External Smart-DNS lab | `PASS_LIVE_SERVER_ROLLBACK_AND_THREE_ORIGINS; CLIENT_DEFAULT_OFF` | `dns.pokrov.space` is authoritative, the owned `it` frontend/backend and certificate are live, receipt-bound rollback/re-apply passes, and bounded DoH plus ChatGPT/Gemini/Xbox TLS/SNI checks pass from current, Brain and RU origins. This server work postdates candidate.16; client selection remains disabled and no device/session/leak/load claim transfers. |
| Candidate.16 LDPlayer rehearsal | `PASS_EXACT_DEFAULT; AWG31_AND_AWG2_EGRESS_FAIL; CLEAN_RESTORE` | Exact x86_64 APK `73c43e21…f5ff`, `109951989` bytes, is byte-identical after install. Ordinary default traffic passes. Both lab profiles form TUN/DNS/routes but fail authenticated egress and clean up without false green. |
| Candidate handoff | `PASS_SIGNED_PRIVATE_CANDIDATE_16` | Strict-v2 handoff `e604410e…2ac3` binds build `4049`, exact four-source tuple, six artifacts, SBOM, provenance and Windows runtime manifest; output is artifact-only and promotion remains false. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_16_SIGNING; X86_64_AND_ARM64_INSTALL_PASS` | Production-signed release/non-debuggable ARM64 `9bcdbe00…cc74` and x86_64 `73c43e21…f5ff` bind the exact candidate Core. Both installed base APKs read back byte-identically; the physical app was not launched. |
| Android device proof | `PASS_CANDIDATE_16_DEFAULT_LDPLAYER_AND_PHYSICAL_INSTALL; RUNTIME_MATRIX_OPEN` | Ordinary LDPlayer traffic passes and physical ARM64 install identity passes. Physical default/AWG/WARP/per-app/handoff, external IPv6/leak, UDP53/MTU, multi-OEM and endurance remain open; older physical proof does not transfer. |
| Android OEM limitations | `MANUAL_OWNER_TEST` | Candidate.16 background, screen-off, tile/notification, permission revoke, Doze/standby and broader OEM/endurance coverage remain manual. |
| Windows package/signing | `PASS_EXACT_CANDIDATE_16_CURRENT_HOST_IDLE_SLICE`; signing `SKIPPED_BY_OWNER` | Setup `0afaf6e1…276c`, `28932793` bytes, `8/8` install identity, service/IPC/restart/uninstall and idle restoration pass. The unsigned direct-beta SmartScreen exception does not permit trusted/Store/broad-stable claims. |
| Windows clean-host proof | `CURRENT_HOST_IDLE_PASS; CONNECTED_CLEAN_VM_MANUAL` | Connected TUN/DNS/AWG/egress, recovery, connected uninstall, interactive SmartScreen and Windows 10/11 clean-VM matrix remain unrun. |
| Linux client | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_IN_CANDIDATE_16` | The non-root Flutter host, typed bounded Unix IPC, `SO_PEERCRED`, polkit, hardened systemd units, supported foundation matrix, secret-free journald envelope and typed transaction seam exist. Live Core/TUN, NetworkManager/resolved/nft mutation and rollback, packages, signing and clean-VM proof remain open. No Linux artifact or 1.2.0 availability claim exists. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `CANDIDATE_16_BUNDLE_AND_PLAN_PASS; ENVIRONMENT_INCOMPLETE` | The exact candidate.16 ten-member RU bundle reproduces and the owned-Pi no-mutation install PLAN passes. Four installed source files differ, runtime material/archive are absent, timers inactive and runner state failed; no RU run/upload/heartbeat/admin readback exists. |
| Hosted CI | `CORE_EXACT_COMMIT_AND_RELEASE_INDEX_PASS; PLATFORM_CLIENT_BLOCKED_BY_BILLING` | Exact Core commit checks and candidate.16 release-index signer execute and pass. Platform/client jobs with empty runner and `steps=[]` remain `HOSTED_CHECK_BLOCKED_BY_BILLING` under the owner-solo lane, not PASS. |
| Runtime sync | `PLATFORM_READINESS_CORRECTION_DEPLOYED; CANDIDATE_METADATA_NOT_PROMOTED` | The bounded managed-profile readiness correction is live on Brain. Candidate.16 remains private and artifact-only. LDPlayer ordinary egress passes; labs fail selected egress; physical Android and Windows connected network remain open. |
| Exact-candidate rollback drill | `PASS_ISOLATED_LOCAL_REVERSAL; LIVE_RUNTIME_OPEN` | Candidate.16 passes disposable portal/client `1.1.6 -> candidate.16 -> 1.1.6` reversal with byte-identical restoration. Live pointer/kill rollback plus current/Brain readback and health remain open. |
| Final go/no-go | `GATE_F_NO_GO_2_PASS_17_NON_PASS_2_FAIL` | Candidate.16 exact physical ARM64 install binding passes. Gate F validates the signed tuple and all `19/19` pointers, then returns `NO_GO` with zero validation errors. The exact AWG LDPlayer rehearsal and authenticated egress are the two FAIL rows; physical runtime, connected Windows, current/Brain/RU and other manual rows remain non-PASS. Gate G, public release, store object and stable pointer are unauthorized. The Windows signing exception never becomes a trusted signing PASS. |

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
