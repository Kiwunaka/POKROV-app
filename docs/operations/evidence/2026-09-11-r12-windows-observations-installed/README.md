# Windows observations — installed package, 2026-09-11

Class: EVIDENCE. Scope: current-origin owned Windows 11 VM; local package
`7ed18c97c43ba39ce18701220d487af1b0c5a446` / Core
`904e440aca98cb6419744c5c04c83223a6d6380e`. [Receipt and capture hashes](receipt.json).

The ordinary installer upgraded a24/Core904 while offline. All 304 installed
files match the staged payload, both immediately after installation and after
the network cycle. Account state and secure storage are byte-preserved at
upgrade; the final outbox remains empty. Compared with a24 only `data/app.so`,
`pokrov_service.exe` and `pokrov_windows.exe` changed.

The default Finish action launched a measured non-elevated UI in session 1.
LocalSystem service ACL matches the prior retained ACL; broad groups cannot
mutate the service. The UI did not load the Core DLL.

After enabling the VM network link, the first immediate read found the adapter
still down. That failed observation is retained. Once the adapter was ready,
the external control request returned HTTP 204 with the owned marker. A UI
Connect action reached Core/DNS/egress-ready and effective/staged parity. Ten
HTTPS requests returned the expected 204 and marker. TUN received/sent counters
each increased by 26,436 bytes; ambient guest traffic prevents per-request
attribution. Disconnect restored the exact route and DNS hashes, removed the
active TUN and left service failure `none`. The viewed [connected](connected.png)
and [disconnected](disconnected.png) captures show the normal Connect CTA after
stop, without the earlier yellow Retry/settings-ready message. This closes that
specific installed UI defect from PR112.

Source PR112 and PR113 were already merged with both exact CI runs passing:
[disconnect source and checks](../2026-09-11-r12-windows-core904-upgrade/README.md),
[WinHTTP classification and checks](../2026-09-11-r12-windows-egress-observations/README.md).
Their focused tests are prior source evidence, not rerun installed-fault tests.
The six new WinHTTP codes are present in the packaged service. This ordinary
connection cycle does not prove a full installed fault matrix or close N05.

Build: `build-resume.ps1` invokes the existing Windows reproducible wrapper
with offline pub get, exact source/Core and public emergency pins. Analyze,
tests and seed were skipped in that build invocation because the source was
already verified. The initial parity attempt failed on an Android LFS pointer;
the pinned artifact was materialized and the unchanged build then passed.
No Android or new Core build was run. Innoextract 1.9 could not unpack the newer
installer format; the original failure is retained. Actual installation then
provided the 304-file payload check. Authenticode remains `SKIPPED_BY_OWNER`.

A powered-off rollback snapshot preserved the preceding 11 snapshots. Its
new writable leaf was moved to E: through VirtualBox with matching SHA-256;
all 12 snapshots remain. VM is now powered off with NIC `none`, and host route
and DNS hashes match the pre-test values. E: free space fell from 43.42 to
40.38 GiB during the VM interval, exceeding the 2 GiB forecast. The 40 GiB floor
was preserved; the growth forecast was insufficient. C: has 41.79 GiB free.
No further VM/build work is justified by the current spare disk budget.

Public release/pointers, Win10, clean-user install/uninstall, WARP, Android,
trusted signing and the full R12 gates remain open. No real payments or
campaigns were executed. Source captures that predate installation retain
their original NOT_YET_PERFORMED limits; the later receipt above supplies the
installed proof. Validation and evidence commits are recorded separately.

Initial docs seed failed because the new entry pushed the retained candidate
name beyond the first 45 lines. The existing baseline paragraph was moved to
the top; the original failing log is preserved. No contract was relaxed.

Final documentation checks: `pwsh -NoProfile -File scripts/validate-seed.ps1
-PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot
C:/r12corec02`, `pwsh -NoProfile -File test/docs-contract.ps1`, 33 platform
docs tests, platform-context audit, scoped link audit and `git diff --check`
PASS. [Validation capture hashes](validation.json). No `artifacts/releases`
delta; evidence commits remain local and do not publish a package.
