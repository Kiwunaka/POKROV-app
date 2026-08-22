# Android Release Audit

Last updated: 2026-08-22

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains the current Android gate for the `1.2.0` working target.
Older APK identities and device runs are retained separately as evidence.

## Current Truth

| Fact | Current state |
|---|---|
| Retained public Android release | Production-signed direct APK `1.1.6` |
| Working package target | `1.2.0+30` |
| Candidate created | `false` |
| Package ID | `space.pokrov.pokrov_android_shell` |
| Active Core package | POKROV Core `1.0.3` AAR |
| Intended Core replacement | `1.1.0`, exact artifact pending |
| Google Play | `NOT_REQUESTED` |

Current source separates direct and store update authority. It also keeps
notification detail private, bounds TUN MTU and uses Core/TUN traffic counters.
Release-safe lifecycle, permission, network, Doze/app-standby, stack-free
watchdog and direct-updater identity breadcrumbs are written through a closed
schema to two bounded files under the app-private no-backup directory. No raw
message, URL, profile, token, endpoint or stack is accepted by that journal.
These local contracts do not prove final APK bytes or physical behavior.

## Exact-Candidate Gate

| Check | Current state |
|---|---|
| Clean client/Core revisions | `BLOCKED` |
| Strict-v2 Android artifact entries | `MISSING` |
| Production signer and lineage | `MISSING` |
| Package/version/ABI/min-SDK identity | `MISSING` |
| SHA-256 and byte-size match | `MISSING` |
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
