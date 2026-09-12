# Android flavor startup regression — 2026-09-12

Document class: EVIDENCE. [Receipt and exact captures](receipt.json).

The production-signed development APK from client `a9bc280` and Core `6b271de`
installed in the owned LDPlayer 14 instance without clearing data. Its SHA-256
is `23fa86a9421930910e6d95d0fdff85f35c5df4e94f8749b83e3457052b66935d`.
After a synthetic invalid-profile service start, the actual app remained on its
splash screen. The available app-PID logcat was examined in memory: nine planted
credential/config/URL/IP/path/PII/provider categories were absent, but one
unhandled Flutter exception pointed to `OperationalBuildIdentity` channel
validation before `runApp`. The native-input pass does not prove GUI/bundle
redaction; that continuation was blocked by this startup failure.

The cause was the newly added `POKROV_RELEASE_CHANNEL=direct/store` arguments.
The operational schema permits alpha/beta/rc/stable/local. The source fix removes
those arguments and reads the existing Flutter `appFlavor` for Android support
metadata. Windows and unflavored tests retain their existing channel selection.
No operational schema, dependency, new define or backend deployment is added.

The existing real diagnostics widget test now checks startup build identity and
the serialized build/identity payload delivered by the app action. It first
reproduced the invalid operational channel, and separately reproduced a store
flavor being mislabeled direct. Both `--flavor direct` and `--flavor store` runs
pass after the change. The three focused diagnostics/observability/support-mode
files pass 25 tests; app-shell analyze, docs contract and explicit-root
validate-seed pass. The contract check rejects the two invalid build arguments.

Synthetic profile and preference bytes were restored from guest-private rollback
copies with exact original hashes. The emulator was stopped; root was disabled
again, with other instance configurations unchanged. Its guest boot check remains
pending. Root was confined to this QA instance. No activation code or support
policy was issued during the blocked UI run. No physical phone was used.

Corrected packages, installed startup/support proof, source promotion and the
full R12 gates remain pending. The failed packages must not be treated as ready.
