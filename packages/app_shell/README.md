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
- route-mode chips for `Full tunnel`, `Selected apps`, and `All except RU` when the host allows them
- profile and support cards for activation-key redeem, external checkout, free-tier fallback, and community bonus handoff
- locations cards that keep the fixed `VLESS+REALITY`, `VMess`, `Trojan`, `XHTTP` ordering
