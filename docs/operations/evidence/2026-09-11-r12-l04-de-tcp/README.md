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

## 2026-09-12 package-8 lifecycle stopped before purge

The existing MINI Ubuntu guest still has the exact signed package 8. A fresh
[installed readback](candidate8-installed-before-lifecycle-20260912.json)
matches all 302 payload entries, modes and ownership. The
[lifecycle attempt](candidate8-lifecycle-20260912-connected-uninstall.json)
reaches daemon phase `running` through root fixture IPC, but all six HTTPS
preconditions time out (`curl 28`, HTTP000) and system DNS lookup fails.
The [driver](candidate8-lifecycle-driver-20260912.log) stops at that assertion
before closing the desktop UI or invoking apt. Purge, reinstall and successful
connected lifecycle are **NOT_EXECUTED**, not passed.

The [finally result](candidate8-lifecycle-recovery-20260912.json) is
`FAIL_WITH_RESTORATION`: disconnect succeeds, all seven network hashes match
their pre-attempt values, the private profile hash is unchanged, all 302
payload entries still match, and the original GUI PID1648 still runs as UID1000.
No TUN or recovery record remains. The readback's empty authorization-events
field is not evidence of a real polkit action; that proof remains in the
separate installed-UI record. Package7 lifecycle evidence is not reassigned.

The selected default server hash differs from the prior alternate DE path.
A [current read-only node projection](candidate8-default-node-owner-20260912.json)
matches it to the enabled **DE** row and its delivery endpoint. This corrects
the provisional interpretation that a different server hash meant another node.
[Path controls](candidate8-default-path-controls-20260912.json) show the same
global IPv4 answer in the guest, MINI and Brain; it is not in the fake-IP range.
Both MINI-host TCP443 attempts and both Brain-host attempts time out after
four seconds, independently of the guest VPN. That address hash is absent
from DE's current global interface addresses. A
[static-config projection](candidate8-de-address-config-20260912.json) also
finds no default delivery address in the inspected netplan file; the management
address is present and systemd-networkd is active.

The [September9 address record](../2026-09-09-r12-windows-nat-path/de-public-address-fingerprints.json)
contained both address hashes, and the
[September11 endpoint control](../2026-09-11-r12-l04-ui-status/candidate7-path-endpoint-diagnostic.json)
passed TCP to the default address. These older observations do not establish
current reachability. Current delivery configuration/DNS and host assignment
therefore disagree; the time, mechanism and intended status of the missing
address remain unknown. This is distinct from the intermittent failure of the
other DE address. No DNS, node row, host address or production network setting
was changed. Restoring or retiring that delivery address requires an explicit
operator decision and production scope. L04 remains active/I4.

The exact lifecycle scripts and read-only observers extend the existing
[retained manifest](retained-files.json) to 45 files. The guest and package
were reused; no new VM, branch, package build or release artifact was created.

Validation: client `pwsh -NoProfile -File test/docs-contract.ps1` and
`pwsh -NoProfile -File scripts/validate-seed.ps1 -CoreRoot C:/r12corec02
-PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start` PASS.
All45 retained disk/index hashes, six preserved failed probes, seven restored
network states and four native control timeouts were checked. All83 registry
statuses are unchanged. Local links, scoped private-material patterns, staged
diff checks and release-artifact isolation pass. Platform docs tests33 and
context audit pass. These checks do not close failed runtime acceptance.

## Existing DE secondary-address owner

The [targeted owner inspection](candidate8-de-address-owner-20260912.json)
finds the default delivery address in the enabled existing service
`pokrov-de-secondary-ip.service`. Its
[redacted unit and state](candidate8-de-secondary-unit-redacted-20260912.json)
show a oneshot with RemainAfterExit, last successful execution on September3,
and active/exited state. It owns the secondary eth0 address with prefix24,
source rule12070 and table33770. The
[current runtime projection](candidate8-de-secondary-runtime-20260912.json)
finds the address, rule and table absent; eth0 is up and the Xray process
still owns wildcard443. No selected unit journal entries remain. The exact
removal cause is unknown. Netplan is not the configuration owner of this
secondary address, so its absence there alone was not a missing-config proof.

The proposed action is to restart this exact existing service after explicit
production approval and fresh hash/state guards. Its existing ExecStop provides
the network rollback; rollback would leave the service inactive rather than
its prior stale active/exited label. The scoped plan and verification are in the
[platform execution record](C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start/docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/EXECUTION-L04-DE-TCP-2026-09-11.md#proposed-de-secondary-address-restoration--not-executed).
No service restart or production mutation has occurred in this follow-up.

## Exact package8 connected purge and separate restoration through US

The existing guest profile contains one direct US VLESS outbound at index29.
The [fixture wrapper](guest-lifecycle8-us-fixture-20260912.py) temporarily
selects that existing transport for the lifecycle check, and restores the
original private profile afterward. It does not change node credentials or
server settings. The original DE failures remain open and are not reassigned
to this successful path. Authorization is root fixture IPC; real GUI/polkit
proof remains separate.

The [native purge result](candidate8-lifecycle-us-20260912-connected-uninstall.json)
passes six HTTPS requests (three app200 and three marker204), system DNS and
full-mode rules, then closes the UID1000 GUI while Core remains running.
The exact signed package8 is removed and purged successfully. Binaries, socket,
Core and daemon processes are absent; all three units are inactive and disabled.
Profile/settings/keyring state remains unchanged (1/6/2 files), the state root
remains0700, and all seven network states match the original clean preinstall.
This is package8 proof of connected purge, independent of the older package7.

The [automatic reinstall log](candidate8-reinstall-us-20260912.log) retains an
apt internal pathname error (exit100) with the instrument's `--no-download`
invocation. The [wrapper result](candidate8-lifecycle-us-recovery-20260912.json)
stays at RUNNING because its next assertion fails; the
[authoritative unit state](candidate8-lifecycle-us-collection-20260912.json)
is terminal failed/MainPID0. No live wait or successful automatic reinstall is
claimed. The [outer result](candidate8-lifecycle-us-fixture-20260912.json)
restores the original profile and all seven network states, but at that point
the package and desktop UI are still absent.

A separate [same-byte dpkg restoration](candidate8-lifecycle-us-manual-restore-20260912.json)
verifies the detached signature, all11 required packages already installed and
a clean dpkg audit, then installs the same local deb with `dpkg -i` (exit0).
All302 payload entries/modes/ownership match; the GUI runs again as UID1000
(new PID136118), the original profile and all seven network states remain
unchanged, and no TUN/recovery record remains. The artifact filename's
`manual-restore` means a separate recovery step; it was executed by the agent,
not supplied as an operator attestation. The
[restore log](candidate8-lifecycle-us-dpkg-restore-20260912.log) is retained.
This successful recovery does not erase the failed apt invocation.

The fresh pre-US [302-entry readback](candidate8-installed-before-lifecycle-20260912.json)
is byte-identical to the earlier retained file; its new guest filename and
matching hash are bound by the collection report without duplicating the payload
listing. The existing manifest now binds69 files. MINI reused the same QEMU
PID1919043 and disk; host free space after recovery/collection is1,631,399,936
bytes. The VM was already running and remains running with the restored GUI.
No new VM, branch, package build or release artifact was created. L04 final
acceptance remains open on the DE paths and the remaining declared criteria.

Follow-up validation: the same client docs-contract/validate-seed commands
with explicit Core6b and platform roots PASS; platform docs tests33 and
context audit PASS. The focused validator checks all69 retained disk/index
hashes, six old failures, six US successes, apt exit100 preservation, separate
dpkg restoration/302 entries, seven network baselines, unchanged83 registry
statuses, local links, script syntax and bounded private-material patterns.
Staged diff checks and release-artifact isolation PASS. No DE restart is run.
