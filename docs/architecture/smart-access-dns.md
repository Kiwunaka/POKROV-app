# Smart Access DNS routing

## Current external-provider work — 21 October 2026

The owner approved commercial embedded use of Shecan, Astra/Astracat, GeoHide,
Bezmezhau, WLrus, DNS-AI and Zapret DNS. For these agreements, an eligible paid
user means **any active Premium access**: purchase, trial, gift, promotion,
bonus, manual or family access. Reuse the existing trial/paid/bonus Premium
projection, including its manual/family handling; exclude Free and
expired/blocked access. Do not require a payment receipt, `provider_payment`
origin or a new entitlement class. Provider fees (fixed or percentage) remain
under discussion; this approval does not authorize purchases or ordinary rollout.

The table records one root-run comparison in the clean Windows 11 VM from the
Russian home network. Only a temporary Edge profile used secure DoH. **PASS**
means Gemini answered the test question about Paris; HTTP 200 or a page without
an answer is not PASS. This is external-provider/browser evidence, not POKROV
integration, Android acceptance, an availability guarantee or an Auto change.
Root verified that VM DNS, routes and proxy were unchanged from the captured
baseline, removed the temporary Edge profile/processes and QA directory, and
powered off both VMs. The owner's host network was not changed.

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

The next implementation stage must enforce that existing Premium projection on
the server's provider/lease issuance and renewal/control paths, then expose the
same eligibility to the UI. The signed provider permission, scoped lease and
runtime expiry remain mandatory. Hiding a picker alone is insufficient:
`client_routing_preferences.dart` still has a legacy custom SmartDNS/direct path
outside catalog compilation that does not require a lease. Closing that path is
an outstanding addon task. Ordinary VPN access for manual/family users stays
intact. Public DNS endpoints themselves are not made private by a POKROV UI gate.

The private 4185 packages contain the Xbox preset removal, not this provider
integration. Flowseal/zapret canary was not executed: the guest token was UAC
filtered. No new DPI acceptance is claimed. Manager is an OpenWrt-only reference;
ideas may be studied, but its own code without a LICENSE must not be copied.

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
No Telegram messages, subscriptions, joins or installations were performed.

## Existing scoped runtime and historical QA

`routing_catalog_materializer.dart` gives each leased service domain a timed DNS
rule using that lease's owned DoH transport. For an IPv4 lease its exact query
list is `A`, `AAAA`, `HTTPS`, `SVCB`: the resolver supplies the owned IPv4 relay
answer for A and NOERROR/NODATA for the other browser queries. These requests
must reach the same resolver instead of falling through to VPN DNS or reject.
Windows and Android validate that exact list before selecting a Smart Access
probe target; extra query types do not authorize it.

The TCP rule remains IPv4 TCP/443 with the signed exact-domain/suffix scope.
DNS handling grants no IPv6 TCP or QUIC access and does not change the client or
server ECH guards. Catalog and lease expiry, declared VPN fallback, the untimed
domain rejection, disabled DNS cache and TTL zero retain their existing roles.
The finite first-provider QA permit remains nonrenewable. A native A/TLS probe
does not prove a browser feature request.

Private Windows QA accepts Gemini or ChatGPT only. The verified permit and grant
select the service and exact hosts for compilation, earlier-rule checks and native
proof; browser input cannot choose this scope. Gemini keeps its single exact host.
ChatGPT requires `chatgpt.com` and may include individually admitted exact hosts
under the existing ChatGPT/OpenAI/static/content roots, each matched to a
nonshared domain in the same disabled catalog service. Unknown services and
suffix scopes fail closed. Public selection stays disabled, and the one attempt
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
