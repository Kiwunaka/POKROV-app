# POKROV-app Codex Contract

This repository is the canonical client-development lane for POKROV. Promote client work through `POKROV-app/main`. The separate platform repository owns backend behavior, public web surfaces, and cross-surface shared facts.

## Start Every Task

1. Classify the task with the route in `docs/README.md`; do not read every document by default.
2. State the intended write set, authority owners, verification, and documentation impact.
3. Inspect current code, tests, Git worktrees, and conflicting evidence before changing a contract.
4. Preserve concurrent work. Never edit or clean another branch or worktree.

## Authority

- Task authority: Codex system/developer instructions, the user's current instruction, this contract, then the task router and process docs.
- Intended product authority: owner-approved decisions and machine-readable contracts, canonical client docs, current code/tests, active execution records, then history.
- Observed runtime authority: current provider/runtime state, candidate-specific evidence, provenance-bearing reports, then older evidence.
- Release-claim authority: exact candidate identity, current candidate evidence, required manual gates, then the current release decision.
- When code and intended canon disagree, record the conflict. Do not silently promote either side.
- Archive and evidence can explain why a decision happened. They cannot decide what to implement now.

## Repository Boundary

- `Android` and `Windows` are the current public outside-store client surfaces.
- `iOS` and `macOS` are readiness tracks only until signing, packaging, store, and device evidence closes their gates.
- Platform-owned facts and API contracts live under `C:/Users/kiwun/Documents/ai/VPN/shared/` and the platform canonical docs. Coordinate cross-repo changes instead of copying new truth here.
- Client product, shell, runtime, host integration, and client release-readiness truth belongs in this repository and its canonical registry entries.

## Runtime And Security

- Do not replace the default runtime core, alter tunnel or WARP lifecycle, or change platform privileges without the matching architecture route and focused tests.
- Keep tokens, credentials, signing material, private keys, raw profiles, and provider data out of Git, logs, fixtures, screenshots, and handoffs.
- Never downgrade secure storage to plaintext or log authentication/session values. Preserve logout, revocation, migration, and corrupt-state behavior.
- Signing identities, entitlements, provisioning, device proof, and store access are operator-owned gates. Do not fabricate or bypass them.
- Do not add a dependency, service, generator, external agent adapter, or retrieval system unless the task explicitly requires it.

## Evidence And Destructive Operations

- Do not modify `artifacts/releases/**` unless the current task is an explicitly approved release-artifact task with candidate and rollback scope.
- Preserve audit evidence, retained release lineage, historical decisions, and generated references. Reclassify or index them instead of rewriting history.
- Never run broad clean, reset, stash drop, worktree removal, recursive deletion, or bulk regeneration without explicit scope and before/after proof.
- Inspect ignored and untracked files before cleanup. Machine-local files are not automatically disposable.

## Release Honesty

- Never infer stable, signed, store-ready, device-proven, WARP-proven, or publicly downloadable status from code, old handoffs, or historical authorization.
- Label inaccessible or operator-only checks precisely, including `MANUAL_OWNER_TEST`, `BLOCKED_BY_ACCESS`, `SKIPPED_BY_OWNER`, `OPERATOR_ATTESTED`, or `NOT_REQUESTED`.
- Documentation-only work must not run Android or Windows release builds merely to manufacture evidence.

## Verification And Documentation

- Shell, domain, or runtime changes: run the narrowest relevant Flutter analyze/tests first, then the affected host checks.
- Android host changes: run focused Flutter and Gradle tests. Windows or Apple packaging checks run only when their files or contracts change.
- Docs/config changes: run `powershell -ExecutionPolicy Bypass -File .\scripts\validate-seed.ps1`.
- Every task runs `git diff --check`; release-related tasks also prove no unintended `artifacts/releases/**` delta.
- Update the owning canonical doc in the same task when behavior, scope, API use, runtime, security, release gates, or user-facing copy changes.
- Handoff with changed files, commands and results, remaining manual gates, blockers, and rollback notes. Never claim checks you did not run.
