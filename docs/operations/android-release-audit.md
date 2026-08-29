# Android Release Audit

Last updated: 2026-08-29

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains the current Android gate for the `1.2.0` working target.
Older APK identities and device runs are retained separately as evidence.

## Current Truth

| Fact | Current state |
|---|---|
| Retained public Android release | Production-signed direct APK `1.1.6` |
| Working package target | `1.2.0+4046` |
| Replacement candidate created | `false`; signed candidate.3 remains private evidence for its exact older bytes only |
| Package ID | `space.pokrov.pokrov_android_shell` |
| Active pre-candidate Core package | POKROV Core `1.1.0` AAR `b42a5489…8007` from exact source `3c2b114…d0f`; two builds are byte-identical and contain all four required ABIs |
| Support-mode signing public pin | `PASS_EXACT_ARTIFACT` — `pokrov-support-2026-08`, SHA-256 `44aed433…8845`, bound by candidate.3 supply evidence |
| Retained public Core | `1.0.3`; rollback/history identity only |
| Google Play | `NOT_REQUESTED` |

Current source separates direct and store update authority. It also keeps
notification detail private, bounds TUN MTU and uses Core/TUN traffic counters.
Release-safe lifecycle, permission, network, Doze/app-standby, stack-free
watchdog and direct-updater identity breadcrumbs are written through a closed
schema to two bounded files under the app-private no-backup directory. No raw
message, URL, profile, token, endpoint or stack is accepted by that journal.
These local contracts do not prove final APK bytes or physical behavior.

## Retained Candidate.3 Evidence And Replacement Gate

The table keeps candidate.3 results only as exact evidence for its old bytes.
The `1.2.0+4046` source replacement now has production-signed working APKs and
bounded two-device configuration-state proof, but no strict-v2 candidate.
Production-signed build-4045 artifacts remain exact evidence only for their
older bytes, and the replacement network matrix is incomplete.
None of the retained candidate.3 signing, runtime or promotion rows below
transfers to the new bytes.

| Check | Current state |
|---|---|
| Clean client/Core revisions | `PASS_SOURCE_CONTROL` — artifact source client `ac22825…ead`, Core `344b317…8f6`; client source run `33032033161` passed |
| Exact Core AAR identity | `PASS_LOCAL` — `da3ea378…aba9`, two byte-identical builds, four ABIs |
| Strict-v2 Android artifact entries | `PASS_SIGNED_CANDIDATE_3` — manifest `a2752b6a…1090`, signature `926f0b46…7121`, promotion false |
| Exact APK support signing pin | `PASS_EXACT_ARTIFACT` — candidate.3 supply evidence binds the active support public key; no private key was read or exported |
| Production signer and lineage | `PASS_5_OF_5` — APK/AAB certificate SHA-256 `0a0602a7…2500` |
| Package/version/ABI/min-SDK identity | `PASS_EXACT_ARTIFACTS` — `1.2.0`, build `30`, min SDK `24`, universal plus three direct ABI APKs and store AAB |
| SHA-256 and byte-size match | `PASS_EXACT_ARTIFACTS` — universal APK `f41c76eb…1c51`, `295051181` bytes; all five Android files match signed manifest |
| LDPlayer upgrade/start/settings persistence | `PASS_EXACT_EMULATOR_PREFLIGHT` — Android 9/API 28, exact universal APK, AI/Games retained after force-stop/relaunch; no matching package fatal exception in bounded logcat |
| LDPlayer catalog/TUN/DNS/egress | `BLOCKED_BY_ACCESS` — retained emulator account is expired and the app withholds the location catalog |
| Private operational journal source contract | `PASS_LOCAL` |
| Exact-device journal privacy/rotation/readback | `MANUAL_OWNER_TEST` |
| Anonymous download | `NOT_RUN` |
| Huawei install and first launch | `MANUAL_OWNER_TEST` |
| Connect/disconnect and verified egress | `MANUAL_OWNER_TEST` |
| Wi-Fi/LTE handoff and sleep/resume | `MANUAL_OWNER_TEST` |
| Full/selected/excluded routing | `MANUAL_OWNER_TEST` |
| DNS/blocked UDP 53/MTU matrix | `MANUAL_OWNER_TEST` |
| WARP enable/fallback/restore | `MANUAL_OWNER_TEST` |
| 100-cycle endurance and battery | `MANUAL_OWNER_TEST` |
| Privacy, backup and exposed-port audit | `MANUAL_OWNER_TEST` |
| Store submission | `NOT_REQUESTED` |

Every manual check must name the exact APK SHA-256 and device. Emulator proof
is preflight only and cannot clear a physical-device gate.

Candidate.3 evidence is bounded to exact install/update, package identity,
launch and settings persistence in LDPlayer. The earlier physical Beeline smoke
proved corrected backend routes with a different client build; it does not
clear candidate.3 physical-device, TUN, DNS, egress, OEM or RU-origin gates.

## Working Build 4041 Evidence

This is pre-candidate evidence for the exact working APK, not candidate or
promotion proof:

- production-signed universal APK `1.2.0+4041` has SHA-256
  `f2a1cb8c0d91f1980f68ad1c97628a6546beb4dd6aa7d13fdfa765bd8bf505aa`;
  the arm64 APK SHA-256 is
  `60ed23cf5f4c39b142878b012c7f924ab43d745a62142ec15f58d8f5695be3d5`;
- exact package/version installation and first launch passed on LDPlayer and a
  physical Huawei; that build-4041 retry ended before restoration could be
  read back. A later build-4044 session independently verified Wi-Fi and
  Hiddify restoration, but does not retroactively change build-4041 evidence;
- device-bound managed-profile requests returned HTTP 200 and server policy
  resolved `awg2_lab`, but clean retries produced no observable AWG2/AWG3.1 UDP
  at the owned server. The Android transport row is `FAIL_ANDROID_DEVICE_PATH`;
- exact Core `f234bb6` completed AWG2 and AWG3.1 handshakes against the same
  live owned server after its UFW ingress rules were corrected. That isolates
  the remaining failure to Android/device-path integration and does not prove
  APK tunnel egress;
- AdGuard DoH, direct-DoH lab, AI/ChatGPT/Gemini and Games/Xbox controls were
  present. Direct-DoH enabled state survived force-stop/relaunch and was then
  restored to its original disabled state. Focused source/config/widget tests
  pass; live tunnel DNS, blocked-UDP/53, leak and service-access checks remain
  `MANUAL_OWNER_TEST` for the eventual exact candidate.

## Rejected Working Build 4042 Evidence

This exact pre-candidate is retained as failure evidence and is not reusable:

- production-signed universal APK `1.2.0+4042` has SHA-256
  `afb3b4daca8374cc16d1e9bbb0ba6ac8fbabcb612c28a9550d98eb6576aa7d2d`;
- LDPlayer installation and version readback passed, but AWG2 failed immediately
  during Core service start with safe code `WIN-SVC-003` and the owned server
  observed no AWG initiation or response packet;
- build 4042 globally enabled interface auto-detection when an AWG endpoint was
  present. That experiment is rejected because it changes ordinary Android
  route behavior. Builds 4043/4044 instead keep global auto-detection disabled
  and bind byte-identical Core source `f44dbe8…f90d`, which requests `VpnService.protect(fd)` only
  for the AWG outer socket.

## Rejected Working Build 4043 Evidence

This exact pre-candidate is retained as failure evidence and is not reusable:

- production-signed universal APK `1.2.0+4043` has SHA-256
  `259daae0e117227a1f38f1178ffc050e2996faac950fe84e8563d3376c264503`;
- installation as an update with settings retained passed on LDPlayer and the
  physical Huawei. LDPlayer reached an AWG userspace handshake and direct Core
  egress, but ordinary application traffic through the system TUN timed out;
- on the physical Beeline path, direct TLS to the old control-plane hostname
  timed out before profile refresh. The app therefore retained stale local
  state and neither the AWG2 nor AWG3.1 owned listener observed an inbound
  packet. This is a control-plane reachability failure, not proof that either
  AWG profile failed after reaching its listener;
- the separately owned `app.pokrov.space/api/*` ingress passed live JSON
  readback on the same Beeline path. Build 4044 makes that owned ingress the
  primary client API origin, verifies `/api/health` as JSON before real work,
  keeps the old API hostname as a bounded fallback, and never replays a
  non-idempotent request during origin selection.

## Working Build 4044 Physical Evidence

This is current-origin pre-candidate evidence for one production-signed working
APK. It is not strict-v2 candidate, promotion, OEM-matrix or RU-origin proof:

- installed package `1.2.0+4044` was `101348658` bytes with SHA-256
  `7417191b9fab0469e2040ae535a5e51ca34821da9848e3af5a26aaf7a2f04f45`;
  APK signature verification passed and its certificate matched the local
  production-signing certificate metadata;
- the owned app API ingress passed on physical Beeline, the managed profile
  refreshed, the Android host granted Core outer-socket protection and both
  owned AWG listeners observed client-originated encrypted UDP;
- AWG2 and the AWG3.1 `randomized_trailers_v1` variant did not complete a
  physical handshake. A guarded plain-UDP echo control then sent three packets
  on each exact listener: each server received and echoed all three, while the
  phone received no valid echo on either listener. The physical AWG result is
  `BLOCKED_BY_NETWORK_CURRENT_ORIGIN`: reverse UDP is dropped on this Beeline
  path. This is not a cryptography, key-alignment, Android socket-protection or
  universal protocol failure claim;
- live AWG alignment v2 passed for both profiles across keys, peer identity,
  ports, tunnel addresses, S/H fields, header protection, content padding and
  randomized trailers. AWG3.1 remains a closed lab and is not release-ready;
- a later explicit no-carrier policy readback selected AWG2 for the exact
  physical and LDPlayer identities. Build 4044 on Wi-Fi returned to disconnected
  state without Android VPN transport or AWG packets. Build 4043 on LDPlayer
  first showed connected without Android VPN transport or AWG traffic, then
  rejected the selected Frankfurt location before tunnel start. This is
  `FAIL_WORKING_CLIENT_ACTIVATION`, before cryptography; AWG3.1 was not repeated
  because AWG2 never reached the common cryptographic path;
- with `DNS напрямую · лаборатория` enabled, the persisted preference and
  generated runtime both selected direct HTTPS DoH. Three bounded cellular DoH
  queries covering the AI and Games groups returned valid DNS responses. The
  runtime still routed ChatGPT/Gemini/Xbox application traffic through the VPN
  target, so this proves DNS resolution only and not service access without a
  VPN;
- the direct-DoH preference was restored to its original VPN-default state.
  AdGuard plus AI/Games remained enabled. After the exact device was removed
  from the AWG cohort and allowlists, normal WARP connected on Beeline and
  separate IP-egress and DNS+egress probes passed. The regenerated runtime had
  no AWG final endpoint, kept HTTPS DNS through the VPN and retained both
  purpose routes;
- final cleanup readback showed both exact devices outside the AWG cohort and
  both lab allowlists with ordinary fallback restored. POKROV was stopped on
  the phone and LDPlayer, phone Wi-Fi was restored off, Hiddify was foreground,
  and no temporary raw profile, endpoint, identifier or screenshot was retained.

The working `1.2.0+4045` source demotes a stale Android `running` snapshot when
the app-owned TUN is absent. The paired platform correction issues owned AWG lab
profiles without applying the ordinary Smart Connect node shortlist first. Both
corrections remain pre-deploy, pre-device evidence: before freezing the final
candidate they must prove AWG2 on a returning origin, followed by AWG3.1. The
exact candidate then still needs the full physical matrix: lifecycle,
permission revoke, sleep/resume, Wi-Fi/LTE handoff, per-app modes, DNS leak,
blocked UDP 53, MTU, endurance, backup/privacy and OEM limitations.

## Working Build 4045 Host-State Evidence

This is bounded pre-candidate evidence for client source
`51f41c646796e506d9d329ce54e8cc15fb7dfa7b`; it does not prove AWG, DNS,
egress, endurance or promotion:

- production-signed arm64 APK SHA-256
  `8e3c45df8db2582f1a29a1f49776f45da5a0420391f584b892f66e4a7947eddf`,
  size `101348662` bytes, installed as `1.2.0+4045` on the physical Huawei;
- production-signed x86_64 APK SHA-256
  `0d76ee15fb9b1519cb8f92940cce315fbe3a1b485aaa44625a8f75623f1cc786`,
  size `109932885` bytes, installed as `1.2.0+4045` on LDPlayer;
- both artifacts passed the production signer, package, version, non-debuggable
  and ABI checks and matched the same configured production certificate;
- after cold launch on both hosts, the app-owned VPN service was absent and the
  UI reported `Подключить` / `Не защищено`; the physical Wi-Fi state remained
  disabled. This closes only the stale-running false-green regression;
- a bounded physical connect control then started the POKROV VPN service but
  produced no Android VPN transport after approximately `25` seconds. The UI
  tree became unavailable before a post-connect label could be retained, so
  DNS/HTTPS checks were not run and no connected-state claim is made. POKROV
  was force-stopped, Android VPN transport read back absent, Hiddify was
  foregrounded and Wi-Fi remained disabled. This is
  `FAIL_4045_PREDEPLOY_ANDROID_ACTIVATION`, before the undeployed platform
  managed-profile correction, not AWG cryptography or tunnel proof.
- an independent LDPlayer connect control reached the canonical
  `core_egress_probe_failed` state: POKROV did not confirm selected-outbound
  internet, stopped the system VPN fail-closed and exposed the safe retry UI.
  No VPN permission prompt, residual POKROV service or VPN transport remained
  after exact cleanup. No AWG policy was bound, so this is
  `FAIL_4045_LDPLAYER_SELECTED_OUTBOUND_EGRESS`, not AWG tunnel evidence.

The later exact clean source tuple platform `9383117…64c17`, client
`f3d3310…174f` and Core `f44dbe8…f90d` passes the bounded Node `22.14.0`
aggregate `15/15`. Its report SHA-256 is `57ca9352…f02ed` and explicitly keeps
`candidate_proven=false`; the installed APK bytes remain bound to runtime
source `51f41c6…dfa7b` above.

## Working Build 4046 External Smart-DNS Lab

Exact client source `75e82b061cd3f127ae640733cfb4fc1a6aef2e62`
adds opt-in routing for a compatible
external Smart-DNS resolver. The preference can be enabled only when a custom
HTTPS DoH URL, direct DNS transport and at least one AI or gaming-service
purpose route are all present. The URL must use port 443 and exact
`/dns-query`, with no query, fragment or persisted token. Only DNS questions
for selected policy suffixes are sent to that server; the existing final DNS
remains authoritative for every other name. Selected service connections use
the existing direct outbound, other groups keep VPN and explicit user rules
keep precedence. Invalid combinations normalize off when restored and fail
closed before native staging if constructed directly. The platform and client
policy copies are byte-identical at SHA-256
`b6977f6f6a5ee48898116820d1db252b5b670cb7b86959c78f7bdbc7de90e0fa`.
App-shell analysis is clean and `412/412` tests pass.

Production packaging from that exact source produced release/non-debuggable
working artifacts with certificate SHA-256
`0a0602a7df5d96a0b427909d004f3ddf26def86587634bf16694da8d654b2500`:

| ABI | Size | APK SHA-256 | Readback |
|---|---:|---|---|
| arm64-v8a | `101346230` | `c7e21ca3aa5baff575e515d22937c1a6b431068afdd0dad5fb6955b966cea6f9` | exact bytes installed on Huawei `ADA_AL00U` |
| x86_64 | `109930165` | `4beebad0f2efeef03b6c6a9ea7634c7c90515d5ec3f7bcdf4a8b74adcc83cd4b` | exact bytes installed on LDPlayer |

Both devices read back package `space.pokrov.pokrov_android_shell`, version
`1.2.0+4046`, and no running POKROV service after cleanup. LDPlayer proved the
full prerequisite/default-off/enable/restore UI state machine without starting
a connection and displayed the visible-IP/compatible-server warning. The
physical phone proved the exact package and safe default-off prerequisite gate
with its existing AdGuard/direct-DNS-off settings; no phone preference was
changed and its prior Chrome foreground was restored.

This is `PASS_WORKING_4046_SIGNER_AND_EXTERNAL_SMART_DNS_DEVICE_STATE`, not a
resolver or access result. The owned server has a byte-reproducible local
bundle from platform `2d18fd7…f78a` but remains uninstalled/default-off; no
compatible live resolver, DNS answer, service connection, leak/lifecycle
matrix or origin proof exists. The Android VPN system surface may still be
present because the existing sing-box TUN owns split-policy routing, even
though selected remote connections use the direct outbound.

## 2026-08-28 AWG Source And Host Contract Retest

The then-current 2026-08-28 pre-candidate source tuple was platform
`50c9d12254d39c6a007f273497dde49faa4f7b8d`, client
`75e82b061cd3f127ae640733cfb4fc1a6aef2e62` and Core
`e8eb7721fc6eaac6813d3a888ac90d0da1f541a1`. Exact AWG2 and AWG3.1
contract-sync reports pass; their local report SHA-256 values are respectively
`0caeaba4ea105a44c3610023c41935e21eccf2d1b45c07a50b8c20c6f8dfeb44`
and `3a4c318a71044aec36d9f85c4443d680f691106267ac56d5afe751cbd2fe106f`.

Focused local verification passes eight runtime-engine AWG tests, one managed
AWG endpoint-materialization test, one AWG DNS/routing test, thirteen Android
`directRelease` JVM egress-probe tests and thirty-one Core AWG tests. The
operator-only `TestOwnedAWGLabAuthenticatedEgress` is explicitly skipped
without live endpoint material. This result is
`PASS_LOCAL_CURRENT_SOURCE_AND_ANDROID_HOST_CONTRACT`; it does not prove the
Brain deploy, an app-owned TUN, AWG handshake/egress, physical-device behavior,
Windows artifact convergence, current-origin reachability or exact-candidate
readiness.

## 2026-08-29 AWG Reply-Route Correction And Physical Retest

The owned lab node is multi-addressed. Packet-level controls isolated the
earlier reverse-UDP failure to reply-route source selection: ordinary replies
left through the wrong public source, while ingress-pinned replies passed in
both directions. A guarded, default-off server correction now installs one
dedicated source-port rule and route table per allowlisted lab listener, plus a
narrow final SNAT rule. PLAN/APPLY/readback, automatic rollback and service
stop/start recreation pass. No cryptography, keys or protocol schema changed.

The exact retest tuple is platform correction `f79974c…ee6`, client
`7a633a8…bbb` and Core `3c2b114…d0f`. Two Android AAR builds are byte-identical
at SHA-256 `b42a5489…8007`. The production-signed arm64 replacement APK is
`1.2.0+4046`, `101357398` bytes, SHA-256
`930aec975927c1c40a87440f62f67b25295a12920e85876adca297b715426058`.
Its embedded arm64 Core library SHA-256
`1e367113624721b3d95e3ff763a73cdc539f4b6dca8290f78dd4533f816c32e1`
matches the same entry in the `3c2b114` AAR exactly.

On the physical Beeline path, AWG2 completed a fresh authenticated handshake
with bidirectional outer traffic and `3/3` inner packets each way. The closed
AWG3.1 randomized-trailers profile also completed a fresh authenticated
handshake, and a bounded owned-site browser slice produced `6` client-to-server
and `7` server-to-client inner packets. Exact current-origin Core interop then
passed both protocols again after a service stop/start cycle. Cleanup stopped
POKROV, removed the lab binding and material, restored the normal device
binding and returned the prior VPN app to foreground.

This closes the earlier `BLOCKED_BY_NETWORK_CURRENT_ORIGIN` diagnosis as a
server reply-routing defect and records `PASS_PHYSICAL_PRE_CANDIDATE` for both
AWG2 and AWG3.1. It is not a strict-v2 candidate, full Android lifecycle/OEM
matrix, broad protocol release decision or stable claim.

## Commands

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure-android-production-signing.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-android-production.ps1

$env:ANDROID_AUDIT_SERIAL = "<physical-device-serial>"
$env:ANDROID_AUDIT_PACKAGE = "space.pokrov.pokrov_android_shell"
$env:ANDROID_AUDIT_RELEASE_EVIDENCE = "<version/sha256>"
python C:\path\to\platform\scripts\android_localhost_audit.py `
  --serial $env:ANDROID_AUDIT_SERIAL `
  --package $env:ANDROID_AUDIT_PACKAGE `
  --release-evidence $env:ANDROID_AUDIT_RELEASE_EVIDENCE `
  --require-release-build
```

The build command does not authorize publishing. The audit command does not
replace install, routing, network, OEM or endurance evidence.

## Retained History

Prior Android candidate identities and audits are preserved as
[2026-08-19-android-release-audit-snapshot.md](history/2026-08-19-android-release-audit-snapshot.md).
They cannot approve `1.2.0`.
