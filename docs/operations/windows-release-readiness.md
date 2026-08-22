# Windows Release Readiness

Last updated: 2026-08-22

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains the current Windows gate for the `1.2.0` working target.
Older unsigned packages and pre-service behavior are retained as evidence.

## Current Truth

| Fact | Current state |
|---|---|
| Retained public Windows release | Unsigned direct setup `1.1.6` |
| Working package target | `1.2.0+30` |
| Candidate created | `false` |
| Runtime architecture | Unelevated UI plus authenticated SCM service |
| Required service | `pokrov_service.exe` |
| Active Core | POKROV Core `1.0.3`, desktop ABI `2` |
| Intended Core replacement | `1.1.0`, exact artifact pending |
| Portable ZIP | Unsupported for the service-first runtime |
| Trusted signing | `MISSING` |
| Native crash profile | `PASS_LOCAL`: stack-only, no full dump default |

The ordinary UI does not load Core, run elevated or use a system-proxy
fallback. The service owns Core, managed state and recovery. Green state
requires the authenticated egress proof.

Local source and fault-injection tests cover IPC, journal, network snapshot and
rollback logic. They do not install the service or mutate this host's network.
The native crash filter writes only exception code plus at most 32 allowlisted
module-relative frame offsets. UI and service use separate protected
current/previous files; paths, symbols, registers, exception text, heap and full
memory dumps have no output field. The controlled-crash and recovery readback
still belongs to the exact-candidate gate below.

## Exact-Candidate Gate

| Check | Current state |
|---|---|
| Clean client/Core revisions | `BLOCKED` |
| Exact Core DLL and dependency identity | `DEVELOPMENT_REPLACEMENT_PENDING` |
| Machine-wide setup package | `MISSING` |
| Service install/start and UI authentication | `MANUAL_OWNER_TEST` |
| Trusted code signing and timestamp | `MANUAL_OWNER_TEST` |
| Clean-host TUN/DNS/egress | `MANUAL_OWNER_TEST` |
| Crash/reboot/sleep/SCM recovery | `MANUAL_OWNER_TEST` |
| Route and DNS restoration | `MANUAL_OWNER_TEST` |
| Uninstall while connected | `MANUAL_OWNER_TEST` |
| SmartScreen/reputation observation | `MANUAL_OWNER_TEST` |
| Strict-v2 size/SHA-256/source binding | `MISSING` |
| Anonymous download and install | `NOT_RUN` |
| Rollback drill | `NOT_RUN` |

## Safe Current Claims

- The `1.2.0` source targets an unelevated UI and authenticated Windows service.
- Local tests prove source contracts and isolated recovery logic only.
- A trusted-signed, clean-host-verified `1.2.0` Windows candidate does not yet
  exist.
- The retained unsigned `1.1.6` publication does not prove `1.2.0` trust,
  recovery or network behavior.

## Verification Commands

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-seed.ps1 `
  -PlatformRoot C:\path\to\platform `
  -CoreRoot C:\path\to\POKROV-core

pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1
```

Packaging remains local and unsigned until the owner provides trusted signing
and authorizes exact-candidate release work.

## Retained History

Prior Windows packages, hashes and pre-service notes are preserved as
[2026-08-21-windows-release-readiness-snapshot.md](history/2026-08-21-windows-release-readiness-snapshot.md).
They cannot approve `1.2.0`.
