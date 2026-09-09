# Integrated ARM64 acceptance on Huawei

2026-09-08, **PASS_BOUNDED**. [Receipt](receipt.json) binds client `7ae931b`
and Core `02a091c` to ARM64 APK SHA-256
`88452b9921873c4fbb42bef25ed4d89c34841399ae11cbe8d9d482e5a03d5850`.
The local 1.2.0+4053 package was rebuilt after shared Dart changes. It is not
a published candidate or a channel update.

`adb install -r` passed. Installed hash matched before runtime checks and
again afterwards; first-install timestamp remained unchanged. Warsaw whitelist,
Russia-direct and WARP-off settings remained visible. Exact account identity
was not independently compared. The previous signed APK remains available for
rollback; no data clear, uninstall or account mutation was performed.

Two fixed-Wi-Fi ordinary-profile connect/disconnect cycles retained foreground
VPN service and TUN while connected. Both protection sheets reported confirmed
tunnel, DNS and VPN egress. This is app-observed protection, not independent
packet/egress/leak evidence. After each disconnect, exact original policy-rule
line hashes and route hash were restored, with VPN service and TUN absent.
The final device retained the new APK, Wi-Fi/mobile enabled and VPN off.

The first observer failed Windows text decoding before connecting. Its retry
then hit UIAutomator idle failures and read stale XML. Those UI strings were
discarded. Native samples plus fresh screenshots and actions based on the
observed controls completed the two cycles. All earlier observations and script
hashes remain retained in `E:/r12-integrated-acceptance-20260908/android`.

AWG identity/protocol matrix, outage/expiry/revocation, network handoff, Doze,
IPv6/MTU/UDP53, energy and final release/channel gates remain open. Previous
different-APK handoff evidence is not transferred to these bytes.
