# Windows Release Readiness

Last updated: 2026-08-24

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
| Active pre-candidate Core | POKROV Core `1.1.0`, desktop ABI `2`, exact local bytes bound |
| Retained public Core | `1.0.3`; rollback/history identity only |
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
| Exact Core DLL and dependency identity | `PASS_LOCAL` — final-bound DLL `ef9672b3…5040`, Cronet `8ef1f8bb…a6f7`, two byte-identical builds and 15 exports |
| Machine-wide setup package | `PASS_LOCAL` — exact unsigned `1.2.0+30` setup SHA-256 `fd1de727…0899` assembled and checksum-bound; not promotable |
| Service install/start and UI authentication | `MANUAL_OWNER_TEST` |
| Trusted code signing and timestamp | `BLOCKED_BY_ACCESS` — fail-closed tooling is ready; no trusted Code Signing identity is installed/configured |
| Clean-host TUN/DNS/egress | `MANUAL_OWNER_TEST` |
| Crash/reboot/sleep/SCM recovery | `MANUAL_OWNER_TEST` |
| Route and DNS restoration | `MANUAL_OWNER_TEST` |
| Uninstall while connected | `MANUAL_OWNER_TEST` |
| SmartScreen/reputation observation | `MANUAL_OWNER_TEST` |
| Strict-v2 size/SHA-256/source binding | `PASS_LOCAL` — handoff SHA-256 `8d9a2d00…b806` retained in local pre-candidate staging; does not prove trusted signing |
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

Unsigned packaging remains available for local verification, but its generated
manifest records canonical status `MISSING` with blocker code
`MISSING_TRUSTED_WINDOWS_SIGNATURE` and is ineligible for candidate promotion.

Trusted candidate packaging is fail closed:

```powershell
$env:POKROV_WINDOWS_SIGNING_CERTIFICATE_THUMBPRINT = '<40-hex store thumbprint>'
$env:POKROV_WINDOWS_SIGNING_EXPECTED_SUBJECT = '<exact certificate subject>'
$env:POKROV_WINDOWS_SIGNING_TIMESTAMP_URL = 'https://<rfc3161-service>'
$env:POKROV_WINDOWS_SIGNING_STORE_LOCATION = 'CurrentUser'

pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 `
  -RequireTrustedWindowsSigning
```

The helper accepts no PFX file or password. It resolves one non-self-signed,
currently valid Code Signing certificate from `CurrentUser/My` or
`LocalMachine/My`, requires a trusted chain, signs the staged UI and service
before packaging, and passes the same signer to Inno Setup for both the final
installer and its embedded uninstaller. It verifies the setup and Inno's signed
uninstaller evidence file for the exact signer identity plus timestamp
certificate with `Get-AuthenticodeSignature`. The public manifest records file
hashes and certificate identities only. A missing tool, partial input,
untrusted chain, signer mismatch, missing timestamp or unsigned target stops the
build.

## Retained History

Prior Windows packages, hashes and pre-service notes are preserved as
[2026-08-21-windows-release-readiness-snapshot.md](history/2026-08-21-windows-release-readiness-snapshot.md).
They cannot approve `1.2.0`.
