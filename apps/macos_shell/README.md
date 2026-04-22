# macOS Shell Seed

Current responsibility:

- macOS-specific Flutter host entry point
- wiring the seed `app_shell` package into a macOS-facing starter
- documenting the future location of macOS permission and lifecycle glue
- carrying placeholder Apple signing, entitlement, and notarization metadata for the next-client lane

Deferred responsibility:

- macOS route-mode and per-app policy integration
- macOS engine and connect lifecycle glue
- production packaging, signing, and release wiring

Checked-in Apple-readiness placeholders:

- `macos/Runner/Configs/AppleSigning.xcconfig` for bundle ID, team, hardened-runtime, App Store, and notary placeholder values
- `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` for a tighter client-facing entitlement baseline
- `macos/Runner/Info.plist` deep-link and category placeholders for store-prep consistency

Still blocked before real macOS publication:

- no committed Apple team, provisioning profile, Developer ID identity, or notary profile
- no signed archive, notarized app bundle, stapled artifact, or Gatekeeper validation from a Mac
- no operator decision yet on direct Developer ID distribution versus Mac App Store-only packaging
