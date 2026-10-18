# Packages

Shared client modules; see the [repository map](../docs/architecture/folder-structure.md)
for source entrypoints and the [product contract](../docs/product/client-product-contract.md)
for behavior.

Current packages:

- `app_ui`: presentation widgets and view data; no network, storage or runtime authority
- `app_shell`
- `runtime_engine`: managed-profile materialization, native bindings and candidate probes
- `core_domain`
- `diagnostics_collectors`
- `observability_contracts`
- `observability_runtime`
- `platform_contracts`
- `support_bundle`
- `support_context`

Dependency ownership follows the package `pubspec.yaml` files:

- `app_shell` composes `app_ui` and consumes the domain, runtime, platform,
  observability and support packages.
- `platform_contracts`, `runtime_engine` and `support_context` depend on
  `core_domain`.
- `observability_runtime` consumes `observability_contracts`; event identities
  remain platform-owned rather than being redefined by their consumers.

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

`app_shell` supplies real data and callbacks to `app_ui`, and uses the runtime
and support packages through their existing contracts. A presentation widget
cannot create authentication, entitlement or connection proof. Native artifact
selection is documented in [runtime_engine](runtime_engine/README.md) and
[scripts](../scripts/README.md).
