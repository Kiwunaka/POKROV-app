# Client bootstrap and runtime preparation

## Local setup

1. Run `scripts/bootstrap-workspace.ps1` from the repository root. It prepares ignored local config from templates, resolves the Flutter workspace and fills missing Android Gradle wrapper files using a temporary Flutter project. It keeps existing host customization.
2. For an affected native host, validate the [selected runtime](../../scripts/README.md#runtime-selection) with `scripts/check-client-version-parity.ps1 -Platforms <platform>`. Pass the same runtime manifest used by the build. Sync only the host that needs a new binding.
3. Run focused Flutter analysis and tests in the affected package. `scripts/run-tests.ps1` is the workspace runner and includes Android direct/store unit tests.
4. Use the host and build entrypoints in the [repository map](folder-structure.md).

## Start, stop and recovery

The shell restores [persisted state](persisted-state-contract.md), reads the installed host and Core capabilities and opens the authenticated account session. Bootstrap can discover readiness without staging a profile or asking for VPN privileges. The connection manager owns one active operation, its selected network, policy snapshot, admitted candidates and cancellation budget.

The runtime package verifies and materializes a managed profile for the selected route mode. The profile can come from the authenticated backend or from the protected cache while ordinary access remains valid. Reevaluate entitlement, policy and catalog restrictions at reuse. Cached location display data cannot restore a connection. Service restrictions or revocation must settle on the affected runtime before another route can use it.

The native host accepts the prepared identity and owns the VPN service or installed privileged helper. Start, cancel, restart, stop and proof results are scoped to that identity. A stale callback or completed previous operation does not settle the current attempt. If route intent or uplink changes while connecting, invalidate the affected work. See the [host runtime contract](platform-privilege-runtime-contract.md).

Use the runtime's owned egress check for the selected route before reporting a usable connection. A resolved address, native process start or transport socket alone does not establish protection. A failed reserve or expired grant must not be presented as an active route.

## Update handoff

The About sheet can retry a validated update after a failed download or missing install permission. Automatic prompts are deduplicated. Android accepts the stable channel and a bounded metadata record with the canonical GitHub release asset, size and SHA-256. The direct flavor verifies the downloaded APK, package identity, version increase, SDK/ABI and signing continuity before handing it to the OS installer. The store flavor opens only the configured Play listing.
