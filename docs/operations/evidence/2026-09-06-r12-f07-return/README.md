# R12-F07 — foreground account refresh

2026-09-06. **I3 / PARTIALLY_FIXED**, full F07 remains open.
Baseline client `3d21244`; Core `8dc57a8`. No APK/EXE build or installation
was performed for this source change. Earlier D06/C05 package evidence retains
its original source tuple and does not prove this new Dart behavior.

## Reproduced defects and changes

1. After a cabinet browser visit, Android/Windows lifecycle resume refreshed
   runtime but did not refresh subscription. The profile could keep showing
   expired access after the server had confirmed paid access. Two widget
   scenarios fail on the original committed shell: expected a third subscription
   read, observed only two. They now pass: the existing account read model is
   refreshed, the profile remains selected, and no second cabinet handoff occurs.
   Only the authenticated subscription response changes the access label.
2. Resume on the welcome screen fetched the inbox before access selection.
   `fetchClientNotifications` uses `_requestClientJsonWithSession`, which calls
   `_startTrial` when no session exists. The fixture observed one premature
   inbox call; the corrected guard observes zero subscription/inbox calls before
   trial selection. Existing restore and acquisition flows remain separate.

Initial, profile-tab and ordinary foreground summary reads now share one
in-flight future. Subscription, bonus and inbox requests run sequentially;
notifications no longer race that summary when entering Profile. The existing
Telegram-verification branch is retained. The grouped refresh releases its
future on completion/failure and does not request a new identity or mutate
local routing state itself.

The offline regression holds one subscription request while two resumes and a
profile tap arrive: exactly one request runs, with no premature bonus/inbox
read. On API failure the prior trial view remains and there is no progress
spinner or false paid/expired transition. A later resume retrieves the synthetic
paid result successfully. HTTP request/body timeouts remain owned by the existing
app-first bootstrapper; no retry policy or authentication contract was changed.

## Checks

- `flutter test test/pokrov_seed_app_test.dart --plain-name 'cabinet return refreshes subscription'` — original shell **FAIL**, Android and Windows; corrected shell **PASS**, 2 tests.
- `flutter test test/pokrov_seed_app_test.dart --plain-name 'foreground account refresh coalesces'` — **PASS**, 1 test, then included in the final regression run.
- `flutter test test/pokrov_seed_app_test.dart --plain-name 'trial selection provisions account data and reports one journey'` — premature inbox **FAIL** before the guard; updated assertion passes in the final suite.
- `flutter test test/pokrov_seed_app_test.dart test/account_session_coordinator_test.dart test/first_session_coordinator_test.dart` — **PASS**, 192 tests on the final behavioral patch.
- `flutter analyze` in `packages/app_shell` — **PASS**, no issues.

The regression suite also exercises existing acquisition validation/expiry,
restore, Telegram return, denied/delayed VPN consent, runtime resume and timeout
recovery. These are synthetic widget/coordinator checks on the Windows host,
not real Android browser, Windows tray, SCM, network or provider acceptance.

Initial attempts included fixture problems (Windows viewport/navigation and
Android tap before scroll settled). They are retained and not counted as
the cabinet oracle. The corrected fixture was rerun against the exact committed
baseline shell, with its source hash recorded; both platforms failed at the
missing subscription request. The prepared fix was restored byte-for-byte before
the green run. No concurrent file or historical package was reverted.

Full F07 still requires installed 1.1.6 upgrade/session continuity, native deep
link/browser/tray delivery, real account/order context, D01/W03 packages and
provider/backend payment return proof. No push, merge, deploy, production
signing, new candidate, publication, payment or host VPN operation occurred.
The four preexisting generated registrants and retained release artifacts remain
outside this change. Rollback is the scoped source commit, preserving evidence.

Final client checks: `validate-seed.ps1` with the explicit platform/Core
worktrees — **PASS**; its performance collector uses a fixture. Scoped
`git diff --check` — **PASS**; retained release artifacts have no delta and
all four previous generated registrants are byte-identical. The [receipt](receipt.json)
records exact commands, all failed and successful log hashes, baseline/source
hashes and a verified archive of the original evidence bytes.
