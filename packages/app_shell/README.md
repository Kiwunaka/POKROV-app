# App Shell Seed

Planned ownership:

- first-run shell and consumer IA
- `Quick Connect`, `Locations`, `Profile`, and `Support` shell structure
- quick-connect home composition
- session-aware navigation guards

Current seed contents:

- `PokrovSeedApp`, a runnable Material shell for local widget tests
- `SeedAppContext`, a handoff contract between host shells and shared app state
- `buildSeedAppContext`, a clean-room host bootstrap factory for Android, iOS, macOS, and Windows
- `PokrovClientObservability`, the Android/Windows bootstrap, reducer-timeline,
  crash-marker and identity-free release-health adapter. It uses the existing
  app-first client for authenticated delivery without creating a session.
- an exact summary diagnostics preview with diagnostic ID, categories, virtual
  files, byte sizes and removal count. With an explicit Ed25519 public build
  pin, the shell verifies the signed recipient key set, persists only the
  encrypted envelope in private app support storage, and resumes its
  case-bound upload. Offline failure retains that encrypted object for an
  explicit retry. Without the pin, the existing ticket action remains an
  honestly labelled safe-summary fallback.
- route-mode chips for `Full tunnel`, `Selected apps`, and `All except RU` when the host allows them
- profile and support cards for activation-key redeem, external checkout, free-tier fallback, and community bonus handoff
- locations cards that keep the fixed `VLESS+REALITY`, `VMess`, `Trojan`, `XHTTP` ordering
