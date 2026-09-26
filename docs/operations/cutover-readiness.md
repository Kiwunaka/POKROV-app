# Client 1.2.0 release status

Public version: **1.1.6** in GitHub Releases. Working target:
**1.2.0+4059** with POKROV Core 1.1.0. The new target is not published.

The client source and local Core artifact binding are in `main`. A local
build proves compilation only; device and account checks below must run on the
same final package before publication.

## Earlier 4055 snapshot

This table records the earlier 4055 checks; it is not the current candidate's
acceptance result.

| Check | 4055 result |
| --- | --- |
| Core REALITY with Xray 26.6.27, 26.7.28, 26.9.9 and two production nodes | The `acc892b` Core CLI with `with_utls` returned HTTPS 204 and the owned egress marker through disposable loopback Xray servers on all three exact versions. The local fixture used the verified public API address because host DNS supplied a reserved fake address. Installed Windows 4055 connected to DE; CH and a second production-node Core check remain open. |
| Android update over 1.1.6, VPN permission, CH plus two other nodes on Wi-Fi and Beeline LTE | Fresh x86_64 4055 install on LDPlayer created a trial and received VPN permission; CH and DE failed protected-egress verification. Published x86_64 1.1.6 also failed CH and DE. Updating that same 1.1.6 instance in place to 4055 preserved its trial, but DE still failed `core_egress_probe_unavailable` and the app removed the VPN. LDPlayer update passed; connectivity and physical-network checks remain open. |
| Android “everything except Russia”, Wi-Fi/LTE switch, internet after disconnect | Not run on 4055 |
| Windows clean install and update over 1.1.6, connect/disconnect, connected reboot, uninstall | Exact 4055 installer updated over 4054 on the owned VM; DE connected and disconnected. Clean install, 1.1.6 update, reboot and uninstall remain open. |
| New account, trial, connection; expired account, renewal and provider invoice creation | A trial was created on LDPlayer with 4055; connection failed. Expired-account and payment checks were not run. |
| Hiddify and Happ subscriptions on CH and another node | On Android 9 LDPlayer, Hiddify 4.1.1 imported the live trial subscription but failed before Core startup. Happ 4.4.1 imported CH and DE and reported connected on each, but the owned HTTPS probe timed out through its VPN and passed immediately after disconnect. Third-party egress remains unproved. |

After those checks, publish Android APK and unsigned Windows beta through the
existing `Kiwunaka/pokrov` release-index flow. Public announcement text needs
owner approval. Rollback points the release index back to the retained 1.1.6
release assets. Do not claim release completion before the package reaches
users and 48 hours pass without critical reports.

## Э1 acceptance, 2026-09-26

The signed Android 4059 APK was installed on the Huawei main profile over 4058.
The existing trial survived. The production subscription fix is deployed from
platform `master`; this entry records the final candidate and relevant earlier
checks without treating an earlier build as proof of 4059.

| Check | Result |
| --- | --- |
| Android 4059, DE and CH, standard «Белые списки» | **PASS** on Wi-Fi and Beeline LTE. The Huawei reported a connected VPN, fresh public pages loaded, and the exact test account's Xray traffic increased on each selected node. Wi-Fi → LTE → Wi-Fi kept DE connected; Wi-Fi → LTE kept CH connected. No unknown-user or REALITY error appeared in the matching node logs. |
| Android 4059, internet after disconnect | **PASS**. The VPN indicator disappeared and a fresh public page loaded over Wi-Fi. |
| Android 4059, Italy | **FAIL** on Wi-Fi. Milan ordinary mode returned `probe_failed` at 22:24 UTC on 2026-09-25, with no increase in the test account's IT Xray traffic. Milan standard «Белые списки» returned `core_egress_probe_unavailable` at 22:36 UTC, then `core_egress_connect_failed` on a later retry. A same-Core diagnostic build reproduced both kinds: Core reported `context deadline exceeded` for `unavailable` and `URL probe connection failed` for `connect_failed`. The first is a network deadline in this reproduction, not the earlier Core-startup error `selected route probe unavailable`. IT Xray showed no unknown-user or REALITY warning in the matching minutes. An earlier synchronized RU-bridge egress capture saw SYN packets toward IT while IT ingress saw none. On 2026-09-26, TCP to IT:443 timed out from mini, RU, and RU-SPB, but passed from DE, PL, and US; all sources resolved the same address. IT allows 443 globally in UFW and has no active Xray fail2ban bans, so the path loss appears upstream of Xray. The app temporarily greyed out Milan variants after a failed live probe, then allowed another choice when that result expired. |
| Android 4058 checks retained | **PASS** for upgrade over published 1.1.6 with the trial preserved, and for a clean install with a new trial. DE and CH connected on Wi-Fi and Beeline LTE in ordinary and white-list modes. «Россия напрямую», full tunnel, network switching, and internet after disconnect were exercised. US ordinary mode also passed on both networks. These checks were not repeated in full on 4059; the 4059 code change only moves the Core egress probe until after Core startup or reload. |
| Third-party clients on Huawei with the current trial subscription | Hiddify 4.1.1: **PASS** on DE and CH «Белые списки», with loaded pages and matching Xray traffic. Happ Android 3.24.1: **PASS for VPN connectivity** after manually refreshing its existing subscription on 2026-09-26. It received Xray JSON profiles including «· БС»; DE and CH «· БС» each reached Android `VPN CONNECTED` and `VALIDATED` over Wi-Fi. The earlier DNS failure was observed with the stale direct-VLESS subscription. A fresh browser page through Happ was not independently checked because the ADB browser launch was rejected by automatic policy. |
| Windows VM | **PARTIAL** for the local 4059 installer built from `7388cbd`. Upgrade from published 1.1.6+29 with its UI running passed: the old EXE, uninstaller, and HKCU entry disappeared, and the new EXE, HKLM entry, and service remained. Clean installation and UI launch passed. An ordinary reboot without VPN kept the service running and the network available. Uninstalling with the UI running removed the EXE, registry entry, and service; Ethernet and TCP to the owned API on port 443 still worked. The VM was left without POKROV. VPN connect/disconnect and reboot with VPN active remain unverified: earlier 4057 and published 1.1.6 both failed connection on this same VM, so further VPN testing stopped under the owner's A/B instruction. |
| Expired-account renewal and payment | **PASS for invoice creation** on 2026-09-26. A separate production test account was created through the trial API, expired in the account and trial grant, and disabled on the panels. Its one-month SBP renewal request returned HTTP 200, an HTTPS checkout URL, and a provider invoice ID with Lava status `new`; the local order is `pending` for 250 RUB. No payment or fulfillment was performed. The other Lava orders in the preceding four days belonged to tests; there was no real-user attempt in that window to establish a real-user success rate. |

**Release decision: HOLD.** Android 4059 has focused DE/CH physical-device
coverage, and the Windows 4059 installation paths passed, but the IT network
path and Windows VPN acceptance remain open. Happ VPN connectivity and
test-account invoice creation passed. Publication and the bot announcement
need the owner's approval after those items are resolved or explicitly waived.
