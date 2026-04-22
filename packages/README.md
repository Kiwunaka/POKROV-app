# Packages

This folder holds the shared starter modules for the new-base client lane.

Current seed packages:

- `app_shell`
- `core_domain`
- `platform_contracts`
- `support_context`

Dependency direction:

`core_domain` -> `platform_contracts` -> `app_shell`

`core_domain` -> `support_context` -> `app_shell`

The package graph stays intentionally small so either a `Karing`-adapted lane or a clean-room lane can reuse or replace pieces without unpicking production code.
