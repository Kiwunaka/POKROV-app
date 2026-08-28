# WARP Runtime Proof Checklist

Last updated: 2026-08-27

Registry class: `ACTIVE_EXECUTION`.

This is the current client evidence gate for WARP on the POKROV `1.2.0+4044`
`PRE_CANDIDATE_LOCAL` Android/Windows line. Older device or runtime passes are
supporting evidence only and cannot close the exact-candidate gate.

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

Current status: `MANUAL_OWNER_TEST` for exact `1.2.0` candidate bytes.

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
- The local pre-candidate client binds the corrected Core `1.1.0` Android AAR
  from `54e76bbb61f79bd0eb0cdbddb71f52e12645fa13`; Windows temporarily retains
  exact DLL bytes from `344b317a7a09eca7943a93866b193553538bd8f6`.
  Platform-source convergence remains a promotion gate.
- Exact Android and Windows release-build WARP/uplink/teardown evidence:
  `MANUAL_OWNER_TEST`.

## Retained History

Candidate-specific `1.0.x` results and their original status labels are kept in
[2026-08-13-warp-runtime-proof-snapshot.md](history/2026-08-13-warp-runtime-proof-snapshot.md).
