# Protected cache expiry after clock rollback

The cache returned an already expired profile after restart when wall time moved
back into its old 24-hour window. One regression reproduces the failure.
The existing secure envelope now records its last observed wall time, and reads
serialize with mutations. An earlier clock value cannot revive the observed expiry.
Profile verification timestamps and downloaded/proven data are preserved.

[Receipt](receipt.json) records the four source hashes, commands and limitations.
Cache/fallback tests: 10 PASS; protected bootstrap restart/server-denial test:
1 PASS; focused Dart analysis: no issues. This is local fixture evidence.
Core/host code and packages are unchanged; no device clock was changed.
Logs and the original failure are retained in platform work-order evidence
`2026-09-05--consolidated-release-and-post12/evidence/cache-expiry-20260913/`.
