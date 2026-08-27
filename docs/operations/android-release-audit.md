# Android Release Audit

Last updated: 2026-08-27

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains the current Android gate for the `1.2.0` working target.
Older APK identities and device runs are retained separately as evidence.

## Current Truth

| Fact | Current state |
|---|---|
| Retained public Android release | Production-signed direct APK `1.1.6` |
| Working package target | `1.2.0+35` |
| Replacement candidate created | `false`; signed candidate.3 remains private evidence for its exact older bytes only |
| Package ID | `space.pokrov.pokrov_android_shell` |
| Active candidate Core package | POKROV Core `1.1.0` AAR from exact source `344b317…8f6` |
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
The `1.2.0+35` replacement has no artifacts yet, so none of the artifact,
emulator, device, network or origin rows below transfers to it.

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
