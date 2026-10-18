# macOS Engineering Host

This host is outside the current public pair. Signing, native-artifact and
device limits belong to [Apple readiness](../../docs/operations/apple-release-readiness.md);
[cutover readiness](../../docs/operations/cutover-readiness.md) owns release scope.

Current responsibility:

- macOS-specific Flutter host entry point
- wiring the shared `app_shell` package into the macOS host
- using the shared POKROV Core desktop FFI adapter and `pokrov-core.dylib` bundle path
- carrying placeholder Apple signing, entitlement, and notarization metadata for the next-client lane

Deferred responsibility:

- macOS route-mode and per-app policy integration
- a macOS-built universal POKROV Core dylib and ABI probe for the exact candidate
- production packaging, signing, and release wiring

Checked-in Apple-readiness placeholders:

- `macos/Runner/Configs/AppleSigning.xcconfig` for bundle ID, team, hardened-runtime, App Store, and notary placeholder values
- `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` for a tighter client-facing entitlement baseline
- `macos/Runner/Info.plist` deep-link and category placeholders for store-prep consistency

Still blocked before real macOS publication:

- no committed Apple team, provisioning profile, Developer ID identity, or notary profile
- no signed archive, notarized app bundle, stapled artifact, or Gatekeeper validation from a Mac
- no Windows-produced substitute is accepted for the required universal `pokrov-core.dylib`; build the exact candidate's pinned Core source on macOS, as required by Apple readiness
- no operator decision yet on direct Developer ID distribution versus Mac App Store-only packaging
