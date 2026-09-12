# Linux package 8: DE TCP-path failure

`FAIL_DE_PATH_CONSISTENCY_L04_OPEN`. The installed signed package remains
`1.2.0~beta.30-8`, SHA-256
`b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933`.
This is the same Ubuntu 24.04.4 amd64 guest on MINI as the
[installed UI proof](../2026-09-11-r12-l04-ui-status/README.md), not RU-origin.
No runtime code, firewall, server configuration or credential was changed.

## Observed result

After earlier MINI-to-DE TCP timeouts, a [concurrent handshake check](de-mini-concurrent-handshake.json)
passed without configuration changes. The following installed-package
[HTTPS recheck](candidate8-de-https-recheck.json) passed all six no-VPN
requests; on the existing DE path it produced one timeout (`curl 28`), four
connection resets (`curl 35`) and one successful request. The
[socket observation](candidate8-de-socket-observation.json) again passed six
controls and failed six DE requests: two timeouts and four resets. During
resets, the exact Core process had pending `SYN-SENT` sockets to DE.

The [simultaneous host captures](candidate8-de-concurrent-wire.json) then
ran around [two further native resets](candidate8-de-wire-socket-observation.json).
One hashed flow established TCP and appeared at both MINI's physical
`enp3s0` and DE's `any` capture. Four other hashed flows each emitted six SYNs
at MINI, with no SYN-ACK or RST there and no matching flow observed at DE.
The two no-VPN controls passed. Socket sampling associates the failure window
with pending Core connections; it does not map each inner HTTP request to one
outer flow. Later host retries can belong to QEMU's user-network proxy after
the guest has stopped Core; they do not prove leaked guest runtime state.

This localizes an observed handshake failure between MINI's egress capture
and DE's capture. It is evidence of a TCP-path problem preceding TLS, not a
demonstration of an incorrect SNI, key or fingerprint. Exact loss location
and cause remain unproven. Capture stderr/drop statistics were not retained
in this observation, so zero capture loss is not claimed. The older
unidentified package-7 `curl 35` session cannot be bound retrospectively to
this particular DE path.

The later [read-only hook projection](de-hook-boundary.json) found no XDP
attachment or ingress/egress TC filters on either host. MINI's physical fq
queue had seven cumulative drops; without a before/after interval, those
drops cannot be assigned to this test or dismissed as irrelevant.

A [subsequent native MINI-host comparison](de-native-host-wire-counters.json)
removed the guest and VPN from the probe path. Of six bounded simultaneous
TCP connections to owned DE:443, four timed out and two established. The
two successful hashed flows appear at both hosts; each failed flow has three
SYNs at MINI and none observed at DE. Both captures reported zero kernel
drops, and both qdisc drop counters stayed unchanged (MINI 7, DE 0).
This independently reproduces the handshake failure outside POKROV and QEMU.
It strengthens the network-path diagnosis without identifying the failing
upstream device or policy. No product or server workaround was applied.

## Configuration and cleanup boundaries

The [native transport projection](candidate8-de-public-metadata.json) matches
the [DE listener projection](de-transport-shape.json): VLESS/REALITY over TCP,
SNI, short ID and public-key hashes, with `xtls-rprx-vision` in the fixture.
The server is Xray 26.6.1; its binary and config hashes are retained. Raw
profiles, keys, endpoint addresses and packet payloads are not retained.
The [read-only panel row](de-fixture-panel-row.json) finds the enabled owned
fixture with no fixed expiry. Its absence from the
[on-disk startup client list](de-fixture-member.json) does not prove absence
from Xray's dynamic runtime user map.

Every guest comparison restored the original private profile bytes and all
seven network baselines. The final observer terminated with MainPID 0,
Result success and ExecMainStatus 0; these indicate harness cleanup, not
successful DE traffic. Real GUI/polkit proof remains in the separate package-8
record; these comparisons use root fixture authorization.

L04 remains open. Existing successful paths, source/main CI and package
installation do not convert these failed requests into Linux acceptance.
[Retained hashes](retained-files.json) bind the observations and their scripts.

Verification: `pwsh -NoProfile -File test/docs-contract.ps1` and
`pwsh -NoProfile -File scripts/validate-seed.ps1 -CoreRoot E:/r12core904-bound-source
-PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start` passed.
The bounded evidence validator checked all 27 retained hashes both on disk
and in the Git index, 57 local links, private-material patterns and the native
host counter interpretation. Platform documentation checks passed 33 tests
and its context audit. Both scoped `git diff --check` checks passed; no client
release-artifact delta exists. These are documentation/provenance checks.

## 2026-09-12 existing-port control

The [native port comparison](de-port-control-20260912.json) performs nine
sequential MINI-host connections: six to the existing DE VPN listener (443)
and three to its existing SSH listener (22). One 443 connection passes;
five 443 connections and all three 22 connections time out after four seconds.
Each attempt has a hashed socket tuple bound to MINI capture counters. Failed
attempts each show three outgoing SYNs and no local SYN-ACK/RST; the successful
443 flow appears in both captures. No corresponding failed flow was observed
in the DE capture. Both observers report zero kernel drops. Capture start/end
epochs were not retained, so exact overlap of every retransmission is not claimed.

The failure therefore affects both tested ports, rather than only the VPN
port or a TLS handshake. This does not identify a dropping device or policy,
and cannot explain the older unidentified curl35 session. No VM, profile,
firewall or service setting was changed. Both observer processes exited zero.
The [script](observe-de-port-control-20260912.py) and result extend the retained
manifest; earlier captures and their conclusions remain unchanged. L04 stays open.
