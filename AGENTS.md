# POKROV-app Contract

## Scope

- Android and Windows are public. iOS and macOS are readiness work. Main branch is `main`.
- Use `shared/` and the Platform docs in `C:/Users/kiwun/Documents/ai/VPN` for shared platform facts and APIs. The runtime core lives in `C:/Users/kiwun/Documents/ai/POKROV-core`.
- Use `C:/Users/kiwun/Downloads/POKROV_RELEASE_2026-11.md` for the current queue. Keep it to 40 lines and remove closed items. Skip the archived `POKROV_KNOWN_PROBLEMS_2026-10-13.md` and the execution plan dated 2026-09-24. Leave both untouched.
- Navigation: [docs index](docs/README.md), [repository map](docs/architecture/folder-structure.md), [packaging and runtime bindings](scripts/README.md).

## Delivery and Verification

- Deliver working code on `main` and run the applicable stage checks. Once publication is authorized, carry the release through to verified delivery to users.
- Use `flutter analyze` and focused tests for affected Flutter packages. Check Gradle or Windows packaging when the change affects that build path or the release checklist calls for it.
- Build a new package when code changes require one. The Platform snapshot records public release state. Verify delivery against the live distribution channels and keep acceptance logs in Git history.

## Git And GitHub

- Check `git status` and the relevant diff first. Preserve unrelated work.
- GitHub is plain storage for code and history. Actions results, PR reviews, commit signatures and LFS are not gates, and nothing paid is used.
- Work on `main` or a short-lived branch; merge right after local checks and delete the branch. Keep only `main` and the current branch locally, with at most one extra worktree.
- Never force-push `main`. Never use `git reset --hard` or a blanket restore on someone else's changes.
- Do not add new release packages (APK, AAB, EXE, MSIX) or Core libraries to git or LFS. Release files go to GitHub Releases of `Kiwunaka/pokrov`. Keep verified packages for the current release until publication, distribution checks and confirmation of the rollback path; a package awaiting approval is not an already-used output. Delete local build outputs only after their use is complete.

## Client Rules

- Use focused tests when replacing the runtime core or changing the tunnel or WARP lifecycle or platform privileges.
- Never downgrade secure storage or log session and auth values.
- Signing, store and physical-device checks are done by the owner or on the owner's device. Do not fake them.

## Owner Decisions

Get the owner's approval for release publication, deleting data or folders, spending money, and prices or tariffs.

## Safety

- Never print, commit or expose secrets, keys, tokens, signing material, raw profiles or customer data.
- Work only on POKROV-owned repos, servers and devices. Third-party systems and accounts are out of scope.
- Devices: VMs through the hypervisor API with the saved guest access; the phone through ADB. Do not take over the owner's desktop with computer use without asking.

## Report (up to 10 lines, plain language)

Give the stage status, what changed for users, whether the change reached `main`, and which platforms you checked. For a release, include delivery status.
