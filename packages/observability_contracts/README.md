# POKROV observability contracts

This package exposes typed identifiers for the platform-owned operational
observability event schema and error catalog. It is a checked compatibility
snapshot, not a second source of truth.

The canonical JSON files live in the platform repository under
`shared/contracts/observability/`. Exact versions and SHA-256 values are bound
through `config/observability-contracts.seed.json`, cross-checked against Core,
and inserted into release-handoff v2 by the client generator.

The package does not send telemetry, write logs, build support bundles or
project events into product analytics. Those runtime decisions belong to later
layers and must preserve the four-mode privacy boundary.
