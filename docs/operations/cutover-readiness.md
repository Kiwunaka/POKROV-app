# Cutover Readiness

Last updated: 2026-09-09

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

[Candidate.33 retention rechecked on 2026-09-09](evidence/2026-09-09-r12-candidate33-retention/README.md):
all 24 local files remain, including 21 matches to previously pinned hashes.
Five related CI archives were retained with their individual deadlines: Core
receipts/SBOM expire on September 13, signer output on September 18. This closes
R12-G02 preservation only; the candidate verdict and runtime gates below remain.

Owner checkpoint, 2026-09-05: execution is `OWNER_PAUSED_FOR_REPLANNING`.
Preserve candidate.33 and all partial/blocked results as-is. Do not continue
the old test/build/deploy plan without a new owner request. This pause does
not mark the release goal complete or turn any missing gate into PASS.

| Fact | Current state |
|---|---|
| Canonical lane | `POKROV-app/main` |
| Retained public release | Android and Windows `1.1.6` |
| New working target | `1.2.0+4053` |
| Continuing source target | `PRE_CANDIDATE_LOCAL` on `POKROV-app/main` |
| Latest exact candidate | Private signed `pokrov-1.2.0-candidate.33`, app `1.2.0+4053`. Supply and exact `WIN-001` pass; bounded Windows synthetic TUN/DNS, partial physical Android and exact LDPlayer install/cold-start evidence exist. Gate F remains `BLOCKED 2/17/0`. |
| Retained signed-index predecessor | Candidate.32 is immutable `NO_GO` history for `WIN-001`. Candidate.31 and earlier candidates retain their original evidence and verdicts. |
| Candidate/source boundary | Candidate.33 binds exact client source `6ab1bca…735e`. Continuing source commits do not change those candidate bytes or inherit their evidence. |
| New public cutover | `BLOCKED_GATE_F_17_NON_PASS`; no public asset, Store object or stable pointer exists |
| Planned distribution if approved | Android direct stable target; Windows direct unsigned beta with mandatory SmartScreen warning; stores `NOT_REQUESTED`. No new public claim exists yet. |

The September 9 source integration uses signed promotion PR #95 after platform
PR #243 and before Core PR #9. This exact client PR validates against Core
`1f9a5a8865b80067784b893ef99d43c63f943777`; its Git tree matches the retained
`c7a11f7` source bound by the runtime seed. Other PRs and pushes keep the normal
promotion-line check. The platform publishing guide owns this bounded merge
sequence and requires ordinary checks after all three source lines converge.
Source integration does not change the candidate.33 or public-release decision
above, and signed Git commits do not establish signed application packages.

The existing `1.1.6` publication does not approve new `1.2.0` bytes. Its
signing, device, runtime and origin evidence cannot be reused for promotion.
The continuing client seed describes the `1.2.0+4053` development line; its
current Core source and bytes are owned by `config/runtime-artifacts.seed.json`.
Its `candidate_created=false` describes continuing `main`,
not the separate signed candidate contract. `config/cutover-readiness.seed.json`
now binds private candidate.33: platform `f530005…5bc1`, client
`6ab1bca…735e` and Core `cd8f0f4…884d`. Six build-4053 artifacts exist.
Candidate.33 strict-v2 handoff `30d9d044…72c81`, refreshed SBOM/provenance and
signed manifest/signature/receipt `5620c2f0…f680` / `5115ab3c…3191` /
`f84843c8…78d7` validate from release-index source `63993fb…c43c`.
The isolated Windows 11 VM proves the exact focus correction plus bounded
secret-free direct and Smart-DNS TUN/DNS lifecycles. Physical Android proves
exact installed bytes and Wi-Fi runtime, with only bounded Beeline credit.
Gate F therefore remains `BLOCKED 2/17/0`; candidate.33 is unpublished and
unpromoted. Candidate.32 and earlier candidates retain their exact historical
verdicts.

The signed candidate contract is the Ed25519 release-index manifest. It is
not Windows Authenticode: the candidate.33 Windows signing field remains
`SKIPPED_BY_OWNER_DIRECT_BETA_ONLY`. Android package signing is separate.
The public `1.1.6` line, retained candidate.33, and continuing source target
must each be read from its own owner above, even when app build numbers match.

## Current 1.2.0 Gate Matrix

### 2026-09-05 Windows managed AWG attempt

Candidate.33 bytes are unchanged. On the isolated Windows VM, exact client
`6ab1bca…735e` completed the local welcome screen using the existing protected
session; no interactive login was required. The platform helper successfully
selected AWG3.1 and AWG2 for this install only and restored the default after
each selection. A subsequent AWG3.1 UI attempt reached the first-connect
`Всё устройство` / `Выбранные приложения` sheet. At that checkpoint selection was
`MANUAL_OWNER_TEST` because the Windows computer-use skill does not allow
changing VPN privacy/scope settings. No managed tunnel, DNS or egress PASS is
assigned. Default restoration was confirmed after the UI attempt; a fresh
guarded lab selection is required before continuing AWG tests.

Sanitized platform reports and the initial eight-report index are retained in
`E:/POKROV-tools/release-evidence/1.2.0-candidate33-windows-awg-authorized-2026-09-05/`.
The later `awg31-ui-test-apply.json` and
`default-after-ui-route-prompt.json` are additional reports, not members of that
earlier index. Platform WO-013HL records identity correction and helper tests.
This control-plane result does not change Gate F or the matrix below.

Owner-ready follow-up on the same day supersedes the scope blocker:
`firstRouteScopeConfirmed=true`, `firstRouteScopeMode=fullTunnel` were read
from the VM. Exact candidate.33 UI/service hashes still match. The client
fetched an `awg31_lab` manifest revision, displayed connected with DNS/egress
ready, and an independent guest probe received an API DNS answer and HTTPS
`200`. This is `PARTIAL_EXACT_CANDIDATE_33_MANAGED_ATTEMPT`, not complete
AWG lifecycle proof: the protected service profile identity was not read back,
location remained unresolved and route counters were unavailable.

After server selection changed to AWG2, ordinary disconnect/reconnect still
retained the AWG3.1 revision. That attempt gets **no AWG2 credit**. Its guest
probes found one Up tunnel, resolved API/ChatGPT/Gemini/Xbox names and received
API/POKROV DoH HTTP `200`; these do not prove DNS-only mode or service access.
An attempted non-UI client restart stopped at `Access is denied`; the previous
zero-Up-tunnel guard passed, but the restart did not happen. DE-side independent
handshake capture also remains `BLOCKED_BY_ACCESS`: the old helper selected an
untrusted port alias, and the configured port-22 SSH target reported a changed
host key. Neither trust check was bypassed.

Both temporary lab selections were restored to default with exact-install
guarded readback (`ok=true`, no cohort/allowlist identity). The final UI showed
disconnected. Exact route/DNS baseline restoration was not measured in this
follow-up. Sanitized apply/restore and guest observations are retained under
`E:/POKROV-tools/release-evidence/1.2.0-candidate33-awg-after-owner-scope-2026-09-05/`.
Source inspection then confirmed that ordinary Windows reconnect intentionally
reuses a staged profile; the built-in repair action explicitly refreshes it.
AWG2 was assigned again to test repair, but the owner stopped computer-use
before that action. Repair therefore remains `NOT_RUN`, not failed or passed.
The final `default-after-owner-freeze.json` confirms restoration after this
interruption. All eight sanitized reports are now retained in Git in
[the freeze evidence](evidence/candidate33-owner-freeze-awg.json), including
original external-file hashes. The previous restart attempt made no process
change. No binary change, new candidate, public publication or deploy occurred;
Gate F stays unchanged. Any future AWG2 run must first assert the refreshed
revision; DE-side observation also requires independently verified host trust.

| Gate | State | Required evidence |
|---|---|---|
| Development package/version parity | `PASS_EXACT_CANDIDATE_33_BUILD_4053` | Candidate.33 Android and Windows artifacts are `1.2.0+4053`; the shared app-shell remains product version `1.2.0`. |
| Strict-v2 generator contract | `PASS_LOCAL` | Schema, generator and cross-repository parity tests pass. |
| Stable pointer and rollback catalog | `PASS_LOCAL` | Retained `1.1.6` pointer matches its exact versioned handoff; isolated A→B→A proves optimistic lock, atomic replace, backup, receipt and byte-identical reversal. |
| Operational producer/privacy contract | `PASS_LOCAL` | Auth, entitlement, performance, support and Android count-only routing producers pass focused client/platform tests; exact-candidate runtime proof remains later. |
| Temporary support mode and encrypted export | `PASS_LOCAL` | Signed exact-audience activation, explicit consent, persistent indicator, nonce/TTL/cumulative caps, no-upload short code and encrypted-only Android/Windows export pass local source/widget/unit contracts; exact-candidate physical host proof remains later. |
| Clean frozen revisions | `PASS_EXACT_CANDIDATE_33_TUPLE_PRIVATE` | Candidate.33 binds platform `f530005…5bc1`, client `6ab1bca…735e`, Core `cd8f0f4…884d` and signed release-index `63993fb…c43c`. Paid GitHub branch protection remains outside the owner-solo lane. |
| Release index | `PASS_EXACT_CANDIDATE_33_ACTIONS_ARTIFACT_ONLY` | Handoff `30d9d044…72c81`, SBOM/provenance and manifest/signature/receipt `5620c2f0…f680` / `5115ab3c…3191` / `f84843c8…78d7` validate; signer run `33851401873` passes with promotion false. Public assets remain absent. |
| Core replacement | `PASS_EXACT_CANDIDATE_33_SIGNED_ARTIFACTS` | All candidate.33 Android/Windows artifacts and refreshed SBOM/provenance bind Core `cd8f0f4…884d`; the six hashes and Windows `11/11` manifest validate. |
| AWG lifecycle | `NOT_RUN_EXACT_CANDIDATE_33_MANAGED` | Older exact-Core and predecessor results do not transfer to candidate.33's managed packaged lifecycle. Android, UDP, IPv6, MTU and endurance remain open. |
| AWG Windows app/service path | `PARTIAL_EXACT_CANDIDATE_33_MANAGED_ATTEMPT` | Owner scope is confirmed; AWG3.1 manifest fetch, connected UI and bounded guest DNS/HTTPS observations exist. Service-profile identity and full lifecycle remain open; the AWG2 attempt retained the AWG3.1 revision and receives no AWG2 credit. |
| External Smart-DNS lab | `PASS_EXACT_CANDIDATE_33_WINDOWS_SYNTHETIC; PHYSICAL_AUTHENTICATED_OPEN` | Windows receives DoH `200` and restores exact network state through a secret-free synthetic profile. Physical Android UI, authenticated managed sessions and leak/load/lifecycle remain open. |
| Candidate.33 LDPlayer | `PASS_EXACT_INSTALL_IDENTITY_AND_COLD_UI_START; NETWORK_BLOCKED_BY_HOST_TUN` | Universal APK `51b86f66…583f2`, `295370161` bytes, update-installs/readbacks byte-identically as `1.2.0+4053`; exact MainActivity cold-start and 321-second minimized process/crash check pass. Host Hiddify/sing-tun excludes DNS, egress, VPN, AWG, Smart-DNS, WARP and protocol credit. |
| Candidate handoff | `PASS_EXACT_CANDIDATE_33_STRICT_V2` | Private candidate input `2ed2160a…2604` and strict-v2 handoff `30d9d044…72c81` bind build `4053`, exact sources and six artifacts. |
| Android artifact/signing | `PASS_EXACT_CANDIDATE_33_PRIVATE_SIGNING_AND_INSTALL_IDENTITY` | Five candidate.33 Android artifacts retain production certificate SHA-256 `0A0602A7…2500`. Universal APK `51b86f66…583f2` is installed/read back byte-identically on physical Android. |
| Android device proof | `PARTIAL_EXACT_CANDIDATE_33_PHYSICAL` | Wi-Fi validated VPN and four DNS/reply probes pass. Beeline Auto is bounded to 32 seconds before an external transport change; selected Milan and emergency whitelist fail closed. AWG, WARP, per-app, handoff, IPv6/leak, UDP53/MTU, OEM and endurance remain open. |
| Android OEM limitations | `MANUAL_OWNER_TEST` | Candidate.33 background, screen-off, tile/notification, permission revoke, Doze/standby and broader OEM/endurance coverage remain manual. |
| Windows package/signing | `PASS_EXACT_CANDIDATE_33_SIGNED_SUPPLY_AND_11_OF_11`; signing `SKIPPED_BY_OWNER` | Setup `250622f7…3580`, `29153792` bytes, binds exact client source `6ab1bca…735e`. SmartScreen warning remains mandatory. |
| Windows exact focus and synthetic runtime | `PASS_EXACT_CANDIDATE_33_BOUNDED` | Isolated Windows 11 proves candidate.32 update, exact `WIN-001`, authenticated service IPC, direct/Smart-DNS TUN/DNS lifecycles, connected recovery/uninstall, startup/saved-state slices and warm-cache plus post-reboot 45-second fresh-process UI idle observations with zero crash events and unchanged route/DNS. The two observations have no performance-budget credit; managed-node/AWG, Windows 10, sleep, IPv6/leak and comparable performance remain open. |
| Windows second-launch focus | `PASS_EXACT_CANDIDATE_33_WIN_001` | Plain and typed second launches retain one original process, forward activation and restore foreground focus. |
| Linux client | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_SHIPPED_IN_CANDIDATE_33` | The non-root UI/system daemon, bounded IPC, polkit and journald exist. The typed NetworkManager/resolved/nft transaction remains source-only and not wired to `connect`; native mutation/restoration, packages, signing and clean-VM proof remain open. |
| Apple native release | `NOT_REQUESTED` | Apple remains readiness-only for this release. |
| RU-origin proof | `BOUNDED_CORE_SLICE_PASS; FULL_CANDIDATE_33_NOT_RUN` | Exact-Core AWG3.1/AWG2 direct-RU Pi checks pass, but no full candidate.33 authenticated RU-origin aggregate exists. |
| Hosted CI | `MIXED_EXACT_CANDIDATE_33_BLOCKED_BY_ACCESS` | Release-index source-contract and signer jobs pass. Platform/client jobs with zero executed steps because of GitHub billing remain `BLOCKED_BY_ACCESS_GITHUB_BILLING`, not PASS. |
| Runtime sync | `CANDIDATE_33_PRIVATE_NOT_PROMOTED` | Candidate.33 remains private. No public runtime switch, stable pointer or post-promotion readback exists. |
| Exact-candidate rollback drill | `PASS_LOCAL_FIXTURE; LIVE_NOT_AUTHORIZED` | Candidate.33 source-owned disposable stable→candidate→stable reversal is byte-identical. Live pointer/runtime rollback and current/Brain/RU readback remain open. |
| Final go/no-go | `BLOCKED_GATE_F_2_PASS_17_NON_PASS_0_FAIL` | Exact candidate.33 Gate F validates all pointers but remains blocked by 17 non-PASS rows. Gate G, public release, Store object and stable pointer are unauthorized. |

## Current Cutover Sequence

1. Retain candidate.33 as the immutable exact private baseline; documentation
   and later evidence must not rewrite its bytes.
2. Run candidate.33 connected contention, managed TUN/DNS/egress,
   recovery and connected-uninstall checks in the isolated Windows VM.
3. Continue physical Android Beeline/AWG/DNS/WARP and the remaining Windows
   gates. A retained
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
