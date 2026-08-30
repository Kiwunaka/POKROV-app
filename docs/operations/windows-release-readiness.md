# Windows Release Readiness

Last updated: 2026-08-30

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains the current Windows gate for the `1.2.0` working target.
Older unsigned packages and pre-service behavior are retained as evidence.

## Current Truth

| Fact | Current state |
|---|---|
| Retained public Windows release | Unsigned direct setup `1.1.6` |
| Working package target | `1.2.0+4048` |
| Exact replacement candidate | `pokrov-1.2.0-candidate.8`; signed manifest `f0006cec…906f`, detached signature `5fcae067…24f6`, promotion false |
| Runtime architecture | Unelevated UI plus authenticated SCM service |
| Required service | `pokrov_service.exe` |
| Active pre-candidate Core | Secret-safe POKROV Core `1.1.0`, desktop ABI `2`, exact source `cd8f0f4…884d`, reproducible DLL `f284fa88…8204` bound; exact candidate.8/10 remains on the older immutable Core |
| Exact candidate.8 setup | `26ec26d8…4668`, `28929376` bytes, exact client/Core `3459438…/a45d69e…`; unsigned owner exception |
| Retained previous-resolver setup | `6ef7899d…cbe9`, `28918848` bytes, client source `b4c9117…9f0`; immutable superseded evidence |
| Retained public Core | `1.0.3`; rollback/history identity only |
| Portable ZIP | Unsupported for the service-first runtime |
| Support-mode signing public pin | `PASS_EXACT_ARTIFACT` — `pokrov-support-2026-08`, SHA-256 `44aed433…8845`, bound by candidate.8 supply evidence |
| Trusted signing for `1.2.0` direct beta | `SKIPPED_BY_OWNER` on `2026-08-24`; warning required |
| Trusted/signed/Store/broad-stable claim | `BLOCKED_BY_ACCESS`; trusted Authenticode still required |
| Candidate.8 current-host smoke | `PASS_EXACT_CANDIDATE_CURRENT_HOST_CLEAN_APP_STATE` — exact install, 8/8 files, LocalSystem service, authenticated IPC, restart, uninstall and unchanged idle route/DNS |
| Candidate.8 clean VM/live network | `MANUAL_OWNER_TEST` — current-host smoke is not a clean Windows 10/11 VM and did not connect TUN/DNS/AWG traffic |
| Native crash profile | `PASS_LOCAL`: stack-only, no full dump default |

The ordinary UI does not load Core, run elevated or use a system-proxy
fallback. The service owns Core, managed state and recovery. Green state
requires the authenticated egress proof.

## Working Build 4048 Core Refresh

The continuing source line pins Core `cd8f0f4169d570d693992a959d81d17c2c44884d`
after removing legacy raw-settings/error logging and retaining explicit
AWG2/AWG 3.1 lifecycle coverage. Two Windows builds are byte-identical: DLL
size `55426048`, SHA-256
`f284fa8841f1a45271874a7a05ed6093fb0e3efbdd03e00001edd046be708204`,
with all 15 ABI exports; pinned Cronet remains `8ef1f8bb…a6f7`. The exact DLL
also passes the host-safe 100-cycle proxy start/stop harness. These results are
`PASS_LOCAL_PRE_CANDIDATE`; no 4048 installer, clean-VM TUN/DNS/egress run,
trusted signature or SmartScreen reputation is claimed.

Local source and fault-injection tests alone cover IPC, journal, network
snapshot and rollback logic without installation. The separate candidate.8
current-host smoke below performed and then removed a bounded installation.
The native crash filter writes only exception code plus at most 32 allowlisted
module-relative frame offsets. UI and service use separate protected
current/previous files; paths, symbols, registers, exception text, heap and full
memory dumps have no output field. The controlled-crash and recovery readback
still belongs to the exact-candidate gate below.

## Candidate.8 Current-Host Evidence

The exact candidate.8 setup is hash-pinned by
`config/windows-clean-host-gate.candidate-8.json` to signed manifest
`f0006cec…906f`, signature `5fcae067…24f6`, client `3459438…f5c`, Core
`a45d69e…665e`, platform `241a83b…c39` and release-index source
`b242e0a…a8`. It is Authenticode `NotSigned` under the exact owner exception
for the `1.2.0` direct beta; the SmartScreen/unknown-publisher warning remains
mandatory.

On the owner Windows 11 host, POKROV service, install directory, owner registry
record and POKROV/Wintun adapter were absent before the run. The elevated
candidate.8 smoke then passed:

- silent machine-wide install and exact `8/8` installed-file size/SHA-256
  readback;
- automatic LocalSystem service identity and install-owner binding;
- installed UI to service authenticated IPC and status request;
- SCM stop/restart;
- silent uninstall with service, install directory and owner registry removal;
- unchanged idle route/DNS fingerprints and zero residual POKROV/Wintun
  adapters.

The retained sanitized evidence SHA-256 is
`2a0f8f71041614a340dfa4e7d5779b61099be7141e52a79dba6bd24cc78f6b85`.
The post-check independently observed the service, install directory and owner
registry record absent with zero POKROV/Wintun adapters. Bounded service runtime
evidence remains under protected `ProgramData`; it is retained rather than
rewritten as cleanup success.

Evidence ceiling:
`EXACT_CANDIDATE_CURRENT_HOST_CLEAN_APP_STATE_INSTALL_SERVICE_AUTHENTICATED_IPC_RESTART_UNINSTALL_AND_NO_IDLE_NETWORK_MUTATION_ONLY`.
This is not a clean OS/VM result and does not prove live TUN, DNS capture,
authenticated egress, AWG2/AWG3.1, sleep/reboot/crash recovery, connected
uninstall or interactive SmartScreen behavior.

## Retained Candidate.3 Evidence

The table keeps candidate.3 results only as exact evidence for its old bytes.
None of its clean-host, network or SmartScreen rows transfers to candidate.8.

| Check | Current state |
|---|---|
| Clean client/Core revisions | `PASS_SOURCE_CONTROL` — artifact source client `ac22825…ead`, exact Core artifact source `344b317…8f6`; client source run `33032033161` passed |
| Exact Core DLL and dependency identity | `PASS_LOCAL` — DLL `60fe3fad…3981`, Cronet `8ef1f8bb…a6f7`, exact bound Core source and 15 exports |
| Machine-wide setup package | `PASS_EXACT_CANDIDATE_3` — private run `33033294889` installed exact unsigned setup SHA-256 `9962e3e8…8021`, 28,898,240 bytes; all eight installed files matched |
| Exact EXE support signing pin | `PASS_EXACT_ARTIFACT` — candidate.3 supply evidence binds the active `pokrov-support-2026-08` public pin for these retained bytes; no private support key was read or exported |
| Service install/start and UI authentication | `PASS_EXACT_CANDIDATE_3` — exact LocalSystem service identity, install-owner binding, accepted authenticated IPC and status request; candidate.1 remains failed history |
| Trusted code signing and timestamp | `SKIPPED_BY_OWNER` for the exact `1.2.0` direct-download beta only; fail-closed trusted tooling remains ready for the later signed lane |
| Clean-host TUN/DNS/egress | `MANUAL_OWNER_TEST` |
| Crash/reboot/sleep/SCM recovery | `MANUAL_OWNER_TEST` |
| Route and DNS restoration | `PASS_EXACT_CANDIDATE_3_IDLE_ONLY` — clean-host route/DNS fingerprints remained unchanged after idle install/restart/uninstall; connected restoration remains `MANUAL_OWNER_TEST` |
| Uninstall while connected | `MANUAL_OWNER_TEST` |
| SmartScreen/reputation observation | `MANUAL_OWNER_TEST` |
| Strict-v2 size/SHA-256/source binding | `PASS_SIGNED_CANDIDATE_3` — handoff `eba6d4c2…72ee`, manifest `a2752b6a…1090`, signature `926f0b46…7121`; promotion is false |
| Anonymous download and install | `NOT_RUN` |
| Rollback drill | `NOT_RUN` |

The private, manual `Windows Exact Candidate Clean Host` workflow first ran
against candidate.1 on a fresh GitHub-hosted Windows runner. Run `33013112167`
proved the exact installer identity, clean
baseline, silent machine-wide install, and all eight installed file identities,
then failed closed at `service_contract` with `service_not_running`; cleanup and
sanitized evidence upload completed. Diagnostic run `33013868113` showed that
the owner registry value existed and matched the installer user while the SCM
record, process, and service journal were all absent. This isolates the defect
to unchecked, incorrectly quoted `sc create` packaging commands rather than a
service-process crash. The builder now configures SCM from checked Inno code,
uses one correctly quoted binary path, and aborts installation on every nonzero
SCM result. Candidate.2 binds the replacement installer and all eight files to
signed manifest `1697a1bc…e5e0`. Its carrier remains inside the private
repository as a non-latest prerelease so the read-only workflow can download
the exact bytes. Clean-host run `33017409577` passed exact identity, silent
machine-wide install, LocalSystem service identity, authenticated UI/service
IPC, SCM stop/restart, clean uninstall, and unchanged idle route/DNS
fingerprints. The downloaded sanitized evidence SHA-256 is
`e0832ed8…0770`. This run cannot advance live TUN, DNS capture,
authenticated egress, sleep/reboot/crash recovery, uninstall while connected,
or interactive SmartScreen reputation checks; those remain
`MANUAL_OWNER_TEST`.

Candidate.3 binds the SPB/client correction and source-freeze build fixes to
signed manifest `a2752b6a…1090`. Its private carrier targets exact artifact
source `ac22825…ead`. Clean-host run `33033294889` downloaded the same EXE
bytes and passed exact identity, silent machine-wide install, all eight
installed-file identities, LocalSystem service identity, authenticated
UI/service IPC, SCM stop/restart, clean uninstall and unchanged idle route/DNS
fingerprints. The downloaded sanitized evidence SHA-256 is
`494f0cd7…1c62`. Live TUN, DNS capture, authenticated egress,
sleep/reboot/crash recovery, uninstall while connected and interactive
SmartScreen observation remain `MANUAL_OWNER_TEST`.

## Superseded 2026-08-29 Exact-Source Pre-Candidate Setup

Clean client source `75aabd9819b0e2dfd36efa3ddf7a8d7aa63a562c`
binds clean Core `3c2b1147c1b42e39026231525c08558a50bc3d0f`. The
release build synchronized the exact Core DLL, reused the already verified
public update/support verification pins and produced:

| Evidence | Exact value |
|---|---|
| Setup | `pokrov-windows-x64-1.2.0+4046-setup.exe` |
| Size | `28928829` bytes |
| SHA-256 | `f12dc8da726aa621834d630eca7b625388553dd131e7e71f7ff165724a26e6fa` |
| Build manifest SHA-256 | `442597ca283dcb40cc4e9c3dde5a572f2cc780f6f0a0af62f62d36bcc7a32946` |
| Core DLL in manifest | `58e329eaddb2dd1f40c1663b380a03a0c7c34c5a3e8506eb2c692611234ac082` |
| Signing | `SKIPPED_BY_OWNER`; Authenticode `NotSigned` |

The manifest retains blocker
`OWNER_ACCEPTED_UNSIGNED_WINDOWS_BETA_1_2_0`, requires the visible SmartScreen
warning and forbids trusted, signed, Store or broad-stable claims. All eight
required bundle files are hash-bound. Full client tests, seed/handoff
contracts and the exact DLL 100-cycle proxy-only check pass. Installation,
SCM/TUN/DNS/egress/recovery/uninstall and interactive SmartScreen observation
remain `MANUAL_OWNER_TEST`. This retained artifact binds the superseded
`3c2b114` DLL and cannot package or prove the active `547f096` runtime. It is
not candidate creation or promotion.

## 2026-08-29 Security-Fixed Exact-Source Setup

The active client bundle now contains Core `a45d69e…665e` DLL
`53b5e82a…4652`, size `55426048`. Two Windows builds are byte-identical, all 15
required ABI exports are present, and the exact bundled DLL passed 100
proxy-only start/stop cycles without changing system routes. Root and embedded
Core vulnerability scans report zero reachable findings after the
`GO-2026-6303` dependency correction. This source also makes the AWG endpoint
honor the configured default domain resolver for its inner FQDN while retaining
hostname-authenticated TLS and fail-close.

Clean client `b4c911773f2f7d8ae55a1ba0896abe700995d9f0` produced:

| Evidence | Exact value |
|---|---|
| Setup | `pokrov-windows-x64-1.2.0+4046-setup.exe` |
| Size | `28918848` bytes |
| SHA-256 | `6ef7899d8d3817c57a1fa8f451f4bf8410daecadc0c51d33c04fa60be0b8cbe9` |
| Build manifest SHA-256 | `8dced6056a8b6fc4eb2adc6ff501545a6b71c6cdf3fb3e8ab3d175726e4ff74b` |
| Bundle tree SHA-256 | `4b6029bf6e9f91919706c69a65bb71219ac74ccbac37742578e7fb44d55b53b8` |
| Retained evidence SHA-256 | `4a3bc7b9aca2882a62b991035657a8be05cc2215a1e1b4aec45b1549c549c730` |
| Core DLL in manifest | `6bf2243ffd907244bc70b1afdcc82a87c805fdc98804d4efd2bfaa1dc5a64c45` |
| Signing | `SKIPPED_BY_OWNER`; Authenticode `NotSigned` |

The manifest hash-binds all eight required bundle files, and retained-copy
readback has no missing, size or digest mismatch. This is
`PASS_PRE_CANDIDATE_ARTIFACT`, not candidate or clean-host proof. Clean
SCM/service/TUN/DNS/egress/recovery/uninstall and interactive SmartScreen proof
remain `MANUAL_OWNER_TEST`.

## 2026-08-29 Superseded Resolver-Corrected Pre-Candidate Setup

Clean client `f500728ce1fef54a32573263999652383cd86ad2` packages the exact
resolver-corrected Core `a45d69e40ed7d892619a2b5c4592a527f630665e`.
Seed, cross-repository, observability, source-logging, release-handoff,
repository-hygiene, presentation and performance contracts passed before the
Windows release build. Analyze/tests reuse the exact clean `15/15` aggregate
for this source tuple; they were not relabelled as a new run.

| Evidence | Exact value |
|---|---|
| Setup | `pokrov-windows-x64-1.2.0+4046-setup.exe` |
| Size | `28932687` bytes |
| SHA-256 | `81268d7e6db144c2944bde4be359e188b42b0bbad427d4f5a438510d9523723c` |
| Build manifest SHA-256 | `d2a7a9001280fee45af669a81d8e8aa753b246faef3818405494affc563d4805` |
| Bundle tree SHA-256 | `26e2e63b0c6d89bfe6c0b7078aa38cf77a13c676af73b69fa51b6e5bc729fbf7` |
| Core DLL | `55426048` bytes; `53b5e82a9c7bc20055c0889a1c8fabb5137f52ad09d38b23cf86477184474652` |
| Required-file readback | `8/8 PASS`; zero missing, size or digest mismatch |
| Signing | `SKIPPED_BY_OWNER`; setup, UI and service are Authenticode `NotSigned` |

The retained external evidence SHA-256 is
`6e33ca7781d5bb20020776aec79beccaf4f2ff7eb087b14a3b86b2bde95f2733`.
The build host has no available Windows Sandbox/Hyper-V isolation, so the setup
was not installed and the main host network was not mutated. This closes the
active-source packaging gap only. Clean-host SCM/service/TUN/DNS/AWG/egress,
recovery, connected uninstall and interactive SmartScreen remain
`MANUAL_OWNER_TEST`.

## Safe Current Claims

- The `1.2.0` source targets an unelevated UI and authenticated Windows service.
- Local tests prove source contracts and isolated recovery logic only.
- Current platform correction `f79974c…ee6` and the active client/Core source
  preserve the AWG2/AWG3.1 contracts. The exact `a45d69e` Windows DLL is
  built twice byte-identically, exposes all 15 required symbols and passes 100
  proxy-only start/stop cycles without changing system routes.
- Candidate.8 setup `26ec26d8…4668` packages exact client/Core
  `3459438…/a45d69e…`, retains the owner-approved unsigned-beta warning and
  passes its eight-file manifest readback. The owner current-host smoke passed
  install/service/authenticated IPC/restart/uninstall and unchanged idle
  route/DNS from a clean POKROV app-state baseline. It is not clean-VM or live
  network proof.
- The earlier current-origin reverse-UDP block was isolated to wrong
  reply-source selection on the multi-addressed owned server. After guarded
  source-port policy routing and service-cycle readback, exact current-origin
  Core interop passes both AWG2 and AWG3.1. This did not exercise the Windows
  client app, SCM service, TUN, DNS capture or leak protection, so those rows
  remain `MANUAL_OWNER_TEST`.
- Signed-manifest candidate.8 exists with promotion false. Candidate.3 remains
  retained history for its own older bytes only.
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
