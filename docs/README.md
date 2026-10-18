# Client documents

- Current release queue: [Known Problems](C:/Users/kiwun/Downloads/POKROV_KNOWN_PROBLEMS_2026-10-13.md).
  [Execution section 0](C:/Users/kiwun/Downloads/POKROV_EXECUTION_PLAN_2026-09-24.md)
  explains how to continue; its older stages retain criteria, not a second queue.
- Repository ownership and entrypoints: [folder structure](architecture/folder-structure.md).
- Product behavior: [client product contract](product/client-product-contract.md).
- Runtime startup and platform boundary:
  [bootstrap workflow](architecture/bootstrap-workflow.md),
  [platform privilege/runtime contract](architecture/platform-privilege-runtime-contract.md).
- Runtime package: [runtime engine](../packages/runtime_engine/README.md).
- Packaging and artifact selection: [scripts](../scripts/README.md).
- Current release: [cutover readiness](operations/cutover-readiness.md).
- Android and Windows checks:
  [Android](operations/android-release-audit.md),
  [Windows](operations/windows-release-readiness.md).
- WARP-specific checks: [runtime proof checklist](operations/warp-runtime-proof-checklist.md).

Public **1.4.5**, seven-asset draft **1.5.0+4175**, and private Android/Windows
**1.5.0+4181** remain separate. Cutover readiness owns their acceptance limits.
Both 4181 platforms require the shared private `RuntimeArtifactsPath` documented
in the [root README](../README.md#local-work-and-packaging); the default manifest
still selects older artifacts. See [DESIGN.md](../DESIGN.md) for screen ownership,
real-data bindings and the Diagnostics boundary.
Dated candidate receipts are history, not current blockers or permission to
repeat accepted checks. Older detailed receipts remain in Git history.
