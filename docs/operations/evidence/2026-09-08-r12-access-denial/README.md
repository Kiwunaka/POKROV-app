# Windows expiry and explicit access denial — 2026-09-08

**PASS_BOUNDED_FIXED_WINDOWS_DENIAL**, client `f479fd4`, Core `02a091c`,
unsigned local installer SHA-256
`f44486c3ae32ac5c3020e9b76c997902c202084076cb7954bc0678d5805f676d`.
[Receipt and retained byte hashes](receipt.json); [15 runtime checks](fixed/summary.json).
This is a correction to the earlier integrated tuple, not release approval.

## Observed defect and correction

The earlier installed client `3784352` (`83c253ce…6063`, 305 verified files)
accepted its cached profile while `/api/client/subscription` returned HTTP 200
with `expiredOrBlocked` and `/api/client/profile/managed` returned 503.
The test subscription expired naturally; no backend mutation was performed.
The account status was a known denial, not an unavailable API.
[Original failure and bounded expiry result](before-fix-summary.json).

The shared bootstrap now clears protected managed-profile storage after an
explicit inactive subscription. The shell denies cached fallback and disconnects
an active tunnel, including when the denial arrives during a native connect.
It rechecks denial after the pending profile request settles. Bootstrap and
persisted-state owners were updated with source commit `f479fd4`.

The new Windows package installed successfully in the same isolated Win11 VM;
all 304 expected package files matched before launch and at completion. The
fresh bundle does not contain the previous `native_assets.json`; this is not an
assertion that every extra file in the install directory was removed. The
diagnostic helper's `0218e89` source field identifies the helper only.

With client API access blocked, the ordinary UI first connected from the still
valid cached profile: service running and one TUN. Restoring API access then
caused automatic disconnect and removal of the protected cache. After API was
blocked again and the UI restarted in a new process, connection was refused:
no TUN, no running tunnel and no new connected event. Independent owned health
remained HTTP 200. The fixed run did not alter the guest clock.

Saved session bytes, disconnected routes and DNS matched the baseline. Both
temporary firewall rules were removed. The lab VM was gracefully shut down
with NIC none; the original VM remained off. No manual backend mutation,
release-artifact change, push, deploy or publication occurred.

## Controlled expiry on the earlier package

The first clock attempt was invalid: Windows time synchronization reset the
clock. Its raw result is retained and excluded. The second attempt temporarily
disabled guest synchronization and held cached-profile age above 24 hours
(92,989 seconds at the final sample); ordinary connect was refused. Restoring
the clock allowed connection with the same original cache timestamps/hashes.
Time service and VirtualBox synchronization settings were restored.

This proves the controlled wall-clock boundary on the earlier package. It does
not prove a real 24-hour soak, protection against clock rollback, or the same
expiry scenario on the new package. `fixed_runtime_status=PENDING` in the
historical before-fix summary is superseded by the separate fixed receipt.

## Verification and remaining scope

Two focused regressions failed before the fix. The final source run passed
301 tests, including denial before reconnect, during a running tunnel and
during native connect. Commands from `packages/app_shell`:

```powershell
flutter test --no-pub test/app_first_runtime_bootstrap_test.dart test/pokrov_seed_app_test.dart test/managed_profile_cache_test.dart test/cached_profile_fallback_gate_test.dart --reporter expanded
flutter analyze --no-pub
```

Full package analysis: no issues. Client `scripts/validate-seed.ps1` with explicit
platform and Core worktrees and `test/docs-contract.ps1` passed. Windows build
used `scripts/build-windows-release-reproducible.ps1 -SkipValidateSeed
-OfflinePubGet -CoreRoot E:/r12core-implementation` and existing public emergency
key pins; the build log is retained. The script name alone is not a claim of
two independent byte-identical builds.

The shared Dart change requires a new Android package and affected device
acceptance. Actual device/session revocation through HTTP 401/403, fixed-package
expiry, full N02/N07, independent egress/leak, Win10 and final channel remain
open. Older Android and Windows receipts retain their exact original bytes.
