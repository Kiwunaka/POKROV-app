# Client 1.2.0 release status

Public version: **1.1.6** in GitHub Releases. Working target:
**1.2.0+4055** with POKROV Core 1.1.0. The new target is not published.

The client source and local Core artifact binding are in `main`. A local
build proves compilation only; device and account checks below must run on the
same final package before publication.

| Check | Current state |
| --- | --- |
| Android update over 1.1.6, VPN permission, CH plus two other nodes on Wi-Fi and Beeline LTE | Fresh x86_64 4055 install on LDPlayer created a trial and received VPN permission; CH and DE failed protected-egress verification. Published x86_64 1.1.6 also failed CH and DE in a separate instance. Update and physical-network checks remain open. |
| Android “everything except Russia”, Wi-Fi/LTE switch, internet after disconnect | Not run on 4055 |
| Windows clean install and update over 1.1.6, connect/disconnect, connected reboot, uninstall | Exact 4055 installer updated over 4054 on the owned VM; DE connected and disconnected. Clean install, 1.1.6 update, reboot and uninstall remain open. |
| New account, trial, connection; expired account, renewal and provider invoice creation | A trial was created on LDPlayer with 4055; connection failed. Expired-account and payment checks were not run. |
| Hiddify and Happ subscriptions on CH and another node | Not run on 4055 |

After those checks, publish Android APK and unsigned Windows beta through the
existing `Kiwunaka/pokrov` release-index flow. Public announcement text needs
owner approval. Rollback points the release index back to the retained 1.1.6
release assets. Do not claim release completion before the package reaches
users and 48 hours pass without critical reports.
