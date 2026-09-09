# Huawei — new Core ARM64 installation and network handoff

**PASS_BOUNDED**, 2026-09-08, Android 12/API31, HUAWEI ADA-AL00U.
The [receipt](receipt.json) binds client `76614b1` / Core `02a091c` to
the 101,229,131-byte ARM64 APK, SHA-256
`0206cd2a0d76ae427a988bc2220af8f2157d5c153c212cbdcaa3338cf89b41ce`.
This is the previously prepared local package, not a new published candidate.

`apksigner verify --print-certs` confirmed the previous and new APK signer.
SDK ADB `install -r` returned Success; on-device `sha256sum` matched the new
APK before runtime checks and again at the end. VersionCode remains 4053:
this is a same-version replacement, not the full version/channel update gate.
The previous APK is retained at the path and hash in the receipt for rollback.
No application-data clear, uninstall, permission reset or account change ran.

Warsaw whitelist location, Russia-direct routing and WARP off remained visible
before/after update and at the end. The original first-install time remained
unchanged. This proves bounded preference continuity; it does not independently
compare account identity or every saved value.

The ordinary managed profile connected on Wi-Fi. The protection panel reported
confirmed tunnel, DNS and VPN egress. During Wi-Fi disable → mobile refresh →
Wi-Fi restore/refresh, all four native samples retained process 32300 and the
foreground VPN service. Both refresh screenshots showed confirmed protection.
These app observations are not independent packet/leak/route proof. The broad
transport-type list in the raw readback includes Android network requests and
must not be interpreted as a list of active networks.

After handoff and disconnect, the route hash matched the original. The global
policy-rule hash differed; the original per-line state was not retained, so
complete rule restoration across that handoff is **UNPROVEN**. A separate
Wi-Fi connect/disconnect then restored exact route and rule-line hashes, with
TUN and foreground VPN service present while connected and absent afterwards.
Its protection panel also confirmed tunnel/DNS/VPN egress. This second pass
does not erase the earlier rule-hash difference.

The read-only AWG binding preview selected a label-matching record reporting
app 1.0.8 and last seen about 24 days earlier, then rejected ownership/entitlement
resolution. That record was not accepted as the current installed client.
No binding, entitlement, cohort or server configuration was changed. Exact
AWG device binding and installed AWG2/AWG3.1 acceptance remain open.

Final state: new ordinary-API ARM64 APK installed, Wi-Fi and mobile data enabled,
VPN disconnected, no `tun0`, retained location/routing/WARP preferences.
No release publication, push, merge or backend deployment was performed.
IPv6, UDP53, AWG MTU, Doze/battery, independent origins and the full D01/D02/F07
and release matrices remain open.

Retained commands/scripts, JSON and screenshot hashes are listed in the receipt
under `E:/r12-android-device-20260908`. System ADB v32 initially corrupted a PNG
stream; SDK ADB v41 produced valid PNGs after the server restarted and the phone
reappeared. Accessibility hierarchy dumping returned no root. The first
reconnect preflight could not read `ip link` under the normal shell; it stopped
before connecting. The corrected readback used `/sys/class/net`.

Documentation validation: `pwsh -NoProfile -File scripts/validate-seed.ps1
-PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start
-CoreRoot E:/r12core-implementation` PASS; `test/docs-contract.ps1` PASS;
scoped links and `git diff --check` PASS. The first seed invocation omitted
worktree paths; the second used Windows PowerShell without `SHA256.HashData`.
Both failed setup attempts are retained separately from the successful Core
PowerShell run. No product test or release-artifact bytes changed in this record.
