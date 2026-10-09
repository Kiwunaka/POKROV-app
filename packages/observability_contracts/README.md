# POKROV observability contracts

This package exposes typed identifiers for the platform-owned operational
observability event schema and error catalog. It is a checked compatibility
snapshot, not a second source of truth.

The canonical JSON files live in the platform repository under
`shared/contracts/observability/`.

The package does not send telemetry, write logs, build support bundles or
project events into product analytics. Those runtime decisions belong to later
layers and must preserve the four-mode privacy boundary.
