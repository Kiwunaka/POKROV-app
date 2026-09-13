# Linux package8 recheck after DE address restoration

L04 remains **active/I4/NEEDS_RUNTIME_PROOF**. The same signed package8
`b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933`
on the existing MINI Ubuntu24.04.4 amd64 guest passes the restored default DE
path. This is MINI-origin, not RU-origin or final Linux acceptance.
[Receipt and hashes](receipt.json) retain the exact scope and earlier harness errors.

The [native controls](default-path-controls.json) find the default address
present on DE; guest/MINI/Brain DNS agree, and MINI/Brain each pass two TCP443
connections. The earlier missing-address diagnosis has been superseded by the
[authorized incident recovery](C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start/docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/EXECUTION-HIDDIFY-2026-09-12.md).
No production mutation occurred in this recheck.

The [same-artifact comparison](de-comparison.json) passes six no-VPN controls
and six default-DE HTTPS requests (three200 and three204). The first default
request takes10.51s; this is a functional pass, not a latency pass. The old
alternate DE endpoint fails all six requests: one curl28 and five curl35.
It remains a distinct unresolved path; no blanket TLS or Linux acceptance follows.

[Runtime mode fixtures](runtime-modes.json) pass four HTTPS requests, system
DNS and the exact owned IPv6 reject route in both full/RU cases. The RU fixture
adds a direct rule using the existing profile's one retained RU rule set.
The established owned-RU test socket is observed directly in Core in RU mode;
no direct Core socket appears in the four-second full-mode sample. This is
bounded socket evidence, not an independent full-path egress oracle. The
IPv4-only plan rejects the documentation IPv6 destination; dual-stack service
is not claimed. These are root IPC fixtures, not GUI mode selection or proof
of today's full client rule catalogue. Actual non-root GUI/polkit evidence
remains in the [package8 UI record](../2026-09-11-r12-l04-ui-status/README.md).

The signature and302 installed payload entries/modes/ownership are verified
before both runs. [Final readback](final-readback.json) verifies all302 again,
the unchanged GUI136118/UID1000, root-owned socket0666, no TUN/recovery, and
the exact transmitted script hashes. Kernel peer/polkit authorization still
controls the world-connectable socket. The modes journal reports successful
deactivation; its transient unit was already garbage-collected at readback.
Both scripts restore original private profile bytes and all seven network
baselines. The same QEMU PID1919043 remains running; MINI free space changed
from1,779,535,872 to1,777,823,744 bytes. No new VM/package or host network change.

[Exact scripts and original archive provenance](archive-provenance.json) retain public observers and root-IPC fixtures.
The owned RU target is read only from the prior guest-private observer and
retained as a hash; no raw endpoint/profile/key material is exported. All
previous failure captures remain unchanged. Full L04 and Linux publication
remain open, including the alternate DE path and exact final-package gates.

Verification: platform33 docs tests, context audit and1179 local links PASS;
client validate-seed with explicit Core/platform roots and docs contract PASS.
Six payload hashes,10 script syntax checks,2 native script byte matches,25
focused links, all83 unchanged status tuples and release-artifact isolation
PASS. [Exact commands/logs/hashes](validation.json) retain the evidence.
Evidence-only local commits; no push, deploy or publication.

Follow-up: after tracking the ZIPs, validate-seed rejected their binary extension.
Their exact UTF-8 members are now retained under `scripts/` and `checks/`;
original ZIP hashes and member hashes are in `archive-provenance.json`. Original
archives remain in the source commit and local rollback storage. The earlier
PASS log predates that tracking step and did not prove the committed tree.
