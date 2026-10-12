# Smart Access DNS routing

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
