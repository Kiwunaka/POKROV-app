# Android 1.2.0 acceptance

Target: `1.2.0+4055`, direct APK, POKROV Core 1.1.0. Current public version
is 1.1.6. Use LDPlayer for interim checks; physical-device checks remain open.

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

The owner deferred physical-phone testing. When resumed, on the Huawei device
update over 1.1.6, grant VPN permission, and connect to
CH plus two other nodes on Wi-Fi and Beeline LTE. Verify “everything except
Russia”: a Russian site opens directly and a foreign site uses VPN. Switch
Wi-Fi to LTE and back while connected. After disconnect, ordinary internet
must work. Record any failed step against the exact installed package.

Run Flutter analyze/tests for changed packages and both
`testDirectDebugUnitTest` and `testStoreDebugUnitTest` for Android host
changes. A local APK build or emulator run does not close the Huawei checks.
