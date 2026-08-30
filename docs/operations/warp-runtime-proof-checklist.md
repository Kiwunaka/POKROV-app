# WARP Runtime Proof Checklist

Last updated: 2026-08-30

Registry class: `ACTIVE_EXECUTION`.

This is the current client evidence gate for WARP on signed
`pokrov-1.2.0-candidate.10`, app `1.2.0+4046`. The successor
`1.2.0+4048`/Core `cd8f0f4…884d` line is pre-candidate only. Older device or runtime passes
are supporting evidence only and cannot close the exact-candidate gate.

The client UI may use the owner-approved labels `WARP`,
`Расширенная защита`, or `Расширенная приватность`. Public copy must not claim
production-ready anonymity or a fully proven WARP runtime until the gate below
passes for exact promoted bytes.

## Current Contract

- WARP is a client-local POKROV Core lane. The client passes `warp.enable`,
  `id=p1`, mode and safe defaults to Core; backend-provided WireGuard material
  is optional.
- Backend `/api/client/warp/*` endpoints own consent, status and runtime-event
  bookkeeping. Missing server-side WARP material must not block the local lane.
- The shared adapter materializes the WARP endpoint into the managed sing-box
  profile, rejects route cycles and restores the untouched managed profile when
  WARP is disabled.
- Manual `Белые списки` variants remain a fail-closed gate before staging.
  WARP-over-bridge composition remains `MANUAL_OWNER_TEST`; the client does not
  silently substitute `Обычный` or disable WARP.

## Evidence Rules

- Raw WireGuard material, hostnames, subscription URLs, tokens, private keys,
  topology and raw config fragments stay out of screenshots, support payloads,
  logs and normal user-facing text.
- Each proof names the exact app version, 40-character client revision,
  artifact SHA-256, platform/OS/device, Core identity, runtime result, UTC time
  and redaction result.
- Physical-device, clean-machine, signing-identity or live-backend work remains
  `MANUAL_OWNER_TEST` until executed and retained for the exact candidate.
- An older candidate or a different APK/installer hash is
  `PASS_SUPPORTING_NOT_EXACT_FINAL`, never an exact-candidate pass.

## Android Exact-Candidate Gate

1. Install the exact production-signed outside-store APK on a physical device
   from a clean app state and complete app-first onboarding.
2. Fetch the managed profile and confirm WARP is available without
   server-managed WireGuard material.
3. Enable consent, reconnect and retain `active`, `degraded` or `fallback` for
   the same connection generation.
4. If fallback occurs, prove the baseline POKROV connection remains usable.
5. Exercise Wi-Fi/LTE/Wi-Fi, screen-off/background, reconnect, tile start/stop
   and notification disconnect without ANR or stale generation.
6. Revoke consent, reconnect and prove the local enabled state is cleared.
7. Inspect support diagnostics and retained media for the redaction rules.

Current status:
`PASS_EXACT_CANDIDATE_FALLBACK_PATH; ACTIVE_WARP_TRAFFIC_NOT_PROVEN` on one
physical Android device. The defined fallback path, baseline usability,
handoff/lifecycle, revoke and redaction steps passed; this is not an active
WARP-carriage claim or broad release approval.

## Windows Exact-Candidate Gate

1. Install the exact outside-store installer on a clean non-elevated user
   profile and verify UI/service/Core identity before connection.
2. Fetch the managed profile and confirm WARP is available without
   server-managed WireGuard material.
3. Enable consent, reconnect and retain `active`, `degraded` or `fallback` for
   the same connection generation.
4. Prove clean TUN/DNS lifecycle, route capture, sleep/resume, network change,
   repeated teardown and baseline fallback on the packaged service path.
5. Revoke consent, reconnect and prove the local enabled state is cleared.
6. Inspect support diagnostics and retained media for the redaction rules.

Current status: `MANUAL_OWNER_TEST` for exact `1.2.0` candidate bytes.

## Current Local Status

- Client lifecycle, consent cache, backend calls and diagnostics redaction:
  implemented and locally tested.
- Client-local WARP materialization, enable/disable parity, desktop ABI 2 and
  Android host/JVM boundaries: implemented and locally tested.
- Candidate.8 binds the Core `1.1.0` Android AAR and Windows
  DLL from security-fixed `a45d69e40ed7d892619a2b5c4592a527f630665e`; two local rebuilds per
  platform are byte-identical, and the exact DLL passes 100 proxy-only
  start/stop cycles. The exact signed manifest and six-artifact supply chain
  pass; public promotion and the complete WARP platform-runtime matrix remain
  separate gates. Prior exact
  production-signed `547f096` Android bytes reached verified ordinary Frankfurt
  on one physical Beeline path; AWG2/AWG3.1 transport also passed there but
  their selected-endpoint checks failed at `egress_probe_dns_lookup`. Corrected
  `a45d69e` plus production-signed client `68779c4` now reaches retained green
  selected-endpoint state for both AWG2 and AWG3.1 on physical Beeline. This
  bounded control did not close WARP lifecycle, handoff, per-app, OEM or
  endurance proof before candidate.8.
- The successor `1.2.0+4048` line binds secret-safe Core `cd8f0f4…884d`.
  Android AAR `2a9677d9…c6a69` and Windows DLL `f284fa88…8204` each reproduce
  byte-for-byte across two builds; the DLL passes 100 proxy-only start/stop
  cycles. This is `PASS_LOCAL_PRE_CANDIDATE`, not transferred WARP, device,
  emulator, clean-VM or exact-candidate evidence.
- Exact x86_64 production build `1.2.0+4046` on LDPlayer created TUN for a
  WARP attempt and for its automatic ordinary fallback, but both paths failed
  the required Core egress probe with terminal `EGRESS-001`. A separate
  WARP-disabled ordinary control failed with the same code. The emulator was
  restored to WARP off with no POKROV service or `tun0`. Classification:
  `BLOCKED_BY_LDPLAYER_NETWORK_CURRENT_ORIGIN`; this is neither a WARP-specific
  failure nor physical proof.
- On exact candidate.8 ARM64 bytes, three observed WARP attempts consistently
  reached the explicit paused/ordinary fallback after the WARP check did not
  pass. Every terminal generation retained app-confirmed tunnel, DNS and
  selected egress. Mobile/Wi-Fi/mobile/Wi-Fi, screen-off, forced deep Doze,
  app standby, Quick Settings stop/start and notification disconnect passed;
  revoke cleared consent and the final ordinary control passed with WARP off.
  Diagnostics were redaction-safe and device state was restored. This closes
  the checklist's fallback path on one physical Android device, while active
  WARP traffic remains `NOT_PROVEN`.
- Exact Android release-build WARP fallback/uplink/teardown evidence:
  `PASS_EXACT_CANDIDATE_FALLBACK_PATH`.
- Exact Windows release-build WARP/uplink/teardown evidence:
  `MANUAL_OWNER_TEST`.

## Retained History

Candidate-specific `1.0.x` results and their original status labels are kept in
[2026-08-13-warp-runtime-proof-snapshot.md](history/2026-08-13-warp-runtime-proof-snapshot.md).
