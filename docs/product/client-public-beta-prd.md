# Client Public Beta PRD

Status: active  
Last updated: 2026-04-26

## Product Scope

The public client beta targets:

- Android, gated until physical release-build audit passes.
- Windows, gated until artifact, checksum, signing or unsigned-warning, and handoff checks pass.

iOS and macOS are readiness tracks only.

This is Open Beta v4 preparation, not a `1.0.0` release authorization.

## Safe Public Claims

- POKROV has an active app-first client lane.
- Android and Windows are the intended public beta platforms.
- Android is internal beta only until the physical audit is green.
- Windows can be a gated unsigned beta only with clear SmartScreen or unknown-publisher guidance.

## Unsafe Claims

- Do not claim public Android safety before the physical audit.
- Do not claim production signing unless signing material and verification are confirmed.
- Do not claim Apple public release in this wave.
- Do not show raw configs, secrets, local control surfaces, or operator jargon in consumer UI.

## Current Launch Decision

Do not release publicly until the platform launch decision changes and client evidence proves:

- Android release-installed physical-device audit;
- Android signing state;
- Windows artifact checksums and signing or unsigned-warning posture;
- runtime handoff URLs;
- support/download copy parity;
- current-origin, brain-origin, and RU-origin evidence where runtime URLs or reachability matter.
