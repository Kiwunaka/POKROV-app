# Android acceptance

Public version remains `1.4.5`; 1.5.0 candidates are private. Older Huawei
acceptance is recorded in `cutover-readiness.md`. The 4061 and 4055 results
below are historical; LDPlayer is not used for VPN acceptance.

Private ARM64 candidate `1.5.0+4145` retains the closed native recovery
cause in current Diagnostics and uses the updated Core `1.2.14` that accepts a
successfully verified egress probe with a measured duration of zero milliseconds.
The result below does not establish the historical 4144 failure cause or verify
the retained-reason display during a new failure.

Private ARM64 candidate `1.5.0+4146` preserves the allowlisted native candidate stage in
a cancelled reply, so Diagnostics can show the last native stage alongside `probe_budget_expired`.
Cancellation still fails and waits for native cleanup; its deadlines are unchanged.
The physical result below verifies the retained stage, not an AWG connectivity fix.

On 2026-10-12, the in-place 4145→4146 update preserved the package UID, main-profile
data inode and secondary-profile state. One US AWG 3.1 attempt on Beeline LTE
failed with `CONN-008`, `probe_budget_expired`, preparation reason
`candidate_selection_exhausted` and origin `core`. Diagnostics now retained
candidate stage `http_204`; this does not prove receipt of an HTTP 204 response.
No usable VPN was established. Final checks found no tunnel, VPN service or
tunnel routes; Auto, Russia-direct, Wi-Fi off and mobile data on were restored.

During the subsequent bounded RU-ingress canary, one CH Mini RAW attempt on
4146 reached native Connected with all four checks confirmed. The server owner
cancelled the case after a strict TLS failure and rolled back; no browser check
was run, so ingress continuity was not accepted. Normal Stop and baseline
restoration completed at 08:50:02 UTC: Auto, Russia-direct, Wi-Fi off, mobile data
on, and no tunnel, tunnel routes, VPN service or Chrome diagnostic forwards.

On 2026-10-12, the in-place 4144→4145 update preserved the package UID, main-profile
data inode and secondary-profile state. One ordinary CH Mini RAW connection on
Beeline LTE in full-device mode passed tunnel, routes, DNS and protected-egress
checks. Chrome passed the owned HTTPS 204 and complete 65536-byte check. After
about 230 seconds, refreshed Diagnostics still confirmed all four checks and its
current timeline contained one connection attempt without recovery entries.
Normal Stop removed the tunnel, routes and VPN service; Auto and Russia-direct
were restored, with Wi-Fi off and mobile data on. This does not cover ingress
changes, US Mini, other transports or SmartDNS.

On 2026-10-12, the Huawei main profile running private ARM64 1.5.0+4144
(Core 1.2.14) connected to the ordinary US VLESS REALITY candidate over Beeline
LTE in full-device mode. Normal Diagnostics confirmed tunnel, routes, DNS and
protected egress. Chrome passed the owned HTTPS 204 and complete 65536-byte
checks; its independent country check returned US. Gemini's fresh public app
page instead showed “Gemini isn’t currently supported in your country” with no
prompt field, so no query was sent and Gemini acceptance failed. The country
disagreement is unexplained; this result does not cover SmartDNS or a US bridge.

The same candidate's ordinary US AWG 3.1 attempt failed on both Beeline LTE and
saved Wi-Fi with `CONN-008`, `probe_budget_expired` and preparation reason
`candidate_selection_exhausted`. US Hysteria 2 reached candidate stage `http_64k`
but then failed at the Core step with `CONN-008`; no more specific cause was shown.
The admitted CH Mini RAW route initially confirmed all four native checks, then
automatically reconnected twice and entered TrafficBlocked with protected egress
requiring attention. Its owned browser HTTPS check and ingress continuity were
not accepted. Stop removed the tunnel, routes and VPN service; Wi-Fi was returned
off with mobile data on, and DevTools forwards were removed. A subsequent normal
UI readback confirmed Auto and Russia-direct with the VPN disconnected.

The x86_64 direct 4055 APK was installed in a fresh LDPlayer instance. It
started, created a trial, and received Android VPN permission. DE and CH both
failed the protected-egress check, after which the app removed the system VPN.
This is an observed LDPlayer result, not a pass for Android connectivity.

The published x86_64 1.1.6 APK (build 4029) also failed its CH and DE
protected-egress checks in a separate fresh LDPlayer instance. On 2026-09-25,
that same 1.1.6 installation was updated in place with the x86_64 direct 4055
APK (`adb install -r`). Android reported `versionCode=4055` and
`versionName=1.2.0`; the existing five-day trial was still shown. A DE connect
then ended with `core_egress_probe_unavailable`, and the app removed the VPN.
The emulator's ordinary network worked after the failure. This closes the
LDPlayer update and session-preservation check, but neither version passed
protected egress, so the cause of the Android connection failure is still open.
From the same emulator, the CH TCP listener on port 443 accepted a connection
and `api.pokrov.space` resolved to its public address. Those checks do not
authenticate REALITY or explain the failed in-app egress probe.

On 2026-09-25, the same Android 9 x86_64 LDPlayer instance repeated the DE
failure on installed 4055. Its authenticated cabinet opened and copied the
private subscription directly into the emulator clipboard. Hiddify 4.1.1
imported it and showed the trial expiry, but its VPN start stopped at
`startService - starting background core...`. Happ 4.4.1 imported the Happ
format and listed CH and DE. Happ reported a VPN connection on each node, yet
the owned HTTPS probe timed out with and without a pinned API address. With
Happ disconnected, the same probe returned HTTP 200 immediately. These are
LDPlayer failures, not proof that the production nodes or the subscription
work through either client. No client or Core fix is attributed to this result.

On 2026-10-08 the production-signed ARM64 1.5.0+4106 candidate (Core 1.2.9)
was installed on the Huawei Android 12 main profile, where POKROV was already
absent. The shared package recorded 1.4.5+4086 in a stopped secondary profile;
Android updated the shared code while that profile's data stayed untouched. Main
app data was fresh, and ordinary onboarding showed five days of trial access;
this does not establish a new server account. The first Beeline LTE Auto attempt
exhausted selection with CONN-008 before VPN permission. Preparation versus native
probe failure remains unknown; the initial DNS warning does not establish cause.
Distinct Wi-Fi Auto selected CH, followed by ordinary Android VPN consent. CH, DE
and US then passed normal tunnel/DNS/egress checks across Wi-Fi and LTE; DE on LTE
was reached by automatic handoff. Wi-Fi to LTE and back retained the VPN, but an
exact recovery deadline was not measured. The owner opened new ya.ru and
pokrov.space pages in Russia-direct mode and a new ya.ru page after Stop.
Final Stop removed the VPN, tun0 and its routes; Auto and original Wi-Fi-off,
mobile-data-on settings were restored. No app cache/session or server trial was
reset. Update preservation from the absent main-profile version was not tested.

An ordinary activity exit and reopen left the running VPN healthy but lost its
location label. The host now supplies displayNodeCode only from the stored profile
matching the healthy effective digest. This is display metadata, without candidate,
lease or upstream profile authority. Physical verification passed on production-signed ARM64 1.5.0+4107: the update
from 4106 preserved the main profile's data inode, UID, access and preferences.
One DE/Wi-Fi connection remained protected while the activity exited to the
launcher; reopening restored Frankfurt in Home and normal Diagnostics with
healthy tunnel/DNS/egress checks, without another Connect. Final Stop removed
VPN/tun0/routes; Auto and the original network settings were restored. The first
4106 LTE Auto failure and CH LTE 25.735-second connect remain unresolved; their
prepare/native stages were not delivered. No release or full physical acceptance
is inferred from this targeted fix check.
Run Flutter analyze/tests for changed packages and both
`testDirectDebugUnitTest` and `testStoreDebugUnitTest` for Android host
changes. A local APK build or emulator run does not close the Huawei checks.
