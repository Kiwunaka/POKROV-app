# Client release status

Private Windows **1.5.0+4167** (`fec1d588`) was built once: 28,626,802 bytes,
unsigned, retaining Core 1.2.14/Cronet. Installation returned 0. On 15 October,
manual WARP was checked and enabled before the single Connect at 01:15:00 UTC.
Runtime became validated at +12.872 s and remained healthy through +60.199 s;
staged/effective profile digests matched. The exact current cabinet/device/build/run
report identifies all four CH WARP chains as **prepare_managed_timeout**, with
zero native duration and no native stage. Route-policy POST completed, but the
managed GET did not finish inside the shared three-second preparation budget.
Ordinary CH VLESS Reality bridge then succeeded (11,748 ms; 64 KiB in 896 ms).
Six attempts were stored without rejection. This proves the preparation boundary,
not a WARP network failure or a working WARP chain. Brain-only read lease
`bd6476f2-0c83-45c1-8d3d-3b26382be19b` closed with fresh health/SSH EOF/FREE
at 01:17:29 UTC; it is not FULL ACK6.

The short cached-profile freshness deadline was also forwarded to each missing
exact candidate. Native probing has a separate budget. The selected-profile
material limit is now one (initial bundled selection remains six), but 4166/4167
still timed out. One normal browser control GET with fewer capabilities returned
the correct exact selection in 1.444 s; it is not a replica of the full client
request. Full-capability server requests additionally validate unselected AWG/HY2
material. Those checks also determine catalog eligibility; no unsafe lazy skip
or server timing diagnosis was introduced. The caller budget correction and a
real chain test remain in progress.

Source checks also fixed candidate IPC size (548-byte reply versus the old generic
512-byte cap; candidate-only cap is now 2048), pending manual-ON Connect, and stale
policy staging after a chain probe. Focused regression checks passed. Neither
the IPC defect nor those policy races explain the observed settled-ON GET timeout.
The new deadline diagnostics retain TimeoutException behavior and snapshot the
operation at the existing deadline; they do not change timeouts or routing.
Platform accepts their closed cause codes without treating them as network hints.

Normal Stop at 01:16:13 UTC and WARP OFF completed. Temporary cabinet subject was
removed and the owned browser closed. VM remains running under root for the
cause/fix/chain test; final baseline restoration and PoweredOff/Unlocked are still
required. Hiddify and host network/clock are untouched. Android remains signed
4161 ARM64; no phone acceptance, FullABI build or publication.

Private Windows **1.5.0+4161** (`c8aff9cb`) passed the real browser-to-app pairing
flow. Its single build produced a 28,622,404-byte unsigned installer; installation
returned 0 and UI/service/Core 1.2.14 binding matched. The browser opened the code
form and one normal submit consumed the fresh code. At 22:09:39 UTC on 14 October,
the existing cabinet's normal API confirmed claimed status, one device, that same
current active Windows device, and a still-valid cabinet session. Month access,
Switzerland and WARP OFF remained; no VPN Connect, extra grant or device was used.
The fix accepts Windows' canonical single-root pairing path and retains a link
arriving before startup subscribes. Native and Dart regression checks passed;
the original browser-launched argv was not captured. At 22:10:59 UTC, the VM had
initialized/stopped runtime, no retained protection/TUN/helpers/fault tasks,
11 routes, baseline DNS and proxy OFF. Temporary browser state was removed and
its window closed; graceful shutdown confirmed PoweredOff/Unlocked, bridge and
GetHostTimeDisabled unchanged. Hiddify and host network/clock stayed untouched.
Android 4161 was built once from the same source, production-signed ARM64 only
(85,199,980 bytes), and saved as
`E:/POKROV-tools/temp/release-1.5.0/pokrov-1.5.0+4161-arm64.apk`. The generic APK
has the same ARM64 bytes and is not a FullABI build. No phone acceptance or
publication is claimed.

Private **1.5.0+4160** (`f6eed53e`) includes same-account website pairing reuse
and the support polling fix. Windows was built once (28,623,254 bytes, unsigned),
installed with exit 0, and its UI/service/Core binding checked. Android was built
once, production-signed ARM64 only (85,199,980 bytes), and saved under
`E:/POKROV-tools/temp/release-1.5.0/pokrov-1.5.0+4160-arm64.apk`; no phone or
FullABI acceptance. Both reuse the accepted Core 1.2.14/Cronet artifacts.
Platform `0dcb3a4` pairing modules are live after one API restart; seven backend
and five client tests plus scoped analysis passed. The real normal cabinet
showed 1 of 1 devices and issued a code, but browser protocol launch did not open
the app form. Same user/session/medium integrity and effective URL registration
matched. Direct launch of the installed EXE with the same raw URI opened the form;
Windows `UrlCanonicalizeW` adds the single root slash which the existing parsers
reject. The expired form was dismissed without submitting. A narrow root-path
compatibility fix and independent startup-link retention fix are under acceptance;
the actual website claim was accepted in 4161 above. No new device or subscription grant.

Private Windows **1.5.0+4159** (`8664bf81`) was built once and installed with exit
0: 28,622,962 bytes, unsigned, service/UI version and retained Core 1.2.14 binding
verified. Its optional `http_local_is_tun` diagnostic passed focused native/IPC,
Dart and Platform checks; it does not change routing or probe acceptance. The
local pending-request test read true/false while still at `sending`; the exact
4157 `response` case was not reproduced. Platform `9f1d3e9` was delivered first.
After normal guest time synchronization (three NTP offsets below 7 ms), one
ordinary CH/WARP-OFF Connect reached validated running at watcher +11.232 s and
remained validated through +90.077 s, with TUN present and no egress failure.
No fault or second Connect was used. This bounded success does not establish
the cause of the earlier failures; no failure tuple or new-field D8 delivery was
observed. Normal Stop restored config_staged at 21:10:58 UTC on 14 October;
at 21:11:25 TUN/helpers/fault tasks were 0, routes 11, DNS baseline and proxy OFF.
Graceful shutdown confirmed PoweredOff/Unlocked, bridge and GetHostTimeDisabled
unchanged. Hiddify/host network/clock were untouched. Android remains saved 4154
ARM64; no public release.

Private Windows **1.5.0+4158** (`ae762f88`, support fix `b23be8e9`) was built once:
28,620,014-byte unsigned installer, with the same accepted Core 1.2.14/Cronet
artifacts. An old in-flight support poll can no longer replace newer send history;
the regression was reproduced before the fix, and 10 support tests plus scoped
analysis passed. This candidate has not been installed or accepted in the VM;
no new connection case is justified by this support-only change alone.

Private Windows **1.5.0+4157** (`82bba408`, diagnostics `b4d83665`) was built
once on 14 October: 28,620,905-byte unsigned installer. Core 1.2.14/Cronet were
reused from the accepted 4151 artifact manifest. The new bounded target, entry
budget and correlated DNS result passed the focused native/IPC, Dart and backend
checks; they do not change timeout or routing behavior. Platform `76ffd21` was
selectively delivered first, then installer exit 0, service/UI 4157 and the retained
Core were verified. One ordinary CH/WARP-OFF connect reached running, then failed
with `core_egress_timeout`: `owned_reserve`, entry budget 1422 ms, correlated DNS A
accepted, `response/deadline/none/0/1469ms`. Stability is still not accepted. These
native durations use a monotonic clock. Guest W32Time stepped wall time back about
70 seconds during the case, so its wall-clock duration is invalid; do not infer a
causal connection from that step. Future cold-boot cases must wait for the existing
time service to settle and use a monotonic watcher. No host clock change was made.
Stop restored config_staged, TUN/UI/tasks 0, routes 11, original IPv4 DNS, empty IPv6
DNS and proxy OFF at guest 20:16:55 UTC; PoweredOff/Unlocked was then confirmed.
Actual D8 delivery of these three fields was not separately read back. Android
remains saved 4154 ARM64; no FullABI or public release.
For this periodic case, `response` means SENDREQUEST_COMPLETE was observed, not
that response headers or the 204 proof were accepted. The 1469 ms covers the whole
HTTP phase after DNS, not only header waiting. The fixed reserve is the apex
`/.well-known/pokrov/egress-probe`; the next server check belongs to its existing
Brain Caddy handler, not portal-api. Do not infer a new timeout fix from this tuple.
The subsequent Brain read found both effective handlers serving local static 204
with the expected marker and no-store. One strict-TLS loopback reserve request
received headers in 49.463 ms. Access logs are not configured; no receipt of the
specific VM request was established. Source review also confirmed that a periodic
deadline removes validation but retains Core, TUN and phase=running. It does not
by itself prove that ordinary user traffic failed or that the VPN was torn down.

The two historical native stall cases and one full instrumented suite subsequently
passed with WinHTTP 12002 at the expected response/TLS stages. The fixture recorded
zero local receive timeouts and client reset 10054. The earlier 12152/12029 cause
was not reproduced or fixed. Only test counters, their assertion and the existing
case selector were changed; this does not require rebuilding production 4157.

Windows candidate **1.5.0+4156** (`7bc66d6e`) was built once as a 28,619,862-byte
private unsigned installer and installed with exit 0, exact version/Core binding
and running service verified. A local regression confirmed that
the 900 ms cross-target wait starved an otherwise working 600 ms reserve. Only
periodic failover now skips that wait; the 3,000 ms owner deadline, original
primary slice, startup and same-target retry delays are unchanged. The focused
reserve regression passed, as did IPC/first-DNS compatibility. The full native
target is not green: both before and after this change, older stall fixtures
returned HTTP 12152 and TLS 12029 instead of the expected timeout codes. Those
fixtures are unchanged. One new ordinary CH/WARP-OFF case started at 18:56:19 UTC,
reached healthy running at 18:56:35 and captured its first periodic failure at
18:56:53: `core_egress_timeout`, `tls/deadline/none/0/1438ms`, guard 0 and
first-owned-DNS `reply_written`. The observation lasted 33.04 seconds. Target
identity is not present in that tuple; the first DNS marker is not correlated
with the periodic query. Stable connectivity is still not accepted, and this
local scheduling fix does not establish or resolve the underlying network cause.
No fault or second Connect was injected. The changing Home action name prevented
the guarded cleanup click; the exact owned UI process was then closed and the
ordinary service Disconnect command used. At 18:59:07 UTC the guest was restored:
TUN/UI/helpers/tasks 0, routes 11, original IPv4 DNS, empty IPv6 DNS and proxy OFF.
Graceful shutdown reached PoweredOff/Unlocked. Host Hiddify/network/clock stayed
unchanged. Another unchanged runtime test or timeout adjustment is not warranted;
the next diagnostic step needs target/budget/query correlation.

Windows candidate **1.5.0+4155**, source `ffbf7f5e`, preserves the failed native IO
observation when the retry wait reaches its deadline and includes the stopped
Home country-label fix. The existing loopback regression failed before the
observation fix and passed afterward; the native egress suite and IPC/first-DNS
compatibility case passed. Retry timings and guard behavior are unchanged.
It was built once (28,621,221-byte unsigned installer) with the accepted
Core 1.2.14/Cronet 4151 manifest and installed with exit 0; installed version,
running service and exact Core binding passed. One ordinary CH/WARP-OFF runtime
check started at 18:36:06 UTC (API health 200 beforehand), reached healthy running
at 18:36:20 and captured the first periodic failure at 18:36:29:
`core_egress_timeout`, `dns_reply/deadline/none/0/516ms`, guard 0.
The new native observation survived, confirming the diagnostic fix on device.
`first_owned_dns_state=reply_written` belongs to the first owned query in that
Core context, not necessarily this periodic query; it does not prove an accepted
DNS answer here. The failing target and underlying network cause remain unknown.
The 3-second periodic schedule currently reserves 1,575 ms for primary, then
waits 900 ms and leaves at most 525 ms for reserve; a local regression is being
used to determine whether that cross-target wait starves a working reserve.
No injected fault or second Connect was used. Stop restored the guest baseline
at 18:38:36 UTC (TUN/helpers/tasks 0, routes 11, original DNS, proxy/WARP OFF),
then PoweredOff/Unlocked was confirmed. Android 4154 ARM64 remains the saved APK.

Private **1.5.0+4154** was built on 14 October from `8de02b00`: the Windows
installer is 28,619,788 bytes, unsigned, with PE version 1.5.0+4154. The
production-signed Android APK is 85,199,980 bytes and contains only arm64-v8a;
its generic and ARM64 output names refer to identical ARM64-only bytes, not a
full-ABI build. Both reuse the accepted Core 2df0fdd/1.2.14 artifacts (Windows
4151 manifest and Android 4148 ARM64 manifest), including the existing Cronet.
4154 was installed and exercised in the owned Windows VM. The manual-WARP
case is not accepted: one Connect at 18:04:05 UTC used cached settings and
selected an ordinary CH VLESS bridge (12,686 ms; its 64 KiB probe passed).
Automatic recovery subsequently repeated; WARP-chain probe records were ignored
with `probe_budget_expired`, not established network failures. The terminal
native failure was `core_egress_dns_failed`: `dns_wait/timeout/none/0/3094ms`,
with frozen `first_owned_dns_state=exchange_failed`. This identifies a failed
owned DNS exchange, not its underlying network cause. Intermediate periodic
observations had been overwritten by `retry_wait/deadline/none/0/0ms`.
No deliberate API fault or further Connect was run. Stop removed protection;
WARP was switched off. At 18:25:17 UTC the guest had TUN/helpers/tasks 0, 11 IPv4
routes, baseline Ethernet DNS, empty IPv6 DNS and proxy OFF; graceful shutdown
then reached PoweredOff/Unlocked. Host Hiddify/network/clock were untouched. Android acceptance,
working WARP-chain acceptance and public publication remain pending.

The stopped Home country label now reads the saved country choice rather than
showing Auto when no individual node was selected. The existing country-selection
widget regression failed before the fix and passed afterward; analyze passed.
Running and failed-reconnect labels retain the last verified location. This small
UI fix was made after the 4154 build and is not included in that installer.

The included source `914cd4a5` fixes the cached
manual-WARP priority, late operator replies in an already closed support chat,
and stale Android uplink callbacks reaching Core after network replacement.
Each regression failed before its fix and passed afterward; focused Flutter
checks/analyze and Android Direct/Store JVM checks passed. The phone has not yet
received the new APK.

Last runtime-accepted Windows candidate (14 October): **1.5.0+4153**, source `b3a06e6d`,
28,619,590-byte unsigned installer; built once and installed successfully in the
owned VM. Core 1.2.14/Cronet reuse remains bound to the accepted 4151 manifest.
The foreground-resume diagnostic fix passed its regression and actual VM use: a
healthy unchanged native binding keeps its protocol/path labels across focus changes.

Real Windows checks passed: CH CountryAuto selected VLESS REALITY through a bridge
and transferred owned HTTP 204/64 KiB. A finite physical TCP failure produced a
native egress failure, then automatic AWG direct recovery after 19.902 seconds
while the block was active, without another Connect action. AWG transferred the
same owned checks afterward. A separate cold CH case selected Hysteria2; its
current native binding and real 204/65,536-byte transfer passed at 16:40:01 UTC.
That case blocked eight resolved TCP/AWG tuples for 40 seconds and skipped two
TCP hostnames returning HostNotFound. The observer did not capture the HY2 label
before its deadline: strict HY2-during-fault evidence is not claimed; actual HY2
traffic was checked after cleanup. Both finite faults removed their objects,
helper processes and watchdog tasks. Final Stop at 16:40:45 UTC restored TUN 0,
11 IPv4 routes and proxy OFF. The subsequent logged-out Telegram WEB proxy check
passed without the POKROV VPN: native transport-with-proxy status plus an owned
authenticated relay session and increasing bytes. Its temporary proxy entry was
deleted and disabled; the server canary was removed and WEB returned OFF. Final
guest readback at 17:25:25 UTC retained the same routes, Ethernet DNS and empty
IPv6 DNS, proxy OFF, TUN/helper/task 0. Graceful shutdown completed: PoweredOff and
Unlocked at 17:28:27 UTC. Host Hiddify/network/clock were untouched.
US is held until the owner replaces its IP; it was not accepted here. One earlier
unexpected RUNNING observation has no established cause; a later stopped-country
change remained stopped. Public release and Android acceptance remain pending.

Previous private Windows candidate (14 October 2026): **1.5.0+4152**, built from
`228cd5a5`. The setup is 28,619,514 bytes, unsigned, and its application PE version
is `1.5.0+4152`. It reuses the bound Core `2df0fdd` / 1.2.14 ABI2 and Cronet from
`windows4151-runtime-artifacts.json`; do not sync the different DLL currently in
Core/dist over these inputs. Ordinary default build flags leave SmartDNS, ATS and
catalog QA disabled while retaining the production support-signing public pin.
Country-only Auto, legacy preference/cache migration, explicit manual WARP,
pairing, support notifications and typed native diagnostics passed focused tests
and app-shell analysis. The installer was installed on the owned VM on
14 October: exit code 0, installed version 4152 and running service confirmed.
The existing account opened with inactive access; protocol and Auto acceptance
remain pending. Android **4152 ARM64** was built once with production signing using the
preserved `android4148-arm64-runtime-artifacts.json` and matching 1.2.14 AAR;
its 85,199,980-byte APK contains only `arm64-v8a`. The builder's generic and
ARM64 output names contain identical bytes; this is not full-ABI acceptance.
The phone has not received this candidate. The compatible new telemetry receiver
was selectively deployed before device testing. These private builds are not a public
release or a renewed SmartDNS case. The historical entries below retain their
original outcomes; the owner's 14 October release scope controls priorities.

Public version: **1.4.5+4086**, using the published POKROV Core 1.2.7 artifacts
and desktop ABI 2. Windows and Android were built from client `5a6f268a`.
The owner-approved quiet GitHub release `v1.4.5` contains four production-signed Android direct APKs,
unsigned Windows beta setup, `release-index.json` and `SHA256SUMS.txt`.
GitHub readback matched all seven asset names, sizes and digests; no announcement job was
created. Windows retains the SmartScreen warning and makes no trusted-signing or
Store claim. Public 1.4.4 remains available for rollback. Ordinary first launch and
Auto passed on the owned Windows VM and Android 9 emulator. The physical Android
phone received the identical APK over USB, and Share opened the system chooser
and Files. Cloud saving was canceled; Nearby/Bluetooth peer transfer was not checked.

Private **1.4.9+4090** and **1.4.10+4091** failed their fresh Android API28 first
Connect before VPN consent or TUN creation, with `CONN-008`. Core initialization
completed in about seven seconds; extending the initial ordinary candidate probe
from four to twelve seconds did not resolve the failure. Windows 1.4.10 passed a
fresh account, ordinary Auto, routes/DNS and owned HTTPS204, followed by a clean
disconnect. Quiet publication is authorized, but these failed candidates remain
private and Brain still recommends 1.4.5. Private **1.4.11+4092 / Core 1.2.8** adds
closed native probe-phase diagnostics and awaits its own ordinary Android check.
Routing catalog remains enabled but unpublished; Smart Access stays disabled.
Protected report #78 localized the private Android refusal to the time before
Start (16.2–16.8 seconds); Start and cleanup occupied only 34–70 milliseconds.
Protected report #79 measured 2577 ms in AndroidCAStore preparation out of a
3933 ms failed manual CH AWG probe; the manual preference had survived the APK
update despite the main screen displaying Automatic. Private 1.5.0+4097 prepares
the same complete CA roots
off-main before candidate timers and reuses a process snapshot; trust-store
changes invalidate it, and interrupted, partial or failed reads are not cached.
The existing Core fallback and active instances remain unchanged. Cancellation
can finish while the read-only preparation completes. Public 1.4.5 remains
recommended until the accumulated 1.5.0 passes normal QA. One normal Auto on the
owned API28 emulator, after clearing the manual preference in Locations, reached
its first VPN consent and connected to CH. The app verified TUN, DNS and VPN
egress; six TUN routes were present, and the same session disconnected cleanly.
Existing QA data and the failure journal were retained. Final production-signed
Android APKs and Windows setup 1.5.0+4097 were built from client `116d7dac`.
Windows passed ordinary Auto DE, six TUN routes, DNS, owned HTTPS204/64 KiB and
clean disconnect. A new Android trial passed Auto CH after VPN permission had
already been granted; its first attempt expired before late OS consent.
A separate clean API28 AVD then failed its first Auto with timely normal consent:
DE/VLESS REALITY passed the candidate probe, but activation/recovery ended with
EGRESS-001 and zero current TUN routes. The saved failure is retained in QA#80;
no unchanged Connect retry is planned. Its exact native cause remains open.
Physical ARM acceptance is deferred until the owner connects the phone.
Android now publishes service stop after cleanup and its terminal runtime state;
a stale TUN observation cannot promote a completed egress failure to running.
The focused native state regression passed. Production-signed private Android
1.5.0+4098 x86_64 and ARM64 packages were built from client `f46314c3`.
One first ordinary Auto on a new API28 AVD with a new trial and normal VPN consent
connected to CH. The exact installation's Brain telemetry recorded running/success
for attempt 1 with egress proof. TUN, six routes, DNS and MTU 1280 were present;
the preinstalled browser loaded the owned HTTPS health endpoint, and a request to
the 64 KiB endpoint increased TUN RX by 71072 bytes. Exact response-body length
and the +10/+20/+30-second samples were not verified in this run. The reported
236761 ms includes QA delay at the VPN explanation, so it is not a first-Connect
speed measurement. Ordinary disconnect removed the TUN and its routes and
restored the Connect button.
After a declined protected replacement, the client reads a fresh runtime snapshot
before retiring its local retained-protection flag. Only a confirmed stop clears
that flag and the active candidate; the attempted candidate remains available for
diagnostics and a normal retry. The focused recovery regression passed.
Scheduled first-activation recovery retains the original attempt and sends one
awaited failed terminal report when recovery is exhausted. A superseded operation
cannot clear the newer attempt. Protected support events also include a separate
runtime snapshot with closed phase, failure kind and stop reason at its observed
read time; this is not a historical native event. Focused regressions passed.
The Android 4098 Core AAR contains all four ABIs; its x86_64 library and Java
classes equal the diagnostic AAR used in this check. Windows 4098 passed an
ordinary Auto CH after an upgrade: TUN, six routes, DNS, MTU 1280, owned HTTPS204
and an exact 65536-byte response were verified. Ordinary disconnect removed its
TUN and routes. A separate CH AWG connection failed at protected DNS before TUN;
the exact installation's Brain telemetry confirmed AWG and the failure.
Private 1.5.0+4099 pins Core 1.2.9 with explicit managed AWG DNS and retains the
existing bootstrap behavior for endpoints without that option. Its changed
AWG/DNS/WARP paths require ordinary VM acceptance. Physical ARM acceptance is
deferred until the owner connects the phone; Brain still recommends public 1.4.5.
The minimum supported version stays 1.3.0. No broadcast or LiveUpdate is planned.
Private 1.4.8 failed profile preparation because its cached recovery had no optional
catalog; the original online failure remains unknown. This candidate permits that
absent catalog only in ordinary VPN modes and retains catalog validation failures.
It requires its own ordinary Connect check and is not a published fix.

First online country Auto without cached or staged material now waits up to 40
seconds for access ACK; pending API-011 asks for an explicit Connect retry with
the same session. Core 1.2.7 treats a successful HTTPS check whose selected route
changed as unavailable under the existing bounded retry; real network failures
and cancellation retain their outcomes. Its Windows DLL and Android AAR are
pinned from Core source `7846df3`; Cronet remains unchanged.

Version 1.4.4 passed the owned Windows VM upgrade from 1.4.3 and offline saving
of the official 1.4.3 setup with equal bytes. Cancel left the destination unchanged;
the saved installer was not executed. Android 1.4.4 UI QA remains **BLOCK** because
the emulator's ADB stayed offline: installation and sharing were not checked.
No fresh 1.4.4 connection acceptance was run on either platform.

The ready 1.4.3 packages passed ordinary first launch and one Auto connection on
the owned Windows VM and Android 9 x86_64 emulator, including DNS and routes,
owned HTTPS 204 and exact 64 KiB transfer. Physical phones and mobile networks
were not part of this acceptance. These are client package results, separate
from the earlier isolated Core selection comparison below.

## Client 1.4.1 quiet publication, 2026-10-02

Owner-approved public release `v1.4.1` contains the existing production-signed four Android
APKs and unsigned Windows beta setup for `1.4.1+4082`, with Core 1.2.2,
`release-index.json` and `SHA256SUMS.txt`; all seven uploaded asset digests
and sizes match the local package. Simple mode keeps country Auto and moves
settings to Advanced. Subsequent fresh-install checks on the owned Windows VM
created a trial and secure pair, but country Auto lost protected egress about
23 seconds after starting. Fresh 1.4.0 with PL ordinary mode stayed healthy and
passed the owned 204/64 KiB traffic check; its selection differs from 1.4.1 Auto.
An instrumented 1.4.1 comparison kept identical profile bytes and four rule sets:
stock Core 1.2.2 lost egress at 19.5 seconds, while 1.2.2 with only the URLTest
failed-history fix stayed healthy beyond 200 seconds and passed 204/64 KiB.
This validates the selection fix. A fresh 1.4.2/Core 1.2.5 Windows installation
created an ordinary trial, stayed healthy on PL Auto/Simple/allExceptRu beyond
five minutes, and passed the owned 204/64 KiB traffic check with its profile unchanged.
On the owned Android 9 emulator both versions returned Profile/API-008 before
VPN permission. Debug tracing confirmed a trial, secure pair and HTTP 200 profile
fetch; the captured-network DNS fallback failed with EBADF because its socket
descriptor wrapper closed before I/O. A controlled 1.4.1 debug run with corrected
descriptor lifetime passed DNS and native candidate admission. The signed
1.4.2/Core 1.2.5 package reached TUN establishment, then stopped on the Core
egress guard; private diagnostics classified the group target as unavailable.
Core 1.2.6 fixes cold URLTest current-tag reporting to use the same TCP fallback
as DialContext without changing selection state, history or timers. Private Android
QA confirmed that this correction passes the startup guard. Ordinary HTTPS still
stalled on Android's mixed TUN TCP path despite successful native egress probes;
changing only its TCP stack to gvisor passed the same owned HTTPS checks. The
client now defaults Android TUN TCP and UDP to gvisor; existing imported TUN
stacks are preserved. The exact kernel return-policy cause is not established.
Final normal 1.4.2+4083 packages built from client `c956e9b` use the published
Core 1.2.6 artifacts. A fresh Windows VM installation created a trial and passed
one default Auto/Simple connection, native health through 185 seconds, and owned
204/64 KiB HTTPS checks through 222 seconds with unchanged profile and routing.
A fresh signed x86_64 Android 9 emulator installation followed Start free access,
default Auto and one Connect with ordinary VPN consent. Its OS TUN remained
present through 298 seconds and ordinary owned 204/64 KiB HTTPS passed at
295 seconds with certificate verification enabled. Android's exact 20/30/181-second
samples and Main runtime-version UI were not captured; Core 1.2.6 is verified by
the build binding. Both test guests are powered off. The five final binaries and
existing release metadata were published quietly as `v1.4.2`.
Older released clients lack first-attempt start coverage, so the production
failure fraction for new installs remains unknown. The new client and deployed
Brain correlate the first observed start and terminal event by trace and sequence.
Physical-device acceptance and old saved-TUN migration are not claimed.
The public 1.4.1 files were published without rebuilding or announcements.
The published 4082 binaries were built from client source `8edd3b2`.
The later D6 correction `c9bcb6b`, which suppresses direct Node latency probes
for bridge locations, is in `main` but is not included in those binaries.
Later source changes preserve the native failure kind in runtime telemetry when
the caller supplies only a snapshot. The Windows service journal also records
the egress probe's closed stage/outcome and numeric error/elapsed time before
retry or deadline handling; it excludes addresses, request data and error text.
Debug QA builds emit closed bootstrap stage, guard reason, HTTP status and
exception class markers, plus a secure-pair presence boolean at persistence and
readback. Request data, paths, secrets and exception text are excluded; this
trace keeps the existing provisioning, retry and storage behavior.
Brain recommends 1.4.1 on Android and Windows with minimum 1.3.0 unchanged;
the public API's versions, URLs, sizes and digests passed readback. Both services
are active and no broadcast or LiveUpdate was created. Rollback restores
`/root/portal_bot/.env.release-backup-20261002T123151Z` and restarts
`portal-api` and `portal-bot`. Physical-device checks remain unclaimed.

## Client 1.4.0 publication, 2026-09-29

Owner-approved quiet publication at 10:10 UTC from client main `f6e5947`,
files built at 11:07–11:11 MSK and published without rebuilding; GitHub asset
digests match the staged SHA256SUMS. Huawei ran the final APK over 1.3 without
clearing data: Core 1.1.2 loaded, Auto connected, the 11 installed RU-catalog
apps bypassed the TUN, and Д8 telemetry reached Brain; an independent Chrome
DNS-leak capture stayed inconclusive because Chrome used its own secure DNS.
The Windows VM ran the final setup (same hash as the published EXE): Auto in
«Только выбранные» connected, `Discord.exe` and `Telegram.exe` exited via the
VPN while other processes stayed direct; Windows DNS per process was not
independently measured. Brain now serves 1.4.0 on both platforms with minimum
1.3.0, so 1.3.0 gets a recommended update, 1.2.0 and older a required one; no
news, LiveUpdate or broadcast was created. Rollback: restore
`/root/portal_bot/.env.bak-release-1.4.0-20260929T101134Z` and restart
`portal-api` and `portal-bot`.

## Client 1.3.0 publication, 2026-09-28

Owner-approved publication on 2026-09-28 used client main `53d3dc2`. Android's
four APKs passed production signer, version and ABI checks; the Windows setup
passed packaging with its Core and runtime dependencies. E2 device acceptance
used private 4078/4079 builds; the final 4080 was not installed on Huawei or
the VM because the phone was absent from ADB during publication. The public API
now marks 1.1.6 and 1.2.0 updates as required on both platforms; direct APK/EXE
downloads answered publicly, and no LiveUpdate or broadcast was created.

The client source and local Core artifact binding are in `main`. A local
build proves compilation only; device and account checks are recorded below
with their exact package versions.

## Earlier 4055 snapshot

This table records the earlier 4055 checks; it is not the current candidate's
acceptance result.

| Check | 4055 result |
| --- | --- |
| Core REALITY with Xray 26.6.27, 26.7.28, 26.9.9 and two production nodes | The `acc892b` Core CLI with `with_utls` returned HTTPS 204 and the owned egress marker through disposable loopback Xray servers on all three exact versions. The local fixture used the verified public API address because host DNS supplied a reserved fake address. Installed Windows 4055 connected to DE; CH and a second production-node Core check remain open. |
| Android update over 1.1.6, VPN permission, CH plus two other nodes on Wi-Fi and Beeline LTE | Fresh x86_64 4055 install on LDPlayer created a trial and received VPN permission; CH and DE failed protected-egress verification. Published x86_64 1.1.6 also failed CH and DE. Updating that same 1.1.6 instance in place to 4055 preserved its trial, but DE still failed `core_egress_probe_unavailable` and the app removed the VPN. LDPlayer update passed; connectivity and physical-network checks remain open. |
| Android “everything except Russia”, Wi-Fi/LTE switch, internet after disconnect | Not run on 4055 |
| Windows clean install and update over 1.1.6, connect/disconnect, connected reboot, uninstall | Exact 4055 installer updated over 4054 on the owned VM; DE connected and disconnected. Clean install, 1.1.6 update, reboot and uninstall remain open. |
| New account, trial, connection; expired account, renewal and provider invoice creation | A trial was created on LDPlayer with 4055; connection failed. Expired-account and payment checks were not run. |
| Hiddify and Happ subscriptions on CH and another node | On Android 9 LDPlayer, Hiddify 4.1.1 imported the live trial subscription but failed before Core startup. Happ 4.4.1 imported CH and DE and reported connected on each, but the owned HTTPS probe timed out through its VPN and passed immediately after disconnect. Third-party egress remains unproved. |

After those checks, publish Android APK and unsigned Windows beta through the
existing `Kiwunaka/pokrov` release-index flow. Public announcement text needs
owner approval. Rollback points the release index back to the retained 1.1.6
release assets. Completion requires the published package and public download
metadata; background observation does not block publication.

## Э1 acceptance, 2026-09-26

The signed Android 4059 APK was installed on the Huawei main profile over 4058.
The existing trial survived. The production subscription fix is deployed from
platform `master`; this entry records the final candidate and relevant earlier
checks without treating an earlier build as proof of 4059.

| Check | Result |
| --- | --- |
| Android 4059, DE and CH, standard «Белые списки» | **PASS** on Wi-Fi and Beeline LTE. The Huawei reported a connected VPN, fresh public pages loaded, and the exact test account's Xray traffic increased on each selected node. Wi-Fi → LTE → Wi-Fi kept DE connected; Wi-Fi → LTE kept CH connected. No unknown-user or REALITY error appeared in the matching node logs. |
| Android 4059, internet after disconnect | **PASS**. The VPN indicator disappeared and a fresh public page loaded over Wi-Fi. |
| Android 4059, Italy | **FAIL** on Wi-Fi. Milan ordinary mode returned `probe_failed` at 22:24 UTC on 2026-09-25, with no increase in the test account's IT Xray traffic. Milan standard «Белые списки» returned `core_egress_probe_unavailable` at 22:36 UTC, then `core_egress_connect_failed` on a later retry. A same-Core diagnostic build reproduced both kinds: Core reported `context deadline exceeded` for `unavailable` and `URL probe connection failed` for `connect_failed`. The first is a network deadline in this reproduction, not the earlier Core-startup error `selected route probe unavailable`. IT Xray showed no unknown-user or REALITY warning in the matching minutes. An earlier synchronized RU-bridge egress capture saw SYN packets toward IT while IT ingress saw none. On 2026-09-26, TCP to IT:443 timed out from mini, RU, and RU-SPB, but passed from DE, PL, and US; all sources resolved the same address. IT allows 443 globally in UFW and has no active Xray fail2ban bans, so the path loss appears upstream of Xray. The app temporarily greyed out Milan variants after a failed live probe, then allowed another choice when that result expired. |
| Android 4058 checks retained | **PASS** for upgrade over published 1.1.6 with the trial preserved, and for a clean install with a new trial. DE and CH connected on Wi-Fi and Beeline LTE in ordinary and white-list modes. «Россия напрямую», full tunnel, network switching, and internet after disconnect were exercised. US ordinary mode also passed on both networks. These checks were not repeated in full on 4059; the 4059 code change only moves the Core egress probe until after Core startup or reload. |
| Third-party clients on Huawei with the current trial subscription | Hiddify 4.1.1: **PASS** on DE and CH «Белые списки», with loaded pages and matching Xray traffic. Happ Android 3.24.1: **PASS for VPN connectivity** after manually refreshing its existing subscription on 2026-09-26. It received Xray JSON profiles including «· БС»; DE and CH «· БС» each reached Android `VPN CONNECTED` and `VALIDATED` over Wi-Fi. The earlier DNS failure was observed with the stale direct-VLESS subscription. A fresh browser page through Happ was not independently checked because the ADB browser launch was rejected by automatic policy. |
| Windows VM | **PARTIAL** for the local 4059 installer built from `7388cbd`. Upgrade from published 1.1.6+29 with its UI running passed: the old EXE, uninstaller, and HKCU entry disappeared, and the new EXE, HKLM entry, and service remained. Clean installation and UI launch passed. An ordinary reboot without VPN kept the service running and the network available. Uninstalling with the UI running removed the EXE, registry entry, and service; Ethernet and TCP to the owned API on port 443 still worked. The VM was left without POKROV. VPN connect/disconnect and reboot with VPN active remain unverified: earlier 4057 and published 1.1.6 both failed connection on this same VM, so further VPN testing stopped under the owner's A/B instruction. |
| Expired-account renewal and payment | **PASS for invoice creation** on 2026-09-26. A separate production test account was created through the trial API, expired in the account and trial grant, and disabled on the panels. Its one-month SBP renewal request returned HTTP 200, an HTTPS checkout URL, and a provider invoice ID with Lava status `new`; the local order is `pending` for 250 RUB. No payment or fulfillment was performed. The other Lava orders in the preceding four days belonged to tests; there was no real-user attempt in that window to establish a real-user success rate. |

## Э1 acceptance, 2026-09-27: 4061

The signed Android APK and unsigned Windows installer were built from `be0f86a`
with the existing Core 1.1.0 binaries. They include `ee80b51` and removal of the
GitHub-key emergency network. Routing rule-set downloads remain unchanged.
The 4060 clean Windows run exposed an invisible welcome when animation tickers
were muted. A regression test reproduced it; `22e9db9` makes that state show
content immediately. The final 4061 clean launch passed without reopening.

| Check | Final 4061 result |
| --- | --- |
| Huawei update | **PASS:** 4059 → 4060 → 4061 without clearing data; trial and routing preferences preserved. |
| Huawei DE/CH | **PASS:** ordinary mode, «Россия напрямую», Wi-Fi. Connected UI and Android VPN state matched increased traffic for the exact test account on both Xray nodes; no unknown-user or REALITY warnings in the matching logs. The existing WARP preference was preserved. A fresh browser request was not checked because automatic tool policy rejected the ADB browser launch. LTE and whitelist-mode checks were not repeated on 4061. |
| Windows update and clean install | **PASS** on POKROV-Win11-Test, VT-x, 4 vCPU, 8 GB, with host builds stopped. Updating the running 1.1.6 UI preserved the trial and removed the old installation. After clearing only test POKROV state, the clean 4061 welcome appeared on its first launch and created a new trial. |
| Windows DE/CH and reboot | **PASS:** ordinary mode, «Россия напрямую», verified TUN/routes/DNS/egress and fresh owned API HTTP 200 on both nodes. DE Core start took 884 ms. Rebooting with CH connected restored ordinary networking before login; the service was running and TUN absent. VPN did not reconnect automatically. A subsequent CH connection passed. |
| Windows uninstall | **PASS** with CH VPN and UI active: EXE, service, processes, uninstall entry and TUN disappeared; Ethernet and the owned API remained available. |

The phone remains on 4061 with VPN off. The VM is left without POKROV.
**Release decision: published by owner approval on 2026-09-27.** The accepted
4061 files were published without rebuilding. Platform metadata recommends
1.2.0 to 1.1.6 clients; no news, LiveUpdate or broadcast was created. Earlier
IT reachability results above were not retested in this scoped DE/CH acceptance.

Publication checks: Android 1.1.6+4029 in a fresh LDPlayer instance showed the
1.2.0 offer; its Update button downloaded all 101,611,855 bytes of the ARM64
APK and opened the Android installer. The downloaded file matched the public
SHA-256, versionName 1.2.0 and versionCode 4061. Installation was not confirmed;
this was an updater check, not VPN acceptance. Windows 1.1.6+29 showed the 1.2.0 offer and unsigned-beta
SmartScreen warning. Its Update button opened the canonical GitHub EXE in Edge;
all 29,357,349 bytes downloaded with the published SHA-256 and file version
1.2.0+4061. Edge retained the file pending its uncommon-download confirmation;
that browser protection was not bypassed. The eight 1.1.6 rollback assets remain
available. The owner cancelled the 48-hour monitoring period and approved
starting Э2 task 1. Any 1.2.0 hotfix must branch from the 4061 build commit
`be0f86a` and needs separate owner approval before publication.
