# Integrated Windows connected update — 2026-09-08

**PASS_BOUNDED_CONNECTED_UPDATE** for the integrated local Windows installer
`83c253ce…6063`, client `3784352` / Core `02a091c`. This closes the connected
update slice for those bytes, not the full W03 or final release gate.
[Receipt, exact identities, commands and evidence hashes](receipt.json).

The isolated Windows 11 Enterprise Evaluation VM first installed retained
client `e88dff9`, setup `29a87a13…beea`; all 305 files matched. Both packages
are `1.2.0+4053`, so this is a source-package replacement rather than proof of
version-number migration. The integrated client `7ae931b` has no subsequent
apps/packages/config/scripts/pubspec changes relative to the installed source.

The ordinary desktop UI connected before setup. The retained service probe
reported running/Core/DNS ready and one active TUN; owned HTTPS health returned
200. Setup's Restart Manager offered to close POKROV, then completed on the
first attempt. Before relaunch, all 305 current file hashes matched, both saved
session and experience files were byte-identical to the immediate preinstall
snapshot, routes/DNS matched the disconnected baseline, and no restart was
required. The current UI launched, connected and disconnected again; final
305-file verification, saved-session identity and route/DNS restoration passed.
The diagnostic probe's `client_source=0218e89` describes that helper only.

There were zero new Defender 1116/1117 records between the before/after
observations; antivirus and real-time protection were enabled. Earlier behavior
detections are retained and unresolved. This run does not prove all AV paths.

External egress hashes did not change from baseline. These observations prove
running TUN and reachability, not independent egress/leak or a protocol-specific
route. The UI continued to show unknown access status. After the final
disconnect, the standard lab selector refused restoration because its target
no longer satisfied entitlement ownership. `restore.json` retains that refusal.
A configuration-only rollback required the exact post-enable configuration
hash, reconstructed the exact original hash, rechecked for concurrent changes,
and used the existing admin action-intent guard. `restore-config.json` confirms
full original configuration restoration; entitlement and material were untouched.
This ownership change is not an executed expiry/revocation acceptance scenario.

Cleanup: UI exited, VPN stopped, guest routes/DNS restored; VM gracefully shut
down and NIC set to none. Source VM stayed off and host route/DNS hashes matched.
No production deployment, release artifact mutation, publication or promotion.

W02 sleep remains unavailable (`powercfg /a`: firmware supports none). Win10,
full W03 standard-user clean install/uninstall/reinstall on these bytes, final
channel and independent network acceptance remain open. Historical receipts
retain their own package identities.

Verification: `pwsh -NoProfile -File scripts/validate-seed.ps1 -PlatformRoot
C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot
E:/r12core-implementation` and `pwsh -NoProfile -File test/docs-contract.ps1`
passed. All 28 retained evidence hashes/sizes and JSON parsing passed.
`git diff --check` passed; no `artifacts/releases/**` diff. Product code and
concurrent generated registrants were not changed by this evidence task.
