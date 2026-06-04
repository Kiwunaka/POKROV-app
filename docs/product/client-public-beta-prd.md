# Client Public Beta PRD

Status: active  
Last updated: 2026-05-26

## Product Scope

The public client beta targets:

- Android, approved for outside-store public beta after operator-attested physical release-build audit and the `2026-05-15` runtime handoff evidence.
- Windows, approved for outside-store public beta as an unsigned EXE with required unknown-publisher warning and the `2026-05-15` runtime handoff evidence.

iOS and macOS are readiness tracks only.

This is Open Beta v4 outside-store public beta authorization, not a `1.0.0`, store, trusted-signing, raw Android audit, or RU-origin readiness authorization.

## Safe Public Claims

- POKROV has an active app-first client lane.
- Android and Windows are the public outside-store beta platforms for this wave.
- Android physical-device audit is operator-attested for this beta wave; do not claim raw repository audit evidence unless it is later attached.
- Windows can be a gated unsigned beta only with clear SmartScreen or unknown-publisher guidance.
- Runtime APK/EXE handoff and Lava.top beta checkout evidence are green for the `2026-05-15` platform launch decision.

## Unsafe Claims

- Do not claim public Android safety beyond the operator-attested beta-wave audit evidence.
- Do not claim production signing unless signing material and verification are confirmed.
- Do not claim Apple public release in this wave.
- Do not show raw configs, secrets, local control surfaces, or operator jargon in consumer UI.

## Current Launch Decision

The platform launch decision changed to outside-store public beta `GO` on `2026-05-15`. For future stronger claims or new release candidates, refresh evidence for:

- Android operator-attested physical-device audit posture;
- Android outside-store APK checksum and runtime handoff state;
- Windows artifact checksums and unsigned-warning posture;
- runtime handoff URLs;
- support/download copy parity;
- current-origin, brain-origin, and RU-origin evidence where runtime URLs or reachability matter.
