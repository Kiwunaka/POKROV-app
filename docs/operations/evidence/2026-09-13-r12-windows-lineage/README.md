# Windows installed lineage reconciliation, 2026-09-13

All 304 retained F03 installed-before hashes match the N08 installed
client `617194f` / Core `0138` package. The earlier F03 comparison used the stale `42df`
receipt; `data/app.so` SHA3487c6bf is the expected N08 payload. Three retained
N08 installed readbacks, the current 304 staged hashes, embedded `617194f` AOT
revision, retained setup `0f901f1a` hash and nine archive receipts agree.

The [receipt](lineage.json) retains full SHA256 and archive bindings. Original
F03 evidence is preserved; its unresolved-provenance note is superseded by this
reconciliation. No installed file repair is needed. The VM remains off with
NIC none and 13 snapshots; it was not started for this read-only check.

This verifies retained N08/F03 lineage against current local artifact bytes.
It is not a new guest readback, install/uninstall, installer extraction,
final candidate or release result. W01/W03 and final release gates remain open.

[Validation](validation.json) records documentation, client seed and diff checks.
The validation log archive is retained by the platform work-order evidence.
