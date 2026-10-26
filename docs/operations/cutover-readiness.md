# Client release status

Updated 26 October 2026. The owner's [Known Problems](C:/Users/kiwun/Downloads/POKROV_KNOWN_PROBLEMS_2026-10-13.md)
is the only current release queue; [Execution section 0](C:/Users/kiwun/Downloads/POKROV_EXECUTION_PLAN_2026-09-24.md)
explains how to continue. Dated results below retain their original scope and do
not create new tasks or permission to repeat accepted checks.

Public metadata remains **1.4.5 / schema 0 / min-supported 1.3.0**.
**1.5.0+4175 is a draft with seven assets**, not a public release. The final
16 October packages contain production-signed universal, arm64-v8a,
armeabi-v7a and x86_64 APKs plus the unsigned Windows setup, release-index and
SHA256SUMS. They were built from App 9fc28bc4 / Core 40356d4; the full Core AAR
contains four native ABIs. Final ARM64 installed with data preserved; Windows
setup exited 0 and app/service/Core 1.2.14 started in the Clean VM. The seven
assets were checked against the draft; unchanged protocol QA was not repeated.
Strict-v2 is not required by the current release plan.

Private **Android ARM64 and Windows 1.5.0+4212**, App `570af7ff` / Core
`58b11d4`, are built. Android's 86,145,493-byte APK passed production signing,
version/ABI/runtime binding; it is not installed because the owner has the phone,
which remains on accepted 4211. Windows setup is 29,248,619 bytes; its 28,750,929-byte
ZIP has one `POKROV-Setup.exe`. Packaging passed and CleanWin11 installation exited 0.
The Locations and Android parser fixes are included but not physically accepted
on Android. **4212 is not a final candidate** because of the Windows findings below.
The preceding 4209 four-ABI Android set and Windows bundle retain their accepted scope.

On Windows4212, ordinary IS Auto Connect with Selective YouTube/LocalDPI reached
native running with DNS/egress flags valid. Real Edge playback advanced 93.357674 s
at 480p: 2,809 frames, 58 dropped, readyState4, no video error; 31 CDN requests used
HTTP/1.1. Local TCP21/VPN TCP0, admitted1/failed0. This accepts the video/TCP case,
not permanent absence of ads, IPv6 or the general VPN-proof boundary.
At 04:32 UTC the periodic native three-second probe returned `core_egress_timeout`
and triggered RF2 recovery. After fresh healthy native state the UI still retained
failure/Retry semantics while visually showing Disconnect. Source review also
found the static `pokrov.space` reserve outside protected routing in Selective.
Both corrections are in progress; probe timeouts have not been changed.
Ordinary tray Disconnect reached initialized/running0/guard0, then Exit left app0/
winws0. Russia Direct, DPI off, empty service selection and IS were restored;
DNS/routes/proxy exactly matched baseline, owned Edge/TUN were absent and VM
PoweredOff was confirmed. No fresh server-health or fleet result is implied.

Android **4210**, App `08222a80` / Core `58b11d4`, passed ordinary UI/TUN
Naive CH: exact 64 KiB in 1,019 ms, Connect 10,257 ms, then normal Stop with
VPN service/network absent. Platform `690658b` fixed the Naive telemetry 422;
the original queued report was delivered without another Connect. On **4211**,
the new Lampa direct address `37.18.102.90` to PL (`lampa`, bridge 8) passed
64 KiB in 818 ms, Connect 9,910 ms and clean Stop. The old address is detached
but retained for rollback; Floating/RF2 is unchanged and no owner DNS edit is needed.
Manual connection choices now exist; the earlier absence of a selector is closed.

On the phone, refreshed existing subscriptions in Hiddify 4.1.1 and Happ 4.4.1
showed the new bridge/Iceland labels. Germany Auto produced real Gemini answers
`2+2 → 4` and `2+3 → 5`, respectively. Settings were preserved and both VPNs
were stopped. Hiddify rewrites routing itself; POKROV-app SmartDNS rules are not
promised there. Happ's POKROV Russia Direct routing/geofiles import was accepted.
These external-client results do not accept Android app SmartDNS or YouTube.

The returned physical Android phone exposed a false `profile_identity_mismatch`
after account refresh withdrew reusable staging while the active profile remained
running. `03fe046d` fixes that exact state without relaxing Start/Apply identity;
the existing regression failed before the fix and passed in both Android flavors.
`39bfe6bf` tries authorized cached material before waiting for the API on a physical
network change. `5555a6ad` preserves an independent known bridge in that cache;
Mini/its XHTTP alias cannot consume both ingress choices. Related existing tests
and app-shell analyze passed; access/expiry binding and probe budgets are unchanged.

On 4209, ordinary Iceland Connect on funded Beeline LTE selected RF2 and completed
the full 64 KiB probe. Live LTE→Wi-Fi→LTE recovered automatically, with fresh
`http_64k` success receipts for both new networks and no profile-identity failure.
The measured Wi-Fi→LTE case completed in about six seconds. Ordinary UI Stop
returned to idle and removed both the Android VPN service and OS VPN network.
The final packaged ARM64 APK was installed with data preserved. Auto country,
Russia Direct, WARP off, the prior advanced view, Wi-Fi/mobile data enabled and
the original system DNS/always-on settings were restored; VPN remains stopped.
Earlier LTE failures with zero SIM balance are not VPN defects. Direct Iceland
HTTPS still timed out on funded LTE; bridge success does not accept IS direct
VLESS/HY2/AWG. Android Naive was subsequently accepted on 4210 as described above;
Android SmartDNS and LocalDPI/YouTube remain separate and unaccepted.
No accepted Windows transport/VM checks were repeated for this shared cache change.
Public release, customer contact and paused automations remain unchanged.

Previously accepted private Windows **1.5.0+4206**, App `addf1bc5`, used the unchanged
Core `b3a021b` / 1.2.14 selected through the retained core-windows-4205 manifest.
It includes the synthesized Auto stream-continuity fix and Stop-only cleanup
of the previous profile intent. Android at that point was **4206**, App
`175eeb1c` (the same code plus documentation), using the accepted Core
`d80a992` / 1.2.14 AAR. Universal, arm64-v8a, armeabi-v7a and x86_64 APKs passed
production signing, package/version, ABI, non-debuggable and runtime-binding
checks. Core was not rebuilt; phone acceptance had not yet resumed at that date.
The Windows build and runtime binding passed. Setup is 29,239,658 bytes;
the delivery ZIP is 28,742,133 bytes with one `POKROV-Setup.exe`.
CleanWin11 installation exited 0. Ordinary IS Connect reached running with
DNS/egress valid. The first ordinary Stop kept a reusable staged profile and
returned to the idle UI without an error. To exercise the changed branch,
one normal minimize/resume caused an authenticated foreground refresh: native
remained running with its staged digest cleared. The following ordinary UI Stop
returned `initialized / failure=none / protection_retained=0`, both digests empty,
TUN 0, idle button visible and no CONN-005/failure warning. The Stop event had
`outcome=cancelled`, with no error. Exact DNS/routes/proxy baseline and preferences
were restored; the temporary guest folder and generated host build/staging
outputs were removed, final setup/ZIP retained, and the VM powered off.
This accepts both the reusable-profile and clean-idle Stop paths. Existing
Twitch/Naive/Flowseal/Gemini tests were not repeated. No public release or
customer contact; SlipNet still awaits NS and its separate Auto/TUN acceptance.

Previous private Windows **1.5.0+4205**, App `831a400d` including `5dd958c2`,
with Core `b3a021b` / 1.2.14. Android packages remain **4204**; the changed Core
and guard code is Windows-only. Core's strict-route permit now includes the
process user, and the guard accepts only its exact service/LocalSystem identity.
Broad or foreign higher-priority permits remain rejected; priorities and ABI
are unchanged. The focused Core identity and native guard tests passed.
The Windows builder verified runtime binding and 48 ABI exports; setup is
29,238,288 bytes, with a 28,740,762-byte ZIP containing `POKROV-Setup.exe`.
On CleanWin11 the installer exited 0. Ordinary PL Connect followed by changing
Full Tunnel to Russia Direct through Rules/Apply returned to `running`, with
DNS and egress verified, guard 0 and TUN 1. Ordinary Stop reached `initialized`;
guard/TUN/app/owned browsers were 0, preferences and exact DNS/routes/proxy
baseline restored, and the temporary QA directory removed. This accepts the
changed running-profile transition, not a repeat of Gemini/Naive/Flowseal QA.
CleanWin11 is powered off.
Public 1.4.5 and draft 4175 remain unchanged; no customer contact.

Included in 4206, `58140491` preserves working streams when
the synthesized fallback `urltest` changes its probe winner. The manual selector
still interrupts on explicit selection. The existing focused bootstrap test and
app_shell analyze passed. Both private platform packages now contain this fix.

The 24 October Twitch check on 4205 reached the owned IS exit and played video,
but ordinary Stop showed CONN-005 in the UI even though native was
`initialized / failure=none / protection_retained=0` and the exact network
baseline returned. A matching source defect was found: an explicit clean Stop
could be compared to the previous profile intent after its digests were cleared.
The Stop-only intent cleanup preserves strict Start/Apply and retained/staged
profile checks. The existing service-client native test reproduced the defect
and passed after the fix; the full Windows runner is now built in 4206.
Its relation to the VM symptom is probable; that run did not
capture the UI failure kind. The matching clean-idle branch passed on 4206 as
described above; it does not reopen accepted transport checks.

The earlier **Android and Windows 1.5.0+4204** packages came from App
`7ac73cf3` with Core `d80a992` / 1.2.14. All four Android APKs passed production
signing, non-debuggable, package/version and ABI checks; device/native acceptance
on Android has not run. The Windows installer remains `NotSigned` (29,248,874 bytes);
its 28,751,166-byte delivery ZIP contains the single `POKROV-Setup.exe`.
Windows packaging and the Core's 48 desktop ABI exports passed. The actual DLL
reports `dnstt_vless_v1` and `singbox_naive_h2_v1`; Android reuses the same accepted
four-ABI Core AAR. Windows **4204** installed in CleanWin11 with exit 0 and passed
the scoped ordinary UI/TUN Naive run below. The earlier 4203 selection change
tries Naive within its existing direct-route group; 4204 retains a real Naive
reserve in the saved cache. Targeted regressions passed. Country, bridge-load
ordering and budgets remain in force.
The DNS tunnel remains gated on recursive DNS and Auto/TUN acceptance.
The accepted 4200 Flowseal and 4195 Gemini checks below were not repeated.

| Private artifact | Path |
| --- | --- |
| Android arm64-v8a, built 4212; device check pending | [APK](E:/POKROV-tools/temp/pokrov-1.5.0-4212-android-arm64-v8a.apk) |
| Android arm64-v8a, accepted 4211 | [APK](E:/POKROV-tools/temp/pokrov-1.5.0-4211-android-arm64-v8a.apk) |
| Android universal, preceding 4209 | [APK](E:/POKROV-tools/temp/pokrov-1.5.0-4209-android-universal.apk) |
| Android arm64-v8a, preceding 4209 | [APK](E:/POKROV-tools/temp/pokrov-1.5.0-4209-android-arm64-v8a.apk) |
| Android armeabi-v7a, preceding 4209 | [APK](E:/POKROV-tools/temp/pokrov-1.5.0-4209-android-armeabi-v7a.apk) |
| Android x86_64, preceding 4209 | [APK](E:/POKROV-tools/temp/pokrov-1.5.0-4209-android-x86_64.apk) |
| Windows x64 installer, 4212; open findings above | [Setup](E:/POKROV-tools/temp/pokrov-windows-x64-1.5.0+4212-setup.exe) |
| Windows delivery ZIP, 4212 | [ZIP](E:/POKROV-tools/temp/pokrov-windows-x64-1.5.0+4212-setup.zip) |

Managed Naive H2 is live on CH at `ch.pokrov.space:443`, with Platform `f019efe`
and Node `3e23441`. Eligibility covers all active Premium, including trial and
manual access; the earlier 02:54 UTC pass acknowledged CH's exact 34-identity
set. That identity check was not repeated in the latest API-only deployment. A normal
device-bound VM API request separately selected `ch:naive_h2` and returned an
authenticated, certificate-verified TLS leaf. On **Windows 4202**, the existing
native Service candidate path (commands 28→29→28), using a QA profile produced
by the actual server helper, passed TLS, owned 204 and the full 64 KiB in
1,189 ms, with the runtime context unchanged. This is transport proof, **not a
full UI/Auto/TUN connection**. The first unavailable result happened before App
initialization and was not a network defect. The subsequent six-node ACK/API
health gate passed at 02:54:19 UTC; the server lease was FREE and temporary
timers inactive. This remains the earlier full-fleet result.

Platform `f019efe` fixes inherited UDP content DNS for the TCP-only Naive path:
content queries use `tcp://8.8.8.8` through the selected tunnel, while explicit
direct UDP `8.8.8.8` and local bootstrap are preserved. Only `node_naive.py` was
deployed with an API restart; the backup is
`/root/portal_bot.deploy-backups/20261023T044724Z-51996`. The fresh **Brain-only**
health gate passed at 04:47:50 UTC and the lease was FREE; this was not another
six-node gate.

On **4204**, normal UI Refresh for CH saved a genuine Naive candidate containing
TUN and the corrected DNS. For this QA only, with App stopped, the DPAPI cache's
downloaded/candidate entries were restricted to that existing `ch:naive_h2`
entry and the old proven entry removed. Binding, config, catalog, expiry and
inventory were unchanged. An App.exe-only TCP/443 rule made the API unavailable,
with a 180-second SYSTEM cleanup watchdog; Service traffic stayed unblocked.
Ordinary **«Включить защиту»** reached running, failure none,
`core_egress_validated=1`, `dns_ready=1`, guard 0 and TUN 1. App itself created
proven material `ch:naive_h2` / `naive,h2,tls`; the profile contained only
Naive/selector/direct/block outbounds. UI showed **«Выключить защиту»** and
**«Состояние защиты: Швейцария»**. This accepts the real UI/TUN connection through
one existing cached Naive path with API unavailable. It does not establish an
all-route Auto run or exhaustion of blackholed alternatives.

Earlier, the corrected 4189 installer completed in the Clean Windows VM with exit 0 while
the unchanged WinDivert driver remained loaded: no driver stop or reboot was
needed. The earlier package failed on that locked driver. The fix is limited to
WinDivert packaging, using `replacesameversion` and `restartreplace` instead of
forcing an identical loaded driver to be overwritten; it does not establish DPI
functionality or acceptance of a changed driver.

Windows 4195 returned real Gemini answers about Paris through WLrus
`191.217.212.16` and DNS-AI `103.137.248.145` in ordinary default Edge: secure
HTTP/2, gateway available and phase running after both requests, without VPN.
Direct gstatic dependencies loaded over IPv4. GeoHide EU returned unusual
traffic; GeoHide RU used VPN with empty inventory, exact cause unestablished.
Live provider policy **2/security 1** now admits only WLrus and DNS-AI for
Windows Gemini; catalog **28/security 2** is unchanged. Existing-key publication
and exact readback passed; admission open, operation lease FREE and API health at
09:07:39 UTC are the last observed server state, not a new check in the 4200 pass.
Server `8018d52` enforces immutable provider kind. The accepted 4195 Gemini
requests were not repeated.
Eligibility includes all active Premium (trial, gifts, promotions, bonuses,
manual and family), excluding Free and expired/blocked. App `38adc208` closes
the legacy custom SmartDNS/direct bypass. A sticky QA guard denial is separate
from gateway availability; no guard was weakened for this acceptance.

Windows 4200 tries strategy 101 (`multidisorder`, `split-pos=1,midsld`) first,
then ALT4, at most twice and only for transport proof failure. Normal Stop keeps
the successful network hint; an observed runtime failure clears it. Standalone
verification of the previously failing CDN IP/SNI returned verified TLS in
411 ms and HTTP 404 for `/`. Ordinary App Connect then reached running with
DNS/egress valid and guard 0. In ordinary default Edge, after rejecting optional
cookies, YouTube reached **84.0167 seconds / 2,537 frames / 480p**, readyState 4,
error 0 and playing. Local TCP handoffs were 21, VPN TCP handoffs 0, admitted 1
/ failed 0. HTTP/3/UDP also used the ordinary VPN and is not counted by those
TCP counters: this establishes working playback with local TCP DPI, not that
the entire video bypassed VPN. The initial playback had an unexplained player
error at about 21 seconds; later pauses were the cookie dialog. Global QUIC,
DNS and the owner's host network were unchanged.

Earlier Windows 4199 contained bounded Flowseal selection (ALT4, then 681; at most two
attempts, only TCP/TLS/HTTP proof failures retry), WFP semantic-priority fix
`499dd3e6` and protected VPN egress verification before WinDivert (`c3ba46d0`).
Core confines local DPI to IPv4 while retaining the original protected IPv6 VPN
rule, ignores unused speculative-socket EOF, and exposes the first closed
failure reason through the existing observation/journal.

Ordinary Connect on 4198 and 4199 reached running with DNS/egress validated and
`protection_retained=0`. Real YouTube playback reached about 13 seconds/400 frames.
However, 4199 subsequently reported `early_read`: 16 local handoffs, 7 VPN
handoffs, admitted 0 / failed 1. That pass confirmed playback with VPN fallback;
it did not establish video carried entirely by local DPI.
Edge recorded SSL_CONNECT -100 (connection closed) to
`rr3---sn-vcpu-axql.googlevideo.com` / `85.114.28.78` at 14:40:07.179; native first
`early_read` followed 82 ms later. A standalone control on that same pinned CDN
IP/SNI and physical source, with a 10-second limit, established TCP but timed out
in TLS with plain, ALT4 and 681; the plain-process exit code was not captured.
This bounds the remaining failure to TLS on that path/endpoint, reproduced
outside POKROV. It does not identify an ISP, DPI or a specific middlebox.
The earlier interpretation of curl `time_connect=0` as TCP failure was wrong;
TCP works, and ALT4's separate `www.youtube.com` control returned verified HTTP 200.
No random strategy flags were added.

Provider fees remain pending. WhiteDNS and SlipNet are separately authorized
for all active Premium. On 23 October the CH UDP/53 endpoint and Premium-only
VLESS loopback backend became live. A real Core direct-authoritative probe passed
TLS, owned 204 and 64 KiB in 696 ms; an invalid personal UUID was denied.
The DNSTT rollout from Platform `cfcd3fb` remains in the current platform.
Timeweb requires two distinct NS addresses, so PL's
existing server sing-box forwards UDP53 to the same CH DNSTT backend without
DNS parsing/cache or a second Noise key. TLS/204/64 KiB through PL passed in
1249 ms, with its existing Node/Xray/HY2 processes unchanged. The owner saved
NS `atlas.portal-privacy.online` and `birch.portal-privacy.online` for `t`;
the last authoritative Timeweb ns1/ns3 reads at 04:53 UTC still returned the parent SOA,
without the delegation.
The catalog entry remains disabled pending recursive WLrus acceptance and
the new App Auto/TUN VM pass. Source checks
cover Premium/trial/manual, Free/expiry/revoke rejection, capability admission,
exact VLESS→DNSTT graph and cached fallback. Auto retains one authorized DNS
reserve, with a separate 30-second attempt after ordinary candidates and before
WARP. No recursive DNS or whitelist-bypass acceptance is claimed yet; individual
device revoke is not added. The last six-node ACK/health result remains the
earlier 02:54 UTC Naive gate; the 04:47:50 UTC check covered Brain only.
WhiteDNS remains research.
See [Smart Access DNS](../architecture/smart-access-dns.md) and platform
[whitelist research](../../../VPN/docs/competitive/censorship-stack-research-2026-07-22/whitelist-bypass-2026-10-21.md).
Root confirmed network/process cleanup after 4200: ordinary Stop left running/guard/TUN/winws 0;
allExceptRu/IS, Automatic SmartDNS, local DPI off and empty service selection
were restored. DNS/routes/proxy exactly match the baseline; owned Edge/app/winws
and TUN are absent. Display `1372×943` was restored and read back; 12 owned guest
QA items and the temporary host build were removed. Root confirmed CleanWin11
PoweredOff and its separate window closed. The host network, Hiddify and clocks were untouched. The 4200
setup/ZIP and selected Core manifest/DLL remain the earlier accepted artifacts.
The later **4204** ordinary UI Stop reached `config_staged`, guard 0 and TUN 0.
Root removed the exact temporary rule/task, restored only the cache key and
original preferences, preserving the remaining secure store and session tokens.
DNS/routes/proxy matched the baseline; display 1372×943 was restored, app/winws/
TUN were absent and the owned QA directory was removed. Root confirmed the VM
PoweredOff. Paused customer work and automations were not resumed.
Existing budgets, country and bridge-load groups remain in force.
Remaining work follows the owner's current queue: final Android packaging and
targeted acceptance, DNSTT after Timeweb publishes the delegation, and unresolved
IS direct/UDP and Android SmartDNS/YouTube. The customer Windows case remains
paused. Lampa's new direct path and Android Naive are accepted above. Public
1.4.5/draft 4175 and paused automations are unchanged; publication requires the owner's yes.

## Earlier private packages and accepted checks

Load-aware bridge ordering is in pushed App 45281e62. Windows **1.5.0+4176**
was built and ordinary US paths through Mini and Lampa passed 204/64 KiB checks.
The seven-asset 4175 draft remains intact.

The earlier private **1.5.0+4181** pass separates source, packages and live state:

| Layer | Result recorded for 4181 |
| --- | --- |
| Pushed source | App `d78aefc9` sets 4181 and includes `9ea67187` Windows packaging fixes plus the earlier UI/accessibility changes. Core `0f159bb` publishes immutable URLTest history snapshots and retains the Android inbound-authentication fix. |
| Android package | [4181 universal APK](E:/POKROV-tools/temp/pokrov-1.5.0-4181-android-universal.apk), 244,695,973 bytes, built from App `d78aefc9`; the standard builder passed production signature, version and ABI checks. Packaged armeabi-v7a/arm64-v8a/x86_64 libraries match the selected Core 1.2.14 / `0f159bb` AAR byte for byte. 4181 was installed over 4178 with the test account preserved; 14 real screens were captured on api35gc for the help Atlas. Simple/Advanced navigation, profile, renewal, support, diagnostics, code entry, theme and notifications were opened. No VPN or checkout was started; phone acceptance is not claimed. The emulator is off again. |
| Windows package | [4181 setup](E:/POKROV-tools/temp/pokrov-windows-x64-1.5.0+4181-setup.exe), 28,875,484 bytes, built from App `d78aefc9` with the ready Core 1.2.14 / `0f159bb` DLL and matching Cronet. Runtime binding, built-runtime equality and executable-version checks passed before installer packaging. The normal installer completed in the Clean VM and retained the existing login. Core 1.2.14 initialized; one ordinary UI connection to the selected Iceland location reached running with native egress and DNS validated. Ordinary Stop restored the baseline DNS/routes (11 routes), no active TUN and proxy off; staging was removed and the VM is PoweredOff/Unlocked. This was a focused new-runtime smoke, not a repeat of the transport matrix. |
| Live and public | Platform payment/admin/support fixes and bridge-sync revocation are deployed. Cinema/Lampa retained their configs and Xray processes; all five bridge entries report fresh sync and both physical channels report metrics. The routing-domain editor is live; since 20 October, activity covers Xray/AWG/HY2 on all six exits with each source's start date and freshness shown. Historical native traffic is not reconstructed. Public 1.4.5 and the seven-asset 4175 draft remain unchanged. Server deployment does not establish 4181 device acceptance. |

Earlier private Windows **1.5.0+4184** from App `50081a23` fixes the startup HTTP probe's
WinHTTP incompatibility on Windows 10. Re-reading the existing customer events
after Platform `41173c6` restored nullable diagnostics showed accepted TUN DNS,
then `http_setup / winhttp / 12009` before any HTTP request. The saved customer OS
is Windows 10 build 19045; the VM runs Windows 11. Both use `allexceptru` and the
same assignment revision. Full customer route/DNS tables were not uploaded.
The Win10 19044 lab reproduced 12009 for the two formerly required options.
The replacement uses a fresh Winsock/Schannel connection, original TLS hostname
validation, OS routing with TUN-address readback, and the same socket for 204 and
64 KiB. Debug egress and runtime checks passed, including the egress fixture on
Win10. The new TLS implementation also passed real owned HTTPS 204/64 KiB there;
that old offline image lacked ISRG Root X1, so the standard public root was
temporarily imported for the check and removed afterwards. No certificate check
was bypassed. Win10 returned to PoweredOff with its original disabled NICs.

The [4184 setup](E:/POKROV-tools/temp/pokrov-windows-x64-1.5.0+4184-setup.exe)
is 28,883,048 bytes and remains unsigned; the [single-installer ZIP](E:/POKROV-tools/temp/POKROV-Windows-1.5.0-4184.zip)
contains identical bytes under `POKROV-Setup.exe`. The builder reused the already
synced Core `0f159bb` without `-SyncRuntime` and verified its artifact binding.
The server-only Core checkout was not reset to an older revision. Clean Win11 upgraded
normally, retained the test login/owner and connected to IS with native DNS and
egress validated; the server recorded success. Stop restored the captured DNS,
11 routes and proxy state, with no active TUN/guard. Test staging was removed and
the VM returned to PoweredOff.
The customer remains on hold: 4184 was not sent, their successful connection is
not yet confirmed, and public 1.4.5/draft 4175 remain unchanged. At that point,
Android's latest built package was 4182; this Windows fix required no Android rebuild.

Earlier private Windows **1.5.0+4183** from App `bb21d730` preserves the closed native
egress observation in failed Connect acknowledgements through cleanup and into
terminal reports. The standard builder passed runtime binding, required-file,
built-runtime equality and PE version checks with the existing Core `0f159bb`.
The [unsigned setup](E:/POKROV-tools/temp/pokrov-windows-x64-1.5.0+4183-setup.exe)
is 28,882,025 bytes; the [delivery ZIP](E:/POKROV-tools/temp/POKROV-Windows-1.5.0-4183.zip)
contains the identical `POKROV-Setup.exe`. On 20 October the Clean Windows VM
upgraded from 4181 through the normal installer (exit 0, install owner preserved,
current automatic LocalSystem service). Ordinary UI Connect to the selected
Iceland location reached running with native DNS and egress verified.
Stop restored the captured DNS, IPv4 routes (11) and proxy state; TUN, retained
guard, temporary firewall rules and auxiliary processes were absent. Staging
was removed and the VM returned to PoweredOff. A temporary service-scoped
block of the owned probe address did not force a failure and is not a negative
ACK acceptance result; the negative path is covered by the focused Dart/native
regressions. The customer's failure was not reproduced. No 4183 delivery to the
customer or public release occurred; Android's latest package at that point was 4182.

The owner's requested elevation/Radmin reproduction on 20 October also passed
in the Clean VM on 4183. A fresh elevated UI under the installation owner's
account connected to Iceland without replacing the LocalSystem service.
Then official, signature-verified Radmin VPN 2.1.4951.1 was installed in the
VM and brought Online. With its service and adapter active, ordinary POKROV
connected to Iceland and Germany; the latter was confirmed as DE2 in server
telemetry. Native DNS and egress validated in both cases. No Radmin peer network
was joined. Its default route had combined metric 9257 versus 25 for the physical
adapter, so a preferred Radmin route was not reproduced. These results do not
establish the cause on the customer's PC. Stop removed the TUN; the VM snapshot
was restored, retaining the latest encrypted login storage. Radmin, its adapter
and test staging were absent, with 11 original IPv4 routes and proxy disabled.
The VM is PoweredOff; the temporary snapshot and host test files were removed.
No networking code or client package was changed for these checks.

Private Android **1.5.0+4182** from App `175cbc86` now also includes `a554135e`
and `54ee4391`, using the existing Core `0f159bb` / 1.2.14 AAR without rebuilding
Core. The standard builder verified production signing, package/version,
non-debuggable manifests and ABI sets for universal, arm64-v8a, armeabi-v7a and
x86_64 APKs; their embedded Core libraries match the selected AAR byte for byte.
The [universal APK](E:/POKROV-tools/temp/pokrov-1.5.0-4182-android-universal.apk)
is 244,712,357 bytes; no 4182 phone/emulator installation or publication occurred.

Post-4181 source change: App `54ee4391` refreshes the open Rewards screen after
calendar check-in. Its focused widget test and app_shell analyze passed; the
existing 4181 packages do not contain it. Private Windows **1.5.0+4182** from
App `4061020a` includes it and the session fix below.
The standard Windows builder passed Core binding, built-runtime
equality, required-file and PE version checks using the same Core override.
The [unsigned setup](E:/POKROV-tools/temp/pokrov-windows-x64-1.5.0+4182-setup.exe)
is 28,878,766 bytes; customer installation was confirmed by subsequent 4182 events.
On 20 October the owner authorized sending this private installer to the
customer in support case 89. Case 90 then reported Inno's
`Cannot respawn self, not named .exe`: its startup check rejects a filename
without the `.exe` extension. The original package has the correct extension;
the customer's local filename is not known. The same installer bytes were sent
in a ZIP containing `POKROV-Setup.exe`, with extraction and upgrade instructions.
Telegram delivery and installation are confirmed. Pre-TUN probes succeeded on
several routes, but Windows Connect still failed after activation; disabling
the reported Radmin VPN and restarting POKROV did not resolve it. No diagnostic
bundle arrived. The customer asked to defer further checks, and the owner
subsequently instructed us not to contact them for now. Do not send questions
or builds while that hold is in effect. Continue independent work in the owned
VM; successful connection on the customer's PC remains unconfirmed.
The account's earlier connection events do not accept
Windows. Server-only Core `6cc372d` adds HY2 statistics and does not replace
the client artifacts used by 4182.
No new client release was published. Separately, the actual production catalog27/security2 envelope
passed the existing pinned Dart verifier and both Android/Windows compilers
offline: Smart Safe has five Direct and 29 VPN rules, Full has no Direct, and
Selective accepts only the four VPN services. Catalog content does not require
a new client binary or provider Smart DNS; this does not replace phone QA.

App `a554135e`, included in private Windows 4182, makes support and account requests
share one session refresher, preventing simultaneous use of the same refresh
token. Analyze, the concurrent-request regression, two existing refresh checks
and seven support checks passed. Existing 4181 packages and public 1.4.5 do not
contain this fix; no new client release was published.

Both 4181 builders used the shared private override
`-RuntimeArtifactsPath E:/POKROV-tools/temp/core-urltest-history-0f159bb/runtime-artifacts.json`
and `CoreArtifactDirectory` pointing to its `android` or `windows` subdirectory;
Windows used `-SyncRuntime`. Repeat packaging must retain that selection and the
approved signing/trust arguments: the default tracked runtime manifest was not
updated. Core artifacts were already built and were reused by client packaging.
No further build or unchanged runtime recheck is required by this documentation
update.

Earlier UI evidence keeps its scope: all screens on Android 4178 api35gc,
Windows 4178 main screen and centering only; 4179 passed package/manifest checks.
New accessibility regressions passed widget checks and analyze, not device QA.
Support codes stay masked before DiagnosticsViewData; raw evidence remains in
technical details. Phone checks for the new client and IS UDP wait for the
owner's explicit return of the phone, expected in the evening.

The earlier isolated Naive transport canary used matching Cronet; managed
issuance, the Windows Service proof and scoped 4204 UI/TUN acceptance are now
recorded at the top of this document. The routing-domain
editor is live; production catalog 27 / security 2 was published on 19 October
with six services and 34 domains. Its signature and Android/Windows compilation
passed offline; that does not replace phone acceptance or enable provider Smart
DNS. Naive remains outside the mandatory 1.5.0 scope.
Since 20 October, personalised AWG/Hysteria2 counters join Xray accounting on all
six exit nodes; the previous native history is not reconstructed. The
[owning monitoring contract](C:/Users/kiwun/Documents/ai/VPN/docs/operations/monitoring-and-visibility.md)
defines per-source coverage and freshness, with Xray presence kept separate from
measured traffic activity. Current trial/paid access has unlimited traffic.

Server route ranking and the physical bridge-metrics producer are live. Fresh
Cinema/Lampa samples are healthy and feed priorities for new routes; this does
not by itself prove behavior under load. Remaining server and route work follows
the owner's current queue.

Telegram WEB on CH/Birch is accepted on desktop and, by the owner's own check,
on mobile on 18 October. The phone returned on 26 October; its newer accepted
cases are listed above. Current endpoints and server roles
belong to the [Platform system map](C:/Users/kiwun/Documents/ai/VPN/docs/architecture/system-overview.md).
The owner deleted Hostkey RU; its protected archive remains on Brain and old
ru/delta DNS is empty. The approved retirement supersedes the old direct RU AWG
acceptance requirement. Further server work belongs to the Platform queue.

## Accepted client checks and limits

| Check | Accepted result | Boundary |
| --- | --- | --- |
| Routing catalog | Android 4175 accepted live signed catalog 26 / security 2 in Rules; expiry 15 November 2026, without cached fallback. | The old expired catalog 25 status is historical. |
| Manual WARP | Android 4172, CH VLESS `warp_over_proxy`, Wi-Fi: complete 64 KiB and native tunnel/DNS/egress, followed by Stop. Windows 4168 also accepted manual CH VLESS WARP with 64 KiB and a one-minute observation. | Other WARP variants and cellular WARP are not accepted by these cases. |
| AWG | Android 4174, direct DE2 `awg31_lab`, Wi-Fi: complete 64 KiB, native egress and clean Stop. | This does not accept US/RU AWG or LTE AWG. |
| Hysteria2 | Android 4175, ordinary CH and DE selections after Birch/Fjord migration: complete 64 KiB, effective Hysteria2, native egress and matching staged/effective revisions. DE2 HY2 separately passed native Core 1.2.14 / Windows 4176 with 204 and full 64 KiB. | The 4174 CH activation-resolver failure was fixed and checked; these cases do not accept direct IS UDP from the home route. |
| Updated ordinary bridge paths | Android 4175, CH/Mini and DE/RF2: complete 64 KiB and native egress after CH/DE endpoint migration. | New-host binding comes from backend issuance plus the ordinary receipt; the event does not itself expose the hostname. Separate new XHTTP connections were not run for CH/DE. |
| Lampa ingress | Android 4169, RF2 to PL on Wi-Fi and cellular; RF2-XHTTP to PL on Wi-Fi: complete 64 KiB and native tunnel/DNS/egress after the Floating-IP repair. | Other destinations, current load and all carrier restrictions are not covered. |
| PL direct XHTTP | Android 4173, ordinary PL selection: complete 64 KiB and native protection after Atlas publication. | New-host use was inferred from the managed render and receipt, not independently proven by the candidate revision. |
| Windows install handoff | Windows 4174, ordinary marketing Download, F5 and Continue in POKROV: refreshed handoff consumed by the same existing account. | Existing installation only; no VPN Connect or fresh installation acceptance. |

The Android [acceptance document](android-release-audit.md) records the remaining
LTE/recovery limits. Earlier Android 4169 ordinary Mini/RF2 routes for CH, DE,
DE2, PL and US, plus the historical Mini-to-RU path, retain their accepted native
scope. The failed cellular catalog refresh and DE/Mini, DE2/Mini and DE/RF2
`proxy_dial` attempts did not establish a tunnel; later PL cellular acceptance
does not close those different cases. Direct RU VLESS/AWG failures remain
historical failures with no established root cause. Earlier DE2 probes cancelled
by a DE winner are not evidence; DE2 AWG was subsequently accepted on 4174.

The last final-package VM cleanup restored no running VPN, guard, TUN or proxy,
baseline DNS and routes, then PoweredOff/Unlocked with its physical bridge and
host-time-sync policy preserved. Accepted phone cases restored their temporary
delivery flags and network settings, used normal Stop and left no tunnel.
No blanket acceptance of LTE handoff, all protocols, all WARP variants or a new
load-aware client is inferred from these results.

## Earlier dated results

The remaining receipts describe the build and scenario named in each paragraph.
Their words “current”, “pending” and “remaining” refer to that checkpoint; they do
not override the status above or the owner's current queue. Superseded detailed
Android candidate receipts remain in Git history.

Windows **1.5.0+4169** passed ordinary support delivery on 16 October. With the
owner's explicit Telegram-notification permission, one message was submitted
from the app at 02:52:45 UTC and created ticket85 on the existing VM account.
One operator reply was saved through the normal admin action at 02:56:45.
While Home stayed open, its unread badge was observed at 02:58:00; this sample
does not establish an exact polling latency. The notification named ticket85,
its Open Chat action showed the exact operator reply, and returning Home cleared
the unread badge. The owner also confirmed the thread in the admin UI.
The initial owner notification used the main bot; Platform b10d3a7 corrected
App/API operator notifications to the support bot and verified one notification
for this same ticket, without creating another ticket or operator reply.

At 03:02:28 UTC the VM was initialized/running0/validated0/guard0/failure=none,
Core1.2.14, TUN0/routes11, baseline DNS/proxy, CH/WARPoff and no helper, fault task
or owned browser. The temporary app screenshot was removed; normal shutdown
confirmed PoweredOff/Unlocked, bridge2/GetHostTimeDisabled1. No VPN Connect,
new grant, build or host Hiddify/network/clock change was used for this case.

Windows **1.5.0+4169** passed the remaining cold-start cache check on 15 October.
A temporary guest firewall rule blocked outbound traffic only from the GUI
before it started; Core/service traffic stayed available. With CH selected and
WARP off, one normal Connect at 20:52:30 UTC reached validated running by
20:52:48. While that rule remained active, ordinary OS requests routed through
the POKROV interface returned marked HTTP204 and all 65536 bytes of HTTP200
(442/214 ms). The GUI had no established TCP connection and reported that
subscription data was unavailable. This accepts cached connection with the
client's API access unavailable, not a production API shutdown or total outage.

The rule and its cleanup task were removed at 20:53:50 UTC. After an ordinary
window minimize/restore, Home showed active access with 29 days remaining at
20:54:53; the same tunnel stayed validated without another Connect. Normal Stop
restored config_staged/running0/validated0/guard0/failure=none at 20:55:46 UTC,
TUN0/routes11, baseline DNS/proxy, CH/WARPoff and no fault/helper/browser objects.
Graceful shutdown reached PoweredOff/Unlocked, bridge2/GetHostTimeDisabled1.
No server, host Hiddify/network/clock, runtime artifact or public release changed.
Android physical acceptance and the separately requested fresh support reply
remain open.

Windows **1.5.0+4169** was installed once in the owned Clean VM on
15 October (installer exit0, guest19:18:47UTC). Native service readback confirmed
Core1.2.14; Home retained CH and WARPoff. No VPN Connect or accepted connection
case was repeated. The ordinary Profile→Cabinet handoff authenticated the same
current active Windows device; its normal GET /api/tickets returned zero tickets.
The fresh operator-reply acceptance is therefore still open. Creating a ticket
through the normal API sends an owner Telegram notification; permission for one
test ticket and one operator reply was requested, and no message was sent.

At guest19:28:13UTC the VM had initialized/running0/validated0/guard0,
failure=none, TUN0/routes11, original IPv4DNS/empty IPv6DNS/proxyoff and no
helper, fault task or owned browser window. Temporary DOM material was cleared
and the browser/DevTools closed. Normal shutdown confirmed PoweredOff/Unlocked,
bridge2 and GetHostTimeDisabled1. Hiddify and host network/clock were untouched.

Private Windows **1.5.0+4169** was built once on 15 October at 20:55 MSK
from client `40abd333`. The x64 installer includes the neutral wording from
`7abbb9e8` and is saved at
`E:/POKROV-tools/temp/release-1.5.0/pokrov-windows-x64-1.5.0+4169-setup.exe`
(28,625,332 bytes, Authenticode **NotSigned**). The existing builder checked
packaging and runtime binding; PE text version is `1.5.0+4169`, with numeric
revision4169. The accepted Core1.2.14/Cronet files were reused through the
windows4151 manifest, without SyncRuntime or a new Core build. No ZIP was built.
The temporary P: mapping was removed normally. The later VM installation is
recorded above; accepted connection cases remain on4168 and publication is open.
Hiddify, host settings, VM and servers were not touched during the build.

Private Android **1.5.0+4169** was built once on 15 October at 19:31 MSK
from client `2ce0447b`, including the later manual-WARP, support and neutral
wording changes. It is production-signed **directRelease, ARM64 only**,
85,199,980 bytes, saved at
`E:/POKROV-tools/temp/release-1.5.0/pokrov-1.5.0+4169-arm64.apk`.
The existing builder verified package/version, production signer, non-debuggable
manifest and the ARM64 ABI set. Its generic APK has the same ARM64 bytes and is
not a FullABI package. The accepted Core1.2.14 AAR (`2df0fdd`) was reused without
syncing from Core/dist; `3ded4a3` is still source only. No phone install, runtime
acceptance or publication occurred. Public1.4.5 is unchanged.

Android production builds can reuse the already installed AAR with an explicit
runtime manifest. The builder always checks its bytes against that manifest;
copying from Core now requires `-SyncRuntime` or `-CoreArtifactDirectory`, as on
Windows. A manifest alone no longer tries to copy from a newer Core checkout.
This keeps the accepted 1.2.14 runtime while packaging later client changes.

On 15 October, private Windows 4168 passed an ordinary US/WARP-OFF connection
through the existing Mini bridge. One normal Connect at 15:02:54 UTC reached
validated running in 12.2 seconds. Actual OS-TUN HTTPS requests returned 204 and
all 65536 bytes of200 in 1007/523 ms. The app showed New York and confirmed
tunnel/DNS/egress; at 15:06:43 the service retained two Mini TCP443 sockets and
no direct-US TCP socket. No manual profile override, QA cohort or new grant
was used. This accepts the working Mini→US path; direct protocols remain
separately unaccepted. Platform changes are recorded in its owning doc.

Earlier raw normal-API probes exposed bootstrap DNS without a direct detour;
Platform 9beb9ef corrected that cycle. App materialization differs, so the raw
probe is not an exact App replay. Direct US subsequently passed 204 and obtained
64-KiB response headers but stalled in the body; diagnostic 8 s and MTU 1400 did
not resolve it. MTU 1500 was restored. No timeout, key or client runtime changed.

Cleanup restored CH/WARPoff, config_staged/running0/validated0/guard0,
TUN0/routes11, Ethernet DNS 192.168.3.1/IPv6empty/proxy off and no helper, fault
task or owned browser window. The cleanup status retained
protected_handoff_unavailable; the accepted connection was healthy before
cleanup. Normal shutdown confirmed PoweredOff/Unlocked, bridge2 and
GetHostTimeDisabled1. Hiddify and host network/clock were untouched.
Core 3ded4a3 contains only a tested internal partial-body observation fix;
it is not built into this accepted Core 1.2.14 runtime. No new client build
was required for this server-route acceptance.

Public client wording was neutralized in `7abbb9e8` (five visible strings across
WARP and diagnostics, scoped analysis passed). It is now in both private4169
candidates and the installed Windows4169.

Private Windows **1.5.0+4168** (`56c24d6b`) passed the real manual-WARP chain
check on 15 October. The single build produced a 28,625,319-byte unsigned installer;
installation returned 0 and retained Core 1.2.14/Cronet matched. Manual ON was
observed checked and enabled before Connect at 01:26:22 UTC. Exact current
cabinet/device/build/run telemetry selected CH VLESS Reality **warp_over_proxy**:
its native 64 KiB probe passed in 2,892 ms, and the same chain connected in
14,135 ms. Both attempt records were stored without rejection; no ordinary
fallback was selected. Native running/egress/DNS were healthy with no retained
protection from watcher +15.186 s through +60.798 s, and staged/effective profile
digests matched. This accepts one real WARP chain on Windows; it does not claim
independent per-hop attestation, both chain orders, other networks or Android.

The cause of the ordinary fallback was a cache-freshness budget applied to new
candidate acquisition. In 4167, all four WARP candidates reached route-policy
completion but expired during managed GET, before native probing. The initial
cache refresh still gets three seconds; only missing exact candidate material
now gets `min(actionTimeout, 6s)`, matching the existing selected-profile refresh
budget. Native probe budgets, cancellation and fallback order are unchanged.
An existing regression reproduced ordinary fallback with a 3.1 s exact response,
then reached the chain probe after the fix. Three focused tests, scoped analysis,
diff check and read-only review passed. No overall Connect wall-clock cap is
claimed. Extra server AWG/HY2 validation work was found but retained because it
also determines catalog eligibility; no server optimization was needed for this
accepted chain.

The earlier candidate-only IPC cap fix, pending manual-ON/stale staging guards,
exact-material limit of one and deadline-stage diagnostics remain included.
These were separately checked; they are not substituted for the 4168 real result.
Historical 4165's missing terminal report remains unexplained and does not affect
the exact 4167/4168 comparison.

Normal Stop at 01:27:33 UTC and WARP OFF completed. The current subject transfer
was removed and owned Edge closed. Brain-only read lease
`0992246a-191d-4339-9901-cc5365e4d3a8` closed with fresh Brain health/SSH EOF/FREE
at 01:28:43 UTC, not FULL ACK6. Guest baseline at 01:28:58 UTC had stopped runtime,
no TUN/guard/helpers/fault tasks/browser windows, 11 IPv4 routes, baseline IPv4 DNS,
empty IPv6 DNS and proxy OFF. Graceful shutdown confirmed PoweredOff/Unlocked,
bridged attachment and GetHostTimeDisabled unchanged. Hiddify and host network/
clock were untouched. Android remains signed 4161 ARM64; no physical Android
acceptance, FullABI build or public release.

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


Android4169 manual WARP was attempted once at05:48:06UTC over the phone's Wi-Fi.
The request failed before any tunnel: normal server Event reported
`managed_profile`, `service_unavailable`, `API-007`, 4673ms. The UI text maps to
HTTP5xx, but the exact status/reason is not stored in ordinary server telemetry;
no private client journal was read and no repeated Connect was made. This is
not WARP transport acceptance and does not establish a Germany/WARP restriction.
WARP was switched off again. Final phone baseline at06:26:54UTC: Auto selected,
TUN0, own VPN service absent, Wi-Fi1/mobile_data1/airplane0. Host network and VM
were untouched.

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
