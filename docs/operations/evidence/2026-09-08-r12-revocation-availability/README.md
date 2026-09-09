# Windows revocation fixture availability — 2026-09-08

**BLOCKED_BY_ACCESS / MANUAL_OWNER_TEST**. Actual session/device revocation
was **NOT_RUN**. This receipt does not close N02/N07/A04.

The observations below cover the first attempt ending at 13:52 UTC. The owner
later agreed to enter UAC credentials manually; a new retry was opened and is
awaiting interactive Windows login. That pending retry does not change these
retained initial results.

A separate linked Win11 clone `808ca28e-cb34-4c49-b661-8aca4d138b01` was
created from a new snapshot of the managed test VM. The source disk and its
existing client data were preserved. A new ordinary local account was created;
its password remains in guest-only DPAPI storage and is excluded from evidence.
No new backend client identity was created and no backend contact occurred.

The existing unsigned installer for client `f479fd4`, SHA-256
`f44486c3ae32ac5c3020e9b76c997902c202084076cb7954bc0678d5805f676d`,
requested administrator credentials from the standard-user session. Automatic
approval review rejected password input with `blocked by policy`; no workaround
was attempted. The installer subsequently exited with code 2. No UAC prompt is
currently waiting: the clone is off. Continuing this route requires a fresh
interactive owner action and a suitable Windows test runtime.

The new clone reports Windows Enterprise Evaluation `LicenseStatus=5` and
`GracePeriodRemaining=0`. No activation, clock or licensing workaround was
attempted. This observation is specific to this clone and time.

The final audit verifies all 304 expected installed file hashes, original file
owner, and old session/experience bytes. No UI process or active adapter remained.
The new clone and its managed parent are both powered off with NIC1 `none`.
The original source VM was not started by this run.

[Receipt](receipt.json) binds six retained raw observations. Scripts, credentials,
VM disks and screenshots are excluded. This is availability and preservation
evidence, not installation, revocation, expiry or release acceptance. Runtime
source, release artifacts and backend state were not changed.
