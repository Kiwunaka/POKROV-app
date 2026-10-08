# Android 1.2.0 acceptance

Published version: `1.2.0+4061`, direct APK, POKROV Core 1.1.0. Current
Huawei acceptance is recorded in `cutover-readiness.md`. The 4055 emulator
results below are historical; LDPlayer is not used for VPN acceptance.

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

Physical 1.5.0 acceptance begins when the owner connects the Huawei device.
First record its actual installed version, UID and first-install time privately;
update once with the current production-signed ARM64 APK using `adb install -r`,
without clearing data or restoring an old session/cache. Confirm the version,
preserved account/access/settings and Core version in normal Diagnostics. Grant
VPN permission normally if requested. Run ordinary Auto on Wi-Fi and Beeline LTE
for CH and two other currently available nodes; confirm TUN/routes/DNS/egress and
“Russia directly” with a Russian and a foreign service. While connected, switch
Wi-Fi to LTE and back, then Stop and verify VPN/routes cleanup and ordinary
internet. Keep existing logs and use normal Diagnostics for any failed step;
repeat only behavior changed by a subsequent fix. Build checks alone do not
accept this physical sequence.

Run Flutter analyze/tests for changed packages and both
`testDirectDebugUnitTest` and `testStoreDebugUnitTest` for Android host
changes. A local APK build or emulator run does not close the Huawei checks.
