# Android AWG31 to managed TCP under UDP data block

The installed x64 APK `288ec01630b4577d94221f5d16624945efb9a273cd9eac5af2f57c8552cc31f3`
binds client `922d9bc` and unchanged Core `0138d04`. [Runtime receipt](runtime-acceptance.json)
records the owned lab scenario and its limits. [PR135](https://github.com/Kiwunaka/POKROV-app/pull/135) merged `75bc1f8`; exact PR/main CI passed.

UDP data was dropped in the dedicated Android guest, with DNS53 permitted.
AWG reported failed egress at46.5s while its TUN remained live. The UI now
observes the existing55s native watchdog, recognizes confirmed failed egress
in the running phase, and disconnects through the bounded reconnect path.
The same installed APK obtained managed VLESS/TLS and verified it3.803s after
failure, without a manual reconnect or AWG/HY2 loop. [Three HTTPS exchanges](https-under-udp-block.json)
returned204 with the authenticated marker while UDP remained blocked.

[AWG scope](scope-awg.json) and [TCP scope](scope-tcp.json) match selected routing
preferences, application scope, user DNS, DNS hijack and all four local RU sets.
TCP keeps its existing additional server geoip/ads/torrent catalogue. There is
no claim of equal whole profiles or equal server rule catalogues. After removing
the fault, the exact original AWG profile verified normally.

[Native events](native-events-timed.json) retain both failed earlier APK runs
and the final transition. [Network restoration](fault-restoration-final.json)
confirms guest routes/DNS/firewall and host routes/DNS. The lab binding and
one-day test grant were removed; worker revoked row108 and removed its peer.
[Server readback](server-restored.json) matches original nonblank config bytes;
only blank separators differ. All prior material rows and the original peer remain.

Root is disabled and all local emulators are stopped. [VM metadata readback](root-restored.json)
retains six changed generated phone/MAC fields; their cause is not established
and original values were not retained. Full VM metadata restoration is not claimed.
App install identity stayed the same. Host Hiddify was not changed.

Earlier APKs, both regression failures, package audits, exact scripts/logs and
cleanup evidence are retained in the [platform execution record](C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start/docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/EXECUTION-A07-INSTALLED-2026-09-13.md).
No physical-device, fresh RU-origin, Windows, full IP/ASN blacklist matrix,
final release-candidate or public AWG activation claim follows from this test.
