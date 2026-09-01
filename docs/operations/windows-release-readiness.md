# Windows Release Readiness

Last updated: 2026-09-01

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains the current Windows gate for the `1.2.0` working target.
Older unsigned packages and pre-service behavior are retained as evidence.

## Current Truth

| Fact | Current state |
|---|---|
| Retained public Windows release | Unsigned direct setup `1.1.6` |
| Working package target | `1.2.0+4049` |
| Latest signed candidate | `pokrov-1.2.0-candidate.19`, app `1.2.0+4049`; setup `0782152d…f8ff`, signed release index `bb789707…6a87`, detached signature `1d39b7bb…e38`, promotion false; immutable `NO_GO` after the local rule-set service-boundary failure below |
| Current promotable candidate | None. The bounded rule-set materialization correction is source proof only and requires a new exact candidate. |
| Runtime architecture | Unelevated UI plus authenticated SCM service |
| Required service | `pokrov_service.exe` |
| Active candidate Core | Secret-safe POKROV Core `1.1.0`, desktop ABI `2`, exact source `cd8f0f4…884d`, reproducible DLL `f284fa88…8204`; the same Core bytes are bound into candidate.17, candidate.18 and candidate.19 |
| Exact candidate.17 setup | `0afaf6e1…276c`, `28932793` bytes; signed tuple client/Core/platform/index `977c6ed…/cd8f0f4…/d6898e6…/2df538c…`; `8/8` runtime manifest and unsigned owner exception; rejected because clean Windows lacks the unbundled VC runtime and setup incorrectly returned success after service-start failure |
| Corrected Windows pre-candidate | Setup `301d72fc…3ddc`, `29135238` bytes; manifest `4c9afeb4…f93a`; client `977c6ed…` plus reviewed diff `379a87fc…6f6f`; `11/11` files, app-local Microsoft VC143 runtime, transactional service failure, automatic cleanup and 1.1.6 per-user migration |
| Retained candidate.16 setup | `0afaf6e1…276c`, `28932793` bytes; older signed tuple `75ba7e7…/cd8f0f4…/719e23d…/54cfa03…`; immutable predecessor evidence only |
| Retained candidate.12 setup | `ebbe06f5…89c99c`, `28931263` bytes, exact client/Core `5b1aa02…/cd8f0f4…`; immutable rejected predecessor |
| Exact candidate.8 setup | `26ec26d8…4668`, `28929376` bytes, exact client/Core `3459438…/a45d69e…`; unsigned owner exception |
| Retained previous-resolver setup | `6ef7899d…cbe9`, `28918848` bytes, client source `b4c9117…9f0`; immutable superseded evidence |
| Retained public Core | `1.0.3`; rollback/history identity only |
| Portable ZIP | Unsupported for the service-first runtime |
| Support-mode signing public pin | `PASS_EXACT_ARTIFACT` — tracked `pokrov-support-2026-08`, carried by the unchanged candidate.16 artifact set |
| Trusted signing for `1.2.0` direct beta | `SKIPPED_BY_OWNER` on `2026-08-24`; warning required |
| Trusted/signed/Store/broad-stable claim | `BLOCKED_BY_ACCESS`; trusted Authenticode still required |
| Candidate.17 clean Windows VM | `FAIL`; missing `msvcp140.dll`, `vcruntime140.dll` and `vcruntime140_1.dll` prevented service start, while setup incorrectly exited `0`. Candidate.17 remains rejected history. |
| Corrected pre-candidate clean Windows VM | `PASS_EXACT_PRE_CANDIDATE_CURRENT_HOST_CLEAN_APP_STATE` — exact install, 11/11 files, LocalSystem service, authenticated IPC, restart, uninstall and unchanged idle route/DNS; this is not candidate.18 or live connected-network proof |
| Candidate.18 non-elevated UI | `FAIL_EXACT_CANDIDATE18_WINDOWS11_VM_NON_ELEVATED_IPC`: install and 11/11 identity passed, but the ordinary UI could not read the protected LocalSystem process token, closed the pipe as untrusted and the service stopped with Win32 code `5` |
| Source correction A/B | `PASS_DIAGNOSTIC_SOURCE_UI_ON_CANDIDATE18_INSTALL`: SCM PID/state/path/account binding kept the ordinary UI and service alive and recorded accepted IPC plus status; this is not exact-candidate proof |
| Candidate.19 clean Windows VM | `FAIL_EXACT_CANDIDATE19_WINDOWS11_VM_CORE_005`: exact setup identity, LocalSystem service, ordinary-user authenticated IPC, fresh-profile authorization, entitlement and profile staging passed; Core rejected service-relocated local rule-set paths, and the service completed rollback without reporting connected |
| Rule-set source correction | `PASS_LOCAL_SOURCE`: the Windows client packages bounded local binary rule sets, the service validates and stages exact bytes in protected A/B generations, and malformed or oversized input fails closed; this is not candidate.20 or live-network proof |
| Public 1.1.6 migration | `PASS_PRE_CANDIDATE_VM` — exact per-user 1.1.6 install was removed only after the new machine-wide service started; new uninstall record existed, old directory/key disappeared, final uninstall left no service, app directory or owner registry residue |
| Clean VM live network | `MANUAL_OWNER_TEST`; TUN/DNS/AWG/egress and recovery were not exercised by the packaging correction smoke |
| Native crash profile | `PASS_LOCAL`: stack-only, no full dump default |

The ordinary UI does not load Core, run elevated or use a system-proxy
fallback. The service owns Core, managed state and recovery. Green state
requires the authenticated egress proof.

## Candidate.19 Local Rule-Set Rejection And Source Correction

Candidate.19 binds client `10f5516648fd40d6c94eb7a7ca0d05be161d393c`,
Core `cd8f0f4169d570d693992a959d81d17c2c44884d`, platform
`d6898e63c5c9ab7dd267b9d5150b54196f99d967` and release-index source
`43fc20fd25342f314554a89ef75e1122f00aee01`. Its exact Windows setup is
`29129601` bytes with SHA-256
`0782152d3a992b1b6320043b9b8ccedb2944b76dcbf939bf7a6ebdad9759f8ff`.
The signed release index SHA-256 is
`bb78970700d8dc51b6b31caabb76a9b4ca6c94da2f8eef82f1c99ab61b5e6a87`;
its detached-signature SHA-256 is
`1d39b7bb7b20481bd165348abc1321ccd9ef4131021505c4054a8c22f6c24e38`.

On the clean Windows 11 VM, the exact candidate installed, the automatic
LocalSystem service stayed running, the ordinary UI authenticated through the
SCM-bound IPC path, and a fresh client profile completed authorization and
entitlement. Profile staging and the connect request reached the service, but
Core returned `CORE-005`; the service stopped the attempted runtime, completed
rollback and did not report a connected state.

The sanitized Core-start diagnostic isolates the cause. Candidate.19 writes
absolute local rule-set paths under the ordinary user's AppData into the
managed profile. The service moves that profile into its protected ProgramData
working root without moving the referenced `.srs` files. Core consequently
resolves a path shaped as the service working directory followed by the
original absolute AppData path and rejects it. This is a client-to-service
materialization defect, not evidence of a server-node, DNS, Germany, SPB or
Core-binary failure.

Sanitized evidence is retained outside the repository:

- service event sequence:
  `E:\POKROV-tools\temp\candidate19-service-events-safe-v2.json`, SHA-256
  `c5ae94aca1d451a4bf2489cd71f438b07f3582a2978260b3b075779b390a70d0`;
- managed-profile shape:
  `E:\POKROV-tools\temp\candidate19-managed-profile-shape.json`, SHA-256
  `3f6a288590cf3e637468bea9302179a9211a5ae43cc582a857a190669389ccf4`;
- one-shot sanitized Core-start result:
  `E:\POKROV-tools\temp\candidate19-core-start-diagnostic-safe.json`, SHA-256
  `cafd6a7c4beafa09b3d46473279e8b00357bd04176e26274d4027bfed6d829c2`.

The source correction adds a Windows-only bounded bundle. The ordinary client
reads materialized local binary rule sets, removes caller-local paths from the
service payload and sends canonical sequential assets. The service validates
the framing, count, names, base64 and size limits, writes exact bytes into a
protected alternate generation, binds the profile to service-relative paths
and removes the superseded generation only after the new profile is staged.
Candidate.19 remains immutable `NO_GO`; the correction must merge and receive a
new candidate identity before clean-VM TUN, DNS, egress and rollback evidence
can be credited.

## Candidate.18 Non-Elevated UI Rejection And Source Correction

Candidate.18 binds client `820ca101…ca5`, Core `cd8f0f41…884d`, platform
`d6898e63…967` and release-index source `5dc25bdd…759`. Its exact setup SHA-256
is `21dca69a4cffe9648bf9788c1279606896c798b32617dd88fa0d9c1e9c1bf2d3`.
The clean Windows 11 VM installed it successfully, matched all `11/11`
manifest files and registered the automatic LocalSystem service for the
correct installation owner.

The exact candidate still fails the required ordinary-user boundary. In a
matched interactive launch without UAC, candidate.18 UI
`d67ea5dc…855d` opened the service pipe and then attempted to read the
LocalSystem process token. Windows denied that query, the UI classified the
server as untrusted and closed the connection, and the service stopped with
Win32 exit code `5`. Sanitized reproduction evidence is retained outside the
repository at
`E:\POKROV-tools\temp\candidate18-non-elevated-ipc\candidate18-old-ui-repro.json`,
SHA-256 `4042ad57…fba8`.

The source correction authenticates the pipe PID against the running
`POKROVService` SCM record, exact sibling binary path and LocalSystem start
account. Those SCM queries are available to the ordinary UI and preserve the
same fail-closed identity checks without reading the protected process token.
A matched A/B using source-built UI `02bae8b2…639b` over the unchanged
candidate.18 installation kept the service `Running` with exit code `0` and
recorded `ipc_session_accepted` plus a status request. Sanitized diagnostic
evidence SHA-256 is `6cf2d905…b1f`.

This A/B proves the cause and source correction only. Candidate.18 remains
immutable `NO_GO`; the correction must merge, rebuild, receive a new signed
candidate identity and repeat the non-elevated install/IPC, TUN/DNS/egress and
rollback gates before promotion.

## Candidate.17 Rejection And Corrected Pre-Candidate

Candidate.17 passed its signed supply contract and hosted exact-source replay,
but a Windows 11 VM without developer tooling exposed a release-blocking
packaging defect. `pokrov_service.exe` imports `msvcp140.dll`,
`vcruntime140.dll` and `vcruntime140_1.dll`; candidate.17 did not ship them and
the clean VM did not have them. SCM therefore could not start the service. The
same run also proved that the installer could report exit code `0` after the
service failure. Candidate.17 is immutable rejected evidence and cannot be
promoted.

The current source-bound correction does three things:

- resolves the official x64 `Microsoft.VC143.CRT`, requires a valid Microsoft
  Authenticode signature on each of the three DLLs, copies them app-local and
  binds them into the release manifest;
- registers and starts the service as the final `[Files]` action, returns
  setup exit code `4` on failure and automatically removes partial service,
  files and owner-registry state;
- detects the retained public 1.1.6 per-user install under
  `{localappdata}\Programs\POKROV` and removes it only after the new
  machine-wide service has started successfully. Missing or residual legacy
  uninstall state fails closed.

Exact pre-candidate evidence:

| Evidence | Exact value |
|---|---|
| Setup | `pokrov-windows-x64-1.2.0+4049-setup.exe` |
| Setup size | `29135238` bytes |
| Setup SHA-256 | `301d72fc01fe32e4add5ff0e546d2923138c9e1005834deb361f3aa817603ddc` |
| Build manifest SHA-256 | `4c9afeb47044ee74fda87574c0775f399f4ecc3e73c6437ef4f0a48a1109f93a` |
| Source identity | client `977c6edd21d4746d5b1b8770d031734df46ad108` plus diff `379a87fce3f8f9b52dc509ee94897ec579c9da3306f0cf62e11195d571946f6f`; Core `cd8f0f4169d570d693992a959d81d17c2c44884d`; platform `d6898e63c5c9ab7dd267b9d5150b54196f99d967` |
| Required-file readback | `11/11 PASS`, including the three Microsoft VC143 runtime DLLs |
| Clean Windows VM smoke | `PASS_EXACT_CANDIDATE_CURRENT_HOST_CLEAN_APP_STATE_INSTALL_SERVICE_IPC_RESTART_UNINSTALL_IDLE_NETWORK` |
| Clean Windows VM evidence SHA-256 | `6e7f8d65c59314e768c5b1e7fdae67f1cdc73fbbc447a0da0cf0a5f34506d75b` |
| 1.1.6 migration | `PASS_PUBLIC_1_1_6_PER_USER_TO_1_2_0_MACHINE_MIGRATION_AND_CLEAN_UNINSTALL` |
| Migration evidence SHA-256 | `6e83f0900db2db073202fab99f5518a898d8e965f3bc1cb23d7f9a3a4412e588` |
| Forced missing-runtime fixture | setup exit `4`; service, install directory and owner registry absent after automatic cleanup |
| Diagnostic fixture SHA-256 | `00a4e72a38e38e5ed596834ebda93ea04c98dc07881a34442d380f3fa66a4c0f`; diagnostic only, never a release artifact |
| Diagnostic result SHA-256 | `4aacef1c4105cbf0d95896fd81dd7675327c969be4b4a8ab03ae0d63ecc36c78` |
| Signing | `SKIPPED_BY_OWNER`; mandatory SmartScreen/unknown-publisher warning |

The clean-VM smoke proves installation, exact installed identities, service,
authenticated IPC, stop/restart, clean uninstall and unchanged idle route/DNS
for these exact pre-candidate bytes. The migration run additionally starts from
the exact public 1.1.6 setup and proves removal of its per-user directory and
HKCU uninstall record before final cleanup. Evidence is retained outside the
repository under
`E:\POKROV-tools\temp\candidate18-winvm-harness-v3`. Candidate.18 later bound
the same setup bytes and passed exact hosted replay, but the newly executed
ordinary-user A/B above supersedes its elevated-UI IPC pass and rejects the
candidate.

## Retained Build 4049 Core And Candidate.16/17 Evidence

The continuing source line pins Core `cd8f0f4169d570d693992a959d81d17c2c44884d`
after removing legacy raw-settings/error logging and retaining explicit
AWG2/AWG 3.1 lifecycle coverage. Two Windows builds are byte-identical: DLL
size `55426048`, SHA-256
`f284fa8841f1a45271874a7a05ed6093fb0e3efbdd03e00001edd046be708204`,
with all 15 ABI exports; pinned Cronet remains `8ef1f8bb…a6f7`. The exact DLL
also passes the host-safe 100-cycle proxy start/stop harness. These Core results
are retained in signed candidate.16 and candidate.17. Candidate.17's exact
setup SHA-256 is
`0afaf6e1d73a7e72762d945557f48793646a9bdbf12bb8ca2e843d4b94df276c`,
size `28932793`, and its runtime manifest matches all `8/8` required files.
That manifest was incomplete because it omitted the three VC runtime DLLs;
candidate.17 is rejected despite its passing source and supply checks. The
candidate.16 current-host install/service/IPC/restart/uninstall evidence below
remains valid only for those old bytes and that host. It does not override the
candidate.17 clean-VM failure or transfer to the corrected pre-candidate.

Local source and fault-injection tests alone cover IPC, journal, network
snapshot and rollback logic without installation. The separate candidate.16
current-host smoke below performed and then removed a bounded installation.
The native crash filter writes only exception code plus at most 32 allowlisted
module-relative frame offsets. UI and service use separate protected
current/previous files; paths, symbols, registers, exception text, heap and full
memory dumps have no output field. The controlled-crash and recovery readback
still belongs to the exact-candidate gate below.

## Candidate.16 Current-Host Evidence

`config/windows-clean-host-gate.candidate-16.json` binds exact setup
`0afaf6e1…276c` to signed manifest `ae1906e6…ffe6`, signature
`f5df6357…07a9a`, client `75ba7e7…6722`, Core `cd8f0f4…884d`, platform
`719e23d…e37c`, release-index `54cfa03…429f`, and all eight installed files.
The file is Authenticode `NotSigned` under the owner exception for the `1.2.0`
direct beta; the SmartScreen/unknown-publisher warning remains mandatory.

From a clean POKROV app-state baseline on the owner Windows 11 host, the
elevated exact-candidate smoke passed:

- silent machine-wide install and exact `8/8` installed-file readback;
- automatic LocalSystem service identity and install-owner binding;
- authenticated installed UI-to-service IPC plus status request;
- SCM stop/restart;
- clean uninstall of service, files and owner registry state;
- byte-identical pre/post idle route and DNS fingerprints with zero residual
  POKROV/Wintun adapters.

Sanitized evidence SHA-256 is
`42d39bf86801ac5d4af50be1a32fa4172b69bc13025a19ab26970a956d1e0db1`.
The post-check independently confirmed no service, UI process, install
directory, owner registry record or POKROV/Wintun adapter remained.

A separate connected attempt did not advance the network gate. The installed
UI reported `Пока недоступно` and required account preparation before it would
enable connection, so no TUN, DNS or egress probe was run. The attempt was
aborted and rolled back; sanitized failure evidence SHA-256 is
`0193b11d8b914643f3e27bc2dcadbdd81d529b9162c8664e92afb729f1916e32`.
Its cleanup confirms route/DNS restoration and zero installed residue. This is
`FAIL_CURRENT_HOST_ACCOUNT_READINESS`, not a product-wide account failure and
not clean-VM or connected-network proof.

Evidence ceiling:
`EXACT_CANDIDATE_CURRENT_HOST_CLEAN_APP_STATE_INSTALL_SERVICE_AUTHENTICATED_IPC_RESTART_UNINSTALL_AND_NO_IDLE_NETWORK_MUTATION_ONLY`.
Live TUN, DNS capture, authenticated egress, AWG2/AWG3.1, sleep/reboot/crash
recovery, connected uninstall and interactive SmartScreen remain
`MANUAL_OWNER_TEST`.

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
None of its clean-host, network or SmartScreen rows transfers to candidate.16.

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
- Local tests prove source contracts and isolated recovery logic. The exact
  corrected pre-candidate additionally has the bounded clean-VM and 1.1.6
  migration evidence stated above; it has no live connected-network proof.
- Current platform source `d6898e6…967` and the active client/Core source
  preserve the AWG2/AWG3.1 contracts. The exact `cd8f0f4` Windows DLL is
  built twice byte-identically, exposes all 15 required symbols and passes 100
  proxy-only start/stop cycles without changing system routes.
- Candidate.17 remains signed but rejected: its eight-file setup omits the
  required VC runtime and could falsely return success after service failure.
  The corrected pre-candidate setup `301d72fc…3ddc` has an eleven-file manifest
  and passes clean-VM install/service/authenticated IPC/restart/uninstall plus
  public 1.1.6 per-user-to-machine migration. Candidate.18 bound the later
  `21dca69a…f2d3` setup but is also rejected by the exact non-elevated IPC
  failure above. Candidate.19 proves the SCM correction but is rejected by the
  exact local rule-set service-boundary failure. The bounded rule-set source
  correction has no new exact-candidate or live TUN/DNS/AWG/egress proof.
- The earlier current-origin reverse-UDP block was isolated to wrong
  reply-source selection on the multi-addressed owned server. After guarded
  source-port policy routing and service-cycle readback, exact current-origin
  Core interop passes both AWG2 and AWG3.1. This did not exercise the Windows
  client app, SCM service, TUN, DNS capture or leak protection, so those rows
  remain `MANUAL_OWNER_TEST`.
- Signed-manifest candidate.19 exists with promotion false and a Windows
  `NO_GO`. Candidate.18, candidate.17, candidate.16, candidate.8 and candidate.3
  remain retained history for their own older bytes only.
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

The builder normally discovers the latest installed official x64
`Microsoft.VC143.CRT` through `vswhere.exe`. A controlled build environment may
set `POKROV_MSVC_RUNTIME_DIRECTORY` to the exact runtime directory; all required
DLLs still must exist and carry valid Microsoft Authenticode signatures.

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
