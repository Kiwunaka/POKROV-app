# Android Release Audit

Last updated: 2026-09-07

## Document Status

Registry class: `ACTIVE_EXECUTION`.

This file contains the current Android gate for the `1.2.0` working target.
Older APK identities and device runs are retained separately as evidence.
The cutover seed still names `pokrov-1.2.0-candidate.33`; its retained evidence
does not prove the newer local working sources below.

## Current Truth

The [current ARM64/access receipt](evidence/2026-09-07-r12-arm64-access/receipt.json)
binds client `9334d46` / Core `8dc57a8` to normal same-signer 1.2.0+4053 APKs.
The canonical Direct build produces genuine per-ABI APKs: ARM64 101225939 bytes,
universal 295227054 bytes (65.71% less delivery). SO identities match the bound
AAR and all notice assets are preserved. The earlier extra-ABI observation
below applies only to the quick local build command. Huawei accepted local
universal-to-ARM64 replacement with preferences retained, and both packages
confirmed protection. A controlled API-unavailable build verified unknown
subscription labels alongside cached-profile tunnel/DNS/egress proof. The
ordinary ARM64 APK was restored, installed hash verified and protection
confirmed again; VPN was then disconnected with Wi-Fi enabled. This is local
physical acceptance, not a final downloadable candidate, actual carrier block,
RU-origin proof or the complete newer-version/channel/OEM/network matrix.

The [same-APK lifecycle receipt](evidence/2026-09-07-r12-lifecycle/receipt.json)
adds 120 seconds of forced deep Doze and 60 seconds of app standby on Huawei.
The process and foreground VPN service survived both; protection refresh after
each returned confirmed tunnel/DNS/egress. Final readback restored ACTIVE,
force=false, standby false, Wi-Fi enabled and no VPN service. Forced idle with
USB attached is not a battery baseline or the full OEM/API/lifecycle matrix.

The [2026-09-07 local Huawei receipt](evidence/2026-09-07-r12-offline-network/receipt.json)
binds client `550329f` / Core `8dc57a8`, same-signer 1.2.0+4053 bytes and
preserved app data. On physical Android 12/API 31, normal Wi-Fi, restart/reconnect
and mobile reached the app's confirmed tunnel/DNS/VPN-egress state. A controlled
build-time API-unavailable fixture connected from the encrypted cache, including
after force-stop/relaunch on mobile. It does not prove an actual carrier block,
RU origin, WARP, Doze or the full network matrix. The normal API APK was restored and its installed SHA-256 verified; the previous installed APK is retained for rollback. These
are local test packages, not published candidates. The ARM64 Flutter build
includes Core-only armeabi-v7a/x86_64 libraries from the AAR, so primary-ARM64
packaging acceptance remains open. Automatic source-network diagnostics pass
local native/Dart/API/RBAC/retention tests; deployed ingestion and geographic
accuracy remain unproven until the new backend is deployed and observed.

The [C05 source packet](evidence/2026-09-06-r12-c05-source-packet/source-packet.json)
prepares the exact Core `8dc57a8` source and authenticated runtime module archives.
All five package graphs resolve offline from that snapshot with the same source
selections and module sums. The four Android `libcronet.a` files match upstream
Git blobs at `f21660be`; both that library commit and wrapper `dc1cda1f` declare
native commit `30f3a568`. Its source archive is verified against the Git tree.
This differs from retained Windows native commit `2be061b6`; the Windows source
archive must not stand in for Android. Native source-to-binary reproduction,
complete license/corresponding-source acceptance and publication remain open.
No runtime binary or candidate identity changed in this source preparation.

C05 updates the development binding to Go 1.26.8 / x/crypto 0.56.0 with the
Psiphon TLS layout correction. [Current two-build evidence](evidence/2026-09-06-r12-c05-core-binding/android-evidence.json)
and [previous D05 binding](evidence/2026-09-06-r12-c05-core-binding/previous-runtime-binding.json)
bind the AAR. This dependency correction requires fresh installed-package,
privacy and device acceptance; retained `pokrov-1.2.0-candidate.33` evidence
stays historical.

The local C05 package audit builds Direct release-mode APKs with the explicit
internal debug-signing option and a loopback API endpoint. All four APKs retain
the exact bound Core SO bytes and now include the existing Golos Text
`OFL.txt` as a package asset. The [package audit receipt](evidence/2026-09-06-r12-c05-package-audit/package-audit.json)
records byte inventories, dependency queries and their limits. This is not a
production-signed candidate or installed runtime/privacy proof. Core native
notice coverage, nested/native dependencies and corresponding source delivery
remain separate gates; a generated Flutter `NOTICES.Z` does not cover them automatically.

The subsequent [Go native notice receipt](evidence/2026-09-06-r12-c05-go-notices/package-notices.json)
verifies `native-go-NOTICES.txt` in all four local Direct APKs. The shared asset
contains 145 verbatim license/patent texts from the recorded Core, Go and module
inputs, with hash, Core source and toolchain binding in the runtime manifest.
The Core SO entries still match the pinned AAR. Psiphon utls has no retained
root license; that gap, nested/native coverage, source delivery and installed
privacy/device acceptance remain open. These APKs use internal debug signing
and the loopback API; they are not a new release candidate.

The [nested notice follow-up](evidence/2026-09-06-r12-c05-nested-notices/package-notices.json)
adds 28 source-package license/patent texts, bringing the asset to 173 verbatim
texts. Five source dependency graphs use the tags and GOOS/GOARCH/CGO settings
recorded in the bound DLL and four AAR libraries; all 128 recorded Go modules
are represented. Package-ancestor selection covers distinct dicttls, freelru
and Psiphon notices, but does not establish every native include or file-header
obligation. The exact Psiphon utls upstream tree has no root license; all 298
module-cache files match it. Its nested dicttls license is included with its
own scope and does not substitute for the missing root text.

The [file-header supplement](evidence/2026-09-06-r12-c05-file-headers/package-notices.json)
retains 12 original comment blocks, including Inferno, fiat-crypto, FreeBSD,
UTF-8 decoder and quic-go tree notices, for a total of 185 verbatim texts.
All four new local Direct APKs contain the exact asset and bound Core libraries;
their Android Debug signer remains an internal packaging-only result. The scan
checked hashes for 6751 selected source files and inspected their first 160
lines for full permission/redistribution blocks. Literal body matching avoids
duplicate texts but does not establish complete file-level licensing, native
include coverage, corresponding source, installed privacy or final acceptance.

The [Flutter/native follow-up](evidence/2026-09-06-r12-c05-flutter-native/package-notices.json)
reconstructs the packaged Flutter `NOTICES.Z` exactly from its license inputs:
1621 distinct bodies, including 1594 sky_engine blocks. Official sky_engine
notices match the SDK; all three packaged Flutter SOs match official engine
`1527ae0ec577a4ef50e65f6fefcfc1326707d9bf` artifacts after the recorded NDK strip
operation. The selected embedding JAR matches its official download; this does
not prove DEX reachability or native source-to-binary reproducibility. Four new
local Direct APKs retain the same Core/Flutter SOs and generated Flutter notices,
and carry the updated shared asset with 186 texts, including the Windows-only
Wintun prebuilt terms. Their internal signer and existing runtime gates remain.

The [Maven notice follow-up](evidence/2026-09-06-r12-c05-maven-notices/package-notices.json)
adds an Android-only asset with 164 license texts and source attributions.
All 58 unique selected public Maven binaries match official downloads; the
63-module public graph also includes five metadata/redirect-only coordinates.
The source scan covers 4035 Java/Kotlin/native source files in 59 source JARs.
It retains the JSR-305 CC BY 2.5 headers, Kotlin Boost attribution and terms,
MurmurHash attribution and the BSD license for Protobuf shaded inside Tink.
Tink release-source metadata declares Protobuf 4.33.0; 539 upstream class names
are present, with three extra anonymous WireFormat classes. That is not byte
reproduction. Its separate OSV query returned no advisory IDs or pagination.
The 59-component CycloneDX supplement records this boundary explicitly.

Four local Direct APKs contain the exact 176690-byte asset and all body hashes.
Only the new asset and Flutter AssetManifest.bin differ from the previous APK
entries; DEX, native SOs and prior notices are byte-identical. These packages
use Android Debug signing and the loopback API. CC legal text is extracted from
the official HTML; other included bodies retain their source bytes. This work
does not close complete license compatibility, corresponding-source delivery,
installed privacy or final candidate/device acceptance. Windows packaging and
retained release artifacts are unchanged.

The [Android Cronet notice follow-up](evidence/2026-09-06-r12-c05-android-cronet/package-notices.json)
adds a separate 173535-byte Android asset with 31 native license sections.
Pinned GN and the declared Android wrapper flags generated four dependency
graphs from native commit `30f3a568` in the local Ubuntu lab. Each graph's
compile-source basenames match the object-member multiset of its bound static
archive: arm64 2663, arm 2663, amd64 2666, 386 2665. Non-assembly STT_FILE
filename multisets also match (2538/2538/2540/2540). Basename agreement does not
prove source-to-binary reproduction. All 30591 original source entries remained
unchanged, and 4771 original GN-declared files have retained hashes.

Android-specific libunwind, CPU Features and JNI Zero licenses are included,
along with the separate BSD header in CPU Features' NDK compatibility layer.
Perfetto, Protobuf and compiler-rt upstream-license evidence was reused only
after every file in those Android source subtrees matched the prior snapshot.
The 29-component CycloneDX supplement distinguishes 25 source directories from
four static archive inputs; 386 remains AAR-only. Four new internal Direct APKs
contain the exact asset and all 31 body hashes. Existing entries changed only
in AssetManifest.bin; DEX, native SOs and prior notices are byte-identical.
The lab VM is again powered off; previous lab services stayed inactive.
There was no native compilation, engine execution, installer or production
operation. Full transitive header/license compatibility, source delivery,
installed privacy and final candidate/device/origin acceptance remain open.

The R12 source branch replaces event/cache health authority with per-call Core
`CommandServer.ProbeEndpoint` and `ProbeSelectedOutbound` results. Core
`8dc57a830bd1487389dd1b7c9190f094c31e13bc` is bound in the runtime manifest;
two byte-identical builds contain both methods and all four Android ABIs.
Both flavor JVM suites pass on this AAR (372 fresh tests, 186 per flavor);
[current backtests](evidence/2026-09-06-r12-c05-core-binding/client-backtests.json) retain the
explicit rerun and JVM/Flutter limits. Host A/B completion tests and Core
race tests reject unrelated late results, changed selection, direct and cyclic
routes. Exact candidate package checks and device evidence remain pending; candidate.33
evidence below is not evidence for this source diff.

The current C05 binding retains the D05 filter for native managed-engine messages before observable
writers, subscriptions and replay buffers, including debug mode. Arbitrary
messages and logger tags become a fixed redacted category; supported AWG
diagnostic categories remain closed. The planted-value Go regression covers
these sinks. [Binding evidence](evidence/2026-09-06-r12-d05-core-binding/android-evidence.json)
and the [previous binding](evidence/2026-09-06-r12-d05-core-binding/previous-runtime-binding.json)
retain exact identities; installed APK and physical log inspection remain open.

| Fact | Current state |
|---|---|
| Retained public Android release | Production-signed direct APK `1.1.6` |
| Working package target | `1.2.0+4053` |
| Latest exact candidate | Private signed `pokrov-1.2.0-candidate.33`, build `4053`; exact physical install/Wi-Fi runtime is partially proven, Beeline automatic mode is bounded to 32 seconds before an external transport change, exact LDPlayer install/cold-start identity passes without network credit, and Gate F remains `BLOCKED 2/17/0` |
| Package ID | `space.pokrov.pokrov_android_shell` |
| Exact candidate source | Platform `f530005…5bc1`, client `6ab1bca…735e`, Core `cd8f0f4…884d`; ARM64 APK `1eca4cbe…cda5`, `101366678` bytes, universal APK `51b86f66…583f2`, `295370161` bytes, and x86_64 APK `fe1fa2d2…3168`, `109951989` bytes |
| Exact candidate Core package | Secret-safe POKROV Core `1.1.0` from `cd8f0f4…884d`, AAR `2a9677d9…c6a69`; two builds are byte-identical and contain all four required ABIs |
| Support-mode signing public pin | `PASS_EXACT_ARTIFACT` — tracked `pokrov-support-2026-08`; candidate.33 signed supply and private artifact scan retain the source-bound trust root |
| Retained public Core | `1.0.3`; rollback/history identity only |
| Google Play | `NOT_REQUESTED` |

Current source separates direct and store update authority. It also keeps
notification detail private, bounds TUN MTU and uses Core/TUN traffic counters.
Release-safe lifecycle, permission, network, Doze/app-standby, stack-free
watchdog and direct-updater identity breadcrumbs are written through a closed
schema to two bounded files under the app-private no-backup directory. No raw
message, URL, profile, token, endpoint or stack is accepted by that journal.
The Home live-speed card is labelled `Сейчас через POKROV`: Android samples
Core/TUN totals for the current session, with reset/unavailable states. It does
not use UID-wide `TrafficStats`. Account traffic in Profile remains the separate
`panel_runtime` measurement and is not a total of the Home samples.
These local contracts do not prove final APK bytes or physical behavior.

## Exact Candidate.33 Physical Android Partial

Candidate.33 is private and has `promotion_authorized=false`. The production-
signed universal APK `51b86f66…583f2`, `295370161` bytes, was installed in
place on a physical Huawei/Android 12 device with `adb install -r`. Application
data was retained; uninstall and clear-data were not used. Package readback is
`1.2.0+4053`, and the installed `base.apk` SHA-256 is byte-identical to the
candidate artifact. `apksigner` verifies APK Signature Scheme v2 and the
production certificate `0a0602a7…2500`.

On Wi-Fi, the preserved ordinary profile reached Android `CONNECTED` and
`VALIDATED`. DNS and reply probes for `example.com`, `chatgpt.com`,
`gemini.google.com` and `xbox.com` passed, and the bounded process log had no
fatal exception, ANR, uncaught exception, terminal egress error or permission
denial. The package update itself stopped the prior VPN, so one explicit
in-app reconnect was required; automatic post-update reconnection is not
claimed.

On physical Beeline, the selected Milan whitelist profile briefly created a
validated VPN but later failed closed. The emergency whitelist screen reported
four saved and four checked channels, then returned `Не удалось подключить
экстренный маршрут.` Automatic selection held a connected, validated VPN for
32 seconds. At the next observation the underlying transport changed back to
Wi-Fi outside the test harness, so the remaining interval receives no Beeline
credit. This is a bounded cellular PASS plus two honest fail-closed results,
not a full Beeline/endurance PASS.

Managed `awg2_lab`, `awg31_lab` and `hy2_lab` were not run because the device
had no authorized managed lab binding and no server rollout was changed.
Direct-DoH/external Smart-DNS UI, WARP, per-app, IPv6/leak, UDP53/MTU, OEM and
endurance also remain open. After owner foreground use was detected, ADB UI
actions stopped; the final retained state has Wi-Fi enabled and POKROV
disconnected. Normalized secret-free evidence is
[`candidate33-physical-android.json`](evidence/candidate33-physical-android.json).

Classification:
`PARTIAL_EXACT_CANDIDATE_33_ANDROID_PHYSICAL`; promotion effect `NONE`.

## Exact Candidate.33 LDPlayer Install And Cold Start

The production-signed universal APK `51b86f66…583f2`, `295370161` bytes, was
installed in place over build `4030` on the dedicated LDPlayer 14 Android 14
instance `pokrov-qa-120`. Application data was preserved; uninstall and
clear-data were not used. Package readback reports `1.2.0+4053`, and the
installed `base.apk` is byte-identical to the candidate artifact.

The exact `MainActivity` cold-started successfully in `665 ms` and remained the
top resumed activity on one stable PID for `321` seconds while the LDPlayer
window stayed minimized and responsive. The crash buffer remained empty. No
POKROV VPN service or emulator `tun0` was present. A sanitized UI-tree summary
contained `23/23` nodes from the POKROV package and no foreign-package nodes;
the raw tree and screenshots were not retained.

The host simultaneously had Hiddify and its sing-tun `tun0` active. DNS,
egress, VPN, AWG, Smart-DNS, WARP, routing and protocol checks are therefore
`BLOCKED_BY_HOST_TUN` and receive no release credit. An earlier hidden-window
harness run was externally terminated by LDPlayer; its engine log records a
requested shutdown, not a product crash. The primary minimized run passed and
the QA instance was stopped gracefully with candidate data retained.

Normalized evidence is
[`candidate33-ldplayer14-ui.json`](evidence/candidate33-ldplayer14-ui.json).
Classification:
`PASS_EXACT_CANDIDATE_33_LDPLAYER_INSTALL_IDENTITY_AND_COLD_UI_START_ONLY`;
promotion effect `NONE`. Gate F remains `BLOCKED 2/17/0`.

## Exact Candidate.32 Android Boundary

Candidate.32 is private with `promotion_authorized=false`. Its ARM64,
ARMv7, universal and x86_64 APKs plus market AAB pass production-certificate
identity and private creation binding. Strict-v2 handoff `df85e2ee…2bef`,
refreshed SBOM/provenance and signed manifest/signature/receipt
`b15938e1…a449` / `e63d8ee3…fcf4` / `7bfaf81f…5a42` validate from exact
release-index source `5d11fd6…53c3`. Exact candidate.32 LDPlayer install/launch
and physical ARM64 install/runtime have not run. Older
candidate install, AWG, WARP, handoff, Doze, routing and endurance results do
not transfer.

The current host routes through a separate TUN, so any future LDPlayer network
result from that host is excluded from release credit. Emulator credit is
limited to exact APK install, version/byte identity, launch and process/crash
checks until an isolated network environment is used. Physical Android must
first hash-bind the installed base APK to ARM64 artifact
`fe8d8228…85f9`, then retain Wi-Fi and Beeline default/lab/runtime evidence.

Candidate.23 Gate F was not generated. Its missing exact installed Android
identity remains an unmet gate, while the independent Windows serial-pipe
contention failure makes the candidate `NO_GO`. Gate G, public assets, Store
submission and stable promotion remain unauthorized.

## Working Build 4053 Pipe-Retry Successor

The continuing build `4053` source line keeps Core `cd8f0f4169d570d693992a959d81d17c2c44884d`
and the existing Android transport surface while correcting the Windows
service client. Two Android Core builds remain byte-identical: AAR
size `107419397`, SHA-256
`2a9677d9e24ed7ef66d4e98f90e7033eb5450c9a2755f0fe6b8bba58036c6a69`,
with all four required ABIs. The bytes are synchronized into the client source.
Candidate.23 carries these exact Core bytes in build `4052`. Its five Android
artifacts retain the production certificate lineage and signed-index supply,
but no exact candidate.23 APK is installed or runtime-tested.
The candidate.16 installs below remain retained evidence for older bytes only.

## Exact Candidate.16 Physical Install Binding

The production-signed ARM64 APK from immutable candidate.16 is installed as an
ADB package update without launching the app or taking screen control. The
pre-install state had no POKROV process and no `tun0`. Exact post-install
readback reports `1.2.0+4049`, `101366678` bytes and SHA-256
`9bcdbe00fe8f8ed029894a65d531614f4fb912dda27e5fb1bb088c5b7516cc74`,
byte-identical to the signed candidate artifact. The post-install state still
has no POKROV process and no `tun0`.

This closes only the required exact physical ARM64 install binding. No app
launch, VPN permission, profile fetch, TUN, DNS, egress, AWG, WARP, per-app,
handoff, Private DNS, leak, MTU, Doze, endurance or Store check ran. Gate F
validates the signed tuple and all `19/19` pointers, then returns
`NO_GO 2/17/2` with zero validation errors. Candidate.16's two LDPlayer AWG
egress results are the explicit FAIL boundary and the full physical matrix
remains `MANUAL_OWNER_TEST`.

Normalized evidence is
[`candidate16-physical-android-install.json`](evidence/candidate16-physical-android-install.json),
SHA-256 `8a7af4360debd2f33bd0b0a0af4e745e7a9c86f6f7092d9c66e9740e7d7b80ea`.

## Retained Exact Candidate.13 LDPlayer Gate

Candidate.13 is an immutable signed internal candidate for app `1.2.0+4049`
with six artifacts, `ACTIONS_ARTIFACT_ONLY` and
`promotion_authorized=false`. Its production-signed x86_64 APK installs
byte-identically at SHA-256
`73c43e21dfc984c474941e14800c551f9545fe423b8f11458f6d41b8cb9af5ff`.
The physical phone was not addressed; this is exact emulator/current-origin
evidence only.

| Check | Candidate.13 result |
|---|---|
| Supply identity | `PASS_EXACT_INTERNAL_CANDIDATE` — manifest `b8a10cf8…190c`, signature `ede7844c…0e4d`, receipt `fc3b1319…b295`, exact source tuple, six artifacts, SBOM and provenance; no tag, public asset, Store object or promotion |
| AWG 3.1 | `PASS_EXACT_CANDIDATE_LDPLAYER_BOUNDED` — exact control-plane selection and normalized runtime-profile match; tunnel, managed DNS and authenticated VPN egress are green |
| Warm AWG2 after AWG 3.1 | `PASS_EXACT_CANDIDATE_LDPLAYER_BOUNDED` — normal VPN teardown/recreate in the same application process accepts the new Core run, matches AWG2 and reaches green tunnel/DNS/egress without `force-stop` |
| Warm default/Auto after AWG2 | `PASS_EXACT_CANDIDATE_LDPLAYER_BOUNDED` — ordinary non-AWG profile contains `33` VLESS outbounds and reaches independent green tunnel/DNS/egress in the same process |
| Lifecycle fence | `PASS_EXACT_SOURCE_AND_RUNTIME` — a changed `runId` resets the sequence fence even when local service generation is reused; delayed callbacks from the previous run remain rejected |
| Emulator transport observation | `RECOVERED_ENVIRONMENT_OBSERVATION` — two short exact-serial ADB reconnects occurred during VPN teardown polling; immediate readback recovered with the unchanged app process and requested disconnected state |
| Final cleanup | `PASS_DEFAULT_OFF_CLEAN_RESTORE` — `default` selected, app disconnected, lab binding/material absent, and no active VPN service or tunnel interface |

Gate F is not generated. Its current validator requires an exact physical
Android install binding to candidate.13's ARM64 APK `9bcdbe00…cc74`; no such
binding exists in this slice. The honest status is
`NOT_RUN_MISSING_EXACT_ARM64_INSTALL_BINDING`. Physical modem/OEM/Doze/WARP,
per-app, Private DNS, external IPv6/leak and endurance remain
`MANUAL_OWNER_TEST`. Candidate.12 below is retained rejected history.

## Exact Candidate.12 LDPlayer Gate

Candidate.12 is an immutable signed internal candidate for app `1.2.0+4048`
with six artifacts and
`promotion_authorized=false`. LDPlayer 9 `emulator-5554`, Android 9/API 28,
installed the production-signed x86_64 APK byte-identically at SHA-256
`e7f74fb22e981c1765642e9197c785b7242827db26b2a623f42ab122dadddd3c`.
The physical phone was visible to ADB but no command addressed it. This is
exact emulator/current-origin evidence only.

| Check | Candidate.12 result |
|---|---|
| Supply identity | `PASS_EXACT_INTERNAL_CANDIDATE` — signed manifest `22ba8bb1…ab98`, detached signature `c2ad2655…1b32`, receipt `1144f7ac…7444`, exact four-source tuple, six artifacts, SBOM and provenance; publication and promotion remain unauthorized |
| AWG 3.1 fresh profile | `PASS_LDPLAYER_CURRENT_ORIGIN_FRESH_PROFILE` — safe runtime readback found exactly one typed AWG endpoint and the AWG 3.1 final route; Android TUN, DNS, mandatory Core egress and selected exit passed, while a 60-second address-free inner capture counted bidirectional TCP payload |
| AWG2 warm switch | `FAIL_EXACT_CANDIDATE_12_WARM_SERVICE_RESTART_EVENT_FENCE` — after the successful AWG 3.1 run, AWG2 established TUN, DNS and routes with bidirectional inner traffic, but two mandatory egress probes ended `stalled`; the app did not claim full protection |
| AWG2 cold control | `PASS_LDPLAYER_CURRENT_ORIGIN_COLD_PROCESS` — after a process restart, the same exact APK, server material and typed AWG2 profile reached terminal Core egress `verified` and retained green tunnel, DNS, exit and route state beyond one minute |
| Exact Core/server differential | `PASS_CURRENT_ORIGIN_CORE_INTEROP_AND_ALIGNMENT` — candidate Core `cd8f0f4…884d` passes AWG2 authenticated interop from current origin and both owned profiles pass all `11/11` secret-free live alignment checks; no server or cryptography change is indicated |
| Ordinary Auto restore | `PASS_LDPLAYER_CURRENT_ORIGIN_AUTOMATIC_FAILOVER` — the first VLESS leaf failed mandatory egress and stopped fail-closed; the automatic successor established TUN and terminal egress `verified`, with UI-confirmed DNS, exit and routes |
| Final cleanup | `PASS_DEFAULT_OFF_CLEAN_RESTORE` — guarded readback selected `default` / `legacy_reality_fallback`, removed AWG2/AWG3.1 material and lab membership, and left the UI disconnected with no connected POKROV VPN |

The warm-switch failure is a client lifecycle defect. A newly created
`VpnService` can restart its local session generation at `1` and Core restarts
its event sequence for a new `run_id`, while the process-wide Android event
fence retained the preceding run's `lastSequence`. Valid egress events from
the new run were therefore rejected as stale. Successor source resets the
sequence fence when the run identity changes while preserving monotonic
filtering between attempts inside one run. Focused direct/store JVM regression
tests pass. Candidate.12 remains immutable and requires a new signed candidate
plus an exact warm AWG 3.1 -> AWG2 replay without a process restart.

## Exact Candidate.11 LDPlayer Gate

Candidate.11 is an immutable signed internal candidate with six artifacts and
`promotion_authorized=false`. LDPlayer 9 `emulator-5554`, Android 9/API 28,
installed the production-signed universal APK byte-identically at SHA-256
`706c546e4d1f1d5a5f476a10f21bd178aff412ffbc163b4a3d0557b4c9655e1a`.
This is exact emulator/current-origin evidence, not physical-device, OEM,
RU-origin, store or stable proof.

| Check | Candidate.11 result |
|---|---|
| Supply identity | `PASS_EXACT_INTERNAL_CANDIDATE` — signed manifest `22ea88cb…a29f`, signature `c1a4c3ce…912c`, receipt `f78e61b0…15aa`, exact four-source tuple and six artifacts; publication and promotion remain unauthorized |
| AWG 3.1 fresh profile | `PASS_LDPLAYER_CURRENT_ORIGIN_FRESH_PROFILE` — the staged runtime contained exactly the `pokrov-awg31-lab` typed AWG endpoint, Android TUN established, mandatory Core egress changed from required to verified, the app finished the attempt as succeeded, and a 60-second address-free inner capture counted bidirectional TCP payload |
| AWG2 compatibility control | `PASS_LDPLAYER_CURRENT_ORIGIN_FRESH_PROFILE` — the independently fetched `pokrov-awg2-lab` profile established TUN and verified Core egress; address-free inner capture counted `63` packets, `37` from client and `25` to client, including bidirectional TCP payload |
| Ordinary Auto restore | `PASS_LDPLAYER_CURRENT_ORIGIN_FRESH_PROFILE` — after guarded `default` bind and cache separation, the non-AWG VLESS/selector profile established TUN and verified Core egress |
| Runtime-profile identity | `PASS_MANUAL_SAFE_READBACK; SUCCESSOR_VERIFIER_IMPLEMENTED` — the test inspected only normalized route/endpoint types and booleans, never raw config, address or key material. A successor source verifier now exits nonzero when a cached default profile is presented as AWG |
| Automatic-node quarantine interaction | `FAIL_EXACT_CANDIDATE_11` — after an ordinary Auto node entered the bounded quarantine set, a later owner-lab retry stopped before profile staging with `Не удалось найти доступную автоматическую локацию.` The candidate incorrectly applied ordinary Smart Connect exclusions to the AWG/HY2 lab envelope |
| Final cleanup | `PASS_DEFAULT_OFF_CLEAN_RESTORE` — the exact device was rebound to `default`, AWG material and lab membership were absent, test-created private profile backups were removed, the UI was disconnected and Android reported no connected VPN |

The clean AWG2/AWG3.1 passes remain valid for their exact attempts, but the
quarantine interaction makes candidate.11 non-promotable. Successor source
sets `smartConnect=null` for `awg2_lab`, `awg31_lab` and `hy2_lab`, and skips
the Smart Connect resolver when no eligible profile exists. That correction
passes the complete `app_first_runtime_bootstrap_test.dart` file (`86/86`) and
`flutter analyze`; it requires a new candidate and exact runtime repeat.

## Exact Candidate.8 Gate

Candidate.8 binds the exact platform/client/Core/release-index tuple, five
production-signed Android artifacts and the unsigned-Windows direct-beta
exception. Its signature and supply chain pass, but promotion remains false
and the physical Android matrix is still incomplete. Candidate.3 and all
working-build sections below remain history for their exact older bytes only.

| Check | Retained candidate.8 result |
|---|---|
| Clean source tuple | `PASS_EXACT_CANDIDATE_8` — platform `241a83b…c39`, client `3459438…f5c`, Core `a45d69e…665e`, signed release-index source `b242e0a…a8` |
| Exact Core AAR identity | `PASS_LOCAL` — `ce82f54b…54dd`, two byte-identical builds, four ABIs |
| Strict-v2 Android artifact entries | `PASS_SIGNED_CANDIDATE_8` — manifest `f0006cec…906f`, signature `5fcae067…24f6`, receipt `4109bb34…1fc`, promotion false |
| Exact APK support signing pin | `PASS_EXACT_ARTIFACT` — candidate.8 supply evidence binds the active support public key; no private key was read or exported |
| Production signer and lineage | `PASS_5_OF_5` — all candidate.8 APK/AAB entries pass signer verification |
| Package/version/ABI identity | `PASS_EXACT_ARTIFACTS` — `1.2.0+4046`, universal plus three direct ABI APKs and store AAB |
| SHA-256 and byte-size match | `PASS_EXACT_ARTIFACTS` — ARM64 APK `9278c09f…572`, `101366934` bytes, and x86_64 APK `ec07ba17…2627`, `109952213` bytes; both installed base APKs are byte-identical |
| LDPlayer install/start/catalog | `PASS_EXACT_EMULATOR_REHEARSAL` — release/non-debuggable x86_64 APK `ec07ba17…2627` installed and read back byte-identically as `1.2.0+4046`; all seven active locations, including Saint Petersburg, are present after refresh |
| LDPlayer ordinary control | `PASS_FAIL_CLOSED_CURRENT_ORIGIN` — the ordinary Frankfurt path formed a TUN but did not confirm protected egress; POKROV stopped Android VPN and showed the explicit unprotected retry state rather than false green |
| LDPlayer AWG2/AWG3.1 | `PASS_AWG2_AWG31_TUN_DNS_SELECTED_EGRESS` — separate guarded owner-lab binds reached connected state only after app-confirmed tunnel, DNS and selected egress; server alignment and count-only outer-traffic evidence were retained without raw addresses |
| LDPlayer final restore | `PASS_DEFAULT_OFF_CLEAN_RESTORE` — guarded restore selected `default` / `legacy_reality_fallback`, removed AWG2/AWG3.1 material and lab membership, left WARP off, no `tun0`, and the UI at `Не защищено` / `Подключить` |
| Private operational journal source contract | `PASS_LOCAL` |
| Exact-device diagnostics redaction | `PASS_BOUNDED_UI_REVIEW` — no endpoint, key, raw profile, subscription URL, token or address appeared in retained user-facing diagnostics; screenshots/UI-tree summaries are retained outside the repository by SHA-256 |
| Anonymous download | `NOT_RUN` |
| Huawei install and first launch | `PASS_EXACT_ARM64` |
| Connect/disconnect and verified egress | `PASS_ORDINARY_AWG2_AWG31` — connected is shown only after tunnel, DNS and selected egress confirmation |
| Wi-Fi/LTE handoff and sleep/resume | `PASS_ONE_PHYSICAL_DEVICE` — mobile/Wi-Fi/mobile/Wi-Fi, 15-second screen-off, forced Doze and app standby preserved the service and connected state |
| Full/selected/excluded routing | `PASS_FULL_SELECTED_AND_EXCLUDED_EXACT_CANDIDATE` — selected-app mode keeps only the chosen app in the VPN range and proves TUN traffic plus excluded control bypass. The later excluded-app slice proves the inverse with the same redacted control app: it first crosses TUN while included, then leaves the VPN UID ranges, loads a public benign page directly and adds only bounded background TUN traffic |
| DNS/blocked UDP 53/MTU matrix | `PASS_PRIVATE_DNS_INTERACTION; IPV6_BLOCKED_NO_UNDERLYING_IPV6; UDP53_AND_EXTERNAL_MTU_OPEN` |
| WARP enable/fallback/restore | `PASS_EXACT_FALLBACK_PATH; ACTIVE_WARP_TRAFFIC_NOT_PROVEN` — every attempt returned to verified ordinary POKROV without loss of access; revoke and final WARP-off restore passed |
| 100-cycle endurance and battery | `MANUAL_OWNER_TEST` |
| Privacy, backup and exposed-port audit | `PASS_BOUNDED_DIAGNOSTICS_REDACTION; BACKUP_AND_EXPOSED_PORTS_OPEN` |
| Store submission | `NOT_REQUESTED` |

Every manual check must name the exact APK SHA-256 and device. Emulator proof
is preflight only and cannot clear a physical-device gate. The ordinary
LDPlayer origin failure does not downgrade the AWG2/AWG3.1 results and the lab
passes do not turn ordinary emulator egress into a pass; each profile keeps
its observed outcome.

The retained physical results close only the named candidate.8 rows. They do
not prove active WARP carriage, external IPv6/leak behavior, blocked UDP 53,
external MTU, a multi-OEM matrix, 100-cycle/battery endurance, store
submission, public download or release promotion.

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

## 2026-08-29 Previous Security-Fixed Core Refresh

The previous client binding used Core `547f096…8cd`, which updates the
affected Go crypto dependency to its `GO-2026-6303` fixed line. Two Android
builds produced byte-identical AAR `7895b2f7…1a63`, size `107414253`, with all
four required ABIs. The client machine contract and bundled AAR bind those
exact bytes.

The preceding physical AWG2/AWG3.1 result remains valid supporting evidence
for the owned server reply-route correction and the protocol path exercised by
Core `3c2b114…d0f`. It does not transfer to the new AAR.

## 2026-08-29 Exact Security-Fixed Physical Repeat

Client `064fcd0…599` plus Core `547f096…8cd` produced production-signed,
release/non-debuggable ARM64 APK `1.2.0+4046`, size `101364310`, SHA-256
`7d1d409368fe8c14c0a5064e0104e10ab0d7c798ff96ca5a65e2b65af6958ee5`.
It installed and read back byte-identically on physical Huawei/Android 12; its
embedded ARM64 Core entry matches the bound AAR entry. Ordinary Frankfurt
reached verified green on the same APK and Beeline path.

AWG2 completed a fresh authenticated handshake and a bounded capture counted
`70` client-to-server and `47` server-to-client inner packets, including `57`
TCP payload packets and `5` UDP packets. AWG3.1 completed a fresh randomized-
trailer handshake and counted `69`/`47` inner packets, `50` TCP payload packets
split `25/25` between directions, and `8` UDP packets. Neither capture saw a
TCP reset. Exact Core operator interop passed authenticated TLS/HTTP for both
owned profiles.

Android still reported `EGRESS-001` for both selected endpoints. The profile's
IPv4-only DNS correction matches its IPv4-only routed prefix but did not change
that result. Classification: `PASS_ACTIVE_CORE_AWG_TRANSPORT` plus
`FAIL_ACTIVE_CORE_AWG_SELECTED_EGRESS`, not end-to-end or candidate PASS.

Cleanup restored `default`, removed both lab materials and membership, stopped
the POKROV VPN service and restored Wi-Fi. The full lifecycle/OEM/per-app/WARP,
leak and exact-candidate matrix remains `MANUAL_OWNER_TEST`.

## 2026-08-29 AWG Endpoint Resolver Correction

Production-signed diagnostic client `f078625…b09` with Core `547f096…8cd`
installed and read back exactly on the same physical device. AWG2 and AWG3.1
both retained the exact terminal diagnostic `egress_probe_dns_lookup` at the
first attempt. Because the two profiles use different tunneled resolver
transports, the common failure was traced to the Core-owned AWG endpoint
resolving its inner FQDN with empty query options instead of the configured
Android default-network bootstrap resolver.

Core `a45d69e…665e` corrects that boundary without changing the authenticated
hostname, pinning a provider IP or weakening fail-close. Two Android builds
produced byte-identical AAR `ce82f54b…54dd`, size `107425409`, with all four
required ABIs; the client machine contract and bundled AAR bind those exact
bytes.

Client `68779c4…f21` produced production-signed, release/non-debuggable ARM64
APK `1.2.0+4046`, size `101366934`, SHA-256
`b583205db9e197c6de873264821319ef1108a2786f1ee5466501712568147296`.
It installed and read back byte-identically on physical Huawei/Android 12 and
embeds the ARM64 Core entry from the bound AAR. With Wi-Fi disabled and mobile
Beeline active, both AWG2 and AWG3.1 independently reached green connected
state and retained it beyond the egress-probe window; the former terminal
`egress_probe_dns_lookup` category did not return. The same source also passed
both profiles on the exact x86_64 production build in LDPlayer.

Cleanup restored the device's default binding, stopped POKROV and restored the
original Wi-Fi, mobile-data and foreground-app state. Sanitized local evidence
SHA-256 is `2f340d98a5f9b7290954ef97f3cdd80a7af70d435630ef7db76a37d5ea8cab18`.
Classification: `PASS_ACTIVE_CORE_AWG2_AWG31_SELECTED_EGRESS_PHYSICAL`, not a
strict-v2 candidate, WARP/per-app/OEM/lifecycle/endurance or broad release PASS.

## 2026-08-29 WARP And Host-Lifecycle Preflight

The exact installed x86_64 production APK `1.2.0+4046`, size `109952213`,
SHA-256 `3d95d82d8290150fadd13600b79eca26326792407532f571909d8df224df6fa4`,
created the Android VPN transport for a WARP attempt and its automatic ordinary
fallback in LDPlayer. Both failed the required Core egress probe. A separate
WARP-disabled ordinary control failed with the same terminal `EGRESS-001`, so
the bounded result is `BLOCKED_BY_LDPLAYER_NETWORK_CURRENT_ORIGIN`, not a
WARP-specific regression. Cleanup restored WARP off and left no POKROV service
or `tun0`.

On the exact physical working APK, service and TUN continuity passed one
Wi-Fi/LTE/Wi-Fi sequence, forced Doze and app standby. Final readback restored
Wi-Fi, mobile enabled, active Doze state, app standby false and no POKROV
service/TUN. The secure keyguard prevented protected-egress and terminal WARP
UI readback, and WARP preference restoration still awaits owner unlock. This
is partial host-lifecycle evidence only; WARP, per-app, Private-DNS/IPv6 leak,
OEM, endurance and exact-candidate rows remain `MANUAL_OWNER_TEST`.

## 2026-08-29 Exact Candidate.8 Physical Matrix

The production-signed ARM64 candidate.8 APK `1.2.0+4046`, size `101366934`,
SHA-256 `9278c09fd8fa5768d3260cf796b4230db5acb0a092187aae00c441d717cfc572`,
was already installed byte-identically on the unlocked physical Huawei/
Android 12 device. The source tuple is client `3459438…f5c` and Core
`a45d69e…665e`. No APK, profile, backend or server mutation occurred during
this continuation.

WARP consent and generation handling passed the exact fallback path. Across
three observed attempts, including one unintended extra re-enable while
returning from the details surface, the client never reported active WARP as
proven. It moved through apply/next-connect state, then settled on
`На паузе · обычный режим` after about 36 seconds. Each terminal generation
kept the ordinary POKROV tunnel usable and the protection sheet confirmed
tunnel, DNS and selected egress. Consent revoke cleared the local enabled
state, and a WARP-disabled ordinary reconnect passed. Classification:
`PASS_EXACT_WARP_FALLBACK_AND_RESTORE`; active WARP traffic is
`NOT_PROVEN`.

The same exact candidate then passed these bounded host checks:

- mobile/Wi-Fi/mobile/Wi-Fi handoff retained `Подключено` on every leg;
- a 15-second screen-off/background interval retained the VPN transport and
  returned to `Подключено` after wake;
- Quick Settings stop removed the service and start restored verified
  connection; the notification `ОТКЛЮЧИТЬ` action also stopped the service and
  returned the app to `Не защищено`;
- forced deep Doze reached `IDLE` for ten seconds while the service remained
  present, then restored `ACTIVE`; forced app standby reached `Idle=true` for
  eight seconds while the service remained present, then restored
  `Idle=false`. The UI still showed `Подключено` after both recoveries;
- strict Android Private DNS interaction retained tunnel, DNS and egress
  confirmation. The public test resolver name was not retained;
- IPv4 worked both with and without the VPN on the same Wi-Fi path. IPv6
  failed in both controls, so the result is
  `BLOCKED_NO_UNDERLYING_IPV6`, not an IPv6 leak PASS or FAIL.

Per-app routing passed with one ordinary installed test app. Android's active
VPN UID range matched the selected app UID and excluded the POKROV host UID.
The idle TUN delta was `0/0` bytes; launching the selected app produced
`2391111` received and `2485252` transmitted TUN bytes. After the selected app
was stopped, an excluded shell control retained internet access with `0/0`
additional TUN bytes. This is `PASS_SELECTED_APP_TRAFFIC_AND_BYPASS`; the
separate inverse excluded-app mode is proved by the 2026-08-30 slice below.

The user-facing status and history surfaces exposed no endpoint hostname,
address, key, raw profile, subscription URL or token. Device serial and raw
runtime material were never retained, and all screenshots/UI dumps were
deleted after deriving the sanitized facts.

Final restoration selected `Всё устройство`, cleared the test-app selection,
left WARP off, stopped POKROV, disabled Wi-Fi, kept mobile data enabled,
restored Private DNS mode and its prior specifier, restored all three animation
scales to `1.0`, preserved `stay_on_while_plugged_in=2`, returned Doze to
`ACTIVE` and app standby to `Idle=false`.

The remaining Android blockers are active WARP carriage, external IPv6/leak
proof, blocked UDP 53 and external MTU checks, broader OEM coverage,
100-cycle/battery endurance, backup/exposed-port review and public/store
delivery. This exact physical slice does not authorize promotion.

## 2026-08-30 Exact Candidate.8 Excluded-App Mode

The installed physical ARM64 package was re-read before this slice: size
`101366934`, SHA-256
`9278c09fd8fa5768d3260cf796b4230db5acb0a092187aae00c441d717cfc572`,
release/non-debuggable `1.2.0+4046`, valid APK signature and the exact
production-certificate digest. The temporary pulled APK was deleted.

On the redacted owner Wi-Fi, the ordinary foreign profile reached the app's
proof-driven connected state in `Кроме выбранных`. The same redacted control
app provided the before/after differential:

- while included, its UID was inside the Android VPN UID ranges and a
  ten-second page-load window added `380962` received and `379884` transmitted
  TUN bytes;
- after explicit exclusion and the app-managed reconnect, its UID was absent
  from the VPN ranges while the POKROV host UID remained excluded;
- the excluded control loaded a separate public benign page, while the
  twelve-second window added only `776/776` TUN bytes, below the bounded
  `10000`-byte background threshold. A six-second idle control had added
  `208/208` bytes.

This is `PASS_EXACT_CANDIDATE_EXCLUDED_APP_TRAFFIC_AND_BYPASS`. It proves one
physical Android implementation of the inverse per-app mode, not broad OEM,
external leak, UDP53, MTU or endurance behavior. A preliminary terminal UI
probe whose marker was not created is explicitly discarded and contributes no
network result.

Cleanup disconnected POKROV, removed both temporary app selections, restored
`Всё устройство`, WARP off, zero TUN, Wi-Fi off, mobile data on and Private DNS
off, deleted all temporary APK/marker/screenshot/UI files and returned Hiddify
to the foreground. No device identifier, UID range, app identity, network
identifier, terminal history or runtime material is retained. Sanitized
evidence SHA-256 is
`2d8f57bfe9ba99285c691c39ece6428836ea6cf4e5065c91e26f4a6fa77a19c8`.

## 2026-08-30 Exact Platform Candidate.10 Smart-DNS LDPlayer Replay

The signed platform candidate.10 binds client source
`3459438f02bd774e722b1b858e7f7f16d57a9f5c` and the x86_64 production APK
already installed in LDPlayer. Fresh device-side SHA-256 readback is
`ec07ba17e9a5c697fcf46ccd193970fa3666eeeb3b9e345876aa8ee1d45a2627`,
exactly matching the retained candidate.10 APK. Package readback remains
release `1.2.0+4046`. The physical phone was unavailable and untouched.

The initial emulator state had no connected Android VPN, no `tun` interface,
`DNS Автоматически` and `Настроено: 2`. Through the user-visible
`Правила -> Редкие настройки -> DNS` path, the exact APK accepted the
allowlisted `dns.pokrov.space/dns-query` custom DoH endpoint, direct-DoH lab
mode and the external Smart-DNS lab mode. The existing `AI-сервисы` and
`Игровые сервисы` purposes both rendered as selected and explicitly warned
that service traffic is direct and the external IP is not hidden.

Custom DoH, direct transport, external Smart DNS and both purpose selections
survived an app force-stop and relaunch. The crash buffer stayed empty. This
proves exact-candidate UI prerequisites, persistence and fail-closed product
copy only. No connection, DoH request, ChatGPT, Gemini or Xbox access test ran:
the hostname was still absent from all four authoritative DNS servers and the
owned resolver/server APPLY had not run.

Cleanup selected `DNS Автоматически`, cleared the custom URL and external
Smart-DNS state, reset DNS transport to VPN through the visible preset path,
returned to `Настроено: 2`, and verified no connected VPN or `tun` interface.
POKROV was force-stopped and all emulator-side temporary capture files were
removed. Classification is
`PASS_EXACT_CANDIDATE10_LDPLAYER_SMART_DNS_CONFIG_PERSISTENCE_AND_CLEANUP`;
live resolver/service access and physical Android remain non-PASS.

The normalized tracked record is
[`candidate10-ldplayer-smart-dns.json`](evidence/candidate10-ldplayer-smart-dns.json).
Its external evidence copy SHA-256 is
`f1dd9f7dc8e4f549ee993f26c037e06cd97e16a76c8a7fda0ff3a8964c2e3ea2`.

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

The build command produces and verifies four production-signed direct APKs and
one production-signed market-only AAB in one fail-closed CLI path. The AAB
check covers its JAR signature, exact production certificate and required Core
ABI entries; its evidence remains `store_submission_status=NOT_REQUESTED` and
`candidate_created=false`. The build command does not authorize publishing or
create a Store claim. The audit command does not replace install, routing,
network, OEM or endurance evidence.

## Retained History

Prior Android candidate identities and audits are preserved as
[2026-08-19-android-release-audit-snapshot.md](history/2026-08-19-android-release-audit-snapshot.md).
They cannot approve `1.2.0`.

### 2026-09-05 local stage/start identity slice

N01C source includes digest-bound service starts, consent fencing, stored-profile
reuse gates and active/effective digest snapshots. Both flavor JVM suites passed
with `gradlew.bat :app:testDirectDebugUnitTest :app:testStoreDebugUnitTest`
(`E:/r12-android-identity-final.log`). Synthetic tests cover same-path content or
route replacement, old consent completion, delayed old proof and stop clearing.
Atomic profile replacement uses OS rename without deleting the old target first;
actual Android rename-failure/crash recovery remains MANUAL_OWNER_TEST.
This is local I3 coverage, not packaged/new-candidate or physical-device PASS.

## R12-D06 local delivery size review — 2026-09-06

The [D06 size report](evidence/2026-09-06-r12-d06-size/README.md) accounts for
all four local Direct APKs and compares them with earlier C05 packages.
Android packaging now excludes only the upstream debugger resource
`DebugProbesKt.bin`. Four rebuilt APKs lose 891 bytes each; every retained ZIP
entry, including manifest, DEX, SO, fonts and license notices, is byte-identical.
ARM64 saves 193984731 bytes versus universal; all nine SOs have no DWARF/debuglink
sections. The duplicate brand assets remain required by the current host-path
contract. This is I3 packaging evidence with internal Android Debug signing
and loopback API. D01/final signed candidate, installation, distribution and
full C05 acceptance remain open; retained candidate.33 evidence is unchanged.
