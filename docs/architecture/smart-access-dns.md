# Smart Access DNS routing

## Current external-provider work — 26 October 2026

The owner approved commercial embedded use of Shecan, Astra/Astracat, GeoHide,
Bezmezhau, WLrus, DNS-AI and Zapret DNS. For these agreements, an eligible paid
user means **any active Premium access**: purchase, trial, gift, promotion,
bonus, manual or family access. The server uses the existing trial/paid/bonus
Premium projection, including its manual/family handling, and excludes Free and
expired/blocked access. No payment receipt, `provider_payment` origin or new
entitlement class is required. Provider fees (fixed or percentage) remain under
discussion; no spending is authorized. Customer contact and public release remain
paused; the phone returned on 26 October, while provider/DPI-specific Android
acceptance is still separate. The owner also accepted WhiteDNS and SlipNet for
all active Premium access; their separate DNS-tunnel addon is not a SmartDNS
endpoint. On 26 October the owner published the delegation of `t.portal-privacy.online`
to `ns1.kiwunaka.space` (CH) and `ns2.kiwunaka.space` (PL). All four Timeweb
servers returned it; recursive native Core through WLrus passed TLS, owned 204
and 65536 bytes in 11,732 ms. CH managed DNSTT delivery is enabled for all current
eligible Premium access. Ordinary Windows 4216 Auto/TUN and cleanup passed.
Rates remain pending. See the platform-owned
[whitelist research](../../../VPN/docs/competitive/censorship-stack-research-2026-07-22/whitelist-bypass-2026-10-21.md).

The table records the earlier 21 October root-run comparison in the clean
Windows 11 VM from the Russian home network. Only a temporary Edge profile used
secure DoH. **PASS** means Gemini answered the test question about Paris; HTTP 200 or a page without
an answer is not PASS. This is external-provider/browser evidence, not POKROV
integration, Android acceptance, an availability guarantee or an Auto change.
At the end of that comparison root verified that VM DNS, routes and proxy were
unchanged from the captured baseline and removed the temporary Edge
profile/processes and QA directory. The later native pass and its separate cleanup
are recorded below. The owner's host network was not changed.

| Provider / endpoint | Gemini result in this comparison | Commercial permission recorded by owner |
| --- | --- | --- |
| COMSS — `https://dns.comss.one/dns-query` | PASS: real answer | Not recorded in the current approved list |
| GeoHide EU — `https://eu.geohide.ru/dns-query` | PASS: real answer | Approved for active Premium |
| GeoHide RU — `https://geohide.ru/dns-query` | PASS: real answer | Approved for active Premium |
| GeoHide US — `https://us.geohide.ru/dns-query` | HTTP 200, blank page; not accepted | Approved for active Premium |
| DNS-AI — `https://dns.dns-ai.ru/dns-query` | PASS: real answer | Approved for active Premium |
| WLrus — `https://dns.wlrus.cfd/dns-query` | PASS: real answer | Approved for active Premium |
| Zapret DNS — `https://dns.zapret.moe/dns-query` | Page and prompt HTTP 200, no answer; not accepted | Approved for active Premium |
| Astra / Astracat — `https://dns.commonnet.work/dns-query` | Google unusual-traffic response; not accepted | Approved for active Premium |
| Bezmezhau — `https://dns.bezmezhau.com/dns-query` | Name resolution failed; not accepted | Approved for active Premium |
| Malw — `https://dns.malw.link/dns-query` | Connection reset; not accepted | Not recorded in the current approved list |
| Shecan | Not tested: no freshly confirmed DoH endpoint | Approved for active Premium |
| Mafioznik | Not tested: no freshly confirmed DoH endpoint | Not recorded in the current approved list |
| Xbox DNS | Not tested in this comparison; built-in preset removed in `ed2a982d` | Not recorded in the current approved list |

Premium gates are implemented on server provider/lease issuance and
renewal/control paths. App commit `38adc208` uses the server's
`smart_access_eligible` projection in the picker and preparation and removes the
legacy custom SmartDNS/direct bypass. A saved legacy custom SmartDNS selection
returns to Automatic without expanding its former DNS scope; ordinary custom
DoH and the existing COMSS preset remain separate. Signed provider permission,
scoped leases and runtime expiry/revocation remain mandatory. Manual/family VPN
access is unchanged, and public DNS endpoints remain public.

Windows local SmartDNS profiles use the same memory policy as ordinary managed
Windows profiles: `disableMemoryLimit=true`, retained through routing copies.
They must not enable Core's mobile 45 MiB connection killer, which can close all
sockets during a later relay dial and appear as a connection failure after a
successful startup. Android keeps its existing memory limit.

Live signed catalog 28/security 2 is unchanged; provider policy **2/security 1**
now admits only **WLrus and DNS-AI**, for Windows Gemini and all eligible active
Premium access. Publication used the existing key and Action Intent, with exact
readback, admission open, API health at 09:07:39 UTC and operation lease FREE.
Those are last-observed server facts; the 4200 pass changed neither catalog nor
provider policy and did not repeat the server checks. Server `8018d52` enforces immutable provider kind for an
existing provider ID. No commercial COMSS offer was added.

Latest accepted Android is **4211 / App `eaf5d0d1` / Core `58b11d4`**; Windows
remains **4209 / Core `b3a021b`**. Android Naive CH was accepted on 4210, followed
by the new direct Lampa→PL path on 4211; see
[cutover readiness](../operations/cutover-readiness.md). Android provider SmartDNS
remains public OFF: Platform `1bbe856` fixed the QA legacy-alias/lifetime 500;
the next actual attempt reached TUN ready but rejected the protected API/app-domain
pair. Parser correction `6e8cb4da` passed its focused test and is being packaged
in 4212; device acceptance waits for the phone's return. Android SmartDNS
and LocalDPI/YouTube are not accepted by those VPN or external-client results.
DNSTT delegation, recursive transport and Windows 4216 Auto/TUN passed. Slipstream remains separate and deferred.
Previous checks retain their original scope.
The already accepted 4195 Gemini checks were not
repeated: in ordinary Edge with default settings, POKROV
returned real Gemini answers about Paris through WLrus `191.217.212.16` and
DNS-AI `103.137.248.145`: secure HTTP/2, phase running and gateway available after
both requests, without VPN. Direct gstatic dependencies loaded over IPv4 after
the physical-IPv6 DNS fix `fcfe46c4`; no additional catalog domains were needed.
GeoHide EU returned Google's unusual-traffic response; GeoHide RU used VPN with
an empty lease inventory, and its exact cause was not established. Neither is
in policy 2. Android packaging remains accepted without new device/native proof.
Artifacts are in [client readiness](../operations/cutover-readiness.md).

Managed Naive is a separate authenticated VPN transport, not provider SmartDNS.
CH `ch.pokrov.space:443` is live on Platform `f019efe` / Node `3e23441`. The
earlier 02:54 UTC pass acknowledged 34 identities; the latest API-only deployment
did not repeat this identity check. All active Premium access, including trial
and manual, is eligible. App requires loaded Naive H2 and TLS capabilities and
accepts only `naive/h2/tls` with certificate verification, explicit SNI, QUIC
and UoT disabled, and no detour. Native Cronet supplies H2 without a custom ALPN
list. DPI/Telegram fallback checks retain the same authenticated TLS boundary.
Cold selection in 4203 tries Naive earlier within the same direct-route group;
country, bridge-load order and existing budgets still apply. Targeted selector
tests cover this ordering change. Version 4204 also retains a genuine Naive
reserve in the saved cache. Runtime acceptance remains scoped to the run below.

On 4202 existing native Service commands 28→29→28, using a QA profile produced
by the actual server helper, passed TLS, owned 204 and the full 64 KiB in
1,189 ms without changing the runtime context. A separate normal device-bound
API check selected `ch:naive_h2` and returned the authenticated TLS leaf; that
response was not the profile passed to the native probe. This accepts the
transport, not a full UI/Auto/TUN connection. The initial unavailable result
preceded App initialization, rather than proving a network failure. The fresh
six-node ACK/API health gate passed at 02:54:19 UTC with server lease FREE and
temporary timers inactive. Public metadata, draft release, customer contact and
paused automations were unchanged. This remains the earlier full-fleet result.

Platform `f019efe` corrects inherited UDP content DNS for this TCP-only transport:
the protected resolver is `tcp://8.8.8.8` through the selector, with explicit
direct UDP `8.8.8.8` and local bootstrap retained. The targeted `node_naive.py`
deployment and API restart used backup
`/root/portal_bot.deploy-backups/20261023T044724Z-51996`; the fresh Brain-only
health gate passed at 04:47:50 UTC with the lease FREE. It did not repeat the
six-node fleet gate.

On **4204**, normal CH Refresh saved the genuine server-issued Naive entry with
TUN and corrected DNS. The QA fixture stopped App, restricted only the DPAPI
cache's downloaded/candidate entries to that existing entry and removed the old
proven entry. It changed no binding, config, catalog, expiry or inventory.
An App.exe-only TCP/443 rule made the API unavailable, with a 180-second SYSTEM
watchdog; Service traffic remained unblocked. Ordinary UI **«Включить защиту»**
reached running with failure none, native egress validated, DNS ready, guard 0
and TUN 1. App itself saved proven `ch:naive_h2` / `naive,h2,tls`, with only
Naive/selector/direct/block outbounds; UI showed **«Выключить защиту»** and
**«Состояние защиты: Швейцария»**. This proves the ordinary UI/TUN path using one
existing cached Naive candidate with API unavailable. It does not prove all-route
Auto selection or exhaustion of blackholed alternatives.

A browser's denied scoped request can leave `readiness.status=failure` and the
sticky `fallback_guard_closed=true` alongside three successful probe stages.
That QA guard is separate from gateway availability and does not itself force
VPN fallback; its protections were not weakened. These results establish the
two Windows Gemini paths above, not other services, platforms or network guarantees.

The bounded Windows strategy retry applies only to the existing TCP connect,
TLS and HTTP proof failures. DNS, physical-interface, WFP-permit, invalid-input,
owner cancellation, child failure and unknown outcomes stop selection immediately.
Ownership is rechecked after proof, before a transport failure can trigger retry.

The current Windows source defaults to upstream zapret's `multidisorder` with
`split-pos=1,midsld` first (journal strategy ID 101), then Flowseal 1.10.3/1.10.4
ALT4's Google TCP branch (ID 4). The two-attempt limit remains; 568 and 681 are
no longer attempted. The same-network success hint survives normal Stop, but
a later observed runtime failure clears its network key before the next Connect;
the original strategy ID stays available for the failure journal. WFP rule
priority is compared semantically
(`499dd3e6`), and ordinary protected VPN egress is verified before WinDivert
starts (`c3ba46d0`). Core `b560f1a` adds an IPv4-only local rule immediately before
the unchanged signed VPN rule, preserving IPv6 fallback. EOF from a speculative
socket with no client write no longer retires admission. The existing holder
observation and native journal retain the first closed failure reason without
addresses or raw errors. Exact host/interface scope and TLS verification remain.

On 4198 and 4199, ordinary Connect reached running, DNS/egress validated and
`protection_retained=0`; YouTube played about 13 seconds/400 frames. On 4199,
local DPI subsequently failed with `early_read` (16 local / 7 VPN handoffs,
admitted 0 / failed 1). That pass confirmed VPN fallback, not video entirely over
local DPI. Edge SSL_CONNECT -100 (connection closed) to
`rr3---sn-vcpu-axql.googlevideo.com` / `85.114.28.78` at 14:40:07.179 precedes
the first native `early_read` at 14:40:07.261 by 82 ms. The same CDN IP/SNI and
physical source were then tested outside POKROV with a 10-second bound: plain,
ALT4 and 681 all established TCP but timed out in TLS; the plain-process exit
code was not captured. The remaining TLS failure is reproducible on that
path/endpoint independently of POKROV and these two candidates. No particular
ISP, DPI or middlebox is established, and no random strategy flags were added.
The separate ALT4 `www.youtube.com` control returned verified HTTPS 200. Earlier
zero curl connect timings were wrongly interpreted as TCP failure; later
Schannel evidence confirms that TCP establishes.

A subsequent single standalone control on that exact CDN IP/SNI and physical
source passed with `multidisorder` / `1,midsld`: verified TLS in 411 ms, HTTP 404
for `/`, curl exit 0, filter alive and owned child cleanup confirmed. The VM is
bridged. Header-only capture lacked the full reply sequence, so it does not
establish a specific DPI mechanism. This supports the new source candidate;
that standalone control alone did not establish integrated playback. The candidate comes
from [upstream blockcheck](https://github.com/bol-van/zapret/blob/master/blockcheck.sh#L1289).

The subsequent **4200** ordinary Connect reached running, DNS/egress valid and
guard 0. Ordinary default Edge, after rejecting optional cookies, played
YouTube to **84.0167 seconds / 2,537 frames at 480p**, readyState 4, error 0 and
playing. Local TCP handoffs were 21, VPN TCP handoffs 0, admitted 1 / failed 0.
HTTP/3/UDP also traversed ordinary VPN and is absent from these TCP counters;
do not claim all video traffic bypassed VPN. An initial playback stopped with
an unexplained player error around 21 seconds. Later pauses were the cookie
dialog, followed by the accepted 84-second run. No global QUIC/DNS or host
network changes were made.

YouTube API and CDN domains use the same signed
Selective local-DPI holder and enables `prefer_tcp` only for that service. A
ready holder rejects routed QUIC/UDP443 attempts and closes its pre-proof QUIC
sessions; unavailable, failed or withdrawn holders retain VPN fallback. Windows
IPv6 TCP still stays on VPN. Android's existing diagnostic summary now reports
admission states, actual local/VPN TCP handoffs and rejected QUIC connections
from the captured Core holder, using the existing traffic sampling callback.
These counters contain no domains or connection material and do not establish
video playback, a uniformly Russian exit or removal of advertising. Device
acceptance of this change is separate from the retained 4200 result above.
Android runtime decoding preserves only the exact closed local-DPI aggregate
from the native summary; other native text stays redacted. Expanded Technical
details show its admission/failure counts, local/VPN TCP handoffs and rejected
QUIC connections. Missing data is shown as unavailable, never as zero success.
Android accepts a VLESS bridge fallback only when every VLESS hop has TLS enabled
without insecure verification; it keeps the original selector or ATS lease as
the fallback and rejects direct, unsupported or cyclic detours. Device acceptance
of this source change remains separate.

SlipNet's VLESS-over-DNSTT source was integrated in Core `b628439`,
Platform `cfcd3fb` and App `fb59e1c5`. Platform and Node's DNSTT backend are live
on Brain/CH respectively; CH also runs the CC0 DNSTT authoritative server.
Direct authoritative QA passed TLS, owned 204 and 64 KiB in 696 ms; an invalid
personal UUID was denied. The optional backend accepts
only existing active Premium account keys (including trial/manual/gift/promo/
bonus/family); Free, expiry, block and revoked keys are excluded. It is a
loopback TCP VLESS backend at `127.0.0.1:12543`, behind the owned UDP53 service,
using account keys rather than separate device keys. App admits the authenticated `vless/dnstt/noise`
reserve for active Premium with loaded `dnstt_vless_v1` and VLESS capabilities.
It validates the fixed loopback VLESS leaf, Noise pin and one numeric recursive
UDP/53 resolver, excludes the carrier from selectable proxy paths, and repeats
that boundary when restoring cached material. WARP/bridge wrapping is excluded;
country selection and the existing maximum of six bundled materials are unchanged.
Auto gives one DNS reserve a separate 30-second attempt after ordinary routes
and before direct WARP, preserving the complete TLS/204/64 KiB proof. The cache
retains one authorized DNS reserve alongside its existing alternatives, so a
blocked API does not require fetching that material again.
Managed delivery was enabled on 26 October at 17:04:47.227 UTC for CH only. The
33 desired identities matched the current paid/admin projection; active trial,
manual/gift/promo/bonus/family qualify, while Free/renewal do not. Backend 12543
and Naive were preserved with no service restart. PL forwards UDP53 through its
existing sing-box to the single CH backend, without DNS cache or a second Noise/KCP
session owner. The owner replaced unpublished atlas/birch names with
`ns1.kiwunaka.space`/`ns2.kiwunaka.space`; all four Timeweb servers returned the
new delegation. Recursive WLrus completed actual TLS/204/65536 bytes in 11,732 ms.
The diagnostic CLI now accepts an optional explicit 30-second budget matching the App's
existing DNS-reserve budget, with 12 seconds still the default. Runtime AAR/DLL and VERSION
were unchanged. Ordinary CH Auto/TUN on Windows 4216 selected `vless_dnstt_noise`
and reached running in 42.721 s; separate http_64k passed in 12.329 s and native
DNS/egress/TUN were valid. Two scoped temporary rules blocked ordinary transports
without replacing API or TUN. Stop removed the running tunnel; preferences and
the recorded nonempty DNS/default-route/proxy baseline matched. Owned rules/task/
QA files were removed and PoweredOff confirmed. This does not prove behavior on
a live whitelist network. WhiteDNS remains research. Commercial permission
already covers active Premium; fees are pending.

Root confirmed network/process cleanup after 4200: ordinary Stop left running/guard/TUN/winws 0;
allExceptRu/IS, Automatic SmartDNS, local DPI off and empty service selection
were restored. DNS/routes/proxy exactly match the baseline; owned Edge/app/winws
and TUN are absent. Display `1372×943` was restored and read back; 12 owned guest
QA items and the temporary host build were removed. Root confirmed CleanWin11
PoweredOff and its separate window closed. Final setup/ZIP and selected earlier
Core DLL/manifest remain. The host network, Hiddify and clocks were untouched.
After the later 4204 run, ordinary UI Stop reached `config_staged`, guard 0 and
TUN 0. Root removed the exact rule/task and restored only the cache key plus
original preferences, leaving the remaining secure store/session tokens intact.
DNS/routes/proxy matched the baseline and display 1372×943 was restored;
app/winws/TUN were absent and the owned QA directory was removed. Root confirmed
the VM PoweredOff. Android Naive was not checked in that Windows pass;
its subsequent 4210 acceptance is recorded above.

Historical 4194/4195 comparison: catalog 28 authorizes selective YouTube local DPI with exact control host
`www.youtube.com`. Verified encrypted bridge/ATS admission, exact pre-connect
guard permission and winws filter readiness are corrected. On 4194, strategies
568 and 681 passed TCP but timed out in native TLS control after 10 seconds and
used safe VPN fallback. The final controlled comparison pinned both plain curl
and standalone 681 to `www.youtube.com:443` at `142.251.157.4`, bound to the
physical interface with the same 10-second budget. Both timed out with zero
published TCP/TLS timings; that did not locate the failure before TCP.
681's filter stayed READY and its child cleanup was confirmed. POKROV was
stopped, with no TUN, POKROV guard or service-owned winws; DNS/routes were not
changed. That comparison did not establish the failing network stage or ISP;
neither integrated local DPI nor video was accepted. At the end of that pass,
root restored the saved allExceptRu/IS preferences,
Automatic SmartDNS, local DPI off and empty service selection; DNS/routes/proxy
match the baseline. Owned Edge/winws and TUN are absent, temporary profiles were
removed, and CleanWin11 is verified PoweredOff. The host network, Hiddify and
clocks were untouched.
Auto, customer contact, phone checks and public release remain unchanged.
Manager remains an OpenWrt-only reference; its code without a LICENSE must not
be copied.

Read-only Telegram research on 21 October: the four August/September messages
in the [older whitelist thread](https://t.me/wlrforum/122620) are historical
community suggestions, not current acceptance. The [DNS thread](https://t.me/wlrforum/141652)
confirms the WLrus endpoint above; Gemini/app reports conflict, and the owner
notes that source-IP changes may trigger Google restrictions. Keep DNS scoped to
the selected service and a stable existing route, rather than replacing all DNS.
The [OpenFlux thread](https://t.me/wlrforum/130437) has 20 October community reports
of one-way MTS traffic and a failing Yandex path; these are not our diagnosis or
evidence for production promotion. SmartDNS is not accepted as a whitelist bypass.
The linked [olcrtc project](https://github.com/openlibrecommunity/olcrtc) is archived
and marked end-of-life on 5 October 2026; its configuration notes are historical.
The separate whitelist-bypass setup requires its own client, authentication
cookies and an SFU session with one creator and one joiner. These remain addon
research only, not a POKROV fallback or a production integration.
That read-only review sent no Telegram messages and performed no subscriptions,
joins or installations.

## Existing scoped runtime and historical QA

An IPv4 lease explicitly sets `address_strategy: ipv4_only` when bootstrapping
its provider's DoH hostname through `dns-direct`. App's existing DNS normalization
carries this into `domain_resolver.strategy` before staging; the global DNS
strategy does not override an explicit resolver's default AsIs. This prevents an
unnecessary AAAA bootstrap wait without changing the service query types, IPv6 lease
behavior, request deadlines or TLS checks. The observed DNS-AI delay is compatible
with that wait, but packet QTYPE evidence has not established its cause.

`routing_catalog_materializer.dart` gives each leased service domain a timed DNS
rule using that lease's DoH transport. For an IPv4 lease its exact query list is
`A`, `AAAA`, `HTTPS`, `SVCB`, with `strategy: ipv4_only`: Core returns local
NOERROR/NODATA for AAAA rather than advertising the provider's unusable IPv6
answer. A and service-binding queries keep the same resolver and lease window.
This suppresses the observed unusable DNS-AI AAAA response under an IPv4-only route.
Windows and Android retain the exact query list and accept only `ipv4_only`
when this optional field is present. Older rules without it remain readable;
extra query types or a different strategy do not authorize a Smart probe.

Windows local SmartAccess reads the existing physical-uplink IPv6 capability on
each profile preparation. When it is explicitly false, an AAAA-only
`ipv4_only` DNS rule follows the signed service rules and their rejection, so
unmatched Direct domains receive NODATA instead of an unusable IPv6 destination
behind the TUN. True or unknown capability leaves Direct IPv6 unchanged. A
changed network during preparation rejects that profile; existing reconnect and
restage paths read the capability again. No host IPv6 setting or signed scope changes.

The TCP rule remains IPv4 TCP/443 with the signed exact-domain/suffix scope.
DNS handling grants no IPv6 TCP or QUIC access and does not change the client or
server's owned-provider ECH guard. For a host-verified external provider, an
approved catalog gateway and an all-exact lease domain set, App projects
`external_ech_outer_sni: true`. Core checks the visible outer SNI against those
exact domains and forwards the ClientHello unchanged; it does not authenticate
an encrypted inner identity or claim to distinguish ECH from GREASE. The same
exact-domain external mode applies to an explicitly signed QA grant; owned QA
retains its ECH guard. Owned and suffix scopes keep the existing rejection.
Foreground renewal compares the
derived mode; server publication makes provider kind immutable for an existing
provider ID, which is already part of the unchanged runtime scope hash.
Catalog and lease expiry, declared VPN fallback, the untimed
domain rejection, disabled DNS cache and TTL zero retain their existing roles.
The finite first-provider QA permit remains nonrenewable. A native A/TLS probe
does not prove a browser feature request.

The private first-provider QA path supports Windows and Android for Gemini or
ChatGPT. A signed, disabled/source-only capability binds the active device
platform, session, build, Core module and profile. Approved embedded external
providers use their existing identity and permission; no provider kind is
relabelled. Exact Gemini/ChatGPT domains remain limited to nonshared domains in
the current catalog. A Windows-enabled service may be tested privately on
Android without adding Android to its public platforms. The server rejects QA
when the same service/platform already has an enabled verified capability. One
attempt lasts at most 600 seconds, is nonrenewable, and native/browser proof is
still required before public promotion. Android exposes the existing diagnostics
action only for a pending device admission and uses the existing identity-bound
Connect/control APIs.

Android keeps the bounded Start deadline until Dart verifies the signed QA permit
and foreground control and the bound native worker is installed. The current
identity-only owner then stays under a watchdog capped by the matching permit and
lease expiry. Core verifies its own runtime-control polls asynchronously.
For Android QA and ordinary SmartDNS, native control uses the common direct
bootstrap resolver already bound into the active leased profile. Missing or
conflicting bootstrap bindings reject control instead of choosing another DNS.

An exception escaping QA start retains only the existing closed exception type,
allowlisted code and up to two local Dart source locations in the QA summary and
bounded protection history. The summary preserves a classified control failure
through the outer start error. Android also logs closed QA control failure reasons
under `POKROV-SmartDNS`, without profile or connection material. Diagnostics
refreshes that summary after the error and retains its error card when the pending
admission disappears. Raw exception
messages, stack paths and connection material are not displayed or retained.
The connection observer keeps `ConnectionConnectedUnverified` pending even when
all four native flags are already ready. It does not send that complete set to
the incomplete-proof event or mark the attempt verified; only the confirmed
`ConnectionExperience` state can complete verification.

The Android paired-API parser fix starts with private build 4212. Earlier
Selective clients, including 4209, reject that profile even after a denied
SmartDNS lease falls back to VPN. Ordinary provider leases do not bind a client
build; the unchanged Core version alone cannot distinguish the Kotlin host fix.
Do not apply the prepared provider4/catalog29 Android promotion patches in this
pass. Public Android SmartDNS stays off: a private QA success must first be
followed by an agreed rollout of the compatible app or an older compatible
catalog for old clients before public enablement.

QA claim and fresh QA control tolerate sub-second issuer clock skew by waiting
until the signed `issued_at`, at most one second within the existing cancellation
and request budget, then strictly verifying that same response once more. This
is not clock leeway: future or expired grants remain rejected, no HTTP request
is repeated, and expiry, subject binding and native verification are unchanged.

Android QA waits for the existing native post-start egress proof before sending
QA control. It reads pending Start through `snapshotForConnectRequest` for the
same request; a `running` snapshot with `connection_pending` still waits for
that Start to complete before accepting egress proof. Identity-only QA does not
set the ATS `transportProofPending` latch: Android derives that requirement from
the digest-verified staged profile, while actual ATS profiles retain their
existing proof and promotion requirement. TUN-ready alone no longer
ends the QA action as `connection_unavailable`. The native connection deadline
is unchanged. Failed
native startup attempts now emit only closed stage/code/error-type, attempt
number and elapsed milliseconds to the existing bounded journal and the
`POKROV-Egress` Logcat tag, readable without `run-as`. A bare Core deadline has
stage `unknown`; no profile, destination or exception text is emitted.
The same tag marks each actual startup probe call with only its attempt number
and fixed target kind, distinguishing it from an unfinished Core start.
After successful bound QA control configuration, Android queues one existing
SmartAccess readiness probe for the sole active QA anchor, behind the already
verified VPN/API boundary. It uses the current session worker and captured
request/profile/Core server ownership; Stop and replacement retain their
existing cancellation. The ACK confirms configuration and dispatch, while
`readSmartAccessLeases` separately reports pending/pass/failure stages. Neither
browser traffic nor receipt reads start this probe, and its result does not
change global VPN health.
Repeated control refresh for the same Connect owner does not rerun the probe.

Android and Windows recognize the selective producer's exact `api.pokrov.space` /
`app.pokrov.space` pair in matching TCP/443 and VPN DNS rules. Ordinary connect
keeps the protected VPN verifier; explicit QA selects the leased service only
after that boundary passes. The previously supported single API rule remains
valid, while extra, duplicate, suffix, mismatched DNS and Direct DNS scopes fail
closed. The native regression failed with the paired producer input before the
parser fix and passed afterwards; this does not identify the exact branch of a
historical device failure or establish browser functionality.
Windows native egress preserves the independent `pokrov.space` static reserve
for Full VPN. A validated Selective API pair uses `app.pokrov.space` with the
same API proof/data endpoints instead; legacy API-only and process-scoped
API-only profiles use no reserve outside that protected scope. Ordinary
Selective profiles without a SmartDNS outbound undergo the same boundary
validation. Entering TUN alone does not prove that Core routed the reserve
through VPN. Probe deadlines, retry timing and failure policy are unchanged.
Malformed protected boundaries return the existing `profile_payload_invalid`
code through the native snapshot, UI timeline and D8 closed taxonomy (CONN-005).
An unsupported probe ABI still returns `core_egress_probe_unavailable`; unknown
private codes remain rejected or redacted at those boundaries.

Core observes a bypass only for the compiled window's own domain matcher.
Walking past another domain's window in the same lease keeps readiness open;
an actual bypass of the matching domain's rule still closes its guard. The
regressions cover synthetic DNS and route walks, not the historical cause of a
particular browser failure.

QA control diagnostics retain the closed native rejection code and exact verifier
failure code. Windows passes a native code only from a trusted, compatible service
response; an unavailable IPC exchange remains `service_unavailable`. Unknown
codes, exception messages and details do not enter the QA context. A failed
Smart probe leaves the separate ordinary VPN health unchanged.

## Resolver location and service egress

Smart DNS changes a service's visible source address by directing selected
connections through a relay, not by moving DNS resolution alone. Control D
documents this DNS-answer and transparent-proxy design; Getflix describes the
same selected-domain relay model. For POKROV the resolver and relay are distinct
roles: an existing US node is a possible relay candidate, not a fix for an
unclassified client control failure. Changing the exit requires a scoped
functional comparison after that failure is understood. No US cutover was
performed during the 2026-10-12 review.

Google publishes exact Gemini network dependencies beyond `gemini.google.com`.
That firewall allowlist is not a requirement to relay every listed host: add only
an observed necessary dependency to the agreed service scope. Real browser
response acceptance remains required; country, successful DNS/TLS and page HTML
do not establish it. COMSS's current documentation describes migration from its
old Control D endpoint to PowerDNS; it does not establish closure of the entire
service or disclose the current relay topology.

Sources checked 2026-10-12: [Control D](https://docs.controld.com/docs/getting-started),
[Getflix](https://www.getflix.com/faqs/),
[Gemini firewall settings](https://knowledge.workspace.google.com/admin/generative-ai/gemini-app/gemini-app-firewall-settings),
[COMSS DNS](https://www.comss.ru/page.php?id=7315).
