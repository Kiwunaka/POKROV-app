# R12-C03 — support conversation ownership and polling recovery

Baseline `988414d`; pure extraction `e91b85d`. Core remains `8dc57a8`.
Current-origin Windows host with synthetic services and Android/Windows shell
contexts. **I3 / PARTIALLY_FIXED**, full C03 and release acceptance remain OPEN.

## Ownership

`SupportConversationController` owns ticket identity/version, visible message
projection, loading/refresh/send/error state, initial selection, message and
feedback operations, and eligibility for `SupportPollingCoordinator`.
The view keeps text/focus/scroll controllers, dialogs, attachment consent and
encrypted bundle actions. It clears only the accepted draft; closing a view
disposes polling and prevents late responses from reaching that view.

The extraction was committed separately from the behavior correction below.
No API, assistant, session, stored-state or native-runtime contract changed.
`seed_shell.dart` and the 29 parts remain unchanged; the library entrypoint
adds one export. The ticket view lost 410 lines. This is an ownership boundary,
not a speed or memory claim. Existing connection/presentation ownership was
inspected and its 14 standalone tests ran; no additional split was required.

## Observed polling failure and correction

The new isolated lifecycle test exposed a preserved defect: starting a read
sets polling ineligible; the failure branch cleared `refreshing` without
restoring eligibility. The offline hint appeared, but no future automatic poll
was scheduled. The prior widget implementation contains the same omission.
The product contract already requires bounded exponential backoff.

On exact extraction commit `e91b85d`, both red oracles failed: the controller
had zero active timers, and the widget retained two reads where three were
expected after another 20 seconds. The correction adds `_syncThreadPolling()`
after clearing the refresh flag in the failure branch. Existing backoff,
jitter, active/quiet cadence and foreground/closed gates remain authoritative.
The tests now prove 16/32-second retries with deterministic zero jitter,
8-second cadence after successful manual retry, background cancellation and
actual widget retry after the error.

## Checks

- Extraction PASS: `flutter test test/pokrov_seed_app_test.dart
  test/support_polling_test.dart test/connection_experience_test.dart` — 203.
- Extraction PASS: `flutter test test/support_conversation_controller_test.dart`
  — 5. Covers ticket reuse, optimistic send/retry, acknowledged create with
  failed readback, feedback, manual refresh/background and late send disposal.
- RED: `flutter test test/support_conversation_controller_test.dart
  test/pokrov_seed_app_test.dart --name 'poll fail'` — two expected failures on
  `e91b85d`, retained before the correction.
- Final PASS: `flutter test test/support_conversation_controller_test.dart
  test/pokrov_seed_app_test.dart test/support_polling_test.dart
  test/connection_experience_test.dart` — **208**.
- PASS: client-root `flutter analyze` after extraction and after correction.
- PASS: client-root `pwsh -NoProfile -ExecutionPolicy Bypass -File
  scripts/validate-seed.ps1 -PlatformRoot
  C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot
  E:/r12core-implementation` for both source states. Performance uses the
  existing collector fixture; it is not reference-device evidence.
- PASS: `git diff --check`; no `artifacts/releases/**` delta. Previous four
  generated registrants retain their exact hashes and remain outside commits.

All Flutter test commands use cwd `packages/app_shell`. Early attempts are
retained: unused import after extraction, one fake-service Future type error,
and the first isolated missing-timer failure. They are not counted as passes.
[Receipt](receipt.json) records log hashes, archive and source counts.

Canonical owners: `docs/architecture/package-boundaries.md`,
`docs/architecture/in-app-ai-assistant-contract.md`,
`docs/product/client-product-contract.md`.

Checkout ownership remains to be reconciled on the platform marketing surface.
Installed device, SCM, CI/enforcement, real provider and final candidate gates
remain open. No build, install, host VPN change, external support message,
signing, push, merge, deploy, publication or new candidate occurred.
Rollback uses the separate scoped source commits; prior evidence is retained.
