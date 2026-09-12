# Setup privacy binding — 2026-09-12

`binding.json` binds Core 6b271decead88b708e2fc03984b703b0a4e63ebd to the
development Android/Windows consumer. Earlier packages retain their own identities.

- `native/`: two byte-identical native DE builds per platform using warmed caches,
  original/corrected SBOMs, exact library receipts and binary composition.
- `native-test-result.json` and `setup-source-delta.patch`: the setup-path regression
  fails on the old source; both focused privacy tests and the full Core script pass.
  Full raw test output was not retained; the receipt records hashes and safe summaries.
- `source-dll-privacy/`: exact new DLL, six synthetic marker categories, debug disabled,
  invalid config before service startup, no live profile/TUN. FFI/stdout/stderr and
  five generated files contain no markers. Raw streams were hashed, not retained.
  The prior failure is retained in [Core880 follow-up](../2026-09-12-r12-wintun-followup/README.md).
- `windows-abi-proxy.json`: ABI2/event ABI1, 15 exports and 100 Dart proxy cycles.
- `binary-scans/` and `static-triage-binding.json`: five scans retain nine advisory
  IDs and their bounded prior dispositions; zero extracted symbols is not clearance.
- `source-packet/`: metadata for a private DE 3902-entry archive, all inputs hashed,
  and five offline module graphs. Prebuilt SDK/toolchain reconstruction and full
  corresponding-source/legal clearance are not established.
- `notices-preparation.json`: 191 verbatim license bodies unchanged; old inventory
  source_ref labels identify inputs, while the shipped notice names the current commit.

Consumer analyze, 81 runtime tests, 8 Android tests, seed/docs contracts and
diff/artifact checks PASS. One generic opt-in DLL test is skipped; the separate
exact-DLL driver passes 100 cycles. Source promotion and installed acceptance
remain pending at binding.
No public release or complete C05/V01 acceptance is established by this directory.
