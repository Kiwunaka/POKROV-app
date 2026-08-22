# POKROV observability runtime

This package owns the local non-blocking operational event pipeline. `emit`
performs bounded in-memory validation/serialization only; a single asynchronous
writer drains batches to a two-segment JSONL store.

Default retained-volume ceilings are 24 MiB on Android and 64 MiB on Windows.
Priority pressure removes trace/debug/repeated info before warn/error/fatal or
security records. Queue depth, bytes, drops, flushes, rotations, writer errors
and truncated-tail recovery are observable without recursive logging.

The event shape and error codes come from `pokrov_observability_contracts`.
Unknown fields, unknown error codes, unbounded strings and forbidden material
fail before serialization. Legacy runtime and Windows-service journals are
read through closed allowlists and translated into safe events; raw records are
never copied into the new store.

Phase timelines distinguish profile, Core, TUN, routes, DNS, egress, verified,
rollback and stopped outcomes with duration and current proof. Cancellation,
supersede, timeout and crash remain distinct closed terminals. A versioned
previous-exit marker retains only safe breadcrumbs and is never runtime
authority. The machine-readable Problem Book maps PB-01..PB-14 to observed and
missing evidence plus closed safe actions; PB-09 is explicitly not shipped.

`ReleaseHealthMirrorWriter` can hand an identity-free aggregate projection to
an injected transport after durable local append. Correlation and attributes
never enter the batch body, transport failure is best-effort, and this package
owns no credentials, session creation or portal endpoint. It does not build
support bundles or grant support access.

`tool/runtime_overhead_benchmark.dart` measures the in-process pipeline's
payload, volume, queue-loss and emit-time observations against the initial
Android/Windows budgets. Its result is always `PARTIAL_LOCAL`: idle CPU,
cold-start/connect deltas and physical battery remain `NOT_MEASURED` until an
exact candidate is exercised by platform-specific collectors.
