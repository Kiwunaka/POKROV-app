# Smart Access DNS routing

## Current external-provider work — 21 October 2026

The owner approved commercial embedded use of Shecan, Astra/Astracat, GeoHide,
Bezmezhau, WLrus, DNS-AI and Zapret DNS. For these agreements, an eligible paid
user means **any active Premium access**: purchase, trial, gift, promotion,
bonus, manual or family access. The server uses the existing trial/paid/bonus
Premium projection, including its manual/family handling, and excludes Free and
expired/blocked access. No payment receipt, `provider_payment` origin or new
entitlement class is required. Provider fees (fixed or percentage) remain under
discussion; no spending is authorized. Customer contact, phone acceptance and
public release remain paused. The owner also accepted WhiteDNS and SlipNet for
all active Premium access; their separate DNS-tunnel addon is not a SmartDNS
endpoint. SlipNet source readiness is recorded below; no live DNS-tunnel
endpoint or App provisioning is enabled. Rates remain pending. See the platform-owned
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

Current private packages are **Windows 4200 / App `c9b6087b` (including `b8644537`) / Core `b560f1a`
(1.2.14)** and unchanged Android 4187 / Core `0f159bb`. The 4200 unsigned installer
(28,913,726 bytes) completed in the Clean Windows VM with exit 0; the ZIP contains
one `POKROV-Setup.exe`. Earlier targeted Core/App and 48 desktop ABI checks retain
their scope. This binary does not contain DNSTT Core `7a62031`.
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

SlipNet's first VLESS-over-DNSTT source slice is pushed in Core `7a62031`,
Platform `85ea9a2` and Node `3d9f3ce`. The existing CC0 engine passed a real local
UDP DNS/KCP/Noise/smux 10 KiB echo plus race/lifecycle/registry checks; one
Platform and three Node focused checks passed. The optional backend accepts
only existing active Premium account keys (including trial/manual/gift/promo/
bonus/family); Free, expiry, block and revoked keys are excluded. It is a
loopback TCP VLESS backend at `127.0.0.1:12543`, not a live DNS service or a
per-device key. App source now admits the authenticated `vless/dnstt/noise`
reserve for active Premium with loaded `dnstt_vless_v1` and VLESS capabilities.
It validates the fixed loopback VLESS leaf, Noise pin and one numeric recursive
UDP/53 resolver, excludes the carrier from selectable proxy paths, and repeats
that boundary when restoring cached material. WARP/bridge wrapping is excluded;
country selection and the existing maximum of six bundled materials are unchanged.
Auto gives one DNS reserve a separate 30-second attempt after ordinary routes
and before direct WARP, preserving the complete TLS/204/64 KiB proof. The cache
retains one authorized DNS reserve alongside its existing alternatives, so a
blocked API does not require fetching that material again.
This is source support, not integrated App/network acceptance. Remaining work is
an owned CH UDP/53 endpoint, owned NS delegation and the packaged Core/App check.
Root observed public UDP/53 and TCP/12543 free on CH; only
systemd-resolved listens on `127.0.0.53/54:53`. No owner DNS change is requested
yet. Windows 4200 still packages the earlier Core binary; WhiteDNS remains
research. Commercial permission already covers active Premium; fees are pending.

Root confirmed network/process cleanup after 4200: ordinary Stop left running/guard/TUN/winws 0;
allExceptRu/IS, Automatic SmartDNS, local DPI off and empty service selection
were restored. DNS/routes/proxy exactly match the baseline; owned Edge/app/winws
and TUN are absent. Display `1372×943` was restored and read back; 12 owned guest
QA items and the temporary host build were removed. Root confirmed CleanWin11
PoweredOff and its separate window closed. Final setup/ZIP and selected earlier
Core DLL/manifest remain. The host network, Hiddify and clocks were untouched.

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
an encrypted inner identity or claim to distinguish ECH from GREASE. Owned, QA
and suffix scopes keep the existing rejection. Foreground renewal compares the
derived mode; server publication makes provider kind immutable for an existing
provider ID, which is already part of the unchanged runtime scope hash.
Catalog and lease expiry, declared VPN fallback, the untimed
domain rejection, disabled DNS cache and TTL zero retain their existing roles.
The finite first-provider QA permit remains nonrenewable. A native A/TLS probe
does not prove a browser feature request.

The separate historical private Windows QA path accepts Gemini or ChatGPT only. The verified permit and grant
select the service and exact hosts for compilation, earlier-rule checks and native
proof; browser input cannot choose this scope. Gemini keeps its single exact host.
ChatGPT requires `chatgpt.com` and may include individually admitted exact hosts
under the existing ChatGPT/OpenAI/static/content roots, each matched to a
nonshared domain in the same disabled catalog service. Unknown services and
suffix scopes fail closed. Its owned QA projection stays outside public selection, and the one attempt
remains nonrenewable and limited to 600 seconds. Source tests do not establish a
real ChatGPT response through the owned relay.

Windows recognizes the selective producer's exact `api.pokrov.space` /
`app.pokrov.space` pair in matching TCP/443 and VPN DNS rules. Ordinary connect
keeps the protected VPN verifier; explicit QA selects the leased service only
after that boundary passes. The previously supported single API rule remains
valid, while extra, duplicate, suffix, mismatched DNS and Direct DNS scopes fail
closed. The native regression failed with the paired producer input before the
parser fix and passed afterwards; this does not identify the exact branch of a
historical device failure or establish browser functionality.
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
