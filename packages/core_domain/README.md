# Core Domain

Current responsibility:

- app-first access and session entities
- route-mode models
- device context models
- managed-profile and smart-connect metadata
- support-safe status summaries

The [repository map](../../docs/architecture/folder-structure.md) describes
consumers of these shared models; [lib/core_domain.dart](lib/core_domain.dart)
is the package entrypoint.

Platform enums include engineering hosts without making them public delivery
targets. Release scope belongs to [cutover readiness](../../docs/operations/cutover-readiness.md).
