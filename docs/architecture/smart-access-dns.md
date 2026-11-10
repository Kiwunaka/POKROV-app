# Smart Access DNS

Smart Access reads the signed Platform routing catalog and provider policy. Ordinary connection keeps the signed VPN or block route if a Smart Access provider is unavailable, revoked or only covers part of the required service. A provider-specific check uses its separate signed scope. The [Platform catalog contract](../../../VPN/docs/architecture/routing-catalog-contract.md) owns publication and policy floors.

The client filters providers by signed host scope, entitled account and device session, OS, loaded Core capabilities and current network. Auto can select only a complete eligible scope. It does not treat a partial result as proof for another host. A denied or expired provider grant cannot broaden the current route.

The host verifies and binds the grant and passes the scoped runtime settings to Core. The managed DNS path is limited to the approved names and transport. The runtime keeps the approved resolver path and service egress bound to the corresponding settings. Expiry, drain and revocation stop affected flows. Client policy and native restrictions are reconciled against the same runtime after UI restart.

For operator validation, use an owned test account and verify the signed scope, current grant, native readback and an owned egress or explicitly in-scope service request. A signed provider entry, a control-plane response or an ordinary VPN smoke does not demonstrate provider traffic.
