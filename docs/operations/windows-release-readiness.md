# Windows Release Readiness

Retained release baseline: `pokrov-1.2.0-candidate.33`. The R12 source and local
lab entries below do not replace its packaged bytes or release decision.

R12 new A03 Core package (2026-09-08): [installed Windows evidence](evidence/2026-09-08-r12-awg-crossfield-windows/README.md)
binds client `295ceac` / Core `02a091c` to an actual 305-file upgrade and ordinary
AWG3.1 → AWG2 → AWG3.1 reconnects. Three disconnects restore exact route/DNS
hashes; package files remain unchanged. Original rollout restored, clone off
with NIC none, host network unchanged. This supersedes the earlier absence of
installed Windows proof for these bytes within this bounded scenario only.
Independent route, effective location, new Android bytes and full release gates
remain open.

R12 connected recovery (2026-09-08): [installed Win11 evidence](evidence/2026-09-08-r12-connected-recovery/README.md)
confirms forced UI termination preserves the running AWG31 service/TUN and
relaunch observes it. Graceful connected reboot returns to safe disconnected
state with exact route/DNS baseline, automatic LocalSystem service and all
305 package hashes unchanged. Original rollout configuration restored; clone
off/NIC none; host route/DNS hashes unchanged. Service-process crash, sleep,
post-reboot reconnect, WFP, IPv6, Win10 and final-channel acceptance remain open.

R12 managed switching (2026-09-08): [installed Win11 evidence](evidence/2026-09-08-r12-managed-switching/README.md)
confirms ordinary UI AWG3.1 → AWG2 → AWG3.1 reconnect, protected service-file
changes and exact return hash, with three running/identity observations and
route/DNS recovery after every disconnect. All 305 installed hashes match.
Independent route proof remains open: unchanged external IP and an unverified
DE SSH host-key change prevented server counter correlation. The original
cohort is restored; VM is off with NIC disabled. Full N01/N03/W01, effective
location presentation, crash/sleep/WFP, Win10 and final candidate remain open.

R12 upgrade and installed cancellation (2026-09-08): [source-bound lab evidence](evidence/2026-09-08-r12-upgrade-managed/README.md)
closes the reproduced Restart Manager shutdown failure and exact obsolete-test
cleanup. Repeated Win11 upgrade, 305 package hashes, unchanged saved state and
ordinary-account IPC PASS. Installed AWG31 service proof was observed; disconnect
and cancellation restore guest route/DNS hashes, with cancellation returning in
2110 ms. Identical external IP hashes limit independent route proof. The temporary
server cohort is fully restored, host routes/DNS unchanged, and the disposable
VM powered off with NIC disabled. Full switching, blocking-call cancellation,
sleep/crash/connected update, WFP, Win10 and final candidate remain OPEN.

R12 IPC cancellation (2026-09-08): concurrent status/cancel, serialized runtime
mutations, cancellable WinHTTP and a worker for UI service calls now have
[source-bound component proof](evidence/2026-09-08-r12-ipc-cancellation/README.md).
Native 12/12, Windows Flutter 24 and runtime Flutter 80 PASS (one exact-DLL
case SKIPPED). Offline Win11 fixtures passed, with an integration recheck after
supplying an omitted test EXE; installed 305 hashes stayed unchanged. Matching
UI/service packaging, blocking Core cancellation, live TUN, WFP coexistence,
Win10 and final candidate gates remain OPEN. Earlier entries below are dated
snapshots; their cancellation gaps are advanced only within this fixture scope.

R12 connect interruption (2026-09-08): a deadline or SCM stop observed between
connection stages now rolls back before publishing protection. Six local
fault scenarios cover pre-mutation, late Core/probe completion, journal commit
and failed rollback; [source-bound evidence](evidence/2026-09-08-r12-connect-interruption/README.md)
retains the failed regression and passing native/runtime suites. This is local
source proof. Blocking-call interruption, correlated IPC cancellation,
concurrent mutations and installed managed-network acceptance remain OPEN.

R12 IPC timeout (2026-09-08): fixed stalled sessions blocking the sole pipe
and an unread reply blocking SCM stop. [Native and installed red/green proof](evidence/2026-09-08-r12-ipc-timeout/README.md)
shows another client admitted after 3.0–3.05 seconds and SCM stop in 10 ms.
The VM experiment replaced only the service EXE, then restored all 305 original
package hashes. Correlated Core/network cancellation, concurrent mutations,
WFP coexistence, connected recovery, Win10 and final-channel gates remain OPEN.

R12 installed IPC (2026-09-07): the standard-account lifecycle package passes
eight ordinary-owner protocol cases and denies a filtered non-owner token.
[Actual service evidence](evidence/2026-09-07-r12-installed-ipc/README.md)
binds every pipe connection to SCM PID, replay/session/deadline/frame rejection,
and 305 unchanged installed files. W06 cancellation/concurrent mutations,
WFP coexistence, managed network, Win10 and final channel remain OPEN.

R12 installer (2026-09-07): fixed clean installation when UAC elevates a
separate ordinary account through another administrator. Owner SID capture now
uses the original process's tagged exit codes instead of an elevated temporary
file. [Exact red/green package proof](evidence/2026-09-07-r12-standard-installer/README.md)
passes clean install, all 305 file hashes, standard-account stock UI/IPC,
uninstall, reinstall and automatic SCM start before login after a planned
reboot. These unsigned loopback-API packages do not close managed-network,
connected update/recovery, Win10 or final-channel gates.

R12 SCM lab (2026-09-07): current service and Core `8dc57a8` pass real
LocalSystem start, limited-token owner IPC, explicit Core initialization and
clean stop on the offline Win11 clone. [Exact component evidence](evidence/2026-09-07-r12-scm-lab/README.md)
retains the rejected fixture attempts and schema-aware lifecycle results. The
filtered token belongs to the existing administrator account; full non-admin
UI/installer, TUN/network, Win10 and final-channel acceptance remain open.

R12 Windows shell (2026-09-07): `0f115d0` fixes repeated hidden startup and
`98c39d6` fixes native teardown re-entry. The offline Win11 clone passes the
six activation/visibility scenarios and exits cleanly through both message-loop
termination and the real tray Exit item. [Current bounded evidence](evidence/2026-09-07-r12-w04-shell/README.md)
binds exact local bytes and retained red/green results. SCM, installer, login
boot, managed-network and final-channel acceptance remain open; retained
`pokrov-1.2.0-candidate.33` is unchanged.

R12 Win11 component lab (2026-09-06): seven Release native test executables pass
on the offline linked clone `d5ae2f7a-96c3-48b5-a2ba-5e009948ee27`, Windows
`10.0.26200`, client `ded58b1`, Core `94dd310`.
[Guest evidence](evidence/2026-09-06-r12-win11-component-lab/evidence.json)
retains binary/source/log hashes and the rejected first collector run. Runtime
Core/egress/network backends are fixtures; no service, UI, installer or TUN
acceptance is claimed. A clone-pinned SCM start/status/stop script is prepared
for manual UAC execution at that historical cutoff; the newer SCM evidence
above executes the current component scenario.
Retained candidate `pokrov-1.2.0-candidate.33` and its release gate are unchanged.

R12 local staging correction (2026-09-05): the service now secures the pending
profile before atomic replacement. A `SecureFile` failure retains the previously
acknowledged profile bytes and reports `profile_security_failed`; the caller does
not receive a successful stage acknowledgement. The native runtime regression
first reproduced loss of the old file, then passed after the fix. This source
test does not establish packaged install, durable profile rollback, service
effective revision or clean-VM TUN proof for a new candidate.

Last updated: 2026-09-06

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains the current Windows gate for the `1.2.0` working target.
Older unsigned packages and pre-service behavior are retained as evidence.

## Current Truth

The local C05 runtime binding uses Core
`8dc57a830bd1487389dd1b7c9190f094c31e13bc`, Go 1.26.8 / x/crypto 0.56.0 and the
Psiphon TLS layout correction, retaining managed native log filtering.
[Two-build evidence](evidence/2026-09-06-r12-c05-core-binding/windows-evidence.json)
pins the DLL; [client backtests](evidence/2026-09-06-r12-c05-core-binding/client-backtests.json)
retain 100 proxy-only start/stop cycles on the synchronized DLL.
The smoke helper isolates and retains each run's runtime database. The
[previous D05 binding](evidence/2026-09-06-r12-c05-core-binding/previous-runtime-binding.json)
and its [older evidence](evidence/2026-09-06-r12-d05-core-binding/windows-evidence.json)
remain rollback/history. An earlier D05 run against reused test storage timed
out with database `file missing` errors; that receipt remains retained.
This binding alone does not establish Windows service, TUN or DNS proof. The
2026-09-06 component lab used D05 bytes; the 2026-09-07 SCM evidence above uses
C05 bytes for the bounded service/Core initialization slice.

The local C05 package audit retains an unsigned release-mode Flutter bundle
with a loopback API endpoint. Golos Text `OFL.txt` is included as a package asset.
The activation protocol test now builds under `build/windows/x64/tests/`
instead of the runner output copied by the release packager. Its CTest entry
remains active; the retained bundle contains no test EXE. The
[package audit receipt](evidence/2026-09-06-r12-c05-package-audit/package-audit.json)
binds these checks. This direct Flutter bundle is not an installer or clean-host
acceptance and does not stage the VC runtime handled by the release builder.
The pinned external Cronet DLL and the current Go module's DLL both report
`143.0.7499.109` but have different hashes. The module SBOM cannot establish
the pinned DLL's source/notice provenance. The subsequent
[Cronet origin receipt](evidence/2026-09-06-r12-c05-cronet-origin/provenance.json)
proves byte-for-byte identity with the upstream `143.0.7499.109-2` Windows
asset, tag commit `82e1521` and declared native gitlink `2be061b6`. The source
archive matches 30,561 Git blobs directly and 30 after CRLF normalization;
no unexplained mismatch remains. A separate 69-file source license review
archive contains all explicitly declared license files from 36 metadata files.
This is source inventory, not the exact Windows linked notice set. Native
source-to-binary reproducibility and installed runtime/privacy evidence remain
open. The subsequent [native notice receipt](evidence/2026-09-06-r12-c05-cronet-notices/native-notices.json)
retains a successful local Windows GN graph (558 recursive dependencies),
recovered Perfetto/Protobuf/compiler-rt license texts and 28 notice sections.
CMake now requires `libcronet.NOTICES.txt` beside the DLL, and seed validation
checks its SHA-256. An isolated 301-file bundle contains the exact notice; its
other 300 files match the preserved C05 package baseline. This covers identified
Cronet native OSS notices; other Core/Android/Flutter/Microsoft notice coverage
and the complete C05 gate remain open.

The subsequent [Go native notice receipt](evidence/2026-09-06-r12-c05-go-notices/package-notices.json)
verifies the shared `native-go-NOTICES.txt` asset in a new 302-file local bundle.
It preserves 145 license/patent texts and binds their hash to the current Core
source and Go toolchain. Compared with the retained 301-file Cronet-notice
bundle, only `AssetManifest.bin` changed and the Go notice was added; the other
300 files match exactly. The earlier Flutter build failed at installation due
to a stale, incorrectly restored CMake cache prefix; a fresh isolated prefix
passed. The cache now uses the normal runner output directory. Psiphon utls,
nested/native notice coverage, corresponding source, signing, installer and
installed privacy/runtime gates remain open.

The [nested notice follow-up](evidence/2026-09-06-r12-c05-nested-notices/package-notices.json)
adds 28 source-package license/patent texts to the shared asset (173 verbatim
texts in total). Selection follows package and embedded-file ancestors using
the bound AAR/DLL build settings; all 128 recorded Go modules are represented.
This includes distinct freelru, dicttls and Psiphon notices without treating
package membership as proof that optional native code was linked. The exact
Psiphon utls upstream tree confirms the missing root license; its scoped
dicttls text does not close that gap. Other native/file-header obligations,
corresponding-source delivery and the complete C05 gate remain open.

The [file-header supplement](evidence/2026-09-06-r12-c05-file-headers/package-notices.json)
adds 12 original license comment blocks to the common asset (185 verbatim
texts). The new local Windows bundle verifies every body hash; only that asset
differs from the preceding 302-file bundle, while 301 files remain identical.
Both application and service executables remain unsigned. The bounded source
scan covers full permission/redistribution blocks in the first 160 lines of
6751 hash-verified selected files; it is not complete native/include, licensing,
source-delivery or installed-runtime proof. The original CMake install prefix
is restored, and the four preexisting generated registrants remain unchanged.

The [Flutter/native follow-up](evidence/2026-09-06-r12-c05-flutter-native/package-notices.json)
reconstructs all 1624 packaged Flutter notice bodies and matches the engine DLL
and sky_engine license to official archives for engine `1527ae0ec577a4ef50e65f6fefcfc1326707d9bf`.
All 49 inspected Windows plugin files/root licenses match six locked pub.dev
archives; their license bodies are included in Flutter notices. This establishes
input and package identity, not native source-to-binary reproducibility.

The exact signed Wintun 0.14.1 amd64 DLL is embedded in the Windows Core. Its
separate prebuilt terms are now included verbatim in the shared asset (186 texts).
A schema-validated native CycloneDX supplement records twelve components,
including Wintun and its Core parent; it is not the complete application SBOM.
The wrapper resolves thirteen names corresponding to official header typedefs
and uses a memory loader. API-use and redistribution compatibility remain a
separate review; the source GPL and wrapper MIT do not replace the binary terms.
The new bundle changes only notices; 301 other files match the preceding bundle.
Root utls licensing, other native/Maven obligations, corresponding source and
installed privacy/final candidate acceptance remain open.

The R12 source branch refreshes managed profiles on ordinary Windows reconnect
and requires explicit staging acknowledgement before connect. Local shell and
runtime regression tests do not prove service-effective revision or a packaged
AWG3.1→AWG2→AWG3.1 cycle. A new exact candidate and isolated VM readback remain
pending; the retained candidate.33 evidence below is unchanged.

| Fact | Current state |
|---|---|
| Retained public Windows release | Unsigned direct setup `1.1.6` |
| Working package target | `1.2.0+4053` |
| Latest exact candidate | Private signed `pokrov-1.2.0-candidate.33`, app `1.2.0+4053`, client `6ab1bca…735e`, Core `cd8f0f4…884d`, platform `f530005…5bc1` and signed release-index `63993fb…c43c`. Exact `WIN-001` focus, product launchAtLogin, hidden login startup, synthetic saved-state migration and a bounded fresh-process Windows UI idle observation pass; Gate F remains `BLOCKED 2/17/0`, so the candidate is private and not promotable. |
| Retained signed-index predecessor | Candidate.22 setup `effc6a8e…f409`; immutable `NO_GO` after connected uninstall leaves the UI and 13 loaded binaries |
| Current promotable candidate | None. Candidate.33 closes the candidate.32 `WIN-001` defect, but aggregate, managed-runtime, device/origin and public-promotion gates remain non-PASS. |
| Runtime architecture | Unelevated UI plus authenticated SCM service |
| Required service | `pokrov_service.exe` |
| Active candidate Core | Secret-safe POKROV Core `1.1.0`, desktop ABI `2`, exact source `cd8f0f4…884d`; candidate.33 carries the same reviewed Core source in its exact private setup |
| Exact candidate.33 setup | `250622f7…3580`, `29153792` bytes; Windows bundle manifest `0f93211e…a5b`, `11/11` files; signed tuple client/Core/platform/index `6ab1bca…/cd8f0f4…/f530005…/63993fb…`; Windows Authenticode `SKIPPED_BY_OWNER` |
| Exact candidate.32 setup | `22689e3e…0574`, `29154647` bytes; Windows bundle manifest `43bd310e…7dd`, `11/11` files; signed tuple client/Core/platform/index `2d6adfc…/cd8f0f4…/d0dd37c…/5d11fd6…`; Windows signing `SKIPPED_BY_OWNER` |
| Exact candidate.25 setup | `ffc9b07c…7fb3`, `29139238` bytes; Windows bundle manifest `344b842c…87c0`, `11/11` files; signed tuple client/Core/platform/index `54259b0…/cd8f0f4…/883cd10…/18d9cb4…`; Windows signing `SKIPPED_BY_OWNER` |
| Exact candidate.23 setup | `ded8c447…291`, `29146140` bytes; manifest `f92c007d…877`, `11/11` files; tuple client/Core/platform `df9ed85…/cd8f0f4…/5ba4dba…`; Windows signing `SKIPPED_BY_OWNER` |
| Exact candidate.22 setup | `effc6a8e…f409`, `29137688` bytes; manifest `fbf08cf5…c527`, `11/11` files; tuple client/Core/platform/index `0aad6bbb…/cd8f0f4…/d16087d…/d45b503…`; signed release-index `81c56e9f…7d59`; unsigned Windows owner exception |
| Exact candidate.21 setup | `87f90be1…dff3`, `29143633` bytes; manifest `665f77f0…2919`, `11/11` files; tuple client/Core/platform/index `1e164586…/cd8f0f4…/e2608130…/cae911e…`; signed release-index `ce0b8586…3dc6`; unsigned Windows owner exception |
| Exact candidate.20 setup | `330b87cb…587f`, `29140987` bytes; manifest `57687e95…bd7`, `11/11` files; signed tuple client/Core/platform/index `8ab9815…/cd8f0f4…/d6898e6…/61ad0b0…`; unsigned owner exception |
| Exact candidate.17 setup | `0afaf6e1…276c`, `28932793` bytes; signed tuple client/Core/platform/index `977c6ed…/cd8f0f4…/d6898e6…/2df538c…`; `8/8` runtime manifest and unsigned owner exception; rejected because clean Windows lacks the unbundled VC runtime and setup incorrectly returned success after service-start failure |
| Corrected Windows pre-candidate | Setup `301d72fc…3ddc`, `29135238` bytes; manifest `4c9afeb4…f93a`; client `977c6ed…` plus reviewed diff `379a87fc…6f6f`; `11/11` files, app-local Microsoft VC143 runtime, transactional service failure, automatic cleanup and 1.1.6 per-user migration |
| Candidate.27 CLI precursor | `NO_GO_PRECURSOR`: setup `0d8c89ae…1213`, `29148103` bytes; a direct first in-place upgrade from the retained candidate.23 VM stopped before file replacement because `ExecAsOriginalUser` could not resolve the installation owner. The second pass is retained only as diagnostic evidence. |
| Candidate.28 corrected CLI precursor | `PASS_PRE_CANDIDATE_WINDOWS_UPGRADE_AND_DIRECT_RUNTIME`: setup `7986a2b3…8182`, `29141384` bytes; manifest `1ff59b17…cfef`, `11/11`; first-pass candidate.23 upgrade, LocalSystem service, direct TUN/DNS lifecycle and connected reboot recovery pass. This is not a created or promotable candidate. |
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
| Candidate.20 Windows 11 VM | `NO_GO_EXACT_CANDIDATE20_SERVICE_RESTART_RECOVERY`: default connect/disconnect/migration and connected reboot pass, but a forced service termination leaves the journal at `committed` after SCM restart and the UI unavailable |
| Candidate.21 Windows 11 VM | `PASS_EXACT_CANDIDATE21_UPGRADE_DEFAULT_RUNTIME`: upgrade startup recovery reaches `clean`; ordinary UI/LocalSystem service, default TUN/route/DNS/DE egress and exact RU baseline restoration pass |
| Rule-set materialization | `PASS_EXACT_CANDIDATE22`: four exact `.srs` files remain service-owned; candidate.22 exact installed identity is `11/11` |
| Public 1.1.6 migration | `PASS_EXACT_CANDIDATE20_VM` — exact per-user 1.1.6 install was replaced by the candidate.20 machine/service package; final uninstall left no service, app directory or owner registry residue |
| `WIN-003` default-path gate | `PASS` for exact candidate.22 on isolated Windows 11: `sing-tun`, route/DNS change, authenticated DE egress, service-restart/reboot recovery and exact RU baseline restoration after disconnect. |
| Candidate.21 startup correction | `PASS_EXACT_UPGRADE_RECOVERY`: the installed service resumes candidate.20's retained committed journal before serving IPC and returns it to `clean`. Fresh in-place candidate.21 termination/SCM restart remains open. |
| Post-candidate.21 pipe-session resilience | `PASS_EXACT_CANDIDATE22`: production rejects a pre-hello, unauthorized or malformed client session without terminating the SCM service; the exact candidate.22 VM proves rejected-first/valid-second continuity. |
| Candidate.22 connected uninstall | `FAIL_EXACT_CANDIDATE22_RESIDUAL_UI_AND_13_BINARIES`; uninstaller exit `0`, service/tunnel removal and RU egress restoration pass, but the UI process and loaded installation files remain |
| Post-candidate.22 uninstall correction | `PASS_EXACT_PRE_CANDIDATE4052_CONNECTED_UNINSTALL_VM`; local setup `9aa6b0fd…3152` terminates the UI, waits for service stop, removes every installed file and the empty app directory, clears service/registry/TUN state and restores RU egress. Candidate.23 packages the source correction, but its exact connected-uninstall replay remains `NOT_RUN`. |
| Candidate.23 serial-pipe contention | `FAIL_EXACT_CANDIDATE23_CORE001_SERVICE_RUNNING`; the exact client fails a later request while the service remains connected and running. A source-exact diagnostic client reproduces `0/32` accepted simultaneous status requests. |
| Post-candidate.23 pipe correction | `PASS_CANDIDATE25_SOURCE_AND_NATIVE`; candidate.25 binds the corrected client/Core artifact set and a fresh CLI rehearsal passes Debug native CTest `8/8` plus the full Windows build. A follow-up CMake correction puts the Debug-only integration restriction on `add_test`, so Release enumerates and passes its seven applicable native tests instead of attempting the SCM binary as a console process. This test-harness-only successor change receives no candidate.25 runtime credit. Exact installed candidate.25 contention/connected runtime remains `NOT_RUN`. |
| Candidate.32 singleton/focus | `FAIL_EXACT_CANDIDATE32_SECOND_LAUNCH_FOCUS_NOT_RESTORED`: plain and typed second launches exit `0`, retain exactly one original UI PID and forward activation, but the existing window does not regain foreground focus from an independent control window. This is exact `WIN-001` stop-ship evidence. |
| Post-candidate.32 focus correction | `PASS_PRE_CANDIDATE_SUCCESSOR_SINGLETON_SHOW_TYPED_FORWARDING_FOCUS`: the foreground-launched second instance transfers foreground permission to the existing UI before `WM_COPYDATA`; focused Flutter `8/8`, Release native CTest `7/7`, Release build and ordinary medium-integrity Windows 11 VM plain/typed replay pass. This is source/precursor proof only. |
| Candidate.33 singleton/focus | `PASS_EXACT_CANDIDATE33_WIN_001`: exact installed candidate.33 plain and typed second launches retain one original UI process, forward activation and restore foreground focus. |
| Candidate.33 Windows startup preference and login | `PASS_EXACT_CANDIDATE33_PRODUCT_PREFERENCE_TOGGLE_AND_LOGIN_STARTUP`: the product Profile → Windows switch creates and removes the exact quoted `--startup` Run value with no TUN or route/DNS drift. Separately, a real guest reboot/login with that exact value creates one responsive hidden session-1 process; ordinary activation exposes a window on the same PID. All temporary Run/task/UI/first-launch state is removed. Valid saved-account/managed-profile refresh and managed auto-connect remain untested. |
| Candidate.33 synthetic saved-state startup | `PASS_EXACT_CANDIDATE33_SYNTHETIC_SAVED_STATE_MIGRATION_OFFLINE_STARTUP_AND_NETWORK_APPEARANCE_NO_AUTOCONNECT`: a dedicated temporary Windows user starts exact candidate.33 offline with synthetic v0 account/profile state and the exact product Run value. The app migrates state to schema v1 secure storage, removes the plaintext token field, stays hidden on one PID and creates no TUN/Core. When the guest link returns, the same hidden PID remains disconnected with unchanged state/secure-store/experience fingerprints. A SYSTEM cleanup removes the temporary user/profile/data/task and restores `pokrovtest`. This is not valid-account or managed-profile proof. |
| Candidate.33 Windows UI idle observation | `PASS_EXACT_CANDIDATE33_WARM_CACHE_AND_POST_REBOOT_FRESH_PROCESS_UI_IDLE_NO_NETWORK_MUTATION; NO_PERFORMANCE_BUDGET_CREDIT`: warm-cache and post-reboot fresh processes reach responsive windows in `376.835/2560.474 ms`; both ten-sample `45`-second intervals remain responsive with `1.9097/0.9722%` normalized CPU and zero crash events. Route/DNS stay byte-fingerprint identical, no adapter is Up, and each cleanup leaves UI `0` with the service Running/Auto/LocalSystem. Two VM observations are not a controlled cold-boot distribution, comparable-device or budget PASS. |
| Candidate.33 direct/Smart-DNS runtime | `PASS_EXACT_CANDIDATE33_SYNTHETIC_SECRET_FREE`: exact installed service/Core creates TUN, changes managed route/DNS, validates Core egress and DNS, receives DoH `200` in Smart-DNS mode, then restores the exact baseline. Managed-node/AWG credit remains open. |
| Candidate.33 connected crash recovery | `PASS_EXACT_CANDIDATE33_CONNECTED_CRASH_RECOVERY_TO_SAFE_DISCONNECTED`: while the exact installed service/Core was connected through a secret-free direct TUN, forced service termination triggered automatic SCM restart in `5449` ms. The durable journal returned from `committed` to `clean`, TUN disappeared, exact route/DNS fingerprints were restored, and ordinary authenticated IPC reported `initialized`, `running=false`, `failure=none`. |
| Candidate.33 connected reboot recovery | `PASS_EXACT_CANDIDATE33_CONNECTED_REBOOT_SAFE_DISCONNECTED_AND_REUSABLE`: Windows rebooted while the exact service/Core direct synthetic TUN was connected. After boot the automatic LocalSystem service was safely disconnected with no TUN, DNS remained `4/4`, API health was `200`, and a fresh connect/disconnect restored the post-boot route/DNS baseline. Final cleanup retained `11/11` exact files and removed the diagnostic CLI. |
| Candidate.33 connected uninstall | `PASS_EXACT_CANDIDATE33_CONNECTED_UNINSTALL_PRODUCT_CLEANUP_AND_CLEAN_REINSTALL`: with the exact interactive UI open and the exact service/Core direct synthetic TUN running, the uninstaller exits `0`, terminates UI, removes service, all `11` product files, uninstall registry and TUN, and restores exact route/DNS. A clean exact setup then reinstalls `11/11` with Automatic LocalSystem service and unchanged network baseline. |
| Remaining Windows network matrix | `MANUAL_OWNER_TEST`; candidate.33 proves the product launchAtLogin toggle, exact login-startup hidden/same-process activation, synthetic saved-state migration across offline startup/network appearance, installed service/Core direct and Smart-DNS synthetic TUN/DNS lifecycles, connected forced-service recovery, connected reboot recovery and connected uninstall. Valid saved-account/managed-profile refresh and managed auto-connect, managed-node/AWG, Windows 10, leak/IPv6, sleep and interactive SmartScreen remain open. VirtualBox exposes no guest sleep or IPv6 path. |
| Native crash profile | `PASS_LOCAL`: stack-only, no full dump default |

The ordinary UI does not load Core, run elevated or use a system-proxy
fallback. The service owns Core, managed state and recovery. Green state
requires the authenticated egress proof.

## Candidate.33 Focus And Connected Synthetic Runtime

Candidate.33 packages the merged focus correction at client
`6ab1bcaf39c61a0ae0c9d8328e6c95382885735e`. The exact setup is
`250622f7…3580`, `29153792` bytes, with `11/11` bundle identities and exact
installed UI `1b175a66…1d97`, service `b962d3d0…326b` and Core DLL
`f284fa88…8204`. In the isolated Windows 11 VM, candidate.32-to-candidate.33
update and plain/typed second-launch replay retain one UI instance, forward
activation and restore foreground focus. Exact `WIN-001` therefore passes for
candidate.33; candidate.32 remains immutable failed history.

The installed LocalSystem service then passed two headless, secret-free
synthetic-profile lifecycles. The direct slice staged and connected through
authenticated IPC, created one TUN, changed route and DNS fingerprints,
resolved the example/ChatGPT/Gemini/Xbox set, returned API health `200`, and
restored the exact disconnected route/DNS/TUN baseline. The Smart-DNS slice
repeated the lifecycle and received an RFC 8484 response from
`dns.pokrov.space/dns-query` with HTTP `200` and a DNS message body. Evidence
SHA-256 values are `f0eaa96e…05f6` and `ae7d0c3f…1d1a`.

The same exact install then passed connected forced-service recovery. An
ordinary medium-integrity diagnostic client staged the secret-free direct
profile from the protected installation directory and reached `running` with
TUN, changed route/DNS fingerprints, Core egress validation, DNS readiness,
four-of-four domain resolution and API health `200`. A high-integrity probe
terminated the LocalSystem service process while its durable journal was
`committed`. SCM started a new service process automatically in `5449` ms;
no operator remediation was used. Startup recovery returned the journal to
`clean`, removed the TUN and restored the exact pre-connect route and DNS
fingerprints. A new ordinary authenticated IPC request reported
`phase=initialized`, `running=false`, `failure=none`. The temporary diagnostic
client was removed, all `11/11` installed candidate files still matched, and
the final VM state had zero POKROV TUN adapters and zero UI processes with
four-of-four DNS resolution and API health `200`.

The retained evidence index is
`E:\POKROV-tools\release-evidence\1.2.0-candidate33-windows-connected-recovery-2026-09-04\candidate33-connected-recovery-evidence-index.json`,
SHA-256 `50552ddd…6109`. Two earlier harness-only failures are retained in the
same directory and explicitly classified as pre-mutation argument/location
errors; neither reached a connected network boundary. No production account,
server, host network, deployment or public release was changed.

The same exact installation then passed connected reboot recovery. The
ordinary diagnostic client reached `running` with the durable journal at
`committed`, after which the dedicated guest rebooted. Windows completed an
already queued guest update without power interruption. On the resulting boot,
`POKROVService` was automatic, running as LocalSystem and exposed trusted
ordinary IPC in safe disconnected `artifact_ready` state. No POKROV TUN
remained; DNS resolved the same four-domain set and API health returned `200`.
A fresh post-boot connect recreated the TUN and changed route/DNS fingerprints;
disconnect removed it and restored the exact post-boot baseline. Final cleanup
found a `clean` journal, `11/11` exact files, zero UI/TUN residue and removed the
temporary diagnostic client.

The reboot evidence index is
`E:\POKROV-tools\release-evidence\1.2.0-candidate33-windows-connected-reboot-2026-09-04\candidate33-connected-reboot-evidence-index.json`,
SHA-256 `e9a9fd5d…b4cf`. To prevent another unrelated interruption, automatic
Windows updates were disabled only inside the dedicated test guest after the
product check; this is harness configuration, not release credit. No host,
production account, server, deployment or public release state changed.

The exact interactive UI was then opened in user session `1`, while the same
ordinary diagnostic client connected the exact service/Core through the
secret-free direct TUN. The uninstaller returned `0`, terminated the UI,
removed `POKROVService`, all `11` manifest-owned product files, the uninstall
registry entry and TUN, and restored the exact route/DNS baseline. The only
remaining file was the exact external diagnostic CLI, which is not part of the
candidate manifest; the harness identified it by SHA-256, removed it and then
removed the empty installation root.

A clean reinstall from exact setup `250622f7…3580` returned `0`, restored
`11/11` files and the Automatic LocalSystem service, and left the route/DNS
baseline unchanged with zero UI/TUN residue. The connected-uninstall evidence
index is
`E:\POKROV-tools\release-evidence\1.2.0-candidate33-windows-connected-uninstall-2026-09-04\candidate33-connected-uninstall-evidence-index.json`,
SHA-256 `bf222d36…a771`. One pre-mutation hash-binding error and two
postcollector StrictMode errors are retained explicitly; neither is presented
as product failure or hidden as PASS. No production account, server, host
network, deployment or public release state changed.

The cleanly reinstalled candidate then passed its exact login-startup boundary.
The dedicated guest rebooted with Windows Update stopped/disabled and the exact
per-user Run value set to the quoted installed UI plus `--startup`. After the
interactive user logged in, Windows created one responsive session-1 POKROV
process. Its main-window handle remained zero; a guest-only screenshot showed
the ordinary desktop with no POKROV window or UAC prompt. The exact route and
DNS fingerprints matched the pre-reboot baseline and no POKROV TUN existed.

An ordinary interactive-token activation returned `0`, removed its temporary
task and exposed the POKROV window on the same original PID. It did not create
a second persistent UI process or change route, DNS, service or TUN state. The
test Run value and UI were removed afterward; the final state again had zero UI
and TUN, the Automatic LocalSystem service running and the exact route/DNS
baseline. The retained evidence index is
`E:\POKROV-tools\release-evidence\1.2.0-candidate33-windows-startup-2026-09-04\candidate33-windows-login-startup-evidence-index.json`,
SHA-256 `a0ba483a…5090`. The first guest Run-dialog activation attempt retained a
stale historical command and never reached POKROV; that harness miss remains
explicit and receives no product classification.

A follow-up exact-artifact slice then exercised the owning product preference.
With the guest network link off, a temporary first-launch-completed marker
exposed the ordinary shell without moving or reading retained session-secret
files. Guest-only keyboard traversal opened Profile → Windows. Enabling
`Запускать вместе с Windows` created the exact quoted installed-UI plus
`--startup` Run value; disabling the same switch removed it. The same UI PID,
Automatic LocalSystem service, zero TUN and exact DNS/route fingerprints were
retained throughout. The marker, UI and temporary tasks/scripts were removed,
and the bridged guest link was restored.

The product-preference evidence index is
`E:\POKROV-tools\release-evidence\1.2.0-candidate33-windows-startup-2026-09-04\candidate33-windows-product-preference-evidence-index.json`,
SHA-256 `085419e4…21a2`. Windows UI Automation exposed no named Flutter controls,
so those no-mutation probes remain harness evidence only; the successful path
used guest-only keyboard focus traversal. One offline rehearsal entered a
whitelist information screen and performed no server or network action.

A separate exact-artifact slice then staged only synthetic v0 account/profile
state under a dedicated temporary Windows user. No existing `pokrovtest`
session files were read, moved or copied. With the exact quoted product Run
value present and the guest adapter cable off, Windows login created one hidden
candidate.33 UI process. The app migrated the state to schema v1, moved the
synthetic token to secure storage and left no plaintext `session_token` field.
The Automatic LocalSystem service remained running while UI, consent, Core and
TUN counts were `1/0/0/0`.

Restoring only the guest adapter cable preserved the same hidden UI PID `6884`
and unchanged state, secure-store and experience fingerprints. Ethernet became
`Up`, but no Core or TUN appeared and no automatic connection occurred. That is
the intended 1.2.0 behavior: login startup registers and hides the UI; it does
not yet own a managed auto-connect contract. The external evidence index is
`E:\POKROV-tools\release-evidence\1.2.0-candidate33-windows-saved-state-startup-2026-09-04\candidate33-windows-saved-state-startup-evidence-index.json`,
SHA-256 `43a7e737…3bb7`.

Cleanup ran once as SYSTEM before the next login and removed the temporary
local user, profile, ProgramData, public fixture files and scheduled task. The
normal `pokrovtest` session was restored with no startup value, UI, Core or TUN;
the exact service remained Running/Auto/LocalSystem. Post-cleanup DNS/route
fingerprints reflect the full guest reboot and DHCP renewal, while the retained
record exposes only the physical Ethernet adapter and no product adapter. The
initial password-policy and Public-folder ACL misses are retained as harness
issues, not product failures.

The exact installed Windows UI then passed a bounded fresh-process idle
observation in the same dedicated VM. With no existing UI process and no
POKROV/Wintun adapter Up, a warm-cache process exposed a responsive window in
`376.835 ms`. Ten samples over `45` seconds remained responsive and kept the
window present. Normalized CPU was `1.9097%` across two vCPUs; working-set
p50/p95 was `94621696/95019008` bytes and private-memory p50/p95 was
`76607488/81367040` bytes. The Application log contained zero matching crash
events.

After a full guest reboot with Windows Update already Stopped/Disabled, the
same exact harness logged in through the guest-only DPAPI helper and repeated
the slice. The fresh process exposed a responsive window in `2560.474 ms`;
all ten samples over `45` seconds remained responsive. Normalized CPU was
`0.9722%`; working-set p50/p95 was `99446784/99713024` bytes and matching crash
events were again zero. Route/DNS stayed unchanged and no POKROV/Wintun adapter
was Up before, during or after cleanup.

No connection was requested and no user data was inspected. Route/DNS
fingerprints were unchanged, the inactive hidden POKROV adapter remained
`Not Present`, and cleanup left zero UI processes with the Automatic
LocalSystem service intact. Closing the main window follows product tray
behavior, so the harness force-stopped only the UI process after measurement.
Normalized evidence is
[`candidate33-windows-ui-idle.json`](evidence/candidate33-windows-ui-idle.json).
These two 2-vCPU/4-GiB VM observations are descriptive only: one uses a warm
file cache and one follows a guest reboot, but they do not form a controlled
cold-boot distribution, comparable-device or release performance-budget PASS.

These passes prove the exact candidate.33 installed service/Core/TUN/DNS
boundary, forced-service rollback, connected-reboot rollback, connected
uninstall, clean exact reinstall and login-startup hidden/same-process
activation plus the owning product preference toggle, synthetic saved-state
migration across offline login/later network appearance and one bounded UI
idle observation. They do not prove
a valid restored account/profile refresh, managed auto-connect, a managed
production node, public egress change, AWG2/AWG3.1,
Hysteria2, WARP, sleep, leak/IPv6, Windows 10, SmartScreen
interaction or promotion. The VM was headless; neither host input nor host
networking was changed.

## Candidate.32 Singleton/Focus NO_GO And Source Correction

Candidate.32 binds client `2d6adfcebc37f2109ef339276be6a1569cb7aa1e`.
In the isolated Windows 11 VM, the exact UI accepts both a plain second launch
and a typed `pokrov://` activation: each new process exits `0`, leaves one
original UI process and forwards activation. However, the existing window
does not regain foreground focus from an independent foreground control
window. Candidate.32 therefore fails `WIN-001` and remains immutable
`NO_GO`; its signed manifest and application files are not rewritten.

The source correction keeps the existing single-instance and `WM_COPYDATA`
contract. Before sending the activation frame, the foreground-launched second
process resolves the existing window's process id and calls
`AllowSetForegroundWindow` for that process. The existing instance then uses
its current restore/focus path when handling the frame.

Focused Flutter contract tests pass `8/8`, Release native CTest passes `7/7`
and the Release build succeeds. A separately named precursor UI is staged in
the VM without replacing candidate.32. Under an ordinary medium-integrity
token, both plain and typed second launches exit `0`, retain one original PID
and return foreground focus to it. Route/DNS/adapter counts remain unchanged;
the precursor and staging directory are removed, candidate.32's UI hash stays
`611208b2…15a2`, its service remains running, and the VM is powered off.

This is `PASS_PRE_CANDIDATE`, not a newly created candidate and not promotion
approval. A newly numbered exact candidate must rebuild/package the correction
and repeat the applicable Windows and aggregate release gates.

## Candidate.25 Hosted Clean-Host Gate PASS

The private client repository pins its manual GitHub-hosted Windows gate to
candidate.25. The gate input binds the signed release-index manifest and
signature, the exact four-source tuple, setup size and SHA-256, the unsigned
owner exception and all `11/11` installed-file identities. The workflow uses
an ephemeral `windows-2025` administrator runner and downloads only the named
asset from the candidate.25 private CI carrier.

Run `33717151777` completed successfully on image `win25-vs2026`
`20260824.214.3`. It performed silent install, validated installed-file
readback, LocalSystem service identity, ordinary UI/service
authenticated IPC, SCM stop/restart, clean uninstall and idle route/DNS
restoration. The exact candidate SHA-256 is `ffc9b07c…7fb3`; all `11/11`
installed files matched. Sanitized evidence SHA-256 is `c6ec9d18…bfcd`.

This bounded PASS cannot claim connected TUN/DNS/egress,
AWG/Smart DNS, sleep/reboot, connected uninstall, interactive SmartScreen,
trusted signing or stable promotion. Candidate.23 remains immutable `NO_GO`
history.

## Candidate.27 Upgrade-Owner NO_GO And Candidate.28 Correction

A clean CLI rebuild from client `ed74928…83a6` and Core
`cd8f0f4…884d` produced candidate.27 precursor setup
`0d8c89ae…1213`. A direct silent upgrade from the retained candidate.23 VM
reproduced the first-run failure: `PrepareToInstall` could not resolve the
interactive installation owner, exited before replacement and left only
`8/11` required hashes current. The complete failing installer log closes
normally and records the owner-resolution error, so the earlier successful
second attempt cannot receive upgrade credit.

The correction preserves the fresh-install fail-closed boundary and reuses an
existing machine installation's protected `InstallOwnerSid` only when the
original-user query fails and the stored value is an exact valid SID. The
candidate.28 precursor binds base client `ed74928…83a6` plus source diff
`1341da36…2888`, the same Core, setup `7986a2b3…8182` and manifest
`1ff59b17…cfef`. Full CLI tests/build pass; native CTest passes Release `7/7`
and Debug `8/8`; the bounded static scan covers 303 files / 99,269,838 bytes
with zero definite findings.

On the restored candidate.23 VM, the corrected setup succeeds on the first
direct launch, records `POKROV_INSTALL_OWNER_REUSED_FOR_UPGRADE`, validates
all `11/11` installed files and leaves `POKROVService` running as automatic
LocalSystem. The exact installed bytes then pass direct synthetic-profile
TUN/route/DNS lifecycle and connected guest-reboot cleanup. Windows rebuilds
its ordinary route/DNS fingerprint across this reboot; the post-boot lifecycle
proves exact restoration to the new boot baseline and no POKROV tunnel
residue. Evidence is retained under
`E:\POKROV-tools\release-evidence\1.2.0-candidate28-owner-upgrade-2026-09-03`.
This is `PASS_PRE_CANDIDATE`, not candidate creation or promotion.

## Candidate.23 Pipe-Contention NO_GO And Source Correction

Candidate.23 binds platform `5ba4dba3db0f900466d2f36d84d981a0a9c9fe68`,
client `df9ed85bb0e7fd7bf1e1c43d033825212c2f6354` and Core
`cd8f0f4169d570d693992a959d81d17c2c44884d`. Exact setup
`ded8c4479e3f890a14298e30291693b8499ea78960813862e649354a597fa291`
validates all `11/11` required files and initially reaches the authenticated
connected state with DE egress. After a disconnect, a later ordinary UI request
reports `CORE-001` although `POKROVService` remains `Running` and a single
trusted CLI status request succeeds.

The same source client, compiled as a secret-safe status-only diagnostic,
reproduces the race with `0/32` simultaneous requests accepted by the running
service. The service intentionally processes one pipe session at a time. The
candidate client waited only 250 ms and did not retry when several waiters woke
for one free instance or while the service replaced the serial instance.
Candidate.23 is therefore immutable `NO_GO`; its connected-uninstall replay and
the broader remaining matrix cannot promote those bytes.

Successor source keeps immediate failure when the service pipe is genuinely
absent, but after observing a busy instance retries the two transient states for
at most five seconds. The focused 32-client native test passes in Debug and
Release. Against the unchanged installed candidate.23 service, the corrected
diagnostic client reaches `32/32` available, trusted and accepted requests and
leaves the service connected with DE egress. This is
`PASS_PRE_CANDIDATE_PIPE_RETRY`, not candidate.24 credit.
The normalized secret-safe record is
[`candidate23-windows-pipe-contention.json`](evidence/candidate23-windows-pipe-contention.json).

## Candidate.22 Connected-Uninstall NO_GO And Source Correction

Candidate.22 binds platform `d16087d5da509e17163bdd7293bec5711aa7eedc`,
client `0aad6bbb3a8baf9bd9e2436ed9e57f7c6fbbafed` and Core
`cd8f0f4169d570d693992a959d81d17c2c44884d`. Exact setup
`effc6a8ed7ccfa943986aca93f4d1d846d66c8d42730ea0b77854b48f77bf409`
validates all `11/11` required files. Its retained Windows 11 evidence covers
ordinary UI/service, default TUN/DNS/DE egress, in-place service-restart and
connected-reboot recovery, in-app Smart DNS and separate packaged AWG3.1/AWG2.

The connected-uninstall run started from one verified tunnel and DE egress.
The exact uninstaller returned `0`, removed `POKROVService`, removed the tunnel
and restored ordinary RU egress, but did not terminate `pokrov_windows.exe`.
Thirteen loaded EXE/DLL files therefore remained under the installation root,
while the uninstall registry entry was already absent. Repeating with the
setup-only `/FORCECLOSEAPPLICATIONS` switch produced the same result because
that switch is not an uninstaller contract. Candidate.22 is immutable
`NO_GO`; its prior PASS slices remain evidence only.

Build-4052 source adds an Inno `InitializeUninstall` step that terminates the
exact configured UI image before uninstall begins and aborts on an unexpected
termination-command failure. Its uninstall run waits up to 30 seconds for the
SCM service to stop before file removal, then removes `{app}` only when empty.
Static packaging tests bind those controls.

An exact local pre-candidate setup, SHA-256
`9aa6b0fd7e43338786a25c7f14b0bd06e04aed01e92e5f21869eb334b5973152`,
installed in the isolated Windows 11 VM, launched the ordinary UI and reached
one connected TUN. Connected silent uninstall then left zero UI/service
processes, zero service registrations, zero TUN adapters, zero installed files,
no uninstall registry entry and no installation directory; ordinary RU egress
was restored. This is `PASS_PRE_CANDIDATE`, not candidate.23 credit. The fix
must merge, be rebuilt into immutable candidate.23 and repeat on those bytes.

## Candidate.21 Private Upgrade And Default-Path PASS

Candidate.21 binds platform `e2608130e85d9a0f8fa4b920f46cf3d7679332c3`,
client `1e164586d741484b5ae8fb2ee267ef5dd813cadb` and Core
`cd8f0f4169d570d693992a959d81d17c2c44884d`. Exact setup
`87f90be11a927c271c84e8042f17e052ee1070a1ac4923fa3949d6e19c00dff3`
is `29143633` bytes; its `11/11` manifest SHA-256 is
`665f77f096a54b9fe5ec375149ebadae4e0871165dcba8f19c3fe6fbf6be2919`.

The isolated Windows 11 VM began with candidate.20's exact committed recovery
journal. Installing candidate.21 returned `0`, validated all required files,
left the automatic LocalSystem service running, executed startup recovery to
`clean` and removed pending network state. The exact non-elevated check then
proved an ordinary-user UI, installed identity and the same running service.

The visible default path reached Germany with `sing-tun`, a distinct DE
egress and changed route/DNS fingerprints. Disconnect removed the tunnel and
returned egress country/hash, route/DNS fingerprints, default-route count,
DNS-interface count and active-adapter count exactly to the RU baseline.
Sanitized evidence SHA-256 values are
`45a1349a…a960` (upgrade recovery), `453b1fa0…60dc` (ordinary UI/service),
`e7e7686a…03d3` (baseline), `44da58ed…9cf9` (connected) and
`bf46957d…0049` (restored).

This replaces the current `WIN-003` default-path proof and proves upgrade-time
recovery from the predecessor failure state. It does not prove a fresh
in-place candidate.21 forced termination followed by SCM restart, Windows 10,
AWG2/AWG3.1, sleep/resume, connected reboot/uninstall, IPv6/leak, interactive
SmartScreen or trusted signing. Candidate.21 has a validated private signed
release index but no public assets or promotion.

Candidate.22 and current main keep the production service alive after a client
opens the protected pipe but disconnects before `hello`, fails caller
authorization or sends an invalid frame. The focused Flutter contract passes
`7/7`; the complete debug Windows bundle builds, and all six native service
executables pass, including a two-session test that rejects the first
connection and serves the second. Candidate.22 packages that correction and
proves it on the isolated VM; it does not rewrite candidate.21. Candidate.22's
separate connected-uninstall failure is recorded above.

## Candidate.20 Reboot Pass And Service-Restart NO_GO

The exact candidate.20 setup was installed again from a residue-free machine
baseline and matched all `11/11` manifest files. The default path reached the
same authenticated Germany egress as the earlier proof. A connected Windows
reboot recorded preshutdown rollback, restored the exact baseline route, DNS and
egress after boot, and allowed a fresh reconnect to the same selected egress.

A separate connected forced termination of `POKROVService` then exposed the
release blocker. SCM restarted the LocalSystem service and Windows removed the
process-owned tunnel state, so route, DNS and egress happened to return to the
baseline. The durable recovery journal nevertheless remained at `committed`,
the restarted service emitted no startup rollback sequence and the UI reported
the runtime unavailable. Candidate.20 therefore does not satisfy the contract
that service restart resumes durable rollback and is immutable `NO_GO`.

Sanitized evidence is retained outside the repository:

- reboot restoration: `E:\POKROV-tools\temp\candidate20-winvm-evidence\candidate20-network-restored-reboot-matrix-20260902.json`, SHA-256 `da811db3b973f06d9848a6d28c991e703deb44c49c5efc22a629c94936623612`;
- service-restart network restoration: `E:\POKROV-tools\temp\candidate20-winvm-evidence\candidate20-network-restored-service-crash-20260902.json`, SHA-256 `d0b39fbafa0712a13ca4fec52e24834f0deb4c2618ab44e23e514101dcf0a746`;
- retained committed recovery stage: `E:\POKROV-tools\temp\candidate20-winvm-evidence\candidate20-recovery-stage-safe-service-crash-20260902.json`, SHA-256 `5bb0263e60b78f97713c2d794f5c0cd5d4288cc4c8f4d67a709cea5637c28e1d`.

The candidate.21 correction invokes pending recovery when the service runtime
is constructed, before it creates its first IPC instance. A clean journal still
avoids eager Core initialization. If startup recovery fails, the runtime stays
in `recovery_required`, rejects a new connection and permits an explicit
disconnect/recovery retry. The exact upgrade result above replaces the earlier
source-only claim, but the fresh in-place connected service-restart matrix is
still required.

## Candidate.20 Exact Windows 11 Default-Path Proof

Candidate.20 binds client `8ab9815ab98f111140c0c8ce4e289555652d56e8`,
Core `cd8f0f4169d570d693992a959d81d17c2c44884d`, platform
`d6898e63c5c9ab7dd267b9d5150b54196f99d967` and exact signed release-index
source `61ad0b0e0780775b8f95f1a567e94d75d198a483`. Its Windows setup is
`29140987` bytes with SHA-256
`330b87cb074a04f43cb7004e4c03cdd0c692b54397acbc223f25dd6e0be8587f`;
the eleven-file manifest SHA-256 is
`57687e95bd3368e43d71025c5d607a60456abfcaf869cf37c6bf84ff297afbd7`.
The signed release index SHA-256 is
`046d331274da76ba524f824debb17c4abc080657456c41099246589cc3c1770a`;
its detached-signature SHA-256 is
`f5e81d310fa18b464421afe4c0da010e3b9c112c9affba64e7d1631b4f6890ea`.

The isolated Windows 11 VM first removed candidate.19 machine state, then
installed the exact candidate.20 setup. The ordinary UI stayed non-elevated;
the automatic LocalSystem service authenticated it, staged the profile and
materialized four rule sets under its protected A/B slot. The selected default
Germany exit reached green only after the service authenticated external
egress. The active `sing-tun` adapter carried the default route and DNS
`172.19.0.2`. Disconnect stopped Core and removed the tunnel route, DNS and
adapter while restoring the original Ethernet route and DNS. Clean uninstall
and the exact public-1.1.6 per-user-to-machine migration both passed.

The VM retained an already authorized user-level app state after candidate.19
was removed; it is therefore not claimed as a fresh user profile. Candidate.19
service, installation root and owner registry were absent before candidate.20
installation, so the machine-install/service boundary was clean. The aggregate
contains 24 true checks and no raw profile, connection material or open egress
IP.

Sanitized evidence is retained outside the repository:

- aggregate Windows foundation:
  `E:\POKROV-tools\temp\candidate20-winvm-evidence\candidate20-windows-foundation.json`,
  SHA-256 `525987f45ceb88197745b0e738fc2ccb4b5aaf969ad5253c22ad2a2091678d04`;
- service-owned rule-set materialization:
  `E:\POKROV-tools\temp\candidate20-winvm-evidence\candidate20-ruleset-materialization-safe.json`,
  SHA-256 `9873b108afc1bc2e19e7d41d39a903140f3f02349fd749eab43c3d1cd350df6a`;
- public-1.1.6 migration summary:
  `E:\POKROV-tools\temp\candidate20-winvm-evidence\candidate20-migration-run-summary.json`,
  SHA-256 `7506a74494772ec556f53222d289cf3d4b0d54a7296edfcb338b442946f91ebc`.

This closes the exact Windows 11 default-path `WIN-003` slice only. The later
service-restart result above rejects candidate.20 as a whole. Windows 10,
AWG 3.1/AWG2 through the app/service boundary, sleep/resume, connected
uninstall, IPv6/leak, interactive SmartScreen and trusted Authenticode remain
non-PASS. Candidate.20 also does not prove physical Android, store or stable
promotion.

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
Candidate.19 remains immutable `NO_GO`. Candidate.20 is the rebuilt successor
and receives only the bounded exact Windows 11 proof stated above.

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
- Local tests prove source contracts and isolated recovery logic. Exact
  candidate.20 additionally passes the bounded Windows 11 default connect,
  TUN, DNS, authenticated egress, disconnect rollback, clean uninstall and
  public-1.1.6 migration slice stated above.
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
  exact local rule-set service-boundary failure. Candidate.20 proves the
  bounded service-owned rule-set correction and the default TUN/DNS/egress/
  rollback path; non-default protocols and recovery remain open.
- The earlier current-origin reverse-UDP block was isolated to wrong
  reply-source selection on the multi-addressed owned server. After guarded
  source-port policy routing and service-cycle readback, exact current-origin
  Core interop passes both AWG2 and AWG3.1. This did not exercise the Windows
  client app, SCM service, TUN, DNS capture or leak protection, so those rows
  remain `MANUAL_OWNER_TEST`.
- Signed-manifest candidate.20 exists with promotion false and the bounded
  Windows 11 PASS ceiling above. Candidate.19 is immutable Windows `NO_GO`;
  candidate.18, candidate.17, candidate.16, candidate.8 and candidate.3 remain
  retained history for their own older bytes only.
- The owner authorizes one unsigned direct-download beta with the mandatory
  SmartScreen/unknown-publisher warning. This is not trusted-signing evidence
  and permits no signed, Store or broad-stable claim.
- The retained unsigned `1.1.6` publication does not prove `1.2.0` trust,
  recovery or network behavior.

## Verification Commands

### Successor-source reproducible build contract

The Windows release builder now normalizes both sources of nondeterminism
observed in fresh candidate.31 source rebuilds:

- MSVC Release/Profile executable and DLL targets use `/Brepro`, removing the
  changing PE linker timestamp and matching debug-directory timestamp;
- after the final `flutter pub get`, the builder assigns the generated Dart
  plugin registrant a stable package URI and invokes `flutter build windows`
  with `--no-pub`. This prevents the absolute worktree path from entering
  `data/app.so`.

For byte-for-byte rebuild evidence, invoke
`scripts/build-windows-release-reproducible.ps1` with the ordinary release
builder arguments. The wrapper fails closed if `P:` is occupied, maps the exact
client checkout to that stable path only for the child build, and removes the
mapping in `finally`. The release builder also stages the pinned Flutter
Windows C++ wrapper from the SDK engine cache before CMake runs, so a clean
worktree does not depend on stale `windows/flutter/ephemeral` files. It removes
the Windows-specific `build/native_assets/windows` staging directory before the
build so an obsolete optional file cannot leak into the release bundle.

The contract is fail closed on a missing, unsupported or conflicting Flutter
package config. It does not patch completed binaries and does not weaken AOT
stack metadata for normal package sources. Byte identity must be proved by two
clean builds from different absolute worktree paths before a successor
candidate can receive reproducibility credit.

Candidate.31 remains immutable. This source/tooling correction is
`PRE_CANDIDATE_LOCAL` until merged and assembled into a newly numbered exact
candidate; it changes no public or stable pointer.

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-seed.ps1 `
  -PlatformRoot C:\path\to\platform `
  -CoreRoot C:\path\to\POKROV-core

pwsh -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\build-windows-release-reproducible.ps1
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

### R12 local service profile identity, 2026-09-05

The local source requires matching ProfileIdentity-capable UI and service.
Connect is bound to the SHA-256 of the stage request, including flags and bundled
rulesets. A stale intent is rejected before start; stop clears effective proof.
Native tests cover digest mismatch, stage failure, invalidation, strict/atomic
snapshot parsing and poll projection. The test pipe uses the existing isolated
`--test-reject-then-serve` process and does not install or replace the host service.
Logs: `E:/r12-identity-before.log`, `E:/r12-identity-ctest.log`,
`E:/r12-identity-flutter-test.log`, `E:/r12-identity-windows-debug-final.log`.
The debug UI build is compilation proof only. Installed mixed-version behavior,
SCM/TUN routing and AWG31→AWG2→AWG31 remain MANUAL_OWNER_TEST on exact candidate
bytes. Rollback must restore UI and service together; Core ABI remains 2.
