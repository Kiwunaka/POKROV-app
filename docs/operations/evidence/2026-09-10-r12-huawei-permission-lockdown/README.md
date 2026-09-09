# Huawei VPN permission and lockdown, before always-on correction

**PERMISSION_AND_LOCKDOWN_BOUNDED_PASS_ALWAYS_ON_START_FAILURE**, 2026-09-10 MSK.
Installed client `c05b58b`, Core `c7a11f7`, ARM64 `d030288a…f510`; backend `6b34dfd`.
[Receipt](receipt.json) binds the retained run. No account, node or artifact mutation.

Forgetting only POKROV in Android VPN settings while connected revoked its VPN
permission, removed service/TUN, and exactly restored route/rule hashes. The app
showed disconnected status and offered connection again. Its system VPN consent
dialog was observed. The first dialog closed and a connection appeared outside
the runner's recorded grant action; that transition is not attributed to an
agent or owner action. A second explicit revoke repeated the consent boundary.

The runner cancelled that dialog. The app presented a permission explanation,
failed-connection status, Retry and Allow VPN actions, with no service/TUN.
Allow VPN opened the existing recovery explanation; Repeat request reopened
Android's `com.android.vpndialogs` dialog. A fresh-tree OK tap restored foreground
VPN/TUN, and the protection sheet confirmed tunnel, DNS and VPN egress.
Disconnect restored exact routes/rules and the original APK/package metadata.

The initial denial harness expected Connect instead of Retry and stopped after
successfully cancelling. The next harness expected an immediate system dialog,
but the app first shows its recovery explanation. v4 followed that visible flow.
These harness assertions are not app failures and are not counted as passed runs.

In Huawei settings, only the row's switch is clickable; tapping the text leaves
always-on off. After the actual switch tap, all three samples (about 1/3/10s)
showed POKROV selected as always-on and an existing service, but no foreground
service or TUN. The installed source ignores system `android.net.VpnService` /
unflagged start commands. This is the reproduced product defect, not a full
always-on pass. [Android's lifecycle guide](https://developer.android.com/develop/connectivity/vpn)
requires the service to connect and enter foreground after system startup.

System lockdown was then enabled through its confirmation dialog. A task-local
Java HTTPS request to the owned public `https://pokrov.space/__build.json` ran as
shell UID 2000. It returned 200 before lockdown, failed with UnknownHostException
without a tunnel, remained blocked with selected-app VPN active, and remained
blocked after disconnect. POKROV's own protection check passed while connected.
UID 2000 is outside the selected-app list; this proves that bounded blocked path,
not routing/leak behavior for every installed app. After disabling both settings,
the same request returned 200 with the original body hash. The first HTTP helper
limit was too small for the 155573-byte public metadata; it was increased before
any successful baseline. It did not test network blocking before that correction.

Final cleanup stopped the lingering system-started idle service, relaunched the
app and verified no service/TUN, exact baseline routes/rules, same APK/package,
Wi-Fi/mobile and Frankfurt selection. Always-on returned to null; lockdown is
now explicit 0 rather than its initial unset value, with the same disabled effect.
No raw UI XML, credentials, connection profiles or customer/provider data retained.
The shared [device/tree collector](../2026-09-10-r12-huawei-current/README.md) is reused.

D03 remains open. The always-on start correction needs its own exact new-build
physical proof; permission/lockdown results here belong to the old installed APK.

Documentation check: `pwsh.exe -File scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation` — PASS including client docs contract; [log](client-seed.log). `git diff --check` passed; no release-artifact delta.
