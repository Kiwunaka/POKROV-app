# WARP Runtime Proof Checklist

Last updated: 2026-06-09

This checklist is the client evidence gate for the internal WARP lane that is
shown to normal users as `Расширенная защита` / `Расширенная приватность`.

Until this checklist has current Android and Windows release-build evidence,
the app may ship the client lifecycle, consent, fallback, and diagnostics
contract, but public copy must not claim production-ready anonymity or a
fully proven WARP runtime.

Implementation update on 2026-06-09:

- WARP is now a client-local Hiddify-core lane. The app passes `warp.enable`,
  `id=p1`, mode, and safe defaults to core; backend-provided WireGuard material
  is optional rather than required.
- Backend `/api/client/warp/*` endpoints are the consent/status/event ledger.
  They must not block the client because server-side WARP material is absent.
- The UI may show a normal WARP control after explicit consent, while runtime
  proof still remains an owner/manual release-build gate.

## Evidence Rules

- Public UI uses `Расширенная защита` / `Расширенная приватность`.
- Literal `WARP`, WireGuard material, hostnames, subscription URLs, tokens,
  private keys, and raw config fragments stay out of screenshots, support
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
- Open the home tile and confirm the sheet uses public wording only.
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
- Open the home tile and confirm public wording only.
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
- Android physical release-build proof: `MANUAL_OWNER_TEST`.
- Windows end-user release-build proof: `MANUAL_OWNER_TEST`.
