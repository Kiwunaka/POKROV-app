# Client Public Beta PRD

Status: active  
Last updated: 2026-05-09

## Product Scope

The public client beta targets:

- Android, staged as an outside-store APK after operator-attested physical release-build audit; runtime link sync and final platform GO are still pending.
- Windows, staged as an unsigned outside-store EXE with required unknown-publisher warning; runtime link sync and final platform GO are still pending.

iOS and macOS are readiness tracks only.

This is Open Beta v4 preparation, not a `1.0.0` release authorization.

## Safe Public Claims

- POKROV has an active app-first client lane.
- Android and Windows are the intended public beta platforms.
- Android physical-device audit is operator-attested for this beta wave; do not claim raw repository audit evidence unless it is later attached.
- Windows can be a gated unsigned beta only with clear SmartScreen or unknown-publisher guidance.

## Unsafe Claims

- Do not claim public Android safety beyond the operator-attested beta-wave audit evidence.
- Do not claim production signing unless signing material and verification are confirmed.
- Do not claim Apple public release in this wave.
- Do not show raw configs, secrets, local control surfaces, or operator jargon in consumer UI.

## Current Launch Decision

Do not release publicly until the platform launch decision changes and client evidence proves:

- Android operator-attested physical-device audit posture;
- Android outside-store APK checksum and runtime handoff state;
- Windows artifact checksums and unsigned-warning posture;
- runtime handoff URLs;
- support/download copy parity;
- current-origin, brain-origin, and RU-origin evidence where runtime URLs or reachability matter.
