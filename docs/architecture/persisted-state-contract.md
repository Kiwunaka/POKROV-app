# Persisted client state

| Data | Owner and lifetime |
| --- | --- |
| Session and account identity | Platform secure storage. An authenticated device session owns its credentials. Clear them on sign-out or invalidation. Pairing and OTP values remain in memory. |
| Managed profile cache | Protected local storage, scoped to the account, device, profile identity and access validity. Reuse must pass the active policy and capability checks. |
| Client experience | Versioned preferences hold interface mode, route mode, chosen country/candidate reference, selected catalog service IDs and non-secret UX settings. These records do not carry raw endpoints or connection authority. |
| Locations convenience cache | Display metadata and the last latency result. Strip live probe addresses on load from older state and preserve the display choices. |
| Signed route and transport policy | Verify the payload before use, keep the accepted revision/security floors with the corresponding local state and enforce expiry and revocation. Refresh before enabling a newly ineligible scope. |
| Native runtime status | Native service owns the active profile and proof identity. UI may retain a bounded pending binding for reattachment, then reconciles it against native readback. |

Additive preferences restore their documented defaults when missing. Unknown route selections fail closed when they could weaken an explicit protection choice. Keep selected catalog service IDs on the device and validate them against the current eligible catalog. If the selective route is unavailable, preserve intent and ask for a different choice. Recompile policy from current inputs before reusing a cached profile.

Use the existing single writer per state record. Migration and rollback preserve session isolation and only reuse state the reader can safely interpret. A successful parse is separate from verified authority. Tests for a schema change should exercise the affected older record and its current reader.
