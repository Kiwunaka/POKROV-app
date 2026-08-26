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
| Support-mode signing public pin | `PASS_SOURCE_CONTROL` — `pokrov-support-2026-08`, SHA-256 `44aed433…8845`; no new EXE built |
| Trusted signing for `1.2.0` direct beta | `SKIPPED_BY_OWNER` on `2026-08-24`; warning required |
| Trusted/signed/Store/broad-stable claim | `BLOCKED_BY_ACCESS`; trusted Authenticode still required |
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
| Machine-wide setup package | `PASS_EXACT_CANDIDATE_1` — private run `33013112167` installed exact unsigned setup SHA-256 `730428bf…8de`; all eight manifest-bound installed files matched, but the candidate predates current source heads |
| Exact EXE support signing pin | `MISSING` — tracked pin exists, replacement setup bytes do not |
| Service install/start and UI authentication | `FAIL_EXACT_CANDIDATE_1` — SCM service did not remain running after clean install; authenticated IPC was not reached |
| Trusted code signing and timestamp | `SKIPPED_BY_OWNER` for the exact `1.2.0` direct-download beta only; fail-closed trusted tooling remains ready for the later signed lane |
| Clean-host TUN/DNS/egress | `MANUAL_OWNER_TEST` |
| Crash/reboot/sleep/SCM recovery | `MANUAL_OWNER_TEST` |
| Route and DNS restoration | `MANUAL_OWNER_TEST` |
| Uninstall while connected | `MANUAL_OWNER_TEST` |
| SmartScreen/reputation observation | `MANUAL_OWNER_TEST` |
| Strict-v2 size/SHA-256/source binding | `PASS_LOCAL` — handoff SHA-256 `8d9a2d00…b806` retained in local pre-candidate staging; does not prove trusted signing |
| Anonymous download and install | `NOT_RUN` |
| Rollback drill | `NOT_RUN` |

The private, manual `Windows Exact Candidate Clean Host` workflow ran against
candidate.1 on a fresh GitHub-hosted Windows runner. The carrier remains inside
the private repository as a non-latest prerelease so the read-only workflow can
download it. Run `33013112167` proved the exact installer identity, clean
baseline, silent machine-wide install, and all eight installed file identities,
then failed closed at `service_contract` with `service_not_running`; cleanup and
sanitized evidence upload completed. Diagnostic run `33013868113` showed that
the owner registry value existed and matched the installer user while the SCM
record, process, and service journal were all absent. This isolates the defect
to unchecked, incorrectly quoted `sc create` packaging commands rather than a
service-process crash. The builder now configures SCM from checked Inno code,
uses one correctly quoted binary path, and aborts installation on every nonzero
SCM result; replacement candidate proof is pending. A future pass may advance
service identity, authenticated UI/service IPC, idle restart,
clean uninstall, and unchanged idle route/DNS fingerprints only. It cannot
advance live TUN, DNS capture,
authenticated egress, sleep/reboot/crash recovery, uninstall while connected,
or interactive SmartScreen reputation checks; those remain
`MANUAL_OWNER_TEST`.

## Safe Current Claims

- The `1.2.0` source targets an unelevated UI and authenticated Windows service.
- Local tests prove source contracts and isolated recovery logic only.
- No final-source, clean-host-verified `1.2.0` Windows candidate exists yet.
- The owner authorizes one unsigned direct-download beta with the mandatory
  SmartScreen/unknown-publisher warning. This is not trusted-signing evidence
  and permits no signed, Store or broad-stable claim.
- The retained unsigned `1.1.6` publication does not prove `1.2.0` trust,
  recovery or network behavior.

## Verification Commands

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-seed.ps1 `
  -PlatformRoot C:\path\to\platform `
  -CoreRoot C:\path\to\POKROV-core

pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1
```

Unsigned packaging for the exact `1.2.0` direct-download beta records
`SKIPPED_BY_OWNER` with blocker code
`OWNER_ACCEPTED_UNSIGNED_WINDOWS_BETA_1_2_0`. Candidate assembly must retain
the mandatory SmartScreen warning and may not claim trusted signing, Store
availability or broad-stable Windows status. The exception expires when a
trusted signer becomes available and does not apply to another version or
channel.

Trusted candidate packaging is fail closed:

```powershell
$env:POKROV_WINDOWS_SIGNING_CERTIFICATE_THUMBPRINT = '<40-hex store thumbprint>'
$env:POKROV_WINDOWS_SIGNING_EXPECTED_SUBJECT = '<exact certificate subject>'
$env:POKROV_WINDOWS_SIGNING_TIMESTAMP_URL = 'https://<rfc3161-service>'
$env:POKROV_WINDOWS_SIGNING_STORE_LOCATION = 'CurrentUser'

pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 `
  -CheckTrustedWindowsSigningReadinessOnly

pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 `
  -RequireTrustedWindowsSigning
```

The readiness-only command stops before version/support-key validation, build,
signing or packaging. It validates the exact certificate-store identity,
private-key presence, exact subject, Code Signing EKU, validity, online
trusted-chain result, HTTPS timestamp URL shape and SignTool availability. On
success it prints a public
`pokrov.windows-signing-readiness-receipt.v1` JSON receipt with exact public
certificate identity plus `artifacts_signed=false`, `candidate_created=false`
and `production_runtime_mutated=false`. It does not contact the timestamp
service, sign bytes or prove candidate eligibility; the full build must still
prove private-key usability, sign and verify every required target and RFC3161
timestamp.

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
