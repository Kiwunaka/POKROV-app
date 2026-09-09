# Huawei always-on system start correction

Document class: EVIDENCE. 2026-09-10 MSK / 2026-09-09 UTC.

## Defect and change

On Huawei ADA-AL00U, Android 12/API31, the actual system always-on switch started
the service on the previous `c05b58b` APK, but three observations found neither a
foreground service nor a TUN. The service handled only the app START action.
The original [permission and lockdown run](../2026-09-10-r12-huawei-permission-lockdown/README.md)
retains this failure, successful revoke/deny/regrant, and bounded excluded-UID
traffic blocking. Those observations belong to the earlier APK.

Client integration `b220e12` / signed source `c691c708e9a3bf0e46451eb40481aaea670dc449`
restores the already confirmed, digest-bound profile for Android system starts.
The existing foreground connection path still verifies actual profile contents.
Missing or unconfirmed profiles fail closed; duplicate system starts preserve an
active or pending connection. The Android instructions explain that lockdown
also blocks apps outside selected-app routing. Core bytes and dependencies are unchanged.

## Package and physical system-start result

Four production-signed local packages passed signature, version, ABI, Core and
notice audit. Version 1.2.0+4053, minSdk24, targetSdk36; none is debuggable.
The ARM64 package is 101229131 bytes, SHA-256
`03924eee799e15b1e1486646331de832d46bb5857fcfbf94d414afb6ff36847c`.
Core source is `c7a11f7d2fd974726095ad7aa0619c055273dd15`.

`adb install -r` replaced the previous APK with the exact new bytes and the same
signer. The actual old APK was pulled and hash-verified for rollback. App data
was not cleared. Frankfurt, selected apps and active-access presentation were
retained; this is visible context, not an independent raw account identity check.
The package-audit and installation receipts intentionally retain their then-pending
runtime fields; the later system-start receipt supplies those observations.

After force-stopping the app, enabling the actual Huawei always-on switch created
a foreground VPN service and tun0 in all three samples around 1, 5 and 15 seconds.
No app Connect button was used. Opening the app subsequently observed the tunnel;
refreshing its protection sheet confirmed tunnel, DNS and VPN egress.
**PASS_SYSTEM_START_WITHOUT_APP_CONNECT** on these exact APK bytes.

## Verification and initial pending evidence

- Gradle `:app:testDirectDebugUnitTest :app:testStoreDebugUnitTest`: 188 tests per
  flavor, zero failures, errors or skips.
- Flutter app_shell analysis: no issues. Android settings navigation: one test
  PASS. Focused runtime, permission, profile staging and 100 serial host bridge
  cycle checks: eight tests PASS.
- Client seed/docs contract and diff check PASS before physical follow-up.
- Clean signed source build and four-package audit PASS; tested source paths
  match integration. Build logs and original packages remain outside Git.
- PR96 exact-source CI: PASS, run34412162097. Main promotion remains pending.
- Connected always-on reboot was sent at the recorded time. Owner manual unlock,
  pre-activity service/TUN observation and final settings restoration are PENDING.

No public client channel or artifacts/releases content changed. Backend remains
`6b34dfd`; this device result does not accept the entire D03 OEM/API, battery,
long-session or final-release matrix.

[Receipt](receipt.json) and [system-start result](alwayson-system-start-result.json)
retain exact identities and observations. Device helpers are linked from the earlier
[Huawei evidence](../2026-09-10-r12-huawei-current/README.md); private profile and raw UI data are not retained.

Documentation validation: `pwsh.exe -File scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot E:/r12core-implementation` — PASS; [log](client-seed.log). `git diff --check` PASS, no release-artifact delta.

## Completed reboot follow-up

After the owner manually unlocked and reconnected USB, a new boot identity,
foreground VPN service and tun0 were observed before the runner opened the app.
The runner did not press Connect. [Native result](alwayson-after-unlock-result.json):
**PASS_AUTOMATIC_AFTER_REBOOT_NATIVE**, 2026-09-09 22:59:31 UTC. This records
the runner's actions; it does not attest to unobserved actions outside the runner.
The subsequent app protection refresh confirmed tunnel, DNS and VPN egress.

Disabling the actual always-on system switch stopped the service and removed
the TUN. Always-on and lockdown are now OFF; Frankfurt, selected apps and exact
APK identity remain unchanged. All seven [restoration checks](alwayson-postboot-result.json)
passed at 23:00:44 UTC. No preboot route identity claim is made.

PR96 merged as `ead081fbeb3831dc9aeda289ffcee51bbe01023c`; exact merge CI
run34414964728 PASS. [Binding](alwayson-merge-binding.json) verifies both signed
commits have the same tree. The pending observations above describe the earlier
checkpoint and are superseded by this follow-up. Public release bytes remain unchanged;
full D03 acceptance remains open. The phone was returned to the owner.

Postboot documentation validation: same `validate-seed.ps1` command PASS; [log](postboot-client-seed.log). All 27 retained file hashes verified; no release-artifact delta.
