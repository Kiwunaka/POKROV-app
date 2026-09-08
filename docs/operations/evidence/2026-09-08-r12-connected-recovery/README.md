# Installed Windows connected recovery — 2026-09-08

PASS_BOUNDED for forced UI termination/relaunch and graceful connected reboot
on the existing Win11 lab VM, client `6fc1e84` / Core `8dc57a8`. The unchanged
v3 package is bound by the [upgrade receipt](../2026-09-08-r12-upgrade-managed/receipt.json);
the [new receipt](receipt.json) retains 21 observations/scripts, original hashes
and the precise limits. This is a local test package, not a release candidate.

With the exact test installation temporarily assigned to AWG3.1, terminating
the sole installed UI process left service PID 2888 unchanged. IPC still
reported running, Core/DNS/egress readiness and matching staged/effective
identity; one TUN and health 200 remained. Relaunching the unchanged UI observed
that running connection. The retained screenshot shows connected status,
location verification and unresolved access status.

Windows then rebooted normally while the service remained connected. New boot
time was `2026-09-08T01:29:47.5000000Z`; the automatic LocalSystem service was
Running with PID 3140. At `01:30:00Z`, IPC reported `artifact_ready`, no running
connection, no effective protection and no failure. TUN count was zero, health
was 200, and route/DNS hashes exactly matched the pre-connect baseline. All
305 installed package files matched before and after reboot.

UI termination is not service-process crash proof. The current guest-control
token is not elevated; forced service termination was not executed. VirtualBox
firmware exposes no supported sleep/hibernate state (`power-states.txt`), so
sleep/resume remains BLOCKED_BY_ACCESS. The reboot was graceful, not abrupt
power loss. Protected journal state and post-reboot UI reconnect were not read
or exercised. Identical baseline/connected external IP hashes still prevent an
independent route claim; the prior DE SSH trust gate is unresolved.

Executed: guarded test-install `lab-control.py` binding; guest
`ui-termination.ps1`, `recovery-launch-ui.ps1`, `network.ps1` snapshots,
`final-identity.ps1` before/after, and `shutdown.exe /r /t 15`; then guarded
`lab-control.py restore --label restore-original`, guest shutdown and clone
NIC restoration after confirming poweroff. The receipt records exact commands
and the local controller hash. Diagnostic `--help` returned unsupported-action
exit 33 through the guest runner; no mutation or acceptance credit came from it.

Cleanup PASS: complete original rollout-config hash restored, endpoint material
and entitlement unchanged, guest route/DNS baseline restored, host route/DNS
hashes unchanged, clone powered off with NIC none. Original VM and rollback
snapshot remain preserved. The existing diagnostic probe remains unchanged on
the offline clone. No source behavior changed; no build, candidate creation,
push, merge, deployment, publication or payment operation occurred.

W01/W02/W04 advance only for these bounded observations. Full service crash,
sleep, network handoff, post-reboot reconnect, WFP, IPv6, Win10 and exact final
candidate acceptance remain open.
