# Connect interruption boundaries — 2026-09-08

Scope: local Windows service source after `0f77637`. A request deadline was
checked only at dispatch; a later Core/probe success could still commit and
publish protection. SCM stop was also invisible until Connect returned.

The service now converts the admitted deadline once to monotonic time and
checks it, together with SCM stop, at connection transaction boundaries.
Interruption after mutation uses the existing serial rollback, clears effective
identity and retains the staged profile. Failed rollback remains
`recovery_required` and can be retried through Disconnect. Native UI parsing
accepts the two closed failure strings without treating them as a protocol
mismatch. Core bytes and wire version are unchanged.

Six deterministic native scenarios cover interruption before mutation, during
Core start, during successful egress verification, during the verified and
committed journal writes, and during egress with failed network restoration.
The initial regression failed against unchanged Connect behavior with only an
unused callback parameter added for compilation. Its first assertion also used
an empty digest instead of the protocol's `none`; that assertion was corrected.
Both failing logs are retained. The other failures independently demonstrate
successful commit, missing rollback and continued probe after interruption.

Validation: eight Debug native suites PASS; runtime Flutter 80 PASS with one
existing exact-DLL test SKIPPED because `POKROV_REAL_CORE_ROOT` is unset; runtime
analyze PASS; Release service build PASS. Exact commands, source hashes and
retained logs: [receipt](receipt.json). This is synthetic local proof, not an
installed or connected VM run. No host network, VM or release artifact changed.

Blocking Core/WinHTTP/recovery calls still need to return before an interruption
can be observed. The cancel command dispatcher, correlated cancellation,
concurrent mutation acceptance, WFP coexistence, Win10 and final package remain
OPEN. Rollback completion is deliberately not abandoned on deadline expiry.
No candidate, push, merge, deployment or publication was performed.

Rollback: revert the scoped source change as a UI/service pair; previous source
and evidence remain retained. The prior installed VM package was not changed.
