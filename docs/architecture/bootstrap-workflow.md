# Bootstrap Workflow

This workflow gives client workers a consistent way to validate the canonical
`POKROV-app` tree, resolve Flutter dependencies, run local tests, and
materialize local-only config. The clean-room/Wave 7 wording below is retained
only where it explains bootstrap provenance.

Ordinary Android and Windows connect/reconnect refresh the authorized managed
profile before staging, even when a reusable staged path exists. Server-side
assignment changes therefore do not depend on the repair action or a local
settings change. Transient refresh failures may reuse only the existing fresh,
authorized cache permitted by `CachedProfileFallbackGate`; the UI identifies
that fallback and does not claim the new assignment was applied. The owner's
2026-09-07 decision permits a manual retry after dataplane failure using the
last downloaded or last proven profile within its original offline window.
An explicit authorization denial is separate from an unreachable API.

After an explicit disconnect settles to a non-running snapshot without a
failure, Home returns to its ordinary Connect action. The runtime's successful
status message is not a recovery notice. A reported failure keeps its message.

Historical mapping note:

- older docs may still say `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo came from `C:/Users/kiwun/Documents/ai/VPN/app-next/`
- this workflow now documents the canonical `POKROV-app` repo rather than the former in-repo bootstrap source

## POST12 Routing Catalog implementation

The local POST12 implementation now has signed Routing Catalog retrieval,
verification and last-accepted storage. Its current scope and default-off trust
configuration are in [app-first onboarding](app-first-onboarding-flow.md#post12-signed-routing-catalog-transport-not_verified),
with retention in [persisted state](persisted-state-contract.md). The default-off
connection-preparation branch now compiles route/DNS rules before normal host
staging. Later sections record the source-only app identity, selective UI and
provider lease work. These components have not been tested or built; native
artifact binding still needs its separate proof.

### POST12 catalog policy compiler (NOT_VERIFIED)

`routing_catalog_policy.dart` is the validated consumer projection of the
platform-owned v1 catalog. It exposes immutable service, domain and Android
identity data after checking the references/lifetimes that can authorize a
rule. These checks validate publisher assertions; they do not prove source
licenses, package installation or service health. The signature/cache path
requires a successful projection before accepting a new envelope.

`compileCatalogDomainPolicy` builds the curated domain layer for an explicit
mode, platform and access state. Full, Smart Safe and in-scope include/exclude
traffic default to VPN (or block when VPN is unavailable); selective defaults
to Direct and requires an explicit set of selected service IDs. Missing,
disabled, unverified, platform/access-ineligible or domainless selected services
fail as unsupported. No account entitlement is inferred from these arguments.

Exact domains and narrower suffixes precede broad suffixes. Equal domain/match
decisions are deduplicated in stable service-ID order; conflicting actions for
the same domain and match kind are rejected. An exact rule and a suffix rule
for the same name may differ: the exact rule takes precedence. A verified `blocked_inside_ru` service in
Smart Safe gets an explicit VPN rule when it would otherwise inherit the mode
default behind another service's broad Direct suffix. Shared hostnames fail
as not routable rather than extending one tenant's policy to all tenants.
CIDR/ASN metadata creates no rule. The output retains catalog/security revision,
digest, lifetime and mode/platform/access binding; domain lookup checks time.

Approved gateway intents use an authenticated lease only for exact covered
domain/match pairs, bound to this catalog/platform and the exact materialized
base profile. Missing or uncovered leases retain VPN/block with a per-rule
reason. Conflicting leases for the same domain are rejected, not deduplicated
into whichever provider appeared first. An explicit Direct intent does not acquire a silent VPN fallback.
Full cannot inherit curated Direct or gateway rules.

### Smart Access profile assembly (NOT_VERIFIED)

The feature-enabled online Selective preparation path now fetches provider
policy and grants through the existing bootstrapper under the existing
ConnectionCoordinator generation. It requires a fresh catalog, known eligible
access and loaded Core Smart Access version 1. The integrated selection subset
is a verified `web_request` capability for `current-origin`; RU-origin,
brain-origin, login, streaming and game proofs are not treated as interchangeable.
Eligibility checks run before equal-weight rendezvous selection owned by the
existing ConnectionCoordinator. Its random 256-bit seed is lazy, memory-only,
never transmitted/logged/persisted, and discarded with the coordinator. The
selection scope is service/platform/origin/feature/family; no account/install ID,
IP, SSID or interface fingerprint is used. An unambiguous still-eligible capability
from the matching running inventory supplies affinity unless restricted. An
inventory containing several candidates is not treated as native selection evidence.
Otherwise the existing IPv4-first subset is selected, then
providers and one capability per provider are ranked separately with SHA-256. More
capability rows do not give a provider more weight. A deterministic ID tie-break
handles equal scores, so input ordering and unrelated revision metadata do not
change the result. This affinity is not a health measurement or new entitlement.
Selection checks the current operation between scores and uses the existing
preparation budget. The ordered pool requires identical domain/matcher scope and
platform/origin/family/feature, with at most 16 providers per service (the catalog
reference bound) and 256 grants total. Running flows are not reselected. Remaining
features and end-to-end failover proof are still open.

One provider-policy request and one grant request per selected candidate run
serially without retries. Their combined time uses the
remaining existing profile-preparation action budget measured by Stopwatch.
Expiry or coordinator completion/supersession closes the request HttpClient;
generation, profile revision and account/install/session fences reject late
results. Authorization denial, TLS/signature/schema errors, cancellation and
exhausted preparation budget stop preparation. A connection failure (`API-002`
without an HTTP status) or HTTP 408/429/502/503/504 from provider-policy/grant
fetch retains the catalog's explicit protected fallback while budget remains.
After the first unavailable/rate-limited grant response, remaining requests to
that authority stop; already verified grants are retained for their own services,
and other services keep VPN/block. This does not classify provider health, rotate
egress, expand Direct, retry certificate failures or renew an expired catalog.
An authenticated `smart_access_*` HTTP 503 invalidates the provider policy store;
pending grants from the same preparation are dropped and the declared VPN/block
fallback is used. A generic transient 503 does not withdraw earlier grants.
An operator admission pause returns `smart_access_admission_paused` (409) on
lease issue. It likewise drops pending grants and uses the declared fallback;
account-access denial remains a preparation failure.
Lack of an eligible capability also retains the declared fallback. No API request
or provider probe was executed while implementing these sources.

`smart_access_profile.dart` binds the grant's SHA-256 to the exact UTF-8 base
configuration after ordinary runtime materialization and before local routing.
This is distinct from the native staged-request digest. The assembler checks
the same base configuration and rejects tag collisions or an already leased
base. Only verified grants can construct the bound in-memory profile set.

Each lease emits one `pokrov-smart-access` outbound with a deterministically
ordered permitted relay list, and a DoH resolver from the same grant using the existing Direct lane
and bootstrap DNS. The endpoint/domain projection enforces the Core public
address boundary, TCP/443 visible-SNI scope and canonical names. The timed route
matches the lease IP family and TCP/443; its DNS rule matches A or AAAA accordingly,
disables caching and rewrites TTL to zero. Other family/ports/UDP and new-flow
lease expiry use the declared VPN fallback while the catalog remains current,
then block. Core rejection after ClientHello is not silently retried via another
egress. DNS answers are not synthesized and certificate validation is unchanged.

The optional permission `relay_connect_policy` is copied into the signed lease,
validated and matched before native projection. Its six fields specify failure
threshold/window, cooldown, per-connect/total timeout and maximum attempts; no
working defaults are supplied. Null means one pinned attempt. With an explicit
budget, Core can try another permitted address of the same provider before
forwarding ClientHello, retaining successful affinity for new flows. Breaker state
belongs to the native outbound; established flows remain unchanged. TCP success
is not TLS/service verification. Operating values require later measurements.

Each service's route/DNS windows now contain the same ordered `lease_group` and
share a native selection anchored to its first outbound. The current member stays
selected while local admission, quota and TCP breaker permit it. Otherwise new
lookups/connections select the first available approved member, preserving that
choice even when an earlier member recovers. If none is available, the existing
scoped VPN/block rules apply. A failed connection is not replayed through another
provider; the group applies to subsequent rule evaluation. Both paths share the
choice, but cannot recall application DNS caches or a query already in flight.
No new grants, probes or profile/TUN replacement occur during selection. Existing
flows retain their own lease/provider. The complete candidate inventory, including
standbys, participates in renewal and exact revocation. The service-selection
sheet reads the native lease/selection snapshot on load/refresh and displays
pending, primary/reserve gateway or unavailable state with its read time. It
does not infer selection from inventory or claim successful service access or
VPN fallback. Profile/generation changes, catalog expiry or known global revoke
invalidate the display; failed readback stays unknown. The sheet observes runtime
snapshot changes and existing operation cancellation, with no new polling loop.
Both hosts bound the schema-1 object to 64 KiB; rows contain public service and
lease identities, state/index/availability only. They are neither persisted nor
sent as telemetry. End-to-end service/failover validation remains open.

The service sheet also optionally reads `fetchSmartAccessProviders` when Smart
Access is enabled and the catalog references capabilities. It reuses the existing
signature/audience/revision/time/session verifier and its action timeout, no retry
or alternative source. UI cancellation and connection-operation cancellation are
passed into that adapter; the current view, profile revision and access state
fence the returned metadata. The normal policy reader may retain its existing
secure version floors; the sheet retains the verified payload only in memory.
Failure is presented as unavailable evidence and does not change catalog choices.

Only capability IDs referenced by that exact catalog service appear in the
expandable evidence view. Feature/platform/origin/family, observation/expiry,
enabled flags, permission and classification stay distinct from native gateway
selection and from the time the app retrieved the policy. Other platforms and
unimplemented automatic feature/origin selection are explicitly labelled.
Technical provider/proof IDs and digests are secondary; provider endpoints and
raw grants are not rendered. The existing sheet expiry timer also follows policy,
permission and evidence validity boundaries, updating display only. Refresh,
close or the save reread invalidates earlier metadata; an unsuccessful save
leaves old observations stale until refreshed. No probe, grant, route mutation,
new periodic fetch or remote telemetry is attached to this view.

Provider capabilities now require the four named `checks` results for resolver
transport, DNS answer, TLS certificate and exact feature request. A verified
capability requires four PASS values; attestation, manual/blocked/skipped and
unperformed states remain non-PASS. The provider reader validates the display and
selection fields before returning verified metadata, including exact row shapes,
unique identities, provider/permission references, revision/time bounds, public
proof digests and supported enum/boolean values. The evidence view displays these
declared stage results without reclassifying them as a locally executed check.
This is a matching-source, unreleased policy-v1 extension; missing checks are
rejected. It adds no grant fields or native wire changes. Structured retained
stage artifacts and pre-signing inspection belong to the platform policy owner;
the client neither fetches nor stores those artifacts.

Existing safety, explicit LAN scope and manual rules still precede curated
rules. Core keeps the chosen relay for an admitted connection. Lease-backed
route/DNS windows also carry `lease_id`; Core binds it to the exact registered
Smart Access outbound before starting the rule. Its admission latch stops new
provider DNS choices as well as new relay choices on revoke/expiry, retaining
the already declared VPN/block fallback. Already admitted DNS exchanges and
application-owned DNS caches are not retroactively cancelled by this rule gate.

### Received provider revocation (NOT_VERIFIED)

The prepared payload retains verified grants only in memory. After a successful
native stage, the existing ConnectionCoordinator records the host's final
`stagedProfileDigest`; grants become eligible for runtime control only when
`effectiveProfileDigest` matches it in a running snapshot. A prepared or merely
staged grant is not a running lease. Stage replacement does not overwrite the
old active binding before the running digest changes.

The stage helper saves a restriction-only identity projection in existing secure
storage before sending native stage. The runtime supplies the exact final host
identity input after materialization and Windows rule-set bundling. The shell
hashes those private in-memory bytes and persists only the digest and restriction
identities. Android and Windows compare the expected digest before writing or
queuing the profile, and the client checks the returned stage digest. Failed
storage or superseded/timed-out preparation therefore sends no native stage.
Prepared metadata alone cannot start a lease. On startup/foreground refresh, a
matching running native digest can restore that identity set and received kills;
it cannot restore a grant for compilation or change any deadline. Details and
failure boundaries are owned by the [persisted-state contract](persisted-state-contract.md).

Successful stage acknowledgements also retain the verified grants in memory for
renewal scope comparison. `SmartAccessLeaseRenewal.prepare` requires a matching
saved scope identity, its current lease ID read from Core, a distinct fresh signed lease, unchanged
base profile/mode, provider/permission/capability/service, platform/origin/family/
feature/transport, relay list, resolver, domain matcher set and quotas. Revisions
cannot decrease; a newer catalog/provider revision alone is not a scope change.
The immutable comparison now uses a domain-separated SHA-256 fingerprint computed
after full grant verification. The same fingerprint and minimal grant request
inputs/revision floors are saved with the restriction identity. No grant, endpoint
or domain list is serialized there. The original 13-field identity remains usable
for restrictions; new 23-field identities prepare for restart recovery but do not
authorize it without a fresh signed grant and exact current native lease identity.
The new admission deadline must advance without exceeding the original running
catalog expiry. Existing flow deadlines are not rewritten. A recovered binding
can now use this preparation after current native ID readback and fresh signed
control/catalog/provider/grant verification. Its saved data cannot authorize renewal alone.

The prepared value is only a pending renewal. Foreground refresh requires a fresh
signed `none` control decision, verified catalog/provider policy, current native
lease readback and loaded native control version 4/runtime control version 1. Once half of that grant's
original admission window has elapsed, it requests a fresh grant through the
existing account/device API within the refresh budget. This adds no new TTL or
background timer. Received restrictions prevent renewal.

The coordinator retains old/new identities securely and adopts that inventory
before native dispatch. Only a positive exact-profile/old-ID/new-ID reply changes
the current verified grant. An uncertain result retries the same pending grant.
Once that candidate expires, a new native read determines the actual current
generation before another grant can be prepared; retained history is not guessed.
At most one renewal per service is attempted within the shared refresh budget.
A known runtime
stop drops in-memory renewal authority while preserving restriction metadata.
Hosts invalidate matching staged-profile reuse before enabling the new lease.
Route/DNS windows retain the original catalog lifetime and also check the current
lease; old flows keep their original deadlines. Background renewal is connected
across platform, client and native source but remains NOT_VERIFIED in runtime.
Foreground UI-restart recovery is connected in source, NOT_VERIFIED;
retained binaries have not acquired these methods.

Ordinary staging rejects a Smart Access outbound without this persistence path.
A WARP rewrite of such a profile requires fresh preparation and a new binding;
the existing bounded WARP fallback uses fresh baseline staging in that case.
It does not copy the old lease into a different profile identity.

Existing foreground resume and account-summary refresh fetch one fresh signed
restriction control response before the provider policy, with no retry loop. The
control response binds a fresh nonce, per-request account/device hash, native
profile digest, platform/audience and at most 60 seconds of response freshness.
It uses lease pins with a separate signing context, even if provider trust pins
have been withdrawn; issuing a new lease still requires both trust sets.
Known access or whole-policy/
catalog disable terminates this profile's Smart Access leases; issuance-only
disable drains them. The operator's separately persisted admission pause uses
this same `issuance_disabled` / `drain` response. Resuming admission on the server
does not clear an already latched client/native restriction: fresh authorization
is required. None cannot clear a latched decision or authorize/renew any
flow. A failed control request may still be followed by independently verified
provider restrictions within the same budget. Account/install/session, coordinator
generation, active binding and shared action-budget fences reject late work.
A newer policy with unchanged relay/resolver/domain scope, capability, quotas and
current proof does not drain a lease whose original verified grant remains in
memory. Scope changes or restriction-only recovery still drain new/pending flows
while healthy active flows keep their original deadline. Removing/disabling the provider or capability,
withdrawing/replacing its permission, or shortening permission below the old
active deadline selects immediate termination. Missing/malformed/expired policy
and HTTP failures are not authenticated withdrawal decisions. Existing confirmed
account-access denial continues through the existing disconnect owner.

Received decisions are latched for the active binding; termination cannot be
downgraded by a later policy. Only a positive native response acknowledges the
exact lease. An unconfirmed command remains pending and is retried on a later
refresh even if the next policy fetch fails. Stopped/unknown snapshots do not
discard a received decision; a known non-running snapshot clears acknowledgement
so a restart needs delivery again. Native commands independently check the exact
running digest and lease identity and never replace the overall route.

Later refresh also retries persistence of the full in-memory received decision
set, including decisions already acknowledged by Core. A failed secure-store
write must not be mistaken for durability just because native delivery succeeded;
storage failure still leaves time for delivery and stricter signed control.

After Core confirms a received revoke, Android synchronously invalidates the
matching persisted Quick Settings profile and staged pointer; Windows drops
the matching staged-profile acknowledgement under its service execution lock.
The running instance and assets remain available for permitted draining flows.
A subsequent native Connect requires a new stage. Accepted service commands
finish independently of the Flutter reply callback. Android persistence failure
leaves the response unconfirmed; an empty in-memory preferences map is retried
with a disk commit, not treated as proof that invalidation survived process death.
Neither host invalidates a concurrently staged different profile.

An otherwise valid cached profile with an already expired Smart Access lease
can load an inert outbound in Core. New route/DNS choices take the declared
VPN/block fallback. No deadline is renewed and no new relay connection is allowed.

The same refresh handles ordinary catalog rules. Signed `catalog_disabled` or
`access_denied` latches a whole-catalog restriction and calls the exact-profile
native revoke; provider-only disable and issuance-only drain still affect only
leases. Core stops new choices through all timed catalog route/DNS rules and
terminates relay leases, retaining manual/safety rules and declared fallback.
Already routed non-lease connections and admitted DNS exchanges are unchanged.
The catalog's original issue/expiry and payload digest are persisted before stage,
including profiles without leases. Stored catalog disable also blocks staging
the same catalog payload under a different profile digest; account denial remains
an exact-profile restriction. New catalog rules require
native control version 4 and configured control pins; no new grant is implied.

Restriction inventory and received decisions now survive successful secure-store
writes and matching UI restart. If inventory reads fail or time out, foreground
refresh can still fetch signed control against the running native digest. An
empty in-memory binding carries only received restrictions; it supplies no grant,
lease identity or lifetime and is never persisted. Restoring metadata preserves
that restriction and acknowledgement for the same running instance. A known
runtime stop clears the acknowledgement so delivery can repeat after restart.
Signed catalog disable also suspends catalog-cache reuse immediately; a bounded
attempt to discard its envelope preserves revision floors. A failed write proves
no durability and does not prevent native delivery. Storage failure alone never
becomes a revoke.

Signed provider-only disable and issuance-only drain use the version-2
profile-wide Smart Access command even without readable lease identities. Core
enumerates its actual Smart Access outbounds, preserving ordinary catalog rules.
Termination dominates drain in memory; a positive drain acknowledgement never
suppresses a later per-lease termination. Restoring metadata copies the received
action into the existing per-lease persistence map without minting grant authority.
Missing native support never becomes a positive acknowledgement; known identities
can still receive the exact-lease command. Durable storage recovery,
background-renewal runtime proof, breaker/failover and the remaining feature
matrix are still open.
Flags remain default-off; no artifacts, tests, formatters or runtime checks were
run and no release status follows from these source edits.

The existing foreground refresh can now provision a native restriction worker
after a fresh signed `none` decision. It mints a profile-bound, read-only runtime
capability through the normal account/device session API. Cancellation, account,
install, session and catalog-generation checks fence that response. The native
command contains only the short-lived capability, profile/platform/audience,
existing API origin, `dns-direct` resolver and locally pinned lease public keys;
the response cannot introduce trust keys. It is memory-only and never enters a
managed profile or secure-store document.

The app-first API adapter also supports single-scope renewal delegation through
`requestSmartAccessRuntimeRenewal`. It sends the in-memory verified grant to the
normal authenticated mint endpoint and fences account/install/session, catalog
and provider generations, the action budget, grant admission and original catalog
expiry before and after the request. The exact response must match nonce, final
profile, platform, lease ID and immutable scope digest; expiry cannot exceed that
catalog. The resulting six-field command contains the separate `pkr_srn1.` token
and the same 23-field recovery identity used by foreground renewal.

`RuntimeSmartAccessBackgroundControl.configureSmartAccessRenewal` carries that
memory-only command through Android/Windows to an already live restriction
worker. Core accepts only the exact current admission-capable lease and dates;
expiry must fit the worker lifetime. After native recovery, fresh control/catalog/
provider checks and successful restriction-worker setup, foreground refresh invokes
this adapter for a current verified grant (including an acknowledged foreground
renewal). At most one mint is attempted per refresh. Successful scope/lease/expiry
receipts stay only in UI memory and suppress repeated enrollment until expiry or
a different lease; profile/operation changes discard them. Missing verified grants
after UI restart require the existing foreground grant-renewal path first.
Enrolled Core source now polls, verifies the signed renewal,
records identities and applies the next generation. Identity handback is wired
to the native journal consumer described below. Signed scope-specific negative
responses revoke the exact native outbound and retain `scope_actions` before
handback. The client merges those actions before ACK and blocks only affected
scope renewals; global policy/catalog and uncertain-recovery gates remain broader.
No delegation mint request or new native artifact was executed for this change.

Hosts negotiate `smartAccessRuntimeControlVersion == 1` from the actual loaded
Core and matching method/export. Android uses its existing runtime executor and
session/generation/profile fence. Windows uses authenticated command 15 and
capability bit 13 through the existing serial service owner. Both invalidate
matching profile reuse before dispatch. The runtime/coordinator also discard
their matching staged reuse; the live graph remains active. Core validates
signed request-bound restrictions and fences each delivery to the captured
instance/worker. It uses bounded protected HTTPS requests, waits 30 seconds
between cycles and stops at delegation expiry. A separate enrolled renewal
capability permits at most one due scope renewal after a fresh signed `current`
control. The restriction-only credential cannot grant or renew, and the worker
cannot refresh its own credentials. A later `none` does not undo a received restriction.

Native decisions now pass through bounded read/retain/ACK recovery during
foreground refresh and before catalog/Smart Access stage. The separate secure
restriction ledger retains kills and uncertain crash markers before exact-hash
ACK; a changed snapshot allows one reread. Stage requires no live worker and
rejects matching profile/catalog restrictions, including cached profile stage.
Renewal retention checks that ledger too. Foreground recovery receives at most
two seconds and half the remaining action budget; failure blocks new worker
provisioning/renewal while leaving time for signed foreground restrictions.
Native snapshots include original profile authority expiry, including persisted
renewal extensions. Recovery keeps the greatest known native/saved bound and
can prune an expired record without reconstructing its grants. Records with no
available bound and positive-authority recovery still require further work.

Native journal readback now includes a bounded `leases` array of non-secret
23-field identities. Before ACK, recovery also reads the exact running native
lease IDs, checks the recursive snapshot hash and merges journal identities into
the existing secure inventory under its original catalog/scope binding. It keeps
live history and current native identities, preserves all received restrictions,
and updates active coordinator metadata without reconstructing verified grants.
An obsolete foreground pending renewal can be discarded when neither generation
is current; its persisted metadata remains. Main-inventory corruption or missing
binding prevents ACK while the native record has live authority. Restrictions
are still retained first, and the native journal remains available for retry.
Background polling now invokes this producer before applying a verified next
identity. It rechecks instance/worker/enrollment/current lease and wall/monotonic
deadlines before and after the write. Old flows keep their original deadlines;
late, invalid or failed responses cannot extend access. This is source behavior,
not an observed background-runtime result.
Native reuse invalidation alone is not proof of retention. No runtime polling,
new artifact, test, build or production activation has been performed.

Foreground refresh now compares a complete verified catalog replacement against
restriction metadata saved before stage. That metadata contains original catalog
revisions, audience/platform/mode/access context, service IDs, hashes of the
compiled domain/matcher/declared-intent tuples and used provider capability IDs.
It contains no domain list or reusable grant. A newer non-rollback replacement
withdraws a service if it removes/disables it, loses verification/eligibility,
or no longer allows every original compiled rule. Removal of a used capability
terminates only matching retained leases, preserving other approved candidates
and the service's declared VPN/block fallback.
Adding domains or renewing TTL/display/evidence metadata alone leaves existing
admission unchanged. The original catalog and lease deadlines are never extended.

Received service restrictions persist before bounded native delivery and survive
matching UI restart; only positive native replies acknowledge them. Version-3
control targets the exact running profile and service ID. Core closes that
service's timed route/DNS windows and linked relay leases, retaining the declared
untimed block fallback and unrelated services/manual rules. Already routed
non-lease flows are unchanged. Known revoked scope cannot be restaged from the
same old catalog payload under a different profile digest. Invalid/failed fetches
never become withdrawals. New routing authority still requires the existing
fresh profile preparation/apply flow; this path only tightens the running scope.

This is the curated layer, not a second native routing owner. The assembler
places retained reject/block and DNS-handling rules first, explicit user rules
next, then catalog pairs and retained VPN rules. Android's existing Builder
include/exclude boundary remains in the TUN configuration. No compiler/cache
tests, analyze, builds or native actions have been run in this functional stage.

### Native catalog lifetime and host negotiation (NOT_VERIFIED)

`routing_catalog_materializer.dart` now turns the compiled domain layer into
contiguous route/DNS pairs. An active rule carries `pokrov_catalog_window`
(`issued_at` and `expires_at`, UTC whole seconds); the immediately following
rule rejects the same exact domain or suffix. Block decisions emit only reject.
This prevents an expired protected rule from falling through to selective
Direct or a broader catalog exception. An expired explicit Direct exception
also becomes unavailable instead of silently taking VPN. Approved gateway
actions still require the separate lease implementation.

The owned Core source gates top-level, non-inverted domain rules by both wall
time and a process-monotonic deadline, latching expiry for that rule instance.
Timed rules inside logical rules are rejected. Timed DNS routes disable cache
and rewrite TTL to zero. This governs new routing decisions; it does not close
already admitted connections, establish a trusted clock across process death,
or prove visibility of private DoH/ECH/QUIC traffic.

The materializer requires native lifetime version 1. Android reads
`Libbox.routingCatalogWindowVersion` after successful initialization, using
reflection because the currently retained AAR lacks that additive getter.
Missing, failed or unknown getters report zero. Windows derives the version
from the exact descriptor of the service-loaded DLL after initialization and
passes it through the negotiated IPC snapshot extension. Flutter retains it
in `RuntimeSnapshot.routingCatalogWindowVersion`, including state equality;
older hosts and undeclared platforms default to zero. A source change or an
artifact filename never grants this capability.

These source changes do not replace pinned AAR/DLL bytes or enable the feature
flag. The separate
verification stage must cover expiry/fallback pairs, old/new host negotiation,
background restart and actual artifact exports. Core Go formatting remains
pending alongside the Core contract documentation update.

### Connection preparation with the catalog (NOT_VERIFIED)

The ordinary shell preparation path fetches the signed catalog, reads the
loaded host's lifetime capability, and compiles using the managed manifest's
access state, platform and mode. It rejects stale connection generations and
changed profile preferences before applying the result. The existing runtime
owner stages the resulting profile; no additional tunnel coordinator is added.
An enabled feature with missing trust, invalid/expired catalog, mismatched
profile binding or missing native support fails before stage. Disabled builds
retain their existing path. Artifact pins and public mode defaults are unchanged.

Full and Smart Safe map from `fullTunnel` and `allExceptRu`. Their in-scope
default remains VPN. The catalog branch removes implicit Direct classifications,
including legacy RU lists, and drops unreferenced rule-set definitions. It also
skips the bootstrapper's legacy RU asset download. Retained reject/block rules
precede manual and curated rules. Explicit domain/IP/subnet overrides, purpose
selections and the current separate LAN setting remain local user policy;
an explicitly selected RU purpose is a manual exclusion, not a verified catalog
classification. Catalog app discovery and LAN runtime acceptance are not
claimed complete by this change.

The final preferences pass now implements explicit LAN scope in both catalog
and ordinary profiles. LAN is disabled by default and admits only user-entered
RFC1918 / IPv6 ULA CIDRs (up to 16); no inferred private range is enabled by an
old boolean. The allowed CIDRs route Direct, followed by an `ip_is_private`
reject before manual/catalog/default routing. Existing mandatory reject/block,
DNS interception and sniff actions stay above these rules. Inherited blanket
LAN DNS decisions are removed or narrowed to the same explicit CIDRs; tunnel
server DNS bootstrap remains separately owned. A local destination outside that scope
does not become Direct merely because Selective defaults to Direct.

The LAN setting is an address-range permission on any network using those
addresses, not automatic interface discovery or a trusted-Wi-Fi binding. IPv6
link-local is not admitted without interface scope. The route explainer reports
the local-IP safety block instead of a VPN/Direct route. This describes traffic
intercepted by Core; OS exclusions and bypassed application DNS retain their
separate capability limits. Fresh stage marks `lanScopeVersion: 1`, and Android
Quick Settings cannot reuse an older profile without that marker. The Android
stage route-mode allowlist also accepts `selectiveServices` as device interception
with locally compiled selected-service routing. No tests or runtime acceptance
have been executed for this change (`NOT_VERIFIED`).

Manual domain/purpose choices and catalog choices receive matching Direct/VPN
DNS lanes. A custom HTTPS resolver gets a copy on each detour; its chosen
transport controls the default, while service-specific DNS follows the service
route. Exact tunnel-server DNS bootstrap remains ahead of manual/catalog rules.
Legacy DNS server selections are replaced, while explicit reject/rcode actions
remain. Catalog route/DNS pairs retain their expiry fallback.

Android include/exclude modes require the corresponding nonempty TUN package
list and reject simultaneous lists. Windows currently admits catalog policy only
for full and Smart Safe: shared OS DNS processes do not prove per-app requester
scope, so that combination is explicitly rejected before stage. This is an open
Windows implementation requirement, not parity or a completed WP-12 claim.
Native app-identity changes and the bound catalog expiry now stop the affected
Android session; runtime handoff and rollback acceptance remain open. Existing external
Smart DNS preferences cannot be combined with the catalog without a lease.

Android TUN replacement within one runtime keeps the old descriptor until the
new `Builder.establish()` succeeds and the new descriptor is published. If
establishment fails, the old interface and its DNS/probe callbacks remain owned.
Successful establishment fences the old callbacks before publishing the new
interface. A new runtime session
still closes its predecessor during startup; this change alone is not a
seamless profile-switch proof. Source is
`NOT_VERIFIED` until the later build and device checks.

An authorized cached managed profile uses `cacheOnly` catalog retrieval. This
does no HTTP request, rechecks the current session and re-verifies the retained
public envelope; it neither extends the catalog lifetime nor renews the managed
profile's offline allowance. A missing/expired/disabled catalog cannot silently
restore legacy broad RU rules. The signed emergency-profile path remains its
separate existing authority and is not converted to a routing-catalog grant.

### POST12 catalog policy preview (NOT_VERIFIED)

The selective compiler now requires a nonempty explicit service selection and
rejects a selected service whose declared intent is Direct. Every selected ID
must resolve to an enabled, verified, platform/access-eligible service with
domain rules; unsupported or removed IDs fail the entire compilation. Gateway
unavailability still resolves to the declared VPN/block fallback. The compiled
policy retains an immutable copy of the selected IDs separately from deduplicated
domain rules. A caller's later selection edits cannot change that policy.

Selective preview uses this selection instead of inferring it from shared
domain rules. An unselected service stays unselected even if a selected service
has the same domains; overlapping domain scope is disclosed instead of promising
that all of its traffic stays Direct. Unknown remaining traffic follows the
selective Direct default, without a device-wide protection claim. This closes
compiler/preview selection semantics. Provider-lease integration and native
selective routing/proof acceptance remain required work.

Enabled-catalog Android/Windows builds now offer a separate service-selection
action inside Rules, leaving public mode seeds/defaults unchanged. The sheet
lists current service eligibility, retains unavailable/removed saved entries
for explicit removal, previews selected VPN/block/fallback decisions and known
domain overlap, and refuses empty/conflicting selections. It re-reads the
authenticated catalog before save; changed digest, access or local profile
revision requires refresh/review. Expiry disables save, resume refreshes the
view, and pop/disposal invalidates pending reads/saves. The scrollable header
and list share a bounded sheet with a separate save button.

Save updates the explicit mode and local service set together, invalidates the
reusable staged profile and takes effect on the next connection. It does not
disconnect the current tunnel. Missing native capability is disclosed before
save and remains mandatory at actual profile assembly, after normal runtime
initialization; saving a preference is not native apply. Restored Selective
intent remains visible even when the catalog feature/platform is unavailable.
In that state, or with an empty selection, Connect opens Rules and refuses to
substitute another mode. Disconnect remains available. A reconnect is reported
applied only when the runtime is running and the pending profile changes have
cleared. These UI/restore changes are source-only, NOT_VERIFIED.

Diagnostics source now carries `selective_services` in the typed network summary
and PSD3 short code. PSD1/2 retain their existing route meanings; the platform
decoder accepts all three formats and also closes its previous PSD2 gap for
release build numbers. The new format marker prevents prefix-only relabelling.
Cross-language vectors, encrypted-bundle round trips and runtime UI acceptance
remain in the separate verification stage.

`RouteMode.selectiveServices` now flows through the client profile model and
catalog assembler. The bootstrapper accepts it only on Android/Windows with
configured, enabled catalog trust. As with the existing Full/Smart Safe paths,
the backend route-policy request uses `all_traffic` for OS interception; the
client's explicit mode defines routing inside that scope. The selected service
IDs remain local and are not repurposed as `selected_apps` or sent with that
request. This is not a new backend entitlement or provider authorization.

The assembler requires a current selective catalog policy with the exact local
selection. It removes inherited outbound-routing classifications, preserves
safety actions and explicit user rules, inserts the compiled lifetime/fallback
pairs, and sets the remaining route and DNS defaults to Direct. Selected VPN
service DNS keeps the VPN lane. A missing catalog cannot use the legacy
assembler, and Android package-include scope cannot silently narrow this mode.
The bootstrap base keeps a VPN-capable target for selected-service rules; the
catalog assembler changes the default only after checking the binding. These
source changes are NOT_VERIFIED and do not add selective mode to public seeds.

Selective materialization also reserves the exact owned `api.pokrov.space`
TCP/443 proof route and its DNS rule on that same protected outbound. Retained
reject/block and DNS-handling safety actions still precede it; local LAN,
manual and catalog classifications follow it. Its DNS rule disables Core cache
and returns TTL zero. The ordinary DNS bootstrap for tunnel servers remains
Direct; a tunnel server using the proof hostname is rejected before stage to
avoid a dependency cycle. The assembler requires the original base final to be
the protected target rather than selecting an unrelated available proxy.

Android startup endpoint preflight and selected-outbound Core proof share the
same target resolver. For a Direct final it requires one exact owned HTTPS rule
and one matching DNS rule whose resolver detours through that target. Missing
or ambiguous binding yields unavailable proof, never Direct success. The rule
binding survives host `_meta` stripping and remains part of the staged profile
digest. Non-Direct final profiles retain their existing target selection.
Windows keeps its existing service-owned authenticated HTTPS verifier; the
compiled rule now routes that request through VPN in Selective. This proves
only the selected protected transport when executed, not every service or the
whole device. Host routing, DNS/cache, cancellation and failure acceptance have
not been run for this source change (`NOT_VERIFIED`).

`AppFirstRoutingCatalogService.routingCatalogEnabled` exposes only the feature
state, not key readiness or a support claim. When enabled, the Rules screen
fetches the verified catalog through that same authenticated/cache-aware service
and reads a native snapshot. It calls `compileCatalogDomainPolicy` for the
current mode/platform/access with prospective VPN availability. No bootstrap,
profile write, entitlement creation or native connection is triggered by this
view. Core version zero means missing/unnegotiated support, not proof that an
update alone resolves the limitation.

When the routing catalog is disabled, a previously saved verified RU app preset
remains an ordinary selected/excluded-app choice. Connection staging does not
request the catalog or require fresh catalog app attestations for that choice;
the selected app IDs still go into the managed profile request and the chosen
route mode is staged on Android. Transport Manifest profiles without a catalog
policy bind their Core identity without catalog restriction persistence; native
staging still rejects a config that contains catalog or Smart Access restrictions.

`routing_catalog_preview.dart` displays the compiler's decisions, including
deduplicated domains shared by service entries. Source-only, disabled,
ineligible, app-only and unselected-mode services receive explicit unavailable
descriptions rather than a supported badge. Service names and route summaries
are primary; revision and signature-check time are secondary. The UI does not
display raw provider material, domain lists or app inventory. Manual/safety/OS
scope remains outside this curated-layer preview and is disclosed as such.

Mode/profile/access/capability/feature-owner changes recreate the view. Local
request generations discard late results, foreground resume re-fetches, and a
one-shot expiry timer hides expired decisions even while the screen stays open.
Refresh failures clear the prior preview. The old static RU preset summary is
hidden for the enabled feature, including loading/error states; default-off
behavior is unchanged. This is not an effective-policy acknowledgment or a
service reachability probe. Flutter/host tests, rendering and expiry/lifecycle
acceptance remain for the separate verification stage.

### POST12 Android catalog app discovery (NOT_VERIFIED)

`AndroidCatalogIdentityResolver` and `CatalogAndroidDiscovery` now feed the
existing explicit RU-app preset preview when the signed catalog is enabled.
The host queries only the requested catalog package names (at most 256), on
the existing bounded worker scope. It returns current signer digests, ordered
rotation history and browser/shared-UID flags to the local Flutter process.
The preview retains per-package match outcomes; connection preparation briefly
keeps the matched signer set for the exact selected packages. No package inventory,
certificate observation, UID or app path is sent to a backend or journal.

The matcher selects enabled, verified Android services with a current-access
Smart Safe Direct intent. Current signer sets must match exactly; a supplied
catalog lineage must also match in order. Single-signer observations use the
last certificate in the OS-proven history; multi-signer observations require
the complete current set. This follows [Android SigningInfo](https://developer.android.com/reference/android/content/pm/SigningInfo).
Browsers/containers and shared or unknown UID scope are manual-only candidates,
not automatic Direct recommendations. A declared Android
[`sharedUserId`](https://developer.android.com/reference/android/content/pm/PackageInfo#sharedUserId) remains
manual-only even if package visibility shows only one package for that UID.
API levels below 28 report unsupported.
Browser/container declarations apply across the entire verified catalog, even
when that declaring service is disabled or ineligible. A package shared by
eligible services is also manual-only if any of them lacks a Smart Safe Direct
intent (including VPN, block and the VPN default). A matching Direct entry
cannot override that conflict to recommend a whole-app exclusion.
Missing/disabled or visibility-filtered packages report unavailable, which is
not proof of absence. The existing manifest visibility remains unchanged; see
[Android package visibility](https://developer.android.com/training/package-visibility).

One process-memory scan cache binds to the catalog digest, requested package set
and package-event generation. Install/remove/replace/change invalidates it;
a change during scanning discards that result. The bridge registers its receiver
before dispatch and unregisters on close. The rules card refreshes on foreground
resume and manual refresh. After preview confirmation it bypasses this cache and
requires the same currently matched package set before applying the person's
selection and the same catalog-backed source. Failure offers retry without falling
back to package-name-only recommendations. The Android VPN Builder aborts the
connection if any selected package cannot be applied; it does not start with a
partial app scope. More than 128 selected apps is rejected instead of truncated.
Disabled catalog builds retain the legacy manual preset path.
The client remembers whether a saved RU preset came from the verified catalog.
Before each Android connection, including cached-profile fallback, it rescans
the selected packages against a still-valid signed catalog; a missing or changed
match stops that connection. Newly eligible packages are not added silently.
Catalog-backed presets are ineligible for Quick Settings reuse without the UI.
The stage now carries the exact observed signer set, rotation lineage and signed
catalog digest/expiry to Android. Native keeps that identity snapshot only in
process memory and rescans the exact selected package set before each TUN
establishment. A changed,
missing, browser or shared-UID package aborts establishment. Package
install/remove/replace/change events for a bound package invalidate that
snapshot, close the active TUN and stop its runtime. The signed catalog expiry
also bounds the process-local snapshot by a monotonic timer, so rolling the
device clock back cannot extend it. A system time-change event rechecks UTC
expiry after a forward clock correction. In-flight work under the same runtime
scope is cancelled before serial Core teardown. A concurrent establishment checks the
invalidation again before publishing its new TUN. Process restart
requires a fresh stage; WARP configuration replacement cannot reuse the old
signer snapshot.

This is discovery and user-confirmed selection, not automatic app bypass. Manual
selections remain manual preferences; automatic app policy and verified store seed are still open. The 25–40 app
seed still requires real store/certificate evidence; no seed or physical-device
result has been fabricated. JVM/widget/identity-negative and package-event checks
remain for the separate validation stage; no build or device scan was run.

## Fast Path

From `POKROV-app/`:

1. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\validate-seed.ps1`.
2. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-workspace.ps1`.
   If an ignored Android Gradle wrapper script or JAR is missing, bootstrap first
   creates a GUID-named project under the system temp directory with Flutter's
   supported `--no-overwrite` Android flow, copies only the missing
   Unix/BAT/JAR wrapper files,
   and removes the verified temp directory. Flutter never repairs the tracked
   Android shell in place or replaces existing Android customization.
3. Build POKROV Core from its separate repository, then run `scripts/sync-pokrov-core-runtime.ps1 -CoreRoot <path> -Platforms android,windows`. The sync helper accepts only the exact source commit, version, sizes, and hashes pinned by the client contract. Apple artifacts must be built on macOS and remain manual.
4. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\run-tests.ps1`.
   This now analyzes testless foundation packages, tests every test-bearing
   package/app across all 11 Flutter modules, and runs both Android
   flavor tasks through `apps/android_shell/android/gradlew.bat` on Windows or
   `apps/android_shell/android/gradlew` on Linux:
   `:app:testDirectDebugUnitTest` / `:app:testStoreDebugUnitTest` tasks.
   On a clean checkout, the bootstrap phase materializes the ignored wrapper
   scripts and JAR before the flavor-specific unit-test tasks run.
5. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\build-windows-release.ps1 -SyncRuntime -CoreRoot <path>` when you want the local Windows analyze, test, build, and unsigned-package lane.
6. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-local.ps1 -DryRun`.
7. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\bootstrap-local.ps1` only if you want local config files under `config/local/`.
8. Treat `melos.yaml` as the future workspace entry once Flutter tooling is available.

## Generated Local Files

`bootstrap-local.ps1` copies:

- `config/templates/local.env.example` -> `config/local/local.env`
- `config/templates/device-overrides.seed.json` -> `config/local/device-overrides.json`

When any required Android Gradle wrapper file is absent,
`bootstrap-workspace.ps1` also runs Flutter's conditional `--no-overwrite`
Android generation in an isolated GUID-named temp directory and copies only:

- `apps/android_shell/android/gradlew`
- `apps/android_shell/android/gradlew.bat`
- `apps/android_shell/android/gradle/wrapper/gradle-wrapper.jar`

The bootstrap does not copy Kotlin DSL files, IDE metadata, Flutter metadata,
or any other temporary project content. It skips each destination that already
exists, marks the Unix wrapper executable on non-Windows hosts, and fails if a
required wrapper file is still absent after repair.

The generated files are git-ignored and can be deleted or regenerated freely.

Treat everything under `config/local/*` and the generated Android wrapper files
as regenerated local-only workstation state. They are useful for local
prototyping and validation, but they are not release artifacts, product truth,
shipping truth, or release truth.

## Runnable Pieces

The clean-room starter now includes:

- shared domain, platform-contract, observability, typed diagnostic collector,
  encryption-only support-bundle, and support-context packages
- a shared Material shell that now locks the consumer-first tab set `Protection / Locations / Rules / Profile`
- Android, iOS, macOS, and Windows host entrypoints that build the shell from shared bootstrap defaults
- a widget test lane in `packages/app_shell/test/`
- Android-shell Flutter tests in `apps/android_shell/test/`
- Android Gradle unit tests in `apps/android_shell/android/app/src/test/`

## Runtime Boundary

This workflow describes the client runtime. The current public version is
1.1.6; the next target is 1.2.0+4055.

Current blocking dependency:

- Android and Windows bind POKROV Core 1.1.0 at source commit
  `acc892bb97b6ae4a00deaf77776a609f900310de`. The local AAR and DLL
  include the REALITY handshake fix. Their sizes and hashes are checked by
  `config/runtime-artifacts.seed.json`; installed-device behavior is still open.
- Core lifecycle errors crossing logs, status and platform ABI expose catalog codes while preserving their typed cause internally; the retained Core c8 privacy binding passed direct FFI planted-data checks; the current C02 binding preserves that source policy and records separate lifecycle/resource evidence
- managed engine log filtering runs before observable writers, subscriptions and replay buffers in normal and debug mode. Arbitrary messages and tags become `runtime_log_redacted`; only fixed AWG categories survive.
- device-bound `awg2_lab`, `awg31_lab` and `hy2_lab` envelopes do not participate in ordinary Smart Connect selection or automatic-node quarantine. Their typed endpoint is already the complete route decision. The bootstrapper clears `smartConnect` for those profiles and skips selection when no Smart Connect profile is present, so an unrelated VLESS egress failure cannot block a fresh lab fetch before Core starts
- owner decision 2026-09-13 leaves AWG3.1 as the only active AWG release-acceptance and development lane. Separate AWG2 gates and AWG2/AWG3.1 switching repeats are `SKIPPED_BY_OWNER`, not PASS. Existing AWG2 implementation and historical evidence remain retained pending consumer inventory. AWG3.1 still requires exact revision, device, failure, route and egress proof within its existing lab/default-off boundary; this decision does not enable public AWG.
- Those lab envelopes may advertise ordinary `legacy_reality_fallback` in
  `fallback_order`. Only then does the client retain their exact source revision
  as a TCP fallback candidate. A confirmed `core_egress_probe_failed` can make
  one fallback request through `GET /api/client/profile/managed` with
  `fallback_from_revision`; unavailable proof and arbitrary runtime errors do
  not trigger it. The server revalidates the current device/lab revision and
  ordinary TCP provisioning. The response must identify the expected REALITY
  transport and `<source-revision>:fallback:legacy_reality_fallback`; ignored
  parameters, stale revision or an unrelated response fail before staging.
  Promote the platform API support before enabling this client recovery path;
  an older server that ignores the query cannot supply an accepted fallback.
  The same route mode, selected/excluded apps and local routing preferences are
  materialized again. Existing WARP consent/fallback policy remains its own
  boundary. The rejected lab cache cannot be used for this retry. Both the lab
  transition and subsequent automatic node retries share the existing two-retry
  budget and generation fence. A manual Home action or location change cancels
  the pending transport choice; there is no persisted cohort mutation. Native
  stage/proof checks still decide whether the new connection is protected.
  A confirmed failed-egress result also enters this bounded fallback when
  Android keeps its TUN running. The retry first disconnects that failed
  runtime through the existing reconnect path, then fetches/stages the managed
  fallback; a running service alone does not keep the failed lab selected.
  Pending/unavailable proof still does not authorize a transport change.
  Android health polling covers the existing 55-second native watchdog for
  every transport, including AWG failures that settle after 21 seconds.

- `Android` host now reaches a real service-backed connect lane: it can initialize POKROV Core, stage a managed profile, request VPN permission, start a foreground `VpnService`, and hand tun ownership to the native runtime through the host `PlatformInterface`
- Android runtime discovery accepts either an extracted `nativeLibraryDir/libpokrov-core.so` or the ABI-matched `lib/<abi>/libpokrov-core.so` entry in the base/split APK. This is required on physical devices that install the release APK with native-library extraction disabled; Java still loads the packaged Core through the generated bindings
- Android runtime materialization is intentionally `tun`-only in this lane; desktop loopback listener inbounds such as `mixed-in` and `dns-in` stay disabled for the mobile `VpnService` path
- Android runtime materialization now keeps backend-managed `dns` servers, selector choice, and route-rule semantics whenever they are already mobile-safe, instead of swapping the whole profile into a custom universal DNS lane
- the Android bootstrap client uses the owned `app.pokrov.space/api/*` ingress
  as its primary control-plane origin and retains `api.pokrov.space` as the
  bounded owned fallback; provider IPs are not baked into the client
- when both owned origins are configured, the client first requires a 2xx JSON
  response from `/api/health`, caches the selected origin for the process, and
  only then sends the real request. The preflight carries no session or request
  body. A non-idempotent request is sent once and is never replayed to the
  second origin after a transport failure
- the Android route block keeps `auto_detect_interface: false`, removes `override_android_vpn`, writes `tun.exclude_package` for `space.pokrov.pokrov_android_shell`, injects a route-level self-package bypass rule, and enforces the same package exclusion through `VpnService.Builder`; the Core AWG endpoint is the bounded exception and requests platform protection directly for its owned UDP socket without changing the global route policy
- the Android host runtime retains default-network monitor hooks for DNS, uplink diagnostics, and network-change handling; ordinary staged routes do not delegate outbound-interface selection to libbox auto-detection, while a Core-requested AWG socket protection fails closed when Android rejects `protect(fd)`
- the Android host runtime now registers a local DNS transport backed by Android `DnsResolver` and the current default network, which keeps the mobile lane off desktop-only loopback DNS stubs when `libbox` resolves staged profile dependencies
- the Core-owned AWG endpoint resolves its inner FQDN with the route's explicit `default_domain_resolver` options, so Android uses that registered default-network transport instead of an empty resolver query; TLS verification still uses the authenticated hostname and any resolver or probe failure remains fail-closed
- an active Android DNS transport callback failure or timeout is terminal and fail-closes the core, TUN, and foreground service with a safe host snapshot; ordinary DNS response codes and canceled or stale callbacks stay non-terminal
- the Android default-network monitor now sticks to the callback-owned uplink after connect instead of re-sampling `ConnectivityManager.activeNetwork`, which keeps mobile DNS from accidentally treating the VPN network as its resolver uplink
- the Android manifest must also declare `ACCESS_NETWORK_STATE` and `CHANGE_NETWORK_STATE`, otherwise the `ConnectivityManager`-backed default-interface monitor fails before runtime start
- the Android `tun` inbound now uses the `mixed` stack instead of the desktop-oriented `system` stack, and the materialized mobile runtime no longer injects the old `android-private-dns-in` loopback bridge into the staged config
- the Android fallback DNS block preserves HTTPS DoH and its path in both the proxied remote and direct bootstrap lanes; it does not downgrade `https://1.1.1.1/dns-query` to UDP/53 or inject desktop loopback DNS surfaces
- the Android DNS block also keeps resolver caches independent so direct bootstrap lookups do not poison the remote resolver lane used for blocked-service traffic
- the Android host route planner now adds IPv4 and IPv6 default routes only for address families that are actually present in the staged profile, and `ipv4_only` sessions no longer keep an unnecessary IPv6 tunnel lane for blocked-service traffic
- the Android default-network monitor now filters out VPN networks before exposing the current uplink to `DnsResolver` or libbox, and it retries interface-index lookup before publishing interface updates
- emergency profiles use the same host/runtime ABI but a separate signed
  materialization path. Only the undetoured reserve root may receive the local
  Android bootstrap resolver; detoured RU and foreign hops must resolve through
  their preceding hop, otherwise the emergency chain leaks or fails under the
  exact blocked-network condition it is intended to recover from
- the emergency materializer accepts only the three documented acyclic chains,
  exact owned-hop placement, exact DNS/ruleset shape, no WARP and no foreign
  direct bypass. A signed catalog is necessary but not sufficient: the final
  managed profile is validated again before staging on Android or Windows
- after an online trial/paid check, the client prewarms one signed bundle for
  every fresh or still-valid signed last-known-good reserve and supported
  chain, encrypts it with a device-local key, and keeps it for at most seven
  days and never beyond account, catalog, or RU/manual-eligibility expiry
- emergency catalog and profile selection are cache-first. Starting a valid
  offline copy performs no control-plane request and does not download the
  normal client rule-set catalog before TUN start; the signed emergency
  ruleset is fetched through the selected reserve-first path after Core starts
- online refresh is best-effort and deduplicated. It replaces catalog and
  profile bundle only after every expected envelope passes signature, device,
  entitlement, revision, reserve, chain, topology, DNS, and expiry checks
- Android keeps an emergency profile's signed terminal proxy as `route.final`
  instead of wrapping it in the normal mandatory selected-outbound probe. A
  blocked control-plane probe therefore cannot tear down an otherwise usable
  emergency TUN. The profile still has no direct foreign fallback: if its
  reserve cannot carry traffic, packets remain closed inside the VPN while
  online catalog verification resumes when the control plane is reachable
- the Android host runtime snapshot now carries structured health fields for the shared shell, including default uplink interface and index, DNS readiness, route counts, package-filter counts, last failure kind, and last stop reason
- the Android lane now has a real repo-local test lane: Flutter tests assert the Android shell keeps the route-mode and runtime-diagnostics affordances visible, and Gradle unit tests cover manifest guards, platform monitoring, runtime-state handling, DNS planning, and TUN route planning
- the Android diagnostics story is now support/internal rather than first-layer UI: local smoke-profile staging and raw runtime controls stay out of the consumer shell while the physical-device gate remains separate
- the Android full-tunnel guarantee in this lane is also stronger: the mobile path stays `tun`-first, desktop loopback listeners remain stripped, backend-managed mobile-safe `dns` and `route` semantics stay intact, Android route ownership flags plus the self-package bypass remain present, and only address families present in the staged profile receive default routes
- the shared shell now treats Android `running` as cleanly healthy only when post-establish uplink/bootstrap-DNS prerequisites and the core URL test for the selected outbound are healthy; the core timeout sentinel (`65535`) is failure, not positive latency, and Android `NET_CAPABILITY_VALIDATED` remains supporting evidence because emulator/network stacks can retain it after selected-outbound egress fails
- for closed AWG endpoint probes only, Android also subscribes to the Core log
  stream long enough to accept the exact bounded
  `selected endpoint URL test failed category=<closed-category>` contract. The
  host discards the initial backlog and every arbitrary line, admits only the
  fixed Core category allowlist into the existing safe protocol-diagnostic
  fields, and retains no raw log text. Once captured, the terminal egress
  category takes precedence over later transport-retry categories until the
  next connection attempt. It never overrides the result of the specific
  endpoint probe call or weakens `EGRESS-001` fail-close
- Android endpoint verification calls the additive Core `CommandServer.ProbeEndpoint`
  method on the server captured for the active lifecycle task. A delayed result
  for another invocation cannot satisfy this call, and the existing session and
  generation fences still guard its application. Shared ABI1 operational events
  remain diagnostic breadcrumbs. A missing method or unknown invocation failure returns
  `UNAVAILABLE`, never healthy. Selector/urltest groups use the per-call
  `ProbeSelectedOutbound` method, which captures the selected proxy leaf and
  rejects a changed selection, runtime replacement, timeout, direct leaf or
  cyclic group. Shared URL-test history cannot settle protection health.
  Both methods are present in the exact replacement AAR recorded by the active
  Core binding decision. Packaged and device proof remain separate gates
- after Android reports `running`, the shared shell polls the host-owned egress result through a bounded 750 ms interval for the Core probe window; a terminal `core_egress_probe_failed` snapshot immediately replaces the protected UI with the normal disconnected/reconnect state, while a canceled or newer connect generation cannot be overwritten by an older poll
- a terminal Android selected-outbound egress failure stops false protection but preserves the bounded downloaded/proven profile cache. A manual retry refreshes opportunistically and may restore the last proven profile if the API is unavailable. Automatic transport/node failover still requires a freshly selected profile and cannot loop through the same cached failed endpoint.
- the Android host performs that selected-outbound fail-close as one synchronous profile-reuse invalidation: it clears the persisted Quick Settings profile and drops the staged pointer while preserving the safe failure snapshot, so a backgrounded Flutter shell cannot let the tile restart the rejected configuration
- Android Quick Settings may reuse only a freshly staged managed profile carrying Flutter's completed first-connect route-scope confirmation; legacy path-only or unconfirmed persisted records fail closed into the app
- Android service stop/start commands carry a monotonic ownership generation;
  source work additionally carries a local per-invocation request ID for Flutter
  connect/cancel, fences queued starts and captured Core callbacks,
  validates the staged digest until first TUN commit, and bounds startup
  endpoint DNS+TCP through a cancellable session worker. See
  [Android start ownership](platform-privilege-runtime-contract.md#android-stagestart-identity).
  These additions are NOT_VERIFIED pending the separate checks stage;
  a completed stop may release foreground state or call `stopSelf()` only when
  no newer start owns the service, so changing an emergency reserve cannot be
  torn down by the previous connection's delayed cleanup
- the Android Quick Settings tile uses Android active-tile mode, reconciles both the live TUN and the app-owned VPN-service presence before choosing start or stop, publishes only the resulting on/off state, and explicitly requests a new SystemUI listen after committed runtime transitions; the notification remains the owner of country, route and speed details
- the shared shell now refreshes Android runtime truth again on foreground resume, and keeps polling a host-owned pending-connect signal through Android notification/VPN consent even when no lifecycle resume reaches Flutter; the host bridge reconciles a live TUN back to `running` and demotes a stale `running` snapshot when the app-owned TUN is absent, so a relaunch or interrupted service cannot leave the button lane falsely connected
- the shared shell now treats `Connect with sing-box` as a one-tap lane on supported hosts: it auto-initializes the runtime, syncs a live app-first managed profile from the platform API, stages that profile, and then requests live connect instead of forcing manual `initialize -> stage -> connect`
- Smart Connect promotes the selected direct outbound inside that authorized profile by canonical `outbound_tag` (with bounded compatibility mapping for older manifests); a second exact managed-profile fetch is a six-second fallback only when local identity cannot be proven, not part of the normal connect path
- Smart Connect probe concurrency (default three) counts unresolved probes across
  profile resolutions on the same bootstrapper. A wrapper timeout ends the wait
  but keeps the slot occupied until the original probe settles; an exhausted
  pool skips further advisory probes. The default socket probe retains its own
  timeout. A late result releases capacity without becoming a new RTT sample
- Android and Windows VPN selector/urltest chains exclude the direct outbound in
  every routing mode, including server-materialized Windows profiles. Nested
  chains retain only paths to managed transport outbounds or AWG endpoints;
  their default cannot select direct. Explicit direct route/DNS rules, LAN
  preferences and platform per-app exclusions remain separate route decisions
- an explicit manual location variant is materialized from the exact managed
  profile only: `direct` requires the verified canonical base outbound to be a
  member of the final selector, while a bridge id requires one unique safe
  `_meta.ru_bridge.endpoints` id/label mapping and its exact selector member.
  The client never derives a bridge target from a host, key, detour, or fuzzy
  label and fails closed when any proof is missing
- device-local catalog cache and latency refresh preserve the safe variant
  projection; the selected variant id persists beside the manual node code.
  Automatic Smart Connect remains direct-selection-compatible and does not
  inherit that manual preference
- WARP with a manual bridge/`Белые списки` variant is gated before staging
  until focused composition proof exists. There is no implicit fallback to
  direct or to WARP-off for this user-selected combination
- production `variants` are additive safe labels projected by
  `/api/client/locations`: `direct` is rendered as `Обычный`, while each
  currently available relay is rendered as a `Белые списки` choice without
  host, port, key, tag, or raw config. Device cache keeps the last non-empty
  safe catalog across transient refresh failure. After a successful refresh,
  a removed or disabled relay id on the still-selected city is reset to its
  available `direct` variant, persisted, and applied through the normal
  reconnect path instead of pretending a stale selection still applies
- materialization creates one private `pokrov-variant-probe` URL-test group
  against the POKROV-owned authenticated-egress marker, containing the
  canonical selected outbound plus every exact, uniquely resolvable white-list
  variant. `_meta.runtime_variant_probe` owns the
  safe-ID-to-tag mapping inside the staged profile only. The Android host reads
  only the canonical managed-profile path, validates that mapping against the
  group, runs full or one-row refresh, and returns safe ID/status/latency/time/
  active ID. Raw tags and transport material never cross MethodChannel; missing
  or ambiguous mappings fail closed and render unavailable
- if the selected outbound fails its core-owned egress proof, the Android TUN
  remains fail-closed while one bounded full variant URL-test completes before
  teardown. Only the exact-catalog safe status/latency snapshot is retained in
  process memory for up to two minutes; it cannot reactivate a route, survives
  neither process death nor a different catalog, and reports no active variant
  after the runtime has stopped
- the `2026-08-14` production redacted readback proved `direct` plus `mini`,
  `ru`, and `ru_spb` for eligible non-US nodes and direct-only for `us`.
  Exact public-app visibility, selection, reconnect, and materialized runtime
  proof remain `MANUAL_OWNER_TEST` until the owner's phone is ADB-visible
- a confirmed selected-outbound egress failure in automatic mode quarantines the exact node for 15 minutes with an eight-node cap and at most two failover attempts; manual mode and unavailable probe evidence remain fail-closed without silent route changes; retry delays use 250/500 ms backoff plus 0–250 ms jitter, and the existing owner-generation check cancels stale retries
- Android reconnect now always resyncs and restages the live managed profile before start, which keeps the staged runtime config aligned with the currently selected route mode instead of trusting whatever was left from an older session
- the shared shell now keeps Android connect/disconnect transitions busy until the host actually settles, which prevents repeated taps from queueing duplicate service start or stop requests while VPN permission or teardown is still underway
- when the Android host tears down immediately after a failed start, runtime snapshot state now keeps the concrete startup failure instead of replacing it with a generic stop message
- Android stop dispatch now demotes runtime state before teardown, which reduces stale `Connected` snapshots during fast reconnect loops
- Android 14+ requires the `specialUse` foreground-service contract for that lane, so the host manifest must declare both `android.permission.FOREGROUND_SERVICE` and `android.permission.FOREGROUND_SERVICE_SPECIAL_USE` alongside the runtime service subtype metadata
- the Android runtime service now uses a non-sticky lifecycle and handles `VpnService.onRevoke()`, which keeps system-side revokes and interrupted reconnect loops from pretending the mobile runtime is still connected
- the Android foreground notification now exposes a direct `Disconnect` action, so operators and testers can stop the live runtime from the system shade without reopening the shared shell
- `All except RU` now has a client-side classification lane on both Android and Windows: the shared bootstrapper caches local sing-box `.srs` files under `getApplicationSupportDirectory()/pokrov-runtime/data/rule-set/all-except-ru-rule-sets`, injects those rule-sets into staged routing before connect, and still preserves `.ru`, `.xn--p1ai`, and `.su` suffix rules as a fail-open fallback when the cache cannot refresh
- the current `All except RU` cache pulls RU-focused geosite overlays from hydraponique `roscomvpn-geosite`, whitelist CIDR overlays from hydraponique `roscomvpn-geoip`, and the upstream `SagerNet/sing-geoip` `geoip-ru` rule-set for the broad RU IP catch-all
- selected-apps picker, route-policy sync, persistence, and runtime
  materialization are beta-active for Android and Windows; public production
  behavior remains gated on exact-artifact physical-device and clean-VM proof
- `iOS` source carries the POKROV Core packet-tunnel bridge: it stages one materialized profile in the shared app-group directory, persists a `NETunnelProviderManager`, boots `LibboxSetup`, starts or reloads `CommandServer`, and opens tun through `NEPacketTunnelFlow`; the framework build, signing, and device validation remain manual
- `macOS` stays on the desktop ABI 2 lane and expects only `pokrov-core.dylib`; the universal dylib must be built and probed on macOS before that host is runnable
- `Windows` copies `pokrov_service.exe`, the exact POKROV Core 1.1.0
  `pokrov-core.dll` and pinned `libcronet.dll` into the machine-wide release
  bundle. Raw materialized config, WARP, `Full tunnel`, `All except RU` and
  selected-process routing are owned by the shared adapter, then passed as
  bounded bytes to the authenticated service. The supported connection lane
  is `VPN/TUN`; advanced TUN stacks remain `system`, `mixed` (system TCP plus
  gVisor UDP) and `gvisor`. Legacy persisted `systemProxy` state migrates to
  this lane
- before securing the desktop config, the Windows runtime verifies every loopback-only helper port for both TCP and UDP. A collision with Hiddify or another local proxy is remapped to an OS-selected free loopback port; external listeners and profile routing are not changed
- generated Windows VPN profiles follow the proven POKROV Core/Hiddify system-TUN shape: `address`, `stack: system` by default, `strict_route`, a first-match `port: 53 -> hijack-dns` rule before LAN/direct or user routing, route-level `sniff`, typed TCP/UDP DNS servers, and no legacy `dns-out` or TUN-level sniff/NAT fields. The final preference pass reasserts that protected rule prefix after every other transform. The explicit port match is required by the shipped Core generation because Windows sends resolver packets to a private LAN DNS address before protocol sniffing has classified them. `Full tunnel` removes inherited Internet bypass rules while retaining local/private LAN access; selected and excluded process modes use opposite route and DNS decisions as their labels promise
- server-materialized Windows profiles also apply the current routing mode and
  process selection: stale process routes and DNS server choices are replaced,
  Full tunnel removes inherited Internet bypasses, and All except RU applies
  the local RU catalog. Profiles without a safe VPN path are rejected before
  staging. A missing direct outbound is added for explicit direct decisions.
  Existing inbounds and unrelated profile options remain; configured DNS
  server protocol, address, TLS and transport options are retained in the
  direct/VPN resolver lanes. With no configured network resolver, defaults
  remain TCP/UDP `1.1.1.1`. Direct resolver copies use local bootstrap instead
  of a self-reference to a generated resolver lane. DNS non-routing actions
  are preserved; user routing preferences apply afterward
- Windows manual location selection follows the VPN selector referenced by
  the selected-process rule when the default route is direct. The selected
  location changes that selector only; unselected processes keep direct routing
  and selected-process DNS keeps its VPN resolver. This applies to generated
  and server-materialized profiles.
- Windows VPN verification is service-owned. After Core starts, WinHTTP uses
  proxy bypass to request the owned HTTPS marker at
  `https://api.pokrov.space/api/public/authenticated-egress-probe`. Windows gets
  three bounded attempts while TUN routes settle. The service may enter
  `running` only after exact HTTP `204` and
  `X-Pokrov-Egress-Probe: pokrov-authenticated-egress-v1`. Failure stops Core,
  returns to `config_staged` and reports `core_egress_probe_failed`; raw DNS,
  provider or WinHTTP details never cross IPC
- the desktop runtime also keeps a bounded safe event journal at `%APPDATA%/space.pokrov/POKROV/pokrov-runtime/working/pokrov-runtime-events.jsonl`. It records UTC time, platform, a closed typed lifecycle event (`initialization`, `profile`, `core_start`, `tun`, `routes`, `dns`, `egress`, `recovery`, `stop`), bounded probe/stop reason, attempt, outcome, and allowlisted failure kind only; it never records profile contents, endpoints, visited domains, IP addresses, credentials, or raw provider/Core errors. Journal failure cannot block a connection, and files over 128 KiB are reduced to the latest 300 events
- The Android production and Windows release builders pass the committed Git
  revision and the pubspec build number into the operational build identity.
  They reject tracked source changes before compiling so a packaged journal
  cannot silently report zero values or attribute dirty source to `HEAD`.
  Local/candidate/channel labels keep their separate release authority.
- Android and Windows now start the shared operational-observability pipeline
  before `runApp`. Bootstrap start/finish/UI-ready, the exact
  `ConnectionExperienceReducer` phase, profile/Core/TUN/routes/DNS/egress
  proof, verified, rollback, stopped, update handoff, previous exit and crash
  marker are closed typed events. A successful attempt cannot be emitted until
  the reducer has current interface, routes/uplink, DNS and selected-outbound
  egress proof.
- Bootstrap and connection timeline events take their next sequence from the
  shared app dispatcher, including after restored Android routing counts or
  interleaved auth and entitlement refresh events. An early routing restoration
  cannot suppress the subsequent UI-ready event.
  Refresh cannot suppress a subsequent connection failure or terminal event as
  a duplicate sequence. The attempt generation stays fixed, so callbacks from
  an older attempt remain rejected.
- Every portal JSON request sends one canonical UUIDv4 `X-Correlation-ID`.
  A connection attempt keeps its attempt UUID in a zone-scoped request context,
  so managed-profile calls and the server request ID can be reconciled without
  account, install, device, destination or package identity. Requests outside
  an attempt receive a fresh UUIDv4.
- The app-private operational store remains authoritative only for diagnostics.
  Its initialization runs in the existing asynchronous writer, so a filesystem
  failure cannot stop bootstrap or a connection action. The bounded in-memory
  timeline remains available, writer failures increment `writerErrors`, and a
  later batch retries the same storage path without relocating diagnostic data.
  Its two-segment cap is 24 MiB on Android and 64 MiB on Windows. A separate
  best-effort mirror sends only the identity-free release-health projection
  after an app session already exists; observability never creates a trial or
  session. Correlation, attributes, destinations and identity are removed from
  the batch body. Portal failure cannot block local persistence or runtime.
- `previous-exit.v1.json` contains only closed run state, catalog crash code,
  fixed safe crash signature and the bounded breadcrumb ring. Crash handlers
  flush that marker synchronously because the process may terminate next.
  Clean exit overwrites it; an active marker on the next launch is reported as
  unclean. The marker is diagnostic evidence and can never restore or declare
  runtime state; host/service snapshot and recovery journal remain authority.
  Marker filesystem write failures are counted in `writeErrors` without escaping
  into bootstrap, normal exit or the crash handler; privacy validation still
  rejects unsafe values before an IO attempt.
- a failed Windows connect keeps its sanitized failure kind and message across subsequent runtime snapshots until an explicit restage or successful retry clears it; polling must not replace a failed `configStaged` state with the success copy `Профиль доступа готов`
- `scripts/test-windows-core-proxy-only.ps1` is the host-safe developer lane while another VPN owns Windows routes: it runs the exact bundled DLL through 100 loopback mixed-proxy start/stop cycles and never creates a TUN. A pass proves Core loading, ABI lifecycle, local proxy traffic and teardown only; Windows TUN, DNS capture and leak proof still require an isolated VM or Windows Sandbox
- source-level runtime tests cover the Windows TUN options for all three route
  modes; exact-candidate clean-VM SCM installation, routing, DNS/leak, connect,
  recovery and teardown proof remains `MANUAL_OWNER_TEST`
- the regular Windows shell stays unelevated and authenticates the service
  before connection. There is no process-token check, `runas`, `--connect` or
  per-user system-proxy fallback. Service absence, identity failure or protocol
  incompatibility blocks the action with bounded recovery copy
- `build-windows-release.ps1` verifies the Windows bundle metadata and uses
  Inno Setup 6 to stage an unsigned machine-wide setup EXE. Installer source
  captures the original owner SID, writes protected service configuration,
  creates/updates/starts the fixed SCM service and removes it on uninstall.
  Portable ZIP output is unsupported for this architecture. Per-user startup
  and `pokrov://` registration are owned by the ordinary UI
- host `build/` outputs and staged local bundles remain disposable local verification artifacts; they are not release truth for any public lane
- treat future live connect, service ownership, and traffic-carrying runtime work as one shared contract owned by the lane, not four host-local improvisations

## POKROV Core 1.1.0 Binding

POKROV Core is an independent repository and release line. The client now
binds local Android and Windows artifacts from source commit
`1aa713b37fa41491a92127cfb7a461608e3d96d7`. The version-derived
`v1.1.0` label is not yet a published Core release. Device and installed-VM
checks remain open.

- Android package namespace: `space.pokrov.core`.
- Android artifact: `pokrov-core.aar`.
- Windows artifact: `pokrov-core.dll` with pinned `libcronet.dll`.
- Apple artifacts are intentionally absent until built and proven on macOS.
- Desktop ABI `2` exposes `pokrovCoreAbiVersion`, `pokrovSecureFile`,
  caller-owned strings through `freeString`, and raw materialized-config start.
  New builds add the optional `pokrovCoreCapabilities` descriptor; released
  marker-only ABI 2 remains compatible, while any present descriptor is
  validated fail-closed before setup.
- Shared Dart materialization owns route modes and client-local WARP before the
  config crosses a host boundary.
- Shared Dart materialization also owns the additive `dnsTransport` client
  preference. Missing or unknown state resolves to `vpn`. For a selected DoH
  preset, the opt-in `direct` value changes only the injected HTTPS resolver
  detour to the profile's existing direct outbound; purpose routes such as AI
  and Games continue through the active VPN/AWG target. `Automatic` injects
  nothing, so the backend-managed DNS block remains authoritative. This is not
  a second DNS owner or a standalone VPN-less resolver service.
- The additive `externalSmartDnsEnabled` laboratory preference is stricter. It
  can materialize only with a validated custom HTTPS DoH address, the direct
  DNS detour and at least one AI/Games purpose route. The resolver and those
  selected purpose-domain connections then use the existing direct outbound;
  other groups keep the VPN/AWG target and explicit user rules retain higher
  priority. Invalid combinations fail closed before native staging. This is a
  client route-policy path for a compatible Smart-DNS resolver, not such a
  resolver, not a second core and not evidence of VPN-free service access.
- `selectedApps` materialization requires a non-empty selection before any
  route-policy sync or profile fetch. Android receives the staged route-mode
  attestation separately and rejects an empty selected-app allow-list instead
  of interpreting it as a device-wide tunnel.
- Windows selected/excluded modes additionally require a non-empty set after
  process-name normalization. A selection containing only rejected identifiers
  fails before bootstrap state, API access or native staging begins.
- In Windows selected-app mode the final route is direct while the selected
  process rule may target an AWG endpoint. Client routing preferences resolve
  that referenced endpoint for VPN/DNS additions without changing the direct
  final or selecting an unused endpoint.
- Android `excludedApps` also requires a non-empty selection. Materialization
  keeps the app itself and every selected package outside `VpnService`, then
  routes all remaining packages through the managed profile; the server still
  receives the device-wide route-policy contract.
- There is no mutable latest-release download and no hidden legacy fallback.

Exact artifacts and platform gates are owned by
`config/runtime-artifacts.seed.json` and
`docs/decisions/2026-07-23-pokrov-core-1.0.0-activation.md`.

The runtime artifact manifest also binds the shared native Go notice asset to
the Core source commit, Go toolchain and notice SHA-256. The app-shell asset
declaration includes it in Android and Windows packages. Seed validation rejects
a missing asset, hash mismatch, source/toolchain mismatch or missing declaration.
The asset includes root notices, selected source-package ancestor notices and
full license comment blocks found in a bounded scan of selected source files.
It also carries the separate prebuilt license for Wintun 0.14.1, whose exact
amd64 DLL bytes are embedded in the bound Windows Core through sing-tun.
The asset also preserves the original Psiphon `u_prng.go` copyright and its
explicit uTLS license reference, linked to the already included BSD body.
Exact a24b211 local packages retain this notice; final package audits and
module-precision scan evidence are linked from that record.
The previous Core904 Psiphon fork lacked a root LICENSE; that file attribution
did not establish clearance for the whole fork. Core2662 introduced authenticated
uTLS7a1fc with its own root LICENSE; the current Core880b binding retains it.
[Exact development packages](../operations/evidence/2026-09-11-r12-c05-2662-packages/README.md)
retain that notice, fresh package audits and the remaining source/license limits.
This notice binding does not establish complete dependency licensing or
corresponding-source delivery; remaining gaps stay explicit in release readiness.

## Update Handoff Boundary

The shared shell may present and open an update only when the metadata carries a
positive bounded byte size, a 64-hex SHA-256, and the exact canonical target
`https://github.com/Kiwunaka/pokrov/releases/download/<tag>/<asset>.apk`.
Alternate initial hosts or repositories, URL authority fields, explicit ports,
query strings, fragments, and non-APK assets fail closed, and the same
validation runs again at tap time.

Android has two explicit distribution flavors with the same canonical package
ID and signing lineage. `direct` alone declares `REQUEST_INSTALL_PACKAGES` and
the non-exported `FileProvider`; it downloads into app-private cache, follows at
most five HTTPS redirects to GitHub-owned asset hosts, and verifies exact byte
size, SHA-256, package ID, requested version, increasing `versionCode`, minimum
SDK, device ABI and signing continuity before the cache commit and again before
any installer intent. `store` declares neither direct-install surface and opens
only the app's explicit Google Play listing; it never downloads or hands off an
APK. Both flavors accept only the configured stable channel and bounded
metadata.

During a direct transfer the bridge exposes only phase and byte counters. The
Flutter sheet shows bounded version, official-source and size copy followed by
verification and installer handoff; it never displays the URL, digest or signer.
Android 8+ may require the user to grant install-source permission. The app
never silently installs an APK. Windows retains the trusted browser handoff.
Signing, install, store-console, runtime, physical-device and exact-candidate
proof remain separate release gates.

## Apple Boundary

Running the iOS or macOS shell locally only validates that the Flutter host project boots.

It does not validate:

- Apple signing
- provisioning profiles
- Network Extension targets
- packet-tunnel provider execution on device
- notarization
- App Store or Mac App Store submission readiness
- trusted Windows signing, installer, or `MSIX` publication

The Apple placeholder inputs that now shape later operator work live in:

- `config/apple-release.seed.json`
- `apps/ios_shell/ios/Flutter/AppleSigning.xcconfig`
- `apps/macos_shell/macos/Runner/Configs/AppleSigning.xcconfig`

## What This Does Not Do

- no production write calls beyond the app-first session and route-policy bootstrap used by Android and Windows connect
- no bridge-client reads or writes
- no Android traffic validation on a real device or emulator
- no replacement for the required Android release-build localhost/control-surface audit on physical hardware
- no reviewed iOS entitlement validation, signed shared-app-group proof, or on-device packet-flow evidence
- no trusted signing, trusted public installer or `MSIX` publishing, or deploy wiring
- no git-model migration for the shipping client or release lanes

That keeps local bootstrap work separate from public release authority. The
active client lane remains `POKROV-app/main`; historical Karing and clean-room
inputs cannot reopen it without a new owner decision.

## R12 Windows profile content identity — local implementation

Windows staging and connect use the negotiated profile-identity contract in
[platform privilege and runtime](platform-privilege-runtime-contract.md).
The service acknowledges the exact stage-request SHA-256 and accepts connect
only for that digest. Staged and effective identity are distinct; effective is
set only after proof and commit. The native UI binds subsequent polls to its
own intent and presents an explicit profile-not-applied recovery on mismatch.
This closes the local stage/start identity gap; server desired/fetched revision,
Android identity and exact packaged AWG transitions remain separate N01 proof.

### Android profile replacement identity

Android stages private config with a persisted content/options SHA-256. Normal,
permission-delayed and Quick Settings starts carry that digest; before replacing
a live session, the service verifies it against metadata and config bytes.
A same-path replacement rejects the stale intent with `profile_identity_mismatch`.
Only the active matching input can receive egress proof. Missing legacy digest
requires a new app-managed fetch/stage before Quick Settings can connect.
The host digest is local identity and does not manufacture server revision truth.

### Fetched revision to service identity

`ManagedProfilePayload.source` carries the exact managed-manifest revision and
`managedManifest` origin; validated emergency material uses
`signedEmergencyEnvelope`. Routing/materialization copies retain that upstream
source. The runtime stores the most recently supplied fetched source separately
from the source of the acknowledged stage digest. Its snapshot exposes
`fetchedProfileSource`, `stagedProfileSource` and `effectiveProfileSource`.
The last field requires running state, successful egress and the same effective,
staged and acknowledged digest. A failed stage can leave fetched B with staged
and effective A; a delayed A proof cannot confirm B. Unknown identity stays null.

This association is process-local and never reconstructed from a filename, hash,
local counter or stale session JSON. After process restart the app fetches/stages
again to restore source lineage; Quick Settings can prove only its persisted
local digest. The managed-manifest response describes desired server assignment
at fetch time, not a promise that the server has not changed it since. Offline
fallback retains its original source and the existing entitlement restrictions.

### Shell operation ownership (local POST12 implementation)

`ConnectionCoordinator` owns a process-local operation generation. Starting a
runtime action advances it; disposal invalidates it. Native-call wrappers check
the captured generation before dispatch and after completion, including errors.
Connect, disconnect and emergency-egress polling retain that original generation
across their waits. A superseded result is discarded; action cleanup only clears
busy/intent state when the operation still owns the coordinator. The same rule
covers repair, trusted-Wi-Fi pause, access-denial disconnect and WARP fallback.
Permission sheets recheck ownership before starting the requested action.
Linux and Windows retain their host-owned runtime-call timeouts instead of
acquiring a shorter UI deadline; profile API deadlines remain unchanged.

The coordinator supplies local async-response ordering. Android connects also
carry the per-invocation cancellation ID described in
[Android stage/start identity](platform-privilege-runtime-contract.md#android-stagestart-identity).
Windows uses its existing authenticated session-token/nonce cancellation target
and now requests cancellation on lost or semantically invalid responses. The
original response failure remains a failure even if cancellation is accepted;
an acknowledgment alone does not establish teardown. These paths do not provide
the full POST12 proof tuple, including artifact and network-context binding, or
add remote observations. Inner profile/cache work retains its existing lifecycle
checks; complete cross-layer cancellation remains open.

The Android, Windows and conditional Linux beta primary Connect action now exposes `Отменить` during profile
preparation as well as native start. This also covers its ordinary-VPN fallback
connect after WARP failure. When dispatched, the fresh native request ID is bound
to the owning operation; IDs from earlier attempts are not reused. Before
dispatch there is no native request to cancel. Cancellation advances the generation,
disables further fallback and keeps the action busy while the original pipeline
settles. If a native request exists, it sends the existing exact-request
cancellation command, then reads
the host and uses the existing disconnect polling bounds. `connectionPending`
also prevents declaring cancellation complete. A failed cancellation or missing
terminal readback leaves a warning and the last observed state; an acknowledgment
alone never becomes stopped/protected proof. Deferred known access denial is
handled after releasing the cancellation action. No unscoped disconnect is sent
by this new cancel path.

Windows binds the fresh Flutter request ID to the queued native invocation's
`ServiceCallControl`. The window thread sets its cancellation flag directly;
the existing service client sends the authenticated session-token/nonce cancel
without exposing those private values through Flutter. Completed invocations
reject cancellation. Acceptance only sets the local flag: connect may have
committed before the service handles it. The original invocation keeps its
native deadline, and the shell joins it before reading current host state.
Running, connecting/busy and unavailable host states cannot report successful
cancellation. This adds no service command, wire version or privilege.

Linux keeps a fresh request ID and cancellation completer for each connect.
Cancellation of that ID signals only its Unix-socket transport. Before request
dispatch it cancels the socket connection task; after dispatch it writes the
single cancellation trailer on that same stream and continues reading the
original response. The daemon binds the stream to the authenticated caller's
request context. Polkit, Core preparation/start and health waits receive that
context; restoration has an independent cleanup deadline. No unscoped daemon
disconnect or second privilege grant is used. Existing host deadlines remain
in force. A completed connect may outlive a late cancel; readback, including
pending recovery, decides whether stopping is confirmed. See the
[Linux runtime owner](platform-privilege-runtime-contract.md#linux-primary-connect-cancellation).

Reconnect and repair now share this cancellation path on the same supported
hosts. The coordinator permits cancellation for connect/reconnect/recover
intents and the common runtime-call wrapper binds any fresh connect ID to that
original generation. Repair uses `beginAction`/`finishAction` and its own pipeline
completion; reconnect also retains its completion while stopping the previous
tunnel. A cancellation before the new connect has no native connect ID to send.
It lets the already-started disconnect or cleanup settle, rejects the superseded
continuation, and reads current host state before releasing the action owner.

The protection sheet receives a cancel callback bound to its repair generation;
that callback is withdrawn when the runtime cycle finishes. Closing the sheet
does not cancel another operation. The sheet keeps its controls busy through the
cancel callback's readback even after the repair body exits. Supersession is
propagated to the sheet as interrupted, never swallowed into a successful repair
or new diagnostic collection. Profile resolution carries the original repair
generation and receives its existing cancellation signal. Normal post-repair
diagnostic collection remains separate read-only work after the runtime cycle.

Repair and reconnect cannot stage/connect after an unconfirmed stop of the old
tunnel. Running, unavailable and pending host states do not establish stopping.
Repair also stops an observed pending host transaction before replacing it. The
ordinary disconnect path does not emit its successful disconnected event when
the same stop condition is unconfirmed. These guards preserve the same owner
while cancellation and cleanup race; they do not add a second state machine.

Profile resolution, cached preparation and legacy Android cache migration retain
the original generation. Cache reads check both operation and profile revision;
stale continuations cannot capture the cancellation operation's generation and
start a fresh profile resolution/stage. WARP-status and trusted-Wi-Fi replies are
fenced before subsequent shell work. A stage already invoked may finish, but its
old continuation cannot start a tunnel.

`ManagedProfileBootstrapper.resolveManagedProfile` accepts an optional local
`cancelled` future. During an owned action the shell supplies its operation-end
signal (which also fires on generation change); outside an action it uses the
captured generation-change signal. Completing or superseding an action therefore
stops its remaining requests, including a still-pending RTT upload.
The App-first implementation closes that resolution's HTTP clients for session/
route-policy/manifest requests, advisory node selection and RTT upload. Created
Smart Connect TCP tasks are also cancelled; a socket delivered after cancellation
or timeout is destroyed. Worker slots remain occupied until the underlying probe
settles, and cancellation prevents new probes, refetch, session retry or a
successful payload return. The existing caller deadlines/concurrency limits are
preserved. Injected latency probes must still settle under their own contract;
the worker does not invent a way to cancel arbitrary injected code.

An explicit 401/403 still clears cached access and propagates even if cancellation
arrives during that cleanup. Local persistence or a server mutation already
accepted is not rolled back by cancellation.

WARP-status and Routing Catalog reads also accept `cancelled`. WARP-status owns
its HTTP client, stops session retries on cancellation and rejects late successful
results before returning status. The shell does not publish an old WARP error
over a superseding action. Existing consent/revoke/rotation calls keep their
separate command behavior.

Online catalog reads still share one active fetch per platform, with one waiter
per caller. A cancelled waiter receives cancellation; other waiters keep the
fetch. When the last waiter leaves before completion, the fetch closes its HTTP
client and cannot use a transient-error cache fallback. A later caller starts a
fresh fetch; completion of an abandoned fetch cannot remove that new flight.
Known denial/disable still discards the old envelope and retained revision floors
remain intact. Cache-only reads check cancellation after local storage work.
Local writes already in progress may finish; cancellation does not delete them
or turn them into runtime activation. The existing request timeouts remain bounds
for readers without an operation cancellation signal.

This is a partial ATS-006 cancellation path, not the adaptive selector.
Existing host deadlines and commands remain in force. Shared total budgets,
complete child-request cancellation, endpoint
selection, full proof binding and native resource-restoration checks remain open.

Status: `NOT_VERIFIED`. The owner requires all functionality before the separate
validation phase. Pending checks include coordinator supersession/disposal,
shell polling and permission/resume races, primary cancellation during cache,
profile/WARP preparation, migration, native start/consent/fallback, failed
cancellation/readback, no new attempt before old
pipeline settlement, preservation of access denial, and
Linux/Windows timeout ownership and exact-request cancellation, followed by the
applicable client checks. No runtime,
device or release readiness is established by this source change.

Windows validation must cover queued cancellation before IPC, cancellation during
connect, completion before flag delivery, stale/replaced IDs, queue rejection,
unavailable or busy readback and window destruction. These checks have not run.

Linux validation must cover cancellation before socket dispatch, during polkit,
while waiting for the service lock, during Core prepare/start/health, rollback
failure, stale IDs, socket loss and completed-connect races. Core read cancellation
must not shorten the subsequent restoration read. Existing fake transport/auth
signatures and service test call sites were adjusted only for the context
parameters; no new cases or test execution are included in this source slice.

Reconnect/repair validation must cover cancellation during the old disconnect,
profile resolution and new native start; stale sheet callbacks; sheet disposal;
late connect completion; known access denial; pending/unavailable stop; and an
interrupted repair that must not start fresh diagnostic collection or report
success. No tests, builds or formatter runs accompany these source changes.

The manifest HTTP/selector/TCP cancellation slice also needs later cancellation
and late-completion cases, rejection of retries after cancellation, concurrent
probe-slot accounting and preservation of explicit denial. Only existing fake
bootstrapper method signatures were adjusted; no new tests or checks ran.

Later validation must also cover WARP cancellation before session retry, two
catalog waiters with one cancelled, all waiters leaving, a fresh reader during
abandoned-fetch completion, normal action-end cancellation and denial versus
cache fallback. The existing WARP fake received only the optional method
parameter; test execution remains deferred.

### Managed profile lifecycle owner

`src/shell/managed_profile_lifecycle.dart` owns profile-input dirtiness and the
local revision, host invalidation queue, timeout generation and disposal. Shell
composition supplies the existing host call and snapshot callback. Bursts are
coalesced into the latest requested revision; connect waits for completed host
invalidation. Timeout/disposal settle the waiter without allowing a late host
acknowledgement to update the shell. This refactor does not change server source
revision, fallback authority or the connection transaction. The module is an
ordinary import and adds no shell `part`.

`managed_profile_lifecycle_test.dart` exercises coalescing, timeout/disposal and
non-Android revision tracking independently. Existing seed-app widget tests
continue to exercise the connection/Quick Settings integration.

Normal connect and explicit protection repair both wait for the pending host
profile invalidation before staging a replacement. An invalidation timeout
ends the operation without stage/connect, even if the host responds later.
Repair also captures the local input revision and checks it after the stage
acknowledgement: if the user closes the repair sheet and changes routing while
staging is pending, the old profile stays dirty and cannot start. The user
retries with the current settings. Host content-digest checks remain separate
from this local intent fence.

### Runtime failure observations

Native failure categories pass through an exact allowlist before reaching public
messages. Offline state, unresolved network interface, DNS failure, refused
endpoint, transport timeout and handshake failure retain distinct observations.
Unknown `dns_`, `default_network_`, `vless_` or `reality_` prefixes do not establish
a cause and become generic runtime failure. A timeout alone does not identify
UDP blocking, DPI, MTU, ASN policy or a whitelist. Request-scoped protocol log
categories remain diagnostic context and cannot change runtime health.

The diagnostics presenter preserves an explicit failure code before checking
incomplete DNS/egress proofs. Failed Core startup, unavailable verifier or absent
network must not become a DNS fault merely because no proof was completed.
Without an explicit failure, existing proof-gap presentation remains available.
These mappings grant no route change or retry permission.

Android per-call Core probes also retain the exact closed `ProbeError.Error()`
observations: connection and TLS negotiation failures become
`core_egress_connect_failed` and `core_egress_tls_failed`; response-stage and
unspecified probe failures remain `core_egress_probe_failed`. Only exact known
messages from the invoked method qualify. Missing APIs and unknown exception
text remain unavailable; raw exception details never enter the snapshot.
Android schedules the selected-egress probe only after Core's
`startOrReloadService` returns successfully. Core opens the TUN while it is
still starting, so probing from the TUN callback can report unavailable before
the selected route exists. Reloads apply the same ordering to the new TUN.
These failures use the existing completed-failure policy: endpoint probes get
at most three attempts, group failures are terminal, and session/generation/TUN
fences still decide whether a result applies. The stop reason stays the generic
failed-egress reason while the failure kind retains the stage. Existing managed
and emergency retry limits and the closed AWG degraded-TUN exception remain.
The stage describes the check, not a proven node fault or filtering cause;
the closed exception text cannot distinguish DNS, timeout or DPI subcauses.

Failure copy keeps the observed stage separate from runtime lifecycle. When
the host reports `running` after an unsuccessful egress check (including the
closed AWG retained-TUN lane), the shared message says that the system VPN
remains enabled and egress is unconfirmed. It must not claim that VPN stopped.
The existing stop copy remains for non-running snapshots. Native stage text
alone makes no teardown claim because the same text serves both retained-TUN
and fail-closed paths. Failure codes, health, retries and TUN ownership do not
change with this presentation rule.

The shared catalog distinguishes pending profile provisioning (`API-011`),
unresolved interface (`ROUTE-005`) and an unspecified runtime failure (`CORE-009`).
Subscription refresh failure keeps its API/auth observation rather than claiming
that access is absent. Native event consumers retain typed DNS, UDP, TLS timeout
and response-stall codes from Core, including in the support timeline. Their
presence is diagnostic evidence and does not authorize automatic fallback.

The Windows service's authenticated egress check retains WinHTTP observations
through rollback and its closed IPC failure allowlist. `core_egress_dns_failed`,
`core_egress_connect_failed` and `core_egress_tls_failed` describe the failed check,
not a proven failure of the VPN node. TLS negotiation and waiting for a response
have separate `core_egress_tls_timeout` / `core_egress_response_timeout` values;
timeouts before those stages remain `core_egress_timeout`. Unknown errors and
invalid HTTP/proof responses remain `core_egress_probe_failed`. The native
callback stores only numeric errors and phases, never host names or response
text. Cancellation remains owned by the connection transaction. These codes
retain the same failed-egress retry eligibility, three verifier attempts and
bounded managed fallback; they neither publish protection nor diagnose DPI,
MTU, ASN or UDP blocking. The UI and native service ship together so their
closed allowlists agree.

Windows also reads the current IPv4/IPv6 default routes and their interface
link state on each existing desktop status poll. A running VPN interface alone
is not an uplink. If no usable external default route remains, the shell keeps
the running tunnel visible but withdraws green protection and reports
`network_unavailable`; an unavailable Windows observation remains unknown.
Returning a usable route allows the unchanged service connection proof to be
displayed again. This local link check is not a new DNS/HTTPS probe and cannot
detect an upstream outage while the local link and route remain available.

### Ordinary cache outage boundary

The owner's 2026-09-07 restricted-network decision permits normal connection
when the API is unreachable but a VPN endpoint from the last downloaded profile
is still reachable. `ManagedProfileCache` stores two records in platform secure
storage: downloaded and last proven. They bind account, install, platform,
route mode, selected apps and preferred node/variant. They preserve the original
server-observation time and expire 24 hours after that observation. Future
timestamps are unavailable. Offline reads, repeated failures and host restaging
never extend that window. A cache transaction ID fences delayed proof from
promoting a different download; it is not a server revision or egress proof.
Each protected-cache read serializes with cache writes and records
`last_observed_at`, including when the records have expired. A wall-clock value
earlier than that observation makes the cache unavailable, including after
process restart; it cannot revive an expiry already observed by this cache.
The original profile timestamps remain unchanged. Existing version-1 records
without this field establish it on their first read. This records observed
clock movement, not trusted elapsed time while the app was absent.

The app tries refresh on ordinary connect/reconnect, allowing at most three
seconds when a matching cached profile exists. Timeout or transient
408/429/502/503/504/no-status failure may restore that protected record through
the regular host staging transaction, including after app/process restart.
The cache is checked again after refresh failure for expiry or intervening
authorization denial. Offline preparation performs no WARP-status API call.
Known 401/403 denial and a successful subscription response with lane
`expiredOrBlocked` clear the protected cache. The subscription denial also
blocks cached reconnect and stops a running tunnel through normal disconnect;
if a native action is in flight, disconnect follows its completion. A transient
managed-profile failure cannot override that known denial. A connect attempt
after known subscription denial refreshes subscription first. If access remains
inactive, it shows the renewal message without requesting or staging a profile;
renewed access may continue through the normal fresh-profile flow. Missing credentials
or an account/input mismatch makes the cache unavailable. A dataplane failure
alone prefers the proven slot on the next manual retry and does not erase either record.

Hosts/bootstrap fixtures without the protected-cache capability retain the
legacy staged-file fallback with a 0–24-hour modification-age check. The real
app bootstrapper uses the protected records rather than resetting freshness
from a newly materialized file. Every restored profile retains its original
server revision, and every new tunnel still requires its normal route/egress
checks. An offline attempt never implies that a new server assignment applied.

This owner-approved grace is not a signed offline entitlement lease. The client
cannot learn a new remote revocation during a complete control-plane outage;
server-side credential enforcement remains authoritative. The separate signed
emergency bundle has its own account/catalog/eligibility expiry checks. Neither
path creates a new trial or subscription. Exact outage/revocation behavior still needs the
candidate and owned server scenario; a local cache test does not prove it.

## Transport manifest admission boundary (ATS-005, source only)

`TransportManifestVerifier`, exposed by `routing_catalog_contract.dart`, admits
the platform `pokrov-transport-manifest-v1` and exact-target signed rollback.
It reuses immutable JSON/canonical encoding and Ed25519 primitives without sharing
catalog/release/support key pins. Explicit transport key maps or the separate
build inputs `POKROV_TRANSPORT_TRUSTED_KEYS_JSON` and `POKROV_TRANSPORT_AUDIENCE`
define trust; no key is configured by this change.
Client/Core release identities are required inputs, never guessed defaults.

The pinned key map is canonical compact JSON with sorted key IDs, no whitespace
or trailing newline, at most 16 KiB. IDs match `[a-z0-9][a-z0-9._-]{0,63}`;
values are canonical standard-base64 encodings of raw 32-byte Ed25519 public
keys. Empty input or `{}` means unconfigured; malformed maps fail with a fixed
`transport_trust_invalid` error. The map is immutable for the verifier lifetime.
Duplicate IDs, noncanonical base64 and ambiguous JSON representations are rejected.
The same source contract is parsed by the platform publication service. The
earlier local single-key build defines are replaced, with no fallback to other
trust domains or keys carried in server replies.

Rotation uses client-release pin provisioning, not an online root-delegation
protocol. Before switching the signer, provision the current and next public
pins in the intended client release and matching server environment. After that
release's required gates/distribution, publish a strictly newer policy signed
by the next key through the existing Action Intent path. Key IDs must not be
rebound to different bytes. Retire the old key from a later release and server
configuration after the intended rollout; rollback targets also need a currently
pinned signer, so removing a pin makes targets signed only by that pin unusable.
None of these steps resets policy epoch/revision/hash/kills/time floors or extends
document validity. An old offline client retains its shipped pins until updated;
pin removal is not an instantaneous remote revoke. Server credential expiry and
revoke remain the final access boundary.

`build-android-production.ps1` (APK and AAB) and `build-windows-release.ps1`
accept optional `-TransportTrustDefinesFile <absolute-path>`, forwarding it to
Flutter's `--dart-define-from-file`. The file is a Flutter defines JSON object:
`POKROV_TRANSPORT_TRUSTED_KEYS_JSON` is a string containing the canonical map,
and `POKROV_TRANSPORT_AUDIENCE` is `lab` or `production`. It contains public pins
only and must be retained with the exact candidate's build inputs. Omission adds
no pins. Other Flutter host builds use the same defines-file input directly.
This source change supplies no key file, does not build/distribute a release,
and does not enable transport admission. Parser/signature/cache parity and
overlap/retirement evidence remain NOT_VERIFIED until the later check stage.

The verifier rejects extra fields, invalid refs or budget bounds, noncanonical
ref ordering, wrong audience/signature/digest, incompatible releases, expired or
future documents and revision equivocation. Rollback authorization must be newer
than its exact target; the authorization advances the floor while target,
authorization and retained kills combine and expiry uses the earlier bound.
An ordinary newer signed manifest explicitly replaces the policy kill set.

The verifier returns a proposed admission. Only `TransportManifestStore` commits
the floor and envelopes before exposing policy for a consumer. Storage and
initial-state enrollment rules belong to `persisted-state-contract.md`. Bootstrap now
exposes `AppFirstTransportManifestService`; native/selector consumers remain
unconnected. A store with explicit release identities and a RuntimeBootClock must be injected; ordinary
construction leaves the path disabled. The loader reuses an existing session,
requires a caller budget, owns cancellation/HTTP lifetime, and checks the account,
install/session and store generation after waits. Ordinary fetch does not enroll
an absent floor or create a trial/account to fetch policy.

Online fetch now uses `POST /api/client/transport-manifest/bootstrap` for a fresh
time observation as well as policy. The public GET/decoder remains a signed-policy
surface, not an offline time source. Success is strict UTF-8 canonical JSON plus
one newline; the scoped decoder checks closed shape and re-encoding equality,
rejecting duplicate keys, ambiguous numbers or alternative escapes. Signed
documents remain independently signature/shape/size checked by the verifier.

Known 401/403 and fixed `transport_*` errors discard cached envelopes while
retaining floors. A generic transient outage may use a reverified record only
within its original validity and the remaining caller budget. Cancelled/stale
session work never returns policy; already-started secure writes may settle,
without native activation. The aggregate runtime budget/child accounting is
still a separate ATS-006 integration. Invalid signatures/wire formats do not
trigger cache fallback.

Both online refresh and the separate `enrollTransportManifest` operation send a fresh 128-bit random
nonce to `POST /api/client/transport-manifest/bootstrap` using the existing normal
session. It accepts only HTTPS without redirects, matching response nonce,
unchanged session/generation and a still-live caller budget. The bootstrap POST
rejects HTTP before sending credentials. The closed canonical
bootstrap reply contains the current manifest/rollback, proposed floor and UTC
server observation; its limit is 2 MiB + 4096 bytes. No network retry, cache
fallback or response-file import is an enrollment path.

Store enrollment checks exact floor version/kind/hash/kills and rejects any
existing record. The operation supplies a cancellation/budget predicate for the
secure commit. Native boot-clock snapshots bracket the HTTP exchange. A time
interval is derived from server seconds plus the full elapsed round trip and
sample quantization, then advanced by the same boot's suspend-inclusive counter.
No DateTime.now fallback or locally corrected wall clock supplies policy UTC.
The native deadline also fences received replies, cache reads and policy commits
after sleep; an in-flight host/storage operation still settles before its caller
can discard the result. The aggregate coordinator/native-child budget remains open.

Store version 2 retains this anchor atomically with policy/floors. Same-boot app
restart can reuse it; reboot/missing clock requires a fresh online anchor while
retaining floors. Version 1 cannot offline-reuse without online migration. See
the persisted-state and host privilege owners for exact storage/clock contracts.
Apple Runner targets now expose the shared boot UUID / continuous-time helper:
iOS through its mobile runtime bridge, macOS through a clock-only method channel
alongside desktop FFI. This supplies the same local anchor input without starting
Core. Native availability and signed-device behavior remain NOT_VERIFIED.
Server-time trust, hardware/OS clock behavior and full snapshot rollback still
need candidate evidence. No request nonce or host boot reference is sent in
telemetry, and no physical first-install claim is made.
Signed opaque references still need capability/profile/probe resolution, current
entitlement and data-plane credential enforcement before selection. No transport,
lease, traffic or paid-access extension is enabled by possessing a manifest.
Clock validation/reinstall detection/rotation/runtime integration and cross-language
parity fixtures remain pending. The source has not been executed or verified.

## Transport candidate admission and operation budget (ATS-006, source only)

`src/features/home/transport_selection.dart` adds local typed candidate/context
inputs and `TransportSelection`, created only by
`ConnectionCoordinator.beginTransportSelection`. It is accounting within the
existing operation generation, not a second connection state machine. Finishing,
superseding or disposing the coordinator closes admission and requests child
cancellation. A generation cannot create another budget to reset counters.

The coordinator now takes a live `TransportManifestSelection` handle from
`AppFirstTransportManifestService.openTransportSelection`, rather than a detached
admission. The caller supplies the original boot-clock sample, full operation
budget, generation predicate and cancellation future. The loader spends only the
remaining time on policy fetch; opening the secure-store handle caps the original
deadline by the signed budget, without restarting it after HTTP/storage work.
Cache-only opening still needs an existing matching stored session and valid
anchored policy; it cannot enroll an absent floor or grant endpoint access.

Opening checks the exact committed version/kind/hash/kills and retains its boot
anchor. `TransportSelection.sample()` serializes fresh native clock reads and
checks the captured account/install/access token plus operation/store validity
before returning each window. Policy/anchor replacement, withdrawal or uncertain
secure writes close old handles before results can be reused and notify the
coordinator to cancel owned children. Same-policy time observations do not replace
the anchor. A handle also closes at its deadline/expiry or caller cancellation.
Closed handles are removed from the in-memory registry; no extra secure key,
session token record or telemetry identifier is created.

Session writes synchronously notify file-scoped in-memory observers before IO.
Changing account/install/access token invalidates the handle even if a native
clock read is in flight; updating profile metadata with the same session does
not. Pairing fences the old session before removing its secret. Disk session
rereads remain part of each sample. These fences cover this app's write paths;
they do not claim inter-process/OS compromise or full snapshot rollback proof.

Candidate facts include capability, profile ref/revision/digest, endpoint/lease
and failure-domain refs, bootstrap/probe sets, exact artifact/Core capability,
route/DNS policies, mode/family and the intersection of authorized validity.
These are resolver inputs, not grants or proofs. A resolver must authenticate
their bindings to the actual profile, lease, access and native artifact. Existing
node codes/profile names must not be substituted for these opaque references.
The inventory is bounded to 1024 candidates and duplicate candidate refs fail.

Before ranking or starting any attempt, admission checks manifest membership,
effective kills, loaded capability/family compatibility, exact context fields,
and both trusted time-window bounds. A caller-proven healthy exact tuple sorts
first, followed by stable candidate-ref order; this is not latency scoring or
proof production. Negative hints apply only to the complete failed tuple within
this operation/context, expire by the signed TTL and never arise from unknown,
unavailable, expired or stopped work. A failure-domain ref is not evidence of
independent observations or an IP-block diagnosis.

The shared budget starts at the original operation's native sample and uses the
lesser of its caller budget and signed total deadline. Policy/access expiry also
bounds children. Attempts, distinct endpoints, repairs, concurrency, diagnostic
bytes, cooldown and per-stage caps come from the admitted signed policy. Stage
deadlines are not reset by later children in that stage. Fresh child-permit
identity prevents completion replay without storing every finished child ID.
The executor must reserve before starting work/diagnostic IO and retain the
permit until actual task settlement. Sleep-delayed timers cannot admit late
success: settlement observes native time while the child is still owned.
Missing time stops admission but still permits cleanup settlement.

Cancellation failure does not free a child slot. A potentially active TUN remains
owned after its start task settles; only an exact-attempt stopped native readback
can acknowledge release. Pending children or an owned TUN prevent replacement
of the budget, including across coordinator generations. A failed attempt cannot
permit another tunnel before that readback. Caller-declared `pass` closes the
selection budget but does not set any UI protection state or create proof.

This source is NOT_VERIFIED. Ordinary Connect does not yet call the new API:
authenticated candidate resolution, proof-bound healthy selection and native
executor/byte accounting still need integration. No threshold,
feature activation, Core ABI or live route changes are implied. Tests, simulator
parity and host deadline/cancellation evidence follow the functionality stage.

iOS uses the statically linked Core from gomobile's c-archive XCFramework.
Both Runner and PacketTunnelExtension link the archive; Runner no longer
requires or embeds a separate Core framework binary at runtime. Its locator
records the actual host executable path. Inventory uses the generated direct
binding, so matching Core headers/archive are required when building the host.
The compiled presence of that function and a host executable path are neither
module digest nor successful connection evidence. Runner preflight and extension
execution images remain distinct for the pending Apple identity integration.

Loaded Core transport ingredients are now available as optional
`RuntimeSnapshot.transportCapabilities` through Android, Windows service and
desktop FFI. The runtime-boundary owner defines transport and parser behavior.
Missing/invalid inventory cannot be replaced by a profile name or bundled file
name. Signed manifest `capability_bindings` now map these ingredients to opaque
capability refs/revisions, allowed platform/module hashes and profile refs.
`TransportSelectionContext` derives allowed capabilities from those verified
bindings and the actual typed snapshot, rather than accepting a caller's ref
set/revision. The module digest must now come from `RuntimeSnapshot.coreModuleSha256`,
not a context factory argument. Linux/Windows/Android native producers supply it; the
remaining platforms stay unavailable until their producer exists. The candidate
resolver must still bind actual profile requirements. Linux supplies preflight/actual
child inventory, and iOS supplies Runner preflight/extension inventory; these
sources do not substitute for each other when a tunnel is running. Exact
artifact/profile/endpoint identity and the ordinary Connect selector call site
remain open. No inventory read activates ATS.

The context retains the admitted manifest's payload hash; a different-policy
context cannot open a selection. The coordinator requires its current snapshot
to match the captured Core inventory at opening, and cancels the selection when
subsequent snapshots lose/change that inventory, module digest or host/ready phase. Constructor
failure closes the unused policy handle. Android now exposes the separate
`RuntimeCoreIdentityConnect` entry point: expected Core/profile digests are bound
to one request through permissions and service start, with native checks before
profile execution. Its dedicated method/envelope has no ordinary snapshot/error
fallback. The selector executor and ordinary Connect do not yet invoke it;
policy/lease time, permits, byte accounting and proof remain separate requirements.
Each child permit now retains the native boot-clock sample used when reserving
its deadline, alongside its remaining duration. Pass those original values to
Android's identity-bound connect; taking a later sample with the same duration
would improperly extend the reservation. The host validates and retains the
absolute boot-relative deadline across permissions, START and runtime session,
and expires pending/running work without treating startup success as promotion
to a healthy leased flow. The full executor/proof-bound handoff remains open.
Linux now has Dart/daemon/Core start checks of the exact module/profile pair
and original boot deadline, documented in the runtime contract. Core retains
the deadline after its response; same-peer cancellation addresses that exact
attempt. Windows service now has a dedicated identity/deadline command and retains
its exact cancellation owner after response. Runner/Dart now dispatch it, verify
the matching envelope and retain cancellation ownership until an exact stopped
receipt for the private service target. Bound Windows startup now requires the interruptible Core export:
an invocation-scoped callback cancels the startup context and joins before DLL
return. Cleanup remains serial; OS/driver calls have no forced-preemption claim.
Executor/proof/lease wiring and Apple
start checks remain open.

The source-only ATS profile loader now exposes `resolveTransportProfile` on the
transport service. It takes a live selection, constrained query and the original
preparation permit clock/budget. A single session-owned HTTPS POST to the reserved
`/api/client/transport-profile/resolve` path carries a fresh nonce and exact
manifest/effective-floor/query identity. It admits only the closed echoed response,
current capability/profile/module membership, kills, authorization interval and
SHA-256 of the exact config string. No re-encoding changes that digest.
The config must use the issuer's canonical JSON form so duplicate fields cannot
make client and Core interpret different material from the same bytes.
The decoded VLESS outbound must use TLS and uTLS and identify exactly one Reality,
gRPC or XHTTP variant. The signed capability must contain ATS lease, VLESS, TLS,
uTLS and that variant; the variant must also equal the shortlist hint before
profile staging. A generic TLS/VLESS shortlist feature cannot stand for the
selected transport.
The raw v1 template also has exactly one VLESS proxy, the issuer's three
direct/block/DNS helpers, and a VPN default with only the DNS helper rule. An
extra proxy or a direct default cannot enter host route assembly outside the
lease gate.
The privately constructed `AuthenticatedTransportProfile` remains bound to the
same handle; `TransportCandidate.fromResolved` derives its selector tuple.

One cancellation window covers storage, clock, HTTP and hash awaits. HTTP closes
on cancellation and pending operations settle before the preparation method
returns. Session/policy/time are checked again after the response and hash.
There is no cache, automatic retry, trial enrollment or ordinary-profile fallback.
Config remains only in memory and redacted object descriptions; no preference
or stage mutation occurs here. Later materialization needs a separate native
stage digest, since flags/TUN/rules may change the host input.

The backend default-off HTTP issuer, bounded endpoint inventory and ten-minute/
one-hour ordinary lease windows are wired in source. Ordinary Connect reaches
this loader only under the ATS flag and still requires native proof and complete
wire-byte enforcement before it can establish protected status. Source remains
NOT_VERIFIED: current issuer/client/native integration has not been built or tested.

For a shortlist that already returned admitted primary endpoints, a failed
optional cold-reserve request may leave those primaries usable only on a network
failure or transient HTTP 408/429/502/503/504 response. Authorization, policy,
malformed-response and cancelled-selection failures stop the selection; an
unavailable reserve cannot substitute for an empty primary shortlist.

`prepareTransportProfile` now creates a private `PreparedTransportProfile` from
the authenticated template through the existing runtime materializer and
`applyPokrovRoutingPreferences`. It captures the user's preferences/apps before
awaiting, requires a supplied compiled catalog for catalog-enabled RU/selective
modes, and uses the existing rule-set acquisition where applicable. It does not
choose a different Smart Connect node/variant, start a trial or alter shell state.
The original preparation deadline covers clock/rule/materialization awaits;
cancelled work settles before returning. Settings/context changes must invalidate
the coordinator owner callback. Mode comes from the authorized query; later
executor wiring must bind its route/DNS refs to those captured preferences.
The prepared profile disables Android Quick Settings reuse; this is not yet a
general lease-based prohibition on every native ordinary-connect entry point.
Before the issuer's VLESS tag is renamed, preparation rejects any existing
`pokrov-ats-upstream` value in the assembled profile. The new tag cannot turn a
previously dangling route or DNS detour into a path around the Core lease gate.
Literal IPv4-mapped IPv6 endpoints are also rejected before stage: their socket
could use IPv4 despite an `ipv6` lease label.

`TransportSelection.stageProfile` reserves one profile/preparation child and
uses `RuntimeCoreIdentityStage` for Android, Windows or Linux. It hashes the final
private host identity input after native-adapter materialization and Windows
rule-set bundling, checks the original selection/candidate/Core around that work,
and compares the stage acknowledgement. Existing catalog/Smart Access profiles
still require their restriction-persistence callback before native dispatch;
its returned digest must equal the ATS binding. Linux rejects those unsupported
restriction profiles. Cancellation retains the child until native staging
returns, and cannot turn an acknowledgement into connectivity proof.

The private `TransportStagedProfile` retains template SHA separately from native
stage SHA and binds both to one attempt/candidate/selection. A later connect must
use native stage SHA and recheck current native ownership; it cannot reuse this
receipt after the attempt changes. There is no new TUN owner, health result,
healthy-lease promotion or normal Connect activation. Issuer/inventory,
end-to-end executor, revocation/reuse policy and proof/lease handoff remain open.
All changes are source NOT_VERIFIED; no runtime or verification commands ran.

### Linux exact connect settlement (source only)

The Linux bound-connect adapter now separates cancellation from proof of stopping
through `RuntimeConnectSettlement`. Daemon admission records the exact invocation
before authorization; cancellation addresses its kernel peer and context, joins
startup and restores only that invocation's resources. Its closed stopped receipt
is independent of a global snapshot. Unknown identity, lost daemon history or
failed restoration cannot release the selector's future TUN owner.

Dart joins pending clock/socket work after a cancellation race and retains the
native owner until this receipt, or proof that dispatch never happened. Its bound
disconnect uses exact cancellation. This interface is currently implemented by
Linux, Windows and Android. The shared start/stop executor and captured route/DNS
binding are described below; proof/lease handoff, live shell wiring and restart
ownership reconciliation remain open. Ordinary Connect does not activate ATS. Source NOT_VERIFIED: focused
cancellation/authorization/late-response/rollback tests follow full functionality.

Windows now uses the same explicit settlement interface via negotiated service
command 22. The original session/nonce remains private to the service client;
runner readback exposes only the exact local request ID and settled boolean.
Cancellation reaches Start before Dart joins its pending futures. Snapshot or
cancellation ACK cannot free the owner, and a bound disconnect cannot become an
unscoped stop of a replacement. Native restoration and service-restart recovery
still require the later verification/reconciliation work; source is NOT_VERIFIED.

Android now binds an admitted bound request to its exact service instance.
Pre-admission cancellation fences late permissions/START; after admission, the
same serial executor joins startup, closes Core/TUN and joins cancelled children
before producing its stopped receipt. Failed handles stay retained for retry;
destroyed-service ownership is held until confirmed cleanup. Hook failure or a
missing process-local record cannot become a stopped claim. Shared Dart code
keeps bound ownership through native and clock/channel settlement. These source
changes are NOT_VERIFIED and do not activate ATS or close executor/proof gates.

### Shared ATS start/stop executor and routing capture (source, NOT_VERIFIED)

`TransportRoutingIntent` captures normalized routing preferences, selected apps,
mode/platform and the verified catalog policy before profile resolution. Its
route/DNS refs are fresh random local handles, not hashes or serialized settings.
Selection context and prepared profile must share this exact object; the resolver
must echo its refs/mode/platform. Preparation cannot substitute a second settings
argument. The configuration-owner callback and catalog validity are rechecked
through preparation, stage and connect. The live shell supplies that callback
from its managed-profile revision/settings owner, as described below.
The resolved candidate retains both the new-flow authorization cutoff and the
later active-flow cutoff in its exact tuple. This preserves the issuer's
separate windows; healthy native handoff and expiry enforcement are still open.

The private stage receipt now retains the actual engine instance. The selector
reserves its tunnel child before reading the current stage and dispatching bound
connect. Module/inventory/stage identity must still match, and snapshot/clock work
uses the original permit interval. Android/Windows/Linux publish the exact request
ID before their first await or native dispatch, including a locally rejected call.
A throw before publication guarantees that this invocation acquired no native
resources. A native response can acknowledge Android pending permission/start.
The shared executor now joins that pending lifecycle before returning its own
acknowledgement; neither response establishes DNS/payload/egress health.

Start settlement releases only the in-flight child. The selector separately keeps
the exact request's native owner. After Start is acknowledged, its timer moves
from the transport-stage cap to the earlier of the original total budget,
candidate authorization and policy expiry. Later proof children retain their own
stage caps; expiry, cancellation and a changed coordinator generation cancel the
owner even after Start returned. A stopped
receipt plus completed executor work releases the TUN slot. Uncertain cleanup
retains the owner, blocks replacement and remains available for explicit retry
through `ConnectionCoordinator.stopTransportConnect`. Concurrent stops join one
request. No global idle snapshot or late response can release another owner.

`connectTransportProfile` binds cancellation to the existing coordinator operation
and only projects that operation's returned snapshot. Proof stages, healthy-lease
handoff/deadline transition, issuer/inventory, shell activation and restart/hook
reconciliation remain open. There is no new connection state machine or normal
Connect activation. No tests, analyzer, format, builds, native calls or hashes ran.

### ATS pre-resolution accounting and shell settings owner (source, NOT_VERIFIED)

The shell now injects its routing capture into `ConnectionCoordinator`. Selection
creation reads the loaded, explicitly confirmed mode, preferences, selected apps,
platform, access object and managed-profile revision. The supplied catalog must
match mode/access and explicit service selection. The callback remains tied to
that operation and those inputs; profile invalidation immediately cancels its
selector before host invalidation. No settings are serialized into the refs.

`resolveAndConnectTransportProfile` now joins resolution, preparation, stage and
bound connect. Before resolver IO, the selector validates the query against its
context/policy and spends one attempt/repair and endpoint slot. This unresolved
attempt can own only profile preparation; no fabricated lease/candidate or TUN is
admitted. The authenticated response must echo the query and supply an eligible
grant before the attempt acquires its candidate identity. A rejected request does
not refund counters or manufacture a negative endpoint health observation.

After route/DNS materialization and before lease binding, preparation checks the
selected VLESS server against the authenticated query's IP family. A literal in
the other family is rejected. For a hostname, the VLESS outbound's existing
bootstrap resolver is kept but its strategy is set to `ipv4_only` or `ipv6_only`
for that family, even if the host assembler replaced the route default or Android
rewrote the outbound resolver tag. Missing resolver ownership closes preparation.
These source changes remain `NOT_VERIFIED` and do not establish reachability.

Resolve and prepare retain one child and its original clock/interval. Stage uses
the remaining part of that same profile-stage cap. After resolution, grant expiry
also cancels preparation; current candidate eligibility is rechecked on native
time samples. Cancellation retains child ownership until loader/materializer work
settles. Successful preparation does not signal cancellation of its own receipt.
An unresolved failed attempt may finish as unknown/unavailable, never as pass.

The ordinary Connect entrypoint remains unchanged. Endpoint inventory/issuer,
catalog grant issuance for this path, proof stages, healthy
lease/deadline handoff and restart reconciliation remain open. The new bridge has
not run; analyze/tests/build/native/API/hash checks remain in the later phase.

### ATS catalog restriction persistence (source, NOT_VERIFIED)

The shell now injects the existing restriction journal/store path into ATS stage.
`TransportStagePersistence` belongs to the exact preparation child and staging
engine. Native journal reads, active-lease reads, durable journal retention and
ACK, identity calculation and `prepareStage` all remain owned until their futures
actually finish. Cancellation/deadline is checked before continuing; a timeout
does not detach native or storage work from the ATS child. Ordinary stage/refresh
callers retain their existing timeout policy through the same recovery routine.

The path requires configured control trust, native catalog control version 4 and
native background journal support. Live-worker/unknown crash restrictions and
revoked catalog/services are not bypassed. Smart Access grants must admit the
whole current time window. The durable binding records the exact final stage
digest, catalog identity and lease scope before native stage; the staged receipt
retains catalog identity only after successful persistence and native confirmation.
The coordinator then acknowledges that same staged binding for existing control/
renewal bookkeeping. The revocation guard survives preparation through connect,
and routing-intent time checks include Smart Access new-flow expiry.

This does not issue new grants, configure background control after connection,
prove connectivity, or activate ordinary ATS Connect. Endpoint inventory/issuer,
proof/lease handoff, background control configuration and restart reconciliation
remain open. No runtime/API/store/hash operation or verification command was run.

### ATS bound proof consumer and presentation gate (source, NOT_VERIFIED)

`RuntimeBoundConnectivityProbe` defines separate transport, system DNS, protected
bidirectional payload and expected-egress results. Its closed local receipt echoes
the exact native connect request, candidate/profile/endpoint/lease, Core identity,
route/DNS/mode/family, attempt/generation/network context, probe/bootstrap sets,
fresh per-invocation nonce and original boot/start/deadline. Integer/field/echo and
observation-time mismatches are rejected. Payload/egress pass requires verifier
and authenticated-receipt refs; parsing these refs alone is not authentication.
The native producer must obtain and verify the actual session-bound exchange.

`proveTransportConnection` executes one bounded ladder per attempt. Each stage
owns a probe child, cancellation and diagnostic-byte reservation callback; the
next stage starts only after a pass and actual child settlement. Native request,
effective profile/module/inventory and current selection are checked after every
result. Unknown/malformed/late results cannot become a negative endpoint health
claim. The original budget is not extended and an old result is not replayed.
The coordinator requests exact native stop if enrollment or any proof stage does
not complete with all four passes; an uncertain stop retains its owner for retry.
After a confirmed stop it refreshes the current operation's native snapshot;
a failed or stale read cannot clear the proof-pending latch.
For a settled negative proof while the selection is still current, confirmed
stop settles the attempt and starts the signed cooldown. Only an explicit bound
failure receipt creates a candidate-local negative hint; unknown and unavailable
do not. A later candidate still consumes the original attempt, endpoint and
total-budget limits. Cancellation or uncertain cleanup cannot start it.
While the selection remains current, resolve, stage and native-start failures
also settle as unknown after exact stop and child settlement. Cleanup checks the
attempt identity before stopping, so a late failure cannot stop a newer attempt.
Neither path frees an uncertain owner.

Current host adapters do not implement this interface. The consumer returns
unavailable without substituting snapshot health, Core URL-test success, the
public 204 marker or the deterministic emergency payload. Native producers,
verifier-origin inventory, two-origin policy/independence, diagnostic-byte
unit/enforcement and proof freshness/healthy-lease handoff remain required.
No probe/network/hash/native operation or tests were executed.

An ATS start sets a coordinator proof-pending gate. Android, Windows and Linux
also publish the native owner's `transportProofPending` state, so recreating the
UI/coordinator cannot promote its legacy healthy snapshot. Shared
`isCleanlyHealthy` and proof timestamps reject that pending state. The coordinator
latches it; only an explicit native false with ended runtime, no pending start
and no retained local child/TUN clears the latch. Missing/failed status does not.
The future healthy-lease handoff must provide the separate successful transition.
Four staged receipts are necessary for attempt pass, but do not yet grant reuse,
establish host/process route coverage or authorize protected presentation. The
ordinary connection path keeps its current proof rules; ATS remains inactive.

Snapshot absence of this field means an older/unsupported host; ATS admission
requires it. A malformed present Dart wire value cannot become false. Before
Start the executor requires false; startup acknowledgement, background control
and proof snapshots require true for the retained bound owner. The bit grants
neither cleanup authority nor a positive proof, and contains no request ID or
private cancellation target. Native service/process restart reconciliation,
healthy attachment and exact cleanup after losing a caller remain open. This
source contract and all host implementations remain NOT_VERIFIED.

Android staging also persists `requires_bound_connect` for ATS input. Ordinary
Connect and Quick Settings cannot reuse it without the live bound request, Core
identity and original deadline. Metadata commits before config replacement;
staging failure cannot acknowledge an uncommitted reuse policy. This prevents an
unbound restart of staged ATS input, not recovery of a lost attempt or a healthy
lease handoff. See the persisted-state contract for the additive schema-1 field.
Its `canConnect` snapshot is false for bound-only input, including after profile
metadata is restored into runtime state.

Windows stages ATS input with a separate negotiated service command. Its profile
bytes and digest remain the normal host identity input, while the service retains
the bound-only restriction until the profile is replaced or invalidated. Ordinary
Connect rejects that staged profile before native network mutation, including
after the UI restarts while the service stays alive. A service restart requires
fresh staging. This is a negative reuse gate, not attempt recovery or proof.
Its `canConnect` snapshot is false for bound-only staging, matching the ordinary
Connect admission result.

Linux uses a separate `stage_bound_profile` action. The daemon persists a private
bound-only marker before replacing the profile file and rejects ordinary Connect
while the marker remains, including after daemon restart. A later ordinary stage
durably replaces the profile before clearing the marker; invalidation removes
both. Bound Connect also requires a successful bound stage in the current daemon
process and the exact staged digest. Old daemons reject the new action, so they
cannot silently stage ATS input as an ordinary profile. This also grants no
recovered attempt or proof.
An early rejected stage request leaves a previous successful bound stage usable;
an error from profile storage closes bound admission because on-disk bytes may
already have changed.
Stage and invalidate requests are rejected as busy during a live transaction
or pending recovery without degrading the existing owner's health.
Its `can_connect` snapshot likewise remains false while the marker is present.
The daemon also watches the kernel-authenticated client PID plus process start
time for each bound request. Client exit cancels pending authorization/startup;
after the request settles, a running owner is stopped through the same serial
network restoration. Failed restoration remains owned for explicit retry. A
new process cannot use the old peer identity to cancel that exact request.
Linux ATS selection now requires a daemon-issued network context source, as
Android and Windows do. `read_network_context` returns a random process-local
ref for the daemon's current physical uplink. The daemon privately compares main
default routes, active interface addresses, per-link DNS and NetworkManager
connection identity, including Wi-Fi access point/BSSID. Its own `pokrov0`,
route table and DNS link are excluded; other uplink types fail closed. Bound Start carries the ref; daemon reads
it before admission, before network mutation and after startup, then watches the
running owner for change or observation failure. A mismatch cancels the exact
attempt and uses existing restoration. A newly sampled DNS/NetworkManager change
also notifies the bound owner without waiting for its next periodic read. Raw
network details stay in the daemon;
an unavailable read closes ATS admission. Netlink invalidation can cancel the
bound attempt while a slow physical sample is still running; that sample cannot
restore the invalidated ref. A failed sample revokes a current ref immediately;
an individual cancelled read does not. Ordinary Linux Connect is unaffected.
This source is NOT_VERIFIED; daemon restart reconciliation remains open.

The shared Android/Windows runtime adapter also refuses WARP's ordinary profile
restage while its current staged payload requires bound Connect. Changing WARP
requires fresh ATS preparation instead of clearing the native reuse restriction.

### ATS session-bound payload preparation (source, NOT_VERIFIED)

The shell injects `AppFirstTransportPayloadService` into the proof executor.
After transport and DNS pass, payload preparation and native execution share one
probe child and its original boot-time deadline. The configured active API origin
(or the sole configured origin) supplies the fixed HTTPS path
`/api/client/transport-proof/payload`; there is no discovery, retry or caller URL.
The admitted probe set and current stored session are required. Preparation makes
a fresh 256-byte upload and expected upload/device hashes in memory. It performs
no network IO. Session rereads, selection/owner/settings/restriction checks and
origin checks bracket asynchronous preparation and exchange operations.

`RuntimePayloadProbeExchange` permits one request take and one response acceptance.
The response must come from that exact endpoint, use status 200 and the closed
canonical JSON-plus-newline schema, fit 2 KiB, contain a 256-byte hex download and
match the nonce, probe set, upload digest and device binding. The response also
contains a canonical `observed_client_ip` from the owned ingress, retained only
in the exchange receipt until closure. A 401/403 from the
exact endpoint closes the selection. Selection closure or child cancellation
closes the exchange; closed/late/replayed calls cannot return a receipt. The
native producer must still authenticate TLS and execute through the owned Core,
reserve diagnostic bytes before IO and join all callbacks and IO on cancellation.

Payload PASS additionally requires native verifier/receipt refs to match the
exchange's accepted receipt, followed by the existing running-owner checks. The
executor releases its stored sensitive references after the actual native Future
settles and closes even a late preparation result. The parsed response does not
prove the chosen transport, expected egress, independent origins or a reusable lease.
Native producers and byte IO remain unimplemented; no probe/hash/native/API call
or validation command was executed. ATS stays inactive and source NOT_VERIFIED.

### ATS background control enrollment (source, NOT_VERIFIED)

For a catalog-bearing ATS start, `proveTransportConnection` first enrolls the
existing background restriction worker. One preparation child consumes the
remaining original transport cap; journal reads/retention/acknowledgement,
signed foreground control, capability mint and native configuration are awaited
without detached timeout wrappers. A running exact profile/module/request is
required. Journal recovery during an active action admits only that owned ATS
scope. Retained restrictions, revoked catalog/services/leases, expired authority,
or failed recovery prevent enrollment and stop this not-yet-proven attempt.

The native command binds the exact connect request as well as the stage digest.
One enrollment is allowed per attempt, and the same acknowledgement is required
before its proof ladder. Invalidating staged reuse does not discard the running
binding. Sensitive worker configuration remains memory-only. A failed/ambiguous
native response requests exact stop; failed cleanup retains the owner for retry.
Enrollment is not DNS/egress proof, a lease renewal, deadline extension or healthy
handoff. Android must already report running; a pending start cannot enroll.
Native proof producers, issuer/inventory, lease handoff
and restart reconciliation remain open. No checks, native calls or API requests
were executed for this source change.

### ATS Android uplink invalidation (source, NOT_VERIFIED)

Before selection, Android captures a native opaque network ref using
`RuntimeTransportNetworkContext` from the same engine that will stage the profile.
The bridge lazily owns one passive observer with underlying-network and default-
network callbacks until it closes. It does not request a network, open sockets,
or acquire the Core monitor. Default-network events preserve changes between
samples; the VPN becoming default retains the observed eligible uplink instead
of reranking other networks. This path requires Android API 24 or later, which
matches this app's `flutter.minSdkVersion` (24). Older hosts are outside the
supported Android build target.
Only `network_<32 hex>` leaves that observer; Network/LinkProperties and selected
uplink capability state stay local.
Every selection sample rereads it before consuming the original clock budget.
A changed/unavailable ref cancels selection; delayed profile work is still joined
and cannot publish a current result. The Android bound Start requires that ref,
and the process owner retains the exact observer/ref through permission and startup.
Observer invalidation or bridge close cancels the request, with existing exact
settlement rules. Background/resume alone does not close the observer.

The admitted service binds a bound attempt to the default-network generation
before starting its new Core, after closing the preceding Core/monitor. It uses
the existing service-owned monitor and checks that its selected Network and
LinkProperties equal the preparation observer's context before accepting the
generation. The preparation observer does not own that monitor's lifecycle.
Switching/loss of the selected Android Network, changed LinkProperties
(DNS, addresses, routes), or changed selected transport/validation/captive state
invalidates the preparation ref. A stale link callback cannot
select a previous network again. Raw link data and the local generation remain
inside the Android process and are not receipts or telemetry.

After binding, ownership/progress checks reject a changed network immediately.
The monitor cancels that exact request outside its network lock and asks its
admitted service to join the existing serial cleanup. Failed cleanup retains the
same resources/owner for retry; it cannot free Dart child/TUN reservations by
itself. Bound service callbacks continue checking request ownership after TUN
publication. A Core reload, including an interface-triggered reload, cancels the
bound attempt instead of replacing Core under the same proof identity. Ordinary
unbound reloads retain their existing path.

This binds Android selection/profile preparation, pending permissions and the
running/startup owner. It does not transfer a healthy lease to a new network,
reconcile process restart, implement
other hosts' network hooks, or prove native restoration. UI background/resume
alone is not interpreted as a network change. Source remains NOT_VERIFIED; no
tests, native operations, network probes or builds were run.

### ATS pending native startup (source, NOT_VERIFIED)

Windows selection now reads an opaque network ref from its service before
profile preparation and rereads it at each selection sample. It uses the same
engine for capture, preparation and staging. The runner forwards the ref in
bound Start; service compares a fresh read before accepting the private revision.
Command 24 and capability bit 18 gate this path; a missing/stale context cannot
fall back to a caller-generated ref or ordinary Connect. The ref is random,
process-local and changes with the revision. IP interface, unicast-address and route notifications invalidate it;
adapter address/prefix/DAD state, metrics/MTU, DNS suffix and ordered DNS servers
are also compared by the existing 100 ms bound-owner watcher and fresh status/
control boundaries. Unavailable or unstable reads cancel admission/use. This is
local OS metadata, with no socket, DNS query or remote observation.
When an active Wi-Fi adapter exists, the same local sample includes its WLAN
interface state, SSID, BSSID and authentication/cipher mode. WLAN connection and
roaming notifications invalidate the revision even if a change is reversed
between 100 ms samples. An unavailable WLAN read or notification registration
makes the ATS context unavailable; unchanged IP/DNS cannot retain the old owner.

The service excludes its `POKROV` TUN using the same interface-name convention as
recovery, retaining its LUID for deletion notifications. A notification only
changes an atomic revision; Core startup interruption and the existing serial
Stop/rollback own cancellation. Failed cleanup keeps the owner for explicit retry.
The bound owner also retains a handle to the client process reported by its
authenticated named pipe. If that process exits, the same watcher cancels and
serially restores the exact attempt; a later UI process cannot inherit its
proof-pending owner. Failure to obtain a live process handle rejects bound Start.
After invalidation, status cannot reuse a cached `running` frame: it projects a
pre-captured `busy` frame with proof pending until settlement, while preserving
an actual `recovery_required` failure. Bound control suppresses stale receipts.

This covers Windows selection/profile preparation and service admission/startup/
running ownership, including UI process exit. Service-restart reconciliation
and healthy lease handoff remain open.
No runtime/native/build/test verification was run for this source change.

Windows service status accepts a running bound tunnel with egress validation
false when the negotiated transport-proof field is present. This is the native
state before proof and after an acknowledged lease revocation; parsing it as an
incompatible service response would hide the unverified state from the shell.
Linux already reports the same state through its structured snapshot. Neither
state presents the tunnel as verified. Android and Windows native handoff
responses, then the ATS coordinator, require egress validation true: a late
promotion response after revocation cannot pass on
`transport_proof_pending=false` alone. These corrections are source NOT_VERIFIED.

The original tunnel child now waits through Android permission/service startup
using `RuntimeConnectProgress.snapshotForConnectRequest`. Polls use the existing
100 ms Android connect observer cadence, read local IPC only, and remain within
the original transport cap and candidate/selection deadlines. Cancellation wakes
the poll delay; any actual native read is awaited before the child settles.
No new Start, attempt, endpoint or deadline is created by this wait. Pending
observations are projected only into the current coordinator operation.

Android's closed receipt binds the exact admitted request, module, profile,
service and original deadline. TUN publication alone stays pending until Core
Start returns. The bound read exposes the actual active profile identity even
while the legacy egress oracle is unknown; it preserves all health fields and
does not create proof. Background enrollment and the proof consumer use this
same read after startup, including after staged reuse was invalidated. Missing,
replaced, expired or malformed ownership fails the attempt and requests exact
cleanup. Windows/Linux bound Start already returns its completed startup result
and does not use this Android polling adapter. Healthy handoff, native proof,
network-change/restart reconciliation and ordinary ATS activation remain open.
equal feature lists need not mean equal
binaries. Per-candidate admission also enforces the capability's signed profile
membership, existing global kills and validity. Source remains NOT_VERIFIED.

### ATS accepted lease reattachment (source, NOT_VERIFIED)

The three native hosts now expose a boolean accepted-lease marker in runtime
status. After a UI restart the coordinator lacks the exact request and lease
identity needed for signed-policy refresh and revocation, even if the native
service still reports healthy egress. Startup, resume and desktop polling treat
that state as unverified and disconnect it before a fresh ATS selection. An
unconfirmed stop retains the unverified presentation. A live UI with the exact
lease owner continues its normal policy refresh; closing the UI alone does not
cancel the native lease. This is source only, NOT_VERIFIED; native proof producers
and full restart/device verification remain open.
