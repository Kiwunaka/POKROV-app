# Android 1.2.0 acceptance

Target: `1.2.0+4055`, direct APK, POKROV Core 1.1.0. Current public version
is 1.1.6. Use LDPlayer for interim checks; physical-device checks remain open.

The x86_64 direct 4055 APK was installed in a fresh LDPlayer instance. It
started, created a trial, and received Android VPN permission. DE and CH both
failed the protected-egress check, after which the app removed the system VPN.
This is an observed LDPlayer result, not a pass for Android connectivity.

The published x86_64 1.1.6 APK (build 4029) also failed its CH protected-egress
check in a separate fresh LDPlayer instance. Different instances and trial
accounts make that comparison insufficient to assign the 4055 failure to the
client or to LDPlayer.

On the Huawei device, update over 1.1.6, grant VPN permission, and connect to
CH plus two other nodes on Wi-Fi and Beeline LTE. Verify “everything except
Russia”: a Russian site opens directly and a foreign site uses VPN. Switch
Wi-Fi to LTE and back while connected. After disconnect, ordinary internet
must work. Record any failed step against the exact installed package.

Run Flutter analyze/tests for changed packages and both
`testDirectDebugUnitTest` and `testStoreDebugUnitTest` for Android host
changes. A local APK build or emulator run does not close the Huawei checks.
