# Support Context

Current responsibility:

- safe diagnostics payloads
- support escalation metadata
- ticket-context shaping for app, web, and Telegram fallback
- app-visible summaries that avoid leaking raw configs or keys

The active `SupportSnapshot` model lives in
[lib/support_context.dart](lib/support_context.dart). Consumer ownership is
listed in the [repository map](../../docs/architecture/folder-structure.md);
the [product contract](../../docs/product/client-product-contract.md) owns the
support flow. Models never grant runtime or support-upload authority.
