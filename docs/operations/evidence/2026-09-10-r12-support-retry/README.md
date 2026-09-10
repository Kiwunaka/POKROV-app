# Windows support retry — 2026-09-10

Document class: EXECUTION_EVIDENCE. PASS_BOUNDED, V01/V03/V04 remain active/I4.

PR [108](https://github.com/Kiwunaka/POKROV-app/pull/108) fixes two observed
defects: saved ciphertext could not be retried after the preview changed or
support mode expired; an exhausted collection limit appeared as a network error.
Diagnostics now lists pending encrypted reports and retries the selected saved ID.
The existing authenticated upload/resume API retains its ID, ciphertext, digest
and idempotency key. Retry does not recollect, re-encrypt, fetch a recipient or
register another support-mode collection. A missing ticket ID no longer produces
a false created-case message. The product contract was updated with the code.

Tested client `24da816d9541468fe4f0d838126d0accc10c6c32` is bound to signed
source `c3e70ad2622d9cb76cfcd226175cf8b222436415`, tree
`12c0bbb12a5600bb1af8b5f6c4e2dab5af6e954c`, merged as
`840e1c597227ec36d0ddd8df71a0ef80d57de485`. Exact PR and merge CI PASS.
Core remains `c8b0461c1975ef96e32024774300a5829b9fdc43`.

Installer SHA-256 `9208b040d1c43bdc7dc834fdf9cf189e8b0946a77fd60d89f5ecfbd03716dc0f`.
Ordinary Windows wizard installation verified all 304 files; only data/app.so
changed from the previous 45d495 payload. Session and secure-store hashes were
preserved before first launch. Previous payload and all snapshots are retained.

Native current-origin Windows 11 VM acceptance:

- Before upgrade: one encrypted pending file, 13123 bytes, case56 uploading.
- After restart with support mode OFF and a different current preview: the old
  report appeared with its own retry button. One explicit click completed case56.
- Brain backend `25c6f7a13a04ee41fa6a86b84fbf90e045580a2f`: worker validated
  the same ciphertext SHA-256
  `b2a70c40a08091c358f54713182b5499ab8a4704e7614575c8df232734771a34`.
  There was one original bundle row and zero new owned cases since pre-install.
- The local outbox became empty only after acknowledged completion.
- Admin lookup by case/diagnostic ID, exact encrypted download, step-up denial,
  one-use grant replay denial and audit passed. Five decrypted extended files
  scanned in worker-key memory contained zero seeded canary markers; no content
  or credentials were exported. Temporary operator session revoked, existing
  sessions unchanged. External OIDC was not retested.
- VM shut down, NIC1 none, ten snapshots retained, final snapshot
  `a991bc7e-b99c-4466-8f0e-49661499ae7a`. Original failed case53 and the acceptance
  cases remain retained. No manual API completion was used for case56.

Validation commands (C:/Users/kiwun/tools/flutter/git-3.38.5/bin/flutter.bat):

- In packages/support_bundle: `flutter analyze`, `flutter test` — PASS, 15 tests.
- In packages/app_shell: `flutter analyze` — PASS;
  `flutter test test/client_diagnostics_test.dart test/support_bundle_delivery_test.dart`
  — 18 PASS; `flutter test test/client_diagnostics_test.dart test/pokrov_seed_app_test.dart`
  — 212 PASS. These runs overlap; their counts must not be summed.
- `scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot C:/r12coreprivacy` and `test/docs-contract.ps1` — PASS.
- `C:/r12-support-retry-20260910/build-windows.ps1` — PASS; the named wrapper
  contains exact build flags. Three original unique build logs were preserved
  and copied to this task directory; their locations and hashes are retained.
- Guest `prepare-install.ps1`, `verify-wizard.ps1`, host `read-case.py 56`,
  `admin-scan.py 56`, `verify-no-duplicate.py` — PASS. Complete scripts remain
  in C:/r12-support-retry-20260910; safe results are in this evidence directory.

The new limit copy is covered by controller/widget checks, not a fresh native
cap exercise. Android, crash profile, full network/runtime matrix and parent
dependencies remain open. This is not a public release or a new RU-origin gate.
No backend/Core deployment or host VPN/phone changes occurred in this slice.
An early merge-CI read asserted while the run was still pending; no PASS receipt
was created then. The retained receipt is from completed successful CI.

[Capture hashes and bounds](receipt.json). Final documentation checks are
recorded separately in `documentation-checks.json`.
