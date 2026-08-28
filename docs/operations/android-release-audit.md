# Android Release Audit

Last updated: 2026-08-28

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains the current Android gate for the `1.2.0` working target.
Older APK identities and device runs are retained separately as evidence.

## Current Truth

| Fact | Current state |
|---|---|
| Retained public Android release | Production-signed direct APK `1.1.6` |
| Working package target | `1.2.0+4045` |
| Replacement candidate created | `false`; signed candidate.3 remains private evidence for its exact older bytes only |
| Package ID | `space.pokrov.pokrov_android_shell` |
| Active candidate Core package | POKROV Core `1.1.0` AAR from exact source `f44dbe8…f90d`; bytes match the prior `54e76bb` build |
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
The `1.2.0+4045` replacement is source-only until its production-signed working
artifacts and live checks complete; it has no strict-v2 replacement candidate. None of the retained candidate.3 signing,
runtime or promotion rows below transfers to the new bytes.

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
