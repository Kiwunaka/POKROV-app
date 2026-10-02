# Client release status

Public version: **1.4.1+4082** with POKROV Core 1.2.2 in
`Kiwunaka/pokrov` GitHub Releases: Android direct APK and unsigned Windows
beta with a SmartScreen warning. Version 1.4.0 remains available for rollback.

## Client 1.4.1 quiet publication, 2026-10-02

Owner-approved public release `v1.4.1` contains the existing production-signed four Android
APKs and unsigned Windows beta setup for `1.4.1+4082`, with Core 1.2.2,
`release-index.json` and `SHA256SUMS.txt`; all seven uploaded asset digests
and sizes match the local package. Simple mode keeps country Auto and moves
settings to Advanced. The exact 1.4.1 APK and installer have not been tested
on the phone or installed VM; old saved-TUN migration is not claimed.
The prepared files were published without rebuilding or announcements.
Brain recommends 1.4.1 on Android and Windows with minimum 1.3.0 unchanged;
the public API's versions, URLs, sizes and digests passed readback. Both services
are active and no broadcast or LiveUpdate was created. Rollback restores
`/root/portal_bot/.env.release-backup-20261002T123151Z` and restarts
`portal-api` and `portal-bot`. Physical-device checks remain unclaimed.

## Client 1.4.0 publication, 2026-09-29

Owner-approved quiet publication at 10:10 UTC from client main `f6e5947`,
files built at 11:07–11:11 MSK and published without rebuilding; GitHub asset
digests match the staged SHA256SUMS. Huawei ran the final APK over 1.3 without
clearing data: Core 1.1.2 loaded, Auto connected, the 11 installed RU-catalog
apps bypassed the TUN, and Д8 telemetry reached Brain; an independent Chrome
DNS-leak capture stayed inconclusive because Chrome used its own secure DNS.
The Windows VM ran the final setup (same hash as the published EXE): Auto in
«Только выбранные» connected, `Discord.exe` and `Telegram.exe` exited via the
VPN while other processes stayed direct; Windows DNS per process was not
independently measured. Brain now serves 1.4.0 on both platforms with minimum
1.3.0, so 1.3.0 gets a recommended update, 1.2.0 and older a required one; no
news, LiveUpdate or broadcast was created. Rollback: restore
`/root/portal_bot/.env.bak-release-1.4.0-20260929T101134Z` and restart
`portal-api` and `portal-bot`.

## Client 1.3.0 publication, 2026-09-28

Owner-approved publication on 2026-09-28 used client main `53d3dc2`. Android's
four APKs passed production signer, version and ABI checks; the Windows setup
passed packaging with its Core and runtime dependencies. E2 device acceptance
used private 4078/4079 builds; the final 4080 was not installed on Huawei or
the VM because the phone was absent from ADB during publication. The public API
now marks 1.1.6 and 1.2.0 updates as required on both platforms; direct APK/EXE
downloads answered publicly, and no LiveUpdate or broadcast was created.

The client source and local Core artifact binding are in `main`. A local
build proves compilation only; device and account checks are recorded below
with their exact package versions.

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
release assets. Completion requires the published package and public download
metadata; background observation does not block publication.

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

## Э1 acceptance, 2026-09-27: 4061

The signed Android APK and unsigned Windows installer were built from `be0f86a`
with the existing Core 1.1.0 binaries. They include `ee80b51` and removal of the
GitHub-key emergency network. Routing rule-set downloads remain unchanged.
The 4060 clean Windows run exposed an invisible welcome when animation tickers
were muted. A regression test reproduced it; `22e9db9` makes that state show
content immediately. The final 4061 clean launch passed without reopening.

| Check | Final 4061 result |
| --- | --- |
| Huawei update | **PASS:** 4059 → 4060 → 4061 without clearing data; trial and routing preferences preserved. |
| Huawei DE/CH | **PASS:** ordinary mode, «Россия напрямую», Wi-Fi. Connected UI and Android VPN state matched increased traffic for the exact test account on both Xray nodes; no unknown-user or REALITY warnings in the matching logs. The existing WARP preference was preserved. A fresh browser request was not checked because automatic tool policy rejected the ADB browser launch. LTE and whitelist-mode checks were not repeated on 4061. |
| Windows update and clean install | **PASS** on POKROV-Win11-Test, VT-x, 4 vCPU, 8 GB, with host builds stopped. Updating the running 1.1.6 UI preserved the trial and removed the old installation. After clearing only test POKROV state, the clean 4061 welcome appeared on its first launch and created a new trial. |
| Windows DE/CH and reboot | **PASS:** ordinary mode, «Россия напрямую», verified TUN/routes/DNS/egress and fresh owned API HTTP 200 on both nodes. DE Core start took 884 ms. Rebooting with CH connected restored ordinary networking before login; the service was running and TUN absent. VPN did not reconnect automatically. A subsequent CH connection passed. |
| Windows uninstall | **PASS** with CH VPN and UI active: EXE, service, processes, uninstall entry and TUN disappeared; Ethernet and the owned API remained available. |

The phone remains on 4061 with VPN off. The VM is left without POKROV.
**Release decision: published by owner approval on 2026-09-27.** The accepted
4061 files were published without rebuilding. Platform metadata recommends
1.2.0 to 1.1.6 clients; no news, LiveUpdate or broadcast was created. Earlier
IT reachability results above were not retested in this scoped DE/CH acceptance.

Publication checks: Android 1.1.6+4029 in a fresh LDPlayer instance showed the
1.2.0 offer; its Update button downloaded all 101,611,855 bytes of the ARM64
APK and opened the Android installer. The downloaded file matched the public
SHA-256, versionName 1.2.0 and versionCode 4061. Installation was not confirmed;
this was an updater check, not VPN acceptance. Windows 1.1.6+29 showed the 1.2.0 offer and unsigned-beta
SmartScreen warning. Its Update button opened the canonical GitHub EXE in Edge;
all 29,357,349 bytes downloaded with the published SHA-256 and file version
1.2.0+4061. Edge retained the file pending its uncommon-download confirmation;
that browser protection was not bypassed. The eight 1.1.6 rollback assets remain
available. The owner cancelled the 48-hour monitoring period and approved
starting Э2 task 1. Any 1.2.0 hotfix must branch from the 4061 build commit
`be0f86a` and needs separate owner approval before publication.
