# iOS Shell Seed

Current responsibility:

- iOS-specific Flutter host entry point
- wiring the seed `app_shell` package into an iOS-facing starter
- carrying a seed `NETunnelProviderManager` connect/disconnect request lane from the Flutter runtime bridge into a real checked-in packet-tunnel target
- staging managed profiles through a shared app-group runtime directory that both the host and packet-tunnel provider can read
- carrying a checked-in Libbox-backed packet-tunnel provider that boots `MobileSetup`, `LibboxSetup`, a command server, and a service-backed `openTun` path
- carrying placeholder Apple signing, bundle metadata, and Network Extension entitlements for the next-client lane

Deferred responsibility:

- iOS route-mode and per-app policy integration
- reviewed production Network Extension entitlements and signed app-group validation on device
- source-verified `iphoneos` proof that the checked-in tunnel service actually carries traffic on Apple hardware
- production packaging, signing, and release wiring

Checked-in Apple-readiness placeholders:

- `ios/Flutter/AppleSigning.xcconfig` for bundle ID, team, profile, TestFlight, and App Store placeholder values
- `ios/Runner/Runner.entitlements` for the shared app-group plus packet-tunnel-provider seed entitlement
- `ios/PacketTunnelExtension/` for the real `PacketTunnelExtension` target scaffold, provider source, plist, and extension entitlements
- `ios/Runner/PacketTunnelSharedPaths.swift` for the shared app-group staging path used by both host and provider
- `ios/Runner/Info.plist` deep-link and display-name placeholders for store-prep consistency

Current packet-tunnel scaffold behavior:

- the host bridge stages the parsed managed profile into the shared runtime directory and points `NETunnelProviderManager` at the real `space.pokrov.app.ios.networkextension` bundle ID placeholder
- the checked-in provider target resolves the shared app-group container, runs `MobileSetup` plus `LibboxSetup`, validates the staged config with `LibboxCheckConfig`, starts a Libbox command server, opens `NEPacketTunnelFlow` through an extension-side platform interface, and starts a real Libbox service when the Apple app-group entitlement is actually available
- the target removes the previous in-repo gap where the host only pointed at a hypothetical bundle ID

Still blocked before real iOS publication:

- no committed Apple team, provisioning profile, or App Store Connect identifiers
- no signed `iphoneos` proof that the checked-in provider can start and keep the shared app-group lane on real Apple hardware
- no reviewed production entitlement approval or signed Network Extension validation
- no archive, export, TestFlight, or App Store validation from a Mac
