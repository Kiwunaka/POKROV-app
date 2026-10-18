# Client documents

- Current release queue: [Known Problems](C:/Users/kiwun/Downloads/POKROV_KNOWN_PROBLEMS_2026-10-13.md).
  [Execution section 0](C:/Users/kiwun/Downloads/POKROV_EXECUTION_PLAN_2026-09-24.md)
  explains how to continue; its older stages retain criteria, not a second queue.
- Product behavior: `product/client-product-contract.md`
- Runtime startup and platform boundary:
  `architecture/bootstrap-workflow.md`,
  `architecture/platform-privilege-runtime-contract.md`
- Current release: `operations/cutover-readiness.md`
- Android and Windows checks:
  `operations/android-release-audit.md`,
  `operations/windows-release-readiness.md`
- WARP-specific checks: `operations/warp-runtime-proof-checklist.md`

Public version is 1.4.5; the seven-asset 1.5.0+4175 draft is retained.
The integrated redesign is built locally as Android and Windows 1.5.0+4178
with the existing Core 1.2.14. Android UI navigation passed in visible api35gc;
Windows 4178 has build/package checks only and awaits runtime acceptance.
Neither 4178 artifact has been published. See [DESIGN.md](../DESIGN.md) for
screen ownership, real-data bindings and the Diagnostics boundary.
Dated candidate receipts are history, not current blockers or permission to
repeat accepted checks. Older detailed receipts remain in Git history.
