# L02/L03: installed runtime and authorization acceptance

`VERIFIED / I4` for the declared conditional Ubuntu 24.04 amd64 L02/L03
requirements. The [receipt](receipt.json) binds each criterion to installed
package 8, unchanged runtime components and the retained package-7 recovery
observations. This does not close L04 or authorize a public Linux claim.

Current package: `1.2.0~beta.30-8`, SHA-256
`b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933`.
Environment: the same retained Ubuntu 24.04.4 amd64 Xfce/X11 guest on MINI,
not RU-origin. UI PID 1648 runs as UID 1000. Daemon source remains `19c480c`,
Core `97ec91e`; current daemon, systemd and polkit Git subtrees match their
build inputs exactly. Core promotion and source-distribution obligations
remain separate release gates.

## Current package authorization

| Action | Native result | Evidence |
| --- | --- | --- |
| Leave the real graphical password prompt unanswered | `linux_authorization_timeout`; no network mutation | [Observer](candidate8-auth-timeout.json), [prompt](candidate8-auth-timeout-prompt.png), [UI afterwards](candidate8-auth-timeout-after.png) |
| Click Cancel in the real graphical prompt | `linux_authorization_dismissed`, outcome denied | [Observer](candidate8-auth-cancel.json), [prompt](candidate8-auth-cancel-visible.png) |
| Stop the exact desktop agent, then connect from the same UI | `linux_authorization_agent_unavailable` | [Agent stop](candidate8-auth-agent-stop.json), [observer](candidate8-auth-missing-agent.json), [UI afterwards](candidate8-auth-missing-agent-after.png) |
| Connect from a separate inactive SSH session as UID 1000 | Generic IPC `linux_authorization_denied`; native denied event | [IPC response](candidate8-auth-inactive-response.json), [final events](candidate8-auth-final.json) |
| Restart the stock agent in the desktop session | Agent PID 10886, UID 1000; prompt appears again and is cancelled | [Prompt after restoration](candidate8-auth-agent-restored-visible.png), [final readback](candidate8-auth-final.json) |

All three GUI observers ended with MainPID 0, Result success, ExecMainStatus 0.
Each retained its original profile bytes and all seven route/rule/nft/DNS/
domain hashes. No TUN or recovery record appeared. No password was entered.
The polkit action file matches the signed payload, and no temporary action
override exists. Root processes only observed these GUI actions. The inactive
request used the real unchanged `allow_any=no` / `allow_inactive=no` policy.

The timeout's exact request-start time was not separately captured; its native
timeout code and source's 60-second deadline are distinct evidence. The first
attempt to restart the agent through AppFinder opened its file location;
the subsequent desktop terminal launch restored it. The terminal was detached
and closed, and a new real prompt verified registration. No startup setting
or policy was changed.

## Criterion-by-criterion scope

L02 requires a real Core/TUN, a validated plan for NM/resolved/nft, non-root
UI, typed IPC, no arbitrary shell and no flush of foreign rules. The
[installed GUI/Core observation](../2026-09-11-r12-l04-ui-status/candidate8-gui-core-loss.json)
and [native transaction events](../2026-09-11-r12-l04-ui-status/candidate8-daemon-events.json)
prove the actual connection. Source review of `coreprocess.Prepare`,
`systemCommandRunner.Run`, protocol decoding and network participants confirms
fixed executable paths, bounded typed inputs and own-table-only rollback.
The [foreign-rule recovery test](../2026-09-11-r12-l04-linux-desktop/candidate7-live-recovery.json)
preserves the injected foreign rule.

L03 requires owned-state recovery after crash/suspend/reboot, correct polkit
denial/timeout/missing-agent handling, and a retained retry journal on partial
rollback. Its recovery proof is the actual package-7
[crash and partial rollback](../2026-09-11-r12-l04-linux-desktop/candidate7-live-recovery.json),
[suspend/resume](../2026-09-11-r12-l04-linux-desktop/candidate7-sleep.json), and
[native reboot](../2026-09-11-r12-l04-linux-desktop/candidate7-reboot-native.json).
The [package comparison](../2026-09-11-r12-l04-ui-status/package8-vs7.json)
proves Core, daemon, units and hooks are byte-identical in package 8; the
[302-entry installed readback](../2026-09-11-r12-l04-ui-status/candidate8-installed-readback.json)
binds the installed payload. The reuse is limited to those unchanged runtime
components; it is not a new package-8 lifecycle run. Current authorization
and Core-loss/UI proof are independently native package-8 observations.

The source/native checks and exact PR/main CI remain in their referenced
records. This criterion review closes L02/L03's declared integration and
runtime scope. [DE-path failures](../2026-09-11-r12-l04-de-tcp/README.md), exact
package lifecycle/mode acceptance, final candidate selection, Core promotion
and Linux publication remain open. Successful paths do not erase failures.
[Retained hashes](retained-files.json) cover these new native observations.

Verification: `scripts/validate-seed.ps1` passed with explicit Core904 and
platform feature roots, including its docs contract. Platform docs tests
passed all 33 cases and the platform-context audit passed. The bounded
validator checked 15 new capture hashes, 12 referenced captures, 39 local
links, native negative/recovery assertions and private-material patterns.
The [matrix projection](matrix-projection.json) changes only L02/L03 prior
status/evidence: all 83 rows, original DoDs, scope and final-candidate results
remain unchanged. Scoped diff checks passed; no release-artifact delta exists.
