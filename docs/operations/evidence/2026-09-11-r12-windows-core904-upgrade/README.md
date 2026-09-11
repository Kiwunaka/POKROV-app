# Windows Core 904 connected upgrade — 2026-09-11

Status: `PASS_BOUNDED_INSTALLED_UPGRADE`. Origin: current-origin owned Windows 11
VM, bridged network. This is an upgrade of the existing test account, not a
clean standard-user installation, Win10 or public distribution acceptance.

## Exact package

- Installed client `a24b211f9c1c4bf83bb5fde9b8a9c98185ea1028`, Core
  `904e440aca98cb6419744c5c04c83223a6d6380e`, local version `1.2.0+4053`.
- Setup SHA-256: `cf28fed53f3e3b9bbe2449a070a6736213265de7c6032f2761339a3903a48e17`.
- Before upgrade, client `e18fa60` / Core `c8b0461` was connected with successful
  Core/DNS/egress and matching staged/effective profile. The ordinary wizard
  used Restart Manager to close the running UI and completed installation.
- All 304 installed files match [the package inventory](expected.json), both
  immediately after installation and after both connection cycles. The wizard
  preserved the exact state and encrypted secure-store bytes. No profile or
  credential content is retained here.

## Observed behavior

[Receipt](receipt.json) indexes all captured hashes. [Wizard readback](wizard-readback.json)
and [completion screenshot](wizard-completion-check.png) prove the installation.
The LocalSystem service is running; its ACL matches before upgrade and does
not grant mutation to broad groups. The separate ordinary UI launch has a
measured `TokenElevation=false` and no loaded Core DLL; [token readback](limited-token.json).
The post-wizard launch used installer context and is not reused as this proof.

Both post-wizard and limited-UI cycles connected through the installed service,
reported Core/DNS/egress ready and matching staged/effective profile, completed
ten owned HTTPS marker requests, and observed positive TUN byte deltas. NIC
counters include ambient guest traffic; they do not attribute each request.
After each explicit disconnect, exact route/DNS hashes returned to the initial
guest baseline. Host route/DNS hashes also remain unchanged. The VM is powered
off with NIC disabled and all eleven earlier snapshots preserved.

The diagnostic `r12_managed_probe.exe` is a retained test helper whose output
contains its own source `0218e89`. Application identity is established by the
independent 304-file readback, not that helper field.

## Defect found and source correction

Both successful disconnects displayed a yellow retry button and “Настройки
POKROV готовы.” despite `config_staged`, `running=false`, `failure=none` and
restored networking; [limited UI screenshot](disconnected-limited.png).
The source assigned the successful runtime message to the recovery notice.
The existing Windows service-loss widget test now checks the ordinary Connect
subtitle after a successful disconnect. It failed before the change and passed
afterward; three focused disconnect/repair tests and app_shell analysis pass.
Source commit `77427ea`, signed source `b0aa9ef`, PR112 carry the correction.
This installed `a24b211` package still contains the UI defect. No new package
was built or distributed for the correction in this slice.

## Commands and limits

Guest helpers retained here: `verify-wizard-current.ps1`, `network-original.ps1`,
`tunnel-traffic-original.ps1`, `read-limited-token.ps1`, `final-readback.ps1`.
They were copied/executed with the existing managed VM control wrappers.
Wizard steps and the tray exit used the VirtualBox console and observed UI.
Two limited synthetic click attempts did not activate the post-wizard UI;
console input succeeded. No process was forcibly terminated.

`flutter.cmd test test/pokrov_seed_app_test.dart --name 'windows observes service loss|protection repair runs|repair warns before disconnect'`
passes 3 tests; `flutter.cmd analyze` reports no issues. Exact-Core seed and
docs contracts pass after correcting the previously retained ZIP placement.
Its 52 entries and original ZIP are preserved in the [materialized older evidence](../2026-09-11-r12-utls-file-attribution/package-evidence/README.md).

Win10, clean-user install, uninstall/reinstall, WARP, Android, final public
channel and trusted signing remain unproven here. This evidence does not close
the full W01/W03/N03/C05 or release scope. Disk usage is checked separately;
no cache deletion or new runtime build is part of this result.

## Source delivery

PR112 merged `5d5264f15cfb2eeee82d16c155f9847a5e3c3095` from signed `b0aa9ef6c8a4b57f3ec822b2d6b8576aecc2d002` with
the identical tree. [PR CI](client-ci-pr.json) and [merge CI](client-ci-merge.json)
passed. [Validation](validation.json) retains the original failed UI regression,
the final three tests, clean analysis, seed/docs checks and the earlier ZIP
placement failure. The corrected UI is in source; no new binary was built.
