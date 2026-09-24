# POKROV-app Contract

## Scope

- Client repo: Android and Windows are public; iOS and macOS are readiness work only. Main branch: `main`.
- Platform facts and APIs live in `C:/Users/kiwun/Documents/ai/VPN` (`shared/` and platform docs); do not copy new truth here. Core runtime: `C:/Users/kiwun/Documents/ai/POKROV-core`.
- Current work follows the owner's execution plan `C:/Users/kiwun/Downloads/POKROV_EXECUTION_PLAN_2026-09-24.md`, one stage per task. Older plans and evidence are history, not instructions.

## How To Work

- Done means working code in `main`, plus a release to users when the stage says so. Reports, ledgers, status labels and evidence files are not results.
- Make the smallest change that solves the task; reuse existing code and patterns. No speculative abstractions, dependencies, configuration, fallbacks or future-proofing.
- Test only the changed behavior plus the stage checklist: `flutter analyze` and tests for the changed packages; Gradle or Windows packaging checks only when their files change. Repeat a check only after a change or a failure.
- Build only after code changes. Never rebuild to refresh hashes, licenses, provenance or a "fresh candidate".
- When behavior changes, update the owning doc with a short paragraph. Do not create evidence folders, ledgers or decision diaries.
- Other agents may work in the same repos. Check `git status` and the diff first; never overwrite, revert or reformat work outside your task.
- Stay inside the stage. List unrelated ideas in one line at the end of the report.

## Git And GitHub

- GitHub is plain storage for code and history. Actions results, PR reviews, commit signatures and LFS are not gates, and nothing paid is used.
- Work on `main` or a short-lived branch; merge right after local checks and delete the branch. Keep only `main` and the current branch locally, with at most one extra worktree.
- Never force-push `main`. Never use `git reset --hard` or a blanket restore on someone else's changes.
- Do not add new release packages (APK, AAB, EXE, MSIX) or Core libraries to git or LFS. Release files go to GitHub Releases of `Kiwunaka/pokrov`. Delete local build outputs after use.

## Client Rules

- Do not replace the runtime core or change the tunnel/WARP lifecycle or platform privileges without focused tests for that change.
- Never downgrade secure storage or log session and auth values.
- Signing, store and physical-device checks are done by the owner or on the owner's device. Do not fake them.

## Ask The Owner Only For

Release publication, deleting data or folders, spending money, prices and tariffs. Decide everything else inside the task.

## Safety

- Never print, commit or expose secrets, keys, tokens, signing material, raw profiles or customer data.
- Work only on POKROV-owned repos, servers and devices. Third-party systems and accounts are out of scope.
- Devices: VMs through the hypervisor API with the saved guest access; the phone through ADB. Do not take over the owner's desktop with computer use without asking.
- Never claim a check, push, build or release that did not happen. State plainly what was not checked.

## Report (up to 10 lines)

Stage and status; what changed for users; code merged (yes/no); how it was checked and what was not; what is left; the blocker; what is needed from the owner.
