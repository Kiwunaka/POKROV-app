# Android 1.2.0 acceptance

Target: `1.2.0+4055`, direct APK, POKROV Core 1.1.0. Current public version
is 1.1.6. Use LDPlayer for interim checks; physical-device checks remain open.

On the Huawei device, update over 1.1.6, grant VPN permission, and connect to
CH plus two other nodes on Wi-Fi and Beeline LTE. Verify “everything except
Russia”: a Russian site opens directly and a foreign site uses VPN. Switch
Wi-Fi to LTE and back while connected. After disconnect, ordinary internet
must work. Record any failed step against the exact installed package.

Run Flutter analyze/tests for changed packages and both
`testDirectDebugUnitTest` and `testStoreDebugUnitTest` for Android host
changes. A local APK build or emulator run does not close the Huawei checks.
