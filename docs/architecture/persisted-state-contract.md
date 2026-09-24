# Persisted State Contract

This document owns the client-side saved-state formats that can affect session
continuity, connection choices, staged runtime reuse, or update handoff. The
active contract is schema `1`. An absent schema is the bounded legacy `v0`
route only where the table below says so.

## Inventory

Android Flutter connect/cancel request IDs are process-local only
(source work, NOT_VERIFIED). The runtime engine uses a weak in-memory snapshot
association, and the host retains one current request plus its cancellation
flag. Neither is written to this inventory's stores, diagnostics or backend.
The ATS preparation network ref and its bridge-owned observer are likewise
process-local. Closing the bridge invalidates the ref; new UI/process instances
cannot restore it from staged-profile metadata. Raw Network/LinkProperties never
leave the observer/native runtime comparison, and no migration is introduced.
The Windows service's IP/DNS observer likewise keeps its comparison material and
atomic revision in process memory only. Its private IPC exposes only a random
opaque ref for the current revision, replaced on revision/process change. That
ref and its mapping are not persisted or included in diagnostics/backend traffic.
It neither restores network authority from recovery artifacts nor exports
addresses/suffixes or numeric revision identifiers.
After process death an old Flutter request ID cannot authorize a new start;
Quick Settings and OS restoration still use the existing staged-profile
digest/eligibility contract. A cancellation acknowledgment means the local owner
accepted the request, not that retained state or a live TUN was erased.

| State | Owner and storage | Current / legacy | Read and retention rule |
| --- | --- | --- | --- |
| App-first session metadata | `AppFirstRuntimeBootstrapper`; `app-first-session-<platform>.json` in application support | `schema_version: 1`; unversioned `v0` | `v0` is decoded, secrets are moved to secure storage, and the metadata file is atomically rewritten as `v1`. Unknown, malformed, or future versions fail before authenticated traffic and remain untouched for recovery or rollback. |
| App-first access/refresh pair | `FlutterSecureAppFirstSessionSecretStore`; platform secure storage | `version: 1`; raw access-token string `v0` | A raw legacy value is decoded and best-effort rewritten as the `v1` JSON pair. Unknown object versions return no credential and are neither overwritten nor deleted. Tokens never enter ordinary JSON state or fixtures. |
| Client experience | `PokrovFileClientExperienceStore`; `pokrov-client-experience-v1.json` | `version: 1`; unversioned `v0` | `v0` is bounded by the normalizers and rewritten as `v1`. Unknown versions produce empty convenience state and the original file is preserved. Routing preferences from a future schema therefore cannot silently control the current client. |
| Android staged-profile reuse | `AndroidRuntimeProfileStore`; private `pokrov_runtime_profile` SharedPreferences | `schema_version: 1`; key set without a schema is `v0` | A valid `v0` record is rewritten as `v1`. Missing safety metadata defaults to Quick Settings disabled and Core egress proof required. Unknown versions are not restored into runtime state and are not cleared, preserving downgrade recovery. A missing staged config file clears only a supported record. |
| Emergency bundle/envelope | `PokrovFileEmergencyNetworkStore`; application support plus platform secure storage | existing `schema_version: 1` | Already version-routed, encrypted/verified, atomic, and fail-closed. WO-004C changes no emergency schema. |
| Signed Routing Catalog (POST12, NOT_VERIFIED) | `RoutingCatalogStore`; platform secure storage, `pokrov-routing-catalog-<audience>-v1` | `version: 1`; no legacy route | One signed public envelope plus catalog/security floors, payload digest and last observed UTC time. Reverify current pinned keys, audience, signature and lifetime on each read. Missing state bootstraps revision 0; corrupt/future state is unavailable and preserved. Discard removes only the envelope, retaining rollback floors. No account, install ID, app inventory or credentials are stored. |
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

When POST12 catalog support is enabled, cached managed-profile restoration
recompiles from the original authorized profile and a separately reverified
catalog. `cacheOnly` does not renew either original lifetime or request network
access. Missing trust, catalog expiry/disable or session change prevents stage;
it does not restore legacy RU rules. The derived native rules carry the catalog
time window and reject fallback, rather than persisting a second policy cache.
This integration is source-only and `NOT_VERIFIED`.

POST12 Android identity observations have no disk cache. The host keeps one
memory-only result bound to catalog digest, requested package set and package
event generation; install/remove/replace/change clears it, and bridge close
discards it. Confirmation of an app preset forces a fresh local scan. Only the
existing user-confirmed package selection is persisted as a manual preference;
matching certificates does not turn it into a perpetual catalog authorization.
Package/signature details never enter API requests or diagnostic storage.

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

Local POST12 source replaces blanket LAN permission with `lanScopeEnabled` and
`lanSubnets` inside the same routing-preferences object. The list admits at most
16 explicit RFC1918 or IPv6 ULA CIDRs, normalizes network addresses, sorts and
deduplicates them. A malformed/oversized list becomes empty, without retaining
only a valid subset. Enablement requires a nonempty valid list; defaults and
legacy `allowLan: true` without the new scope restore with LAN disabled. Writes
set legacy `allowLan` to false so an older client cannot interpret a saved narrow
permission as a blanket private-IP bypass. This is convenience state, not an
interface identity or proof that a network is trusted. No SSID/IP inventory is
collected or sent by the LAN editor.

The final route-preferences assembler marks its output with `lanScopeVersion: 1`.
Android stage metadata stores `lan_scope_version`; Quick Settings reuse requires
version 1 in addition to the existing exact profile digest, route scope and
eligibility. Missing legacy metadata remains zero, requiring a fresh preparation
through the app. Reading a legacy profile never grants the new marker or tears
down an already active tunnel. Runtime schema 1 and profile files remain retained.
These source changes and migration paths are `NOT_VERIFIED`.

The managed-profile cache also retains `last_observed_at` in its version-1
secure-storage envelope. Reads serialize with mutations and advance this
observation even when a record is expired. A subsequent earlier wall-clock
value makes the cache unavailable after restart as well; profile verification
timestamps are never renewed by this metadata. Existing envelopes establish
the observation on their first read. This is not an independent trusted clock.

## Version Routing and Rollback

Local POST12 source adds `selectedCatalogServiceIds` to the existing routing
preferences JSON, defaulting to an empty set when absent. These are public
catalog service IDs, not installed package IDs or a record of destinations
visited. They remain on the device, serialize in sorted order, and are copied
immutably by preference updates. More than 256 entries or an invalid ID makes
the selection empty rather than silently preserving a reduced protected set;
selective compilation then refuses connection until the selection is repaired.
Unknown/removed/ineligible IDs also fail compilation against the current signed
catalog. Service selection is recompiled on cache reuse, not authority stored
inside an old compiled profile. The current client restores confirmed Selective
intent even when the feature is disabled or the host is unsupported, displays
that unavailable choice and refuses Connect until the user changes the mode.
It does not silently replace the stored intent with Full/Smart Safe. The mode
and service set are saved through the existing single experience-state writer;
the picker revalidates the catalog and current preference revision before that
update. Closing the picker discards its unsaved draft. Older-version rollback
and actual restart/storage-failure evidence remain pending. PSD3 diagnostic
source is implemented separately; compatibility evidence remains pending. Status:
NOT_VERIFIED; no migration command or test was run.

The default-off POST12 Routing Catalog store serializes reads and mutations
across instances in the app isolate. Each successful read/accept observation
persists its UTC timestamp, including an expired or revoked-envelope read.
Observed clock rollback fails closed; this is not an independent trusted clock.
Invalid incoming catalogs preserve the last accepted envelope and revision
floors. This includes failure of the service/source/evidence consumer projection,
which runs after signature verification and before accepting a candidate.
Same-revision acceptance requires the retained digest. A known API
denial or catalog disable discards the envelope without resetting those floors;
if persistence fails, a process-local suspension prevents subsequent cache reuse
until a newly verified API result is accepted. Failed persistence cannot promise
that suspension survives process death.
Discard increments an in-process generation before waiting for pending storage
work. Fetch captures that generation before its request; a late successful reply
from before a denial cannot resume cache use. The generation is checked around
signature verification and the final write, across store instances in the same
app isolate.

The catalog is public policy metadata scoped to its audience and app storage,
not an account entitlement. Account changes/logout therefore do not reset its
security floors. API fetch results are fenced against changes of account,
installation or session while in flight. A future policy compiler must still
check current access, mode, platform capabilities and catalog lifetime before
apply, and remove expired applied rules through the host owner. No native
policy or profile currently restores from this store.

Smart Access separately retains only provider revision/security floors, payload
digest and last observed UTC time at
`pokrov-smart-access-floors-<audience>-v1` in secure storage. Updates are serialized
across instances in the app isolate. Corrupt storage, clock rollback or failed
write prevents acceptance; first use has revision 0/security 1. Logout/account
change does not reset these public-policy floors. Provider envelopes are fetched
fresh, and grants/nonces/service choices/account/install IDs are not persisted
by this new store. A process-local invalidation generation rejects late replies.
No native offline lease restoration follows from this metadata.

Smart Access runtime restriction metadata uses a separate secure-storage key
`pokrov-smart-access-runtime-<platform>-<audience>-v1`. Its version-1 document
keeps at most three native profile digests (running, current native stage and
prepared next stage), with at
most 256 lease identities per profile, original issue/new/active deadlines,
provider-policy digest/revision/security revision, provider/permission/capability/
service references and received drain/terminate decisions. Catalog-bearing entries
also keep the catalog payload digest, original UTC issue/expiry, a profile-wide
catalog revoke and a separate catalog-withdrawn flag; they may have no lease
identities. Existing three-field lease and eight-field catalog entries remain
readable. New entries have ten fields: `catalog_identity` adds original revisions,
audience/platform/mode/access context and per-service compiled-rule hashes/used
capability IDs; `catalog_service_revocations` retains the received service IDs.
Old entries have no reconstructed service metadata. All decisions latch. Account access denial closes
the exact profile; only catalog disable blocks that payload under a different
profile digest while the record remains current. The coordinator retains the
last withdrawn payload through profile switches if persistence fails; catalog
revision floors exclude earlier revisions. It contains no raw
profile, relay/resolver addresses, domains, tokens, keys, request nonce, device
binding or signed grant. The restriction-only type cannot enter native profile
assembly and cannot start, renew or extend access.

New lease identities contain 23 fields instead of the original 13. The additional
fields are base `profile_sha256`, `route_mode`, `runtime_scope_sha256`, origin,
family, feature and provider/permission/catalog/security revision floors. The
scope fingerprint is computed only after signature, device/request binding and
catalog/provider verification, using SHA-256 with the distinct
`pokrov-smart-access-runtime-scope-v1` context. It covers immutable runtime scope,
including relay/resolver, domain matcher set, quotas and nullable `relay_connect_policy`, without storing those
values here. Domain order is normalized; relay order remains significant.
Dates and revision floors are checked separately. Original 13-field identities
remain readable for restrictions and have no fabricated recovery fingerprint.

Stage and renewal persistence already retain this projection through the existing
inventory path. Normal in-memory renewal uses the same fingerprint comparison
plus nondecreasing revisions. This is recovery metadata, not a replacement for
a fresh signed grant or an acknowledgement of which lease Core currently runs.
The restart path now obtains those two inputs through current native readback
and the existing authenticated grant API. Old 13-field records cannot use it.

Service failover pools retain all candidate lease identities, including standbys,
through the same inventory; this does not identify the native selected provider.
Catalog capability removal records termination for matching identities rather
than withdrawing every candidate in the service. Full service scope withdrawal
still uses the existing service restriction. Live group affinity belongs to Core
and is not reconstructed from the order of recovered inventory rows.

Native selection readback is ephemeral UI data. The existing lease-read command
now returns a bounded schema-1 object separating actual current `lease_ids` from
`selections`; renewal/recovery consume only IDs, never selection as grant authority.
Service rows report last native choice and local availability, not successful
DNS/TLS/service traffic. The sheet retains read time and exact profile/operation
fences only in memory. A failed or stale read is not replaced with catalog order,
saved inventory or a persisted provider preference.

The local renewal source adds `retainRenewal` to this same serialized store.
It accepts a prepared renewal backed by a saved scope fingerprint, exact current
native lease ID and a fresh verified grant. Before native dispatch, it retains the new
restriction identity together with all still-live old identities and known
current generations, including current IDs whose old active deadline has expired.
The original catalog lifetime/digest and service capability
binding must match; received profile/service/old-or-new-lease restrictions reject
the write. Exact retries retain the same identity without changing its dates.
Expired non-current history may be pruned; the 256-identity and 1 MiB limits remain
hard bounds. The other profile slots and their decisions are preserved.

Cancellation or expiry after a completed write leaves only extra restriction
metadata and rejects dispatch. No write result proves native acceptance. The
stage path rejects an attempt to replace this same digest with an inventory
missing a still-live retained identity. This prevents old staged bytes from
erasing renewal history. Verified grants remain memory-only and are never
encoded by the store; storage recovery alone cannot prepare a renewal.
Foreground native delivery now follows this write. The coordinator adopts both
identities before dispatch and replaces its in-memory current grant only after
an exact positive acknowledgement; unconfirmed results retain the same pending
grant for retry. Native hosts invalidate reuse of matching old staged bytes before
admission. A known runtime stop discards memory-only renewal authority, retaining
restrictions. A new current-ID read permits discarding an expired/unrelated
memory-only pending candidate without erasing its retained restriction history.
The current generation can then request a fresh grant. A metadata-only provider
revision is compared against the saved scope fingerprint after signed permission/
disable checks, without reconstructing an old grant or clearing received kills.
Foreground UI-restart renewal is connected; background renewal remains open.
This source has not been tested or built.

Stage persistence precedes the native stage request. The digest covers the exact
host input after materialization and Windows rule-set bundling; those private
input bytes are neither logged nor retained here. Both hosts reject a different
expected digest before staging, and the client checks the stage acknowledgement.
A native snapshot taken during preparation identifies the running/staged entries
to retain alongside the next candidate, so failed preparation does not evict the
old reusable profile's restriction inventory. The next preparation discards
abandoned candidates; ordinary reads also prune expired entries. A prepared
entry with received decisions cannot be reused for a new stage.
An entry with received service revocations also prevents staging those services
from the same old catalog payload under a different profile digest. The coordinator
retains the last such payload/service set through a profile switch if persistence
fails; catalog revision floors remain the boundary against older replacements.
The same secure key, schema version, three-slot limit and 1 MiB document budget
apply. Older clients that do not understand the ten-field entry reject and preserve
it; no plaintext fallback or destructive downgrade migration is introduced.
Startup/foreground refresh restores only the exact running native
digest, and received decisions become pending again; Core acknowledgement is
never persisted across a runtime restart. Termination dominates drain in both
memory and serialized storage updates. Reads/writes share an app-isolate queue,
bound the document to 1 MiB, preserve corrupt/future schema, reject clock rollback
and retain an observed clock even after removing expired bindings. A binding is
removed on the next store operation after both its original catalog expiry and
all original lease active limits expire.
It is runtime-scoped rather than a reusable account credential; switching accounts
cannot authorize it for a different profile or extend its lifetime.

A failed stage metadata write prevents sending the native stage request. Late
completion after the operation deadline or supersession cannot dispatch stage.
An acknowledged prepared record does not itself authorize a connection.
A received kill is retained before
native delivery with a bounded storage wait. Storage failure/timeout still allows
delivery to the current Core when action budget remains, but does not establish
durability. On a confirmed Core revoke the native host also invalidates reuse of
the matching staged profile, preserving the live Core for allowed draining flows.
Android requires a successful preferences commit before acknowledging this
invalidation; it retries a failed commit even if memory already appears empty.
Windows requires fresh staging after the current runtime stops and after service
restart. Neither path deletes the live profile assets or a different staged
profile.

An unavailable or corrupt inventory no longer prevents fetching fresh signed
catalog/access denial for the exact running native digest. The coordinator holds
that digest and received decision in memory without inventing catalog metadata,
lease identities or deadlines; it never writes this empty binding to storage.
Recovering matching metadata preserves the received restriction. Catalog disable
also suspends cache reuse before a bounded envelope-discard attempt, retaining
revision floors and corrupt bytes on failure. This does not prove durable recovery
after process death.

The same memory-only binding can latch signed provider-wide terminate or
issuance-only drain. Version-2 native control applies that action to all actual
Smart Access outbounds in the matching running profile without touching ordinary
catalog rules. Once known metadata is recovered, the action is projected onto
its existing lease IDs and persisted through the existing decisions map. No new
storage schema or fabricated identity is introduced. Older lease-only records can
also retain a whole-profile revoke without catalog dates; their original lease
active deadlines still bound retention, and no catalog payload identity is
invented. Durable storage recovery and fetching new restrictions without the UI
remain open.

No cache, crypto interoperability, restart or secure-storage checks have run
for this new implementation. They belong to the separately requested validation
phase after functional implementation.

Smart Access rendezvous selection adds no persistent state. The existing
ConnectionCoordinator lazily creates a random 256-bit session seed and clears it
on disposal; neither secure inventory, diagnostics nor API requests contain it.
Only eligible capability IDs already bound to the running profile provide active
affinity. A received lease/service/profile restriction disqualifies that affinity.
Restart may recover those restriction identities against the native digest, but
does not reconstruct the random seed, prove health or authorize another lease.

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

Smart Access native worker provisioning uses a memory-only restriction
capability; it is excluded from all persisted-state schemas, managed profiles,
diagnostics and logs. Before starting it, Android durably invalidates the
matching reusable profile and Windows removes the matching staged permission
under the runtime execution lock. Failure to commit Android invalidation blocks
worker creation. This preserves the live Core instance while preventing native
tile/service reuse of saved bytes that can later be restricted without Flutter.
The worker expires with the existing parent-session-bound delegation and does
not refresh that authority. Native decisions are transferred into the separate
secure restriction ledger described below before acknowledging the journal;
invalidation alone does not prove retention. Source only, NOT_VERIFIED.

The separate renewal delegation has the same memory-only boundary. Its mint API
temporarily sends an already verified signed grant; the native enrollment command
contains only the opaque `pkr_srn1.` credential and 23-field recovery identity.
Neither the credential nor that command enters secure storage, profiles, journal,
diagnostics or logs. The existing non-secret identity projection is shared with
foreground retention rather than storing another grant copy. Native enrollment
is bounded to 256 scopes / 1 MiB per worker and disappears with the instance.
Replacement of a live restriction worker may retain eligible enrollments with
their original monotonic deadlines. The journal handback below can retain
background-issued identities. Verified native polling/application now invokes
the producer before adoption. Foreground refresh enrolls a current verified grant
after successful restriction-worker setup and current catalog/provider/control
checks, with at most one mint per refresh. Only scope digest, lease ID and expiry
are cached in UI memory to suppress repeated successful enrollment. Profile or
operation-generation changes discard those receipts; no capability is persisted.

Core now retains a separate private native restriction journal before worker
enrollment. It holds at most three records, 256 non-secret lease identities per
record and 1 MiB minus 1024 bytes for the serialized document: native profile
digest, original catalog hash when known, random worker generation, pending
status, strongest policy restriction, catalog withdrawal, expiry, lease
identities and `scope_actions` (at most 256 scope digests mapped to drain/terminate).
Credentials and raw policies are excluded. A clean finish settles
pending; a crash can leave pending without
a live worker, which must be treated as uncertain recovery rather than proof of
either a kill or a clean state. Restriction I/O failure does not delay the live
revoke, and the precommitted pending marker remains available after a crash.

Native readback includes a snapshot hash and liveness. Only after durable client
retention of restrictions and lease identities may that exact hash be acknowledged. A changed snapshot is not deleted,
and live-worker records always remain. The Android/Windows/Dart consumer validates
the bounded schema and SHA-256 of canonical exported entries, then merges into
`pokrov-smart-access-native-restrictions-<platform>-<audience>-v1` through the
same serialized secure-storage queue as the three-slot lease inventory. This
separate ledger holds at most 256 restriction records / 1 MiB and a last-observed
UTC timestamp; clock rollback, corruption or a full ledger blocks new authority
without overwriting the unreadable data or acknowledging the native snapshot.

The unreleased native entry has ten fields including `scope_actions` and `leases`, an array of at
most 256 strict 23-field identities. The consumer hashes recursively sorted map
keys, preserving array order. Identity handback uses the existing main inventory
and its serialized queue, not a second grant store. Exact ID collisions, changed
immutable scope, regressed revision floors, missing original catalog metadata,
wrong capability or capacity overflow prevent ACK. Live/current identities and
existing decisions survive the merge; records with expired original authority
can be consumed without manufacturing a new binding. If the main inventory is
damaged or absent while authority remains, native records stay unacknowledged.
The separate restriction ledger is written first; either write failure prevents
ACK. A candidate retained by Core before a failed adoption cannot authorize
renewal without exact current-ID readback and a fresh signed grant.

Each secure restriction-ledger row has seven fields: profile/catalog digests,
strongest policy action, catalog withdrawal, uncertain-recovery state, optional
original expiry and `scope_actions`. Scope actions merge with terminate winning;
a later clean snapshot cannot remove a retained scope restriction. Known
expiry is the latest original catalog/active-flow bound from the native snapshot
and matching saved metadata. Core captures it from the accepted profile and
persists any larger renewal bound before adopting the renewed lease, so lost
client inventory does not discard that expiry. Missing bounds in both sources
leave expiry unknown; no replacement TTL is invented.
Expired known records are pruned on access. Unknown records remain until a
matching native snapshot establishes their bounds. A clean snapshot can supply
that original expiry without clearing a still-valid kill or recovery marker.
When the recovered bound has already expired, the retained record is removed.
Records with neither native nor saved bounds still require separate recovery.

Foreground refresh and catalog/Smart Access staging read, retain and then ACK
the exact native snapshot. One changed snapshot permits one reread within the
action budget. Staging requires no live native worker and checks retained
profile restrictions and matching catalog withdrawal/recovery before persisting
the new binding. Unknown catalog scope blocks catalog staging. Renewal retention
uses the same ledger gate. Pending without a live worker blocks reuse/renewal;
it is not converted into a signed kill against healthy active connections.
Scope-only restrictions affect matching leases in the exact profile. Stage rejects
any matching scope; renewal checks only the identity being renewed, allowing other
scopes to continue. Before ACK, the coordinator applies retained scope actions to
all known generations with that digest. A native scope-map overflow leaves pending
after worker completion, requiring recovery instead of claiming a clean stop.
Foreground native recovery uses at most two seconds and half the remaining
action budget, leaving time for independently signed foreground restrictions.
Failure prevents worker provisioning and positive renewal in that refresh.
No crash/device/power-loss validation has been run for this source implementation.

The additive `config_digest` in supported schema `1` is lowercase SHA-256 of
`egress-required + newline + route-mode + newline + UTF-8 config`. It identifies
local execution input, not a server revision or entitlement. Missing/malformed
values remain readable for migration but cannot authorize Quick Settings reuse;
the app must refresh and stage a profile first. Unknown schema records remain
untouched. A service start verifies the captured digest against the saved
metadata and actual file, then pins the verified bytes before replacing Core.

Staging restricts the pending file before `android.system.Os.rename` atomically
replaces the old file. A rename failure retains the old file. The preferences
write is committed before replacement; a failed commit prevents replacing the
file. A crash between metadata and different bytes produces a digest mismatch
and requires refresh, never a successful acknowledgement of different bytes.
This is not durable last-known-good rollback or device crash proof.

Android ATS staging adds `requires_bound_connect` to schema `1`. Missing means
legacy ordinary input; a present value other than boolean false requires bound
Connect. New `stageWithCoreIdentity` calls persist true before replacing the
config, so even identical bytes cannot acquire old ordinary reuse permission on
an interrupted stage. Quick Settings cannot start this profile. Restored runtime
state reports `canConnect=false` for ordinary Connect while the bit is set.
Service admission also requires the live process-local request, Core identity and
original deadline
before replacing Core/TUN; existing owner and content checks still apply. The bit
does not persist those capabilities, revive an expired request or grant healthy
lease handoff. This source change is NOT_VERIFIED; restart/power-loss tests remain
for the later validation stage.

## Transport manifest and monotonic floor (ATS-005, source only)

`TransportManifestStore` owns `pokrov-transport-manifest-<audience>-v1` in
FlutterSecureStorage. Its closed version-2 record contains `manifest`, optional
`rollback`, `floor`, `last_observed_at`, `clock_anchor`, and `last_elapsed_ms`; the whole encoded record is bounded
to 3 MiB. Signed envelopes retain the 512 KiB per-document bound. Floor contains
audience, epoch/revision, document kind/hash, observed UTC time and effective kill
refs. It contains no credentials, account/device IDs or operational profiles.
The anchor contains local-only boot reference, receipt elapsed milliseconds and
earliest/latest UTC at receipt. These boot references never go to API/telemetry.
Apple anchors use the same version-2 record, with `ios:<uuid>` or `macos:<uuid>`
from the native boot-clock bridge; they do not create another persistence lane.
Effective expiry is rederived from verified signed documents on each read.
The verifier's release-pinned key set is not copied into this record. An app
update adding/removing pins rechecks retained envelopes under its current pins;
a removed signer makes those envelopes unusable without clearing the floor.
A newer policy signed by a retained/new pin must still satisfy the existing
epoch/revision/hash/kills/time rules. Pin rotation never authorizes reenrollment
of an existing record or trust in keys contained in downloaded documents.

All instances use an audience-keyed queue in the app isolate. Accept observes
time, verifies immutable candidate bytes, checks generation/expiry and writes the
whole record before returning policy. Read verifies the exact committed
version/kind/hash and both signatures before returning. These methods provide
admission only; consumers must still enforce entitlement, capability and runtime
proof. Multiple isolates must not own this record concurrently.

Normal `accept` and `read` reject an absent floor. `enroll` is a separate API for
an explicit fresh online initial-state operation and refuses an existing record.
The bootstrap service supplies the current server floor/time from its matching
nonce exchange. Enrollment validates the exact epoch/revision/kind/hash and full
effective kill set; imported policy/response files are not an enrollment route.
It requires fresh boot-clock samples around the nonce exchange and admission.
It does not prove a physical first install or recover an existing corrupt record.
Corrupt/unsupported records remain untouched. There is no clear/reset method.
`discardEnvelopes` invalidates generations immediately, suspends in-process reuse,
then removes only envelopes, retaining floor/kills/time. Failed storage writes
also suspend local reuse until a fresh successful admission. Invalidation during
an older commit prevents its result from returning; the queued discard follows.
The loader also supplies a synchronous cancellation/budget predicate, checked
before admission and before/after policy writes. An already-started secure write
may settle after cancellation, without returning admission. No response nonce or
session token is added to the retained transport record.

Reads persist the upper UTC observation and latest native elapsed counter even
when policy is expired or suspended. UTC comes from the fresh server observation
plus elapsed time that includes suspend, not DateTime.now. The lower interval bound
gates not-before; the upper gates expiry and retained observed-time floors.
The interval accounts for server second truncation, the entire measured request
round trip and millisecond quantization; no midpoint or zero-delay assumption.

The same OS boot can reuse this anchor after app restart. Changed boot reference,
decreasing elapsed counter or unavailable host clock blocks offline reuse. A fresh
online accept can replace the anchor after reboot, retaining all version/digest/
kill floors and refusing to decrease the recorded upper UTC boundary. Version-1
records remain readable for their floors but require fresh online anchoring before
reuse; only successful admission writes version 2 at the same secure key. Unknown
or corrupt versions remain untouched. Withdrawal clears envelopes even without
a usable clock; it never needs to erase an anchor/floor to record denial.

Native boot/time APIs, Windows volatile-marker lifecycle, oscillator/VM behavior
and secure-write durability remain host validation requirements. This source does
not claim protection against a full machine/secure-storage snapshot rollback or
compromised kernel, nor prove physical reinstall detection. There is no plaintext
or local-wall-clock fallback and no automatic identity/floor reset.
`openSelection` now binds a process-local handle to the exact committed
version/kind/hash/kills, boot anchor and invalidation generation. It persists the
opening time observation; later serialized samples advance that same immutable
anchor in memory under native monotonic/expiry checks. Policy/anchor commits
invalidate handles before writing; withdrawal and uncertain storage writes do
likewise. Ordinary observed-time writes keep the anchor and do not invalidate
handles. Handle expiry/cancellation removes its registry entry. No storage schema
or key changes and no persisted session material are introduced by this view.
The loader binds account/install/access token through session rereads and
file-scoped write observers; closure signals owned cancellation in the coordinator.
All new source is NOT_VERIFIED; parity/crash/race tests remain deferred under the
owner's all-functionality-first instruction.
