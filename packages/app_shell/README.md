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
- an authenticated, existing-session-only release-health baseline reader for
  the exact current build. Diagnostics keeps the response in memory, accepts
  only closed weekly sample/failure bands, hides comparison below the privacy
  floor, and never stores or displays identity, bucket indexes, exact counts or
  exact percentages.
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

Android foreground network handling uses the native context reference and the existing protected candidate handoff. The optional untrusted Wi-Fi policy defaults off; it starts only while the app is foreground, with a known untrusted SSID, a non-captive physical uplink and VPN/notification/SSID permissions already granted. Explicit stop suppresses automatic starts on that physical uplink and fences older requests by a native stop epoch. This uses the current request owner and proof flow; it does not start a cold process or a second VPN service.

The first Android connection without a staged or cached profile gives each ordinary candidate up to 12 seconds within the existing selection budget, covering cold Core setup and the authenticated HTTPS probes. Later, cached and recovery probes keep their four-second limit; cancellation still joins native work before staging or connecting. Diagnostics keeps an initialized Core in the Core phase until a profile is staged, so initialization cannot appear as a completed system tunnel.
