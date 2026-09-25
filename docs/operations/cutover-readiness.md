# Client 1.2.0 release status

Public version: **1.1.6** in GitHub Releases. Working target:
**1.2.0+4054** with POKROV Core 1.1.0. The new target is not published.

The client source and local Core artifact binding are in `main`. A local
build proves compilation only; device and account checks below must run on the
same final package before publication.

| Check | Current state |
| --- | --- |
| Android update over 1.1.6, VPN permission, CH plus two other nodes on Wi-Fi and Beeline LTE | Not run on 4054 |
| Android “everything except Russia”, Wi-Fi/LTE switch, internet after disconnect | Not run on 4054 |
| Windows clean install and update over 1.1.6, connect/disconnect, connected reboot, uninstall | Not run on 4054 |
| New account, trial, connection; expired account, renewal and provider invoice creation | Not run on 4054 |
| Hiddify and Happ subscriptions on CH and another node | Not run on 4054 |

After those checks, publish Android APK and unsigned Windows beta through the
existing `Kiwunaka/pokrov` release-index flow. Public announcement text needs
owner approval. Rollback points the release index back to the retained 1.1.6
release assets. Do not claim release completion before the package reaches
users and 48 hours pass without critical reports.
