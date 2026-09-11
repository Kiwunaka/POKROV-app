# R12-L04 — exact signed desktop package, partial acceptance

Package `1.2.0~beta.30-7`, SHA-256
`5fadf99660301b7456e8e0b133b90921b807b992fc58fb27af92183ebc81154d`,
passes clean installation, non-root GUI/polkit, installed permissions,
connected upgrade, rollback and connected uninstall/purge on the recorded
Ubuntu 24.04.4 amd64 Xfce/X11 guest. **L04 remains open:** intermittent TLS
failures occurred during full-mode traffic probes. Later passing connections
do not establish their cause or resolve them.

The [receipt](receipt.json) binds the exact package, source associations,
environment, results and limitations. This is isolated `pokrov-mini` guest
evidence, not RU-origin or public Linux release acceptance. Current package
crash/suspend/reboot proof is now retained below, separately from older L03
binary evidence.

| Check | Result | Evidence |
| --- | --- | --- |
| Native build, package contents, unit and signatures | PASS | [UI build](l04-client-build-08.json), [package audit](candidate7-package-audit.json), [native signatures](native-signature-verification.json) |
| Clean install, package/state previously absent | PASS | [Install](clean-install.json), [APT log](clean-install.log) |
| UID 1000 GUI and production polkit/PAM approval | PASS | [Desktop](candidate7-desktop-environment.json), [first frame](clean-candidate7-first-frame.png), [prompt](clean-candidate7-auth-prompt.png), [closed daemon events](candidate7-daemon-events.json) |
| Root-owned files/socket/unit; state remains 0700 after activation | PASS | [Permissions](candidate7-installed-permissions.json), [upgrade activation](candidate7-connected-upgrade.json) |
| RU direct path versus full-device path | PASS for observed connections | [RU TCP/SSH](candidate7-ru-route-proof.json), [RU sampled sockets](candidate7-ru-443-sampled-route-proof.json), [full sampled sockets](candidate7-full-443-sampled-route-proof.json), [selected full mode](clean-candidate7-full-selected.png) |
| DNS resolution and IPv4-only plan's IPv6 rejection | PASS for observed connections | Both sampled route receipts above |
| GUI disconnect and recovery-record removal | PASS | [After RU](candidate7-after-ru-disconnect.json), [after full](candidate7-after-full-disconnect.json) |
| Rollback to signed lower-version fixture | PASS | [Rollback](candidate7-rollback-to-baseline.json), [same-payload audit](candidate7-baseline-audit.json) |
| Upgrade while runtime continues after UI exit | PASS | [Upgrade](candidate7-connected-upgrade.json), [APT log](candidate7-connected-upgrade.log), [restored UI](clean-candidate7-after-upgrade-state.png) |
| Remove and purge while connected | PASS | [Uninstall](candidate7b-connected-uninstall.json), [APT remove/purge log](candidate7b-connected-uninstall.log) |
| Profiles, six settings files and two keyring files retained | PASS, byte-for-byte | Rollback, upgrade and uninstall receipts above |
| Original IPv4/IPv6 routes/rules, nft, DNS and domains restored | PASS, all seven hashes equal | Upgrade and uninstall receipts above |
| Current package Core/daemon crash, foreign-rule preservation and partial rollback retry | PASS | [Recovery](candidate7-live-recovery.json) |
| Actual suspend/resume and reconnect | PASS | [Guest](candidate7-sleep.json), [QMP suspend/wakeup](candidate7-sleep-qmp.json) |
| Connected native reboot and reconnect | PASS | [Guest](candidate7-reboot-native.json), [same QEMU PID](candidate7-reboot-native-qmp.json), [terminal state](candidate7-recovery-terminal.json) |
| Full-mode HTTPS consistency | UNRESOLVED | [First TLS failure](candidate7-full-443-sampled-route-proof.json), [four failures in six requests](candidate7-connected-uninstall.json), [no-VPN control](candidate7-no-vpn-http-control.json), [later six passes](candidate7-full-http-diagnostic.json), [another six passes](candidate7b-connected-uninstall.json) |

The lower-version package is a deliberate upgrade fixture with the same 334
payload entries except its version declaration. It is not a previous public
Linux release. This revision introduces no Linux profile schema migration;
version-1 session/settings, private profile and secure keyring continuity were
checked across both package directions and purge.

Observed defects led to the current source: unsupported observability
startup prevented the first frame; API metadata reached Core without
materialization; the shared UI timeout expired before Linux authorization;
IPv6 reject-route cleanup did not recognize native type 7 on `lo`; full mode
retained RU exceptions; and systemd reset the state directory to 0755.
The corresponding fixes are `d43862c`, `77c4d5d`, `19c480c`, `2e0d784` and
`a9999f4`. The UI was built at `2e0d784`, the daemon at `19c480c`, and Core at
`97ec91e`; package revision `a9999f4` changes the unit only. The build manifest's
`UNSIGNED` field describes assembly; the separately retained detached-signature
receipts verify the final unchanged bytes.

The first RU port-443 observation checked too early and missed the direct
socket. An SSH-banner probe and repeated observations over eight seconds
confirmed it. One uninstall observer expired before a connection was approved;
it performed no package operation. These records remain retained. The failed
full-mode HTTPS run likewise stopped before uninstall. Two later connections
passed six requests each; their recorded primary transport/SNI fingerprints
differ, so they do not prove the same path recovered.

After connected purge, the exact signed package was [reinstalled](candidate7-reinstall-for-recovery.json) with the retained profile unchanged. Root-peer
recovery fixtures then exercised the installed binaries without an API refresh;
this is separate from the real non-root GUI/polkit proof. Core and daemon
SIGKILL, same-priority foreign-rule preservation, partial rollback retaining
the filter/journal/profile, exact fault removal and retry all passed. Sleep
entered actual QMP `suspended`, resumed in the same boot and restored all seven
raw network hashes after 6.59 seconds. Connected native reboot changed the
boot ID while keeping QEMU PID 1908675, then restored the original network.
Both paths reconnected and retained the exact private profile bytes.

The [first reboot run](candidate7-reboot.json) ended QEMU because the original
VM had `-no-reboot`. [Its restart receipt](candidate7-reboot-qemu.json) records
the verified absent old process, same retained disk and removed harness flag.
That recovery passed; the separate second native reboot above proves normal
in-process VM reboot. Across crash, sleep and both reboot observations, all
24 HTTPS marker requests returned HTTP 204. They use one unchanged profile
and do not resolve the earlier failures on unidentified transport paths.

The daemon still reports DNS/egress health as unknown. The GUI screenshot's
checking state is not validated-health proof. No production grant override,
public artifact publication, source promotion or final release decision is
claimed here. Raw profiles, credentials and provider data are absent from this
evidence; [retained-files.json](retained-files.json) indexes the public files.
