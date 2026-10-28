# Windows acceptance

Private **1.5.0+4236**, App `0359cf68` including `d6105816`, preserves live QA
ownership during read-only resume. All six packages are retained in
`E:/POKROV-tools/temp/release-1.5.0-4236`: four production-signed, non-debuggable
APKs, the unsigned Windows setup and its single-installer ZIP. Standard builders
passed version, ABI and runtime-binding checks; packaged Android Core/Slipstream
bytes and license match the retained Core **1.2.15 / ABI2**, `1b74a65` SDK,
and the Windows verified bundle includes its CLI/license pair. Core was not rebuilt.
Installed Windows VM acceptance and Android device acceptance of 4236 are pending.

Private **1.5.0+4235** is built from App `43d506a6` (Android) and `1af27810`
(Windows), with Core `1b74a65` / **1.2.15 / ABI2** and its bundled Slipstream CLI.
Four production-signed APKs and the unsigned Windows setup plus single-installer
ZIP passed version, ABI, native-byte, license and packaging checks; Android enables
extraction of executable JNI libraries. The private manifest pair is retained beside
the SDK in `E:/POKROV-tools/artifacts/core-1.2.15-slipstream-private4235`, and all
six packages are in `E:/POKROV-tools/temp/release-1.5.0-4235`. Device extraction,
SmartDNS and Slipstream Auto/TUN acceptance are not established by these builds.
Public 1.4.5, draft 4175 and the selected Core 1.2.14 seeds are unchanged.

Earlier private Android and Windows **1.5.0+4234**, App `34a2533c`, include the Russia Direct
LocalDPI diagnostics and DNSTT naming changes. The four production-signed APKs,
unsigned Windows setup and ZIP containing only its byte-identical `POKROV-Setup.exe`
passed package checks with production trust and ATS=false. Android reuses Core
`8897fd8`; Windows reuses `2b2354f` / 1.2.14 / ABI2. Core was not rebuilt.
Packages are retained in `E:/POKROV-tools/temp/release-1.5.0-4234`.
No 4234 device installation or runtime acceptance was performed; earlier results
below retain their stated scope. Public 1.4.5 and draft 4175 are unchanged.

## Earlier 4233 and 4232 acceptance

Updated 27 October 2026. Public version remains **1.4.5**; the seven-asset
**1.5.0+4175** draft is unchanged. Windows **4232**, App `376cd9c9` /
Core `2b2354f` / 1.2.14, passed the scoped runtime retry case after the App
`aec7268a` WFP-proof permit correction. On healthy 101, one curl to an owned unused
IP with SNI www.youtube.com caused real `connect_timeout_ipv4`; the journal then
showed auto start4/proof4/admit4. Final state was running/DNS/egress=1,
admitted=1/failed=0; PID/TUN/effectiveDigest stayed stable with zero extra Core
starts and six error-free observations. Curl returned HTTP 200/exit 0 in 6.37 s.
This is a scoped end-to-end runtime retry pass, not 1080p video or an independently
measured long-running VPN flow. Cleanup completed: recorded IPv4/IPv6 DNS, routes,
user/WinHTTP proxy and Edge policies matched baseline; App/observer/TUN/winws=0,
QA removed, other cache/events retained. VM state=1/PoweredOff is confirmed. No
WFP helper was started; its unused host temporary folder was removed and the
original helper retained.

Windows **4233**, App `938b0d0b` / Core `2b2354f` / 1.2.14 / ABI2, passed package
checks with production trust and ATS=false. Since 4232, source changes are
clock-rollback copy `b97609f7` and version/seed only; native sources are unchanged.
Runtime acceptance belongs to 4232; 4233 was not installed or functionally retested
on the VM. The unsigned
[setup](E:/POKROV-tools/temp/release-1.5.0-4233/pokrov-windows-x64-1.5.0+4233-setup.exe)
and adjacent ZIP are retained; the ZIP contains only the byte-identical
POKROV-Setup.exe. Intermediate Windows/Android build trees
and the unused TCP-only helper temporary folder were removed; final release
folders and selected Core libraries were retained, older helpers/wrappers unchanged.
Android remains 4229 with the owner; mobile checks/cleanup await its return.

The existing technical diagnostics card now shows LocalDPI runtime observations in
both Russia Direct and Selective on Android and Windows. Previously Russia Direct
could use LocalDPI but hid its counters. The focused regression covers both
supported route modes; this source change is not in the retained private packages
and has no new device acceptance.

## Earlier 4230 and 4229 acceptance

Windows **1.5.0+4230**, App `08f17394` (includes `b0f686fd`) / Core `8897fd8` / 1.2.14.
Its setup and installer-only ZIP passed build and package checks and are in
`E:/POKROV-tools/temp/release-1.5.0-4230`. Installation exited 0 and registry showed
1.5.0+4230. Ordinary UI Connect reached running with DNS/egress=1; Stop reached
config_staged/running=0/failure=none with Protection off/Connect. Reconnect in the
same process reached running/DNS/egress=1 and the second Stop again had no mismatch.
ATS production was false; runtime-bound acceptance was not checked.

The 4229 YouTube time≈0 case was an active cookie-consent dialog; ordinary Reject
all unblocked playback. A brief controlled `--disable-quic` observation played direct 1080p
for 22.06 s, local=22/VPN=0/admitted=1; it is not a full direct acceptance pass.
After removing that flag, ordinary Edge played 1080p for 31.34 s/1885 frames with
10 HTTP 200 responses/24,053,437 bytes, but strategy 101 runtime `early_read`
withdrew admission: local 35→41, VPN 0→9, admitted=0/failed=1.
This is mixed local/VPN fallback playback. Individual CDN 403
responses are not established as the cause. ALT4 is selected on the next Connect
using the in-memory network-failure hint; the active Connect does not iterate ALT4.

Normal Refresh replaced the damaged 18 October cached IS label at 27 October 14:04 UTC;
4230 UI showed «Исландия». Restore changed only routingPreferences/firstRouteScopeMode,
retaining new protection events/cache/notifications. Saved IPv4 DNS settings,
the default route, proxy and Edge policy matched baseline; app/TUN/winws/ownedEdge=0.
Guest QA and the owned host SSH forward/logs/via-US config were removed; the Windows
intermediate build was removed and final setup/ZIP retained. VM state=1/PoweredOff
is confirmed. Android remains 4229 with the owner: mobile YouTube/DNSTT and cleanup
after Wi-Fi-off await its return. The Beeline HTTPS 200/h3 baseline was not a full
whitelist-network check.

## Earlier 4228 acceptance

Private **1.5.0+4228**, App `ee9c7fc0` / Core `698662e`, was installed in the owned VM.
Ordinary UI Selective with only YouTube and LocalDPI Auto admitted
strategy 101 after fresh start/proof. About 124 seconds later, runtime `early_read`
withdrew admission; local/VPN handoffs were 8/1 and video continued over VPN.
Ordinary Retry then selected ALT4/id4 and passed fresh proof/admission. Edge UI
selected 1080p60: the bounded 45-second observation retained 1920×1080 at both ends,
video advanced from 67.740 to 111.400 seconds, readyState=4/error=null. Native before
and after remained running=1, DNS/egress=1, services=1, admitted=1/failed=0 and localTCP=6/
vpnTCP=0. Playback was paused afterward. This accepts that bounded ALT4 direct 1080p
case and switching after failure; it does not establish long-term stability or Android.

The 4228 run exposed a separate UI/profile-identity issue. After the first ordinary
Stop, native state was running=0/config_staged/failure=none while Home showed
`profile_identity_mismatch`. During the successful second ALT4 run, native state
was healthy but Home still showed «Защита требует внимания». Later App source
`56a50d91` uses trusted service Status after bound settlement; `d20b2840` rechecks
the existing owner/proof-fenced reconciliation after an action even when the
healthy snapshot is unchanged. The targeted regression went RED→PASS and guards
remain. Both fixes are outside 4228; the warning's removal on this VM with the new
code has not been tested. The concrete `config_staged` cause remains unproven.

Final normal Stop and app exit completed. Preferences were restored byte for byte;
DNS, default routes and proxy matched baseline. Edge policy was unchanged, the
owned debug browser was closed, and the temporary guest QA folder and host
screenshot were removed with path checks. VirtualBox state1/PoweredOff was confirmed.

Separate Core source `8897fd8` fixes idle `ECONNRESET` on Read before the first
write, with a meaningful RED→PASS regression. The `early_read` guard after a write
remains. That commit is absent from 4228; the concrete VM failure is not proven to
have that cause.

The earlier 4227 [installer](E:/POKROV-tools/temp/release-1.5.0-4227/pokrov-windows-x64-1.5.0+4227-setup.exe)
is unsigned, and the [ZIP](E:/POKROV-tools/temp/release-1.5.0-4227/pokrov-windows-x64-1.5.0+4227.zip)
contains one installer. Windows 4227 was not reinstalled on the VM; the accepted
Windows 4216 results remain in [cutover readiness](cutover-readiness.md).
The 4184 results below are historical. Customer cases 89–90 are paused: do not
contact the customer or send a package until the owner lifts the hold. Public
release requires a separate explicit yes.

The separate clean-Win11 Edge secure-DoH comparison is recorded in
[Smart Access DNS](../architecture/smart-access-dns.md). It does not test POKROV
4185 or change Auto. The earlier Flowseal canary was not executed because the guest
token was UAC filtered; it is separate from the 4228 acceptance above.

## Earlier 4184 acceptance

Private **1.5.0+4184**, built from App `50081a23` with the existing Core `0f159bb` /
1.2.14 and matching Cronet. It replaces incompatible WinHTTP probe options with
a fresh Winsock/Schannel connection, retaining TUN DNS, hostname/certificate
validation, OS-route readback and the two-request proof on one socket.
The standard builder passed runtime binding,
built-runtime equality, required-file and executable-version checks.
The [4184 installer](E:/POKROV-tools/temp/pokrov-windows-x64-1.5.0+4184-setup.exe)
is 28,883,048 bytes and unsigned. The [delivery ZIP](E:/POKROV-tools/temp/POKROV-Windows-1.5.0-4184.zip)
contains the same installer as `POKROV-Setup.exe`. Native checks passed on Win10
19044, including real owned TLS/204/64 KiB with the standard ISRG root temporarily
supplied to the old offline image and then removed. Clean Win11 installation,
ordinary Connect to IS, native DNS/egress and Stop passed; the original DNS,
11 routes and proxy state were restored. Both VMs are off and test staging is
removed. The customer's Win10 19045 connection remains unconfirmed; do not
contact them or send 4184 while the owner's hold remains. No public release.

The preceding **1.5.0+4181** installer, built from App `d78aefc9` with the same
Core and Cronet, completed in the Clean VM, retaining the
existing login. One ordinary connection to the selected Iceland location reached
native running with validated egress and DNS. Stop restored baseline DNS,
11 routes, no active TUN and proxy off; the VM is PoweredOff/Unlocked. This
accepts the focused new-runtime smoke, not every Iceland transport or route.
The installer remains unsigned and private; publication needs the owner's
explicit approval.

## Earlier package checks

The 4175 installer belongs to the retained seven-asset draft.
Setup and app/service startup passed;
unchanged protocol QA was not repeated. Load-aware ordering in App 45281e62
was built in 4176; ordinary US paths through Mini and Lampa passed 204/64 KiB
checks. The 4175 draft is retained.

Redesign **1.5.0+4178** built from App 9a567f88 with the accepted Core 1.2.14
artifacts and production trust defines. The standard builder checked runtime
binding, bundle files and PE metadata, and produced the unsigned x64 installer;
PE version is 1.5.0+4178. The same presentation package is used on Android, with
a centered 480-pixel column. The Windows 4178 main screen and centering were
checked in the VM; this was UI acceptance only. No release assets were published
or replaced.
Windows **1.5.0+4179** corrects the 4178 Cronet dependency: retained public
1.0.3 bytes had an incompatible callback ABI and crashed on Naive dial. The
current DLL is the pinned `cronet-go/lib/windows_amd64` c10c03c318db artifact
(9,529,344 bytes). Core 1.2.14 itself was not rebuilt. Standard packaging and
both release/staged runtime identity checks passed; the installer is unsigned.
The owner’s isolated CH Naive h2 canary with the same Core and matching DLL
passed 64 KiB. That canary does not replace installation/runtime acceptance of
the final 4179 setup. Android APK 4178 is unchanged; no assets were published.

See [cutover-readiness.md](cutover-readiness.md) for the current package status and
[Known Problems](C:/Users/kiwun/Downloads/POKROV_KNOWN_PROBLEMS_2026-10-13.md)
for the release queue.

Manual WARP through CH VLESS was accepted on Windows 4168 with a complete 64 KiB
check and one-minute observation. Other accepted scenarios retain their recorded
scope. The dated 4151 and earlier receipts below are historical; their pending
labels do not reopen accepted later checks or create new device authorization.

On 2026-10-13, private 4151 passed an actual automatic protocol failover in the
owned Clean VM, without an application rebuild. Runtime readback confirmed
sing-tun's two service AppID hard permits at ALE_AUTH_CONNECT_V4/V6, with
CLEAR_ACTION_RIGHT and sublayer weight 65535. These permits explain why the
earlier ordinary firewall block was ineffective; neither permit was changed.
A finite dynamic WFP fault instead blocked physical-interface TCP at
OUTBOUND_TRANSPORT_V4/V6, excluding loopback and preserving UDP. The SDK helper
required a start gate after its separate 55-second process watchdog was armed;
its own monotonic timer closed the dynamic session after 40 seconds. Harness
command-length and PowerShell argument-mode errors were corrected before any
packet fault occurred.

The one actual fault began at guest 00:10:43.168 UTC. Current VLESS REALITY
through a bridge failed with `core_egress_timeout` after 3.370 seconds. At
22.732 seconds, native DNS/egress were healthy again with a changed profile
binding; refreshed Diagnostics confirmed AWG3.1 directly, with that same current
binding, while the TCP filters were still active. No manual Connect occurred.
The helper exited 0 and confirmed both filters and its sublayer absent; its
watchdog was removed. This accepts native automatic protocol recovery; a fresh
browser traffic check and Smart DNS response were not performed.

Normal Stop and Exit restored app/aux/TUN/VPN routes/WinDivert/helper/task to
zero, routes 16, DNS 1/0, DHCP on, proxy off and link up at guest 00:12:28 UTC.
The separately requested Edge self-check launch was again rejected before
execution by automatic review (`blocked by policy`, no further reason).
No alternate launch or private QA admission followed. Guest sessions closed;
SaveState RC0/EOF and Saved/Unlocked with an empty session were confirmed at
host 00:15:04 UTC. Physical bridge, guest clock policy and host Hiddify remain.

Private Windows candidate `1.5.0+4151` also retains an already materialized
UDP reserve beside TCP candidates in the runtime cache, without another HTTP
request. Core and Cronet remain the exact 4148 artifacts. The 28,679,408-byte
installer completed once in the owned Clean VM; PE 4151 and fresh guest clock
offset at most 1.7 ms were verified. One Auto connection on 2026-10-12 showed
current VLESS REALITY through a bridge with healthy native DNS/egress. A bounded
guest-only TCP firewall rule for the service and physical interface was present
for 40.559 seconds, with a separate cleanup watchdog. Native failure and a
protocol change were not observed. Rule/filter readback does not prove packet
blocking; the removed rule's ActiveStore enforcement was not recorded. This is
an inconclusive fault test, not a failed recovery or successful failover.
Both rule and task were removed. Normal Stop/Exit restored app/aux/TUN/VPN
routes/WinDivert to zero, routes 16, DNS 1/0, DHCP on, proxy off and link up.
After a separate read-only prerequisites check, BFE/MpsSvc were running, the
active Public firewall profile enabled, local rules allowed and the physical
interface not excluded. The fault had used the actual service process image;
a later whitespace parsing error was confined to that read-only comparison.
No new connection or firewall change was made during it. Final guest sessions
closed, SaveState RC0/EOF and Saved/Unlocked were confirmed at host time
17:24:32 UTC. Browser and Smart DNS operations remained held after the earlier
automatic-review denial; no alternate launcher was used. Host Hiddify, guest
physical bridge and saved identity/preferences were preserved.

Private Windows candidate `1.5.0+4150` adds the bounded ChatGPT QA path and keeps
an available candidate from the other TCP/UDP family within the three-candidate
recovery limit. It reuses the exact Core and Cronet artifacts from 4148.
4150 was not installed; native recovery was subsequently accepted on 4151.
ChatGPT browser functionality remains pending.

Private Windows candidate `1.5.0+4149` shows only the confirmed active protocol
and direct or bridge path in Diagnostics. It reuses the exact Core `1.2.14` and
Cronet artifacts from 4148. On 2026-10-12 one unpinned Auto connection in the
owned Clean VM reached native running/DNS/egress at 16:43:07 UTC. Current
Diagnostics at 16:46:59 confirmed VLESS REALITY through a bridge and all four
native checks. No terminal failure or primary/reserve error was observed.
The fresh Edge self-check launch was rejected before execution by automatic
approval review; browser verification, fault injection and Smart DNS were not
performed. Normal Stop and tray Exit restored app/aux/TUN/VPN routes/WinDivert
to zero, routes 16, DNS counts 1/0, DHCP on, proxy off and link up. Guest sessions
closed; SaveState ended RC0/EOF and Saved/Unlocked at 16:56:52 UTC. The physical
bridge, guest clock correction and host Hiddify were preserved. 4150 was not
installed in this case.

Private unsigned Windows `1.5.0+4148` from App `919c62c4` / Core `2df0fdd`
(`1.2.14`, existing Cronet) upgraded the owned Clean VM in place on 2026-10-12.
The 28,679,169-byte normal installer exited 0; version 4148, the expected loaded
Core module, reused Cronet and running service were confirmed. Cold UI showed
active access for two days and no public error. Functional testing started only
after backend readiness; no new QA admission was issued. W32Time Auto uses `time.windows.com,0x8`, with
subsequent automatic synchronization confirmed. After SaveState/resume, run
ordinary elevated `w32tm /resync /rediscover` and require NTP residuals below
one second before authentication; the latest three samples were within 2 ms.
Leap 0 and Last Sync Error 0 were confirmed after the peer fix. The
owner-approved test-VM policy is now
`ConsentPromptBehaviorAdmin=0`, with `EnableLUA=1` and
`PromptOnSecureDesktop=1`; normal RunAs administrator access passed without a
prompt. Original DWORD 5 is retained in guest
`Downloads/windows4144-admin-policy.safe.json`. Host time and Hiddify remain.

One ordinary 4148 US AWG 3.1 selection passed native DNS/egress readiness,
TUN and nine routes. Real Edge 204/64 KiB checks passed with increased TUN
traffic; public Cloudflare geography was US. Gemini's editor was focused and
filled with actual keyboard input. Before the one enabled `Send message`
Invoke action, the scoped editor exactly matched the controlled prompt, with
zero matching text nodes outside the editor. Both immediate and delayed reads
afterwards found the same nonempty editor, no new user bubble, no generation
control, no answer or response actions, and no recognized country/request error.
Submission and Gemini functionality remain UNKNOWN, not a network failure.
No resend or browser login followed. The earlier 4147 US VLESS REALITY case
also passed its native/browser/geography checks; Gemini submission was unknown.
On 4147 the complete native candidate-probe fixture passed elevated with exit 0,
including cancellation/network-change detail retention and bound Smart handoff.
Its first launch stopped in the loader (`0xC0000135`); the one corrected run used
only a process-local PATH to the VC runtime DLLs already installed with POKROV.

One 4148 Auto attempt, after clearing manual country/protocol pins in the UI,
selected Frankfurt and passed native DNS/egress plus the owned browser 204/64 KiB
check. Current UI/IPC did not expose the selected protocol or bridge identity;
bridge-first selection remains unverified. Exactly one guest link interruption
held the cable down for five seconds and restored it in `finally` (both commands
exited 0). Guest Up → Down → Up was observed. After link restoration, without
manual Connect or retry, the native snapshot reported running/DNS/egress ready and a newly reloaded owned browser
document passed 204/64 KiB again (RX +115,456 / TX +113,184 bytes). This is a
network-return functional PASS; the during-down native snapshot was unavailable,
and no proof epoch or protocol switch was established. Exact UTC times for the
initial Auto acceptance and first browser check were not recorded.

One ordinary audited 48-hour extension activated the existing account until
2026-10-14 04:58:28 UTC without charge or identity/key reset; UI refresh showed
two days. The first real Auto attempt ended before TUN with `access_preparing`
/ `API-011`: expiry had disabled all six assignments, leaving zero sync targets.
That cause is closed; audited restoration confirmed canonical ACKs and mappings
6/6 with account, keys and expiry preserved. After the backend fix was released,
one Auto connected, with native tunnel/DNS/egress readiness and real browser
HTTPS 204/64 KiB passing. Its UI label was Germany; external DE geography and
the exact automatic route were not observed, and Auto was not repeated.

Four ordinary US catalog pins passed separately: VLESS REALITY, AWG 3.1,
Hysteria 2 and VLESS XHTTP. Each reached native running/DNS/egress readiness,
TUN plus nine routes, then browser 204/200 with the exact 65,536-byte marker
body and increased TUN traffic. The REALITY connection also returned public
Cloudflare `loc=US`; this is observed geolocation, not exact-node attestation.
Every Stop restored TUN 0, routes 16 and DNS counts 1/0. Gemini opened an unsigned
editor, but the test text remained pending after native keyboard entry and an
enabled Send click, with no response or public error; functionality is UNKNOWN.
Country/protocol Auto and WARP variants remain open.

A new Smart DNS case used a fresh public source fetch on Brain after the host's
Hiddify fake-IP was rejected by the normal source guard. Reviewed catalog 25 /
security 2 and private provider policy 26 / security 1 passed signature checks;
the catalog was published once, with public provider and issuer OFF and the
provider pointer NULL. Four source-only checks remained `NOT_VERIFIED`. After
natural access-token expiry, ordinary same-account refresh gave 857 seconds of
parent coverage. One audited, nonrenewable 600-second admission matched the
actual 4144/Core module and expired at 08:30:43 UTC.

QA Start at 08:22:24 UTC failed at 08:22:34 during `core_connect`, candidate
phase `http_64k`: the timeline showed `CONN-005`, the support rule `CONN-008`,
and native status `core_egress_probe_unavailable`. Native rollback left no TUN
or VPN routes. The admission was claimed; no control/proof context or Gemini
request was obtained, and no second Start or renewal was made. This is an early
Core connect failure, distinct from the historical case 781 control POST failure;
the underlying native branch remains unknown.
The subsequent native regression reproduced rejection of the current Dart
producer's paired API rules. The parser now accepts their exact matching
TCP/443 and DNS scope, with negative-boundary checks passing. Version 4148 is
installed; fresh SmartDNS runtime acceptance remains required. The old case is closed.

At 11:55:34 UTC the VM baseline was restored: app, auxiliary processes, TUN,
VPN routes, WinDivert and consent prompts were absent; routes were 16, DNS
counts 1/0, DHCP4/6 enabled and proxy off. Guest sessions were zero; SaveState
reached EOF with exit 0 and Saved/Unlocked with an empty session was confirmed.
The 4147 and 4148 cases made no administrative server writes or QA admissions;
the prior deploy lease was already released. Earlier three Ctrl+W requests were
sent, but individual tab closure was not verified. In the Auto case, closure
targeted the confirmed current owned self-check document; afterwards it was
confirmed no longer current. Other browser tabs were preserved.
The Intel bridge and GetHostTimeDisabled setting remain; the corrected NTP
source and owner-approved admin consent policy are the new guest baseline.
Auto selection, Russia Direct, WARP off, Advanced mode and guest link UP were
confirmed before final exit/save.

Private unsigned Windows `1.5.0+4143` was built once from App `f581aa68` to
preserve the first Smart DNS control rejection across service, runner and Dart.
The build and runner compilation passed; the installer is 28,661,152 bytes and
reuses the exact 4142 Core `1.2.14` / Cronet artifacts. Version, required files,
source/trust pins and runtime binding checks passed. The source regression file
passed 32 tests, analysis passed, and native service runtime/client tests passed.
This diagnostic change does not establish the cause of case 779.

Case 781 ran once on 2026-10-12 with the corrected guest clock (56–57 ms NTP
offset), a fresh parent session (880/879 seconds before admission) and the
independent physical bridge. QA Start at 01:04:19 UTC reached ordinary
Core/TUN/routes/DNS/egress READY, then reported `control_delivery=failed` and
`api_failure_kind=request_socket`. Operation, HTTP status, errno and the
preparation reason were not displayed. Current bound Smart DNS proof was not
obtained; no Gemini query was submitted. The source places this exception at
the QA control POST; the underlying socket cause remains unknown.

The client exited normally at 01:08:28 UTC. Fresh guest baseline at 01:08:59
confirmed no app/auxiliary process, TUN, VPN route or WinDivert, with 16 routes,
DNS counts 1/0, DHCP enabled and proxy off. Guest sessions closed, SaveState
completed with exit 0 and Saved/Unlocked was confirmed. Bridge, guest time
correction, identity, preferences and browser were preserved; host Hiddify and
host time were unchanged. Case 781 is closed without replay or renewal;
real Gemini functionality remains unverified.

On 2026-10-12 private unsigned Windows `1.5.0+4142` was built from App
`89674dcd` with Core `1.2.14` (`7db9519`) and the unchanged pinned Cronet.
The single DLL and installer builds completed successfully; the 48 required
Core exports, ABI 2, package versions/files, Core/Cronet binding and compiled
native/Dart trust pins passed. The Core suite had one zero-millisecond
`lightReserve` timing assertion failure; the test now accepts a valid zero-ms
result and its focused run passed. Windows `service_runtime` passed;
`candidate_probe` stopped because the host token could not read the privileged
boot clock. Public version remains `1.4.5`.

The owned bridged Clean VM installed 4142 successfully. Case 779 used a fresh
session (809/808 seconds remaining before admission) and corrected guest time
(NTP offset 57–58 ms), without changing host Hiddify or the host clock. One QA
Start at 00:16:57 UTC reached profile/Core/TUN/routes/DNS/egress READY, then
reported `control_delivery=failed`, `control_reason=unclassified`. Current
Smart DNS proof and a real Gemini answer were not obtained; no browser query
or second Start was made. The client exited normally; OS baseline at 00:23:13
had no app/auxiliary process, TUN, VPN route or WinDivert, with 16 routes,
DNS counts 1/0, DHCP enabled and proxy off. Guest sessions closed and
SaveState completed with exit 0; Saved/Unlocked was confirmed. The physical
bridge, clock correction, identity, preferences and browser were preserved.
This case is closed; the underlying control failure is still unknown.

On 2026-10-08 the owned Clean VM upgraded from 4105 to private unsigned
1.5.0+4107 (App code `d09f555c`, unchanged Core `dbc73e1` / 1.2.9).
Direct UAC/terminal installer success, actual AOT/Core/Cronet, stable
Auto/LocalSystem service and preserved identity/owner passed. One Auto reached
protected Home and normal Diagnostics confirmed tunnel/routes/DNS/egress.
The NIC was off for 10.084 seconds: the loss frame needed attention, then Home
returned to Connected/Germany 10.08 seconds after cable-on. Fresh native proof
within 60 seconds and the exact source-fix branch were not observed; the earlier
4105 blocked-traffic cause remains unknown. Normal Stop cleared TUN/routes/DNS,
with service/PID stable; original preferences, cable-on and closed sessions were
confirmed. BFE remains unknown; its rejected reader was not repeated. Unchanged
4103 reboot/uninstall acceptance is carried. This does not accept a fresh user,
the full 1.5.0 release or public signing.
Public version remains `1.4.5`. Historical `1.2.0+4061` was an unsigned Windows beta with Core 1.1.0.
Version 1.1.6 remains available for rollback. The earlier 4055 installed-VM checks remain historical. On
the same VM, 4053 connected to DE while 4054 timed out; replacing only Core
with the fixed DLL restored the connection. The exact 4055 installer was then
installed over 4054 on that VM: its bundled Core DLL matched the staged artifact, DE connected,
and disconnect returned the UI to the disconnected state. This verifies that
historical update path and connect/disconnect only. Current acceptance is recorded below.

When upgrading a legacy 1.1.6 per-user installation, the administrator
installer closes the running old POKROV UI and waits for its process to exit
before invoking its uninstaller.
It waits for the old uninstaller's second phase to remove the uninstall entry
and binary before keeping the new service installation. The old uninstaller
can return success before that second phase finishes; a running UI can also
hold its EXE and leave a broken partial upgrade.

Legacy cleanup finishes before the final service setup. The installer snapshots
the previous owner first, then checks service existence again after cleanup and
applies the saved owner and ACLs before creating/configuring and starting the
service. It waits up to 30 seconds for `POKROVService` to reach `Running` and
fails the installation if that state is not confirmed. Installed QA separately
checks the public service status and owner identity.

Before installing files, Setup uses the existing scoped `Stop-Service` pattern,
waits up to 30 seconds for `Stopped`, and confirms that state with `Refresh`.
An absent or already stopped service is valid; failure stops preparation before
file installation. The log retains the stop request, launch result and exit code.
This change does not establish the cause of an earlier abrupt Setup exit.

An upgrade preserves a valid `InstallOwnerSid` already recorded in
`HKLM64\Software\space.pokrov\POKROV\Service`, including when another
administrator launches the installer. The installer queries the original
launcher SID only when no valid installation owner is recorded. This keeps the
existing user's service access across upgrades.

On the owned Windows VM, install from a clean state and update over 1.1.6.
Connect and disconnect; reboot while VPN is connected and check that network
access returns. Finally uninstall and check network access again. Record any
failed step against the exact installer and installed Core DLL.

The VM is accessed through VirtualBox guest control and saved guest access.
On 2026-10-14, the Clean VM logon screen confirmed that its Windows password
had expired. The normal password-change flow using the previous password
succeeded; no security-policy change was needed. Current access uses
`E:/POKROV-tools/vm/control/Invoke-VBoxGuestOperation.ps1` with exact VM UUID
`d09be66e-b063-4f86-aa8b-123c0e1e73ce` and the separate DPAPI credential at
`E:/POKROV-tools/vm/secrets/pokrov-win11-clean-4100.dpapi`. The old Test credential
is retained; wrappers hardcoded to `POKROV-Win11-Test` must not target Clean.
Guest access and UUID matching passed without exposing the credential. PNG
capture returned `E_FAIL`; `IDisplay.TakeScreenShotToArray` with RGBA through
`win32com` and PIL captured the guest screen without controlling the host UI.

Unsigned output may show SmartScreen; that is part of the beta handoff, not a
claim of trusted signing. A local debug build does not prove installed-VM
behavior.

## 4061 acceptance, 2026-09-27

The final `be0f86a` installer passed on the owned VT-x VM (4 vCPU, 8 GB),
with host builds stopped: update over running 1.1.6 with the trial preserved;
true clean installation, visible welcome on its first launch and a new trial;
DE and CH in ordinary mode with «Россия напрямую»; reboot with CH active;
and uninstall with VPN and UI active. Both nodes passed Core egress checks
and fresh owned API HTTP 200 requests. Reboot restored ordinary networking
before login; VPN does not automatically reconnect. Manual reconnection passed.
Uninstall removed the EXE, service, processes, registration and TUN while
network access remained available. The VM was left without POKROV.

The first 4060 clean launch had an invisible welcome until reopening. A focused
regression test reproduced muted animation tickers leaving opacity at zero;
`22e9db9` fixed that path, and the first clean 4061 launch confirmed the fix.
The owner approved publication on 2026-09-27. The same installer is available
in `Kiwunaka/pokrov` release `v1.2.0`, with the SmartScreen warning.
