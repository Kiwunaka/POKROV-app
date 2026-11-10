# Client package boundaries

See the [repository map](folder-structure.md) for source entrypoints.

- `core_domain` defines access, routing and connection models. `platform_contracts` describes the host-owned services and lifecycle. Neither depends on the Flutter shell or on a native implementation.
- `runtime_engine` materializes and validates managed profiles, negotiates host and Core capabilities and supplies probe and lifecycle adapters. The shell decides intent, choice, attempt ownership and presentation. Widgets do not implement runtime or authentication logic.
- `app_shell` owns account and device state, service orchestration, feature handlers and real-data composition. `app_ui` owns widgets and view data. The host supplies platform permissions, activation and privileged runtime operations.
- `observability_contracts` uses the Platform-owned event identities. `observability_runtime` dispatches bounded fields and controls retention. Diagnostics collectors produce closed snapshots. Support bundle code encrypts authorized report content and support context prepares the allowed ticket handoff.

The Android and Windows packages use the [selected runtime manifest](../../scripts/README.md#runtime-selection). Optional Core descriptors are validated when present. Older compatible ABI markers do not imply support for additive operations. Client host startup, connection, cancellation and proof remain separate stages. See the [native boundary](platform-privilege-runtime-contract.md).
