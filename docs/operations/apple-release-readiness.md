# Apple Release Readiness

Last updated: 2026-04-18

This document is the concrete Apple release-prep checklist for the next-client lane.

Current truth:

- this lane now carries explicit Apple placeholder config in source control
- those placeholders make bundle, entitlement, signing, and store-prep assumptions visible
- no real Apple credentials, provisioning profiles, signing identities, or notary profiles are committed here
- the lane is still not ready for public iOS or macOS publication

## Source Of Truth

- `config/apple-release.seed.json`
- `apps/ios_shell/ios/Flutter/AppleSigning.xcconfig`
- `apps/ios_shell/ios/Runner/Runner.entitlements`
- `apps/ios_shell/ios/Runner/PacketTunnelSharedPaths.swift`
- `apps/ios_shell/ios/Runner/Info.plist`
- `apps/ios_shell/ios/PacketTunnelExtension/Info.plist`
- `apps/ios_shell/ios/PacketTunnelExtension/PacketTunnelExtension.entitlements`
- `apps/ios_shell/ios/PacketTunnelExtension/PacketTunnelProvider.swift`
- `apps/macos_shell/macos/Runner/Configs/AppleSigning.xcconfig`
- `apps/macos_shell/macos/Runner/DebugProfile.entitlements`
- `apps/macos_shell/macos/Runner/Release.entitlements`
- `apps/macos_shell/macos/Runner/Info.plist`

## iOS Placeholder State

Checked in now:

- release-shaped bundle ID placeholder: `space.pokrov.app.ios`
- shared app-group placeholder carried by both the host and packet-tunnel extension entitlements
- deep-link scheme placeholder: `pokrov`
- checked-in `PacketTunnelExtension` target scaffold with real provider source, plist, and entitlements
- shared runtime-path helper so the host and packet-tunnel target point at the same staged managed-profile directory
- checked-in Libbox-backed provider wiring for command server startup, service startup, tunnel-network settings, and `NEPacketTunnelFlow` handoff
- explicit placeholders for Apple team, provisioning-profile specifier, TestFlight group, SKU, and App Store ID

Still missing before iOS release:

- Apple Developer team assignment
- signed proof that the checked-in provider can start and hold the shared app-group lane on real Apple hardware
- reviewed production Network Extension entitlements and signed `iphoneos` validation
- device-signing validation on `iphoneos`
- archive and export from Xcode
- TestFlight upload and App Store Connect processing
- store screenshots, support contact, privacy answers, and review notes

Mac/operator commands to run later:

```bash
cd apps/ios_shell
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -showBuildSettings
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos archive -archivePath build/Runner.xcarchive
```

## macOS Placeholder State

Checked in now:

- release-shaped bundle ID placeholder: `space.pokrov.app.macos`
- deep-link scheme placeholder: `pokrov`
- explicit placeholders for Apple team, provisioning profile, notary profile, App Store SKU, and App Store ID
- tighter release entitlements with sandbox, shared app group, and client networking
- hardened-runtime build placeholder for release signing

Still missing before macOS release:

- Apple Developer team assignment
- chosen distribution path: Developer ID direct or Mac App Store first
- signed archive or exported `.app`
- notarization submission, success result, and stapled artifact
- Gatekeeper validation on the signed artifact
- store screenshots, support contact, privacy answers, and review notes

Mac/operator commands to run later:

```bash
cd apps/macos_shell
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Release -showBuildSettings
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Release archive -archivePath build/Runner.xcarchive
xcrun notarytool submit build/Runner.zip --keychain-profile "REPLACE_WITH_NOTARY_PROFILE" --wait
xcrun stapler staple build/POKROV.app
spctl -a -vv build/POKROV.app
```

## What These Placeholders Do Not Mean

- they do not prove Apple Developer enrollment is active
- they do not prove the bundle IDs are reserved
- they do not prove provisioning works
- they do not prove the checked-in packet-tunnel service can carry traffic on signed Apple builds
- they do not prove notarization, TestFlight, App Store, or Mac App Store approval
