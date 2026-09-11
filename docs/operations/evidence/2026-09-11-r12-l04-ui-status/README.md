# Linux installed UI status correction — package 8

`PASS_INSTALLED_GUI_STATUS_FIX_L04_ACCEPTANCE_OPEN`. Signed package
`1.2.0~beta.30-8`, SHA-256
`b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933`,
was built from UI source `aa08746` and upgraded over package 7 in the same
Ubuntu 24.04.4 amd64 Xfce/X11 guest on `pokrov-mini`. This is not RU-origin.
The [receipt](receipt.json) defines the exact scope and remaining gates.

Package 7 had an observed stale GUI: more than ten minutes after daemon
disconnect, the window still displayed Disconnect/checking although TUN and
recovery state were absent. The [native observation](candidate7-stale-gui-readonly.json)
and [screenshot](candidate7-gui-tls01-after.png) retain that failure. Source
`aa08746` extends the existing desktop local-status poll to Linux, preserving
its single-flight and newer-action guards. The existing Windows service-loss
regression and package-level analysis passed before the native rebuild.

| Check | Result and evidence |
| --- | --- |
| Exact source, offline lockfile and native Flutter release build | PASS: [source archive](source-archive.json), [build](l04-client-build-09.json), [log](l04-client-build-09.log) |
| Package contents, ownership, executable modes, hooks and dynamic libraries | PASS: [native audit](l04-deb-audit-08.json) |
| Detached signing and verification before installation | PASS: [signature](package8-signature.json), [gpgv log](package8-signature-verify.log), [native upgrade](candidate8-upgrade.json) |
| Package-7 to package-8 upgrade | PASS: [native receipt](candidate8-upgrade.json), [APT log](candidate8-upgrade.log); private profile unchanged |
| Non-root GUI and actual polkit/PAM connection | PASS: UID 1000, PID 1648; [window](candidate8-launched.png), [masked prompt](candidate8-auth-prompt.png), [two native authorization passes](candidate8-daemon-events.json) |
| Installed files against the signed deb | PASS: [302 entries](candidate8-installed-readback.json), exact bytes/modes/root ownership, private directories 0700 and profile 0600 |
| Running Core and HTTPS | PASS: [native observer](candidate8-gui-core-loss.json), six requests, selected server/SNI hashes retained; [connected window](candidate8-connected.png) |
| External Core loss observed by the same UI | PASS: [visual receipt](package8-gui-visual.json), [window after SIGKILL](candidate8-after-core-loss.png); Retry/error without app clicks or restart after injection |
| Network restoration after Core loss | PASS: all seven original route/rule/nft/DNS/domain hashes; observer ended MainPID 0, Result success, ExecMainStatus 0 |

The [package comparison](package8-vs7.json) found 299 identical non-directory
entries and seven differences: rebuilt UI executable/plugins/AOT and package
metadata. Core, daemon, unit and hooks are byte-identical to package 7.
Earlier clean-install, connected package lifecycle and suspend/reboot results
remain [package-7 evidence](../2026-09-11-r12-l04-linux-desktop/README.md), not
new claims for package 8. The assembly receipt's `UNSIGNED` label predates the
separate signature. No Ubuntu archive trust is inferred.

The first rebuild attempt stopped before extraction because the retained build
guest had less than 1 GiB free. The same task-owned disk grew from 12 to 13 GiB
within the reserved host capacity; the retry above passed. Initial local package
comparison lacked zstd decoding; the corrected retained comparator reads both
archive formats and reports actual UI differences. Neither harness failure is
presented as a product failure or omitted from the interpretation.

## TLS investigation remains open

The [package-7 comparison](candidate7-tls-path-comparison.json) used three
existing direct paths, restored the original profile bytes and all seven
network baselines. No-VPN control and paths 0 and 34 each passed six HTTPS
requests. Path 5 timed out on all six; its [endpoint diagnostic](candidate7-path-endpoint-diagnostic.json)
found a TCP-443 reachability failure to the owned DE endpoint. A separate
[origin comparison](de-origin-reachability.json) reproduced that timeout on
the MINI host without the guest VPN, while Brain and current Windows passed.
This establishes a path-specific reachability problem; its cause is unproven.
It does not reproduce or explain the older unidentified `curl` exit 35 failure.

The [actual package-7 GUI connection](candidate7-gui-tls01.json) and current
package-8 observer each passed six requests on a recorded path. Those passes
do not close the original TLS issue. The inherited authorization label in the
package-7 GUI observer describes its root observation/cleanup; interactive
connection was through the real GUI/polkit. Package 8 records that separation
explicitly. No profile, credential or raw endpoint is retained here.

The installed readback initially searched `MESSAGE` for authorization JSON;
its empty authorization list is not auth proof. The separate native event
capture reads the daemon's structured journald fields and finds two actual
polkit passes during this GUI session.

The two-second poll interval is source-verified; end-to-end observation latency
was not timed. DNS/egress health remains unknown by contract. This record does
not claim full Linux acceptance, source/Core promotion or publication.
[Retained file hashes](retained-files.json) bind the public evidence.
