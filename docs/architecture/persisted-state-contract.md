# Persisted State Contract

This document owns the client-side saved-state formats that can affect session
continuity, connection choices, staged runtime reuse, or update handoff. The
active contract is schema `1`. An absent schema is the bounded legacy `v0`
route only where the table below says so.

## Inventory

| State | Owner and storage | Current / legacy | Read and retention rule |
| --- | --- | --- | --- |
| App-first session metadata | `AppFirstRuntimeBootstrapper`; `app-first-session-<platform>.json` in application support | `schema_version: 1`; unversioned `v0` | `v0` is decoded, secrets are moved to secure storage, and the metadata file is atomically rewritten as `v1`. Unknown, malformed, or future versions fail before authenticated traffic and remain untouched for recovery or rollback. |
| App-first access/refresh pair | `FlutterSecureAppFirstSessionSecretStore`; platform secure storage | `version: 1`; raw access-token string `v0` | A raw legacy value is decoded and best-effort rewritten as the `v1` JSON pair. Unknown object versions return no credential and are neither overwritten nor deleted. Tokens never enter ordinary JSON state or fixtures. |
| Client experience | `PokrovFileClientExperienceStore`; `pokrov-client-experience-v1.json` | `version: 1`; unversioned `v0` | `v0` is bounded by the normalizers and rewritten as `v1`. Unknown versions produce empty convenience state and the original file is preserved. Routing preferences from a future schema therefore cannot silently control the current client. |
| Android staged-profile reuse | `AndroidRuntimeProfileStore`; private `pokrov_runtime_profile` SharedPreferences | `schema_version: 1`; key set without a schema is `v0` | A valid `v0` record is rewritten as `v1`. Missing safety metadata defaults to Quick Settings disabled and Core egress proof required. Unknown versions are not restored into runtime state and are not cleared, preserving downgrade recovery. A missing staged config file clears only a supported record. |
| Emergency bundle/envelope | `PokrovFileEmergencyNetworkStore`; application support plus platform secure storage | existing `schema_version: 1` | Already version-routed, encrypted/verified, atomic, and fail-closed. WO-004C changes no emergency schema. |
| WARP consent readback | `AppFirstRuntimeBootstrapper`; `warp-consent-<platform>.json` | emitted with `schema_version: 1` | Safe, secret-free, write-only readback. It is replaced by the next authoritative server status and never authorizes runtime behavior. There is no local decoder or legacy migration. |
| Materialized runtime config | runtime engine and Android host; private working/config directories | derived sing-box JSON, no saved-state schema | It is regenerated from the current authorized managed profile. Desktop never restores it as user state. Android retains only the versioned pointer/attestation above. Core owns no independently persisted client-state format. |
| Downloaded and proven managed-profile cache | `ManagedProfileCache`; platform secure storage, `pokrov-managed-profile-<platform>-v1` | `version: 1`; no legacy route | At most two records, account/install/platform/input-bound, valid for 24 hours from the original server observation. App restart may restore one through normal host staging on transient API failure. Offline reuse/proof/restaging never renews the timestamp. Known authorization denial, including a successful subscription response with lane `expiredOrBlocked`, clears the cache; missing credentials and account/input mismatch reject it. Unknown/corrupt versions remain unavailable and untouched. No profile or WARP secrets enter ordinary session JSON. |
| Rule-set cache | app-first bootstrapper; private `.srs` cache | upstream binary content | Derived cache, refreshed or replaced from pinned HTTPS sources. It is not session or preference authority and has no migration route. |
| Update progress and installer handoff | shared shell and flavor-specific `AndroidClientUpdateInstaller` | no durable state | Phase/byte counters are process memory only. A direct cached APK is named by expected SHA-256 and is rechecked for exact size, digest, package, version/versionCode, SDK, ABI and installed-to-target signer continuity before reuse and before installer intent. Store flavor retains no APK and hands off only to Google Play. There is no update-state decoder or migration to invent. |
| Runtime event journal | desktop runtime engine; bounded JSONL | event ABI `1` contract | Append-only redacted diagnostics, not restored product state. Rotation may discard old lines; it cannot affect connect authority. |
| Operational event store | `observability_runtime`; app-private `pokrov-observability/operational-events.v1.{0,1}.jsonl` | operational event schema `1` | Android retains at most 24 MiB and Windows at most 64 MiB across two crash-tolerant segments. Records contain only closed typed fields and safe attributes. They are diagnostic evidence, never restored session/profile/runtime authority. |
| Encrypted support outbox | `PokrovFileSupportBundleOutbox`; app-private `support-bundle-outbox/` | encrypted envelope schema `1` | Each envelope is at most 2.5 MiB; new admission is capped at 24 MiB including interrupted temporary files, independently of the event-store cap. Existing diagnostic IDs reuse their original encrypted bytes even when full. New IDs fail with `outbox_full`; unsent evidence is never evicted. Queued/validated server completion removes only the matching stored object. |
| Previous-exit marker | `PreviousExitMarkerStore`; app-private `pokrov-observability/previous-exit.v1.json` | `schema_version: 1`; no legacy route | The current run writes `active`, a normal detach/dispose writes `clean`, and a crash handler writes `crash` with a catalog code, fixed safe signature and at most 32 safe breadcrumbs. Unknown fields, invalid IDs/codes/signatures, oversize or malformed content are reported as corrupt evidence. The marker cannot start, stop or restore a tunnel. |
| First-launch, theme, hint, and promo markers | small file or SharedPreferences stores | scalar or bounded-list tokens | Convenience-only. Unknown/corrupt values fall back to the documented safe default. They do not carry session, profile, update, or release authority. |
| Android system-surface preferences | `AndroidSystemSurfacePreferencesStore`; private `pokrov_system_surfaces` SharedPreferences | legacy scalar booleans only; current policy is all false | A read never restores notification detail authority. Any retained country, speed, or route `true` value is rewritten to false; writes also persist only false. This is a one-way privacy migration for convenience state, not a session/profile schema migration. |

The client-experience `routingPreferences` object has an additive
`dnsTransport` field. `vpn` is the safe default; an absent, malformed, or
unknown value decodes to `vpn`. Older clients ignore the field inside schema
`1`, so the opt-in direct-DoH laboratory preference remains downgrade-safe
without inventing a new state owner or migration route.

The same object has an additive boolean `externalSmartDnsEnabled`. It restores
as `true` only when the same decoded object contains a valid custom HTTPS DoH
resolver, `dnsTransport: direct`, and at least one AI or Games purpose route.
Every absent, malformed, downgraded or incomplete combination normalizes to
`false`; native materialization independently rejects an invalid enabled
combination. The field remains convenience policy inside schema `1`, never
session, entitlement, resolver-account or server capability authority.

The managed-profile cache also retains `last_observed_at` in its version-1
secure-storage envelope. Reads serialize with mutations and advance this
observation even when a record is expired. A subsequent earlier wall-clock
value makes the cache unavailable after restart as well; profile verification
timestamps are never renewed by this metadata. Existing envelopes establish
the observation on their first read. This is not an independent trusted clock.

## Version Routing and Rollback

Version fields must be integer values. The current client accepts only the
current version and the explicit legacy route. It never guesses that a future
shape is compatible.

- Supported `v0` data migrates on the first successful read. A second read
  produces the same `v1` representation.
- A failed secure-store migration leaves the legacy credential usable and does
  not remove it. A failed metadata rewrite leaves the atomic backup path for
  recovery.
- Future state is rejected without destructive cleanup. This lets the newer
  client resume later and lets a rollback use the older format if that client
  actually understands it.
- `v1` adds fields that pre-004C decoders ignored, so rolling back from this
  client does not require deleting current session, experience, or Android
  profile state.
- Reset is allowed only for convenience state or a supported staged-profile
  record whose referenced config file no longer exists. Reset is not a session
  migration strategy.
- Operational JSONL rotation and previous-exit replacement may remove only
  their own bounded diagnostic files. Corrupt evidence is not interpreted as
  product state, and previous-exit recovery never overrides the host/service
  snapshot or privileged recovery journal.

## Fixtures and Gates

`config/state-migrations.v1.json` is the machine-readable 1.1.x-to-1.2.0
authority. It binds the target product/build, every supported migration owner,
source and target schema, synthetic fixture SHA-256, migration behavior,
rollback policy and named regression. Both `validate-seed.ps1` and the
cross-platform app-shell contract test reject missing fixtures, hash drift or
a removed regression.

Sanitized previous-version fixtures live at:

- `packages/app_shell/test/fixtures/app-first-session-v0.json`
- `packages/app_shell/test/fixtures/secure-session-v0.txt`
- `packages/app_shell/test/fixtures/client-experience-v0.json`
- `packages/app_shell/test/fixtures/routing-preferences-v0.json`
- `apps/android_shell/android/app/src/test/resources/runtime-profile-v0.properties`

The app-shell tests prove v0-to-v1 rewrite, idempotence, future-version
preservation, secret-store migration, and failure preservation. Android JVM
tests prove schema routing, safe legacy defaults, idempotent encoding, and
future-version rejection. The raw-credential fixture contains only the literal
synthetic test value named by the test; no fixture contains a real credential,
provider endpoint, private key or account/customer identifier.

Update discovery, direct/store source separation, native APK identity policy,
emergency storage, and typed runtime journaling keep focused tests. They are
inventory entries, not evidence that a production-signed artifact,
physical-device upgrade/downgrade, store submission, or exact release candidate
was tested.

Operational tests additionally prove atomic previous-exit replacement,
crash-over-clean ordering, bounded secret-free breadcrumbs, false-green
rejection, distinct cancelled/superseded/timeout/crash terminals, and an
identity-free aggregate projection. Exact-candidate crash survival and remote
delivery remain candidate/environment evidence, not a source-level pass.

Previous-exit writes flush a same-directory `.next` file and rename it over the
existing marker without deleting the destination first. If either asynchronous
or synchronous rename fails, the last committed marker remains readable and
`writeErrors` increments. Two fault-injection regressions cover that failure;
the Windows Dart 3.10.4 native check also verifies sharing-violation preservation
and replacement after the temporary file is unlocked. This does not establish
power-loss durability or installed-device crash survival for a new package.

### Android staged profile identity

The additive `config_digest` in supported schema `1` is lowercase SHA-256 of
`egress-required + newline + route-mode + newline + UTF-8 config`. It identifies
local execution input, not a server revision or entitlement. Missing/malformed
values remain readable for migration but cannot authorize Quick Settings reuse;
the app must refresh and stage a profile first. Unknown schema records remain
untouched. A service start verifies the captured digest against the saved
metadata and actual file, then pins the verified bytes before replacing Core.

Staging restricts the pending file before `android.system.Os.rename` atomically
replaces the old file. A rename failure retains the old file. The preferences
write follows replacement; a crash between the two produces a digest mismatch
and requires refresh, never a successful acknowledgement of different bytes.
This is not durable last-known-good rollback or device crash proof.
