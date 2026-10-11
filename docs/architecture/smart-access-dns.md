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
