# Android acceptance

Updated 21 October 2026. Public version remains **1.4.5**; the seven-asset
**1.5.0+4175** draft is unchanged. The current private candidate is
**1.5.0+4185**, built from App `54a5e680` with the ready Core `0f159bb` / 1.2.14.
The built-in Xbox DNS preset was removed in `ed2a982d`. Packaging is accepted:
universal, arm64-v8a, armeabi-v7a and x86_64 APKs are production-signed.
The [universal APK](E:/POKROV-tools/temp/pokrov-1.5.0-4185-android-universal.apk)
and the other artifact paths are listed in [cutover readiness](cutover-readiness.md).
No 4185 installation, phone/emulator or network check was performed. The phone
requires a new explicit return; public release still requires the owner's yes.
The [external DNS browser comparison](../architecture/smart-access-dns.md) is
Windows-only research, not Android or POKROV provider acceptance.

The preceding **1.5.0+4181**, built from App `d78aefc9` with the same Core,
installed over 4178 and preserved the test account; 14 real screens were opened
and captured on api35gc for the help Atlas. No VPN or checkout was started,
and the emulator was turned off. That screen walkthrough does not establish
physical VPN or load-aware route behavior for the current candidate.

## Earlier package checks

Private 4182 from App `175cbc86` included the shared support/account refresh and
Rewards fixes. Its four APKs passed production signature, package/version,
non-debuggable manifest, ABI and selected-Core-library checks; it was not installed
or accepted on a phone/emulator. This remains packaging history.

The 4175 draft contains production-signed universal and three ABI-specific
APKs, Windows setup and two metadata assets. Its ARM64 APK installed without
removing app data. Load-aware bridge ordering changed after 4175; no Android
acceptance of the new load-aware behavior is inferred.

Redesign build **1.5.0+4178** is production-signed and built with the accepted
Core 1.2.14 artifacts. Visible api35gc accepted real-data screen navigation,
Iceland/flag, promo rendering, AI-to-human navigation without sending, masked
Diagnostics, Rules, Bonuses and complete catalog plan labels. Existing session
data survived installation. This is UI acceptance, not physical VPN acceptance;
no payment, support message or release publication occurred.

[Known Problems](C:/Users/kiwun/Downloads/POKROV_KNOWN_PROBLEMS_2026-10-13.md)
is the current release queue; [cutover-readiness.md](cutover-readiness.md)
records the package status and accepted checks. The phone is unavailable until
the owner explicitly returns it. The owner's mobile Telegram WEB acceptance on
CH/Birch on 18 October does not authorize a new device session.

## Accepted physical checks

| Build / scenario | Result and scope |
| --- | --- |
| 4175 routing catalog | Rules accepted live signed catalog 26 / security 2, expiry 15 November 2026, without cached fallback. |
| 4175 CH and DE Hysteria2 on Wi-Fi | Ordinary country selection after Birch/Fjord migration completed 64 KiB with effective Hysteria2, native egress and matching staged/effective revisions. The earlier 4174 CH activation-resolver failure was fixed and checked. |
| 4174 DE2 AWG on Wi-Fi | Ordinary Germany Connect selected `de2:awg31_lab`, completed 64 KiB and reached native egress; Stop removed the tunnel. |
| 4172 manual WARP on Wi-Fi | CH VLESS `warp_over_proxy` completed 64 KiB and retained native tunnel/DNS/egress before clean Stop. This accepts that chain, not every WARP variant or cellular WARP. |
| 4175 CH/Mini and DE/RF2 | Ordinary connections after endpoint migration completed 64 KiB with native egress. Backend issuance plus the normal receipt supports the hostname binding; the receipt alone does not expose it. |
| 4173 PL direct XHTTP on Wi-Fi | Complete 64 KiB and native protection after Atlas publication. Exact new-host use was inferred from the managed render and receipt, not independently established by the candidate revision. |
| 4169 RF2 to PL on Wi-Fi and cellular; RF2-XHTTP to PL on Wi-Fi | Complete 64 KiB and native tunnel/DNS/egress after the Floating-IP repair. This covers those paths, not all Lampa destinations or new load-aware ordering. |
| 4169 ordinary country routes | Mini to CH, DE, US and DE2; RF2 to PL and DE2; historical Mini to RU reached native tunnel/DNS/egress with successful 64 KiB probes. This is not independent browser acceptance for every route. |

Temporary delivery scopes were restored after the accepted cases. Normal Stop
removed the tunnel; Auto, WARP off and the original network settings were restored.
The final 4175 FullABI packaging reused accepted ARM64 runtime behavior and did
not repeat unchanged protocol QA on all ABIs.

## Limits retained from earlier checks

- Recent acceptance does not establish live-tunnel Wi-Fi/LTE recovery deadlines,
  long-running stability, all cellular protocols or every WARP variant. A cellular
  catalog refresh and DE/Mini, DE2/Mini and DE/RF2 attempts on 4169 failed without
  a tunnel; the later PL cellular success does not close those distinct cases.
- Direct RU VLESS/AWG failed on 4172/4173; the precise cause was not established.
  The owner subsequently deleted Hostkey RU; its protected archive remains on
  Brain. The retirement replaces the old direct RU AWG acceptance requirement.
- On 12 October, 4145 CH/Mini RAW on Beeline LTE passed native checks and fresh
  Chrome HTTPS 204 plus all 65536 bytes, remaining healthy for about 230 seconds.
  On 4144, US VLESS REALITY passed the same traffic checks and an independent US
  country check; Gemini still rejected the country. Neither case accepts SmartDNS
  or subsequent endpoint changes. SmartDNS is outside the current release scope.
- US AWG on 4144–4147 and US HY2 on 4144 failed. The 4147 AWG diagnostics retained
  `tls_read` and reserve `egress_204` cancellation before a response; that localized
  cancellation without establishing the underlying cause. Later DE2 AWG and
  CH/DE HY2 success does not turn those old US/LTE attempts into passes.
- The 4106 Wi-Fi/LTE checks did not measure an exact recovery deadline; its first
  LTE Auto failure remained unexplained. The 4107 activity-reopen check did confirm
  the healthy connection's location label without another Connect.
- LDPlayer 4029/4055 failures and update/session preservation are historical
  emulator observations. LDPlayer and local APK builds do not close physical
  Android VPN acceptance. Detailed superseded candidate receipts remain in Git.

Run Flutter analyze/tests for changed packages and both
`testDirectDebugUnitTest` and `testStoreDebugUnitTest` for Android host
changes. Test changed behavior and the applicable stage criteria; do not repeat
accepted unchanged cases merely because another package was produced.
