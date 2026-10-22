# App Shell

The [repository map](../../docs/architecture/folder-structure.md) locates source
entrypoints; the [product contract](../../docs/product/client-product-contract.md)
owns user-facing behavior and [cutover readiness](../../docs/operations/cutover-readiness.md)
owns release acceptance.

Current responsibility:

- first-run shell and consumer IA
- Protection, Locations, Rules, Profile and Support composition
- quick-connect home composition
- session-aware navigation guards

Entrypoints and behavior:

- `PokrovSeedApp`, the shared Material application and its widget-test entrypoint
- `SeedAppContext`, a handoff contract between host shells and shared app state
- `buildSeedAppContext`, the shared host bootstrap factory
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
- profile and support actions for code redeem, external checkout, account/access status and community bonus handoff
- Operator replies appear in the existing notifications inbox. Opening it refreshes the server state, waiting for any inbox request already in flight before displaying and marking notifications read; a support notification opens its exact conversation, including closed tickets. The chat refreshes and scrolls to new replies while foregrounded. Closing a ticket does not stop updates to its open chat: a later operator reply can reopen it and appears through the same polling policy. An older in-flight poll cannot replace the history returned by a newer send or overwrite a pending message. The inbox refreshes on resume and every 60 seconds in the foreground after authenticated account data is available, without overlapping requests or a full account refresh. Pause, dispose and session rejection stop the timer. This uses the current support screen without a new permission or system push channel.
- Locations offers a country or Auto in both interface modes; protocol and path selection remain automatic under the product contract, with WARP enabled only by a current manual action

Android foreground network handling uses the native context reference and the existing protected candidate handoff. The optional untrusted Wi-Fi policy defaults off; it starts only while the app is foreground, with a known untrusted SSID, a non-captive physical uplink and VPN/notification/SSID permissions already granted. Explicit stop suppresses automatic starts on that physical uplink and fences older requests by a native stop epoch. This uses the current request owner and proof flow; it does not start a cold process or a second VPN service.

Rules saves the untrusted Wi-Fi toggle immediately and reflects external changes while keeping pending routing edits. The toggle alone does not create an Apply or reconnect action.

Custom DoH accepts bounded HTTPS resolver URLs without user information, query
parameters or fragments. The DNS sheet rejects unsupported input explicitly.
A previously saved URL with a query or fragment stays editable but cannot
replace the profile DNS; Rules explains that fallback until the user corrects
the URL or chooses another preset. Host, port and resolver paths remain
supported. Managed SmartDNS policy and its signed resolver scope are unchanged.

Android access-network diagnostics uses the existing authenticated flow and an hourly app-lifecycle timer, sharing a persisted 60-minute due check with open/connect/resume. Roaming, low or unknown battery, power-save and missing/expired sessions skip it; analytics neither renews auth nor wakes a force-quit app. One owned, physically bound POST has a body up to 1 KiB, 2.5-second connect/read timeouts and a six-second disconnect timer; response bodies are not read. These are configured limits, not a measured hard DNS-settlement or total-wire-byte guarantee. A failed check queues a small unknown-network observation for ordinary D8 delivery without changing VPN state; resource skips queue nothing. No new UI, Android permission or service is introduced. Windows physical geography remains unknown, and the profile cache keeps its six-hour interval.

Cold Android Connect keeps the ordinary probe policy for both initial profile preparation and cached candidates; a cached profile does not imply a warm Core instance. Recovery and Windows retain their separate budgets, as described in the [bootstrap workflow](../../docs/architecture/bootstrap-workflow.md). Cancellation still joins native work before staging or connecting. Diagnostics keeps an initialized Core in the Core phase until a profile is staged, so initialization cannot appear as a completed system tunnel.

After Auto selects a candidate, the staged profile and the confirmed location use that exact material's node, even when the catalog still records the server's initial choice. The location describes the selected node; it is not a measured geolocation of the exit IP. WARP continues to show an unknown exit country.
