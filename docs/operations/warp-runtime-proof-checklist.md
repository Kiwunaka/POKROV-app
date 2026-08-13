# WARP Runtime Proof Checklist

Last updated: 2026-08-13

This checklist is the client evidence gate for the WARP lane. Current client UI
may use the owner-approved labels `WARP`, `Расширенная защита`, or
`Расширенная приватность`.

Until this checklist has current Android and Windows release-build evidence,
the app may ship the client lifecycle, consent, fallback, and diagnostics
contract, but public copy must not claim production-ready anonymity or a
fully proven WARP runtime.

Implementation update on 2026-07-22:

- WARP is now a client-local Pokrov-core lane. The app passes `warp.enable`,
  `id=p1`, mode, and safe defaults to core; backend-provided WireGuard material
  is optional rather than required.
- Backend `/api/client/warp/*` endpoints are the consent/status/event ledger.
  They must not block the client because server-side WARP material is absent.
- The UI may show a normal WARP control after explicit consent, while runtime
  proof still remains an owner/manual release-build gate.
- POKROV Core receives a materialized sing-box WARP endpoint. The shared
  adapter materializes a `warp` endpoint into raw sing-box config, supports
  direct or proxy-backed WARP bootstrap plus proxy-over-WARP and
  WARP-over-proxy without route cycles, and
  restores the untouched managed profile when WARP is disabled.

## Evidence Rules

- Public UI and screenshots may use the literal feature label `WARP`.
- Raw WireGuard material, hostnames, subscription URLs, tokens, private keys,
  topology, and raw config fragments stay out of screenshots, support
  payloads, logs, and normal user-facing text.
- Evidence may mark owner-only device work as `MANUAL_OWNER_TEST` when the
  local agent cannot access a physical Android device, Windows release
  machine, signing identity, or live backend.
- Each proof item records build hash, artifact name, platform, app version,
  backend status response shape, runtime event result, and redaction check.

## Android Release-Build Proof

- Install the unsigned/outside-store beta APK on a physical Android device.
- Start from a clean app install and complete app-first onboarding.
- Fetch managed profile; WARP should be available even when the backend has no
  server-managed WireGuard material.
- Open the home tile and confirm the sheet uses an approved public WARP label
  without raw WireGuard or topology details.
- Enable consent and reconnect.
- Record one of these runtime states: `active`, `degraded`, or `fallback`.
- If fallback occurs, verify baseline POKROV connection remains usable.
- Revoke consent, reconnect, and verify the local enabled state is cleared.
- Attach support diagnostics and verify only `enhanced_protection_*` keys are
  present for this feature.
- Confirm no screenshot/log/payload contains raw WARP, WireGuard, private key,
  token, hostname, or subscription URL material.

## Windows Unsigned Beta Proof

- Install or unpack the unsigned Windows beta artifact on a clean user profile.
- Complete app-first onboarding and fetch the managed profile; WARP should be
  available even when the backend has no server-managed WireGuard material.
- Confirm responsive shell remains stable at `700`, `900`, `1024`, `1180`,
  and `1440` px widths.
- Open the home tile and confirm an approved public WARP label without raw
  WireGuard or topology details.
- Enable consent and reconnect.
- Record one of these runtime states: `active`, `degraded`, or `fallback`.
- If fallback occurs, verify baseline POKROV connection remains usable.
- Revoke consent, reconnect, and verify the local enabled state is cleared.
- Attach support diagnostics and verify only `enhanced_protection_*` keys are
  present for this feature.
- Confirm no screenshot/log/payload contains raw WARP, WireGuard, private key,
  token, hostname, or subscription URL material.

## Current Local Agent Status

- Client lifecycle contract: implemented.
- Backend status, consent, rotate, and runtime-event client calls: implemented.
- Client-local WARP runtime options without server material: implemented.
- Backend consent/status ledger no longer rejects client-local WARP for missing
  server material: implemented.
- Safe consent cache: implemented.
- Support diagnostics redaction: implemented.
- POKROV Core 1.0.3 release commit, sizes, and SHA-256 values: pinned.
- POKROV desktop ABI 2, private staged-file contract, and fail-closed
  adapter boundary: implemented.
- POKROV Core client-local WARP materialization and enable/disable parity: implemented
  in shared runtime tests.
- Manual `Белые списки` location variants currently gate WARP before runtime
  staging with actionable consumer copy. WARP-over-bridge composition remains
  `MANUAL_OWNER_TEST`; the client does not silently substitute `Обычный` or
  disable WARP.
- The pinned sing-box fork includes the reviewed WireGuard shutdown ordering:
  unregister callback, `Down`, then `Close`. The exact Windows DLL completed
  100 serial start/stop cycles; real WARP teardown on Android and Windows
  release candidates remains `MANUAL_OWNER_TEST`.
- POKROV Core Android host bridge and JVM contract tests: implemented.
- A 2026-08-13 Huawei run of the superseded local `1.0.3+11` build reproduced
  an Android ANR while the Quick Settings service was publishing a default
  network interface to the native listener on the main callback thread. The
  client now resolves and publishes that interface on dedicated serialized
  workers, ignores duplicate capability callbacks while resolution is pending,
  caches the last resolved interface, and fences stale network generations.
  Android JVM regression tests pass. The immediately following
  production-signed `1.0.4+13` Huawei run proved tile start/stop, WARP traffic,
  reconnect, Wi-Fi/LTE/Wi-Fi continuity, background screen-off operation, and
  notification disconnect without a new ANR. Later final-candidate changes
  were limited to the location variant sheet and support AI UI, but they
  changed the APK hash; the supporting run therefore remains
  `PASS_SUPPORTING_NOT_EXACT_FINAL` for WARP/uplink rather than being promoted
  to exact-final evidence.
- POKROV Core iOS host bridge: implemented in source; Xcode build and signed
  physical-device tunnel proof remain `MANUAL_OWNER_TEST`.
- Windows POKROV DLL repeated byte-identical release build and exact-client
  100-cycle raw start/stop test: `PASS` for `v1.0.3`. Private ACL, packaged
  route capture, real WARP, sleep/resume, and clean-machine proof remain
  candidate gates.
- macOS POKROV universal dylib build and ABI probe: `MANUAL_OWNER_TEST` on a
  Mac with Xcode.
- Android physical ordinary-tunnel/system-UX proof for the final `1.0.4+13`
  ARM64 hash: `PASS_EXACT_CANDIDATE`. Exact-final WARP/uplink repetition and
  long-duration endurance remain `MANUAL_OWNER_TEST`.
- Windows end-user release-build proof: `MANUAL_OWNER_TEST`.
