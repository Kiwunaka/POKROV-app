# Packages

This folder holds the shared starter modules for the new-base client lane.

Current seed packages:

- `app_shell`
- `core_domain`
- `diagnostics_collectors`
- `observability_contracts`
- `observability_runtime`
- `platform_contracts`
- `support_bundle`
- `support_context`

Dependency direction:

`core_domain` -> `platform_contracts` -> `app_shell`

`core_domain` -> `support_context` -> `app_shell`

`observability_contracts` -> `observability_runtime` -> runtime/support consumers

`observability_contracts` -> `diagnostics_collectors` -> `support_bundle` -> `app_shell`

`observability_contracts` is a checked snapshot of platform-owned schema and
catalog identities. It cannot redefine their contents; cross-repository hash
validation fails on drift.

`observability_runtime` owns the non-blocking typed event dispatcher, privacy
guard, bounded priority queue, breadcrumb/security rings, legacy translation,
phase/proof timelines, stable failure and Problem Book mappings, previous-exit
marker, identity-free aggregate projection, and two-segment app-private JSONL
store. Android and Windows use exact 24 MiB and 64 MiB retention policies
respectively. `app_shell` supplies the authenticated transport only after an
existing session and adds `X-Correlation-ID`; observability cannot create an
account, trial, session, entitlement or runtime state.

`diagnostics_collectors` accepts only closed typed snapshots and emits a fixed,
bounded in-memory virtual file set. `support_bundle` derives the exact preview,
canonical manifest and per-file hashes from that set, then exposes only
X25519/HKDF/AES-GCM encrypted output for a recipient from an Ed25519-verified
platform contract. Neither package enumerates files or exports plaintext.

The package graph stays intentionally small so either a `Karing`-adapted lane or a clean-room lane can reuse or replace pieces without unpicking production code.
