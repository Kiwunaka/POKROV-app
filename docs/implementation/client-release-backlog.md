# POKROV Client Release Backlog

Last updated: 2026-09-04

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains only the current client release queue. Candidate-specific
results belong in dated evidence and never become reusable release approval.

## Current Release Line

| Fact | Current state |
|---|---|
| Public retained release | Android and Windows `1.1.6`, tag `v1.1.6` |
| Working package target | `1.2.0+4053` |
| Working source target state | `PRE_CANDIDATE_LOCAL` continuing-source seed on `POKROV-app/main`; the separate exact candidate.33 artifact source is `6ab1bca…735e` |
| Latest exact candidate | Private signed `pokrov-1.2.0-candidate.33`, app `1.2.0+4053`; exact `WIN-001`, product launchAtLogin, hidden login startup, synthetic saved-state migration across offline startup/network appearance, bounded Windows synthetic TUN/DNS and partial physical Android slices pass, while Gate F remains `BLOCKED 2/17/0`; public promotion is false |
| Candidate created | `false` |
| Private candidate created | `true` for candidate.33 in the separate creation/cutover contract; the continuing-source seed remains pre-candidate by design |
| Candidate-created scope | Candidate.33 binds platform `f530005…`, client `6ab1bca…`, Core `cd8f0f4…` and release-index source `63993fb…`; its six build-4053 client artifacts are private and immutable. |
| Signed candidate contract | `PASS_ACTIONS_ARTIFACT_ONLY`: handoff `30d9d044…`, SBOM `3b586c6e…`, provenance `9aadcb1d…`, manifest/signature/receipt `5620c2f0…` / `5115ab3c…` / `f84843c8…`; promotion false and no public assets. |
| Public cutover allowed for a new candidate | `false` |
| Google Play | `NOT_REQUESTED` |
| Exact candidate Core artifact | POKROV Core `1.1.0` at `cd8f0f4…884d`; candidate.33 six private artifacts and signed SBOM/provenance bind the reviewed Core source |
| Support-mode signing public pin | `PASS_SOURCE_CONTROL` — tracked key `pokrov-support-2026-08`; private/HMAC values are secret-only and not deployed |
| Retained public Core | `1.0.3`; rollback/history identity only |
| Windows trusted-signing decision | `SKIPPED_BY_OWNER` for the exact `1.2.0` direct-download beta; mandatory SmartScreen warning; no trusted/Store/broad-stable claim |
| Conditional Linux beta | `IMPLEMENTED_PARTIAL_SOURCE_ONLY`; non-public and absent from the current candidate |

`config/release-handoff.seed.json` owns the public release and continuing
development target. `config/cutover-readiness.seed.json` owns the current
candidate and cutover verdict. Exact candidate.33 identity comes from the
private creation manifest, signed strict-v2 contract and cutover seed; the
release-handoff seed's `candidate_created=false` applies only to continuing
`main`. Candidate.33 is unpublished and unpromoted. Its generated Gate F
snapshot is `BLOCKED 2/17/0`: exact Windows focus, product launchAtLogin,
login-startup hidden/same-process activation, synthetic saved-state migration
across offline startup/network appearance, synthetic direct/Smart-DNS service
lifecycles, partial physical Android evidence and exact LDPlayer install/cold-
start proof do not close the
remaining managed-runtime, device, origin, provider and promotion rows.
Candidate.32 remains immutable `NO_GO` history for its `WIN-001` focus defect.
Candidate.23 is immutable `NO_GO` for serial-pipe
contention. Candidate.22, candidate.21, candidate.20,
candidates 17–19 and candidate.12 remain rejected
history for their own bytes.

## Current Local Completion

- Core `cd8f0f4…884d` retains the `GO-2026-6303` dependency correction and
  makes the Core-owned AWG endpoint use the configured default domain-resolver
  transport and strategy for its inner FQDN. Hostname-authenticated TLS and
  fail-close remain unchanged. It also removes legacy raw-settings/error
  logging and retains explicit AWG2/AWG 3.1 start/close coverage. Both module roots retain
  `golang.org/x/crypto v0.55.0` and the compatible dependency
  closure. Module verification, focused tests, full Core tests, `go vet` and
  root/embedded reachable-vulnerability scans pass locally.
- Android AAR `2a9677d9…c6a69`, size `107419397`, and Windows DLL
  `f284fa88…8204`, size `55426048`, are each byte-identical across two clean
  builds from that source. The bundled artifacts and machine contract match.
- The exact Windows DLL exposes all 15 required symbols and passes 100
  proxy-only start/stop cycles. This does not prove SCM, TUN, DNS, leak,
  recovery or clean-host behavior.
- Prior production-signed ARM64 APK `7d1d4093…58ee5` from client `064fcd0...`
  embeds Core `547f096...`, installs/readbacks exactly on physical Huawei and
  passes ordinary Frankfurt on Beeline. AWG2/AWG3.1 each pass fresh handshake
  plus bidirectional TCP/UDP payload, but Android selected-endpoint verification
  remains `EGRESS-001`; this is transport PASS and end-to-end FAIL.
- Later production-signed diagnostic client `f078625...` with the same Core
  retained exact terminal category `egress_probe_dns_lookup` for both profiles.
  Corrected Core `a45d69e...` plus production-signed client `68779c4...` produces
  ARM64 APK `b583205d…7296`, installs/readbacks exactly, and reaches retained
  green selected-endpoint state for AWG2 and AWG3.1 on physical Beeline. The
  same source passes both profiles in LDPlayer. This closes the common resolver
  defect, not the remaining Android device matrix or candidate gate.
- Core hosted run `33227157016` passes all five jobs. The exact client hosted
  run contains zero executed steps and remains `BLOCKED_BY_ACCESS`, not PASS.
- Exact candidate.10 x86_64 APK `ec07ba17…2627`, `109952213` bytes, installed
  and read back byte-identically on LDPlayer as release/non-debuggable
  `1.2.0+4046`. All seven locations were visible. The ordinary Frankfurt
  control stopped fail-closed at the emulator-origin egress boundary; separate
  guarded AWG2 and AWG3.1 binds each reached app-confirmed tunnel, DNS and
  selected egress. Final guarded restore removed both lab materials and
  membership and left the app disconnected with no TUN.
- Exact candidate.11 universal APK `706c546e…e1a`, `295370161` bytes, is
  production-signed and installed byte-identically on LDPlayer as
  `1.2.0+4047`. Fresh AWG3.1, AWG2 and ordinary Auto attempts each reached
  verified egress, with separate normalized runtime-profile readback and
  address-free server traffic evidence. A later repeat exposed a release
  blocker: ordinary Smart Connect quarantine was applied before returning an
  owner-lab profile, so the app failed with no available automatic location.
  Successor source removes Smart Connect from AWG2/AWG3.1/HY2 lab envelopes;
  `86/86` bootstrap tests and `flutter analyze` pass. Candidate.11 remains
  immutable and requires replacement plus exact-device replay.
- Exact candidate.12 x86_64 APK `e7f74fb2…dd3c`, `109951989` bytes, is
  production-signed and installed byte-identically on LDPlayer as
  `1.2.0+4048`. Fresh AWG3.1 and cold-process AWG2 each reached verified
  egress, and ordinary Auto failed over from a fail-closed VLESS leaf to a
  verified successor. The warm AWG3.1 to AWG2 service restart rejected the new
  Core run's restarted event sequence, so candidate.12 remains immutable and
  non-promotable. Successor source fixes that lifecycle fence and requires a
  new signed candidate plus an exact warm-switch replay.
- Exact candidate.16 binds platform `719e23d…e3e3`, client `75ba7e7…6722`, Core
  `cd8f0f4…884d` and signed release-index source `54cfa03…f20c`. Its x86_64 APK
  `73c43e21…f5ff`, `109951989` bytes, installs byte-identically as
  release/non-debuggable `1.2.0+4049`. The ordinary default path reaches
  verified tunnel, managed DNS and authenticated egress. AWG 3.1 and AWG2 each
  activate the exact selected profile and form TUN/DNS/routes, then fail
  authenticated egress without false green and restore cleanly.
- Candidate.16's ARM64 APK `9bcdbe00…cc74`, `101366678` bytes, is now installed
  byte-identically on the owner's physical Android 12 device without launching
  the app; no POKROV process or `tun0` remains. This closes the install binding,
  not the physical runtime matrix.
- Candidate.16's strict-v2 six-artifact/8-file supply chain, production Android
  signing, SBOM/provenance and hosted public-index Ed25519 signer pass. Windows
  setup `0afaf6e1…276c`, `28932793` bytes, remains `NotSigned` /
  `SKIPPED_BY_OWNER` for direct beta only. Exact current-host Windows
  install/service/IPC/restart/uninstall and idle-network restoration pass;
  connected network/recovery remains manual. Gate F now validates all `19/19`
  checks and returns `NO_GO 2/17/2` with zero validation errors. The former
  missing-ARM64 prerequisite is closed, while current AWG egress and the
  remaining manual rows stay non-PASS.
- Candidate.17 binds platform `d6898e6…967`, client `977c6ed…108`, Core
  `cd8f0f4…884d` and signed release-index source `2df538c…b17`. Signed supply,
  index receipt and exact hosted replay runs `33463318296` / `33463427737`
  pass. Its six artifacts are byte-identical to candidate.16, but clean Windows
  proves that the eight-file setup omits three required VC runtime DLLs; the
  service cannot start and setup falsely exits `0`. Candidate.17 is immutable
  `NO_GO`.
- Candidate.18 binds the corrected `11/11` package, but its ordinary UI cannot
  validate the LocalSystem process token and closes the authenticated pipe;
  candidate.18 is immutable `NO_GO`.
- Candidate.19 corrects the SCM identity boundary and reaches profile staging,
  but the service receives ordinary-user AppData paths for local rule sets.
  Core returns `CORE-005`, rollback completes without connected state and
  candidate.19 is immutable `NO_GO`.
- Candidate.20 binds platform `d6898e6…967`, client `8ab9815…6e8`, Core
  `cd8f0f4…884d` and release-index source `61ad0b0…483`. Signed manifest
  `046d3312…770a`, signature `f5e81d31…90ea` and receipt `47429c2c…9479`
  validate with all six artifacts, a 352-component SBOM, six-subject
  provenance and hosted exact-tuple replay `33511744299`. Setup
  `330b87cb…587f`, `29140987` bytes, proves `11/11` files, ordinary UI,
  LocalSystem service, authenticated IPC, default TUN/DNS/DE egress,
  disconnect restoration, clean uninstall and public-1.1.6 migration on the
  isolated Windows 11 VM. A connected reboot restores the exact baseline and
  reconnects, but a forced service termination leaves the durable journal at
  `committed` after SCM restart and the UI unavailable. Candidate.20 is
  immutable `NO_GO`; process-owned tunnel disappearance is not proof that the
  service resumed rollback.
- Candidate.21 checks the durable journal before the first IPC client,
  preserves lazy Core initialization for a clean journal and leaves failed
  startup recovery fail-closed and retryable. Its six exact build-4050 private
  artifacts, signed supply and bounded Windows 11 upgrade/default runtime pass;
  fresh in-place service-restart recovery remains open.
- Candidate.22 exact build-4051 source isolates a rejected pipe session from service
  availability. A pre-hello, unauthorized or malformed client no longer ends
  the production SCM loop. The focused Flutter contract passes `7/7`, the
  complete Windows debug bundle builds and all six native service executables
  pass, including rejected-first/valid-second session recovery. Candidate.21
  remains immutable; candidate.22 receives exact Windows recovery credit.
- Working build-4052 successor source terminates the machine-wide Windows UI,
  waits for the SCM service to stop and removes the app directory only when it
  is empty. Exact local setup `9aa6b0fd…3152` reaches one TUN in the Windows 11
  VM, then connected uninstall removes UI/service/TUN/files/registry/app root
  and restores RU egress. Candidate.23 packages that correction, but its exact
  connected-uninstall replay did not run before an independent pipe failure
  rejected the candidate.
- Candidate.23 exact build-4052 source and signed supply validate, and its
  `11/11` Windows installation reaches an initial authenticated connection.
  A later UI request reports `CORE-001` while the service is still running; a
  source-exact diagnostic client reproduces `0/32` accepted simultaneous status
  requests. Build-4053 source adds a bounded retry for the busy-instance race
  and short serial-instance replacement gap. Eight native tests, Debug/Release
  builds and a fixed diagnostic run of `32/32` pass. This is pre-candidate only.
- VLESS/Reality remains the baseline. AWG 3.1 is the preferred closed UDP lab
  transport and AWG2 its rollback. XHTTP is post-1.2.0 TLS/CDN reserve work;
  Hysteria2 stays default-off and advances only after a bounded lab shows a
  measurable advantage over the baseline.
- Clean client `b4c9117…9f0` produced unsigned setup `6ef7899d…cbe9`, size
  `28918848`, with manifest `8dced605…f74b`; all eight files match and the
  embedded DLL is exact. Signing remains `SKIPPED_BY_OWNER` with mandatory
  SmartScreen warning. Clean-host runtime proof is open.

## Retained Pre-Convergence Evidence

- Android and Windows development package versions match `1.2.0+4053`; app-shell reports the
  shared product version `1.2.0`.
- Strict release-handoff v2 generation and client/Core parity pass locally.
- The retained `1.1.6` stable pointer is hash-bound to its versioned rollback
  target, and an isolated fixture proves byte-identical A→B→A pointer reversal.
- Release notes and visible client version share the manifest-validated
  package identity.
- Android uses separate direct and store update authorities.
- Windows uses the service-first privilege boundary in current source.
- Linux has a non-root Flutter host and a fail-closed systemd/polkit daemon
  foundation. Each mutation has a closed peer-credential/polkit-D-Bus
  authorization trace without peer identity or raw diagnostics. A dormant
  typed NetworkManager/resolved/nft transaction engine and reverse fault
  recovery exist in source, but live connect remains disabled until the exact
  Core/TUN plan, durable integration and native rollback proof exist.
- Local observability, diagnostics and support-bundle contracts are present.
- Production packaging is source-bound to one tracked support-mode public key
  and rejects partial or different overrides before Flutter.
- Build 4045 carries the opt-in direct-DoH laboratory detour and managed AWG
  endpoint materialization without changing VPN-default routing. Its Android
  AAR binds Core `f44dbe8…f90d`, whose AWG endpoint resolves probe hostnames,
  preserves the canonical `egress` event subsystem and requests Android
  platform protection only for its outer socket. It also selects the reachable
  owned app ingress through a JSON health preflight, with the canonical API
  hostname retained as a bounded fallback and no replay of non-idempotent
  requests. Two AAR builds are byte-identical. A production-signed working
  build-4044 APK was installed and exercised physically, but no strict-v2
  replacement candidate exists.
- AWG2 and AWG3.1 userspace lifecycles pass locally. After the owned DE UFW
  ingress correction, exact Core `f234bb6` proved live server handshakes for
  both profiles. Physical build 4041 received the device-bound managed profile
  but emitted no observable AWG UDP. Build 4042 then enabled global interface
  auto-detection as an experiment; LDPlayer failed immediately at Core start
  with no observable AWG UDP, so those bytes are rejected. Build 4043 reached
  an AWG userspace handshake and direct Core egress on LDPlayer, but ordinary
  system-TUN traffic timed out. On physical Beeline, the old API hostname timed
  out before profile refresh and neither owned AWG listener received a packet;
  the same connection did reach JSON through the new app ingress. Build 4044
  then refreshed through that ingress and reached both new owned listeners.
  Each guarded plain-UDP control was received and echoed 3/3 by the server but
  returned 0/3 to the phone, classifying physical AWG as
  `BLOCKED_BY_NETWORK_CURRENT_ORIGIN` on Beeline rather than a crypto mismatch.
  Direct cellular DoH resolved all three bounded AI/Games queries, while the
  generated routes correctly kept application traffic on the VPN. After lab
  unbind and VPN-default DNS restore, ordinary WARP, IP egress and DNS+egress
  passed on the same phone. A later explicit no-carrier readback selected AWG2
  for exact physical and LDPlayer identities, but build 4044 on Wi-Fi and build
  4043 on LDPlayer emitted no AWG traffic. LDPlayer additionally rejected the
  selected Frankfurt location before tunnel start. The common managed-profile
  activation/fallback path is therefore a pre-candidate failure; AWG3.1 was not
  repeated above the same unmet AWG2 precondition. Full exact-candidate tunnel
  DNS, leak, handoff and OEM proof remain open.
- Core is clean and pushed. Platform head `42522fe…a3d9` now bypasses the
  ordinary Smart Connect shortlist when issuing device-bound AWG2/AWG3.1 lab
  material, while working build 4045 demotes stale Android `running` state when
  no app-owned TUN exists. These corrections are source-only until the platform
  deploy and exact Android device proof; cross-repository preflight must be
  rerun on their committed revisions before `READY_LOCAL_FREEZE` can return.
- Exact client source `75e82b0…e62` adds an opt-in external Smart-DNS
  laboratory route.
  It is accepted only with exact HTTPS port 443 `/dns-query` without a
  query/fragment/token, direct DNS and an enabled AI or gaming-service group.
  Only selected suffix DNS questions use that resolver while normal final DNS
  stays unchanged; selected service connections use the existing direct
  outbound, other groups keep VPN and explicit user rules keep precedence.
  The client/platform policy bytes match and app-shell analyze plus `412/412`
  tests pass. Production-signed arm64/x86_64 working APKs were installed and
  read back byte-identically on the Huawei and LDPlayer. LDPlayer passed the
  prerequisite/default-off/enable/restore state machine; the phone passed the
  exact-package/default-off gate without a setting change. Platform
  `2d18fd7…f78a` produces a byte-reproducible verified server bundle, and the
  platform operations `ca9eb41…7334` add the tested guarded
  PLAN/APPLY/ROLLBACK source contract. No dedicated-node PLAN, installed owned
  resolver/relay or live service-access proof exists.
- A fresh AWG source/host-contract retest binds platform `50c9d12…dde49`,
  client `75e82b0…e62` and Core `e8eb772…41a1`. AWG2 and AWG3.1 contract-sync
  reports pass with digests `0caeaba4…eb44` and `3a4c318a…06f`; ten focused
  Flutter tests, thirteen Android direct-release JVM tests and thirty-one Core
  AWG tests pass. The operator-only live Core egress test remains skipped
  without runtime material. This is local source/host contract evidence only:
  Windows still lacks a converged Core artifact, and neither server deploy nor
  device tunnel was run.
- A separate exact-Core live interop from the current Windows origin emitted
  outer packets for AWG2 and AWG3.1 but received no outer response. Concurrent
  address-free AWG2 server capture counted `34` inbound and `8` outbound
  packets, including `8` initiation and `8` response-sized packets, with no
  handshake. AWG2 is therefore
  `BLOCKED_BY_NETWORK_CURRENT_WINDOWS_ORIGIN_REVERSE_UDP`; AWG3.1 keeps the
  narrower `FAIL_NO_OUTER_RESPONSE_CURRENT_WINDOWS_ORIGIN` because its server
  capture was not repeated. This Core-only probe did not exercise the Windows
  app, TUN or DNS and changed no rollout/device binding.

These results mix source, live-lab and explicitly identified pre-candidate
physical evidence. None is exact replacement-candidate, hosted-CI, public
runtime, rollback or promotion proof.

## Open Gate Queue

| Order | Gate | State | Completion rule |
|---:|---|---|---|
| 1 | Clean platform, client, Core and release-index revisions | `PASS_EXACT_CANDIDATE_33_TUPLE` | Candidate.33 binds platform `f530005…5bc1`, client `6ab1bca…735e`, Core `cd8f0f4…884d` and signed release-index source `63993fb…c43c`. |
| 2 | Public release-index revision | `PASS_SIGNED_CANDIDATE_33_MANIFEST` | Manifest `5620c2f0…f680`, detached signature `5115ab3c…3191`, receipt `f84843c8…78d7`, keyring and six exact artifacts validate. Output is artifact-only and promotion remains false. |
| 3 | POKROV Core `1.1.0` replacement artifact | `PASS_EXACT_CANDIDATE_33_ARTIFACTS` | Candidate.33 binds reproducible AAR `2a9677d9…c6a69`, DLL `f284fa88…8204`, unchanged Cronet `8ef1f8bb…a6f7`, refreshed SBOM/provenance and exact Core source `cd8f0f4…884d`. |
| 4 | Conditional Linux beta runtime and package | `IMPLEMENTED_PARTIAL_SOURCE_ONLY; NOT_IN_CURRENT_CANDIDATE` | The current source contains the non-root Flutter host plus fail-closed systemd/socket/polkit daemon foundation, a closed authorization trace, and a dormant typed transaction engine for a real NetworkManager D-Bus checkpoint, per-link resolved settings, one dedicated atomic nft table and reverse rollback with injected faults. It is not wired to `connect`; the exact Core/TUN plan, durable recovery, native mutation/restoration, signed packages and clean-VM proof remain absent. Current candidate and public facts exclude Linux. |
| 5 | Strict-v2 candidate metadata | `PASS_SIGNED_CANDIDATE_33` | Handoff `30d9d044…72c81` binds build `4053`, exact four-source tuple, six artifacts, SBOM, provenance and the `11/11` Windows runtime manifest. |
| 6 | Android exact-candidate build and signer | `PASS_EXACT_CANDIDATE_33_INSTALL_IDENTITY` | Five Android artifacts are production-signed. Universal APK `51b86f66…583f2`, `295370161` bytes, is installed and read back byte-identically as `1.2.0+4053` on physical Android. |
| 7 | Android device matrix | `PARTIAL_EXACT_CANDIDATE_33_PHYSICAL` | Wi-Fi validated VPN and four DNS/reply probes pass. Beeline Auto is bounded to 32 seconds before an external transport change; selected Milan and emergency whitelist fail closed. AWG, WARP, per-app, handoff, IPv6/leak, UDP53/MTU, OEM and endurance remain open. |
| 8 | Windows exact-candidate package | `PASS_EXACT_CANDIDATE_33_FOCUS_PRODUCT_STARTUP_SAVED_STATE_AND_SYNTHETIC_TUN_DNS` | Setup `250622f7…3580`, `29153792` bytes, validates `11/11`. Isolated Windows 11 proves candidate.32 update, exact focus restoration, product launchAtLogin on/off, real-login hidden startup with ordinary same-PID activation, synthetic saved-state migration across offline startup/network appearance, and secret-free direct/Smart-DNS service/Core/TUN/DNS lifecycles with exact cleanup. |
| 9 | Windows STOP-SHIP and unsigned-beta warning | `PASS_EXACT_CANDIDATE_33_WIN_001; OWNER_ACCEPTED_UNSIGNED_DIRECT_BETA_ONLY` | Plain and typed second launches restore foreground focus; the product switch creates/removes the exact Run value, `--startup` stays hidden, and synthetic saved state remains secure and disconnected when networking appears. Authenticode remains `NotSigned`; the SmartScreen warning is mandatory and valid saved-account/managed-profile auto-connect, managed-node/AWG, Windows 10/sleep/IPv6/leak coverage stays open. |
| 10 | Hosted cross-repository CI | `MIXED_EXACT_CANDIDATE_33_BLOCKED_BY_ACCESS` | Release-index source-contract and signer runs pass; platform/client jobs that execute zero steps because of GitHub billing remain `BLOCKED_BY_ACCESS_GITHUB_BILLING`, not PASS. |
| 11 | Runtime/public readback and rollback | `PASS_LOCAL_FIXTURE_CANDIDATE_33; LIVE_NOT_AUTHORIZED` | Candidate.33 disposable stable→candidate→stable reversal is byte-identical. No public tag/assets, live stable-pointer switch, anonymous public readback or runtime rollback exists. |
| 12 | Promotion and go/no-go | `BLOCKED_GATE_F_2_PASS_17_NON_PASS_0_FAIL` | Candidate.33 remains private with promotion false. Gate G, public release and stable pointer are unauthorized. |

## Next Action Order

1. Retain candidate.33 as the exact private baseline; do not rebuild or patch
   its bytes. Re-run Gate F only when new exact-candidate pointers are added.
2. Continue the isolated Windows matrix with a valid saved account/profile,
   managed auto-connect timing and managed-node TUN/DNS/egress/recovery.
   Exact product launchAtLogin, login startup, contention, connected
   crash/reboot and connected uninstall are retained.
3. Run candidate.33 on Windows 10, AWG 3.1/AWG2, sleep/resume,
   IPv6/leak and interactive SmartScreen matrix only in isolated targets; keep
   the main host network untouched.
4. Continue physical Android from the exact installed candidate.33 bytes:
   finish a stable Beeline interval, then bounded AWG/DNS/WARP and lifecycle
   checks without changing managed rollout unless separately authorized.
   Candidate.33 LDPlayer install identity and cold UI start already pass; rerun
   its network matrix only on an isolated path without the host Hiddify tunnel.
5. Retain authenticated current/Brain/RU-origin evidence separately. Bind
   Linux Core/TUN ownership to the typed transaction and add durable recovery,
   but run native mutation/restoration, packaging and VM proof only for its
   separate conditional beta lane.
6. Complete provider/payment/PostgreSQL, Operator OIDC/RBAC/action-intent,
   legal/commercial, comparable performance and final no-open-P0/privacy
   attestations for the successor candidate.
7. Regenerate Gate F only after exact successor evidence changes;
   every skip, inaccessible environment and unrun manual row remains non-PASS.
8. Request separate authority for public same-byte candidate publication,
   anonymous readback, rollback drill and promotion.
9. Provision trusted Windows signing later before any signed, Store or
   broad-stable Windows claim.

## Retained History

The previous mixed backlog is preserved as
[2026-08-21-client-release-backlog-snapshot.md](history/2026-08-21-client-release-backlog-snapshot.md).
Its candidate statuses are evidence only.
